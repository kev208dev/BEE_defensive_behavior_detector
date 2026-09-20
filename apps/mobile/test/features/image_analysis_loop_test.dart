import 'dart:async';

import 'package:beehive_guard/features/monitoring/domain/image_analysis_loop.dart';
import 'package:beehive_guard/features/monitoring/domain/on_device_hornet_detector.dart';
import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';

import 'on_device_hornet_detector_test.dart' show testCameraImage;

void main() {
  test('samples frames no faster than the configured interval', () async {
    DateTime now = DateTime(2026, 9, 19, 12);
    final _Detector detector = _Detector();
    final ImageAnalysisLoop loop = ImageAnalysisLoop(
      detector: detector,
      interval: const Duration(seconds: 1),
      now: () => now,
      onDetection: (_, _) {},
    );
    addTearDown(loop.dispose);

    loop.add(testCameraImage());
    await _settle();
    now = now.add(const Duration(milliseconds: 500));
    loop.add(testCameraImage());
    await _settle();
    now = now.add(const Duration(milliseconds: 500));
    loop.add(testCameraImage());
    await _settle();

    expect(detector.calls, 2);
  });

  test('never runs concurrent inference and drops frames while busy', () async {
    final Completer<void> gate = Completer<void>();
    final _Detector detector = _Detector(gate: gate);
    DateTime now = DateTime(2026, 9, 19, 12);
    final ImageAnalysisLoop loop = ImageAnalysisLoop(
      detector: detector,
      interval: Duration.zero,
      now: () => now,
      onDetection: (_, _) {},
    );
    addTearDown(loop.dispose);

    loop.add(testCameraImage());
    await _settle();
    now = now.add(const Duration(seconds: 1));
    loop.add(testCameraImage());
    loop.add(testCameraImage());

    expect(detector.calls, 1);
    expect(detector.maxConcurrent, 1);
    expect(loop.droppedWhileBusy, 2);

    gate.complete();
    await _settle();
    loop.add(testCameraImage());
    await _settle();

    expect(detector.calls, 2);
    expect(detector.maxConcurrent, 1);
  });

  test('a failed result callback does not stop later inference', () async {
    final _Detector detector = _Detector();
    int callbacks = 0;
    final ImageAnalysisLoop loop = ImageAnalysisLoop(
      detector: detector,
      interval: Duration.zero,
      onDetection: (_, _) {
        callbacks++;
        if (callbacks == 1) throw Exception('upload failed');
      },
    );
    addTearDown(loop.dispose);

    loop.add(testCameraImage());
    await _settle();
    loop.add(testCameraImage());
    await _settle();

    expect(detector.calls, 2);
    expect(callbacks, 2);
  });
}

class _Detector implements OnDeviceHornetDetector {
  _Detector({this.gate});

  final Completer<void>? gate;
  int calls = 0;
  int concurrent = 0;
  int maxConcurrent = 0;

  @override
  Future<OnDeviceDetectionResult> detect(CameraImage image) async {
    calls++;
    concurrent++;
    if (concurrent > maxConcurrent) maxConcurrent = concurrent;
    await (gate?.future ?? Future<void>.value());
    concurrent--;
    return const OnDeviceDetectionResult(
      hornetCount: 0,
      maxConfidence: 0,
      detections: <OnDeviceDetection>[],
      inferenceMs: 1,
      modelVersion: 'test',
    );
  }

  @override
  Future<void> dispose() async {}
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);
