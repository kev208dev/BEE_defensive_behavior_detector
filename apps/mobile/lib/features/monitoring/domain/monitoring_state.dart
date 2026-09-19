import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/models/hive_status.dart';
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
    this.framesUploaded = 0,
    this.framesDropped = 0,
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
  final int framesUploaded;
  final int framesDropped;

  /// Set when the backend reported that this frame raised an alert.
  final String? lastAlertId;

  /// A blocking problem, e.g. the camera could not start.
  final String? errorMessage;

  /// The most recent upload failure, shown non-blockingly.
  final Failure? uploadFailure;

  bool get canStart =>
      hiveId != null &&
      cameraPermission.isGranted &&
      !monitoring &&
      !starting;

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
    int? framesUploaded,
    int? framesDropped,
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
      framesUploaded: framesUploaded ?? this.framesUploaded,
      framesDropped: framesDropped ?? this.framesDropped,
      lastAlertId: lastAlertId ?? this.lastAlertId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      uploadFailure: clearUploadFailure
          ? null
          : (uploadFailure ?? this.uploadFailure),
    );
  }
}
