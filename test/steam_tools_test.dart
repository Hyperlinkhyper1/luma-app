import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/steam_tools/data/steam_database.dart';
import 'package:luma/features/plugins/installed/steam_tools/steam_models.dart';
import 'package:luma/features/plugins/installed/steam_tools/steam_price_history.dart';
import 'package:luma/features/plugins/installed/steam_tools/steam_repository.dart';
import 'package:luma/features/plugins/installed/steam_tools/steam_requirements.dart';

/// The shape Steam actually serves — a heading, a bare note, then labelled
/// `<li>` rows. Taken from the live `appdetails` response for Cyberpunk 2077.
const _cyberpunkMinimum =
    '<strong>Minimum:</strong><br><ul class="bb_ul">'
    '<li>Requires a 64-bit processor and operating system<br></li>'
    '<li><strong>OS:</strong> 64-bit Windows 10<br></li>'
    '<li><strong>Processor:</strong> Core i7-6700 or Ryzen 5 1600<br></li>'
    '<li><strong>Memory:</strong> 12 GB RAM<br></li>'
    '<li><strong>Storage:</strong> 70 GB available space<br></li>'
    '</ul>';

SteamPricePoint _point(DateTime at, int cents, {int discount = 0}) =>
    SteamPricePoint(
      id: at.microsecondsSinceEpoch,
      appId: 1,
      observedAt: at,
      finalCents: cents,
      initialCents: discount > 0 ? 5999 : cents,
      discountPercent: discount,
      currency: 'USD',
    );

