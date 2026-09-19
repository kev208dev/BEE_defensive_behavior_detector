import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

/// Records fixed-length audio chunks, back to back.
///
/// The spec asks for 3-second chunks uploaded one after another, with no
/// realtime websocket streaming. The loop here is deliberately sequential:
/// record → stop → hand the bytes over → record again. Overlapping recordings
/// would fight over the microphone, and a gap between them is far less
/// harmful than a recorder that wedges.
///
/// Entirely independent of [CameraService] — they share no hardware, which is
/// why the camera is created with `enableAudio: false`.
class AudioService {
  AudioService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  bool _running = false;
  bool _disposed = false;
  Directory? _tempDir;

  bool get isRecording => _running;

  /// Emits each completed chunk's bytes.
  final StreamController<Uint8List> _chunks =
      StreamController<Uint8List>.broadcast();

  Stream<Uint8List> get chunks => _chunks.stream;

  /// Whether the microphone is usable. Never throws.
  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } on Object catch (error) {
      debugPrint('AudioService: permission check failed — $error');
      return false;
    }
  }

  /// Starts the record → upload → record loop.
  ///
  /// Returns `null` on success or a reason on failure.
  Future<String?> start({required Duration chunkDuration}) async {
    if (_running) return null;
    if (_disposed) return '오디오 서비스가 이미 종료되었습니다.';

    if (!await hasPermission()) {
      return '마이크 권한이 거부되었습니다. 설정에서 권한을 허용해주세요.';
    }

    try {
      _tempDir ??= await Directory.systemTemp.createTemp('beehive_audio');
    } on Object catch (error) {
      debugPrint('AudioService: could not create temp directory — $error');
      return '녹음 파일을 저장할 공간을 준비하지 못했습니다.';
    }

    _running = true;
    unawaited(_loop(chunkDuration));
    return null;
  }

  Future<void> _loop(Duration chunkDuration) async {
    int sequence = 0;

    while (_running && !_disposed) {
      final String path =
          '${_tempDir!.path}/chunk_${sequence++ % 4}.m4a';

      try {
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            // Hornet and bee wingbeats are low-frequency; 22.05 kHz keeps the
            // band that matters while roughly halving the upload size.
            sampleRate: 22050,
            numChannels: 1,
          ),
          path: path,
        );
      } on Object catch (error) {
        debugPrint('AudioService: could not start recording — $error');
        _running = false;
        break;
      }

      await Future<void>.delayed(chunkDuration);
      if (!_running || _disposed) break;

      final Uint8List? bytes = await _stopAndRead(path);
      if (bytes != null && bytes.isNotEmpty && !_chunks.isClosed) {
        _chunks.add(bytes);
      }
    }

    // Make sure the recorder is not left holding the microphone.
    await _safeStop();
  }

  Future<Uint8List?> _stopAndRead(String path) async {
    try {
      await _recorder.stop();
      final File file = File(path);
      if (!file.existsSync()) return null;
      return await file.readAsBytes();
    } on Object catch (error) {
      debugPrint('AudioService: could not read chunk — $error');
      return null;
    }
  }

  Future<void> _safeStop() async {
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } on Object catch (error) {
      debugPrint('AudioService: stop failed — $error');
    }
  }

  /// Stops the loop and releases the microphone.
  Future<void> stop() async {
    _running = false;
    await _safeStop();
  }

  /// Stops and cleans up everything, including the temporary files.
  Future<void> dispose() async {
    _disposed = true;
    _running = false;
    await _safeStop();

    try {
      await _recorder.dispose();
    } on Object catch (error) {
      debugPrint('AudioService: recorder dispose failed — $error');
    }

    final Directory? dir = _tempDir;
    _tempDir = null;
    if (dir != null) {
      try {
        if (dir.existsSync()) await dir.delete(recursive: true);
      } on Object catch (error) {
        debugPrint('AudioService: temp cleanup failed — $error');
      }
    }

    await _chunks.close();
  }
}
