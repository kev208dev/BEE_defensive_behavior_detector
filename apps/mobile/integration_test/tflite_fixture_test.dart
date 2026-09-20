// Opt-in native inference on locally served fixtures, never camera emulation.
// No network requests unless VESPAI_FIXTURE_BASE is explicitly supplied.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:beehive_guard/core/api/api_client.dart';
import 'package:beehive_guard/core/config/app_config.dart';
import 'package:beehive_guard/core/models/requests.dart';
import 'package:beehive_guard/features/monitoring/domain/detection_roi.dart';
import 'package:beehive_guard/features/monitoring/domain/detection_tracker.dart';
import 'package:beehive_guard/features/monitoring/domain/tflite_hornet_detector.dart';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const fixtureBase = String.fromEnvironment('VESPAI_FIXTURE_BASE');
  const apiBase = String.fromEnvironment('VESPAI_E2E_API');
  const hiveId = String.fromEnvironment('VESPAI_E2E_HIVE');
  testWidgets('real native TFLite fixture inference, optional metadata E2E', (
    tester,
  ) async {
    final http = HttpClient();
    addTearDown(() => http.close(force: true));
    final dio = Dio(BaseOptions(baseUrl: apiBase));
    addTearDown(() => dio.close(force: true));
    final api = ApiClient(dio);
    final tracker = DetectionTracker(iouThreshold: .3, maxMisses: 2);
    for (final item in [
      (name: 'crabro', roi: DetectionRoi.full),
      (name: 'velutina', roi: DetectionRoi.full),
      (name: 'crabro_scale_0.15', roi: DetectionRoi.full),
      (
        name: 'crabro_scale_0.15',
        roi: DetectionRoi.clamped(x: .425, y: .425, width: .15, height: .15),
      ),
      (name: 'honeybee', roi: DetectionRoi.full),
      (
        name: 'text_ui',
        roi: DetectionRoi.clamped(x: .25, y: .25, width: .5, height: .5),
      ),
      (name: 'empty_hive', roi: DetectionRoi.full),
    ]) {
      tracker.reset();
      final request = await http.getUrl(
        Uri.parse('$fixtureBase/${item.name}.jpg'),
      );
      final response = await request.close();
      expect(response.statusCode, 200);
      final bytes = BytesBuilder();
      await for (final chunk in response) {
        bytes.add(chunk);
      }
      final image = img.decodeImage(bytes.takeBytes())!;
      // Same public camera event representation as the AVFoundation BGRA stream.
      // ignore: deprecated_member_use
      final frame = CameraImage.fromPlatformData(<dynamic, dynamic>{
        'format': 1111970369, // kCVPixelFormatType_32BGRA
        'height': image.height, 'width': image.width,
        'planes': <Map<dynamic, dynamic>>[
          {
            'bytes': image.getBytes(order: img.ChannelOrder.bgra),
            'bytesPerPixel': 4,
            'bytesPerRow': image.width * 4,
            'height': image.height,
            'width': image.width,
          },
        ],
      });
      final detector = await TfliteHornetDetector.fromAsset(
        assetPath: AppConfig.tfliteModelAsset,
        modelVersion: AppConfig.modelVersion,
        decoder: const VespAiYoloV5Decoder(confidenceThreshold: .65),
        roi: item.roi,
      );
      try {
        final result = await detector.detect(frame);
        final tracked = tracker.update(result.detections);
        final upload = DetectionSnapshot.current(result.detections, .8);
        final evidence = <String, dynamic>{
          'fixture': item.name,
          'mode': item.roi.isFullFrame ? 'full' : 'roi',
          'raw': result.detections.length,
          'tracked': tracked.length,
          'upload': upload.count,
          'inference_ms': result.inferenceMs,
          'detections': result.detections
              .map(
                (d) => {
                  'class': d.className,
                  'confidence': d.confidence,
                  'bbox': [d.x, d.y, d.width, d.height],
                },
              )
              .toList(),
        };
        // Upload only an actual positive and a clean empty frame. Known model
        // false positives are recorded locally, not injected into live risk.
        if (apiBase.isNotEmpty &&
            hiveId.isNotEmpty &&
            (item.name == 'crabro' || item.name == 'empty_hive')) {
          final response = await api.uploadObservation(
            ObservationRequest(
              hiveId: hiveId,
              deviceId: 'vespai-native-fixture-evaluation',
              timestamp: DateTime.now(),
              hornetCount: upload.count,
              maxConfidence: upload.maxConfidence,
              detections: upload.detections
                  .map(
                    (d) => ObservationDetectionRequest(
                      confidence: d.confidence,
                      x: d.x,
                      y: d.y,
                      width: d.width,
                      height: d.height,
                      className: d.className,
                    ),
                  )
                  .toList(),
              inferenceMs: result.inferenceMs,
              modelVersion: result.modelVersion,
            ),
          );
          expect(response.hornetCount, upload.count);
          evidence['risk_score'] = response.riskScore;
          evidence['server_count'] = response.hornetCount;
          evidence['server_max_count'] = response.maxHornetCount;
          evidence['snapshot_url'] = response.snapshotUrl;
          expect(response.snapshotUrl, isNull);
        }
        // Measured evidence, not a claim of physical camera validation.
        // ignore: avoid_print
        print('VESPAI_NATIVE ${jsonEncode(evidence)}');
        if (item.name == 'crabro') expect(upload.count, 3);
        if (item.name == 'empty_hive') expect(upload.count, 0);
      } finally {
        await detector.dispose();
      }
    }
  }, skip: fixtureBase.isEmpty);
}
