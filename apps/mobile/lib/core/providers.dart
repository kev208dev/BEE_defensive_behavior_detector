import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/alerts/data/alert_repository.dart';
import '../features/hives/data/hive_repository.dart';
import 'api/api_client.dart';
import 'api/dio_client.dart';
import 'config/app_config.dart';
import 'config/mode_storage.dart';

/// Application-wide providers.
///
/// This is the composition root. Swapping the real repositories for the demo
/// ones happens here and nowhere else — screens and controllers only ever see
/// the interfaces.

/// Overridden in `main()` once `SharedPreferences` has loaded.
final Provider<ModeStorage> modeStorageProvider = Provider<ModeStorage>(
  (Ref ref) => throw UnimplementedError(
    'modeStorageProvider must be overridden in main()',
  ),
);

/// Overridden in `main()` with the instance `ModeStorage` was built from.
final Provider<SharedPreferences> sharedPreferencesProvider =
    Provider<SharedPreferences>(
  (Ref ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main()',
  ),
);

/// The backend base URL currently in effect.
///
/// Starts from the compile-time default and can be overridden at runtime from
/// the Settings screen — which matters at a venue, where the laptop's IP is
/// not known until the day.
final NotifierProvider<BaseUrlNotifier, String> baseUrlProvider =
    NotifierProvider<BaseUrlNotifier, String>(BaseUrlNotifier.new);

class BaseUrlNotifier extends Notifier<String> {
  @override
  String build() {
    final ModeStorage storage = ref.read(modeStorageProvider);
    final String? override = storage.readBaseUrlOverride();
    return (override != null && override.isNotEmpty)
        ? override
        : AppConfig.apiBaseUrl;
  }

  Future<void> set(String value) async {
    final String trimmed = value.trim();
    final ModeStorage storage = ref.read(modeStorageProvider);
    if (trimmed.isEmpty || trimmed == AppConfig.apiBaseUrl) {
      await storage.clearBaseUrlOverride();
      state = AppConfig.apiBaseUrl;
      return;
    }
    await storage.writeBaseUrlOverride(trimmed);
    state = trimmed;
  }
}

final Provider<Dio> dioProvider = Provider<Dio>((Ref ref) {
  final String baseUrl = ref.watch(baseUrlProvider);
  final Dio dio = DioClient.create(baseUrl: baseUrl);
  ref.onDispose(dio.close);
  return dio;
});

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>(
  (Ref ref) => ApiClient(ref.watch(dioProvider)),
);

/// This phone's stable identifier, used in every upload and heartbeat.
final Provider<String> deviceIdProvider = Provider<String>(
  (Ref ref) => ref.watch(modeStorageProvider).readOrCreateDeviceId(),
);

// ----------------------------------------------------------------------
// Repositories — the DEMO_MODE swap point
// ----------------------------------------------------------------------

final Provider<HiveRepository> hiveRepositoryProvider =
    Provider<HiveRepository>((Ref ref) {
  if (AppConfig.demoMode) return const DemoHiveRepository();
  return ApiHiveRepository(ref.watch(apiClientProvider));
});

final Provider<AlertRepository> alertRepositoryProvider =
    Provider<AlertRepository>((Ref ref) {
  if (AppConfig.demoMode) return const DemoAlertRepository();
  return ApiAlertRepository(ref.watch(apiClientProvider));
});

/// Whether the backend is currently reachable.
///
/// Every screen that shows a connection badge watches this rather than
/// making its own health call.
final NotifierProvider<ConnectionNotifier, BackendConnectionState>
    connectionProvider =
    NotifierProvider<ConnectionNotifier, BackendConnectionState>(
  ConnectionNotifier.new,
);

/// Backend reachability as far as the UI is concerned.
enum BackendConnectionState {
  unknown,
  connected,
  disconnected;

  bool get isConnected => this == BackendConnectionState.connected;
}

class ConnectionNotifier extends Notifier<BackendConnectionState> {
  @override
  BackendConnectionState build() {
    if (AppConfig.demoMode) return BackendConnectionState.connected;
    return BackendConnectionState.unknown;
  }

  /// Actively checks `GET /health`.
  Future<bool> check() async {
    if (AppConfig.demoMode) {
      state = BackendConnectionState.connected;
      return true;
    }
    final bool reachable = await ref.read(apiClientProvider).ping();
    state = reachable ? BackendConnectionState.connected : BackendConnectionState.disconnected;
    return reachable;
  }

  /// Records the outcome of a request that already happened, so the badge
  /// stays accurate without extra health polling during monitoring.
  void report({required bool success}) {
    final BackendConnectionState next =
        success ? BackendConnectionState.connected : BackendConnectionState.disconnected;
    if (state != next) state = next;
  }
}