void main() {
  group('requirements parsing', () {
    test('reads labelled specs out of Steam store HTML', () {
      final lines = parseSteamRequirementBlock(_cyberpunkMinimum);

      expect(lines, hasLength(5));
      // The "Minimum:" heading is the block's own name, not a spec.
      expect(lines.first.label, isNull);
      expect(lines.first.value,
          'Requires a 64-bit processor and operating system');
      expect(lines[1], const SteamRequirementLine(label: 'OS', value: '64-bit Windows 10'));
      expect(lines[3].label, 'Memory');
      expect(lines[3].value, '12 GB RAM');
    });

    test('falls back to <br> separated text when there is no list', () {
      final lines = parseSteamRequirementBlock(
        '<strong>Minimum:</strong><br><strong>OS:</strong> Windows 7<br>'
        '<strong>Memory:</strong> 4 GB RAM<br>',
      );

      expect(lines.map((l) => l.label).toList(), ['OS', 'Memory']);
      expect(lines.last.value, '4 GB RAM');
    });

    test('unescapes entities and collapses whitespace', () {
      final lines = parseSteamRequirementBlock(
        '<ul><li><strong>Graphics:</strong> GTX 1060 &amp;   RX 580</li></ul>',
      );

      expect(lines.single.value, 'GTX 1060 & RX 580');
    });

    test('handles the empty list Steam sends for apps with no specs', () {
      // Steam sends `[]` rather than an object when nothing was filled in.
      expect(SteamRequirements.fromJson(const []).isEmpty, isTrue);
      expect(SteamRequirements.fromJson(null).isEmpty, isTrue);
      expect(parseSteamRequirementBlock(''), isEmpty);
    });

    test('survives a round trip through the database column', () {
      final original = SteamRequirements(
        minimum: parseSteamRequirementBlock(_cyberpunkMinimum),
        recommended: const [
          SteamRequirementLine(label: 'Memory', value: '16 GB RAM'),
        ],
      );

      final restored =
          decodeSteamRequirements(encodeSteamRequirements(original));

      expect(restored.minimum, original.minimum);
      expect(restored.recommended, original.recommended);
    });
  });

  group('price parsing', () {
    test('keeps Steam prices as integer minor units', () {
      final price = SteamPrice.fromJson(const {
        'currency': 'EUR',
        'initial': 5999,
        'final': 2999,
        'discount_percent': 50,
      });

      expect(price!.finalCents, 2999);
      expect(price.initialCents, 5999);
      expect(price.onSale, isTrue);
      expect(formatSteamPrice(price.finalCents, price.currency), '€29.99');
    });

    test('a free game has no price block at all', () {
      expect(SteamPrice.fromJson(null), isNull);
      expect(SteamPrice.fromJson(const {}), isNull);
    });

    test('formats an unknown currency by code rather than guessing', () {
      expect(formatSteamPrice(1250, 'ARS'), '12.50 ARS');
    });
  });

  group('library rows', () {
    test('skips entries missing an id or name', () {
      expect(SteamLibraryGame.fromJson(const {'appid': 570}), isNull);
      expect(
        SteamLibraryGame.fromJson(const {'name': 'Dota 2'}),
        isNull,
      );
      final game = SteamLibraryGame.fromJson(
        const {'appid': 570, 'name': 'Dota 2', 'playtime_forever': 90},
      );
      expect(game!.appId, 570);
      expect(game.playtimeLabel, '1.5 h');
    });
  });

  group('price series', () {
    final now = DateTime(2026, 8, 25, 12);

    test('is empty when there is no history at all', () {
      final series = buildSteamPriceSeries([], SteamPriceRange.year, now);

      expect(series.isEmpty, isTrue);
      expect(series.historyFrom, isNull);
      expect(series.coversFullRange, isFalse);
    });

    test('carries the last price before the window across the whole range',
        () {
      // The price last changed two years ago, so a one-month window contains
      // no recorded point at all — the line still has to span it.
      final points = [_point(now.subtract(const Duration(days: 730)), 5999)];

      final series = buildSteamPriceSeries(points, SteamPriceRange.month, now);

      expect(series.samples, hasLength(2));
      expect(series.samples.first.at,
          SteamPriceRange.month.startFrom(now));
      expect(series.samples.first.finalCents, 5999);
      // ...and run all the way to now rather than stopping at the last change.
      expect(series.samples.last.at, now);
      expect(series.samples.last.finalCents, 5999);
      expect(series.isFlat, isTrue);
    });

    test('keeps every change inside the window and extends to now', () {
      final points = [
        _point(now.subtract(const Duration(days: 20)), 5999),
        _point(now.subtract(const Duration(days: 10)), 2999, discount: 50),
        _point(now.subtract(const Duration(days: 3)), 5999),
      ];

      final series = buildSteamPriceSeries(points, SteamPriceRange.month, now);

      expect(series.samples, hasLength(4));
      expect(series.lowestCents, 2999);
      expect(series.highestCents, 5999);
      expect(series.isFlat, isFalse);
      expect(series.samples.last.at, now);
    });

    test('reports whether the line really covers the range asked for', () {
      final points = [_point(now.subtract(const Duration(days: 10)), 5999)];

      final week = buildSteamPriceSeries(points, SteamPriceRange.week, now);
      final fiveYears =
          buildSteamPriceSeries(points, SteamPriceRange.fiveYears, now);

      // Ten days of history spans a one-week window but nowhere near a
      // five-year one, and the chart says so rather than drawing a
      // confident flat line across years it never watched.
      expect(week.coversFullRange, isTrue);
      expect(fiveYears.coversFullRange, isFalse);
      expect(fiveYears.historyFrom, points.first.observedAt);
    });

    test('history shorter than the window is never claimed as full', () {
      final points = [_point(now.subtract(const Duration(days: 5)), 5999)];

      expect(
        buildSteamPriceSeries(points, SteamPriceRange.week, now)
            .coversFullRange,
        isFalse,
      );
    });

    test('a window containing no stored point is still drawn', () {
      // The only observation predates the 1D window, so the line is built
      // purely from the carried price plus the "as of now" point.
      final points = [_point(now.subtract(const Duration(days: 2)), 5999)];
      final series = buildSteamPriceSeries(points, SteamPriceRange.day, now);

      expect(series.samples, hasLength(2));
      expect(series.samples.first.at, SteamPriceRange.day.startFrom(now));
      expect(series.samples.first.finalCents, 5999);
      expect(series.samples.last.at, now);
      expect(series.coversFullRange, isTrue);
    });

    test('takes its currency from the newest observation', () {
      final points = [
        _point(now.subtract(const Duration(days: 2)), 5999),
      ];
      final series = buildSteamPriceSeries(
        points,
        SteamPriceRange.year,
        now,
        fallbackCurrency: 'EUR',
      );

      expect(series.currency, 'USD');
      expect(
        buildSteamPriceSeries([], SteamPriceRange.year, now,
                fallbackCurrency: 'EUR')
            .currency,
        'EUR',
      );
    });

    test('ranges are ordered longest first, as the selector shows them', () {
      expect(
        SteamPriceRange.values.map((r) => r.label).toList(),
        ['5Y', '1Y', '6M', '1M', '1W', '1D'],
      );
      expect(
        SteamPriceRange.values.first.span >
            SteamPriceRange.values.last.span,
        isTrue,
      );
    });
  });

  group('app details', () {
    test('flattens genres and categories into one tag list', () {
      final details = SteamAppDetails.fromJson(1091500, const {
        'name': 'Cyberpunk 2077',
        'short_description': 'An open-world RPG.',
        'is_free': false,
        'genres': [
          {'id': '3', 'description': 'RPG'},
        ],
        'categories': [
          {'id': 2, 'description': 'Single-player'},
          // Duplicated across both lists — should appear once.
          {'id': 3, 'description': 'RPG'},
        ],
        'platforms': {'windows': true, 'mac': true, 'linux': false},
        'price_overview': {
          'currency': 'USD',
          'initial': 5999,
          'final': 5999,
          'discount_percent': 0,
        },
        'pc_requirements': {'minimum': _cyberpunkMinimum},
        'release_date': {'coming_soon': false, 'date': 'Dec 9, 2020'},
        'metacritic': {'score': 86},
      });

      expect(details!.tags, ['RPG', 'Single-player']);
      expect(details.price!.finalCents, 5999);
      expect(details.requirements.minimum, hasLength(5));
      expect(details.linux, isFalse);
      expect(details.mac, isTrue);
      expect(details.metacritic, 86);
      expect(details.releaseDate, 'Dec 9, 2020');
    });

    test('header art is addressable from the app id alone', () {
      expect(
        steamHeaderImage(1091500),
        'https://cdn.cloudflare.steamstatic.com/steam/apps/1091500/header.jpg',
      );
    });
  });
}
