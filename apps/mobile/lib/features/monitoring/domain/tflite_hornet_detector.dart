import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'on_device_hornet_detector.dart';

/// Converts model-specific output tensors into the app's stable contract.
abstract interface class TfliteOutputDecoder {
  List<OnDeviceDetection> decode(List<Object> outputs);
}

/// Decoder for the common `[1, N, 6]` layout: x, y, width, height, score, class.
///
/// A production model with a different head can supply another decoder without
/// changing camera, sampling, upload or backend code.
class SixColumnDetectionDecoder implements TfliteOutputDecoder {
  const SixColumnDetectionDecoder({this.confidenceThreshold = 0.5});

  final double confidenceThreshold;

  @override
  List<OnDeviceDetection> decode(List<Object> outputs) {
    final List<List<num>> rows = <List<num>>[];
    for (final Object output in outputs) {
      _collectRows(output, rows);
    }
    return rows
        .where((List<num> row) => row[4].toDouble() >= confidenceThreshold)
        .map(
          (List<num> row) => OnDeviceDetection(
            x: row[0].toDouble().clamp(0.0, 1.0),
            y: row[1].toDouble().clamp(0.0, 1.0),
            width: row[2].toDouble().clamp(0.0, 1.0),
            height: row[3].toDouble().clamp(0.0, 1.0),
            confidence: row[4].toDouble().clamp(0.0, 1.0),
            className: row.length > 6 ? 'class-${row[5].toInt()}' : 'hornet',
          ),
        )
        .where(
          (OnDeviceDetection item) =>
              item.width > 0 &&
              item.height > 0 &&
              item.x + item.width <= 1.0 &&
              item.y + item.height <= 1.0,
        )
        .toList(growable: false);
  }

  static void _collectRows(Object value, List<List<num>> rows) {
    if (value is! List || value.isEmpty) return;
    if (value.length >= 6 && value.every((Object? item) => item is num)) {
      rows.add(value.cast<num>());
      return;
    }
    for (final Object? child in value) {
      if (child != null) _collectRows(child, rows);
    }
  }
}

/// TensorFlow Lite adapter. Preprocessing and inference run off the UI isolate.
class TfliteHornetDetector implements OnDeviceHornetDetector {
  TfliteHornetDetector._({
    required this._interpreter,
    required this._isolateInterpreter,
    required this.decoder,
    required this.modelVersion,
  });

  static Future<TfliteHornetDetector> fromAsset({
    required String assetPath,
    required String modelVersion,
    TfliteOutputDecoder decoder = const SixColumnDetectionDecoder(),
  }) async {
    final Interpreter interpreter = await Interpreter.fromAsset(assetPath);
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
    final Tensor inputTensor = _interpreter.getInputTensor(0);
    if (inputTensor.shape.length != 4 || inputTensor.shape.last != 3) {
      throw StateError(
        'Expected an NHWC image tensor, got ${inputTensor.shape}.',
      );
    }

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
    final List<OnDeviceDetection> detections = decoder.decode(outputs);
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
      ? Float32List(pixelCount * 3)
      : null;
  final Uint8List? bytes = request.floatInput
      ? null
      : Uint8List(pixelCount * 3);

  for (int targetY = 0; targetY < request.targetHeight; targetY++) {
    final int sourceY = targetY * request.frame.height ~/ request.targetHeight;
    for (int targetX = 0; targetX < request.targetWidth; targetX++) {
      final int sourceX = targetX * request.frame.width ~/ request.targetWidth;
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
