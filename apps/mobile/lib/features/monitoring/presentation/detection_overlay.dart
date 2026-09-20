import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../domain/detection_tracker.dart';
import '../domain/on_device_hornet_detector.dart';
import '../domain/preview_geometry.dart';

/// Colours for the two classes the VespAI model distinguishes.
///
/// Kept here rather than in the painter so a design pass can restyle the
/// overlay without touching the geometry.
abstract final class DetectionColors {
  /// European hornet — the resident species, amber.
  static const Color crabro = Color(0xFFFFB020);

  /// Asian hornet — the invasive one this system exists to catch, red.
  static const Color velutina = Color(0xFFFF4D4F);

  static Color forClass(String className) =>
      className.toLowerCase().contains('velutina') ? velutina : crabro;
}

/// Draws tracked detections over the camera preview.
///
/// Boxes are placed through [PreviewGeometry] rather than by scaling the
/// normalized coordinates to the widget size, because the preview is drawn
/// with `BoxFit.cover` and therefore crops: a naive scale puts every box in
/// the wrong place, worst at the edges where a hornet enters frame.
class DetectionOverlay extends StatelessWidget {
  const DetectionOverlay({
    required this.detections,
    required this.imageSize,
    super.key,
  });

  final List<TrackedDetection> detections;

  /// The camera image size, in the orientation the preview lays it out.
  final Size? imageSize;

  @override
  Widget build(BuildContext context) {
    final Size? image = imageSize;
    if (image == null || detections.isEmpty) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: DetectionPainter(
              detections: detections,
              imageSize: image,
            ),
          );
        },
      ),
    );
  }
}

@visibleForTesting
class DetectionPainter extends CustomPainter {
  const DetectionPainter({required this.detections, required this.imageSize});

  final List<TrackedDetection> detections;
  final Size imageSize;

  @override
  void paint(Canvas canvas, Size size) {
    final PreviewGeometry geometry = PreviewGeometry.cover(
      image: imageSize,
      viewport: size,
    );
    canvas.clipRect(Offset.zero & size);

    for (final TrackedDetection track in detections) {
      final OnDeviceDetection detection = track.detection;
      final Rect rect = geometry.rectFor(detection, image: imageSize);
      if (!geometry.isVisible(rect)) continue;

      final Color color = DetectionColors.forClass(detection.className);
      // A held-over box is drawn faded, so the operator can tell a live
      // detection from one the tracker is carrying through a missed frame.
      final double opacity = track.isCurrent ? 1.0 : 0.45;

      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = color.withValues(alpha: opacity),
      );
      _paintLabel(canvas, size, rect, detection, color, opacity);
    }
  }

  void _paintLabel(
    Canvas canvas,
    Size size,
    Rect rect,
    OnDeviceDetection detection,
    Color color,
    double opacity,
  ) {
    final TextPainter text = TextPainter(
      text: TextSpan(
        text: '${detection.className} '
            '${detection.confidence.toStringAsFixed(2)}',
        style: TextStyle(
          color: Colors.white.withValues(alpha: opacity),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const double padding = 4;
    final double labelWidth = text.width + padding * 2;
    final double labelHeight = text.height + padding;
    // Above the box normally, inside it when the box is against the top edge.
    final double top = rect.top - labelHeight >= 0
        ? rect.top - labelHeight
        : rect.top;
    final double left = rect.left.clamp(0.0, (size.width - labelWidth).clamp(0.0, size.width));

    final Rect background = Rect.fromLTWH(left, top, labelWidth, labelHeight);
    canvas.drawRect(
      background,
      Paint()..color = color.withValues(alpha: opacity * 0.85),
    );
    text.paint(canvas, Offset(left + padding, top + padding / 2));
  }

  @override
  bool shouldRepaint(DetectionPainter oldDelegate) =>
      oldDelegate.detections != detections ||
      oldDelegate.imageSize != imageSize;
}

/// Compact live read-out of what the detector is doing.
///
/// Sits over the preview so the numbers can be read while pointing the phone,
/// which is when they matter.
class DetectionStatsBar extends StatelessWidget {
  const DetectionStatsBar({
    required this.detectionCount,
    required this.maxConfidence,
    required this.inferenceMs,
    required this.modelLabel,
    required this.detecting,
    super.key,
  });

  final int detectionCount;
  final double maxConfidence;
  final int inferenceMs;
  final String modelLabel;
  final bool detecting;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: Colors.black.withValues(alpha: 0.55),
      child: Row(
        children: <Widget>[
          Icon(
            detecting ? Icons.radar : Icons.pause_circle_outline,
            size: 14,
            color: detecting ? AppColors.statusNormal : AppColors.textDisabled,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  detecting ? '탐지 중' : '탐지 중지됨',
                  style: AppTypography.label,
                ),
                if (modelLabel.isNotEmpty)
                  Text(
                    modelLabel,
                    style: AppTypography.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          _Stat(label: '탐지', value: '$detectionCount'),
          _Stat(
            label: '신뢰도',
            value: maxConfidence <= 0
                ? '—'
                : maxConfidence.toStringAsFixed(2),
          ),
          _Stat(label: '지연', value: '${inferenceMs}ms'),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(label, style: AppTypography.label),
          Text(value, style: AppTypography.bodyLarge),
        ],
      ),
    );
  }
}
