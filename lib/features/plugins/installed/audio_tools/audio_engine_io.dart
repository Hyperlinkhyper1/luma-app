import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import 'audio_types.dart';
import 'eq.dart';

const _sampleRate = 48000;

/// Lets the shared-mode engine resample and remix to the format we ask for,
/// so every device is opened as 48 kHz float regardless of its mix format.
const _autoConvertPcm = 0x80000000;
const _srcDefaultQuality = 0x08000000;
const _eventCallback = 0x00040000;

/// 100 ms shared buffers, in 100 ns units.
const _bufferDuration = 1000000;

/// Silence queued on the output before the first block, to absorb jitter.
const _prefillFrames = _sampleRate * 20 ~/ 1000;

/// Beyond this much queued audio, incoming blocks are dropped so drift
/// between the mic's clock and the output's can't grow the delay forever.
const _maxQueuedFrames = _sampleRate * 60 ~/ 1000;

const _levelInterval = Duration(milliseconds: 50);

/// Routes a microphone through the EQ into an output device in real time,
/// using WASAPI shared mode. All audio work happens on a background isolate;
/// this object is the main isolate's handle to it.
class AudioEngine {
  AudioEngine._(this._isolate, this._commands, this._exited);

  static bool get supported => Platform.isWindows;

  final Isolate _isolate;
  final SendPort _commands;
  final Future<void> _exited;

  static Future<AudioDevices> listDevices() async {
    if (!supported) return AudioDevices.empty;
    return Isolate.run(_enumerateDevices);
  }

  /// Opens the devices and starts routing. Throws [AudioEngineException]
  /// when a device can't be opened. After a successful start, [onError]
  /// reports the engine stopping on its own (e.g. the mic was unplugged).
  static Future<AudioEngine> start({
    required String? inputId,
    required String? outputId,
    required bool monitor,
    required EqSettings eq,
    required bool bypass,
    required void Function(AudioLevels levels) onLevels,
    required void Function(AudioEngineError error) onError,
  }) async {
    if (!supported) {
      throw const AudioEngineException(AudioEngineError.failed);
    }
    final port = ReceivePort();
    final ready = Completer<SendPort>();
    final exited = Completer<void>();
    SendPort? commands;

    void fail(AudioEngineError error, String? detail) {
      if (!ready.isCompleted) {
        ready.completeError(AudioEngineException(error, detail));
      } else {
        onError(error);
      }
    }

    port.listen((msg) {
      if (msg is SendPort) {
        commands = msg;
      } else if (msg == null) {
        if (!ready.isCompleted) fail(AudioEngineError.failed, 'exited');
        if (!exited.isCompleted) exited.complete();
        port.close();
      } else if (msg is List) {
        fail(AudioEngineError.failed, msg.isEmpty ? null : '${msg.first}');
      } else if (msg is Map) {
        switch (msg['t']) {
          case 'started':
            if (!ready.isCompleted) ready.complete(commands!);
          case 'levels':
            onLevels(
              AudioLevels(
                (msg['in'] as num).toDouble(),
                (msg['out'] as num).toDouble(),
              ),
            );
          case 'error':
            fail(
              AudioEngineError.values.byName(msg['code'] as String),
              msg['detail'] as String?,
            );
        }
      }
    });

    final isolate = await Isolate.spawn(
      _audioMain,
      _StartArgs(
        reply: port.sendPort,
        inputId: inputId,
        outputId: outputId,
        monitor: monitor,
        eq: eq.toJson(),
        bypass: bypass,
      ),
      onError: port.sendPort,
      onExit: port.sendPort,
      debugName: 'luma-audio-tools',
    );
    final sendPort = await ready.future;
    return AudioEngine._(isolate, sendPort, exited.future);
  }

  void updateEq(EqSettings eq) =>
      _commands.send({'t': 'eq', 'eq': eq.toJson()});

  void setBypass(bool bypass) => _commands.send({'t': 'bypass', 'v': bypass});

  Future<void> stop() async {
    _commands.send({'t': 'stop'});
    try {
      await _exited.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      _isolate.kill(priority: Isolate.immediate);
    }
  }
}

class _StartArgs {
  const _StartArgs({
    required this.reply,
    required this.inputId,
    required this.outputId,
    required this.monitor,
    required this.eq,
    required this.bypass,
  });

  final SendPort reply;
  final String? inputId;
  final String? outputId;
  final bool monitor;
  final Map<String, dynamic> eq;
  final bool bypass;
}

