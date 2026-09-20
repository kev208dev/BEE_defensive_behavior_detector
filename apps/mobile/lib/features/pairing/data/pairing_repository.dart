import '../../../core/api/api_client.dart';
import '../../../core/errors/pairing_exception.dart';
import '../../../core/models/pairing.dart';

/// Issues and redeems pairing codes.
///
/// An interface so `DEMO_MODE` can exercise the whole pairing UI with no
/// backend, exactly like the hive and alert repositories.
abstract interface class PairingRepository {
  /// Manager side: ask a hive for a code.
  Future<PairingSession> createPairing(String hiveId);

  /// Manager side: poll whether a monitoring phone has redeemed it yet.
  Future<PairingSession> fetchPairing(String pairingId);

  /// Monitoring side: redeem a code.
  ///
  /// Throws [PairingException] when the server refuses.
  Future<PairedHive> claim({required String code, required String deviceId});
}

/// Talks to the real backend.
class ApiPairingRepository implements PairingRepository {
  const ApiPairingRepository(this._api);

  final ApiClient _api;

  @override
  Future<PairingSession> createPairing(String hiveId) =>
      _api.createPairing(hiveId);

  @override
  Future<PairingSession> fetchPairing(String pairingId) =>
      _api.fetchPairing(pairingId);

  @override
  Future<PairedHive> claim({
    required String code,
    required String deviceId,
  }) =>
      _api.claimPairing(code: code, deviceId: deviceId);
}

/// Serves a scripted pairing, for `DEMO_MODE`.
///
/// Accepts one fixed code so the flow can be walked end to end without a
/// server, and rejects everything else with a realistic failure so the error
/// states are reviewable too.
class DemoPairingRepository implements PairingRepository {
  DemoPairingRepository();

  /// The code the demo repository accepts.
  static const String demoCode = '482731';
  static const String demoHiveId = 'hive-a';
  static const String demoHiveName = '벌통 A';
  static const Duration _latency = Duration(milliseconds: 220);

  /// Flipped once a claim succeeds, so the manager's poll reports CLAIMED and
  /// the sheet closes just as it would against a real backend.
  bool _claimed = false;

  @override
  Future<PairingSession> createPairing(String hiveId) async {
    await Future<void>.delayed(_latency);
    _claimed = false;
    return PairingSession(
      id: 'demo-pairing',
      code: demoCode,
      hiveId: hiveId,
      hiveName: demoHiveName,
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      expiresInSeconds: 600,
      pairUri: buildPairUri(demoCode),
    );
  }

  @override
  Future<PairingSession> fetchPairing(String pairingId) async {
    await Future<void>.delayed(_latency);
    return PairingSession(
      id: pairingId,
      code: demoCode,
      hiveId: demoHiveId,
      hiveName: demoHiveName,
      status: _claimed ? PairingStatus.claimed : PairingStatus.waiting,
      claimedDeviceId: _claimed ? 'demo-device' : null,
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      expiresInSeconds: 600,
      pairUri: buildPairUri(demoCode),
    );
  }

  @override
  Future<PairedHive> claim({
    required String code,
    required String deviceId,
  }) async {
    await Future<void>.delayed(_latency);
    if (code != demoCode) {
      throw const PairingException(PairingFailure.invalidCode);
    }
    _claimed = true;
    return PairedHive(
      hiveId: demoHiveId,
      hiveName: demoHiveName,
      deviceId: deviceId,
      pairingId: 'demo-pairing',
    );
  }
}
