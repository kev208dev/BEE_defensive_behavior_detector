import 'package:beehive_guard/core/config/app_config.dart';
import 'package:beehive_guard/features/monitoring/domain/tflite_hornet_detector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bundled VespAI model opens with the native TFLite runtime', (
    WidgetTester tester,
  ) async {
    final TfliteHornetDetector detector =
        await TfliteHornetDetector.fromAsset(
          assetPath: AppConfig.tfliteModelAsset,
          modelVersion: AppConfig.modelVersion,
        );

    expect(detector.modelVersion, 'vespai-yolov5s-all-but-22ip');
    await detector.dispose();
  });
}
