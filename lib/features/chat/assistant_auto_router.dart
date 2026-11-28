import 'dart:convert';

import 'assistant_compose_mode.dart';
import 'assistant_file_policy.dart';
import 'providers/ai_modes.dart';
import 'providers/ai_providers.dart';

/// The Luma AI "mode" stored in `SettingsController.aiMode` when the user
/// picks Luma Auto. It is not an [AiMode]: every place that reads the
/// setting as one falls back to Aurora, and the chat controller swaps it
/// for a real mode per message through [routeAutoRequest].
const kAutoAiMode = 'auto';

/// Counts Auto's messages for the model picker, next to the routed mode's
/// own count. Not in `kModelUsageEntries`, so usage totals don't double it.
const kAutoModelUsageKey = 'google:auto';

bool isAutoAiMode(String providerId, String aiMode) =>
    providerId == AiProviderId.google.name && aiMode == kAutoAiMode;

/// What kind of request Luma Auto took a message for.
enum AutoRouteKind {
  /// Small talk and short factual questions: the cheapest model.
  quick,

  /// Explanations, rewrites, summaries: the middle model.
  standard,

  /// Code, maths, analysis and long inputs: the strongest chat model.
  hard,

  /// A question that asks to be researched: deep research on the strongest
  /// model that can run it.
  research,

  /// A file to create: the file is requested directly.
  file,

  /// A new picture to draw.
  picture,

  /// An attached or earlier picture to change: the Pro picture model when
  /// the plan has it.
  pictureEdit,
}

/// Everything besides the message text that decides a route.
class AutoRouteContext {
  const AutoRouteContext({
    required this.planId,
    this.pictureAvailable = false,
    this.pictureProAvailable = false,
    this.imageAttachments = 0,
    this.textAttachments = 0,
    this.lastReplyWasPicture = false,
  });

  final String? planId;

  /// Whether this plan can draw with the standard / Pro picture model.
  final bool pictureAvailable;
  final bool pictureProAvailable;

  final int imageAttachments;
  final int textAttachments;

  /// The conversation's newest reply is a picture, so "now make it night"
  /// is a change to that picture.
  final bool lastReplyWasPicture;

  bool get filesAllowed => assistantFilesAllowed(planId);
}

/// Where Luma Auto sends one message.
class AutoRoute {
  const AutoRoute({
    required this.kind,
    required this.chatMode,
    this.composeMode = AssistantComposeMode.chat,
    this.pictureTier,
    this.artifactType,
  });

  final AutoRouteKind kind;

  /// The Luma AI mode the turn runs on. Picture turns are charged against
  /// it too.
  final AiMode chatMode;
  final AssistantComposeMode composeMode;

  /// `standard` or `pro` for picture turns.
  final String? pictureTier;

  /// The file type to create, for [AutoRouteKind.file].
  final String? artifactType;
}

/// Tags a reply with Luma Auto's pick, so the transcript can say which model
/// answered. Left alone when Auto wasn't selected.
String? chatMetadataWithAutoRoute(String? metadataJson, AutoRoute? route) {
  if (route == null) return metadataJson;
  return jsonEncode({
    ..._decode(metadataJson),
    'auto': {
      'kind': route.kind.name,
      'mode': route.chatMode.name,
      'tier': ?route.pictureTier,
    },
  });
}

/// What [chatMetadataWithAutoRoute] stored, if anything.
({AutoRouteKind kind, AiMode mode, String? tier})? chatAutoRouteOf(
  String? metadataJson,
) {
  final auto = _decode(metadataJson)['auto'];
  if (auto is! Map) return null;
  final kind = AutoRouteKind.values.asNameMap()[auto['kind']];
  final mode = AiMode.values.asNameMap()[auto['mode']];
  if (kind == null || mode == null) return null;
  final tier = auto['tier'];
  return (kind: kind, mode: mode, tier: tier is String ? tier : null);
}

/// The model that answered an Auto turn, as the model picker names it.
/// Brand names, so not localized.
String autoRouteModelLabel(({AutoRouteKind kind, AiMode mode, String? tier}) r) =>
    switch (r.kind) {
      AutoRouteKind.picture || AutoRouteKind.pictureEdit =>
        r.tier == 'pro' ? 'Luma Picture Pro' : 'Luma Picture',
      _ => 'Luma ${r.mode.baseName}',
    };

Map<String, dynamic> _decode(String? metadataJson) {
  if (metadataJson == null) return const {};
  try {
    final decoded = jsonDecode(metadataJson);
    if (decoded is Map) return decoded.cast<String, dynamic>();
  } catch (_) {}
  return const {};
}

