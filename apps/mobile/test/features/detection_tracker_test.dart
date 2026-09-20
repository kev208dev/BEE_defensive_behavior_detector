import 'package:beehive_guard/features/monitoring/domain/detection_tracker.dart';
import 'package:beehive_guard/features/monitoring/domain/on_device_hornet_detector.dart';
import 'package:flutter_test/flutter_test.dart';

/// The tracker exists to stop a one-frame miss from erasing a hornet — on the
/// overlay, where it strobes, and in the uploaded count, where it becomes a
/// 3 -> 0 -> 2 spike the risk engine has to absorb.
void main() {
  OnDeviceDetection hornet({
    double x = 0.4,
    double y = 0.4,
    double size = 0.1,
    double confidence = 0.9,
    String className = 'Vespa velutina',
  }) => OnDeviceDetection(
    x: x,
    y: y,
    width: size,
    height: size,
    confidence: confidence,
    className: className,
  );

  group('holding a detection through a miss', () {
    test('a hornet seen once survives the next two empty frames', () {
      final DetectionTracker tracker = DetectionTracker(maxMisses: 2);

      expect(tracker.update(<OnDeviceDetection>[hornet()]), hasLength(1));
      expect(
        tracker.update(<OnDeviceDetection>[]),
        hasLength(1),
        reason: 'first miss must still be displayed',
      );
      expect(
        tracker.update(<OnDeviceDetection>[]),
        hasLength(1),
        reason: 'second miss is still within maxMisses',
      );
    });

    test('a third consecutive miss drops it', () {
      final DetectionTracker tracker = DetectionTracker(maxMisses: 2);
      tracker.update(<OnDeviceDetection>[hornet()]);

      tracker.update(<OnDeviceDetection>[]);
      tracker.update(<OnDeviceDetection>[]);

      expect(tracker.update(<OnDeviceDetection>[]), isEmpty);
    });

    test('a held track is marked as not current, so it can be drawn faded', () {
      final DetectionTracker tracker = DetectionTracker();
      tracker.update(<OnDeviceDetection>[hornet()]);

      final List<TrackedDetection> held = tracker.update(<OnDeviceDetection>[]);

      expect(held.single.isCurrent, isFalse);
      expect(held.single.missCount, 1);
    });

    test('reappearing resets the miss count and keeps the same track', () {
      final DetectionTracker tracker = DetectionTracker();
      final int id = tracker.update(<OnDeviceDetection>[hornet()]).single.id;

      tracker.update(<OnDeviceDetection>[]);
      final List<TrackedDetection> back = tracker.update(<OnDeviceDetection>[
        hornet(x: 0.42),
      ]);

      expect(back.single.id, id, reason: 'it is the same hornet');
      expect(back.single.missCount, 0);
      expect(back.single.seenCount, 2);
    });
  });

  group('matching', () {
    test('a moved box within the IoU threshold is the same track', () {
      final DetectionTracker tracker = DetectionTracker(iouThreshold: 0.3);
      final int id = tracker.update(<OnDeviceDetection>[hornet()]).single.id;

      final List<TrackedDetection> next = tracker.update(<OnDeviceDetection>[
        hornet(x: 0.44),
      ]);

      expect(next, hasLength(1));
      expect(next.single.id, id);
    });

    test('a box on the other side of the frame is a new track', () {
      final DetectionTracker tracker = DetectionTracker();
      tracker.update(<OnDeviceDetection>[hornet(x: 0.1, y: 0.1)]);

      final List<TrackedDetection> next = tracker.update(<OnDeviceDetection>[
        hornet(x: 0.8, y: 0.8),
      ]);

      // The first is held as a miss, the second is new: two hornets on screen.
      expect(next, hasLength(2));
      expect(next.map((TrackedDetection t) => t.id).toSet(), hasLength(2));
    });

    test('two species in the same place do not merge', () {
      final DetectionTracker tracker = DetectionTracker();
      tracker.update(<OnDeviceDetection>[hornet(className: 'Vespa crabro')]);

      final List<TrackedDetection> next = tracker.update(<OnDeviceDetection>[
        hornet(className: 'Vespa velutina'),
      ]);

      expect(next, hasLength(2));
    });

    test('two hornets stay two tracks across frames', () {
      final DetectionTracker tracker = DetectionTracker();
      tracker.update(<OnDeviceDetection>[
        hornet(x: 0.1, y: 0.1),
        hornet(x: 0.7, y: 0.7),
      ]);

      final List<TrackedDetection> next = tracker.update(<OnDeviceDetection>[
        hornet(x: 0.12, y: 0.1),
        hornet(x: 0.72, y: 0.7),
      ]);

      expect(next, hasLength(2));
      expect(next.every((TrackedDetection t) => t.seenCount == 2), isTrue);
    });
  });

  group('upload snapshot', () {
    test('only tracks above the upload threshold are reported', () {
      final DetectionTracker tracker = DetectionTracker();
      tracker.update(<OnDeviceDetection>[
        hornet(x: 0.1, y: 0.1, confidence: 0.92),
        hornet(x: 0.7, y: 0.7, confidence: 0.70),
      ]);

      final DetectionSnapshot snapshot = tracker.snapshotForUpload(0.8);

      expect(snapshot.count, 1);
      expect(snapshot.maxConfidence, closeTo(0.92, 1e-9));
    });

    test(
      'a past confidence peak cannot promote a current low-confidence box',
      () {
        // This is the flicker the backend used to see as 1 -> 0 -> 1.
        final DetectionTracker tracker = DetectionTracker();
        tracker.update(<OnDeviceDetection>[hornet(confidence: 0.95)]);

        tracker.update(<OnDeviceDetection>[hornet(x: 0.41, confidence: 0.70)]);
        final DetectionSnapshot snapshot = tracker.snapshotForUpload(0.8);

        expect(snapshot.count, 0);
      },
    );

    test('a missed frame retains the UI box but uploads zero', () {
      final DetectionTracker tracker = DetectionTracker();
      tracker.update(<OnDeviceDetection>[hornet(confidence: 0.95)]);

      tracker.update(<OnDeviceDetection>[]);

      expect(tracker.tracks, hasLength(1));
      expect(tracker.snapshotForUpload(0.8).count, 0);
    });

    test('held old box plus new distant box is one current upload', () {
      final tracker = DetectionTracker();
      tracker.update([hornet(x: .1)]);
      tracker.update([hornet(x: .8)]);
      expect(tracker.tracks, hasLength(2));
      expect(tracker.snapshotForUpload(.8).count, 1);
    });

    test('the snapshot satisfies the backend observation schema', () {
      // hornet_count must equal detections length, and max_confidence must be
      // zero when there are none — the API rejects anything else.
      final DetectionTracker tracker = DetectionTracker();
      tracker.update(<OnDeviceDetection>[
        hornet(x: 0.1, y: 0.1, confidence: 0.9),
        hornet(x: 0.7, y: 0.7, confidence: 0.85),
      ]);

      final DetectionSnapshot snapshot = tracker.snapshotForUpload(0.8);

      expect(snapshot.count, snapshot.detections.length);
      expect(
        snapshot.maxConfidence,
        snapshot.detections
            .map((OnDeviceDetection d) => d.confidence)
            .reduce((double a, double b) => a > b ? a : b),
      );
    });

    test(
      'nothing above threshold reports an empty, zero-confidence snapshot',
      () {
        final DetectionTracker tracker = DetectionTracker();
        tracker.update(<OnDeviceDetection>[hornet(confidence: 0.66)]);

        final DetectionSnapshot snapshot = tracker.snapshotForUpload(0.8);

        expect(snapshot.count, 0);
        expect(snapshot.maxConfidence, 0);
        expect(snapshot.detections, isEmpty);
      },
    );
  });

  test('reset forgets everything', () {
    final DetectionTracker tracker = DetectionTracker();
    tracker.update(<OnDeviceDetection>[hornet()]);

    tracker.reset();

    expect(tracker.tracks, isEmpty);
    expect(tracker.snapshotForUpload(0.8).count, 0);
  });
}
