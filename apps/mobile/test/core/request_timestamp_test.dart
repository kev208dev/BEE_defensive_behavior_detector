import 'package:beehive_guard/core/models/requests.dart';
import 'package:flutter_test/flutter_test.dart';

/// The backend reads an unmarked timestamp as UTC, so anything this app sends
/// has to carry the offset. A phone in KST that sends local wall-clock time
/// stamps every heartbeat nine hours ahead, and `is_offline()` then measures a
/// negative age — the hive stays "online" forever after the phone is gone.
void main() {
  // A fixed instant expressed in KST (UTC+9), the competition's timezone.
  final DateTime kst = DateTime.parse('2026-09-19T21:00:00+09:00');
  const String expected = '2026-09-19T12:00:00.000Z';

  group('timestamps are serialised as UTC', () {
    test('HeartbeatRequest', () {
      final Map<String, dynamic> json = HeartbeatRequest(
        hiveId: 'hive-a',
        deviceId: 'phone-1',
        timestamp: kst,
        cameraOk: true,
        microphoneOk: true,
        monitoring: true,
      ).toJson();

      expect(json['timestamp'], expected);
    });

    test('ObservationRequest', () {
      final Map<String, dynamic> json = ObservationRequest(
        hiveId: 'hive-a',
        deviceId: 'phone-1',
        timestamp: kst,
        hornetCount: 0,
        maxConfidence: 0,
        detections: const <ObservationDetectionRequest>[],
        inferenceMs: 12,
        modelVersion: 'mock-v1',
      ).toJson();

      expect(json['timestamp'], expected);
    });

    test('a local DateTime is converted, not relabelled', () {
      // Whatever the test machine's zone is, the wire value must be UTC and
      // must denote the same instant.
      final DateTime local = DateTime(2026, 9, 19, 21);
      final Map<String, dynamic> json = HeartbeatRequest(
        hiveId: 'hive-a',
        deviceId: 'phone-1',
        timestamp: local,
        cameraOk: true,
        microphoneOk: true,
        monitoring: true,
      ).toJson();

      final String encoded = json['timestamp']! as String;
      expect(encoded, endsWith('Z'));
      expect(DateTime.parse(encoded).isAtSameMomentAs(local), isTrue);
    });
  });
}