/// Picks a route for [text] without a model call: instant, free and the
/// same every time. Explicit choices (a + menu mode or a file type picked in
/// the composer) never reach this; they win over Auto.
AutoRoute routeAutoRequest(String text, AutoRouteContext context) {
  final lower = text.toLowerCase().trim();
  final plan = context.planId;
  final strongest = _strongestChatMode(plan);

  final artifactType = context.filesAllowed
      ? detectRequestedFileType(lower)
      : null;
  if (artifactType != null) {
    return AutoRoute(
      kind: AutoRouteKind.file,
      chatMode: _atMost(AiMode.smarter, plan),
      artifactType: artifactType,
    );
  }

  if (context.pictureAvailable || context.pictureProAvailable) {
    if (_asksToEditPicture(lower, context)) {
      return AutoRoute(
        kind: AutoRouteKind.pictureEdit,
        chatMode: AiMode.normal,
        composeMode: AssistantComposeMode.picture,
        pictureTier: context.pictureProAvailable ? 'pro' : 'standard',
      );
    }
    if (_asksForNewPicture(lower)) {
      final pro =
          context.pictureProAvailable &&
          (!context.pictureAvailable || _wantsDetailedPicture(lower));
      return AutoRoute(
        kind: AutoRouteKind.picture,
        chatMode: AiMode.normal,
        composeMode: AssistantComposeMode.picture,
        pictureTier: pro ? 'pro' : 'standard',
      );
    }
  }

  if (_research.hasMatch(lower)) {
    if (composeModesUnlocked(plan) &&
        deepResearchAvailable(AiProviderId.google.name, strongest.name)) {
      return AutoRoute(
        kind: AutoRouteKind.research,
        chatMode: strongest,
        composeMode: AssistantComposeMode.deepResearch,
      );
    }
    return AutoRoute(kind: AutoRouteKind.hard, chatMode: strongest);
  }

  if (text.length > 600 ||
      context.textAttachments > 0 ||
      _hard.hasMatch(lower)) {
    return AutoRoute(kind: AutoRouteKind.hard, chatMode: strongest);
  }

  if (text.length > 220 ||
      context.imageAttachments > 0 ||
      _standard.hasMatch(lower)) {
    return AutoRoute(
      kind: AutoRouteKind.standard,
      chatMode: _atMost(AiMode.smarter, plan),
    );
  }

  return const AutoRoute(kind: AutoRouteKind.quick, chatMode: AiMode.normal);
}

/// The file type a message asks to have created, or null. Needs both a
/// format and a sign that the format is what should come out ("make a pdf",
/// "export it as csv", "a json file with…"), so "summarise this pdf" or
/// "answer in markdown" stay a chat.
String? detectRequestedFileType(String lower) {
  // An explicit output format wins over mentions of the input file.
  for (final format in _fileFormats) {
    if (format.outputPattern?.hasMatch(lower) ?? false) return format.type;
  }
  for (final format in _fileFormats) {
    if (format.pattern.hasMatch(lower)) return format.type;
  }
  return null;
}

/// Unicode-aware word boundaries. Dart's `\b` only counts ASCII letters, so
/// it would never match "écris" or "détaillé".
const _start = r'(?<![\p{L}\p{N}_])';
const _end = r'(?![\p{L}\p{N}_])';

/// Matches any of [words] as whole words, or any of [cjk] anywhere (those
/// languages don't separate words with spaces).
RegExp _anyOf(List<String> words, [List<String> cjk = const []]) => RegExp(
  [
    '$_start(?:${words.join('|')})$_end',
    ...cjk,
  ].join('|'),
  unicode: true,
);

class _FileFormat {
  _FileFormat(
    this.type,
    String names, {
    bool afterPreposition = true,
    bool matchFileMention = true,
  }) : outputPattern = afterPreposition
           ? RegExp(
               '$_start(?:as|to|into|als|naar|como|para|en)\\s+(?:a|an|een|un|une|una)?\\s*\\.?(?:$names)$_end',
               unicode: true,
             )
           : null,
       pattern = RegExp(
         [
           if (matchFileMention) ...[
             '$_start(?:$names)[\\s-]+(?:file|document|bestand|fichier|archivo|documento|download)$_end',
             '(?:$names)\\s*(?:文件|文档)',
           ],
           '$_start(?:$_createVerbs)\\s+(?:\\S+\\s+){0,3}?\\.?(?:$names)$_end',
           '(?:$_cjkCreateVerbs).{0,6}(?:$names)',
         ].join('|'),
         unicode: true,
       );

  final String type;
  final RegExp? outputPattern;
  final RegExp pattern;
}

