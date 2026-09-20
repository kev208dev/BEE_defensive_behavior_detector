# Bundled on-device hornet model

The default mobile build runs a real VespAI detector from
`assets/models/hornet.tflite`. Raw camera images stay on the phone; only
detection metadata is sent to the observation API.

## Provenance

- Model project: [andrw3000/vespai](https://github.com/andrw3000/vespai)
- VespAI revision used for this conversion:
  `004f3d8930d19affd04f5d112224107c5d81eec4`
- Selected pretrained weight: `models/yolov5-params/yolov5s-all-but-22ip.pt`
- Original weight size: 14,369,205 bytes
- Original weight SHA-256:
  `28da7714df2ec105a4600082a0a2ce565ccf1b60a64a425393fbb19709f616ef`
- Compatible YOLOv5 revision:
  `23701eac7a7b160e478ba4bbef966d0af9348251`
- Bundled TFLite size: 14,136,328 bytes
- Bundled TFLite SHA-256:
  `0a89d40e90f8204308d795b49288178260b3ed6cf78d171bbffee694b1868ba3`
- Classes: `0 = Vespa crabro`, `1 = Vespa velutina`

This is a public pretrained VespAI model. It was not trained by this project.

## Runtime contract

| Item | Verified value |
|---|---|
| Input | index `0`, `[1, 640, 640, 3]`, `float32`, NHWC |
| Colour | RGB |
| Normalization | channel value divided by 255, producing `[0, 1]` |
| Resize | aspect-preserving nearest-neighbour letterbox |
| Padding | RGB `(114, 114, 114)` |
| Output | index `525`, `[1, 25200, 7]`, `float32` |
| Output row | normalized `cx, cy, w, h, objectness, crabro, velutina` |
| Confidence | `objectness × selected class probability` |
| Confidence threshold | `0.8` (the VespAI monitor default) |
| NMS | performed in Flutter, class-aware, IoU threshold `0.45` |

The output is the raw YOLO head, not final detections. Flutter reverses the
letterbox transform, clamps each box to the source camera frame, and sends
normalized top-left `x, y, width, height`. Both classes count toward
`hornet_count`; `class_name` preserves the species.

The camera plugin supplies iOS frames as BGRA8888 and Android frames as NV21
or planar YUV. Conversion, letterboxing, and inference retain the existing
background-isolate and single-flight frame-dropping pipeline. Coordinates are
relative to the native camera buffer. The overlay separately maps these to
preview orientation and `BoxFit.cover`. AVFoundation already rotates/mirrors
the shared texture/stream buffer; CameraX requires the sensor/device transform.
Only current-frame detections >= 0.80 are uploaded; held UI tracks are excluded.
The debug overlay shows raw/current versus faded held tracks at display 0.65.

## September 2026 model comparison

The existing asset is retained as a **diagnostic baseline, not a validated
hive-entrance winner**. A paired comparison of four VespAI weights found high
confidence false positives on cropped hard negatives, including text. No
alternative met the adoption criteria, so no rejected candidate was exported.
See `tools/model_conversion/evaluations/2026-09-20/REPORT.md` for the frozen
manifest, protocol, metrics, limitations and next steps. The asset SHA and
decoder contract above are unchanged.

## Failure behavior

Input and output tensor shapes and dtypes are checked while the model loads.
An absent or incompatible model stops monitoring and shows
`말벌 탐지 모델을 불러올 수 없습니다.` There is no automatic mock fallback.
Developers can still explicitly build with `--dart-define=MODEL_MODE=mock`.

## Verification

See `tools/model_conversion/README.md`. The checked-in verifier prints tensor
details and runs the same preprocessing, confidence filtering, species mapping,
letterbox reversal, and NMS as the Flutter decoder.

## License

The VespAI repository states that it is distributed under
**CC BY-NC-SA 4.0**, with constituent model code under **AGPL-3.0** and each
dependency under its own license. This bundled converted model is used for a
non-commercial MVP/competition demonstration. A separate license review and,
where needed, permission from the rights holder are required before any
commercial deployment.
