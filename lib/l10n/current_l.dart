import 'dart:ui';

import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app_localizations.dart';

/// The app's strings in the language picked in settings, for code that has
/// no [BuildContext]: repositories, services, notifications, enum labels.
/// Widgets should keep using `L.of(context)` so they rebuild on a change.
L get currentL => lookupL(currentLocale);

Locale? _picked;
var _dateSymbolsLoaded = false;

/// Called by the app root whenever the settings language changes. `null`
/// follows the operating system, like `MaterialApp.locale` does. Also points
/// intl's default locale there, so a `DateFormat` or `NumberFormat` built
/// without one names months and days in the same language.
void setCurrentLocale(Locale? locale) {
  _picked = locale;
  if (!_dateSymbolsLoaded) {
    _dateSymbolsLoaded = true;
    initializeDateFormatting();
  }
  Intl.defaultLocale = currentLocale.languageCode;
}

/// The locale [currentL] resolves to: the picked one, else the OS locale
/// when luma speaks it, else English.
Locale get currentLocale {
  final wanted = _picked ?? PlatformDispatcher.instance.locale;
  for (final supported in L.supportedLocales) {
    if (supported.languageCode == wanted.languageCode) return supported;
  }
  return const Locale('en');
}
