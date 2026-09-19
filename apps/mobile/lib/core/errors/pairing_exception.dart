import '../models/pairing.dart';

/// A pairing claim that the server refused.
///
/// Separate from [Failure] because the UI reacts to the *reason*, not just the
/// fact of failure: an expired code sends the beekeeper back to the manager
/// phone for a new one, while a mistyped code just needs correcting.
class PairingException implements Exception {
  const PairingException(this.failure, {this.serverMessage});

  final PairingFailure failure;

  /// The server's own wording, preferred when present so the two ends stay in
  /// step without the app having to duplicate every message.
  final String? serverMessage;

  String get message =>
      (serverMessage != null && serverMessage!.isNotEmpty)
          ? serverMessage!
          : failure.message;

  @override
  String toString() => 'PairingException(${failure.wireValue}, $message)';
}
