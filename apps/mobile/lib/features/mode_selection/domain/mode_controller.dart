import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/mode_storage.dart';
import '../../../core/models/hive_status.dart';
import '../../../core/providers.dart';

/// The role this phone is currently playing, persisted locally.
///
/// `null` means the user has not chosen yet, which is what sends them to
/// `/mode` on first launch.
final NotifierProvider<AppModeNotifier, AppMode?> appModeProvider =
    NotifierProvider<AppModeNotifier, AppMode?>(AppModeNotifier.new);

class AppModeNotifier extends Notifier<AppMode?> {
  @override
  AppMode? build() => ref.read(modeStorageProvider).readMode();

  Future<void> select(AppMode mode) async {
    await ref.read(modeStorageProvider).writeMode(mode);
    state = mode;
  }

  /// Returns to the mode picker, from Settings.
  Future<void> clear() async {
    await ref.read(modeStorageProvider).clearMode();
    state = null;
  }
}

/// Which hive this monitoring phone is assigned to.
final NotifierProvider<SelectedHiveNotifier, String?> selectedHiveIdProvider =
    NotifierProvider<SelectedHiveNotifier, String?>(SelectedHiveNotifier.new);

class SelectedHiveNotifier extends Notifier<String?> {
  @override
  String? build() => ref.read(modeStorageProvider).readSelectedHiveId();

  Future<void> select(String hiveId) async {
    final ModeStorage storage = ref.read(modeStorageProvider);
    await storage.writeSelectedHiveId(hiveId);
    state = hiveId;
  }
}
