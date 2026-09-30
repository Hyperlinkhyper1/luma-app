import 'audio_types.dart';
import 'eq.dart';

/// Web/stub: there is no microphone routing outside the desktop app.
class AudioEngine {
  AudioEngine._();

  static bool get supported => false;

  static Future<AudioDevices> listDevices() async => AudioDevices.empty;

  static Future<AudioEngine> start({
    required String? inputId,
    required String? outputId,
    required bool monitor,
    required EqSettings eq,
    required bool bypass,
    required void Function(AudioLevels levels) onLevels,
    required void Function(AudioEngineError error) onError,
  }) async => throw const AudioEngineException(AudioEngineError.failed);

  void updateEq(EqSettings eq) {}

  void setBypass(bool bypass) {}

  Future<void> stop() async {}
}
