import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/models/alert.dart';
import '../../../core/models/hive_status.dart';
import '../../../core/providers.dart';
import 'alert_controllers.dart';
import 'alert_watcher.dart';
import 'notification_service.dart';
import 'push_service.dart';

final Provider<PushService> pushServiceProvider = Provider<PushService>((
  Ref ref,
) {
  final PushService service = PushService(ref.watch(apiClientProvider));
  ref.onDispose(service.dispose);
  return service;
});

/// Wires notification delivery to navigation.
///
/// Both delivery paths — FCM and the polling fallback — end here, and both
/// route to `/alerts/:id`. Keeping the wiring in one place is what makes the
/// two paths behave identically from the user's point of view.
///
/// Every step is individually guarded: a manager phone with no Firebase
/// project still gets alerts through polling, and a phone that cannot show
/// notifications at all still shows them in the app.
class PushBootstrap {
  PushBootstrap(this._ref);

  final Ref _ref;

  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];

  /// Called once, after the first frame, on a manager phone.
  Future<void> start() async {
    final LocalNotificationService notifications =
        _ref.read(localNotificationServiceProvider);
    await notifications.initialise();

    // A local notification that launched the app from terminated.
    final String? launchAlertId = await notifications.launchAlertId();
    if (launchAlertId != null) _openAlert(launchAlertId);

    _subscriptions.add(notifications.onTapped.listen(_openAlert));

    final PushService push = _ref.read(pushServiceProvider);
    final bool available = await push.initialise();

    if (available) {
      await push.registerToken(platform: defaultTargetPlatform.name);
      _subscriptions.add(push.onOpened.listen(_openAlert));
      _subscriptions.add(
        push.onForegroundMessage.listen(_handleForegroundPush),
      );
    } else {
      debugPrint(
        'PushBootstrap: FCM unavailable — relying on alert polling. '
        'This is a supported configuration.',
      );
    }

    // The watcher runs regardless. When FCM is available it is a safety net
    // for missed pushes; when it is not, it is the delivery mechanism.
    _ref.read(alertWatcherProvider.notifier).start();
  }

  /// A push that arrived while the app was open.
  ///
  /// Android does not show a notification for a foreground data message, so
  /// we raise a local one ourselves and tell the watcher not to duplicate it.
  Future<void> _handleForegroundPush(Map<String, dynamic> data) async {
    final String? alertId = alertIdFromPush(data);
    if (alertId == null) return;

    _ref.read(alertWatcherProvider.notifier).markNotified(alertId);
    unawaited(_ref.read(alertListControllerProvider.notifier).refresh());

    final Object? severity = data['severity'];
    if (severity is! String || severity.toUpperCase() != 'DANGER') return;

    final Object? hiveId = data['hiveId'];
    await _ref.read(localNotificationServiceProvider).showAlert(
          AlertSummary(
            id: alertId,
            hiveId: hiveId is String ? hiveId : '',
            hiveName: '벌통',
            timestamp: DateTime.now(),
            severity: AlertSeverity.danger,
            message: '말벌 집단 공격 징후가 감지되었습니다.',
          ),
        );
  }

  void _openAlert(String alertId) {
    if (alertId.isEmpty) return;
    // Navigating through the router key works even with no BuildContext,
    // which is the case when a notification resumes a backgrounded app.
    final BuildContext? context = rootNavigatorKey.currentContext;
    if (context == null) {
      debugPrint('PushBootstrap: navigator not ready, ignoring deep link.');
      return;
    }
    context.push(Routes.alert(alertId));
  }

  Future<void> dispose() async {
    for (final StreamSubscription<Object?> subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }
}

final Provider<PushBootstrap> pushBootstrapProvider = Provider<PushBootstrap>((
  Ref ref,
) {
  final PushBootstrap bootstrap = PushBootstrap(ref);
  ref.onDispose(() => unawaited(bootstrap.dispose()));
  return bootstrap;
});
