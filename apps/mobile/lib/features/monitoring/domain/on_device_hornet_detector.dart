import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// One normalized detection box produced on the monitoring phone.
@immutable
class OnDeviceDetection {
  const OnDeviceDetection({
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.className,
  });

  final double confidence;
  final double x;
  final double y;
  final double width;
  final double height;
  final String className;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'confidence': confidence,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'class_name': className,
  };
}

/// Metadata sent to the backend after one on-device inference.
@immutable
class OnDeviceDetectionResult {
  const OnDeviceDetectionResult({
    required this.hornetCount,
    required this.maxConfidence,
    required this.detections,
    required this.inferenceMs,
    required this.modelVersion,
  });

  final int hornetCount;
  final double maxConfidence;
  final List<OnDeviceDetection> detections;
  final int inferenceMs;
  final String modelVersion;
}

abstract interface class OnDeviceHornetDetector {
  Future<OnDeviceDetectionResult> detect(CameraImage image);
  Future<void> dispose();
}

/// Safe default used until a real model asset is supplied.
class MockOnDeviceHornetDetector implements OnDeviceHornetDetector {
  MockOnDeviceHornetDetector({
    this.result = const OnDeviceDetectionResult(
      hornetCount: 0,
      maxConfidence: 0,
      detections: <OnDeviceDetection>[],
      inferenceMs: 0,
      modelVersion: 'mock-v1',
    ),
  });

  final OnDeviceDetectionResult result;
  bool _disposed = false;

  @override
  Future<OnDeviceDetectionResult> detect(CameraImage image) async {
    if (_disposed) throw StateError('Detector has been disposed.');
    return result;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
  }
}
