import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'on_device_hornet_detector.dart';

/// One hornet followed across frames.
///
/// [detection] is the most recent box actually observed for this track, so a
/// track that was missed this frame keeps drawing where it last really was
/// rather than guessing.
@immutable
class TrackedDetection {
  const TrackedDetection({
    required this.id,
    required this.detection,
    required this.missCount,
    required this.seenCount,
    required this.bestConfidence,
  });

  /// Stable identity for as long as the track lives, so the overlay can
  /// animate a box instead of replacing it every frame.
  final int id;

  /// The last box genuinely produced by the model for this track.
  final OnDeviceDetection detection;

  /// Consecutive frames this track has not been matched in.
  final int missCount;

  /// How many frames this track has been matched in, ever.
  final int seenCount;

  /// Highest confidence this track has reached.
  ///
  /// Used for the upload decision so that a hornet which dips for one frame
  /// is not dropped from the count the risk engine sees.
  final double bestConfidence;

  bool get isCurrent => missCount == 0;

  TrackedDetection _copyWith({
    OnDeviceDetection? detection,
    int? missCount,
    int? seenCount,
    double? bestConfidence,
  }) => TrackedDetection(
    id: id,
    detection: detection ?? this.detection,
    missCount: missCount ?? this.missCount,
    seenCount: seenCount ?? this.seenCount,
    bestConfidence: bestConfidence ?? this.bestConfidence,
  );
}

/// What the app reports for one moment, once flicker has been taken out.
@immutable
class DetectionSnapshot {
  const DetectionSnapshot({
    required this.detections,
    required this.maxConfidence,
  });

  static const DetectionSnapshot empty = DetectionSnapshot(
    detections: <OnDeviceDetection>[],
    maxConfidence: 0,
  );

  final List<OnDeviceDetection> detections;
  final double maxConfidence;

  int get count => detections.length;
}

/// Smooths per-frame detections into tracks that survive a brief miss.
///
/// The model is run on one sampled frame per second and a hornet that is
/// partly occluded, motion-blurred, or simply at an awkward angle drops below
/// the threshold for a frame and comes back. Drawing raw per-frame output
/// makes the overlay strobe, and feeding it straight to the backend makes the
/// hornet count jump 3 -> 0 -> 2, which is noise the risk engine then has to
/// absorb.
///
/// The rule is deliberately simple — match by IoU within a class, keep a track
/// alive for [maxMisses] further frames, then drop it. No velocity model: at
/// roughly 1 FPS a hornet moves too far between frames for extrapolation to
/// beat just holding the last known box.
class DetectionTracker {
  DetectionTracker({
    this.iouThreshold = 0.3,
    this.maxMisses = 2,
    this.minimumSeenFrames = 1,
  }) : assert(maxMisses >= 0, 'maxMisses cannot be negative'),
       assert(
         iouThreshold > 0 && iouThreshold < 1,
         'iouThreshold must be a proper overlap fraction',
       );

  /// Overlap at which a new box is considered the same hornet as a track.
  ///
  /// Lower than the NMS threshold on purpose: between two frames a second
  /// apart the same hornet has moved, so boxes that are clearly the same
  /// animal overlap less than two duplicate boxes in one frame would.
  final double iouThreshold;

  /// How many consecutive misses a track survives before it is dropped.
  final int maxMisses;

  /// Frames a track must have been seen in before it is reported at all.
  ///
  /// Left at 1 by default: with a ~1s sampling interval, requiring two
  /// sightings would delay every alert by a second for little gain.
  final int minimumSeenFrames;

  final List<TrackedDetection> _tracks = <TrackedDetection>[];
  int _nextId = 1;

  /// Tracks currently worth showing, most confident first.
  List<TrackedDetection> get tracks => List<TrackedDetection>.unmodifiable(
    _tracks.where((TrackedDetection track) => track.seenCount >= minimumSeenFrames),
  );

