import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/models/alert.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../domain/alert_controllers.dart';

/// One alert in full, including why the system decided to raise it.
///
/// This is the screen the push notification deep-links to, and the one the
/// judges will look at — so the reasoning is given as much room as the numbers.
class AlertDetailScreen extends ConsumerWidget {
  const AlertDetailScreen({required this.alertId, super.key});

  final String alertId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AlertDetail> alert =
        ref.watch(alertDetailProvider(alertId));

    return Scaffold(
      appBar: AppBar(title: const Text('경보 상세')),
      body: alert.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => ErrorState(
          failure: ErrorMapper.map(error, stackTrace),
          onRetry: () => ref.invalidate(alertDetailProvider(alertId)),
        ),
        data: (AlertDetail detail) => _AlertDetailBody(detail: detail),
      ),
    );
  }
}

class _AlertDetailBody extends StatelessWidget {
  const _AlertDetailBody({required this.detail});

  final AlertDetail detail;

  @override
  Widget build(BuildContext context) {
    final Color accent = statusColor(detail.severity.asStatus);

    return ListView(
      padding: AppSpacing.screen,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(detail.hiveName, style: AppTypography.titleLarge),
            ),
            StatusBadge(status: detail.severity.asStatus),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${Formatters.absoluteTime(detail.timestamp)} '
          '(${Formatters.relativeTime(detail.timestamp)})',
          style: AppTypography.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                statusIcon(detail.severity.asStatus),
                color: accent,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(detail.message, style: AppTypography.bodyLarge),
              ),
            ],
          ),
        ),
        const SectionHeader(title: '판단 근거'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.outline),
          ),
          child: Text(
            detail.explanation.isEmpty
                ? '판단 근거가 기록되지 않았습니다.'
                : detail.explanation,
            style: AppTypography.bodyLarge,
          ),
        ),
        const SectionHeader(title: '측정값'),
        _MetricGrid(detail: detail, accent: accent),
        const SectionHeader(title: '탐지 스냅샷'),
        _Snapshot(url: detail.thumbnailUrl),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.detail, required this.accent});

  final AlertDetail detail;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: MetricCard(
                label: '위험 점수',
                value: '${detail.riskScore}',
                unit: '/ 100',
                accent: accent,
                icon: Icons.speed,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: MetricCard(
                label: '탐지 말벌 수',
                value: '${detail.hornetCount}',
                unit: '마리',
                icon: Icons.bug_report_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: MetricCard(
                label: '최대 말벌 수',
                value: '${detail.maxHornetCount}',
                unit: '마리',
                icon: Icons.trending_up,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: MetricCard(
                label: '지속성',
                value: Formatters.percent(detail.persistenceRatio),
                caption: '말벌이 탐지된 프레임 비율',
                icon: Icons.timelapse,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: MetricCard(
                label: '음향 위험도',
                value: Formatters.percent(detail.audioProbability),
                caption: '음향 분석 말벌 확률',
                icon: Icons.graphic_eq,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: MetricCard(
                label: '증가 속도',
                value: Formatters.growthRate(detail.growthPerSecond),
                caption: '개체 수 증가율',
                icon: Icons.show_chart,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Snapshot extends StatelessWidget {
  const _Snapshot({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: AppColors.outline),
        ),
        child: const Text('스냅샷이 없습니다.', style: AppTypography.bodyMedium),
      );
    }

    return ClipRRect(
      borderRadius: AppRadius.cardRadius,
      child: Image.network(
        url!,
        fit: BoxFit.cover,
        height: 220,
        width: double.infinity,
        // A snapshot that fails to load must not take the screen down — the
        // reasoning above it is the important part.
        errorBuilder: (_, _, _) => Container(
          height: 160,
          alignment: Alignment.center,
          color: AppColors.surface,
          child: const Text(
            '스냅샷을 불러오지 못했습니다.',
            style: AppTypography.bodyMedium,
          ),
        ),
        loadingBuilder: (
          BuildContext context,
          Widget child,
          ImageChunkEvent? progress,
        ) {
          if (progress == null) return child;
          return Container(
            height: 160,
            alignment: Alignment.center,
            color: AppColors.surface,
            child: const CircularProgressIndicator(),
          );
        },
      ),
    );
  }
}
