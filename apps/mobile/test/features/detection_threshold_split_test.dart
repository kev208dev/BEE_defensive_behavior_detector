import 'dart:convert';
import 'dart:typed_data';

import 'package:beehive_guard/core/api/api_client.dart';
import 'package:beehive_guard/core/config/app_config.dart';
import 'package:beehive_guard/core/config/mode_storage.dart';
import 'package:beehive_guard/core/providers.dart';
import 'package:beehive_guard/features/monitoring/domain/camera_service.dart';
import 'package:beehive_guard/features/monitoring/domain/monitoring_controller.dart';
import 'package:beehive_guard/features/monitoring/domain/monitoring_state.dart';
import 'package:beehive_guard/features/monitoring/domain/on_device_hornet_detector.dart';
import 'package:beehive_guard/features/monitoring/domain/permission_service.dart';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'on_device_hornet_detector_test.dart' show testCameraImage;

/// The overlay and the risk engine deliberately disagree about what counts.
///
/// The overlay is a live view for someone standing at the hive, so a
/// reasonably-confident hornet is worth drawing. The uploaded count moves the
/// risk score, so it stays at VespAI's conservative 0.8. Both are served from
/// the same inference, which only works if the decoder keeps everything above
/// the *lower* of the two.
void main() {
  test('config keeps the display threshold below the upload threshold', () {
    expect(AppConfig.detectionDisplayConfidenceThreshold, 0.65);
    expect(AppConfig.detectionUploadConfidenceThreshold, 0.8);
    expect(
      AppConfig.detectionDecodeConfidenceThreshold,
      AppConfig.detectionDisplayConfidenceThreshold,
      reason: 'decoding must keep anything either consumer might want',
    );
  });

  test('a mid-confidence hornet is drawn but not uploaded', () async {
    // 0.70 sits between the two thresholds on purpose.
    final _Harness harness = await _Harness.start(
      const OnDeviceDetectionResult(
        hornetCount: 1,
        maxConfidence: 0.7,
        detections: <OnDeviceDetection>[
          OnDeviceDetection(
            x: 0.4,
            y: 0.4,
            width: 0.1,
            height: 0.1,
            confidence: 0.7,
            className: 'Vespa velutina',
          ),
        ],
        inferenceMs: 30,
        modelVersion: 'test',
      ),
    );
    addTearDown(harness.dispose);

    harness.session.emit(testCameraImage());
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(
      harness.state.trackedDetections,
      hasLength(1),
      reason: '0.70 clears the 0.65 display threshold',
    );
    expect(harness.adapter.observations, hasLength(1));
    final Map<String, dynamic> sent = harness.adapter.observations.single;
    expect(
      sent['hornet_count'],
      0,
      reason: '0.70 does not clear the 0.8 upload threshold',
    );
    expect(sent['max_confidence'], 0);
    expect(sent['detections'], isEmpty);
  });

  test('a confident hornet is both drawn and uploaded', () async {
    final _Harness harness = await _Harness.start(
      const OnDeviceDetectionResult(
        hornetCount: 1,
        maxConfidence: 0.93,
        detections: <OnDeviceDetection>[
          OnDeviceDetection(
            x: 0.4,
            y: 0.4,
            width: 0.1,
            height: 0.1,
            confidence: 0.93,
            className: 'Vespa velutina',
          ),
        ],
        inferenceMs: 30,
        modelVersion: 'test',
      ),
    );
    addTearDown(harness.dispose);

    harness.session.emit(testCameraImage());
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(harness.state.trackedDetections, hasLength(1));
    expect(harness.adapter.observations, hasLength(1));
    final Map<String, dynamic> sent = harness.adapter.observations.single;
    expect(sent['hornet_count'], 1);
    expect(sent['max_confidence'], closeTo(0.93, 1e-9));
    expect(sent['detections'], hasLength(1));
  });

  test('a detection below both thresholds is neither drawn nor sent', () async {
    final _Harness harness = await _Harness.start(
      const OnDeviceDetectionResult(
        hornetCount: 1,
        maxConfidence: 0.5,
        detections: <OnDeviceDetection>[
          OnDeviceDetection(
            x: 0.4,
            y: 0.4,
            width: 0.1,
            height: 0.1,
            confidence: 0.5,
            className: 'Vespa crabro',
          ),
        ],
        inferenceMs: 30,
        modelVersion: 'test',
      ),
    );
    addTearDown(harness.dispose);

    harness.session.emit(testCameraImage());
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(harness.state.trackedDetections, isEmpty);
    expect(harness.adapter.observations.single['hornet_count'], 0);
  });
}

