// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LEn extends L {
  LEn([String locale = 'en']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navFileConverter => 'File Converter';

  @override
  String get navFinance => 'Finance';

  @override
  String get navPasswordManager => 'Password Manager';

  @override
  String get navNotes => 'Notes';

  @override
  String get navAssistant => 'Assistant';

  @override
  String get navPlugins => 'Plugins';

  @override
  String get navSettings => 'Settings';

  @override
  String get navAccount => 'Account';

  @override
  String get navConvert => 'Convert';

  @override
  String get navVault => 'Vault';

  @override
  String get navMore => 'More';

  @override
  String get shellPluginUnavailable => 'This plugin isn\'t here';

  @override
  String get shellStorageLimitMsg =>
      'You\'re out of space. Clear a little out and we\'ll start saving and syncing again.';

  @override
  String get shellStorageManage => 'Clean up';

  @override
  String get shellStorageDismiss => 'Not now';

  @override
  String get settingsAppearance => 'Look & feel';

  @override
  String get settingsAppearanceSub => 'Make luma yours.';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsAccentColor => 'Colour';

  @override
  String get settingsThemeStyle => 'Theme style';

  @override
  String get settingsThemeStyleDefault => 'Default';

  @override
  String get settingsThemeStyleDefaultSub =>
      'Good old luma — plain and simple, in your colour.';

  @override
  String get settingsThemeStyleCoffee => 'Coffee';

  @override
  String get settingsThemeStyleCoffeeSub =>
      'Warm browns, soft corners, little coffee beans floating around.';

  @override
  String get settingsThemeStyleLocked => 'Orbit or Nova';

  @override
  String get settingsThemeStyleUpgrade =>
      'Coffee comes with Orbit and Nova. Grab one of those to turn it on.';

  @override
  String get settingsAccentCoffeeNote =>
      'Coffee has its own colours, so you can\'t pick a colour while it\'s on.';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsGeneralSub => 'Small things that change how the app acts.';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsOpenOnLaunch => 'Open on launch';

  @override
  String get settingsHideAmounts => 'Hide money on Home';

  @override
  String get settingsHideAmountsSub =>
      'Hide your money on Home, in case someone\'s peeking over your shoulder.';

  @override
  String get settingsLockPasswords => 'Lock passwords';

  @override
  String get settingsLockPasswordsSub =>
      'Ask for an 8-digit PIN before showing your saved logins.';

  @override
  String get settingsAmericanGpa => 'American grades';

  @override
  String get settingsAmericanGpaSub =>
      'Use American 4.0 grades in School instead of Dutch 1-to-10s.';

  @override
  String get settingsAiAssistant => 'AI Assistant';

  @override
  String get settingsAiAssistantSub =>
      'Pop in your own Anthropic key to start chatting.';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsResetDefaults => 'Put everything back';

  @override
  String get settingsResetTitle => 'Start fresh?';

  @override
  String get settingsResetContent =>
      'This puts your theme, colour and other little picks back to how they were at the start.';

  @override
  String get settingsResetCancel => 'Keep mine';

  @override
  String get settingsResetConfirm => 'Yep, reset';

  @override
  String get settingsCheckUpdates => 'Look for updates';

  @override
  String get settingsSystem => 'System';

  @override
  String get settingsLight => 'Light';

  @override
  String get settingsDark => 'Dark';

  @override
  String get langEnglish => 'English';

  @override
  String get langDutch => 'Nederlands';

  @override
  String get langChinese => '中文';

  @override
  String get langSpanish => 'Español';

  @override
  String get langFrench => 'Français';

  @override
  String get langSystemDefault => 'System';

  @override
  String get homeGreetingMorning => 'Good morning';

  @override
  String get homeGreetingAfternoon => 'Hey there';

  @override
  String get homeGreetingEvening => 'Good evening';

  @override
  String get homeNetWorth => 'All together';

  @override
  String get homeAtAGlance => 'How things look';

  @override
  String get homeJumpBackIn => 'Pick up where you left off';

  @override
  String get homeRecentActivity => 'What you\'ve been up to';

  @override
  String get homeIncomeMonth => 'Came in this month';

  @override
  String get homeSpentMonth => 'Went out this month';

  @override
  String get homeInPots => 'Set aside in pots';

  @override
  String get homeInvestments => 'Investments';

  @override
  String get homeAskAssistant => 'Ask Assistant';

  @override
  String get homeAskAssistantSub => 'Have a chat, ask anything';

  @override
  String get homeFinance => 'Finance';

  @override
  String get homeFinanceSub => 'Your money, pots & stocks';

  @override
  String get homeFileConverter => 'File Converter';

  @override
  String get homeFileConverterSub => 'Change up images & files';

  @override
  String get homeSettings => 'Settings';

  @override
  String get homeSettingsSub => 'Colours, theme & stuff';

  @override
  String get homeNoTransactions =>
      'Quiet here for now — add something in Finance and it\'ll pop up here.';

  @override
  String get homeIncome => 'In';

  @override
  String get homeExpense => 'Out';

  @override
  String get homeAllocation => 'Split';

  @override
  String get pinEnterNew => 'Pick a new 8-digit PIN';

  @override
  String get pinVerify => 'Type it once more';

  @override
  String get pinEnterDisable => 'Type your PIN to turn it off';

  @override
  String get pinNotMatch => 'Those PINs don\'t match.';

  @override
  String get pinIncorrect => 'Nope, wrong PIN.';

  @override
  String aboutVersionRelease(String version) {
    return 'Version $version · a small app that keeps your stuff with you';
  }

  @override
  String get aboutVersionDev =>
      'Dev build · made with care on someone\'s laptop';

  @override
  String get monthJan => 'Jan';

  @override
  String get monthFeb => 'Feb';

  @override
  String get monthMar => 'Mar';

  @override
  String get monthApr => 'Apr';

  @override
  String get monthMay => 'May';

  @override
  String get monthJun => 'Jun';

  @override
  String get monthJul => 'Jul';

  @override
  String get monthAug => 'Aug';

  @override
  String get monthSep => 'Sep';

  @override
  String get monthOct => 'Oct';

  @override
  String get monthNov => 'Nov';

  @override
  String get monthDec => 'Dec';

  @override
  String get weekdayMon => 'Monday';

  @override
  String get weekdayTue => 'Tuesday';

  @override
  String get weekdayWed => 'Wednesday';

  @override
  String get weekdayThu => 'Thursday';

  @override
  String get weekdayFri => 'Friday';

  @override
  String get weekdaySat => 'Saturday';

  @override
  String get weekdaySun => 'Sunday';

  @override
  String planSuffix(String name) {
    return '$name plan';
  }
}
