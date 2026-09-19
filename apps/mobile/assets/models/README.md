# On-device hornet model

No placeholder or fake model is committed. To enable the real adapter, place
the validated TensorFlow Lite model at `hornet.tflite` (or override
`TFLITE_MODEL_ASSET`) and build with `--dart-define=MODEL_MODE=tflite`.

The default `MODEL_MODE=mock` requires no model asset.
