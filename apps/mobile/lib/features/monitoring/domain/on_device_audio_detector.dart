import 'dart:typed_data';

/// Boundary reserved for moving audio inference onto the monitoring phone.
///
/// TODO(edge-audio): implement this beside the current chunk uploader once a
/// validated audio model is available, then send metadata instead of audio.
abstract interface class OnDeviceAudioDetector {
  Future<OnDeviceAudioResult> detect(Uint8List pcmBytes);
  Future<void> dispose();
}

class OnDeviceAudioResult {
  const OnDeviceAudioResult({
    required this.hornetProbability,
    required this.inferenceMs,
    required this.modelVersion,
  });

  final double hornetProbability;
  final int inferenceMs;
  final String modelVersion;
}
