import 'dart:typed_data';

import 'package:beehive_guard/features/monitoring/domain/on_device_hornet_detector.dart';
import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mock detector returns its configured metadata', () async {
    const OnDeviceDetectionResult expected = OnDeviceDetectionResult(
      hornetCount: 1,
      maxConfidence: 0.87,
      detections: <OnDeviceDetection>[
        OnDeviceDetection(
          confidence: 0.87,
          x: 0.1,
          y: 0.2,
          width: 0.3,
          height: 0.4,
          className: 'hornet',
        ),
      ],
      inferenceMs: 4,
      modelVersion: 'mock-test',
    );
    final MockOnDeviceHornetDetector detector = MockOnDeviceHornetDetector(
      result: expected,
    );

    expect(await detector.detect(testCameraImage()), expected);
  });

  test('mock detector rejects inference after disposal', () async {
    final MockOnDeviceHornetDetector detector = MockOnDeviceHornetDetector();

    await detector.dispose();

    await expectLater(detector.detect(testCameraImage()), throwsStateError);
  });
}

// The camera package exposes no public test constructor yet.
CameraImage testCameraImage() =>
    // ignore: deprecated_member_use
    CameraImage.fromPlatformData(<dynamic, dynamic>{
      'format': 0,
      'height': 2,
      'width': 2,
      'lensAperture': null,
      'sensorExposureTime': null,
      'sensorSensitivity': null,
      'planes': <Map<dynamic, dynamic>>[
        <dynamic, dynamic>{
          'bytes': Uint8List.fromList(<int>[0, 0, 0, 0]),
          'bytesPerPixel': 1,
          'bytesPerRow': 2,
          'height': 2,
          'width': 2,
        },
      ],
    });
