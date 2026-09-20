import '../models/alert.dart';
import '../models/hive.dart';
import '../models/hive_status.dart';

/// In-memory fixtures for `DEMO_MODE`.
///
/// These exist so the whole app can be walked through with no backend running
/// — useful for reviewing screens and for handing a build to the designer.
/// Real backend integration remains the default and the development target.
abstract final class DemoData {
  static DateTime get _now => DateTime.now();

  static List<Hive> hives() => <Hive>[
        Hive(
          id: 'hive-a',
          name: '벌통 A',
          location: '1구역 동편',
          status: HiveStatus.danger,
          riskScore: 82,
          hornetCount: 6,
          maxHornetCount: 7,
          audioProbability: 0.78,
          lastUpdated: _now.subtract(const Duration(seconds: 3)),
          monitoringOnline: true,
          lastHeartbeat: _now.subtract(const Duration(seconds: 4)),
        ),
        Hive(
          id: 'hive-b',
          name: '벌통 B',
          location: '1구역 서편',
          status: HiveStatus.caution,
          riskScore: 47,
          hornetCount: 3,
          maxHornetCount: 4,
          audioProbability: 0.41,
          lastUpdated: _now.subtract(const Duration(seconds: 6)),
          monitoringOnline: true,
          lastHeartbeat: _now.subtract(const Duration(seconds: 6)),
        ),
        Hive(
          id: 'hive-c',
          name: '벌통 C',
          location: '2구역 남편',
          status: HiveStatus.normal,
          riskScore: 8,
          hornetCount: 0,
          audioProbability: 0.09,
          lastUpdated: _now.subtract(const Duration(seconds: 2)),
          monitoringOnline: true,
          lastHeartbeat: _now.subtract(const Duration(seconds: 2)),
        ),
        Hive(
          id: 'hive-d',
          name: '벌통 D',
          location: '2구역 북편',
          status: HiveStatus.offline,
          riskScore: 0,
          hornetCount: 0,
          lastUpdated: _now.subtract(const Duration(minutes: 14)),
        ),
      ];

  static List<AlertSummary> alerts() => <AlertSummary>[
        AlertSummary(
          id: 'alert-1',
          hiveId: 'hive-a',
          hiveName: '벌통 A',
          timestamp: _now.subtract(const Duration(seconds: 40)),
          severity: AlertSeverity.danger,
          riskScore: 82,
          hornetCount: 6,
          message: '벌통 A에서 말벌 집단 공격 징후가 감지되었습니다.',
        ),
        AlertSummary(
          id: 'alert-2',
          hiveId: 'hive-b',
          hiveName: '벌통 B',
          timestamp: _now.subtract(const Duration(minutes: 6)),
          severity: AlertSeverity.caution,
          riskScore: 47,
          hornetCount: 3,
          message: '벌통 B에서 말벌 활동이 증가하고 있습니다.',
        ),
        AlertSummary(
          id: 'alert-3',
          hiveId: 'hive-a',
          hiveName: '벌통 A',
          timestamp: _now.subtract(const Duration(hours: 3)),
          severity: AlertSeverity.caution,
          riskScore: 44,
          hornetCount: 2,
          message: '벌통 A에서 말벌 활동이 증가하고 있습니다.',
        ),
      ];

  static AlertDetail alertDetail(String id) {
    final AlertSummary summary = alerts().firstWhere(
      (AlertSummary alert) => alert.id == id,
      orElse: () => alerts().first,
    );
    return AlertDetail(
      summary: summary,
      maxHornetCount: summary.hornetCount + 1,
      audioProbability: summary.severity == AlertSeverity.danger ? 0.78 : 0.41,
      persistenceRatio: 0.76,
      growthPerSecond: 0.26,
      explanation: summary.severity == AlertSeverity.danger
          ? '현재 말벌 6마리가 탐지되었고 최근 30초 내 최대 7마리까지 관측되었습니다, '
              '최근 분석 프레임의 76%에서 말벌이 연속적으로 확인되어 일시적인 통과가 아닌 '
              '지속적인 체류로 판단됩니다, 말벌 개체 수가 초당 약 0.26마리 속도로 빠르게 '
              '증가하고 있습니다, 음향 분석에서 말벌 관련 신호가 78% 확률로 함께 '
              '감지되었습니다. 집단 공격 가능성이 높아 즉시 확인이 필요합니다.'
          : '현재 말벌 3마리가 탐지되었고 최근 30초 내 최대 4마리까지 관측되었습니다, '
              '최근 분석 프레임의 62%에서 말벌이 연속적으로 확인되어 일시적인 통과가 아닌 '
              '지속적인 체류로 판단됩니다. 상황을 주의 깊게 관찰할 필요가 있습니다.',
    );
  }

  static HiveDetail hiveDetail(String hiveId) {
    final Hive hive = hives().firstWhere(
      (Hive item) => item.id == hiveId,
      orElse: () => hives().first,
    );
    return HiveDetail(
      hive: hive,
      persistenceRatio: hive.status == HiveStatus.danger ? 0.76 : 0.3,
      growthPerSecond: hive.status == HiveStatus.danger ? 0.26 : 0.04,
      cameraOk: hive.monitoringOnline,
      microphoneOk: hive.monitoringOnline,
      monitoring: hive.monitoringOnline,
      statusReason: '현재 ${hive.hornetCount}마리 탐지, '
          '최근 최대 ${hive.maxHornetCount}마리, '
          '음향 위험도 ${(hive.audioProbability * 100).round()}%.',
      lastAnalyzedAt: hive.lastUpdated,
      recentAlerts: alerts()
          .where((AlertSummary alert) => alert.hiveId == hiveId)
          .toList(growable: false),
    );
  }
}
