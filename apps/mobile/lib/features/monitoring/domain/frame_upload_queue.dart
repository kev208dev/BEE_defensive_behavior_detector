import 'dart:async';

import 'package:flutter/foundation.dart';

/// A frame waiting to be uploaded.
@immutable
class PendingFrame {
  const PendingFrame({required this.bytes, required this.capturedAt});

  final Uint8List bytes;
  final DateTime capturedAt;
}

/// Outcome of one upload attempt, reported back to the controller.
@immutable
class UploadOutcome<T> {
  const UploadOutcome.success(this.value)
      : failure = null,
        succeeded = true;

  const UploadOutcome.failure(this.failure)
      : value = null,
        succeeded = false;

  final T? value;
  final Object? failure;
  final bool succeeded;
}

/// Single-flight, latest-wins upload queue.
///
/// **The problem it solves.** The camera produces a frame every second
/// regardless of how the network is doing. On a slow uplink, a naive
/// implementation queues every frame and the backlog grows without bound —
/// memory climbs, and the server ends up analysing footage from minutes ago
/// while an attack is happening *now*.
///
/// **The rule.** At most one upload is in flight. While it is, newly captured
/// frames overwrite a single pending slot rather than being appended, so the
/// old frame is dropped. The server therefore always receives the freshest
/// frame available the moment it is free to take one, and memory use is
/// bounded at two frames no matter how bad the connection gets.
class FrameUploadQueue<T> {
  FrameUploadQueue({required this.upload});

  /// Performs the actual upload. Injected so this class stays testable and
  /// knows nothing about HTTP.
  final Future<T> Function(PendingFrame frame) upload;

  PendingFrame? _pending;
  bool _inFlight = false;
  bool _closed = false;

  int _droppedCount = 0;
  int _uploadedCount = 0;

  /// Frames discarded because a newer one arrived first.
  int get droppedCount => _droppedCount;

  /// Frames successfully handed to [upload].
  int get uploadedCount => _uploadedCount;

  bool get isUploading => _inFlight;

  bool get hasPending => _pending != null;

  final StreamController<UploadOutcome<T>> _outcomes =
      StreamController<UploadOutcome<T>>.broadcast();

  /// Every upload result, in completion order.
  Stream<UploadOutcome<T>> get outcomes => _outcomes.stream;

  /// Offers a newly captured frame.
  ///
  /// Returns `true` if it was accepted for upload, `false` if it replaced an
  /// older pending frame (which was dropped) or the queue is closed.
  bool submit(Uint8List bytes, {DateTime? capturedAt}) {
    if (_closed) return false;

    final PendingFrame frame = PendingFrame(
      bytes: bytes,
      capturedAt: capturedAt ?? DateTime.now(),
    );

    if (_pending != null) {
      // Drop the older frame — freshness beats completeness here.
      _droppedCount++;
    }
    _pending = frame;

    if (!_inFlight) {
      unawaited(_drain());
    }
    return true;
  }

  /// Uploads pending frames one at a time until none is left.
  Future<void> _drain() async {
    if (_inFlight || _closed) return;
    _inFlight = true;

    try {
      while (!_closed) {
        final PendingFrame? frame = _pending;
        if (frame == null) break;
        _pending = null;

        try {
          final T result = await upload(frame);
          _uploadedCount++;
          if (!_outcomes.isClosed) {
            _outcomes.add(UploadOutcome<T>.success(result));
          }
        } on Object catch (error) {
          // A failed upload is reported and then forgotten. Retrying would
          // compete with the frame that is about to be captured anyway.
          if (!_outcomes.isClosed) {
            _outcomes.add(UploadOutcome<T>.failure(error));
          }
        }
      }
    } finally {
      _inFlight = false;
    }
  }

  /// Discards any pending frame without closing the queue.
  void clearPending() {
    if (_pending != null) {
      _droppedCount++;
      _pending = null;
    }
  }

  /// Closes the queue. In-flight work finishes; nothing new is accepted.
  Future<void> dispose() async {
    _closed = true;
    _pending = null;
    await _outcomes.close();
  }
}
