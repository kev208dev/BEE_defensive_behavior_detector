import 'package:freezed_annotation/freezed_annotation.dart';

import '../utils/json_reader.dart';
import 'hive_status.dart';

part 'alert.freezed.dart';

/// One row of the alert list.
@freezed
abstract class AlertSummary with _$AlertSummary {
  const factory AlertSummary({
    required String id,
    required String hiveId,
    required String hiveName,
    required DateTime timestamp,
    required AlertSeverity severity,
    @Default(0) int riskScore,
    @Default(0) int hornetCount,
    @Default('') String message,
  }) = _AlertSummary;

  const AlertSummary._();

  factory AlertSummary.fromApi(Map<String, dynamic> json) => AlertSummary(
        id: JsonReader.string(json, 'id'),
        hiveId: JsonReader.string(json, 'hive_id'),
        hiveName: JsonReader.string(json, 'hive_name', fallback: '벌통'),
        timestamp: JsonReader.dateTime(json, 'timestamp'),
        severity:
            AlertSeverity.fromWire(JsonReader.stringOrNull(json, 'severity')),
        riskScore: JsonReader.integer(json, 'risk_score'),
        hornetCount: JsonReader.integer(json, 'hornet_count'),
        message: JsonReader.string(json, 'message'),
      );
}

/// Everything the Alert Detail screen shows, including why the system decided.
@freezed
abstract class AlertDetail with _$AlertDetail {
  const factory AlertDetail({
    required AlertSummary summary,
    @Default(0) int maxHornetCount,
    @Default(0.0) double audioProbability,
    @Default(0.0) double persistenceRatio,
    @Default(0.0) double growthPerSecond,
    @Default('') String explanation,
    String? thumbnailUrl,
    String? clipUrl,
    DateTime? resolvedAt,
  }) = _AlertDetail;

  const AlertDetail._();

  factory AlertDetail.fromApi(Map<String, dynamic> json) => AlertDetail(
        summary: AlertSummary.fromApi(json),
        maxHornetCount: JsonReader.integer(json, 'max_hornet_count'),
        audioProbability: JsonReader.decimal(json, 'audio_probability'),
        persistenceRatio: JsonReader.decimal(json, 'persistence_ratio'),
        growthPerSecond: JsonReader.decimal(json, 'growth_per_second'),
        explanation: JsonReader.string(json, 'explanation'),
        thumbnailUrl: JsonReader.stringOrNull(json, 'thumbnail_url'),
        clipUrl: JsonReader.stringOrNull(json, 'clip_url'),
        resolvedAt: JsonReader.dateTimeOrNull(json, 'resolved_at'),
      );

  String get id => summary.id;
  String get hiveName => summary.hiveName;
  AlertSeverity get severity => summary.severity;
  int get riskScore => summary.riskScore;
  int get hornetCount => summary.hornetCount;
  DateTime get timestamp => summary.timestamp;
  String get message => summary.message;
}
