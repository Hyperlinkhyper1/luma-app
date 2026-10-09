import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'assistant_file_policy.dart';
import 'data/chat_repository.dart';
import 'providers/ai_client.dart';

export 'assistant_file_policy.dart';

class AssistantAttachment {
  const AssistantAttachment({
    required this.name,
    required this.mimeType,
    this.text,
    this.base64Data,
  });
  final String name;
  final String mimeType;
  final String? text;
  final String? base64Data;
  bool get isImage => mimeType.startsWith('image/');

  void validate() {
    if (name.isEmpty || name.length > 255) {
      throw const FormatException('Invalid attachment name.');
    }
    if (isImage) {
      if (!const ['image/png', 'image/jpeg', 'image/webp'].contains(mimeType) ||
          base64Data == null ||
          base64Data!.length > 5600000 ||
          base64Decode(base64Data!).length > 4 * 1024 * 1024) {
        throw const FormatException(
          'Unsupported image or image larger than 4 MB.',
        );
      }
    } else if (text == null || text!.length > 30000) {
      throw const FormatException(
        'Attachment text is too long (maximum 30,000 characters).',
      );
    }
  }

  static const textExtensions = [
    'txt',
    'md',
    'csv',
    'json',
    'html',
    'xml',
    'dart',
    'js',
    'py',
    'css',
    'yaml',
    'yml',
    'log',
    'pdf',
  ];
  static const imageExtensions = ['png', 'jpg', 'jpeg', 'webp'];

  static Future<AssistantAttachment> fromFile(File file) async {
    if (await file.length() > 4 * 1024 * 1024) {
      throw const FormatException('Each attachment must be smaller than 4 MB.');
    }
    final bytes = await file.readAsBytes();
    final extension = p
        .extension(file.path)
        .replaceFirst('.', '')
        .toLowerCase();
    final name = p.basename(file.path);
    if (imageExtensions.contains(extension)) {
      return AssistantAttachment(
        name: name,
        mimeType: switch (extension) {
          'jpg' || 'jpeg' => 'image/jpeg',
          'webp' => 'image/webp',
          _ => 'image/png',
        },
        base64Data: base64Encode(bytes),
      );
    }
    if (!textExtensions.contains(extension)) {
      throw const FormatException('Unsupported attachment type.');
    }
    String content;
    if (extension == 'pdf') {
      final document = PdfDocument(inputBytes: bytes);
      try {
        content = PdfTextExtractor(document).extractText();
      } finally {
        document.dispose();
      }
      if (content.trim().isEmpty) {
        throw const FormatException(
          'This PDF has no readable text. Upload a text PDF or an image instead.',
        );
      }
    } else {
      content = utf8.decode(bytes);
    }
    if (content.length > 30000) {
      throw const FormatException(
        'Attachment text is too long (maximum 30,000 characters).',
      );
    }
    return AssistantAttachment(
      name: name,
      mimeType: 'text/plain',
      text: content,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'mimeType': mimeType,
    if (text != null) 'text': text,
    if (base64Data != null) 'base64Data': base64Data,
  };

  factory AssistantAttachment.fromJson(Map<String, dynamic> json) =>
      AssistantAttachment(
        name: json['name'] as String,
        mimeType: json['mimeType'] as String,
        text: json['text'] as String?,
        base64Data: json['base64Data'] as String?,
      );

  String get promptText =>
      '<luma_attachment name="${const HtmlEscape().convert(name)}">\n'
      '${text ?? '[image attached]'}\n</luma_attachment>';
}

List<AssistantAttachment> chatAttachmentsOf(String? metadata) {
  try {
    final decoded = jsonDecode(metadata ?? '{}');
    final list = decoded is Map ? decoded['attachments'] : null;
    return [
      for (final item in list is List ? list : const [])
        if (item is Map)
          AssistantAttachment.fromJson(Map<String, dynamic>.from(item)),
    ];
  } catch (_) {
    return const [];
  }
}

class AssistantArtifactStore {
  AssistantArtifactStore(
    this.repository, {
    Future<Directory> Function()? directory,
  }) : _directory = directory ?? _defaultDirectory;
  final ChatRepository repository;
  final Future<Directory> Function() _directory;

  static Future<Directory> _defaultDirectory() async => Directory(
    p.join(
      (await getApplicationSupportDirectory()).path,
      'assistant_artifacts',
    ),
  );

  static const toolName = 'create_artifact';

