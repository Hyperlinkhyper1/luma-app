import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_nl.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L
/// returned by `L.of(context)`.
///
/// Applications need to include `L.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L.localizationsDelegates,
///   supportedLocales: L.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L.supportedLocales
/// property.
abstract class L {
  L(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L of(BuildContext context) {
    return Localizations.of<L>(context, L)!;
  }

  static const LocalizationsDelegate<L> delegate = _LDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('nl'),
    Locale('zh'),
  ];

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navFileConverter.
  ///
  /// In en, this message translates to:
  /// **'File Converter'**
  String get navFileConverter;

  /// No description provided for @navFinance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get navFinance;

  /// No description provided for @navPasswordManager.
  ///
  /// In en, this message translates to:
  /// **'Password Manager'**
  String get navPasswordManager;

  /// No description provided for @navNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get navNotes;

  /// No description provided for @navAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get navAssistant;

  /// No description provided for @navPlugins.
  ///
  /// In en, this message translates to:
  /// **'Plugins'**
  String get navPlugins;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get navAccount;

  /// No description provided for @navConvert.
  ///
  /// In en, this message translates to:
  /// **'Convert'**
  String get navConvert;

  /// No description provided for @navVault.
  ///
  /// In en, this message translates to:
  /// **'Vault'**
  String get navVault;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @shellPluginUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Plugin unavailable'**
  String get shellPluginUnavailable;

  /// No description provided for @shellStorageLimitMsg.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached your storage limit. New data won\'t be saved or synced until you free up space.'**
  String get shellStorageLimitMsg;

  /// No description provided for @shellStorageManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get shellStorageManage;

  /// No description provided for @shellStorageDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get shellStorageDismiss;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsAppearanceSub.
  ///
  /// In en, this message translates to:
  /// **'Make luma feel like yours.'**
  String get settingsAppearanceSub;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsAccentColor.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get settingsAccentColor;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsGeneralSub.
  ///
  /// In en, this message translates to:
  /// **'How the app behaves.'**
  String get settingsGeneralSub;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsOpenOnLaunch.
  ///
  /// In en, this message translates to:
  /// **'Open on launch'**
  String get settingsOpenOnLaunch;

  /// No description provided for @settingsHideAmounts.
  ///
  /// In en, this message translates to:
  /// **'Hide amounts on Home'**
  String get settingsHideAmounts;

  /// No description provided for @settingsHideAmountsSub.
  ///
  /// In en, this message translates to:
  /// **'Mask balances on the dashboard for shoulder-surfers.'**
  String get settingsHideAmountsSub;

  /// No description provided for @settingsLockPasswords.
  ///
  /// In en, this message translates to:
  /// **'Lock Passwords'**
  String get settingsLockPasswords;

  /// No description provided for @settingsLockPasswordsSub.
  ///
  /// In en, this message translates to:
  /// **'Require an 8-digit PIN to view or edit saved credentials.'**
  String get settingsLockPasswordsSub;

  /// No description provided for @settingsAmericanGpa.
  ///
  /// In en, this message translates to:
  /// **'American GPA scale'**
  String get settingsAmericanGpa;

  /// No description provided for @settingsAmericanGpaSub.
  ///
  /// In en, this message translates to:
  /// **'Use the US 4.0 GPA system in the School plugin instead of the Dutch 1-10 grading scale.'**
  String get settingsAmericanGpaSub;

  /// No description provided for @settingsAiAssistant.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get settingsAiAssistant;

  /// No description provided for @settingsAiAssistantSub.
  ///
  /// In en, this message translates to:
  /// **'Connect your own Anthropic API key.'**
  String get settingsAiAssistantSub;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsResetDefaults.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get settingsResetDefaults;

  /// No description provided for @settingsResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset settings?'**
  String get settingsResetTitle;

  /// No description provided for @settingsResetContent.
  ///
  /// In en, this message translates to:
  /// **'This restores the theme, accent color and other preferences to their defaults.'**
  String get settingsResetContent;

  /// No description provided for @settingsResetCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsResetCancel;

  /// No description provided for @settingsResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get settingsResetConfirm;

  /// No description provided for @settingsCheckUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get settingsCheckUpdates;

  /// No description provided for @settingsSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsSystem;

  /// No description provided for @settingsLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsLight;

  /// No description provided for @settingsDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsDark;

  /// No description provided for @langEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @langDutch.
  ///
  /// In en, this message translates to:
  /// **'Nederlands'**
  String get langDutch;

  /// No description provided for @langChinese.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get langChinese;

  /// No description provided for @langSpanish.
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get langSpanish;

  /// No description provided for @langFrench.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get langFrench;

  /// No description provided for @langSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get langSystemDefault;

  /// No description provided for @homeGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get homeGreetingMorning;

  /// No description provided for @homeGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get homeGreetingAfternoon;

  /// No description provided for @homeGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get homeGreetingEvening;

  /// No description provided for @homeNetWorth.
  ///
  /// In en, this message translates to:
  /// **'Net worth'**
  String get homeNetWorth;

  /// No description provided for @homeAtAGlance.
  ///
  /// In en, this message translates to:
  /// **'At a glance'**
  String get homeAtAGlance;

  /// No description provided for @homeJumpBackIn.
  ///
  /// In en, this message translates to:
  /// **'Jump back in'**
  String get homeJumpBackIn;

  /// No description provided for @homeRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get homeRecentActivity;

  /// No description provided for @homeIncomeMonth.
  ///
  /// In en, this message translates to:
  /// **'Income this month'**
  String get homeIncomeMonth;

