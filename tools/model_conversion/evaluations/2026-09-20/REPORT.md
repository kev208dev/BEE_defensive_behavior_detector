# VespAI geometry and model comparison — 2026-09-20

## Decision

No candidate is a validated replacement. The official VespAI monitor's
`yolov5s-all-data` checkpoint was compared first, followed by the two additional
candidates below. The existing
`yolov5s-all-but-22ip` TFLite asset remains unchanged so a rejected checkpoint
is not shipped. All four VespAI YOLOv5s checkpoints produced high-confidence
false positives on cropped hard negatives. This is **case C: domain mismatch**,
not evidence that a larger generic COCO model would solve the problem.

Display and upload thresholds remain 0.65 and 0.80. ROI remains useful for
small-target recall, but also magnifies out-of-domain patterns; it is not an
accuracy substitute.

## Protocol and limitations

- VespAI revision `004f3d8930d19affd04f5d112224107c5d81eec4`.
- Pinned YOLOv5 revision `23701eac7a7b160e478ba4bbef966d0af9348251`.
- Identical RGB 640x640 nearest-neighbour letterbox, padding 114, class-aware
  NMS 0.45 and thresholds 0.65–0.90.
- Species-correct, one-to-one IoU >= 0.50 matching. Predictions are never used
  as ground truth.
- 17 positive cases / 40 expected objects. Only two independent positive
  source frames exist here; scale, edge, occlusion and UI variants are derived.
- 14 hard-negative cases: honeybee, bee swarm, paper wasp, yellowjacket,
  hoverfly, flower, leaves, hive exterior, hand, wood, yellow/black object,
  text/UI, negative thumbnail grid and empty-hive crop. These are a screening
  set, not held-out hive-entrance field validation.
- The user's original screenshot and attack video were not supplied as image
  data, so the synthetic text/thumbnail controls do not claim pixel-identical
  reproduction.
- Positive source overlap with training data is unknown. Results must not be
  presented as production accuracy.
- Fixture manifest SHA-256:
  `776398b2cd686aaa79ea998c795728a3daa475eaba76f6239a65194ecff033f4`.
- Host latency is median of three Mac CPU runs including preprocessing and
  inference, excluding decode/NMS. It is not iPhone latency.

Run `prepare_comparison.py` into a fresh directory, then `compare_weights.py`.
The comparer verifies every fixture SHA-256 before inference. Preparing into a
directory with an existing frozen manifest is rejected.

## Results at threshold 0.80

| Model | full TP / recall | full negative FP | ROI TP / recall | ROI negative FP | mean TP conf | multi exact | Mac latency |
|---|---:|---:|---:|---:|---:|---:|---:|
| all-but-22ip | 16/40 · 40.0% | 1 | 15/20 · 75.0% | 6 | .933 | 4/15 | 44.6 ms |
| all-data | 15/40 · 37.5% | 0 | 18/20 · 90.0% | 5 | .935 | 3/15 | 46.7 ms |
| all-hornets | 18/40 · 45.0% | 1 | 20/20 · 100% | 6 | .935 | 6/15 | 47.9 ms |
| 21all | 18/40 · 45.0% | 0 | 20/20 · 100% | 6 | .931 | 6/15 | 48.1 ms |
| bundled all-but-22ip TFLite | 16/40 · 40.0% | 1 | 15/20 · 75.0% | 6 | .933 | 4/15 | 60.5 ms |

The TFLite result matches its PyTorch source in TP and FP counts. File size is
14,136,328 bytes; SHA-256 is
`0a89d40e90f8204308d795b49288178260b3ed6cf78d171bbffee694b1868ba3`.

Small-target subset at 0.80: current full 4/20 versus ROI 15/20; all-data full
3/20 versus ROI 18/20; all-hornets full 3/20 versus ROI 20/20; 21all full 4/20
versus ROI 20/20. ROI materially improves small-target recall.

## Hard-negative threshold sweep

Values are negative false positives for **full / ROI** across 14 negative
cases, thresholds 0.65, 0.70, 0.75, 0.80, 0.85 and 0.90.

| Model | .65 | .70 | .75 | .80 | .85 | .90 |
|---|---:|---:|---:|---:|---:|---:|
| all-but-22ip | 9/13 | 5/12 | 2/9 | 1/6 | 0/5 | 0/1 |
| all-data | 1/12 | 0/8 | 0/6 | 0/5 | 0/4 | 0/0 |
| all-hornets | 9/18 | 5/13 | 3/8 | 1/6 | 0/0 | 0/0 |
| 21all | 3/15 | 1/14 | 0/10 | 0/6 | 0/2 | 0/1 |

At 0.80, the current full-frame false positive is the honeybee image
(`Vespa crabro`, 0.804). Cropped text/UI produces four `Vespa velutina`
detections up to 0.918. All-data avoids full-frame negative FP at 0.80 but its
ROI still produces five, including text/UI detections up to 0.896 and a
honeybee at 0.855. Other candidates also fail cropped text or yellow/black
controls. Raising the threshold hides some errors while reducing recall; it is
not a model improvement.