  /// Folds one frame of raw detections into the tracks.
  ///
  /// Returns the tracks that should be displayed, which includes ones missed
  /// in this frame but still within [maxMisses].
  List<TrackedDetection> update(List<OnDeviceDetection> observed) {
    final List<bool> claimed = List<bool>.filled(observed.length, false);
    final List<TrackedDetection> next = <TrackedDetection>[];

    // Existing tracks first, each taking its best unclaimed match. Greedy is
    // enough here: at this frame rate two hornets close enough to contend for
    // one box are not separable anyway.
    for (final TrackedDetection track in _tracks) {
      int bestIndex = -1;
      double bestIou = iouThreshold;
      for (int index = 0; index < observed.length; index++) {
        if (claimed[index]) continue;
        final OnDeviceDetection candidate = observed[index];
        if (candidate.className != track.detection.className) continue;
        final double iou = intersectionOverUnion(track.detection, candidate);
        if (iou >= bestIou) {
          bestIou = iou;
          bestIndex = index;
        }
      }

      if (bestIndex >= 0) {
        claimed[bestIndex] = true;
        final OnDeviceDetection matched = observed[bestIndex];
        next.add(
          track._copyWith(
            detection: matched,
            missCount: 0,
            seenCount: track.seenCount + 1,
            bestConfidence: math.max(track.bestConfidence, matched.confidence),
          ),
        );
        continue;
      }

      final int missCount = track.missCount + 1;
      if (missCount <= maxMisses) {
        next.add(track._copyWith(missCount: missCount));
      }
      // Otherwise the track is dropped: the hornet has gone.
    }

    for (int index = 0; index < observed.length; index++) {
      if (claimed[index]) continue;
      next.add(
        TrackedDetection(
          id: _nextId++,
          detection: observed[index],
          missCount: 0,
          seenCount: 1,
          bestConfidence: observed[index].confidence,
        ),
      );
    }

    next.sort(
      (TrackedDetection a, TrackedDetection b) =>
          b.detection.confidence.compareTo(a.detection.confidence),
    );
    _tracks
      ..clear()
      ..addAll(next);
    return tracks;
  }

  /// What to upload, filtered by the stricter server-side threshold.
  ///
  /// Reads [TrackedDetection.bestConfidence] rather than the latest frame so a
  /// hornet that dipped this frame still counts — that dip is exactly the
  /// flicker this class exists to absorb. The snapshot is self-consistent by
  /// construction: the count is the list length and the maximum is taken from
  /// the same list, which is what the backend's observation schema requires.
  DetectionSnapshot snapshotForUpload(double confidenceThreshold) {
    final List<OnDeviceDetection> detections = <OnDeviceDetection>[
      for (final TrackedDetection track in tracks)
        if (track.bestConfidence >= confidenceThreshold) track.detection,
    ];
    if (detections.isEmpty) return DetectionSnapshot.empty;
    return DetectionSnapshot(
      detections: List<OnDeviceDetection>.unmodifiable(detections),
      maxConfidence: detections.fold<double>(
        0,
        (double value, OnDeviceDetection item) =>
            math.max(value, item.confidence),
      ),
    );
  }

  /// Forgets every track, for when monitoring stops or the region changes.
  void reset() {
    _tracks.clear();
    _nextId = 1;
  }
}

/// Overlap of two normalized boxes, 0 when they do not touch.
@visibleForTesting
double intersectionOverUnion(OnDeviceDetection a, OnDeviceDetection b) {
  final double overlapWidth = math.max(
    0,
    math.min(a.x + a.width, b.x + b.width) - math.max(a.x, b.x),
  );
  final double overlapHeight = math.max(
    0,
    math.min(a.y + a.height, b.y + b.height) - math.max(a.y, b.y),
  );
  final double intersection = overlapWidth * overlapHeight;
  final double union =
      a.width * a.height + b.width * b.height - intersection;
  return union <= 0 ? 0 : intersection / union;
}
