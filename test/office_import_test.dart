import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/chat/ai_key_store.dart';
import 'package:luma/features/chat/ai_tools.dart';
import 'package:luma/features/chat/assistant_files.dart';
import 'package:luma/features/chat/chat_controller.dart';
import 'package:luma/features/chat/data/chat_database.dart';
import 'package:luma/features/chat/data/chat_repository.dart';
import 'package:luma/features/chat/office/assistant_workbench.dart';
import 'package:luma/features/chat/office/office_document.dart';
import 'package:luma/features/chat/office/office_export.dart';
import 'package:luma/features/chat/office/office_import.dart';
import 'package:luma/features/chat/providers/ai_client.dart';
import 'package:luma/settings/settings_controller.dart';

List<int> _zip(Map<String, String> parts) {
  final archive = Archive();
  for (final entry in parts.entries) {
    final bytes = utf8.encode(entry.value);
    archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
  }
  return ZipEncoder().encode(archive);
}

const _w =
    'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';
const _rel =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const _ns =
    'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
    'xmlns:r="$_rel" '
    'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"';

String _rels(Map<String, String> targets) =>
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '${targets.entries.map((e) => '<Relationship Id="${e.key}" Type="$_rel/x" Target="${e.value}"/>').join()}'
    '</Relationships>';

String _shape(String text, {String? ph, int lvl = 0}) =>
    '<p:sp><p:nvSpPr><p:cNvPr id="2" name="s"/><p:cNvSpPr/><p:nvPr>'
    '${ph == null ? '' : '<p:ph type="$ph"/>'}</p:nvPr></p:nvSpPr><p:spPr/>'
    '<p:txBody><a:bodyPr/><a:p><a:pPr lvl="$lvl"/><a:r><a:t>$text</a:t></a:r></a:p></p:txBody></p:sp>';

String _slide(String shapes, {bool hidden = false}) =>
    '<p:sld $_ns${hidden ? ' show="0"' : ''}><p:cSld><p:spTree>$shapes</p:spTree></p:cSld></p:sld>';

