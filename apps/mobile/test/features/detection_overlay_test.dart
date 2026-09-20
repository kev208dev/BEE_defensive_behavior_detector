import 'package:beehive_guard/features/monitoring/domain/detection_tracker.dart';
import 'package:beehive_guard/features/monitoring/domain/on_device_hornet_detector.dart';
import 'package:beehive_guard/features/monitoring/presentation/detection_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('held history is visibly different from current raw detections', () {
    const box = OnDeviceDetection(
      x: .2,
      y: .2,
      width: .1,
      height: .1,
      confidence: .94,
      className: 'Vespa crabro',
    );
    final tracker = DetectionTracker();
    final current = tracker.update([box]).single;
    final held = tracker.update([]).single;
    expect(DetectionPainter.opacityFor(current), 1);
    expect(DetectionPainter.opacityFor(held), .25);
    expect(
      DetectionPainter.debugLabel(current.isCurrent),
      'RAW CURRENT DETECTION',
    );
    expect(DetectionPainter.debugLabel(held.isCurrent), 'HELD TRACK');
  });

  testWidgets(
    'debug stats report current, tracked and upload counts separately',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DetectionStatsBar(
              detectionCount: 2,
              rawCount: 1,
              uploadCount: 0,
              maxConfidence: .7,
              inferenceMs: 400,
              modelLabel: 'test',
              detecting: true,
            ),
          ),
        ),
      );
      expect(find.textContaining('Raw AI: 1 · Tracked UI: 2'), findsOneWidget);
      expect(find.textContaining('Upload >= 0.80: 0'), findsOneWidget);
    },
  );
}
