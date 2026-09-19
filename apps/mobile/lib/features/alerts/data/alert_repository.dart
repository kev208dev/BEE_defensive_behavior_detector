import '../../../core/api/api_client.dart';
import '../../../core/api/demo_data.dart';
import '../../../core/models/alert.dart';

/// Reads alerts.
abstract interface class AlertRepository {
  Future<List<AlertSummary>> fetchAlerts({
    String? hiveId,
    DateTime? since,
    int limit,
  });

  Future<AlertDetail> fetchAlertDetail(String alertId);
}

/// Talks to the real backend.
class ApiAlertRepository implements AlertRepository {
  const ApiAlertRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<AlertSummary>> fetchAlerts({
    String? hiveId,
    DateTime? since,
    int limit = 50,
  }) =>
      _api.fetchAlerts(hiveId: hiveId, since: since, limit: limit);

  @override
  Future<AlertDetail> fetchAlertDetail(String alertId) =>
      _api.fetchAlertDetail(alertId);
}

/// Serves fixtures, for `DEMO_MODE`.
class DemoAlertRepository implements AlertRepository {
  const DemoAlertRepository();

  static const Duration _latency = Duration(milliseconds: 220);

  @override
  Future<List<AlertSummary>> fetchAlerts({
    String? hiveId,
    DateTime? since,
    int limit = 50,
  }) async {
    await Future<void>.delayed(_latency);
    return DemoData.alerts()
        .where((AlertSummary alert) => hiveId == null || alert.hiveId == hiveId)
        .where((AlertSummary alert) =>
            since == null || alert.timestamp.isAfter(since))
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<AlertDetail> fetchAlertDetail(String alertId) async {
    await Future<void>.delayed(_latency);
    return DemoData.alertDetail(alertId);
  }
}
