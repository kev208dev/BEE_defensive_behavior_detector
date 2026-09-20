import 'package:beehive_guard/features/monitoring/domain/on_device_hornet_detector.dart';
import 'package:beehive_guard/features/monitoring/domain/tflite_hornet_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VespAI input contract', () {
    test('accepts the exported 640 square NHWC tensor', () {
      expect(
        () => TfliteHornetDetector.validateInputShape(<int>[1, 640, 640, 3]),
        returnsNormally,
      );
    });

    test('rejects a different tensor shape before monitoring starts', () {
      for (final List<int> shape in <List<int>>[
        <int>[1, 640, 640],
        <int>[1, 320, 320, 3],
        <int>[1, 640, 640, 1],
      ]) {
        expect(
          () => TfliteHornetDetector.validateInputShape(shape),
          throwsStateError,
        );
      }
    });

    test('accepts only the exported raw prediction output shape', () {
      expect(
        () => TfliteHornetDetector.validateOutputShape(<int>[1, 25200, 7]),
        returnsNormally,
      );
      expect(
        () => TfliteHornetDetector.validateOutputShape(<int>[1, 25200, 6]),
        throwsStateError,
      );
      expect(
        () => TfliteHornetDetector.validateOutputShape(<int>[1, 7]),
        throwsStateError,
      );
    });

    test('letterboxes a 16:9 camera frame with VespAI padding', () {
      final VespAiLetterboxGeometry geometry =
          TfliteHornetDetector.letterboxGeometry(
            frameWidth: 1920,
            frameHeight: 1080,
            inputWidth: 640,
            inputHeight: 640,
          );

      expect(geometry.resizedWidth, 640);
      expect(geometry.resizedHeight, 360);
      expect(geometry.padLeft, 0);
      expect(geometry.padTop, 140);
      expect(VespAiLetterboxGeometry.paddingValue, 114);
    });
  });

  group('VespAiYoloV5Decoder', () {
    const VespAiYoloV5Decoder decoder = VespAiYoloV5Decoder();

    test('decodes one Vespa crabro prediction', () {
      final List<OnDeviceDetection> detections = decoder.decode(
        _output(<List<num>>[
          <num>[0.5, 0.5, 0.2, 0.2, 0.9, 1.0, 0.1],
        ]),
        frameWidth: 640,
        frameHeight: 640,
        inputWidth: 640,
        inputHeight: 640,
      );

      expect(detections, hasLength(1));
      expect(detections.single.className, 'Vespa crabro');
      expect(detections.single.confidence, closeTo(0.9, 1e-9));
    });

    test('decodes one Vespa velutina prediction', () {
      final List<OnDeviceDetection> detections = decoder.decode(
        _output(<List<num>>[
          <num>[0.5, 0.5, 0.2, 0.2, 0.95, 0.1, 0.9],
        ]),
        frameWidth: 640,
        frameHeight: 640,
        inputWidth: 640,
        inputHeight: 640,
      );

      expect(detections, hasLength(1));
      expect(detections.single.className, 'Vespa velutina');
      expect(detections.single.confidence, closeTo(0.855, 1e-9));
    });

    test('keeps multiple hornets from both model classes', () {
      final List<OnDeviceDetection> detections = decoder.decode(
        _output(<List<num>>[
          <num>[0.2, 0.2, 0.1, 0.1, 0.9, 1.0, 0.0],
          <num>[0.8, 0.8, 0.1, 0.1, 0.9, 0.0, 1.0],
        ]),
        frameWidth: 640,
        frameHeight: 640,
        inputWidth: 640,
        inputHeight: 640,
      );

      expect(detections, hasLength(2));
      expect(
        detections.map((OnDeviceDetection item) => item.className),
        containsAll(<String>['Vespa crabro', 'Vespa velutina']),
      );
    });

    test('multiplies objectness by class probability before thresholding', () {
      final List<OnDeviceDetection> detections = decoder.decode(
        _output(<List<num>>[
          <num>[0.5, 0.5, 0.2, 0.2, 0.9, 0.85, 0.0],
          <num>[0.5, 0.5, 0.2, 0.2, 0.9, 0.0, 0.9],
        ]),
        frameWidth: 640,
        frameHeight: 640,
        inputWidth: 640,
        inputHeight: 640,
      );

      expect(detections, hasLength(1));
      expect(detections.single.className, 'Vespa velutina');
      expect(detections.single.confidence, closeTo(0.81, 1e-9));
    });

    test('applies class-aware non-maximum suppression', () {
      final List<OnDeviceDetection> detections = decoder.decode(
        _output(<List<num>>[
          <num>[0.5, 0.5, 0.4, 0.4, 0.95, 1.0, 0.0],
          <num>[0.51, 0.51, 0.4, 0.4, 0.90, 1.0, 0.0],
        ]),
        frameWidth: 640,
        frameHeight: 640,
        inputWidth: 640,
        inputHeight: 640,
      );

      expect(detections, hasLength(1));
      expect(detections.single.confidence, closeTo(0.95, 1e-9));
    });

    test('returns no detections when every candidate is below threshold', () {
      final List<OnDeviceDetection> detections = decoder.decode(
        _output(<List<num>>[
          <num>[0.5, 0.5, 0.2, 0.2, 0.79, 1.0, 0.0],
        ]),
        frameWidth: 640,
        frameHeight: 640,
        inputWidth: 640,
        inputHeight: 640,
      );

      expect(detections, isEmpty);
    });

    test('reverses letterbox padding into normalized camera coordinates', () {
      final List<OnDeviceDetection> detections = decoder.decode(
        _output(<List<num>>[
          // Original 1920x1080 box is x=.25, y=.25, w=.5, h=.5.
          <num>[0.5, 0.5, 0.5, 0.28125, 0.9, 1.0, 0.0],
        ]),
        frameWidth: 1920,
        frameHeight: 1080,
        inputWidth: 640,
        inputHeight: 640,
      );

      final OnDeviceDetection box = detections.single;
      expect(box.x, closeTo(0.25, 1e-9));
      expect(box.y, closeTo(0.25, 1e-9));
      expect(box.width, closeTo(0.5, 1e-9));
      expect(box.height, closeTo(0.5, 1e-9));
      expect(box.x + box.width, lessThanOrEqualTo(1));
      expect(box.y + box.height, lessThanOrEqualTo(1));
    });

    test('rejects an output tensor whose rows do not have seven values', () {
      expect(
        () => decoder.decode(
          <Object>[
            <Object>[
              <Object>[
                <num>[0.5, 0.5, 0.2, 0.2, 0.9, 1.0],
              ],
            ],
          ],
          frameWidth: 640,
          frameHeight: 640,
          inputWidth: 640,
          inputHeight: 640,
        ),
        throwsStateError,
      );
    });
  });
}

List<Object> _output(List<List<num>> rows) => <Object>[
  <Object>[
    <Object>[...rows],
  ],
];
