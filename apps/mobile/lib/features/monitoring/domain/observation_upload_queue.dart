import 'dart:async';

import 'package:flutter/foundation.dart';

import 'on_device_hornet_detector.dart';

@immutable
class PendingObservation {
  const PendingObservation({required this.result, required this.observedAt});

  final OnDeviceDetectionResult result;
  final DateTime observedAt;
}

@immutable
class UploadOutcome<T> {
  const UploadOutcome.success(this.value) : failure = null, succeeded = true;

  const UploadOutcome.failure(this.failure) : value = null, succeeded = false;

  final T? value;
  final Object? failure;
  final bool succeeded;
}

/// Single-flight, latest-wins metadata upload queue.
class ObservationUploadQueue<T> {
  ObservationUploadQueue({required this.upload});

  final Future<T> Function(PendingObservation observation) upload;

  PendingObservation? _pending;
  bool _inFlight = false;
  bool _closed = false;
  int _droppedCount = 0;
  int _uploadedCount = 0;

  int get droppedCount => _droppedCount;
  int get uploadedCount => _uploadedCount;
  bool get isUploading => _inFlight;
  bool get hasPending => _pending != null;

  final StreamController<UploadOutcome<T>> _outcomes =
      StreamController<UploadOutcome<T>>.broadcast();

  Stream<UploadOutcome<T>> get outcomes => _outcomes.stream;

  bool submit(OnDeviceDetectionResult result, {DateTime? observedAt}) {
    if (_closed) return false;
    if (_pending != null) _droppedCount++;
    _pending = PendingObservation(
      result: result,
      observedAt: observedAt ?? DateTime.now(),
    );
    if (!_inFlight) unawaited(_drain());
    return true;
  }

  Future<void> _drain() async {
    if (_inFlight || _closed) return;
    _inFlight = true;
    try {
      while (!_closed) {
        final PendingObservation? observation = _pending;
        if (observation == null) break;
        _pending = null;
        try {
          final T value = await upload(observation);
          _uploadedCount++;
          if (!_outcomes.isClosed) {
            _outcomes.add(UploadOutcome<T>.success(value));
          }
        } on Object catch (error) {
          if (!_outcomes.isClosed) {
            _outcomes.add(UploadOutcome<T>.failure(error));
          }
        }
      }
    } finally {
      _inFlight = false;
    }
  }

  Future<void> dispose() async {
    _closed = true;
    _pending = null;
    await _outcomes.close();
  }
}
