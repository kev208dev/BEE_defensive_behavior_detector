import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'detection_roi.dart';
import 'on_device_hornet_detector.dart';

/// Clockwise quarter turns, followed by a horizontal mirror. Coordinates are
/// normalized; transforming all four corners also handles 180/270 degrees.
@immutable
class CameraRectTransform {
  const CameraRectTransform({this.quarterTurns = 0, this.mirror = false});
  final int quarterTurns;
  final bool mirror;

  Offset _point(Offset p) {
    final Offset rotated = switch (quarterTurns % 4) {
      1 => Offset(1 - p.dy, p.dx),
      2 => Offset(1 - p.dx, 1 - p.dy),
      3 => Offset(p.dy, 1 - p.dx),
      _ => p,
    };
    return mirror ? Offset(1 - rotated.dx, rotated.dy) : rotated;
  }

  Rect rect(Rect source) {
    final List<Offset> corners = <Offset>[
      source.topLeft,
      source.topRight,
      source.bottomLeft,
      source.bottomRight,
    ].map(_point).toList();
    final List<double> xs = corners.map((p) => p.dx).toList()..sort();
    final List<double> ys = corners.map((p) => p.dy).toList()..sort();
    return Rect.fromLTRB(xs.first, ys.first, xs.last, ys.last);
  }

  Rect inverseRect(Rect source) {
    final Rect unmirrored = mirror
        ? const CameraRectTransform(mirror: true).rect(source)
        : source;
    return CameraRectTransform(quarterTurns: -quarterTurns).rect(unmirrored);
  }

  Size size(Size source) =>
      quarterTurns.isOdd ? Size(source.height, source.width) : source;

  OnDeviceDetection detection(OnDeviceDetection box) {
    final Rect mapped = rect(
      Rect.fromLTWH(box.x, box.y, box.width, box.height),
    );
    return OnDeviceDetection(
      x: mapped.left,
      y: mapped.top,
      width: mapped.width,
      height: mapped.height,
      confidence: box.confidence,
      className: box.className,
    );
  }

  DetectionRoi roi(DetectionRoi source) => roiFromRect(
    rect(Rect.fromLTWH(source.x, source.y, source.width, source.height)),
  );

  static DetectionRoi roiFromRect(Rect rect) => DetectionRoi.clamped(
    x: rect.left,
    y: rect.top,
    width: rect.width,
    height: rect.height,
  );
}

/// Matches camera 0.12.1 CameraPreview's applicable orientation precedence.
DeviceOrientation previewOrientation(CameraValue value) =>
    value.isRecordingVideo && value.recordingOrientation != null
    ? value.recordingOrientation!
    : value.previewPauseOrientation ??
          value.lockedCaptureOrientation ??
          value.deviceOrientation;

CameraRectTransform sensorToPreview(
  CameraDescription camera,
  DeviceOrientation orientation,
) {
  final int degrees = switch (orientation) {
    DeviceOrientation.portraitUp => 0,
    DeviceOrientation.landscapeLeft => 90,
    DeviceOrientation.portraitDown => 180,
    DeviceOrientation.landscapeRight => 270,
  };
  final bool front = camera.lensDirection == CameraLensDirection.front;
  return CameraRectTransform(
    quarterTurns:
        (camera.sensorOrientation + (front ? degrees : -degrees)) ~/ 90,
    mirror: front,
  );
}

/// AVFoundation 0.10.3 rotates/mirrors the shared pixel buffer before BOTH
/// streaming and texture publication. Rotating it again is incorrect.
/// CameraX streams sensor pixels; its preview applies rotation and mirroring.
CameraRectTransform bufferToPreview({
  required TargetPlatform platform,
  required CameraDescription camera,
  required DeviceOrientation orientation,
}) => platform == TargetPlatform.iOS
    ? const CameraRectTransform()
    : sensorToPreview(camera, orientation);

Size cameraPreviewSize(CameraValue value) {
  final Size sensor = value.previewSize ?? const Size(640, 480);
  final DeviceOrientation orientation = previewOrientation(value);
  return orientation == DeviceOrientation.landscapeLeft ||
          orientation == DeviceOrientation.landscapeRight
      ? sensor
      : Size(sensor.height, sensor.width);
}
