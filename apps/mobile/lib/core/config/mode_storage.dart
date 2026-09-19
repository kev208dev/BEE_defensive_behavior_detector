import 'package:shared_preferences/shared_preferences.dart';

import '../models/hive_status.dart';

/// Persists the small amount of local state the app needs between launches:
/// which role this phone plays, which hive it watches, and its device id.
///
/// Deliberately not a full account system — the spec calls for none, and a
/// beekeeper setting up a phone in a field should not have to log in.
class ModeStorage {
  const ModeStorage(this._prefs);

  static const String _modeKey = 'app_mode';
  static const String _hiveKey = 'selected_hive_id';
  static const String _deviceKey = 'device_identifier';
  static const String _baseUrlKey = 'api_base_url';
  static const String _lastAlertSeenKey = 'last_alert_seen_at';

  final SharedPreferences _prefs;

  static Future<ModeStorage> create() async =>
      ModeStorage(await SharedPreferences.getInstance());

  AppMode? readMode() => AppMode.fromStorage(_prefs.getString(_modeKey));

  Future<void> writeMode(AppMode mode) =>
      _prefs.setString(_modeKey, mode.storageValue);

  Future<void> clearMode() => _prefs.remove(_modeKey);

  String? readSelectedHiveId() => _prefs.getString(_hiveKey);

  Future<void> writeSelectedHiveId(String hiveId) =>
      _prefs.setString(_hiveKey, hiveId);

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

  String? readBaseUrlOverride() => _prefs.getString(_baseUrlKey);

  Future<void> writeBaseUrlOverride(String value) =>
      _prefs.setString(_baseUrlKey, value);

  Future<void> clearBaseUrlOverride() => _prefs.remove(_baseUrlKey);

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
