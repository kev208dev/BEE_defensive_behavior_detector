/// Why a request failed, in terms the UI can act on.
enum FailureKind {
  /// The device could not reach the server at all.
  network,

  /// The server took too long.
  timeout,

  /// The server answered, but with an error status.
  server,

  /// The requested resource does not exist.
  notFound,

  /// The response could not be understood.
  parsing,

  /// A permission (camera, microphone, notifications) was refused.
  permission,

  /// Anything else.
  unknown,
}

/// A failure that has already been turned into something displayable.
///
/// Repositories return these instead of throwing, so that no exception can
/// escape into a widget and take the app down mid-demo.
class Failure implements Exception {
  const Failure({
    required this.kind,
    required this.message,
    this.statusCode,
    this.cause,
  });

  const Failure.network([String? message])
      : kind = FailureKind.network,
        message = message ?? '서버에 연결할 수 없습니다. 네트워크를 확인해주세요.',
        statusCode = null,
        cause = null;

  const Failure.timeout([String? message])
      : kind = FailureKind.timeout,
        message = message ?? '서버 응답이 지연되고 있습니다.',
        statusCode = null,
        cause = null;

  const Failure.permission(this.message)
      : kind = FailureKind.permission,
        statusCode = null,
        cause = null;

  final FailureKind kind;
  final String message;
  final int? statusCode;
  final Object? cause;

  /// Whether retrying the same request could plausibly succeed.
  bool get isRetryable =>
      kind == FailureKind.network ||
      kind == FailureKind.timeout ||
      (statusCode != null && statusCode! >= 500);

  /// Whether this failure means the backend is unreachable, which the
  /// connection badge reflects.
  bool get isConnectivityProblem =>
      kind == FailureKind.network || kind == FailureKind.timeout;

  @override
  String toString() => 'Failure(${kind.name}, $message, status: $statusCode)';
}
