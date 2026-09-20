import 'package:beehive_guard/features/monitoring/domain/detection_roi.dart';
import 'package:beehive_guard/features/monitoring/presentation/detection_area_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The editor is how a beekeeper tells the detector where the hive is, so its
/// gestures have to produce a region that is actually usable: inside the
/// frame, never inverted, never collapsed to nothing.
void main() {
  const Size canvas = Size(400, 300);

  Future<DetectionRoi> drag(
    WidgetTester tester, {
    required DetectionRoi start,
    required Offset from,
    required Offset delta,
  }) async {
    DetectionRoi current = start;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: canvas.width,
              height: canvas.height,
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) =>
                    RegionEditor(
                      roi: current,
                      onChanged: (DetectionRoi roi) =>
                          setState(() => current = roi),
                    ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.dragFrom(from, delta);
    await tester.pumpAndSettle();
    return current;
  }

  testWidgets('dragging the body moves the region without resizing it', (
    WidgetTester tester,
  ) async {
    final DetectionRoi start = DetectionRoi.clamped(
      x: 0.25,
      y: 0.25,
      width: 0.5,
      height: 0.5,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: canvas.width,
              height: canvas.height,
              child: RegionEditor(roi: start, onChanged: (_) {}),
            ),
          ),
        ),
      ),
    );
    final Rect editor = tester.getRect(find.byType(RegionEditor));

    final DetectionRoi moved = await drag(
      tester,
      start: start,
      from: editor.center,
      delta: const Offset(40, 0),
    );

    expect(moved.width, closeTo(start.width, 1e-9));
    expect(moved.height, closeTo(start.height, 1e-9));
    expect(moved.x, greaterThan(start.x));
  });

  testWidgets('dragging the corner handle resizes without moving the origin', (
    WidgetTester tester,
  ) async {
    final DetectionRoi start = DetectionRoi.clamped(
      x: 0.2,
      y: 0.2,
      width: 0.4,
      height: 0.4,
    );
    // The handle sits on the bottom-right corner of the region.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: canvas.width,
              height: canvas.height,
              child: RegionEditor(roi: start, onChanged: (_) {}),
            ),
          ),
        ),
      ),
    );
    final Rect editor = tester.getRect(find.byType(RegionEditor));
    final Offset handle = Offset(
      editor.left + start.right * canvas.width,
      editor.top + start.bottom * canvas.height,
    );

    final DetectionRoi resized = await drag(
      tester,
      start: start,
      from: handle,
      delta: const Offset(40, 30),
    );

    expect(resized.x, closeTo(start.x, 1e-9));
    expect(resized.y, closeTo(start.y, 1e-9));
    expect(resized.width, greaterThan(start.width));
    expect(resized.height, greaterThan(start.height));
  });

  testWidgets('a region dragged past the edge stays inside the frame', (
    WidgetTester tester,
  ) async {
    final DetectionRoi start = DetectionRoi.clamped(
      x: 0.6,
      y: 0.6,
      width: 0.35,
      height: 0.35,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: canvas.width,
              height: canvas.height,
              child: RegionEditor(roi: start, onChanged: (_) {}),
            ),
          ),
        ),
      ),
    );
    final Rect editor = tester.getRect(find.byType(RegionEditor));

    final DetectionRoi moved = await drag(
      tester,
      start: start,
      from: editor.center.translate(60, 50),
      delta: const Offset(500, 500),
    );

    expect(moved.right, lessThanOrEqualTo(1.0 + 1e-9));
    expect(moved.bottom, lessThanOrEqualTo(1.0 + 1e-9));
    expect(moved.width, closeTo(start.width, 1e-9));
  });
}
