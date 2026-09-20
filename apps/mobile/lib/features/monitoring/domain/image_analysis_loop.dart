import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import 'on_device_hornet_detector.dart';

typedef DetectionCallback = FutureOr<void> Function(
  OnDeviceDetectionResult result,
  DateTime observedAt,
);

/// Samples a continuous camera stream without ever queueing inference work.
class ImageAnalysisLoop {
  ImageAnalysisLoop({
    required this.detector,
    required this.interval,
    required this.onDetection,
    this.onBusyChanged,
    this.onFrameStarted,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final OnDeviceHornetDetector detector;
  final Duration interval;
  final DetectionCallback onDetection;
  final ValueChanged<bool>? onBusyChanged;
  final ValueChanged<CameraImage>? onFrameStarted;
  final DateTime Function() _now;

  DateTime? _lastStartedAt;
  Future<void>? _inFlight;
  bool _disposed = false;
  int _droppedWhileBusy = 0;

  bool get isBusy => _inFlight != null;
  int get droppedWhileBusy => _droppedWhileBusy;

  void add(CameraImage image) {
    if (_disposed) return;
    final DateTime observedAt = _now();

    if (_inFlight != null) {
      _droppedWhileBusy++;
      return;
    }
    final DateTime? previous = _lastStartedAt;
    if (previous != null && observedAt.difference(previous) < interval) return;

    _lastStartedAt = observedAt;
    onFrameStarted?.call(image);
    onBusyChanged?.call(true);
    final Future<void> operation = _analyse(image, observedAt);
    _inFlight = operation;
    unawaited(
      operation.whenComplete(() {
        if (identical(_inFlight, operation)) {
          _inFlight = null;
          if (!_disposed) onBusyChanged?.call(false);
        }
      }),
    );
  }

  Future<void> _analyse(CameraImage image, DateTime observedAt) async {
    try {
      final OnDeviceDetectionResult result = await detector.detect(image);
      if (!_disposed) await onDetection(result, observedAt);
    } on Object catch (error) {
      // A bad frame or failed hand-off must never stop the camera stream.
      debugPrint('ImageAnalysisLoop: dropped analysis — $error');
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _inFlight;
    await detector.dispose();
  }
}
