# On-device hornet model

No placeholder or fake model is committed. `MODEL_MODE=mock` is the default and
needs no asset: it reports **zero hornets on every frame**. It exercises the
camera → detector → metadata → backend pipeline; it does not look at the image
and it detects nothing. A build running in mock mode is not performing hornet
detection, and nothing in the app should be read as if it were.

## Enabling the real adapter

Place the validated model at `assets/models/hornet.tflite` and build with:

```bash
flutter build apk --dart-define=MODEL_MODE=tflite \
                  --dart-define=MODEL_VERSION=hornet-yolo-v1
```

Overrides: `TFLITE_MODEL_ASSET` (asset path), `MODEL_VERSION` (the string
reported to the backend and stored on every observation, so a risk score can
later be traced to the model that produced it).

## Model contract

The bundled adapter (`TfliteHornetDetector`) requires:

| | Requirement |
|---|---|
| Input tensor | rank 4, NHWC, 3 channels — `[1, H, W, 3]` |
| Input type | `float32` (normalised to 0..1) or `uint8` |
| Colour order | RGB |
| Preprocessing | nearest-neighbour resize to the model's `H`×`W`; done off the UI isolate |
| Output | one or more tensors whose innermost rows have ≥ 6 columns: `x, y, width, height, score, class` |
| Coordinates | normalised 0..1, with `x + width <= 1` and `y + height <= 1` |

The input shape is checked when the model loads, not on the first frame: a
model this adapter cannot feed makes `startMonitoring()` fail with a visible
error rather than silently dropping every frame while the UI reports zero
hornets.

## Single-class assumption

`SixColumnDetectionDecoder` counts **every** box above its confidence threshold
as a hornet, because `hornet_count` is the dominant term in the backend's risk
score. That is correct only for a single-class hornet model.

For a multi-class model (hornets plus honeybees, or several species),
implement `TfliteOutputDecoder` and filter on the class column, then pass it to
`TfliteHornetDetector.fromAsset(decoder: ...)`. Without that, a frame full of
the colony's own bees scores as a mass attack. No other layer needs to change —
that is what the decoder boundary is for.

## Still outstanding

There is no trained, validated hornet model in this repository. Producing one
(dataset, labelling, training, field validation) is the remaining work before
the system detects anything real.
