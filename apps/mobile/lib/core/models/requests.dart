import 'package:json_annotation/json_annotation.dart';

part 'requests.g.dart';

/// Outbound JSON request bodies.
///
/// These are generated with `json_serializable` because the field names must
/// match the backend's snake_case contract exactly, and a typo in a
/// hand-written map would only surface at runtime.

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
  final DateTime timestamp;
  final bool cameraOk;
  final bool microphoneOk;
  final bool monitoring;

  Map<String, dynamic> toJson() => _$HeartbeatRequestToJson(this);
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
