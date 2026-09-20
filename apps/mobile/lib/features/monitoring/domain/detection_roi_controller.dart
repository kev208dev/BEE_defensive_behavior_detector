import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import 'detection_roi.dart';

/// The detection region this phone watches, persisted across restarts.
///
/// Held in a notifier rather than read straight from storage at each use so
/// the setup screen and the detector see the same value, and so a change takes
/// effect on the next `startMonitoring()` without the app being restarted.
final NotifierProvider<DetectionRoiController, DetectionRoi>
detectionRoiProvider = NotifierProvider<DetectionRoiController, DetectionRoi>(
  DetectionRoiController.new,
);

class DetectionRoiController extends Notifier<DetectionRoi> {
  @override
  DetectionRoi build() => ref.read(modeStorageProvider).readDetectionRoi();

  /// Stores a new region. Values outside the frame are clamped, not rejected.
  Future<void> set(DetectionRoi roi) async {
    state = roi;
    await ref.read(modeStorageProvider).writeDetectionRoi(roi);
  }

  /// Goes back to analysing the whole frame.
  Future<void> reset() async {
    state = DetectionRoi.full;
    await ref.read(modeStorageProvider).clearDetectionRoi();
  }
}
