/// The four states a hive can be in.
///
/// Hand-written rather than generated so the JSON mapping is explicit and an
/// unknown value from a newer backend degrades to [offline] instead of
/// throwing in the middle of monitoring.
enum HiveStatus {
  normal('NORMAL'),
  caution('CAUTION'),
  danger('DANGER'),
  offline('OFFLINE');

  const HiveStatus(this.wireValue);

  /// The exact string the backend uses.
  final String wireValue;

  static HiveStatus fromWire(String? value) {
    return switch (value?.toUpperCase()) {
      'NORMAL' => HiveStatus.normal,
      'CAUTION' => HiveStatus.caution,
      'DANGER' => HiveStatus.danger,
      _ => HiveStatus.offline,
    };
  }

  /// Korean label shown in the UI.
  String get label => switch (this) {
        HiveStatus.normal => '정상',
        HiveStatus.caution => '주의',
        HiveStatus.danger => '위험',
        HiveStatus.offline => '오프라인',
      };

  /// Escalation rank. Offline is a liveness state, not a threat level, so it
  /// shares rank 0 with normal.
  int get rank => switch (this) {
        HiveStatus.normal || HiveStatus.offline => 0,
        HiveStatus.caution => 1,
        HiveStatus.danger => 2,
      };

  bool get isAlerting => this == HiveStatus.caution || this == HiveStatus.danger;
}

/// Severity of an alert. Alerts are only ever raised at caution or danger.
enum AlertSeverity {
  caution('CAUTION'),
  danger('DANGER');

  const AlertSeverity(this.wireValue);

  final String wireValue;

  static AlertSeverity fromWire(String? value) {
    return value?.toUpperCase() == 'DANGER'
        ? AlertSeverity.danger
        : AlertSeverity.caution;
  }

  String get label => switch (this) {
        AlertSeverity.caution => '주의',
        AlertSeverity.danger => '위험',
      };

  /// The hive status this severity corresponds to, for shared status styling.
  HiveStatus get asStatus => switch (this) {
        AlertSeverity.caution => HiveStatus.caution,
        AlertSeverity.danger => HiveStatus.danger,
      };
}

/// Which role this phone is playing.
enum AppMode {
  /// Fixed in front of a hive, acting as the camera and microphone.
  monitoring('monitoring'),

  /// Carried by the beekeeper, receiving alerts.
  manager('manager');

  const AppMode(this.storageValue);

  final String storageValue;

  static AppMode? fromStorage(String? value) {
    return switch (value) {
      'monitoring' => AppMode.monitoring,
      'manager' => AppMode.manager,
      _ => null,
    };
  }

  String get label => switch (this) {
        AppMode.monitoring => '관찰 모드',
        AppMode.manager => '관리자 모드',
      };
}
