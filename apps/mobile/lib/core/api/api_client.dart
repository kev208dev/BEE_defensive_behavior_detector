import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../errors/error_mapper.dart';
import '../errors/failure.dart';
import '../models/alert.dart';
import '../models/hive.dart';
import '../models/monitor_responses.dart';
import '../models/requests.dart';
import 'endpoints.dart';

/// Typed access to the backend.
///
/// This is the only class in the app that knows HTTP exists. It translates
/// every transport error into a [Failure] and every response body into a
/// domain model, so repositories and controllers deal purely in domain terms.
class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  String get baseUrl => _dio.options.baseUrl;

  set baseUrl(String value) => _dio.options.baseUrl = value;

  // ------------------------------------------------------------------
  // Health
  // ------------------------------------------------------------------

  /// Whether the backend is reachable. Never throws.
  Future<bool> ping() async {
    try {
      await _dio.get<Map<String, dynamic>>(Endpoints.health);
      return true;
    } on Object {
      return false;
    }
  }

  // ------------------------------------------------------------------
  // Hives
  // ------------------------------------------------------------------

  Future<List<Hive>> fetchHives() async {
    final List<Map<String, dynamic>> rows =
        await _getList(Endpoints.hives);
    return rows.map(Hive.fromApi).toList(growable: false);
  }

  Future<DashboardSummary> fetchDashboard() async {
    final Map<String, dynamic> json = await _getObject(Endpoints.dashboard);
    return DashboardSummary.fromApi(json);
  }

  Future<HiveDetail> fetchHiveDetail(String hiveId) async {
    final Map<String, dynamic> json = await _getObject(Endpoints.hive(hiveId));
    return HiveDetail.fromApi(json);
  }

  Future<HiveStatusSnapshot> fetchHiveStatus(String hiveId) async {
    final Map<String, dynamic> json =
        await _getObject(Endpoints.hiveStatus(hiveId));
    return HiveStatusSnapshot.fromApi(json);
  }

  // ------------------------------------------------------------------
  // Alerts
  // ------------------------------------------------------------------

  Future<List<AlertSummary>> fetchAlerts({
    String? hiveId,
    DateTime? since,
    int limit = 50,
  }) async {
    final List<Map<String, dynamic>> rows = await _getList(
      Endpoints.alerts,
      query: <String, dynamic>{
        'limit': limit,
        'hive_id': ?hiveId,
        'since': ?since?.toUtc().toIso8601String(),
      },
    );
    return rows.map(AlertSummary.fromApi).toList(growable: false);
  }

  Future<AlertDetail> fetchAlertDetail(String alertId) async {
    final Map<String, dynamic> json =
        await _getObject(Endpoints.alert(alertId));
    return AlertDetail.fromApi(json);
  }

  // ------------------------------------------------------------------
  // Monitoring uploads
  // ------------------------------------------------------------------

  /// Uploads one analysis frame as multipart form data.
  Future<FrameAnalysis> uploadFrame({
    required String hiveId,
    required String deviceId,
    required Uint8List jpegBytes,
    required DateTime timestamp,
    CancelToken? cancelToken,
  }) async {
    final FormData form = FormData.fromMap(<String, dynamic>{
      'hive_id': hiveId,
      'device_id': deviceId,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'image': MultipartFile.fromBytes(
        jpegBytes,
        filename: 'frame.jpg',
      ),
    });

    final Map<String, dynamic> json = await _postObject(
      Endpoints.frame,
      data: form,
      cancelToken: cancelToken,
    );
    return FrameAnalysis.fromApi(json);
  }

  /// Uploads one recorded audio chunk.
  Future<AudioAnalysis> uploadAudio({
    required String hiveId,
    required String deviceId,
    required Uint8List audioBytes,
    required DateTime timestamp,
    String filename = 'chunk.m4a',
    CancelToken? cancelToken,
  }) async {
    final FormData form = FormData.fromMap(<String, dynamic>{
      'hive_id': hiveId,
      'device_id': deviceId,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'audio': MultipartFile.fromBytes(audioBytes, filename: filename),
    });

    final Map<String, dynamic> json = await _postObject(
      Endpoints.audio,
      data: form,
      cancelToken: cancelToken,
    );
    return AudioAnalysis.fromApi(json);
  }

  Future<HeartbeatAck> sendHeartbeat(HeartbeatRequest request) async {
    final Map<String, dynamic> json = await _postObject(
      Endpoints.heartbeat,
      data: request.toJson(),
    );
    return HeartbeatAck.fromApi(json);
  }

  // ------------------------------------------------------------------
  // Devices
  // ------------------------------------------------------------------

  Future<void> registerDevice(DeviceRegistrationRequest request) async {
    await _postObject(Endpoints.devices, data: request.toJson());
  }

  Future<void> registerPushToken(PushTokenRequest request) async {
    await _postObject(Endpoints.pushToken, data: request.toJson());
  }

  // ------------------------------------------------------------------
  // Transport helpers
  // ------------------------------------------------------------------

  Future<Map<String, dynamic>> _getObject(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        path,
        queryParameters: query,
      );
      return _asObject(response.data);
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  Future<List<Map<String, dynamic>>> _getList(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        path,
        queryParameters: query,
      );
      return _asObjectList(response.data);
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  Future<Map<String, dynamic>> _postObject(
    String path, {
    required Object data,
    CancelToken? cancelToken,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        path,
        data: data,
        cancelToken: cancelToken,
      );
      return _asObject(response.data);
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  static Map<String, dynamic> _asObject(Object? data) {
    if (data is Map<String, dynamic>) return data;
    throw const Failure(
      kind: FailureKind.parsing,
      message: '서버가 예상과 다른 형식으로 응답했습니다.',
    );
  }

  static List<Map<String, dynamic>> _asObjectList(Object? data) {
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList(growable: false);
    }
    throw const Failure(
      kind: FailureKind.parsing,
      message: '서버가 예상과 다른 형식으로 응답했습니다.',
    );
  }
}
