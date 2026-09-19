import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/alerts/presentation/alert_detail_screen.dart';
import '../features/alerts/presentation/alert_list_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/hives/presentation/hive_detail_screen.dart';
import '../features/hives/presentation/hive_list_screen.dart';
import '../features/mode_selection/presentation/mode_selection_screen.dart';
import '../features/monitoring/presentation/live_monitoring_screen.dart';
import '../features/monitoring/presentation/monitoring_setup_screen.dart';
import '../features/pairing/presentation/pair_device_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

/// Named route paths, so navigation calls never contain a raw string.
abstract final class Routes {
  static const String mode = '/mode';
  static const String pair = '/pair';
  static const String monitorSetup = '/monitor/setup';
  static const String monitorLive = '/monitor/live';
  static const String dashboard = '/dashboard';
  static const String hives = '/hives';
  static const String alerts = '/alerts';
  static const String settings = '/settings';

  static String hive(String id) => '/hives/$id';
  static String alert(String id) => '/alerts/$id';
}

/// A [GlobalKey] on the router's navigator.
///
/// Needed so a push notification arriving while the app is in the background
/// can navigate without a [BuildContext].
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.mode,
    routes: <RouteBase>[
      GoRoute(
        path: Routes.mode,
        builder: (BuildContext context, GoRouterState state) =>
            const ModeSelectionScreen(),
      ),
      GoRoute(
        path: Routes.pair,
        builder: (BuildContext context, GoRouterState state) =>
            const PairDeviceScreen(),
      ),
      GoRoute(
        path: Routes.monitorSetup,
        builder: (BuildContext context, GoRouterState state) =>
            const MonitoringSetupScreen(),
      ),
      GoRoute(
        path: Routes.monitorLive,
        builder: (BuildContext context, GoRouterState state) =>
            const LiveMonitoringScreen(),
      ),
      GoRoute(
        path: Routes.dashboard,
        builder: (BuildContext context, GoRouterState state) =>
            const DashboardScreen(),
      ),
      GoRoute(
        path: Routes.hives,
        builder: (BuildContext context, GoRouterState state) =>
            const HiveListScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: ':id',
            builder: (BuildContext context, GoRouterState state) =>
                HiveDetailScreen(hiveId: state.pathParameters['id'] ?? ''),
          ),
        ],
      ),
      GoRoute(
        path: Routes.alerts,
        builder: (BuildContext context, GoRouterState state) =>
            const AlertListScreen(),
        routes: <RouteBase>[
          // The deep-link target for a push notification.
          GoRoute(
            path: ':id',
            builder: (BuildContext context, GoRouterState state) =>
                AlertDetailScreen(alertId: state.pathParameters['id'] ?? ''),
          ),
        ],
      ),
      GoRoute(
        path: Routes.settings,
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsScreen(),
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) => Scaffold(
      appBar: AppBar(title: const Text('페이지를 찾을 수 없습니다')),
      body: Center(child: Text('알 수 없는 경로: ${state.uri}')),
    ),
  );

  ref.onDispose(router.dispose);
  return router;
});
