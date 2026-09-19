import 'package:beehive_guard/core/config/app_config.dart';
import 'package:beehive_guard/features/monitoring/domain/detector_factory.dart';
import 'package:beehive_guard/features/monitoring/domain/on_device_hornet_detector.dart';
import 'package:flutter_test/flutter_test.dart';

import 'on_device_hornet_detector_test.dart' show testCameraImage;

/// Mock mode must not be able to pass for a working model.
///
/// The mock detector reports zero hornets on every frame without looking at
/// the image. On screen that is indistinguishable from a real model watching a
/// quiet hive, so the build's own honesty about which one is running has to be
/// something the code guarantees, not something a reader infers.
void main() {
  test('the default build carries no real model', () {
    // If this ever fails, a build is shipping mock detection as if it were real
    // — or a real model has landed and the docs need updating with it.
    expect(AppConfig.modelMode, 'mock');
    expect(AppConfig.usesMockDetector, isTrue);
  });

  test('the factory returns the mock detector in mock mode', () async {
    final OnDeviceHornetDetector detector =
        await createOnDeviceHornetDetector();
    addTearDown(detector.dispose);

    expect(detector, isA<MockOnDeviceHornetDetector>());
  });

  test('the mock detector reports nothing, whatever it is shown', () async {
    final MockOnDeviceHornetDetector detector = MockOnDeviceHornetDetector();
    addTearDown(detector.dispose);

    final OnDeviceDetectionResult result = await detector.detect(
      testCameraImage(),
    );

    expect(result.hornetCount, 0);
    expect(result.maxConfidence, 0);
    expect(result.detections, isEmpty);
    expect(
      result.modelVersion,
      startsWith('mock'),
      reason: 'the version string is what the UI shows; it must name the mock',
    );
  });

  test('usesMockDetector is the same switch the factory branches on', () {
    // The screens label the model from this getter and the factory chooses the
    // detector from it, so the label cannot drift from what is running.
    expect(AppConfig.usesMockDetector, AppConfig.modelMode != 'tflite');
  });
}
