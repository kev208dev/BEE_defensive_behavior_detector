import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/models/pairing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/error_state.dart';
import '../domain/pairing_controllers.dart';

/// Shows the pairing sheet for [hiveId] and waits for it to close.
///
/// A bottom sheet rather than a route: pairing is a short, modal errand
/// started from a hive the manager is already looking at, and the spec asks
/// not to add screens without cause.
Future<void> showPairingSheet(
  BuildContext context, {
  required String hiveId,
  required String hiveName,
}) {
  return showModalBackgroundSheet(
    context,
    child: _PairingSheet(hiveId: hiveId, hiveName: hiveName),
  );
}

/// Thin wrapper so the sheet's chrome is defined in one place.
Future<void> showModalBackgroundSheet(
  BuildContext context, {
  required Widget child,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (BuildContext context) => SafeArea(child: child),
  );
}

class _PairingSheet extends ConsumerStatefulWidget {
  const _PairingSheet({required this.hiveId, required this.hiveName});

  final String hiveId;
  final String hiveName;

  @override
  ConsumerState<_PairingSheet> createState() => _PairingSheetState();
}

class _PairingSheetState extends ConsumerState<_PairingSheet> {
  @override
  void initState() {
    super.initState();
    // Request the first code once the sheet is mounted, so it can show its
    // loading state rather than appearing frozen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(pairingSheetControllerProvider.notifier).start(widget.hiveId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final PairingSheetState state = ref.watch(pairingSheetControllerProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('모니터링 기기 연결', style: AppTypography.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${widget.hiveName} 앞에 둘 스마트폰에서 아래 코드를 스캔하거나 입력하세요.',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          _SheetBody(state: state),
        ],
      ),
    );
  }
}

class _SheetBody extends ConsumerWidget {
  const _SheetBody({required this.state});

  final PairingSheetState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.failure != null) {
      return ErrorState(
        failure: state.failure!,
        onRetry: () =>
            ref.read(pairingSheetControllerProvider.notifier).issueCode(),
      );
    }

    if (state.loading || state.session == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.isClaimed) {
      return _ClaimedView(session: state.session!);
    }

    if (state.isExpired) {
      return _ExpiredView(
        onReissue: () =>
            ref.read(pairingSheetControllerProvider.notifier).issueCode(),
      );
    }

    return _WaitingView(state: state);
  }
}

class _WaitingView extends StatelessWidget {
  const _WaitingView({required this.state});

  final PairingSheetState state;

  @override
  Widget build(BuildContext context) {
    final PairingSession session = state.session!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // The QR sits on white regardless of theme — scanners need the
        // contrast, and a dark-on-dark code simply will not read.
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.cardRadius,
          ),
          child: QrImageView(
            data: session.effectivePairUri,
            version: QrVersions.auto,
            size: 190,
            backgroundColor: Colors.white,
            // Keeps the code readable if part of it is obscured on screen.
            errorCorrectionLevel: QrErrorCorrectLevel.M,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const Text('또는 6자리 코드 입력', style: AppTypography.label),
        const SizedBox(height: AppSpacing.sm),
        Text(
          session.formattedCode,
          style: AppTypography.displayLarge.copyWith(
            letterSpacing: 8,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${PairingStatus.waiting.label} · ${state.formattedRemaining} 남음',
              style: AppTypography.bodyMedium,
            ),
          ],
        ),
      ],
    );
  }
}

class _ClaimedView extends StatelessWidget {
  const _ClaimedView({required this.session});

  final PairingSession session;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(
          Icons.check_circle_outline,
          size: 56,
          color: AppColors.statusNormal,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          '연결 완료',
          style: AppTypography.titleLarge.copyWith(
            color: AppColors.statusNormal,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${session.hiveName.isEmpty ? '벌통' : session.hiveName}에 모니터링 기기가 '
          '연결되었습니다. 해당 기기에서 모니터링을 시작하세요.',
          style: AppTypography.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: '닫기',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _ExpiredView extends StatelessWidget {
  const _ExpiredView({required this.onReissue});

  final VoidCallback onReissue;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(
          Icons.timer_off_outlined,
          size: 48,
          color: AppColors.statusCaution,
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text('코드가 만료되었습니다', style: AppTypography.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          '보안을 위해 코드는 10분 후 만료됩니다. 새 코드를 발급받아주세요.',
          style: AppTypography.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: '새 코드 발급',
          icon: Icons.refresh,
          onPressed: onReissue,
        ),
      ],
    );
  }
}
