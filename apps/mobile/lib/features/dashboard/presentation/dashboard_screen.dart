import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/models/alert.dart';
import '../../../core/models/hive.dart';
import '../../../core/models/hive_status.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/alert_card.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/hive_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../alerts/domain/alert_watcher.dart';
import '../domain/dashboard_controller.dart';

/// The manager's home screen.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Start watching for new alerts as soon as the manager lands here. This is
    // the fallback that keeps the demo working without any Firebase setup.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(alertWatcherProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<DashboardSummary> dashboard =
        ref.watch(dashboardControllerProvider);
    final BackendConnectionState connection = ref.watch(connectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('양봉장 현황'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ConnectionBadge(state: connection)),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '설정',
            onPressed: () => context.push(Routes.settings),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(dashboardControllerProvider.notifier).refresh(),
        child: dashboard.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stackTrace) => ListView(
            // Must stay scrollable so pull-to-refresh works on the error view.
            physics: const AlwaysScrollableScrollPhysics(),
            children: <Widget>[
              SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
              ErrorState(
                failure: ErrorMapper.map(error, stackTrace),
                onRetry: () =>
                    ref.read(dashboardControllerProvider.notifier).refresh(),
              ),
            ],
          ),
          data: (DashboardSummary summary) => _DashboardBody(summary: summary),
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppSpacing.screen,
      children: <Widget>[
        _StatusSummaryRow(summary: summary),
        SectionHeader(
          title: '벌통',
          subtitle: '${summary.total}개',
          trailing: TextButton(
            onPressed: () => context.push(Routes.hives),
            child: const Text('벌통 전체 보기'),
          ),
        ),
        if (summary.hives.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: EmptyState(
              icon: Icons.hive_outlined,
              message: '등록된 벌통이 없습니다.',
            ),
          )
        else
          ...summary.hives.take(4).map(
                (Hive hive) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: HiveCard(
                    hive: hive,
                    onTap: () => context.push(Routes.hive(hive.id)),
                  ),
                ),
              ),
        SectionHeader(
          title: '최근 경보',
          trailing: TextButton(
            onPressed: () => context.push(Routes.alerts),
            child: const Text('경보 전체 보기'),
          ),
        ),
        if (summary.recentAlerts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: EmptyState(
              icon: Icons.notifications_none,
              message: '아직 발생한 경보가 없습니다.',
            ),
          )
        else
          ...summary.recentAlerts.take(5).map(
                (AlertSummary alert) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: AlertCard(
                    alert: alert,
                    onTap: () => context.push(Routes.alert(alert.id)),
                  ),
                ),
              ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

/// The four status counts, which is the first thing a manager looks at.
class _StatusSummaryRow extends StatelessWidget {
  const _StatusSummaryRow({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _CountTile(
          status: HiveStatus.danger,
          count: summary.danger,
          emphasise: summary.danger > 0,
        ),
        const SizedBox(width: AppSpacing.sm),
        _CountTile(status: HiveStatus.caution, count: summary.caution),
        const SizedBox(width: AppSpacing.sm),
        _CountTile(status: HiveStatus.normal, count: summary.normal),
        const SizedBox(width: AppSpacing.sm),
        _CountTile(status: HiveStatus.offline, count: summary.offline),
      ],
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.status,
    required this.count,
    this.emphasise = false,
  });

  final HiveStatus status;
  final int count;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final Color color = statusColor(status);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: emphasise ? color.withValues(alpha: 0.14) : AppColors.surface,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(
            color: emphasise ? color : AppColors.outline,
            width: emphasise ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: <Widget>[
            Text(
              '$count',
              style: AppTypography.metric.copyWith(color: color),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              status.label,
              style: AppTypography.label,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
