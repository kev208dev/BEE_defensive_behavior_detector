// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'requests.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$HeartbeatRequestToJson(HeartbeatRequest instance) =>
    <String, dynamic>{
      'hive_id': instance.hiveId,
      'device_id': instance.deviceId,
      'timestamp': instance.timestamp.toIso8601String(),
      'camera_ok': instance.cameraOk,
      'microphone_ok': instance.microphoneOk,
      'monitoring': instance.monitoring,
    };

Map<String, dynamic> _$ObservationDetectionRequestToJson(
  ObservationDetectionRequest instance,
) => <String, dynamic>{
  'confidence': instance.confidence,
  'x': instance.x,
  'y': instance.y,
  'width': instance.width,
  'height': instance.height,
  'class_name': instance.className,
};

Map<String, dynamic> _$ObservationRequestToJson(ObservationRequest instance) =>
    <String, dynamic>{
      'hive_id': instance.hiveId,
      'device_id': instance.deviceId,
      'timestamp': instance.timestamp.toIso8601String(),
      'hornet_count': instance.hornetCount,
      'max_confidence': instance.maxConfidence,
      'detections': instance.detections,
      'inference_ms': instance.inferenceMs,
      'model_version': instance.modelVersion,
    };

Map<String, dynamic> _$DeviceRegistrationRequestToJson(
  DeviceRegistrationRequest instance,
) => <String, dynamic>{
  'device_id': instance.deviceId,
  'hive_id': instance.hiveId,
  'role': instance.role,
  'platform': instance.platform,
};

Map<String, dynamic> _$PushTokenRequestToJson(PushTokenRequest instance) =>
    <String, dynamic>{
      'token': instance.token,
      'platform': instance.platform,
      'device_id': instance.deviceId,
    };
