import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/models/pairing.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/section_header.dart';
import '../../pairing/domain/pairing_controllers.dart';
import '../domain/monitoring_controller.dart';
import '../domain/monitoring_state.dart';
import '../domain/permission_service.dart';

/// Prepares this phone for monitoring: pick a hive, grant permissions, check
/// the server, start.
class MonitoringSetupScreen extends ConsumerStatefulWidget {
  const MonitoringSetupScreen({super.key});

  @override
  ConsumerState<MonitoringSetupScreen> createState() =>
      _MonitoringSetupScreenState();
}

class _MonitoringSetupScreenState
    extends ConsumerState<MonitoringSetupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  Future<void> _prepare() async {
    if (!mounted) return;
    final MonitoringController controller =
        ref.read(monitoringControllerProvider.notifier);
    await controller.refreshPermissions();
    await controller.checkConnection();

    // The hive comes from the pairing, which survives restarts — a phone that
    // reboots overnight comes straight back up on the same hive with nothing
    // to re-enter.
    final PairedHive? paired = ref.read(pairedHiveProvider);
    if (paired != null) {
      controller.selectHive(hiveId: paired.hiveId, hiveName: paired.hiveName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final MonitoringState state = ref.watch(monitoringControllerProvider);
    final PairedHive? paired = ref.watch(pairedHiveProvider);
    final BackendConnectionState connection = ref.watch(connectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('모니터링 설정'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '설정',
            onPressed: () => context.push(Routes.settings),
          ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.screen,
        children: <Widget>[
          const Text(
            '이 스마트폰을 벌통 앞에 고정한 뒤 모니터링을 시작하세요.',
            style: AppTypography.bodyLarge,
          ),
          const SectionHeader(title: '연결된 벌통'),
          _PairedHiveCard(paired: paired),
          const SectionHeader(title: '권한'),
          _PermissionRow(
            icon: Icons.camera_alt_outlined,
            label: '카메라',
            description: '벌통 앞 영상을 분석합니다. 필수입니다.',
            permission: state.cameraPermission,
          ),
          const SizedBox(height: AppSpacing.md),
          _PermissionRow(
            icon: Icons.mic_none,
            label: '마이크',
            description: '날갯짓 소리를 분석합니다. 없어도 영상만으로 동작합니다.',
            permission: state.microphonePermission,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton(
                  label: '권한 요청',
                  icon: Icons.lock_open,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => ref
                      .read(monitoringControllerProvider.notifier)
                      .requestPermissions(),
                ),
              ),
              if (state.cameraPermission ==
                      PermissionState.permanentlyDenied ||
                  state.microphonePermission ==
                      PermissionState.permanentlyDenied) ...<Widget>[
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppButton(
                    label: '설정 열기',
                    icon: Icons.settings,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => ref
                        .read(monitoringControllerProvider.notifier)
                        .openAppSettings(),
                  ),
                ),
              ],
            ],
          ),
          const SectionHeader(title: '서버 연결'),
          _ConnectionRow(connection: connection),
          if (state.errorMessage != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.statusDanger.withValues(alpha: 0.12),
                borderRadius: AppRadius.cardRadius,
                border: Border.all(
                  color: AppColors.statusDanger.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.statusDanger,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: AppTypography.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: '모니터링 시작',
            icon: Icons.play_arrow,
            busy: state.starting,
            onPressed: state.canStart ? _start : null,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            state.hiveId == null
                ? '벌통에 연결하면 시작할 수 있습니다.'
                : '화면이 켜진 상태에서 동작합니다. 절전 모드를 해제해 두세요.',
            style: AppTypography.label,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Future<void> _start() async {
    final bool started =
        await ref.read(monitoringControllerProvider.notifier).startMonitoring();
    if (!mounted || !started) return;
    if (!context.mounted) return;
    // The live screen is pushed, not replaced, so Back returns here.
    unawaited(context.push(Routes.monitorLive));
  }
}

/// Shows which hive this phone is paired to, with a way to re-pair.
///
/// There is no hive picker any more: the binding is established by code, so
/// the phone cannot be pointed at the wrong hive by a mis-tap here.
class _PairedHiveCard extends ConsumerWidget {
  const _PairedHiveCard({required this.paired});

  final PairedHive? paired;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PairedHive? current = paired;

    if (current == null) {
      return Container(
        padding: AppSpacing.card,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('연결된 벌통이 없습니다', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              '관리자 스마트폰에서 벌통을 선택하고 발급한 코드로 연결하세요.',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: '벌통 연결하기',
              icon: Icons.qr_code_scanner,
              onPressed: () => unawaited(context.push(Routes.pair)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.primary),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.link, size: 20, color: AppColors.statusNormal),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(current.hiveName, style: AppTypography.titleMedium),
                const SizedBox(height: 2),
                const Text(
                  '이 기기는 이 벌통을 관찰합니다.',
                  style: AppTypography.bodyMedium,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => unawaited(context.push(Routes.settings)),
            child: const Text('변경'),
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.permission,
  });

  final IconData icon;
  final String label;
  final String description;
  final PermissionState permission;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (permission) {
      PermissionState.granted => AppColors.statusNormal,
      PermissionState.denied => AppColors.statusCaution,
      PermissionState.permanentlyDenied => AppColors.statusDanger,
      PermissionState.unknown => AppColors.textSecondary,
    };

    return Container(
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: AppTypography.titleMedium),
                const SizedBox(height: 2),
                Text(description, style: AppTypography.bodyMedium),
              ],
            ),
          ),
          Text(
            permission.label,
            style: AppTypography.label.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _ConnectionRow extends ConsumerWidget {
  const _ConnectionRow({required this.connection});

  final BackendConnectionState connection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: <Widget>[
          // Deliberately no server address here — it is build configuration,
          // not something a beekeeper should read or act on.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ConnectionBadge(state: connection),
                const SizedBox(height: 2),
                Text(
                  connection.isConnected
                      ? '분석 서버와 통신할 수 있습니다.'
                      : '서버에 연결되면 모니터링을 시작할 수 있습니다.',
                  style: AppTypography.bodyMedium,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () =>
                ref.read(monitoringControllerProvider.notifier).checkConnection(),
            child: const Text('다시 확인'),
          ),
        ],
      ),
    );
  }
}
