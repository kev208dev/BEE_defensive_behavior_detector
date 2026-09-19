import 'dart:io';

import 'package:beehive_guard/features/monitoring/domain/camera_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'on_device_hornet_detector_test.dart' show testCameraImage;

void main() {
  const CameraDescription rearCamera = CameraDescription(
    name: 'rear',
    lensDirection: CameraLensDirection.back,
    sensorOrientation: 90,
  );

  test('starts a continuous image stream with the iOS-safe format', () async {
    final _FakeCameraSession session = _FakeCameraSession();
    ImageFormatGroup? requestedFormat;
    final CameraService service = CameraService(
      cameraLoader: () async => <CameraDescription>[rearCamera],
      sessionFactory: (_, ImageFormatGroup format) {
        requestedFormat = format;
        return session;
      },
      targetPlatform: TargetPlatform.iOS,
    );
    addTearDown(service.dispose);

    expect(await service.initialise(), isNull);
    int frames = 0;
    expect(await service.startImageStream((_) => frames++), isNull);
    session.emit(testCameraImage());

    expect(requestedFormat, ImageFormatGroup.bgra8888);
    expect(session.startCalls, 1);
    expect(frames, 1);
  });

  test('uses NV21 for the Android analysis stream', () async {
    final _FakeCameraSession session = _FakeCameraSession();
    ImageFormatGroup? requestedFormat;
    final CameraService service = CameraService(
      cameraLoader: () async => <CameraDescription>[rearCamera],
      sessionFactory: (_, ImageFormatGroup format) {
        requestedFormat = format;
        return session;
      },
      targetPlatform: TargetPlatform.android,
    );
    addTearDown(service.dispose);

    expect(await service.initialise(), isNull);

    expect(requestedFormat, ImageFormatGroup.nv21);
  });

  test('production camera path contains no still-photo capture', () {
    final String source = File(
      'lib/features/monitoring/domain/camera_service.dart',
    ).readAsStringSync();

    expect(source, contains('startImageStream'));
    expect(source, isNot(contains('takePicture')));
  });
}

class _FakeCameraSession implements CameraSession {
  void Function(CameraImage)? _listener;
  int startCalls = 0;

  @override
  bool isInitialized = false;

  @override
  bool isStreamingImages = false;

  @override
  CameraController? get previewController => null;

  @override
  Future<void> initialize() async {
    isInitialized = true;
  }

  @override
  Future<void> applyStableSettings() async {}

  @override
  Future<void> startImageStream(void Function(CameraImage) onImage) async {
    startCalls++;
    isStreamingImages = true;
    _listener = onImage;
  }

  @override
  Future<void> stopImageStream() async {
    isStreamingImages = false;
    _listener = null;
  }

  @override
  Future<void> dispose() async {}

  void emit(CameraImage image) => _listener?.call(image);
}
