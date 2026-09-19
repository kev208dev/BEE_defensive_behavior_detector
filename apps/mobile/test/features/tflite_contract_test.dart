import 'package:beehive_guard/features/monitoring/domain/on_device_hornet_detector.dart';
import 'package:beehive_guard/features/monitoring/domain/tflite_hornet_detector.dart';
import 'package:flutter_test/flutter_test.dart';

/// The model contract, asserted without a model file.
///
/// No validated `hornet.tflite` exists yet, so the adapter cannot be exercised
/// end to end. What can be pinned down is the contract it enforces: which input
/// shapes it accepts, and how it turns output rows into the metadata the
/// backend scores. See `assets/models/README.md`.
void main() {
  group('input shape validation', () {
    test('accepts an NHWC image tensor', () {
      expect(
        () => TfliteHornetDetector.validateInputShape(<int>[1, 320, 320, 3]),
        returnsNormally,
      );
    });

    test('rejects a tensor that is not rank 4', () {
      expect(
        () => TfliteHornetDetector.validateInputShape(<int>[1, 320, 320]),
        throwsStateError,
      );
    });

    test('rejects a channel count this adapter cannot fill', () {
      // Grayscale and RGBA models both need different preprocessing.
      expect(
        () => TfliteHornetDetector.validateInputShape(<int>[1, 320, 320, 1]),
        throwsStateError,
      );
      expect(
        () => TfliteHornetDetector.validateInputShape(<int>[1, 320, 320, 4]),
        throwsStateError,
      );
    });

    test('the error names the contract so the failure is actionable', () {
      expect(
        () => TfliteHornetDetector.validateInputShape(<int>[1, 320, 320, 1]),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            allOf(contains('[1, 320, 320, 1]'), contains('README')),
          ),
        ),
      );
    });
  });

  group('SixColumnDetectionDecoder', () {
    const SixColumnDetectionDecoder decoder = SixColumnDetectionDecoder();

    test('decodes a [1, N, 6] batch', () {
      final List<OnDeviceDetection> detections = decoder.decode(<Object>[
        <Object>[
          <Object>[
            <num>[0.1, 0.2, 0.3, 0.4, 0.9, 0],
            <num>[0.5, 0.5, 0.2, 0.2, 0.8, 0],
          ],
        ],
      ]);

      expect(detections, hasLength(2));
      expect(detections.first.confidence, closeTo(0.9, 1e-9));
      expect(detections.first.x, closeTo(0.1, 1e-9));
      expect(detections.first.height, closeTo(0.4, 1e-9));
    });

    test('drops rows below the confidence threshold', () {
      final List<OnDeviceDetection> detections = decoder.decode(<Object>[
        <Object>[
          <num>[0.1, 0.1, 0.2, 0.2, 0.49, 0],
          <num>[0.1, 0.1, 0.2, 0.2, 0.51, 0],
        ],
      ]);

      expect(detections, hasLength(1));
      expect(detections.single.confidence, closeTo(0.51, 1e-9));
    });

    test('drops a box that does not fit inside the frame', () {
      // The backend rejects these outright, so sending one would cost the
      // whole observation.
      final List<OnDeviceDetection> detections = decoder.decode(<Object>[
        <Object>[
          <num>[0.9, 0.9, 0.5, 0.5, 0.95, 0],
        ],
      ]);

      expect(detections, isEmpty);
    });

    test('drops a zero-area box', () {
      final List<OnDeviceDetection> detections = decoder.decode(<Object>[
        <Object>[
          <num>[0.1, 0.1, 0.0, 0.2, 0.95, 0],
        ],
      ]);

      expect(detections, isEmpty);
    });

    test('an empty output decodes to no detections, not an error', () {
      expect(decoder.decode(<Object>[<Object>[]]), isEmpty);
    });

    test('every surviving box is labelled hornet', () {
      // Documented single-class assumption: a multi-class model needs its own
      // decoder, or its non-hornet boxes would inflate hornet_count.
      final List<OnDeviceDetection> detections = decoder.decode(<Object>[
        <Object>[
          <num>[0.1, 0.1, 0.2, 0.2, 0.9, 0],
        ],
      ]);

      expect(detections.single.className, 'hornet');
    });
  });
}
