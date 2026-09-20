import 'package:beehive_guard/core/models/alert.dart';
import 'package:beehive_guard/core/models/hive.dart';
import 'package:beehive_guard/core/models/hive_status.dart';
import 'package:beehive_guard/core/models/monitor_responses.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HiveStatus', () {
    test('maps the backend wire values', () {
      expect(HiveStatus.fromWire('NORMAL'), HiveStatus.normal);
      expect(HiveStatus.fromWire('CAUTION'), HiveStatus.caution);
      expect(HiveStatus.fromWire('DANGER'), HiveStatus.danger);
      expect(HiveStatus.fromWire('OFFLINE'), HiveStatus.offline);
    });

    test('degrades an unknown or missing status to offline', () {
      // A newer backend must not crash an older app.
      expect(HiveStatus.fromWire('SOMETHING_NEW'), HiveStatus.offline);
      expect(HiveStatus.fromWire(null), HiveStatus.offline);
    });

    test('ranks danger above caution above normal', () {
      expect(HiveStatus.danger.rank, greaterThan(HiveStatus.caution.rank));
      expect(HiveStatus.caution.rank, greaterThan(HiveStatus.normal.rank));
    });

    test('treats offline as a liveness state, not a threat level', () {
      expect(HiveStatus.offline.rank, HiveStatus.normal.rank);
      expect(HiveStatus.offline.isAlerting, isFalse);
    });
  });

  group('Hive.fromApi', () {
    test('parses a full backend payload', () {
      final Hive hive = Hive.fromApi(<String, dynamic>{
        'id': 'hive-a',
        'name': '벌통 A',
        'location': '1구역',
        'status': 'DANGER',
        'risk_score': 82,
        'hornet_count': 6,
        'max_hornet_count': 7,
        'audio_probability': 0.78,
        'last_updated': '2026-09-19T12:00:00',
        'monitoring_online': true,
        'last_heartbeat': '2026-09-19T11:59:55',
      });

      expect(hive.id, 'hive-a');
      expect(hive.name, '벌통 A');
      expect(hive.status, HiveStatus.danger);
      expect(hive.riskScore, 82);
      expect(hive.hornetCount, 6);
      expect(hive.maxHornetCount, 7);
      expect(hive.audioProbability, closeTo(0.78, 1e-9));
      expect(hive.monitoringOnline, isTrue);
      expect(hive.lastHeartbeat, isNotNull);
    });

    test('survives a payload missing every optional field', () {
      final Hive hive = Hive.fromApi(<String, dynamic>{'id': 'x'});

      expect(hive.id, 'x');
      expect(hive.name, isNotEmpty);
      expect(hive.status, HiveStatus.offline);
      expect(hive.riskScore, 0);
    });
  });

  group('DashboardSummary', () {
    test('parses counts from the backend', () {
      final DashboardSummary summary =
          DashboardSummary.fromApi(<String, dynamic>{
        'total': 4,
        'normal': 1,
        'caution': 1,
        'danger': 1,
        'offline': 1,
        'hives': <dynamic>[],
        'recent_alerts': <dynamic>[],
      });

      expect(summary.total, 4);
      expect(summary.hasDanger, isTrue);
    });

    test('derives counts locally from a hive list', () {
      final DashboardSummary summary = DashboardSummary.fromHives(<Hive>[
        _hive(HiveStatus.danger),
        _hive(HiveStatus.caution),
        _hive(HiveStatus.normal),
        _hive(HiveStatus.normal),
        _hive(HiveStatus.offline),
      ]);

      expect(summary.total, 5);
      expect(summary.danger, 1);
      expect(summary.caution, 1);
      expect(summary.normal, 2);
      expect(summary.offline, 1);
      expect(
        summary.normal + summary.caution + summary.danger + summary.offline,
        summary.total,
      );
    });
  });

  group('AlertDetail.fromApi', () {
    test('parses the summary and the reasoning together', () {
      final AlertDetail detail = AlertDetail.fromApi(<String, dynamic>{
        'id': 'alert-1',
        'hive_id': 'hive-a',
        'hive_name': '벌통 A',
        'timestamp': '2026-09-19T12:00:00',
        'severity': 'DANGER',
        'risk_score': 82,
        'hornet_count': 6,
        'message': '경보',
        'max_hornet_count': 7,
        'audio_probability': 0.78,
        'persistence_ratio': 0.76,
        'growth_per_second': 0.26,
        'explanation': '판단 근거',
      });

      expect(detail.id, 'alert-1');
      expect(detail.severity, AlertSeverity.danger);
      expect(detail.severity.asStatus, HiveStatus.danger);
      expect(detail.explanation, '판단 근거');
      expect(detail.maxHornetCount, 7);
    });

    test('defaults an unknown severity to caution, never danger', () {
      // Erring towards danger would create false alarms from a parse glitch.
      expect(AlertSeverity.fromWire('WHAT'), AlertSeverity.caution);
      expect(AlertSeverity.fromWire(null), AlertSeverity.caution);
    });
  });

  group('FrameAnalysis.fromApi', () {
    test('parses the documented frame response shape', () {
      final FrameAnalysis analysis = FrameAnalysis.fromApi(<String, dynamic>{
        'status': 'CAUTION',
        'risk_score': 44,
        'hornet_count': 2,
        'confidence': 0.87,
        'processed_at': '2026-09-19T12:00:00',
      });

      expect(analysis.status, HiveStatus.caution);
      expect(analysis.riskScore, 44);
      expect(analysis.hornetCount, 2);
      expect(analysis.confidence, closeTo(0.87, 1e-9));
      expect(analysis.alertId, isNull);
    });

    test('parses the documented audio response shape', () {
      final AudioAnalysis analysis = AudioAnalysis.fromApi(<String, dynamic>{
        'hornet_probability': 0.31,
        'processed_at': '2026-09-19T12:00:00',
      });

      expect(analysis.hornetProbability, closeTo(0.31, 1e-9));
      expect(analysis.status, isNull);
    });
  });
}

Hive _hive(HiveStatus status) => Hive(
      id: 'id-${status.name}',
      name: status.name,
      status: status,
      riskScore: 0,
      hornetCount: 0,
      lastUpdated: DateTime(2026),
    );
