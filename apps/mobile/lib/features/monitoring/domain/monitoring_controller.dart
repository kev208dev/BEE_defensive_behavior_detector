import 'dart:async';

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
import 'frame_upload_queue.dart';
import 'monitoring_state.dart';
import 'permission_service.dart';

final Provider<PermissionService> permissionServiceProvider =
    Provider<PermissionService>((Ref ref) => const PermissionService());

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
  FrameUploadQueue<FrameAnalysis>? _frameQueue;

  Timer? _captureTimer;
  Timer? _heartbeatTimer;
  StreamSubscription<UploadOutcome<FrameAnalysis>>? _frameOutcomes;
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

    final CameraService camera = CameraService();
    final String? cameraError = await camera.initialise();
    if (cameraError != null) {
      await camera.dispose();
      state = state.copyWith(starting: false, errorMessage: cameraError);
      return false;
    }
    _camera = camera;

    _startFrameQueue(hiveId);
    _startCaptureTimer();
    _startHeartbeat(hiveId);
    // The microphone is optional — monitoring proceeds without it.
    final bool audioReady = await _startAudio(hiveId);

    state = state.copyWith(
      monitoring: true,
      starting: false,
      cameraReady: true,
      audioReady: audioReady,
      cameraController: camera.controller,
      clearError: true,
    );

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
      clearCameraController: true,
    );
  }

  // ------------------------------------------------------------------
  // Frames
  // ------------------------------------------------------------------

  void _startFrameQueue(String hiveId) {
    final ApiClient api = ref.read(apiClientProvider);
    final String deviceId = ref.read(deviceIdProvider);

    final FrameUploadQueue<FrameAnalysis> queue =
        FrameUploadQueue<FrameAnalysis>(
      upload: (PendingFrame frame) => api.uploadFrame(
        hiveId: hiveId,
        deviceId: deviceId,
        jpegBytes: frame.bytes,
        timestamp: frame.capturedAt,
      ),
    );

    _frameOutcomes = queue.outcomes.listen(_onFrameOutcome);
    _frameQueue = queue;
  }

  void _startCaptureTimer() {
    _captureTimer = Timer.periodic(
      AppConfig.frameInterval,
      (Timer _) => unawaited(_captureAndSubmit()),
    );
  }

  Future<void> _captureAndSubmit() async {
    final CameraService? camera = _camera;
    final FrameUploadQueue<FrameAnalysis>? queue = _frameQueue;
    if (camera == null || queue == null || !state.monitoring) return;

    final Uint8List? bytes = await camera.captureFrame();
    if (bytes == null || bytes.isEmpty) return;

    queue.submit(bytes);
    // Surface the drop counter so the live screen can show that the network,
    // not the detector, is the bottleneck.
    if (queue.droppedCount != state.framesDropped) {
      state = state.copyWith(framesDropped: queue.droppedCount);
    }
  }

  void _onFrameOutcome(UploadOutcome<FrameAnalysis> outcome) {
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
        framesUploaded: _frameQueue?.uploadedCount ?? state.framesUploaded,
        lastAlertId: analysis.alertId,
        clearUploadFailure: true,
      );
      return;
    }

    final Failure failure = ErrorMapper.map(outcome.failure ?? Exception());
    ref
        .read(connectionProvider.notifier)
        .report(success: !failure.isConnectivityProblem);
    // Monitoring keeps running — a failed frame is not a failed session.
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
    final String? error =
        await audio.start(chunkDuration: AppConfig.audioChunkDuration);
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
    if (_audioUploadInFlight || !state.monitoring) return;
    _audioUploadInFlight = true;

    try {
      final AudioAnalysis analysis =
          await ref.read(apiClientProvider).uploadAudio(
                hiveId: hiveId,
                deviceId: ref.read(deviceIdProvider),
                audioBytes: bytes,
                timestamp: DateTime.now(),
              );
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
    try {
      await ref.read(apiClientProvider).sendHeartbeat(
            HeartbeatRequest(
              hiveId: hiveId,
              deviceId: ref.read(deviceIdProvider),
              timestamp: DateTime.now(),
              cameraOk: state.cameraReady || (_camera?.isReady ?? false),
              microphoneOk: _audio?.isRecording ?? false,
              monitoring: state.monitoring,
            ),
          );
      ref.read(connectionProvider.notifier).report(success: true);
    } on Object catch (error) {
      debugPrint('MonitoringController: heartbeat failed — $error');
      ref.read(connectionProvider.notifier).report(success: false);
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
    _captureTimer?.cancel();
    _captureTimer = null;

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    await _frameOutcomes?.cancel();
    _frameOutcomes = null;

    await _audioChunks?.cancel();
    _audioChunks = null;

    final FrameUploadQueue<FrameAnalysis>? queue = _frameQueue;
    _frameQueue = null;
    await queue?.dispose();

    final AudioService? audio = _audio;
    _audio = null;
    await audio?.dispose();

    final CameraService? camera = _camera;
    _camera = null;
    await camera?.dispose();

    _audioUploadInFlight = false;
  }
}
