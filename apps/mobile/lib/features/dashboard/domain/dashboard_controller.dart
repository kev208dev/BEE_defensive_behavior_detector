import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/models/hive.dart';
import '../../../core/providers.dart';
import '../../hives/data/hive_repository.dart';

/// Loads the manager dashboard.
///
/// An [AsyncNotifier] so the screen gets loading / data / error for free and
/// pull-to-refresh is a single call to [refresh].
final AsyncNotifierProvider<DashboardController, DashboardSummary>
    dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardSummary>(
  DashboardController.new,
);

class DashboardController extends AsyncNotifier<DashboardSummary> {
  @override
  Future<DashboardSummary> build() => _load();

  Future<DashboardSummary> _load() async {
    final HiveRepository repository = ref.read(hiveRepositoryProvider);
    try {
      final DashboardSummary summary = await repository.fetchDashboard();
      ref.read(connectionProvider.notifier).report(success: true);
      return summary;
    } on Object catch (error, stackTrace) {
      final Failure failure = ErrorMapper.map(error, stackTrace);
      ref
          .read(connectionProvider.notifier)
          .report(success: !failure.isConnectivityProblem);
      throw failure;
    }
  }

  /// Pull-to-refresh. Keeps the previous data on screen while reloading, so
  /// the dashboard does not flash empty.
  Future<void> refresh() async {
    state = await AsyncValue.guard(_load);
  }
}
