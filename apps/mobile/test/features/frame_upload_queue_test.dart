import 'dart:async';
import 'dart:typed_data';

import 'package:beehive_guard/features/monitoring/domain/frame_upload_queue.dart';
import 'package:flutter_test/flutter_test.dart';

/// The queue's contract is what stops a slow network from turning into
/// unbounded memory growth and minutes-stale analysis. These tests pin it.
void main() {
  Uint8List frame(int marker) => Uint8List.fromList(<int>[marker]);

  group('FrameUploadQueue', () {
    test('uploads a single submitted frame', () async {
      final List<int> uploaded = <int>[];
      final FrameUploadQueue<String> queue = FrameUploadQueue<String>(
        upload: (PendingFrame f) async {
          uploaded.add(f.bytes.first);
          return 'ok';
        },
      );
      addTearDown(queue.dispose);

      queue.submit(frame(1));
      await _settle();

      expect(uploaded, <int>[1]);
      expect(queue.uploadedCount, 1);
      expect(queue.droppedCount, 0);
    });

    test('keeps only one upload in flight at a time', () async {
      int concurrent = 0;
      int maxConcurrent = 0;
      final Completer<void> gate = Completer<void>();

      final FrameUploadQueue<String> queue = FrameUploadQueue<String>(
        upload: (PendingFrame f) async {
          concurrent++;
          maxConcurrent =
              concurrent > maxConcurrent ? concurrent : maxConcurrent;
          await gate.future;
          concurrent--;
          return 'ok';
        },
      );
      addTearDown(queue.dispose);

      queue.submit(frame(1));
      await _settle();
      queue.submit(frame(2));
      queue.submit(frame(3));
      await _settle();

      expect(maxConcurrent, 1);

      gate.complete();
      await _settle();
    });

    test('drops older frames so the newest one wins', () async {
      final List<int> uploaded = <int>[];
      final Completer<void> firstUpload = Completer<void>();

      final FrameUploadQueue<String> queue = FrameUploadQueue<String>(
        upload: (PendingFrame f) async {
          uploaded.add(f.bytes.first);
          // Hold the first upload open to simulate a slow network.
          if (uploaded.length == 1) await firstUpload.future;
          return 'ok';
        },
      );
      addTearDown(queue.dispose);

      queue.submit(frame(1));
      await _settle();

      // Three more frames arrive while the first is still uploading.
      queue.submit(frame(2));
      queue.submit(frame(3));
      queue.submit(frame(4));

      firstUpload.complete();
      await _settle();

      // Frames 2 and 3 were discarded; only the freshest was sent.
      expect(uploaded, <int>[1, 4]);
      expect(queue.droppedCount, 2);
    });

    test('memory stays bounded under sustained backpressure', () async {
      final Completer<void> gate = Completer<void>();
      final FrameUploadQueue<String> queue = FrameUploadQueue<String>(
        upload: (PendingFrame f) async {
          await gate.future;
          return 'ok';
        },
      );
      addTearDown(queue.dispose);

      queue.submit(frame(0));
      await _settle();

      // A hundred frames pile up behind one stuck upload.
      for (int i = 1; i <= 100; i++) {
        queue.submit(frame(i));
      }

      // Exactly one is retained, regardless of how many arrived.
      expect(queue.hasPending, isTrue);
      expect(queue.droppedCount, 99);

      gate.complete();
      await _settle();

      expect(queue.uploadedCount, 2);
    });

    test('reports a failed upload without stopping the queue', () async {
      final List<UploadOutcome<String>> outcomes = <UploadOutcome<String>>[];
      int attempt = 0;

      final FrameUploadQueue<String> queue = FrameUploadQueue<String>(
        upload: (PendingFrame f) async {
          attempt++;
          if (attempt == 1) throw Exception('network down');
          return 'ok';
        },
      );
      addTearDown(queue.dispose);

      final StreamSubscription<UploadOutcome<String>> sub =
          queue.outcomes.listen(outcomes.add);
      addTearDown(sub.cancel);

      queue.submit(frame(1));
      await _settle();
      queue.submit(frame(2));
      await _settle();

      expect(outcomes, hasLength(2));
      expect(outcomes[0].succeeded, isFalse);
      expect(outcomes[1].succeeded, isTrue);
      // A failure must not wedge the queue.
      expect(queue.uploadedCount, 1);
    });

    test('a failed upload is not retried', () async {
      // Retrying would compete with the frame captured a second later, which
      // is fresher and therefore more useful.
      int attempts = 0;
      final FrameUploadQueue<String> queue = FrameUploadQueue<String>(
        upload: (PendingFrame f) async {
          attempts++;
          throw Exception('still down');
        },
      );
      addTearDown(queue.dispose);

      queue.submit(frame(1));
      await _settle();

      expect(attempts, 1);
    });

    test('clearPending discards a queued frame', () async {
      final Completer<void> gate = Completer<void>();
      final FrameUploadQueue<String> queue = FrameUploadQueue<String>(
        upload: (PendingFrame f) async {
          await gate.future;
          return 'ok';
        },
      );
      addTearDown(queue.dispose);

      queue.submit(frame(1));
      await _settle();
      queue.submit(frame(2));

      expect(queue.hasPending, isTrue);
      queue.clearPending();
      expect(queue.hasPending, isFalse);

      gate.complete();
      await _settle();
    });

    test('rejects submissions once disposed', () async {
      final FrameUploadQueue<String> queue = FrameUploadQueue<String>(
        upload: (PendingFrame f) async => 'ok',
      );
      await queue.dispose();

      expect(queue.submit(frame(1)), isFalse);
      expect(queue.uploadedCount, 0);
    });

    test('records the capture time of the frame that is sent', () async {
      final DateTime captured = DateTime(2026, 9, 19, 12);
      DateTime? seen;

      final FrameUploadQueue<String> queue = FrameUploadQueue<String>(
        upload: (PendingFrame f) async {
          seen = f.capturedAt;
          return 'ok';
        },
      );
      addTearDown(queue.dispose);

      queue.submit(frame(1), capturedAt: captured);
      await _settle();

      expect(seen, captured);
    });
  });
}

/// Lets queued microtasks and completed futures run.
Future<void> _settle() => Future<void>.delayed(Duration.zero);
