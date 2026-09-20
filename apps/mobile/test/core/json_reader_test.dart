import 'package:beehive_guard/core/utils/json_reader.dart';
import 'package:flutter_test/flutter_test.dart';

/// The parsers must be total: a malformed or partial response should degrade,
/// never throw. A crash here would take the monitoring app down mid-demo.
void main() {
  group('JsonReader', () {
    test('reads well-formed values', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'name': 'hive',
        'count': 3,
        'ratio': 0.75,
        'flag': true,
      };

      expect(JsonReader.string(json, 'name'), 'hive');
      expect(JsonReader.integer(json, 'count'), 3);
      expect(JsonReader.decimal(json, 'ratio'), 0.75);
      expect(JsonReader.boolean(json, 'flag'), isTrue);
    });

    test('falls back when a key is missing', () {
      const Map<String, dynamic> json = <String, dynamic>{};

      expect(JsonReader.string(json, 'name', fallback: '-'), '-');
      expect(JsonReader.integer(json, 'count', fallback: 7), 7);
      expect(JsonReader.decimal(json, 'ratio', fallback: 1.5), 1.5);
      expect(JsonReader.boolean(json, 'flag', fallback: true), isTrue);
      expect(JsonReader.stringOrNull(json, 'name'), isNull);
    });

    test('coerces between numeric types', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'whole': 5,
        'fraction': 2.7,
        'text': '42',
      };

      // A float where an int was expected is the classic JSON hazard.
      expect(JsonReader.decimal(json, 'whole'), 5.0);
      expect(JsonReader.integer(json, 'fraction'), 3);
      expect(JsonReader.integer(json, 'text'), 42);
    });

    test('survives values of the wrong type entirely', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'name': 42,
        'count': <String>['not', 'a', 'number'],
        'ratio': null,
      };

      expect(JsonReader.string(json, 'name', fallback: 'x'), 'x');
      expect(JsonReader.integer(json, 'count'), 0);
      expect(JsonReader.decimal(json, 'ratio'), 0.0);
    });

    test('treats a zone-less timestamp as UTC', () {
      // The backend serialises naive UTC; reading it as local time would make
      // every "n seconds ago" wrong by the device's offset.
      final Map<String, dynamic> json = <String, dynamic>{
        'at': '2026-09-19T12:00:00',
      };

      final DateTime? parsed = JsonReader.dateTimeOrNull(json, 'at');

      expect(parsed, isNotNull);
      expect(parsed!.toUtc(), DateTime.utc(2026, 9, 19, 12));
    });

    test('respects an explicit zone designator', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'at': '2026-09-19T12:00:00Z',
      };

      expect(
        JsonReader.dateTimeOrNull(json, 'at')!.toUtc(),
        DateTime.utc(2026, 9, 19, 12),
      );
    });

    test('returns null for an unparseable timestamp', () {
      expect(
        JsonReader.dateTimeOrNull(<String, dynamic>{'at': 'nonsense'}, 'at'),
        isNull,
      );
    });

    test('filters non-objects out of a list', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'items': <dynamic>[
          <String, dynamic>{'id': 'a'},
          'not an object',
          42,
          <String, dynamic>{'id': 'b'},
        ],
      };

      final List<Map<String, dynamic>> items =
          JsonReader.objectList(json, 'items');

      expect(items, hasLength(2));
      expect(items.first['id'], 'a');
    });
  });
}
