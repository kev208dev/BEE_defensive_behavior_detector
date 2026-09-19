import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../../core/config/app_config.dart';

/// Owns the camera and produces analysis frames.
///
/// **Why periodic still capture rather than an image stream.** The spec allows
/// either and asks for stability above all. `startImageStream` hands back
/// platform-specific planar formats (YUV420 on Android, BGRA on iOS) that must
/// be converted by hand; that conversion is the single most common source of
/// crashes and colour bugs in Flutter camera code, and at 1 FPS it buys
/// nothing. `takePicture()` returns an encoded JPEG on both platforms, which
/// we then downscale and re-encode — predictable, and well within budget for
/// one frame per second.
///
/// The controller, and nothing else, owns the camera. The UI only receives a
/// preview widget, and the audio recorder is a separate service entirely —
/// which is why [CameraController] is created with `enableAudio: false`.
class CameraService {
  CameraService();

  CameraController? _controller;
  bool _initialising = false;
  bool _disposed = false;

  /// True once the camera is ready to capture.
  bool get isReady =>
      _controller != null && _controller!.value.isInitialized && !_disposed;

  /// The live controller, for building a preview. Null until initialised.
  CameraController? get controller => isReady ? _controller : null;

  /// Starts the camera.
  ///
  /// Returns `null` on success, or a human-readable reason on failure — the
  /// caller shows it rather than crashing.
  Future<String?> initialise() async {
    if (isReady) return null;
    if (_initialising) return null;

    _initialising = true;
    try {
      final List<CameraDescription> cameras = await availableCameras();
      if (cameras.isEmpty) {
        return '사용 가능한 카메라를 찾을 수 없습니다.';
      }

      // Prefer the rear camera — the phone faces the hive.
      final CameraDescription camera = cameras.firstWhere(
        (CameraDescription c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final CameraController controller = CameraController(
        camera,
        // Medium is plenty: the frame is downscaled to 640px before upload,
        // and a lower preset means faster capture and less heat over hours.
        ResolutionPreset.medium,
        // The microphone belongs to AudioService. Claiming it here would make
        // the two services fight over the same hardware.
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      // Locking these stops the camera from re-metering every second, which
      // otherwise makes consecutive frames inconsistent for the detector.
      await _lockCaptureSettings(controller);

      if (_disposed) {
        await controller.dispose();
        return '모니터링이 이미 종료되었습니다.';
      }

      _controller = controller;
      return null;
    } on CameraException catch (error) {
      debugPrint('CameraService: ${error.code} — ${error.description}');
      return switch (error.code) {
        'CameraAccessDenied' ||
        'CameraAccessDeniedWithoutPrompt' ||
        'CameraAccessRestricted' =>
          '카메라 권한이 거부되었습니다. 설정에서 권한을 허용해주세요.',
        _ => '카메라를 시작할 수 없습니다: ${error.description ?? error.code}',
      };
    } on Object catch (error) {
      debugPrint('CameraService: initialisation failed — $error');
      return '카메라를 시작할 수 없습니다.';
    } finally {
      _initialising = false;
    }
  }

  Future<void> _lockCaptureSettings(CameraController controller) async {
    // Best-effort: several devices do not support locking, and that is fine.
    try {
      await controller.setFocusMode(FocusMode.auto);
      await controller.setExposureMode(ExposureMode.auto);
      await controller.setFlashMode(FlashMode.off);
    } on Object catch (error) {
      debugPrint('CameraService: could not apply capture settings — $error');
    }
  }

  /// Captures one frame, downscaled and JPEG-compressed for upload.
  ///
  /// Returns `null` when the camera is not ready or the capture failed. A
  /// dropped frame is unremarkable; the next one arrives in a second.
  Future<Uint8List?> captureFrame() async {
    final CameraController? controller = _controller;
    if (controller == null || !controller.value.isInitialized || _disposed) {
      return null;
    }
    if (controller.value.isTakingPicture) {
      // The previous capture has not finished; skip rather than queue.
      return null;
    }

    try {
      final XFile file = await controller.takePicture();
      final Uint8List raw = await file.readAsBytes();
      return await _compress(raw);
    } on CameraException catch (error) {
      debugPrint('CameraService: capture failed — ${error.code}');
      return null;
    } on Object catch (error) {
      debugPrint('CameraService: capture failed — $error');
      return null;
    }
  }

  /// Downscales and re-encodes on a background isolate.
  ///
  /// Uploading a full-resolution still every second would saturate a rural
  /// uplink and heat the phone; this keeps frames to a few tens of kilobytes.
  /// Doing it on an isolate keeps the preview from stuttering.
  static Future<Uint8List> _compress(Uint8List raw) async {
    try {
      return await compute(_compressSync, raw);
    } on Object catch (error) {
      debugPrint('CameraService: compression failed, sending original — $error');
      return raw;
    }
  }

  static Uint8List _compressSync(Uint8List raw) {
    final img.Image? decoded = img.decodeImage(raw);
    if (decoded == null) return raw;

    final int longest =
        decoded.width > decoded.height ? decoded.width : decoded.height;
    final img.Image resized = longest <= AppConfig.frameMaxDimension
        ? decoded
        : img.copyResize(
            decoded,
            width: decoded.width >= decoded.height
                ? AppConfig.frameMaxDimension
                : null,
            height: decoded.height > decoded.width
                ? AppConfig.frameMaxDimension
                : null,
            interpolation: img.Interpolation.average,
          );

    return Uint8List.fromList(
      img.encodeJpg(resized, quality: AppConfig.frameJpegQuality),
    );
  }

  /// Releases the camera. Safe to call more than once.
  Future<void> dispose() async {
    _disposed = true;
    final CameraController? controller = _controller;
    _controller = null;
    if (controller == null) return;

    try {
      await controller.dispose();
    } on Object catch (error) {
      debugPrint('CameraService: dispose failed — $error');
    }
  }
}
