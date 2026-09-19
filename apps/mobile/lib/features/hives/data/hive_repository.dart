import '../../../core/api/api_client.dart';
import '../../../core/api/demo_data.dart';
import '../../../core/models/hive.dart';

/// Reads hive state.
///
/// An interface rather than a concrete class so `DEMO_MODE` can swap in
/// fixtures without any screen or controller knowing.
abstract interface class HiveRepository {
  Future<List<Hive>> fetchHives();

  Future<DashboardSummary> fetchDashboard();

  Future<HiveDetail> fetchHiveDetail(String hiveId);

  Future<HiveStatusSnapshot> fetchHiveStatus(String hiveId);
}

/// Talks to the real backend.
class ApiHiveRepository implements HiveRepository {
  const ApiHiveRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Hive>> fetchHives() => _api.fetchHives();

  @override
  Future<DashboardSummary> fetchDashboard() => _api.fetchDashboard();

  @override
  Future<HiveDetail> fetchHiveDetail(String hiveId) =>
      _api.fetchHiveDetail(hiveId);

  @override
  Future<HiveStatusSnapshot> fetchHiveStatus(String hiveId) =>
      _api.fetchHiveStatus(hiveId);
}

/// Serves fixtures, for `DEMO_MODE`.
class DemoHiveRepository implements HiveRepository {
  const DemoHiveRepository();

  static const Duration _latency = Duration(milliseconds: 220);

  @override
  Future<List<Hive>> fetchHives() async {
    await Future<void>.delayed(_latency);
    return DemoData.hives();
  }

  @override
  Future<DashboardSummary> fetchDashboard() async {
    await Future<void>.delayed(_latency);
    return DashboardSummary.fromHives(DemoData.hives(), alerts: DemoData.alerts());
  }

  @override
  Future<HiveDetail> fetchHiveDetail(String hiveId) async {
    await Future<void>.delayed(_latency);
    return DemoData.hiveDetail(hiveId);
  }

  @override
  Future<HiveStatusSnapshot> fetchHiveStatus(String hiveId) async {
    await Future<void>.delayed(_latency);
    final HiveDetail detail = DemoData.hiveDetail(hiveId);
    return HiveStatusSnapshot(
      hiveId: detail.id,
      status: detail.status,
      riskScore: detail.hive.riskScore,
      hornetCount: detail.hive.hornetCount,
      maxHornetCount: detail.hive.maxHornetCount,
      audioProbability: detail.hive.audioProbability,
      monitoringOnline: detail.hive.monitoringOnline,
      statusReason: detail.statusReason,
      lastHeartbeat: detail.hive.lastHeartbeat,
      lastAnalyzedAt: detail.lastAnalyzedAt,
    );
  }
}
