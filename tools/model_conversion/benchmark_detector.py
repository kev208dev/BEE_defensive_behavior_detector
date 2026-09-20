#!/usr/bin/env python3
"""Measure how the bundled VespAI detector behaves on small, low-resolution targets.

The detector works on high-quality stills but drops to zero when the hornets
get small in frame. That has two possible causes, and they need opposite fixes:

A. candidates are still produced, but their confidence falls under the
   threshold -> recalibrate the threshold;
B. candidates stop being produced at all -> the target is too small at the
   model's 640x640 input, which only more input pixels on the hornet (ROI
   cropping, tiling, or a larger input) can fix.

This tool reports the raw candidate distribution *before* thresholding, which
is what separates the two. It reuses the decode and letterbox from
``verify_tflite`` so that what it measures is what the app runs.

Examples::

    benchmark_detector.py --source frame.jpeg --scale-sweep
    benchmark_detector.py --source frame.jpeg --mode tiled --threshold 0.6
    benchmark_detector.py --source clip.mp4 --frame-step 15 --csv out.csv
"""

from __future__ import annotations

import argparse
import csv
import json
import statistics
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path

import cv2
import numpy as np

from verify_tflite import CLASS_NAMES, Detection, _iou, _letterbox_rgb, decode_predictions

#: Rows below this are noise, not "candidates the model nearly fired on".
CANDIDATE_FLOOR = 0.05

#: Thresholds compared side by side, per the calibration brief.
SWEEP_THRESHOLDS = (0.80, 0.75, 0.70, 0.65, 0.60, 0.50)


@dataclass
class FrameStats:
    """What one inference produced, before and after thresholding."""

    raw_candidates: int = 0
    top_objectness: float = 0.0
    top_class_probability: float = 0.0
    top_combined_confidence: float = 0.0
    inference_ms: float = 0.0
    tiles: int = 1
    detections: dict[float, list[Detection]] = field(default_factory=dict)

    def at(self, threshold: float) -> list[Detection]:
        return self.detections.get(threshold, [])


class Detector:
    """Thin wrapper so a model is loaded once and reused across frames."""

    def __init__(self, model_path: Path) -> None:
        import tensorflow as tf

        self._interpreter = tf.lite.Interpreter(model_path=str(model_path))
        self._interpreter.allocate_tensors()
        self._inputs = self._interpreter.get_input_details()
        self._outputs = self._interpreter.get_output_details()
        shape = self._inputs[0]["shape"].tolist()
        if len(shape) != 4 or shape[3] != 3:
            raise ValueError(f"Expected an NHWC image tensor, got {shape}")
        self.input_height, self.input_width = int(shape[1]), int(shape[2])

    def raw(self, image_bgr: np.ndarray) -> tuple[np.ndarray, float]:
        """Run one inference, returning the [N, 7] rows and elapsed milliseconds."""
        model_input = _letterbox_rgb(image_bgr, self.input_width, self.input_height)
        model_input = model_input.astype(np.float32)[None] / 255.0
        self._interpreter.set_tensor(self._inputs[0]["index"], model_input)
        started = time.perf_counter()
        self._interpreter.invoke()
        elapsed_ms = (time.perf_counter() - started) * 1000.0
        return self._interpreter.get_tensor(self._outputs[0]["index"])[0], elapsed_ms


def candidate_summary(rows: np.ndarray) -> tuple[int, float, float, float]:
    """Count and rank rows *before* any threshold is applied.

    A frame where this returns zero candidates is a resolution problem; one
    where it returns candidates at 0.4-0.75 is a threshold problem.
    """
    objectness = rows[:, 4]
    class_probability = rows[:, 5:7].max(axis=1)
    combined = objectness * class_probability
    above_floor = int((combined >= CANDIDATE_FLOOR).sum())
    if combined.size == 0:
        return 0, 0.0, 0.0, 0.0
    best = int(np.argmax(combined))
    return (
        above_floor,
        float(objectness[best]),
        float(class_probability[best]),
        float(combined[best]),
    )


def crop_roi(image: np.ndarray, roi: tuple[float, float, float, float] | None) -> tuple[np.ndarray, tuple[float, float, float, float]]:
    """Crop a normalized ROI, returning the crop and its normalized placement."""
    height, width = image.shape[:2]
    if roi is None:
        return image, (0.0, 0.0, 1.0, 1.0)
    x, y, w, h = roi
    left, top = int(round(x * width)), int(round(y * height))
    right, bottom = int(round((x + w) * width)), int(round((y + h) * height))
    left, top = max(0, left), max(0, top)
    right, bottom = min(width, right), min(height, bottom)
    if right <= left or bottom <= top:
        raise ValueError(f"ROI {roi} is empty against a {width}x{height} frame")
    return image[top:bottom, left:right], (left / width, top / height, (right - left) / width, (bottom - top) / height)


