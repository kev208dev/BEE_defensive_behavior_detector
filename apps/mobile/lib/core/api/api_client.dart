import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../errors/error_mapper.dart';
import '../errors/failure.dart';
import '../errors/pairing_exception.dart';
import '../models/alert.dart';
import '../models/hive.dart';
import '../models/monitor_responses.dart';
import '../models/pairing.dart';
import '../models/requests.dart';
import 'endpoints.dart';

/// Typed access to the backend.
///
/// This is the only class in the app that knows HTTP exists. It translates
/// every transport error into a [Failure] and every response body into a
/// domain model, so repositories and controllers deal purely in domain terms.
class ApiClient {
  ApiClient(this._dio, {Dio? mediaDio}) : _mediaDio = mediaDio ?? _dio;

  final Dio _dio;
  final Dio _mediaDio;

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
    final List<Map<String, dynamic>> rows = await _getList(Endpoints.hives);
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
    final Map<String, dynamic> json = await _getObject(
      Endpoints.hiveStatus(hiveId),
    );
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
    final Map<String, dynamic> json = await _getObject(
      Endpoints.alert(alertId),
    );
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
      'image': MultipartFile.fromBytes(jpegBytes, filename: 'frame.jpg'),
    });

    final Map<String, dynamic> json = await _postObject(
      Endpoints.frame,
      data: form,
      cancelToken: cancelToken,
      client: _mediaDio,
    );
    return FrameAnalysis.fromApi(json);
  }

  /// Uploads on-device inference metadata; no camera image is transmitted.
  Future<FrameAnalysis> uploadObservation(
    ObservationRequest request, {
    CancelToken? cancelToken,
  }) async {
    final Map<String, dynamic> json = await _postObject(
      Endpoints.observation,
      data: request.toJson(),
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
      client: _mediaDio,
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
  // Pairing
  // ------------------------------------------------------------------

  /// Asks a hive for a fresh pairing code (manager side).
  Future<PairingSession> createPairing(String hiveId) async {
    final Map<String, dynamic> json = await _postObject(
      Endpoints.pairings,
      data: <String, dynamic>{'hive_id': hiveId},
    );
    return PairingSession.fromApi(json);
  }

  /// Current state of a pairing, polled while the manager's sheet is open.
  Future<PairingSession> fetchPairing(String pairingId) async {
    final Map<String, dynamic> json = await _getObject(
      Endpoints.pairing(pairingId),
    );
    return PairingSession.fromApi(json);
  }

  /// Redeems a code (monitoring side).
  ///
  /// Throws a [PairingException] carrying the server's reason, so the screen
  /// can tell the beekeeper whether to retype or ask for a new code.
  Future<PairedHive> claimPairing({
    required String code,
    required String deviceId,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        Endpoints.claimPairing,
        data: <String, dynamic>{'code': code, 'device_id': deviceId},
      );
      return PairedHive.fromApi(_asObject(response.data));
    } on DioException catch (error) {
      throw _pairingException(error);
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  /// Turns a rejected claim into a typed failure.
  ///
  /// The backend puts `{success, reason, message}` inside FastAPI's `detail`
  /// envelope; anything else (a proxy error page, a dead connection) falls
  /// back to a generic reason rather than crashing on a missing field.
  static PairingException _pairingException(DioException error) {
    if (error.response == null) {
      return const PairingException(PairingFailure.network);
    }

    final Object? data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final Object? detail = data['detail'];
      if (detail is Map<String, dynamic>) {
        return PairingException(
          PairingFailure.fromWire(detail['reason'] as String?),
          serverMessage: detail['message'] as String?,
        );
      }
    }

    // No structured body: fall back to the status code.
    return PairingException(switch (error.response?.statusCode) {
      404 => PairingFailure.invalidCode,
      409 => PairingFailure.alreadyClaimed,
      410 => PairingFailure.expired,
      429 => PairingFailure.rateLimited,
      _ => PairingFailure.unknown,
    });
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
    Dio? client,
  }) async {
    try {
      final Response<dynamic> response = await (client ?? _dio).post<dynamic>(
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
