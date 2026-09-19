import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/models/pairing.dart';
import '../../../core/widgets/app_button.dart';
import '../domain/pairing_controllers.dart';

/// Where a monitoring phone attaches itself to a hive.
///
/// Replaces the old flow of typing a server address and picking a hive from a
/// list: the manager's phone shows a code, this screen redeems it, and the
/// hive is remembered locally from then on.
class PairDeviceScreen extends ConsumerStatefulWidget {
  const PairDeviceScreen({super.key});

  @override
  ConsumerState<PairDeviceScreen> createState() => _PairDeviceScreenState();
}

class _PairDeviceScreenState extends ConsumerState<PairDeviceScreen> {
  late final TextEditingController _codeController;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
    // Reopening after a failure should start clean.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(claimControllerProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ClaimState state = ref.watch(claimControllerProvider);

    // A successful claim leaves the screen for monitoring setup.
    ref.listen<ClaimState>(claimControllerProvider, (
      ClaimState? previous,
      ClaimState next,
    ) {
      if (next.succeeded && !(previous?.succeeded ?? false)) {
        _onPaired(next.paired!);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('모니터링 기기 연결')),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screen,
          children: <Widget>[
            const Text(
              '관리자 스마트폰에서 벌통을 선택하고 "모니터링 기기 연결"을 누르면 '
              'QR 코드와 6자리 코드가 표시됩니다.',
              style: AppTypography.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'QR 코드 스캔',
              icon: Icons.qr_code_scanner,
              onPressed: state.submitting ? null : _scan,
            ),
            const SizedBox(height: AppSpacing.xl),
            const Row(
              children: <Widget>[
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Text('또는', style: AppTypography.label),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text('6자리 코드 입력', style: AppTypography.label),
            const SizedBox(height: AppSpacing.sm),
            _CodeField(
              controller: _codeController,
              enabled: !state.submitting,
              onChanged: (String value) {
                ref.read(claimControllerProvider.notifier).codeChanged();
                setState(() {});
                // Submit the moment six digits are in, so the beekeeper does
                // not have to reach for a button.
                if (isCompletePairingCode(value)) _submit(value);
              },
              onSubmitted: _submit,
            ),
            if (state.failure != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              _FailureBanner(failure: state.failure!),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: '연결하기',
              icon: Icons.link,
              busy: state.submitting,
              onPressed: isCompletePairingCode(_codeController.text)
                  ? () => _submit(_codeController.text)
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              '코드는 발급 후 10분간만 사용할 수 있으며, 한 번 사용하면 만료됩니다.',
              style: AppTypography.label,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scan() async {
    final String? scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (BuildContext context) => const _QrScannerScreen(),
      ),
    );
    if (!mounted || scanned == null) return;

    _codeController.text = scanned;
    setState(() {});
    await _submit(scanned);
  }

  Future<void> _submit(String code) async {
    FocusScope.of(context).unfocus();
    await ref.read(claimControllerProvider.notifier).submit(code);
  }

  void _onPaired(PairedHive paired) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${paired.hiveName}에 연결되었습니다.')),
    );
    // Replace rather than push: there is nothing useful to go back to.
    context.go(Routes.monitorSetup);
  }
}

/// A single field that reads as six boxes.
///
/// One [TextEditingController] rather than six fields — six controllers means
/// six focus transitions to get wrong, and the boxes here are purely visual.
class _CodeField extends StatelessWidget {
  const _CodeField({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    this.enabled = true,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        // The boxes are decoration; the real field sits on top, transparent.
        IgnorePointer(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List<Widget>.generate(pairingCodeLength, (int index) {
              final String digit = index < controller.text.length
                  ? controller.text[index]
                  : '';
              final bool isNext = index == controller.text.length;
              return Container(
                width: 46,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.cardRadius,
                  border: Border.all(
                    color: isNext && enabled
                        ? AppColors.primary
                        : AppColors.outline,
                    width: isNext && enabled ? 1.6 : 1,
                  ),
                ),
                child: Text(digit, style: AppTypography.metric),
              );
            }),
          ),
        ),
        Opacity(
          opacity: 0,
          child: TextField(
            controller: controller,
            enabled: enabled,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: pairingCodeLength,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(pairingCodeLength),
            ],
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            decoration: const InputDecoration(counterText: ''),
          ),
        ),
      ],
    );
  }
}

class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.failure});

  final PairingFailure failure;

  @override
  Widget build(BuildContext context) {
    // A code that can never work again is shown as an error; one worth
    // retrying is shown as a caution.
    final bool fatal = !failure.isRetryableWithSameCode &&
        failure != PairingFailure.invalidCode;
    final Color color =
        fatal ? AppColors.statusDanger : AppColors.statusCaution;

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
            fatal ? Icons.error_outline : Icons.warning_amber_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(failure.message, style: AppTypography.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// Full-screen camera view that pops the pairing code it finds.
///
/// Ignores QR codes that are not ours, so pointing the phone at an unrelated
/// code does nothing rather than reporting an error for each frame.
class _QrScannerScreen extends StatefulWidget {
  const _QrScannerScreen();

  @override
  State<_QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<_QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
  );

  /// Guards against the detector firing again while the route is popping.
  bool _handled = false;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR 코드 스캔')),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            // A camera that cannot start must not leave a blank screen.
            errorBuilder: (
              BuildContext context,
              MobileScannerException error,
            ) =>
                _ScannerError(error: error),
          ),
          _ScannerOverlay(),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    for (final Barcode barcode in capture.barcodes) {
      final String? code = parsePairCode(barcode.rawValue);
      if (code == null) continue;

      _handled = true;
      Navigator.of(context).pop(code);
      return;
    }
  }
}

class _ScannerOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            color: Colors.black.withValues(alpha: 0.55),
            child: const Text(
              '관리자 스마트폰에 표시된 QR 코드를 비춰주세요.',
              style: AppTypography.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.no_photography_outlined,
                size: 44,
                color: AppColors.statusDanger,
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                '카메라를 사용할 수 없습니다.',
                style: AppTypography.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                '카메라 권한을 허용했는지 확인하거나, 뒤로 돌아가 6자리 코드를 '
                '직접 입력해주세요.',
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: '코드 직접 입력',
                variant: AppButtonVariant.secondary,
                expand: false,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
