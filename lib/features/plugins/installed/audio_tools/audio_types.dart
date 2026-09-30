/// An audio endpoint as Windows lists it.
class AudioDevice {
  const AudioDevice({required this.id, required this.name});

  final String id;
  final String name;

  /// Virtual cables are the bridge into Discord and friends: whatever luma
  /// plays into one shows up as a microphone on the other side.
  bool get isVirtualCable {
    final n = name.toLowerCase();
    return n.contains('cable') ||
        n.contains('voicemeeter') ||
        n.contains('vb-audio') ||
        n.contains('virtual');
  }
}

class AudioDevices {
  const AudioDevices({
    this.inputs = const [],
    this.outputs = const [],
    this.defaultInputId,
    this.defaultOutputId,
  });

  static const empty = AudioDevices();

  final List<AudioDevice> inputs;
  final List<AudioDevice> outputs;
  final String? defaultInputId;
  final String? defaultOutputId;

  /// The playback side of a virtual cable (e.g. "CABLE Input"), if one is
  /// installed.
  AudioDevice? get virtualCableOutput {
    for (final d in outputs) {
      if (d.isVirtualCable) return d;
    }
    return null;
  }
}

/// Peak levels (0..1) of the last block, before and after the EQ.
class AudioLevels {
  const AudioLevels(this.input, this.output);

  static const silent = AudioLevels(0, 0);

  final double input;
  final double output;
}

/// Why the audio engine could not start or stopped on its own.
enum AudioEngineError {
  deviceMissing,
  deviceInUse,
  deviceLost,
  micBlocked,
  failed,
}

class AudioEngineException implements Exception {
  const AudioEngineException(this.error, [this.detail]);

  final AudioEngineError error;
  final String? detail;

  @override
  String toString() => 'AudioEngineException($error, $detail)';
}
