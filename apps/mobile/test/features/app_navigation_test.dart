import 'package:beehive_guard/app/app.dart';
import 'package:beehive_guard/app/router.dart';
import 'package:beehive_guard/core/api/demo_data.dart';
import 'package:beehive_guard/core/config/mode_storage.dart';
import 'package:beehive_guard/core/models/alert.dart';
import 'package:beehive_guard/core/models/hive.dart';
import 'package:beehive_guard/core/models/hive_status.dart';
import 'package:beehive_guard/core/models/pairing.dart';
import 'package:beehive_guard/core/providers.dart';
import 'package:beehive_guard/core/errors/failure.dart';
import 'package:beehive_guard/features/alerts/data/alert_repository.dart';
import 'package:beehive_guard/features/alerts/domain/alert_watcher.dart';
import 'package:beehive_guard/features/hives/data/hive_repository.dart';
import 'package:beehive_guard/features/pairing/data/pairing_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Walks the manager-side flow with the repositories overridden.
///
/// This is the test that proves the UI and the data layer are genuinely
/// separable: the whole app runs against fixtures with no backend, no HTTP
/// and no platform channels, purely by swapping two providers.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  /// Scrolls the first scrollable until [target] is on screen.
  ///
  /// The default test viewport is shorter than a real phone, so anything
  /// below the fold has to be scrolled to before it can be found or tapped.
  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    HiveRepository hiveRepository = const DemoHiveRepository(),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          modeStorageProvider.overrideWithValue(ModeStorage(prefs)),
          hiveRepositoryProvider.overrideWithValue(hiveRepository),
          alertRepositoryProvider.overrideWithValue(
            const DemoAlertRepository(),
          ),
          pairingRepositoryProvider.overrideWithValue(DemoPairingRepository()),
          // A periodic poll would keep pumpAndSettle from ever settling.
          alertWatchEnabledProvider.overrideWithValue(false),
        ],
        child: const BeehiveGuardApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the mode selection screen', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('벌통 지킴이'), findsOneWidget);
    expect(find.text('관찰 모드'), findsOneWidget);
    expect(find.text('관리자 모드'), findsOneWidget);
  });

  testWidgets('manager mode leads to the dashboard', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('관리자 모드'));
    await tester.pumpAndSettle();

    expect(find.text('양봉장 현황'), findsOneWidget);
    // The four status counts from the fixtures: 1 danger, 1 caution,
    // 1 normal, 1 offline.
    expect(find.text('위험'), findsWidgets);
    expect(find.text('오프라인'), findsWidgets);
  });

  testWidgets('dashboard replaces loading with a retryable timeout error', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, hiveRepository: const _FailingHiveRepository());

    await tester.tap(find.text('관리자 모드'));
    await tester.pumpAndSettle();

    expect(find.text('서버 응답이 지연되고 있습니다.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('manager settings never offers the monitoring scanner', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('관리자 모드'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();

    expect(find.text('벌통 연결하기'), findsNothing);
    expect(find.text('모니터링 기기는 벌통 상세에서 연결할 수 있습니다.'), findsOneWidget);
  });

  testWidgets('manager cannot open the monitoring pairing route directly', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('관리자 모드'));
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.byType(MaterialApp));
    ProviderScope.containerOf(context).read(routerProvider).go(Routes.pair);
    await tester.pumpAndSettle();

    expect(find.text('양봉장 현황'), findsOneWidget);
    expect(find.text('QR 코드 스캔'), findsNothing);
  });

  testWidgets('dashboard shows hives and recent alerts', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('관리자 모드'));
    await tester.pumpAndSettle();

    expect(find.text('벌통 A'), findsWidgets);

    await scrollTo(tester, find.text('최근 경보'));
    expect(find.text('최근 경보'), findsOneWidget);

    await scrollTo(tester, find.text('벌통 A에서 말벌 집단 공격 징후가 감지되었습니다.'));
    expect(find.text('벌통 A에서 말벌 집단 공격 징후가 감지되었습니다.'), findsWidgets);
  });

  testWidgets('tapping a hive opens its detail screen', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('관리자 모드'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('벌통 A').first);
    await tester.pumpAndSettle();

    expect(find.text('현재 상태'), findsOneWidget);
    expect(find.text('관찰 스마트폰'), findsOneWidget);
    expect(find.text('위험 점수'), findsOneWidget);
  });

  testWidgets('manager hive detail opens the code and QR pairing sheet', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('관리자 모드'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('벌통 A').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('모니터링 기기 연결'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('482 731'), findsOneWidget);
    expect(find.text('또는 6자리 코드 입력'), findsOneWidget);
  });

  testWidgets('tapping an alert opens the detail with its reasoning', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('관리자 모드'));
    await tester.pumpAndSettle();

    final Finder alert = find.text('벌통 A에서 말벌 집단 공격 징후가 감지되었습니다.');
    await scrollTo(tester, alert);
    await tester.tap(alert.first);
    await tester.pumpAndSettle();

    expect(find.text('경보 상세'), findsOneWidget);

    // The explanation must be present — it is the heart of the demo.
    await scrollTo(tester, find.text('판단 근거'));
    expect(find.text('판단 근거'), findsOneWidget);
    expect(find.textContaining('최근 분석 프레임의'), findsOneWidget);
  });

  testWidgets('the alert list is reachable and populated', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('관리자 모드'));
    await tester.pumpAndSettle();

    final Finder alertsLink = find.text('경보 전체 보기');
    await scrollTo(tester, alertsLink);
    await tester.tap(alertsLink);
    await tester.pumpAndSettle();

    expect(find.text('경보 기록'), findsOneWidget);
    expect(find.byType(ListView), findsWidgets);
  });

  testWidgets('the hive list is reachable and populated', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('관리자 모드'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('벌통 전체 보기'));
    await tester.pumpAndSettle();

    expect(find.text('벌통 목록'), findsOneWidget);
    for (final Hive hive in DemoData.hives()) {
      expect(find.text(hive.name), findsWidgets);
    }
  });

  testWidgets('an unpaired monitoring phone is sent to pairing', (
    WidgetTester tester,
  ) async {
    // There is no hive picker any more — the phone has to be paired first.
    await pumpApp(tester);

    await tester.tap(find.text('관찰 모드'));
    await tester.pumpAndSettle();

    expect(find.text('모니터링 기기 연결'), findsWidgets);
    expect(find.text('6자리 코드 입력'), findsOneWidget);
    expect(find.text('QR 코드 스캔'), findsOneWidget);
  });

  testWidgets('a paired monitoring phone goes straight to setup', (
    WidgetTester tester,
  ) async {
    // This is the restart case: pairing survives, so nothing is retyped.
    await ModeStorage(prefs)
        .writePairedHive(const PairedHive(hiveId: 'hive-a', hiveName: '벌통 A'));

    await pumpApp(tester);
    await tester.tap(find.text('관찰 모드'));
    await tester.pumpAndSettle();

    expect(find.text('모니터링 설정'), findsOneWidget);
    expect(find.text('연결된 벌통'), findsOneWidget);
    expect(find.text('벌통 A'), findsWidgets);
    expect(find.text('카메라'), findsOneWidget);
    expect(find.text('마이크'), findsOneWidget);
  });

  testWidgets('the selected mode is persisted', (WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('관리자 모드'));
    await tester.pumpAndSettle();

    expect(ModeStorage(prefs).readMode()?.storageValue, 'manager');
  });

  testWidgets('demo fixtures expose one alert per severity', (
    WidgetTester tester,
  ) async {
    final List<AlertSummary> alerts = DemoData.alerts();

    expect(
      alerts.where((AlertSummary a) => a.severity == AlertSeverity.danger),
      isNotEmpty,
    );
    expect(
      alerts.where((AlertSummary a) => a.severity == AlertSeverity.caution),
      isNotEmpty,
    );
  });
}

class _FailingHiveRepository implements HiveRepository {
  const _FailingHiveRepository();

  Never _timeout() => throw const Failure.timeout();

  @override
  Future<DashboardSummary> fetchDashboard() async => _timeout();

  @override
  Future<HiveDetail> fetchHiveDetail(String hiveId) async => _timeout();

  @override
  Future<List<Hive>> fetchHives() async => _timeout();

  @override
  Future<HiveStatusSnapshot> fetchHiveStatus(String hiveId) async => _timeout();
}
