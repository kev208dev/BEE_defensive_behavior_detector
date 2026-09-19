import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/mode_storage.dart';
import '../../../core/models/alert.dart';
import '../../../core/models/hive_status.dart';
import '../../../core/providers.dart';
import '../data/alert_repository.dart';
import 'alert_controllers.dart';
import 'notification_service.dart';

/// Whether the manager phone should poll for alerts.
///
/// Off in demo mode (there is no server to poll) and overridden to `false` in
/// widget tests, where a periodic timer would otherwise keep `pumpAndSettle`
/// from ever settling.
final Provider<bool> alertWatchEnabledProvider =
    Provider<bool>((Ref ref) => !AppConfig.demoMode);

/// Owns the process-wide notification service.
final Provider<LocalNotificationService> localNotificationServiceProvider =
    Provider<LocalNotificationService>((Ref ref) {
  final LocalNotificationService service = LocalNotificationService();
  ref.onDispose(service.dispose);
  return service;
});

/// What the manager screen knows about alert watching.
@immutable
class AlertWatcherState {
  const AlertWatcherState({
    this.watching = false,
    this.lastPolledAt,
    this.latestAlert,
    this.newAlertCount = 0,
  });

  final bool watching;
  final DateTime? lastPolledAt;
  final AlertSummary? latestAlert;

  /// How many new DANGER alerts have been surfaced since watching began.
  final int newAlertCount;

  AlertWatcherState copyWith({
    bool? watching,
    DateTime? lastPolledAt,
    AlertSummary? latestAlert,
    int? newAlertCount,
  }) {
    return AlertWatcherState(
      watching: watching ?? this.watching,
      lastPolledAt: lastPolledAt ?? this.lastPolledAt,
      latestAlert: latestAlert ?? this.latestAlert,
      newAlertCount: newAlertCount ?? this.newAlertCount,
    );
  }
}

/// Polls the backend for new alerts and raises a local notification for each.
///
/// **Why this exists.** Push delivery is the product's real mechanism, but it
/// depends on a configured Firebase project. This watcher gives the manager
/// phone a second, self-contained path: it asks
/// `GET /api/alerts?since=<watermark>` on a timer and notifies locally. The
/// end-to-end demo therefore works with zero Firebase setup, and when FCM *is*
/// configured the two paths converge — [_notifyIfNew] de-duplicates by alert
/// id, so an alert that arrives by push and is then seen by a poll only
/// notifies once.
final NotifierProvider<AlertWatcher, AlertWatcherState> alertWatcherProvider =
    NotifierProvider<AlertWatcher, AlertWatcherState>(AlertWatcher.new);

class AlertWatcher extends Notifier<AlertWatcherState> {
  Timer? _timer;
  DateTime? _watermark;
  final Set<String> _notifiedIds = <String>{};

  @override
  AlertWatcherState build() {
    // Riverpod disposes the notifier when nothing watches it; the timer must
    // go with it or it would keep firing against a dead ref.
    ref.onDispose(_stopTimer);
    return const AlertWatcherState();
  }

  /// Begins polling. Safe to call repeatedly, and a no-op when disabled.
  void start() {
    if (state.watching) return;
    if (!ref.read(alertWatchEnabledProvider)) return;

    _watermark = ref.read(modeStorageProvider).readLastAlertSeenAt();
    state = state.copyWith(watching: true);

    // Poll immediately so a DANGER raised while the app was closed is not
    // hidden until the first interval elapses.
    unawaited(poll());
    _timer = Timer.periodic(
      AppConfig.alertPollInterval,
      (Timer _) => unawaited(poll()),
    );
  }

  void stop() {
    _stopTimer();
    state = state.copyWith(watching: false);
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// One poll cycle. Never throws — a failed poll just means we try again.
  Future<void> poll() async {
    final AlertRepository repository = ref.read(alertRepositoryProvider);
    try {
      final List<AlertSummary> alerts = await repository.fetchAlerts(
        since: _watermark,
        limit: 20,
      );
      ref.read(connectionProvider.notifier).report(success: true);
      state = state.copyWith(lastPolledAt: DateTime.now());

      if (alerts.isEmpty) return;

      // fetchAlerts returns newest first; notify oldest first so the most
      // recent alert ends up on top of the notification shade.
      for (final AlertSummary alert in alerts.reversed) {
        await _notifyIfNew(alert);
      }

      await _advanceWatermark(alerts);
      // The list screen should reflect what we just found.
      unawaited(ref.read(alertListControllerProvider.notifier).refresh());
    } on Object catch (error) {
      debugPrint('AlertWatcher: poll failed — $error');
      ref.read(connectionProvider.notifier).report(success: false);
    }
  }

  Future<void> _notifyIfNew(AlertSummary alert) async {
    if (!_notifiedIds.add(alert.id)) return;

    state = state.copyWith(
      latestAlert: alert,
      newAlertCount: state.newAlertCount + 1,
    );

    // Only DANGER interrupts the beekeeper, matching the backend's push rule.
    if (alert.severity != AlertSeverity.danger) return;
    await ref.read(localNotificationServiceProvider).showAlert(alert);
  }

  /// Records how far we have read, so a restart does not re-notify.
  Future<void> _advanceWatermark(List<AlertSummary> alerts) async {
    DateTime newest = alerts.first.timestamp;
    for (final AlertSummary alert in alerts) {
      if (alert.timestamp.isAfter(newest)) newest = alert.timestamp;
    }
    _watermark = newest;
    await ref.read(modeStorageProvider).writeLastAlertSeenAt(newest);
  }

  /// Marks an alert as already surfaced — called when FCM delivered it, so the
  /// next poll does not notify a second time.
  void markNotified(String alertId) => _notifiedIds.add(alertId);
}
