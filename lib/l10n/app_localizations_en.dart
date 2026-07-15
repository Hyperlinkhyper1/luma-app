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
  String get shellPluginUnavailable => 'Plugin unavailable';

  @override
  String get shellStorageLimitMsg =>
      'You\'ve reached your storage limit. New data won\'t be saved or synced until you free up space.';

  @override
  String get shellStorageManage => 'Manage';

  @override
  String get shellStorageDismiss => 'Dismiss';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsAppearanceSub => 'Make luma feel like yours.';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsAccentColor => 'Accent color';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsGeneralSub => 'How the app behaves.';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsOpenOnLaunch => 'Open on launch';

  @override
  String get settingsHideAmounts => 'Hide amounts on Home';

  @override
  String get settingsHideAmountsSub =>
      'Mask balances on the dashboard for shoulder-surfers.';

  @override
  String get settingsLockPasswords => 'Lock Passwords';

  @override
  String get settingsLockPasswordsSub =>
      'Require an 8-digit PIN to view or edit saved credentials.';

  @override
  String get settingsAmericanGpa => 'American GPA scale';

  @override
  String get settingsAmericanGpaSub =>
      'Use the US 4.0 GPA system in the School plugin instead of the Dutch 1-10 grading scale.';

  @override
  String get settingsAiAssistant => 'AI Assistant';

  @override
  String get settingsAiAssistantSub => 'Connect your own Anthropic API key.';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsResetDefaults => 'Reset to defaults';

  @override
  String get settingsResetTitle => 'Reset settings?';

  @override
  String get settingsResetContent =>
      'This restores the theme, accent color and other preferences to their defaults.';

  @override
  String get settingsResetCancel => 'Cancel';

  @override
  String get settingsResetConfirm => 'Reset';

  @override
  String get settingsCheckUpdates => 'Check for updates';

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
  String get homeGreetingAfternoon => 'Good afternoon';

  @override
  String get homeGreetingEvening => 'Good evening';

  @override
  String get homeNetWorth => 'Net worth';

  @override
  String get homeAtAGlance => 'At a glance';

  @override
  String get homeJumpBackIn => 'Jump back in';

  @override
  String get homeRecentActivity => 'Recent activity';

  @override
  String get homeIncomeMonth => 'Income this month';

  @override
  String get homeSpentMonth => 'Spent this month';

  @override
  String get homeInPots => 'In pots';

  @override
  String get homeInvestments => 'Investments';

  @override
  String get homeAskAssistant => 'Ask Assistant';

  @override
  String get homeAskAssistantSub => 'Chat with the AI assistant';

  @override
  String get homeFinance => 'Finance';

  @override
  String get homeFinanceSub => 'Budgets, pots & stocks';

  @override
  String get homeFileConverter => 'File Converter';

  @override
  String get homeFileConverterSub => 'Convert images & files';

  @override
  String get homeSettings => 'Settings';

  @override
  String get homeSettingsSub => 'Theme, colors & more';

  @override
  String get homeNoTransactions =>
      'Nothing here yet — add a transaction in the Finance tab and it will show up here.';

  @override
  String get homeIncome => 'Income';

  @override
  String get homeExpense => 'Expense';

  @override
  String get homeAllocation => 'Allocation';

  @override
  String get homeTabDashboard => 'Dashboard';

  @override
  String get homeTabStats => 'Stats';

  @override
  String get homeStatsTitle => 'Plugin download stats';

  @override
  String get homeStatsTotalDownloads => 'Total downloads';

  @override
  String get homeStatsPluginsInstalled => 'Plugins installed';

  @override
  String get homeStatsPlugin => 'Plugin';

  @override
  String get homeStatsDownloads => 'Downloads';

  @override
  String get homeStatsNoPlugins =>
      'No plugins installed yet. Download a plugin from the Plugins tab to see stats here.';

  @override
  String get homeStatsBrowsePlugins => 'Browse plugins';

  @override
  String get pinEnterNew => 'Enter new 8-digit PIN';

  @override
  String get pinVerify => 'Verify new PIN';

  @override
  String get pinEnterDisable => 'Enter PIN to disable';

  @override
  String get pinNotMatch => 'PINs do not match.';

  @override
  String get pinIncorrect => 'Incorrect PIN.';

  @override
  String aboutVersionRelease(String version) {
    return 'Version $version · a clean local utility';
  }

  @override
  String get aboutVersionDev => 'Dev build · a clean local utility';

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
