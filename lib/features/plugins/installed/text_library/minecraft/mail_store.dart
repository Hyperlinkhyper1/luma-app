import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// The Minecraft hall's post and vault: how long the hall has been open
/// toward the next letter, the letters waiting in the mailbox (each its coin
/// amount), the coins in the reader's hand and those in the vault.
///
/// The page does the timing and hands the whole state over whenever it
/// changes; it is kept on this device only, like the skin.
class MailState {
  const MailState({
    this.open = 0,
    this.letters = const [],
    this.hand = 0,
    this.vault = 0,
  });

  /// Seconds counted toward the next letter.
  final int open;
  final List<int> letters;
  final int hand;
  final int vault;

  static int _count(Object? value) => switch (value) {
    final num n when n.isFinite && n > 0 => n.floor(),
    _ => 0,
  };

  /// Whatever the page sent, cleaned up: counts are whole and never negative,
  /// and empty letters are dropped.
  factory MailState.fromJson(Object? json) {
    if (json is! Map) return const MailState();
    final letters = json['letters'];
    return MailState(
      open: _count(json['open']),
      letters: [
        if (letters is List)
          for (final l in letters.take(9))
            if (_count(l) > 0) _count(l),
      ],
      hand: _count(json['hand']),
      vault: _count(json['vault']),
    );
  }

  Map<String, Object?> toJson() => {
    'open': open,
    'letters': letters,
    'hand': hand,
    'vault': vault,
  };
}

Future<File> _file() async {
  final support = await getApplicationSupportDirectory();
  return File(
    '${support.path}${Platform.pathSeparator}text_library_mail.json',
  );
}

Future<MailState?> loadMail() async {
  try {
    final file = await _file();
    if (!await file.exists()) return null;
    return MailState.fromJson(jsonDecode(await file.readAsString()));
  } catch (_) {
    return null;
  }
}

Future<void> _saving = Future.value();

/// Saves one after another, so a quick run of changes lands in order.
Future<void> saveMail(MailState state) {
  final next = _saving.catchError((Object _) {}).then((_) async {
    final file = await _file();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(state.toJson()), flush: true);
    await temp.rename(file.path);
  });
  _saving = next;
  return next;
}
