import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'cs2_translator_service.dart';

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

/// The one-time console command that makes Numpad Enter send the latest
/// translation. CS2 ignores -netconport, so luma can't type into the console
/// itself; it rewrites [cs2SayConfigFile] and the player's key runs it.
const cs2SayConfigFile = 'luma_say.cfg';
const cs2SayBindCommand = 'bind "KP_ENTER" "exec luma_say"';

Future<Directory?> findCs2ConfigDirectory() async {
  final log = await Cs2TranslatorService.instance.findConsoleLog();
  if (log == null) return null;
  final cfg = Directory('${File(log).parent.path}${Platform.pathSeparator}cfg');
  return await cfg.exists() ? cfg : null;
}

Future<String> sendCs2Chat(
  String text,
  bool Function() stillCurrent, {
  Future<Directory?> Function()? findConfigDirectory,
}) async {
  final message = sanitizeCs2ChatMessage(text);
  final cfg = await (findConfigDirectory ?? findCs2ConfigDirectory)();
  if (cfg == null) throw const Cs2NotFound();
  if (!stillCurrent()) throw const Cs2VoiceCancelled();
  await File(
    '${cfg.path}${Platform.pathSeparator}$cs2SayConfigFile',
  ).writeAsString('say "$message"\n', flush: true);
  return message;
}

class Cs2VoiceCancelled implements Exception {
  const Cs2VoiceCancelled();
}

class Cs2NotFound implements Exception {
  const Cs2NotFound();

  @override
  String toString() =>
      'CS2 was not found in your Steam libraries, so the message could not '
      'be saved.';
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
