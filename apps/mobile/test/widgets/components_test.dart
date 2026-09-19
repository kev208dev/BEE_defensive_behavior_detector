import 'package:beehive_guard/app/theme/app_theme.dart';
import 'package:beehive_guard/core/errors/failure.dart';
import 'package:beehive_guard/core/models/alert.dart';
import 'package:beehive_guard/core/models/hive.dart';
import 'package:beehive_guard/core/models/hive_status.dart';
import 'package:beehive_guard/core/providers.dart';
import 'package:beehive_guard/core/widgets/alert_card.dart';
import 'package:beehive_guard/core/widgets/app_button.dart';
import 'package:beehive_guard/core/widgets/connection_badge.dart';
import 'package:beehive_guard/core/widgets/empty_state.dart';
import 'package:beehive_guard/core/widgets/error_state.dart';
import 'package:beehive_guard/core/widgets/hive_card.dart';
import 'package:beehive_guard/core/widgets/metric_card.dart';
import 'package:beehive_guard/core/widgets/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// These are the components the Figma design will replace. The tests assert
/// the *contract* each one fulfils — what it displays and what it calls — so
/// a restyle can be verified without rewriting the suite.
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(body: Center(child: child)),
      );

  group('StatusBadge', () {
    testWidgets('labels each status in Korean', (WidgetTester tester) async {
      for (final HiveStatus status in HiveStatus.values) {
        await tester.pumpWidget(host(StatusBadge(status: status)));
        expect(find.text(status.label), findsOneWidget);
      }
    });

    testWidgets('gives each status a distinct colour',
        (WidgetTester tester) async {
      final Set<int> colours = HiveStatus.values
          .map((HiveStatus s) => statusColor(s).toARGB32())
          .toSet();

      // A shared colour would make two states indistinguishable at a glance.
      expect(colours, hasLength(HiveStatus.values.length));
    });
  });

  group('AppButton', () {
    testWidgets('invokes its callback when tapped',
        (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(
        host(AppButton(label: '시작', onPressed: () => taps++)),
      );

      await tester.tap(find.text('시작'));
      expect(taps, 1);
    });

    testWidgets('is inert while busy', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(
        host(AppButton(label: '시작', busy: true, onPressed: () => taps++)),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('시작'), findsNothing);

      await tester.tap(find.byType(AppButton));
      expect(taps, 0);
    });

    testWidgets('is inert when given no callback',
        (WidgetTester tester) async {
      await tester.pumpWidget(host(const AppButton(label: '시작', onPressed: null)));

      final FilledButton button =
          tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });
  });

  group('HiveCard', () {
    final Hive hive = Hive(
      id: 'hive-a',
      name: '벌통 A',
      location: '1구역',
      status: HiveStatus.danger,
      riskScore: 82,
      hornetCount: 6,
      lastUpdated: DateTime.now(),
    );

    testWidgets('shows name, status, risk score and hornet count',
        (WidgetTester tester) async {
      await tester.pumpWidget(host(HiveCard(hive: hive)));

      expect(find.text('벌통 A'), findsOneWidget);
      expect(find.text('1구역'), findsOneWidget);
      expect(find.text('위험'), findsOneWidget);
      expect(find.text('82'), findsOneWidget);
      expect(find.text('6마리'), findsOneWidget);
    });

    testWidgets('is tappable', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(host(HiveCard(hive: hive, onTap: () => taps++)));

      await tester.tap(find.text('벌통 A'));
      expect(taps, 1);
    });
  });

  group('AlertCard', () {
    testWidgets('shows severity, hive name, message and risk score',
        (WidgetTester tester) async {
      final AlertSummary alert = AlertSummary(
        id: 'alert-1',
        hiveId: 'hive-a',
        hiveName: '벌통 A',
        timestamp: DateTime.now(),
        severity: AlertSeverity.danger,
        riskScore: 82,
        hornetCount: 6,
        message: '말벌 집단 공격 징후가 감지되었습니다.',
      );

      await tester.pumpWidget(host(AlertCard(alert: alert)));

      expect(find.text('벌통 A'), findsOneWidget);
      expect(find.text('위험'), findsOneWidget);
      expect(find.text('말벌 집단 공격 징후가 감지되었습니다.'), findsOneWidget);
      expect(find.text('위험도 82'), findsOneWidget);
    });
  });

  group('MetricCard', () {
    testWidgets('renders label, value, unit and caption',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          const SizedBox(
            width: 200,
            child: MetricCard(
              label: '위험 점수',
              value: '82',
              unit: '/ 100',
              caption: '최근 30초',
            ),
          ),
        ),
      );

      expect(find.text('위험 점수'), findsOneWidget);
      expect(find.text('82'), findsOneWidget);
      expect(find.text('/ 100'), findsOneWidget);
      expect(find.text('최근 30초'), findsOneWidget);
    });
  });

  group('ConnectionBadge', () {
    testWidgets('distinguishes connected from disconnected',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        host(const ConnectionBadge(state: BackendConnectionState.connected)),
      );
      expect(find.text('서버 연결됨'), findsOneWidget);

      await tester.pumpWidget(
        host(const ConnectionBadge(state: BackendConnectionState.disconnected)),
      );
      expect(find.text('서버 연결 끊김'), findsOneWidget);
    });
  });

  group('EmptyState / ErrorState', () {
    testWidgets('EmptyState shows its message', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(const EmptyState(title: '경보 없음', message: '아직 경보가 없습니다.')),
      );

      expect(find.text('경보 없음'), findsOneWidget);
      expect(find.text('아직 경보가 없습니다.'), findsOneWidget);
    });

    testWidgets('ErrorState offers a retry when given one',
        (WidgetTester tester) async {
      int retries = 0;
      await tester.pumpWidget(
        host(
          ErrorState(
            failure: const Failure.network(),
            onRetry: () => retries++,
          ),
        ),
      );

      expect(find.text('다시 시도'), findsOneWidget);
      await tester.tap(find.text('다시 시도'));
      expect(retries, 1);
    });

    testWidgets('ErrorState omits retry when none is given',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        host(const ErrorState(failure: Failure.network())),
      );

      expect(find.text('다시 시도'), findsNothing);
    });
  });
}