def tile_rects(overlap: float, columns: int = 2, rows_count: int = 2) -> list[tuple[float, float, float, float]]:
    """Normalized tiles covering a region, overlapping so edge targets survive."""
    if not 0.0 <= overlap < 1.0:
        raise ValueError("overlap must be in [0, 1)")
    tile_width = 1.0 / (columns - (columns - 1) * overlap)
    tile_height = 1.0 / (rows_count - (rows_count - 1) * overlap)
    step_x = tile_width * (1.0 - overlap)
    step_y = tile_height * (1.0 - overlap)
    rects: list[tuple[float, float, float, float]] = []
    for row in range(rows_count):
        for column in range(columns):
            x = min(column * step_x, 1.0 - tile_width)
            y = min(row * step_y, 1.0 - tile_height)
            rects.append((x, y, tile_width, tile_height))
    return rects


def to_parent(detection: Detection, placement: tuple[float, float, float, float]) -> Detection:
    """Map a detection from a sub-region back into its parent's coordinates."""
    px, py, pw, ph = placement
    mapped = dict(detection)
    mapped["x"] = px + detection["x"] * pw
    mapped["y"] = py + detection["y"] * ph
    mapped["width"] = detection["width"] * pw
    mapped["height"] = detection["height"] * ph
    return mapped  # type: ignore[return-value]


def global_nms(detections: list[Detection], iou_threshold: float) -> list[Detection]:
    """Class-aware NMS across tiles, so one hornet in an overlap counts once."""
    ordered = sorted(detections, key=lambda item: item["confidence"], reverse=True)
    kept: list[Detection] = []
    for candidate in ordered:
        if any(
            accepted["class_index"] == candidate["class_index"]
            and _iou(accepted, candidate) > iou_threshold
            for accepted in kept
        ):
            continue
        kept.append(candidate)
    return kept


def analyse(
    detector: Detector,
    frame: np.ndarray,
    *,
    mode: str,
    roi: tuple[float, float, float, float] | None,
    overlap: float,
    iou: float,
    thresholds: tuple[float, ...],
) -> FrameStats:
    """Run one frame through the chosen mode and collect stats at each threshold."""
    region, placement = crop_roi(frame, roi)
    stats = FrameStats()

    if mode == "tiled":
        rects = tile_rects(overlap)
        stats.tiles = len(rects)
        pooled: dict[float, list[Detection]] = {t: [] for t in thresholds}
        best_candidates = 0
        for rect in rects:
            tile, tile_placement = crop_roi(region, rect)
            rows, elapsed = detector.raw(tile)
            stats.inference_ms += elapsed
            count, objectness, class_probability, combined = candidate_summary(rows)
            best_candidates += count
            if combined > stats.top_combined_confidence:
                stats.top_objectness = objectness
                stats.top_class_probability = class_probability
                stats.top_combined_confidence = combined
            for threshold in thresholds:
                decoded = decode_predictions(
                    rows,
                    frame_width=tile.shape[1],
                    frame_height=tile.shape[0],
                    input_width=detector.input_width,
                    input_height=detector.input_height,
                    confidence_threshold=threshold,
                    iou_threshold=iou,
                )
                inside_region = [to_parent(item, tile_placement) for item in decoded]
                pooled[threshold].extend(to_parent(item, placement) for item in inside_region)
        stats.raw_candidates = best_candidates
        stats.detections = {t: global_nms(pooled[t], iou) for t in thresholds}
        return stats

    rows, elapsed = detector.raw(region)
    stats.inference_ms = elapsed
    (
        stats.raw_candidates,
        stats.top_objectness,
        stats.top_class_probability,
        stats.top_combined_confidence,
    ) = candidate_summary(rows)
    for threshold in thresholds:
        decoded = decode_predictions(
            rows,
            frame_width=region.shape[1],
            frame_height=region.shape[0],
            input_width=detector.input_width,
            input_height=detector.input_height,
            confidence_threshold=threshold,
            iou_threshold=iou,
        )
        stats.detections[threshold] = [to_parent(item, placement) for item in decoded]
    return stats