  Future<Map<String, dynamic>> createQr(int conversationId, String url) async {
    final painter = QrPainter(
      data: url,
      version: QrVersions.auto,
      eyeStyle: const QrEyeStyle(color: Color(0xff000000)),
      dataModuleStyle: const QrDataModuleStyle(color: Color(0xff000000)),
    );
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawColor(const Color(0xffffffff), BlendMode.src)
      ..translate(16, 16);
    painter.paint(canvas, const Size(480, 480));
    final picture = recorder.endRecording();
    final image = await picture.toImage(512, 512);
    final data = await image.toByteData(format: ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (data == null) throw StateError('Could not save the QR image.');
    final directory = await _directory();
    await directory.create(recursive: true);
    final file = File(
      p.join(directory.path, '${DateTime.now().microsecondsSinceEpoch}_qr.png'),
    );
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    final id = await repository.addArtifact(
      conversationId: conversationId,
      name: 'qr.png',
      path: file.path,
      mimeType: 'image/png',
    );
    return {
      'status': 'created',
      'id': id,
      'name': 'qr.png',
      'path': file.path,
      'mimeType': 'image/png',
    };
  }

  static final schema = AiToolDefinition(
    name: toolName,
    description:
        'Create a downloadable file in the user\'s Artifacts library. Provide the complete content. PDF content is plain text; SVG must be a valid SVG document. Do not claim a file exists until this tool succeeds.',
    parameters: {
      'type': 'object',
      'properties': {
        'name': {
          'type': 'string',
          'description': 'A short file name, without directories.',
        },
        'type': {
          'type': 'string',
          'enum': assistantArtifactTypes.keys.toList(),
        },
        'content': {
          'type': 'string',
          'description': 'Complete file content, without Markdown fences.',
        },
      },
      'required': ['name', 'type', 'content'],
    },
  );

  Future<Map<String, dynamic>> create(
    int conversationId,
    Map<String, dynamic> input, {
    String? requiredType,
  }) async {
    final type = input['type'];
    final content = input['content'];
    if (type is! String ||
        !assistantArtifactTypes.containsKey(type) ||
        (requiredType != null && type != requiredType)) {
      throw const FormatException('Choose a supported artifact type.');
    }
    if (content is! String ||
        content.trim().isEmpty ||
        content.length > 250000) {
      throw const FormatException(
        'The artifact must contain complete content (maximum 250,000 characters).',
      );
    }
    if (type == 'json') {
      jsonDecode(content);
    }
    if (type == 'svg' && !content.contains('<svg')) {
      throw const FormatException('The image must contain an SVG document.');
    }
    final rawName = p.basename(input['name']?.toString() ?? 'artifact');
    final stem = p
        .basenameWithoutExtension(rawName)
        .replaceAll(RegExp(r'[^\p{L}\p{N} _-]', unicode: true), '_');
    final name =
        '${stem.isEmpty ? 'artifact' : stem.substring(0, stem.length.clamp(0, 80))}.$type';
    final directory = await _directory();
    await directory.create(recursive: true);
    final file = File(
      p.join(directory.path, '${DateTime.now().microsecondsSinceEpoch}_$name'),
    );
    Uint8List bytes;
    if (type == 'pdf') {
      final document = PdfDocument();
      try {
        PdfTextElement(
          text: content,
          font: PdfStandardFont(PdfFontFamily.helvetica, 11),
        ).draw(
          page: document.pages.add(),
          bounds: const Rect.fromLTWH(0, 0, 500, 720),
          format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
        );
        bytes = Uint8List.fromList(await document.save());
      } finally {
        document.dispose();
      }
    } else {
      bytes = Uint8List.fromList(utf8.encode(content));
    }
    await file.writeAsBytes(bytes, flush: true);
    final mime = switch (type) {
      'pdf' => 'application/pdf',
      'html' => 'text/html',
      'csv' => 'text/csv',
      'json' => 'application/json',
      'svg' => 'image/svg+xml',
      'md' => 'text/markdown',
      _ => 'text/plain',
    };
    try {
      final id = await repository.addArtifact(
        conversationId: conversationId,
        name: name,
        path: file.path,
        mimeType: mime,
      );
      return {
        'status': 'created',
        'id': id,
        'name': name,
        'path': file.path,
        'mimeType': mime,
      };
    } catch (_) {
      await file.delete();
      rethrow;
    }
  }
}
