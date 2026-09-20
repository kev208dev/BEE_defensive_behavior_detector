/// Defensive readers for decoded JSON maps.
///
/// The app must not crash because a field arrived as `int` where `double` was
/// expected, or was missing entirely. These helpers keep every model's
/// `fromJson` total, which matters more than strictness when a demo is live.
abstract final class JsonReader {
  static String string(Map<String, dynamic> json, String key, {String fallback = ''}) {
    final Object? value = json[key];
    return value is String ? value : fallback;
  }

  static String? stringOrNull(Map<String, dynamic> json, String key) {
    final Object? value = json[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  static int integer(Map<String, dynamic> json, String key, {int fallback = 0}) {
    final Object? value = json[key];
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static double decimal(
    Map<String, dynamic> json,
    String key, {
    double fallback = 0,
  }) {
    final Object? value = json[key];
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static bool boolean(
    Map<String, dynamic> json,
    String key, {
    bool fallback = false,
  }) {
    final Object? value = json[key];
    return value is bool ? value : fallback;
  }

  /// Parses an ISO-8601 timestamp.
  ///
  /// The backend serialises naive UTC timestamps, so a value without a zone
  /// designator is interpreted as UTC rather than local time — otherwise
  /// "2 minutes ago" would be wrong by the device's offset.
  static DateTime? dateTimeOrNull(Map<String, dynamic> json, String key) {
    final Object? value = json[key];
    if (value is! String || value.isEmpty) return null;
    final bool hasZone =
        value.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(value);
    return DateTime.tryParse(hasZone ? value : '${value}Z')?.toLocal();
  }

  static DateTime dateTime(Map<String, dynamic> json, String key) {
    return dateTimeOrNull(json, key) ?? DateTime.now();
  }

  static List<Map<String, dynamic>> objectList(
    Map<String, dynamic> json,
    String key,
  ) {
    final Object? value = json[key];
    if (value is! List) return const <Map<String, dynamic>>[];
    return value.whereType<Map<String, dynamic>>().toList(growable: false);
  }
}
