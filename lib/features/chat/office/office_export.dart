import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'office_document.dart';

/// Serialises an [OfficeDocument] as a real .docx, .pptx or .xlsx file:
/// a zip of the smallest set of Open XML parts Word, PowerPoint, Excel and
/// LibreOffice open without a repair prompt.
Uint8List exportOfficeDocument(OfficeDocument document) {
  final parts = switch (document.kind) {
    OfficeKind.docx => _docxParts(document),
    OfficeKind.pptx => _pptxParts(document),
    OfficeKind.xlsx => _xlsxParts(document),
  };
  parts['docProps/core.xml'] = _coreProps(document.title);
  final archive = Archive();
  for (final entry in parts.entries) {
    final bytes = utf8.encode(entry.value);
    archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

const _xmlHeader = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';
const _relsNs = 'http://schemas.openxmlformats.org/package/2006/relationships';
const _officeRel =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const _drawingNs = 'http://schemas.openxmlformats.org/drawingml/2006/main';

final _invalidXmlChars = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]');

String _esc(String value) => value
    .replaceAll(_invalidXmlChars, '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _contentTypes(Map<String, String> overrides) =>
    '$_xmlHeader<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '${overrides.entries.map((e) => '<Override PartName="/${e.key}" ContentType="${e.value}"/>').join()}'
    '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
    '</Types>';

String _rels(List<(String id, String type, String target)> rels) =>
    '$_xmlHeader<Relationships xmlns="$_relsNs">'
    '${rels.map((r) => '<Relationship Id="${r.$1}" Type="${r.$2}" Target="${r.$3}"/>').join()}'
    '</Relationships>';

String _rootRels(String mainPart) => _rels([
  ('rId1', '$_officeRel/officeDocument', mainPart),
  (
    'rId2',
    'http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties',
    'docProps/core.xml',
  ),
]);

String _coreProps(String title) {
  final now = '${DateTime.now().toUtc().toIso8601String().split('.').first}Z';
  return '$_xmlHeader<cp:coreProperties '
      'xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
      'xmlns:dc="http://purl.org/dc/elements/1.1/" '
      'xmlns:dcterms="http://purl.org/dc/terms/" '
      'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
      '<dc:title>${_esc(title)}</dc:title><dc:creator>luma</dc:creator>'
      '<dcterms:created xsi:type="dcterms:W3CDTF">$now</dcterms:created>'
      '<dcterms:modified xsi:type="dcterms:W3CDTF">$now</dcterms:modified>'
      '</cp:coreProperties>';
}

// ---------------------------------------------------------------- Word

const _wNs = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';

Map<String, String> _docxParts(OfficeDocument document) {
  final numbered = <int>[];
  final body = StringBuffer();
  var numberedListOpen = false;
  for (final block in document.blocks) {
    if (block.type == DocBlockType.numbered) {
      if (!numberedListOpen) numbered.add(numbered.length + 2);
      numberedListOpen = true;
    } else if (block.type != DocBlockType.bullet) {
      numberedListOpen = false;
    }
    body.write(_docBlock(block, numbered.isEmpty ? 2 : numbered.last));
  }
  body.write(
    '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
    '<w:pgMar w:top="1417" w:right="1417" w:bottom="1417" w:left="1417" '
    'w:header="708" w:footer="708" w:gutter="0"/></w:sectPr>',
  );
  return {
    '[Content_Types].xml': _contentTypes({
      'word/document.xml':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml',
      'word/styles.xml':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml',
      'word/numbering.xml':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml',
    }),
    '_rels/.rels': _rootRels('word/document.xml'),
    'word/_rels/document.xml.rels': _rels([
      ('rId1', '$_officeRel/styles', 'styles.xml'),
      ('rId2', '$_officeRel/numbering', 'numbering.xml'),
    ]),
    'word/document.xml':
        '$_xmlHeader<w:document xmlns:w="$_wNs" xmlns:r="$_officeRel"><w:body>$body</w:body></w:document>',
    'word/styles.xml': _docxStyles,
    'word/numbering.xml': _docxNumbering(numbered),
  };
}

String _runs(String text, {bool bold = false}) => [
  for (final run in parseInline(text))
    '<w:r>${run.bold || run.italic || bold ? '<w:rPr>${run.bold || bold ? '<w:b/>' : ''}${run.italic ? '<w:i/>' : ''}</w:rPr>' : ''}'
        '<w:t xml:space="preserve">${_esc(run.text)}</w:t></w:r>',
].join();

String _docBlock(DocBlock block, int numberedId) => switch (block.type) {
  DocBlockType.heading =>
    '<w:p><w:pPr><w:pStyle w:val="Heading${block.level.clamp(1, 3)}"/></w:pPr>${_runs(block.text)}</w:p>',
  DocBlockType.paragraph => '<w:p>${_runs(block.text)}</w:p>',
  DocBlockType.bullet =>
    '<w:p><w:pPr><w:pStyle w:val="ListParagraph"/><w:numPr><w:ilvl w:val="${block.level}"/><w:numId w:val="1"/></w:numPr></w:pPr>${_runs(block.text)}</w:p>',
  DocBlockType.numbered =>
    '<w:p><w:pPr><w:pStyle w:val="ListParagraph"/><w:numPr><w:ilvl w:val="${block.level}"/><w:numId w:val="$numberedId"/></w:numPr></w:pPr>${_runs(block.text)}</w:p>',
  DocBlockType.quote =>
    '<w:p><w:pPr><w:pStyle w:val="Quote"/></w:pPr>${_runs(block.text)}</w:p>',
  DocBlockType.pageBreak => '<w:p><w:r><w:br w:type="page"/></w:r></w:p>',
  DocBlockType.table => _docTable(block.rows),
};

String _docTable(List<List<String>> rows) {
  final columns = rows.fold(1, (m, r) => math.max(m, r.length));
  final width = 9072 ~/ columns;
  const border = 'w:val="single" w:sz="4" w:space="0" w:color="BFC7D5"';
  final buffer = StringBuffer(
    '<w:tbl><w:tblPr><w:tblW w:w="5000" w:type="pct"/>'
    '<w:tblBorders><w:top $border/><w:left $border/><w:bottom $border/>'
    '<w:right $border/><w:insideH $border/><w:insideV $border/></w:tblBorders>'
    '<w:tblCellMar><w:left w:w="108" w:type="dxa"/><w:right w:w="108" w:type="dxa"/></w:tblCellMar>'
    '</w:tblPr><w:tblGrid>${'<w:gridCol w:w="$width"/>' * columns}</w:tblGrid>',
  );
  for (final (i, row) in rows.indexed) {
    buffer.write('<w:tr>');
    for (var c = 0; c < columns; c++) {
      final text = c < row.length ? row[c] : '';
      buffer.write(
        '<w:tc><w:tcPr><w:tcW w:w="$width" w:type="dxa"/>'
        '${i == 0 ? '<w:shd w:val="clear" w:color="auto" w:fill="E7EEF8"/>' : ''}'
        '</w:tcPr><w:p><w:pPr><w:spacing w:after="0"/></w:pPr>${_runs(text, bold: i == 0)}</w:p></w:tc>',
      );
    }
    buffer.write('</w:tr>');
  }
  buffer.write('</w:tbl><w:p/>');
  return buffer.toString();
}

const _docxStyles =
    '$_xmlHeader<w:styles xmlns:w="$_wNs">'
    '<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:eastAsia="Calibri" w:cs="Calibri"/>'
    '<w:sz w:val="22"/><w:szCs w:val="22"/><w:lang w:val="en-US"/></w:rPr></w:rPrDefault>'
    '<w:pPrDefault><w:pPr><w:spacing w:after="160" w:line="276" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>'
    '<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/></w:style>'
    '<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/>'
    '<w:pPr><w:keepNext/><w:spacing w:before="360" w:after="120"/><w:outlineLvl w:val="0"/></w:pPr>'
    '<w:rPr><w:b/><w:color w:val="1F3A5F"/><w:sz w:val="36"/><w:szCs w:val="36"/></w:rPr></w:style>'
    '<w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/>'
    '<w:pPr><w:keepNext/><w:spacing w:before="280" w:after="100"/><w:outlineLvl w:val="1"/></w:pPr>'
    '<w:rPr><w:b/><w:color w:val="1F3A5F"/><w:sz w:val="28"/><w:szCs w:val="28"/></w:rPr></w:style>'
    '<w:style w:type="paragraph" w:styleId="Heading3"><w:name w:val="heading 3"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/>'
    '<w:pPr><w:keepNext/><w:spacing w:before="200" w:after="80"/><w:outlineLvl w:val="2"/></w:pPr>'
    '<w:rPr><w:b/><w:color w:val="2E4B73"/><w:sz w:val="24"/><w:szCs w:val="24"/></w:rPr></w:style>'
    '<w:style w:type="paragraph" w:styleId="ListParagraph"><w:name w:val="List Paragraph"/><w:basedOn w:val="Normal"/>'
    '<w:pPr><w:spacing w:after="60"/><w:ind w:left="720"/><w:contextualSpacing/></w:pPr></w:style>'
    '<w:style w:type="paragraph" w:styleId="Quote"><w:name w:val="Quote"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/>'
    '<w:pPr><w:ind w:left="567" w:right="567"/></w:pPr><w:rPr><w:i/><w:color w:val="555F6D"/></w:rPr></w:style>'
    '</w:styles>';

String _docxNumbering(List<int> numberedIds) {
  String level(int i, String format, String text, String font) =>
      '<w:lvl w:ilvl="$i"><w:start w:val="1"/><w:numFmt w:val="$format"/>'
      '<w:lvlText w:val="$text"/><w:lvlJc w:val="left"/>'
      '<w:pPr><w:ind w:left="${720 + 360 * i}" w:hanging="360"/></w:pPr>'
      '${font.isEmpty ? '' : '<w:rPr><w:rFonts w:ascii="$font" w:hAnsi="$font" w:hint="default"/></w:rPr>'}</w:lvl>';
  final bullets = [
    level(0, 'bullet', '•', ''),
    level(1, 'bullet', 'o', 'Courier New'),
    level(2, 'bullet', '▪', ''),
  ].join();
  final decimals = [
    level(0, 'decimal', '%1.', ''),
    level(1, 'lowerLetter', '%2.', ''),
    level(2, 'lowerRoman', '%3.', ''),
  ].join();
  return '$_xmlHeader<w:numbering xmlns:w="$_wNs">'
      '<w:abstractNum w:abstractNumId="0"><w:multiLevelType w:val="hybridMultilevel"/>$bullets</w:abstractNum>'
      '<w:abstractNum w:abstractNumId="1"><w:multiLevelType w:val="hybridMultilevel"/>$decimals</w:abstractNum>'
      '<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>'
      '${[
        for (final id in {2, ...numberedIds}) '<w:num w:numId="$id"><w:abstractNumId w:val="1"/>'
              '<w:lvlOverride w:ilvl="0"><w:startOverride w:val="1"/></w:lvlOverride></w:num>',
      ].join()}'
      '</w:numbering>';
}