## Tensor and training metadata

All tested checkpoints load as two-class models:
`0 = Vespa crabro`, `1 = Vespa velutina`; 7,025,023 unfused parameters,
7,015,519 fused parameters, 213 layers, approximately 15.8 GFLOPs, raw output
`[1, 25200, 7]`. Each checkpoint is 14,369,205 bytes.

Training metadata records 500 epochs and 640px input. The notebook mounts a
private Google Drive dataset and uses Colab GPU settings (batch 64, workers 24).
The dataset itself is not in the checkout, so filename fragments are not used
to invent exact dataset composition.

Checkpoint SHA-256 values:

- all-but-22ip: `28da7714df2ec105a4600082a0a2ce565ccf1b60a64a425393fbb19709f616ef`
- all-data: `1fff0bde968690917e6136077bf144dda2e03cccaa5ae0648cf2bf5cce423694`
- all-hornets: `db8b65cf5e204dde5838b0782e933847c3deaaab153104ef9c4b90089345eb9c`
- 21all: `0cc775c6e023af1ab04e9bddd197d91d9063d81c07805ac432318c7a3123bb37`

## Geometry finding

Two independent defects existed before model scoring:

1. Detections were scaled through `BoxFit.cover` but their normalized x/y
   coordinates were not transformed for sensor/device rotation and front
   mirroring.
2. The ROI editor persisted viewport fractions as native buffer fractions,
   ignoring both cover crop and orientation.

The implementation now uses pure normalized transforms for 0/90/180/270,
front mirror and inverse ROI mapping. CameraX receives the sensor/device
transform. For the pinned AVFoundation plugin, the same pixel buffer is
rotated/mirrored before both texture publication and image streaming, so iOS
buffer-to-preview is deliberately identity to avoid double rotation. A preview
orientation change during inference discards that stale result.

Old ROI values remain stored for recovery but are not silently reinterpreted;
the operator is asked to select the area once in the corrected sensor-space
editor.

## Raw, tracked and server semantics

- Current raw boxes are solid 100% opacity.
- Held UI tracks are 25% opacity and labelled separately in debug builds.
- Debug counts are `Raw AI`, `Tracked UI` and `Upload >= 0.80`.
- The server receives only current-frame detections >= 0.80 and their current
  confidence. Held boxes and historical peak confidence never enter uploads.
- The backend continues to own time-window aggregation.

## Larger model investigation

The VespAI checkout has no hornet-trained YOLOv5m/l/x checkpoint. A generic
COCO checkpoint does not implement this two-species detector and is rejected.
The [published study](https://www.nature.com/articles/s42003-024-05979-z)
reports 3,302 bait-station images; access to the complete training data is by
author request, while the local training notebook expects a private Google
Drive dataset. Consequently, a defensible m/l fine-tune is not possible today
and no long training job was started.

[Hornet3000](https://github.com/vespCV/hornet3000) is an archived, GPL-3.0
alternative project with YOLOv8s/YOLOv10n artifacts and a different
focus/contract. It is a research candidate, not a drop-in winner and was not
shipped.

Next evidence needed: collect and annotate real fixed-phone hive-entrance hard
negatives and positives, split by site/time, obtain the original labels, then
fine-tune/evaluate s and m backbones on the same held-out field set. Compare
false positives first, then recall/count, and finally physical-iPhone latency.

## Verification boundary

Pure geometry, crop inverse, UI/upload separation, benchmark matching and
tensor contracts are automated. A native iOS fixture integration test records
raw/tracked/upload counts and can optionally send only detection metadata to
Railway. It is explicitly not a substitute for physical camera alignment,
shutter/audio behavior, or attack-video testing.

### Native iOS simulator fixture run

The bundled asset was executed through `tflite_flutter` on an iPhone 17 Pro
simulator, using BGRA frames and the production Dart preprocessing/decoder:

| Fixture | mode | raw | upload >= .80 | inference |
|---|---|---:|---:|---:|
| crabro official frame | full | 3 | 3 | 159 ms |
| velutina official frame | full | 1 | 1 | 162 ms |
| 0.15-scale crabro | full | 0 | 0 | 137 ms |
| 0.15-scale crabro | ROI | 3 | 2 | 132 ms |
| honeybee | full | 2 | 0 | 135 ms |
| text/UI | ROI | 10 | 4 | 121 ms |
| empty-hive crop | full | 0 | 0 | 124 ms |

This confirms the native model path and the same text false positive. It is
not physical-iPhone latency. The physical iPhone 14 Pro remained unavailable,
so actual camera alignment, shutter sound, live false positives and attack
video were not fabricated.

### Live Railway metadata E2E

The native crabro result was sent to production `hive-a` as metadata only:
server count 3, max count 3, risk score 28, `snapshot_url = null`. A subsequent
empty-frame observation returned count 0, max-window count 3 and risk score 11,
showing that current-frame count clears while backend time-window aggregation
remains. No raw image endpoint was used. The monitoring phone stayed offline
because this fixture check intentionally did not forge a live heartbeat.
