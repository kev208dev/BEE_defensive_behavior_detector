/// Compile-time application configuration.
///
/// Everything here comes from `--dart-define`, so a build can be pointed at a
/// different backend or retuned for a demo without touching code:
///
/// ```sh
/// flutter run \
///   --dart-define=API_BASE_URL=http://192.168.0.10:8000 \
///   --dart-define=ANALYSIS_INTERVAL_MS=1000 \
///   --dart-define=AUDIO_CHUNK_SECONDS=3
/// ```
abstract final class AppConfig {
  /// Base URL of the FastAPI backend.
  ///
  /// Release builds use Railway automatically. Developers can still override
  /// this at build time for a local backend.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue:
        'https://beedefensivebehaviordetector-production.up.railway.app',
  );

  /// Milliseconds between sampled frames from the continuous camera stream.
  static const int analysisIntervalMs = int.fromEnvironment(
    'ANALYSIS_INTERVAL_MS',
    defaultValue: 1000,
  );

  /// On-device detector adapter. `mock` needs no bundled model.
  static const String modelMode = String.fromEnvironment(
    'MODEL_MODE',
    defaultValue: 'mock',
  );

  static const String tfliteModelAsset = String.fromEnvironment(
    'TFLITE_MODEL_ASSET',
    defaultValue: 'assets/models/hornet.tflite',
  );

  static const String modelVersion = String.fromEnvironment(
    'MODEL_VERSION',
    defaultValue: 'hornet-tflite-v1',
  );

  /// True when this build carries no real model.
  ///
  /// The mock detector reports zero hornets on every frame without looking at
  /// the image: it exercises the pipeline, it does not detect anything. The
  /// screens say so rather than showing a bare "mock-v1", because a reading of
  /// "0 hornets" is otherwise indistinguishable from a working model watching a
  /// quiet hive. [createOnDeviceHornetDetector] branches on this same getter so
  /// what is displayed cannot drift from what is running.
  static bool get usesMockDetector => modelMode.toLowerCase() != 'tflite';

  /// Length of each recorded audio chunk, in seconds.
  static const int audioChunkSeconds = int.fromEnvironment(
    'AUDIO_CHUNK_SECONDS',
    defaultValue: 3,
  );

  /// Seconds between heartbeats from a monitoring phone.
  static const int heartbeatIntervalSeconds = int.fromEnvironment(
    'HEARTBEAT_INTERVAL_SECONDS',
    defaultValue: 10,
  );

  /// Seconds between alert polls on a manager phone.
  ///
  /// This is the fallback that keeps the demo working when Firebase is not
  /// configured: the app asks the backend for new alerts and raises a local
  /// notification itself.
  static const int alertPollIntervalSeconds = int.fromEnvironment(
    'ALERT_POLL_INTERVAL_SECONDS',
    defaultValue: 10,
  );

  /// Serve every screen from in-memory fixtures instead of the backend.
  ///
  /// Lets the designer and reviewers walk the whole app with no server
  /// running. Real backend integration remains the default.
  static const bool demoMode = bool.fromEnvironment(
    'DEMO_MODE',
    defaultValue: false,
  );

  /// Attempt Firebase initialisation at startup.
  ///
  /// Turning this off skips FCM entirely and relies on the polling fallback.
  /// Firebase failing to initialise is handled gracefully either way.
  static const bool enableFirebase = bool.fromEnvironment(
    'ENABLE_FIREBASE',
    defaultValue: true,
  );

  static const Duration analysisInterval = Duration(
    milliseconds: analysisIntervalMs,
  );
  static const Duration audioChunkDuration = Duration(
    seconds: audioChunkSeconds,
  );
  static const Duration heartbeatInterval = Duration(
    seconds: heartbeatIntervalSeconds,
  );
  static const Duration alertPollInterval = Duration(
    seconds: alertPollIntervalSeconds,
  );

  /// Control-plane requests must fail quickly so a dashboard can show retry.
  static const Duration connectTimeout = Duration(seconds: 3);
  static const Duration receiveTimeout = Duration(seconds: 5);
  static const Duration sendTimeout = Duration(seconds: 5);

  /// Media uploads get a larger budget for rural LTE connections.
  static const Duration mediaConnectTimeout = Duration(seconds: 8);
  static const Duration mediaReceiveTimeout = Duration(seconds: 12);
  static const Duration mediaSendTimeout = Duration(seconds: 12);
}
