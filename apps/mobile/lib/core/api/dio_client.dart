import 'package:dio/dio.dart';

import '../config/app_config.dart';

/// Builds the configured [Dio] instance.
///
/// Timeouts are mandatory here: the monitoring loop uploads a frame every
/// second, and a request that hangs forever would stall the capture pipeline
/// behind it.
abstract final class DioClient {
  static Dio create({String? baseUrl}) {
    final Dio dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        sendTimeout: AppConfig.sendTimeout,
        responseType: ResponseType.json,
        // Non-2xx is surfaced as a DioException and mapped to a Failure,
        // rather than being silently treated as a successful response.
        validateStatus: (int? status) => status != null && status < 400,
        headers: <String, String>{'Accept': 'application/json'},
      ),
    );
    return dio;
  }
}
