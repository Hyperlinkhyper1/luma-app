import 'dart:async';
import 'dart:convert';
import 'dart:io';

String sanitizeCs2ChatMessage(String text, {int maxBytes = 120}) {
  final clean = text
      .replaceAll(RegExp(r'[\x00-\x1f\x7f-\x9f\u2028\u2029]'), ' ')
      .replaceAll('"', "'")
      .replaceAll(RegExp(r'[;\\]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final result = StringBuffer();
  var bytes = 0;
  for (final rune in clean.runes) {
    final char = String.fromCharCode(rune);
    final size = utf8.encode(char).length;
    if (bytes + size > maxBytes) break;
    result.write(char);
    bytes += size;
  }
  final message = result.toString().trim();
  if (message.isEmpty) throw const FormatException('The translation is empty.');
  return message;
}

const cs2NetconPort = 2121;

// CS2's -netconport can listen on the PC's LAN address instead of loopback,
// so every local address is worth a try before giving up.
Future<Socket> connectCs2Netcon() async {
  final candidates = <InternetAddress>[
    InternetAddress.loopbackIPv4,
    InternetAddress.loopbackIPv6,
  ];
  try {
    for (final interface in await NetworkInterface.list()) {
      candidates.addAll(interface.addresses);
    }
  } on SocketException {
    // Loopback alone is still worth trying.
  }
  SocketException? lastError;
  for (final address in candidates) {
    try {
      return await Socket.connect(
        address,
        cs2NetconPort,
        timeout: const Duration(milliseconds: 600),
      );
    } on SocketException catch (error) {
      lastError = error;
    }
  }
  throw lastError ??
      const SocketException('No local address accepted the connection.');
}

Future<String> sendCs2Chat(
  String text,
  bool Function() stillCurrent, {
  Future<Socket> Function()? connect,
}) async {
  final message = sanitizeCs2ChatMessage(text);
  final socket = await (connect ?? connectCs2Netcon)();
  final incoming = socket.listen((_) {}, onError: (Object _) {});
  try {
    if (!stillCurrent()) throw const Cs2VoiceCancelled();
    socket.add(utf8.encode('say "$message"\n'));
    await socket.flush().timeout(const Duration(seconds: 2));
    return message;
  } finally {
    socket.destroy();
    await incoming.cancel();
  }
}

class Cs2VoiceCancelled implements Exception {
  const Cs2VoiceCancelled();
}

class Cs2VoiceTranslation {
  const Cs2VoiceTranslation({
    required this.transcript,
    required this.translation,
  });

  final String transcript;
  final String translation;

  factory Cs2VoiceTranslation.fromJson(Map<String, dynamic> json) {
    final transcript = json['transcript'];
    final translation = json['translation'];
    if (transcript is! String ||
        transcript.trim().isEmpty ||
        translation is! String ||
        translation.trim().isEmpty) {
      throw const FormatException('No speech or translation was returned.');
    }
    return Cs2VoiceTranslation(
      transcript: transcript.trim(),
      translation: translation.trim(),
    );
  }
}