/// File types Auto can request, most specific first. Markdown and plain
/// text skip the "as …" form: "answer as markdown" is about formatting the
/// reply, not about a file.
final _fileFormats = [
  _FileFormat('pdf', 'pdf'),
  _FileFormat(
    'docx',
    'docx|microsoft\\s+word|word[\\s-]*(?:document|doc|file|bestand|fichier)|'
        'document\\s+word|documento\\s+word',
    matchFileMention: false,
  ),
  _FileFormat('pptx', 'pptx|powerpoint', matchFileMention: false),
  _FileFormat('xlsx', 'xlsx|excel', matchFileMention: false),
  _FileFormat('csv', 'csv|spreadsheet|rekenblad|tableur|hoja de cálculo'),
  _FileFormat('json', 'json'),
  _FileFormat('svg', 'svg|vector\\s+(?:image|graphic|logo|icon|illustration)'),
  _FileFormat(
    'html',
    'html|web\\s?page|webpagina|landing\\s+page|page web|página web',
  ),
  _FileFormat('md', 'markdown|\\.md', afterPreposition: false),
  _FileFormat(
    'txt',
    'txt|text\\s+file|tekstbestand|fichier texte|archivo de texto',
    afterPreposition: false,
  ),
];

const _createVerbs =
    'create|make|generate|build|export|save|produce|give me|turn (?:this|it) into|convert (?:this|it) (?:to|into)'
    '|maak|genereer|exporteer|bouw|zet (?:dit|het) om in'
    '|crée|créer|génère|générer|exporte|fais'
    '|crea|crear|genera|generar|exporta|haz';

const _cjkCreateVerbs = '生成|创建|导出|做一个|做个';

bool _asksToEditPicture(String lower, AutoRouteContext context) {
  final attached = context.imageAttachments > 0;
  // A follow-up to an earlier picture is short ("now make it night"); a
  // long message after one is usually a new topic.
  final followUp = context.lastReplyWasPicture && lower.length <= 160;
  if (!attached && !followUp) return false;
  if (_questionAboutPicture.hasMatch(lower)) return false;
  return _editVerbs.hasMatch(lower);
}

final _editVerbs = _anyOf(
  [
    'edit',
    'change',
    r'make (?:it|this|him|her|them|the)',
    r'turn (?:it|this|him|her|them) into',
    'remove',
    'erase',
    'add',
    'replace',
    r'recolou?r',
    r'colou?r (?:it|the)',
    'swap',
    r'put (?:a|an|the|some)',
    r'give (?:it|him|her|them)',
    'retouch',
    'crop',
    'extend',
    'enhance',
    'brighten',
    'darken',
    'blur',
    r'now (?:make|with|in|as)',
    'instead',
    r'but (?:with|in|as)',
    'bewerk',
    'verander',
    r'maak (?:het|hem|haar|dit|de|er)',
    'verwijder',
    'vervang',
    r'voeg\s.*\stoe',
    'kleur',
    'modifie',
    'retouche',
    'enlève',
    'supprime',
    'remplace',
    'ajoute',
    'rends',
    'edita',
    'cambia',
    'quita',
    'elimina',
    'reemplaza',
    'añade',
    'agrega',
    'hazlo',
    'ponle',
  ],
  ['修改', '编辑', '换成', '去掉', '加上', '改成'],
);

/// "What is in this picture?" is a question for the chat model even when a
/// picture is attached.
final _questionAboutPicture = RegExp(
  '^$_start(?:what|who|where|when|which|why|how|is|are|does|do|can you (?:tell|describe|explain|read)|describe|explain|identify'
  '|wat|wie|waar|welke|waarom|hoe|beschrijf'
  "|qu'est|qui|où|pourquoi|comment|décris"
  '|qué|quién|dónde|por qué|cómo)$_end'
  '|^(?:这|什么|谁)',
  unicode: true,
);

final _drawVerbs = _anyOf(
  [
    'draw',
    'paint',
    'sketch',
    'illustrate',
    'doodle',
    'teken',
    'schilder',
    'dessine',
    'peins',
    'dibuja',
    'pinta',
  ],
  ['画'],
);

final _pictureRequest = RegExp(
  '$_start(?:generate|create|make|design|render|produce|give me|show me|maak|genereer|ontwerp|crée|génère|fais|crea|genera|diseña|haz)$_end'
  r'(?:\s+\S+){0,5}?\s+'
  '(?:image|picture|photo|pic|illustration|drawing|painting|logo|wallpaper|icon|poster|artwork|portrait|banner|thumbnail|avatar|meme'
  '|afbeelding|plaatje|foto|tekening|achtergrond|dessin|imagen|dibujo|ilustración|cartel)s?$_end'
  '|(?:生成|创建|做).{0,8}(?:图片|图像|照片|插画|头像|海报)',
  unicode: true,
);

