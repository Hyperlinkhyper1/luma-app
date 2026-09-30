// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LEn extends L {
  LEn([String locale = 'en']) : super(locale);

  @override
  String get trayOpen => 'Open luma';

  @override
  String get trayQuit => 'Quit luma';

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
  String homeSaveFailed(String error) {
    return 'Could not save your home: $error';
  }

  @override
  String get homeAddSheetTitle => 'Make room for what matters';

  @override
  String get homeEditLayout => 'Edit layout';

  @override
  String get homeEditingTitle => 'Make yourself at home';

  @override
  String get homePhoneLayout => 'Phone layout';

  @override
  String get homeDesktopLayout => 'Desktop & laptop layout';

  @override
  String get homeResetDashboard => 'Reset to original dashboard';

  @override
  String get homeAddTile => 'Add tile';

  @override
  String get homeSaveLayout => 'Save layout';

  @override
  String get homeEdit => 'Edit home';

  @override
  String get homeDragHint =>
      'Drag a tile by its title. Drag its lower corner to resize. Everything snaps into place; overlapping tiles move down.';

  @override
  String get homeUnavailable => 'Unavailable';

  @override
  String get homeInspiration => 'A little inspiration';

  @override
  String get homeEditSummary => 'Edit summary';

  @override
  String get homeCashBalance => 'Cash balance';

  @override
  String get homeCustomText => 'Custom text';

  @override
  String get homeSummaryTitle => 'Greeting summary';

  @override
  String get homeSummaryDescription =>
      'Your greeting always stays at the top. Choose what appears beneath it.';

  @override
  String get homeShowInGreeting => 'Show in greeting';

  @override
  String get homeSummaryLabel => 'Label';

  @override
  String get homeSummaryLabelHint => 'Today’s focus';

  @override
  String get homeSummaryText => 'Text';

  @override
  String get homeSummaryTextHint => 'Make time for what matters.';

  @override
  String get homeApply => 'Apply';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get homeTileShortcut => 'App shortcut';

  @override
  String get homeTileRecentActivity => 'Recent activity';

  @override
  String get homeTileFinanceOverview => 'Finance overview';

  @override
  String get homeTilePinnedNote => 'Pinned note';

  @override
  String get homeTilePluginShortcut => 'Plugin shortcut';

  @override
  String get homeTileMinecraftInstance => 'Minecraft instance';

  @override
  String get homeTileErrands => 'Errands';

  @override
  String get homeTileStockChart => 'Stock chart';

  @override
  String get homeTileGithubActivity => 'GitHub activity';

  @override
  String get homeTileGithubIssues => 'GitHub issues';

  @override
  String get homeTileAiUsage => 'AI usage';

  @override
  String get homeTileCalculator => 'Calculator';

  @override
  String get homeTileClockDate => 'Clock & date';

  @override
  String get homeTileFocusTimer => 'Focus timer';

  @override
  String get homeTileQuickActions => 'Quick actions';

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
      'Your own API keys; provider credits and limits still apply';

  @override
  String get assistantUsageUnlimited => 'Unlimited in Luma';

  @override
  String get assistantUsageByModel => 'Messages by model';

  @override
  String get assistantUsageByModelSubtitle =>
      'Successful messages on this device, counted per model.';

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

  @override
  String get textLibraryBack => 'Back';

  @override
  String get textLibraryBodyHint => 'Write your text…';

  @override
  String get textLibraryBold => 'Bold';

  @override
  String get textLibraryCancel => 'Cancel';

  @override
  String get textLibraryClearFormatting => 'Clear formatting';

  @override
  String get textLibraryColor => 'Color';

  @override
  String get textLibraryCover => 'Cover';

  @override
  String get textLibraryCreate => 'Create';

  @override
  String get textLibraryDefaultInk => 'Default ink';

  @override
  String get textLibraryDelete => 'Delete';

  @override
  String textLibraryDeleteSubjectTitle(String name) {
    return 'Delete subject \"$name\"?';
  }

  @override
  String textLibraryDeleteSubjectBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count texts',
      one: 'one text',
      zero: 'no texts',
    );
    return 'Delete this subject and its $_temp0?';
  }

  @override
  String get textLibraryDeleteTextBody =>
      'This text will be permanently deleted.';

  @override
  String textLibraryDeleteTextTitle(String title) {
    return 'Delete \"$title\"?';
  }

  @override
  String textLibraryEdited(String date) {
    return 'Edited $date';
  }

  @override
  String get textLibraryInk => 'Ink';

  @override
  String get textLibraryItalic => 'Italic';

  @override
  String textLibraryMcBooks(String count) {
    return '$count books';
  }

  @override
  String get textLibraryMcBuild => 'Build';

  @override
  String get textLibraryMcBuiltIn => 'Built-in';

  @override
  String get textLibraryMcBurn => 'Burn';

  @override
  String get textLibraryMcBurnConfirm =>
      'Burn this book? This cannot be undone.';

  @override
  String get textLibraryMcChooseSlot => 'Choose a shelf slot';

  @override
  String get textLibraryMcDone => 'Done';

  @override
  String get textLibraryMcDownload => 'Download Minecraft assets';

  @override
  String get textLibraryMcDownloadFailed =>
      'Could not download Minecraft assets.';

  @override
  String get textLibraryMcDownloadNote =>
      'Minecraft assets are downloaded from Mojang and cached on this device.';

  @override
  String get textLibraryMcEmptyHall =>
      'Your hall is empty. Create a subject to begin.';

  @override
  String get textLibraryMcEmptySlot => 'Empty slot';

  @override
  String get textLibraryMcFailedAndroid =>
      'Could not open the Minecraft library on Android.';

  @override
  String get textLibraryMcFailedWindows =>
      'Could not open the Minecraft library on Windows.';

  @override
  String get textLibraryMcLoading => 'Loading Minecraft library…';

  @override
  String get textLibraryMcLost => 'The Minecraft library connection was lost.';

  @override
  String get textLibraryMcMoveHint => 'Move this book to another shelf.';

  @override
  String get textLibraryMcNewCase => 'New case';

  @override
  String get textLibraryMcNewCaseTitle => 'Create a case';

  @override
  String textLibraryMcPage(String page, String total) {
    return 'Page $page of $total';
  }

  @override
  String get textLibraryMcQuality => 'Render quality';

  @override
  String get textLibraryMcQualityHigh => 'High';

  @override
  String get textLibraryMcQualityLow => 'Low';

  @override
  String get textLibraryMcRedo => 'Redo';

  @override
  String get textLibraryMcRetry => 'Retry';

  @override
  String get textLibraryMcSaveFailed => 'Could not save the book.';

  @override
  String get textLibraryMcSettings => 'Hall settings';

  @override
  String textLibraryMcShelfPage(String page, String total) {
    return 'Shelf page $page of $total';
  }

  @override
  String get textLibraryMcSign => 'Sign book';

  @override
  String get textLibraryMcSignAndShelve => 'Sign and shelve';

  @override
  String get textLibraryMcSignTitle => 'Sign this book?';

  @override
  String get textLibraryMcTime => 'Time';

  @override
  String get textLibraryMcTimeClock => 'My clock';

  @override
  String get textLibraryMcTimeCycle => 'Day and night';

  @override
  String get textLibraryMcTimeDay => 'Always day';

  @override
  String get textLibraryMcTimeNight => 'Always night';

  @override
  String get textLibraryMcUndo => 'Undo';

  @override
  String get textLibraryMcUntitled => 'Untitled';

  @override
  String textLibraryMcVanilla(String version) {
    return 'Minecraft $version';
  }

  @override
  String get textLibraryMcWalkHint =>
      'WASD to walk · click to look around · click a bookcase, chair or door to use it · Esc frees the mouse';

  @override
  String get textLibraryMcLookHint => 'Click to look around';

  @override
  String get textLibraryMcStandHint => 'Shift or Space to stand up';

  @override
  String get textLibraryMcStandUp => 'Stand up';

  @override
  String get textLibraryMcSit => 'Sit down';

  @override
  String get textLibraryMcOpenDoor => 'Open the door';

  @override
  String get textLibraryMcCloseDoor => 'Close the door';

  @override
  String get textLibraryMcShapes => 'Shapes';

  @override
  String get textLibraryMcShapeCircle => 'Circle';

  @override
  String get textLibraryMcShapeSquare => 'Square';

  @override
  String get textLibraryMcShapeTriangle => 'Triangle';

  @override
  String get textLibraryMcShapeStar => 'Star';

  @override
  String get textLibraryMcShapeHeart => 'Heart';

  @override
  String get textLibraryMcShapeLine => 'Line';

  @override
  String get textLibraryMcShapeFill => 'Filled or outline';

  @override
  String get textLibraryMcDrawHint =>
      'drag on the page to draw it · right-click a drawing to remove it';

  @override
  String textLibraryMcSkinCurrent(String name) {
    return 'Skin: $name';
  }

  @override
  String get textLibraryMcSkinDefault => 'Default skin';

  @override
  String get textLibraryMcSkinYours => 'your own';

  @override
  String get textLibraryMcSkinImport => 'Import skin…';

  @override
  String get textLibraryMcSkinName => 'Minecraft name…';

  @override
  String get textLibraryMcSkinNameTitle => 'Your Minecraft username';

  @override
  String get textLibraryMcSkinNameHint => 'Username';

  @override
  String get textLibraryMcSkinUse => 'Use skin';

  @override
  String get textLibraryMcSkinFailed => 'Couldn\'t load that skin.';

  @override
  String get textLibraryMcWriteHint => 'Write your book here…';

  @override
  String get textLibraryModeClassic => 'Classic';

  @override
  String get textLibraryModeMinecraft => 'Minecraft hall';

  @override
  String get textLibraryMoveTo => 'Move to';

  @override
  String get textLibraryMoveToTitle => 'Move text to a subject';

  @override
  String get textLibraryNewSubject => 'New subject';

  @override
  String get textLibraryNewText => 'New text';

  @override
  String textLibraryNoMatches(String query) {
    return 'No texts match \"$query\"';
  }

  @override
  String get textLibraryNoSubjects => 'No subjects yet';

  @override
  String get textLibraryNoSubjectsSub =>
      'Create a subject to organize your texts.';

  @override
  String get textLibraryNoTexts => 'No texts yet';

  @override
  String get textLibraryNoTextsSub =>
      'Add a text to this subject to get started.';

  @override
  String get textLibraryRename => 'Rename';

  @override
  String get textLibraryRenameSubject => 'Rename subject';

  @override
  String get textLibrarySave => 'Save';

  @override
  String get textLibrarySaved => 'Saved';

  @override
  String get textLibrarySaving => 'Saving…';

  @override
  String get textLibrarySearchHint => 'Search texts';

  @override
  String get textLibrarySpineHint => 'A short label shown on the book spine';

  @override
  String get textLibrarySpineLabel => 'Spine label';

  @override
  String get textLibraryStrike => 'Strikethrough';

  @override
  String get textLibrarySubjectNameHint => 'Subject name';

  @override
  String get textLibrarySubjectNameRequired => 'Enter a subject name.';

  @override
  String get textLibrarySubjects => 'Subjects';

  @override
  String textLibraryTextCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count texts',
      one: '1 text',
    );
    return '$_temp0';
  }

  @override
  String get textLibraryTitleHint => 'Title';

  @override
  String get textLibraryUnderline => 'Underline';

  @override
  String get audioToolsTitle => 'Audio Tools';

  @override
  String get audioToolsSubtitle =>
      'Shape your voice with an equalizer and send it to Discord, OBS or any app that takes a microphone.';

  @override
  String get audioToolsWindowsOnly => 'Windows only';

  @override
  String get audioToolsWindowsOnlyBody =>
      'Audio Tools routes your microphone in real time, which luma can only do in the Windows desktop app.';

  @override
  String get audioToolsStart => 'Start';

  @override
  String get audioToolsStop => 'Stop';

  @override
  String get audioToolsLive => 'Live';

  @override
  String get audioToolsOff => 'Off';

  @override
  String get audioToolsRouting => 'Routing';

  @override
  String get audioToolsMicrophone => 'Microphone';

  @override
  String get audioToolsSendTo => 'Send to';

  @override
  String audioToolsWindowsDefault(String name) {
    return 'Windows default ($name)';
  }

  @override
  String get audioToolsWindowsDefaultPlain => 'Windows default';

  @override
  String get audioToolsRefreshDevices => 'Refresh devices';

  @override
  String get audioToolsVirtualCableTag => 'Virtual cable';

  @override
  String get audioToolsNotACable =>
      'This output is a speaker, not a virtual cable, so other apps won\'t hear it as a microphone.';

  @override
  String get audioToolsHearMyself => 'Hear myself';

  @override
  String get audioToolsHearMyselfBody =>
      'Also play the result on your default speakers or headset.';

  @override
  String get audioToolsBypass => 'Bypass equalizer';

  @override
  String get audioToolsBypassBody =>
      'Send your voice through untouched, to compare.';

  @override
  String get audioToolsAutoStart => 'Start with luma';

  @override
  String get audioToolsAutoStartBody =>
      'Turn the voice changer on as soon as luma opens.';

  @override
  String get audioToolsDiscordTitle => 'Use it in Discord';

  @override
  String get audioToolsCableFound => 'Virtual cable found';

  @override
  String get audioToolsCableMissingTitle => 'One-time setup: a virtual cable';

  @override
  String get audioToolsCableMissingBody =>
      'Windows can\'t add a new microphone without a driver, so luma sends your processed voice through a free virtual cable. Install VB-CABLE once, then come back here. Discord, OBS and games will see it as a microphone.';

  @override
  String get audioToolsGetCable => 'Get VB-CABLE';

  @override
  String get audioToolsInstalledCheck => 'I installed it';

  @override
  String audioToolsStepSendTo(String device) {
    return 'Set Send to to $device.';
  }

  @override
  String get audioToolsUseCable => 'Use it';

  @override
  String audioToolsStepDiscord(String device) {
    return 'In Discord, open Settings → Voice & Video and set Input Device to $device.';
  }

  @override
  String get audioToolsStepStart =>
      'Press Start. If the effect sounds washed out, turn off Discord\'s noise suppression.';

  @override
  String get audioToolsErrDeviceMissing =>
      'That audio device isn\'t connected any more. Pick another one.';

  @override
  String get audioToolsErrDeviceInUse =>
      'Another app is using that device in exclusive mode.';

  @override
  String get audioToolsErrDeviceLost =>
      'The audio device was disconnected, so the voice changer stopped.';

  @override
  String get audioToolsErrMicBlocked =>
      'Windows is blocking the microphone. Turn on \"Let desktop apps access your microphone\" in Privacy settings.';

  @override
  String get audioToolsErrFailed =>
      'Couldn\'t start audio. Try another device.';

  @override
  String get audioToolsOpenSettings => 'Open settings';

  @override
  String get audioToolsDismiss => 'Dismiss';

  @override
  String get audioToolsEqualizer => 'Equalizer';

  @override
  String get audioToolsReset => 'Reset';

  @override
  String get audioToolsEqHint =>
      'Drag a point to shape your voice. Scroll over the graph to make the selected band wider or narrower.';

  @override
  String get audioToolsPreamp => 'Preamp';

  @override
  String get audioToolsFrequency => 'Frequency';

  @override
  String get audioToolsGain => 'Gain';

  @override
  String get audioToolsWidth => 'Width (Q)';

  @override
  String get audioToolsBandOn => 'On';

  @override
  String get audioToolsTypeHighPass => 'Low cut';

  @override
  String get audioToolsTypeLowShelf => 'Low shelf';

  @override
  String get audioToolsTypePeak => 'Bell';

  @override
  String get audioToolsTypeHighShelf => 'High shelf';

  @override
  String get audioToolsTypeLowPass => 'High cut';

  @override
  String get audioToolsPresetFlat => 'Flat';

  @override
  String get audioToolsPresetClear => 'Clear';

  @override
  String get audioToolsPresetDeep => 'Deep';

  @override
  String get audioToolsPresetRadio => 'Radio';

  @override
  String get audioToolsPresetTelephone => 'Telephone';

  @override
  String get audioToolsPresetMegaphone => 'Megaphone';

  @override
  String get audioToolsPresetMuffled => 'Through a wall';

  @override
  String get audioToolsPresetTiny => 'Tiny';

  @override
  String get audioToolsPresetCustom => 'Custom';

  @override
  String get audioToolsSystemTitle => 'Use it in Discord';

  @override
  String audioToolsSystemBody(String mic) {
    return 'luma can put the EQ on $mic itself, so Discord, OBS and games hear it with no extra software. Windows asks for admin permission once, and sound drops out for a second while it switches over.';
  }

  @override
  String get audioToolsSystemEnable => 'Turn on for this mic';

  @override
  String audioToolsSystemActive(String mic) {
    return 'On for $mic';
  }

  @override
  String get audioToolsSystemPaused => 'Paused';

  @override
  String get audioToolsSystemEveryApp => 'EQ in every app';

  @override
  String get audioToolsSystemEveryAppBody =>
      'Pausing needs no admin permission and keeps everything set up.';

  @override
  String audioToolsSystemDiscordHint(String mic) {
    return 'In Discord, keep $mic as your input device. If the EQ sounds washed out, turn off Discord\'s noise suppression and automatic gain control.';
  }

  @override
  String get audioToolsSystemOutdated =>
      'luma updated its EQ engine. Apply the update to keep this mic in sync.';

  @override
  String get audioToolsSystemUpdate => 'Update';

  @override
  String get audioToolsSystemRemove => 'Turn off and restore';

  @override
  String get audioToolsSystemCancelled =>
      'Windows didn\'t get permission, so nothing changed.';

  @override
  String get audioToolsSystemFailed =>
      'That didn\'t work, and the mic was left as it was.';

  @override
  String get audioToolsSystemRestart =>
      'Almost there: restart your PC so Windows picks up the change.';

  @override
  String get audioToolsSystemNoDevice =>
      'That microphone isn\'t connected right now.';

  @override
  String get audioToolsSystemMissing =>
      'Parts of luma are missing. Reinstall luma and try again.';

  @override
  String get audioToolsSystemNoMic =>
      'No microphone found. Plug one in and refresh the device list.';

  @override
  String get assistantAddMenu => 'Add';

  @override
  String get assistantModePlan => 'Plan mode';

  @override
  String get assistantModePlanHint => 'Get a plan before anything happens';

  @override
  String get assistantModeResearch => 'Deep research';

  @override
  String get assistantModeResearchHint =>
      'Several agents dig in, then report back';

  @override
  String get assistantModeResearchUnavailable =>
      'Switch to Nebula, Pulsar or Luma Assistant';

  @override
  String get assistantModePicture => 'Picture';

  @override
  String assistantModePictureHint(int percent) {
    return 'Draw an image · uses $percent% of your weekly limit';
  }

  @override
  String get assistantModePictureUnavailable =>
      'Needs a signed-in luma account';

  @override
  String get assistantModeOff => 'Turn off';

  @override
  String get assistantPlanComposerHint => 'What should I plan?';

  @override
  String get assistantResearchComposerHint =>
      'What should the agents research?';

  @override
  String get assistantPictureComposerHint => 'Describe the picture';

  @override
  String get assistantResearchPlanning => 'Planning the research…';

  @override
  String assistantResearchProgress(int done, int total) {
    return '$done of $total agents done';
  }

  @override
  String get assistantResearchParallel => 'Agents working side by side';

  @override
  String get assistantResearchSequential =>
      'Agents taking turns on this device';

  @override
  String get assistantResearchWriting => 'Writing up the answer…';

  @override
  String get assistantPictureDrawing => 'Drawing your picture…';

  @override
  String get assistantPictureMissing => 'This picture isn\'t on this device';
}
