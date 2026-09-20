import 'dart:ui' show Rect, Size;

import 'package:beehive_guard/features/monitoring/domain/on_device_hornet_detector.dart';
import 'package:beehive_guard/features/monitoring/domain/preview_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

/// The preview is drawn with `BoxFit.cover`, which crops. Scaling a normalized
/// box by the widget size would therefore misplace every box, worst at the
/// edges — which is exactly where a hornet entering frame appears. These pin
/// the transform against hand-computed values.
void main() {
  OnDeviceDetection box({
    required double x,
    required double y,
    required double w,
    required double h,
  }) => OnDeviceDetection(
    x: x,
    y: y,
    width: w,
    height: h,
    confidence: 0.9,
    className: 'Vespa velutina',
  );

  group('same aspect ratio', () {
    test('nothing is cropped and a centred box stays centred', () {
      const Size image = Size(640, 480);
      const Size viewport = Size(320, 240);
      final PreviewGeometry geometry = PreviewGeometry.cover(
        image: image,
        viewport: viewport,
      );

      expect(geometry.scale, closeTo(0.5, 1e-9));
      expect(geometry.offsetX, closeTo(0, 1e-9));
      expect(geometry.offsetY, closeTo(0, 1e-9));

      final Rect rect = geometry.rectFor(
        box(x: 0.25, y: 0.25, w: 0.5, h: 0.5),
        image: image,
      );

      expect(rect.left, closeTo(80, 1e-9));
      expect(rect.top, closeTo(60, 1e-9));
      expect(rect.width, closeTo(160, 1e-9));
      expect(rect.height, closeTo(120, 1e-9));
    });
  });

  group('wider image than viewport', () {
    // A 16:9 sensor in a 4:3 viewport: cover scales to height and the left and
    // right edges fall off screen.
    const Size image = Size(1920, 1080);
    const Size viewport = Size(400, 300);

    test('scales to the taller axis and centres the overflow', () {
      final PreviewGeometry geometry = PreviewGeometry.cover(
        image: image,
        viewport: viewport,
      );

      // 300/1080 = 0.2777..., which is larger than 400/1920 = 0.2083...
      expect(geometry.scale, closeTo(300 / 1080, 1e-9));
      // Scaled width is 533.33, so 66.67 hangs off each side.
      expect(geometry.offsetX, closeTo((400 - 1920 * 300 / 1080) / 2, 1e-9));
      expect(geometry.offsetY, closeTo(0, 1e-9));
    });

    test('a centred hornet lands in the middle of the viewport', () {
      final PreviewGeometry geometry = PreviewGeometry.cover(
        image: image,
        viewport: viewport,
      );

      final Rect rect = geometry.rectFor(
        box(x: 0.475, y: 0.475, w: 0.05, h: 0.05),
        image: image,
      );

      expect(rect.center.dx, closeTo(200, 1e-6));
      expect(rect.center.dy, closeTo(150, 1e-6));
    });

    test('a hornet at the cropped edge is reported outside the viewport', () {
      // This is the case a naive scale gets wrong: it would draw this box
      // inside the preview, on top of something that is not there.
      final PreviewGeometry geometry = PreviewGeometry.cover(
        image: image,
        viewport: viewport,
      );

      final Rect rect = geometry.rectFor(
        box(x: 0.0, y: 0.45, w: 0.03, h: 0.05),
        image: image,
      );

      expect(rect.left, lessThan(0));
      expect(geometry.isVisible(rect), isFalse);
    });

    test('a hornet just inside the visible band is visible', () {
      final PreviewGeometry geometry = PreviewGeometry.cover(
        image: image,
        viewport: viewport,
      );

      final Rect rect = geometry.rectFor(
        box(x: 0.2, y: 0.45, w: 0.05, h: 0.05),
        image: image,
      );

      expect(geometry.isVisible(rect), isTrue);
      expect(rect.left, greaterThan(0));
    });
  });

  group('taller image than viewport', () {
    test('scales to width and crops top and bottom', () {
      const Size image = Size(480, 640);
      const Size viewport = Size(400, 300);
      final PreviewGeometry geometry = PreviewGeometry.cover(
        image: image,
        viewport: viewport,
      );

      expect(geometry.scale, closeTo(400 / 480, 1e-9));
      expect(geometry.offsetX, closeTo(0, 1e-9));
      expect(geometry.offsetY, lessThan(0));
    });
  });

  group('degenerate input', () {
    test('a zero-sized viewport does not produce NaN', () {
      final PreviewGeometry geometry = PreviewGeometry.cover(
        image: const Size(640, 480),
        viewport: Size.zero,
      );

      expect(geometry.scale.isFinite, isTrue);
      expect(geometry.offsetX.isFinite, isTrue);
      expect(geometry.offsetY.isFinite, isTrue);
    });

    test('a zero-sized image does not produce NaN', () {
      final PreviewGeometry geometry = PreviewGeometry.cover(
        image: Size.zero,
        viewport: const Size(400, 300),
      );

      expect(geometry.scale.isFinite, isTrue);
    });
  });
}