bool _asksForNewPicture(String lower) =>
    _drawVerbs.hasMatch(lower) || _pictureRequest.hasMatch(lower);

/// Photorealism, fine detail, lettering or a long brief are where the Pro
/// picture model earns its price; a quick doodle goes to the cheaper one.
bool _wantsDetailedPicture(String lower) =>
    lower.length > 280 || _detailedPicture.hasMatch(lower);

final _detailedPicture = _anyOf(
  [
    r'photo-?realistic',
    'realistic',
    r'hyper-?realistic',
    'detailed',
    'intricate',
    '4k',
    '8k',
    r'high[- ]res(?:olution)?',
    'cinematic',
    'professional',
    'studio',
    'product shot',
    'infographic',
    'poster',
    r'with the (?:text|words)',
    'that says',
    'lettering',
    'typography',
    'fotorealistisch',
    'realistisch',
    'gedetailleerd',
    'professioneel',
    'réaliste',
    'détaillé',
    'professionnel',
    'realista',
    'detallado',
    'profesional',
  ],
  ['写实', '逼真', '高清', '精细'],
);

final _research = _anyOf(
  [
    'research',
    r'deep[ -]dive',
    r'in[ -]depth',
    r'thorough(?:ly)? (?:look|analysis|overview|investigation|research)',
    r'comprehensive (?:overview|analysis|report|guide|comparison)',
    'literature review',
    'state of the art',
    r'market (?:analysis|research)',
    'investigate',
    'look into',
    'find out everything',
    'onderzoek',
    'diepgaand',
    'uitgebreid overzicht',
    'recherche',
    'approfondie?',
    'enquête sur',
    'investiga',
    'investigación',
    'análisis exhaustivo',
    'a fondo',
  ],
  ['研究', '调研', '深入', '全面分析'],
);

final _hard = RegExp(
  [
    '```',
    _anyOf([
      'code',
      'function',
      'class',
      'method',
      'bug',
      'exception',
      r'stack ?trace',
      'compile',
      'regex',
      'sql',
      'algorithm',
      'implement',
      'refactor',
      'debug',
      'python',
      'javascript',
      'typescript',
      'dart',
      'flutter',
      'java',
      'kotlin',
      'swift',
      'rust',
      'golang',
      r'c\+\+',
      'c#',
      'prove',
      'proof',
      'derive',
      'derivative',
      'integral',
      'equation',
      r'optimi[sz]e',
      'probability',
      'theorem',
      'step by step',
      r'analy[sz]e',
      'analysis',
      'pros and cons',
      r'trade-?offs?',
      'critique',
      'strategy',
      'architecture',
      'essay',
      'business plan',
      'bewijs',
      'vergelijking',
      'los op',
      'analyseer',
      'stap voor stap',
      'démontre',
      'équation',
      'résous',
      'analyse',
      'étape par étape',
      'demuestra',
      'ecuación',
      'resuelve',
      'analiza',
      'paso a paso',
    ], ['代码', '函数', '证明', '方程', '分析', '一步一步']).pattern,
  ].join('|'),
  unicode: true,
);

final _standard = RegExp(
  [
    _anyOf([
      'explain',
      r'how (?:do|does|can|to|would|should)',
      'why',
      r'summari[sz]e',
      'summary',
      'translate',
      'rewrite',
      'rephrase',
      'write',
      'draft',
      'compare',
      'difference between',
      'recommend',
      'suggest',
      'calculate',
      'help me',
      'tips',
      'ideas',
      'leg uit',
      'hoe',
      'waarom',
      'vat samen',
      'samenvatting',
      'vertaal',
      'herschrijf',
      'schrijf',
      'vergelijk',
      'verschil tussen',
      'bereken',
      'ideeën',
      'explique',
      'comment',
      'pourquoi',
      'résume',
      'traduis',
      'réécris',
      'écris',
      'compare',
      'calcule',
      'explica',
      'cómo',
      'por qué',
      'resume',
      'traduce',
      'reescribe',
      'escribe',
      'compara',
      'calcula',
    ], ['解释', '怎么', '为什么', '总结', '翻译', '改写', '写']).pattern,
    r'\d+\s*[*/^×÷]\s*\d+',
  ].join('|'),
  unicode: true,
);

/// The strongest Luma AI chat mode this plan has: Pulsar on Nova, Nebula
/// otherwise.
AiMode _strongestChatMode(String? planId) => AiMode.values.lastWhere(
  (mode) => mode.availableForPlan(planId),
  orElse: () => AiMode.normal,
);

AiMode _atMost(AiMode wanted, String? planId) =>
    wanted.availableForPlan(planId) ? wanted : AiMode.normal;