class _Keys implements AiKeyStore {
  @override
  Future<String?> readKey(String providerId) async => 'test';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Tools implements AiToolRegistry {
  @override
  List<AiToolDefinition> get schemas => const [];
  @override
  List<AiToolDefinition> get localAssistantSchemas => schemas;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Reads the upload's file_id from the prompt and rewrites block 1.
class _EditingClient extends AiClient {
  String lastUserTurn = '';
  @override
  Future<AiChatResult> chat({
    required String apiKey,
    required List<AiTurn> history,
    required String systemPrompt,
    required List<AiToolDefinition> tools,
    required AiToolExecutor executeTool,
    required AiToolMetadata metadataFor,
    AiTextProgress? onText,
    AiTextProgress? onCommentary,
  }) async {
    lastUserTurn = history.last.text;
    final id = int.parse(
      RegExp(r'file_id (\d+)').firstMatch(lastUserTurn)!.group(1)!,
    );
    final result = await executeTool(AssistantWorkbench.editTool, {
      'file_id': id,
      'action': 'replace',
      'index': 1,
      'content': 'Herschreven door de assistent.',
    });
    return AiChatResult(text: 'Done: ${result['status']}');
  }
}

void main() {
  group('round trip', () {
    test('a Word file luma wrote reads back block for block', () {
      final original = OfficeDocument(OfficeKind.docx, title: 'Notitie')
        ..edit(
          action: 'append',
          content:
              '# Doel\n\nEen **vet** en *schuin* woord.\n\n- punt\n  - genest\n1. een\n2. twee\n\n> citaat\n\n| A | B |\n|---|---|\n| 1 | 2 |\n\n## Slot',
        );
      final back = importOfficeFile('n.docx', exportOfficeDocument(original));
      expect(back.document.title, 'Notitie');
      expect(
        back.document.blocks.map((b) => b.toJson()),
        original.blocks.map((b) => b.toJson()),
      );
    });

    test('slides and sheets read back too', () {
      final deck = OfficeDocument(OfficeKind.pptx)
        ..edit(
          action: 'append',
          content: '# Cover\n## Sub\n---\n# Twee\n- a\n  - b',
        );
      expect(
        importOfficeFile(
          'd.pptx',
          exportOfficeDocument(deck),
        ).document.slides.map((s) => s.toJson()),
        deck.slides.map((s) => s.toJson()),
      );
      final book = OfficeDocument(OfficeKind.xlsx)
        ..writeCells(
          sheetName: 'Data',
          cell: 'A1',
          values: [
            ['Naam', 'Waarde'],
            ['x', '2.5'],
            ['y', '=B2*2'],
          ],
        );
      final sheet = importOfficeFile(
        'b.xlsx',
        exportOfficeDocument(book),
      ).document.sheets.single;
      expect(sheet.name, 'Data');
      expect(sheet.rows, book.sheets.single.rows);
    });
  });

  test(
    'Word: localized heading styles, numbering, links, fields and tracked changes',
    () {
      final bytes = _zip({
        'word/styles.xml':
            '<w:styles $_w><w:style w:type="paragraph" w:styleId="Kop1"><w:name w:val="heading 1"/></w:style>'
            '<w:style w:type="paragraph" w:styleId="Titel"><w:name w:val="Title"/></w:style>'
            '<w:style w:type="paragraph" w:styleId="Lijstopsomteken"><w:name w:val="List Bullet"/>'
            '<w:pPr><w:numPr><w:numId w:val="7"/></w:numPr></w:pPr></w:style></w:styles>',
        'word/numbering.xml':
            '<w:numbering $_w><w:abstractNum w:abstractNumId="3"><w:lvl w:ilvl="0"><w:numFmt w:val="decimal"/></w:lvl></w:abstractNum>'
            '<w:abstractNum w:abstractNumId="4"><w:lvl w:ilvl="0"><w:numFmt w:val="bullet"/></w:lvl></w:abstractNum>'
            '<w:num w:numId="5"><w:abstractNumId w:val="3"/></w:num><w:num w:numId="7"><w:abstractNumId w:val="4"/></w:num></w:numbering>',
        'word/document.xml':
            '<w:document $_w><w:body>'
            '<w:p><w:pPr><w:pStyle w:val="Titel"/></w:pPr><w:r><w:t>Jaarplan</w:t></w:r></w:p>'
            '<w:p><w:pPr><w:pStyle w:val="Kop1"/></w:pPr><w:r><w:t>Inleiding</w:t></w:r></w:p>'
            '<w:p><w:r><w:rPr><w:b/></w:rPr><w:t xml:space="preserve">Vet </w:t></w:r>'
            '<w:hyperlink><w:r><w:t>link</w:t></w:r></w:hyperlink>'
            '<w:del><w:r><w:delText>weg</w:delText></w:r></w:del>'
            '<w:ins><w:r><w:t xml:space="preserve"> erbij</w:t></w:r></w:ins>'
            '<w:r><w:rPr><w:b w:val="0"/></w:rPr><w:t>.</w:t></w:r></w:p>'
            '<w:p><w:pPr><w:pStyle w:val="Lijstopsomteken"/></w:pPr><w:r><w:t>opsomming</w:t></w:r></w:p>'
            '<w:p><w:pPr><w:numPr><w:ilvl w:val="1"/><w:numId w:val="5"/></w:numPr></w:pPr><w:r><w:t>genummerd</w:t></w:r></w:p>'
            '<w:p/>'
            '<w:sdt><w:sdtContent><w:p><w:r><w:t>In een blok</w:t></w:r></w:p></w:sdtContent></w:sdt>'
            '<w:p><w:r><w:br w:type="page"/></w:r></w:p>'
            '<w:tbl><w:tr><w:tc><w:p><w:r><w:t>a|b</w:t></w:r></w:p></w:tc><w:tc><w:p/></w:tc></w:tr></w:tbl>'
            '</w:body></w:document>',
      });
      final blocks = importOfficeFile('jaarplan.docx', bytes).document.blocks;
      expect(blocks.map((b) => (b.type, b.text, b.level)), [
        (DocBlockType.heading, 'Jaarplan', 1),
        (DocBlockType.heading, 'Inleiding', 1),
        (DocBlockType.paragraph, '**Vet** link erbij.', 0),
        (DocBlockType.bullet, 'opsomming', 0),
        (DocBlockType.numbered, 'genummerd', 1),
        (DocBlockType.paragraph, 'In een blok', 0),
        (DocBlockType.pageBreak, '', 0),
        (DocBlockType.table, '', 0),
      ]);
      expect(blocks.last.rows, [
        ['a/b', ''],
      ]);
    },
  );

  test('PowerPoint: deck order, placeholders, hidden slides and footers', () {
    final bytes = _zip({
      'ppt/presentation.xml':
          '<p:presentation $_ns><p:sldIdLst><p:sldId id="256" r:id="rB"/><p:sldId id="257" r:id="rA"/>'
          '<p:sldId id="258" r:id="rH"/></p:sldIdLst></p:presentation>',
      'ppt/_rels/presentation.xml.rels': _rels({
        'rA': 'slides/slide1.xml',
        'rB': 'slides/slide2.xml',
        'rH': 'slides/slide3.xml',
      }),
      'ppt/slides/slide2.xml': _slide(
        _shape('Openingsdia', ph: 'ctrTitle') +
            _shape('Q3 2026', ph: 'subTitle') +
            _shape('7', ph: 'sldNum'),
      ),
      'ppt/slides/slide1.xml': _slide(
        '<p:grpSp>${_shape('Groep punt', lvl: 1)}</p:grpSp>'
        '${_shape('Resultaten', ph: 'title')}',
      ),
      'ppt/slides/slide3.xml': _slide(
        _shape('Verborgen', ph: 'title'),
        hidden: true,
      ),
    });
    final slides = importOfficeFile('q3.pptx', bytes).document.slides;
    expect(slides.length, 2);
    expect((slides[0].title, slides[0].subtitle), ('Openingsdia', 'Q3 2026'));
    expect(slides[0].bullets, isEmpty);
    expect(slides[1].title, 'Resultaten');
    expect(slides[1].bullets.map((b) => (b.text, b.level)), [
      ('Groep punt', 1),
    ]);
  });

  test('Excel: shared strings, shared formulas, booleans and missing refs', () {
    const s =
        'xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"';
    final bytes = _zip({
      'xl/workbook.xml':
          '<workbook $s xmlns:r="$_rel"><sheets><sheet name="Omzet" sheetId="1" r:id="r1"/></sheets></workbook>',
      'xl/_rels/workbook.xml.rels': _rels({
        'r1': '/xl/worksheets/sheet1.xml',
        'r2': 'sharedStrings.xml',
      }),
      'xl/sharedStrings.xml':
          '<sst $s><si><t>Maand</t></si><si><r><t>Om</t></r><r><t>zet</t></r><rPh><t>x</t></rPh></si></sst>',
      'xl/worksheets/sheet1.xml':
          '<worksheet $s><sheetData>'
          '<row r="1"><c r="A1" t="s"><v>0</v></c><c t="s"><v>1</v></c></row>'
          '<row r="3"><c r="A3"><v>1.50</v></c><c r="B3"><f t="shared" ref="B3:B4" si="0">A3*2</f><v>3</v></c><c r="C3" t="b"><v>1</v></c></row>'
          '<row><c r="A4" t="inlineStr"><is><t>los</t></is></c><c r="B4"><f t="shared" si="0"/><v>8</v></c></row>'
          '</sheetData></worksheet>',
    });
    final sheet = importOfficeFile('omzet.xlsx', bytes).document.sheets.single;
    expect(sheet.name, 'Omzet');
    expect(sheet.rows, [
      ['Maand', 'Omzet'],
      [],
      ['1.5', '=A3*2', 'TRUE'],
      ['los', '8'],
    ]);
  });

  test('anything that is not a readable Office file is refused', () {
    expect(
      () => importOfficeFile('x.docx', utf8.encode('not a zip')),
      throwsFormatException,
    );
    expect(
      () => importOfficeFile('x.doc', _zip({'a': 'b'})),
      throwsFormatException,
    );
    expect(
      () => importOfficeFile('x.docx', _zip({'word/other.xml': '<a/>'})),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('word/document.xml'),
        ),
      ),
    );
    expect(
      () => importOfficeFile(
        'x.docx',
        _zip({'word/document.xml': '<w:document'}),
      ),
      throwsFormatException,
    );
  });

