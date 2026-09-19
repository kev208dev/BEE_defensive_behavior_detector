import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/models/monitor_responses.dart';
import '../../../core/models/requests.dart';
import '../../../core/providers.dart';
import 'audio_service.dart';
import 'camera_service.dart';
import 'detector_factory.dart';
import 'image_analysis_loop.dart';
import 'monitoring_state.dart';
import 'observation_upload_queue.dart';
import 'on_device_hornet_detector.dart';
import 'permission_service.dart';

final Provider<PermissionService> permissionServiceProvider =
    Provider<PermissionService>((Ref ref) => const PermissionService());

final Provider<CameraService Function()> cameraServiceFactoryProvider =
    Provider<CameraService Function()>((Ref ref) => CameraService.new);

final Provider<Future<OnDeviceHornetDetector> Function()>
onDeviceDetectorFactoryProvider =
    Provider<Future<OnDeviceHornetDetector> Function()>(
      (Ref ref) => createOnDeviceHornetDetector,
    );

/// Drives the monitoring phone.
///
/// Assembles four independent services — camera, audio, upload queue and
/// heartbeat — and is the **sole owner of their lifetimes**. No widget holds a
/// camera controller, a recorder, a timer or a subscription; they all live
/// here and are torn down in [_teardown], which both [stopMonitoring] and
/// provider disposal go through. That is what keeps the app from leaking the
/// camera when the user leaves the screen mid-session.
final NotifierProvider<MonitoringController, MonitoringState>
monitoringControllerProvider =
    NotifierProvider<MonitoringController, MonitoringState>(
      MonitoringController.new,
    );

class MonitoringController extends Notifier<MonitoringState> {
  CameraService? _camera;
  AudioService? _audio;
  ObservationUploadQueue<FrameAnalysis>? _observationQueue;
  ImageAnalysisLoop? _analysisLoop;

  Timer? _heartbeatTimer;
  StreamSubscription<UploadOutcome<FrameAnalysis>>? _observationOutcomes;
  StreamSubscription<Uint8List>? _audioChunks;

  /// Guards against an audio upload starting before the previous finished.
  bool _audioUploadInFlight = false;

  @override
  MonitoringState build() {
    // Riverpod tears the notifier down when the last listener goes away; the
    // hardware must go with it.
    ref.onDispose(() {
      unawaited(_teardown());
    });
    return const MonitoringState();
  }

  // ------------------------------------------------------------------
  // Setup
  // ------------------------------------------------------------------

  /// Chooses which hive this phone watches.
  void selectHive({required String hiveId, required String hiveName}) {
    state = state.copyWith(hiveId: hiveId, hiveName: hiveName);
  }

  /// Reads the current permission states without prompting.
  Future<void> refreshPermissions() async {
    final PermissionService permissions = ref.read(permissionServiceProvider);
    final PermissionState camera = await permissions.cameraStatus();
    final PermissionState microphone = await permissions.microphoneStatus();
    state = state.copyWith(
      cameraPermission: camera,
      microphonePermission: microphone,
    );
  }

  /// Prompts for camera and microphone access.
  ///
  /// A refusal is recorded in the state and shown on the setup screen. It is
  /// never thrown, and monitoring can still start without the microphone.
  Future<void> requestPermissions() async {
    final PermissionService permissions = ref.read(permissionServiceProvider);
    final PermissionState camera = await permissions.requestCamera();
    final PermissionState microphone = await permissions.requestMicrophone();
    state = state.copyWith(
      cameraPermission: camera,
      microphonePermission: microphone,
    );
  }

  Future<bool> openAppSettings() =>
      ref.read(permissionServiceProvider).openSettings();

  /// Checks that the backend is reachable, for the setup screen's badge.
  Future<bool> checkConnection() =>
      ref.read(connectionProvider.notifier).check();

  // ------------------------------------------------------------------
  // Monitoring lifecycle
  // ------------------------------------------------------------------

