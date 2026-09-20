import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

typedef CameraLoader = Future<List<CameraDescription>> Function();
typedef CameraSessionFactory = CameraSession Function(
  CameraDescription description,
  ImageFormatGroup imageFormatGroup,
);

/// Narrow camera surface used by monitoring.
///
/// It intentionally exposes streaming only: still-photo capture cannot be
/// invoked anywhere in the monitoring pipeline.
abstract interface class CameraSession {
  bool get isInitialized;
  bool get isStreamingImages;
  CameraController? get previewController;

  Future<void> initialize();
  Future<void> applyStableSettings();
  Future<void> startImageStream(void Function(CameraImage image) onImage);
  Future<void> stopImageStream();
  Future<void> dispose();
}

class _PluginCameraSession implements CameraSession {
  _PluginCameraSession(
    CameraDescription description,
    ImageFormatGroup imageFormatGroup,
  ) : _controller = CameraController(
        description,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: imageFormatGroup,
      );

  final CameraController _controller;

  @override
  bool get isInitialized => _controller.value.isInitialized;

  @override
  bool get isStreamingImages => _controller.value.isStreamingImages;

  @override
  CameraController get previewController => _controller;

  @override
  Future<void> initialize() => _controller.initialize();

  @override
  Future<void> applyStableSettings() async {
    await _controller.setFocusMode(FocusMode.auto);
    await _controller.setExposureMode(ExposureMode.auto);
    await _controller.setFlashMode(FlashMode.off);
  }

  @override
  Future<void> startImageStream(void Function(CameraImage image) onImage) =>
      _controller.startImageStream(onImage);

  @override
  Future<void> stopImageStream() => _controller.stopImageStream();

  @override
  Future<void> dispose() => _controller.dispose();
}

/// Owns the preview camera and its continuous analysis stream.
class CameraService {
  CameraService({
    CameraLoader? cameraLoader,
    CameraSessionFactory? sessionFactory,
    TargetPlatform? targetPlatform,
  }) : _cameraLoader = cameraLoader ?? availableCameras,
       _sessionFactory = sessionFactory ?? _PluginCameraSession.new,
       _targetPlatform = targetPlatform ?? defaultTargetPlatform;

  final CameraLoader _cameraLoader;
  final CameraSessionFactory _sessionFactory;
  final TargetPlatform _targetPlatform;

  CameraSession? _session;
  bool _initialising = false;
  bool _disposed = false;

  bool get isReady => _session != null && _session!.isInitialized && !_disposed;

  CameraController? get controller =>
      isReady ? _session?.previewController : null;

  Future<String?> initialise() async {
    if (isReady) return null;
    if (_initialising) return null;

    _initialising = true;
    try {
      final List<CameraDescription> cameras = await _cameraLoader();
      if (cameras.isEmpty) return '사용 가능한 카메라를 찾을 수 없습니다.';

      final CameraDescription camera = cameras.firstWhere(
        (CameraDescription item) =>
            item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final CameraSession session = _sessionFactory(
        camera,
        _analysisFormatFor(_targetPlatform),
      );
      await session.initialize();
      await _applyStableSettings(session);

      if (_disposed) {
        await session.dispose();
        return '모니터링이 이미 종료되었습니다.';
      }
      _session = session;
      return null;
    } on CameraException catch (error) {
      debugPrint('CameraService: ${error.code} — ${error.description}');
      return switch (error.code) {
        'CameraAccessDenied' ||
        'CameraAccessDeniedWithoutPrompt' ||
        'CameraAccessRestricted' => '카메라 권한이 거부되었습니다. 설정에서 권한을 허용해주세요.',
        _ => '카메라를 시작할 수 없습니다: ${error.description ?? error.code}',
      };
    } on Object catch (error) {
      debugPrint('CameraService: initialisation failed — $error');
      return '카메라를 시작할 수 없습니다.';
    } finally {
      _initialising = false;
    }
  }

  static ImageFormatGroup _analysisFormatFor(TargetPlatform platform) =>
      switch (platform) {
        TargetPlatform.iOS => ImageFormatGroup.bgra8888,
        TargetPlatform.android => ImageFormatGroup.nv21,
        _ => ImageFormatGroup.yuv420,
      };

  Future<void> _applyStableSettings(CameraSession session) async {
    try {
      await session.applyStableSettings();
    } on Object catch (error) {
      debugPrint('CameraService: could not apply capture settings — $error');
    }
  }

  /// Starts preview-backed frame delivery. Returns an error message on failure.
  Future<String?> startImageStream(
    void Function(CameraImage image) onImage,
  ) async {
    final CameraSession? session = _session;
    if (session == null || !session.isInitialized || _disposed) {
      return '카메라가 준비되지 않았습니다.';
    }
    if (session.isStreamingImages) return null;

    try {
      await session.startImageStream(onImage);
      return null;
    } on CameraException catch (error) {
      debugPrint('CameraService: image stream failed — ${error.code}');
      return '카메라 분석 스트림을 시작할 수 없습니다.';
    } on Object catch (error) {
      debugPrint('CameraService: image stream failed — $error');
      return '카메라 분석 스트림을 시작할 수 없습니다.';
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final CameraSession? session = _session;
    _session = null;
    if (session == null) return;

    try {
      if (session.isStreamingImages) await session.stopImageStream();
    } on Object catch (error) {
      debugPrint('CameraService: stop stream failed — $error');
    }
    try {
      await session.dispose();
    } on Object catch (error) {
      debugPrint('CameraService: dispose failed — $error');
    }
  }
}
