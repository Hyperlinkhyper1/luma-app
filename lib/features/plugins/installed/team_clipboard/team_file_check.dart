import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../../../l10n/app_localizations.dart';
import 'team_clipboard_models.dart';

/// The same limits the server holds files to (`server/lib/team_board.dart`).
const kTeamMaxImageWidth = 4096;
const kTeamMaxImageHeight = 16384;
const kTeamMaxImagePixels = 16 * 1024 * 1024;
const kTeamMaxJsonDepth = 64;

enum TeamFileProblemKind {
  wrongType,
  empty,
  tooLarge,
  badPng,
  imageTooBig,
  notText,
  badJson,
  notObject,
  tooDeep,
}

/// Why a file can't be attached. [line] and [column] point at a JSON error.
class TeamFileProblem {
  const TeamFileProblem(this.kind, {this.line = 0, this.column = 0});

  final TeamFileProblemKind kind;
  final int line;
  final int column;

  String describe(L t, String name) => switch (kind) {
    TeamFileProblemKind.wrongType => t.teamClipboardFileWrongType(name),
    TeamFileProblemKind.empty => t.teamClipboardFileEmpty(name),
    TeamFileProblemKind.tooLarge => t.teamClipboardFileTooLarge(name),
    TeamFileProblemKind.badPng => t.teamClipboardFileBadPng(name),
    TeamFileProblemKind.imageTooBig => t.teamClipboardFileImageTooBig(
      name,
      kTeamMaxImageWidth,
      kTeamMaxImageHeight,
    ),
    TeamFileProblemKind.notText => t.teamClipboardFileNotText(name),
    TeamFileProblemKind.badJson => t.teamClipboardFileBadJson(
      name,
      line,
      column,
    ),
    TeamFileProblemKind.notObject => t.teamClipboardFileNotObject(name),
    TeamFileProblemKind.tooDeep => t.teamClipboardFileTooDeep(
      name,
      kTeamMaxJsonDepth,
    ),
  };
}

/// Checks a file the way the server will, before it is sent: the right
/// extension and size, a PNG that is whole (every chunk's CRC right, IHDR
/// first, IEND last, nothing hidden after it) and actually decodes, and a
/// model or `.mcmeta` that parses as a JSON object. Null when it's fine.
Future<TeamFileProblem?> checkTeamFile(String name, Uint8List bytes) async {
  final problem = teamFileStructureProblem(name, bytes);
  if (problem != null) return problem;
  if (_extension(name) == 'png' && !await compute(_decodes, bytes)) {
    return const TeamFileProblem(TeamFileProblemKind.badPng);
  }
  return null;
}

bool _decodes(Uint8List bytes) {
  try {
    return img.decodePng(bytes) != null;
  } catch (_) {
    return false;
  }
}

/// [checkTeamFile] without the image decode, which needs an isolate.
TeamFileProblem? teamFileStructureProblem(String name, Uint8List bytes) {
  final ext = _extension(name);
  if (!kTeamFileExtensions.contains(ext)) {
    return const TeamFileProblem(TeamFileProblemKind.wrongType);
  }
  if (bytes.isEmpty) return const TeamFileProblem(TeamFileProblemKind.empty);
  if (bytes.length > kTeamMaxFileBytes) {
    return const TeamFileProblem(TeamFileProblemKind.tooLarge);
  }
  return ext == 'png' ? _pngProblem(bytes) : _jsonProblem(bytes);
}

String _extension(String name) {
  final dot = name.lastIndexOf('.');
  return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
}

const _pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
final _chunkType = RegExp(r'^[A-Za-z]{4}$');

TeamFileProblem? _pngProblem(Uint8List bytes) {
  const bad = TeamFileProblem(TeamFileProblemKind.badPng);
  if (bytes.length < 8 + 25 + 12) return bad;
  for (var i = 0; i < _pngSignature.length; i++) {
    if (bytes[i] != _pngSignature[i]) return bad;
  }
  final data = ByteData.sublistView(bytes);
  var at = 8;
  var first = true;
  var sawData = false;
  while (true) {
    if (at + 12 > bytes.length) return bad;
    final length = data.getUint32(at);
    if (length > bytes.length - at - 12) return bad;
    final type = String.fromCharCodes(bytes, at + 4, at + 8);
    if (!_chunkType.hasMatch(type)) return bad;
    if (_crc32(bytes, at + 4, at + 8 + length) !=
        data.getUint32(at + 8 + length)) {
      return bad;
    }
    if (first) {
      if (type != 'IHDR' || length != 13) return bad;
      final width = data.getUint32(at + 8);
      final height = data.getUint32(at + 12);
      if (width == 0 || height == 0) return bad;
      if (width > kTeamMaxImageWidth ||
          height > kTeamMaxImageHeight ||
          width * height > kTeamMaxImagePixels) {
        return const TeamFileProblem(TeamFileProblemKind.imageTooBig);
      }
      first = false;
    } else if (type == 'IHDR') {
      return bad;
    }
    if (type == 'IDAT') sawData = true;
    at += 12 + length;
    if (type == 'IEND') {
      return sawData && length == 0 && at == bytes.length ? null : bad;
    }
  }
}

TeamFileProblem? _jsonProblem(Uint8List bytes) {
  var start = 0;
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    start = 3;
  }
  final String text;
  try {
    text = utf8.decode(Uint8List.sublistView(bytes, start));
  } on FormatException {
    return const TeamFileProblem(TeamFileProblemKind.notText);
  }
  var depth = 0;
  var inString = false;
  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if (inString) {
      if (c == 0x5C) {
        i++;
      } else if (c == 0x22) {
        inString = false;
      }
    } else if (c == 0x22) {
      inString = true;
    } else if (c == 0x7B || c == 0x5B) {
      if (++depth > kTeamMaxJsonDepth) {
        return const TeamFileProblem(TeamFileProblemKind.tooDeep);
      }
    } else if (c == 0x7D || c == 0x5D) {
      depth--;
    }
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException catch (e) {
    final end = (e.offset ?? 0).clamp(0, text.length);
    var line = 1, column = 1;
    for (var i = 0; i < end; i++) {
      if (text.codeUnitAt(i) == 0x0A) {
        line++;
        column = 1;
      } else {
        column++;
      }
    }
    return TeamFileProblem(
      TeamFileProblemKind.badJson,
      line: line,
      column: column,
    );
  }
  if (decoded is! Map) {
    return const TeamFileProblem(TeamFileProblemKind.notObject);
  }
  return null;
}

final List<int> _crcTable = List.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(Uint8List bytes, int start, int end) {
  var crc = 0xFFFFFFFF;
  for (var i = start; i < end; i++) {
    crc = _crcTable[(crc ^ bytes[i]) & 0xFF] ^ (crc >> 8);
  }
  return crc ^ 0xFFFFFFFF;
}
