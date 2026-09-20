# VespAI TFLite conversion and verification

The paired multi-weight screening report is in
[`evaluations/2026-09-20/REPORT.md`](evaluations/2026-09-20/REPORT.md). It
documents the frozen protocol, hard-negative failures and why no alternative
checkpoint was exported.

This directory contains only reproducible verification code. The VespAI and
YOLOv5 repositories, downloaded samples, virtual environment, SavedModel, and
other temporary conversion files are intentionally not committed.

## Fixed inputs

- VespAI: `004f3d8930d19affd04f5d112224107c5d81eec4`
- Weight: `models/yolov5-params/yolov5s-all-but-22ip.pt`
- YOLOv5: `23701eac7a7b160e478ba4bbef966d0af9348251`
- Conversion environment: `tools/model_conversion/.venv`
- TensorFlow: `2.16.2` with legacy Keras `2.16.0`

The pinned YOLOv5 exporter was run with:

```bash
TF_USE_LEGACY_KERAS=1 tools/model_conversion/.venv/bin/python \
  /path/to/yolov5/export.py \
  --weights /path/to/vespai/models/yolov5-params/yolov5s-all-but-22ip.pt \
  --imgsz 640 --batch-size 1 --device cpu --include tflite
```

That exporter writes `yolov5s-all-but-22ip-fp16.tflite`: its default converter
stores weights as FP16 while keeping float32 input and output tensors. No INT8
quantization or embedded NMS was requested.

## Set up and verify

```bash
python3.12 -m venv tools/model_conversion/.venv
tools/model_conversion/.venv/bin/pip install -r tools/model_conversion/requirements.txt

tools/model_conversion/.venv/bin/python \
  tools/model_conversion/verify_tflite.py \
  --sample /path/to/vespai/images/example-detections/crabro/frames/frame-1.jpeg

cd tools/model_conversion
.venv/bin/python -m unittest test_verify_tflite.py
```

The verifier exits with an error when the tensor contract is wrong or the
sample yields no detection. The VespAI sample above produces three
`Vespa crabro` detections above 0.8. The corresponding velutina sample
`images/example-detections/velutina/frames/frame-11.jpeg` produces one
`Vespa velutina` detection.

## Small-target benchmark

`benchmark_detector.py` answers the question that decides the fix: when a
hornet gets small in frame, does the model still produce candidates that a
threshold is discarding, or does it stop producing them at all?

```bash
tools/model_conversion/.venv/bin/python tools/model_conversion/benchmark_detector.py \
  --model apps/mobile/assets/models/hornet.tflite \
  --source /path/to/vespai/images/example-detections/crabro/frames/frame-1.jpeg \
  --screen-sweep --threshold-sweep
```

`--screen-sweep` shrinks the frame's *content* inside a same-sized canvas,
which is what filming a monitor — or a hive entrance far from the phone —
actually does. It is not the same as `--scale-sweep`, which only removes
resolution: downscaling the whole frame to 192x108 changes nothing, because
the hornet keeps its share of the 640x640 input.

### Result, VespAI crabro sample (ground truth 3 hornets)

| hornet width in a 1920px frame | mode | raw candidates | best confidence | detections @0.80 |
|---|---|---|---|---|
| ~154px | full | 54 | 0.970 | 3 |
| ~92px  | full | 58 | 0.949 | 2 (3 at 0.75) |
| ~61px  | full | 18 | 0.597 | 0 (1 at 0.50) |
| ~46px  | full | 0  | 0.001 | 0 |
| ~23px  | full | 0  | 0.002 | 0 |
| ~46px  | **ROI** | 54 | **0.969** | **3** |
| ~23px  | **ROI** | 56 | **0.965** | **3** |
| ~46px  | tiled 2x2 | 166 | 0.958 | 4 |
| ~23px  | tiled 2x2 | 69 | 0.859 | 1 |

Velutina sample (ground truth 1) behaves the same: full-frame falls to zero
candidates by ~61px, ROI holds 1 detection at 0.96 down to ~23px.

### What the numbers mean

* **Below ~46px of hornet the model emits no candidates at all** — best
  confidence 0.001. This is a resolution failure, not a threshold failure, and
  lowering the threshold cannot recover it.
* Between ~61px and ~92px there is a genuine threshold band, where 0.75
  recovers a detection 0.80 misses.
* **Cropping to the region fixes it completely** at one inference per frame:
  0.96 confidence and the full count at every size tested.
* **Tiling was rejected.** It costs 4x the inference time and it fabricates
  detections: on the velutina sample at 0.75 it reports 2 where the truth is
  1, because a hornet split across a tile boundary yields two partial boxes
  whose IoU is too low for NMS to merge. `hornet_count` is the dominant term
  in the backend risk score, so an inflated count is worse than a miss.

The confidence threshold therefore stays at VespAI's own 0.8 and is exposed as
`--dart-define=DETECTION_CONFIDENCE_THRESHOLD`. Lowering it trades hornet
recall against bee false positives, and **that trade cannot be made from these
samples** — they contain no honeybee-only footage. Measure it before changing
the default.
