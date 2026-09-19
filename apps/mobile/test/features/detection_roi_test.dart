import 'package:beehive_guard/features/monitoring/domain/detection_roi.dart';
import 'package:beehive_guard/features/monitoring/domain/on_device_hornet_detector.dart';
import 'package:flutter_test/flutter_test.dart';

/// The region is what makes a small hornet detectable at all, so its geometry
/// has to be exact: a wrong crop feeds the model the wrong pixels, and a wrong
/// reverse mapping puts the boxes — and the uploaded metadata — somewhere the
/// hornet is not.
void main() {
  group('construction', () {
    test('the default is the whole frame', () {
      expect(DetectionRoi.full.isFullFrame, isTrue);
      expect(DetectionRoi.full.width, 1);
      expect(DetectionRoi.full.height, 1);
    });

    test('a region inside the frame is kept as given', () {
      final DetectionRoi roi = DetectionRoi.clamped(
        x: 0.25,
        y: 0.1,
        width: 0.5,
        height: 0.4,
      );

      expect(roi.x, closeTo(0.25, 1e-9));
      expect(roi.y, closeTo(0.1, 1e-9));
      expect(roi.width, closeTo(0.5, 1e-9));
      expect(roi.height, closeTo(0.4, 1e-9));
      expect(roi.isFullFrame, isFalse);
    });

    test('a drag past the edge pins the region inside the frame', () {
      final DetectionRoi roi = DetectionRoi.clamped(
        x: 0.9,
        y: 0.9,
        width: 0.5,
        height: 0.5,
      );

      expect(roi.right, lessThanOrEqualTo(1.0));
      expect(roi.bottom, lessThanOrEqualTo(1.0));
      expect(roi.x, closeTo(0.5, 1e-9));
      expect(roi.y, closeTo(0.5, 1e-9));
    });

    test('a pinch to nothing stops at the minimum side', () {
      final DetectionRoi roi = DetectionRoi.clamped(
        x: 0.5,
        y: 0.5,
        width: 0.0001,
        height: 0.0,
      );

      expect(roi.width, DetectionRoi.minimumSide);
      expect(roi.height, DetectionRoi.minimumSide);
    });

    test('non-finite input falls back to the whole frame', () {
      final DetectionRoi roi = DetectionRoi.clamped(
        x: double.nan,
        y: double.infinity,
        width: double.nan,
        height: double.nan,
      );

      expect(roi.isFullFrame, isTrue);
    });
  });

  group('pixel crop', () {
    test('the full frame crops to the whole frame', () {
      final ({int left, int top, int width, int height}) crop = DetectionRoi
          .full
          .pixelsIn(frameWidth: 1920, frameHeight: 1080);

      expect(crop.left, 0);
      expect(crop.top, 0);
      expect(crop.width, 1920);
      expect(crop.height, 1080);
    });

    test('a centred half crops to the middle of the frame', () {
      final ({int left, int top, int width, int height}) crop =
          DetectionRoi.clamped(
            x: 0.25,
            y: 0.25,
            width: 0.5,
            height: 0.5,
          ).pixelsIn(frameWidth: 1920, frameHeight: 1080);

      expect(crop.left, 480);
      expect(crop.top, 270);
      expect(crop.width, 960);
      expect(crop.height, 540);
    });

    test('the crop never leaves the frame or collapses', () {
      final ({int left, int top, int width, int height}) crop =
          DetectionRoi.clamped(
            x: 0.95,
            y: 0.95,
            width: DetectionRoi.minimumSide,
            height: DetectionRoi.minimumSide,
          ).pixelsIn(frameWidth: 640, frameHeight: 480);

      expect(crop.width, greaterThan(0));
      expect(crop.height, greaterThan(0));
      expect(crop.left + crop.width, lessThanOrEqualTo(640));
      expect(crop.top + crop.height, lessThanOrEqualTo(480));
    });
  });

  group('mapping detections back to the frame', () {
    OnDeviceDetection detection({
      required double x,
      required double y,
      required double width,
      required double height,
    }) => OnDeviceDetection(
      x: x,
      y: y,
      width: width,
      height: height,
      confidence: 0.9,
      className: 'Vespa velutina',
    );

    test('the full frame leaves a detection untouched', () {
      final OnDeviceDetection original = detection(
        x: 0.1,
        y: 0.2,
        width: 0.3,
        height: 0.4,
      );

      final OnDeviceDetection mapped = DetectionRoi.full.mapToFrame(original);

      expect(mapped.x, original.x);
      expect(mapped.y, original.y);
      expect(mapped.width, original.width);
      expect(mapped.height, original.height);
    });

    test('a box in the crop lands where the crop is', () {
      // A hornet filling the middle of a region that occupies the middle half
      // of the frame must come back in the middle of the frame, at half size.
      final DetectionRoi roi = DetectionRoi.clamped(
        x: 0.25,
        y: 0.25,
        width: 0.5,
        height: 0.5,
      );

      final OnDeviceDetection mapped = roi.mapToFrame(
        detection(x: 0.5, y: 0.5, width: 0.25, height: 0.25),
      );

      expect(mapped.x, closeTo(0.5, 1e-9));
      expect(mapped.y, closeTo(0.5, 1e-9));
      expect(mapped.width, closeTo(0.125, 1e-9));
      expect(mapped.height, closeTo(0.125, 1e-9));
    });

    test('a mapped box stays inside the frame', () {
      final DetectionRoi roi = DetectionRoi.clamped(
        x: 0.6,
        y: 0.6,
        width: 0.4,
        height: 0.4,
      );

      final OnDeviceDetection mapped = roi.mapToFrame(
        detection(x: 0.0, y: 0.0, width: 1.0, height: 1.0),
      );

      expect(mapped.x + mapped.width, lessThanOrEqualTo(1.0 + 1e-9));
      expect(mapped.y + mapped.height, lessThanOrEqualTo(1.0 + 1e-9));
    });

    test('confidence and class survive the mapping', () {
      final DetectionRoi roi = DetectionRoi.clamped(
        x: 0.1,
        y: 0.1,
        width: 0.5,
        height: 0.5,
      );

      final OnDeviceDetection mapped = roi.mapToFrame(
        detection(x: 0.2, y: 0.2, width: 0.1, height: 0.1),
      );

      expect(mapped.confidence, 0.9);
      expect(mapped.className, 'Vespa velutina');
    });
  });

  group('persistence round trip', () {
    test('a region survives encode and decode', () {
      final DetectionRoi roi = DetectionRoi.clamped(
        x: 0.2,
        y: 0.3,
        width: 0.45,
        height: 0.25,
      );

      final DetectionRoi? restored = DetectionRoi.fromJson(roi.toJson());

      expect(restored, roi);
    });

    test('a malformed record falls back rather than throwing', () {
      // Monitoring must still start if preferences were written by an older
      // build or truncated.
      expect(DetectionRoi.fromJson(<String, dynamic>{'x': 'nope'}), isNull);
      expect(DetectionRoi.fromJson(<String, dynamic>{}), isNull);
    });
  });
}