// ---------------------------------------------------------- PowerPoint

const _pNs = 'http://schemas.openxmlformats.org/presentationml/2006/main';
const _pptNs = 'xmlns:a="$_drawingNs" xmlns:r="$_officeRel" xmlns:p="$_pNs"';
const _slideWidth = 12192000;
const _slideHeight = 6858000;

Map<String, String> _pptxParts(OfficeDocument document) {
  final slides = document.slides.isEmpty
      ? [OfficeSlide(title: document.title)]
      : document.slides;
  const pres = 'application/vnd.openxmlformats-officedocument.presentationml';
  final parts = <String, String>{
    '[Content_Types].xml': _contentTypes({
      'ppt/presentation.xml': '$pres.presentation.main+xml',
      'ppt/presProps.xml': '$pres.presProps+xml',
      'ppt/viewProps.xml': '$pres.viewProps+xml',
      'ppt/tableStyles.xml': '$pres.tableStyles+xml',
      'ppt/slideMasters/slideMaster1.xml': '$pres.slideMaster+xml',
      'ppt/slideLayouts/slideLayout1.xml': '$pres.slideLayout+xml',
      'ppt/theme/theme1.xml':
          'application/vnd.openxmlformats-officedocument.theme+xml',
      for (var i = 1; i <= slides.length; i++)
        'ppt/slides/slide$i.xml': '$pres.slide+xml',
    }),
    '_rels/.rels': _rootRels('ppt/presentation.xml'),
    'ppt/_rels/presentation.xml.rels': _rels([
      ('rId1', '$_officeRel/slideMaster', 'slideMasters/slideMaster1.xml'),
      for (var i = 1; i <= slides.length; i++)
        ('rId${i + 1}', '$_officeRel/slide', 'slides/slide$i.xml'),
      ('rId${slides.length + 2}', '$_officeRel/presProps', 'presProps.xml'),
      ('rId${slides.length + 3}', '$_officeRel/viewProps', 'viewProps.xml'),
      ('rId${slides.length + 4}', '$_officeRel/theme', 'theme/theme1.xml'),
      ('rId${slides.length + 5}', '$_officeRel/tableStyles', 'tableStyles.xml'),
    ]),
    'ppt/presentation.xml':
        '$_xmlHeader<p:presentation $_pptNs saveSubsetFonts="1">'
        '<p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>'
        '<p:sldIdLst>${[for (var i = 1; i <= slides.length; i++) '<p:sldId id="${255 + i}" r:id="rId${i + 1}"/>'].join()}</p:sldIdLst>'
        '<p:sldSz cx="$_slideWidth" cy="$_slideHeight"/><p:notesSz cx="6858000" cy="9144000"/>'
        '</p:presentation>',
    'ppt/presProps.xml': '$_xmlHeader<p:presentationPr $_pptNs/>',
    'ppt/viewProps.xml':
        '$_xmlHeader<p:viewPr $_pptNs><p:slideViewPr><p:cSldViewPr><p:cViewPr>'
        '<p:scale><a:sx n="100" d="100"/><a:sy n="100" d="100"/></p:scale><p:origin x="0" y="0"/>'
        '</p:cViewPr><p:guideLst/></p:cSldViewPr></p:slideViewPr><p:gridSpacing cx="76200" cy="76200"/></p:viewPr>',
    'ppt/tableStyles.xml':
        '$_xmlHeader<a:tblStyleLst xmlns:a="$_drawingNs" def="{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}"/>',
    'ppt/slideMasters/slideMaster1.xml':
        '$_xmlHeader<p:sldMaster $_pptNs><p:cSld><p:bg><p:bgRef idx="1001"><a:schemeClr val="bg1"/></p:bgRef></p:bg>'
        '$_emptyTree</p:cSld>'
        '<p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" '
        'accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>'
        '<p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst></p:sldMaster>',
    'ppt/slideMasters/_rels/slideMaster1.xml.rels': _rels([
      ('rId1', '$_officeRel/slideLayout', '../slideLayouts/slideLayout1.xml'),
      ('rId2', '$_officeRel/theme', '../theme/theme1.xml'),
    ]),
    'ppt/slideLayouts/slideLayout1.xml':
        '$_xmlHeader<p:sldLayout $_pptNs type="blank" preserve="1"><p:cSld name="Blank">$_emptyTree</p:cSld>'
        '<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>',
    'ppt/slideLayouts/_rels/slideLayout1.xml.rels': _rels([
      ('rId1', '$_officeRel/slideMaster', '../slideMasters/slideMaster1.xml'),
    ]),
    'ppt/theme/theme1.xml': _theme,
  };
  for (final (i, slide) in slides.indexed) {
    parts['ppt/slides/slide${i + 1}.xml'] = _slideXml(slide, cover: i == 0);
    parts['ppt/slides/_rels/slide${i + 1}.xml.rels'] = _rels([
      ('rId1', '$_officeRel/slideLayout', '../slideLayouts/slideLayout1.xml'),
    ]);
  }
  return parts;
}

