/// Backend route constants.
///
/// One place to change if the API is versioned or moved behind a prefix.
abstract final class Endpoints {
  static const String health = '/health';

  static const String hives = '/api/hives';
  static const String dashboard = '/api/dashboard';
  static String hive(String id) => '/api/hives/$id';
  static String hiveStatus(String id) => '/api/hives/$id/status';

  static const String alerts = '/api/alerts';
  static String alert(String id) => '/api/alerts/$id';

  static const String frame = '/api/monitor/frame';
  static const String audio = '/api/monitor/audio';
  static const String heartbeat = '/api/monitor/heartbeat';

  static const String devices = '/api/devices';
  static const String pushToken = '/api/devices/push-token';
}