  /// Starts capture, upload and heartbeats.
  ///
  /// Returns `true` if monitoring is now running.
  Future<bool> startMonitoring() async {
    if (state.monitoring || state.starting) return state.monitoring;

    final String? hiveId = state.hiveId;
    if (hiveId == null) {
      state = state.copyWith(errorMessage: '먼저 모니터링할 벌통을 선택해주세요.');
      return false;
    }

    state = state.copyWith(starting: true, clearError: true);

    // The camera is mandatory; without it there is nothing to monitor.
    if (!state.cameraPermission.isGranted) {
      await requestPermissions();
      if (!state.cameraPermission.isGranted) {
        state = state.copyWith(
          starting: false,
          errorMessage: '카메라 권한이 필요합니다. 설정에서 권한을 허용해주세요.',
        );
        return false;
      }
    }

    final CameraService camera = ref.read(cameraServiceFactoryProvider)();
    final String? cameraError = await camera.initialise();
    if (cameraError != null) {
      await camera.dispose();
      state = state.copyWith(starting: false, errorMessage: cameraError);
      return false;
    }
    _camera = camera;

    final OnDeviceHornetDetector detector;
    try {
      detector = await ref.read(onDeviceDetectorFactoryProvider)();
    } on Object catch (error) {
      debugPrint('MonitoringController: detector failed to load — $error');
      await camera.dispose();
      _camera = null;
      state = state.copyWith(
        starting: false,
        errorMessage: '온디바이스 탐지 모델을 시작할 수 없습니다.',
      );
      return false;
    }

    _startObservationQueue(hiveId);
    final ImageAnalysisLoop analysisLoop = ImageAnalysisLoop(
      detector: detector,
      interval: AppConfig.analysisInterval,
      onDetection: _onDeviceDetection,
      onBusyChanged: (bool busy) {
        if (state.monitoring) {
          state = state.copyWith(inferenceInProgress: busy);
        }
      },
    );
    _analysisLoop = analysisLoop;

    state = state.copyWith(
      monitoring: true,
      starting: false,
      cameraReady: true,
      cameraController: camera.controller,
      clearError: true,
    );
    final String? streamError = await camera.startImageStream((
      CameraImage image,
    ) {
      final int before = analysisLoop.droppedWhileBusy;
      analysisLoop.add(image);
      if (analysisLoop.droppedWhileBusy != before) {
        _refreshDroppedCount();
      }
    });
    if (streamError != null) {
      await _teardown();
      state = state.copyWith(
        monitoring: false,
        cameraReady: false,
        clearCameraController: true,
        errorMessage: streamError,
      );
      return false;
    }

    _startHeartbeat(hiveId);
    // The microphone is optional — monitoring proceeds without it.
    final bool audioReady = await _startAudio(hiveId);

    state = state.copyWith(audioReady: audioReady, clearError: true);

    // Send one heartbeat straight away so the hive leaves OFFLINE promptly
    // rather than after a full interval.
    unawaited(_sendHeartbeat(hiveId));
    return true;
  }

  /// Stops everything and releases the hardware.
  Future<void> stopMonitoring() async {
    await _teardown();
    state = state.copyWith(
      monitoring: false,
      starting: false,
      cameraReady: false,
      audioReady: false,
      inferenceInProgress: false,
      clearCameraController: true,
    );
  }

  // ------------------------------------------------------------------
  // Vision observations
  // ------------------------------------------------------------------

  void _startObservationQueue(String hiveId) {
    final ApiClient api = ref.read(apiClientProvider);
    final String deviceId = ref.read(deviceIdProvider);

    final ObservationUploadQueue<FrameAnalysis> queue =
        ObservationUploadQueue<FrameAnalysis>(
          upload: (PendingObservation observation) => api.uploadObservation(
            ObservationRequest(
              hiveId: hiveId,
              deviceId: deviceId,
              timestamp: observation.observedAt,
              hornetCount: observation.result.hornetCount,
              maxConfidence: observation.result.maxConfidence,
              detections: observation.result.detections
                  .map(
                    (OnDeviceDetection item) => ObservationDetectionRequest(
                      confidence: item.confidence,
                      x: item.x,
                      y: item.y,
                      width: item.width,
                      height: item.height,
                      className: item.className,
                    ),
                  )
                  .toList(growable: false),
              inferenceMs: observation.result.inferenceMs,
              modelVersion: observation.result.modelVersion,
            ),
          ),
        );

    _observationOutcomes = queue.outcomes.listen(_onObservationOutcome);
    _observationQueue = queue;
  }

  void _onDeviceDetection(OnDeviceDetectionResult result, DateTime observedAt) {
    if (!state.monitoring) return;
    state = state.copyWith(
      hornetCount: result.hornetCount,
      confidence: result.maxConfidence,
      inferenceMs: result.inferenceMs,
      modelVersion: result.modelVersion,
      lastDetectionAt: observedAt,
    );
    _observationQueue?.submit(result, observedAt: observedAt);
    _refreshDroppedCount();
  }

  void _refreshDroppedCount() {
    final int dropped =
        (_analysisLoop?.droppedWhileBusy ?? 0) +
        (_observationQueue?.droppedCount ?? 0);
    if (dropped != state.observationsDropped) {
      state = state.copyWith(observationsDropped: dropped);
    }
  }

  void _onObservationOutcome(UploadOutcome<FrameAnalysis> outcome) {
    // An upload can land while the notifier is being torn down; the result is
    // of no use to anyone by then.
    if (!ref.mounted) return;
    if (outcome.succeeded && outcome.value != null) {
      final FrameAnalysis analysis = outcome.value!;
      ref.read(connectionProvider.notifier).report(success: true);
      state = state.copyWith(
        status: analysis.status,
        riskScore: analysis.riskScore,
        hornetCount: analysis.hornetCount,
        maxHornetCount: analysis.maxHornetCount,
        confidence: analysis.confidence,
        audioProbability: analysis.audioProbability,
        lastUploadAt: DateTime.now(),
        observationsUploaded:
            _observationQueue?.uploadedCount ?? state.observationsUploaded,
        lastAlertId: analysis.alertId,
        clearUploadFailure: true,
      );
      return;
    }

    final Failure failure = ErrorMapper.map(outcome.failure ?? Exception());
    ref
        .read(connectionProvider.notifier)
        .report(success: !failure.isConnectivityProblem);
    // Monitoring keeps running — a failed observation is not a failed session.
    state = state.copyWith(uploadFailure: failure);
  }

