import 'package:json_annotation/json_annotation.dart';

part 'requests.g.dart';

/// Outbound JSON request bodies.
///
/// These are generated with `json_serializable` because the field names must
/// match the backend's snake_case contract exactly, and a typo in a
/// hand-written map would only surface at runtime.

/// Serialises an instant as UTC with an explicit offset.
///
/// `DateTime.toIso8601String()` on a local `DateTime` emits no timezone marker,
/// and the backend reads an unmarked timestamp as UTC. A phone in KST would
/// therefore stamp every heartbeat and observation nine hours in the future:
/// `is_offline()` subtracts that from the server's clock, gets a negative age,
/// and the hive never goes OFFLINE no matter how long the phone is gone.
/// Converting here rather than at each call site means a new request type
/// cannot reintroduce the skew.
String _utcIso8601(DateTime value) => value.toUtc().toIso8601String();

/// Body of `POST /api/monitor/heartbeat`.
@JsonSerializable(fieldRename: FieldRename.snake, createFactory: false)
class HeartbeatRequest {
  const HeartbeatRequest({
    required this.hiveId,
    required this.deviceId,
    required this.timestamp,
    required this.cameraOk,
    required this.microphoneOk,
    required this.monitoring,
  });

  final String hiveId;
  final String deviceId;
  @JsonKey(toJson: _utcIso8601)
  final DateTime timestamp;
  final bool cameraOk;
  final bool microphoneOk;
  final bool monitoring;

  Map<String, dynamic> toJson() => _$HeartbeatRequestToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake, createFactory: false)
class ObservationDetectionRequest {
  const ObservationDetectionRequest({
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.className,
  });

  final double confidence;
  final double x;
  final double y;
  final double width;
  final double height;
  final String className;

  Map<String, dynamic> toJson() => _$ObservationDetectionRequestToJson(this);
}

/// Body of `POST /api/monitor/observation`.
@JsonSerializable(fieldRename: FieldRename.snake, createFactory: false)
class ObservationRequest {
  const ObservationRequest({
    required this.hiveId,
    required this.deviceId,
    required this.timestamp,
    required this.hornetCount,
    required this.maxConfidence,
    required this.detections,
    required this.inferenceMs,
    required this.modelVersion,
  });

  final String hiveId;
  final String deviceId;
  @JsonKey(toJson: _utcIso8601)
  final DateTime timestamp;
  final int hornetCount;
  final double maxConfidence;
  final List<ObservationDetectionRequest> detections;
  final int inferenceMs;
  final String modelVersion;

  Map<String, dynamic> toJson() => _$ObservationRequestToJson(this);
}

/// Body of `POST /api/devices`.
@JsonSerializable(fieldRename: FieldRename.snake, createFactory: false)
class DeviceRegistrationRequest {
  const DeviceRegistrationRequest({
    required this.deviceId,
    required this.role,
    required this.platform,
    this.hiveId,
  });

  final String deviceId;
  final String? hiveId;
  final String role;
  final String platform;

  Map<String, dynamic> toJson() => _$DeviceRegistrationRequestToJson(this);
}

/// Body of `POST /api/devices/push-token`.
@JsonSerializable(fieldRename: FieldRename.snake, createFactory: false)
class PushTokenRequest {
  const PushTokenRequest({
    required this.token,
    required this.platform,
    this.deviceId,
  });

  final String token;
  final String platform;
  final String? deviceId;

  Map<String, dynamic> toJson() => _$PushTokenRequestToJson(this);
}
