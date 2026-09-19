import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../errors/failure.dart';
import 'app_button.dart';

/// Shown when a load failed.
///
/// Takes a [Failure] so the copy and the retry affordance follow from *why*
/// it failed — a 404 has no useful retry, a timeout does.
class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.failure,
    this.onRetry,
    super.key,
  });

  final Failure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final IconData icon = switch (failure.kind) {
      FailureKind.network || FailureKind.timeout => Icons.wifi_off,
      FailureKind.notFound => Icons.search_off,
      FailureKind.permission => Icons.lock_outline,
      _ => Icons.error_outline,
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 44, color: AppColors.statusDanger),
            const SizedBox(height: AppSpacing.lg),
            Text(
              failure.message,
              style: AppTypography.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (failure.isConnectivityProblem) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              const Text(
                '설정 화면에서 서버 주소를 확인할 수 있습니다.',
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: '다시 시도',
                icon: Icons.refresh,
                onPressed: onRetry,
                variant: AppButtonVariant.secondary,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
