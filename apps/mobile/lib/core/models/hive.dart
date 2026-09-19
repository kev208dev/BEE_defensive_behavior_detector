import 'package:freezed_annotation/freezed_annotation.dart';

import '../utils/json_reader.dart';
import 'alert.dart';
import 'hive_status.dart';

part 'hive.freezed.dart';

/// A beehive as shown in the list and on the dashboard.
@freezed
abstract class Hive with _$Hive {
  const factory Hive({
    required String id,
    required String name,
    required HiveStatus status,
    required int riskScore,
    required int hornetCount,
    required DateTime lastUpdated,
    @Default('') String location,
    @Default(0) int maxHornetCount,
    @Default(0.0) double audioProbability,
    @Default(false) bool monitoringOnline,
    DateTime? lastHeartbeat,
  }) = _Hive;

  const Hive._();

  factory Hive.fromApi(Map<String, dynamic> json) => Hive(
        id: JsonReader.string(json, 'id'),
        name: JsonReader.string(json, 'name', fallback: '이름 없는 벌통'),
        location: JsonReader.string(json, 'location'),
        status: HiveStatus.fromWire(JsonReader.stringOrNull(json, 'status')),
        riskScore: JsonReader.integer(json, 'risk_score'),
        hornetCount: JsonReader.integer(json, 'hornet_count'),
        maxHornetCount: JsonReader.integer(json, 'max_hornet_count'),
        audioProbability: JsonReader.decimal(json, 'audio_probability'),
        lastUpdated: JsonReader.dateTime(json, 'last_updated'),
        monitoringOnline: JsonReader.boolean(json, 'monitoring_online'),
        lastHeartbeat: JsonReader.dateTimeOrNull(json, 'last_heartbeat'),
      );
}

/// Everything the Hive Detail screen shows.
@freezed
abstract class HiveDetail with _$HiveDetail {
  const factory HiveDetail({
    required Hive hive,
    @Default(0.0) double persistenceRatio,
    @Default(0.0) double growthPerSecond,
    @Default(false) bool cameraOk,
    @Default(false) bool microphoneOk,
    @Default(false) bool monitoring,
    @Default('') String statusReason,
    String? latestSnapshotUrl,
    DateTime? lastAnalyzedAt,
    @Default(<AlertSummary>[]) List<AlertSummary> recentAlerts,
  }) = _HiveDetail;

  const HiveDetail._();

  factory HiveDetail.fromApi(Map<String, dynamic> json) => HiveDetail(
        hive: Hive.fromApi(json),
        persistenceRatio: JsonReader.decimal(json, 'persistence_ratio'),
        growthPerSecond: JsonReader.decimal(json, 'growth_per_second'),
        cameraOk: JsonReader.boolean(json, 'camera_ok'),
        microphoneOk: JsonReader.boolean(json, 'microphone_ok'),
        monitoring: JsonReader.boolean(json, 'monitoring'),
        statusReason: JsonReader.string(json, 'status_reason'),
        latestSnapshotUrl: JsonReader.stringOrNull(json, 'latest_snapshot_url'),
        lastAnalyzedAt: JsonReader.dateTimeOrNull(json, 'last_analyzed_at'),
        recentAlerts: JsonReader.objectList(json, 'recent_alerts')
            .map(AlertSummary.fromApi)
            .toList(growable: false),
      );

  String get id => hive.id;
  String get name => hive.name;
  HiveStatus get status => hive.status;
}

/// Aggregated counts for the manager dashboard.
@freezed
abstract class DashboardSummary with _$DashboardSummary {
  const factory DashboardSummary({
    @Default(0) int total,
    @Default(0) int normal,
    @Default(0) int caution,
    @Default(0) int danger,
    @Default(0) int offline,
    @Default(<Hive>[]) List<Hive> hives,
    @Default(<AlertSummary>[]) List<AlertSummary> recentAlerts,
  }) = _DashboardSummary;

  const DashboardSummary._();

  factory DashboardSummary.fromApi(Map<String, dynamic> json) =>
      DashboardSummary(
        total: JsonReader.integer(json, 'total'),
        normal: JsonReader.integer(json, 'normal'),
        caution: JsonReader.integer(json, 'caution'),
        danger: JsonReader.integer(json, 'danger'),
        offline: JsonReader.integer(json, 'offline'),
        hives: JsonReader.objectList(json, 'hives')
            .map(Hive.fromApi)
            .toList(growable: false),
        recentAlerts: JsonReader.objectList(json, 'recent_alerts')
            .map(AlertSummary.fromApi)
            .toList(growable: false),
      );

  /// Builds the summary locally, used by the demo repository and as a
  /// fallback if only the hive list is available.
  factory DashboardSummary.fromHives(
    List<Hive> hives, {
    List<AlertSummary> alerts = const <AlertSummary>[],
  }) {
    int count(HiveStatus status) =>
        hives.where((Hive hive) => hive.status == status).length;

    return DashboardSummary(
      total: hives.length,
      normal: count(HiveStatus.normal),
      caution: count(HiveStatus.caution),
      danger: count(HiveStatus.danger),
      offline: count(HiveStatus.offline),
      hives: hives,
      recentAlerts: alerts,
    );
  }

  bool get hasDanger => danger > 0;
}

/// Lightweight status poll for one hive.
@freezed
abstract class HiveStatusSnapshot with _$HiveStatusSnapshot {
  const factory HiveStatusSnapshot({
    required String hiveId,
    required HiveStatus status,
    @Default(0) int riskScore,
    @Default(0) int hornetCount,
    @Default(0) int maxHornetCount,
    @Default(0.0) double audioProbability,
    @Default(false) bool monitoringOnline,
    @Default('') String statusReason,
    DateTime? lastHeartbeat,
    DateTime? lastAnalyzedAt,
  }) = _HiveStatusSnapshot;

  const HiveStatusSnapshot._();

  factory HiveStatusSnapshot.fromApi(Map<String, dynamic> json) =>
      HiveStatusSnapshot(
        hiveId: JsonReader.string(json, 'hive_id'),
        status: HiveStatus.fromWire(JsonReader.stringOrNull(json, 'status')),
        riskScore: JsonReader.integer(json, 'risk_score'),
        hornetCount: JsonReader.integer(json, 'hornet_count'),
        maxHornetCount: JsonReader.integer(json, 'max_hornet_count'),
        audioProbability: JsonReader.decimal(json, 'audio_probability'),
        monitoringOnline: JsonReader.boolean(json, 'monitoring_online'),
        statusReason: JsonReader.string(json, 'status_reason'),
        lastHeartbeat: JsonReader.dateTimeOrNull(json, 'last_heartbeat'),
        lastAnalyzedAt: JsonReader.dateTimeOrNull(json, 'last_analyzed_at'),
      );
}