def downscale(frame: np.ndarray, scale: float) -> np.ndarray:
    """Shrink then restore size, so the target loses detail as if seen further away.

    This is the controlled stand-in for "the hornets are small in frame": the
    frame geometry is unchanged, only the pixels on each hornet are reduced.
    """
    if scale >= 1.0:
        return frame
    height, width = frame.shape[:2]
    small = cv2.resize(
        frame,
        (max(1, int(width * scale)), max(1, int(height * scale))),
        interpolation=cv2.INTER_AREA,
    )
    return cv2.resize(small, (width, height), interpolation=cv2.INTER_LINEAR)


def embed_in_canvas(frame: np.ndarray, fraction: float) -> np.ndarray:
    """Shrink the frame's *content* inside a same-sized canvas.

    This is the controlled stand-in for the real failure: filming a monitor
    from a distance, or a hive entrance that occupies a small part of the view.
    Unlike :func:`downscale`, it changes how many pixels land on each hornet
    relative to the model's fixed 640x640 input, which is the quantity that
    actually decides whether a small target survives.
    """
    if fraction >= 1.0:
        return frame
    height, width = frame.shape[:2]
    inner_w, inner_h = max(1, int(width * fraction)), max(1, int(height * fraction))
    inner = cv2.resize(frame, (inner_w, inner_h), interpolation=cv2.INTER_AREA)
    # Mid grey stands in for the wall around the monitor.
    canvas = np.full((height, width, 3), 60, dtype=frame.dtype)
    top, left = (height - inner_h) // 2, (width - inner_w) // 2
    canvas[top : top + inner_h, left : left + inner_w] = inner
    return canvas


def embedded_roi(fraction: float) -> tuple[float, float, float, float]:
    """The normalized ROI that exactly frames what :func:`embed_in_canvas` placed."""
    if fraction >= 1.0:
        return (0.0, 0.0, 1.0, 1.0)
    margin = (1.0 - fraction) / 2.0
    return (margin, margin, fraction, fraction)


def parse_roi(value: str | None) -> tuple[float, float, float, float] | None:
    if not value:
        return None
    parts = [float(item) for item in value.split(",")]
    if len(parts) != 4:
        raise argparse.ArgumentTypeError("--roi expects x,y,w,h as normalized values")
    return parts[0], parts[1], parts[2], parts[3]


def print_row(label: str, stats: FrameStats, threshold: float) -> None:
    detections = stats.at(threshold)
    print(
        f"  {label:<26} raw={stats.raw_candidates:<5} "
        f"obj={stats.top_objectness:.3f} cls={stats.top_class_probability:.3f} "
        f"conf={stats.top_combined_confidence:.3f} "
        f"det@{threshold:.2f}={len(detections):<3} "
        f"{stats.inference_ms:7.1f}ms"
    )


def run_image(detector: Detector, args: argparse.Namespace) -> int:
    frame = cv2.imread(str(args.source))
    if frame is None:
        raise FileNotFoundError(args.source)
    height, width = frame.shape[:2]
    explicit_roi = parse_roi(args.roi)
    print(f"source {args.source} ({width}x{height})")

    if args.screen_sweep or args.screen_fraction < 1.0:
        fractions = args.fractions if args.screen_sweep else [args.screen_fraction]
        for fraction in fractions:
            composite = embed_in_canvas(frame, fraction)
            roi = explicit_roi or embedded_roi(fraction)
            hornet_px = 0.08 * width * fraction
            print(
                f"\nin-frame fraction {fraction:.2f}  "
                f"(a hornet ~{hornet_px:.0f}px wide in a {width}px frame)"
            )
            for mode in ("full", "roi", "tiled"):
                if args.mode != "all" and args.mode != mode:
                    continue
                stats = analyse(
                    detector,
                    composite,
                    mode="tiled" if mode == "tiled" else "full",
                    roi=None if mode == "full" else roi,
                    overlap=args.overlap,
                    iou=args.iou,
                    thresholds=SWEEP_THRESHOLDS,
                )
                label = mode if mode != "tiled" else f"tiled(x{stats.tiles})"
                print_row(label, stats, args.threshold)
                if args.threshold_sweep:
                    counts = "  ".join(
                        f"{t:.2f}:{len(stats.at(t))}" for t in SWEEP_THRESHOLDS
                    )
                    print(f"    thresholds  {counts}")
        return 0

    scales = args.scales if args.scale_sweep else [args.scale]
    for scale in scales:
        scaled = downscale(frame, scale)
        print(f"\nscale {scale:.2f} (effective {int(width * scale)}x{int(height * scale)})")
        for mode in ("full", "roi", "tiled"):
            if mode == "roi" and explicit_roi is None:
                continue
            if args.mode != "all" and args.mode != mode:
                continue
            stats = analyse(
                detector,
                scaled,
                mode="tiled" if mode == "tiled" else "full",
                roi=None if mode == "full" else explicit_roi,
                overlap=args.overlap,
                iou=args.iou,
                thresholds=SWEEP_THRESHOLDS,
            )
            label = mode if mode != "tiled" else f"tiled(x{stats.tiles})"
            print_row(label, stats, args.threshold)
            if args.threshold_sweep:
                counts = "  ".join(
                    f"{t:.2f}:{len(stats.at(t))}" for t in SWEEP_THRESHOLDS
                )
                print(f"    thresholds  {counts}")
    return 0


