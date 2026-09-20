import 'package:freezed_annotation/freezed_annotation.dart';

import '../utils/json_reader.dart';

part 'pairing.freezed.dart';

/// Lifecycle of a pairing code, mirroring the backend enum.
enum PairingStatus {
  waiting('WAITING'),
  claimed('CLAIMED'),
  expired('EXPIRED');

  const PairingStatus(this.wireValue);

  final String wireValue;

  /// Anything unrecognised is treated as [expired] — the safe direction, since
  /// it tells the manager to issue a fresh code rather than wait forever.
  static PairingStatus fromWire(String? value) {
    return switch (value?.toUpperCase()) {
      'WAITING' => PairingStatus.waiting,
      'CLAIMED' => PairingStatus.claimed,
      _ => PairingStatus.expired,
    };
  }

  String get label => switch (this) {
        PairingStatus.waiting => '연결 대기 중',
        PairingStatus.claimed => '연결 완료',
        PairingStatus.expired => '코드 만료',
      };

  bool get isWaiting => this == PairingStatus.waiting;
  bool get isClaimed => this == PairingStatus.claimed;
  bool get isExpired => this == PairingStatus.expired;
}

/// Why a claim was rejected.
///
/// The monitoring app shows a different message for each, because the right
/// next action differs: retype the digits, or go ask for a new code.
enum PairingFailure {
  invalidCode('INVALID_CODE'),
  expired('EXPIRED'),
  alreadyClaimed('ALREADY_CLAIMED'),
  rateLimited('RATE_LIMITED'),
  network('NETWORK'),
  unknown('UNKNOWN');

  const PairingFailure(this.wireValue);

  final String wireValue;

  static PairingFailure fromWire(String? value) {
    return switch (value?.toUpperCase()) {
      'INVALID_CODE' => PairingFailure.invalidCode,
      'EXPIRED' => PairingFailure.expired,
      'ALREADY_CLAIMED' => PairingFailure.alreadyClaimed,
      'RATE_LIMITED' => PairingFailure.rateLimited,
      'NETWORK' => PairingFailure.network,
      _ => PairingFailure.unknown,
    };
  }

  /// Fallback copy, used when the server did not supply its own message.
  String get message => switch (this) {
        PairingFailure.invalidCode => '존재하지 않는 코드입니다. 다시 확인해주세요.',
        PairingFailure.expired => '만료된 코드입니다. 새 코드를 발급받아주세요.',
        PairingFailure.alreadyClaimed => '이미 사용된 코드입니다. 새 코드를 발급받아주세요.',
        PairingFailure.rateLimited => '시도 횟수가 너무 많습니다. 잠시 후 다시 시도해주세요.',
        PairingFailure.network => '서버에 연결할 수 없습니다. 네트워크를 확인해주세요.',
        PairingFailure.unknown => '연결에 실패했습니다. 다시 시도해주세요.',
      };

  /// Whether retyping the same code could plausibly work.
  ///
  /// A used or expired code never will, so the UI points at getting a new one.
  bool get isRetryableWithSameCode =>
      this == PairingFailure.network || this == PairingFailure.rateLimited;
}

/// A pairing code as the manager app displays it.
@freezed
abstract class PairingSession with _$PairingSession {
  const factory PairingSession({
    required String id,
    required String code,
    required String hiveId,
    required DateTime expiresAt,
    @Default('') String hiveName,
    @Default(PairingStatus.waiting) PairingStatus status,
    @Default(0) int expiresInSeconds,
    @Default('') String pairUri,
    String? claimedDeviceId,
  }) = _PairingSession;

  const PairingSession._();

  factory PairingSession.fromApi(Map<String, dynamic> json) => PairingSession(
        id: JsonReader.string(json, 'id'),
        code: JsonReader.string(json, 'code'),
        hiveId: JsonReader.string(json, 'hive_id'),
        hiveName: JsonReader.string(json, 'hive_name'),
        expiresAt: JsonReader.dateTime(json, 'expires_at'),
        // Absent on the create response, which is always WAITING.
        status: json['status'] == null
            ? PairingStatus.waiting
            : PairingStatus.fromWire(JsonReader.stringOrNull(json, 'status')),
        expiresInSeconds: JsonReader.integer(json, 'expires_in_seconds'),
        pairUri: JsonReader.string(json, 'pair_uri'),
        claimedDeviceId: JsonReader.stringOrNull(json, 'claimed_device_id'),
      );

  /// What the QR image should encode.
  ///
  /// Falls back to building the deep link locally if the server did not send
  /// one, so an older backend still produces a scannable code.
  String get effectivePairUri =>
      pairUri.isNotEmpty ? pairUri : buildPairUri(code);

  /// "482 731" — grouped so it is easy to read aloud and retype.
  String get formattedCode {
    if (code.length != 6) return code;
    return '${code.substring(0, 3)} ${code.substring(3)}';
  }
}

/// A successful claim, as stored on the monitoring phone.
@freezed
abstract class PairedHive with _$PairedHive {
  const factory PairedHive({
    required String hiveId,
    required String hiveName,
    @Default('') String deviceId,
    @Default('') String pairingId,
  }) = _PairedHive;

  const PairedHive._();

  factory PairedHive.fromApi(Map<String, dynamic> json) => PairedHive(
        hiveId: JsonReader.string(json, 'hive_id'),
        hiveName: JsonReader.string(json, 'hive_name', fallback: '벌통'),
        deviceId: JsonReader.string(json, 'device_id'),
        pairingId: JsonReader.string(json, 'pairing_id'),
      );

  bool get isValid => hiveId.isNotEmpty;
}

/// The deep-link form a QR code carries.
///
/// Kept next to the parser so the two cannot drift apart.
String buildPairUri(String code) => 'beehiveguard://pair?code=$code';

/// Extracts a pairing code from scanned QR content.
///
/// Accepts the deep link and also a bare run of digits, so a code that was
/// photographed, typed into a note or printed on paper still works. Returns
/// `null` when the content is not one of ours, which is what lets the scanner
/// ignore unrelated QR codes instead of reporting a failure for each one.
String? parsePairCode(String? raw, {int expectedDigits = 6}) {
  if (raw == null) return null;
  final String value = raw.trim();
  if (value.isEmpty) return null;

  final RegExp digitsOnly = RegExp('^[0-9]{$expectedDigits}\$');

  // A bare code, possibly with the display spacing left in.
  final String compact = value.replaceAll(RegExp(r'[\s-]'), '');
  if (digitsOnly.hasMatch(compact)) return compact;

  final Uri? uri = Uri.tryParse(value);
  if (uri == null) return null;

  final String? fromQuery = uri.queryParameters['code'];
  if (fromQuery != null) {
    final String candidate = fromQuery.replaceAll(RegExp(r'[\s-]'), '');
    if (digitsOnly.hasMatch(candidate)) return candidate;
  }

  return null;
}
