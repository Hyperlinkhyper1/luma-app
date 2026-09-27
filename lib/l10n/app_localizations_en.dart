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
  String get settingsOpenSourceLicenses => 'Open source licences';

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
  String get petSearchHint => 'Search plugins and pages';

  @override
  String get petMoodIdle => 'What are we opening?';

  @override
  String get petMoodCurious => 'Ooh, let me look…';

  @override
  String get petMoodHappy => 'That tickles.';

  @override
  String get petMoodDelighted => 'Best day ever!';

  @override
  String get petMoodSleepy => 'Still up? Me too.';

  @override
  String get petNoResults => 'Nothing by that name';

  @override
  String get petNoResultsHint => 'Try a shorter word, or just part of one.';

  @override
  String get petSectionJumpTo => 'JUMP TO';

  @override
  String get petSectionResults => 'RESULTS';

  @override
  String get petKindPlugin => 'Plugin';

  @override
  String get petKindPage => 'Page';

  @override
  String get petHintMove => 'move';

  @override
  String get petHintOpen => 'open';

  @override
  String get petHintClose => 'close';

  @override
  String get petClose => 'Close';

  @override
  String get petPatsTooltip => 'Pats given';

  @override
  String petPatLabel(String name) {
    return 'Pat $name';
  }

  @override
  String get petSettingsTitle => 'luma pet';

  @override
  String get petSettingsSubtitle =>
      'Press the shortcut anywhere to summon the pet, then type to jump to any page or plugin.';

  @override
  String get petSettingsHotkey => 'Summon from anywhere';

  @override
  String get petSettingsHotkeyTaken =>
      'Another app already owns this shortcut, so it only works while luma is in front. Pick a different one below.';

  @override
  String get petSettingsRebind => 'Change';

  @override
  String get petSettingsRebindTitle => 'Press a new shortcut';

  @override
  String get petSettingsRebindSave => 'Use it';

  @override
  String get petSettingsName => 'Name';

  @override
  String get petSettingsSummon => 'Open the pet now';

  @override
  String get petSettingsSummonHint =>
      'Brings the panel up straight away — no keyboard shortcut needed.';

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

  @override
  String get assistantNewChat => 'New chat';

  @override
  String get assistantSearchChats => 'Search chats';

  @override
  String get assistantStarred => 'Starred';

  @override
  String get assistantRecents => 'Recents';

  @override
  String get assistantNoChats => 'No chats yet';

  @override
  String get assistantNoMatches => 'No chats match';

  @override
  String get assistantGreetingMorning => 'Good morning';

  @override
  String get assistantGreetingAfternoon => 'Good afternoon';

  @override
  String get assistantGreetingEvening => 'Good evening';

  @override
  String assistantGreetingMorningName(String name) {
    return 'Good morning, $name';
  }

  @override
  String assistantGreetingAfternoonName(String name) {
    return 'Good afternoon, $name';
  }

  @override
  String assistantGreetingEveningName(String name) {
    return 'Good evening, $name';
  }

  @override
  String get assistantHowCanIHelp => 'How can I help you today?';

  @override
  String get assistantReplyHint => 'Reply to luma…';

  @override
  String get assistantOutOfMessages => 'You\'re out of messages for now';

  @override
  String get assistantCopy => 'Copy';

  @override
  String get assistantCopied => 'Copied';

  @override
  String get assistantStar => 'Star';

  @override
  String get assistantUnstar => 'Unstar';

  @override
  String get assistantRename => 'Rename';

  @override
  String get assistantDelete => 'Delete';

  @override
  String get assistantSuggestPlugin => 'Find a plugin';

  @override
  String get assistantSuggestQr => 'Make a QR code';

  @override
  String get assistantSuggestWeek => 'Plan my week';

  @override
  String get assistantSuggestNote => 'Write a note';

  @override
  String get assistantSuggestPluginPrompt =>
      'Which luma plugin would help me with ';

  @override
  String get assistantSuggestQrPrompt => 'Make a QR code for ';

  @override
  String get assistantSuggestWeekPrompt => 'What\'s on my calendar this week?';

  @override
  String get assistantSuggestNotePrompt => 'Save a note that says ';

  @override
  String get assistantToggleSidebar => 'Toggle sidebar';

  @override
  String get assistantChats => 'Chats';

  @override
  String get assistantUsage => 'Usage';

  @override
  String get assistantContextWindow => 'Context window';

  @override
  String get assistantUsageLimits => 'Usage limits';

  @override
  String get assistantFiveHourLimit => '5-hour limit';

  @override
  String get assistantWeeklyLimit => 'Weekly';

  @override
  String get assistantDailyMessages => 'Today';

  @override
  String assistantMessagesOf(int used, int limit) {
    return '$used of $limit messages';
  }

  @override
  String get assistantLastReply => 'Last reply';

  @override
  String assistantTokensInOut(String input, String output) {
    return '$input in · $output out';
  }

  @override
  String get assistantNoLimits => 'Runs on this device — no usage limits';

  @override
  String get assistantUsageUnavailable =>
      'Usage unavailable — check your connection';

  @override
  String get assistantDetailedBreakdown => 'See detailed breakdown';

  @override
  String get assistantNoRepliesYet => 'No replies in this chat yet';

  @override
  String get assistantMenuUsage => 'Usage';

  @override
  String get assistantMenuSettings => 'Settings';

  @override
  String get assistantMenuAgents => 'Agents';

  @override
  String get assistantYourUsage => 'Your usage';

  @override
  String get assistantUsageHeadlinePlenty => 'Plenty of room left. Chat away.';

  @override
  String get assistantUsageHeadlineOnTrack =>
      'You\'re on track, with room to spare.';

  @override
  String get assistantUsageHeadlineClose =>
      'Heads up. You\'re close to a limit.';

  @override
  String get assistantUsageHeadlineOut =>
      'You\'ve hit a limit. It frees up again as the window rolls on.';

  @override
  String get assistantUsageLumaAi => 'Luma AI';

  @override
  String get assistantUsageLumaAiSubtitle =>
      'Aurora, Nebula and Pulsar, through your luma account';

  @override
  String get assistantUsageCurrentSession => 'Current session';

  @override
  String get assistantUsageRollingFiveHours => 'Rolling 5-hour window';

  @override
  String get assistantUsageThisWeek => 'This week';

  @override
  String get assistantUsageRollingWeek => 'Rolling 7-day window';

  @override
  String get assistantUsageLumaAssistant => 'Luma Assistant';

  @override
  String get assistantUsageLumaAssistantSubtitle => 'On-device Qwen model';

  @override
  String get assistantUsageWebSearch => 'Web searches';

  @override
  String assistantUsageCountOf(int used, int limit) {
    return '$used of $limit';
  }

  @override
  String assistantUsagePercentUsed(int percent) {
    return '$percent% used';
  }

  @override
  String get assistantUsageLumaSupport => 'Luma Support';

  @override
  String get assistantUsageResetsDaily => 'Resets at midnight';

  @override
  String get assistantUsageApiKeys => 'Your API keys';

  @override
  String get assistantUsageApiKeysSubtitle =>
      'Anthropic Claude and OpenAI with your own key, on this device';

  @override
  String get assistantUsageByModel => 'Messages by model';

  @override
  String get assistantUsageByModelSubtitle =>
      'All time on this device. ×5 and ×20 mark the heavier models.';

  @override
  String assistantUsageMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
    );
    return '$_temp0';
  }

  @override
  String get assistantUsageNoMessages => 'No messages yet';

  @override
  String get assistantUsageStorage => 'Storage';

  @override
  String get assistantUsageMemoryStorage => 'Assistant memory';

  @override
  String get assistantUsageMemoryStorageCaption =>
      'Syncs with your account on every plan and counts toward server storage';

  @override
  String get assistantUsageServerStorage => 'Server storage';

  @override
  String assistantUsageStorageOf(String used, String quota) {
    return '$used of $quota';
  }

  @override
  String get assistantSettingsChat => 'Chat';

  @override
  String get assistantSettingsMemory => 'Memory';

  @override
  String get assistantSettingsUser => 'User';

  @override
  String get assistantSettingsLanguage => 'Response language';

  @override
  String get assistantSettingsLanguageHint =>
      'The language the assistant answers you in.';

  @override
  String get assistantSettingsLanguageAuto => 'Match my language';

  @override
  String get assistantSettingsFont => 'Font';

  @override
  String get assistantSettingsFontHint =>
      'The typeface the assistant\'s replies are set in.';

  @override
  String get assistantFontSerif => 'Serif';

  @override
  String get assistantFontSans => 'Sans';

  @override
  String get assistantFontMono => 'Mono';

  @override
  String get assistantSettingsTextSize => 'Text size';

  @override
  String get assistantSettingsTextSizeHint => 'Size of the conversation text.';

  @override
  String get assistantTextSmall => 'Small';

  @override
  String get assistantTextMedium => 'Medium';

  @override
  String get assistantTextLarge => 'Large';

  @override
  String get assistantSettingsPreview => 'Preview';

  @override
  String get assistantSettingsPreviewText =>
      'Here\'s how replies will look. **Bold**, *italic* and `code` all follow your choice.';

  @override
  String get assistantMemoryUse => 'Use memory';

  @override
  String get assistantMemoryUseHint =>
      'Let the assistant remember things about you across chats, and bring them up when they help.';

  @override
  String assistantMemorySyncNote(String size) {
    return 'Synced to your account on every plan · $size of server storage';
  }

  @override
  String get assistantMemoryAdd => 'Add memory';

  @override
  String get assistantMemoryEdit => 'Edit memory';

  @override
  String get assistantMemoryEmpty => 'Nothing remembered yet';

  @override
  String get assistantMemoryEmptyHint =>
      'Tell the assistant about yourself in a chat, or add a memory here.';

  @override
  String get assistantMemoryYou => 'You';

  @override
  String get assistantMemoryTopics => 'Topics';

  @override
  String get assistantMemoryAreas => 'Areas';

  @override
  String assistantMemoryUpdated(String date) {
    return 'Updated $date';
  }

  @override
  String get assistantMemoryClear => 'Delete all memory';

  @override
  String get assistantMemoryClearTitle => 'Delete all memory?';

  @override
  String get assistantMemoryClearBody =>
      'The assistant forgets everything it remembered, on every device. Your profile on the User tab stays.';

  @override
  String get assistantMemoryTitle => 'Title';

  @override
  String get assistantMemoryTitleHint => 'e.g. Hardware';

  @override
  String get assistantMemoryDescription => 'Summary';

  @override
  String get assistantMemoryDescriptionHint => 'One line, shown in the list';

  @override
  String get assistantMemoryBody => 'What to remember';

  @override
  String get assistantMemoryBodyHint => 'One fact per line';

  @override
  String get assistantProfileCallMe => 'What should the assistant call you?';

  @override
  String get assistantProfileCallMeHint => 'Your name or nickname';

  @override
  String get assistantProfileOccupation => 'What do you do?';

  @override
  String get assistantProfileOccupationHint =>
      'e.g. student, indie game developer';

  @override
  String get assistantProfileSummary => 'About you';

  @override
  String get assistantProfileSummaryHint =>
      'A few sentences the assistant should always know';

  @override
  String get assistantProfileInstructions =>
      'How should the assistant respond?';

  @override
  String get assistantProfileInstructionsHint =>
      'e.g. keep it short, explain code step by step';

  @override
  String get assistantProfileSave => 'Save';

  @override
  String get assistantProfileSaved => 'Saved';

  @override
  String get assistantAgentsComingSoon => 'Coming soon';

  @override
  String get assistantAgentsSubtitle =>
      'Agents you\'ve built in the AI Usage plugin. Running them from the assistant is coming soon.';

  @override
  String get assistantAgentsEmpty => 'No agents yet';

  @override
  String get assistantAgentsEmptyHint =>
      'Build one in the AI Usage plugin\'s Agents tab and it shows up here.';

  @override
  String get assistantAgentsOpenBuilder => 'Open AI Usage';

  @override
  String get assistantAgentsNoDescription => 'No description';
}
