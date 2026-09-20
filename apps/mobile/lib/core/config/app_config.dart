import 'dart:math' as math;

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

  /// On-device detector adapter. The bundled VespAI model is the default.
  static const String modelMode = String.fromEnvironment(
    'MODEL_MODE',
    defaultValue: 'tflite',
  );

  static const String tfliteModelAsset = String.fromEnvironment(
    'TFLITE_MODEL_ASSET',
    defaultValue: 'assets/models/hornet.tflite',
  );

  static const String modelVersion = String.fromEnvironment(
    'MODEL_VERSION',
    defaultValue: 'vespai-yolov5s-all-but-22ip',
  );

  /// Confidence a detection needs before it is drawn on the preview.
  ///
  /// Lower than [detectionUploadConfidenceThreshold] on purpose. The overlay
  /// is a live view for a person standing at the hive, so showing a hornet the
  /// model is fairly sure about is useful even when the backend should not yet
  /// count it. Being wrong here costs a box that disappears; being wrong on
  /// the upload threshold moves the risk score.
  ///
  /// `--dart-define=DETECTION_DISPLAY_CONFIDENCE_THRESHOLD=0.7`.
  static double get detectionDisplayConfidenceThreshold =>
      _parseUnitInterval(_displayThresholdRaw, 0.65);

  static const String _displayThresholdRaw = String.fromEnvironment(
    'DETECTION_DISPLAY_CONFIDENCE_THRESHOLD',
  );

  /// Confidence a detection needs before it is reported to the risk engine.
  ///
  /// Stays at VespAI's own 0.8. Once the frame is cropped to the hive entrance
  /// true detections come back at ~0.96, well clear of this, so lowering it
  /// buys recall the ROI already provides while adding bee false positives
  /// whose cost is unmeasured. See `tools/model_conversion/README.md`.
  ///
  /// `--dart-define=DETECTION_CONFIDENCE_THRESHOLD=0.75`. The old name is kept
  /// so existing build scripts keep working.
  static double get detectionUploadConfidenceThreshold =>
      _parseUnitInterval(_confidenceThresholdRaw, 0.8);

  static const String _confidenceThresholdRaw = String.fromEnvironment(
    'DETECTION_CONFIDENCE_THRESHOLD',
  );

  /// The threshold the model decodes at — the lower of the two.
  ///
  /// Decoding at the display threshold and filtering afterwards is what makes
  /// two thresholds possible at all: anything discarded inside the decoder is
  /// gone, so it has to keep everything either consumer might want.
  static double get detectionDecodeConfidenceThreshold => math.min(
    detectionDisplayConfidenceThreshold,
    detectionUploadConfidenceThreshold,
  );

  /// Frames a detection keeps being displayed after the model stops seeing it.
  static int get detectionMaxMisses => const int.fromEnvironment(
    'DETECTION_MAX_MISSES',
    defaultValue: 2,
  );

  /// Overlap at which a new box is treated as an existing tracked hornet.
  static double get detectionTrackIouThreshold =>
      _parseUnitInterval(_trackIouRaw, 0.3);

  static const String _trackIouRaw = String.fromEnvironment(
    'DETECTION_TRACK_IOU_THRESHOLD',
  );

  /// IoU above which two same-class boxes are treated as one hornet.
  static double get detectionNmsIouThreshold =>
      _parseUnitInterval(_nmsIouThresholdRaw, 0.45);

  static const String _nmsIouThresholdRaw = String.fromEnvironment(
    'DETECTION_NMS_IOU_THRESHOLD',
  );

  /// Parses a 0..1 override, falling back when it is absent or nonsense.
  ///
  /// A typo in a `--dart-define` must not silently disable detection by
  /// leaving the threshold at 0 (everything is a hornet) or 1 (nothing is).
  static double _parseUnitInterval(String raw, double fallback) {
    if (raw.isEmpty) return fallback;
    final double? parsed = double.tryParse(raw);
    if (parsed == null || !parsed.isFinite || parsed <= 0 || parsed > 1) {
      return fallback;
    }
    return parsed;
  }

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
