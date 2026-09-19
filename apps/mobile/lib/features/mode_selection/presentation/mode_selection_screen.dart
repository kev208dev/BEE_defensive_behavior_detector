import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/hive_status.dart';
import '../domain/mode_controller.dart';

/// The first screen: which role is this phone playing?
///
/// No accounts, no login — the spec calls for none, and a phone being taped to
/// a hive in a field should be usable in ten seconds.
class ModeSelectionScreen extends ConsumerWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: AppSpacing.xxl),
              const Text('벌통 지킴이', style: AppTypography.displayLarge),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                '스마트폰 카메라와 마이크로 말벌 집단 공격을 조기에 감지합니다.',
                style: AppTypography.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.xxl),
              const Text('이 스마트폰의 역할을 선택하세요', style: AppTypography.label),
              const SizedBox(height: AppSpacing.md),
              _ModeCard(
                icon: Icons.videocam_outlined,
                title: AppMode.monitoring.label,
                description: '벌통 앞에 고정해 두고 카메라와 마이크로 상황을 관찰합니다.',
                onTap: () => _select(context, ref, AppMode.monitoring),
              ),
              const SizedBox(height: AppSpacing.md),
              _ModeCard(
                icon: Icons.notifications_active_outlined,
                title: AppMode.manager.label,
                description: '가지고 다니며 모든 벌통의 상태와 경보를 확인합니다.',
                onTap: () => _select(context, ref, AppMode.manager),
              ),
              const Spacer(),
              const Row(
                children: <Widget>[
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: AppColors.textDisabled,
                  ),
                  SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      AppConfig.demoMode
                          ? '데모 모드 — 서버 없이 화면만 확인합니다.'
                          : '역할은 설정 화면에서 언제든 변경할 수 있습니다.',
                      style: AppTypography.label,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _select(
    BuildContext context,
    WidgetRef ref,
    AppMode mode,
  ) async {
    await ref.read(appModeProvider.notifier).select(mode);
    if (!context.mounted) return;

    context.go(
      mode == AppMode.monitoring ? Routes.monitorSetup : Routes.dashboard,
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  borderRadius: AppRadius.cardRadius,
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: AppTypography.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(description, style: AppTypography.bodyMedium),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textDisabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
