import '../../../core/config/app_config.dart';
import 'on_device_hornet_detector.dart';
import 'tflite_hornet_detector.dart';

Future<OnDeviceHornetDetector> createOnDeviceHornetDetector() async {
  if (AppConfig.modelMode.toLowerCase() != 'tflite') {
    return MockOnDeviceHornetDetector();
  }
  return TfliteHornetDetector.fromAsset(
    assetPath: AppConfig.tfliteModelAsset,
    modelVersion: AppConfig.modelVersion,
  );
}
