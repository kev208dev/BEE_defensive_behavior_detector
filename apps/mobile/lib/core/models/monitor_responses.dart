import 'package:freezed_annotation/freezed_annotation.dart';

import '../utils/json_reader.dart';
import 'hive_status.dart';

part 'monitor_responses.freezed.dart';

/// Answer to a frame upload — what drives the Live Monitoring screen.
@freezed
abstract class FrameAnalysis with _$FrameAnalysis {
  const factory FrameAnalysis({
    required HiveStatus status,
    required DateTime processedAt,
    @Default(0) int riskScore,
    @Default(0) int hornetCount,
    @Default(0) int maxHornetCount,
    @Default(0.0) double confidence,
    @Default(0.0) double audioProbability,
    String? snapshotUrl,
    String? alertId,
  }) = _FrameAnalysis;

  const FrameAnalysis._();

  factory FrameAnalysis.fromApi(Map<String, dynamic> json) => FrameAnalysis(
        status: HiveStatus.fromWire(JsonReader.stringOrNull(json, 'status')),
        processedAt: JsonReader.dateTime(json, 'processed_at'),
        riskScore: JsonReader.integer(json, 'risk_score'),
        hornetCount: JsonReader.integer(json, 'hornet_count'),
        maxHornetCount: JsonReader.integer(json, 'max_hornet_count'),
        confidence: JsonReader.decimal(json, 'confidence'),
        audioProbability: JsonReader.decimal(json, 'audio_probability'),
        snapshotUrl: JsonReader.stringOrNull(json, 'snapshot_url'),
        alertId: JsonReader.stringOrNull(json, 'alert_id'),
      );
}

/// Answer to an audio chunk upload.
@freezed
abstract class AudioAnalysis with _$AudioAnalysis {
  const factory AudioAnalysis({
    required double hornetProbability,
    required DateTime processedAt,
    HiveStatus? status,
    int? riskScore,
  }) = _AudioAnalysis;

  const AudioAnalysis._();

  factory AudioAnalysis.fromApi(Map<String, dynamic> json) => AudioAnalysis(
        hornetProbability: JsonReader.decimal(json, 'hornet_probability'),
        processedAt: JsonReader.dateTime(json, 'processed_at'),
        status: json['status'] == null
            ? null
            : HiveStatus.fromWire(JsonReader.stringOrNull(json, 'status')),
        riskScore: json['risk_score'] == null
            ? null
            : JsonReader.integer(json, 'risk_score'),
      );
}

/// Answer to a heartbeat.
@freezed
abstract class HeartbeatAck with _$HeartbeatAck {
  const factory HeartbeatAck({
    required String hiveId,
    required HiveStatus status,
    @Default(0) int riskScore,
    @Default(true) bool acknowledged,
  }) = _HeartbeatAck;

  const HeartbeatAck._();

  factory HeartbeatAck.fromApi(Map<String, dynamic> json) => HeartbeatAck(
        hiveId: JsonReader.string(json, 'hive_id'),
        status: HiveStatus.fromWire(JsonReader.stringOrNull(json, 'status')),
        riskScore: JsonReader.integer(json, 'risk_score'),
        acknowledged: JsonReader.boolean(json, 'acknowledged', fallback: true),
      );
}
