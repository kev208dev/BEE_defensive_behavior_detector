import 'package:beehive_guard/features/monitoring/domain/camera_geometry.dart';
import 'package:beehive_guard/features/monitoring/domain/preview_geometry.dart';
import 'package:beehive_guard/features/monitoring/domain/on_device_hornet_detector.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const Rect box = Rect.fromLTWH(.1, .2, .3, .4);
  final expected = <Rect>[
    box,
    const Rect.fromLTWH(.4, .1, .4, .3),
    const Rect.fromLTWH(.6, .4, .3, .4),
    const Rect.fromLTWH(.2, .6, .4, .3),
  ];
  void near(Rect actual, Rect expected) {
    expect(actual.left, closeTo(expected.left, 1e-9));
    expect(actual.top, closeTo(expected.top, 1e-9));
    expect(actual.width, closeTo(expected.width, 1e-9));
    expect(actual.height, closeTo(expected.height, 1e-9));
  }

  for (int turn = 0; turn < 4; turn++) {
    test('${turn * 90} degrees and inverse, rear and mirrored front', () {
      final transform = CameraRectTransform(quarterTurns: turn);
      near(transform.rect(box), expected[turn]);
      near(transform.inverseRect(transform.rect(box)), box);
      final front = CameraRectTransform(quarterTurns: turn, mirror: true);
      near(
        front.rect(box),
        Rect.fromLTWH(
          1 - expected[turn].right,
          expected[turn].top,
          expected[turn].width,
          expected[turn].height,
        ),
      );
      near(front.inverseRect(front.rect(box)), box);
    });
  }
  const camera = CameraDescription(
    name: 'rear',
    lensDirection: CameraLensDirection.back,
    sensorOrientation: 90,
  );
  test('Android rear sensor rotation follows device orientation', () {
    const orientations = [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeRight,
    ];
    const turns = [1, 0, 3, 2];
    for (int i = 0; i < 4; i++) {
      near(
        bufferToPreview(
          platform: TargetPlatform.android,
          camera: camera,
          orientation: orientations[i],
        ).rect(box),
        expected[turns[i]],
      );
    }
  });
  test('Android front sensor rotation includes preview mirroring', () {
    const front = CameraDescription(
      name: 'front',
      lensDirection: CameraLensDirection.front,
      sensorOrientation: 90,
    );
    final transformed = bufferToPreview(
      platform: TargetPlatform.android,
      camera: front,
      orientation: DeviceOrientation.portraitUp,
    );
    near(
      transformed.rect(box),
      Rect.fromLTWH(
        1 - expected[1].right,
        expected[1].top,
        expected[1].width,
        expected[1].height,
      ),
    );
  });
  test('AVFoundation already rotated and mirrored its shared buffer', () {
    for (final orientation in DeviceOrientation.values) {
      for (final lens in [
        CameraLensDirection.front,
        CameraLensDirection.back,
      ]) {
        final transform = bufferToPreview(
          platform: TargetPlatform.iOS,
          camera: CameraDescription(
            name: 'ios',
            lensDirection: lens,
            sensorOrientation: 90,
          ),
          orientation: orientation,
        );
        near(transform.rect(box), box);
        expect(transform.size(const Size(480, 640)), const Size(480, 640));
      }
    }
  });
  test(
    'viewport selection returns to identical iOS pixels in every orientation',
    () {
      for (final orientation in DeviceOrientation.values) {
        for (final lens in [
          CameraLensDirection.front,
          CameraLensDirection.back,
        ]) {
          final transform = sensorToPreview(
            CameraDescription(
              name: 'camera',
              lensDirection: lens,
              sensorOrientation: 90,
            ),
            orientation,
          );
          final image = transform.size(const Size(640, 480));
          final cover = PreviewGeometry.cover(
            image: image,
            viewport: const Size(400, 300),
          );
          const selection = Rect.fromLTWH(30, 70, 140, 100);
          final previewRect = cover.normalizedRect(selection, image: image);
          final storedSensor = transform.inverseRect(previewRect);
          final nativeIos = transform.rect(storedSensor);
          near(
            cover.rectFor(
              OnDeviceDetection(
                x: nativeIos.left,
                y: nativeIos.top,
                width: nativeIos.width,
                height: nativeIos.height,
                confidence: 1,
                className: 'test',
              ),
              image: image,
            ),
            selection,
          );
        }
      }
    },
  );
  test('cover mapping clips edge and ROI inverse recovers source pixels', () {
    const image = Size(480, 640);
    const viewport = Size(400, 300);
    final cover = PreviewGeometry.cover(image: image, viewport: viewport);
    final full = cover.rectFor(
      const OnDeviceDetection(
        x: 0,
        y: 0,
        width: 1,
        height: 1,
        confidence: .9,
        className: 'Vespa crabro',
      ),
      image: image,
    );
    final visible = full.intersect(Offset.zero & viewport);
    expect(visible, Offset.zero & viewport);
    near(
      cover.normalizedRect(visible, image: image),
      const Rect.fromLTWH(0, .21875, 1, .5625),
    );
  });
  test(
    'locked orientation takes precedence over current device orientation',
    () {
      final value = const CameraValue.uninitialized(camera).copyWith(
        deviceOrientation: DeviceOrientation.landscapeLeft,
        lockedCaptureOrientation: const Optional.of(
          DeviceOrientation.portraitDown,
        ),
      );
      expect(previewOrientation(value), DeviceOrientation.portraitDown);
    },
  );
}
