import 'package:flutter/foundation.dart';

import 'on_device_hornet_detector.dart';

/// The part of the camera frame the detector actually looks at.
///
/// Why this exists, measured rather than assumed: the bundled VespAI model has
/// a fixed 640x640 input, so what decides whether a hornet is found is how many
/// of those 640 pixels land on it. Benchmarking the model against its own
/// sample frames (see `tools/model_conversion/benchmark_detector.py`) shows the
/// cliff clearly, with the whole frame fed to the model:
///
/// | hornet width in a 1920px frame | raw candidates | best confidence |
/// |---|---|---|
/// | ~154px | 54 | 0.97 |
/// | ~92px  | 58 | 0.95 |
/// | ~61px  | 18 | 0.60 |
/// | ~46px  | 0  | 0.001 |
/// | ~23px  | 0  | 0.002 |
///
/// Below roughly 46px the model stops producing candidates at all, so no
/// confidence threshold can recover them. Cropping to the hive entrance first
/// restored every detection at 0.96 confidence at every size tested, because
/// the same hornet then covers far more of the model's input — and it costs
/// nothing, since it is still one inference per frame.
@immutable
class DetectionRoi {
  const DetectionRoi._({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// Builds a region, clamped so it always lies inside the frame.
  ///
  /// Clamping rather than throwing: this is fed by a drag gesture, and a
  /// finger leaving the preview should pin the edge, not crash monitoring.
  factory DetectionRoi.clamped({
    required double x,
    required double y,
    required double width,
    required double height,
  }) {
    final double w = width.isFinite
        ? width.clamp(minimumSide, 1.0)
        : 1.0;
    final double h = height.isFinite
        ? height.clamp(minimumSide, 1.0)
        : 1.0;
    final double left = x.isFinite ? x.clamp(0.0, 1.0 - w) : 0.0;
    final double top = y.isFinite ? y.clamp(0.0, 1.0 - h) : 0.0;
    return DetectionRoi._(x: left, y: top, width: w, height: h);
  }

  /// The whole frame — what a device uses until the beekeeper marks the hive.
  static const DetectionRoi full = DetectionRoi._(
    x: 0,
    y: 0,
    width: 1,
    height: 1,
  );

  /// Smallest region worth allowing, as a fraction of a side.
  ///
  /// A sliver crop would magnify noise and make the preview overlay
  /// unusable; it is also never what a hive entrance looks like.
  static const double minimumSide = 0.05;

  /// Normalized left edge, 0..1 of frame width.
  final double x;

  /// Normalized top edge, 0..1 of frame height.
  final double y;

  /// Normalized width, 0..1.
  final double width;

  /// Normalized height, 0..1.
  final double height;

  bool get isFullFrame => x == 0 && y == 0 && width == 1 && height == 1;

  double get right => x + width;

  double get bottom => y + height;

  /// Converts a detection expressed inside this region into frame coordinates.
  ///
  /// The detector only ever saw the crop, so every box it returns is relative
  /// to the crop. Without this the boxes would be drawn — and uploaded — in the
  /// wrong place whenever the region is not the full frame.
  OnDeviceDetection mapToFrame(OnDeviceDetection detection) {
    if (isFullFrame) return detection;
    return OnDeviceDetection(
      x: x + detection.x * width,
      y: y + detection.y * height,
      width: detection.width * width,
      height: detection.height * height,
      confidence: detection.confidence,
      className: detection.className,
    );
  }

  /// Pixel bounds of this region inside a frame of the given size.
  ///
  /// Rounded outwards to whole pixels and guaranteed at least one pixel wide,
  /// so a crop can always be sampled.
  ({int left, int top, int width, int height}) pixelsIn({
    required int frameWidth,
    required int frameHeight,
  }) {
    final int left = (x * frameWidth).floor().clamp(0, frameWidth - 1);
    final int top = (y * frameHeight).floor().clamp(0, frameHeight - 1);
    final int right = (this.right * frameWidth).ceil().clamp(
      left + 1,
      frameWidth,
    );
    final int bottom = (this.bottom * frameHeight).ceil().clamp(
      top + 1,
      frameHeight,
    );
    return (left: left, top: top, width: right - left, height: bottom - top);
  }

  Map<String, double> toJson() => <String, double>{
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };

  static DetectionRoi? fromJson(Map<String, dynamic> json) {
    final Object? x = json['x'];
    final Object? y = json['y'];
    final Object? width = json['width'];
    final Object? height = json['height'];
    if (x is! num || y is! num || width is! num || height is! num) return null;
    return DetectionRoi.clamped(
      x: x.toDouble(),
      y: y.toDouble(),
      width: width.toDouble(),
      height: height.toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DetectionRoi &&
      other.x == x &&
      other.y == y &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(x, y, width, height);

  @override
  String toString() =>
      'DetectionRoi(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, '
      '${width.toStringAsFixed(3)}x${height.toStringAsFixed(3)})';
}
