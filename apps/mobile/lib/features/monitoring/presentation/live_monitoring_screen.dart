import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../domain/monitoring_controller.dart';
import '../domain/monitoring_state.dart';

/// The monitoring phone's main screen.
///
/// Pure presentation: it reads [MonitoringState] and calls controller methods.
/// It owns no camera, no timer and no upload — that all lives in
/// [MonitoringController], which is what lets this whole file be replaced when
/// the Figma design lands.
class LiveMonitoringScreen extends ConsumerStatefulWidget {
  const LiveMonitoringScreen({super.key});

  @override
  ConsumerState<LiveMonitoringScreen> createState() =>
      _LiveMonitoringScreenState();
}

class _LiveMonitoringScreenState extends ConsumerState<LiveMonitoringScreen> {
  @override
  Widget build(BuildContext context) {
    final MonitoringState state = ref.watch(monitoringControllerProvider);
    final BackendConnectionState connection = ref.watch(connectionProvider);

    return PopScope(
      // Leaving the screen must not silently leave the camera running.
      canPop: !state.monitoring,
      onPopInvokedWithResult: (bool didPop, Object? _) async {
        if (didPop || !state.monitoring) return;
        final bool stop = await _confirmStop(context) ?? false;
        if (!stop || !context.mounted) return;
        await ref.read(monitoringControllerProvider.notifier).stopMonitoring();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(state.hiveName.isEmpty ? '실시간 모니터링' : state.hiveName),
          actions: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              child: Center(child: ConnectionBadge(state: connection)),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: AppSpacing.screen,
            children: <Widget>[
              _CameraPreview(state: state),
              const SizedBox(height: AppSpacing.lg),
              _StatusBanner(state: state),
              const SizedBox(height: AppSpacing.lg),
              _MetricsGrid(state: state),
              const SizedBox(height: AppSpacing.lg),
              _PipelineInfo(state: state),
              if (state.uploadFailure != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                _InlineWarning(message: state.uploadFailure!.message),
              ],
              if (state.errorMessage != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                _InlineWarning(message: state.errorMessage!, severe: true),
              ],
              const SizedBox(height: AppSpacing.xl),
              if (state.monitoring)
                AppButton(
                  label: '모니터링 중지',
                  icon: Icons.stop,
                  variant: AppButtonVariant.danger,
                  onPressed: () => ref
                      .read(monitoringControllerProvider.notifier)
                      .stopMonitoring(),
                )
              else
                AppButton(
                  label: '모니터링 시작',
                  icon: Icons.play_arrow,
                  busy: state.starting,
                  onPressed: state.canStart
                      ? () => ref
                            .read(monitoringControllerProvider.notifier)
                            .startMonitoring()
                      : null,
                ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmStop(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('모니터링을 중지할까요?'),
        content: const Text('화면을 벗어나면 카메라와 마이크가 해제됩니다.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('계속 모니터링'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('중지'),
          ),
        ],
      ),
    );
  }
}

class _CameraPreview extends StatelessWidget {
  const _CameraPreview({required this.state});

  final MonitoringState state;

  @override
  Widget build(BuildContext context) {
    final CameraController? controller = state.cameraController;

    return ClipRRect(
      borderRadius: AppRadius.cardRadius,
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Container(
          color: Colors.black,
          child: controller != null && controller.value.isInitialized
              ? Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: controller.value.previewSize?.height ?? 480,
                        height: controller.value.previewSize?.width ?? 640,
                        child: CameraPreview(controller),
                      ),
                    ),
                    if (state.monitoring)
                      const Positioned(
                        top: AppSpacing.md,
                        left: AppSpacing.md,
                        child: _RecordingIndicator(),
                      ),
                  ],
                )
              : const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.videocam_off_outlined,
                        color: AppColors.textDisabled,
                        size: 36,
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Text('카메라가 준비되지 않았습니다', style: AppTypography.bodyMedium),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _RecordingIndicator extends StatelessWidget {
  const _RecordingIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: AppRadius.pillRadius,
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.circle, size: 9, color: AppColors.statusDanger),
          SizedBox(width: AppSpacing.xs),
          Text('분석 중', style: AppTypography.label),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.state});

  final MonitoringState state;

  @override
  Widget build(BuildContext context) {
    final Color accent = statusColor(state.status);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: <Widget>[
          Icon(statusIcon(state.status), color: accent, size: 30),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  state.status.label,
                  style: AppTypography.titleLarge.copyWith(color: accent),
                ),
                const SizedBox(height: 2),
                Text(
                  state.monitoring ? '모니터링 진행 중' : '모니터링 중지됨',
                  style: AppTypography.bodyMedium,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '${state.riskScore}',
                style: AppTypography.metric.copyWith(color: accent),
              ),
              const Text('위험 점수', style: AppTypography.label),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.state});

  final MonitoringState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: MetricCard(
                label: '현재 말벌 수',
                value: '${state.hornetCount}',
                unit: '마리',
                icon: Icons.bug_report_outlined,
                accent: state.hornetCount > 0 ? AppColors.statusCaution : null,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: MetricCard(
                label: '최근 최대',
                value: '${state.maxHornetCount}',
                unit: '마리',
                icon: Icons.trending_up,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: MetricCard(
                label: '탐지 신뢰도',
                value: Formatters.percent(state.confidence),
                icon: Icons.verified_outlined,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: MetricCard(
                label: '음향 위험도',
                value: Formatters.percent(state.audioProbability),
                caption: state.audioReady ? null : '마이크 미사용',
                icon: Icons.graphic_eq,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Shows that the upload pipeline is healthy, including dropped frames —
/// which is how an operator can tell a slow network from a quiet hive.
class _PipelineInfo extends StatelessWidget {
  const _PipelineInfo({required this.state});

  final MonitoringState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: <Widget>[
          _InfoRow(
            label: '온디바이스 탐지',
            value: !state.monitoring
                ? '중지됨'
                : (state.inferenceInProgress ? '분석 중' : '스트림 대기 중'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(
            label: '최근 추론 시간',
            value: state.lastDetectionAt == null
                ? '아직 없음'
                : '${state.inferenceMs} ms',
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(
            label: '탐지 모델',
            value: state.modelVersion.isEmpty
                ? '초기화 중'
                // Without this, "0마리" from the mock reads exactly like a real
                // model watching a quiet hive.
                : AppConfig.usesMockDetector
                ? '${state.modelVersion} · 실제 탐지 안 함'
                : '${state.modelVersion} · 실제 탐지 중',
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(
            label: '마지막 업로드',
            value: state.lastUploadAt == null
                ? '아직 없음'
                : '${Formatters.clockTime(state.lastUploadAt)} '
                      '(${Formatters.relativeTime(state.lastUploadAt)})',
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(
            label: '마지막 음향 업로드',
            value: state.lastAudioUploadAt == null
                ? (state.audioReady ? '대기 중' : '사용 안 함')
                : Formatters.clockTime(state.lastAudioUploadAt),
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(
            label: '전송 / 드롭 관측치',
            value:
                '${state.observationsUploaded} / ${state.observationsDropped}',
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(label, style: AppTypography.bodyMedium)),
        Text(value, style: AppTypography.bodyLarge),
      ],
    );
  }
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.message, this.severe = false});

  final String message;
  final bool severe;

  @override
  Widget build(BuildContext context) {
    final Color color = severe
        ? AppColors.statusDanger
        : AppColors.statusCaution;
    return Container(
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            severe ? Icons.error_outline : Icons.warning_amber_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message, style: AppTypography.bodyMedium)),
        ],
      ),
    );
  }
}
