import 'dart:convert';
import 'dart:typed_data';

import 'package:beehive_guard/core/api/api_client.dart';
import 'package:beehive_guard/core/config/mode_storage.dart';
import 'package:beehive_guard/core/providers.dart';
import 'package:beehive_guard/features/monitoring/domain/camera_service.dart';
import 'package:beehive_guard/features/monitoring/domain/monitoring_controller.dart';
import 'package:beehive_guard/features/monitoring/domain/on_device_hornet_detector.dart';
import 'package:beehive_guard/features/monitoring/domain/permission_service.dart';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'on_device_hornet_detector_test.dart' show testCameraImage;

void main() {
  test(
    'updates detection state and keeps monitoring after upload failure',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final _MonitoringAdapter adapter = _MonitoringAdapter();
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
            () async => MockOnDeviceHornetDetector(result: _detection),
          ),
          apiClientProvider.overrideWithValue(ApiClient(dio)),
        ],
      );
      addTearDown(() async {
        await container
            .read(monitoringControllerProvider.notifier)
            .stopMonitoring();
        container.dispose();
        dio.close(force: true);
      });

      final MonitoringController controller = container.read(
        monitoringControllerProvider.notifier,
      );
      controller.selectHive(hiveId: 'hive-a', hiveName: '벌통 A');

      expect(await controller.startMonitoring(), isTrue);
      session.emit(testCameraImage());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(container.read(monitoringControllerProvider).hornetCount, 1);
      expect(container.read(monitoringControllerProvider).confidence, 0.91);
      expect(container.read(monitoringControllerProvider).inferenceMs, 12);
      expect(
        container.read(monitoringControllerProvider).uploadFailure,
        isNotNull,
      );
      expect(container.read(monitoringControllerProvider).monitoring, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 1000));
      session.emit(testCameraImage());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(adapter.observationAttempts, 2);
      expect(
        container.read(monitoringControllerProvider).observationsUploaded,
        1,
      );
      expect(
        container.read(monitoringControllerProvider).uploadFailure,
        isNull,
      );
      expect(container.read(monitoringControllerProvider).monitoring, isTrue);
    },
  );
}

const OnDeviceDetectionResult _detection = OnDeviceDetectionResult(
  hornetCount: 1,
  maxConfidence: 0.91,
  detections: <OnDeviceDetection>[
    OnDeviceDetection(
      confidence: 0.91,
      x: 0.1,
      y: 0.2,
      width: 0.3,
      height: 0.4,
      className: 'hornet',
    ),
  ],
  inferenceMs: 12,
  modelVersion: 'mock-test',
);

class _GrantedCameraPermissionService extends PermissionService {
  const _GrantedCameraPermissionService();

  @override
  Future<PermissionState> requestCamera() async => PermissionState.granted;

  @override
  Future<PermissionState> requestMicrophone() async => PermissionState.denied;
}

class _FakeCameraSession implements CameraSession {
  void Function(CameraImage)? _listener;

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
  Future<void> dispose() async {}

  void emit(CameraImage image) => _listener?.call(image);
}

class _MonitoringAdapter implements HttpClientAdapter {
  int observationAttempts = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/api/monitor/observation') {
      observationAttempts++;
      if (observationAttempts == 1) {
        return ResponseBody.fromString('{"detail":"temporary"}', 503);
      }
      return _json(<String, dynamic>{
        'status': 'NORMAL',
        'risk_score': 8,
        'hornet_count': 1,
        'max_hornet_count': 1,
        'confidence': 0.91,
        'audio_probability': 0.0,
        'processed_at': '2026-09-19T12:00:00Z',
        'snapshot_url': null,
        'alert_id': null,
      });
    }
    if (options.path == '/api/monitor/heartbeat') {
      return _json(<String, dynamic>{
        'acknowledged': true,
        'hive_id': 'hive-a',
        'status': 'NORMAL',
        'risk_score': 0,
        'server_time': '2026-09-19T12:00:00Z',
        'next_heartbeat_seconds': 10,
      });
    }
    return ResponseBody.fromString('{"detail":"not found"}', 404);
  }

  ResponseBody _json(Map<String, dynamic> body) => ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>['application/json'],
    },
  );

  @override
  void close({bool force = false}) {}
}