  /// No description provided for @homeSpentMonth.
  ///
  /// In en, this message translates to:
  /// **'Spent this month'**
  String get homeSpentMonth;

  /// No description provided for @homeInPots.
  ///
  /// In en, this message translates to:
  /// **'In pots'**
  String get homeInPots;

  /// No description provided for @homeInvestments.
  ///
  /// In en, this message translates to:
  /// **'Investments'**
  String get homeInvestments;

  /// No description provided for @homeAskAssistant.
  ///
  /// In en, this message translates to:
  /// **'Ask Assistant'**
  String get homeAskAssistant;

  /// No description provided for @homeAskAssistantSub.
  ///
  /// In en, this message translates to:
  /// **'Chat with the AI assistant'**
  String get homeAskAssistantSub;

  /// No description provided for @homeFinance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get homeFinance;

  /// No description provided for @homeFinanceSub.
  ///
  /// In en, this message translates to:
  /// **'Budgets, pots & stocks'**
  String get homeFinanceSub;

  /// No description provided for @homeFileConverter.
  ///
  /// In en, this message translates to:
  /// **'File Converter'**
  String get homeFileConverter;

  /// No description provided for @homeFileConverterSub.
  ///
  /// In en, this message translates to:
  /// **'Convert images & files'**
  String get homeFileConverterSub;

  /// No description provided for @homeSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get homeSettings;

  /// No description provided for @homeSettingsSub.
  ///
  /// In en, this message translates to:
  /// **'Theme, colors & more'**
  String get homeSettingsSub;

  /// No description provided for @homeNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet — add a transaction in the Finance tab and it will show up here.'**
  String get homeNoTransactions;

  /// No description provided for @homeIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get homeIncome;

  /// No description provided for @homeExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get homeExpense;

  /// No description provided for @homeAllocation.
  ///
  /// In en, this message translates to:
  /// **'Allocation'**
  String get homeAllocation;

  /// No description provided for @homeTabDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get homeTabDashboard;

  /// No description provided for @homeTabStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get homeTabStats;

  /// No description provided for @homeStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Plugin download stats'**
  String get homeStatsTitle;

  /// No description provided for @homeStatsTotalDownloads.
  ///
  /// In en, this message translates to:
  /// **'Total downloads'**
  String get homeStatsTotalDownloads;

  /// No description provided for @homeStatsPluginsInstalled.
  ///
  /// In en, this message translates to:
  /// **'Plugins installed'**
  String get homeStatsPluginsInstalled;

  /// No description provided for @homeStatsPlugin.
  ///
  /// In en, this message translates to:
  /// **'Plugin'**
  String get homeStatsPlugin;

  /// No description provided for @homeStatsDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get homeStatsDownloads;

  /// No description provided for @homeStatsNoPlugins.
  ///
  /// In en, this message translates to:
  /// **'No plugins installed yet. Download a plugin from the Plugins tab to see stats here.'**
  String get homeStatsNoPlugins;

  /// No description provided for @homeStatsBrowsePlugins.
  ///
  /// In en, this message translates to:
  /// **'Browse plugins'**
  String get homeStatsBrowsePlugins;

  /// No description provided for @pinEnterNew.
  ///
  /// In en, this message translates to:
  /// **'Enter new 8-digit PIN'**
  String get pinEnterNew;

  /// No description provided for @pinVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify new PIN'**
  String get pinVerify;

  /// No description provided for @pinEnterDisable.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN to disable'**
  String get pinEnterDisable;

  /// No description provided for @pinNotMatch.
  ///
  /// In en, this message translates to:
  /// **'PINs do not match.'**
  String get pinNotMatch;

  /// No description provided for @pinIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN.'**
  String get pinIncorrect;

  /// No description provided for @aboutVersionRelease.
  ///
  /// In en, this message translates to:
  /// **'Version {version} · a clean local utility'**
  String aboutVersionRelease(String version);

  /// No description provided for @aboutVersionDev.
  ///
  /// In en, this message translates to:
  /// **'Dev build · a clean local utility'**
  String get aboutVersionDev;

  /// No description provided for @monthJan.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get monthJan;

  /// No description provided for @monthFeb.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get monthFeb;

  /// No description provided for @monthMar.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get monthMar;

  /// No description provided for @monthApr.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get monthApr;

  /// No description provided for @monthMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get monthMay;

  /// No description provided for @monthJun.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get monthJun;

  /// No description provided for @monthJul.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get monthJul;

  /// No description provided for @monthAug.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get monthAug;

  /// No description provided for @monthSep.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get monthSep;

  /// No description provided for @monthOct.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get monthOct;

  /// No description provided for @monthNov.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get monthNov;

  /// No description provided for @monthDec.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get monthDec;

  /// No description provided for @weekdayMon.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get weekdaySun;

  /// No description provided for @planSuffix.
  ///
  /// In en, this message translates to:
  /// **'{name} plan'**
  String planSuffix(String name);
}

class _LDelegate extends LocalizationsDelegate<L> {
  const _LDelegate();

  @override
  Future<L> load(Locale locale) {
    return SynchronousFuture<L>(lookupL(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'fr', 'nl', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_LDelegate old) => false;
}

L lookupL(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return LEn();
    case 'es':
      return LEs();
    case 'fr':
      return LFr();
    case 'nl':
      return LNl();
    case 'zh':
      return LZh();
  }

  throw FlutterError(
    'L.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
