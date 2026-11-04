import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:luma/features/chat/clipboard_files.dart';
import 'package:luma/features/chat/data/chat_repository.dart';
import 'package:luma/features/chat/picture_context.dart';

ChatMessageRecord _msg(int id, String role, String content, {String? image}) =>
    ChatMessageRecord(
      id: id,
      conversationId: 1,
      role: role,
      content: content,
      createdAt: DateTime(2026, 1, 1, 0, id),
      metadataJson: image == null
          ? null
          : jsonEncode({'imagePath': image, 'composeMode': 'picture'}),
    );

void main() {
  group('PictureContext', () {
    test('an empty chat sends the prompt unchanged', () {
      final context = PictureContext.fromHistory(const []);
      expect(context.isEmpty, isTrue);
      expect(context.promptFor('a cat', editingImage: false), 'a cat');
    });

    test('collects the prompts behind each picture and the newest path', () {
      final context = PictureContext.fromHistory([
        _msg(1, 'user', 'hello'),
        _msg(2, 'assistant', 'hi'),
        _msg(3, 'user', 'a red fox'),
        _msg(4, 'assistant', '', image: '/a.png'),
        _msg(5, 'user', 'make it snow'),
        _msg(6, 'error', 'failed'),
        _msg(7, 'user', 'make it snow please'),
        _msg(8, 'assistant', '', image: '/b.png'),
      ]);
      expect(context.prompts, ['a red fox', 'make it snow please']);
      expect(context.lastImagePath, '/b.png');
    });

    test('asks the model to edit the previous picture', () {
      final context = PictureContext.fromHistory([
        _msg(1, 'user', 'a red fox'),
        _msg(2, 'assistant', '', image: '/a.png'),
      ]);
      final prompt = context.promptFor('add a hat', editingImage: true);
      expect(prompt, contains('The first image is the picture you drew last'));
      expect(prompt, contains('- a red fox'));
      expect(prompt, endsWith('New request: add a hat'));
    });

    test('without image input, folds earlier prompts into a redraw', () {
      final context = PictureContext.fromHistory([
        _msg(1, 'user', 'a red fox'),
        _msg(2, 'assistant', '', image: '/a.png'),
      ]);
      final prompt = context.promptFor('add a hat', editingImage: false);
      expect(prompt, startsWith('Redraw the picture'));
      expect(prompt, contains('- a red fox'));
    });

    test('drops the oldest prompts to stay under the length cap', () {
      final long = 'x' * 1500;
      final context = PictureContext.fromHistory([
        for (var i = 0; i < 4; i++) ...[
          _msg(i * 2, 'user', '$i$long'),
          _msg(i * 2 + 1, 'assistant', '', image: '/$i.png'),
        ],
      ]);
      final prompt = context.promptFor('final', editingImage: true);
      expect(prompt.length, lessThanOrEqualTo(PictureContext.maxPromptChars));
      expect(prompt, isNot(contains('0$long')));
      expect(prompt, contains('3$long'));
      expect(prompt, endsWith('New request: final'));
    });
  });

  test('a zero-alpha 32-bit clipboard DIB turns into an opaque PNG', () {
    const width = 2, height = 2;
    final dib = Uint8List(40 + width * height * 4);
    ByteData.sublistView(dib)
      ..setUint32(0, 40, Endian.little)
      ..setInt32(4, width, Endian.little)
      ..setInt32(8, height, Endian.little)
      ..setUint16(12, 1, Endian.little)
      ..setUint16(14, 32, Endian.little)
      ..setUint32(16, 0, Endian.little)
      ..setUint32(20, width * height * 4, Endian.little);
    for (var i = 0; i < width * height; i++) {
      dib[40 + i * 4] = 255;
    }
    final png = ClipboardFiles.dibToPng(dib);
    expect(png, isNotNull);
    final decoded = img.decodePng(png!)!;
    expect(decoded.width, width);
    expect(decoded.height, height);
    final pixel = decoded.getPixel(0, 0);
    expect(pixel.b, 255);
    expect(pixel.a, 255);
  });
}
