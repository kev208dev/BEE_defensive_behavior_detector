import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/errors/failure.dart';
import '../../../core/models/hive_status.dart';
import 'detection_tracker.dart';
import 'on_device_hornet_detector.dart';
import 'permission_service.dart';

/// Everything the monitoring screens display.
///
/// A plain immutable class rather than a freezed model: it holds a live
/// [CameraController] reference, which is neither serialisable nor value-
/// comparable, so code generation would buy nothing here.
@immutable
class MonitoringState {
  const MonitoringState({
    this.hiveId,
    this.hiveName = '',
    this.monitoring = false,
    this.starting = false,
    this.cameraPermission = PermissionState.unknown,
    this.microphonePermission = PermissionState.unknown,
    this.cameraController,
    this.cameraReady = false,
    this.audioReady = false,
    this.status = HiveStatus.normal,
    this.riskScore = 0,
    this.hornetCount = 0,
    this.maxHornetCount = 0,
    this.confidence = 0,
    this.audioProbability = 0,
    this.lastUploadAt,
    this.lastAudioUploadAt,
    this.observationsUploaded = 0,
    this.observationsDropped = 0,
    this.inferenceMs = 0,
    this.modelVersion = '',
    this.trackedDetections = const <TrackedDetection>[],
    this.previewImageSize,
    this.rawDetections = const <OnDeviceDetection>[],
    this.uploadDetectionCount = 0,
    this.detectionOrientation,
    this.inferenceInProgress = false,
    this.lastDetectionAt,
    this.lastAlertId,
    this.errorMessage,
    this.uploadFailure,
  });

  final String? hiveId;
  final String hiveName;

  /// Whether the capture loop is running.
  final bool monitoring;

  /// Whether start-up (permissions, camera init) is in progress.
  final bool starting;

  final PermissionState cameraPermission;
  final PermissionState microphonePermission;

  /// Live controller for the preview. Owned by `CameraService`, never by a
  /// widget — the widget only renders it.
  final CameraController? cameraController;
  final bool cameraReady;
  final bool audioReady;

  // --- Latest analysis from the backend ---
  final HiveStatus status;
  final int riskScore;
  final int hornetCount;
  final int maxHornetCount;
  final double confidence;
  final double audioProbability;

  final DateTime? lastUploadAt;
  final DateTime? lastAudioUploadAt;
  final int observationsUploaded;
  final int observationsDropped;
  final int inferenceMs;
  final String modelVersion;

  /// Smoothed detections for the preview overlay.
  ///
  /// These are display values: they use the lower display threshold and keep a
  /// briefly-missed hornet on screen. What the backend is told is computed
  /// separately, at the stricter upload threshold.
  final List<TrackedDetection> trackedDetections;

  /// Camera image size the detections were produced from, for overlay mapping.
  final Size? previewImageSize;
  final List<OnDeviceDetection> rawDetections;
  final int uploadDetectionCount;
  final DeviceOrientation? detectionOrientation;
  final bool inferenceInProgress;
  final DateTime? lastDetectionAt;

  /// Set when the backend reported that this frame raised an alert.
  final String? lastAlertId;

  /// A blocking problem, e.g. the camera could not start.
  final String? errorMessage;

  /// The most recent upload failure, shown non-blockingly.
  final Failure? uploadFailure;

  bool get canStart =>
      hiveId != null && cameraPermission.isGranted && !monitoring && !starting;

  bool get hasEverUploaded => lastUploadAt != null;

  MonitoringState copyWith({
    String? hiveId,
    String? hiveName,
    bool? monitoring,
    bool? starting,
    PermissionState? cameraPermission,
    PermissionState? microphonePermission,
    CameraController? cameraController,
    bool? cameraReady,
    bool? audioReady,
    HiveStatus? status,
    int? riskScore,
    int? hornetCount,
    int? maxHornetCount,
    double? confidence,
    double? audioProbability,
    DateTime? lastUploadAt,
    DateTime? lastAudioUploadAt,
    int? observationsUploaded,
    int? observationsDropped,
    int? inferenceMs,
    String? modelVersion,
    List<TrackedDetection>? trackedDetections,
    Size? previewImageSize,
    List<OnDeviceDetection>? rawDetections,
    int? uploadDetectionCount,
    DeviceOrientation? detectionOrientation,
    bool? inferenceInProgress,
    DateTime? lastDetectionAt,
    String? lastAlertId,
    String? errorMessage,
    Failure? uploadFailure,
    bool clearError = false,
    bool clearUploadFailure = false,
    bool clearCameraController = false,
  }) {
    return MonitoringState(
      hiveId: hiveId ?? this.hiveId,
      hiveName: hiveName ?? this.hiveName,
      monitoring: monitoring ?? this.monitoring,
      starting: starting ?? this.starting,
      cameraPermission: cameraPermission ?? this.cameraPermission,
      microphonePermission: microphonePermission ?? this.microphonePermission,
      cameraController: clearCameraController
          ? null
          : (cameraController ?? this.cameraController),
      cameraReady: cameraReady ?? this.cameraReady,
      audioReady: audioReady ?? this.audioReady,
      status: status ?? this.status,
      riskScore: riskScore ?? this.riskScore,
      hornetCount: hornetCount ?? this.hornetCount,
      maxHornetCount: maxHornetCount ?? this.maxHornetCount,
      confidence: confidence ?? this.confidence,
      audioProbability: audioProbability ?? this.audioProbability,
      lastUploadAt: lastUploadAt ?? this.lastUploadAt,
      lastAudioUploadAt: lastAudioUploadAt ?? this.lastAudioUploadAt,
      observationsUploaded: observationsUploaded ?? this.observationsUploaded,
      observationsDropped: observationsDropped ?? this.observationsDropped,
      inferenceMs: inferenceMs ?? this.inferenceMs,
      modelVersion: modelVersion ?? this.modelVersion,
      trackedDetections: trackedDetections ?? this.trackedDetections,
      previewImageSize: previewImageSize ?? this.previewImageSize,
      rawDetections: rawDetections ?? this.rawDetections,
      uploadDetectionCount: uploadDetectionCount ?? this.uploadDetectionCount,
      detectionOrientation: detectionOrientation ?? this.detectionOrientation,
      inferenceInProgress: inferenceInProgress ?? this.inferenceInProgress,
      lastDetectionAt: lastDetectionAt ?? this.lastDetectionAt,
      lastAlertId: lastAlertId ?? this.lastAlertId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      uploadFailure: clearUploadFailure
          ? null
          : (uploadFailure ?? this.uploadFailure),
    );
  }
}
