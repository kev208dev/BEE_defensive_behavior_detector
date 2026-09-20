import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../domain/camera_service.dart';
import '../domain/camera_geometry.dart';
import '../domain/preview_geometry.dart';
import '../domain/on_device_hornet_detector.dart';
import '../domain/detection_roi.dart';
import '../domain/detection_roi_controller.dart';
import '../domain/monitoring_controller.dart';

/// Lets the beekeeper mark where the hive entrance is in frame.
///
/// This is the highest-value control in the app for detection quality. The
/// model has a fixed 640x640 input, so a hornet occupying a small part of a
/// wide camera frame lands on too few input pixels to be found at all —
/// measured, not assumed: below roughly 46px of hornet width in a 1920px frame
/// the model stops producing candidates entirely, and no confidence threshold
/// can bring them back. Cropping to the entrance first restores detection at
/// full confidence for the same inference cost.
class DetectionAreaScreen extends ConsumerStatefulWidget {
  const DetectionAreaScreen({super.key});

  @override
  ConsumerState<DetectionAreaScreen> createState() =>
      _DetectionAreaScreenState();
}

class _DetectionAreaScreenState extends ConsumerState<DetectionAreaScreen> {
  CameraService? _camera;
  CameraController? _controller;
  String? _error;
  late DetectionRoi _draft;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(detectionRoiProvider);
    unawaited(_openPreview());
  }

  Future<void> _openPreview() async {
    // A preview of its own, so this screen never borrows the monitoring
    // camera and cannot leave it running when the user backs out.
    final CameraService camera = ref.read(cameraServiceFactoryProvider)();
    final String? error = await camera.initialise();
    if (!mounted) {
      await camera.dispose();
      return;
    }
    if (error != null) {
      await camera.dispose();
      setState(() => _error = error);
      return;
    }
    setState(() {
      _camera = camera;
      _controller = camera.controller;
    });
  }

  @override
  void dispose() {
    unawaited(_camera?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('탐지 영역 설정')),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screen,
          children: <Widget>[
            const Text(
              '벌통 입구가 사각형 안에 가득 차도록 맞춰주세요. 표시한 영역만 분석하므로, '
              '영역이 좁을수록 작은 말벌도 탐지됩니다.',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            _PreviewWithRegion(
              controller: _controller,
              error: _error,
              roi: _draft,
              onChanged: (DetectionRoi roi) => setState(() => _draft = roi),
            ),
            const SizedBox(height: AppSpacing.md),
            _CoverageHint(roi: _draft),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: '이 영역으로 저장',
              icon: Icons.check,
              onPressed: () => unawaited(_save()),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: '전체 화면으로 되돌리기',
              icon: Icons.fullscreen,
              variant: AppButtonVariant.secondary,
              onPressed: _draft.isFullFrame
                  ? null
                  : () => setState(() => _draft = DetectionRoi.full),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    await ref.read(detectionRoiProvider.notifier).set(_draft);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_draft.isFullFrame ? '전체 화면을 분석합니다.' : '표시한 영역만 분석합니다.'),
      ),
    );
    Navigator.of(context).pop();
  }
}

/// Camera preview with the region drawn on top and draggable.
class _PreviewWithRegion extends StatelessWidget {
  const _PreviewWithRegion({
    required this.controller,
    required this.error,
    required this.roi,
    required this.onChanged,
  });