  test('prompt contents are numbered and cut to the limit', () {
    final doc = OfficeDocument(OfficeKind.docx)
      ..edit(
        action: 'append',
        content: List.generate(
          400,
          (i) => 'Alinea $i is wat langer dan nodig.',
        ).join('\n\n'),
      );
    final text = officeContentsForPrompt(doc, limit: 2000);
    expect(text, startsWith('[0]\nAlinea 0'));
    expect(text.length, lessThan(2100));
    expect(text, contains('more blocks; read them with read_office_file.'));
  });

  group('uploads', () {
    late ChatDatabase db;
    late ChatRepository repo;
    late Directory directory;
    late AssistantWorkbench workbench;

    setUp(() async {
      db = ChatDatabase(NativeDatabase.memory());
      repo = ChatRepository(db);
      directory = await Directory.systemTemp.createTemp('luma_import_');
      workbench = AssistantWorkbench(repo, directory: () async => directory);
    });

    tearDown(() async {
      workbench.dispose();
      await db.close();
      await directory.delete(recursive: true);
    });

    Future<File> sampleDocx() async {
      final doc = OfficeDocument(OfficeKind.docx)
        ..edit(action: 'append', content: '# Verslag\n\nOude tekst.');
      final file = File(
        '${directory.path}${Platform.pathSeparator}Verslag Q3.docx',
      );
      await file.writeAsBytes(exportOfficeDocument(doc));
      return file;
    }

    test('picking a .docx makes an office attachment that validates', () async {
      final attachment = await AssistantAttachment.fromFile(await sampleDocx());
      expect(attachment.isOffice, isTrue);
      expect(attachment.isImage, isFalse);
      expect(attachment.validate, returnsNormally);
      expect(
        AssistantAttachment.textExtensions,
        containsAll(['docx', 'pptx', 'xlsx']),
      );
    });

    test(
      'importing makes an editable copy, opens it and tells the model its id',
      () async {
        final original = await sampleDocx();
        final before = await original.readAsBytes();
        final chat = await repo.createConversation();
        final text = await workbench.importUpload(
          chat,
          await AssistantAttachment.fromFile(original),
        );
        final artifact = (await repo.watchArtifacts().first).single;
        expect(artifact.name, 'Verslag Q3.docx');
        expect(artifact.path, isNot(original.path));
        expect(workbench.session?.document.blocks.length, 2);
        expect(text.isOffice, isFalse);
        expect(text.text, contains('file_id ${artifact.id}'));
        expect(text.text, contains('[1]\nOude tekst.'));
        expect(
          await original.readAsBytes(),
          before,
          reason: 'original untouched',
        );
      },
    );

    test(
      'a sent upload is edited by the model and history keeps only text',
      () async {
        final settings = await SettingsController.load();
        addTearDown(settings.dispose);
        settings.setAiProviderId('google');
        settings.setAdminPlan('nova');
        final client = _EditingClient();
        final controller = ChatController(
          repository: repo,
          keyStore: _Keys(),
          tools: _Tools(),
          settings: settings,
          clientOverride: client,
          workbench: workbench,
        );
        final chat = await repo.createConversation();
        await controller.sendMessage(
          chat,
          'Herschrijf de tweede alinea',
          attachments: [await AssistantAttachment.fromFile(await sampleDocx())],
        );

        final messages = await repo.loadMessages(chat);
        expect(messages.last.content, 'Done: saved');
        final stored = chatAttachmentsOf(messages.first.metadataJson).single;
        expect(
          stored.base64Data,
          isNull,
          reason: 'no file bytes in chat history',
        );
        expect(stored.text, contains('file_id'));
        expect(client.lastUserTurn, contains('Oude tekst.'));
        final copy = (await repo.watchArtifacts().first).single;
        final xml = utf8.decode(
          ZipDecoder()
                  .decodeBytes(File(copy.path).readAsBytesSync())
                  .findFile('word/document.xml')!
                  .content
              as List<int>,
        );
        expect(xml, contains('Herschreven door de assistent.'));
        expect(xml, isNot(contains('Oude tekst.')));
      },
    );

    test('a broken upload becomes a chat error, not a crash', () async {
      final settings = await SettingsController.load();
      addTearDown(settings.dispose);
      settings.setAiProviderId('google');
      settings.setAdminPlan('nova');
      final controller = ChatController(
        repository: repo,
        keyStore: _Keys(),
        tools: _Tools(),
        settings: settings,
        clientOverride: _EditingClient(),
        workbench: workbench,
      );
      final chat = await repo.createConversation();
      await controller.sendMessage(
        chat,
        'Kijk hiernaar',
        attachments: [
          AssistantAttachment(
            name: 'kapot.docx',
            mimeType: officeUploadMimeTypes['docx']!,
            base64Data: base64Encode(utf8.encode('geen zip')),
          ),
        ],
      );
      final messages = await repo.loadMessages(chat);
      expect(messages.single.role, 'error');
      expect(messages.single.content, contains('not a readable .docx'));
    });
  });
}
