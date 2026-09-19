/// Small display formatters shared across screens.
abstract final class Formatters {
  /// "방금 전" / "12초 전" / "3분 전" / "2시간 전" / "5일 전".
  static String relativeTime(DateTime? time) {
    if (time == null) return '기록 없음';

    final Duration elapsed = DateTime.now().difference(time);
    if (elapsed.isNegative || elapsed.inSeconds < 5) return '방금 전';
    if (elapsed.inSeconds < 60) return '${elapsed.inSeconds}초 전';
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}분 전';
    if (elapsed.inHours < 24) return '${elapsed.inHours}시간 전';
    return '${elapsed.inDays}일 전';
  }

  /// "2026-09-19 14:03:22", for timestamps that must be exact.
  static String absoluteTime(DateTime? time) {
    if (time == null) return '-';
    final DateTime local = time.toLocal();
    return '${local.year}-${_two(local.month)}-${_two(local.day)} '
        '${_two(local.hour)}:${_two(local.minute)}:${_two(local.second)}';
  }

  /// "14:03:22", for the live screen where the date is obvious.
  static String clockTime(DateTime? time) {
    if (time == null) return '--:--:--';
    final DateTime local = time.toLocal();
    return '${_two(local.hour)}:${_two(local.minute)}:${_two(local.second)}';
  }

  /// 0.78 -> "78%".
  static String percent(double ratio) => '${(ratio.clamp(0, 1) * 100).round()}%';

  /// 0.264 -> "0.26마리/초".
  static String growthRate(double perSecond) =>
      '${perSecond.toStringAsFixed(2)}마리/초';

  static String _two(int value) => value.toString().padLeft(2, '0');
}