const _emptyTree =
    '<p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
    '<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree>';

/// A cover slide when it has no bullets, a title-and-content slide otherwise.
/// Every shape is a plain text box with explicit geometry, so the deck does
/// not depend on layout placeholders.
String _slideXml(OfficeSlide slide, {required bool cover}) {
  final isCover = cover && slide.bullets.isEmpty;
  var shapeId = 2;
  String box(
    int x,
    int y,
    int w,
    int h,
    String paragraphs, {
    String anchor = 't',
  }) =>
      '<p:sp><p:nvSpPr><p:cNvPr id="${shapeId++}" name="Text ${shapeId - 2}"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>'
      '<p:spPr><a:xfrm><a:off x="$x" y="$y"/><a:ext cx="$w" cy="$h"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:noFill/></p:spPr>'
      '<p:txBody><a:bodyPr wrap="square" lIns="0" rIns="0" anchor="$anchor"><a:normAutofit/></a:bodyPr><a:lstStyle/>$paragraphs</p:txBody></p:sp>';
  String para(
    String text, {
    required int size,
    bool bold = false,
    String color = '1F2937',
    int level = 0,
    bool bullet = false,
  }) {
    final runs = parseInline(text)
        .map(
          (run) =>
              '<a:r><a:rPr lang="en-US" sz="$size" b="${bold || run.bold ? 1 : 0}" i="${run.italic ? 1 : 0}" dirty="0">'
              '<a:solidFill><a:srgbClr val="$color"/></a:solidFill></a:rPr><a:t>${_esc(run.text)}</a:t></a:r>',
        )
        .join();
    final indent = 342900 + level * 342900;
    final pPr = bullet
        ? '<a:pPr marL="$indent" indent="-285750"><a:spcBef><a:spcPts val="900"/></a:spcBef>'
              '<a:buClr><a:srgbClr val="2563EB"/></a:buClr><a:buFont typeface="Arial"/><a:buChar char="${level == 0 ? '•' : '–'}"/></a:pPr>'
        : '<a:pPr><a:buNone/></a:pPr>';
    return '<a:p>$pPr${runs.isEmpty ? '' : runs}<a:endParaRPr lang="en-US" sz="$size" dirty="0"/></a:p>';
  }

  final shapes = StringBuffer();
  if (isCover) {
    shapes
      ..write(
        box(
          838200,
          2286000,
          10515600,
          1371600,
          para(slide.title, size: 4400, bold: true, color: 'FFFFFF'),
          anchor: 'b',
        ),
      )
      ..write(
        box(
          838200,
          3810000,
          10515600,
          1143000,
          para(slide.subtitle, size: 2200, color: 'DBEAFE'),
        ),
      );
  } else {
    shapes
      ..write(
        box(
          685800,
          457200,
          10820400,
          914400,
          para(slide.title, size: 3200, bold: true, color: '1F3A5F'),
          anchor: 'b',
        ),
      )
      ..write(
        '<p:cxnSp><p:nvCxnSpPr><p:cNvPr id="${shapeId++}" name="Rule"/><p:cNvCxnSpPr/><p:nvPr/></p:nvCxnSpPr>'
        '<p:spPr><a:xfrm><a:off x="685800" y="1417320"/><a:ext cx="1371600" cy="0"/></a:xfrm><a:prstGeom prst="line"><a:avLst/></a:prstGeom>'
        '<a:ln w="38100"><a:solidFill><a:srgbClr val="2563EB"/></a:solidFill></a:ln></p:spPr></p:cxnSp>',
      );
    final body = [
      if (slide.subtitle.isNotEmpty)
        para(slide.subtitle, size: 2000, color: '4B5563'),
      for (final b in slide.bullets)
        para(
          b.text,
          size: b.level == 0 ? 2000 : 1700,
          color: '1F2937',
          level: b.level,
          bullet: true,
        ),
    ];
    shapes.write(
      box(
        685800,
        1645920,
        10820400,
        4572000,
        body.isEmpty ? para('', size: 2000) : body.join(),
      ),
    );
  }
  final background = isCover
      ? '<p:bg><p:bgPr><a:solidFill><a:srgbClr val="1F3A5F"/></a:solidFill><a:effectLst/></p:bgPr></p:bg>'
      : '';
  return '$_xmlHeader<p:sld $_pptNs><p:cSld>$background'
      '<p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
      '<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>'
      '$shapes</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>';
}