  final CameraController? controller;
  final String? error;
  final DetectionRoi roi;
  final ValueChanged<DetectionRoi> onChanged;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.cardRadius,
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: ColoredBox(
          color: Colors.black,
          child: error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      error!,
                      style: AppTypography.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : controller == null || !controller!.value.isInitialized
              ? const Center(child: CircularProgressIndicator())
              : ValueListenableBuilder<CameraValue>(
                  valueListenable: controller!,
                  builder: (context, value, _) => Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: cameraPreviewSize(value).width,
                          height: cameraPreviewSize(value).height,
                          child: CameraPreview(controller!),
                        ),
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final Size image = cameraPreviewSize(value);
                          final Size viewport = constraints.biggest;
                          final PreviewGeometry cover = PreviewGeometry.cover(
                            image: image,
                            viewport: viewport,
                          );
                          final CameraRectTransform transform = sensorToPreview(
                            controller!.description,
                            previewOrientation(value),
                          );
                          final DetectionRoi oriented = transform.roi(roi);
                          final Rect visible = cover
                              .rectFor(
                                OnDeviceDetection(
                                  x: oriented.x,
                                  y: oriented.y,
                                  width: oriented.width,
                                  height: oriented.height,
                                  confidence: 1,
                                  className: '',
                                ),
                                image: image,
                              )
                              .intersect(Offset.zero & viewport);
                          return RegionEditor(
                            roi: DetectionRoi.clamped(
                              x: visible.left / viewport.width,
                              y: visible.top / viewport.height,
                              width: visible.width / viewport.width,
                              height: visible.height / viewport.height,
                            ),
                            onChanged: (selected) {
                              final Rect preview = cover.normalizedRect(
                                Rect.fromLTWH(
                                  selected.x * viewport.width,
                                  selected.y * viewport.height,
                                  selected.width * viewport.width,
                                  selected.height * viewport.height,
                                ),
                                image: image,
                              );
                              onChanged(
                                CameraRectTransform.roiFromRect(
                                  transform.inverseRect(preview),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// A draggable, resizable rectangle expressed in normalized coordinates.
///
/// Kept separate from the camera so it can be exercised without one.
@visibleForTesting
class RegionEditor extends StatelessWidget {
  const RegionEditor({required this.roi, required this.onChanged, super.key});

  /// Side of the corner grab handle, in logical pixels.
  static const double handleSize = 28;

  final DetectionRoi roi;
  final ValueChanged<DetectionRoi> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        final Rect rect = Rect.fromLTWH(
          roi.x * width,
          roi.y * height,
          roi.width * width,
          roi.height * height,
        );

        return Stack(
          children: <Widget>[
            // Dim everything the detector will not look at, so the chosen
            // region reads at a glance.
            IgnorePointer(
              child: CustomPaint(
                size: Size(width, height),
                painter: _RegionPainter(rect: rect),
              ),
            ),
            Positioned(
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanUpdate: (DragUpdateDetails details) => onChanged(
                  DetectionRoi.clamped(
                    x: roi.x + details.delta.dx / width,
                    y: roi.y + details.delta.dy / height,
                    width: roi.width,
                    height: roi.height,
                  ),
                ),
              ),
            ),
            Positioned(
              left: rect.right - handleSize / 2,
              top: rect.bottom - handleSize / 2,
              width: handleSize,
              height: handleSize,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (DragUpdateDetails details) => onChanged(
                  DetectionRoi.clamped(
                    x: roi.x,
                    y: roi.y,
                    width: roi.width + details.delta.dx / width,
                    height: roi.height + details.delta.dy / height,
                  ),
                ),
                child: const _CornerHandle(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CornerHandle extends StatelessWidget {
  const _CornerHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
  }
}

class _RegionPainter extends CustomPainter {
  const _RegionPainter({required this.rect});

  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint shade = Paint()..color = Colors.black.withValues(alpha: 0.55);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRect(rect),
      ),
      shade,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.primary,
    );
  }

  @override
  bool shouldRepaint(_RegionPainter oldDelegate) => oldDelegate.rect != rect;
}

/// Says plainly how much of the frame is being analysed.
class _CoverageHint extends StatelessWidget {
  const _CoverageHint({required this.roi});

  final DetectionRoi roi;

  @override
  Widget build(BuildContext context) {
    final int percent = (roi.width * roi.height * 100).round();
    final bool wide = roi.isFullFrame;
    return Container(
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            wide ? Icons.warning_amber_rounded : Icons.center_focus_strong,
            size: 18,
            color: wide ? AppColors.statusCaution : AppColors.statusNormal,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              wide
                  ? '화면 전체를 분석합니다. 벌통 입구가 작게 보이면 말벌이 탐지되지 않을 수 있습니다.'
                  : '화면의 약 $percent%만 분석합니다.',
              style: AppTypography.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
