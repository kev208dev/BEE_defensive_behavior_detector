import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/models/hive.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../hives/domain/hive_controllers.dart';
import '../../mode_selection/domain/mode_controller.dart';
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

    // Restore the previously chosen hive, so a phone that restarts overnight
    // comes back watching the same hive.
    final String? savedId = ref.read(selectedHiveIdProvider);
    if (savedId != null && ref.read(monitoringControllerProvider).hiveId == null) {
      final List<Hive>? hives = ref.read(hiveListControllerProvider).value;
      final Hive? saved = hives?.where((Hive h) => h.id == savedId).firstOrNull;
      if (saved != null) {
        controller.selectHive(hiveId: saved.id, hiveName: saved.name);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final MonitoringState state = ref.watch(monitoringControllerProvider);
    final AsyncValue<List<Hive>> hives = ref.watch(hiveListControllerProvider);
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
            '이 스마트폰을 벌통 앞에 고정하고, 관찰할 벌통을 선택하세요.',
            style: AppTypography.bodyLarge,
          ),
          const SectionHeader(title: '벌통 선택'),
          _HiveSelector(hives: hives, selectedId: state.hiveId),
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
                ? '벌통을 선택하면 시작할 수 있습니다.'
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

class _HiveSelector extends ConsumerWidget {
  const _HiveSelector({required this.hives, required this.selectedId});

  final AsyncValue<List<Hive>> hives;
  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return hives.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace stackTrace) => ErrorState(
        failure: ErrorMapper.map(error, stackTrace),
        onRetry: () => ref.read(hiveListControllerProvider.notifier).refresh(),
      ),
      data: (List<Hive> items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.hive_outlined,
            message: '등록된 벌통이 없습니다. 백엔드 seed 데이터를 확인해주세요.',
          );
        }

        return Column(
          children: items.map((Hive hive) {
            final bool selected = hive.id == selectedId;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Material(
                color: AppColors.surface,
                borderRadius: AppRadius.cardRadius,
                child: InkWell(
                  borderRadius: AppRadius.cardRadius,
                  onTap: () {
                    ref.read(monitoringControllerProvider.notifier).selectHive(
                          hiveId: hive.id,
                          hiveName: hive.name,
                        );
                    ref.read(selectedHiveIdProvider.notifier).select(hive.id);
                  },
                  child: Container(
                    padding: AppSpacing.card,
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.cardRadius,
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.outline,
                        width: selected ? 1.6 : 1,
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textDisabled,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                hive.name,
                                style: AppTypography.titleMedium,
                              ),
                              if (hive.location.isNotEmpty)
                                Text(
                                  hive.location,
                                  style: AppTypography.bodyMedium,
                                ),
                            ],
                          ),
                        ),
                        StatusBadge(status: hive.status, compact: true),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ConnectionBadge(state: connection),
                const SizedBox(height: 2),
                Text(
                  ref.watch(baseUrlProvider),
                  style: AppTypography.bodyMedium,
                  overflow: TextOverflow.ellipsis,
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