const _theme =
    '$_xmlHeader<a:theme xmlns:a="$_drawingNs" name="luma"><a:themeElements>'
    '<a:clrScheme name="luma"><a:dk1><a:srgbClr val="1F2937"/></a:dk1><a:lt1><a:srgbClr val="FFFFFF"/></a:lt1>'
    '<a:dk2><a:srgbClr val="1F3A5F"/></a:dk2><a:lt2><a:srgbClr val="EEF2F7"/></a:lt2>'
    '<a:accent1><a:srgbClr val="2563EB"/></a:accent1><a:accent2><a:srgbClr val="0EA5E9"/></a:accent2>'
    '<a:accent3><a:srgbClr val="10B981"/></a:accent3><a:accent4><a:srgbClr val="F59E0B"/></a:accent4>'
    '<a:accent5><a:srgbClr val="EF4444"/></a:accent5><a:accent6><a:srgbClr val="8B5CF6"/></a:accent6>'
    '<a:hlink><a:srgbClr val="2563EB"/></a:hlink><a:folHlink><a:srgbClr val="7C3AED"/></a:folHlink></a:clrScheme>'
    '<a:fontScheme name="luma"><a:majorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>'
    '<a:minorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont></a:fontScheme>'
    '<a:fmtScheme name="luma"><a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill>'
    '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst>'
    '<a:lnStyleLst><a:ln w="6350"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>'
    '<a:ln w="12700"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>'
    '<a:ln w="19050"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst>'
    '<a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle>'
    '<a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst>'
    '<a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill>'
    '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst></a:fmtScheme>'
    '</a:themeElements></a:theme>';

