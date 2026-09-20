import '../../../core/config/app_config.dart';
import 'detection_roi.dart';
import 'on_device_hornet_detector.dart';
import 'tflite_hornet_detector.dart';

/// Builds the detector this build is configured to run.
///
/// [roi] is the slice of each frame the model is shown. It is supplied by the
/// caller rather than read here so the choice stays testable, and because a
/// monitoring phone's region is per-device local state, not build config.
Future<OnDeviceHornetDetector> createOnDeviceHornetDetector({
  DetectionRoi roi = DetectionRoi.full,
  DetectionRoi Function()? roiForFrame,
}) async {
  if (AppConfig.usesMockDetector) {
    return MockOnDeviceHornetDetector();
  }
  return TfliteHornetDetector.fromAsset(
    assetPath: AppConfig.tfliteModelAsset,
    modelVersion: AppConfig.modelVersion,
    decoder: VespAiYoloV5Decoder(
      confidenceThreshold: AppConfig.detectionDecodeConfidenceThreshold,
      iouThreshold: AppConfig.detectionNmsIouThreshold,
    ),
    roi: roi,
    roiForFrame: roiForFrame,
  );
}
