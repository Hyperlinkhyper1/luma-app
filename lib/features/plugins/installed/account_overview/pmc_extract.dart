/// Reading a Planet Minecraft profile.
///
/// PMC publishes no API and sits behind Cloudflare, which refuses every
/// non-browser client — a plain HTTP GET from Dart returns 403 no matter what
/// headers it carries. The only thing that gets through is a real browser
/// engine, so the fetch happens in an embedded WebView and this file holds
/// the two halves that can be reasoned about without one: the script that
/// runs inside the page, and the parser for what it returns.
///
/// Keeping them here rather than inside the widget means the parsing is
/// unit-testable against captured markup, which matters for a scraper — the
/// site's HTML will change eventually, and the failure should be a caught,
/// explained "unavailable" rather than a crash.
library;

import 'dart:convert';

import 'mc_models.dart';

/// Extracts a member's submissions and profile counters from the page.
///
/// Written against the live markup: submission cards are
/// `li.resource[data-type="resource"]` carrying `data-id` and `data-subkey`;
/// each has an `a.r-title`, an `abbr[data-timestamp]`, a `.r-stats` block
/// whose `<i title="views|downloads|comments">` precede their `<span>`, and
/// `.c-num-votes` / `.c-num-favs` for diamonds and favourites. The profile
/// side menu carries `a[href*="/member/"] .menu-stat` counters.
///
/// It returns a JSON string rather than an object because the two WebView
/// backends disagree about how rich a value may cross the bridge; a string
/// is the one thing both hand back intact.
const String pmcExtractorScript = r'''
(function () {
  function text(el) { return el ? el.textContent.trim() : null; }
  var cards = Array.prototype.slice.call(
    document.querySelectorAll('li.resource[data-type="resource"], .resource[data-type="resource"]')
  );
  var items = cards.map(function (card) {
    var stats = {};
    Array.prototype.forEach.call(
      card.querySelectorAll('.r-stats i[title]'),
      function (icon) {
        var span = icon.nextElementSibling;
        while (span && span.tagName !== 'SPAN') span = span.nextElementSibling;
        if (span) stats[icon.getAttribute('title')] = span.textContent.trim();
      }
    );
    var link = card.querySelector('a.r-title');
    var when = card.querySelector('abbr[data-timestamp]');
    return {
      id: card.getAttribute('data-id'),
      kind: card.getAttribute('data-subkey'),
      title: text(link),
      url: link ? link.getAttribute('href') : null,
      views: stats.views || null,
      downloads: stats.downloads || null,
      comments: stats.comments || null,
      diamonds: text(card.querySelector('.c-num-votes')),
      favorites: text(card.querySelector('.c-num-favs')),
      updated: when ? when.getAttribute('data-timestamp') : null
    };
  });

  var menu = {};
  Array.prototype.forEach.call(
    document.querySelectorAll('a[href*="/member/"]'),
    function (a) {
      var stat = a.querySelector('.menu-stat');
      if (!stat) return;
      var m = a.getAttribute('href').match(/\/member\/[^\/]+\/([a-z]+)/);
      if (m) menu[m[1]] = stat.textContent.trim();
    }
  );

  var blocked = /just a moment|attention required|cf-browser-verification/i
    .test(document.title + ' ' + (document.body ? document.body.innerText.slice(0, 400) : ''));

  return JSON.stringify({
    items: items,
    menu: menu,
    blocked: blocked,
    hasMore: !!document.querySelector('.pagination a[rel="next"], a.pagination_next')
  });
})();
''';

/// One page of a member's submissions, as parsed from [pmcExtractorScript].
class PmcPage {
  const PmcPage({
    required this.projects,
    required this.menuCounts,
    required this.hasMore,
    required this.blocked,
  });

  final List<McProject> projects;

  /// Side-menu counters keyed by their URL segment: `subscribers`,
  /// `submissions`, `favorites`, …
  final Map<String, int> menuCounts;
  final bool hasMore;

  /// True when Cloudflare served an interstitial instead of the profile.
  final bool blocked;

  static const empty =
      PmcPage(projects: [], menuCounts: {}, hasMore: false, blocked: false);
}

