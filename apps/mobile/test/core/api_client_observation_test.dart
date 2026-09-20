import 'dart:convert';
import 'dart:typed_data';

import 'package:beehive_guard/core/api/api_client.dart';
import 'package:beehive_guard/core/models/requests.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uploads observation metadata as JSON without image bytes', () async {
    final _RecordingAdapter adapter = _RecordingAdapter();
    final Dio dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final ApiClient api = ApiClient(dio);

    await api.uploadObservation(
      ObservationRequest(
        hiveId: 'hive-a',
        deviceId: 'phone-1',
        timestamp: DateTime.utc(2026, 9, 19, 12),
        hornetCount: 1,
        maxConfidence: 0.91,
        detections: const <ObservationDetectionRequest>[
          ObservationDetectionRequest(
            confidence: 0.91,
            x: 0.1,
            y: 0.2,
            width: 0.3,
            height: 0.4,
            className: 'hornet',
          ),
        ],
        inferenceMs: 37,
        modelVersion: 'mock-v1',
      ),
    );

    expect(adapter.request?.path, '/api/monitor/observation');
    final Map<String, dynamic> body =
        (adapter.request?.data as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    expect(body['hive_id'], 'hive-a');
    expect(body['hornet_count'], 1);
    expect(body['inference_ms'], 37);
    expect(body['model_version'], 'mock-v1');
    expect(body, isNot(contains('image')));
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{
        'status': 'NORMAL',
        'risk_score': 0,
        'hornet_count': 1,
        'confidence': 0.91,
        'processed_at': '2026-09-19T12:00:00Z',
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
