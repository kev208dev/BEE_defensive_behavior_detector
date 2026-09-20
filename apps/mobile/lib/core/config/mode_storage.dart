import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/monitoring/domain/detection_roi.dart';

import '../models/hive_status.dart';
import '../models/pairing.dart';

/// Persists the small amount of local state the app needs between launches:
/// which role this phone plays, which hive it is paired to, and its device id.
///
/// Deliberately not a full account system — the spec calls for none, and a
/// beekeeper setting up a phone in a field should not have to log in.
///
/// The paired hive is what lets a monitoring phone that restarts overnight
/// come straight back up watching the same hive, with no code to retype.
class ModeStorage {
  const ModeStorage(this._prefs);

  static const String _modeKey = 'app_mode';
  static const String _deviceKey = 'device_identifier';
  static const String _lastAlertSeenKey = 'last_alert_seen_at';
  static const String _pairedHiveIdKey = 'paired_hive_id';
  static const String _pairedHiveNameKey = 'paired_hive_name';
  static const String _pairingIdKey = 'paired_pairing_id';
  // v1 stored viewport fractions as buffer fractions, without orientation or
  // cover metadata. It cannot be safely reinterpreted as a sensor-space ROI.
  // Retain that value for recovery and ask the operator to mark the area once.
  static const String _legacyDetectionRoiKey = 'detection_roi';
  static const String _detectionRoiKey = 'detection_roi_sensor_v2';

  final SharedPreferences _prefs;

  bool get needsDetectionRoiReview =>
      _prefs.containsKey(_legacyDetectionRoiKey) &&
      !_prefs.containsKey(_detectionRoiKey);

  static Future<ModeStorage> create() async =>
      ModeStorage(await SharedPreferences.getInstance());

  AppMode? readMode() => AppMode.fromStorage(_prefs.getString(_modeKey));

  Future<void> writeMode(AppMode mode) =>
      _prefs.setString(_modeKey, mode.storageValue);

  Future<void> clearMode() => _prefs.remove(_modeKey);

  /// The detection region this phone was last set to watch.
  ///
  /// Persisted so a phone propped in front of a hive overnight comes back up
  /// still cropping to the entrance, rather than silently reverting to the
  /// whole frame — where a hornet is too small for the model to see at all.
  DetectionRoi readDetectionRoi() {
    final String? stored = _prefs.getString(_detectionRoiKey);
    if (stored == null || stored.isEmpty) return DetectionRoi.full;
    try {
      final Object? decoded = jsonDecode(stored);
      if (decoded is! Map<String, dynamic>) return DetectionRoi.full;
      return DetectionRoi.fromJson(decoded) ?? DetectionRoi.full;
    } on FormatException {
      // Corrupt preferences must not stop monitoring from starting.
      return DetectionRoi.full;
    }
  }

  Future<void> writeDetectionRoi(DetectionRoi roi) =>
      _prefs.setString(_detectionRoiKey, jsonEncode(roi.toJson()));

  Future<void> clearDetectionRoi() => writeDetectionRoi(DetectionRoi.full);

  /// A stable per-install identifier, generated on first use.
  ///
  /// Enough to tell monitoring phones apart without any device-identifier
  /// permission or privacy exposure.
  String readOrCreateDeviceId() {
    final String? existing = _prefs.getString(_deviceKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final String generated =
        'phone-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    // Fire-and-forget: the value is returned either way, and a failed write
    // only means a new id next launch.
    unawaited(_prefs.setString(_deviceKey, generated));
    return generated;
  }

  /// The hive this phone was paired to, or `null` if it never was.
  PairedHive? readPairedHive() {
    final String? hiveId = _prefs.getString(_pairedHiveIdKey);
    if (hiveId == null || hiveId.isEmpty) return null;

    return PairedHive(
      hiveId: hiveId,
      hiveName: _prefs.getString(_pairedHiveNameKey) ?? '벌통',
      deviceId: _prefs.getString(_deviceKey) ?? '',
      pairingId: _prefs.getString(_pairingIdKey) ?? '',
    );
  }

  Future<void> writePairedHive(PairedHive paired) async {
    await _prefs.setString(_pairedHiveIdKey, paired.hiveId);
    await _prefs.setString(_pairedHiveNameKey, paired.hiveName);
    await _prefs.setString(_pairingIdKey, paired.pairingId);
  }

  /// Forgets the pairing. The device id is deliberately kept so re-pairing the
  /// same phone updates its existing registration instead of orphaning it.
  Future<void> clearPairedHive() async {
    await _prefs.remove(_pairedHiveIdKey);
    await _prefs.remove(_pairedHiveNameKey);
    await _prefs.remove(_pairingIdKey);
  }

  /// Watermark used by the manager phone's alert polling fallback.
  DateTime? readLastAlertSeenAt() {
    final String? raw = _prefs.getString(_lastAlertSeenKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> writeLastAlertSeenAt(DateTime value) =>
      _prefs.setString(_lastAlertSeenKey, value.toUtc().toIso8601String());
}

/// Local `unawaited`, so this file needn't depend on `dart:async` elsewhere.
void unawaited(Future<void> future) {
  future.ignore();
}
