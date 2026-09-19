import 'package:beehive_guard/core/config/app_config.dart';
import 'package:beehive_guard/features/monitoring/domain/on_device_hornet_detector.dart';
import 'package:beehive_guard/features/monitoring/domain/tflite_hornet_detector.dart';
import 'package:flutter_test/flutter_test.dart';

import 'on_device_hornet_detector_test.dart' show testCameraImage;

void main() {
  test('the default build selects the bundled VespAI model', () {
    expect(AppConfig.modelMode, 'tflite');
    expect(AppConfig.usesMockDetector, isFalse);
    expect(AppConfig.modelVersion, 'vespai-yolov5s-all-but-22ip');
  });

  test('a missing model fails instead of silently using mock detection', () {
    expect(
      TfliteHornetDetector.fromAsset(
        assetPath: 'assets/models/does-not-exist.tflite',
        modelVersion: 'missing',
      ),
      throwsA(anything),
    );
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
}
