import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/models/hive.dart';
import '../../../core/providers.dart';

/// All hives, for the hive list and the monitoring setup picker.
final AsyncNotifierProvider<HiveListController, List<Hive>>
    hiveListControllerProvider =
    AsyncNotifierProvider<HiveListController, List<Hive>>(
  HiveListController.new,
);

class HiveListController extends AsyncNotifier<List<Hive>> {
  @override
  Future<List<Hive>> build() => _load();

  Future<List<Hive>> _load() async {
    try {
      final List<Hive> hives =
          await ref.read(hiveRepositoryProvider).fetchHives();
      ref.read(connectionProvider.notifier).report(success: true);
      return hives;
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

/// One hive's full detail, keyed by id.
///
/// See the note on `alertDetailProvider`: load-and-retry needs no notifier.
final hiveDetailProvider =
    FutureProvider.family<HiveDetail, String>(
  (Ref ref, String hiveId) async {
    try {
      return await ref.read(hiveRepositoryProvider).fetchHiveDetail(hiveId);
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  },
);
