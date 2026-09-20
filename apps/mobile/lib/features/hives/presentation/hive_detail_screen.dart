import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/models/alert.dart';
import '../../../core/models/hive.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/alert_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../pairing/presentation/pairing_sheet.dart';
import '../domain/hive_controllers.dart';

/// Everything known about one hive.
class HiveDetailScreen extends ConsumerWidget {
  const HiveDetailScreen({required this.hiveId, super.key});

  final String hiveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<HiveDetail> detail =
        ref.watch(hiveDetailProvider(hiveId));

    return Scaffold(
      appBar: AppBar(
        title: Text(detail.value?.name ?? '벌통 상세'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(hiveDetailProvider(hiveId)),
        child: detail.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stackTrace) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: <Widget>[
              SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
              ErrorState(
                failure: ErrorMapper.map(error, stackTrace),
                onRetry: () => ref.invalidate(hiveDetailProvider(hiveId)),
              ),
            ],
          ),
          data: (HiveDetail data) => _HiveDetailBody(detail: data),
        ),
      ),
    );
  }
}

class _HiveDetailBody extends StatelessWidget {
  const _HiveDetailBody({required this.detail});

  final HiveDetail detail;

  @override
  Widget build(BuildContext context) {
    final Hive hive = detail.hive;
    final Color accent = statusColor(hive.status);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppSpacing.screen,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(hive.name, style: AppTypography.titleLarge),
                  if (hive.location.isNotEmpty)
                    Text(hive.location, style: AppTypography.bodyMedium),
                ],
              ),
            ),
            StatusBadge(status: hive.status),
          ],
        ),
        if (detail.statusReason.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: AppColors.outline),
            ),
            child: Text(detail.statusReason, style: AppTypography.bodyLarge),
          ),
        ],
        const SectionHeader(title: '현재 상태'),
        Row(
          children: <Widget>[
            Expanded(
              child: MetricCard(
                label: '위험 점수',
                value: '${hive.riskScore}',
                unit: '/ 100',
                accent: accent,
                icon: Icons.speed,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: MetricCard(
                label: '현재 말벌 수',
                value: '${hive.hornetCount}',
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
                label: '최근 최대 말벌 수',
                value: '${hive.maxHornetCount}',
                unit: '마리',
                icon: Icons.trending_up,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: MetricCard(
                label: '음향 위험도',
                value: Formatters.percent(hive.audioProbability),
                icon: Icons.graphic_eq,
              ),
            ),
          ],
        ),
        SectionHeader(
          title: '관찰 스마트폰',
          trailing: TextButton.icon(
            onPressed: () => showPairingSheet(
              context,
              hiveId: hive.id,
              hiveName: hive.name,
            ),
            icon: const Icon(Icons.qr_code, size: 18),
            label: const Text('모니터링 기기 연결'),
          ),
        ),
        _DeviceStatusCard(detail: detail),
        const SectionHeader(title: '최근 스냅샷'),
        _LatestSnapshot(url: detail.latestSnapshotUrl),
        const SectionHeader(title: '최근 경보'),
        if (detail.recentAlerts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: EmptyState(
              icon: Icons.notifications_none,
              message: '이 벌통에서 발생한 경보가 없습니다.',
            ),
          )
        else
          ...detail.recentAlerts.map(
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

class _DeviceStatusCard extends StatelessWidget {
  const _DeviceStatusCard({required this.detail});

  final HiveDetail detail;

  @override
  Widget build(BuildContext context) {
    final bool online = detail.hive.monitoringOnline;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: <Widget>[
          _Row(
            label: '연결 상태',
            value: online ? '온라인' : '오프라인',
            color: online ? AppColors.statusNormal : AppColors.statusOffline,
            icon: online ? Icons.check_circle_outline : Icons.cloud_off,
          ),
          const Divider(height: AppSpacing.xl),
          _Row(
            label: '마지막 heartbeat',
            value: Formatters.relativeTime(detail.hive.lastHeartbeat),
            icon: Icons.favorite_outline,
          ),
          const Divider(height: AppSpacing.xl),
          _Row(
            label: '마지막 분석',
            value: Formatters.relativeTime(detail.lastAnalyzedAt),
            icon: Icons.analytics_outlined,
          ),
          const Divider(height: AppSpacing.xl),
          _Row(
            label: '카메라 / 마이크',
            value: '${detail.cameraOk ? '정상' : '불가'} / '
                '${detail.microphoneOk ? '정상' : '불가'}',
            icon: Icons.camera_alt_outlined,
          ),
          const Divider(height: AppSpacing.xl),
          _Row(
            label: '모니터링',
            value: detail.monitoring ? '진행 중' : '중지됨',
            icon: Icons.videocam_outlined,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(label, style: AppTypography.bodyMedium)),
        Text(
          value,
          style: AppTypography.titleMedium.copyWith(color: color),
        ),
      ],
    );
  }
}

class _LatestSnapshot extends StatelessWidget {
  const _LatestSnapshot({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Container(
        height: 140,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: AppColors.outline),
        ),
        child: const Text('아직 업로드된 프레임이 없습니다.', style: AppTypography.bodyMedium),
      );
    }

    return ClipRRect(
      borderRadius: AppRadius.cardRadius,
      child: Image.network(
        url!,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          height: 140,
          alignment: Alignment.center,
          color: AppColors.surface,
          child: const Text(
            '스냅샷을 불러오지 못했습니다.',
            style: AppTypography.bodyMedium,
          ),
        ),
      ),
    );
  }
}
