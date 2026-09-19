# VespAI TFLite conversion and verification

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