  // ------------------------------------------------------------------
  // Audio
  // ------------------------------------------------------------------

  Future<bool> _startAudio(String hiveId) async {
    if (!state.microphonePermission.isGranted) {
      debugPrint('MonitoringController: microphone unavailable, vision only.');
      return false;
    }

    final AudioService audio = AudioService();
    final String? error = await audio.start(
      chunkDuration: AppConfig.audioChunkDuration,
    );
    if (error != null) {
      debugPrint('MonitoringController: audio unavailable — $error');
      await audio.dispose();
      return false;
    }

    _audioChunks = audio.chunks.listen(
      (Uint8List bytes) => unawaited(_uploadAudio(hiveId, bytes)),
    );
    _audio = audio;
    return true;
  }

  Future<void> _uploadAudio(String hiveId, Uint8List bytes) async {
    // Same backpressure rule as frames: never let uploads pile up. A chunk
    // that arrives while the previous is still going is simply skipped.
    if (!ref.mounted || _audioUploadInFlight || !state.monitoring) return;
    _audioUploadInFlight = true;

    try {
      final AudioAnalysis analysis = await ref
          .read(apiClientProvider)
          .uploadAudio(
            hiveId: hiveId,
            deviceId: ref.read(deviceIdProvider),
            audioBytes: bytes,
            timestamp: DateTime.now(),
          );
      if (!ref.mounted) return;
      state = state.copyWith(
        audioProbability: analysis.hornetProbability,
        lastAudioUploadAt: DateTime.now(),
        status: analysis.status ?? state.status,
        riskScore: analysis.riskScore ?? state.riskScore,
      );
    } on Object catch (error) {
      debugPrint('MonitoringController: audio upload failed — $error');
    } finally {
      _audioUploadInFlight = false;
    }
  }

  // ------------------------------------------------------------------
  // Heartbeat
  // ------------------------------------------------------------------

  void _startHeartbeat(String hiveId) {
    _heartbeatTimer = Timer.periodic(
      AppConfig.heartbeatInterval,
      (Timer _) => unawaited(_sendHeartbeat(hiveId)),
    );
  }

  Future<void> _sendHeartbeat(String hiveId) async {
    // The first heartbeat is fired unawaited from startMonitoring and the rest
    // come off a timer, so one can still be in flight when the user leaves the
    // screen and Riverpod disposes this notifier. Touching `ref` or `state`
    // after that throws, and it used to throw from inside the catch below —
    // where nothing was left to handle it, so it surfaced as an unhandled
    // async error rather than a failed heartbeat.
    if (!ref.mounted) return;

    // Read everything needed up front: after the await, this notifier may be
    // gone and none of it is reachable.
    final ApiClient api = ref.read(apiClientProvider);
    final HeartbeatRequest request = HeartbeatRequest(
      hiveId: hiveId,
      deviceId: ref.read(deviceIdProvider),
      timestamp: DateTime.now(),
      cameraOk: state.cameraReady || (_camera?.isReady ?? false),
      microphoneOk: _audio?.isRecording ?? false,
      monitoring: state.monitoring,
    );

    try {
      await api.sendHeartbeat(request);
      if (ref.mounted) {
        ref.read(connectionProvider.notifier).report(success: true);
      }
    } on Object catch (error) {
      debugPrint('MonitoringController: heartbeat failed — $error');
      if (ref.mounted) {
        ref.read(connectionProvider.notifier).report(success: false);
      }
    }
  }

  // ------------------------------------------------------------------
  // Teardown
  // ------------------------------------------------------------------

  /// Releases every resource this controller owns.
  ///
  /// Ordered deliberately: timers first so nothing new is produced, then the
  /// subscriptions, then the hardware. Each step is independently guarded so
  /// one failure cannot leave the camera held.
  Future<void> _teardown() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    await _audioChunks?.cancel();
    _audioChunks = null;

    final CameraService? camera = _camera;
    _camera = null;
    await camera?.dispose();

    final ImageAnalysisLoop? analysisLoop = _analysisLoop;
    _analysisLoop = null;
    await analysisLoop?.dispose();

    await _observationOutcomes?.cancel();
    _observationOutcomes = null;

    final ObservationUploadQueue<FrameAnalysis>? queue = _observationQueue;
    _observationQueue = null;
    await queue?.dispose();

    final AudioService? audio = _audio;
    _audio = null;
    await audio?.dispose();

    _audioUploadInFlight = false;
  }
}