def run_video(detector: Detector, args: argparse.Namespace) -> int:
    capture = cv2.VideoCapture(str(args.source))
    if not capture.isOpened():
        raise FileNotFoundError(args.source)
    roi = parse_roi(args.roi)
    rows: list[dict[str, object]] = []
    index = 0
    latencies: list[float] = []

    while True:
        ok, frame = capture.read()
        if not ok:
            break
        if index % args.frame_step == 0:
            stats = analyse(
                detector,
                downscale(frame, args.scale),
                mode=args.mode if args.mode in {"full", "tiled"} else "full",
                roi=roi,
                overlap=args.overlap,
                iou=args.iou,
                thresholds=SWEEP_THRESHOLDS,
            )
            latencies.append(stats.inference_ms)
            rows.append(
                {
                    "frame_index": index,
                    "timestamp": capture.get(cv2.CAP_PROP_POS_MSEC) / 1000.0,
                    "raw_candidates": stats.raw_candidates,
                    "detections": len(stats.at(args.threshold)),
                    "max_confidence": round(stats.top_combined_confidence, 4),
                    "inference_ms": round(stats.inference_ms, 2),
                    **{
                        f"det_{t:.2f}": len(stats.at(t)) for t in SWEEP_THRESHOLDS
                    },
                }
            )
        index += 1
    capture.release()

    if args.csv:
        with open(args.csv, "w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
            writer.writeheader()
            writer.writerows(rows)
        print(f"wrote {len(rows)} rows to {args.csv}")

    detected = sum(1 for row in rows if int(row["detections"]) > 0)
    print(f"frames analysed {len(rows)}  with detections {detected}")
    for threshold in SWEEP_THRESHOLDS:
        hit = sum(1 for row in rows if int(row[f"det_{threshold:.2f}"]) > 0)
        total = sum(int(row[f"det_{threshold:.2f}"]) for row in rows)
        print(f"  threshold {threshold:.2f}  frames_with_detection={hit:<4} total_detections={total}")
    if latencies:
        print(f"latency mean {statistics.mean(latencies):.1f}ms  max {max(latencies):.1f}ms")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", type=Path, default=Path("apps/mobile/assets/models/hornet.tflite"))
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--threshold", type=float, default=0.8)
    parser.add_argument("--iou", type=float, default=0.45)
    parser.add_argument("--roi", type=str, default=None, help="normalized x,y,w,h")
    parser.add_argument("--mode", choices=("full", "roi", "tiled", "all"), default="all")
    parser.add_argument("--overlap", type=float, default=0.2)
    parser.add_argument("--frame-step", type=int, default=10)
    parser.add_argument("--scale", type=float, default=1.0)
    parser.add_argument("--scale-sweep", action="store_true")
    parser.add_argument("--scales", type=float, nargs="+", default=[1.0, 0.5, 0.35, 0.25, 0.15, 0.1])
    parser.add_argument("--threshold-sweep", action="store_true")
    parser.add_argument("--screen-fraction", type=float, default=1.0)
    parser.add_argument("--screen-sweep", action="store_true")
    parser.add_argument(
        "--fractions", type=float, nargs="+", default=[1.0, 0.6, 0.4, 0.3, 0.2, 0.15]
    )
    parser.add_argument("--csv", type=Path, default=None)
    args = parser.parse_args()

    detector = Detector(args.model)
    if args.source.suffix.lower() in {".mp4", ".mov", ".avi", ".mkv"}:
        return run_video(detector, args)
    return run_image(detector, args)


if __name__ == "__main__":
    sys.exit(main())
