import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'on_device_hornet_detector.dart';

/// Converts model-specific output tensors into the app's stable contract.
abstract interface class TfliteOutputDecoder {
  List<OnDeviceDetection> decode(
    List<Object> outputs, {
    required int frameWidth,
    required int frameHeight,
    required int inputWidth,
    required int inputHeight,
  });
}

class VespAiLetterboxGeometry {
  const VespAiLetterboxGeometry({
    required this.scale,
    required this.resizedWidth,
    required this.resizedHeight,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.padLeft,
    required this.padTop,
  });

  static const int paddingValue = 114;

  final double scale;
  final int resizedWidth;
  final int resizedHeight;
  final double horizontalPadding;
  final double verticalPadding;
  final int padLeft;
  final int padTop;
}

/// Decodes the raw head exported from VespAI's two-class YOLOv5s model.
///
/// Each row is normalized `cx, cy, width, height, objectness, crabro, velutina`.
/// The original VespAI monitor uses a confidence threshold of 0.8. The exported
/// model does not contain NMS, so class-aware YOLO NMS is applied here.
class VespAiYoloV5Decoder implements TfliteOutputDecoder {
  const VespAiYoloV5Decoder({
    this.confidenceThreshold = 0.8,
    this.iouThreshold = 0.45,
  });

  final double confidenceThreshold;
  final double iouThreshold;

  static const List<String> _classNames = <String>[
    'Vespa crabro',
    'Vespa velutina',
  ];

  @override
  List<OnDeviceDetection> decode(
    List<Object> outputs, {
    required int frameWidth,
    required int frameHeight,
    required int inputWidth,
    required int inputHeight,
  }) {
    if (outputs.length != 1 ||
        outputs.single is! List<Object> ||
        (outputs.single as List<Object>).length != 1) {
      throw StateError('Expected one VespAI output tensor with batch size 1.');
    }

    final Object batch = (outputs.single as List<Object>).single;
    if (batch is! List<Object>) {
      throw StateError('Expected VespAI output rows.');
    }

    final VespAiLetterboxGeometry geometry =
        TfliteHornetDetector.letterboxGeometry(
          frameWidth: frameWidth,
          frameHeight: frameHeight,
          inputWidth: inputWidth,
          inputHeight: inputHeight,
        );
    final double scale = geometry.scale;
    final double padX = geometry.horizontalPadding;
    final double padY = geometry.verticalPadding;
    final List<_DetectionCandidate> candidates = <_DetectionCandidate>[];

    for (final Object? value in batch) {
      if (value is! List ||
          value.length != 7 ||
          !value.every((Object? item) => item is num)) {
        throw StateError('Expected VespAI prediction rows with 7 values.');
      }
      final List<num> row = value.cast<num>();
      final double objectness = row[4].toDouble();
      final int classIndex = row[5].toDouble() >= row[6].toDouble() ? 0 : 1;
      final double confidence = objectness * row[5 + classIndex].toDouble();
      if (!confidence.isFinite || confidence < confidenceThreshold) continue;

      final double centerX = row[0].toDouble() * inputWidth;
      final double centerY = row[1].toDouble() * inputHeight;
      final double modelWidth = row[2].toDouble() * inputWidth;
      final double modelHeight = row[3].toDouble() * inputHeight;
      final double left = ((centerX - modelWidth / 2 - padX) / scale).clamp(
        0.0,
        frameWidth.toDouble(),
      );
      final double top = ((centerY - modelHeight / 2 - padY) / scale).clamp(
        0.0,
        frameHeight.toDouble(),
      );
      final double right = ((centerX + modelWidth / 2 - padX) / scale).clamp(
        0.0,
        frameWidth.toDouble(),
      );
      final double bottom = ((centerY + modelHeight / 2 - padY) / scale).clamp(
        0.0,
        frameHeight.toDouble(),
      );
      if (right <= left || bottom <= top) continue;

      candidates.add(
        _DetectionCandidate(
          left: left / frameWidth,
          top: top / frameHeight,
          right: right / frameWidth,
          bottom: bottom / frameHeight,
          confidence: confidence.clamp(0.0, 1.0),
          classIndex: classIndex,
        ),
      );
    }

    candidates.sort(
      (_DetectionCandidate a, _DetectionCandidate b) =>
          b.confidence.compareTo(a.confidence),
    );
    final List<_DetectionCandidate> kept = <_DetectionCandidate>[];
    for (final _DetectionCandidate candidate in candidates) {
      final bool overlaps = kept.any(
        (_DetectionCandidate accepted) =>
            accepted.classIndex == candidate.classIndex &&
            _intersectionOverUnion(accepted, candidate) > iouThreshold,
      );
      if (!overlaps) kept.add(candidate);
    }

    return kept
        .map(
          (_DetectionCandidate item) => OnDeviceDetection(
            x: item.left,
            y: item.top,
            width: item.right - item.left,
            height: item.bottom - item.top,
            confidence: item.confidence,
            className: _classNames[item.classIndex],
          ),
        )
        .toList(growable: false);
  }
}