// --------------------------------------------------------------- Excel

const _sNs = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';

Map<String, String> _xlsxParts(OfficeDocument document) {
  final sheets = document.sheets.isEmpty
      ? [OfficeSheet('Sheet1')]
      : document.sheets;
  const sml = 'application/vnd.openxmlformats-officedocument.spreadsheetml';
  final parts = <String, String>{
    '[Content_Types].xml': _contentTypes({
      'xl/workbook.xml': '$sml.sheet.main+xml',
      'xl/styles.xml': '$sml.styles+xml',
      for (var i = 1; i <= sheets.length; i++)
        'xl/worksheets/sheet$i.xml': '$sml.worksheet+xml',
    }),
    '_rels/.rels': _rootRels('xl/workbook.xml'),
    'xl/_rels/workbook.xml.rels': _rels([
      for (var i = 1; i <= sheets.length; i++)
        ('rId$i', '$_officeRel/worksheet', 'worksheets/sheet$i.xml'),
      ('rId${sheets.length + 1}', '$_officeRel/styles', 'styles.xml'),
    ]),
    'xl/workbook.xml':
        '$_xmlHeader<workbook xmlns="$_sNs" xmlns:r="$_officeRel"><sheets>'
        '${[for (final (i, s) in sheets.indexed) '<sheet name="${_esc(s.name)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}'
        '</sheets><calcPr calcId="191029" fullCalcOnLoad="1"/></workbook>',
    'xl/styles.xml':
        '$_xmlHeader<styleSheet xmlns="$_sNs">'
        '<fonts count="2"><font><sz val="11"/><name val="Calibri"/><family val="2"/></font>'
        '<font><b/><sz val="11"/><color rgb="FF1F3A5F"/><name val="Calibri"/><family val="2"/></font></fonts>'
        '<fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill>'
        '<fill><patternFill patternType="solid"><fgColor rgb="FFE7EEF8"/><bgColor indexed="64"/></patternFill></fill></fills>'
        '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
        '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
        '<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
        '<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/></cellXfs>'
        '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
        '</styleSheet>',
  };
  for (final (i, sheet) in sheets.indexed) {
    parts['xl/worksheets/sheet${i + 1}.xml'] = _sheetXml(sheet);
  }
  return parts;
}