class _Harness {
  _Harness({
    required this.container,
    required this.controller,
    required this.session,
    required this.dio,
    required this.adapter,
  });

  final ProviderContainer container;
  final MonitoringController controller;
  final _FakeCameraSession session;
  final Dio dio;
  final _StubAdapter adapter;

  MonitoringState get state => container.read(monitoringControllerProvider);

  static Future<_Harness> start(OnDeviceDetectionResult result) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final _StubAdapter adapter = _StubAdapter();
    final Dio dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    final _FakeCameraSession session = _FakeCameraSession();
    final CameraService camera = CameraService(
      cameraLoader: () async => const <CameraDescription>[
        CameraDescription(
          name: 'rear',
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 90,
        ),
      ],
      sessionFactory: (_, _) => session,
    );
    final ProviderContainer container = ProviderContainer(
      overrides: [
        modeStorageProvider.overrideWithValue(ModeStorage(preferences)),
        permissionServiceProvider.overrideWithValue(
          const _GrantedCameraPermissionService(),
        ),
        cameraServiceFactoryProvider.overrideWithValue(() => camera),
        onDeviceDetectorFactoryProvider.overrideWithValue(
          (_) async => MockOnDeviceHornetDetector(result: result),
        ),
        apiClientProvider.overrideWithValue(ApiClient(dio)),
      ],
    );

    final MonitoringController controller = container.read(
      monitoringControllerProvider.notifier,
    );
    controller.selectHive(hiveId: 'hive-a', hiveName: '벌통 A');
    expect(await controller.startMonitoring(), isTrue);

    return _Harness(
      container: container,
      controller: controller,
      session: session,
      dio: dio,
      adapter: adapter,
    );
  }

  Future<void> dispose() async {
    await controller.stopMonitoring();
    container.dispose();
    dio.close(force: true);
  }
}

class _GrantedCameraPermissionService extends PermissionService {
  const _GrantedCameraPermissionService();

  @override
  Future<PermissionState> requestCamera() async => PermissionState.granted;

  @override
  Future<PermissionState> requestMicrophone() async => PermissionState.denied;
}

class _FakeCameraSession implements CameraSession {
  void Function(CameraImage)? _listener;

  bool disposed = false;

  @override
  bool isInitialized = false;

  @override
  bool isStreamingImages = false;

  @override
  CameraController? get previewController => null;

  @override
  Future<void> initialize() async => isInitialized = true;

  @override
  Future<void> applyStableSettings() async {}

  @override
  Future<void> startImageStream(void Function(CameraImage) onImage) async {
    isStreamingImages = true;
    _listener = onImage;
  }

  @override
  Future<void> stopImageStream() async {
    isStreamingImages = false;
    _listener = null;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    isInitialized = false;
  }

  void emit(CameraImage image) => _listener?.call(image);
}

class _StubAdapter implements HttpClientAdapter {
  /// Bodies posted to the observation endpoint, so a test can assert on what
  /// the backend was actually told rather than on state, which the server's
  /// echoed response overwrites.
  final List<Map<String, dynamic>> observations = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.contains('observation') && options.data is Map) {
      observations.add(Map<String, dynamic>.from(options.data as Map));
    }
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{
        'status': 'NORMAL',
        'risk_score': 0,
        'hornet_count': 0,
        'max_hornet_count': 0,
        'confidence': 0.0,
        'audio_probability': 0.0,
        'processed_at': '2026-09-20T00:00:00Z',
        'snapshot_url': null,
        'alert_id': null,
      }),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
