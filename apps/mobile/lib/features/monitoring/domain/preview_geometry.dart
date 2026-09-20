import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

import 'package:flutter/foundation.dart';

import 'on_device_hornet_detector.dart';

/// Maps normalized detections onto the camera preview as it is actually drawn.
///
/// The preview is shown with `BoxFit.cover` inside a fixed aspect ratio, which
/// means part of the camera image is **off screen**: a 4:3 viewport showing a
/// 16:9 sensor crops the left and right edges. Scaling a normalized box by the
/// widget size would therefore put every box in the wrong place, and the error
/// grows towards the edges — exactly where a hornet entering frame appears.
///
/// This computes the same transform the widget uses, so a box drawn from it
/// lands on the hornet.
@immutable
class PreviewGeometry {
  const PreviewGeometry({
    required this.scale,
    required this.offsetX,
    required this.offsetY,
    required this.viewport,
  });

  /// Builds the transform for an [image] displayed to [viewport] with cover.
  ///
  /// A degenerate size yields an identity-ish geometry rather than a NaN, so a
  /// preview that has not laid out yet simply draws nothing useful instead of
  /// throwing during paint.
  factory PreviewGeometry.cover({
    required Size image,
    required Size viewport,
  }) {
    if (image.width <= 0 ||
        image.height <= 0 ||
        viewport.width <= 0 ||
        viewport.height <= 0) {
      return PreviewGeometry(
        scale: 1,
        offsetX: 0,
        offsetY: 0,
        viewport: viewport,
      );
    }
    final double scale = math.max(
      viewport.width / image.width,
      viewport.height / image.height,
    );
    final double scaledWidth = image.width * scale;
    final double scaledHeight = image.height * scale;
    return PreviewGeometry(
      scale: scale,
      offsetX: (viewport.width - scaledWidth) / 2,
      offsetY: (viewport.height - scaledHeight) / 2,
      viewport: viewport,
    );
  }

  /// Uniform scale applied to the camera image to cover the viewport.
  final double scale;

  /// Left offset of the scaled image relative to the viewport, normally
  /// negative or zero because cover overflows.
  final double offsetX;

  /// Top offset of the scaled image relative to the viewport.
  final double offsetY;

  final Size viewport;

  /// Places a normalized detection in viewport coordinates.
  ///
  /// The returned rectangle may fall partly outside the viewport when the
  /// hornet is in the cropped-away part of the sensor image; callers clip.
  Rect rectFor(OnDeviceDetection detection, {required Size image}) {
    final double left = offsetX + detection.x * image.width * scale;
    final double top = offsetY + detection.y * image.height * scale;
    return Rect.fromLTWH(
      left,
      top,
      detection.width * image.width * scale,
      detection.height * image.height * scale,
    );
  }

  /// Whether a rectangle is at least partly visible in the viewport.
  bool isVisible(Rect rect) =>
      rect.right > 0 &&
      rect.bottom > 0 &&
      rect.left < viewport.width &&
      rect.top < viewport.height;
}