/// Whether the first row reads as column headers: all text, more rows below.
bool sheetHasHeaderRow(OfficeSheet sheet) =>
    sheet.rows.length > 1 &&
    sheet.rows.first.isNotEmpty &&
    sheet.rows.first.every(
      (v) => v.isNotEmpty && parseSheetNumber(v) == null && !v.startsWith('='),
    );

String _sheetXml(OfficeSheet sheet) {
  final header = sheetHasHeaderRow(sheet);
  final columns = sheet.columnCount;
  final cols = [
    for (var c = 0; c < columns; c++)
      () {
        var widest = 6;
        for (final row in sheet.rows.take(300)) {
          if (c < row.length) {
            widest = math.max(widest, displayCellValue(sheet, row[c]).length);
          }
        }
        return '<col min="${c + 1}" max="${c + 1}" width="${math.min(60, widest + 2)}" customWidth="1"/>';
      }(),
  ].join();
  final rows = StringBuffer();
  for (final (r, row) in sheet.rows.indexed) {
    if (row.every((v) => v.isEmpty)) continue;
    rows.write('<row r="${r + 1}">');
    for (final (c, value) in row.indexed) {
      if (value.isEmpty) continue;
      final ref = cellName(r, c);
      final style = header && r == 0 ? ' s="1"' : '';
      if (value.startsWith('=')) {
        final cached = evaluateSheetFormula(sheet, value);
        rows.write(
          '<c r="$ref"$style><f>${_esc(value.substring(1))}</f>'
          '${cached == null ? '' : '<v>${formatSheetNumber(cached)}</v>'}</c>',
        );
      } else if (parseSheetNumber(value) != null) {
        rows.write('<c r="$ref"$style><v>${value.trim()}</v></c>');
      } else {
        rows.write(
          '<c r="$ref"$style t="inlineStr"><is><t xml:space="preserve">${_esc(value)}</t></is></c>',
        );
      }
    }
    rows.write('</row>');
  }
  final pane = header
      ? '<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>'
      : '<sheetViews><sheetView workbookViewId="0"/></sheetViews>';
  return '$_xmlHeader<worksheet xmlns="$_sNs" xmlns:r="$_officeRel">$pane'
      '<sheetFormatPr defaultRowHeight="15"/>'
      '${cols.isEmpty ? '' : '<cols>$cols</cols>'}'
      '<sheetData>$rows</sheetData></worksheet>';
}
