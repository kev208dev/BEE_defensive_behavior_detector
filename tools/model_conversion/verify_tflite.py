#!/usr/bin/env python3
"""Inspect and run the bundled VespAI TFLite detector on one image."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import TypedDict

import cv2
import numpy as np


CLASS_NAMES = ("Vespa crabro", "Vespa velutina")


class Detection(TypedDict):
    class_index: int
    class_name: str
    confidence: float
    x: float
    y: float
    width: float
    height: float


def decode_predictions(
    predictions: np.ndarray,
    *,
    frame_width: int,
    frame_height: int,
    input_width: int,
    input_height: int,
    confidence_threshold: float,
    iou_threshold: float,
) -> list[Detection]:
    """Decode normalized YOLOv5 rows and apply class-aware NMS."""
    if predictions.ndim != 2 or predictions.shape[1] != 7:
        raise ValueError(f"Expected prediction rows shaped [N, 7], got {predictions.shape}")

    scale = min(input_width / frame_width, input_height / frame_height)
    resized_width = round(frame_width * scale)
    resized_height = round(frame_height * scale)
    pad_x = (input_width - resized_width) / 2.0
    pad_y = (input_height - resized_height) / 2.0
    candidates: list[Detection] = []

    for row in predictions:
        class_index = int(np.argmax(row[5:7]))
        confidence = float(row[4] * row[5 + class_index])
        if not np.isfinite(confidence) or confidence < confidence_threshold:
            continue

        center_x, center_y = float(row[0] * input_width), float(row[1] * input_height)
        model_width, model_height = float(row[2] * input_width), float(row[3] * input_height)
        left = np.clip((center_x - model_width / 2 - pad_x) / scale, 0, frame_width)
        top = np.clip((center_y - model_height / 2 - pad_y) / scale, 0, frame_height)
        right = np.clip((center_x + model_width / 2 - pad_x) / scale, 0, frame_width)
        bottom = np.clip((center_y + model_height / 2 - pad_y) / scale, 0, frame_height)
        if right <= left or bottom <= top:
            continue

        candidates.append(
            {
                "class_index": class_index,
                "class_name": CLASS_NAMES[class_index],
                "confidence": min(confidence, 1.0),
                "x": float(left / frame_width),
                "y": float(top / frame_height),
                "width": float((right - left) / frame_width),
                "height": float((bottom - top) / frame_height),
            }
        )

    candidates.sort(key=lambda item: item["confidence"], reverse=True)
    kept: list[Detection] = []
    for candidate in candidates:
        if any(
            accepted["class_index"] == candidate["class_index"]
            and _iou(accepted, candidate) > iou_threshold
            for accepted in kept
        ):
            continue
        kept.append(candidate)
    return kept


def _iou(first: Detection, second: Detection) -> float:
    first_right, first_bottom = first["x"] + first["width"], first["y"] + first["height"]
    second_right, second_bottom = second["x"] + second["width"], second["y"] + second["height"]
    intersection_width = max(0.0, min(first_right, second_right) - max(first["x"], second["x"]))
    intersection_height = max(0.0, min(first_bottom, second_bottom) - max(first["y"], second["y"]))
    intersection = intersection_width * intersection_height
    union = first["width"] * first["height"] + second["width"] * second["height"] - intersection
    return 0.0 if union <= 0 else intersection / union


def _letterbox_rgb(image_bgr: np.ndarray, width: int, height: int) -> np.ndarray:
    image = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
    source_height, source_width = image.shape[:2]
    scale = min(width / source_width, height / source_height)
    resized_width, resized_height = round(source_width * scale), round(source_height * scale)
    resized = cv2.resize(image, (resized_width, resized_height), interpolation=cv2.INTER_NEAREST)
    horizontal_padding = (width - resized_width) / 2.0
    vertical_padding = (height - resized_height) / 2.0
    left, right = round(horizontal_padding - 0.1), round(horizontal_padding + 0.1)
    top, bottom = round(vertical_padding - 0.1), round(vertical_padding + 0.1)
    return cv2.copyMakeBorder(
        resized,
        top,
        bottom,
        left,
        right,
        cv2.BORDER_CONSTANT,
        value=(114, 114, 114),
    )


def _tensor_detail(detail: dict[str, object]) -> dict[str, object]:
    return {
        "index": int(detail["index"]),
        "name": str(detail["name"]),
        "shape": np.asarray(detail["shape"]).tolist(),
        "dtype": np.dtype(detail["dtype"]).name,
        "quantization": list(detail["quantization"]),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--model",
        type=Path,
        default=Path("apps/mobile/assets/models/hornet.tflite"),
    )
    parser.add_argument("--sample", type=Path, required=True)
    parser.add_argument("--confidence", type=float, default=0.8)
    parser.add_argument("--iou", type=float, default=0.45)
    args = parser.parse_args()

    import tensorflow as tf

    interpreter = tf.lite.Interpreter(model_path=str(args.model))
    interpreter.allocate_tensors()
    inputs, outputs = interpreter.get_input_details(), interpreter.get_output_details()
    print("INPUT", json.dumps([_tensor_detail(item) for item in inputs], indent=2))
    print("OUTPUT", json.dumps([_tensor_detail(item) for item in outputs], indent=2))
    if len(inputs) != 1 or inputs[0]["shape"].tolist() != [1, 640, 640, 3]:
        raise ValueError("Unexpected VespAI input contract")
    if len(outputs) != 1 or outputs[0]["shape"].tolist() != [1, 25200, 7]:
        raise ValueError("Unexpected VespAI output contract")

    frame = cv2.imread(str(args.sample))
    if frame is None:
        raise FileNotFoundError(args.sample)
    input_height, input_width = inputs[0]["shape"][1:3]
    model_input = _letterbox_rgb(frame, int(input_width), int(input_height))
    model_input = model_input.astype(np.float32)[None] / 255.0
    interpreter.set_tensor(inputs[0]["index"], model_input)
    interpreter.invoke()
    raw = interpreter.get_tensor(outputs[0]["index"])
    print("RAW", json.dumps({"shape": list(raw.shape), "dtype": str(raw.dtype)}))
    detections = decode_predictions(
        raw[0],
        frame_width=frame.shape[1],
        frame_height=frame.shape[0],
        input_width=int(input_width),
        input_height=int(input_height),
        confidence_threshold=args.confidence,
        iou_threshold=args.iou,
    )
    print("DETECTIONS", json.dumps(detections, indent=2))
    if not detections:
        raise RuntimeError("The sample produced no detections")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