class _DetectionCandidate {
  const _DetectionCandidate({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.confidence,
    required this.classIndex,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;
  final double confidence;
  final int classIndex;
}

double _intersectionOverUnion(
  _DetectionCandidate first,
  _DetectionCandidate second,
) {
  final double intersectionWidth = math.max(
    0,
    math.min(first.right, second.right) - math.max(first.left, second.left),
  );
  final double intersectionHeight = math.max(
    0,
    math.min(first.bottom, second.bottom) - math.max(first.top, second.top),
  );
  final double intersection = intersectionWidth * intersectionHeight;
  final double firstArea =
      (first.right - first.left) * (first.bottom - first.top);
  final double secondArea =
      (second.right - second.left) * (second.bottom - second.top);
  final double union = firstArea + secondArea - intersection;
  return union <= 0 ? 0 : intersection / union;
}

/// TensorFlow Lite adapter. Preprocessing and inference run off the UI isolate.
class TfliteHornetDetector implements OnDeviceHornetDetector {
  TfliteHornetDetector._({
    required this._interpreter,
    required this._isolateInterpreter,
    required this.decoder,
    required this.modelVersion,
  });

  /// Checks that a model's input tensor is one this adapter can feed.
  ///
  /// Exposed so the contract can be asserted without a model file present.
  static void validateInputShape(List<int> shape) {
    if (shape.length != 4 ||
        shape[0] != 1 ||
        shape[1] != 640 ||
        shape[2] != 640 ||
        shape[3] != 3) {
      throw StateError(
        'Expected the VespAI NHWC tensor [1, 640, 640, 3], got $shape. '
        'See assets/models/README.md for the model contract.',
      );
    }
  }

  static VespAiLetterboxGeometry letterboxGeometry({
    required int frameWidth,
    required int frameHeight,
    required int inputWidth,
    required int inputHeight,
  }) {
    final double scale = math.min(
      inputWidth / frameWidth,
      inputHeight / frameHeight,
    );
    final int resizedWidth = (frameWidth * scale).round();
    final int resizedHeight = (frameHeight * scale).round();
    final double horizontalPadding = (inputWidth - resizedWidth) / 2.0;
    final double verticalPadding = (inputHeight - resizedHeight) / 2.0;
    return VespAiLetterboxGeometry(
      scale: scale,
      resizedWidth: resizedWidth,
      resizedHeight: resizedHeight,
      horizontalPadding: horizontalPadding,
      verticalPadding: verticalPadding,
      padLeft: (horizontalPadding - 0.1).round(),
      padTop: (verticalPadding - 0.1).round(),
    );
  }

  static void validateOutputShape(List<int> shape) {
    if (shape.length != 3 ||
        shape[0] != 1 ||
        shape[1] != 25200 ||
        shape[2] != 7) {
      throw StateError(
        'Expected the VespAI output tensor [1, 25200, 7], got $shape. '
        'See assets/models/README.md for the model contract.',
      );
    }
  }

  /// Loads a model, failing loudly if it cannot actually be driven.
  ///
  /// The shape check happens here rather than on the first frame on purpose.
  /// [ImageAnalysisLoop] swallows per-frame errors so that one bad frame
  /// cannot kill the camera stream, which means a model this adapter cannot
  /// feed would otherwise fail silently on every frame forever: monitoring
  /// would look healthy and report zero hornets indefinitely. Failing at load
  /// turns that into a refusal to start, which the user is told about.
  static Future<TfliteHornetDetector> fromAsset({
    required String assetPath,
    required String modelVersion,
    TfliteOutputDecoder decoder = const VespAiYoloV5Decoder(),
  }) async {
    final Interpreter interpreter = await Interpreter.fromAsset(assetPath);
    try {
      final Tensor input = interpreter.getInputTensor(0);
      final List<Tensor> outputs = interpreter.getOutputTensors();
      validateInputShape(input.shape);
      if (input.type != TensorType.float32) {
        throw StateError('Expected a float32 VespAI input tensor.');
      }
      if (outputs.length != 1) {
        throw StateError('Expected one VespAI output tensor.');
      }
      validateOutputShape(outputs.single.shape);
      if (outputs.single.type != TensorType.float32) {
        throw StateError('Expected a float32 VespAI output tensor.');
      }
    } on Object {
      interpreter.close();
      rethrow;
    }
    final IsolateInterpreter isolateInterpreter =
        await IsolateInterpreter.create(address: interpreter.address);
    return TfliteHornetDetector._(
      interpreter: interpreter,
      isolateInterpreter: isolateInterpreter,
      decoder: decoder,
      modelVersion: modelVersion,
    );
  }

  final Interpreter _interpreter;
  final IsolateInterpreter _isolateInterpreter;
  final TfliteOutputDecoder decoder;
  final String modelVersion;
  bool _disposed = false;

  @override
  Future<OnDeviceDetectionResult> detect(CameraImage image) async {
    if (_disposed) throw StateError('Detector has been disposed.');
    final Stopwatch stopwatch = Stopwatch()..start();
    // Shape was validated in [fromAsset]; an interpreter that got this far can
    // be fed.
    final Tensor inputTensor = _interpreter.getInputTensor(0);
    final _FrameData frame = _FrameData.fromCameraImage(image);
    final _PreprocessRequest request = _PreprocessRequest(
      frame: frame,
      targetWidth: inputTensor.shape[2],
      targetHeight: inputTensor.shape[1],
      floatInput: inputTensor.type == TensorType.float32,
    );
    final Uint8List input = await Isolate.run(() => _preprocess(request));
    final List<Tensor> outputTensors = _interpreter.getOutputTensors();
    final List<Object> outputs = outputTensors
        .map<Object>((Tensor tensor) => _emptyTensor(tensor.shape, tensor.type))
        .toList(growable: false);
    await _isolateInterpreter.runForMultipleInputs(
      <Object>[input],
      <int, Object>{
        for (int index = 0; index < outputs.length; index++)
          index: outputs[index],
      },
    );
    final List<OnDeviceDetection> detections = decoder.decode(
      outputs,
      frameWidth: image.width,
      frameHeight: image.height,
      inputWidth: inputTensor.shape[2],
      inputHeight: inputTensor.shape[1],
    );
    stopwatch.stop();
    return OnDeviceDetectionResult(
      hornetCount: detections.length,
      maxConfidence: detections.fold<double>(
        0,
        (double value, OnDeviceDetection item) =>
            math.max(value, item.confidence),
      ),
      detections: detections,
      inferenceMs: stopwatch.elapsedMilliseconds,
      modelVersion: modelVersion,
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _isolateInterpreter.close();
    _interpreter.close();
  }
}

Object _emptyTensor(List<int> shape, TensorType type, [int dimension = 0]) {
  if (dimension == shape.length) {
    return type == TensorType.float32 ? 0.0 : 0;
  }
  return List<Object>.generate(
    shape[dimension],
    (_) => _emptyTensor(shape, type, dimension + 1),
    growable: false,
  );
}

class _PlaneData {
  const _PlaneData({
    required this.bytes,
    required this.bytesPerRow,
    required this.bytesPerPixel,
  });

  final Uint8List bytes;
  final int bytesPerRow;
  final int bytesPerPixel;
}

class _FrameData {
  const _FrameData({
    required this.width,
    required this.height,
    required this.format,
    required this.planes,
  });

  factory _FrameData.fromCameraImage(CameraImage image) => _FrameData(
    width: image.width,
    height: image.height,
    format: image.format.group,
    planes: image.planes
        .map(
          (Plane plane) => _PlaneData(
            bytes: Uint8List.fromList(plane.bytes),
            bytesPerRow: plane.bytesPerRow,
            bytesPerPixel: plane.bytesPerPixel ?? 1,
          ),
        )
        .toList(growable: false),
  );

  final int width;
  final int height;
  final ImageFormatGroup format;
  final List<_PlaneData> planes;
}

class _PreprocessRequest {
  const _PreprocessRequest({
    required this.frame,
    required this.targetWidth,
    required this.targetHeight,
    required this.floatInput,
  });

  final _FrameData frame;
  final int targetWidth;
  final int targetHeight;
  final bool floatInput;
}

Uint8List _preprocess(_PreprocessRequest request) {
  final int pixelCount = request.targetWidth * request.targetHeight;
  final Float32List? floats = request.floatInput
      ? (Float32List(pixelCount * 3)..fillRange(
          0,
          pixelCount * 3,
          VespAiLetterboxGeometry.paddingValue / 255.0,
        ))
      : null;
  final Uint8List? bytes = request.floatInput
      ? null
      : (Uint8List(pixelCount * 3)
          ..fillRange(0, pixelCount * 3, VespAiLetterboxGeometry.paddingValue));

  final VespAiLetterboxGeometry geometry =
      TfliteHornetDetector.letterboxGeometry(
        frameWidth: request.frame.width,
        frameHeight: request.frame.height,
        inputWidth: request.targetWidth,
        inputHeight: request.targetHeight,
      );

  for (int resizedY = 0; resizedY < geometry.resizedHeight; resizedY++) {
    final int targetY = geometry.padTop + resizedY;
    final int sourceY =
        resizedY * request.frame.height ~/ geometry.resizedHeight;
    for (int resizedX = 0; resizedX < geometry.resizedWidth; resizedX++) {
      final int targetX = geometry.padLeft + resizedX;
      final int sourceX =
          resizedX * request.frame.width ~/ geometry.resizedWidth;
      final (int, int, int) rgb = _rgbAt(request.frame, sourceX, sourceY);
      final int offset = (targetY * request.targetWidth + targetX) * 3;
      if (floats != null) {
        floats[offset] = rgb.$1 / 255.0;
        floats[offset + 1] = rgb.$2 / 255.0;
        floats[offset + 2] = rgb.$3 / 255.0;
      } else {
        bytes![offset] = rgb.$1;
        bytes[offset + 1] = rgb.$2;
        bytes[offset + 2] = rgb.$3;
      }
    }
  }
  return floats == null
      ? bytes!
      : floats.buffer.asUint8List(floats.offsetInBytes, floats.lengthInBytes);
}

(int, int, int) _rgbAt(_FrameData frame, int x, int y) {
  if (frame.format == ImageFormatGroup.bgra8888) {
    final _PlaneData plane = frame.planes.first;
    final int offset = y * plane.bytesPerRow + x * 4;
    return (
      plane.bytes[offset + 2],
      plane.bytes[offset + 1],
      plane.bytes[offset],
    );
  }

  late int yValue;
  late int uValue;
  late int vValue;
  if (frame.format == ImageFormatGroup.nv21) {
    final _PlaneData plane = frame.planes.first;
    yValue = plane.bytes[y * plane.bytesPerRow + x];
    final int chromaOffset =
        frame.height * plane.bytesPerRow +
        (y ~/ 2) * plane.bytesPerRow +
        (x ~/ 2) * 2;
    vValue = plane.bytes[chromaOffset];
    uValue = plane.bytes[chromaOffset + 1];
  } else if (frame.planes.length >= 3) {
    final _PlaneData yPlane = frame.planes[0];
    final _PlaneData uPlane = frame.planes[1];
    final _PlaneData vPlane = frame.planes[2];
    yValue = yPlane.bytes[y * yPlane.bytesPerRow + x * yPlane.bytesPerPixel];
    final int chromaX = x ~/ 2;
    final int chromaY = y ~/ 2;
    uValue = uPlane
        .bytes[chromaY * uPlane.bytesPerRow + chromaX * uPlane.bytesPerPixel];
    vValue = vPlane
        .bytes[chromaY * vPlane.bytesPerRow + chromaX * vPlane.bytesPerPixel];
  } else {
    throw StateError('Unsupported camera image format: ${frame.format}');
  }

  final double u = uValue - 128.0;
  final double v = vValue - 128.0;
  return (
    (yValue + 1.402 * v).round().clamp(0, 255),
    (yValue - 0.344136 * u - 0.714136 * v).round().clamp(0, 255),
    (yValue + 1.772 * u).round().clamp(0, 255),
  );
}