class _HResultFailure implements Exception {
  _HResultFailure(int hr, {bool opening = false})
    : error = _errorFor(hr, opening),
      detail = '0x${(hr & 0xFFFFFFFF).toRadixString(16)}';

  final AudioEngineError error;
  final String detail;

  static AudioEngineError _errorFor(int hr, bool opening) => switch (hr &
      0xFFFFFFFF) {
    0x88890004 =>
      opening ? AudioEngineError.deviceMissing : AudioEngineError.deviceLost,
    0x8889000A => AudioEngineError.deviceInUse,
    0x80070005 => AudioEngineError.micBlocked,
    0x80070490 || 0x80070002 => AudioEngineError.deviceMissing,
    _ => AudioEngineError.failed,
  };
}

void _check(int hr, {bool opening = false}) {
  if (FAILED(hr)) throw _HResultFailure(hr, opening: opening);
}

/// Releases a COM object now rather than whenever the finalizer runs, so a
/// stopped engine lets go of the devices straight away.
void _dispose(IUnknown? object) {
  if (object == null) return;
  object.detach();
  object.release();
  free(object.ptr);
}

// The isolate may resume on another pool thread after an await, so COM is
// joined as MTA and never uninitialised here; the MTA outlives the isolate.
void _initCom() => CoInitializeEx(nullptr, COINIT_MULTITHREADED);

AudioDevices _enumerateDevices() {
  _initCom();
  final enumerator = MMDeviceEnumerator.createInstance();
  try {
    return AudioDevices(
      inputs: _listDevices(enumerator, eCapture),
      outputs: _listDevices(enumerator, eRender),
      defaultInputId: _defaultId(enumerator, eCapture),
      defaultOutputId: _defaultId(enumerator, eRender),
    );
  } finally {
    _dispose(enumerator);
  }
}

List<AudioDevice> _listDevices(IMMDeviceEnumerator enumerator, int flow) {
  final ppCollection = calloc<COMObject>();
  if (FAILED(
    enumerator.enumAudioEndpoints(
      flow,
      DEVICE_STATE_ACTIVE,
      ppCollection.cast(),
    ),
  )) {
    free(ppCollection);
    return const [];
  }
  final collection = IMMDeviceCollection(ppCollection);
  final pCount = calloc<Uint32>();
  final devices = <AudioDevice>[];
  try {
    if (FAILED(collection.getCount(pCount))) return const [];
    for (var i = 0; i < pCount.value; i++) {
      final ppDevice = calloc<COMObject>();
      if (FAILED(collection.item(i, ppDevice.cast()))) {
        free(ppDevice);
        continue;
      }
      final device = IMMDevice(ppDevice);
      try {
        final id = _deviceId(device);
        if (id != null) {
          devices.add(AudioDevice(id: id, name: _friendlyName(device)));
        }
      } finally {
        _dispose(device);
      }
    }
  } finally {
    free(pCount);
    _dispose(collection);
  }
  devices.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return devices;
}

String? _defaultId(IMMDeviceEnumerator enumerator, int flow) {
  final ppDevice = calloc<COMObject>();
  if (FAILED(
    enumerator.getDefaultAudioEndpoint(flow, eConsole, ppDevice.cast()),
  )) {
    free(ppDevice);
    return null;
  }
  final device = IMMDevice(ppDevice);
  try {
    return _deviceId(device);
  } finally {
    _dispose(device);
  }
}

String? _deviceId(IMMDevice device) {
  final ppId = calloc<Pointer<Utf16>>();
  try {
    if (FAILED(device.getId(ppId))) return null;
    final id = ppId.value.toDartString();
    CoTaskMemFree(ppId.value);
    return id;
  } finally {
    free(ppId);
  }
}

String _friendlyName(IMMDevice device) {
  final ppStore = calloc<COMObject>();
  if (FAILED(device.openPropertyStore(STGM_READ, ppStore.cast()))) {
    free(ppStore);
    return '';
  }
  final store = IPropertyStore(ppStore);
  final key = PROPERTYKEY.Device_FriendlyName();
  final value = calloc<PROPVARIANT>();
  try {
    if (SUCCEEDED(store.getValue(key, value)) && value.ref.vt == VT_LPWSTR) {
      return value.ref.pwszVal.toDartString();
    }
    return '';
  } finally {
    PropVariantClear(value);
    free(value);
    free(key);
    _dispose(store);
  }
}

