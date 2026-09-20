import 'dart:async';

import 'package:beehive_guard/features/monitoring/domain/observation_upload_queue.dart';
import 'package:beehive_guard/features/monitoring/domain/on_device_hornet_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const OnDeviceDetectionResult result = OnDeviceDetectionResult(
    hornetCount: 0,
    maxConfidence: 0,
    detections: <OnDeviceDetection>[],
    inferenceMs: 3,
    modelVersion: 'mock-v1',
  );

  test('keeps a single upload in flight and latest observation wins', () async {
    final Completer<void> gate = Completer<void>();
    final List<DateTime> uploaded = <DateTime>[];
    final ObservationUploadQueue<String> queue = ObservationUploadQueue<String>(
      upload: (PendingObservation item) async {
        uploaded.add(item.observedAt);
        if (uploaded.length == 1) await gate.future;
        return 'ok';
      },
    );
    addTearDown(queue.dispose);

    final DateTime base = DateTime(2026, 9, 19, 12);
    queue.submit(result, observedAt: base);
    await _settle();
    queue.submit(result, observedAt: base.add(const Duration(seconds: 1)));
    queue.submit(result, observedAt: base.add(const Duration(seconds: 2)));

    expect(queue.droppedCount, 1);
    expect(queue.hasPending, isTrue);

    gate.complete();
    await _settle();

    expect(uploaded, <DateTime>[base, base.add(const Duration(seconds: 2))]);
    expect(queue.uploadedCount, 2);
  });

  test('reports failure and continues with the next observation', () async {
    int attempts = 0;
    final List<UploadOutcome<String>> outcomes = <UploadOutcome<String>>[];
    final ObservationUploadQueue<String> queue = ObservationUploadQueue<String>(
      upload: (_) async {
        attempts++;
        if (attempts == 1) throw Exception('network down');
        return 'ok';
      },
    );
    addTearDown(queue.dispose);
    final StreamSubscription<UploadOutcome<String>> subscription = queue
        .outcomes
        .listen(outcomes.add);
    addTearDown(subscription.cancel);

    queue.submit(result);
    await _settle();
    queue.submit(result);
    await _settle();

    expect(outcomes, hasLength(2));
    expect(outcomes.first.succeeded, isFalse);
    expect(outcomes.last.succeeded, isTrue);
    expect(queue.uploadedCount, 1);
  });
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);
