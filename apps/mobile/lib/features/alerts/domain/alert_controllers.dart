import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/models/alert.dart';
import '../../../core/providers.dart';
import '../data/alert_repository.dart';

/// The alert list, newest first.
final AsyncNotifierProvider<AlertListController, List<AlertSummary>>
    alertListControllerProvider =
    AsyncNotifierProvider<AlertListController, List<AlertSummary>>(
  AlertListController.new,
);

class AlertListController extends AsyncNotifier<List<AlertSummary>> {
  @override
  Future<List<AlertSummary>> build() => _load();

  Future<List<AlertSummary>> _load() async {
    final AlertRepository repository = ref.read(alertRepositoryProvider);
    try {
      final List<AlertSummary> alerts = await repository.fetchAlerts();
      ref.read(connectionProvider.notifier).report(success: true);
      return alerts;
    } on Object catch (error, stackTrace) {
      final Failure failure = ErrorMapper.map(error, stackTrace);
      ref
          .read(connectionProvider.notifier)
          .report(success: !failure.isConnectivityProblem);
      throw failure;
    }
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_load);
  }
}

/// One alert's full detail, keyed by id.
///
/// A [FutureProvider.family] rather than a notifier: the screen only loads and
/// retries, and `ref.invalidate` already gives it a refresh. A notifier would
/// add a class without adding behaviour.
final alertDetailProvider =
    FutureProvider.family<AlertDetail, String>(
  (Ref ref, String alertId) async {
    try {
      return await ref.read(alertRepositoryProvider).fetchAlertDetail(alertId);
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  },
);
