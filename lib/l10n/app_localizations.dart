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

  /// No description provided for @trayOpen.
  ///
  /// In en, this message translates to:
  /// **'Open luma'**
  String get trayOpen;

  /// No description provided for @trayQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit luma'**
  String get trayQuit;

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
  /// **'This plugin isn\'t here'**
  String get shellPluginUnavailable;

  /// No description provided for @shellStorageLimitMsg.
  ///
  /// In en, this message translates to:
  /// **'You\'re out of space. Clear a little out and we\'ll start saving and syncing again.'**
  String get shellStorageLimitMsg;

  /// No description provided for @shellStorageManage.
  ///
  /// In en, this message translates to:
  /// **'Clean up'**
  String get shellStorageManage;

  /// No description provided for @shellStorageDismiss.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get shellStorageDismiss;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Look & feel'**
  String get settingsAppearance;

  /// No description provided for @settingsAppearanceSub.
  ///
  /// In en, this message translates to:
  /// **'Make luma yours.'**
  String get settingsAppearanceSub;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsAccentColor.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get settingsAccentColor;

  /// No description provided for @settingsThemeStyle.
  ///
  /// In en, this message translates to:
  /// **'Theme style'**
  String get settingsThemeStyle;

  /// No description provided for @settingsThemeStyleDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get settingsThemeStyleDefault;

  /// No description provided for @settingsThemeStyleDefaultSub.
  ///
  /// In en, this message translates to:
  /// **'Good old luma — plain and simple, in your colour.'**
  String get settingsThemeStyleDefaultSub;

  /// No description provided for @settingsThemeStyleCoffee.
  ///
  /// In en, this message translates to:
  /// **'Coffee'**
  String get settingsThemeStyleCoffee;

  /// No description provided for @settingsThemeStyleCoffeeSub.
  ///
  /// In en, this message translates to:
  /// **'Warm browns, soft corners, little coffee beans floating around.'**
  String get settingsThemeStyleCoffeeSub;

  /// No description provided for @settingsThemeStyleLocked.
  ///
  /// In en, this message translates to:
  /// **'Orbit or Nova'**
  String get settingsThemeStyleLocked;

  /// No description provided for @settingsThemeStyleUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Coffee comes with Orbit and Nova. Grab one of those to turn it on.'**
  String get settingsThemeStyleUpgrade;

  /// No description provided for @settingsAccentCoffeeNote.
  ///
  /// In en, this message translates to:
  /// **'Coffee has its own colours, so you can\'t pick a colour while it\'s on.'**
  String get settingsAccentCoffeeNote;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsGeneralSub.
  ///
  /// In en, this message translates to:
  /// **'Small things that change how the app acts.'**
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
  /// **'Hide money on Home'**
  String get settingsHideAmounts;

  /// No description provided for @settingsHideAmountsSub.
  ///
  /// In en, this message translates to:
  /// **'Hide your money on Home, in case someone\'s peeking over your shoulder.'**
  String get settingsHideAmountsSub;

  /// No description provided for @settingsLockPasswords.
  ///
  /// In en, this message translates to:
  /// **'Lock passwords'**
  String get settingsLockPasswords;

  /// No description provided for @settingsLockPasswordsSub.
  ///
  /// In en, this message translates to:
  /// **'Ask for an 8-digit PIN before showing your saved logins.'**
  String get settingsLockPasswordsSub;

  /// No description provided for @settingsAmericanGpa.
  ///
  /// In en, this message translates to:
  /// **'American grades'**
  String get settingsAmericanGpa;

  /// No description provided for @settingsAmericanGpaSub.
  ///
  /// In en, this message translates to:
  /// **'Use American 4.0 grades in School instead of Dutch 1-to-10s.'**
  String get settingsAmericanGpaSub;

  /// No description provided for @settingsAiAssistant.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get settingsAiAssistant;

  /// No description provided for @settingsAiAssistantSub.
  ///
  /// In en, this message translates to:
  /// **'Pop in your own Anthropic key to start chatting.'**
  String get settingsAiAssistantSub;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsResetDefaults.
  ///
  /// In en, this message translates to:
  /// **'Put everything back'**
  String get settingsResetDefaults;

  /// No description provided for @settingsResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Start fresh?'**
  String get settingsResetTitle;

  /// No description provided for @settingsResetContent.
  ///
  /// In en, this message translates to:
  /// **'This puts your theme, colour and other little picks back to how they were at the start.'**
  String get settingsResetContent;

  /// No description provided for @settingsResetCancel.
  ///
  /// In en, this message translates to:
  /// **'Keep mine'**
  String get settingsResetCancel;

  /// No description provided for @settingsResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Yep, reset'**
  String get settingsResetConfirm;

  /// No description provided for @settingsCheckUpdates.
  ///
  /// In en, this message translates to:
  /// **'Look for updates'**
  String get settingsCheckUpdates;

  /// No description provided for @settingsOpenSourceLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open source licences'**
  String get settingsOpenSourceLicenses;

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
  /// **'Hey there'**
  String get homeGreetingAfternoon;

  /// No description provided for @homeGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get homeGreetingEvening;

  /// No description provided for @homeNetWorth.
  ///
  /// In en, this message translates to:
  /// **'All together'**
  String get homeNetWorth;

  /// No description provided for @homeAtAGlance.
  ///
  /// In en, this message translates to:
  /// **'How things look'**
  String get homeAtAGlance;

  /// No description provided for @homeJumpBackIn.
  ///
  /// In en, this message translates to:
  /// **'Pick up where you left off'**
  String get homeJumpBackIn;

  /// No description provided for @homeRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'What you\'ve been up to'**
  String get homeRecentActivity;

  /// No description provided for @homeIncomeMonth.
  ///
  /// In en, this message translates to:
  /// **'Came in this month'**
  String get homeIncomeMonth;

  /// No description provided for @homeSpentMonth.
  ///
  /// In en, this message translates to:
  /// **'Went out this month'**
  String get homeSpentMonth;

  /// No description provided for @homeInPots.
  ///
  /// In en, this message translates to:
  /// **'Set aside in pots'**
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
  /// **'Have a chat, ask anything'**
  String get homeAskAssistantSub;

  /// No description provided for @homeFinance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get homeFinance;

  /// No description provided for @homeFinanceSub.
  ///
  /// In en, this message translates to:
  /// **'Your money, pots & stocks'**
  String get homeFinanceSub;

  /// No description provided for @homeFileConverter.
  ///
  /// In en, this message translates to:
  /// **'File Converter'**
  String get homeFileConverter;

  /// No description provided for @homeFileConverterSub.
  ///
  /// In en, this message translates to:
  /// **'Change up images & files'**
  String get homeFileConverterSub;

  /// No description provided for @homeSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get homeSettings;

  /// No description provided for @homeSettingsSub.
  ///
  /// In en, this message translates to:
  /// **'Colours, theme & stuff'**
  String get homeSettingsSub;

  /// No description provided for @homeNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'Quiet here for now — add something in Finance and it\'ll pop up here.'**
  String get homeNoTransactions;

  /// No description provided for @homeIncome.
  ///
  /// In en, this message translates to:
  /// **'In'**
  String get homeIncome;

  /// No description provided for @homeExpense.
  ///
  /// In en, this message translates to:
  /// **'Out'**
  String get homeExpense;

  /// No description provided for @homeAllocation.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get homeAllocation;

  /// No description provided for @homeSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save your home: {error}'**
  String homeSaveFailed(String error);

  /// No description provided for @homeAddSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Make room for what matters'**
  String get homeAddSheetTitle;

  /// No description provided for @homeEditLayout.
  ///
  /// In en, this message translates to:
  /// **'Edit layout'**
  String get homeEditLayout;

  /// No description provided for @homeEditingTitle.
  ///
  /// In en, this message translates to:
  /// **'Make yourself at home'**
  String get homeEditingTitle;

  /// No description provided for @homePhoneLayout.
  ///
  /// In en, this message translates to:
  /// **'Phone layout'**
  String get homePhoneLayout;

  /// No description provided for @homeDesktopLayout.
  ///
  /// In en, this message translates to:
  /// **'Desktop & laptop layout'**
  String get homeDesktopLayout;

  /// No description provided for @homeResetDashboard.
  ///
  /// In en, this message translates to:
  /// **'Reset to original dashboard'**
  String get homeResetDashboard;

  /// No description provided for @homeAddTile.
  ///
  /// In en, this message translates to:
  /// **'Add tile'**
  String get homeAddTile;

  /// No description provided for @homeSaveLayout.
  ///
  /// In en, this message translates to:
  /// **'Save layout'**
  String get homeSaveLayout;

  /// No description provided for @homeEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit home'**
  String get homeEdit;

  /// No description provided for @homeDragHint.
  ///
  /// In en, this message translates to:
  /// **'Drag a tile by its title. Drag its lower corner to resize. Everything snaps into place; overlapping tiles move down.'**
  String get homeDragHint;

  /// No description provided for @homeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get homeUnavailable;

  /// No description provided for @homeInspiration.
  ///
  /// In en, this message translates to:
  /// **'A little inspiration'**
  String get homeInspiration;

  /// No description provided for @homeEditSummary.
  ///
  /// In en, this message translates to:
  /// **'Edit summary'**
  String get homeEditSummary;

  /// No description provided for @homeCashBalance.
  ///
  /// In en, this message translates to:
  /// **'Cash balance'**
  String get homeCashBalance;

  /// No description provided for @homeCustomText.
  ///
  /// In en, this message translates to:
  /// **'Custom text'**
  String get homeCustomText;

  /// No description provided for @homeSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Greeting summary'**
  String get homeSummaryTitle;

  /// No description provided for @homeSummaryDescription.
  ///
  /// In en, this message translates to:
  /// **'Your greeting always stays at the top. Choose what appears beneath it.'**
  String get homeSummaryDescription;

  /// No description provided for @homeShowInGreeting.
  ///
  /// In en, this message translates to:
  /// **'Show in greeting'**
  String get homeShowInGreeting;

  /// No description provided for @homeSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get homeSummaryLabel;

  /// No description provided for @homeSummaryLabelHint.
  ///
  /// In en, this message translates to:
  /// **'Today’s focus'**
  String get homeSummaryLabelHint;

  /// No description provided for @homeSummaryText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get homeSummaryText;

  /// No description provided for @homeSummaryTextHint.
  ///
  /// In en, this message translates to:
  /// **'Make time for what matters.'**
  String get homeSummaryTextHint;

  /// No description provided for @homeApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get homeApply;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @homeTileShortcut.
  ///
  /// In en, this message translates to:
  /// **'App shortcut'**
  String get homeTileShortcut;

  /// No description provided for @homeTileRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get homeTileRecentActivity;

  /// No description provided for @homeTileFinanceOverview.
  ///
  /// In en, this message translates to:
  /// **'Finance overview'**
  String get homeTileFinanceOverview;

  /// No description provided for @homeTilePinnedNote.
  ///
  /// In en, this message translates to:
  /// **'Pinned note'**
  String get homeTilePinnedNote;

  /// No description provided for @homeTilePluginShortcut.
  ///
  /// In en, this message translates to:
  /// **'Plugin shortcut'**
  String get homeTilePluginShortcut;

  /// No description provided for @homeTileMinecraftInstance.
  ///
  /// In en, this message translates to:
  /// **'Minecraft instance'**
  String get homeTileMinecraftInstance;

  /// No description provided for @homeTileErrands.
  ///
  /// In en, this message translates to:
  /// **'Errands'**
  String get homeTileErrands;

  /// No description provided for @homeTileStockChart.
  ///
  /// In en, this message translates to:
  /// **'Stock chart'**
  String get homeTileStockChart;

  /// No description provided for @homeTileGithubActivity.
  ///
  /// In en, this message translates to:
  /// **'GitHub activity'**
  String get homeTileGithubActivity;

  /// No description provided for @homeTileGithubIssues.
  ///
  /// In en, this message translates to:
  /// **'GitHub issues'**
  String get homeTileGithubIssues;

  /// No description provided for @homeTileAiUsage.
  ///
  /// In en, this message translates to:
  /// **'AI usage'**
  String get homeTileAiUsage;

  /// No description provided for @homeTileCalculator.
  ///
  /// In en, this message translates to:
  /// **'Calculator'**
  String get homeTileCalculator;

  /// No description provided for @homeTileClockDate.
  ///
  /// In en, this message translates to:
  /// **'Clock & date'**
  String get homeTileClockDate;

  /// No description provided for @homeTileFocusTimer.
  ///
  /// In en, this message translates to:
  /// **'Focus timer'**
  String get homeTileFocusTimer;

  /// No description provided for @homeTileQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get homeTileQuickActions;

  /// No description provided for @pinEnterNew.
  ///
  /// In en, this message translates to:
  /// **'Pick a new 8-digit PIN'**
  String get pinEnterNew;

  /// No description provided for @pinVerify.
  ///
  /// In en, this message translates to:
  /// **'Type it once more'**
  String get pinVerify;

  /// No description provided for @pinEnterDisable.
  ///
  /// In en, this message translates to:
  /// **'Type your PIN to turn it off'**
  String get pinEnterDisable;

  /// No description provided for @pinNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Those PINs don\'t match.'**
  String get pinNotMatch;

  /// No description provided for @pinIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Nope, wrong PIN.'**
  String get pinIncorrect;

  /// No description provided for @aboutVersionRelease.
  ///
  /// In en, this message translates to:
  /// **'Version {version} · a small app that keeps your stuff with you'**
  String aboutVersionRelease(String version);

  /// No description provided for @aboutVersionDev.
  ///
  /// In en, this message translates to:
  /// **'Dev build · made with care on someone\'s laptop'**
  String get aboutVersionDev;

  /// No description provided for @petSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search plugins and pages'**
  String get petSearchHint;

  /// No description provided for @petMoodIdle.
  ///
  /// In en, this message translates to:
  /// **'What are we opening?'**
  String get petMoodIdle;

  /// No description provided for @petMoodCurious.
  ///
  /// In en, this message translates to:
  /// **'Ooh, let me look…'**
  String get petMoodCurious;

  /// No description provided for @petMoodHappy.
  ///
  /// In en, this message translates to:
  /// **'That tickles.'**
  String get petMoodHappy;

  /// No description provided for @petMoodDelighted.
  ///
  /// In en, this message translates to:
  /// **'Best day ever!'**
  String get petMoodDelighted;

  /// No description provided for @petMoodSleepy.
  ///
  /// In en, this message translates to:
  /// **'Still up? Me too.'**
  String get petMoodSleepy;

  /// No description provided for @petNoResults.
  ///
  /// In en, this message translates to:
  /// **'Nothing by that name'**
  String get petNoResults;

  /// No description provided for @petNoResultsHint.
  ///
  /// In en, this message translates to:
  /// **'Try a shorter word, or just part of one.'**
  String get petNoResultsHint;

  /// No description provided for @petSectionJumpTo.
  ///
  /// In en, this message translates to:
  /// **'JUMP TO'**
  String get petSectionJumpTo;

  /// No description provided for @petSectionResults.
  ///
  /// In en, this message translates to:
  /// **'RESULTS'**
  String get petSectionResults;

  /// No description provided for @petKindPlugin.
  ///
  /// In en, this message translates to:
  /// **'Plugin'**
  String get petKindPlugin;

  /// No description provided for @petKindPage.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get petKindPage;

  /// No description provided for @petHintMove.
  ///
  /// In en, this message translates to:
  /// **'move'**
  String get petHintMove;

  /// No description provided for @petHintOpen.
  ///
  /// In en, this message translates to:
  /// **'open'**
  String get petHintOpen;

  /// No description provided for @petHintClose.
  ///
  /// In en, this message translates to:
  /// **'close'**
  String get petHintClose;

  /// No description provided for @petClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get petClose;

  /// No description provided for @petPatsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Pats given'**
  String get petPatsTooltip;

  /// No description provided for @petPatLabel.
  ///
  /// In en, this message translates to:
  /// **'Pat {name}'**
  String petPatLabel(String name);

  /// No description provided for @petSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'luma pet'**
  String get petSettingsTitle;

  /// No description provided for @petSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Press the shortcut anywhere to summon the pet, then type to jump to any page or plugin.'**
  String get petSettingsSubtitle;

  /// No description provided for @petSettingsHotkey.
  ///
  /// In en, this message translates to:
  /// **'Summon from anywhere'**
  String get petSettingsHotkey;

  /// No description provided for @petSettingsHotkeyTaken.
  ///
  /// In en, this message translates to:
  /// **'Another app already owns this shortcut, so it only works while luma is in front. Pick a different one below.'**
  String get petSettingsHotkeyTaken;

  /// No description provided for @petSettingsRebind.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get petSettingsRebind;

  /// No description provided for @petSettingsRebindTitle.
  ///
  /// In en, this message translates to:
  /// **'Press a new shortcut'**
  String get petSettingsRebindTitle;

  /// No description provided for @petSettingsRebindSave.
  ///
  /// In en, this message translates to:
  /// **'Use it'**
  String get petSettingsRebindSave;

  /// No description provided for @petSettingsName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get petSettingsName;

  /// No description provided for @petSettingsSummon.
  ///
  /// In en, this message translates to:
  /// **'Open the pet now'**
  String get petSettingsSummon;

  /// No description provided for @petSettingsSummonHint.
  ///
  /// In en, this message translates to:
  /// **'Brings the panel up straight away — no keyboard shortcut needed.'**
  String get petSettingsSummonHint;

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

  /// No description provided for @assistantNewChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get assistantNewChat;

  /// No description provided for @assistantSearchChats.
  ///
  /// In en, this message translates to:
  /// **'Search chats'**
  String get assistantSearchChats;

  /// No description provided for @assistantStarred.
  ///
  /// In en, this message translates to:
  /// **'Starred'**
  String get assistantStarred;

  /// No description provided for @assistantRecents.
  ///
  /// In en, this message translates to:
  /// **'Recents'**
  String get assistantRecents;

  /// No description provided for @assistantNoChats.
  ///
  /// In en, this message translates to:
  /// **'No chats yet'**
  String get assistantNoChats;

  /// No description provided for @assistantNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No chats match'**
  String get assistantNoMatches;

  /// No description provided for @assistantGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get assistantGreetingMorning;

  /// No description provided for @assistantGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get assistantGreetingAfternoon;

  /// No description provided for @assistantGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get assistantGreetingEvening;

  /// No description provided for @assistantGreetingMorningName.
  ///
  /// In en, this message translates to:
  /// **'Good morning, {name}'**
  String assistantGreetingMorningName(String name);

  /// No description provided for @assistantGreetingAfternoonName.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon, {name}'**
  String assistantGreetingAfternoonName(String name);

  /// No description provided for @assistantGreetingEveningName.
  ///
  /// In en, this message translates to:
  /// **'Good evening, {name}'**
  String assistantGreetingEveningName(String name);

  /// No description provided for @assistantHowCanIHelp.
  ///
  /// In en, this message translates to:
  /// **'How can I help you today?'**
  String get assistantHowCanIHelp;

  /// No description provided for @assistantReplyHint.
  ///
  /// In en, this message translates to:
  /// **'Reply to luma…'**
  String get assistantReplyHint;

  /// No description provided for @assistantOutOfMessages.
  ///
  /// In en, this message translates to:
  /// **'You\'re out of messages for now'**
  String get assistantOutOfMessages;

  /// No description provided for @assistantCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get assistantCopy;

  /// No description provided for @assistantCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get assistantCopied;

  /// No description provided for @assistantStar.
  ///
  /// In en, this message translates to:
  /// **'Star'**
  String get assistantStar;

  /// No description provided for @assistantUnstar.
  ///
  /// In en, this message translates to:
  /// **'Unstar'**
  String get assistantUnstar;

  /// No description provided for @assistantRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get assistantRename;

  /// No description provided for @assistantDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get assistantDelete;

  /// No description provided for @assistantSuggestPlugin.
  ///
  /// In en, this message translates to:
  /// **'Find a plugin'**
  String get assistantSuggestPlugin;

  /// No description provided for @assistantSuggestQr.
  ///
  /// In en, this message translates to:
  /// **'Make a QR code'**
  String get assistantSuggestQr;

  /// No description provided for @assistantSuggestWeek.
  ///
  /// In en, this message translates to:
  /// **'Plan my week'**
  String get assistantSuggestWeek;

  /// No description provided for @assistantSuggestNote.
  ///
  /// In en, this message translates to:
  /// **'Write a note'**
  String get assistantSuggestNote;

  /// No description provided for @assistantSuggestPluginPrompt.
  ///
  /// In en, this message translates to:
  /// **'Which luma plugin would help me with '**
  String get assistantSuggestPluginPrompt;

  /// No description provided for @assistantSuggestQrPrompt.
  ///
  /// In en, this message translates to:
  /// **'Make a QR code for '**
  String get assistantSuggestQrPrompt;

  /// No description provided for @assistantSuggestWeekPrompt.
  ///
  /// In en, this message translates to:
  /// **'What\'s on my calendar this week?'**
  String get assistantSuggestWeekPrompt;

  /// No description provided for @assistantSuggestNotePrompt.
  ///
  /// In en, this message translates to:
  /// **'Save a note that says '**
  String get assistantSuggestNotePrompt;

  /// No description provided for @assistantToggleSidebar.
  ///
  /// In en, this message translates to:
  /// **'Toggle sidebar'**
  String get assistantToggleSidebar;

  /// No description provided for @assistantChats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get assistantChats;

  /// No description provided for @assistantUsage.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get assistantUsage;

  /// No description provided for @assistantContextWindow.
  ///
  /// In en, this message translates to:
  /// **'Context window'**
  String get assistantContextWindow;

  /// No description provided for @assistantUsageLimits.
  ///
  /// In en, this message translates to:
  /// **'Usage limits'**
  String get assistantUsageLimits;

  /// No description provided for @assistantFiveHourLimit.
  ///
  /// In en, this message translates to:
  /// **'5-hour limit'**
  String get assistantFiveHourLimit;

  /// No description provided for @assistantWeeklyLimit.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get assistantWeeklyLimit;

  /// No description provided for @assistantDailyMessages.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get assistantDailyMessages;

  /// No description provided for @assistantMessagesOf.
  ///
  /// In en, this message translates to:
  /// **'{used} of {limit} messages'**
  String assistantMessagesOf(int used, int limit);

  /// No description provided for @assistantLastReply.
  ///
  /// In en, this message translates to:
  /// **'Last reply'**
  String get assistantLastReply;

  /// No description provided for @assistantTokensInOut.
  ///
  /// In en, this message translates to:
  /// **'{input} in · {output} out'**
  String assistantTokensInOut(String input, String output);

  /// No description provided for @assistantNoLimits.
  ///
  /// In en, this message translates to:
  /// **'Runs on this device — no usage limits'**
  String get assistantNoLimits;

  /// No description provided for @assistantUsageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Usage unavailable — check your connection'**
  String get assistantUsageUnavailable;

  /// No description provided for @assistantDetailedBreakdown.
  ///
  /// In en, this message translates to:
  /// **'See detailed breakdown'**
  String get assistantDetailedBreakdown;

  /// No description provided for @assistantNoRepliesYet.
  ///
  /// In en, this message translates to:
  /// **'No replies in this chat yet'**
  String get assistantNoRepliesYet;

  /// No description provided for @assistantMenuUsage.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get assistantMenuUsage;

  /// No description provided for @assistantMenuSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get assistantMenuSettings;

  /// No description provided for @assistantMenuAgents.
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get assistantMenuAgents;

  /// No description provided for @assistantYourUsage.
  ///
  /// In en, this message translates to:
  /// **'Your usage'**
  String get assistantYourUsage;

  /// No description provided for @assistantUsageHeadlinePlenty.
  ///
  /// In en, this message translates to:
  /// **'Plenty of room left. Chat away.'**
  String get assistantUsageHeadlinePlenty;

  /// No description provided for @assistantUsageHeadlineOnTrack.
  ///
  /// In en, this message translates to:
  /// **'You\'re on track, with room to spare.'**
  String get assistantUsageHeadlineOnTrack;

  /// No description provided for @assistantUsageHeadlineClose.
  ///
  /// In en, this message translates to:
  /// **'Heads up. You\'re close to a limit.'**
  String get assistantUsageHeadlineClose;

  /// No description provided for @assistantUsageHeadlineOut.
  ///
  /// In en, this message translates to:
  /// **'You\'ve hit a limit. It frees up again as the window rolls on.'**
  String get assistantUsageHeadlineOut;

  /// No description provided for @assistantUsageLumaAi.
  ///
  /// In en, this message translates to:
  /// **'Luma AI'**
  String get assistantUsageLumaAi;

  /// No description provided for @assistantUsageLumaAiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Aurora, Nebula and Pulsar, through your luma account'**
  String get assistantUsageLumaAiSubtitle;

  /// No description provided for @assistantUsageCurrentSession.
  ///
  /// In en, this message translates to:
  /// **'Current session'**
  String get assistantUsageCurrentSession;

  /// No description provided for @assistantUsageRollingFiveHours.
  ///
  /// In en, this message translates to:
  /// **'Rolling 5-hour window'**
  String get assistantUsageRollingFiveHours;

  /// No description provided for @assistantUsageThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get assistantUsageThisWeek;

  /// No description provided for @assistantUsageRollingWeek.
  ///
  /// In en, this message translates to:
  /// **'Rolling 7-day window'**
  String get assistantUsageRollingWeek;

  /// No description provided for @assistantUsageLumaAssistant.
  ///
  /// In en, this message translates to:
  /// **'Luma Assistant'**
  String get assistantUsageLumaAssistant;

  /// No description provided for @assistantUsageLumaAssistantSubtitle.
  ///
  /// In en, this message translates to:
  /// **'On-device Qwen model'**
  String get assistantUsageLumaAssistantSubtitle;

  /// No description provided for @assistantUsageWebSearch.
  ///
  /// In en, this message translates to:
  /// **'Web searches'**
  String get assistantUsageWebSearch;

  /// No description provided for @assistantUsageCountOf.
  ///
  /// In en, this message translates to:
  /// **'{used} of {limit}'**
  String assistantUsageCountOf(int used, int limit);

  /// No description provided for @assistantUsagePercentUsed.
  ///
  /// In en, this message translates to:
  /// **'{percent}% used'**
  String assistantUsagePercentUsed(int percent);

  /// No description provided for @assistantUsageLumaSupport.
  ///
  /// In en, this message translates to:
  /// **'Luma Support'**
  String get assistantUsageLumaSupport;

  /// No description provided for @assistantUsageResetsDaily.
  ///
  /// In en, this message translates to:
  /// **'Resets at midnight'**
  String get assistantUsageResetsDaily;

  /// No description provided for @assistantUsageApiKeys.
  ///
  /// In en, this message translates to:
  /// **'Your API keys'**
  String get assistantUsageApiKeys;

  /// No description provided for @assistantUsageApiKeysSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your own API keys; provider credits and limits still apply'**
  String get assistantUsageApiKeysSubtitle;

  /// No description provided for @assistantUsageUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited in Luma'**
  String get assistantUsageUnlimited;

  /// No description provided for @assistantUsageByModel.
  ///
  /// In en, this message translates to:
  /// **'Messages by model'**
  String get assistantUsageByModel;

  /// No description provided for @assistantUsageByModelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Successful messages on this device, counted per model.'**
  String get assistantUsageByModelSubtitle;

  /// No description provided for @assistantUsageMessageCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 message} other{{count} messages}}'**
  String assistantUsageMessageCount(int count);

  /// No description provided for @assistantUsageNoMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get assistantUsageNoMessages;

  /// No description provided for @assistantUsageStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get assistantUsageStorage;

  /// No description provided for @assistantUsageMemoryStorage.
  ///
  /// In en, this message translates to:
  /// **'Assistant memory'**
  String get assistantUsageMemoryStorage;

  /// No description provided for @assistantUsageMemoryStorageCaption.
  ///
  /// In en, this message translates to:
  /// **'Syncs with your account on every plan and counts toward server storage'**
  String get assistantUsageMemoryStorageCaption;

  /// No description provided for @assistantUsageServerStorage.
  ///
  /// In en, this message translates to:
  /// **'Server storage'**
  String get assistantUsageServerStorage;

  /// No description provided for @assistantUsageStorageOf.
  ///
  /// In en, this message translates to:
  /// **'{used} of {quota}'**
  String assistantUsageStorageOf(String used, String quota);

  /// No description provided for @assistantSettingsChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get assistantSettingsChat;

  /// No description provided for @assistantSettingsMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get assistantSettingsMemory;

  /// No description provided for @assistantSettingsUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get assistantSettingsUser;

  /// No description provided for @assistantSettingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Response language'**
  String get assistantSettingsLanguage;

  /// No description provided for @assistantSettingsLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'The language the assistant answers you in.'**
  String get assistantSettingsLanguageHint;

  /// No description provided for @assistantSettingsLanguageAuto.
  ///
  /// In en, this message translates to:
  /// **'Match my language'**
  String get assistantSettingsLanguageAuto;

  /// No description provided for @assistantSettingsFont.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get assistantSettingsFont;

  /// No description provided for @assistantSettingsFontHint.
  ///
  /// In en, this message translates to:
  /// **'The typeface the assistant\'s replies are set in.'**
  String get assistantSettingsFontHint;

  /// No description provided for @assistantFontSerif.
  ///
  /// In en, this message translates to:
  /// **'Serif'**
  String get assistantFontSerif;

  /// No description provided for @assistantFontSans.
  ///
  /// In en, this message translates to:
  /// **'Sans'**
  String get assistantFontSans;

  /// No description provided for @assistantFontMono.
  ///
  /// In en, this message translates to:
  /// **'Mono'**
  String get assistantFontMono;

  /// No description provided for @assistantSettingsTextSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get assistantSettingsTextSize;

  /// No description provided for @assistantSettingsTextSizeHint.
  ///
  /// In en, this message translates to:
  /// **'Size of the conversation text.'**
  String get assistantSettingsTextSizeHint;

  /// No description provided for @assistantTextSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get assistantTextSmall;

  /// No description provided for @assistantTextMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get assistantTextMedium;

  /// No description provided for @assistantTextLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get assistantTextLarge;

  /// No description provided for @assistantSettingsPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get assistantSettingsPreview;

  /// No description provided for @assistantSettingsPreviewText.
  ///
  /// In en, this message translates to:
  /// **'Here\'s how replies will look. **Bold**, *italic* and `code` all follow your choice.'**
  String get assistantSettingsPreviewText;

  /// No description provided for @assistantMemoryUse.
  ///
  /// In en, this message translates to:
  /// **'Use memory'**
  String get assistantMemoryUse;

  /// No description provided for @assistantMemoryUseHint.
  ///
  /// In en, this message translates to:
  /// **'Let the assistant remember things about you across chats, and bring them up when they help.'**
  String get assistantMemoryUseHint;

  /// No description provided for @assistantMemorySyncNote.
  ///
  /// In en, this message translates to:
  /// **'Synced to your account on every plan · {size} of server storage'**
  String assistantMemorySyncNote(String size);

  /// No description provided for @assistantMemoryAdd.
  ///
  /// In en, this message translates to:
  /// **'Add memory'**
  String get assistantMemoryAdd;

  /// No description provided for @assistantMemoryEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit memory'**
  String get assistantMemoryEdit;

  /// No description provided for @assistantMemoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing remembered yet'**
  String get assistantMemoryEmpty;

  /// No description provided for @assistantMemoryEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tell the assistant about yourself in a chat, or add a memory here.'**
  String get assistantMemoryEmptyHint;

  /// No description provided for @assistantMemoryYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get assistantMemoryYou;

  /// No description provided for @assistantMemoryTopics.
  ///
  /// In en, this message translates to:
  /// **'Topics'**
  String get assistantMemoryTopics;

  /// No description provided for @assistantMemoryAreas.
  ///
  /// In en, this message translates to:
  /// **'Areas'**
  String get assistantMemoryAreas;

  /// No description provided for @assistantMemoryUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated {date}'**
  String assistantMemoryUpdated(String date);

  /// No description provided for @assistantMemoryClear.
  ///
  /// In en, this message translates to:
  /// **'Delete all memory'**
  String get assistantMemoryClear;

  /// No description provided for @assistantMemoryClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all memory?'**
  String get assistantMemoryClearTitle;

  /// No description provided for @assistantMemoryClearBody.
  ///
  /// In en, this message translates to:
  /// **'The assistant forgets everything it remembered, on every device. Your profile on the User tab stays.'**
  String get assistantMemoryClearBody;

  /// No description provided for @assistantMemoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get assistantMemoryTitle;

  /// No description provided for @assistantMemoryTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Hardware'**
  String get assistantMemoryTitleHint;

  /// No description provided for @assistantMemoryDescription.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get assistantMemoryDescription;

  /// No description provided for @assistantMemoryDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'One line, shown in the list'**
  String get assistantMemoryDescriptionHint;

  /// No description provided for @assistantMemoryBody.
  ///
  /// In en, this message translates to:
  /// **'What to remember'**
  String get assistantMemoryBody;

  /// No description provided for @assistantMemoryBodyHint.
  ///
  /// In en, this message translates to:
  /// **'One fact per line'**
  String get assistantMemoryBodyHint;

  /// No description provided for @assistantProfileCallMe.
  ///
  /// In en, this message translates to:
  /// **'What should the assistant call you?'**
  String get assistantProfileCallMe;

  /// No description provided for @assistantProfileCallMeHint.
  ///
  /// In en, this message translates to:
  /// **'Your name or nickname'**
  String get assistantProfileCallMeHint;

  /// No description provided for @assistantProfileOccupation.
  ///
  /// In en, this message translates to:
  /// **'What do you do?'**
  String get assistantProfileOccupation;

  /// No description provided for @assistantProfileOccupationHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. student, indie game developer'**
  String get assistantProfileOccupationHint;

  /// No description provided for @assistantProfileSummary.
  ///
  /// In en, this message translates to:
  /// **'About you'**
  String get assistantProfileSummary;

  /// No description provided for @assistantProfileSummaryHint.
  ///
  /// In en, this message translates to:
  /// **'A few sentences the assistant should always know'**
  String get assistantProfileSummaryHint;

  /// No description provided for @assistantProfileInstructions.
  ///
  /// In en, this message translates to:
  /// **'How should the assistant respond?'**
  String get assistantProfileInstructions;

  /// No description provided for @assistantProfileInstructionsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. keep it short, explain code step by step'**
  String get assistantProfileInstructionsHint;

  /// No description provided for @assistantProfileSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get assistantProfileSave;

  /// No description provided for @assistantProfileSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get assistantProfileSaved;

  /// No description provided for @assistantAgentsComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get assistantAgentsComingSoon;

  /// No description provided for @assistantAgentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Agents you\'ve built in the AI Usage plugin. Running them from the assistant is coming soon.'**
  String get assistantAgentsSubtitle;

  /// No description provided for @assistantAgentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No agents yet'**
  String get assistantAgentsEmpty;

  /// No description provided for @assistantAgentsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Build one in the AI Usage plugin\'s Agents tab and it shows up here.'**
  String get assistantAgentsEmptyHint;

  /// No description provided for @assistantAgentsOpenBuilder.
  ///
  /// In en, this message translates to:
  /// **'Open AI Usage'**
  String get assistantAgentsOpenBuilder;

  /// No description provided for @assistantAgentsNoDescription.
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get assistantAgentsNoDescription;

  /// No description provided for @textLibraryBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get textLibraryBack;

  /// No description provided for @textLibraryBodyHint.
  ///
  /// In en, this message translates to:
  /// **'Write your text…'**
  String get textLibraryBodyHint;

  /// No description provided for @textLibraryBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get textLibraryBold;

  /// No description provided for @textLibraryCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get textLibraryCancel;

  /// No description provided for @textLibraryClearFormatting.
  ///
  /// In en, this message translates to:
  /// **'Clear formatting'**
  String get textLibraryClearFormatting;

  /// No description provided for @textLibraryColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get textLibraryColor;

  /// No description provided for @textLibraryCover.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get textLibraryCover;

  /// No description provided for @textLibraryCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get textLibraryCreate;

  /// No description provided for @textLibraryDefaultInk.
  ///
  /// In en, this message translates to:
  /// **'Default ink'**
  String get textLibraryDefaultInk;

  /// No description provided for @textLibraryDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get textLibraryDelete;

  /// No description provided for @textLibraryDeleteSubjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete subject \"{name}\"?'**
  String textLibraryDeleteSubjectTitle(String name);

  /// No description provided for @textLibraryDeleteSubjectBody.
  ///
  /// In en, this message translates to:
  /// **'Delete this subject and its {count, plural, =0{no texts} =1{one text} other{{count} texts}}?'**
  String textLibraryDeleteSubjectBody(int count);

  /// No description provided for @textLibraryDeleteTextBody.
  ///
  /// In en, this message translates to:
  /// **'This text will be permanently deleted.'**
  String get textLibraryDeleteTextBody;

  /// No description provided for @textLibraryDeleteTextTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"?'**
  String textLibraryDeleteTextTitle(String title);

  /// No description provided for @textLibraryEdited.
  ///
  /// In en, this message translates to:
  /// **'Edited {date}'**
  String textLibraryEdited(String date);

  /// No description provided for @textLibraryInk.
  ///
  /// In en, this message translates to:
  /// **'Ink'**
  String get textLibraryInk;

  /// No description provided for @textLibraryItalic.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get textLibraryItalic;

  /// No description provided for @textLibraryMcBooks.
  ///
  /// In en, this message translates to:
  /// **'{count} books'**
  String textLibraryMcBooks(String count);

  /// No description provided for @textLibraryMcBuild.
  ///
  /// In en, this message translates to:
  /// **'Build'**
  String get textLibraryMcBuild;

  /// No description provided for @textLibraryMcBuiltIn.
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get textLibraryMcBuiltIn;

  /// No description provided for @textLibraryMcBurn.
  ///
  /// In en, this message translates to:
  /// **'Burn'**
  String get textLibraryMcBurn;

  /// No description provided for @textLibraryMcBurnConfirm.
  ///
  /// In en, this message translates to:
  /// **'Burn this book? This cannot be undone.'**
  String get textLibraryMcBurnConfirm;

  /// No description provided for @textLibraryMcChooseSlot.
  ///
  /// In en, this message translates to:
  /// **'Choose a shelf slot'**
  String get textLibraryMcChooseSlot;

  /// No description provided for @textLibraryMcDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get textLibraryMcDone;

  /// No description provided for @textLibraryMcDownload.
  ///
  /// In en, this message translates to:
  /// **'Download Minecraft assets'**
  String get textLibraryMcDownload;

  /// No description provided for @textLibraryMcDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not download Minecraft assets.'**
  String get textLibraryMcDownloadFailed;

  /// No description provided for @textLibraryMcDownloadNote.
  ///
  /// In en, this message translates to:
  /// **'Minecraft assets are downloaded from Mojang and cached on this device.'**
  String get textLibraryMcDownloadNote;

  /// No description provided for @textLibraryMcEmptyHall.
  ///
  /// In en, this message translates to:
  /// **'Your hall is empty. Create a subject to begin.'**
  String get textLibraryMcEmptyHall;

  /// No description provided for @textLibraryMcEmptySlot.
  ///
  /// In en, this message translates to:
  /// **'Empty slot'**
  String get textLibraryMcEmptySlot;

  /// No description provided for @textLibraryMcFailedAndroid.
  ///
  /// In en, this message translates to:
  /// **'Could not open the Minecraft library on Android.'**
  String get textLibraryMcFailedAndroid;

  /// No description provided for @textLibraryMcFailedWindows.
  ///
  /// In en, this message translates to:
  /// **'Could not open the Minecraft library on Windows.'**
  String get textLibraryMcFailedWindows;

  /// No description provided for @textLibraryMcLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading Minecraft library…'**
  String get textLibraryMcLoading;

  /// No description provided for @textLibraryMcLost.
  ///
  /// In en, this message translates to:
  /// **'The Minecraft library connection was lost.'**
  String get textLibraryMcLost;

  /// No description provided for @textLibraryMcMoveHint.
  ///
  /// In en, this message translates to:
  /// **'Move this book to another shelf.'**
  String get textLibraryMcMoveHint;

  /// No description provided for @textLibraryMcNewCase.
  ///
  /// In en, this message translates to:
  /// **'New case'**
  String get textLibraryMcNewCase;

  /// No description provided for @textLibraryMcNewCaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a case'**
  String get textLibraryMcNewCaseTitle;

  /// No description provided for @textLibraryMcPage.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {total}'**
  String textLibraryMcPage(String page, String total);

  /// No description provided for @textLibraryMcQuality.
  ///
  /// In en, this message translates to:
  /// **'Render quality'**
  String get textLibraryMcQuality;

  /// No description provided for @textLibraryMcQualityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get textLibraryMcQualityHigh;

  /// No description provided for @textLibraryMcQualityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get textLibraryMcQualityLow;

  /// No description provided for @textLibraryMcRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get textLibraryMcRedo;

  /// No description provided for @textLibraryMcRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get textLibraryMcRetry;

  /// No description provided for @textLibraryMcSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the book.'**
  String get textLibraryMcSaveFailed;

  /// No description provided for @textLibraryMcSettings.
  ///
  /// In en, this message translates to:
  /// **'Hall settings'**
  String get textLibraryMcSettings;

  /// No description provided for @textLibraryMcShelfPage.
  ///
  /// In en, this message translates to:
  /// **'Shelf page {page} of {total}'**
  String textLibraryMcShelfPage(String page, String total);

  /// No description provided for @textLibraryMcSign.
  ///
  /// In en, this message translates to:
  /// **'Sign book'**
  String get textLibraryMcSign;

  /// No description provided for @textLibraryMcSignAndShelve.
  ///
  /// In en, this message translates to:
  /// **'Sign and shelve'**
  String get textLibraryMcSignAndShelve;

  /// No description provided for @textLibraryMcSignTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign this book?'**
  String get textLibraryMcSignTitle;

  /// No description provided for @textLibraryMcTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get textLibraryMcTime;

  /// No description provided for @textLibraryMcTimeClock.
  ///
  /// In en, this message translates to:
  /// **'My clock'**
  String get textLibraryMcTimeClock;

  /// No description provided for @textLibraryMcTimeCycle.
  ///
  /// In en, this message translates to:
  /// **'Day and night'**
  String get textLibraryMcTimeCycle;

  /// No description provided for @textLibraryMcTimeDay.
  ///
  /// In en, this message translates to:
  /// **'Always day'**
  String get textLibraryMcTimeDay;

  /// No description provided for @textLibraryMcTimeNight.
  ///
  /// In en, this message translates to:
  /// **'Always night'**
  String get textLibraryMcTimeNight;

  /// No description provided for @textLibraryMcUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get textLibraryMcUndo;

  /// No description provided for @textLibraryMcUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get textLibraryMcUntitled;

  /// No description provided for @textLibraryMcVanilla.
  ///
  /// In en, this message translates to:
  /// **'Minecraft {version}'**
  String textLibraryMcVanilla(String version);

  /// No description provided for @textLibraryMcWalkHint.
  ///
  /// In en, this message translates to:
  /// **'WASD to walk · click to look around · click a bookcase, chair or door to use it · Esc frees the mouse'**
  String get textLibraryMcWalkHint;

  /// No description provided for @textLibraryMcLookHint.
  ///
  /// In en, this message translates to:
  /// **'Click to look around'**
  String get textLibraryMcLookHint;

  /// No description provided for @textLibraryMcStandHint.
  ///
  /// In en, this message translates to:
  /// **'Shift or Space to stand up'**
  String get textLibraryMcStandHint;

  /// No description provided for @textLibraryMcStandUp.
  ///
  /// In en, this message translates to:
  /// **'Stand up'**
  String get textLibraryMcStandUp;

  /// No description provided for @textLibraryMcSit.
  ///
  /// In en, this message translates to:
  /// **'Sit down'**
  String get textLibraryMcSit;

  /// No description provided for @textLibraryMcOpenDoor.
  ///
  /// In en, this message translates to:
  /// **'Open the door'**
  String get textLibraryMcOpenDoor;

  /// No description provided for @textLibraryMcCloseDoor.
  ///
  /// In en, this message translates to:
  /// **'Close the door'**
  String get textLibraryMcCloseDoor;

  /// No description provided for @textLibraryMcOpenDrawer.
  ///
  /// In en, this message translates to:
  /// **'Open the drawer'**
  String get textLibraryMcOpenDrawer;

  /// No description provided for @textLibraryMcCloseDrawer.
  ///
  /// In en, this message translates to:
  /// **'Close the drawer'**
  String get textLibraryMcCloseDrawer;

  /// No description provided for @textLibraryMcShapes.
  ///
  /// In en, this message translates to:
  /// **'Shapes'**
  String get textLibraryMcShapes;

  /// No description provided for @textLibraryMcShapeCircle.
  ///
  /// In en, this message translates to:
  /// **'Circle'**
  String get textLibraryMcShapeCircle;

  /// No description provided for @textLibraryMcShapeSquare.
  ///
  /// In en, this message translates to:
  /// **'Square'**
  String get textLibraryMcShapeSquare;

  /// No description provided for @textLibraryMcShapeTriangle.
  ///
  /// In en, this message translates to:
  /// **'Triangle'**
  String get textLibraryMcShapeTriangle;

  /// No description provided for @textLibraryMcShapeStar.
  ///
  /// In en, this message translates to:
  /// **'Star'**
  String get textLibraryMcShapeStar;

  /// No description provided for @textLibraryMcShapeHeart.
  ///
  /// In en, this message translates to:
  /// **'Heart'**
  String get textLibraryMcShapeHeart;

  /// No description provided for @textLibraryMcShapeLine.
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get textLibraryMcShapeLine;

  /// No description provided for @textLibraryMcShapeFill.
  ///
  /// In en, this message translates to:
  /// **'Filled or outline'**
  String get textLibraryMcShapeFill;

  /// No description provided for @textLibraryMcDrawHint.
  ///
  /// In en, this message translates to:
  /// **'drag on the page to draw it · right-click a drawing to remove it'**
  String get textLibraryMcDrawHint;

  /// No description provided for @textLibraryMcSkinCurrent.
  ///
  /// In en, this message translates to:
  /// **'Skin: {name}'**
  String textLibraryMcSkinCurrent(String name);

  /// No description provided for @textLibraryMcSkinDefault.
  ///
  /// In en, this message translates to:
  /// **'Default skin'**
  String get textLibraryMcSkinDefault;

  /// No description provided for @textLibraryMcSkinYours.
  ///
  /// In en, this message translates to:
  /// **'your own'**
  String get textLibraryMcSkinYours;

  /// No description provided for @textLibraryMcSkinImport.
  ///
  /// In en, this message translates to:
  /// **'Import skin…'**
  String get textLibraryMcSkinImport;

  /// No description provided for @textLibraryMcSkinName.
  ///
  /// In en, this message translates to:
  /// **'Minecraft name…'**
  String get textLibraryMcSkinName;

  /// No description provided for @textLibraryMcSkinNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Minecraft username'**
  String get textLibraryMcSkinNameTitle;

  /// No description provided for @textLibraryMcSkinNameHint.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get textLibraryMcSkinNameHint;

  /// No description provided for @textLibraryMcSkinUse.
  ///
  /// In en, this message translates to:
  /// **'Use skin'**
  String get textLibraryMcSkinUse;

  /// No description provided for @textLibraryMcSkinFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load that skin.'**
  String get textLibraryMcSkinFailed;

  /// No description provided for @textLibraryMcWriteHint.
  ///
  /// In en, this message translates to:
  /// **'Write your book here…'**
  String get textLibraryMcWriteHint;

  /// No description provided for @textLibraryModeClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get textLibraryModeClassic;

  /// No description provided for @textLibraryModeMinecraft.
  ///
  /// In en, this message translates to:
  /// **'Minecraft hall'**
  String get textLibraryModeMinecraft;

  /// No description provided for @textLibraryMoveTo.
  ///
  /// In en, this message translates to:
  /// **'Move to'**
  String get textLibraryMoveTo;

  /// No description provided for @textLibraryMoveToTitle.
  ///
  /// In en, this message translates to:
  /// **'Move text to a subject'**
  String get textLibraryMoveToTitle;

  /// No description provided for @textLibraryNewSubject.
  ///
  /// In en, this message translates to:
  /// **'New subject'**
  String get textLibraryNewSubject;

  /// No description provided for @textLibraryNewText.
  ///
  /// In en, this message translates to:
  /// **'New text'**
  String get textLibraryNewText;

  /// No description provided for @textLibraryNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No texts match \"{query}\"'**
  String textLibraryNoMatches(String query);

  /// No description provided for @textLibraryNoSubjects.
  ///
  /// In en, this message translates to:
  /// **'No subjects yet'**
  String get textLibraryNoSubjects;

  /// No description provided for @textLibraryNoSubjectsSub.
  ///
  /// In en, this message translates to:
  /// **'Create a subject to organize your texts.'**
  String get textLibraryNoSubjectsSub;

  /// No description provided for @textLibraryNoTexts.
  ///
  /// In en, this message translates to:
  /// **'No texts yet'**
  String get textLibraryNoTexts;

  /// No description provided for @textLibraryNoTextsSub.
  ///
  /// In en, this message translates to:
  /// **'Add a text to this subject to get started.'**
  String get textLibraryNoTextsSub;

  /// No description provided for @textLibraryRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get textLibraryRename;

  /// No description provided for @textLibraryRenameSubject.
  ///
  /// In en, this message translates to:
  /// **'Rename subject'**
  String get textLibraryRenameSubject;

  /// No description provided for @textLibrarySave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get textLibrarySave;

  /// No description provided for @textLibrarySaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get textLibrarySaved;

  /// No description provided for @textLibrarySaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get textLibrarySaving;

  /// No description provided for @textLibrarySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search texts'**
  String get textLibrarySearchHint;

  /// No description provided for @textLibrarySpineHint.
  ///
  /// In en, this message translates to:
  /// **'A short label shown on the book spine'**
  String get textLibrarySpineHint;

  /// No description provided for @textLibrarySpineLabel.
  ///
  /// In en, this message translates to:
  /// **'Spine label'**
  String get textLibrarySpineLabel;

  /// No description provided for @textLibraryStrike.
  ///
  /// In en, this message translates to:
  /// **'Strikethrough'**
  String get textLibraryStrike;

  /// No description provided for @textLibrarySubjectNameHint.
  ///
  /// In en, this message translates to:
  /// **'Subject name'**
  String get textLibrarySubjectNameHint;

  /// No description provided for @textLibrarySubjectNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a subject name.'**
  String get textLibrarySubjectNameRequired;

  /// No description provided for @textLibrarySubjects.
  ///
  /// In en, this message translates to:
  /// **'Subjects'**
  String get textLibrarySubjects;

  /// No description provided for @textLibraryTextCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 text} other{{count} texts}}'**
  String textLibraryTextCount(int count);

  /// No description provided for @textLibraryTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get textLibraryTitleHint;

  /// No description provided for @textLibraryUnderline.
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get textLibraryUnderline;

  /// No description provided for @audioToolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Audio Tools'**
  String get audioToolsTitle;

  /// No description provided for @audioToolsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shape your voice with an equalizer and send it to Discord, OBS or any app that takes a microphone.'**
  String get audioToolsSubtitle;

  /// No description provided for @audioToolsWindowsOnly.
  ///
  /// In en, this message translates to:
  /// **'Windows only'**
  String get audioToolsWindowsOnly;

  /// No description provided for @audioToolsWindowsOnlyBody.
  ///
  /// In en, this message translates to:
  /// **'Audio Tools routes your microphone in real time, which luma can only do in the Windows desktop app.'**
  String get audioToolsWindowsOnlyBody;

  /// No description provided for @audioToolsStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get audioToolsStart;

  /// No description provided for @audioToolsStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get audioToolsStop;

  /// No description provided for @audioToolsLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get audioToolsLive;

  /// No description provided for @audioToolsOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get audioToolsOff;

  /// No description provided for @audioToolsRouting.
  ///
  /// In en, this message translates to:
  /// **'Routing'**
  String get audioToolsRouting;

  /// No description provided for @audioToolsMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get audioToolsMicrophone;

  /// No description provided for @audioToolsSendTo.
  ///
  /// In en, this message translates to:
  /// **'Send to'**
  String get audioToolsSendTo;

  /// No description provided for @audioToolsWindowsDefault.
  ///
  /// In en, this message translates to:
  /// **'Windows default ({name})'**
  String audioToolsWindowsDefault(String name);

  /// No description provided for @audioToolsWindowsDefaultPlain.
  ///
  /// In en, this message translates to:
  /// **'Windows default'**
  String get audioToolsWindowsDefaultPlain;

  /// No description provided for @audioToolsRefreshDevices.
  ///
  /// In en, this message translates to:
  /// **'Refresh devices'**
  String get audioToolsRefreshDevices;

  /// No description provided for @audioToolsVirtualCableTag.
  ///
  /// In en, this message translates to:
  /// **'Virtual cable'**
  String get audioToolsVirtualCableTag;

  /// No description provided for @audioToolsNotACable.
  ///
  /// In en, this message translates to:
  /// **'This output is a speaker, not a virtual cable, so other apps won\'t hear it as a microphone.'**
  String get audioToolsNotACable;

  /// No description provided for @audioToolsHearMyself.
  ///
  /// In en, this message translates to:
  /// **'Hear myself'**
  String get audioToolsHearMyself;

  /// No description provided for @audioToolsHearMyselfBody.
  ///
  /// In en, this message translates to:
  /// **'Also play the result on your default speakers or headset.'**
  String get audioToolsHearMyselfBody;

  /// No description provided for @audioToolsBypass.
  ///
  /// In en, this message translates to:
  /// **'Bypass equalizer'**
  String get audioToolsBypass;

  /// No description provided for @audioToolsBypassBody.
  ///
  /// In en, this message translates to:
  /// **'Send your voice through untouched, to compare.'**
  String get audioToolsBypassBody;

  /// No description provided for @audioToolsAutoStart.
  ///
  /// In en, this message translates to:
  /// **'Start with luma'**
  String get audioToolsAutoStart;

  /// No description provided for @audioToolsAutoStartBody.
  ///
  /// In en, this message translates to:
  /// **'Turn the voice changer on as soon as luma opens.'**
  String get audioToolsAutoStartBody;

  /// No description provided for @audioToolsDiscordTitle.
  ///
  /// In en, this message translates to:
  /// **'Use it in Discord'**
  String get audioToolsDiscordTitle;

  /// No description provided for @audioToolsCableFound.
  ///
  /// In en, this message translates to:
  /// **'Virtual cable found'**
  String get audioToolsCableFound;

  /// No description provided for @audioToolsCableMissingTitle.
  ///
  /// In en, this message translates to:
  /// **'One-time setup: a virtual cable'**
  String get audioToolsCableMissingTitle;

  /// No description provided for @audioToolsCableMissingBody.
  ///
  /// In en, this message translates to:
  /// **'Windows can\'t add a new microphone without a driver, so luma sends your processed voice through a free virtual cable. Install VB-CABLE once, then come back here. Discord, OBS and games will see it as a microphone.'**
  String get audioToolsCableMissingBody;

  /// No description provided for @audioToolsGetCable.
  ///
  /// In en, this message translates to:
  /// **'Get VB-CABLE'**
  String get audioToolsGetCable;

  /// No description provided for @audioToolsInstalledCheck.
  ///
  /// In en, this message translates to:
  /// **'I installed it'**
  String get audioToolsInstalledCheck;

  /// No description provided for @audioToolsStepSendTo.
  ///
  /// In en, this message translates to:
  /// **'Set Send to to {device}.'**
  String audioToolsStepSendTo(String device);

  /// No description provided for @audioToolsUseCable.
  ///
  /// In en, this message translates to:
  /// **'Use it'**
  String get audioToolsUseCable;

  /// No description provided for @audioToolsStepDiscord.
  ///
  /// In en, this message translates to:
  /// **'In Discord, open Settings → Voice & Video and set Input Device to {device}.'**
  String audioToolsStepDiscord(String device);

  /// No description provided for @audioToolsStepStart.
  ///
  /// In en, this message translates to:
  /// **'Press Start. If the effect sounds washed out, turn off Discord\'s noise suppression.'**
  String get audioToolsStepStart;

  /// No description provided for @audioToolsErrDeviceMissing.
  ///
  /// In en, this message translates to:
  /// **'That audio device isn\'t connected any more. Pick another one.'**
  String get audioToolsErrDeviceMissing;

  /// No description provided for @audioToolsErrDeviceInUse.
  ///
  /// In en, this message translates to:
  /// **'Another app is using that device in exclusive mode.'**
  String get audioToolsErrDeviceInUse;

  /// No description provided for @audioToolsErrDeviceLost.
  ///
  /// In en, this message translates to:
  /// **'The audio device was disconnected, so the voice changer stopped.'**
  String get audioToolsErrDeviceLost;

  /// No description provided for @audioToolsErrMicBlocked.
  ///
  /// In en, this message translates to:
  /// **'Windows is blocking the microphone. Turn on \"Let desktop apps access your microphone\" in Privacy settings.'**
  String get audioToolsErrMicBlocked;

  /// No description provided for @audioToolsErrFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start audio. Try another device.'**
  String get audioToolsErrFailed;

  /// No description provided for @audioToolsOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get audioToolsOpenSettings;

  /// No description provided for @audioToolsDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get audioToolsDismiss;

  /// No description provided for @audioToolsEqualizer.
  ///
  /// In en, this message translates to:
  /// **'Equalizer'**
  String get audioToolsEqualizer;

  /// No description provided for @audioToolsReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get audioToolsReset;

  /// No description provided for @audioToolsEqHint.
  ///
  /// In en, this message translates to:
  /// **'Drag a point to shape your voice. Scroll over the graph to make the selected band wider or narrower.'**
  String get audioToolsEqHint;

  /// No description provided for @audioToolsPreamp.
  ///
  /// In en, this message translates to:
  /// **'Preamp'**
  String get audioToolsPreamp;

  /// No description provided for @audioToolsFrequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get audioToolsFrequency;

  /// No description provided for @audioToolsGain.
  ///
  /// In en, this message translates to:
  /// **'Gain'**
  String get audioToolsGain;

  /// No description provided for @audioToolsWidth.
  ///
  /// In en, this message translates to:
  /// **'Width (Q)'**
  String get audioToolsWidth;

  /// No description provided for @audioToolsBandOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get audioToolsBandOn;

  /// No description provided for @audioToolsTypeHighPass.
  ///
  /// In en, this message translates to:
  /// **'Low cut'**
  String get audioToolsTypeHighPass;

  /// No description provided for @audioToolsTypeLowShelf.
  ///
  /// In en, this message translates to:
  /// **'Low shelf'**
  String get audioToolsTypeLowShelf;

  /// No description provided for @audioToolsTypePeak.
  ///
  /// In en, this message translates to:
  /// **'Bell'**
  String get audioToolsTypePeak;

  /// No description provided for @audioToolsTypeHighShelf.
  ///
  /// In en, this message translates to:
  /// **'High shelf'**
  String get audioToolsTypeHighShelf;

  /// No description provided for @audioToolsTypeLowPass.
  ///
  /// In en, this message translates to:
  /// **'High cut'**
  String get audioToolsTypeLowPass;

  /// No description provided for @audioToolsPresetFlat.
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get audioToolsPresetFlat;

  /// No description provided for @audioToolsPresetClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get audioToolsPresetClear;

  /// No description provided for @audioToolsPresetDeep.
  ///
  /// In en, this message translates to:
  /// **'Deep'**
  String get audioToolsPresetDeep;

  /// No description provided for @audioToolsPresetRadio.
  ///
  /// In en, this message translates to:
  /// **'Radio'**
  String get audioToolsPresetRadio;

  /// No description provided for @audioToolsPresetTelephone.
  ///
  /// In en, this message translates to:
  /// **'Telephone'**
  String get audioToolsPresetTelephone;

  /// No description provided for @audioToolsPresetMegaphone.
  ///
  /// In en, this message translates to:
  /// **'Megaphone'**
  String get audioToolsPresetMegaphone;

  /// No description provided for @audioToolsPresetMuffled.
  ///
  /// In en, this message translates to:
  /// **'Through a wall'**
  String get audioToolsPresetMuffled;

  /// No description provided for @audioToolsPresetTiny.
  ///
  /// In en, this message translates to:
  /// **'Tiny'**
  String get audioToolsPresetTiny;

  /// No description provided for @audioToolsPresetCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get audioToolsPresetCustom;

  /// No description provided for @audioToolsSystemTitle.
  ///
  /// In en, this message translates to:
  /// **'Use it in Discord'**
  String get audioToolsSystemTitle;

  /// No description provided for @audioToolsSystemBody.
  ///
  /// In en, this message translates to:
  /// **'luma can put the EQ on {mic} itself, so Discord, OBS and games hear it with no extra software. Windows asks for admin permission once. Sound drops out for a few seconds while luma switches over and checks the mic still works, and if it doesn\'t, luma puts it straight back.'**
  String audioToolsSystemBody(String mic);

  /// No description provided for @audioToolsSystemEnable.
  ///
  /// In en, this message translates to:
  /// **'Turn on for this mic'**
  String get audioToolsSystemEnable;

  /// No description provided for @audioToolsSystemActive.
  ///
  /// In en, this message translates to:
  /// **'On for {mic}'**
  String audioToolsSystemActive(String mic);

  /// No description provided for @audioToolsSystemPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get audioToolsSystemPaused;

  /// No description provided for @audioToolsSystemEveryApp.
  ///
  /// In en, this message translates to:
  /// **'EQ in every app'**
  String get audioToolsSystemEveryApp;

  /// No description provided for @audioToolsSystemEveryAppBody.
  ///
  /// In en, this message translates to:
  /// **'Pausing needs no admin permission and keeps everything set up.'**
  String get audioToolsSystemEveryAppBody;

  /// No description provided for @audioToolsSystemDiscordHint.
  ///
  /// In en, this message translates to:
  /// **'In Discord, keep {mic} as your input device. If the EQ sounds washed out, turn off Discord\'s noise suppression and automatic gain control.'**
  String audioToolsSystemDiscordHint(String mic);

  /// No description provided for @audioToolsSystemOutdated.
  ///
  /// In en, this message translates to:
  /// **'luma updated its EQ engine. Apply the update to keep this mic in sync.'**
  String get audioToolsSystemOutdated;

  /// No description provided for @audioToolsSystemUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get audioToolsSystemUpdate;

  /// No description provided for @audioToolsSystemRemove.
  ///
  /// In en, this message translates to:
  /// **'Turn off and restore'**
  String get audioToolsSystemRemove;

  /// No description provided for @audioToolsSystemCancelled.
  ///
  /// In en, this message translates to:
  /// **'Windows didn\'t get permission, so nothing changed.'**
  String get audioToolsSystemCancelled;

  /// No description provided for @audioToolsSystemFailed.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t work, and the mic was left as it was.'**
  String get audioToolsSystemFailed;

  /// No description provided for @audioToolsSystemRestart.
  ///
  /// In en, this message translates to:
  /// **'Almost there: restart your PC so Windows picks up the change.'**
  String get audioToolsSystemRestart;

  /// No description provided for @audioToolsSystemNoDevice.
  ///
  /// In en, this message translates to:
  /// **'That microphone isn\'t connected right now.'**
  String get audioToolsSystemNoDevice;

  /// No description provided for @audioToolsSystemIncompatible.
  ///
  /// In en, this message translates to:
  /// **'Windows won\'t run luma\'s EQ on this mic, so luma put it back exactly as it was. It still works normally. You can keep using the EQ inside luma.'**
  String get audioToolsSystemIncompatible;

  /// No description provided for @audioToolsSystemMicSilent.
  ///
  /// In en, this message translates to:
  /// **'luma couldn\'t record from this mic to test it, so nothing changed. Close apps that might have it to themselves and check Windows lets apps use the microphone.'**
  String get audioToolsSystemMicSilent;

  /// No description provided for @audioToolsSystemMissing.
  ///
  /// In en, this message translates to:
  /// **'Parts of luma are missing. Reinstall luma and try again.'**
  String get audioToolsSystemMissing;

  /// No description provided for @audioToolsSystemNoMic.
  ///
  /// In en, this message translates to:
  /// **'No microphone found. Plug one in and refresh the device list.'**
  String get audioToolsSystemNoMic;

  /// No description provided for @assistantAddMenu.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get assistantAddMenu;

  /// No description provided for @assistantModePlan.
  ///
  /// In en, this message translates to:
  /// **'Plan mode'**
  String get assistantModePlan;

  /// No description provided for @assistantModePlanHint.
  ///
  /// In en, this message translates to:
  /// **'Get a plan before anything happens'**
  String get assistantModePlanHint;

  /// No description provided for @assistantModeResearch.
  ///
  /// In en, this message translates to:
  /// **'Deep research'**
  String get assistantModeResearch;

  /// No description provided for @assistantModeResearchHint.
  ///
  /// In en, this message translates to:
  /// **'Several agents dig in, then report back'**
  String get assistantModeResearchHint;

  /// No description provided for @assistantModeResearchUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Switch to Nebula, Pulsar or Luma Assistant'**
  String get assistantModeResearchUnavailable;

  /// No description provided for @assistantModePicture.
  ///
  /// In en, this message translates to:
  /// **'Picture'**
  String get assistantModePicture;

  /// No description provided for @assistantModePictureHint.
  ///
  /// In en, this message translates to:
  /// **'Draw an image · uses {percent}% of your weekly limit'**
  String assistantModePictureHint(int percent);

  /// No description provided for @assistantModePictureUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Needs a signed-in luma account'**
  String get assistantModePictureUnavailable;

  /// No description provided for @assistantModeOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get assistantModeOff;

  /// No description provided for @assistantPlanComposerHint.
  ///
  /// In en, this message translates to:
  /// **'What should I plan?'**
  String get assistantPlanComposerHint;

  /// No description provided for @assistantResearchComposerHint.
  ///
  /// In en, this message translates to:
  /// **'What should the agents research?'**
  String get assistantResearchComposerHint;

  /// No description provided for @assistantPictureComposerHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the picture'**
  String get assistantPictureComposerHint;

  /// No description provided for @assistantResearchPlanning.
  ///
  /// In en, this message translates to:
  /// **'Planning the research…'**
  String get assistantResearchPlanning;

  /// No description provided for @assistantResearchProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} agents done'**
  String assistantResearchProgress(int done, int total);

  /// No description provided for @assistantResearchParallel.
  ///
  /// In en, this message translates to:
  /// **'Agents working side by side'**
  String get assistantResearchParallel;

  /// No description provided for @assistantResearchSequential.
  ///
  /// In en, this message translates to:
  /// **'Agents taking turns on this device'**
  String get assistantResearchSequential;

  /// No description provided for @assistantResearchWriting.
  ///
  /// In en, this message translates to:
  /// **'Writing up the answer…'**
  String get assistantResearchWriting;

  /// No description provided for @assistantPictureDrawing.
  ///
  /// In en, this message translates to:
  /// **'Drawing your picture…'**
  String get assistantPictureDrawing;

  /// No description provided for @assistantPictureMissing.
  ///
  /// In en, this message translates to:
  /// **'This picture isn\'t on this device'**
  String get assistantPictureMissing;

  /// No description provided for @textLibraryMcMailbox.
  ///
  /// In en, this message translates to:
  /// **'Mailbox'**
  String get textLibraryMcMailbox;

  /// No description provided for @textLibraryMcMailWaiting.
  ///
  /// In en, this message translates to:
  /// **'Letters waiting: {count}'**
  String textLibraryMcMailWaiting(String count);

  /// No description provided for @textLibraryMcMailNext.
  ///
  /// In en, this message translates to:
  /// **'Next letter in {minutes} min'**
  String textLibraryMcMailNext(String minutes);

  /// No description provided for @textLibraryMcTakeLetter.
  ///
  /// In en, this message translates to:
  /// **'Take the letter'**
  String get textLibraryMcTakeLetter;

  /// No description provided for @textLibraryMcNewMail.
  ///
  /// In en, this message translates to:
  /// **'You\'ve got mail!'**
  String get textLibraryMcNewMail;

  /// No description provided for @textLibraryMcNewMailBody.
  ///
  /// In en, this message translates to:
  /// **'A letter is waiting in the mailbox'**
  String get textLibraryMcNewMailBody;

  /// No description provided for @textLibraryMcLetterOpen.
  ///
  /// In en, this message translates to:
  /// **'Click the letter to open it'**
  String get textLibraryMcLetterOpen;

  /// No description provided for @textLibraryMcLetterTitle.
  ///
  /// In en, this message translates to:
  /// **'Dear reader,'**
  String get textLibraryMcLetterTitle;

  /// No description provided for @textLibraryMcLetterBody.
  ///
  /// In en, this message translates to:
  /// **'Thank you for keeping the library. Here is a little something for your vault.'**
  String get textLibraryMcLetterBody;

  /// No description provided for @textLibraryMcLetterSign.
  ///
  /// In en, this message translates to:
  /// **'— The Library Post'**
  String get textLibraryMcLetterSign;

  /// No description provided for @textLibraryMcLetterTake.
  ///
  /// In en, this message translates to:
  /// **'Take the coins'**
  String get textLibraryMcLetterTake;

  /// No description provided for @textLibraryMcCoins.
  ///
  /// In en, this message translates to:
  /// **'{count} coins'**
  String textLibraryMcCoins(String count);

  /// No description provided for @textLibraryMcHandHint.
  ///
  /// In en, this message translates to:
  /// **'Put the coins in your vault, in the bookcase by the fire'**
  String get textLibraryMcHandHint;

  /// No description provided for @textLibraryMcVault.
  ///
  /// In en, this message translates to:
  /// **'Vault'**
  String get textLibraryMcVault;

  /// No description provided for @textLibraryMcVaultOpen.
  ///
  /// In en, this message translates to:
  /// **'Open the vault'**
  String get textLibraryMcVaultOpen;

  /// No description provided for @textLibraryMcVaultPut.
  ///
  /// In en, this message translates to:
  /// **'Put {count} coins in the vault'**
  String textLibraryMcVaultPut(String count);

  /// No description provided for @textLibraryMcVaultDeposited.
  ///
  /// In en, this message translates to:
  /// **'+{count} coins put away'**
  String textLibraryMcVaultDeposited(String count);

  /// No description provided for @textLibraryMcVaultEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing in here yet. The post brings coins every half hour.'**
  String get textLibraryMcVaultEmpty;

  /// No description provided for @textLibraryMcTraderName.
  ///
  /// In en, this message translates to:
  /// **'Wandering Trader'**
  String get textLibraryMcTraderName;

  /// No description provided for @textLibraryMcTraderArrived.
  ///
  /// In en, this message translates to:
  /// **'A wandering trader has arrived'**
  String get textLibraryMcTraderArrived;

  /// No description provided for @textLibraryMcTraderArrivedBody.
  ///
  /// In en, this message translates to:
  /// **'His stall is open in front of the house'**
  String get textLibraryMcTraderArrivedBody;

  /// No description provided for @textLibraryMcTraderLeaving.
  ///
  /// In en, this message translates to:
  /// **'The trader is packing up'**
  String get textLibraryMcTraderLeaving;

  /// No description provided for @textLibraryMcTraderLeavingBody.
  ///
  /// In en, this message translates to:
  /// **'He leaves in {minutes} min'**
  String textLibraryMcTraderLeavingBody(String minutes);

  /// No description provided for @textLibraryMcTraderGone.
  ///
  /// In en, this message translates to:
  /// **'The wandering trader has moved on'**
  String get textLibraryMcTraderGone;

  /// No description provided for @textLibraryMcTraderTrade.
  ///
  /// In en, this message translates to:
  /// **'Trade with the wandering trader'**
  String get textLibraryMcTraderTrade;

  /// No description provided for @textLibraryMcTraderStall.
  ///
  /// In en, this message translates to:
  /// **'Market stall'**
  String get textLibraryMcTraderStall;

  /// No description provided for @textLibraryMcTraderAway.
  ///
  /// In en, this message translates to:
  /// **'The trader is back in {minutes} min'**
  String textLibraryMcTraderAway(String minutes);

  /// No description provided for @textLibraryMcTraderBusy.
  ///
  /// In en, this message translates to:
  /// **'The trader is setting up'**
  String get textLibraryMcTraderBusy;

  /// No description provided for @textLibraryMcShopLeaves.
  ///
  /// In en, this message translates to:
  /// **'Leaves in {minutes} min'**
  String textLibraryMcShopLeaves(String minutes);

  /// No description provided for @textLibraryMcShopBuy.
  ///
  /// In en, this message translates to:
  /// **'Buy for {count} coins'**
  String textLibraryMcShopBuy(String count);

  /// No description provided for @textLibraryMcShopTooPoor.
  ///
  /// In en, this message translates to:
  /// **'Not enough coins'**
  String get textLibraryMcShopTooPoor;

  /// No description provided for @textLibraryMcShopOwned.
  ///
  /// In en, this message translates to:
  /// **'In your crate: {count}'**
  String textLibraryMcShopOwned(String count);

  /// No description provided for @textLibraryMcShopPlaced.
  ///
  /// In en, this message translates to:
  /// **'Placed: {count}'**
  String textLibraryMcShopPlaced(String count);

  /// No description provided for @textLibraryMcShopWallet.
  ///
  /// In en, this message translates to:
  /// **'{total} coins · in hand {hand} · in the vault {vault}'**
  String textLibraryMcShopWallet(String total, String hand, String vault);

  /// No description provided for @textLibraryMcShopBought.
  ///
  /// In en, this message translates to:
  /// **'Bought: {item}'**
  String textLibraryMcShopBought(String item);

  /// No description provided for @textLibraryMcShopBoughtBody.
  ///
  /// In en, this message translates to:
  /// **'Press B to place it'**
  String get textLibraryMcShopBoughtBody;

  /// No description provided for @textLibraryMcShopBoughtTouch.
  ///
  /// In en, this message translates to:
  /// **'Tap it in the hotbar to place it'**
  String get textLibraryMcShopBoughtTouch;

  /// No description provided for @textLibraryMcWhereInside.
  ///
  /// In en, this message translates to:
  /// **'For inside'**
  String get textLibraryMcWhereInside;

  /// No description provided for @textLibraryMcWhereOutside.
  ///
  /// In en, this message translates to:
  /// **'For outside'**
  String get textLibraryMcWhereOutside;

  /// No description provided for @textLibraryMcWhereBoth.
  ///
  /// In en, this message translates to:
  /// **'For inside or outside'**
  String get textLibraryMcWhereBoth;

  /// No description provided for @textLibraryMcItemBed.
  ///
  /// In en, this message translates to:
  /// **'Cosy bed'**
  String get textLibraryMcItemBed;

  /// No description provided for @textLibraryMcItemAquarium.
  ///
  /// In en, this message translates to:
  /// **'Aquarium'**
  String get textLibraryMcItemAquarium;

  /// No description provided for @textLibraryMcItemGramophone.
  ///
  /// In en, this message translates to:
  /// **'Gramophone'**
  String get textLibraryMcItemGramophone;

  /// No description provided for @textLibraryMcItemCandelabra.
  ///
  /// In en, this message translates to:
  /// **'Candelabra'**
  String get textLibraryMcItemCandelabra;

  /// No description provided for @textLibraryMcItemSwing.
  ///
  /// In en, this message translates to:
  /// **'Garden swing'**
  String get textLibraryMcItemSwing;

  /// No description provided for @textLibraryMcItemBirdbath.
  ///
  /// In en, this message translates to:
  /// **'Bird bath'**
  String get textLibraryMcItemBirdbath;

  /// No description provided for @textLibraryMcItemBeehive.
  ///
  /// In en, this message translates to:
  /// **'Beehive post'**
  String get textLibraryMcItemBeehive;

  /// No description provided for @textLibraryMcItemTelescope.
  ///
  /// In en, this message translates to:
  /// **'Telescope'**
  String get textLibraryMcItemTelescope;

  /// No description provided for @textLibraryMcDescBed.
  ///
  /// In en, this message translates to:
  /// **'A spruce bed with a patchwork quilt. You can lie down on it.'**
  String get textLibraryMcDescBed;

  /// No description provided for @textLibraryMcDescAquarium.
  ///
  /// In en, this message translates to:
  /// **'A lit fish tank with sand, kelp and three tropical fish.'**
  String get textLibraryMcDescAquarium;

  /// No description provided for @textLibraryMcDescGramophone.
  ///
  /// In en, this message translates to:
  /// **'Plays a little music-box tune when you click it.'**
  String get textLibraryMcDescGramophone;

  /// No description provided for @textLibraryMcDescCandelabra.
  ///
  /// In en, this message translates to:
  /// **'Wrought iron, with three flickering candles.'**
  String get textLibraryMcDescCandelabra;

  /// No description provided for @textLibraryMcDescSwing.
  ///
  /// In en, this message translates to:
  /// **'A slatted bench on chains that sways in the breeze. Sit on it.'**
  String get textLibraryMcDescSwing;

  /// No description provided for @textLibraryMcDescBirdbath.
  ///
  /// In en, this message translates to:
  /// **'A stone pedestal with a shallow basin of water.'**
  String get textLibraryMcDescBirdbath;

  /// No description provided for @textLibraryMcDescBeehive.
  ///
  /// In en, this message translates to:
  /// **'A bee nest on a post, with bees buzzing round it.'**
  String get textLibraryMcDescBeehive;

  /// No description provided for @textLibraryMcDescTelescope.
  ///
  /// In en, this message translates to:
  /// **'Look through it at the sky and the sea of clouds.'**
  String get textLibraryMcDescTelescope;

  /// No description provided for @textLibraryMcBuildHint.
  ///
  /// In en, this message translates to:
  /// **'Click to place · R to rotate · right-click a piece to pick it up · B when done'**
  String get textLibraryMcBuildHint;

  /// No description provided for @textLibraryMcBuildHintTouch.
  ///
  /// In en, this message translates to:
  /// **'Tap the ground to place it · walk with the arrows'**
  String get textLibraryMcBuildHintTouch;

  /// No description provided for @textLibraryMcPickHint.
  ///
  /// In en, this message translates to:
  /// **'Click a piece to put it back in your crate · B when done'**
  String get textLibraryMcPickHint;

  /// No description provided for @textLibraryMcCrateHint.
  ///
  /// In en, this message translates to:
  /// **'Press B to place your new furniture'**
  String get textLibraryMcCrateHint;

  /// No description provided for @textLibraryMcBuildRotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate (R)'**
  String get textLibraryMcBuildRotate;

  /// No description provided for @textLibraryMcBuildPick.
  ///
  /// In en, this message translates to:
  /// **'Pick up (X)'**
  String get textLibraryMcBuildPick;

  /// No description provided for @textLibraryMcBuildDone.
  ///
  /// In en, this message translates to:
  /// **'Done (B)'**
  String get textLibraryMcBuildDone;

  /// No description provided for @textLibraryMcCantPlace.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t fit there'**
  String get textLibraryMcCantPlace;

  /// No description provided for @textLibraryMcPutBack.
  ///
  /// In en, this message translates to:
  /// **'Back in your crate'**
  String get textLibraryMcPutBack;

  /// No description provided for @textLibraryMcPutBackBody.
  ///
  /// In en, this message translates to:
  /// **'{item} didn\'t fit any more'**
  String textLibraryMcPutBackBody(String item);

  /// No description provided for @textLibraryMcLieDown.
  ///
  /// In en, this message translates to:
  /// **'Lie down'**
  String get textLibraryMcLieDown;

  /// No description provided for @textLibraryMcPlayMusic.
  ///
  /// In en, this message translates to:
  /// **'Play a tune'**
  String get textLibraryMcPlayMusic;

  /// No description provided for @textLibraryMcStopMusic.
  ///
  /// In en, this message translates to:
  /// **'Stop the music'**
  String get textLibraryMcStopMusic;

  /// No description provided for @textLibraryMcLookThrough.
  ///
  /// In en, this message translates to:
  /// **'Look through the telescope'**
  String get textLibraryMcLookThrough;

  /// No description provided for @textLibraryMcStepBack.
  ///
  /// In en, this message translates to:
  /// **'Step back'**
  String get textLibraryMcStepBack;

  /// No description provided for @textLibraryMcScopeHint.
  ///
  /// In en, this message translates to:
  /// **'Move the mouse to look around · Shift or Space to step back'**
  String get textLibraryMcScopeHint;

  /// No description provided for @textLibraryMcPcTitle.
  ///
  /// In en, this message translates to:
  /// **'Library Review Desk'**
  String get textLibraryMcPcTitle;

  /// No description provided for @textLibraryMcPcUse.
  ///
  /// In en, this message translates to:
  /// **'Use the computer'**
  String get textLibraryMcPcUse;

  /// No description provided for @textLibraryMcPcIntro.
  ///
  /// In en, this message translates to:
  /// **'Send a book you wrote to the reviewer. A good book earns 1 to 50 coins; otherwise the letter brings tips to make it better.'**
  String get textLibraryMcPcIntro;

  /// No description provided for @textLibraryMcPcPick.
  ///
  /// In en, this message translates to:
  /// **'Pick a book to send:'**
  String get textLibraryMcPcPick;

  /// No description provided for @textLibraryMcPcNoBooks.
  ///
  /// In en, this message translates to:
  /// **'No books to send yet. Write one first.'**
  String get textLibraryMcPcNoBooks;

  /// No description provided for @textLibraryMcPcSend.
  ///
  /// In en, this message translates to:
  /// **'Send for review'**
  String get textLibraryMcPcSend;

  /// No description provided for @textLibraryMcPcSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get textLibraryMcPcSending;

  /// No description provided for @textLibraryMcPcSent.
  ///
  /// In en, this message translates to:
  /// **'Your book has been sent!'**
  String get textLibraryMcPcSent;

  /// No description provided for @textLibraryMcPcSentBody.
  ///
  /// In en, this message translates to:
  /// **'It will be evaluated. Expect a letter in your mailbox tomorrow, in about {minutes} min.'**
  String textLibraryMcPcSentBody(String minutes);

  /// No description provided for @textLibraryMcPcWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the review of \"{title}\"'**
  String textLibraryMcPcWaiting(String title);

  /// No description provided for @textLibraryMcPcWaitingBody.
  ///
  /// In en, this message translates to:
  /// **'The letter arrives in about {minutes} min. The reviewer reads one book at a time.'**
  String textLibraryMcPcWaitingBody(String minutes);

  /// No description provided for @textLibraryMcPcSame.
  ///
  /// In en, this message translates to:
  /// **'This version was already reviewed. Change the book to send it again.'**
  String get textLibraryMcPcSame;

  /// No description provided for @textLibraryMcPcFailed.
  ///
  /// In en, this message translates to:
  /// **'It could not be sent'**
  String get textLibraryMcPcFailed;

  /// No description provided for @textLibraryMcPcTimeout.
  ///
  /// In en, this message translates to:
  /// **'The reviewer took too long. Try again later.'**
  String get textLibraryMcPcTimeout;

  /// No description provided for @textLibraryMcPcLogOff.
  ///
  /// In en, this message translates to:
  /// **'Log off'**
  String get textLibraryMcPcLogOff;

  /// No description provided for @textLibraryMcReviewArrived.
  ///
  /// In en, this message translates to:
  /// **'Your book review came in'**
  String get textLibraryMcReviewArrived;

  /// No description provided for @textLibraryMcReviewArrivedBody.
  ///
  /// In en, this message translates to:
  /// **'The letter is in the mailbox'**
  String get textLibraryMcReviewArrivedBody;

  /// No description provided for @textLibraryMcReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'A review of \"{title}\"'**
  String textLibraryMcReviewTitle(String title);

  /// No description provided for @textLibraryMcReviewTips.
  ///
  /// In en, this message translates to:
  /// **'To make it better:'**
  String get textLibraryMcReviewTips;

  /// No description provided for @textLibraryMcReviewNoBetter.
  ///
  /// In en, this message translates to:
  /// **'It reads well, but it isn\'t better than last time, so there are no new coins.'**
  String get textLibraryMcReviewNoBetter;

  /// No description provided for @textLibraryMcReviewSign.
  ///
  /// In en, this message translates to:
  /// **'— The Library Review Desk'**
  String get textLibraryMcReviewSign;

  /// No description provided for @textLibraryMcReviewThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks'**
  String get textLibraryMcReviewThanks;

  /// No description provided for @textLibraryMcReviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'That book is empty.'**
  String get textLibraryMcReviewEmpty;

  /// No description provided for @textLibraryMcReviewSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to an approved luma account to send books for review.'**
  String get textLibraryMcReviewSignIn;

  /// No description provided for @textLibraryMcReviewUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the luma server. Check your connection and try again.'**
  String get textLibraryMcReviewUnreachable;

  /// No description provided for @textLibraryMcClassroom.
  ///
  /// In en, this message translates to:
  /// **'Classroom'**
  String get textLibraryMcClassroom;

  /// No description provided for @textLibraryMcClassLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get textLibraryMcClassLocked;

  /// No description provided for @textLibraryMcClassLockedNova.
  ///
  /// In en, this message translates to:
  /// **'The classroom is part of Nova'**
  String get textLibraryMcClassLockedNova;

  /// No description provided for @textLibraryMcClassLockedSignin.
  ///
  /// In en, this message translates to:
  /// **'Sign in to a luma account to open it'**
  String get textLibraryMcClassLockedSignin;

  /// No description provided for @textLibraryMcClassLockedOffline.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the luma server right now'**
  String get textLibraryMcClassLockedOffline;

  /// No description provided for @textLibraryMcClassDown.
  ///
  /// In en, this message translates to:
  /// **'Climb down to the cellar'**
  String get textLibraryMcClassDown;

  /// No description provided for @textLibraryMcClassUp.
  ///
  /// In en, this message translates to:
  /// **'Climb up the ladder'**
  String get textLibraryMcClassUp;

  /// No description provided for @textLibraryMcClassSit.
  ///
  /// In en, this message translates to:
  /// **'Sit down for a lesson'**
  String get textLibraryMcClassSit;

  /// No description provided for @textLibraryMcClassBoard.
  ///
  /// In en, this message translates to:
  /// **'Blackboard'**
  String get textLibraryMcClassBoard;

  /// No description provided for @textLibraryMcClassCountryTitle.
  ///
  /// In en, this message translates to:
  /// **'Which country do you go to school in?'**
  String get textLibraryMcClassCountryTitle;

  /// No description provided for @textLibraryMcClassCountryNote.
  ///
  /// In en, this message translates to:
  /// **'You can only set this once.'**
  String get textLibraryMcClassCountryNote;

  /// No description provided for @textLibraryMcClassCountryOther.
  ///
  /// In en, this message translates to:
  /// **'Somewhere else'**
  String get textLibraryMcClassCountryOther;

  /// No description provided for @textLibraryMcClassCountryName.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get textLibraryMcClassCountryName;

  /// No description provided for @textLibraryMcClassCountrySet.
  ///
  /// In en, this message translates to:
  /// **'Set country'**
  String get textLibraryMcClassCountrySet;

  /// No description provided for @textLibraryMcClassCountryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Set {name} as your country? You can\'t change it later.'**
  String textLibraryMcClassCountryConfirm(String name);

  /// No description provided for @textLibraryMcClassCountryIs.
  ///
  /// In en, this message translates to:
  /// **'Country: {name}'**
  String textLibraryMcClassCountryIs(String name);

  /// No description provided for @textLibraryMcClassSchool.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get textLibraryMcClassSchool;

  /// No description provided for @textLibraryMcClassYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get textLibraryMcClassYear;

  /// No description provided for @textLibraryMcClassLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get textLibraryMcClassLevel;

  /// No description provided for @textLibraryMcClassSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get textLibraryMcClassSubject;

  /// No description provided for @textLibraryMcClassPublisher.
  ///
  /// In en, this message translates to:
  /// **'Book (publisher)'**
  String get textLibraryMcClassPublisher;

  /// No description provided for @textLibraryMcClassChapter.
  ///
  /// In en, this message translates to:
  /// **'Chapter'**
  String get textLibraryMcClassChapter;

  /// No description provided for @textLibraryMcClassParagraph.
  ///
  /// In en, this message translates to:
  /// **'Paragraph'**
  String get textLibraryMcClassParagraph;

  /// No description provided for @textLibraryMcClassTopic.
  ///
  /// In en, this message translates to:
  /// **'What is the paragraph about?'**
  String get textLibraryMcClassTopic;

  /// No description provided for @textLibraryMcClassTopicHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Pythagoras\' theorem'**
  String get textLibraryMcClassTopicHint;

  /// No description provided for @textLibraryMcClassStart.
  ///
  /// In en, this message translates to:
  /// **'Start the lesson'**
  String get textLibraryMcClassStart;

  /// No description provided for @textLibraryMcClassNeedAll.
  ///
  /// In en, this message translates to:
  /// **'Fill in every field to start.'**
  String get textLibraryMcClassNeedAll;

  /// No description provided for @textLibraryMcClassAsking.
  ///
  /// In en, this message translates to:
  /// **'The teacher is writing a question…'**
  String get textLibraryMcClassAsking;

  /// No description provided for @textLibraryMcClassQuestion.
  ///
  /// In en, this message translates to:
  /// **'Question {number}'**
  String textLibraryMcClassQuestion(String number);

  /// No description provided for @textLibraryMcClassAnswerHint.
  ///
  /// In en, this message translates to:
  /// **'Your answer'**
  String get textLibraryMcClassAnswerHint;

  /// No description provided for @textLibraryMcClassNext.
  ///
  /// In en, this message translates to:
  /// **'Next question'**
  String get textLibraryMcClassNext;

  /// No description provided for @textLibraryMcClassPrev.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get textLibraryMcClassPrev;

  /// No description provided for @textLibraryMcClassSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get textLibraryMcClassSkip;

  /// No description provided for @textLibraryMcClassHandIn.
  ///
  /// In en, this message translates to:
  /// **'Hand in'**
  String get textLibraryMcClassHandIn;

  /// No description provided for @textLibraryMcClassLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get textLibraryMcClassLeave;

  /// No description provided for @textLibraryMcClassSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get textLibraryMcClassSkipped;

  /// No description provided for @textLibraryMcClassChecking.
  ///
  /// In en, this message translates to:
  /// **'The teacher is checking your work…'**
  String get textLibraryMcClassChecking;

  /// No description provided for @textLibraryMcClassNothing.
  ///
  /// In en, this message translates to:
  /// **'Answer at least one question first.'**
  String get textLibraryMcClassNothing;

  /// No description provided for @textLibraryMcClassHandInConfirm.
  ///
  /// In en, this message translates to:
  /// **'Hand in {count} answers? Skipped questions are not checked.'**
  String textLibraryMcClassHandInConfirm(String count);

  /// No description provided for @textLibraryMcClassLast.
  ///
  /// In en, this message translates to:
  /// **'That is the last question for this lesson.'**
  String get textLibraryMcClassLast;

  /// No description provided for @textLibraryMcClassCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get textLibraryMcClassCorrect;

  /// No description provided for @textLibraryMcClassPartly.
  ///
  /// In en, this message translates to:
  /// **'Partly right'**
  String get textLibraryMcClassPartly;

  /// No description provided for @textLibraryMcClassWrong.
  ///
  /// In en, this message translates to:
  /// **'Not right'**
  String get textLibraryMcClassWrong;

  /// No description provided for @textLibraryMcClassUnchecked.
  ///
  /// In en, this message translates to:
  /// **'Not checked'**
  String get textLibraryMcClassUnchecked;

  /// No description provided for @textLibraryMcClassScore.
  ///
  /// In en, this message translates to:
  /// **'{right} right, {partly} partly, {wrong} not'**
  String textLibraryMcClassScore(String right, String partly, String wrong);

  /// No description provided for @textLibraryMcClassYourAnswer.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get textLibraryMcClassYourAnswer;

  /// No description provided for @textLibraryMcClassModel.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get textLibraryMcClassModel;

  /// No description provided for @textLibraryMcClassAgain.
  ///
  /// In en, this message translates to:
  /// **'Same paragraph again'**
  String get textLibraryMcClassAgain;

  /// No description provided for @textLibraryMcClassNew.
  ///
  /// In en, this message translates to:
  /// **'New lesson'**
  String get textLibraryMcClassNew;

  /// No description provided for @textLibraryMcClassFailed.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t work'**
  String get textLibraryMcClassFailed;

  /// No description provided for @textLibraryMcClassRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get textLibraryMcClassRetry;

  /// No description provided for @textLibraryMcClassTimeout.
  ///
  /// In en, this message translates to:
  /// **'The teacher took too long. Try again.'**
  String get textLibraryMcClassTimeout;

  /// No description provided for @textLibraryMcClassCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get textLibraryMcClassCancel;

  /// No description provided for @textLibraryMcClassOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get textLibraryMcClassOk;
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
