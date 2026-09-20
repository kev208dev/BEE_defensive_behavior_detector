import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/hive_status.dart';
import '../../../core/models/pairing.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/section_header.dart';
import '../../alerts/domain/alert_watcher.dart';
import '../../mode_selection/domain/mode_controller.dart';
import '../../monitoring/domain/monitoring_controller.dart';
import '../../pairing/domain/pairing_controllers.dart';

/// Runtime settings.
///
/// Note what is *not* here: a server address field. Beekeepers pair their
/// phones with a code, so the backend URL is build configuration rather than
/// something a user should ever see or type. In a debug build it is shown
/// read-only under a developer section, purely as a diagnostic.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppMode? mode = ref.watch(appModeProvider);
    final BackendConnectionState connection = ref.watch(connectionProvider);
    final AlertWatcherState watcher = ref.watch(alertWatcherProvider);
    final PairedHive? paired = ref.watch(pairedHiveProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: AppSpacing.screen,
        children: <Widget>[
          const SectionHeader(title: '역할'),
          _Card(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    mode?.label ?? '선택되지 않음',
                    style: AppTypography.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => _changeMode(context, ref),
                  child: const Text('변경'),
                ),
              ],
            ),
          ),
          SectionHeader(
            title: mode == AppMode.monitoring ? '연결된 벌통' : '모니터링 기기',
          ),
          if (mode == AppMode.monitoring)
            _PairingCard(paired: paired)
          else
            const _ManagerPairingInfo(),
          const SectionHeader(title: '서버 연결'),
          _Card(
            child: Row(
              children: <Widget>[
                ConnectionBadge(state: connection),
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      ref.read(connectionProvider.notifier).check(),
                  child: const Text('다시 확인'),
                ),
              ],
            ),
          ),
          const SectionHeader(title: '동작 설정'),
          const _InfoTile(
            label: '온디바이스 분석 주기',
            value: '${AppConfig.analysisIntervalMs}ms',
          ),
          const _InfoTile(
            label: '오디오 청크 길이',
            value: '${AppConfig.audioChunkSeconds}초',
          ),
          const _InfoTile(
            label: 'Heartbeat 주기',
            value: '${AppConfig.heartbeatIntervalSeconds}초',
          ),
          const _InfoTile(
            label: '경보 폴링 주기',
            value: '${AppConfig.alertPollIntervalSeconds}초',
          ),
          _InfoTile(
            label: '탐지 모델 모드',
            value: AppConfig.usesMockDetector
                ? '${AppConfig.modelMode} (실제 탐지 안 함)'
                : '${AppConfig.modelMode} (실제 탐지 중)',
          ),
          _InfoTile(
            label: '경보 감시',
            value: watcher.watching
                ? '동작 중 (새 경보 ${watcher.newAlertCount}건)'
                : '중지됨',
          ),
          // Diagnostics that would only confuse a beekeeper, shown in debug
          // builds so a developer can confirm which backend a build points at.
          if (kDebugMode) ...<Widget>[
            const SectionHeader(
              title: '개발자 정보',
              subtitle: 'debug 빌드에서만 표시됩니다.',
            ),
            _InfoTile(label: '서버 주소', value: ref.watch(baseUrlProvider)),
            const _InfoTile(
              label: '데모 모드',
              value: AppConfig.demoMode ? '켜짐 (서버 미사용)' : '꺼짐',
            ),
            _InfoTile(label: '기기 ID', value: ref.watch(deviceIdProvider)),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              '서버 주소는 빌드 시 --dart-define=API_BASE_URL=... 로만 변경할 수 '
              '있습니다.',
              style: AppTypography.label,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Future<void> _changeMode(BuildContext context, WidgetRef ref) async {
    // Monitoring must be torn down before the role changes, or the camera
    // would keep running behind the manager UI.
    await ref.read(monitoringControllerProvider.notifier).stopMonitoring();
    ref.read(alertWatcherProvider.notifier).stop();
    await ref.read(appModeProvider.notifier).clear();
    if (!context.mounted) return;
    context.go(Routes.mode);
  }
}

class _ManagerPairingInfo extends StatelessWidget {
  const _ManagerPairingInfo();

  @override
  Widget build(BuildContext context) {
    return const _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, color: AppColors.primary),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              '모니터링 기기는 벌통 상세에서 연결할 수 있습니다.',
              style: AppTypography.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the paired hive, or an invitation to pair when there is none.
class _PairingCard extends ConsumerWidget {
  const _PairingCard({required this.paired});

  final PairedHive? paired;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PairedHive? current = paired;

    if (current == null) {
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('연결된 벌통이 없습니다', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              '관리자 스마트폰에서 발급한 코드로 이 기기를 벌통에 연결하세요.',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: '벌통 연결하기',
              icon: Icons.qr_code_scanner,
              variant: AppButtonVariant.secondary,
              onPressed: () => context.push(Routes.pair),
            ),
          ],
        ),
      );
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.link, size: 18, color: AppColors.statusNormal),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(current.hiveName, style: AppTypography.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('ID: ${current.hiveId}', style: AppTypography.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton(
                  label: '연결 해제',
                  icon: Icons.link_off,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => _confirmUnpair(context, ref),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmUnpair(BuildContext context, WidgetRef ref) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('연결을 해제할까요?'),
            content: const Text(
              '이 기기와 벌통의 연결이 끊어집니다. 다시 연결하려면 새 코드가 '
              '필요합니다.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('연결 해제'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !context.mounted) return;

    // Stop monitoring first — continuing to upload frames for a hive this
    // phone is no longer paired to would be wrong.
    await ref.read(monitoringControllerProvider.notifier).stopMonitoring();
    await ref.read(pairedHiveProvider.notifier).unpair();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('연결이 해제되었습니다.')));
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.outline),
      ),
      child: child,
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: AppTypography.bodyMedium)),
          Flexible(
            child: Text(
              value,
              style: AppTypography.bodyLarge,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
