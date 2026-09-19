import 'package:dio/dio.dart';

import 'failure.dart';

/// Translates transport-level exceptions into [Failure]s.
///
/// Keeping this in one place means every repository reports problems the same
/// way, and the UI never has to know that Dio exists.
abstract final class ErrorMapper {
  static Failure map(Object error, [StackTrace? stackTrace]) {
    if (error is Failure) {
      return error;
    }
    if (error is DioException) {
      return _mapDio(error);
    }
    if (error is FormatException || error is TypeError) {
      return Failure(
        kind: FailureKind.parsing,
        message: '서버 응답을 해석할 수 없습니다.',
        cause: error,
      );
    }
    return Failure(
      kind: FailureKind.unknown,
      message: '알 수 없는 오류가 발생했습니다.',
      cause: error,
    );
  }

  static Failure _mapDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const Failure.timeout();

      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return Failure(
          kind: FailureKind.network,
          message: '서버에 연결할 수 없습니다. 네트워크와 서버 주소를 확인해주세요.',
          cause: error,
        );

      case DioExceptionType.cancel:
        return Failure(
          kind: FailureKind.unknown,
          message: '요청이 취소되었습니다.',
          cause: error,
        );

      case DioExceptionType.badCertificate:
        return Failure(
          kind: FailureKind.network,
          message: '서버 인증서를 확인할 수 없습니다.',
          cause: error,
        );

      case DioExceptionType.badResponse:
        final int? status = error.response?.statusCode;
        if (status == 404) {
          return Failure(
            kind: FailureKind.notFound,
            message: '요청한 정보를 찾을 수 없습니다.',
            statusCode: status,
            cause: error,
          );
        }
        return Failure(
          kind: FailureKind.server,
          message: '서버 오류가 발생했습니다. (${status ?? '알 수 없음'})',
          statusCode: status,
          cause: error,
        );
    }
  }
}