IMMDevice _openDevice(IMMDeviceEnumerator enumerator, String? id, int flow) {
  final ppDevice = calloc<COMObject>();
  final int hr;
  if (id == null) {
    hr = enumerator.getDefaultAudioEndpoint(flow, eConsole, ppDevice.cast());
  } else {
    final pId = id.toNativeUtf16();
    hr = enumerator.getDevice(pId, ppDevice.cast());
    free(pId);
  }
  if (FAILED(hr)) {
    free(ppDevice);
    throw _HResultFailure(hr, opening: true);
  }
  return IMMDevice(ppDevice);
}

/// One opened WASAPI stream: the device, its IAudioClient and the capture or
/// render service, in 48 kHz float at [channels].
class _Stream {
  _Stream._(this.device, this.client, this.channels);

  final IMMDevice device;
  final IAudioClient client;
  final int channels;
  IAudioCaptureClient? capture;
  IAudioRenderClient? render;
  int event = 0;
  int bufferFrames = 0;

  final _ppData = calloc<Pointer<Uint8>>();
  final _pFrames = calloc<Uint32>();
  final _pFlags = calloc<Uint32>();

  static _Stream open(IMMDevice device, {required bool isCapture}) {
    final channels = isCapture ? 1 : 2;
    final iid = convertToIID(IID_IAudioClient);
    final ppClient = calloc<COMObject>();
    final hr = device.activate(iid, CLSCTX_ALL, nullptr, ppClient.cast());
    free(iid);
    if (FAILED(hr)) {
      free(ppClient);
      _dispose(device);
      throw _HResultFailure(hr, opening: true);
    }
    final stream = _Stream._(device, IAudioClient(ppClient), channels);
    try {
      stream._initialize(isCapture);
    } catch (_) {
      stream.close();
      rethrow;
    }
    return stream;
  }

  void _initialize(bool isCapture) {
    final format = calloc<WAVEFORMATEX>();
    format.ref
      ..wFormatTag = WAVE_FORMAT_IEEE_FLOAT
      ..nChannels = channels
      ..nSamplesPerSec = _sampleRate
      ..wBitsPerSample = 32
      ..nBlockAlign = 4 * channels
      ..nAvgBytesPerSec = _sampleRate * 4 * channels
      ..cbSize = 0;
    try {
      _check(
        client.initialize(
          AUDCLNT_SHAREMODE_SHARED,
          _autoConvertPcm |
              _srcDefaultQuality |
              (isCapture ? _eventCallback : 0),
          _bufferDuration,
          0,
          format,
          nullptr,
        ),
        opening: true,
      );
    } finally {
      free(format);
    }

    if (isCapture) {
      event = CreateEvent(nullptr, FALSE, FALSE, nullptr);
      _check(client.setEventHandle(event), opening: true);
    }
    _check(client.getBufferSize(_pFrames), opening: true);
    bufferFrames = _pFrames.value;

    final iid = convertToIID(
      isCapture ? IID_IAudioCaptureClient : IID_IAudioRenderClient,
    );
    final ppService = calloc<COMObject>();
    final hr = client.getService(iid, ppService.cast());
    free(iid);
    if (FAILED(hr)) {
      free(ppService);
      throw _HResultFailure(hr, opening: true);
    }
    if (isCapture) {
      capture = IAudioCaptureClient(ppService);
    } else {
      render = IAudioRenderClient(ppService);
      _writeSilence(_prefillFrames);
    }
  }

  void start() => _check(client.start(), opening: true);

  /// The next captured packet as mono samples, or null when none is waiting.
  Float32List? read() {
    final cap = capture!;
    _check(cap.getNextPacketSize(_pFrames));
    if (_pFrames.value == 0) return null;
    _check(cap.getBuffer(_ppData, _pFrames, _pFlags, nullptr, nullptr));
    final frames = _pFrames.value;
    final block = Float32List(frames);
    if (_pFlags.value & AUDCLNT_BUFFERFLAGS_SILENT == 0) {
      block.setAll(0, _ppData.value.cast<Float>().asTypedList(frames));
    }
    _check(cap.releaseBuffer(frames));
    return block;
  }

  /// Queues a mono block on every output channel.
  void write(Float32List mono) {
    _check(client.getCurrentPadding(_pFrames));
    final queued = _pFrames.value;
    if (queued > _maxQueuedFrames) return;
    final frames = math.min(bufferFrames - queued, mono.length);
    if (frames <= 0) return;
    _check(render!.getBuffer(frames, _ppData));
    final out = _ppData.value.cast<Float>().asTypedList(frames * channels);
    for (var i = 0; i < frames; i++) {
      final s = mono[i];
      for (var ch = 0; ch < channels; ch++) {
        out[i * channels + ch] = s;
      }
    }
    _check(render!.releaseBuffer(frames, 0));
  }