/// Turns the extractor's JSON into projects.
///
/// Throws nothing: a shape that no longer matches yields an empty page, which
/// the repository reports as "unavailable" rather than as a crash.
PmcPage parsePmcPayload(String? raw, {String? memberName}) {
  if (raw == null || raw.trim().isEmpty) return PmcPage.empty;

  Object? decoded;
  try {
    decoded = jsonDecode(raw);
    // Some WebView bridges hand back a JSON string that itself contains the
    // JSON, so one extra unwrap is worth trying before giving up.
    if (decoded is String) decoded = jsonDecode(decoded);
  } catch (_) {
    return PmcPage.empty;
  }
  if (decoded is! Map<String, dynamic>) return PmcPage.empty;

  final blocked = decoded['blocked'] as bool? ?? false;
  final projects = <McProject>[];

  // Checked rather than cast: if PMC's markup shifts under the extractor,
  // `items` can come back as something that is not a list at all, and a cast
  // would throw straight past this function's promise not to.
  final items = decoded['items'];
  for (final entry in (items is List ? items : const [])) {
    if (entry is! Map) continue;
    final id = entry['id']?.toString();
    final title = entry['title'] as String?;
    if (id == null || id.isEmpty || title == null || title.isEmpty) continue;

    final viewsRaw = entry['views'] as String?;
    final downloadsRaw = entry['downloads'] as String?;
    final path = entry['url'] as String?;

    final timestamp = int.tryParse(entry['updated']?.toString() ?? '');

    projects.add(McProject(
      platform: McPlatform.planetMinecraft,
      id: id,
      slug: _slugFromPath(path) ?? id,
      name: title,
      url: path == null
          ? 'https://www.planetminecraft.com/member/${memberName ?? ''}/'
          : 'https://www.planetminecraft.com$path',
      kind: _prettyKind(entry['kind'] as String?),
      downloads: parseCompactCount(downloadsRaw) ?? 0,
      followers: parseCompactCount(entry['diamonds'] as String?) ?? 0,
      views: parseCompactCount(viewsRaw) ?? 0,
      favourites: parseCompactCount(entry['favorites'] as String?) ?? 0,
      comments: parseCompactCount(entry['comments'] as String?) ?? 0,
      updatedAt: timestamp == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(timestamp),
      // PMC abbreviates anything past a thousand on listing pages, so a
      // project's headline figures may be rounded even though its diamonds
      // and favourites are exact.
      approximate: isCompactCount(viewsRaw) || isCompactCount(downloadsRaw),
    ));
  }

  final menu = <String, int>{};
  final rawMenu = decoded['menu'];
  if (rawMenu is Map) {
    for (final entry in rawMenu.entries) {
      final value = parseCompactCount(entry.value?.toString());
      if (value != null) menu[entry.key.toString()] = value;
    }
  }

  return PmcPage(
    projects: projects,
    menuCounts: menu,
    hasMore: decoded['hasMore'] as bool? ?? false,
    blocked: blocked,
  );
}

/// `/skin/official-cyprezz/` -> `official-cyprezz`.
String? _slugFromPath(String? path) {
  if (path == null) return null;
  final parts = path.split('/').where((p) => p.isNotEmpty).toList();
  return parts.isEmpty ? null : parts.last;
}

/// PMC's `data-subkey` is plural and lowercase (`skins`, `mods`); this is the
/// singular form the cards show.
String _prettyKind(String? subkey) {
  if (subkey == null || subkey.isEmpty) return 'submission';
  final singular =
      subkey.endsWith('s') ? subkey.substring(0, subkey.length - 1) : subkey;
  return switch (singular) {
    'mod' => 'mod',
    'skin' => 'skin',
    'project' => 'project',
    'texture_pack' || 'texture-pack' => 'resource pack',
    'data_pack' || 'data-pack' => 'data pack',
    'blog' => 'blog',
    'server' => 'server',
    'collection' => 'collection',
    _ => singular.replaceAll('_', ' '),
  };
}

/// The member pages luma reads, in order.
///
/// Capped deliberately: each page is a full browser navigation, and four of
/// them covers a hundred submissions, which is more than almost any member
/// has. Going deeper would turn a refresh into a minute of hidden browsing.
List<String> pmcPagesFor(String member, {int maxPages = 4}) => [
      for (var page = 1; page <= maxPages; page++)
        page == 1
            ? 'https://www.planetminecraft.com/member/$member/submissions/'
            : 'https://www.planetminecraft.com/member/$member/submissions/?p=$page',
    ];
