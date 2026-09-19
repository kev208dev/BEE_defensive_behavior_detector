import 'package:beehive_guard/core/api/dio_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('control-plane requests fail fast against an unreachable backend', () {
    final dio = DioClient.create();
    addTearDown(dio.close);

    expect(
      dio.options.baseUrl,
      'https://beedefensivebehaviordetector-production.up.railway.app',
    );
    expect(dio.options.connectTimeout, const Duration(seconds: 3));
    expect(dio.options.receiveTimeout, const Duration(seconds: 5));
    expect(dio.options.sendTimeout, const Duration(seconds: 5));
  });

  test('media uploads retain a longer rural-network timeout budget', () {
    final dio = DioClient.createMedia();
    addTearDown(dio.close);

    expect(dio.options.connectTimeout, const Duration(seconds: 8));
    expect(dio.options.receiveTimeout, const Duration(seconds: 12));
    expect(dio.options.sendTimeout, const Duration(seconds: 12));
  });
}