  void _writeSilence(int frames) {
    final n = math.min(frames, bufferFrames);
    _check(render!.getBuffer(n, _ppData), opening: true);
    _check(render!.releaseBuffer(n, AUDCLNT_BUFFERFLAGS_SILENT), opening: true);
  }

  void close() {
    client.stop();
    _dispose(capture);
    _dispose(render);
    _dispose(client);
    _dispose(device);
    if (event != 0) CloseHandle(event);
    free(_ppData);
    free(_pFrames);
    free(_pFlags);
  }
}

/// Everything the audio isolate owns while it runs.
class _Session {
  _Session._(this.enumerator, this.input, this.output, this.monitor, this.eq);

  final IMMDeviceEnumerator enumerator;
  final _Stream input;
  final _Stream output;
  final _Stream? monitor;
  final EqProcessor eq;
  bool bypass = false;

  double _inPeak = 0;
  double _outPeak = 0;
  final _levelClock = Stopwatch()..start();

  static _Session open(_StartArgs args) {
    final enumerator = MMDeviceEnumerator.createInstance();
    final opened = <_Stream>[];
    try {
      final input = _Stream.open(
        _openDevice(enumerator, args.inputId, eCapture),
        isCapture: true,
      );
      opened.add(input);
      final output = _Stream.open(
        _openDevice(enumerator, args.outputId, eRender),
        isCapture: false,
      );
      opened.add(output);

      _Stream? monitor;
      if (args.monitor) {
        final speakersId = _defaultId(enumerator, eRender);
        final outputId = args.outputId ?? speakersId;
        if (speakersId != null && speakersId != outputId) {
          monitor = _Stream.open(
            _openDevice(enumerator, speakersId, eRender),
            isCapture: false,
          );
          opened.add(monitor);
        }
      }

      final session = _Session._(
        enumerator,
        input,
        output,
        monitor,
        EqProcessor(
          sampleRate: _sampleRate.toDouble(),
          channels: 1,
          settings: EqSettings.fromJson(args.eq),
        ),
      )..bypass = args.bypass;
      output.start();
      monitor?.start();
      input.start();
      return session;
    } catch (_) {
      for (final s in opened) {
        s.close();
      }
      _dispose(enumerator);
      rethrow;
    }
  }

  /// Waits for the mic (at most 20 ms), then moves every waiting packet
  /// through the EQ to the outputs.
  void pump(SendPort reply) {
    WaitForSingleObject(input.event, 20);
    for (var block = input.read(); block != null; block = input.read()) {
      _inPeak = math.max(_inPeak, EqProcessor.peak(block));
      if (!bypass) eq.process(block);
      _outPeak = math.max(_outPeak, EqProcessor.peak(block));
      output.write(block);
      monitor?.write(block);
    }
    if (_levelClock.elapsed >= _levelInterval) {
      reply.send({'t': 'levels', 'in': _inPeak, 'out': _outPeak});
      _inPeak = 0;
      _outPeak = 0;
      _levelClock.reset();
    }
  }

  void close() {
    input.close();
    output.close();
    monitor?.close();
    _dispose(enumerator);
  }
}

Future<void> _audioMain(_StartArgs args) async {
  final inbox = ReceivePort();
  args.reply.send(inbox.sendPort);
  _initCom();

  final _Session session;
  try {
    session = _Session.open(args);
  } on _HResultFailure catch (e) {
    args.reply.send({'t': 'error', 'code': e.error.name, 'detail': e.detail});
    inbox.close();
    return;
  }

  var running = true;
  inbox.listen((msg) {
    if (msg is! Map) return;
    switch (msg['t']) {
      case 'eq':
        session.eq.apply(
          EqSettings.fromJson((msg['eq'] as Map).cast<String, dynamic>()),
        );
      case 'bypass':
        session.bypass = msg['v'] as bool;
      case 'stop':
        running = false;
    }
  });
  args.reply.send({'t': 'started'});

  try {
    while (running) {
      session.pump(args.reply);
      await Future<void>.delayed(Duration.zero);
    }
  } on _HResultFailure catch (e) {
    args.reply.send({'t': 'error', 'code': e.error.name, 'detail': e.detail});
  } finally {
    session.close();
    inbox.close();
  }
}
