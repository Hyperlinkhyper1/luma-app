import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/l10n/current_l.dart';
import 'package:luma/finance/logic/money.dart';
import 'package:luma/features/plugins/installed/_shared/scene_localizations.dart';
import 'package:luma/settings/settings_controller.dart';
import 'package:luma/sync/sync_collections.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/sim/airport_world.dart';

void main() {
  for (final locale in L.supportedLocales.where(
    (locale) => locale.languageCode != 'en',
  )) {
    test(
      '${locale.languageCode} catalog covers every English message and placeholder',
      () {
        Map<String, dynamic> read(String locale) =>
            jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
                as Map<String, dynamic>;

        final english = read('en');
        final dutch = read(locale.languageCode);
        final keys = english.keys.where((key) => !key.startsWith('@')).toSet();
        final dutchKeys = dutch.keys
            .where((key) => !key.startsWith('@'))
            .toSet();
        expect(
          dutchKeys.difference(keys),
          isEmpty,
          reason: 'Orphaned Dutch keys',
        );
        expect(
          keys.difference(dutchKeys),
          isEmpty,
          reason: 'Missing Dutch keys',
        );

        final placeholder = RegExp(r'\{([A-Za-z][A-Za-z0-9_]*)(?=[},])');
        for (final key in keys) {
          final source = (english[key] as String);
          final translation = (dutch[key] as String);
          final metadata = english['@$key'] as Map<String, dynamic>?;
          final declared =
              (metadata?['placeholders'] as Map<String, dynamic>?)?.keys
                  .toSet() ??
              <String>{};
          final sourceNames = placeholder
              .allMatches(source)
              .map((match) => match.group(1))
              .where(declared.contains)
              .toSet();
          final translatedNames = placeholder
              .allMatches(translation)
              .map((match) => match.group(1))
              .where(declared.contains)
              .toSet();
          expect(translatedNames, sourceNames, reason: 'Placeholders in $key');
        }
      },
    );
  }

  test('settings language updates strings outside the widget tree', () {
    addTearDown(() => setCurrentLocale(null));
    for (final language in AppLanguage.values.where(
      (language) => language != AppLanguage.system,
    )) {
      final locale = localeForLanguage(language)!;
      setCurrentLocale(locale);
      expect(currentLocale.languageCode, locale.languageCode);
      expect(currentL.localeName, locale.languageCode);
      expect(currentL.settingsLanguage, lookupL(locale).settingsLanguage);
    }
  });

  test('shared money formatter follows later settings changes', () {
    addTearDown(() => setCurrentLocale(null));
    setCurrentLocale(const Locale('en'));
    expect(formatCents(123456), contains('1,234.56'));
    setCurrentLocale(const Locale('nl'));
    expect(formatCents(123456), contains('1.234,56'));
  });

  test('an initialized sync collection follows later language changes', () {
    final notifier = ChangeNotifier();
    addTearDown(notifier.dispose);
    addTearDown(() => setCurrentLocale(null));
    final collection = JsonStoreSyncCollection(
      id: 'settings',
      labelBuilder: () => currentL.syncCollectionSettings,
      icon: Icons.settings,
      listenable: notifier,
      exporter: () async => null,
      importer: (_) async {},
    );
    for (final locale in L.supportedLocales) {
      setCurrentLocale(locale);
      expect(collection.label, lookupL(locale).syncCollectionSettings);
    }
  });

  test(
    'airport catalog text follows language changes without changing simulation data',
    () {
      addTearDown(() => setCurrentLocale(null));
      final runway = facilityDef('runway');
      final carousel = facilityDef('baggageCarousel');
      for (final locale in L.supportedLocales) {
        setCurrentLocale(locale);
        final t = lookupL(locale);
        expect(runway.name, t.airportFacilityRunwayName);
        expect(runway.blurb, t.airportFacilityRunwayDescription);
        expect(
          carousel.blurb,
          t.airportFacilityBaggageCarouselDescription(carouselCapacity),
        );
        expect(runway.depth, 1800);
        expect(runway.cost, 6000000);
        for (final facility in airportFacilities) {
          expect(facility.name, isNotEmpty);
          expect(facility.blurb, isNotEmpty);
        }
      }
    },
  );

  test('every bundled plugin has translated marketplace text', () {
    final registry =
        jsonDecode(File('plugins/registry.json').readAsStringSync())
            as Map<String, dynamic>;
    final entries = (registry['plugins'] as List).cast<Map<String, dynamic>>();
    for (final entry in entries) {
      final id = entry['id'] as String;
      final manifest =
          jsonDecode(File('plugins/$id/manifest.json').readAsStringSync())
              as Map<String, dynamic>;
      for (final locale in L.supportedLocales.where(
        (locale) => locale.languageCode != 'en',
      )) {
        for (final document in [entry, manifest]) {
          final translations = document['i18n'] as Map<String, dynamic>?;
          final translated =
              translations?[locale.languageCode] as Map<String, dynamic>?;
          for (final field in ['name', 'description', 'details']) {
            if (document[field] is! String ||
                (document[field] as String).isEmpty) {
              continue;
            }
            expect(
              translated?[field],
              isA<String>().having(
                (text) => text.trim(),
                'nonempty',
                isNotEmpty,
              ),
              reason: '$id ${locale.languageCode} $field',
            );
          }
        }
      }
    }
  });

  test('static widget copy uses localization instead of literal prose', () {
    const identifiers = {
      'luma',
      'Planet Minecraft',
      'Aa',
      'MSC Virtuosa',
      'Kinetic Hosting',
      'KINETIC HOSTING',
      'CurseForge',
      'USD',
      'EUR',
      'GBP',
      'Mbps',
    };
    final literal = RegExp(r'''\bText\(\s*(['"])([^\r\n]*?)\1''');
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart') || file.path.endsWith('.g.dart'))
        continue;
      for (final match in literal.allMatches(file.readAsStringSync())) {
        final text = match.group(2)!;
        if (text.contains(r'$') || !RegExp(r'[A-Za-z]{2}').hasMatch(text))
          continue;
        expect(
          identifiers,
          contains(text),
          reason: 'Localize widget copy in ${file.path}: $text',
        );
      }
    }
  });

  test('scene payloads preserve template parameters in every language', () {
    const scenes = [
      'airline_tycoon/scene',
      'asset_studio',
      'city_planner',
      'space_colony',
      'subway_builder',
      'text_library/scene',
      'transport_tracker',
    ];
    final english =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    final placeholder = RegExp(r'\{([A-Za-z][A-Za-z0-9_]*)\}');
    for (final locale in L.supportedLocales) {
      final t = lookupL(locale);
      for (final scene in scenes) {
        final strings = sceneKeyStrings(t, scene);
        expect(
          strings,
          isNotEmpty,
          reason: '$scene locale ${locale.languageCode}',
        );
        for (final entry in strings.entries) {
          final parameters = placeholder
              .allMatches(english[entry.key] as String)
              .map((m) => m.group(1))
              .toSet();
          final rendered = placeholder
              .allMatches(entry.value)
              .map((m) => m.group(1))
              .toSet();
          expect(
            rendered,
            parameters,
            reason:
                '${entry.key} template parameters in ${locale.languageCode}',
          );
        }
      }
      expect(
        sceneSourceStrings(t, 'city_planner')['Gras'],
        t.sceneCityPlannerDataGras,
      );
      expect(
        sceneSourceStrings(t, 'space_colony')['Solar Panel'],
        t.sceneSpaceColonyDataSolarPanel,
      );
    }
  });

  test('embedded scene localization keys exist in every language', () {
    final catalogs = {
      for (final locale in L.supportedLocales)
        locale.languageCode:
            jsonDecode(
                  File(
                    'lib/l10n/app_${locale.languageCode}.arb',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>,
    };
    final references = RegExp(
      r'''data-luma-(?:text|title|placeholder|aria)=["']([A-Za-z][A-Za-z0-9_]*)["']|LumaSceneI18n\.(?:value|format)\(["']([A-Za-z][A-Za-z0-9_]*)["'](?=\s*[,\)])|\b(?:sceneValue|sceneFormat|fmt|uiFmt|uiValue)\(\s*["']((?:scene[A-Z]|airportVehicle)[A-Za-z0-9_]*)["'](?=\s*[,\)])''',
    );
    var checked = 0;
    for (final file in Directory(
      'assets',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.html') && !file.path.endsWith('.js')) continue;
      for (final match in references.allMatches(file.readAsStringSync())) {
        final key = match.group(1) ?? match.group(2) ?? match.group(3)!;
        checked++;
        for (final entry in catalogs.entries) {
          expect(
            entry.value[key],
            isA<String>(),
            reason: '${file.path}: $key in ${entry.key}',
          );
        }
      }
    }
    expect(
      checked,
      greaterThan(0),
      reason: 'Scene translations must be connected',
    );
  });
}
