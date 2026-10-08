// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LEn extends L {
  LEn([String locale = 'en']) : super(locale);

  @override
  String get settingsTrackBackendAiUsage => 'Track backend AI usage';

  @override
  String get settingsTrackBackendAiUsageSub =>
      'Include new calls made by app features through the Luma server in AI Usage. Off by default.';

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
  String get tabClose => 'Close tab';

  @override
  String get tabNew => 'New tab';

  @override
  String get tabOpenPlugin => 'Open another plugin';

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
  String get textLibraryMcOpenDrawer => 'Open the drawer';

  @override
  String get textLibraryMcCloseDrawer => 'Close the drawer';

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
    return 'luma can put the EQ on $mic itself, so Discord, OBS and games hear it with no extra software. Windows asks for admin permission once. Sound drops out for a few seconds while luma switches over and checks the mic still works, and if it doesn\'t, luma puts it straight back.';
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
  String get audioToolsSystemIncompatible =>
      'Windows won\'t run luma\'s EQ on this mic, so luma put it back exactly as it was. It still works normally. You can keep using the EQ inside luma.';

  @override
  String get audioToolsSystemMicSilent =>
      'luma couldn\'t record from this mic to test it, so nothing changed. Close apps that might have it to themselves and check Windows lets apps use the microphone.';

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

  @override
  String get textLibraryMcMailbox => 'Mailbox';

  @override
  String textLibraryMcMailWaiting(String count) {
    return 'Letters waiting: $count';
  }

  @override
  String textLibraryMcMailNext(String minutes) {
    return 'Next letter in $minutes min';
  }

  @override
  String get textLibraryMcTakeLetter => 'Take the letter';

  @override
  String get textLibraryMcNewMail => 'You\'ve got mail!';

  @override
  String get textLibraryMcNewMailBody => 'A letter is waiting in the mailbox';

  @override
  String get textLibraryMcLetterOpen => 'Click the letter to open it';

  @override
  String get textLibraryMcLetterTitle => 'Dear reader,';

  @override
  String get textLibraryMcLetterBody =>
      'Thank you for keeping the library. Here is a little something for your vault.';

  @override
  String get textLibraryMcLetterSign => '— The Library Post';

  @override
  String get textLibraryMcLetterTake => 'Take the coins';

  @override
  String textLibraryMcCoins(String count) {
    return '$count coins';
  }

  @override
  String get textLibraryMcHandHint =>
      'Put the coins in your vault, in the bookcase by the fire';

  @override
  String get textLibraryMcVault => 'Vault';

  @override
  String get textLibraryMcVaultOpen => 'Open the vault';

  @override
  String textLibraryMcVaultPut(String count) {
    return 'Put $count coins in the vault';
  }

  @override
  String textLibraryMcVaultDeposited(String count) {
    return '+$count coins put away';
  }

  @override
  String get textLibraryMcVaultEmpty =>
      'Nothing in here yet. The post brings coins every half hour.';

  @override
  String get textLibraryMcTraderName => 'Wandering Trader';

  @override
  String get textLibraryMcTraderArrived => 'A wandering trader has arrived';

  @override
  String get textLibraryMcTraderArrivedBody =>
      'His stall is open in front of the house';

  @override
  String get textLibraryMcTraderLeaving => 'The trader is packing up';

  @override
  String textLibraryMcTraderLeavingBody(String minutes) {
    return 'He leaves in $minutes min';
  }

  @override
  String get textLibraryMcTraderGone => 'The wandering trader has moved on';

  @override
  String get textLibraryMcTraderTrade => 'Trade with the wandering trader';

  @override
  String get textLibraryMcTraderStall => 'Market stall';

  @override
  String textLibraryMcTraderAway(String minutes) {
    return 'The trader is back in $minutes min';
  }

  @override
  String get textLibraryMcTraderBusy => 'The trader is setting up';

  @override
  String get textLibraryMcPetDog => 'Pet the dog';

  @override
  String get textLibraryMcPetCat => 'Pet the cat';

  @override
  String get textLibraryMcPetFish => 'Feed the fish';

  @override
  String textLibraryMcShopLeaves(String minutes) {
    return 'Leaves in $minutes min';
  }

  @override
  String textLibraryMcShopBuy(String count) {
    return 'Buy for $count coins';
  }

  @override
  String get textLibraryMcShopTooPoor => 'Not enough coins';

  @override
  String textLibraryMcShopOwned(String count) {
    return 'In your crate: $count';
  }

  @override
  String textLibraryMcShopPlaced(String count) {
    return 'Placed: $count';
  }

  @override
  String textLibraryMcShopWallet(String total, String hand, String vault) {
    return '$total coins · in hand $hand · in the vault $vault';
  }

  @override
  String textLibraryMcShopBought(String item) {
    return 'Bought: $item';
  }

  @override
  String get textLibraryMcShopBoughtBody => 'Press B to place it';

  @override
  String get textLibraryMcShopBoughtTouch => 'Tap it in the hotbar to place it';

  @override
  String get textLibraryMcWhereInside => 'For inside';

  @override
  String get textLibraryMcWhereOutside => 'For outside';

  @override
  String get textLibraryMcWhereBoth => 'For inside or outside';

  @override
  String get textLibraryMcItemBed => 'Cosy bed';

  @override
  String get textLibraryMcItemAquarium => 'Aquarium';

  @override
  String get textLibraryMcItemGramophone => 'Gramophone';

  @override
  String get textLibraryMcItemCandelabra => 'Candelabra';

  @override
  String get textLibraryMcItemSwing => 'Garden swing';

  @override
  String get textLibraryMcItemBirdbath => 'Bird bath';

  @override
  String get textLibraryMcItemBeehive => 'Beehive post';

  @override
  String get textLibraryMcItemTelescope => 'Telescope';

  @override
  String get textLibraryMcDescBed =>
      'A spruce bed with a patchwork quilt. You can lie down on it.';

  @override
  String get textLibraryMcDescAquarium =>
      'A lit fish tank with sand, kelp and three tropical fish.';

  @override
  String get textLibraryMcDescGramophone =>
      'Plays a little music-box tune when you click it.';

  @override
  String get textLibraryMcDescCandelabra =>
      'Wrought iron, with three flickering candles.';

  @override
  String get textLibraryMcDescSwing =>
      'A slatted bench on chains that sways in the breeze. Sit on it.';

  @override
  String get textLibraryMcDescBirdbath =>
      'A stone pedestal with a shallow basin of water.';

  @override
  String get textLibraryMcDescBeehive =>
      'A bee nest on a post, with bees buzzing round it.';

  @override
  String get textLibraryMcDescTelescope =>
      'Look through it at the sky and the sea of clouds.';

  @override
  String get textLibraryMcBuildHint =>
      'Click to place · R to rotate · right-click a piece to pick it up · B when done';

  @override
  String get textLibraryMcBuildHintTouch =>
      'Tap the ground to place it · walk with the arrows';

  @override
  String get textLibraryMcPickHint =>
      'Click a piece to put it back in your crate · B when done';

  @override
  String get textLibraryMcCrateHint => 'Press B to place your new furniture';

  @override
  String get textLibraryMcBuildRotate => 'Rotate (R)';

  @override
  String get textLibraryMcBuildPick => 'Pick up (X)';

  @override
  String get textLibraryMcBuildDone => 'Done (B)';

  @override
  String get textLibraryMcCantPlace => 'That doesn\'t fit there';

  @override
  String get textLibraryMcPutBack => 'Back in your crate';

  @override
  String textLibraryMcPutBackBody(String item) {
    return '$item didn\'t fit any more';
  }

  @override
  String get textLibraryMcLieDown => 'Lie down';

  @override
  String get textLibraryMcPlayMusic => 'Play a tune';

  @override
  String get textLibraryMcStopMusic => 'Stop the music';

  @override
  String get textLibraryMcLookThrough => 'Look through the telescope';

  @override
  String get textLibraryMcStepBack => 'Step back';

  @override
  String get textLibraryMcScopeHint =>
      'Move the mouse to look around · Shift or Space to step back';

  @override
  String get textLibraryMcPcTitle => 'Library Review Desk';

  @override
  String get textLibraryMcPcUse => 'Use the computer';

  @override
  String get textLibraryMcPcIntro =>
      'Send a book you wrote to the reviewer. A good book earns 1 to 50 coins; otherwise the letter brings tips to make it better.';

  @override
  String get textLibraryMcPcPick => 'Pick a book to send:';

  @override
  String get textLibraryMcPcNoBooks => 'No books to send yet. Write one first.';

  @override
  String get textLibraryMcPcSend => 'Send for review';

  @override
  String get textLibraryMcPcSending => 'Sending…';

  @override
  String get textLibraryMcPcSent => 'Your book has been sent!';

  @override
  String textLibraryMcPcSentBody(String minutes) {
    return 'It will be evaluated. Expect a letter in your mailbox tomorrow, in about $minutes min.';
  }

  @override
  String textLibraryMcPcWaiting(String title) {
    return 'Waiting for the review of \"$title\"';
  }

  @override
  String textLibraryMcPcWaitingBody(String minutes) {
    return 'The letter arrives in about $minutes min. The reviewer reads one book at a time.';
  }

  @override
  String get textLibraryMcPcSame =>
      'This version was already reviewed. Change the book to send it again.';

  @override
  String get textLibraryMcPcFailed => 'It could not be sent';

  @override
  String get textLibraryMcPcTimeout =>
      'The reviewer took too long. Try again later.';

  @override
  String get textLibraryMcPcLogOff => 'Log off';

  @override
  String get textLibraryMcReviewArrived => 'Your book review came in';

  @override
  String get textLibraryMcReviewArrivedBody => 'The letter is in the mailbox';

  @override
  String textLibraryMcReviewTitle(String title) {
    return 'A review of \"$title\"';
  }

  @override
  String get textLibraryMcReviewTips => 'To make it better:';

  @override
  String get textLibraryMcReviewNoBetter =>
      'It reads well, but it isn\'t better than last time, so there are no new coins.';

  @override
  String get textLibraryMcReviewSign => '— The Library Review Desk';

  @override
  String get textLibraryMcReviewThanks => 'Thanks';

  @override
  String get textLibraryMcReviewEmpty => 'That book is empty.';

  @override
  String get textLibraryMcReviewSignIn =>
      'Sign in to an approved luma account to send books for review.';

  @override
  String get textLibraryMcReviewUnreachable =>
      'Could not reach the luma server. Check your connection and try again.';

  @override
  String get textLibraryMcClassroom => 'Classroom';

  @override
  String get textLibraryMcClassLocked => 'Locked';

  @override
  String get textLibraryMcClassLockedNova => 'The classroom is part of Nova';

  @override
  String get textLibraryMcClassLockedSignin =>
      'Sign in to a luma account to open it';

  @override
  String get textLibraryMcClassLockedOffline =>
      'Can\'t reach the luma server right now';

  @override
  String get textLibraryMcClassDown => 'Climb down to the cellar';

  @override
  String get textLibraryMcClassUp => 'Climb up the ladder';

  @override
  String get textLibraryMcClassSit => 'Sit down for a lesson';

  @override
  String get textLibraryMcClassBoard => 'Blackboard';

  @override
  String get textLibraryMcClassCountryTitle =>
      'Which country do you go to school in?';

  @override
  String get textLibraryMcClassCountryNote => 'You can only set this once.';

  @override
  String get textLibraryMcClassCountryOther => 'Somewhere else';

  @override
  String get textLibraryMcClassCountryName => 'Country';

  @override
  String get textLibraryMcClassCountrySet => 'Set country';

  @override
  String textLibraryMcClassCountryConfirm(String name) {
    return 'Set $name as your country? You can\'t change it later.';
  }

  @override
  String textLibraryMcClassCountryIs(String name) {
    return 'Country: $name';
  }

  @override
  String get textLibraryMcClassSchool => 'School';

  @override
  String get textLibraryMcClassYear => 'Year';

  @override
  String get textLibraryMcClassLevel => 'Level';

  @override
  String get textLibraryMcClassSubject => 'Subject';

  @override
  String get textLibraryMcClassPublisher => 'Book (publisher)';

  @override
  String get textLibraryMcClassChapter => 'Chapter';

  @override
  String get textLibraryMcClassParagraph => 'Paragraph';

  @override
  String get textLibraryMcClassTopic => 'What is the paragraph about?';

  @override
  String get textLibraryMcClassTopicHint => 'e.g. Pythagoras\' theorem';

  @override
  String get textLibraryMcClassStart => 'Start the lesson';

  @override
  String get textLibraryMcClassNeedAll => 'Fill in every field to start.';

  @override
  String get textLibraryMcClassAsking => 'The teacher is writing a question…';

  @override
  String textLibraryMcClassQuestion(String number) {
    return 'Question $number';
  }

  @override
  String get textLibraryMcClassAnswerHint => 'Your answer';

  @override
  String get textLibraryMcClassNext => 'Next question';

  @override
  String get textLibraryMcClassPrev => 'Previous';

  @override
  String get textLibraryMcClassSkip => 'Skip';

  @override
  String get textLibraryMcClassHandIn => 'Hand in';

  @override
  String get textLibraryMcClassLeave => 'Leave';

  @override
  String get textLibraryMcClassSkipped => 'Skipped';

  @override
  String get textLibraryMcClassChecking => 'The teacher is checking your work…';

  @override
  String get textLibraryMcClassNothing => 'Answer at least one question first.';

  @override
  String textLibraryMcClassHandInConfirm(String count) {
    return 'Hand in $count answers? Skipped questions are not checked.';
  }

  @override
  String get textLibraryMcClassLast =>
      'That is the last question for this lesson.';

  @override
  String get textLibraryMcClassCorrect => 'Correct';

  @override
  String get textLibraryMcClassPartly => 'Partly right';

  @override
  String get textLibraryMcClassWrong => 'Not right';

  @override
  String get textLibraryMcClassUnchecked => 'Not checked';

  @override
  String textLibraryMcClassScore(String right, String partly, String wrong) {
    return '$right right, $partly partly, $wrong not';
  }

  @override
  String get textLibraryMcClassYourAnswer => 'You';

  @override
  String get textLibraryMcClassModel => 'Answer';

  @override
  String get textLibraryMcClassAgain => 'Same paragraph again';

  @override
  String get textLibraryMcClassNew => 'New lesson';

  @override
  String get textLibraryMcClassFailed => 'That didn\'t work';

  @override
  String get textLibraryMcClassRetry => 'Try again';

  @override
  String get textLibraryMcClassTimeout =>
      'The teacher took too long. Try again.';

  @override
  String get textLibraryMcClassCancel => 'Cancel';

  @override
  String get textLibraryMcClassOk => 'OK';

  @override
  String get pluginAddToHomeScreen => 'Add to home screen';

  @override
  String get pluginAddToHomeScreenUnsupported =>
      'Your launcher can\'t add widgets from apps. Long-press your home screen, open Widgets and pick luma instead.';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonClose => 'Close';

  @override
  String get commonOk => 'OK';

  @override
  String get commonDone => 'Done';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonRename => 'Rename';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonTryAgain => 'Try again';

  @override
  String get commonBack => 'Back';

  @override
  String get commonNext => 'Next';

  @override
  String get commonPrevious => 'Previous';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonCopied => 'Copied';

  @override
  String get commonCopiedToClipboard => 'Copied to clipboard';

  @override
  String get commonPaste => 'Paste';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonSearchHint => 'Search…';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonOpen => 'Open';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonImport => 'Import';

  @override
  String get commonExport => 'Export';

  @override
  String get commonShare => 'Share';

  @override
  String get commonDownload => 'Download';

  @override
  String get commonUpload => 'Upload';

  @override
  String get commonSettings => 'Settings';

  @override
  String get commonName => 'Name';

  @override
  String get commonTitle => 'Title';

  @override
  String get commonDescription => 'Description';

  @override
  String get commonNotes => 'Notes';

  @override
  String get commonDate => 'Date';

  @override
  String get commonTime => 'Time';

  @override
  String get commonAmount => 'Amount';

  @override
  String get commonTotal => 'Total';

  @override
  String get commonAll => 'All';

  @override
  String get commonNone => 'None';

  @override
  String get commonOther => 'Other';

  @override
  String get commonUnknown => 'Unknown';

  @override
  String get commonUntitled => 'Untitled';

  @override
  String get commonOn => 'On';

  @override
  String get commonOff => 'Off';

  @override
  String get commonEnable => 'Enable';

  @override
  String get commonDisable => 'Disable';

  @override
  String get commonStart => 'Start';

  @override
  String get commonStop => 'Stop';

  @override
  String get commonPause => 'Pause';

  @override
  String get commonResume => 'Resume';

  @override
  String get commonReset => 'Reset';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonApply => 'Apply';

  @override
  String get commonSend => 'Send';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonRedo => 'Redo';

  @override
  String get commonMore => 'More';

  @override
  String get commonShowMore => 'Show more';

  @override
  String get commonShowLess => 'Show less';

  @override
  String get commonError => 'Error';

  @override
  String commonErrorDetail(String error) {
    return 'Something went wrong: $error';
  }

  @override
  String get commonSomethingWentWrong => 'Something went wrong';

  @override
  String get commonSaved => 'Saved';

  @override
  String get commonDeleted => 'Deleted';

  @override
  String get commonNothingHereYet => 'Nothing here yet';

  @override
  String get commonNoResults => 'No results';

  @override
  String get commonToday => 'Today';

  @override
  String get commonYesterday => 'Yesterday';

  @override
  String get commonTomorrow => 'Tomorrow';

  @override
  String get commonNever => 'Never';

  @override
  String get commonJustNow => 'Just now';

  @override
  String commonMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String commonHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String commonDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get commonRequired => 'Required';

  @override
  String get commonOptional => 'Optional';

  @override
  String get commonDetails => 'Details';

  @override
  String get commonHistory => 'History';

  @override
  String get commonOverview => 'Overview';

  @override
  String get commonPreview => 'Preview';

  @override
  String get commonHelp => 'Help';

  @override
  String get commonSelectAll => 'Select all';

  @override
  String get commonBrowse => 'Browse';

  @override
  String get commonChooseFile => 'Choose file';

  @override
  String get commonChooseFolder => 'Choose folder';

  @override
  String get commonInstall => 'Install';

  @override
  String get commonUninstall => 'Uninstall';

  @override
  String get commonUpdate => 'Update';

  @override
  String get commonSignIn => 'Sign in';

  @override
  String get commonSignOut => 'Sign out';

  @override
  String get commonEmail => 'Email';

  @override
  String get commonPassword => 'Password';

  @override
  String get commonUsername => 'Username';

  @override
  String get commonCategory => 'Category';

  @override
  String get commonType => 'Type';

  @override
  String get commonSize => 'Size';

  @override
  String get commonStatus => 'Status';

  @override
  String get commonPrice => 'Price';

  @override
  String get commonQuantity => 'Quantity';

  @override
  String get commonColor => 'Color';

  @override
  String get commonIcon => 'Icon';

  @override
  String get commonFilter => 'Filter';

  @override
  String get commonSort => 'Sort';

  @override
  String get commonAccountRequired => 'Account required';

  @override
  String get marketplaceLoadFailed => 'The plugin list wouldn\'t load';

  @override
  String get marketplaceEmpty => 'No plugins available yet';

  @override
  String marketplaceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plugins',
      one: '1 plugin',
    );
    return '$_temp0';
  }

  @override
  String get marketplaceNoMatches => 'Nothing matches those filters';

  @override
  String get marketplaceSearchHint => 'Look for a plugin...';

  @override
  String get marketplaceSortRelevance => 'Relevance';

  @override
  String get marketplaceSortNameAsc => 'Name (A-Z)';

  @override
  String get marketplaceSortNameDesc => 'Name (Z-A)';

  @override
  String marketplaceSortBy(String option) {
    return 'Sort by: $option';
  }

  @override
  String get marketplaceRemovePlugin => 'Remove plugin';

  @override
  String get marketplaceUpdateAvailable => 'Update available';

  @override
  String get marketplaceUpdating => 'Updating…';

  @override
  String get marketplaceDownloading => 'Downloading…';

  @override
  String get marketplaceUpdated => 'Updated';

  @override
  String get marketplaceInstalled => 'Installed';

  @override
  String get marketplaceAbout => 'About';

  @override
  String get marketplaceScreenshots => 'Screenshots';

  @override
  String marketplaceRepoUnreachable(String error) {
    return 'Could not reach the plugin repo. Check your connection.\n($error)';
  }

  @override
  String marketplaceRepoError(int status) {
    return 'Plugin repo returned an error ($status).';
  }

  @override
  String get pluginNameAccountOverview => 'Account Overview';

  @override
  String get pluginNameAiDetector => 'AI Detector';

  @override
  String get pluginNameAiUsage => 'AI Usage';

  @override
  String get pluginNameAirlineTycoon => 'Airline Tycoon';

  @override
  String get pluginNameAudioTools => 'Audio Tools';

  @override
  String get pluginNameAutoClicker => 'Auto Clicker';

  @override
  String get pluginNameBulletinBoard => 'Bulletin Board';

  @override
  String get pluginNameCalculator => 'Calculator';

  @override
  String get pluginNameCalendar => 'Calendar';

  @override
  String get pluginNameCardWallet => 'Card Wallet';

  @override
  String get pluginNameCityPlanner => 'City Planner';

  @override
  String get pluginNameCloudFiles => 'Cloud Files';

  @override
  String get pluginNameDataManagement => 'Data Management';

  @override
  String get pluginNameDeviceHealth => 'Device Health';

  @override
  String get pluginNameErrandManager => 'Errand Manager';

  @override
  String get pluginNameFileTree => 'File Tree';

  @override
  String get pluginNameFileViewer => 'File Viewer';

  @override
  String get pluginNameFreeSketch => 'Free Sketch';

  @override
  String get pluginNameGallery => 'Gallery';

  @override
  String get pluginNameGameTools => 'Game Tools';

  @override
  String get pluginNameGroceriesList => 'Groceries List';

  @override
  String get pluginNameMachineLearning => 'Machine Learning';

  @override
  String get pluginNameMindMap => 'Mind Map';

  @override
  String get pluginNameMinecraftLauncher => 'Minecraft Launcher';

  @override
  String get pluginNameMoodJournal => 'Mood Journal';

  @override
  String get pluginNameNfcTagEditor => 'NFC Tag Editor';

  @override
  String get pluginNamePriceTracker => 'Price Tracker';

  @override
  String get pluginNameQrCodeGenerator => 'QR Code Generator';

  @override
  String get pluginNameRecipeBook => 'Recipe Book';

  @override
  String get pluginNameSchool => 'School';

  @override
  String get pluginNameSecureChat => 'Chat';

  @override
  String get pluginNameServerTycoon => 'Server Hosting Tycoon';

  @override
  String get pluginNameSftp => 'SFTP';

  @override
  String get pluginNameSmallGames => 'Small Games';

  @override
  String get pluginNameSmartHome => 'Smart Home';

  @override
  String get pluginNameSpaceColony => 'Space Colony';

  @override
  String get pluginNameSubwayBuilder => 'Subway Builder';

  @override
  String get pluginNameTextLibrary => 'Text Library';

  @override
  String get pluginNameTransportTracker => 'Transport Tracker';

  @override
  String get pluginNameUsage => 'Usage';

  @override
  String get pluginNameWhiteboard => 'Whiteboard';

  @override
  String get pluginNameWifiSpeedTest => 'Wi-Fi Speed Test';

  @override
  String get pluginNameWorthCounter => 'Worth Counter';

  @override
  String get pluginNameYoutubeDownloader => 'Media Downloader';

  @override
  String get pluginTagUtility => 'Utility';

  @override
  String get pluginTagShopping => 'Shopping';

  @override
  String get pluginTagSystem => 'System';

  @override
  String get pluginTagDocuments => 'Documents';

  @override
  String get pluginTagProductivity => 'Productivity';

  @override
  String get pluginTagSync => 'Sync';

  @override
  String get pluginTagData => 'Data';

  @override
  String get pluginTagGames => 'Games';

  @override
  String get pluginTagSimulation => 'Simulation';

  @override
  String get pluginTagWellness => 'Wellness';

  @override
  String get pluginTagAnalytics => 'Analytics';

  @override
  String get pluginTagAi => 'AI';

  @override
  String get pluginTagWriting => 'Writing';

  @override
  String get pluginTagMedia => 'Media';

  @override
  String get pluginTagAudio => 'Audio';

  @override
  String get pluginTagAutomation => 'Automation';

  @override
  String get pluginTagEducation => 'Education';

  @override
  String get pluginTagNetwork => 'Network';

  @override
  String get pluginTagSocial => 'Social';

  @override
  String get pluginTagNova => 'Nova';

  @override
  String get pluginTagFood => 'Food';

  @override
  String get pluginTagPhotos => 'Photos';

  @override
  String get pluginTagTravel => 'Travel';

  @override
  String get pluginTagFinance => 'Finance';

  @override
  String get pluginTagDeveloper => 'Developer';

  @override
  String get pluginTagMinecraft => 'Minecraft';

  @override
  String get pluginTagPaid => 'Paid';

  @override
  String get pluginTagFree => 'Free';

  @override
  String get accountTabProfile => 'Profile';

  @override
  String get accountTabStats => 'Stats';

  @override
  String get accountProfileSubtitle => 'How you look on this device.';

  @override
  String get accountSyncTitle => 'Sync & account';

  @override
  String get accountSyncSubtitle =>
      'Your stuff on every device, plus devices linked to this one.';

  @override
  String get accountStorageTitle => 'Storage';

  @override
  String get accountStorageSubtitle => 'How much room luma takes up here.';

  @override
  String get accountPlanTitle => 'Plan';

  @override
  String get accountPlanSubtitle => 'What you picked and what is in it.';

  @override
  String get accountFamilySubtitle => 'Share your calendar with your people.';

  @override
  String get accountProfilePicture => 'Profile picture';

  @override
  String get accountProfilePictureNote =>
      'Only on this device — nobody else sees it.';

  @override
  String get accountChangePhoto => 'Change photo';

  @override
  String get accountChoosePhoto => 'Choose photo';

  @override
  String get accountLocalStorage => 'Local storage';

  @override
  String accountUsedLocally(String size) {
    return '$size used locally';
  }

  @override
  String get accountWhatUsingSpace => 'What\'s using space?';

  @override
  String get accountNothingCounted => 'Nothing counted yet.';

  @override
  String get accountChangePlan => 'Change plan';

  @override
  String get accountNoFamilyYet => 'No family yet';

  @override
  String get accountStartFamilyHint => 'Start one to share your calendar.';

  @override
  String get accountCreateFamily => 'Create a family';

  @override
  String get accountManageFamily => 'Manage family';

  @override
  String get familyTitle => 'Family';

  @override
  String get familyBackToAccount => 'Back to account';

  @override
  String get familyStartTitle => 'Start a family';

  @override
  String get familyStartSubtitle =>
      'Invite your people and plan things together.';

  @override
  String get familyNameLabel => 'Family name';

  @override
  String get familyEnterName => 'Enter a family name.';

  @override
  String get familyCreate => 'Create family';

  @override
  String familySlotsUsed(String used, String limit) {
    return '$used of $limit slots used';
  }

  @override
  String get familyMembers => 'Members';

  @override
  String get familyPendingInvites => 'Pending invites';

  @override
  String get familyInviteTitle => 'Invite by email';

  @override
  String get familyNoInvites => 'No invites waiting.';

  @override
  String get familyDeleteFamily => 'Delete family';

  @override
  String get familyLeaveFamily => 'Leave family';

  @override
  String get familyRemoveMemberTitle => 'Remove member?';

  @override
  String get familyRemoveMemberBody =>
      'They will lose access to shared events immediately.';

  @override
  String get familyLeaveTitle => 'Leave family?';

  @override
  String get familyLeaveBody => 'You will lose access to shared events.';

  @override
  String get familyLeaveConfirm => 'Leave';

  @override
  String get familyDeleteTitle => 'Delete family?';

  @override
  String get familyDeleteBody =>
      'This removes every member and every shared event. This cannot be undone.';

  @override
  String get familyRoleOwner => 'Owner';

  @override
  String get familyRoleYou => 'You';

  @override
  String get familyRoleMember => 'Member';

  @override
  String get familyPending => 'Pending';

  @override
  String get familyInviteInvalidEmail => 'Enter a valid email address.';

  @override
  String get familyInviteInfo =>
      'They\'ll see the invite in their inbox (top-right icon) the next time they open Luma.';

  @override
  String get familyInviteSend => 'Send invite';

  @override
  String get loginBarrierLabel => 'Sign in';

  @override
  String get loginEnterValidEmail => 'Enter a valid email address.';

  @override
  String get loginPasswordTooShort =>
      'Use at least 10 characters — this password protects your encrypted data.';

  @override
  String get loginEnterPassword => 'Enter your password.';

  @override
  String get loginPasswordsMismatch => 'Passwords do not match.';

  @override
  String get loginEmailNotVerified =>
      'Your email is not verified yet. We sent you a new code.';

  @override
  String get loginEnterSixDigitCode =>
      'Enter the 6-digit code from your email.';

  @override
  String get loginCouldNotOpenBrowser =>
      'Could not open your browser. Copy the link below and open it yourself.';

  @override
  String get loginSignInIncomplete => 'Sign-in did not complete.';

  @override
  String get loginChoosePassphrase => 'Choose a passphrase.';

  @override
  String get loginEnterPassphrase =>
      'Enter your luma passphrase to unlock your data.';

  @override
  String get loginPassphraseTooShort =>
      'Use at least 10 characters — this passphrase is what encrypts your data.';

  @override
  String get loginPassphrasesMismatch => 'Passphrases do not match.';

  @override
  String get loginPasswordResetDone =>
      'Your password was reset. Sign in with your new password.';

  @override
  String get loginLinkCopied => 'Link copied to your clipboard.';

  @override
  String get loginShow => 'Show';

  @override
  String get loginHide => 'Hide';

  @override
  String get loginWelcomeBack => 'Welcome back';

  @override
  String get loginMakeAccount => 'Make your account';

  @override
  String get loginSetUpLocalSync => 'Set up local-only sync';

  @override
  String get loginSignInSubtitle =>
      'Sign in and grab your stuff from your other devices.';

  @override
  String get loginCreateSubtitle =>
      'One account, every device — locked before it leaves this one.';

  @override
  String get loginLocalSubtitle =>
      'No server, no account. Devices pair directly over your own network.';

  @override
  String get loginCreateAccount => 'Create account';

  @override
  String get loginConfirmPassword => 'Confirm password';

  @override
  String get loginForgotPassword => 'Forgot password?';

  @override
  String get loginServerAddress => 'Server address';

  @override
  String get loginSetUp => 'Set up';

  @override
  String get loginUseLocalOnly => 'Use local-only sync';

  @override
  String get loginUseLumaAccount => 'Use a luma account instead';

  @override
  String get loginSelfHostedServer => 'Self-hosted server';

  @override
  String get loginContinueInBrowser => 'Continue in your browser';

  @override
  String loginOpenedInBrowser(String provider) {
    return 'We opened $provider in your browser. Finish up there, then come back — this page sorts itself out.';
  }

  @override
  String get loginYourProvider => 'your provider';

  @override
  String get loginReopenPage => 'Reopen the page';

  @override
  String get loginCopyLink => 'Copy link';

  @override
  String get loginCancelAndGoBack => 'Cancel and go back';

  @override
  String get loginOneLastThing => 'One last thing';

  @override
  String get loginUnlockYourData => 'Unlock your data';

  @override
  String loginNewAccountExplain(String provider) {
    return '$provider proved who you are, but it cannot unlock your data — nothing can except a passphrase only you know. Choose one now; you will need it on every device.';
  }

  @override
  String loginExistingAccountExplain(String provider) {
    return 'This account already exists, so $provider signed you straight into it. Enter the luma passphrase you set up — the same one you would type to sign in with a password.';
  }

  @override
  String get loginChoosePassphraseLabel => 'Choose a passphrase';

  @override
  String get loginYourPassphrase => 'Your luma passphrase';

  @override
  String get loginConfirmPassphrase => 'Confirm passphrase';

  @override
  String get loginUnlockAndSignIn => 'Unlock and sign in';

  @override
  String get loginUseDifferentAccount => 'Use a different account';

  @override
  String get loginAlmostThere => 'Almost there';

  @override
  String get loginNeedsApproval =>
      'Your account has to be approved before you can sign in.';

  @override
  String get loginBackToSignIn => 'Back to sign in';

  @override
  String get loginCheckYourEmail => 'Check your email';

  @override
  String loginCodeSentTo(String email) {
    return 'We sent a 6-digit code to $email. Enter it below to verify your account.';
  }

  @override
  String get loginSixDigitCode => '6-digit code';

  @override
  String get loginVerifyAndSignIn => 'Verify and sign in';

  @override
  String get loginSending => 'Sending…';

  @override
  String get loginResendCode => 'Resend code';

  @override
  String get loginUseDifferentEmail => 'Use a different email';

  @override
  String get loginForgotTitle => 'Forgot your password?';

  @override
  String get loginForgotSubtitle =>
      'Enter the email of your account and we will send you a 6-digit code to choose a new password. The code works for 15 minutes.';

  @override
  String get loginSendCode => 'Send code';

  @override
  String get loginChooseNewPassword => 'Choose a new password';

  @override
  String loginResetSubtitle(String email) {
    return 'If $email has an account, a 6-digit code is on its way. Enter it within 15 minutes, together with your new password.';
  }

  @override
  String get loginRecoveryKey => 'Recovery key (keeps your synced data)';

  @override
  String get loginNewPassword => 'New password';

  @override
  String get loginConfirmNewPassword => 'Confirm new password';

  @override
  String get loginResetAndSignIn => 'Reset password and sign in';

  @override
  String get loginSendNewCode => 'Send a new code';

  @override
  String get loginStrengthTooShort => 'Too short';

  @override
  String get loginStrengthWeak => 'Weak';

  @override
  String get loginStrengthGood => 'Good';

  @override
  String get loginStrengthStrong => 'Strong';

  @override
  String get loginBrandTagline =>
      'Everything you keep here,\non every device you use.';

  @override
  String get loginBrandPointEncrypted =>
      'Encrypted on this device before it ever leaves it.';

  @override
  String get loginBrandPointPerFeature =>
      'Nothing syncs until you switch it on, per feature.';

  @override
  String get loginBrandPointSkipServer =>
      'Or skip the server entirely and pair over your own network.';

  @override
  String get loginBrandNotEvenUs => 'Not even we can read your data.';

  @override
  String loginContinueWith(String provider) {
    return 'Continue with $provider';
  }

  @override
  String get loginOrWithEmail => 'or with your email';

  @override
  String get loginKeyWarning =>
      'Everything is encrypted with this before it leaves the device. If you forget it you can reset it by email, but the synced copies on the server are erased — only what is still on your devices comes back.';

  @override
  String get loginResetWithRecoveryKey =>
      'Your recovery key unlocks your synced data, so it stays on the server and is re-encrypted under your new password. Every device is signed out and picks it up again with the new password.';

  @override
  String get loginResetWithoutRecoveryKey =>
      'Your synced data is locked with your old password. Without your recovery key, a reset erases the copies on the server and signs out every device. Whatever is still on your devices uploads again once they sign in with the new password.';

  @override
  String loginAgreeLegal(String terms, String privacy) {
    return 'By continuing you agree to our $terms and $privacy';
  }

  @override
  String get loginTermsOfService => 'Terms of service';

  @override
  String get loginPrivacyPolicy => 'Privacy policy';

  @override
  String get planPriceFree => 'Free';

  @override
  String get planPriceOrbit => '\$3 / month';

  @override
  String get planPriceNova => '\$6 / month';

  @override
  String get planCoreBlurb => 'All the basics, right on your device.';

  @override
  String get planOrbitBlurb =>
      'More synced features, SFTP, Groceries List and the Coffee theme.';

  @override
  String get planNovaBlurb =>
      'Everything in sync on every device, plus the premium tools.';

  @override
  String planFeatureSyncUpTo(int count) {
    return 'Keep up to $count features in sync across your devices, end-to-end encrypted';
  }

  @override
  String get planFeatureEveryPlugin =>
      'Every plugin works on your device, free';

  @override
  String planFeatureFamilyRoom(int count) {
    return 'Room for $count in your family';
  }

  @override
  String get planFeatureAiCoreExchange =>
      'AI Detector reviews: exchange 10% of your weekly AI limit each';

  @override
  String planFeatureStorage(int mb) {
    return '$mb MB of sync storage';
  }

  @override
  String get planFeatureAiOrbit =>
      '10 AI Detector reviews a week, then 4% of your weekly AI limit each';

  @override
  String get planFeatureAiNova =>
      '30 AI Detector reviews a week, then 2% of your weekly AI limit each';

  @override
  String get planFeatureOrbitAirline =>
      'Carry your Airline Tycoon airline between devices';

  @override
  String get planFeatureOrbitCs2 => 'CS2 market prices in Steam Tools';

  @override
  String get planFeatureOrbitSftp =>
      'SFTP client and shared folder between your devices';

  @override
  String get planFeatureOrbitGroceries =>
      'Groceries List with prices from Jumbo, Albert Heijn, Hoogvliet and Lidl';

  @override
  String get planFeatureOrbitCoffee => 'The Coffee theme';

  @override
  String get planFeatureNovaEverythingSync =>
      'Keep everything in sync across all your devices, end-to-end encrypted';

  @override
  String get planFeatureNovaAssistant =>
      'Assistant plan mode, deep research and picture creation';

  @override
  String get planFeatureNovaGallery => 'Gallery People and Categories';

  @override
  String get planFeatureNovaClassroom =>
      'Classroom tutor in the Text Library hall';

  @override
  String get planFeatureNovaEverythingOrbit =>
      'Everything in Orbit, including the Coffee theme';

  @override
  String get planCodeEnterCode => 'Enter an access code.';

  @override
  String planCodeUnlockTitle(String plan) {
    return 'Unlock $plan';
  }

  @override
  String planCodeBody(String plan) {
    return 'Enter your access code. It unlocks $plan for 30 days, then you\'re moved back to Core automatically.';
  }

  @override
  String get planCodeHint => 'Access code';

  @override
  String get planCodeUnlockButton => 'Unlock';

  @override
  String get passwordResetChooseNew => 'Choose a new password.';

  @override
  String passwordResetMinLengthError(int min) {
    return 'Use at least $min characters.';
  }

  @override
  String get passwordResetMismatch => 'The two passwords do not match.';

  @override
  String get passwordResetTitle => 'Choose a new password';

  @override
  String get passwordResetBodyNoEmail =>
      'The server operator reset this account\'s password, so the old one no longer works.';

  @override
  String passwordResetBodyWithEmail(String email) {
    return 'The server operator reset the password for $email, so the old one no longer works.';
  }

  @override
  String get passwordResetSyncNote =>
      'Set a new one here and luma re-encrypts your synced data under it, so nothing is lost. Your other devices will ask for the new password the next time they sync.';

  @override
  String get passwordResetNewPassword => 'New password';

  @override
  String passwordResetMinHelper(int min) {
    return 'At least $min characters.';
  }

  @override
  String get passwordResetRepeatPassword => 'Repeat new password';

  @override
  String get passwordResetSubmit => 'Set new password';

  @override
  String get passwordResetLockedNote =>
      'Everything else in luma stays locked until this is done. Your local data on this device is untouched.';

  @override
  String get passwordResetShowPassword => 'Show password';

  @override
  String get passwordResetHidePassword => 'Hide password';

  @override
  String get planSelectionBackTooltip => 'Back to account';

  @override
  String get planSelectionTitle => 'Choose your plan';

  @override
  String get planSelectionSubtitle =>
      'Select the plan that works best for you.';

  @override
  String get planSelectionInvalidCode => 'That access code is invalid.';

  @override
  String planCreditsNotOpen(String tokens, String price) {
    return 'Buying credits isn\'t open yet — $tokens tokens for $price will be available once payments are set up.';
  }

  @override
  String get planCreditsHeader => 'ONE-TIME AI CREDITS';

  @override
  String get planCreditsBody =>
      'Extra tokens for when your plan\'s AI limit runs out. They never expire.';

  @override
  String planCreditsBodyWithBalance(String balance) {
    return 'Extra tokens for when your plan\'s AI limit runs out. You have $balance left. They never expire.';
  }

  @override
  String planCreditsPackTokens(String tokens) {
    return '$tokens tokens';
  }

  @override
  String planCreditsBuy(String price) {
    return '$price · Buy';
  }

  @override
  String planTokenAmountMillions(String amount) {
    return '${amount}M tokens';
  }

  @override
  String planTokenAmountThousands(String amount) {
    return '${amount}K tokens';
  }

  @override
  String get planCurrentBadge => 'Current';

  @override
  String planRevertsToCore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return 'Reverts to Core in $_temp0';
  }

  @override
  String get planWhatYouGet => 'WHAT YOU GET';

  @override
  String get planYourCurrentPlan => 'Your current plan';

  @override
  String planSelectPlan(String plan) {
    return 'Select $plan';
  }

  @override
  String get statsNetWorthTitle => 'Net worth';

  @override
  String get statsNetWorthSubtitle =>
      'Everything you\'ve earned since you started tracking.';

  @override
  String get statsTravelTitle => 'Travel';

  @override
  String get statsTravelSubtitle => 'The countries you\'ve been to, on a map.';

  @override
  String get statsTotalIncomeAllTime => 'Total income of all time';

  @override
  String get statsSpent => 'Spent';

  @override
  String get statsKept => 'Kept';

  @override
  String get statsPerMonth => 'Per month';

  @override
  String get statsTotalIncome => 'Total income';

  @override
  String get statsTotalSpent => 'Total spent';

  @override
  String statsKeptOfIncome(String amount, String percent) {
    return '$amount · $percent% of income';
  }

  @override
  String get statsAverageIncomePerMonth => 'Average income per month';

  @override
  String get statsEntriesLogged => 'Entries logged';

  @override
  String get statsTrackingSince => 'Tracking since';

  @override
  String get statsNoEntriesYet => 'No entries yet';

  @override
  String get statsCountriesVisited => 'Countries visited';

  @override
  String statsVisitedSoFar(int count) {
    return '$count so far';
  }

  @override
  String statsVisitedOfTotal(int visited, int total, String percent) {
    return '$visited of $total · $percent% of the world';
  }

  @override
  String get statsMapButton => 'Map';

  @override
  String get travelMapTitle => 'Travel map';

  @override
  String get travelResetZoom => 'Reset zoom';

  @override
  String get travelFullscreen => 'Fullscreen';

  @override
  String get travelMapLoadFailed => 'The map could not be loaded';

  @override
  String get travelClearTitle => 'Clear the map?';

  @override
  String get travelClearBody =>
      'Every country you\'ve marked as visited will be unmarked.';

  @override
  String travelSummaryOfTotal(int total, String percent) {
    return 'of $total countries · $percent% of the world';
  }

  @override
  String get travelRegionAfrica => 'Africa';

  @override
  String get travelRegionAsia => 'Asia';

  @override
  String get travelRegionEurope => 'Europe';

  @override
  String get travelRegionNorthAmerica => 'North America';

  @override
  String get travelRegionOceania => 'Oceania';

  @override
  String get travelRegionSouthAmerica => 'South America';

  @override
  String get travelRegionOther => 'Other';

  @override
  String travelRegionPill(String region, int visited, int total) {
    return '$region $visited/$total';
  }

  @override
  String get travelMapHint =>
      'Tap a country to mark it visited, tap it again to remove it. Pinch to zoom, or open the map fullscreen.';

  @override
  String get travelOpenFullscreen => 'Open fullscreen';

  @override
  String get travelCountriesTitle => 'Countries';

  @override
  String travelCountriesCount(int count) {
    return 'Countries · $count';
  }

  @override
  String get travelClearAll => 'Clear all';

  @override
  String get travelSearchCountry => 'Search a country';

  @override
  String travelNoCountryMatch(String query) {
    return 'No country matches \"$query\".';
  }

  @override
  String travelFullscreenCount(int visited, int total) {
    return '$visited of $total visited';
  }

  @override
  String get pinMustBe8Digits => 'PIN must be exactly 8 digits.';

  @override
  String get serverGateSetUpAccount => 'Set up account';

  @override
  String get serverGateEnterCode => 'Enter code';

  @override
  String serverGatePendingEmail(String email) {
    return 'Your account ($email) still needs a thumbs-up. Enter the 6-digit code we emailed you to finish signing in — until then we leave the server completely alone.';
  }

  @override
  String serverGatePendingApproval(String email) {
    return 'Your account ($email) is waiting on the server owner to say yes. Nothing for you to do in the meantime — just sign in once they have; until then we leave the server completely alone.';
  }

  @override
  String get serverGateExpired =>
      'This account lost its thumbs-up. Once it is approved again, sign in and this turns back on.';

  @override
  String serverGateSetupHint(String description) {
    return '$description Make an account under Settings → Sync & account, tap the link in the email you get, then sign in.';
  }

  @override
  String get serverGateCloudFilesTitle =>
      'Cloud Files needs an approved account';

  @override
  String get serverGateCloudFilesDescription =>
      'Cloud Files keeps your files on the luma server, locked on this device first.';

  @override
  String get serverGateChatTitle => 'Chat needs an approved account';

  @override
  String get serverGateChatDescription =>
      'Chat passes locked messages between accounts through the luma server.';

  @override
  String get titleBarMinimize => 'Minimize';

  @override
  String get titleBarMaximize => 'Maximize';

  @override
  String get titleBarRestore => 'Restore';

  @override
  String get licensePoweredByFlutter => 'Powered by Flutter';

  @override
  String get splashTagline => 'The utility app';

  @override
  String get splashStarting => 'Starting luma';

  @override
  String get updateNoTestBuilds =>
      'No updates on test builds — this one is handmade.';

  @override
  String updateUpToDate(String version) {
    return 'You are all caught up ($version). Nice.';
  }

  @override
  String updateDownloadNotReady(String version) {
    return 'luma $version is out, but the download is still getting ready. Give it a few minutes and try again.';
  }

  @override
  String updateNewVersionTitle(String version) {
    return 'There is a new luma — $version';
  }

  @override
  String updateReadyBody(String current) {
    return 'A fresh luma is ready to install.\n\nYou have $current.';
  }

  @override
  String updateWhatsNew(String current, String version) {
    return 'You have $current. Here is what is new in $version:';
  }

  @override
  String get updateLater => 'Later';

  @override
  String get updateInstallIt => 'Install it';

  @override
  String get updateFailedGeneric => 'Update failed. Please try again later.';

  @override
  String get updateAndroidBlocked =>
      'Android blocked the install — allow \"Install unknown apps\" for luma in system settings, then try again.';

  @override
  String get updateDownloadFailed =>
      'Download failed. Check the network and update source.';

  @override
  String updateServerHttpError(String code) {
    return 'Server returned HTTP $code for the installer.';
  }

  @override
  String updateOpenInstallerFailed(String message) {
    return 'Could not open the installer: $message';
  }

  @override
  String updateStartInstallerFailed(String error) {
    return 'Could not start the installer: $error';
  }

  @override
  String get updateTitle => 'Updating luma';

  @override
  String get updateDontClose =>
      'Don\'t close luma — it will relaunch on its own.';

  @override
  String get updateStageDownloading => 'Downloading update';

  @override
  String get updateStageVerifying => 'Verifying files';

  @override
  String get updateStagePreparing => 'Preparing installer';

  @override
  String get updateRestarting => 'Restarting luma';

  @override
  String get familyInboxTitle => 'Inbox';

  @override
  String familyInboxPendingInvites(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pending invites',
      one: '1 pending invite',
    );
    return '$_temp0';
  }

  @override
  String get familyInboxEmptySubtitle =>
      'Messages from luma and family invites will show up here.';

  @override
  String get familyInboxNew => 'New';

  @override
  String familyInboxFromLuma(String date) {
    return 'From luma · $date';
  }

  @override
  String familyInboxInvitedBy(String email) {
    return 'Invited by $email';
  }

  @override
  String familyInboxSentOn(String date) {
    return 'Sent $date';
  }

  @override
  String familyInboxExpiresOn(String date) {
    return 'Expires $date';
  }

  @override
  String get familyInboxAccept => 'Accept';

  @override
  String get familyInboxDecline => 'Decline';

  @override
  String familyLimitExceeded(int limit) {
    String _temp0 = intl.Intl.pluralLogic(
      limit,
      locale: localeName,
      other:
          'This family plan allows up to $limit members. Upgrade the owner\'s plan to add more.',
      one:
          'This family plan allows up to 1 member. Upgrade the owner\'s plan to add more.',
    );
    return '$_temp0';
  }

  @override
  String get familyNotInFamily => 'Not in a family.';

  @override
  String get familyNotSignedIn => 'Not signed in.';

  @override
  String familyApiServerError(String status) {
    return 'Server error ($status).';
  }

  @override
  String get aiSettingsLocalNotAvailableIos =>
      'The on-device model is not available on iOS. Pick another model above.';

  @override
  String get aiSettingsRetentionNotice =>
      'Hosted model Zero Data Retention must be enabled on the provider account behind the API key, including a shared server key. Luma cannot switch or verify that account setting. OpenAI requests disable response storage, but that does not replace provider approval. Mistral uses its stateless chat endpoint. On-device Qwen sends no prompts to a model provider; Luma still saves chat history on this device.';

  @override
  String aiSettingsLocalModelTitle(String model) {
    return 'Luma Assistant · $model on-device';
  }

  @override
  String aiSettingsLocalModelBlurb(String size) {
    return 'Download the $size model once to use the Assistant offline. Prompts run on this device; online actions such as plugin downloads and market prices still need internet. Qwen is provided under Apache-2.0.';
  }

  @override
  String get aiSettingsDownloadingModel => 'Downloading model…';

  @override
  String aiSettingsDownloadingModelPercent(String percent) {
    return 'Downloading model… $percent%';
  }

  @override
  String aiSettingsDownloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String get aiSettingsModelReady => 'Model downloaded and ready';

  @override
  String get aiSettingsDownloadModel => 'Download model';

  @override
  String get aiSettingsModelUsage => 'Model usage';

  @override
  String get aiSettingsModelUsageSubtitle =>
      'Successful messages sent with each model on this device.';

  @override
  String get aiSettingsNoMessagesYet => 'No messages sent yet.';

  @override
  String get aiSettingsKeySaved => 'API key saved.';

  @override
  String get aiSettingsEnterKeyFirst => 'Enter an API key first.';

  @override
  String get aiSettingsConnectionWorks => 'Connection works.';

  @override
  String aiSettingsCouldNotVerifyKey(String error) {
    return 'Could not verify the key: $error';
  }

  @override
  String get aiSettingsKeyRemoved => 'API key removed.';

  @override
  String get aiSettingsRemoveKeyTitle => 'Remove API key?';

  @override
  String aiSettingsRemoveKeyBody(String provider) {
    return 'You won\'t be able to chat with $provider until you add another key.';
  }

  @override
  String get aiSettingsRemoveKey => 'Remove key';

  @override
  String get aiSettingsTestConnection => 'Test connection';

  @override
  String get aiSettingsSharedKeyAvailable =>
      'Shared key available from your sync server';

  @override
  String get aiSettingsHintReplaceKey => 'Enter a new key to replace it';

  @override
  String get aiSettingsHintOverrideSharedKey =>
      'Enter your own key to override the shared one';

  @override
  String aiSettingsSharedKeyExplanation(String provider) {
    return 'Your sync server\'s admin has configured a shared $provider key, so you don\'t need one — chats are relayed through your sync server, which holds the key; it\'s never sent to this device. Enter your own key above to bypass the server and talk to $provider directly instead.';
  }

  @override
  String aiSettingsLocalKeyExplanation(String provider) {
    return 'Stored locally on this device only, encrypted at rest. Sent directly to $provider when you chat — never to any luma server.';
  }

  @override
  String get assistantNeedsAccountTitle => 'Create an account to continue';

  @override
  String get assistantNeedsAccountBody =>
      'Set up a luma account — just an email and password, no server required — before chatting with the assistant.';

  @override
  String get assistantSetUpAccount => 'Set up account';

  @override
  String get assistantRenameTitle => 'Rename conversation';

  @override
  String assistantDeleteTitle(String title) {
    return 'Delete \"$title\"?';
  }

  @override
  String get assistantDeleteBody =>
      'This removes the conversation and its messages.';

  @override
  String get assistantModelUnused => 'Unused';

  @override
  String assistantModelMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count msgs',
      one: '1 msg',
    );
    return '$_temp0';
  }

  @override
  String get assistantModelsHeader => 'Models';

  @override
  String get assistantApiKeyHeader => 'API key';

  @override
  String get assistantWouldntWakeUp => 'The assistant wouldn\'t wake up';

  @override
  String get assistantDownloadTitle => 'Download Luma Assistant';

  @override
  String get assistantDownloadUnsupported =>
      'The on-device model is not available on this platform.';

  @override
  String assistantDownloadingModel(String model, String size) {
    return 'Downloading $model ($size)…';
  }

  @override
  String assistantDownloadPrompt(String model, String size) {
    return 'Download $model ($size) to start chatting. It runs on this device.';
  }

  @override
  String get assistantChooseAnotherModel =>
      'Choose another model from the selector below.';

  @override
  String get assistantDownloadingModelShort => 'Downloading model…';

  @override
  String get assistantDownloadModel => 'Download model';

  @override
  String assistantDownloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String get assistantModelUnavailableTitle =>
      'This model isn\'t available yet';

  @override
  String get assistantModelUnavailableBody =>
      'Add your own API key in Settings to use it — stored locally on this device only — or switch to another model below.';

  @override
  String get assistantOpenSettings => 'Open Settings';

  @override
  String get assistantIAddedKey => 'I added a key';

  @override
  String assistantNoApiKeyYet(String provider) {
    return 'No $provider API key saved yet — add one in Settings.';
  }

  @override
  String get assistantPictureNeedsAccount =>
      'Picture mode needs this device signed in to an approved luma account.';

  @override
  String get assistantResearchAgentsEmpty =>
      'The research agents came back empty.';

  @override
  String get assistantNewConversation => 'New conversation';

  @override
  String get aiClientNoReply => 'I couldn\'t come up with a reply for that.';

  @override
  String get aiClientTooManySteps =>
      'I couldn\'t finish that — too many tool steps.';

  @override
  String aiClientUnreachable(String provider, String error) {
    return 'Couldn\'t reach $provider — check your connection.\n($error)';
  }

  @override
  String aiClientNoConnection(String provider) {
    return 'Couldn\'t reach $provider — check your connection.';
  }

  @override
  String aiClientKeyRejected(String provider) {
    return '$provider rejected the API key. Check it in Settings.';
  }

  @override
  String get aiClientRateLimited => 'Too many requests — try again shortly.';

  @override
  String aiClientApiError(String provider, int status) {
    return '$provider returned an error ($status).';
  }

  @override
  String get aiClientLumaSignIn => 'Sign in again to use Luma AI.';

  @override
  String aiClientLumaImageFailed(int status) {
    return 'Luma AI could not draw that ($status).';
  }

  @override
  String get aiClientLumaBrokenImage => 'Luma AI sent back a broken picture.';

  @override
  String aiLocalModelMissing(String model) {
    return 'Download $model in Assistant settings before using the on-device model.';
  }

  @override
  String aiLocalModelFailed(String error) {
    return 'The on-device model could not answer: $error';
  }

  @override
  String get chatProviderLocalName => 'Luma Assistant (on-device Qwen)';

  @override
  String get chatBubbleOpenInQrGenerator => 'Open in QR Generator';

  @override
  String get chatCodeLanguagePlainText => 'text';

  @override
  String get assistantModelDamaged =>
      'The model file was incomplete or damaged. Download it again.';

  @override
  String get assistantModelDownloadInvalid =>
      'The model download did not produce a valid file.';

  @override
  String get converterHubPickTool => 'Pick a tool to get started.';

  @override
  String get converterHubAudioTitle => 'Audio converter';

  @override
  String get converterHubPictureTitle => 'Picture converter';

  @override
  String get converterHubVideoTitle => 'Video converter';

  @override
  String get converterHubDownscalerTitle => 'Image downscaler';

  @override
  String get converterHubDownscalerSubtitle =>
      'Make pictures smaller, your way';

  @override
  String get converterHubVideoDownscalerTitle => 'Video downscaler';

  @override
  String get converterHubVideoDownscalerSubtitle => 'Make videos smaller';

  @override
  String get converterHubImageEditorTitle => 'Image editor';

  @override
  String get converterHubImageEditorSubtitle => 'Cut out white backgrounds';

  @override
  String get converterHubAudioEditorTitle => 'Audio editor';

  @override
  String get converterHubAudioEditorSubtitle => 'Snip and polish your sound';

  @override
  String get converterHubCollageTitle => 'Collage maker';

  @override
  String get converterHubCollageSubtitle => 'Stick photos together';

  @override
  String get converterHubOtherSubtitle =>
      'Minecraft worlds & builds, file breaker & fixer';

  @override
  String get converterBadgeAudio => 'AUDIO';

  @override
  String get converterBadgeImage => 'IMAGE';

  @override
  String get converterBadgeVideo => 'VIDEO';

  @override
  String get converterBadgeOptimize => 'OPTIMIZE';

  @override
  String get converterBadgeEdit => 'EDIT';

  @override
  String get converterBadgeCreate => 'CREATE';

  @override
  String get converterBadgeOther => 'OTHER';

  @override
  String get converterChange => 'Change';

  @override
  String get converterSigPngImage => 'PNG image';

  @override
  String get converterSigJpegImage => 'JPEG image';

  @override
  String get converterSigGifImage => 'GIF image';

  @override
  String get converterSigBmpImage => 'BMP image';

  @override
  String get converterSigTiffImage => 'TIFF image';

  @override
  String get converterSigWebpImage => 'WebP image';

  @override
  String get converterSigWindowsIcon => 'Windows icon';

  @override
  String get converterSigPhotoshopDocument => 'Photoshop document';

  @override
  String get converterSigAvifHeicImage => 'AVIF/HEIC image';

  @override
  String get converterSigPdfDocument => 'PDF document';

  @override
  String get converterSigRichTextDocument => 'Rich text document';

  @override
  String get converterSigLegacyOfficeDocument => 'Legacy Office document';

  @override
  String get converterSigZipArchive => 'ZIP archive';

  @override
  String get converterSigEmptyZipArchive => 'Empty ZIP archive';

  @override
  String get converterSigRarArchive => 'RAR archive';

  @override
  String get converterSig7ZipArchive => '7-Zip archive';

  @override
  String get converterSigGzipArchive => 'GZip archive';

  @override
  String get converterSigBzip2Archive => 'BZip2 archive';

  @override
  String get converterSigXzArchive => 'XZ archive';

  @override
  String get converterSigZstdArchive => 'Zstandard archive';

  @override
  String get converterSigTarArchive => 'TAR archive';

  @override
  String get converterSigWavAudio => 'WAV audio';

  @override
  String get converterSigAviVideo => 'AVI video';

  @override
  String get converterSigMp3Audio => 'MP3 audio';

  @override
  String get converterSigMp4Video => 'MP4 video';

  @override
  String get converterSigFlacAudio => 'FLAC audio';

  @override
  String get converterSigOggMedia => 'Ogg media';

  @override
  String get converterSigMatroskaVideo => 'Matroska video';

  @override
  String get converterSigMidiFile => 'MIDI file';

  @override
  String get converterSigWindowsExecutable => 'Windows executable';

  @override
  String get converterSigElfBinary => 'ELF binary';

  @override
  String get converterSigSqliteDatabase => 'SQLite database';

  @override
  String get converterSigWebAssemblyModule => 'WebAssembly module';

  @override
  String get converterSigJavaClass => 'Java class';

  @override
  String get converterSigTrueTypeFont => 'TrueType font';

  @override
  String get converterSigOpenTypeFont => 'OpenType font';

  @override
  String get converterSigWoffFont => 'WOFF font';

  @override
  String get converterSigWoff2Font => 'WOFF2 font';

  @override
  String get converterSigMinecraftNbt => 'Minecraft NBT (gzip)';

  @override
  String get converterSigLumaRecipe => 'luma recovery recipe';

  @override
  String get converterDamageBitRotLabel => 'Bit rot';

  @override
  String get converterDamageScrambleLabel => 'Scramble';

  @override
  String get converterDamageShuffleLabel => 'Block shuffle';

  @override
  String get converterDamageHeaderSmashLabel => 'Header smash';

  @override
  String get converterDamageTruncateLabel => 'Truncate';

  @override
  String get converterDamageJunkLabel => 'Junk injection';

  @override
  String get converterDamageBitRotDesc =>
      'Scattered single bytes flipped, the way failing storage does it.';

  @override
  String get converterDamageScrambleDesc =>
      'A whole region XORed into noise. Nothing can read it.';

  @override
  String get converterDamageShuffleDesc =>
      'Chunks of the file swapped around. Structure survives, meaning does not.';

  @override
  String get converterDamageHeaderSmashDesc =>
      'The first bytes wiped, so nothing can even tell what the file is.';

  @override
  String get converterDamageTruncateDesc =>
      'The tail cut off, as if the copy never finished.';

  @override
  String get converterDamageJunkDesc =>
      'Random bytes wedged in, shifting everything after them.';

  @override
  String get converterPresetLight => 'Light';

  @override
  String get converterPresetMedium => 'Medium';

  @override
  String get converterPresetHeavy => 'Heavy';

  @override
  String get converterPresetTotal => 'Total';

  @override
  String get converterPresetLightHint =>
      'Usually still opens, but looks wrong in places.';

  @override
  String get converterPresetMediumHint =>
      'Most readers will refuse to open it.';

  @override
  String get converterPresetHeavyHint => 'Thoroughly broken.';

  @override
  String get converterPresetTotalHint => 'Nothing recognisable is left.';

  @override
  String converterCorruptTooSmall(int size) {
    return 'That file is only $size bytes — too small to corrupt in any interesting way.';
  }

  @override
  String get converterCorruptPickStyle => 'Pick at least one kind of damage.';

  @override
  String converterCorruptStyleSkipped(String style) {
    return '$style was skipped — the file is too small for it.';
  }

  @override
  String get converterCorruptNothingApplied =>
      'Nothing could be applied to a file this small.';

  @override
  String get converterCorruptNoRecipeRearranged =>
      'These damage styles rearrange and mask bytes rather than removing them. Without the recipe nothing can read the file, but the data is technically still in there. Add Header smash or Truncate if you want bytes genuinely gone.';

  @override
  String get converterCorruptNoRecipeDestroyed =>
      'No recipe was written and bytes were destroyed. This cannot be undone by anything, including luma.';

  @override
  String converterOpFlipped(int count, String range) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bytes',
      one: '1 byte',
    );
    return 'Flipped $_temp0 across $range';
  }

  @override
  String converterOpScrambled(String range) {
    return 'Scrambled $range with a keystream';
  }

  @override
  String converterOpShuffled(int count, String size, String offset) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocks',
      one: '1 block',
    );
    return 'Shuffled $_temp0 of $size from $offset';
  }

  @override
  String converterOpWiped(String range) {
    return 'Wiped $range';
  }

  @override
  String converterOpCutOff(String offset) {
    return 'Cut the file off at $offset';
  }

  @override
  String converterOpInjected(String size, String offset) {
    return 'Injected $size of junk at $offset';
  }

  @override
  String converterRecipeUnknownStep(String type) {
    return 'Unknown damage step \"$type\".';
  }

  @override
  String converterRecipeMissingField(String key) {
    return 'Recipe step is missing \"$key\".';
  }

  @override
  String get converterRecipeNotReadable =>
      'That is not a readable .lumafix recipe.';

  @override
  String get converterRecipeNotLuma =>
      'That file is not a luma recovery recipe.';

  @override
  String converterRecipeNewerVersion(int version) {
    return 'This recipe was written by a newer version of luma (format $version). Update the app to use it.';
  }

  @override
  String get converterRecipeNoSteps => 'The recipe has no steps to undo.';

  @override
  String get converterRecipeWipedUnrecorded =>
      'This step wiped bytes that were never recorded.';

  @override
  String get converterRecipeCutUnrecorded =>
      'This step cut off bytes that were never recorded.';

  @override
  String get converterRecipeShorter =>
      'The file is shorter than the recipe expects.';

  @override
  String get converterRepairRecipeMismatch =>
      'This recipe was written for a different file than the one you opened. Undoing it anyway will almost certainly produce nonsense.';

  @override
  String converterRepairRecipeWrongSize(String recipeSize, String openedSize) {
    return 'That recipe belongs to a $recipeSize file, but the one you opened is $openedSize. Pick the matching pair.';
  }

  @override
  String converterRepairLostSteps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count steps',
      one: '1 step',
    );
    return 'This recipe has $_temp0 that destroyed bytes without recording them, so the original cannot be rebuilt from it.';
  }

  @override
  String converterRepairUndid(String step) {
    return 'Undid: $step';
  }

  @override
  String get converterRepairChecksumExact =>
      'The result matches the original checksum exactly — this is the file that was corrupted, byte for byte.';

  @override
  String get converterRepairChecksumChanged =>
      'The rebuilt file does not match the checksum recorded when it was corrupted, so something else changed it after the fact.';

  @override
  String get converterRepairFormatRecipe => 'Restored from recipe';

  @override
  String get converterRepairEmpty =>
      'That file is empty — there is nothing in it to repair.';

  @override
  String converterRepairFoundHeader(String label, String size) {
    return 'Found the $label header $size into the file and dropped everything before it.';
  }

  @override
  String converterRepairFoundStart(String label, String size) {
    return 'Found a $label starting $size into the file and dropped everything before it.';
  }

  @override
  String converterRepairHeaderGone(String ext, String label) {
    return 'The header is gone, so nothing in the bytes says what this is. Going by the .$ext name and treating it as a $label.';
  }

  @override
  String get converterRepairNoSignature =>
      'This does not start with any file signature luma recognises, and the name gives nothing away either. Only the generic checks were run.';

  @override
  String converterRepairExtMismatch(String ext, String label, String newExt) {
    return 'The file is named .$ext but the bytes are a $label. Saving it as .$newExt will make it open again.';
  }

  @override
  String converterRepairGenericOnly(String label) {
    return 'luma knows this is a $label but has no structural repairer for that format, so only the generic checks ran.';
  }

  @override
  String get converterRepairFormatUnknown => 'Unknown format';

  @override
  String converterRepairTrimmed(String size) {
    return 'Trimmed $size of zero-fill from the end, which is what an interrupted copy leaves behind.';
  }

  @override
  String get converterRepairPaddingOnly =>
      'Nothing but padding was left once the zero-fill came off.';

  @override
  String get converterRepairNothingChanged =>
      'Nothing needed changing — the structure already checks out.';

  @override
  String get repairBmpTooShort =>
      'A BMP needs at least a 14-byte file header and a DIB header.';

  @override
  String get repairBmpMagicRewritten => 'Rewrote the \"BM\" magic bytes.';

  @override
  String repairBmpSizeCorrected(int declared, int actual) {
    return 'Corrected the file-size field from $declared to $actual.';
  }

  @override
  String repairBmpDibUnknown(int size) {
    return 'The DIB header size reads $size, which is not a known BMP header layout. Width, height and bit depth are unrecoverable.';
  }

  @override
  String repairBmpDimensionsImpossible(int width, int height, int bpp) {
    return 'The DIB header reads $width×$height at $bpp bpp, which cannot be right. Those numbers are stored nowhere else.';
  }

  @override
  String repairBmpImageInfo(int width, int height, int bpp) {
    return 'Image: $width×$height at $bpp bpp.';
  }

  @override
  String repairBmpOffsetRecalculated(int expected, int declared) {
    return 'Recalculated the pixel-data offset as $expected (it read $declared).';
  }

  @override
  String repairBmpPadded(String size) {
    return 'Padded $size of missing pixel rows with black so the image opens; the bottom of the picture is lost.';
  }

  @override
  String repairBmpTrimmed(String size) {
    return 'Trimmed $size of bytes past the end of the pixel data.';
  }

  @override
  String get repairGifTooShort =>
      'A GIF needs at least 13 bytes of header; this has fewer.';

  @override
  String get repairGifSignatureRewritten => 'Rewrote the \"GIF\" signature.';

  @override
  String get repairGifVersionRestored =>
      'Restored the version stamp to \"89a\".';

  @override
  String repairGifScreenSizeBad(int width, int height) {
    return 'The logical screen size reads $width×$height, which no decoder will accept. The real dimensions are not recorded anywhere else.';
  }

  @override
  String repairGifScreenSizeInfo(int width, int height) {
    return 'Logical screen: $width×$height.';
  }

  @override
  String repairGifTableTruncated(String size) {
    return 'The global colour table is declared as $size but the file ends before it does.';
  }

  @override
  String repairGifJunkTrimmed(String size) {
    return 'Trimmed $size of junk after the GIF trailer.';
  }

  @override
  String get repairGifTrailerAppended =>
      'Appended the missing 0x3B trailer byte.';

  @override
  String repairJpegJunkDropped(String size) {
    return 'Dropped $size of junk in front of the image.';
  }

  @override
  String get repairJpegTooShort => 'The file is too short to be a JPEG.';

  @override
  String get repairJpegSoiRewritten =>
      'Rewrote the missing FFD8 start-of-image marker.';

  @override
  String repairJpegMarkerExpected(String offset, String byte) {
    return 'Expected a marker at $offset and found $byte instead.';
  }

  @override
  String repairJpegSegmentPastEnd(String offset) {
    return 'The segment at $offset runs past the end of the file.';
  }

  @override
  String get repairJpegNoSegments =>
      'No readable JPEG segments survived — the quantisation and Huffman tables are gone, and those cannot be guessed.';

  @override
  String get repairJpegNoScan =>
      'The file never reaches its image scan (SOS), so there is header but no picture to decode.';

  @override
  String get repairJpegEoiAppended =>
      'Appended the missing FFD9 end-of-image marker.';

  @override
  String repairJpegTrailingTrimmed(String size) {
    return 'Trimmed $size of trailing junk after the end marker.';
  }

  @override
  String repairMp3TagTooBig(String size) {
    return 'The ID3 tag claims $size but the file is smaller — dropped the tag and kept the audio.';
  }

  @override
  String repairMp3TagKept(String size) {
    return 'Kept the $size ID3 tag at the front.';
  }

  @override
  String get repairMp3NoFrames =>
      'No run of valid MPEG audio frames could be found anywhere in the file. There is no audio left to salvage.';

  @override
  String repairMp3JunkSkipped(String size) {
    return 'Skipped $size of junk before the first real audio frame.';
  }

  @override
  String repairMp3DamagedStretch(String offset) {
    return 'A damaged stretch at $offset was skipped; playback will glitch there.';
  }

  @override
  String get repairMp3FramesStop =>
      'The frames stop being readable immediately after the header.';

  @override
  String repairMp3FramesSurvived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count audio frames survived.',
      one: '1 audio frame survived.',
    );
    return '$_temp0';
  }

  @override
  String repairMp3CutTail(String size) {
    return 'Cut $size of unplayable bytes off the end.';
  }

  @override
  String get repairMp4TooShort => 'The file is too short to hold a single box.';

  @override
  String repairMp4JunkDropped(String size) {
    return 'Dropped $size of junk before the ftyp box.';
  }

  @override
  String get repairMp4NoFtyp =>
      'There is no ftyp box, so the exact flavour of MP4 is unknown. The box tree was still checked.';

  @override
  String repairMp4UnreadableBox(String offset) {
    return 'Unreadable box name at $offset — stopping the walk there.';
  }

  @override
  String repairMp4BoxClamped(
    String type,
    String offset,
    String claimed,
    String available,
  ) {
    return 'The \"$type\" box at $offset claimed $claimed but only $available follows — clamped it to fit.';
  }

  @override
  String repairMp4BoxesParsed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count top-level boxes parsed.',
      one: '1 top-level box parsed.',
    );
    return '$_temp0';
  }

  @override
  String repairMp4MoovMisplaced(String offset) {
    return 'A moov box exists at $offset but the box chain never reaches it. Some players will still find it by scanning.';
  }

  @override
  String get repairMp4NoMoov =>
      'There is no moov box. That box is the index of every video and audio sample in the file, and without it the media data cannot be played back — recovering it needs an undamaged file recorded by the same device.';

  @override
  String get repairMp4NoMdat =>
      'No mdat box was found, so there may be no media data left.';

  @override
  String get repairMp4ClampExplain =>
      'Clamping a box size keeps readers from walking off the end; it does not bring back what was cut off.';

  @override
  String repairMp4TailTrimmed(String size) {
    return 'Trimmed $size of unreadable tail.';
  }

  @override
  String repairMp4TrailingTrimmed(String size) {
    return 'Trimmed $size of trailing junk.';
  }

  @override
  String get repairPdfHeaderAdded => 'Rewrote the missing \"%PDF-1.7\" header.';

  @override
  String repairPdfJunkDropped(String size) {
    return 'Dropped $size of junk before the PDF header.';
  }

  @override
  String get repairPdfNoObjects =>
      'No PDF objects were found at all. There is no document structure left to index.';

  @override
  String repairPdfObjectsIntact(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Found $count objects still intact.',
      one: 'Found 1 object still intact.',
    );
    return '$_temp0';
  }

  @override
  String get repairPdfEncrypted =>
      'The document is encrypted. The index can be rebuilt, but a reader will still ask for the password it was protected with.';

  @override
  String get repairPdfNoCatalog =>
      'No document catalog (/Type /Catalog) survived, so nothing points at the page tree. Readers will open the file and find no pages.';

  @override
  String repairPdfCatalogFound(int root) {
    return 'Document catalog is object $root.';
  }

  @override
  String repairPdfFreeSlots(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count object slots were empty and had to be marked free. Whatever those held is gone.',
      one:
          '1 object slot was empty and had to be marked free. Whatever those held is gone.',
    );
    return '$_temp0';
  }

  @override
  String get repairPdfXrefRebuilt =>
      'Rebuilt the cross-reference table and appended a fresh trailer.';

  @override
  String get repairPdfXrefFromScratch =>
      'Built a cross-reference table and trailer from scratch — the file had neither.';

  @override
  String get repairPngTooShort => 'The file is too short to be a PNG at all.';

  @override
  String get repairPngSignatureRewritten => 'Rewrote the 8-byte PNG signature.';

  @override
  String repairPngUnreadableChunk(String offset) {
    return 'Unreadable chunk name at $offset — stopping the walk there.';
  }

  @override
  String repairPngChunkPastEnd(String type, String offset, int length) {
    return 'The \"$type\" chunk at $offset claims $length bytes but the file ends first.';
  }

  @override
  String get repairPngNoIhdr =>
      'No IHDR header chunk survived, so the image size and colour type are gone. Nothing can rebuild those.';

  @override
  String repairPngCrcRecomputed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Recomputed $count bad chunk checksums — the pixel data behind them may still be wrong, but readers will stop rejecting the file outright.',
      one:
          'Recomputed 1 bad chunk checksum — the pixel data behind it may still be wrong, but readers will stop rejecting the file outright.',
    );
    return '$_temp0';
  }

  @override
  String repairPngCutAtLastChunk(String size) {
    return 'Cut the file at the last chunk that parsed and dropped $size of unusable tail.';
  }

  @override
  String repairPngJunkAfterIend(String size) {
    return 'Trimmed $size of junk sitting after IEND.';
  }

  @override
  String get repairPngNoChunks => 'The file has no chunks left.';

  @override
  String get repairPngIendAppended =>
      'Appended the missing IEND end-of-image chunk.';

  @override
  String get repairRiffTooShort =>
      'A RIFF file needs at least a 12-byte header; this has fewer.';

  @override
  String get repairRiffMagicRewritten => 'Rewrote the \"RIFF\" magic bytes.';

  @override
  String get repairRiffUnreadableForm =>
      'The RIFF form type is unreadable and no known chunk names survive, so there is no telling what this file was.';

  @override
  String repairRiffFormRestored(String form) {
    return 'Restored the form type to \"$form\".';
  }

  @override
  String repairRiffLengthCorrected(int declared, int actual) {
    return 'Corrected the RIFF length field from $declared to $actual.';
  }

  @override
  String repairRiffUnreadableChunk(String offset) {
    return 'Unreadable chunk name at $offset — stopping there.';
  }

  @override
  String repairRiffChunkClamped(String id, String claimed, String available) {
    return 'The \"$id\" chunk claimed $claimed but only $available is present — shortened it to match.';
  }

  @override
  String get repairRiffNoFmt =>
      'The \"fmt \" chunk is gone, so the sample rate, channel count and bit depth are unknown. Nothing can guess those from the samples alone.';

  @override
  String repairRiffTrailingTrimmed(String size) {
    return 'Trimmed $size of bytes past the last valid chunk.';
  }

  @override
  String repairZipSkipped(String size, String offset) {
    return 'Skipped $size of unreadable bytes before the entry at $offset.';
  }

  @override
  String get repairZipNoEntries =>
      'No recoverable entries were found — every local file header is gone, so there is nothing left to rebuild the archive from.';

  @override
  String repairZipDamagedEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count entries were damaged beyond use and left out of the rebuilt archive.',
      one:
          '1 entry was damaged beyond use and left out of the rebuilt archive.',
    );
    return '$_temp0';
  }

  @override
  String repairZipCentralRebuilt(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Rebuilt the missing central directory from $count local file headers.',
      one: 'Rebuilt the missing central directory from 1 local file header.',
    );
    return '$_temp0';
  }

  @override
  String repairZipCentralRewritten(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Rewrote the central directory and end-of-archive record around $count recovered entries.',
      one:
          'Rewrote the central directory and end-of-archive record around 1 recovered entry.',
    );
    return '$_temp0';
  }

  @override
  String repairZipUndecompressable(String name) {
    return '\"$name\" could not be decompressed at all — dropped.';
  }

  @override
  String repairZipUnsupportedMethod(String name, int method) {
    return '\"$name\" uses compression method $method, which luma cannot decompress. It was copied through untouched.';
  }

  @override
  String repairZipChecksumMismatch(String name) {
    return '\"$name\" does not match its checksum — the contents came out damaged, but the entry was kept so you can see what is left of it.';
  }

  @override
  String repairZipOfficeComplete(String ext) {
    return 'All the parts a .$ext needs are present, so it should open.';
  }

  @override
  String repairZipOfficeMissing(String ext, String missing) {
    return 'The .$ext is still missing $missing. Those parts carry the document itself, and nothing can regenerate them.';
  }

  @override
  String get converterSaveDialogTitle => 'Save converted image';

  @override
  String converterSaved(String path) {
    return 'Saved to $path';
  }

  @override
  String converterReplacedOriginal(String path) {
    return 'Replaced original: $path';
  }

  @override
  String converterDownloaded(String name) {
    return 'Downloaded $name';
  }

  @override
  String get converterSaveUnsupported =>
      'Saving files is not supported on this platform.';

  @override
  String get converterReplaceUnsupported =>
      'Replacing files is not supported on this platform.';

  @override
  String get converterReplaceUnsupportedWeb =>
      'Replacing files is not supported on the web.';

  @override
  String get downscalerCouldNotRead => 'Could not read this image.';

  @override
  String get converterImageCouldNotRead =>
      'Could not read this image — it may be corrupt or unsupported.';

  @override
  String get ffmpegInstallDesktopOnly =>
      'Automatic install is only available on Windows. Please add ffmpeg to your PATH manually.';

  @override
  String ffmpegDownloadFailed(int status) {
    return 'Download failed (HTTP $status). Check your connection and try again.';
  }

  @override
  String get ffmpegArchiveMissingExe =>
      'The downloaded archive did not contain ffmpeg.exe.';

  @override
  String ffmpegInstallFailed(String error) {
    return 'Install failed: $error';
  }

  @override
  String get ffmpegInstalledNotStarted =>
      'Installed, but ffmpeg still could not be started.';

  @override
  String get ffmpegStillNotFound => 'Still not found.';

  @override
  String get ffmpegNotFound =>
      'ffmpeg was not found. Place ffmpeg(.exe) next to the app or on your system PATH, then try again.';

  @override
  String get ffmpegNotFoundShort => 'ffmpeg was not found.';

  @override
  String ffmpegFailedExitCode(int code) {
    return 'ffmpeg failed (exit code $code).';
  }

  @override
  String ffmpegFailedWithDetail(String detail) {
    return 'ffmpeg failed: $detail';
  }

  @override
  String get ffmpegStubDesktopOnly =>
      'Installing ffmpeg is only available in the desktop app.';

  @override
  String get ffmpegAudioVideoDesktopOnly =>
      'Audio and video conversion is only available in the desktop app.';

  @override
  String get ffmpegVideoDesktopOnly =>
      'Video conversion is only available in the desktop app.';

  @override
  String get ffmpegSetupTitle => 'ffmpeg is required';

  @override
  String get ffmpegSetupBodyInstall =>
      'Audio & video tools need ffmpeg. Install it once and luma will keep using it.';

  @override
  String get ffmpegSetupBodyManual =>
      'Audio & video tools need ffmpeg on your PATH. Automatic install is Windows-only.';

  @override
  String get ffmpegSetupPreparing => 'Preparing…';

  @override
  String ffmpegSetupDownloading(String percent) {
    return 'Downloading ffmpeg… $percent%';
  }

  @override
  String get ffmpegSetupInstall => 'Install ffmpeg';

  @override
  String get ffmpegSetupChecking => 'Checking…';

  @override
  String get ffmpegSetupRecheck => 'Re-check';

  @override
  String get converterSaveCancelled => 'Save cancelled.';

  @override
  String get schematicLitematicNoRegions =>
      'This .litematic file contains no regions.';

  @override
  String get schematicLitematicNoReadableRegions =>
      'None of the regions in this .litematic file could be read.';

  @override
  String schematicLitematicMergedRegions(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count regions',
      one: '1 region',
    );
    return 'The source had $_temp0; they were merged into one $size box.';
  }

  @override
  String get schematicLitematicConvertedName => 'Converted with luma';

  @override
  String get schematicLitematicMainRegion => 'Main';

  @override
  String get schematicMceditMissingSize =>
      'This .schematic file is missing its Width/Height/Length tags.';

  @override
  String get schematicMceditNoBlocks =>
      'This .schematic file has no Blocks array.';

  @override
  String schematicMceditUnmappedIds(int count, String list) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count legacy block ids had no modern equivalent and became air (ids $list).',
      one:
          '1 legacy block id had no modern equivalent and became air (id $list).',
    );
    return '$_temp0';
  }

  @override
  String get schematicMceditTileEntities =>
      'Tile entity contents (chest inventories, sign text) are not carried across.';

  @override
  String schematicMceditUnmappedTypes(int count, String list) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count block types did not exist before Minecraft 1.13 and became stone ($list).',
      one:
          '1 block type did not exist before Minecraft 1.13 and became stone ($list).',
    );
    return '$_temp0';
  }

  @override
  String schematicMceditInexactStates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count block states kept the right block but lost their orientation or variant.',
      one:
          '1 block state kept the right block but lost its orientation or variant.',
    );
    return '$_temp0';
  }

  @override
  String get schematicMcstructureNoSize =>
      'This .mcstructure file has no size tag.';

  @override
  String get schematicMcstructureNoIndices =>
      'This .mcstructure file has no block indices.';

  @override
  String get schematicMcstructureNoPalette =>
      'This .mcstructure file has no block palette.';

  @override
  String get schematicBedrockApproximate =>
      'Bedrock and Java do not share a block vocabulary, so this conversion is approximate.';

  @override
  String schematicBedrockReadApproximate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count palette entries had properties Java has no equivalent for.',
      one: '1 palette entry had properties Java has no equivalent for.',
    );
    return '$_temp0';
  }

  @override
  String schematicBedrockWriteApproximate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count palette entries lost a property Bedrock has no equivalent for.',
      one: '1 palette entry lost a property Bedrock has no equivalent for.',
    );
    return '$_temp0';
  }

  @override
  String schematicMcstructureTooLarge(String size) {
    return 'This build is $size. A Bedrock structure stores every position in two index lists, so one that size would be unusably large, and Bedrock only loads 64 blocks per side. Convert to .litematic or .schem instead.';
  }

  @override
  String get schematicMcstructureSplitNeeded =>
      'Bedrock structure blocks load at most 64×64×64 at a time, so this build will need splitting up in-game.';

  @override
  String get schematicFormatSpongeDescription => 'Sponge schematic (WorldEdit)';

  @override
  String get schematicFormatMceditDescription => 'MCEdit legacy';

  @override
  String get schematicFormatStructureDescription => 'Vanilla structure block';

  @override
  String get schematicFormatMcstructureDescription => 'Bedrock structure';

  @override
  String get schematicEmptyArea =>
      'This file declares an empty area, so there is nothing to convert.';

  @override
  String schematicVolumeTooLarge(
    int width,
    int height,
    int length,
    int millions,
  ) {
    return 'This build is $width×$height×$length, which is larger than the $millions million blocks the converter can hold in memory.';
  }

  @override
  String get schematicPaletteTooLarge =>
      'This build uses more than 65535 distinct block states, which is more than the converter can hold.';

  @override
  String get schematicNotRecognised =>
      'This file is not a Minecraft schematic, structure or litematic that luma recognises.';

  @override
  String get schematicLegacyPaletteLoss =>
      'The legacy format has no palette, so builds with many block variants lose the most detail here.';

  @override
  String get schematicSpongeMissingSize =>
      'This .schem file is missing its Width/Height/Length tags.';

  @override
  String get schematicSpongeV3NoBlocks =>
      'This version 3 .schem file has no Blocks tag.';

  @override
  String get schematicSpongeNoPalette =>
      'This .schem file has no block palette or block data.';

  @override
  String get schematicSpongeTruncatedValue =>
      'The block data ends in the middle of a value.';

  @override
  String get schematicSpongeCorrupt => 'The block data is corrupt.';

  @override
  String schematicSpongeShortBlocks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocks',
      one: '1 block',
    );
    return 'The block data stopped $_temp0 short of the declared size; the rest was filled with air.';
  }

  @override
  String get schematicStructureNoSize =>
      'This .nbt file has no size tag, so it is not a structure file.';

  @override
  String get schematicStructureNoPalette =>
      'This structure file has no palette.';

  @override
  String schematicStructureOutOfBounds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocks sat',
      one: '1 block sat',
    );
    return '$_temp0 outside the declared size and were skipped.';
  }

  @override
  String schematicStructureTooLarge(
    int width,
    int height,
    int length,
    int limit,
  ) {
    return 'This build is $width×$height×$length. A vanilla structure file stores every position separately, so one that size would be unusably large, and a structure block only loads $limit blocks per side. Convert to .litematic or .schem instead.';
  }

  @override
  String schematicStructureTooLong(
    int width,
    int height,
    int length,
    int limit,
  ) {
    return 'This build is $width×$height×$length, past the $limit-block limit a structure block can load. It will need splitting up in-game.';
  }

  @override
  String get schematicNbtNotCompoundRoot =>
      'The NBT root is not a compound tag.';

  @override
  String get schematicNbtNotNbt =>
      'This does not look like an NBT file: the root is not a compound tag.';

  @override
  String schematicNbtUnknownTag(int type, int position) {
    return 'Unknown NBT tag type $type at byte $position.';
  }

  @override
  String schematicNbtTruncated(int length, int position) {
    return 'The file is truncated or not valid NBT (bad length $length at byte $position).';
  }

  @override
  String get textureNoInstallation =>
      'No Minecraft installation found on this device.';

  @override
  String get textureFileNoBlockTextures =>
      'That file has no block textures in it.';

  @override
  String textureCouldNotRead(String error) {
    return 'Could not read block textures: $error';
  }

  @override
  String textureCouldNotDownload(String error) {
    return 'Could not download block textures: $error';
  }

  @override
  String get textureNeedsFilesystem =>
      'Block textures need a filesystem to read from.';

  @override
  String get textureDownloadUnsupported =>
      'Block textures can only be downloaded on desktop and Android.';

  @override
  String get textureMojangBadVersionId =>
      'Mojang returned an unusable version id.';

  @override
  String get textureCouldNotReachMojang =>
      'Could not reach Mojang. Check your connection and try again.';

  @override
  String textureManifestStatus(int code) {
    return 'Mojang returned $code for the version manifest.';
  }

  @override
  String textureClientStatus(int code) {
    return 'Mojang returned $code for the client download.';
  }

  @override
  String get textureManifestNoRelease =>
      'Mojang\'s version manifest did not name a current release.';

  @override
  String get textureManifestMalformed =>
      'Mojang\'s version manifest was malformed.';

  @override
  String textureManifestNoEntry(String version) {
    return 'Mojang\'s manifest has no entry for $version.';
  }

  @override
  String textureVersionNoClient(String version) {
    return 'Version $version has no client download.';
  }

  @override
  String get textureDownloadFailed =>
      'Could not download the textures. Check your connection and try again.';

  @override
  String textureDownloadEndedEarly(int received, int expected) {
    return 'The download ended early: got $received of $expected bytes.';
  }

  @override
  String get textureChecksumMismatch =>
      'The downloaded file did not match Mojang\'s checksum.';

  @override
  String get textureStageAskingVersion =>
      'Asking Mojang which version is current…';

  @override
  String get textureStageUsingCopy => 'Using the copy already downloaded.';

  @override
  String textureStageDownloading(String version) {
    return 'Downloading Minecraft $version…';
  }

  @override
  String get textureStageVerifying => 'Verifying the download…';

  @override
  String get textureStageReading => 'Reading block textures…';

  @override
  String get audioEditorTitle => 'Audio editor';

  @override
  String get audioEditorSubtitle =>
      'Cut, equalize, and preview audio before exporting';

  @override
  String get audioEditorPickPrompt => 'Tap to pick some audio';

  @override
  String get audioEditorEditAnother => 'Edit another';

  @override
  String get audioEditorReadingWaveform => 'Reading audio & building waveform…';

  @override
  String get audioEditorNoFilePath =>
      'Could not read the file path — editing needs the desktop app.';

  @override
  String get audioEditorCannotRead => 'Could not read this audio file.';

  @override
  String audioEditorLoadFailed(String error) {
    return 'Could not load this file: $error';
  }

  @override
  String get audioEditorEverythingCut =>
      'Everything has been cut — remove a cut first.';

  @override
  String get audioEditorPreviewDesktopOnly =>
      'Preview playback is only available in the desktop app.';

  @override
  String audioEditorPreviewFailed(String error) {
    return 'Could not play the preview: $error';
  }

  @override
  String audioEditorSaveFailed(String error) {
    return 'Could not save: $error';
  }

  @override
  String get audioEditorCutTitle => 'Cut & trim';

  @override
  String get audioEditorCutSubtitle =>
      'Drag on the waveform to select a range, then cut it out or keep only the selection.';

  @override
  String audioEditorSelectionRange(String start, String end) {
    return 'Selection  $start – $end';
  }

  @override
  String audioEditorOutputOfTotal(String output, String total) {
    return 'Output $output of $total';
  }

  @override
  String get audioEditorCutSelection => 'Cut selection out';

  @override
  String get audioEditorKeepSelection => 'Keep only selection';

  @override
  String get audioEditorClearCuts => 'Clear all cuts';

  @override
  String get audioEditorEqualizerTitle => 'Equalizer';

  @override
  String get audioEditorEqualizerSubtitle =>
      'Boost or cut each band by up to 12 dB.';

  @override
  String get audioEditorReset => 'Reset';

  @override
  String get audioEditorPresetFlat => 'Flat';

  @override
  String get audioEditorPresetBassBoost => 'Bass boost';

  @override
  String get audioEditorPresetVocal => 'Vocal';

  @override
  String get audioEditorPresetTreble => 'Treble';

  @override
  String get audioEditorEffectsTitle => 'Effects';

  @override
  String get audioEditorVolume => 'Volume';

  @override
  String get audioEditorSpeed => 'Speed';

  @override
  String get audioEditorFadeIn => 'Fade in';

  @override
  String get audioEditorFadeOut => 'Fade out';

  @override
  String get audioEditorPreviewRenderHint =>
      'Renders your edits, then plays the result.';

  @override
  String get audioEditorPreviewExactHint =>
      'Hear exactly what will be exported.';

  @override
  String get audioEditorMakeEditToExport =>
      'Make an edit above to enable exporting.';

  @override
  String get audioEditorGenerateSave => 'Generate & save';

  @override
  String get collageMakerTitle => 'Collage maker';

  @override
  String get collageMakerSubtitle => 'Create photo collages with templates';

  @override
  String get collageMakerImportPrompt => 'Import photos to get started';

  @override
  String get collageMakerImportedPhotos => 'Imported photos';

  @override
  String collageMakerPhotoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
    );
    return '$_temp0';
  }

  @override
  String get collageMakerChooseLayout => 'Choose a layout';

  @override
  String get collageMakerNewShape => 'New shape';

  @override
  String get collageMakerCanvas => 'Canvas';

  @override
  String collageMakerSlotsFilled(int slots, int filled) {
    return '$slots slots · $filled filled';
  }

  @override
  String get collageMakerDropHere => 'Drop here';

  @override
  String get collageMakerDragPhoto => 'Drag photo';

  @override
  String get collageMakerSettings => 'Settings';

  @override
  String get collageMakerAspectRatio => 'Aspect ratio';

  @override
  String get collageMakerBackground => 'Background';

  @override
  String get collageMakerGap => 'Gap';

  @override
  String get collageMakerRadius => 'Radius';

  @override
  String get collageMakerBgWhite => 'White';

  @override
  String get collageMakerBgBlack => 'Black';

  @override
  String get collageMakerBgTransparent => 'Transparent';

  @override
  String get collageMakerBgDark => 'Dark';

  @override
  String get collageMakerTplTwoHorizontal => '2 Horizontal';

  @override
  String get collageMakerTplTwoVertical => '2 Vertical';

  @override
  String get collageMakerTplThreeColumn => '3 Column';

  @override
  String get collageMakerTplTwoByTwo => '2×2 Grid';

  @override
  String get collageMakerTplLShape => 'L-Shape';

  @override
  String get collageMakerTplHeroStrip => 'Hero + Strip';

  @override
  String get collageMakerTplThreeByThree => '3×3 Grid';

  @override
  String get collageMakerTplMosaic => 'Mosaic';

  @override
  String get collageMakerTplPanorama => 'Panorama';

  @override
  String get collageMakerTplCross => 'Cross';

  @override
  String get collageMakerTplThreeRow => '3 Row';

  @override
  String get collageMakerTplFourColumn => '4 Column';

  @override
  String get collageMakerTplRightLShape => 'Right L-Shape';

  @override
  String get collageMakerTplStripHero => 'Strip + Hero';

  @override
  String get collageMakerTplSidebar => 'Sidebar';

  @override
  String get collageMakerTplFilmstrip => 'Filmstrip';

  @override
  String get collageMakerTplFrame => 'Frame';

  @override
  String get collageMakerTplWindowpane => 'Windowpane';

  @override
  String get collageMakerTplCascade => 'Cascade';

  @override
  String get collageMakerDownloadPng => 'Download PNG';

  @override
  String get collageMakerExportPng => 'Export PNG';

  @override
  String get collageMakerReset => 'Reset';

  @override
  String get collageMakerNewCollage => 'New collage';

  @override
  String collageMakerExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get collageShapeTitle => 'Design your layout';

  @override
  String get collageShapeSubtitle =>
      'Add, drag and resize frames to build your own shape';

  @override
  String get collageShapeLayout => 'Layout';

  @override
  String collageShapeFrameCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count frames',
      one: '1 frame',
    );
    return '$_temp0';
  }

  @override
  String get collageShapeName => 'Name';

  @override
  String get collageShapeNameHint => 'e.g. My layout';

  @override
  String get collageShapeSave => 'Save shape';

  @override
  String get collageShapeAddFrame => 'Add frame';

  @override
  String get collageShapeSplitHorizontal => 'Split ↔';

  @override
  String get collageShapeSplitVertical => 'Split ↕';

  @override
  String get collageShapeDelete => 'Delete';

  @override
  String get collageShapeClearAll => 'Clear all';

  @override
  String get collageShapeSnap => 'Snap to grid';

  @override
  String get collageShapeEmptyHint =>
      'Tap \"Add frame\" to start building your shape';

  @override
  String get downscalerTitle => 'Image downscaler';

  @override
  String get downscalerSubtitle =>
      'Shrink image file size with stackable optimizations';

  @override
  String get downscalerPickPrompt => 'Tap to pick a picture';

  @override
  String get downscalerPickFormats => 'PNG or JPEG';

  @override
  String get downscalerOptimizeAnother => 'Optimize another';

  @override
  String get downscalerReadFailed => 'Could not read the selected file.';

  @override
  String get downscalerDecodeFailed =>
      'Could not read this image — it may be corrupt or unsupported.';

  @override
  String downscalerEstimateFailed(String error) {
    return 'Could not estimate size: $error';
  }

  @override
  String get downscalerOptimizations => 'Optimizations';

  @override
  String get downscalerOptimizationsHint =>
      'Stack any of these. Hover for details; chips show what each saves on its own.';

  @override
  String get downscalerScale => 'Scale';

  @override
  String get downscalerColors => 'Colors';

  @override
  String get downscalerDithering => 'Dithering';

  @override
  String get downscalerDepth => 'Depth';

  @override
  String get downscalerBits32 => '32-bit';

  @override
  String get downscalerBits16 => '16-bit';

  @override
  String get downscalerBits8 => '8-bit';

  @override
  String get downscalerOriginal => 'Original';

  @override
  String downscalerEstimated(String format) {
    return 'Estimated ($format)';
  }

  @override
  String downscalerSavesPercent(String percent, String size) {
    return 'Saves $percent% ($size)';
  }

  @override
  String downscalerLargerPercent(String percent) {
    return '$percent% larger than the original';
  }

  @override
  String get downscalerOptimizeDownload => 'Optimize & download';

  @override
  String get downscalerOptimizeSave => 'Optimize & save';

  @override
  String get downscalerOptimizeReplace => 'Optimize & replace original';

  @override
  String get downscalerSelectOne => 'Select at least one optimization';

  @override
  String get downscalerResizeTitle => 'Resize resolution';

  @override
  String get downscalerResizeDesc =>
      'Scale the pixel dimensions down. Fewer pixels is usually the single biggest size saver.';

  @override
  String get downscalerColorDepthTitle => 'Reduce color depth';

  @override
  String get downscalerColorDepthDesc =>
      'Map the image onto a small color palette (e.g. 64 or 16 colors). Great for flat graphics and screenshots.';

  @override
  String get downscalerBitDepthTitle => 'Reduce bit depth';

  @override
  String get downscalerBitDepthDesc =>
      'Keep fewer bits per color channel (32 → 16 → 8-bit). Slightly banded but compresses much better.';

  @override
  String get downscalerStripMetadataTitle => 'Strip metadata';

  @override
  String get downscalerStripMetadataDesc =>
      'Remove the embedded ICC profile, EXIF and text chunks. No visible change.';

  @override
  String get downscalerRemoveAlphaTitle => 'Remove alpha channel';

  @override
  String get downscalerRemoveAlphaDesc =>
      'Drop the transparency channel. Only offered when the image is fully opaque, so it is lossless.';

  @override
  String get downscalerRemoveAlphaDisabled =>
      'Unavailable — this image either has no alpha channel or uses real transparency.';

  @override
  String get downscalerTrimTitle => 'Trim transparent borders';

  @override
  String get downscalerTrimDesc =>
      'Crop away fully transparent edges around the image.';

  @override
  String get downscalerTrimDisabled =>
      'Unavailable — no transparent border to trim.';

  @override
  String get downscalerPngRecompressTitle => 'PNG lossless re-compress';

  @override
  String get downscalerPngRecompressDesc =>
      'Re-encode the PNG at maximum compression. Safe, no visible change.';

  @override
  String get downscalerToWebpTitle => 'Convert to WebP';

  @override
  String get downscalerToWebpDesc =>
      'Encode the result as WebP, which is often much smaller than PNG.';

  @override
  String get downscalerToWebpDisabled =>
      'Unavailable — WebP needs ffmpeg (desktop app only).';

  @override
  String get convFileReadFailed => 'Could not read the selected file.';

  @override
  String get convTapToPickFile => 'Tap to pick a file';

  @override
  String get convOtherSubtitle => 'Odd jobs that fit nowhere else';

  @override
  String get convOtherMinecraftWorld => 'Minecraft world converter';

  @override
  String get convOtherMinecraftWorldSub =>
      'Java ↔ Bedrock · versions, entities, players & stats';

  @override
  String get convOtherMinecraftSchematics => 'Minecraft schematics';

  @override
  String get convOtherBadgeDamage => 'DAMAGE';

  @override
  String get convOtherBadgeRepair => 'REPAIR';

  @override
  String get convOtherCorruptor => 'File corruptor';

  @override
  String get convOtherCorruptorSub =>
      'Break a file on purpose — fix it later, or not';

  @override
  String get convOtherFixer => 'File fixer';

  @override
  String get convOtherFixerSub => 'Unbreak a file, or patch up a broken one';

  @override
  String get convOtherFooter =>
      'The schematic tool converts any of the five block formats into any other and shows the build in 3D before you save it. The corruptor and fixer are a pair: corrupt with a recipe and the fixer rebuilds the original byte for byte, or point the fixer at any damaged file and it rebuilds what structure it can.';

  @override
  String get convCorruptorSubtitle =>
      'Break a file on purpose, and keep the key to unbreak it';

  @override
  String get convCorruptPickSubtitle =>
      'Any file at all — the original is never touched';

  @override
  String get convCorruptDamageLabel => 'Damage';

  @override
  String get convCorruptPickMany => 'Pick one or more';

  @override
  String get convCorruptHowHard => 'How hard';

  @override
  String convCorruptSeed(String seed) {
    return 'Seed $seed';
  }

  @override
  String get convCorruptNewSeed => 'New seed';

  @override
  String get convCorruptButton => 'Corrupt file';

  @override
  String get convCorruptNoRecipeWarning =>
      'No recovery recipe will be written. Nothing — including luma — will be able to undo this.';

  @override
  String get convCorruptSaveCorrupted => 'Save corrupted file';

  @override
  String get convCorruptDownloadCorrupted => 'Download corrupted file';

  @override
  String get convCorruptKeepRecipe =>
      'Keep the recipe somewhere safe — it is the only thing that can undo this.';

  @override
  String get convCorruptSaveRecipe => 'Save .lumafix recipe';

  @override
  String get convCorruptDownloadRecipe => 'Download .lumafix recipe';

  @override
  String get convCorruptAnother => 'Corrupt another file';

  @override
  String get convCorruptRecoverable => 'Recoverable';

  @override
  String get convCorruptPermanent => 'Permanent';

  @override
  String get convCorruptRecipeTitle => 'Write a recovery recipe';

  @override
  String get convCorruptRecipeOn =>
      'A .lumafix file records every edit, so the fixer can rebuild the original exactly.';

  @override
  String get convCorruptRecipeOff =>
      'Nothing is recorded. The damage is permanent.';

  @override
  String convCorruptUnexpectedError(String error) {
    return 'Something went wrong while corrupting that file: $error';
  }

  @override
  String get convFixPickTitle => 'Tap to pick the damaged file';

  @override
  String get convFixPickSubtitle =>
      'Images · archives · documents · audio · video';

  @override
  String get convFixerSubtitle =>
      'Undo what the corruptor did, or patch up a broken file';

  @override
  String get convFixRecipeReadFailed => 'Could not read the recipe.';

  @override
  String convFixUnexpectedError(String error) {
    return 'Something went wrong while repairing that file: $error';
  }

  @override
  String get convFixBestEffort => 'Best-effort repair';

  @override
  String get convFixExactRestore => 'Exact restore from recipe';

  @override
  String get convFixNoRecipeBody =>
      'No recipe loaded, so luma will work out what the file is and rebuild whatever structure it can. Headers, checksums and indexes can come back; bytes that were overwritten cannot.';

  @override
  String convFixRecipeInfo(String age, String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count steps',
      one: '1 step',
    );
    return 'Recorded $age for “$name” in $_temp0. The original comes back byte for byte.';
  }

  @override
  String get convFixAgeJustNow => 'just now';

  @override
  String convFixAgeMinutes(int count) {
    return '$count min ago';
  }

  @override
  String convFixAgeHours(int count) {
    return '$count h ago';
  }

  @override
  String convFixAgeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get convFixLoadRecipe => 'Load a .lumafix recipe';

  @override
  String get convFixAnalyseRepair => 'Analyse & repair';

  @override
  String get convFixRestoreOriginal => 'Restore original';

  @override
  String get convFixDownloadRepaired => 'Download repaired file';

  @override
  String get convFixSaveRepaired => 'Save repaired file';

  @override
  String get convFixAnother => 'Fix another';

  @override
  String get convFixRestoredExactly => 'Restored exactly';

  @override
  String convFixRepairsApplied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count repairs applied',
      one: '1 repair applied',
    );
    return '$_temp0';
  }

  @override
  String get convFixNothingToRepair => 'Nothing to repair';

  @override
  String convFixSizeInOut(String from, String to) {
    return '$from in · $to out';
  }

  @override
  String get convFixStructuralWarning =>
      'A structural repair puts the container back together. It cannot invent content that was overwritten — check the result before you rely on it.';

  @override
  String get convMediaAudioTitle => 'Audio converter';

  @override
  String get convMediaAudioSubtitle =>
      'Convert between MP3, OGG, FLAC, M4A, WAV and AAC';

  @override
  String get convMediaVideoTitle => 'Video converter';

  @override
  String get convMediaVideoSubtitle =>
      'Convert between MP4, MOV, WEBM, OGV, MPG, M4V (or to M4A)';

  @override
  String get convMediaNoFilePath =>
      'Could not read the file path — conversion needs the desktop app.';

  @override
  String convMediaConvertFailed(String error) {
    return 'Something went wrong while converting: $error';
  }

  @override
  String get convMediaConvertTo => 'Convert to';

  @override
  String get convMediaQuality => 'Quality';

  @override
  String get convMediaQualitySmaller => 'Smaller';

  @override
  String get convMediaQualityBalanced => 'Balanced';

  @override
  String get convMediaQualityHigh => 'High';

  @override
  String get convMediaConvertSave => 'Convert & save';

  @override
  String get convMediaConvertAnother => 'Convert another';

  @override
  String convImgEditUnexpectedError(String error) {
    return 'Something went wrong: $error';
  }

  @override
  String get convImgEditCantRead => 'Could not read this image.';

  @override
  String convImgEditSaveFailed(String error) {
    return 'Could not save: $error';
  }

  @override
  String get convImgEditTitle => 'Image editor';

  @override
  String get convImgEditSubtitle =>
      'Rotate, adjust, filter, and remove backgrounds';

  @override
  String get convImgEditPickTitle => 'Tap to pick a picture';

  @override
  String get convImgEditSaveReplace => 'Save & replace original';

  @override
  String get convImgEditDownloadPng => 'Download PNG';

  @override
  String get convImgEditSavePng => 'Save PNG';

  @override
  String get convImgEditResetEdits => 'Reset edits';

  @override
  String get convImgEditAnother => 'Edit another';

  @override
  String get convImgEditMetadata => 'Metadata';

  @override
  String get convImgEditTransform => 'Transform';

  @override
  String get convImgEditAdjustments => 'Adjustments';

  @override
  String get convImgEditFilters => 'Filters';

  @override
  String get convImgEditBgRemoval => 'Background removal';

  @override
  String get convImgEditBgRemovalBody =>
      'Make white pixels transparent. Raise the tolerance to also catch off-white pixels.';

  @override
  String get convImgEditRotateLeft => 'Rotate left';

  @override
  String get convImgEditRotateRight => 'Rotate right';

  @override
  String get convImgEditFlipHorizontal => 'Flip horizontal';

  @override
  String get convImgEditFlipVertical => 'Flip vertical';

  @override
  String get convImgEditBrightness => 'Brightness';

  @override
  String get convImgEditContrast => 'Contrast';

  @override
  String get convImgEditSaturation => 'Saturation';

  @override
  String get convImgEditFilterGrayscale => 'Grayscale';

  @override
  String get convImgEditFilterSepia => 'Sepia';

  @override
  String get convImgEditFilterInvert => 'Invert';

  @override
  String get convImgEditTolerance => 'Tolerance';

  @override
  String get convImgEditRemoveAllMeta => 'Remove all';

  @override
  String get convImgEditMetaExisting =>
      'This image already has embedded metadata. Edit it below, or remove it all.';

  @override
  String get convImgEditMetaNew =>
      'Add a title, author, or copyright notice to the saved file.';

  @override
  String get convImgEditAuthor => 'Author';

  @override
  String get convImgEditCopyright => 'Copyright';

  @override
  String get convImgEditNotSet => 'Not set';

  @override
  String get pictureConvUnsupported =>
      'That file is not a supported image (PNG, JPG, BMP, TIFF, ICO, SVG or OIP).';

  @override
  String get pictureConvSubtitle =>
      'Convert between PNG, JPG, BMP, TIFF, ICO, SVG and OIP';

  @override
  String get pictureConvSvgVector =>
      'SVG is vector — it will be rasterized at a crisp size before converting.';

  @override
  String get pictureConvConvertDownload => 'Convert & download';

  @override
  String get schemConvTitle => 'Minecraft schematics';

  @override
  String get schemConvSubtitle =>
      'Convert between schem, litematic, schematic, nbt and mcstructure';

  @override
  String get schemConvPickPrompt => 'Tap to pick a build';

  @override
  String get schemConvReading => 'Reading the build…';

  @override
  String schemConvReadFailed(String error) {
    return 'Something went wrong while reading that file: $error';
  }

  @override
  String get schemConvBedrockNote =>
      'Bedrock uses different block ids and states from Java, so this direction is a best-effort translation.';

  @override
  String get schemConvConvertDownload => 'Convert & download';

  @override
  String get schemConvWorthKnowing => 'Worth knowing';

  @override
  String schemConvBlockCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocks',
      one: '1 block',
    );
    return '$_temp0';
  }

  @override
  String get schemConvPreview3d => '3D preview';

  @override
  String get schemConvPreviewHint => 'Drag to orbit · scroll to zoom';

  @override
  String get schemConvMaterials => 'Materials';

  @override
  String get schemConvStatBlocks => 'Blocks';

  @override
  String get schemConvStatVolume => 'Volume';

  @override
  String get schemConvStatBlockTypes => 'Block types';

  @override
  String get schemConvNoBlocks => 'This build has no blocks in it.';

  @override
  String get schemConvShowFewer => 'Show fewer';

  @override
  String schemConvShowAll(int count) {
    return 'Show all $count block types';
  }

  @override
  String get schemViewerEmpty => 'Nothing to show — this build is all air.';

  @override
  String schemViewerSemantics(int width, int height, int length) {
    return '3D preview of the build, $width by $height by $length blocks. Drag to rotate, or use the rotate and zoom buttons below.';
  }

  @override
  String schemViewerSimplified(int stride) {
    return 'This build is too large to draw block-for-block, so the preview is simplified $stride× — the converted file keeps every block.';
  }

  @override
  String schemViewerDownloadProgress(
    String stage,
    String received,
    String total,
  ) {
    return '$stage $received of $total';
  }

  @override
  String schemViewerTexturesFrom(String source, int count) {
    return 'Textures from $source ($count blocks)';
  }

  @override
  String schemViewerFlatColours(String size) {
    return 'Flat colours — no Minecraft found. Download the textures from Mojang (~$size) or use your own copy.';
  }

  @override
  String schemViewerFailureFallback(String failure) {
    return '$failure Showing flat block colours.';
  }

  @override
  String get schemViewerDownloadTextures => 'Download textures';

  @override
  String get schemViewerUseInstall => 'Use my install';

  @override
  String get schemViewerLayers => 'Layers';

  @override
  String schemViewerLayerRange(int startY, int endY) {
    return 'Y $startY–$endY';
  }

  @override
  String get schemViewerZoomOut => 'Zoom out';

  @override
  String get schemViewerZoomIn => 'Zoom in';

  @override
  String get schemViewerResetView => 'Reset the view';

  @override
  String get vidDownNoPath =>
      'Could not read the file path — video downscaling needs the desktop app.';

  @override
  String get vidDownProbeFailed =>
      'Could not read this video — it may be unsupported or ffmpeg is missing.';

  @override
  String vidDownEstimateFailed(String error) {
    return 'Could not estimate size: $error';
  }

  @override
  String get vidDownSubtitle =>
      'Compress & shrink video with stackable optimizations';

  @override
  String get vidDownPickPrompt => 'Tap to pick a video';

  @override
  String get vidDownShrinkAnother => 'Shrink another';

  @override
  String get vidDownShrinkDownload => 'Shrink & download';

  @override
  String get vidDownShrinkSave => 'Shrink & save';

  @override
  String get vidDownOptimizationsHint =>
      'Stack any of these. Hover any option for details.';

  @override
  String get vidDownMaxHeight => 'Max height';

  @override
  String get vidDownFrameRate => 'Frame rate';

  @override
  String get vidDownAudio => 'Audio';

  @override
  String get vidDownCrfHigh => 'High quality';

  @override
  String get vidDownCrfSmallest => 'Smallest';

  @override
  String vidDownCrfLabel(String word, int crf) {
    return '$word · CRF $crf';
  }

  @override
  String get vidDownResizeTitle => 'Resize resolution';

  @override
  String get vidDownResizeBody =>
      'Cap the frame height (e.g. 1080p → 720p), keeping aspect ratio. The biggest size saver for high-resolution video.';

  @override
  String get vidDownQualityTitle => 'Quality (CRF)';

  @override
  String get vidDownQualityBody =>
      'The main compression dial. Lower keeps more detail; higher makes a much smaller file.';

  @override
  String get vidDownFpsTitle => 'Frame rate cap';

  @override
  String get vidDownFpsBody =>
      'Limit frames per second (e.g. 60 → 30). Invisible for most footage and cuts size noticeably.';

  @override
  String get vidDownH265Title => 'Re-encode to H.265';

  @override
  String get vidDownH265Body =>
      'Use the newer HEVC codec — roughly 40–50% smaller than H.264 at the same quality, but slower to encode and less compatible with old players.';

  @override
  String get vidDownAudioBitrateTitle => 'Reduce audio bitrate';

  @override
  String get vidDownAudioBitrateBody =>
      'Re-encode the soundtrack at a lower bitrate (e.g. 96 kbps).';

  @override
  String get vidDownNoAudio => 'Unavailable — this video has no audio track.';

  @override
  String get vidDownRemoveAudioTitle => 'Remove audio track';

  @override
  String get vidDownRemoveAudioBody =>
      'Drop audio entirely — ideal for screen recordings and silent clips.';

  @override
  String get vidDownStripTitle => 'Strip metadata';

  @override
  String get vidDownStripBody =>
      'Remove embedded metadata and chapter markers. No visible change.';

  @override
  String get vidDownWebmTitle => 'Convert to WebM (VP9)';

  @override
  String get vidDownWebmBody =>
      'Re-encode to the VP9/WebM codec — often smaller than H.264 and great for the web. Slower to encode; outputs a .webm file.';

  @override
  String vidDownSmaller(String percent, String saved) {
    return '≈ $percent% smaller (saves $saved)';
  }

  @override
  String vidDownLarger(String percent) {
    return '≈ $percent% larger than the original';
  }

  @override
  String vidDownSampleNote(String seconds) {
    return 'Estimated from a ${seconds}s sample — the final size may vary.';
  }

  @override
  String get worldConvPickFolderTitle =>
      'Select the world folder containing level.dat';

  @override
  String get worldConvPickArchiveTitle => 'Select an exported Minecraft world';

  @override
  String get worldConvReading => 'Reading the world…';

  @override
  String get worldConvPickOutputTitle =>
      'Choose where to save the converted world';

  @override
  String get worldConvSubtitle =>
      'Java ↔ Bedrock · terrain, entities and player data';

  @override
  String get worldConvPlatformUnsupported =>
      'World conversion is available on Windows and Linux.';

  @override
  String get worldConvIntro =>
      'Close this world in Minecraft before converting. Choose its folder or an exported .mcworld / .zip file, or paste its path below. The original stays unchanged.';

  @override
  String get worldConvChooseFolder => 'Choose world folder';

  @override
  String get worldConvChooseArchive => 'Choose .mcworld file';

  @override
  String get worldConvPathLabel => 'World folder or .mcworld / .zip path';

  @override
  String get worldConvPathHint => 'Paste a path here';

  @override
  String get worldConvLoad => 'Load world';

  @override
  String worldConvCensusLine(
    String edition,
    int entities,
    int localPlayers,
    int remotePlayers,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      entities,
      locale: localeName,
      other: '$entities entities',
      one: '1 entity',
    );
    String _temp1 = intl.Intl.pluralLogic(
      localPlayers,
      locale: localeName,
      other: '$localPlayers local players',
      one: '1 local player',
    );
    String _temp2 = intl.Intl.pluralLogic(
      remotePlayers,
      locale: localeName,
      other: '$remotePlayers additional players',
      one: '1 additional player',
    );
    return '$edition · $_temp0 · $_temp1 · $_temp2';
  }

  @override
  String get worldConvTargetVersion => 'Target Minecraft version';

  @override
  String get worldConvVersionNote =>
      'Java 1.8.8–26.3 and Bedrock 1.12–1.26.60 release formats. Targets before Java 1.13 or Bedrock 1.18.30 require excluding entities and players. Incompatible selected records cause an error. Custom dimensions are refused.';

  @override
  String get worldConvEntitiesTitle => 'Convert entities';

  @override
  String get worldConvEntitiesBody =>
      'Mobs, pets, villagers, vehicles and passengers. Every source entity must match a saved output record or conversion fails. Projectiles still in mid-air are listed, not carried over.';

  @override
  String get worldConvPlayersTitle => 'Convert players';

  @override
  String worldConvPlayersMultiple(int count) {
    return 'This world has $count additional player records. Turn off Convert players to convert terrain and entities. Moving these players requires account mappings.';
  }

  @override
  String get worldConvPlayersSingle =>
      'Single-player inventory, equipment and position. Additional players require account mappings and cause an error when selected.';

  @override
  String get worldConvStatsTitle => 'Preserve statistics';

  @override
  String get worldConvStatsBody =>
      'Java stats are archived for conversion back to Java. Bedrock has no compatible per-world stats format.';

  @override
  String get worldConvChooseOutput => 'Choose output location';

  @override
  String worldConvAlreadyEdition(String edition) {
    return 'This world is already $edition. Choose the other edition to convert it.';
  }

  @override
  String get worldConvConvertVerify => 'Convert & verify world';

  @override
  String worldConvSaved(String path) {
    return 'Saved to $path';
  }

  @override
  String worldConvEntitiesVerified(int count) {
    return '$count entity records verified.';
  }

  @override
  String get worldConvEntitiesExcluded => 'Entities excluded.';

  @override
  String get pictureConvRasterizeFailed => 'Could not rasterize the SVG.';

  @override
  String get worldEditionJava => 'Java Edition';

  @override
  String get worldEditionBedrock => 'Bedrock Edition';

  @override
  String worldConvEntityUnrepresentable(
    String target,
    String entity,
    String minimum,
  ) {
    return '$target cannot represent $entity. Choose $minimum or newer, or exclude entities.';
  }

  @override
  String get worldConvInvalidEntityPosition =>
      'Invalid entity position in world audit.';

  @override
  String get worldConvWrongTargetVersion =>
      'The saved world has the wrong target version.';

  @override
  String get worldConvAdditionalPlayers =>
      'Additional players need Java UUID / Bedrock XUID mappings. Player conversion currently supports single-player worlds.';

  @override
  String get worldConvLocalPlayerMissing =>
      'The local player was not transferred.';

  @override
  String get worldConvPlayersRemain =>
      'Excluded player records remain in the output.';

  @override
  String get worldConvEntitiesRemain =>
      'Excluded entities remain in the output.';

  @override
  String worldConvEntityVerificationFailed(String detail) {
    return 'Entity transfer failed verification: $detail. The converted world was not saved. Your source is unchanged.';
  }

  @override
  String get worldConvUnsupportedPlatform =>
      'World conversion requires Windows or Linux.';

  @override
  String get worldConvEngineMissing =>
      'The world conversion engine is missing from this build. Install a desktop build containing the world converter.';

  @override
  String worldConvEngineStopped(String code) {
    return 'The world conversion engine stopped unexpectedly (exit code $code). The original world has not changed.';
  }

  @override
  String get worldConvMissingAudit => 'Missing saved-world audit.';

  @override
  String get worldConvVersionEngineMissing =>
      'The Minecraft version engine is missing from this build. Install a desktop build containing both world conversion engines.';

  @override
  String worldConvVersionConversionFailed(String detail) {
    return 'Version conversion failed: $detail';
  }

  @override
  String worldConvExitCodeDetail(String code) {
    return 'exit code $code';
  }

  @override
  String get worldConvLinkedFiles => 'Linked world files are not supported.';

  @override
  String get worldConvProgressCopy =>
      'Opening a temporary copy of the source world…';

  @override
  String get worldConvProgressChecking => 'Checking entities and players…';

  @override
  String get worldConvChooseOtherEdition =>
      'Choose the other Minecraft edition.';

  @override
  String get worldConvProgressConverting =>
      'Converting terrain, containers and selected records…';

  @override
  String worldConvProgressTerrain(String target) {
    return 'Converting terrain to $target…';
  }

  @override
  String get worldConvProgressVerifying =>
      'Verifying entities in the saved world…';

  @override
  String worldConvProgressAdapting(String target) {
    return 'Adapting selected records to $target…';
  }

  @override
  String get worldConvOutputInsideSource =>
      'Choose an output folder outside your source world.';

  @override
  String get worldConvOutputExists =>
      'The output path already exists. Choose a new name.';

  @override
  String get worldConvJavaTooOldForRecords =>
      'Java targets before 1.13 cannot safely store entity/player records. Choose Java 1.13 or newer, or turn off Convert entities and Convert players. The original world has not changed.';

  @override
  String get worldConvBedrockTooOldForRecords =>
      'Bedrock targets before 1.18.30 require older entity/player storage that this converter cannot safely write. Choose a newer target or exclude those records. The original world has not changed.';

  @override
  String get worldConvOlderJavaCannotRead =>
      'This older Java target cannot safely read the selected newer entity/player schemas. Choose a newer Java version or exclude those records. The original world has not changed.';

  @override
  String get worldConvUnsupportedTarget => 'Unsupported target version.';

  @override
  String get worldConvChooseWorldSource =>
      'Choose a world folder or an exported .mcworld / .zip file.';

  @override
  String get worldConvMissingLevelDat =>
      'The selected world is missing level.dat.';

  @override
  String get worldConvNoJavaStats =>
      'No Java world statistics were present. Bedrock account statistics are not stored in the world.';

  @override
  String get worldConvJavaStatsRestored =>
      'Java statistics restored from the archive.';

  @override
  String get worldConvJavaStatsArchived =>
      'Java statistics archived for a later conversion back to Java. Bedrock cannot display them.';

  @override
  String get worldConvArchiveUnsafePath =>
      'The world archive contains an unsafe file path.';

  @override
  String get worldConvArchiveDuplicatePath =>
      'The world archive contains duplicate file paths.';

  @override
  String get worldConvArchiveLinkedFiles =>
      'Linked files in world archives are not supported.';

  @override
  String get worldConvArchiveNeedsOneLevel =>
      'The archive must contain exactly one world with level.dat.';

  @override
  String worldConvArchiveTruncated(String path) {
    return 'The world archive contains a truncated file: $path';
  }

  @override
  String worldConvArchiveDamaged(String path) {
    return 'The world archive contains a damaged file: $path';
  }

  @override
  String get homeGithubUnavailable => 'GitHub is unavailable.';

  @override
  String get homeGithubConnectHint =>
      'Connect GitHub to see your activity and private repositories. Your token stays on this device.';

  @override
  String get homeGithubConnect => 'Connect GitHub';

  @override
  String get homeGithubRefresh => 'Refresh GitHub';

  @override
  String get homeGithubRecentIssues => 'Recent issues';

  @override
  String homeGithubContributions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contributions',
      one: '1 contribution',
    );
    return '$_temp0';
  }

  @override
  String get homeGithubNoIssues =>
      'No recent issues in the connected account snapshot.';

  @override
  String get homeGithubOpenFailed => 'Could not open GitHub.';

  @override
  String get homeGithubNoHistory =>
      'Contribution history is not available yet.';

  @override
  String homeGithubCommitsAndPrs(int commits, int prs) {
    String _temp0 = intl.Intl.pluralLogic(
      commits,
      locale: localeName,
      other: '$commits commits',
      one: '1 commit',
    );
    String _temp1 = intl.Intl.pluralLogic(
      prs,
      locale: localeName,
      other: '$prs pull requests',
      one: '1 pull request',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get homeGithubPastYear =>
      'Past year · includes private activity allowed by your token';

  @override
  String get homeStocksFinanceUnavailable => 'Finance is unavailable.';

  @override
  String get homeStocksLoadFailed => 'Could not load your holdings.';

  @override
  String get homeStocksAddHoldings =>
      'Add holdings in Finance, or choose a ticker in this tile’s settings.';

  @override
  String get homeStocksRefreshPrices => 'Refresh prices';

  @override
  String get homeStocksHistoryUnavailable =>
      'Price history unavailable. Try refreshing.';

  @override
  String get homeAiUsageUnavailable => 'AI usage is unavailable.';

  @override
  String get homeAiUsageNewTokens => 'new tokens · last 7 days';

  @override
  String homeAiUsageTurns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count turns',
      one: '1 turn',
    );
    return '$_temp0 across local AI tools';
  }

  @override
  String get homeAiUsageReadFailed => 'Could not read usage records.';

  @override
  String get homeAiUsageScanHint =>
      'Scan this device to import supported AI session logs.';

  @override
  String get homeAiUsageScanFailed => 'Scan failed. Try again.';

  @override
  String get homeAiUsageScanning => 'Scanning…';

  @override
  String get homeAiUsageScan => 'Scan usage';

  @override
  String get homeAiUsageLocalNote =>
      'Local session records; excludes cached input replays.';

  @override
  String get homeLayoutDifferentFormat =>
      'This home layout belongs to a different device format.';

  @override
  String get homeTileInvalid => 'Invalid home tile.';

  @override
  String get homeTileDuplicate => 'Duplicate home tile.';

  @override
  String get homeLayoutInvalid => 'Invalid home layout.';

  @override
  String homeLayoutLoadFailed(String error) {
    return 'Your saved layout could not be loaded. $error';
  }

  @override
  String get homeConnectFinancesSummary =>
      'Connect your finances to see this summary.';

  @override
  String get homeCouldNotLoadInvestments => 'Could not load investments.';

  @override
  String get homeCouldNotLoadFinances => 'Could not load finances.';

  @override
  String get homeShortcutPasswords => 'Passwords';

  @override
  String get homeShortcutAssistantSubtitle => 'Have a chat, ask anything';

  @override
  String get homeShortcutFinanceSubtitle => 'Your money, pots & stocks';

  @override
  String get homeShortcutConverterSubtitle => 'Change up images & files';

  @override
  String get homeShortcutSettingsSubtitle => 'Colours, theme & stuff';

  @override
  String get homeShortcutNotesSubtitle => 'Your ideas, close at hand';

  @override
  String get homeShortcutPasswordsSubtitle => 'Keep your secrets safe';

  @override
  String get homeShortcutPluginsSubtitle => 'Discover your next little helper';

  @override
  String get homeNothingRecentYet =>
      'Nothing here yet. Your next chapter starts with your first transaction.';

  @override
  String get homeRecentTransactionsEmpty =>
      'Your recent transactions will appear here.';

  @override
  String get homeCouldNotLoadRecentActivity =>
      'Could not load recent activity.';

  @override
  String get homeActivityIncome => 'Income';

  @override
  String get homeActivityExpense => 'Expense';

  @override
  String get homeResizeTileSemantics =>
      'Resize tile. Use tile menu for precise size.';

  @override
  String get homeEmptyGridTitle => 'A space for your everyday';

  @override
  String get homeEmptyGridBody =>
      'Add notes, shortcuts, charts and little helpers.';

  @override
  String get homeAddFirstTile => 'Add your first tile';

  @override
  String get homeSectionRecent => 'What you\'ve been up to';

  @override
  String homeEditTileTooltip(String title) {
    return 'Edit $title';
  }

  @override
  String get homeTileConfigure => 'Configure';

  @override
  String get homeTilePositionSize => 'Position & size';

  @override
  String get homeTileRemove => 'Remove tile';

  @override
  String get homePositionColumn => 'Column';

  @override
  String get homePositionRow => 'Row';

  @override
  String get homePositionWidth => 'Width in columns';

  @override
  String get homePositionHeight => 'Height in rows';

  @override
  String get homePositionHint =>
      'Positions start at 1. Tiles snap to the grid and make room automatically.';

  @override
  String get homeChooseShortcut => 'Choose a shortcut';

  @override
  String get homeChooseNote => 'Choose a note';

  @override
  String get homeUntitledNote => 'Untitled note';

  @override
  String get homeCreateNoteFirst => 'Create a note in Notes first.';

  @override
  String get homeChoosePlugin => 'Choose a plugin';

  @override
  String get homeInstallPluginFirst =>
      'Install a plugin from the marketplace first.';

  @override
  String get homeChooseInstance => 'Choose an instance';

  @override
  String get homeCreateInstanceFirst =>
      'Create an instance in Minecraft Launcher first.';

  @override
  String get homeStockSymbolInput => 'Stock symbol (blank for all holdings)';

  @override
  String get homeTimerMinutesInput => 'Timer minutes (1–1440)';

  @override
  String get homeRepositoryInput => 'Repository: owner/name (blank for all)';

  @override
  String get homeQuickConvertFiles => 'Convert files';

  @override
  String get homeQuickFinances => 'Finances';

  @override
  String get homeTileUnavailable =>
      'This tile is not available in this version.';

  @override
  String get homeCouldNotLoadPlugins => 'Could not load installed plugins.';

  @override
  String homeInstallPluginToUse(String name) {
    return 'Install $name to use this tile.';
  }

  @override
  String get homeNoteTileEmpty =>
      'Choose a note using this tile’s settings. Notes must be synced separately to appear on another device.';

  @override
  String get homeChoosePluginInSettings =>
      'Choose an installed plugin in tile settings.';

  @override
  String get homeCouldNotLoadErrands => 'Could not load errands.';

  @override
  String get homeErrandsEmpty =>
      'Add your recurring tasks in the Errands plugin.';

  @override
  String get homeErrandDueToday => 'Due today';

  @override
  String homeErrandUpdateFailed(String error) {
    return 'Could not update errand: $error';
  }

  @override
  String get homeMinecraftAddAccount =>
      'Add an account in Minecraft Launcher first.';

  @override
  String homeLaunchFailed(String error) {
    return 'Launch failed: $error';
  }

  @override
  String get homeMinecraftPreparing => 'Preparing…';

  @override
  String get homeMinecraftRunning => 'Running';

  @override
  String get homeMinecraftPlayNow => 'Play now';

  @override
  String get homeChooseInstanceInSettings =>
      'Choose an instance available on this device in tile settings.';

  @override
  String get homeCalcHint => 'e.g. (42 + 8) / 2';

  @override
  String get homeTimeIsUp => 'Time is up. Take a breath.';

  @override
  String get homeTimerHint => 'A little space to focus.';

  @override
  String get homeAvailableBalance => 'AVAILABLE BALANCE';

  @override
  String homeInPotsAmount(String amount) {
    return 'In pots  $amount';
  }

  @override
  String homeTotalCashAmount(String amount) {
    return 'Total cash  $amount';
  }

  @override
  String get notesNewNoteTooltip => 'New note';

  @override
  String get notesNewNoteButton => '+ New Note';

  @override
  String get notesNoNotesYet => 'No notes yet';

  @override
  String get notesBackTooltip => 'Back to notes';

  @override
  String get notesAddChecklistTooltip => 'Add checklist item';

  @override
  String get notesJotHint => 'Jot something down…';

  @override
  String get notesTapEditToAdd => 'Tap Edit to add content.';

  @override
  String get notesNoneSelected => 'No note selected';

  @override
  String get notesCreateToStart => 'Create a new note to get started.';

  @override
  String get passwordsUnreadableCredential => 'Unreadable credential';

  @override
  String get passwordsErrorEnterService => 'Enter the service name.';

  @override
  String get passwordsErrorEnterEmail => 'Enter the email.';

  @override
  String get passwordsErrorEnterPassword => 'Enter the password.';

  @override
  String get passwordsErrorInvalidTotp =>
      'That doesn\'t look like a valid 2FA secret (should be base32, e.g. JBSWY3DPEHPK3PXP).';

  @override
  String passwordsErrorPickImage(String error) {
    return 'Failed to pick image: $error';
  }

  @override
  String get passwordsWeakTitle => 'Weak password';

  @override
  String get passwordsWeakBody =>
      'This password is on a list of extremely common or previously breached passwords. Anyone with that list could guess it. Use the generate button for a strong one, or save it anyway.';

  @override
  String get passwordsSaveAnyway => 'Save anyway';

  @override
  String get passwordsUploadPng => 'Upload PNG';

  @override
  String get passwordsGenerateTooltip => 'Generate random password';

  @override
  String get passwordsShow => 'Show';

  @override
  String get passwordsHide => 'Hide';

  @override
  String get passwordsReveal => 'Reveal';

  @override
  String get passwordsNewCredential => 'New credential';

  @override
  String get passwordsEditCredential => 'Edit credential';

  @override
  String get passwordsFieldService => 'Service *';

  @override
  String get passwordsFieldIconOptional => 'Icon (Optional)';

  @override
  String get passwordsFieldEmail => 'Email *';

  @override
  String get passwordsFieldPassword => 'Password *';

  @override
  String get passwordsFieldUsername => 'Username (optional)';

  @override
  String get passwordsFieldPhone => 'Phone number (optional)';

  @override
  String get passwordsFieldInfo => 'Info (optional)';

  @override
  String get passwordsFieldTotp => '2FA secret (optional)';

  @override
  String get passwordsHintService => 'e.g. Netflix';

  @override
  String get passwordsHintIcon => 'e.g. 🍿';

  @override
  String get passwordsHintUsername => 'e.g. ayden31';

  @override
  String get passwordsHintPhone => 'e.g. +31 6 1234 5678';

  @override
  String get passwordsHintInfo => 'Security question, recovery codes, notes…';

  @override
  String get passwordsHintTotp =>
      'Base32 key from the \"manual setup\" QR fallback';

  @override
  String get passwordsSaveChanges => 'Save changes';

  @override
  String get passwordsAddCredential => 'Add credential';

  @override
  String get passwordsSearchHint => 'Search by service, email or username';

  @override
  String get passwordsEmptyTitle => 'No passwords saved yet';

  @override
  String get passwordsEmptySubtitle =>
      'Passwords and 2FA seeds are encrypted on this device.';

  @override
  String get passwordsNoMatches => 'No matches';

  @override
  String passwordsNoMatchesSubtitle(String query) {
    return 'No login looks like \"$query\".';
  }

  @override
  String get passwordsTotpCode => '2FA code';

  @override
  String passwordsCopiedToast(String label) {
    return '$label copied';
  }

  @override
  String get passwordsEnterPinToUnlock => 'Enter PIN to unlock';

  @override
  String get passwordsIncorrectPin => 'Incorrect PIN';

  @override
  String get passwordsDeleteTitle => 'Delete credential?';

  @override
  String passwordsDeleteBody(String service) {
    return 'This will permanently remove the saved credential for \"$service\".';
  }

  @override
  String get passwordsCopyPassword => 'Copy password';

  @override
  String get passwordsCopyEmail => 'Copy email';

  @override
  String get passwordsCopyUsername => 'Copy username';

  @override
  String get passwordsCopyTotp => 'Copy 2FA code';

  @override
  String get passwordsDecryptFailed =>
      '⚠ Could not decrypt — data corrupt or key file changed';

  @override
  String get passwordsInvalidSecret => 'Invalid secret';

  @override
  String get passwordsPhone => 'Phone';

  @override
  String get passwordsInfo => 'Info';

  @override
  String get passwordsBreachedWarning =>
      'This password was found in a known breach — change it where you use it.';

  @override
  String get nativeWebviewNoHost => 'This build has no native webview host.';

  @override
  String get accountOverviewPasteTokenFirst =>
      'Paste a personal access token first.';

  @override
  String get accountOverviewStageIdle => 'Idle';

  @override
  String get accountOverviewStageProfile => 'Reading your profile';

  @override
  String get accountOverviewStageRepos => 'Listing repositories';

  @override
  String get accountOverviewStageContributions => 'Counting contributions';

  @override
  String get accountOverviewStageDownloads => 'Adding up release downloads';

  @override
  String get accountOverviewStageIssues =>
      'Collecting issues and pull requests';

  @override
  String get accountOverviewStageActions => 'Fetching workflow runs';

  @override
  String get accountOverviewStageBilling => 'Reading usage and allowances';

  @override
  String accountOverviewWarnContributions(String error) {
    return 'Contribution graph unavailable: $error';
  }

  @override
  String accountOverviewWarnDownloads(String error) {
    return 'Release downloads unavailable: $error';
  }

  @override
  String accountOverviewWarnIssues(String error) {
    return 'Issues and pull requests unavailable: $error';
  }

  @override
  String accountOverviewWarnWorkflowRuns(String error) {
    return 'Workflow runs unavailable: $error';
  }

  @override
  String accountOverviewWarnBilling(String error) {
    return 'Usage and allowances unavailable: $error';
  }

  @override
  String get accountOverviewSectionRepositories => 'Repositories';

  @override
  String get accountOverviewSectionIssues => 'Issues & PRs';

  @override
  String get accountOverviewSectionActions => 'Actions';

  @override
  String get accountOverviewSectionUsage => 'Usage';

  @override
  String get accountOverviewSectionMcContent => 'MC Content';

  @override
  String get accountOverviewSectionVideos => 'Videos';

  @override
  String get accountOverviewSectionAnalytics => 'Analytics';

  @override
  String get accountOverviewSectionStats => 'Stats';

  @override
  String get accountOverviewBlurbOverview => 'Commits, stars, activity';

  @override
  String get accountOverviewBlurbRepositories => 'Every repo you own';

  @override
  String get accountOverviewBlurbIssues => 'What is open on you';

  @override
  String get accountOverviewBlurbActions => 'Workflow runs and health';

  @override
  String get accountOverviewBlurbUsage => 'Copilot, storage, compute';

  @override
  String get accountOverviewBlurbYoutubeOverview =>
      'Subscribers, views, videos';

  @override
  String get accountOverviewBlurbYoutubeVideos => 'Every recent upload';

  @override
  String get accountOverviewBlurbYoutubeAnalytics =>
      'Watch time, traffic, subscribers';

  @override
  String get accountOverviewBlurbSpotifyStats =>
      'Top music, recent plays, library';

  @override
  String get accountOverviewConnected => 'Connected';

  @override
  String get accountOverviewNotSetUp => 'Not set up';

  @override
  String accountOverviewServiceTooltip(String service, String status) {
    return '$service — $status';
  }

  @override
  String accountOverviewSectionListLabel(String service) {
    return '$service section list';
  }

  @override
  String accountOverviewSectionTooltip(String label, String blurb) {
    return '$label — $blurb';
  }

  @override
  String get accountOverviewMoreServicesComing => 'More services coming';

  @override
  String get accountOverviewExpandSidebar => 'Expand sidebar';

  @override
  String get accountOverviewCollapseSidebar => 'Collapse sidebar';

  @override
  String get accountOverviewCollapse => 'Collapse';

  @override
  String get accountOverviewRefreshing => 'Refreshing…';

  @override
  String accountOverviewStageInProgress(String stage) {
    return '$stage…';
  }

  @override
  String accountOverviewStepOf(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get accountOverviewAccountSettings => 'Account settings';

  @override
  String get accountOverviewConnectGithubTitle => 'Connect your GitHub account';

  @override
  String get accountOverviewConnectGithubSubtitle =>
      'See your commits, stars, downloads, repositories, issues and workflow runs in one place — plus your Copilot, storage and compute allowances.';

  @override
  String get accountOverviewConnectGithubButton => 'Connect GitHub';

  @override
  String get accountOverviewGithubPrivacy =>
      'luma stores your personal access token encrypted on this device and talks to api.github.com directly. Nothing about your GitHub account is sent to a luma server, and no account is needed to use this plugin.';

  @override
  String get accountOverviewConnectYoutubeTitle =>
      'Connect your YouTube channel';

  @override
  String get accountOverviewConnectYoutubeSubtitle =>
      'See your subscribers, views, recent uploads and deep analytics — watch time, traffic sources and subscriber trends — in one place.';

  @override
  String get accountOverviewConnectYoutubeButton => 'Connect YouTube';

  @override
  String get accountOverviewYoutubePrivacy =>
      'luma stores your Google OAuth credentials encrypted on this device and talks to Google directly. Nothing about your account is sent to a luma server, and no luma account is needed to use this plugin.';

  @override
  String get accountOverviewGithubRateLimited =>
      'GitHub rate limit reached. Try again shortly.';

  @override
  String accountOverviewGithubRateLimitResets(String time) {
    return 'GitHub rate limit reached. It resets at $time.';
  }

  @override
  String get accountOverviewGithubTokenRejected =>
      'GitHub rejected the token. It may have expired or been revoked.';

  @override
  String accountOverviewGithubRefused(String path) {
    return 'GitHub refused $path. The token is probably missing a scope.';
  }

  @override
  String accountOverviewGithubHttpError(String code, String path) {
    return 'GitHub returned HTTP $code for $path.';
  }

  @override
  String get accountOverviewGithubUnexpectedProfile =>
      'GitHub returned an unexpected profile payload.';

  @override
  String get accountOverviewGithubUnexpectedGraphql =>
      'GitHub returned an unexpected GraphQL payload.';

  @override
  String get accountOverviewGithubContributionsFailed =>
      'GitHub could not read your contribution graph.';

  @override
  String get accountOverviewBillingItemActionsMinutes => 'Actions minutes';

  @override
  String get accountOverviewBillingItemSharedStorage => 'shared storage';

  @override
  String get accountOverviewBillingItemCopilot => 'Copilot usage';

  @override
  String get accountOverviewGithubBillingNoAccess =>
      'This token cannot read billing. A classic token needs the \"user\" scope; a fine-grained token needs the \"Plan\" permission (read-only).';

  @override
  String accountOverviewGithubBillingMissing(String items) {
    return 'GitHub did not return $items for this account.';
  }

  @override
  String get accountOverviewGithubWorkflowDefault => 'Workflow';

  @override
  String get accountOverviewCopilotUnitDefault => 'requests';

  @override
  String get accountOverviewModrinthNoUser =>
      'Modrinth has no user by that name.';

  @override
  String get accountOverviewModrinthTokenRejected =>
      'Modrinth rejected the token. Check it has the analytics scope.';

  @override
  String get accountOverviewModrinthRateLimited =>
      'Modrinth rate limit reached. Try again shortly.';

  @override
  String accountOverviewModrinthHttpError(String code) {
    return 'Modrinth returned HTTP $code.';
  }

  @override
  String get accountOverviewModrinthUnexpectedPayload =>
      'Modrinth returned an unexpected user payload.';

  @override
  String get accountOverviewCurseforgeKeyRejected =>
      'CurseForge rejected the API key. Generate one in the CurseForge for Studios console.';

  @override
  String accountOverviewCurseforgeHttpError(String code) {
    return 'CurseForge returned HTTP $code.';
  }

  @override
  String get accountOverviewCurseforgeNeedKey =>
      'Add your CurseForge API key first.';

  @override
  String get accountOverviewCurseforgeBadSlug =>
      'That does not look like a CurseForge project URL or slug.';

  @override
  String accountOverviewCurseforgeNoProject(String slug) {
    return 'CurseForge has no project called \"$slug\".';
  }

  @override
  String get accountOverviewCurseforgeNeedAuthor =>
      'Add your CurseForge author id, or track projects individually.';

  @override
  String get accountOverviewCurseforgeNeedKeyToInclude =>
      'Add a CurseForge API key to include it.';

  @override
  String get accountOverviewModrinthNeedUsername =>
      'Add your Modrinth username to include it.';

  @override
  String get accountOverviewPmcNeedUsername =>
      'Add your Planet Minecraft username to include it.';

  @override
  String get accountOverviewPmcNeedsBrowser =>
      'Planet Minecraft needs an embedded browser, which is not available on this platform.';

  @override
  String get accountOverviewCurseforgeTrackedProjects => 'tracked projects';

  @override
  String get accountOverviewSpotifyUnknownArtist => 'Unknown artist';

  @override
  String get accountOverviewSpotifyUnknownTrack => 'Unknown track';

  @override
  String accountOverviewSpotifyHttpError(String code) {
    return 'Spotify returned HTTP $code.';
  }

  @override
  String get accountOverviewSpotifyOAuthTimedOut =>
      'Timed out waiting for Spotify. Try connecting again.';

  @override
  String get accountOverviewSpotifyConnectedPage =>
      'Spotify connected. Return to luma.';

  @override
  String get accountOverviewSpotifyFailedPage =>
      'Spotify connection failed. Return to luma.';

  @override
  String accountOverviewSpotifyDeclined(String error) {
    return 'Spotify declined: $error';
  }

  @override
  String get accountOverviewSpotifyInvalidResponse =>
      'Spotify sign-in response was invalid.';

  @override
  String get accountOverviewSpotifyNoAccessToken =>
      'Spotify did not return an access token.';

  @override
  String get accountOverviewSpotifyCouldNotOpenPage =>
      'Could not open the Spotify sign-in page.';

  @override
  String accountOverviewSpotifyReadSavedFailed(String error) {
    return 'Could not read the saved Spotify connection: $error';
  }

  @override
  String get accountOverviewSpotifyEnterClientId =>
      'Enter your Spotify Client ID.';

  @override
  String get accountOverviewSpotifyNoRefreshToken =>
      'Spotify did not return a refresh token.';

  @override
  String get accountOverviewSpotifyAccountDefault => 'Spotify account';

  @override
  String get accountOverviewSpotifyNotConnected => 'Spotify is not connected.';

  @override
  String get accountOverviewSpotifyConnectionChanged =>
      'Spotify connection changed while refreshing.';

  @override
  String get accountOverviewSpotifyPaginationStalled =>
      'Spotify recent-play pagination did not advance.';

  @override
  String get accountOverviewSpotifyHistoryGap =>
      'Spotify history does not reach the last counted play. Some plays may be missing.';

  @override
  String accountOverviewSpotifyWarningListeningTotal(String error) {
    return 'Listening total: $error';
  }

  @override
  String accountOverviewSpotifyWarningRecentPlays(String error) {
    return 'Recent plays: $error';
  }

  @override
  String accountOverviewSpotifyWarningLabeled(String label, String error) {
    return '$label: $error';
  }

  @override
  String get accountOverviewSpotifyTopArtists => 'Top artists';

  @override
  String get accountOverviewSpotifyTopTracks => 'Top tracks';

  @override
  String get accountOverviewSpotifySavedTracks => 'Saved tracks';

  @override
  String get accountOverviewSpotifyPlaylists => 'Playlists';

  @override
  String accountOverviewSpotifyRefreshFailed(String error) {
    return 'Could not refresh Spotify: $error';
  }

  @override
  String get accountOverviewKindSubmission => 'submission';

  @override
  String get accountOverviewKindMod => 'mod';

  @override
  String get accountOverviewKindModpack => 'modpack';

  @override
  String get accountOverviewKindSkin => 'skin';

  @override
  String get accountOverviewKindProject => 'project';

  @override
  String get accountOverviewKindResourcePack => 'resource pack';

  @override
  String get accountOverviewKindDataPack => 'data pack';

  @override
  String get accountOverviewKindBlog => 'blog';

  @override
  String get accountOverviewKindServer => 'server';

  @override
  String get accountOverviewKindCollection => 'collection';

  @override
  String get accountOverviewKindCustomization => 'customization';

  @override
  String get accountOverviewKindAddon => 'addon';

  @override
  String get accountOverviewKindShader => 'shader';

  @override
  String get accountOverviewKindWorld => 'world';

  @override
  String get accountOverviewJustNow => 'just now';

  @override
  String accountOverviewMonthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months ago',
      one: '1 month ago',
    );
    return '$_temp0';
  }

  @override
  String accountOverviewYearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years ago',
      one: '1 year ago',
    );
    return '$_temp0';
  }

  @override
  String get accountOverviewTimeUnknown => 'unknown';

  @override
  String accountOverviewMinutesValue(String value) {
    return '$value min';
  }

  @override
  String accountOverviewHoursValue(String value) {
    return '$value h';
  }

  @override
  String accountOverviewDurationSeconds(String seconds) {
    return '${seconds}s';
  }

  @override
  String accountOverviewDurationMinutesSeconds(String minutes, String seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String accountOverviewDurationHoursMinutes(String hours, String minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String get accountOverviewWeekdayMonShort => 'Mon';

  @override
  String get accountOverviewWeekdayWedShort => 'Wed';

  @override
  String get accountOverviewWeekdayFriShort => 'Fri';

  @override
  String get accountOverviewAllowanceUsedUp => 'Allowance used up';

  @override
  String get accountOverviewNearAllowance => 'Nearly at your allowance';

  @override
  String get accountOverviewNoIncludedAllowance =>
      'GitHub did not report an included allowance.';

  @override
  String get accountOverviewSetAllowance => 'Set it';

  @override
  String accountOverviewAllowanceIncluded(String unit, String total) {
    return '$unit of $total $unit included';
  }

  @override
  String accountOverviewMeterSemantics(
    String label,
    String used,
    String total,
    String unit,
    String percent,
  ) {
    return '$label: $used of $total $unit used, $percent';
  }

  @override
  String accountOverviewStatSemantics(String label, String value) {
    return '$label: $value';
  }

  @override
  String accountOverviewStatSemanticsCaption(
    String label,
    String value,
    String caption,
  ) {
    return '$label: $value. $caption';
  }

  @override
  String get accountOverviewNoContributionData => 'No contribution data yet.';

  @override
  String accountOverviewNoContributionsOn(String date) {
    return 'No contributions on $date';
  }

  @override
  String accountOverviewContributionsOn(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contributions on $date',
      one: '1 contribution on $date',
    );
    return '$_temp0';
  }

  @override
  String get accountOverviewLess => 'Less';

  @override
  String get accountOverviewRunFilterAll => 'All runs';

  @override
  String get accountOverviewFailed => 'Failed';

  @override
  String get accountOverviewRunFilterInProgress => 'In progress';

  @override
  String get accountOverviewRunFilterSucceeded => 'Succeeded';

  @override
  String get accountOverviewNoWorkflowRuns => 'No workflow runs';

  @override
  String get accountOverviewNoWorkflowRunsSub =>
      'luma checks your twelve most recently pushed repositories. Runs appear here once one of them has CI history.';

  @override
  String get accountOverviewNoRunsMatch => 'No runs match';

  @override
  String accountOverviewNoRunsMatchSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Clear the filter to see all $count runs.',
      one: 'Clear the filter to see the 1 run.',
    );
    return '$_temp0';
  }

  @override
  String get accountOverviewSuccessRate => 'Success rate';

  @override
  String get accountOverviewNoCompletedRuns => 'no completed runs';

  @override
  String get accountOverviewOfRecentCompletedRuns => 'of recent completed runs';

  @override
  String get accountOverviewRunsSeen => 'Runs seen';

  @override
  String get accountOverviewMostRecentFirst => 'most recent first';

  @override
  String accountOverviewRunsInProgress(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count in progress',
      one: '1 in progress',
    );
    return '$_temp0';
  }

  @override
  String get accountOverviewInThisWindow => 'in this window';

  @override
  String get accountOverviewAverageDuration => 'Average duration';

  @override
  String get accountOverviewPerCompletedRun => 'per completed run';

  @override
  String get accountOverviewFilterByRepository => 'Filter by repository';

  @override
  String get accountOverviewAllRepositories => 'All repositories';

  @override
  String get githubConnectTitle => 'Connect GitHub';

  @override
  String get githubReconnectTitle => 'Reconnect GitHub';

  @override
  String githubConnectConnectedNotice(String login, String tokenEnd) {
    return 'Connected as $login with a token ending $tokenEnd. Pasting a new token replaces it.';
  }

  @override
  String get githubConnectTokenLabel => 'Personal access token';

  @override
  String get githubConnectShowToken => 'Show token';

  @override
  String get githubConnectHideToken => 'Hide token';

  @override
  String get githubConnectTokenPrivacy =>
      'The token is encrypted on this device and sent only to api.github.com. It never reaches a luma server.';

  @override
  String get githubConnectAction => 'Connect';

  @override
  String get githubConnectDisconnect => 'Disconnect';

  @override
  String get githubConnectScopesTitle => 'Scopes to tick';

  @override
  String get githubConnectScopeRepo =>
      'Private repositories, their issues and their workflow runs';

  @override
  String get githubConnectScopeReadUser => 'Profile, followers, contributions';

  @override
  String get githubConnectScopeUser => 'Usage, storage and Copilot allowances';

  @override
  String get githubConnectFineGrainedNote =>
      'A fine-grained token wants the equivalent read-only permissions plus \"Plan\".';

  @override
  String get githubConnectOpenTokenSettings => 'Open GitHub token settings';

  @override
  String get githubDisconnectTitle => 'Disconnect GitHub?';

  @override
  String get githubDisconnectBody =>
      'The stored token and every cached number are deleted from this device. Your GitHub account itself is untouched.';

  @override
  String get githubDisconnectKeep => 'Keep it';

  @override
  String get githubAllowanceTitle => 'Your monthly allowances';

  @override
  String get githubAllowanceIntro =>
      'GitHub reports what you have used but not always what your plan includes. Fill in the figures from your billing page and the meters get a bar; leave one blank and it shows the raw usage instead.';

  @override
  String get githubAllowanceOpenBilling => 'Open GitHub billing';

  @override
  String get githubAllowanceCopilotLabel => 'Copilot allowance';

  @override
  String get githubAllowanceCopilotHelper =>
      'Included AI credits or premium requests per month';

  @override
  String get githubAllowanceStorageLabel => 'Storage allowance';

  @override
  String get githubAllowanceStorageHelper =>
      'Included Packages and Actions storage, in GB';

  @override
  String get githubAllowanceMinutesLabel => 'Actions compute allowance';

  @override
  String get githubAllowanceMinutesHelper =>
      'Included workflow minutes per month';

  @override
  String get githubAllowanceHint => 'Leave blank if you do not know';

  @override
  String get githubOpenIssues => 'Open issues';

  @override
  String get githubOpenPrs => 'Open PRs';

  @override
  String get githubMergedPrs => 'Merged PRs';

  @override
  String get githubClosedIssues => 'Closed issues';

  @override
  String get githubIssuesFilterAll => 'Everything';

  @override
  String get githubIssuesFilterMerged => 'Merged';

  @override
  String get githubIssuesFilterClosed => 'Closed';

  @override
  String get githubCaptionYouOpened => 'you opened';

  @override
  String get githubCaptionAwaitingReview => 'awaiting review';

  @override
  String get githubCaptionAllTime => 'all time';

  @override
  String get githubIssuesEmptyTitle => 'Nothing to show yet';

  @override
  String get githubIssuesEmptySubtitle =>
      'Issues and pull requests you are involved in appear here after a refresh.';

  @override
  String githubIssuesNothingInFilter(String filter) {
    return 'Nothing in $filter';
  }

  @override
  String get githubIssuesPickAnotherFilter =>
      'Pick another filter to see the rest.';

  @override
  String get githubStatusMergedPr => 'Merged pull request';

  @override
  String get githubStatusClosedPr => 'Closed pull request';

  @override
  String get githubStatusDraftPr => 'Draft pull request';

  @override
  String get githubStatusOpenPr => 'Open pull request';

  @override
  String get githubStatusOpenIssue => 'Open issue';

  @override
  String get githubStatusClosedIssue => 'Closed issue';

  @override
  String githubIssueRowMeta(String repo, String number, String when) {
    return '$repo #$number  ·  updated $when';
  }

  @override
  String githubIssueCommentsSemantic(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comments',
      one: '1 comment',
    );
    return '$_temp0';
  }

  @override
  String get githubContributions => 'Contributions';

  @override
  String githubContributionsInLastYear(String count) {
    return '$count in the last year';
  }

  @override
  String get githubContributionsYearActivity => 'The last year of activity';

  @override
  String get githubTopRepositories => 'Top repositories';

  @override
  String get githubByStars => 'By stars';

  @override
  String get githubViewAll => 'View all';

  @override
  String get githubLanguages => 'Languages';

  @override
  String get githubByRepoCount => 'By repository count';

  @override
  String get githubLatestRuns => 'Latest workflow runs';

  @override
  String get githubNoRepositoriesYet => 'No repositories yet.';

  @override
  String get githubNoLanguagesYet => 'No languages detected yet.';

  @override
  String get githubNoRunsFound =>
      'No workflow runs found in your most recently pushed repositories.';

  @override
  String get githubNotRefreshedYet => 'Not refreshed yet';

  @override
  String githubUpdated(String when) {
    return 'Updated $when';
  }

  @override
  String get githubProfile => 'Profile';

  @override
  String githubFollowers(String count) {
    return '$count followers';
  }

  @override
  String githubFollowing(String count) {
    return '$count following';
  }

  @override
  String githubCompanySemantic(String name) {
    return 'Company $name';
  }

  @override
  String githubLocationSemantic(String name) {
    return 'Location $name';
  }

  @override
  String githubJoined(String date) {
    return 'Joined $date';
  }

  @override
  String githubAvatarSemantic(String login) {
    return '$login avatar';
  }

  @override
  String githubCurrentStreakSemantic(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Current streak $days days',
      one: 'Current streak 1 day',
    );
    return '$_temp0';
  }

  @override
  String githubLongestStreakSemantic(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Longest streak $days days',
      one: 'Longest streak 1 day',
    );
    return '$_temp0';
  }

  @override
  String githubStreakCurrent(String days) {
    return '${days}d streak';
  }

  @override
  String githubStreakBest(String days) {
    return '${days}d best';
  }

  @override
  String get githubCommits => 'Commits';

  @override
  String githubPrivateCountPlus(String count) {
    return '+$count private';
  }

  @override
  String get githubInLastYear => 'in the last year';

  @override
  String get githubStarsEarned => 'Stars earned';

  @override
  String githubAcrossRepos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count repos',
      one: '1 repo',
    );
    return 'across $_temp0';
  }

  @override
  String get githubRepositories => 'Repositories';

  @override
  String githubPrivateCount(String count) {
    return '$count private';
  }

  @override
  String get githubDownloads => 'Downloads';

  @override
  String get githubReleaseAssets => 'release assets';

  @override
  String githubClosedCount(String count) {
    return '$count closed';
  }

  @override
  String githubOpenCount(String count) {
    return '$count open';
  }

  @override
  String get githubForks => 'Forks';

  @override
  String get githubOfYourRepos => 'of your repos';

  @override
  String get githubRecent => 'recent';

  @override
  String get githubWorkflowRuns => 'Workflow runs';

  @override
  String get githubRunStatusInProgress => 'In progress';

  @override
  String get githubRunStatusSucceeded => 'Succeeded';

  @override
  String get githubRunStatusFailed => 'Failed';

  @override
  String get githubRunStatusCancelled => 'Cancelled';

  @override
  String get githubRunStatusSkipped => 'Skipped';

  @override
  String get githubRunStatusUnknown => 'Unknown';

  @override
  String get githubRepoSortRecentlyPushed => 'Recently pushed';

  @override
  String get githubRepoSortStars => 'Stars';

  @override
  String get githubRepoFilterSources => 'Sources';

  @override
  String get githubPrivate => 'Private';

  @override
  String get githubPublic => 'Public';

  @override
  String get githubFork => 'Fork';

  @override
  String get githubArchived => 'Archived';

  @override
  String get githubRepoSearchHint => 'Find a repository';

  @override
  String get githubRepoSortTooltip => 'Sort repositories';

  @override
  String get githubReposEmptyTitle => 'No repositories';

  @override
  String get githubReposEmptySubtitle =>
      'Refresh once your account has repositories, or widen the token scope to include private ones.';

  @override
  String get githubReposNothingMatches => 'Nothing matches this filter';

  @override
  String githubReposNoMatch(String query) {
    return 'No repositories match \"$query\"';
  }

  @override
  String get githubReposTryDifferent =>
      'Try a different filter or a shorter search.';

  @override
  String githubReposCountOf(int shown, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$shown of $total repositories',
      one: '$shown of 1 repository',
    );
    return '$_temp0';
  }

  @override
  String get githubReposStarsInView => 'Stars in view';

  @override
  String get githubReposDownloadsInView => 'Downloads in view';

  @override
  String get githubReposSizeInView => 'Size in view';

  @override
  String githubStarsCount(String count) {
    return '$count stars';
  }

  @override
  String githubForksCount(String count) {
    return '$count forks';
  }

  @override
  String githubOpenIssuesAndPrsCount(String count) {
    return '$count open issues and pull requests';
  }

  @override
  String githubReleaseDownloadsCount(String count) {
    return '$count release downloads';
  }

  @override
  String githubSizeSemantic(String size) {
    return 'Size $size';
  }

  @override
  String get ghUsageBillingUnavailable =>
      'Billing data is not available for this token.';

  @override
  String get ghUsageReconnect => 'Reconnect';

  @override
  String get ghUsageThisPeriod => 'This billing period';

  @override
  String get ghUsageCopilotUsage => 'Copilot usage';

  @override
  String ghUsageCopilotSpend(String amount) {
    return 'Billed beyond the included allowance: $amount';
  }

  @override
  String get ghUsageNoCopilotSpend =>
      'Nothing billed beyond the included allowance.';

  @override
  String get ghUsageStorage => 'Storage';

  @override
  String get ghUsageStorageSubtitle =>
      'Live Actions artifacts, private repos only';

  @override
  String get ghUsageSharedStorage => 'Shared storage';

  @override
  String ghUsageStoragePartial(int counted, int total) {
    return 'Counted the $counted most recently active of your $total private repositories. Public repositories are never metered, so they are left out entirely.';
  }

  @override
  String get ghUsageStorageSummed =>
      'Summed directly from every private repository\'s Actions artifacts — GitHub has no API for Packages storage, so that is not included.';

  @override
  String get ghUsagePackagesBandwidth => 'Packages bandwidth';

  @override
  String get ghUsageWorkflowCompute => 'Workflow compute';

  @override
  String get ghUsageActionsSubtitle => 'GitHub Actions minutes';

  @override
  String get ghUsageActionsMinutes => 'Actions minutes';

  @override
  String get ghUsageUnitMinutes => 'minutes';

  @override
  String ghUsageMinutesBilled(String minutes) {
    return '$minutes minutes billed beyond the allowance.';
  }

  @override
  String get ghUsageAdjustAllowances => 'Adjust your allowances';

  @override
  String get ghUsageFootnote =>
      'GitHub reports consumption but not always the allowance that goes with it. Meters without a bar are waiting on a figure from your billing page.';

  @override
  String get ghUsageDaysLeft => 'Days left in cycle';

  @override
  String get ghUsageUntilReset => 'until the meters reset';

  @override
  String get ghUsageBilledThisPeriod => 'Billed this period';

  @override
  String get ghUsageBeyondIncluded => 'beyond included allowances';

  @override
  String get ghUsageUsageLines => 'Usage lines';

  @override
  String get ghUsageProductsWithActivity => 'products with activity';

  @override
  String get ghUsageByRunner => 'By runner';

  @override
  String get ghUsageNoBillable => 'No billable usage reported for this period.';

  @override
  String get ghUsageConnectForBreakdown =>
      'Connect a token that can read billing to see the breakdown.';

  @override
  String get ghUsageBreakdownTitle => 'Usage breakdown';

  @override
  String get ghUsageBreakdownSubtitle =>
      'Totalled by product for this billing period';

  @override
  String get ghUsageColProduct => 'Product';

  @override
  String get ghUsageColQuantity => 'Quantity';

  @override
  String get ghUsageColBilled => 'Billed';

  @override
  String get mcAll => 'All';

  @override
  String get mcMetricDownloads => 'Downloads';

  @override
  String get mcMetricFollowers => 'Followers';

  @override
  String get mcMetricViews => 'Views';

  @override
  String mcChartSemantics(
    String metric,
    String fromDate,
    String toDate,
    String low,
    String high,
  ) {
    return '$metric from $fromDate to $toDate: $low up to $high';
  }

  @override
  String mcChartValueWithMetric(String count, String metric) {
    return '$count $metric';
  }

  @override
  String mcGainSemantics(int days, String peak) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return 'Daily gain over $_temp0, peaking at $peak';
  }

  @override
  String mcGainTooltip(String count) {
    return '+$count downloads';
  }

  @override
  String get mcChartNoHistory => 'No history yet';

  @override
  String get mcChartOneDay => 'One day recorded so far';

  @override
  String get mcChartCollecting =>
      'These platforms publish a running total and no history, so luma records one point per day. The line appears once there are two.';

  @override
  String get mcViewProjects => 'Projects';

  @override
  String get mcViewTrends => 'Trends';

  @override
  String get mcPlatformSettings => 'Platform settings';

  @override
  String get mcViaEmbeddedBrowser => 'via embedded browser';

  @override
  String mcReadingPlatform(String platform) {
    return 'Reading $platform…';
  }

  @override
  String get mcCombinedLibrary => 'Combined library';

  @override
  String get mcCombinedLibrarySubtitle =>
      'CurseForge and Modrinth, added together.';

  @override
  String get mcCurseforgeModrinthCombined => 'CurseForge and Modrinth combined';

  @override
  String get mcTotalDownloads => 'Total downloads';

  @override
  String get mcAcrossBothPlatforms => 'across both platforms';

  @override
  String get mcLast30Days => 'Last 30 days';

  @override
  String get mcDownloadsGained => 'downloads gained';

  @override
  String get mcStillCollecting => 'still collecting';

  @override
  String get mcFollowersCaption => 'followers and thumbs-up';

  @override
  String mcProjectsSplit(int cf, int mr) {
    return '$cf CF · $mr MR';
  }

  @override
  String get mcNothingToShowYet => 'Nothing to show yet.';

  @override
  String mcSemDownloads(int count) {
    return '$count downloads';
  }

  @override
  String mcSemFollowers(int count) {
    return '$count followers';
  }

  @override
  String mcSemViews(int count) {
    return '$count views';
  }

  @override
  String mcProjectsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count projects',
      one: '1 project',
    );
    return '$_temp0';
  }

  @override
  String mcUpdatedRelative(String when) {
    return 'updated $when';
  }

  @override
  String get mcSetUp => 'Set up';

  @override
  String get mcSetUpPlatforms => 'Set up platforms';

  @override
  String get mcStateNotSetUp => 'Not set up';

  @override
  String get mcStateConnected => 'Connected';

  @override
  String get mcStateUnavailable => 'Unavailable';

  @override
  String get mcPmcKeptSeparate =>
      'Kept separate — PMC counts views, and its skins, blogs and builds are not mods.';

  @override
  String get mcPmcAddUsername =>
      'Add your Planet Minecraft username to include it.';

  @override
  String get mcPmcApproximate =>
      'Planet Minecraft rounds views and downloads above a thousand on listing pages (“1.1k”), so these totals are approximate. Diamonds and favourites are exact.';

  @override
  String get mcPmcViewsDownloadsOverTime => 'Views and downloads over time';

  @override
  String get mcRecordedOnePointPerDay => 'Recorded by luma, one point per day';

  @override
  String get mcApproximate => 'approximate';

  @override
  String get mcAcrossSubmissions => 'across submissions';

  @override
  String get mcExact => 'exact';

  @override
  String get mcDiamonds => 'Diamonds';

  @override
  String get mcFavourites => 'Favourites';

  @override
  String mcFavouritesCount(int count) {
    return '$count favourites';
  }

  @override
  String mcSubmissionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count submissions',
      one: '1 submission',
    );
    return '$_temp0';
  }

  @override
  String get mcFindProject => 'Find a project';

  @override
  String get mcNoProjectsYet => 'No projects yet';

  @override
  String get mcNothingMatchesFilter => 'Nothing matches this filter';

  @override
  String get mcSetUpToPullProjects =>
      'Set up a platform and refresh to pull your projects in.';

  @override
  String get mcTryDifferentFilter =>
      'Try a different platform or a shorter search.';

  @override
  String get mcBadgeRounded => 'rounded';

  @override
  String get mcDownloadsOverTime => 'Downloads over time';

  @override
  String get mcHoverBarTopProjects =>
      'Hover a bar for the top projects that day';

  @override
  String get mcDownloadsGainedPerDay => 'Downloads gained per day';

  @override
  String mcPlatformDownloads(String platform) {
    return '$platform downloads';
  }

  @override
  String get mcPmcViews => 'PMC views';

  @override
  String get mcPmcApproximateSubtitle =>
      'Approximate — PMC rounds figures above a thousand';

  @override
  String get mcPmcDownloads => 'PMC downloads';

  @override
  String mcSinceDate(String date) {
    return 'since $date';
  }

  @override
  String get mcSetupTitle => 'Track your Minecraft content';

  @override
  String get mcSetupSubtitle =>
      'Pull CurseForge, Modrinth and Planet Minecraft into one dashboard — downloads, followers, views and trends over time.';

  @override
  String get mcReqModrinthTitle => 'Modrinth — username only';

  @override
  String get mcReqModrinthBody =>
      'Totals are public. A token is optional and only unlocks real download history.';

  @override
  String get mcReqCurseforgeTitle => 'CurseForge — API key required';

  @override
  String get mcReqCurseforgeBody =>
      'CurseForge serves nothing anonymously. Add a key plus either your numeric author id or individual project links.';

  @override
  String get mcReqPmcTitle => 'Planet Minecraft — username only';

  @override
  String get mcReqPmcBody =>
      'PMC has no API, so luma reads your public profile in an embedded browser. Windows and Android only.';

  @override
  String get mcSetupPlatformsTitle => 'Minecraft platforms';

  @override
  String get mcSetupModrinthNote => 'Public — a username is all it takes.';

  @override
  String get mcSetupModrinthUsername => 'Modrinth username';

  @override
  String get mcSetupModrinthUsernameHint => 'e.g. jellysquid3';

  @override
  String get mcSetupModrinthToken => 'Access token (optional)';

  @override
  String get mcSetupModrinthTokenHelper =>
      'Only needed for real download history. Without it, luma grows the graph itself from daily snapshots.';

  @override
  String get mcSetupModrinthTokenLink => 'Modrinth token settings';

  @override
  String get mcSetupCurseNote =>
      'Needs an API key — CurseForge serves nothing without one.';

  @override
  String get mcSetupCurseKey => 'CurseForge API key';

  @override
  String get mcSetupCurseKeyHint => 'x-api-key from the Studios console';

  @override
  String get mcSetupCurseKeysLink => 'CurseForge API keys';

  @override
  String get mcSetupTestingKey => 'Testing…';

  @override
  String get mcSetupTestKey => 'Test key';

  @override
  String get mcSetupEnterKeyFirst => 'Enter a key first.';

  @override
  String get mcSetupKeyWorks => 'Key works — CurseForge answered HTTP 200.';

  @override
  String get mcSetupAuthorId => 'Author id (optional)';

  @override
  String get mcSetupAuthorIdHint => 'numeric id, e.g. 123456';

  @override
  String get mcSetupAuthorIdHelper =>
      'CurseForge filters by numeric id and offers no username lookup. Leave it blank and track projects individually instead.';

  @override
  String get mcSetupTrackTitle => 'Track a single project';

  @override
  String get mcSetupTrackHint => 'Paste a CurseForge project URL or slug';

  @override
  String get mcSetupTrack => 'Track';

  @override
  String mcSetupNowTracking(String name) {
    return 'Now tracking $name.';
  }

  @override
  String mcSetupStopTracking(String id) {
    return 'Stop tracking #$id';
  }

  @override
  String get mcSetupCurseConsole => 'CurseForge console';

  @override
  String get mcSetupPmcNote =>
      'No API — read from your public profile in an embedded browser.';

  @override
  String get mcSetupPmcUsername => 'Planet Minecraft username';

  @override
  String get mcSetupPmcUsernameHint => 'e.g. cyprezz';

  @override
  String get mcSetupPmcUnsupported =>
      'This platform has no embedded browser engine, so Planet Minecraft cannot be read here. Windows and Android can.';

  @override
  String get mcSetupPrivacy =>
      'Every key is encrypted on this device and sent only to the platform it belongs to. None of it reaches a luma server.';

  @override
  String get mcSetupDisconnectAll => 'Disconnect all';

  @override
  String get mcSetupDisconnectTitle => 'Disconnect every platform?';

  @override
  String get mcSetupDisconnectBody =>
      'The stored keys, the cached numbers and the download history luma has been recording are all deleted from this device. The history cannot be re-fetched — CurseForge and Planet Minecraft publish no past data.';

  @override
  String get accountOverviewKeepIt => 'Keep it';

  @override
  String get accountOverviewDisconnect => 'Disconnect';

  @override
  String get accountOverviewOneTimeSetup => 'One-time setup';

  @override
  String get pmcBrowserNotReady => 'The embedded browser is not ready yet.';

  @override
  String get pmcDidNotFinishLoading =>
      'Planet Minecraft did not finish loading. Cloudflare may be challenging this device.';

  @override
  String get spotifyConnectTitle => 'Connect Spotify';

  @override
  String get spotifyAccountSettingsTitle => 'Spotify account settings';

  @override
  String spotifyConnectedAs(String name) {
    return 'Connected as $name.';
  }

  @override
  String get spotifyDisconnectNote =>
      'Disconnecting removes the stored listening total from this device.';

  @override
  String get spotifyClientIdLabel => 'Spotify Client ID';

  @override
  String get spotifyClientIdHint => 'Paste your Client ID';

  @override
  String get spotifySetupSteps =>
      '1. Create an app in the Spotify Developer Dashboard (Web API).\n2. Add http://127.0.0.1/callback as its redirect URI. Spotify allows luma to use a dynamic port for this loopback address.\n3. Copy the app Client ID here, then sign in through your browser. A development-mode app requires Spotify Premium.';

  @override
  String get spotifyOpenDashboard => 'Open Spotify Developer Dashboard';

  @override
  String get spotifyTokensNote =>
      'Tokens stay in this device’s secure storage. luma reads your Spotify data directly.';

  @override
  String get spotifyReconnect => 'Reconnect';

  @override
  String get spotifySignIn => 'Sign in with Spotify';

  @override
  String get spotifyEmptyTitle => 'Connect your Spotify account';

  @override
  String get spotifyEmptySubtitle =>
      'See your top artists and tracks, recent plays, saved tracks, playlists, and profile stats.';

  @override
  String get spotifyStatFollowers => 'Followers';

  @override
  String get spotifyStatSavedTracks => 'Saved tracks';

  @override
  String get spotifyStatPlaylists => 'Playlists';

  @override
  String get spotifyStatTrackedMinutes => 'Tracked minutes';

  @override
  String spotifyMinutesShort(int count) {
    return '$count min';
  }

  @override
  String get spotifyWaitingForPlays => 'Waiting for recent plays';

  @override
  String spotifyFromDate(String date) {
    return 'From $date';
  }

  @override
  String get spotifyEstimateNote =>
      'Estimated from full track lengths in Spotify’s available recent plays. Refresh regularly to keep the total current.';

  @override
  String get spotifyFavoritesTitle => 'Your favorites';

  @override
  String get spotifyFavoritesSubtitle =>
      'Spotify rankings for the selected period';

  @override
  String get spotifyRangeShort => 'Last 4 weeks';

  @override
  String get spotifyRangeMedium => 'Last 6 months';

  @override
  String get spotifyRangeLong => 'Long term';

  @override
  String spotifyUpdatedAgo(String time) {
    return 'Updated $time';
  }

  @override
  String get spotifyRefreshToLoad => 'Refresh to load your Spotify stats.';

  @override
  String get spotifyTopArtists => 'Top artists';

  @override
  String get spotifyTopTracks => 'Top tracks';

  @override
  String get spotifyRecentlyPlayed => 'Recently played';

  @override
  String get spotifyNoTopArtists => 'No top artists available for this period.';

  @override
  String get spotifyNoTopTracks => 'No top tracks available for this period.';

  @override
  String get spotifyNoRecentTracks => 'No recent tracks available.';

  @override
  String get youtubeAnalyticsLoading => 'Loading analytics…';

  @override
  String get youtubeAnalyticsEmpty =>
      'No analytics yet. Refresh to fetch the last 90 days.';

  @override
  String get youtubeMetricViews => 'Views';

  @override
  String get youtubeMetricWatchTime => 'Watch time';

  @override
  String get youtubeLast90Days => 'Last 90 days';

  @override
  String get youtubeLast90DaysCaption => 'last 90 days';

  @override
  String get youtubeWatchTimeSubtitle => 'Minutes watched, last 90 days';

  @override
  String get youtubeUnitViews => 'views';

  @override
  String get youtubeUnitMinutes => 'minutes';

  @override
  String get youtubeAvgViewDuration => 'Avg. view duration';

  @override
  String get youtubeNetSubscribers => 'Net subscribers';

  @override
  String get youtubeTrafficSources => 'Traffic sources';

  @override
  String get youtubeTrafficSourcesSubtitle =>
      'Where views came from, last 90 days';

  @override
  String get youtubeNoTrafficData => 'No traffic data yet.';

  @override
  String get youtubeChartNotEnoughData => 'Not enough data yet.';

  @override
  String youtubeChartSemantics(
    String unit,
    String start,
    String end,
    String low,
    String high,
  ) {
    return '$unit from $start to $end: $low up to $high';
  }

  @override
  String youtubeChartTooltip(String value, String unit, String date) {
    return '$value $unit\n$date';
  }

  @override
  String get youtubeReconnectTitle => 'Reconnect YouTube';

  @override
  String get youtubeYourChannel => 'your channel';

  @override
  String youtubeConnectedAs(String channel) {
    return 'Connected as $channel. Signing in again replaces the stored credentials.';
  }

  @override
  String get youtubeClientId => 'Client ID';

  @override
  String get youtubeClientSecret => 'Client secret';

  @override
  String get youtubeCredentialsNote =>
      'These are stored encrypted on this device. Connecting opens a Google sign-in page in your browser; nothing about your account reaches a luma server.';

  @override
  String get youtubeSignIn => 'Sign in with Google';

  @override
  String get youtubeDisconnectTitle => 'Disconnect YouTube?';

  @override
  String get youtubeDisconnectBody =>
      'The stored credentials and every cached number are deleted from this device. Your Google account itself is untouched.';

  @override
  String get youtubeSetupStep1 => 'Create a project at Google Cloud Console.';

  @override
  String get youtubeSetupStep2 =>
      'Under \"OAuth consent screen\", set it to Testing and add your own Google account as a test user.';

  @override
  String get youtubeSetupStep3 =>
      'Under \"Library\", enable \"YouTube Data API v3\" and \"YouTube Analytics API\".';

  @override
  String get youtubeSetupStep4 =>
      'Under \"Credentials\", create an OAuth client ID of type \"Desktop app\", then paste its ID and secret above.';

  @override
  String get youtubeOpenConsole => 'Open Google Cloud Console';

  @override
  String get youtubeNotRefreshedYet => 'Not refreshed yet';

  @override
  String youtubeUpdatedAgo(String when) {
    return 'Updated $when';
  }

  @override
  String get youtubeSubscribersHidden => 'Subscribers hidden';

  @override
  String youtubeSubscribersCount(String formatted) {
    return '$formatted subscribers';
  }

  @override
  String get youtubeSubscriberCountHiddenSemantic => 'Subscriber count hidden';

  @override
  String youtubeSubscribersExact(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subscribers',
      one: '1 subscriber',
    );
    return '$_temp0';
  }

  @override
  String youtubeChannelSince(String date) {
    return 'Since $date';
  }

  @override
  String youtubeChannelCreated(String date) {
    return 'Channel created $date';
  }

  @override
  String get youtubeChannelButton => 'Channel';

  @override
  String get youtubeStatTotalViews => 'Total views';

  @override
  String get youtubeStatAllTime => 'all time';

  @override
  String get youtubeStatSubscribers => 'Subscribers';

  @override
  String get youtubeStatHidden => 'Hidden';

  @override
  String get youtubeStatWatchTime => 'Watch time';

  @override
  String get youtubeStatLast90Days => 'last 90 days';

  @override
  String get youtubeStatNetSubscribers => 'Net subscribers';

  @override
  String get youtubeStatViews => 'Views';

  @override
  String get youtubeRecentUploads => 'Recent uploads';

  @override
  String get youtubeViewAll => 'View all';

  @override
  String get youtubeNoVideosYet => 'No videos yet.';

  @override
  String youtubeAvatarSemantic(String title) {
    return '$title avatar';
  }

  @override
  String youtubeViewsExact(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count views',
      one: '1 view',
    );
    return '$_temp0';
  }

  @override
  String youtubeLikesExact(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count likes',
      one: '1 like',
    );
    return '$_temp0';
  }

  @override
  String youtubeVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos',
      one: '1 video',
    );
    return '$_temp0';
  }

  @override
  String get youtubeSortNewest => 'Newest';

  @override
  String get youtubeSortMostViewed => 'Most viewed';

  @override
  String get youtubeSortMostLiked => 'Most liked';

  @override
  String get youtubeUploadsTitle => 'Uploads';

  @override
  String get youtubeTrafficAdvertising => 'Advertising';

  @override
  String get youtubeTrafficAnnotations => 'Annotations';

  @override
  String get youtubeTrafficCampaignCards => 'Campaign cards';

  @override
  String get youtubeTrafficEndScreens => 'End screens';

  @override
  String get youtubeTrafficExternalSites => 'External sites';

  @override
  String get youtubeTrafficEmbeddedPlayer => 'Embedded player';

  @override
  String get youtubeTrafficDirectOrUnknown => 'Direct or unknown';

  @override
  String get youtubeTrafficNotifications => 'Notifications';

  @override
  String get youtubeTrafficPlaylists => 'Playlists';

  @override
  String get youtubeTrafficPromoted => 'Promoted content';

  @override
  String get youtubeTrafficSuggestedVideos => 'Suggested videos';

  @override
  String get youtubeTrafficSubscriptionFeed => 'Subscription feed';

  @override
  String get youtubeTrafficChannelPage => 'Channel page';

  @override
  String get youtubeTrafficOtherPages => 'Other YouTube pages';

  @override
  String get youtubeTrafficYoutubeSearch => 'YouTube search';

  @override
  String get youtubeTrafficShortsFeed => 'Shorts feed';

  @override
  String get youtubeApiRejectedToken => 'Google rejected the access token.';

  @override
  String get youtubeApiForbidden =>
      'Google refused the request. The channel may not have analytics available yet, or the API may need enabling in your Google Cloud project.';

  @override
  String youtubeApiHttpStatus(String status) {
    return 'Google returned HTTP $status.';
  }

  @override
  String get youtubeApiNoChannel =>
      'This Google account has no YouTube channel.';

  @override
  String get youtubeOAuthTimeout =>
      'Timed out waiting for Google to redirect back. Try connecting again.';

  @override
  String youtubeOAuthDeclined(String error) {
    return 'Google declined the request: $error';
  }

  @override
  String get youtubeOAuthStateMismatch =>
      'Google\'s response did not match this request.';

  @override
  String get youtubeOAuthNoCode =>
      'Google did not return an authorization code.';

  @override
  String get youtubeOAuthLandingConnected => 'You\'re connected';

  @override
  String get youtubeOAuthLandingClose =>
      'You can close this tab and go back to luma.';

  @override
  String youtubeOAuthRejected(String description) {
    return 'Google rejected the request: $description';
  }

  @override
  String get youtubeOAuthNoAccessToken =>
      'Google did not return an access token.';

  @override
  String get youtubeOAuthNoRefreshToken =>
      'Google did not return a refresh token. Remove luma\'s access at myaccount.google.com/permissions and try connecting again.';

  @override
  String get youtubeStageChannel => 'Reading your channel';

  @override
  String get youtubeStageVideos => 'Listing recent videos';

  @override
  String get youtubeStageAnalytics => 'Fetching analytics';

  @override
  String get youtubeEnterCredentialsFirst =>
      'Enter both the Client ID and Client Secret first.';

  @override
  String get youtubeNotConnected => 'YouTube is not connected.';

  @override
  String youtubeWarnVideos(String error) {
    return 'Recent videos unavailable: $error';
  }

  @override
  String youtubeWarnAnalytics(String error) {
    return 'Analytics unavailable: $error';
  }

  @override
  String get aiDetectorClipboardEmpty => 'Your clipboard is empty.';

  @override
  String aiDetectorTabHighlights(int count) {
    return 'Highlights  $count';
  }

  @override
  String aiDetectorTabSignals(int count) {
    return 'Signals  $count';
  }

  @override
  String get aiDetectorDisclaimer =>
      'Heuristic style analysis — arithmetic on sentence lengths and word choices, not proof of anything. Formal human writing can look machine-like; edited machine output can look human. A named verdict rests on a signature the text carries itself, and a signature can be stripped or forged. The statistics run on this device. Signed in, the text is also sent to the luma server for an AI model review.';

  @override
  String get aiDetectorInputTitle => 'Review a piece of writing';

  @override
  String get aiDetectorInputSubtitle =>
      'Style statistics plus a Claude watermark scan.';

  @override
  String get aiDetectorOnDevice => 'On device';

  @override
  String aiDetectorReviewsLeft(int remaining, int limit) {
    return '$remaining/$limit AI reviews left this week';
  }

  @override
  String aiDetectorReviewsCost(int percent) {
    return 'Reviews cost $percent% of your weekly limit';
  }

  @override
  String get aiDetectorHint =>
      'Paste the text you want checked — an essay, an email, a product review…';

  @override
  String aiDetectorWordsShort(int words, int minWords) {
    return '$words of $minWords words — style statistics need a bit more to work on.';
  }

  @override
  String aiDetectorWordsReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words ready to review.',
      one: '1 word ready to review.',
    );
    return '$_temp0';
  }

  @override
  String get aiDetectorReview => 'Review';

  @override
  String get aiDetectorAiLikelihood => 'AI-likelihood';

  @override
  String aiDetectorGaugeSemantic(int score, String verdict) {
    return 'AI likelihood $score out of 100. $verdict.';
  }

  @override
  String get aiDetectorWatermarkMatch => 'Watermark match';

  @override
  String get aiDetectorSummarySigned =>
      'The text signs itself — the scan found the hidden marks a Claude watermark is carried in, so this is an attribution rather than a guess about style.';

  @override
  String aiDetectorSummaryBased(int words, int sentences) {
    return 'Based on $words words across $sentences sentences.';
  }

  @override
  String get aiDetectorSummaryShort =>
      'Short sample — treat every signal as a hint rather than a measurement.';

  @override
  String get aiDetectorStatWords => 'words';

  @override
  String get aiDetectorStatSentences => 'sentences';

  @override
  String get aiDetectorStatAvgWords => 'avg words/sentence';

  @override
  String get aiDetectorStatFlagged => 'flagged spans';

  @override
  String get aiDetectorDeepCheckTitle => 'AI model review';

  @override
  String get aiDetectorDeepCheckSignIn =>
      'Sign in to an approved luma account to also have an AI model review the text. Below is the on-device analysis.';

  @override
  String get aiDetectorDeepCheckReading => 'The AI model is reading the text…';

  @override
  String aiDetectorDeepCheckExhausted(int percent) {
    return 'No included reviews left this week. Exchange $percent% of your weekly Luma AI limit to run one more.';
  }

  @override
  String get aiDetectorDeepCheckIntro =>
      'Where and how the text reads AI-generated, according to the AI model.';

  @override
  String aiDetectorChargeExchanged(int percent) {
    return 'Where and how the text reads AI-generated, according to the AI model. Exchanged $percent% of your weekly limit.';
  }

  @override
  String aiDetectorChargeUsed(int used, int included) {
    return 'Where and how the text reads AI-generated, according to the AI model. $used of $included included reviews used this week.';
  }

  @override
  String get aiDetectorRunReview => 'Run AI review';

  @override
  String aiDetectorExchangeWeekly(int percent) {
    return 'Exchange $percent% of weekly';
  }

  @override
  String aiDetectorPassageSemantic(int percent, String passage) {
    return '$percent% AI-likely: $passage';
  }

  @override
  String aiDetectorHighlightSemantic(String note, String passage) {
    return '$note: $passage';
  }

  @override
  String get aiDetectorNothingFlagged => 'Nothing flagged';

  @override
  String get aiDetectorNothingFlaggedBody =>
      'No stock phrases, no hidden characters, no formulaic openers. Every stretch of this text reads as written by hand.';

  @override
  String get aiDetectorHighlightsTitle =>
      'Everything the checks matched, marked in place';

  @override
  String get aiDetectorHighlightsLegend =>
      'Each mark is styled by how strongly it counts, not only by colour: wavy for a signature, solid for a strong tell, dotted for a mild one.';

  @override
  String aiDetectorTruncated(int limit) {
    return 'Showing the first $limit characters. The score and the signals below cover the whole text.';
  }

  @override
  String get aiDetectorSignalsNothing =>
      'Nothing suspicious fired — varied lengths, no stock phrases, no watermark. Reads like human writing.';

  @override
  String get aiDetectorQuietChecks => 'Quiet checks';

  @override
  String aiDetectorQuietOneWay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count checks found nothing — a dash means the check only ever counts against a text, so finding nothing left it with no opinion',
      one:
          '1 check found nothing — a dash means the check only ever counts against a text, so finding nothing left it with no opinion',
    );
    return '$_temp0';
  }

  @override
  String aiDetectorQuietNothing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count checks found nothing worth flagging',
      one: '1 check found nothing worth flagging',
    );
    return '$_temp0';
  }

  @override
  String get aiDetectorMatch => 'match';

  @override
  String get aiReviewSignInRequired =>
      'Sign in to an approved luma account to use the deep check.';

  @override
  String get aiReviewUnreachable =>
      'Could not reach the luma server. Check your connection and try again.';

  @override
  String aiReviewFailedStatus(int status) {
    return 'The deep check failed (HTTP $status).';
  }

  @override
  String get aiReviewMalformed => 'The server sent a malformed review.';

  @override
  String aiUsageSyncOsDevice(String os) {
    return '$os device';
  }

  @override
  String get aiUsageSyncAnotherDevice => 'Another device';

  @override
  String get aiAgentHeader => 'Agent Builder';

  @override
  String aiAgentHeaderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count agents',
      one: '1 agent',
    );
    return '$_temp0 · reusable specialists for Codex, Claude Code and opencode';
  }

  @override
  String get aiAgentNew => 'New agent';

  @override
  String get aiAgentEmptyTitle => 'No agents yet';

  @override
  String get aiAgentEmptyBody => 'Give a repeatable job its own specialist.';

  @override
  String get aiAgentCreate => 'Create agent';

  @override
  String get aiAgentSpecialistSubtitle => 'Specialist agent';

  @override
  String get aiAgentDeleteTitle => 'Delete agent?';

  @override
  String aiAgentDeleteBody(String name) {
    return '\"$name\" will be removed from Luma.';
  }

  @override
  String get aiAgentSaved => 'Agent saved';

  @override
  String aiAgentPromptCopied(String target) {
    return 'Prompt copied — paste it into $target';
  }

  @override
  String aiAgentExportDialogTitle(String target, String file) {
    return 'Export $target $file';
  }

  @override
  String aiAgentExported(String target, String file) {
    return 'Exported $target $file';
  }

  @override
  String aiAgentChooseProjectFolder(String target) {
    return 'Choose the $target project folder';
  }

  @override
  String aiAgentReplaceTitle(String file) {
    return 'Replace existing $file?';
  }

  @override
  String aiAgentReplaceBody(String path) {
    return '$path already exists in this project.';
  }

  @override
  String get aiAgentReplace => 'Replace';

  @override
  String aiAgentInstalledAt(String path) {
    return 'Installed at $path';
  }

  @override
  String get aiAgentEdit => 'Edit agent';

  @override
  String get aiAgentDeleteTooltip => 'Delete agent';

  @override
  String get aiAgentNameHint => 'Flutter code reviewer';

  @override
  String get aiAgentFieldDescription => 'Short description';

  @override
  String get aiAgentDescriptionHint => 'What this specialist is for';

  @override
  String get aiAgentFieldModel => 'Preferred model (optional)';

  @override
  String get aiAgentModelHint =>
      'sonnet for Claude Code, anthropic/claude-sonnet-5 for opencode';

  @override
  String get aiAgentFieldInstructions => 'Instructions';

  @override
  String get aiAgentInstructionsHint =>
      'You are a specialist…\n\nDescribe the job, boundaries, and reasoning approach.';

  @override
  String get aiAgentFieldOutput => 'Output format (optional)';

  @override
  String get aiAgentOutputHint =>
      'Findings grouped by severity, with file and line references';

  @override
  String get aiAgentLibraryContext => 'Library context';

  @override
  String get aiAgentLibraryContextHelp =>
      'Selected notes are embedded when you copy or export this agent.';

  @override
  String get aiAgentLibraryEmpty =>
      'Create Markdown notes in the Library tab first.';

  @override
  String get aiAgentUseWith => 'Use with';

  @override
  String get aiAgentCopyPrompt => 'Copy prompt';

  @override
  String aiAgentExportFile(String file) {
    return 'Export $file';
  }

  @override
  String aiAgentInstallFor(String target) {
    return 'Install for $target';
  }

  @override
  String get aiAgentSave => 'Save agent';

  @override
  String get aiUsageSaving => 'Saving…';

  @override
  String get aiMarkdownNoteLabel => 'Markdown note';

  @override
  String get aiLibrarySaved => 'Markdown note saved';

  @override
  String get aiLibraryImportTitle => 'Import Markdown note';

  @override
  String aiLibraryImported(String name) {
    return 'Imported $name — save it to add it to the library';
  }

  @override
  String get aiLibraryExportTitle => 'Export Markdown note';

  @override
  String aiLibraryExported(String name) {
    return 'Exported $name';
  }

  @override
  String get aiLibraryDeleteTitle => 'Delete Markdown note?';

  @override
  String aiLibraryDeleteBody(String title) {
    return '\"$title\" will be removed from the library.';
  }

  @override
  String get aiLibraryHeader => 'Markdown Library';

  @override
  String aiLibraryHeaderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes',
      one: '1 note',
    );
    return '$_temp0 · reusable context for your agents';
  }

  @override
  String get aiLibraryNewNote => 'New note';

  @override
  String get aiLibraryEmptyTitle => 'Your library is empty';

  @override
  String get aiLibraryEmptyBody =>
      'Save prompts, project context, and checklists here.';

  @override
  String get aiLibraryCreateNote => 'Create note';

  @override
  String get aiLibraryNewEditorTitle => 'New Markdown note';

  @override
  String get aiLibraryEditNote => 'Edit note';

  @override
  String get aiLibraryExportMdTooltip => 'Export .md';

  @override
  String get aiLibraryDeleteNoteTooltip => 'Delete note';

  @override
  String get aiLibraryTitleHint => 'Project conventions';

  @override
  String get aiLibraryFieldTags => 'Tags';

  @override
  String get aiLibraryTagsHint => 'flutter, conventions, project';

  @override
  String get aiLibraryContent => 'Content';

  @override
  String get aiLibraryNothingWritten => 'Nothing written yet.';

  @override
  String get aiLibraryBodyHint =>
      '# Instructions\n\nWrite reusable context in Markdown…';

  @override
  String get aiLibrarySaveNote => 'Save note';

  @override
  String get aiUsageNoLogsTitle => 'No local AI usage logs found';

  @override
  String get aiUsageNoLogsSubtitle =>
      'AI Usage reads session logs from Claude Code (~/.claude/projects), Codex CLI (~/.codex/sessions), Antigravity (~/.gemini/antigravity), OpenCode (~/.local/share/opencode), and Freebuff (~/.config/freebuff-desktop/projects) on this device, and logs every call luma\'s own Assistant makes. Nothing leaves it unless you turn on AI Usage sync in Settings, which also adds up your other devices. Use one of these tools here, then rescan.';

  @override
  String get aiUsageRescan => 'Rescan';

  @override
  String get aiUsageSettingsTitle => 'Usage settings';

  @override
  String get aiUsageCombineByCompany => 'Combine models by company';

  @override
  String get aiUsageCombineByCompanyHint =>
      'Group every model from one company into a single row';

  @override
  String get aiUsageSorting => 'Sorting';

  @override
  String get aiUsageSortingHint => 'What each table and chart orders by';

  @override
  String get aiUsageSortModels => 'Models (pie + table)';

  @override
  String get aiUsageSortProjects => 'Top projects';

  @override
  String get aiUsageSortProviders => 'Providers (OpenCode)';

  @override
  String get aiUsageRescanTooltip => 'Rescan local AI usage logs';

  @override
  String get aiUsageDisplaySettingsTooltip => 'Usage display settings';

  @override
  String aiUsageStatusUpToDate(String time, String synced) {
    return 'Up to date · $time$synced';
  }

  @override
  String aiUsageStatusNewTurns(int count, String time, String synced) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new turns',
      one: '1 new turn',
    );
    return '$_temp0 · $time$synced';
  }

  @override
  String aiUsageStatusSyncedDevices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count other devices',
      one: '1 other device',
    );
    return ' · incl. $_temp0';
  }

  @override
  String get aiUsageDevicesTooltipHeader => 'Usage summed across your devices:';

  @override
  String get aiUsageThisDevice => 'This device';

  @override
  String aiUsageDeviceLine(String name, int count, String synced) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count turns',
      one: '1 turn',
    );
    return '$name · $_temp0 · synced $synced';
  }

  @override
  String get aiUsageSourceAntigravityEst => 'Antigravity (est.)';

  @override
  String get aiUsageNoUsageTitle => 'No usage recorded in this range';

  @override
  String get aiUsageNoUsageSubtitle =>
      'Try a wider range, or use one of the supported tools and rescan.';

  @override
  String aiUsageNoUsageSourceSubtitle(String source) {
    return 'Try a wider range, or use $source and rescan.';
  }

  @override
  String get aiUsageTotalTokens => 'Total tokens';

  @override
  String get aiUsageTotalTokensTooltip =>
      'New tokens only: input + output + first-time cache writes. Doesn\'t include cache reads (see that tile). A long session re-reads the same growing context on nearly every turn, which would otherwise count the same conversation over and over.';

  @override
  String get aiUsageCacheReads => 'Cache reads';

  @override
  String get aiUsageCacheReadsTooltip =>
      'Cached context re-read across all turns in range: real and billed, but at a steep discount, and not counted in \"Total tokens\" since it\'s re-use of content rather than new content.';

  @override
  String get aiUsageEstCost => 'Est. cost';

  @override
  String get aiUsageEstCostTooltip =>
      'Estimated cost at API rates, including cache reads/writes at their discounted rate, so this reflects more usage than \"Total tokens\" shows on its own. Subscription plans (Max/Pro) bill differently than this per-token estimate.';

  @override
  String get aiUsageTurns => 'Turns';

  @override
  String get aiUsageSessions => 'Sessions';

  @override
  String get aiUsageTopCompany => 'Top company';

  @override
  String get aiUsageTopModel => 'Top model';

  @override
  String get aiUsageUnbillableNote =>
      '* excludes usage from models outside their provider\'s known pricing';

  @override
  String get aiUsageAntigravityNote =>
      'Antigravity numbers are estimated from message length. It doesn\'t record real token usage locally. They\'re not exact like Claude Code/Codex CLI. Cost (marked ~) only shows for recognized Gemini/Claude models, and is a rougher estimate than the other two sources.';

  @override
  String get aiUsagePickWiderRange =>
      'Pick a wider range to see a daily breakdown';

  @override
  String get aiUsageCompanies => 'Companies';

  @override
  String get aiUsageModels => 'Models';

  @override
  String aiUsageSortedBy(String metric) {
    return 'Sorted by $metric';
  }

  @override
  String get aiUsageSwitchToAllHeatmap =>
      'Switch to \"All\" to see your yearly contribution heatmap';

  @override
  String get aiUsageLongestSession => 'Longest session';

  @override
  String get aiUsagePriciestSession => 'Priciest session';

  @override
  String get aiUsageLongestStreak => 'Longest streak';

  @override
  String aiUsageStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String aiUsageDurationDaysHours(int days, int hours) {
    return '${days}d ${hours}h';
  }

  @override
  String aiUsageDurationHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String aiUsageDurationMinutes(int minutes) {
    return '${minutes}m';
  }

  @override
  String get aiUsageOther => 'Other';

  @override
  String aiUsageTooltipDay(
    String day,
    String input,
    String output,
    String cacheRead,
    String cacheWrite,
    String cost,
  ) {
    return '$day\nInput: $input\nOutput: $output\nCache read: $cacheRead\nCache write: $cacheWrite\n$cost';
  }

  @override
  String get aiUsageInput => 'Input';

  @override
  String get aiUsageOutput => 'Output';

  @override
  String get aiUsageCacheWrite => 'Cache write';

  @override
  String get aiUsageAvgHourly => 'Average Hourly Distribution';

  @override
  String get aiUsageAnthropicPeakTooltip =>
      'Anthropic published this window for Claude Code in March 2026; the rate-limit reduction itself was lifted for Pro/Max on May 6, 2026, but the hours are still commonly referenced.';

  @override
  String aiUsageAnthropicPeak(String start, String end) {
    return 'Anthropic peak: $start–$end';
  }

  @override
  String get aiUsageHourlyHint =>
      'Tokens per hour, averaged across the days in this range, local time. Highlighted bars fall in the window above (weekdays 5–11am PT).';

  @override
  String aiUsageHourlyTooltip(String hour, String tokens, String turns) {
    return '$hour\n$tokens tokens/day avg\n$turns turns/day avg';
  }

  @override
  String get aiUsageNoProjectData => 'No project data in this range';

  @override
  String aiUsageTopProjectsBy(String metric) {
    return 'Top Projects by $metric';
  }

  @override
  String get aiUsageProjectSourceNote =>
      'Claude Code, Codex CLI and OpenCode only. Antigravity has no reliable project source, so it is grouped as \"Unknown project\" instead.';

  @override
  String get aiUsageUnknownProject => 'Unknown project';

  @override
  String aiUsageProjectTooltip(
    String input,
    String output,
    int turns,
    int sessions,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      turns,
      locale: localeName,
      other: '$turns turns',
      one: '1 turn',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sessions,
      locale: localeName,
      other: '$sessions sessions',
      one: '1 session',
    );
    return 'Input: $input · Output: $output\n$_temp0 · $_temp1';
  }

  @override
  String get aiUsageNoProviderData => 'No provider data in this range';

  @override
  String aiUsageProvidersBy(String metric) {
    return 'Providers by $metric';
  }

  @override
  String get aiUsageProvidersHint =>
      'Which provider each OpenCode turn was routed to. Every provider is priced as if reached with a normal paid API key, including OpenCode\'s own \"free\" models and any provider this app hasn\'t been specifically taught. Both are shown at an estimated rate rather than taken at face value or shown as n/a. A provider that genuinely runs on your own hardware (Ollama, llama.cpp, ...) still shows a real \$0.00.';

  @override
  String aiUsageModelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count models',
      one: '1 model',
    );
    return '$_temp0';
  }

  @override
  String aiUsageProviderTooltip(
    String input,
    String output,
    String cacheRead,
    int turns,
    String models,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      turns,
      locale: localeName,
      other: '$turns turns',
      one: '1 turn',
    );
    return 'Input: $input · Output: $output\nCache reads: $cacheRead\n$_temp0 · $models';
  }

  @override
  String get aiUsageNotApplicable => 'n/a';

  @override
  String get aiUsageCompany => 'Company';

  @override
  String get aiUsageModel => 'Model';

  @override
  String get aiUsageCompanyHeaderTip => 'Which company built the models used';

  @override
  String get aiUsageModelHeaderTip =>
      'Which model was used, and which local tool it came from';

  @override
  String get aiUsageTurnsHeaderTip =>
      'How many separate AI responses (API calls) were made with this model';

  @override
  String get aiUsageTokens => 'Tokens';

  @override
  String get aiUsageTokensHeaderTip =>
      'New tokens only: input + output + first-time cache writes. Excludes cache reads (repeated re-use of prior context). See the Cache reads stat tile above for that figure.';

  @override
  String get aiUsageCost => 'Cost';

  @override
  String get aiUsageCostHeaderTip =>
      'USD cost reported by the provider for Luma calls when available; otherwise an estimate at the model or vendor API rate. \"n/a\" means no cost could be resolved.';

  @override
  String get aiUsageHeatmapTitle => 'Contribution Heatmap';

  @override
  String get aiUsageHeatmapHint =>
      'Daily token intensity over the last year. Hover a day for details.';

  @override
  String get aiUsageNoUsageYet => 'No usage recorded yet';

  @override
  String aiUsageHeatmapCellTooltip(String date, String tokens, String cost) {
    return '$date\n$tokens tokens · $cost';
  }

  @override
  String aiUsageHeatmapEmptyTooltip(String date) {
    return '$date\nNo usage';
  }

  @override
  String get aiUsageLess => 'Less';

  @override
  String get aiUsageSectionUsage => 'AI Usage';

  @override
  String get aiUsageSectionUsageBlurb => 'Your own token spend';

  @override
  String get aiUsageSectionLeaderboard => 'Leaderboard';

  @override
  String get aiUsageSectionLeaderboardBlurb => 'Every model, ranked';

  @override
  String get aiUsageSectionOpenSource => 'Open Source';

  @override
  String get aiUsageSectionOpenSourceBlurb => 'What your hardware can run';

  @override
  String get aiUsageSectionLibrary => 'Library';

  @override
  String get aiUsageSectionLibraryBlurb => 'Reusable Markdown context';

  @override
  String get aiUsageSectionAgents => 'Agents';

  @override
  String get aiUsageSectionAgentsBlurb => 'Codex, Claude Code & opencode';

  @override
  String get aiUsageSectionTests => 'Tests';

  @override
  String get aiUsageSectionTestsBlurb => 'Experiments in progress';

  @override
  String get aiUsageSectionAssets => 'Assets';

  @override
  String get aiUsageSectionAssetsBlurb => 'Free to use';

  @override
  String get aiUsageSidebarExpand => 'Expand sidebar';

  @override
  String get aiUsageSidebarCollapse => 'Collapse sidebar';

  @override
  String get aiUsageSidebarCollapseShort => 'Collapse';

  @override
  String aiUsageSectionTooltip(String label, String blurb) {
    return '$label — $blurb';
  }

  @override
  String get aiUsageRangeLast7Days => '7d';

  @override
  String get aiUsageRangeLast30Days => '30d';

  @override
  String get aiUsageRangeAll => 'All';

  @override
  String get aiUsageUnknownProvider => 'unknown';

  @override
  String get aiUsageSortTokens => 'Tokens';

  @override
  String get aiUsageSortTurns => 'Turns';

  @override
  String get aiUsageSortCost => 'Cost';

  @override
  String get aiUsageCompanyLocal => 'Local';

  @override
  String get aiUsageUntitledNote => 'Untitled note';

  @override
  String get aiUsageUntitledAgent => 'Untitled agent';

  @override
  String get aiAgentTargetFileSubagent => 'subagent';

  @override
  String get aiAgentTargetFileAgent => 'agent';

  @override
  String get aiUsageEffortUnspecified => 'Unspecified';

  @override
  String get aiUsageEffortMinimal => 'Minimal';

  @override
  String get aiUsageEffortLow => 'Low';

  @override
  String get aiUsageEffortMedium => 'Medium';

  @override
  String get aiUsageEffortHigh => 'High';

  @override
  String get aiUsageEffortExtraHigh => 'Extra high';

  @override
  String get aiUsageEffortMax => 'Max';

  @override
  String get aiUsageEffortBreakdownTitle => 'Claude Effort Breakdown';

  @override
  String get aiUsageEffortBreakdownBlurb =>
      'How hard each Claude model was asked to think, by turns and tokens spent.';

  @override
  String aiUsageEffortTurns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count turns',
      one: '1 turn',
    );
    return '$_temp0';
  }

  @override
  String aiUsageAssetsIntro(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count procedural models from the airport game. Open one to inspect it in 3D, or download it as an HTML file.',
      one:
          '1 procedural model from the airport game. Open it to inspect it in 3D, or download it as an HTML file.',
    );
    return '$_temp0';
  }

  @override
  String get aiUsageAssetsSearchHint => 'Search models';

  @override
  String get aiUsageAssetsClearSearch => 'Clear search';

  @override
  String get aiUsageAssetsCategoryAll => 'All';

  @override
  String get aiUsageAssetsCategoryRetail => 'Retail';

  @override
  String get aiUsageAssetsCategoryFood => 'Food';

  @override
  String get aiUsageAssetsCategoryEntertainment => 'Entertainment';

  @override
  String get aiUsageAssetsCategorySecurity => 'Security';

  @override
  String get aiUsageAssetsCategoryPassenger => 'Passenger';

  @override
  String get aiUsageAssetsNoMatch => 'No models match';

  @override
  String get aiUsageAssetsNoMatchHint =>
      'Try another name or clear the filter.';

  @override
  String aiUsageAssetOpenLabel(String name) {
    return 'Open $name';
  }

  @override
  String get aiUsageAssetsLoadFailed => 'Could not load the assets';

  @override
  String get aiUsageAssetBackTooltip => 'Back to assets';

  @override
  String get aiUsageAssetDownloadHtmlTooltip =>
      'A single HTML file that opens this model offline in any browser';

  @override
  String get aiUsageAssetDownloadHtml => 'Download HTML';

  @override
  String aiUsageAssetSaved(String fileName) {
    return 'Saved $fileName';
  }

  @override
  String aiUsageAssetSaveFailed(String error) {
    return 'Could not save: $error';
  }

  @override
  String aiUsageAssetSaveDialogTitle(String name) {
    return 'Save $name';
  }

  @override
  String get aiUsageAssetStudioUnsupported =>
      'The 3D studio runs on Windows and Android';

  @override
  String get aiUsageAssetStudioUnsupportedHint =>
      'Download the HTML to open this model in any browser — it works offline.';

  @override
  String get aiUsageAssetStudioUnavailable => 'Studio unavailable';

  @override
  String aiUsageAssetStudioPrepareFailed(String error) {
    return 'Could not prepare the studio: $error';
  }

  @override
  String aiCatalogServerError(String status) {
    return 'The server could not return the model leaderboard (HTTP $status).';
  }

  @override
  String get aiCatalogMalformedResponse => 'Malformed leaderboard response.';

  @override
  String get aiCompareTitle => 'Compare models';

  @override
  String get aiComparePickTwo => 'Pick at least two models to compare.';

  @override
  String get aiCompareAddHint => 'Add models to compare them side by side.';

  @override
  String get aiCompareAddTooltip => 'Add a model';

  @override
  String get aiCompareAddModel => 'Add model';

  @override
  String get aiCompareNotEnoughRatings =>
      'Not enough shared ratings to draw a radar for this selection.';

  @override
  String get aiLeaderboardMetricIntelligence => 'Intelligence Index';

  @override
  String get aiLeaderboardMetricReasoning => 'Reasoning Index';

  @override
  String get aiLeaderboardMetricCoding => 'Coding Index';

  @override
  String get aiLeaderboardMetricAgent => 'Agent Index';

  @override
  String get aiLeaderboardMetricMath => 'Math Index';

  @override
  String get aiLeaderboardMetricBlendedPrice => 'Blended Price 8:1';

  @override
  String get aiLeaderboardMetricAveragePrice => 'Average Price';

  @override
  String get aiLeaderboardMetricInputPrice => 'Input Price';

  @override
  String get aiLeaderboardMetricOutputPrice => 'Output Price';

  @override
  String get aiLeaderboardMetricParameters => 'Parameters';

  @override
  String get aiLeaderboardMetricContext => 'Context Length';

  @override
  String get aiLeaderboardMetricSpeed => 'Speed';

  @override
  String get aiLeaderboardMetricLatency => 'Time to First Token';

  @override
  String get aiLeaderboardUnitTokens => 'tokens';

  @override
  String get aiLeaderboardColumnRank => 'RANK';

  @override
  String get aiLeaderboardColumnRankHelp => 'Position in the current sort';

  @override
  String get aiLeaderboardColumnName => 'MODEL';

  @override
  String get aiLeaderboardColumnNameHelp =>
      'Model name and the provider that serves it';

  @override
  String get aiLeaderboardColumnIntelligence => 'INTELLIGENCE';

  @override
  String get aiLeaderboardColumnIntelligenceHelp =>
      'Artificial Analysis\' Intelligence Index: the composite across every benchmark it runs, at the model\'s best reasoning effort';

  @override
  String get aiLeaderboardColumnCoding => 'CODING';

  @override
  String get aiLeaderboardColumnCodingHelp =>
      'Code generation and repair benchmarks';

  @override
  String get aiLeaderboardColumnAgent => 'AGENT';

  @override
  String get aiLeaderboardColumnAgentHelp =>
      'Long-horizon tool use and multi-step task benchmarks';

  @override
  String get aiLeaderboardColumnCodeArenaHelp =>
      'Head-to-head Elo from human preference on coding tasks';

  @override
  String get aiLeaderboardColumnParams => 'PARAMS';

  @override
  String get aiLeaderboardColumnParamsHelp =>
      'Total parameter count, in billions. Only known for open-weight models';

  @override
  String get aiLeaderboardColumnContext => 'CONTEXT';

  @override
  String get aiLeaderboardColumnContextHelp =>
      'Largest prompt the model accepts, in tokens';

  @override
  String get aiLeaderboardColumnPrice => 'PRICE \$/M';

  @override
  String get aiLeaderboardColumnPriceHelp =>
      'Input and output price averaged, in USD per million tokens';

  @override
  String get aiLeaderboardColumnLicense => 'LICENSE';

  @override
  String get aiLeaderboardColumnLicenseHelp =>
      'Open padlock means the weights are downloadable';

  @override
  String get aiLeaderboardGraphEmptyTitle => 'No model data yet';

  @override
  String get aiLeaderboardGraphEmptySubtitle =>
      'The graph needs the model catalogue to plot.';

  @override
  String aiLeaderboardGraphNotEnough(String x, String y) {
    return 'Not enough models have both $x and $y to plot.';
  }

  @override
  String get aiLeaderboardGraphXAxis => 'X AXIS';

  @override
  String get aiLeaderboardGraphYAxis => 'Y AXIS';

  @override
  String get aiLeaderboardGraphVendors => 'VENDORS';

  @override
  String get aiLeaderboardGraphHighlight => 'HIGHLIGHT MODELS';

  @override
  String get aiLeaderboardGraphHighlightHint =>
      'Pick models to pick out on the plot.';

  @override
  String get aiLeaderboardGraphLogScale => 'Log scale';

  @override
  String aiLeaderboardGraphPlotted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count models plotted',
      one: '1 model plotted',
    );
    return '$_temp0';
  }

  @override
  String get aiLeaderboardTabTable => 'Table';

  @override
  String get aiLeaderboardTabGraph => 'Graph';

  @override
  String get aiLeaderboardTabInsights => 'Insights';

  @override
  String get aiLeaderboardCompare => 'Compare';

  @override
  String get aiLeaderboardEffortMinimal => 'Minimal';

  @override
  String get aiLeaderboardEffortLow => 'Low';

  @override
  String get aiLeaderboardEffortMedium => 'Medium';

  @override
  String get aiLeaderboardEffortHigh => 'High';

  @override
  String get aiLeaderboardEffortXhigh => 'Extra high';

  @override
  String get aiLeaderboardEffortMax => 'Max';

  @override
  String get aiLeaderboardInsightsEmptySubtitle =>
      'Insights need the model catalogue to build from.';

  @override
  String get aiLeaderboardInsightsEyebrowEfficiency => 'EFFICIENCY';

  @override
  String get aiLeaderboardInsightsPriceVsPerformance => 'Price vs Performance';

  @override
  String aiLeaderboardInsightsFrontierBlurb(String metric) {
    return 'Blended cost (8:1 input/output) against $metric. Models on the line are pareto-efficient: nothing else is both cheaper and at least as good.';
  }

  @override
  String get aiLeaderboardInsightsEyebrowBestByTask => 'BEST BY TASK';

  @override
  String get aiLeaderboardInsightsCategoryLeaders => 'Category Leaders';

  @override
  String get aiLeaderboardInsightsEyebrowResearch => 'RESEARCH';

  @override
  String get aiLeaderboardInsightsLatestNews => 'Latest News';

  @override
  String get aiLeaderboardInsightsScoreAxis => 'Score axis';

  @override
  String aiLeaderboardInsightsNotEnoughPriced(String metric) {
    return 'Not enough priced models rate $metric yet.';
  }

  @override
  String get aiLeaderboardInsightsBlendedCostAxis =>
      'Blended cost \$/1M tokens (8:1 input/output)';

  @override
  String get aiLeaderboardInsightsTaskReasoning => 'Best for reasoning';

  @override
  String get aiLeaderboardInsightsTaskCoding => 'Best for coding';

  @override
  String get aiLeaderboardInsightsTaskAgents => 'Best for agents';

  @override
  String get aiLeaderboardInsightsTaskFastest => 'Fastest';

  @override
  String get aiLeaderboardInsightsTaskCheapest => 'Cheapest frontier';

  @override
  String get aiLeaderboardInsightsTaskLargest => 'Largest context';

  @override
  String get aiLeaderboardInsightsNewBadge => 'NEW';

  @override
  String get aiLeaderboardDetailFallbackTitle => 'Model';

  @override
  String get aiLeaderboardDetailCompareTooltip => 'Compare with other models';

  @override
  String get aiLeaderboardDetailNoLongerListed =>
      'This model is no longer listed.';

  @override
  String get aiLeaderboardDetailProprietary => 'Proprietary — API access only';

  @override
  String get aiLeaderboardDetailOpenWeights => 'Open weights';

  @override
  String aiLeaderboardDetailOpenWeightsLicensed(String license) {
    return 'Open weights · $license';
  }

  @override
  String aiLeaderboardDetailReleased(String date) {
    return 'Released $date';
  }

  @override
  String aiLeaderboardDetailKnowledgeCutoff(String date) {
    return 'Knowledge cutoff $date';
  }

  @override
  String aiLeaderboardDetailParamsTag(String params) {
    return '$params params';
  }

  @override
  String get aiLeaderboardDetailRatingIntelligence => 'Intelligence';

  @override
  String get aiLeaderboardDetailRatingIntelligenceHelp =>
      'Artificial Analysis Intelligence Index, at best effort';

  @override
  String get aiLeaderboardDetailRatingReasoning => 'Reasoning';

  @override
  String get aiLeaderboardDetailRatingReasoningHelp =>
      'Graduate-level reasoning & knowledge';

  @override
  String get aiLeaderboardDetailRatingCoding => 'Coding';

  @override
  String get aiLeaderboardDetailRatingCodingHelp =>
      'Code generation and repair';

  @override
  String get aiLeaderboardDetailRatingAgent => 'Agent';

  @override
  String get aiLeaderboardDetailRatingAgentHelp => 'Long-horizon tool use';

  @override
  String get aiLeaderboardDetailRatingCodeArenaHelp =>
      'Head-to-head coding preference Elo';

  @override
  String get aiLeaderboardDetailRatingMath => 'Math';

  @override
  String get aiLeaderboardDetailRatingMathHelp =>
      'Competition-level mathematics';

  @override
  String aiLeaderboardDetailTokensCount(String tokens) {
    return '$tokens tokens';
  }

  @override
  String aiLeaderboardDetailPricePerMTokens(String price) {
    return '$price/M tokens';
  }

  @override
  String get aiLeaderboardDetailContextWindow => 'Context window';

  @override
  String get aiLeaderboardDetailMaxOutput => 'Max output';

  @override
  String get aiLeaderboardDetailInputPrice => 'Input price';

  @override
  String get aiLeaderboardDetailOutputPrice => 'Output price';

  @override
  String get aiLeaderboardDetailCacheRead => 'Cache read';

  @override
  String get aiLeaderboardDetailEffortLevels => 'Effort levels';

  @override
  String get aiLeaderboardDetailLicence => 'Licence';

  @override
  String get aiLeaderboardDetailSpecifications => 'SPECIFICATIONS';

  @override
  String get aiLeaderboardDetailEffortTitle => 'EFFORT VS TOKENS USED';

  @override
  String get aiLeaderboardDetailEffortBlurb =>
      'How much smarter each reasoning-effort tier gets, and how many tokens it spends thinking to get there.';

  @override
  String get aiLeaderboardDetailIntelligenceAxis => 'Intelligence index';

  @override
  String aiLeaderboardDetailIndexOnly(String index) {
    return 'Index $index';
  }

  @override
  String aiLeaderboardDetailIndexTokens(String index, String tokens) {
    return 'Index $index · $tokens tok';
  }

  @override
  String aiLeaderboardDetailTokenLine(String label, String tokens) {
    return '$label: $tokens tok';
  }

  @override
  String get aiLeaderboardTableEmptyTitle => 'No model data yet';

  @override
  String get aiLeaderboardTableLoadFailed =>
      'The leaderboard could not be loaded. Try again, or ask the server operator to refresh the model catalogue.';

  @override
  String get aiLeaderboardTableSignInHint =>
      'The leaderboard downloads from the luma server. Sign in to an approved account to fetch it; it stays cached for offline viewing afterwards.';

  @override
  String get aiLeaderboardTableRefreshing => 'Refreshing…';

  @override
  String get aiLeaderboardTableNoMatch => 'No model matches those filters.';

  @override
  String get aiLeaderboardTableSearchHint => 'Search models';

  @override
  String get aiLeaderboardTableOpenWeights => 'Open weights';

  @override
  String get aiLeaderboardTableOpenWeightsTooltip =>
      'Show only models whose weights you can download';

  @override
  String get aiLeaderboardTableDetailed => 'Detailed';

  @override
  String get aiLeaderboardTableDetailedTooltip =>
      'One row per model and reasoning effort, so each effort level is ranked on its own scores';

  @override
  String aiLeaderboardTableModelsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count models',
      one: '1 model',
    );
    return '$_temp0';
  }

  @override
  String aiLeaderboardTableVariantsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count variants',
      one: '1 variant',
    );
    return '$_temp0';
  }

  @override
  String aiLeaderboardTableShownOfModels(int shown, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total models',
      one: '1 model',
    );
    return '$shown of $_temp0';
  }

  @override
  String aiLeaderboardTableShownOfVariants(int shown, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total variants',
      one: '1 variant',
    );
    return '$shown of $_temp0';
  }

  @override
  String get aiLeaderboardOriginNotLoaded => 'not loaded yet';

  @override
  String get aiLeaderboardOriginCached => 'from your last sync';

  @override
  String get aiLeaderboardOriginServer => 'from the luma server';

  @override
  String aiLeaderboardFreshnessText(String time, String origin) {
    return '$time · $origin';
  }

  @override
  String aiLeaderboardFreshnessTooltip(String text) {
    return 'Model data $text';
  }

  @override
  String get aiLeaderboardTableFilterProvider => 'Filter by provider';

  @override
  String get aiLeaderboardTableAllProviders => 'All providers';

  @override
  String get aiLeaderboardTableSortBy => 'Sort by';

  @override
  String aiLeaderboardTableSortedDescending(String column) {
    return '$column, sorted descending';
  }

  @override
  String aiLeaderboardTableSortedAscending(String column) {
    return '$column, sorted ascending';
  }

  @override
  String aiLeaderboardTableNotSorted(String column) {
    return '$column, not sorted';
  }

  @override
  String get aiLeaderboardTableArena => 'Arena';

  @override
  String aiLeaderboardCardPricePerM(String price) {
    return '$price /M';
  }

  @override
  String aiLeaderboardCardContext(String tokens) {
    return '$tokens context';
  }

  @override
  String aiLeaderboardCardParams(String params) {
    return '$params params';
  }

  @override
  String get aiOsEmptyTitle => 'No open-weight models yet';

  @override
  String get aiOsEmptySubtitle =>
      'This calculator sizes models whose weights you can download. None in the current catalogue have a known parameter count — refresh the leaderboard and try again.';

  @override
  String get aiOsWhatCanRunIt => 'WHAT CAN RUN IT';

  @override
  String get aiOsFootnote =>
      'Weight memory is exact arithmetic. The context cost is estimated from the parameter count — the catalogue does not carry each model’s layer count or attention shape, so a model with an unusual design will differ. Leave headroom.';

  @override
  String get aiOsFieldModel => 'Model';

  @override
  String get aiOsFieldQuantization => 'Quantization';

  @override
  String get aiOsFieldContext => 'Context';

  @override
  String get aiOsKv8bit => '8-bit KV';

  @override
  String get aiOsKv8bitTooltip =>
      'Store the context cache at 8 bits instead of 16 — roughly halves what the context costs.';

  @override
  String get aiOsGbOfMemory => 'GB of memory';

  @override
  String get aiOsPartWeights => 'Weights';

  @override
  String get aiOsPartContextCache => 'Context cache';

  @override
  String get aiOsPartRuntime => 'Runtime';

  @override
  String get aiOsVerdictRunsWell => 'Runs well';

  @override
  String get aiOsVerdictTightFit => 'Tight fit';

  @override
  String get aiOsVerdictSpills => 'Spills to RAM';

  @override
  String get aiOsVerdictWontRun => 'Won’t run';

  @override
  String get aiOsUnified => 'unified';

  @override
  String get aiOsUnifiedTooltip =>
      'Shared CPU/GPU memory — this is the share a model can actually claim, not the machine’s total.';

  @override
  String aiOsBitsPerWeight(String bits) {
    return '$bits bit';
  }

  @override
  String get aiOsQuantFp16 => 'Full precision. What the weights ship as.';

  @override
  String get aiOsQuantQ8 => 'Near-lossless. The safe choice when it fits.';

  @override
  String get aiOsQuantQ6 => 'Very close to Q8, noticeably smaller.';

  @override
  String get aiOsQuantQ5 => 'Small quality loss, good balance.';

  @override
  String get aiOsQuantQ4 => 'The usual pick. Real but modest quality loss.';

  @override
  String get aiOsQuantQ3 => 'Visible quality loss. For fitting one tier up.';

  @override
  String get aiOsQuantIq2 => 'Heavy loss. Last resort to fit at all.';

  @override
  String aiBenchmarkServerFailed(String what, int status) {
    return 'The server could not return $what (HTTP $status).';
  }

  @override
  String get aiBenchmarkWhatList => 'the benchmark list';

  @override
  String get aiBenchmarkWhatScene => 'the benchmark scene';

  @override
  String get aiBenchmarkWhatPreview => 'the benchmark preview';

  @override
  String get aiBenchmarkWhatArtwork => 'the benchmark artwork';

  @override
  String get aiBenchmarkMalformed => 'Malformed benchmark response.';

  @override
  String aiBenchmarkUnknownId(String id) {
    return 'Unknown benchmark \"$id\".';
  }

  @override
  String get aiBenchmarkSignInToDownload =>
      'Sign in to an approved luma account to download this benchmark.';

  @override
  String get aiBenchmarkIntegrityFailed =>
      'The downloaded scene failed its integrity check.';

  @override
  String get aiBenchmarkSelectModel => 'Select a Model';

  @override
  String get aiBenchmarkViewList => 'List';

  @override
  String get aiBenchmarkViewBanners => 'Banners';

  @override
  String aiBenchmarkNoMatch(String query) {
    return 'No models match \"$query\"';
  }

  @override
  String get aiBenchmarkTryShorterSearch => 'Try a shorter search.';

  @override
  String get aiBenchmarkNoEntries => 'No entries yet';

  @override
  String get aiBenchmarkSignInToFetch =>
      'Models download from the luma server. Sign in to an approved account to fetch them.';

  @override
  String aiBenchmarkDownloading(String model) {
    return 'Downloading $model…';
  }

  @override
  String aiBenchmarkCouldNotLoad(String model) {
    return 'Could not load $model';
  }

  @override
  String get aiBenchmarkDownloadFailed => 'The download failed.';

  @override
  String aiBenchmarkLoadFailedDetail(String error) {
    return '$error Models are cached after the first download, so a retry is usually all it takes.';
  }

  @override
  String get aiBenchmarkBackToModels => 'Back to models';

  @override
  String get aiBenchmarkOpenInBrowser => 'Open in browser';

  @override
  String get aiBenchmarkCouldNotOpenBrowser => 'Could not open a browser.';

  @override
  String get aiCathedralTitle => 'Cathedral Test';

  @override
  String get aiCathedralHeading => 'Benchmark Model';

  @override
  String get aiCathedralIntro =>
      'A cathedral modelled as a 3D .glb file, one per model. Orbit, zoom and pan to inspect it.';

  @override
  String get aiCathedralEmptyNone => 'No cathedral models have been added yet.';

  @override
  String get aiCathedralUnsupportedTitle => 'Not available on this platform';

  @override
  String get aiCathedralUnsupportedBody =>
      'The Cathedral Test requires a Windows desktop. Mobile and Linux support are coming soon.';

  @override
  String get aiCruiseTitle => 'Cruise Ship Test';

  @override
  String get aiCruiseIntro =>
      'Explore an empty cruise ship at human scale, from the lifeboat promenade to the open upper decks.';

  @override
  String get aiCruiseGptDescription =>
      'MSC Virtuosa at sea: walk the exterior decks and Deck 7 lifeboat promenade, with a day/night cycle, weather and tender views.';

  @override
  String get aiCruiseOpusDescription =>
      'MSC Virtuosa at true scale on a WebGPU sea: walk the outside decks and the Deck 7 lifeboat promenade, ride a tender at sea level, fly a drone or moor in port, with a day/night cycle, volumetric clouds, rain, fog and thunderstorms.';

  @override
  String get aiCruiseWindowsOnlyTitle => 'Windows desktop required';

  @override
  String get aiCruiseWindowsOnlyBody =>
      'Cruise Ship Test uses keyboard and mouse controls in the Windows desktop app.';

  @override
  String get aiCruiseCouldNotLoad => 'Could not load this cruise ship';

  @override
  String get aiCruiseCouldNotStart => 'Could not start the cruise ship';

  @override
  String get aiCruiseTimeout => 'The ship did not finish loading. Try again.';

  @override
  String get aiCruiseRendererFailed =>
      'The cruise ship renderer could not start.';

  @override
  String get aiTestsKeyboardTitle => 'Keyboard Test';

  @override
  String get aiTestsEngineTitle => 'Engine Test';

  @override
  String get aiTestsPagodaTitle => 'Pagoda Test';

  @override
  String get aiTestsBenchmarkModelHeading => 'Benchmark Model';

  @override
  String get aiTestsBenchmarkSceneHeading => 'Benchmark Scene';

  @override
  String get aiTestsKeyboardIntro =>
      'A keyboard built as an interactive scene, one per model.';

  @override
  String get aiTestsEngineIntro =>
      'Cutaway V8 — a real-time 3D cross-plane engine benchmark with crank-driven pistons, half-speed camshafts, synchronized valves, combustion effects and a 30-second FPS benchmark.';

  @override
  String get aiTestsPagodaIntro =>
      'Spring Festival at the Five-Story Pagoda — an interactive voxel garden benchmark with procedural terrain, animated elements, and dynamic lighting.';

  @override
  String get aiTestsSelectModel => 'Select a Model';

  @override
  String get aiTestsListView => 'List';

  @override
  String get aiTestsBannersView => 'Banners';

  @override
  String aiTestsNoModelsMatch(String query) {
    return 'No models match \"$query\"';
  }

  @override
  String get aiTestsTryShorterSearch => 'Try a shorter search.';

  @override
  String get aiTestsKeyboardNoEntries => 'No entries yet';

  @override
  String get aiTestsKeyboardNoScenes =>
      'No keyboard scenes have been added yet.';

  @override
  String get aiTestsScenesSignInHint =>
      'Scenes download from the luma server. Sign in to an approved account to fetch them.';

  @override
  String get aiTestsNoBenchmarksYet => 'No benchmarks yet';

  @override
  String get aiTestsBenchmarkListFailed =>
      'The benchmark list could not be loaded. Try again, or ask the server operator to add scenes.';

  @override
  String get aiTestsBenchmarksSignInHint =>
      'Benchmarks download from the luma server. Sign in to an approved account to fetch them.';

  @override
  String get aiTestsRefreshing => 'Refreshing…';

  @override
  String get aiTestsEngineBundledHeading => 'Bundled engine entries';

  @override
  String get aiTestsEngineOnlineHeading => 'Online benchmark entries';

  @override
  String aiTestsEngineNoBundledMatch(String query) {
    return 'No bundled entries match \"$query\".';
  }

  @override
  String aiTestsEngineDescProcedural(String model) {
    return 'Procedural cross-plane V8 generated by $model.';
  }

  @override
  String aiTestsEngineDescStudy(String model) {
    return 'Interactive V8 engine study generated by $model.';
  }

  @override
  String get aiTestsNotAvailableOnPlatform => 'Not available on this platform';

  @override
  String aiTestsNeedsWindowsDesktop(String test) {
    return '$test requires a Windows desktop. Mobile and Linux support are coming soon.';
  }

  @override
  String aiTestsDownloadingModel(String model) {
    return 'Downloading $model…';
  }

  @override
  String aiTestsCouldNotLoadModel(String model) {
    return 'Could not load $model';
  }

  @override
  String get aiTestsDownloadFailed => 'The download failed.';

  @override
  String aiTestsSceneLoadFailedBody(String error) {
    return '$error Scenes are cached after the first download, so a retry is usually all it takes.';
  }

  @override
  String aiTestsByVendor(String vendor) {
    return 'by $vendor';
  }

  @override
  String get aiTestsPagodaDescStep5 =>
      'StepFun Step 5 Preview voxel garden benchmark';

  @override
  String get aiTestsPagodaDescIndependent =>
      'Independent voxel garden benchmark';

  @override
  String get aiTestsPagodaDescSpaceBunny =>
      'Independent voxel garden benchmark — flying island, sky waterfalls and a five-storey pagoda';

  @override
  String get aiTestsPagodaDescSonnetXhigh =>
      'Sonnet 5.5 at extra-high reasoning effort — a floating garden island with a waterfall and a five-storey pagoda';

  @override
  String get aiTestsPagodaDescGptSolXhigh =>
      'GPT 6.1 Sol at extra-high reasoning effort — spring festival voxel garden with a five-storey pagoda';

  @override
  String get aiTestsPagodaDescGptSolLow =>
      'GPT 6.1 Sol at low reasoning effort — spring festival voxel garden with a five-storey pagoda';

  @override
  String get aiTestPagodaTitle => 'Pagoda Test';

  @override
  String get aiTestEngineTitle => 'Engine Test';

  @override
  String get aiTestPcTitle => 'PC Test';

  @override
  String get aiTestCathedralTitle => 'Cathedral Test';

  @override
  String get aiTestKeyboardTitle => 'Keyboard Test';

  @override
  String get aiTestServerRackTitle => 'Server Rack Test';

  @override
  String get aiTestCruiseShipTitle => 'Cruise Ship Test';

  @override
  String get aiTestWebsiteLandingTitle => 'Website landing page';

  @override
  String get aiTestSportsCarTitle => 'Sports Car Test';

  @override
  String get aiTestTrainWorldTitle => 'Train World Test';

  @override
  String get aiTestWorldTimelineTitle => 'World Timeline Test';

  @override
  String get aiTestFluidSimTitle => 'Fluid Simulation Test';

  @override
  String get aiTestGalaxyTitle => 'Galaxy Test';

  @override
  String get aiTestCruisePortTitle => 'Cruise Port Test';

  @override
  String get aiTestOpenScreen => 'Open the test screen';

  @override
  String get aiTestNewOpenScreen => 'New · Open the test screen';

  @override
  String get aiTestsBlurb =>
      'Scratch space for experiments that are not ready to be a section of their own.';

  @override
  String get aiTestBenchmarkScene => 'Benchmark Scene';

  @override
  String get aiTestBenchmarkModel => 'Benchmark Model';

  @override
  String get aiTestSelectModel => 'Select a Model';

  @override
  String get aiTestViewList => 'List';

  @override
  String get aiTestViewBanners => 'Banners';

  @override
  String get aiTestNotAvailablePlatform => 'Not available on this platform';

  @override
  String aiTestNoMatch(String query) {
    return 'No models match \"$query\"';
  }

  @override
  String get aiTestTrySearchShorter => 'Try a shorter search.';

  @override
  String aiTestDownloadingModel(String model) {
    return 'Downloading $model…';
  }

  @override
  String aiTestCouldNotLoadModel(String model) {
    return 'Could not load $model';
  }

  @override
  String aiTestLoadFailedBody(String error) {
    return '$error Scenes are cached after the first download, so a retry is usually all it takes.';
  }

  @override
  String get aiTestDownloadFailed => 'The download failed.';

  @override
  String get aiTestPcBlurb =>
      'Explore interactive 3D gaming PC builds with power sequences, RGB lighting and hardware controls.';

  @override
  String get aiTestPcBundledDesc =>
      'HELIX 01 — an ivory and aluminum showcase with a custom liquid loop, hinged glass, exploded inspection and power/RGB controls.';

  @override
  String get aiTestPcPlatformBody =>
      'The PC Test requires a Windows desktop. Mobile and Linux support are coming soon.';

  @override
  String get aiTestPcEmptyCanRefresh =>
      'The benchmark list could not be loaded. Try again, or ask the server operator to add scenes.';

  @override
  String get aiTestEmptyNoAccount =>
      'Benchmarks download from the luma server. Sign in to an approved account to fetch them.';

  @override
  String get aiTestNoScenesYet => 'No scenes have been added to this test yet.';

  @override
  String get aiTestScenesDownloadNoAccount =>
      'Scenes download from the luma server. Sign in to an approved account to fetch them.';

  @override
  String aiTestScenePlatformBody(String title) {
    return 'The $title requires a Windows desktop. Mobile and Linux support are coming soon.';
  }

  @override
  String get aiTestSportsCarBlurb =>
      'An original sports car: studio configurator and test drive.';

  @override
  String get aiTestTrainWorldBlurb =>
      'A miniature railway with three trains kept apart by signals.';

  @override
  String get aiTestWorldTimelineBlurb =>
      'An SVG animation of the world from its formation to today.';

  @override
  String get aiTestFluidSimBlurb =>
      'Real-time 3D water in a glass tank you can stir and tilt.';

  @override
  String get aiTestGalaxyBlurb =>
      'A spaceship voyage across a procedural spiral galaxy.';

  @override
  String get aiTestCruisePortBlurb =>
      'A cruise ship docked in Lisbon, below Alfama.';

  @override
  String get aiTestWebsiteLandingBlurb =>
      'A responsive coffee landing page with working interactions.';

  @override
  String get aiTestServerRackBlurb =>
      'A full 42U rack and a single-server slice view: macro architecture of how machines fit a rack, and micro architecture of the hardware inside one chassis.';

  @override
  String get aiTestRackPlatformBody =>
      'The Server Rack Test requires Windows desktop.';

  @override
  String get aiTestRackSonnetLowDesc =>
      'Full 42U rack plus single-slice server inspection by Sonnet 5.5 Low.';

  @override
  String get aiTestRackSonnetXhighDesc =>
      'A 42U rack of nine inspectable servers; each one slides out on its rails into an open single-slice view with exploded, cutaway and airflow modes.';

  @override
  String get aiTestRackSonnetHighDesc =>
      'A 42U rack with labelled units that opens into a per-server detail view with airflow simulation.';

  @override
  String get aiTestRackOpusLowDesc =>
      'A cabled 42U rack of nine servers across five archetypes; each slides out into an open-chassis slice with exploded, cutaway and obstacle-aware airflow views.';

  @override
  String get aiTestRackOpusXhighDesc =>
      'A cabled, power-budgeted 42U rack of nine servers with nine different layouts; each unlatches, slides out on its rails and opens into a hoverable slice with exploded, cutaway and solved-airflow views.';

  @override
  String get aiTestRackMuseDesc =>
      'RACKSCOPE·42U: a cabled rack with a unit browser and an inspectable single-server view.';

  @override
  String get airlineBuildingApronName => 'Apron';

  @override
  String get airlineBuildingApronBlurb =>
      'Paved parking and taxi surface. Hangars and fuel depots work better next to one.';

  @override
  String get airlineBuildingGateName => 'Gate';

  @override
  String get airlineBuildingGateBlurb =>
      'One stand for one route. Only works when it touches a terminal.';

  @override
  String get airlineBuildingTerminalName => 'Terminal';

  @override
  String get airlineBuildingTerminalBlurb =>
      'Passenger building. Gates must touch one to be usable.';

  @override
  String get airlineBuildingRunwayShortName => 'Short runway';

  @override
  String get airlineBuildingRunwayShortBlurb =>
      '1,800 m. Turboprops and small regional jets only.';

  @override
  String get airlineBuildingRunwayMediumName => 'Medium runway';

  @override
  String get airlineBuildingRunwayMediumBlurb =>
      '2,600 m. Opens up narrowbodies and the smaller widebodies.';

  @override
  String get airlineBuildingRunwayLongName => 'Long runway';

  @override
  String get airlineBuildingRunwayLongBlurb =>
      '3,400 m. Everything up to the A380 can use it.';

  @override
  String get airlineBuildingHangarName => 'Hangar';

  @override
  String get airlineBuildingHangarBlurb =>
      'Cuts maintenance. Worth more when it opens onto an apron.';

  @override
  String get airlineBuildingFuelDepotName => 'Fuel depot';

  @override
  String get airlineBuildingFuelDepotBlurb =>
      'Buys fuel in bulk. Worth more when it opens onto an apron.';

  @override
  String get airlineBuildingCargoName => 'Cargo terminal';

  @override
  String get airlineBuildingCargoBlurb =>
      'Sells the hold space under the cabin on every flight.';

  @override
  String get airlineBuildingLoungeName => 'Lounge';

  @override
  String get airlineBuildingLoungeBlurb =>
      'Premium fares on long-haul. Must touch a terminal.';

  @override
  String get airlineSlotAnyTime => 'any time';

  @override
  String get airlineErrRestoreBalance =>
      'Restore a positive balance before acquiring aircraft.';

  @override
  String get airlineErrNotEnoughCashAircraft =>
      'Not enough cash for that aircraft.';

  @override
  String get airlineErrLeaseWeek =>
      'You need at least a week of lease payments in the bank first.';

  @override
  String get airlineErrCancelFlightsFirst =>
      'Cancel scheduled flights and wait for this aircraft to return before releasing it.';

  @override
  String get airlineErrNoSuchAircraft => 'No such aircraft.';

  @override
  String get airlineErrRouteUnavailable => 'That route is not available.';

  @override
  String airlineErrOutOfRange(
    String model,
    String city,
    String km,
    String rangeKm,
  ) {
    return '$model cannot reach $city — $km km against $rangeKm km of range.';
  }

  @override
  String airlineErrRunwayTooShort(String model, String needM, String longestM) {
    return '$model needs $needM m of runway; your longest is $longestM m.';
  }

  @override
  String get airlineErrUnknownDestination => 'Unknown destination.';

  @override
  String get airlineErrOwnHub => 'That is your own hub.';

  @override
  String airlineErrAlreadyFly(String city) {
    return 'You already fly to $city.';
  }

  @override
  String airlineErrGatesTaken(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gates',
      one: '1 gate',
    );
    return 'Every usable gate is taken. You have $_temp0 not touching a terminal — move them next to one to put them to work.';
  }

  @override
  String get airlineErrNeedGate =>
      'You need another gate next to a terminal to add a route.';

  @override
  String get airlineErrNotEnoughCashLaunch =>
      'Not enough cash to launch the route.';

  @override
  String get airlineErrDoesNotFit => 'That does not fit on the field.';

  @override
  String get airlineErrAlreadyBuilt => 'Something is already built there.';

  @override
  String airlineErrCannotAffordBuilding(String name) {
    return 'Not enough cash for $name.';
  }

  @override
  String get airlineErrNothingToDemolish => 'Nothing to demolish there.';

  @override
  String get airlineErrFieldAtLimit => 'The field is already at its limit.';

  @override
  String get airlineErrNotEnoughCashLand => 'Not enough cash to buy more land.';

  @override
  String get airlineErrSaveUnreadable =>
      'Could not read the airport save. The original file has been preserved.';

  @override
  String get airlineErrSaveStorageUnavailable =>
      'Airport save storage is unavailable.';

  @override
  String get airlineErrSaveFailed =>
      'Could not save this airport. Progress is still in memory; check available storage.';

  @override
  String airlineEventAdvanced(String minutes) {
    return 'Airport operations advanced $minutes game minutes.';
  }

  @override
  String airlineEventHeavyCheck(String registration, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$registration went in for a heavy check ($_temp0).';
  }

  @override
  String get airlineErrStartAirportFirst => 'Start an airport first.';

  @override
  String get airlineErrSelectBuildingFirst => 'Select a building first.';

  @override
  String get airlineErrCatalogUnavailable => 'Airport catalog is unavailable.';

  @override
  String get airlineErrChooseSpeed => 'Choose 1×, 4× or 12×.';

  @override
  String get airlineErrUnknownCommand => 'Unknown airport command.';

  @override
  String get airlineErrInvalidCommand => 'Invalid airport command.';

  @override
  String get airlineErrNoPanel => 'That panel does not exist.';

  @override
  String get airlineTabFleet => 'Fleet';

  @override
  String get airlineTabRoutes => 'Routes';

  @override
  String get airlineTabHub => 'Hub';

  @override
  String get airlineTabFinances => 'Finances';

  @override
  String get airlinePause => 'Pause';

  @override
  String get airlineResume => 'Resume';

  @override
  String airlineDaySemantics(int day) {
    return 'Day $day';
  }

  @override
  String airlineSpeedSemantics(int speed) {
    return '${speed}x speed';
  }

  @override
  String get airlineTakeOff => 'Take off';

  @override
  String get airlineChooseHubToContinue => 'Choose a hub to continue.';

  @override
  String get airlineStartAirlineTitle => 'Start an airline';

  @override
  String get airlinePickHubBlurb =>
      'Pick a home airport. Everything you fly departs from there, and it is the field you will build out.';

  @override
  String get airlineNameLabel => 'Airline name';

  @override
  String get airlineHomeHubLabel => 'Home hub';

  @override
  String airlineHubOptionDetail(String name, String runway, String country) {
    return '$name · $runway m runway · $country';
  }

  @override
  String get airlineBackToAirport => 'Back to airport';

  @override
  String get airlineRoutesEstimateNote =>
      'Route estimates assume full-day aircraft use. Airport earnings come from the flights you schedule.';

  @override
  String get airlineSceneStartFailedWindows =>
      'The airport did not start. Check that the Microsoft Edge WebView2 Runtime is installed, then retry.';

  @override
  String get airlineSceneStartFailedAndroid =>
      'The airport did not start. Update Android System WebView, then retry.';

  @override
  String get airlineSceneConnectionLost =>
      'Airport connection interrupted. Retry to reconnect.';

  @override
  String get airlineSceneWebglFailed => 'WebGL could not initialize.';

  @override
  String airlineSceneLoadFailed(String error) {
    return 'Could not load the bundled airport: $error';
  }

  @override
  String get airlineReloadAirport => 'Reload airport';

  @override
  String get airlineAwayTitle => 'While you were away';

  @override
  String airlineAwayDuration(String duration, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$duration away · $_temp0 flown';
  }

  @override
  String get airlineAwayEarned => 'earned';

  @override
  String get airlineAwayLost => 'lost';

  @override
  String get airlineAwayIncome => 'Income';

  @override
  String get airlineAwayCosts => 'Costs';

  @override
  String get airlineAwayPassengers => 'Passengers';

  @override
  String get airlineAwayOfflineRate => 'Offline rate';

  @override
  String airlineAwayCapped(int elapsed, int maxDays) {
    String _temp0 = intl.Intl.pluralLogic(
      elapsed,
      locale: localeName,
      other: '$elapsed days',
      one: '1 day',
    );
    return '$_temp0 went by, but an absence pays for at most $maxDays days. The rest were not flown.';
  }

  @override
  String get airlineBackToWork => 'Back to work';

  @override
  String get airlineLabelDay => 'Day';

  @override
  String get airlineLabelSeats => 'Seats';

  @override
  String get airlineLabelRange => 'Range';

  @override
  String get airlineLabelHours => 'Hours';

  @override
  String get airlineLabelLease => 'Lease';

  @override
  String get airlineLabelResale => 'Resale';

  @override
  String get airlineLabelCruise => 'Cruise';

  @override
  String get airlineLabelRunway => 'Runway';

  @override
  String get airlineLabelAircraft => 'Aircraft';

  @override
  String get airlineLabelRoutes => 'Routes';

  @override
  String get airlineLabelDistance => 'Distance';

  @override
  String get airlineLabelDailyDemand => 'Daily demand';

  @override
  String get airlineLabelFairFare => 'Fair fare';

  @override
  String get airlineLabelRunwayThere => 'Runway there';

  @override
  String get airlineLabelType => 'Type';

  @override
  String get airlineLabelMaintenance => 'Maintenance';

  @override
  String get airlineLabelFuel => 'Fuel';

  @override
  String get airlineLabelUpkeep => 'Upkeep';

  @override
  String airlineFactPerDay(String amount) {
    return '$amount/day';
  }

  @override
  String airlineFactMetres(String value) {
    return '$value m';
  }

  @override
  String airlineFactKmh(String speed) {
    return '$speed km/h';
  }

  @override
  String get airlineRunwayNone => 'none';

  @override
  String get airlineFinCash => 'Cash';

  @override
  String get airlineFinChartEmpty =>
      'Trade a few days and the balance chart appears here.';

  @override
  String get airlineFinSoFar => 'The airline so far';

  @override
  String airlineFinDayHeading(String day) {
    return 'Day $day';
  }

  @override
  String get airlineFinStatFlightsFlown => 'Flights flown';

  @override
  String get airlineFinStatPassengers => 'Passengers carried';

  @override
  String get airlineFinStatFuelPrice => 'Fuel price';

  @override
  String get airlineFinLineTickets => 'Tickets';

  @override
  String get airlineFinLineCargo => 'Cargo';

  @override
  String get airlineFinLineCrew => 'Crew';

  @override
  String get airlineFinLineAirportFees => 'Airport fees';

  @override
  String get airlineFinLineHubUpkeep => 'Hub upkeep';

  @override
  String get airlineFinLineLeasePayments => 'Lease payments';

  @override
  String airlineFinDaySummary(String flights, String passengers) {
    return '$flights flights · $passengers passengers';
  }

  @override
  String get airlineFinFieldTitle => 'The field';

  @override
  String airlineFinLandAtMax(String size) {
    return 'Your land is $size by $size — the largest the airport authority will sell you.';
  }

  @override
  String airlineFinLandGrow(String size) {
    return 'Your land is $size by $size. Buying more gives you room for another terminal and the gates that go with it.';
  }

  @override
  String get airlineFinAtLimit => 'At the limit';

  @override
  String airlineFinBuyLand(String price) {
    return 'Buy land · $price';
  }

  @override
  String airlineFleetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aircraft',
      one: '1 aircraft',
      zero: 'No aircraft',
    );
    return '$_temp0';
  }

  @override
  String get airlineFleetAcquire => 'Acquire';

  @override
  String get airlineFleetEmptyTitle => 'Your hangar is empty';

  @override
  String get airlineFleetEmptySubtitle =>
      'Buy or lease an aircraft to start flying.';

  @override
  String get airlineFleetBrowse => 'Browse aircraft';

  @override
  String airlineFleetInCheck(String days) {
    return 'In check · ${days}d';
  }

  @override
  String airlineFleetDetail(String registration, String maker) {
    return '$registration · $maker';
  }

  @override
  String airlineFleetDetailLeased(String registration, String maker) {
    return '$registration · $maker · leased';
  }

  @override
  String get airlineFleetReturnTitle => 'Return this aircraft?';

  @override
  String get airlineFleetSellTitle => 'Sell this aircraft?';

  @override
  String airlineFleetReturnBody(String registration) {
    return '$registration goes back to the lessor. The daily payment stops.';
  }

  @override
  String airlineFleetSellBody(String registration, String value, String price) {
    return '$registration sells for $value, well under the $price it cost.';
  }

  @override
  String get airlineFleetKeepIt => 'Keep it';

  @override
  String get airlineFleetReturn => 'Return';

  @override
  String get airlineFleetSell => 'Sell';

  @override
  String get airlineFleetOpenRouteFirst => 'Open a route first';

  @override
  String get airlineFleetUnassigned => 'Unassigned';

  @override
  String get airlineMarketTitle => 'Aircraft market';

  @override
  String airlineMarketJoinedFleet(String name) {
    return '$name joined the fleet.';
  }

  @override
  String airlineMarketNeedsRunway(String needed, String longest) {
    return 'Needs $needed of runway; your longest is $longest. You can still buy it and build up to it.';
  }

  @override
  String get airlineMarketLease => 'Lease';

  @override
  String get airlineMarketBuy => 'Buy';

  @override
  String get airlineRoutesEmptyTitle => 'No routes yet';

  @override
  String get airlineRoutesEmptySubtitle =>
      'Tap an airport on the map to open your first route.';

  @override
  String airlineRoutesSummary(int routes, int gates) {
    String _temp0 = intl.Intl.pluralLogic(
      routes,
      locale: localeName,
      other: '$routes routes',
      one: '1 route',
    );
    String _temp1 = intl.Intl.pluralLogic(
      gates,
      locale: localeName,
      other: '$gates gates',
      one: '1 gate',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get airlineRoutesNoUsableAircraft =>
      'Nothing in the catalogue can fly this from your hub yet — you need a longer runway, or this sector is beyond every aircraft you could buy.';

  @override
  String airlineRoutesCanBeFlownBy(String names) {
    return 'Can be flown by: $names.';
  }

  @override
  String airlineRoutesCanBeFlownByMore(String names, String more) {
    return 'Can be flown by: $names and $more more.';
  }

  @override
  String airlineRoutesOpenRoute(String price) {
    return 'Open route · $price';
  }

  @override
  String airlineRoutesPax(String count) {
    return '$count pax';
  }

  @override
  String get airlineRoutesNoAircraft => 'no aircraft';

  @override
  String airlineRoutesAssigned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count assigned',
      one: '1 assigned',
    );
    return '$_temp0';
  }

  @override
  String get airlineRoutesFare => 'Fare';

  @override
  String get airlineRoutesCabinFilled => 'Cabin filled';

  @override
  String get airlineRoutesNoAircraftAssigned => 'No aircraft assigned';

  @override
  String get airlineRoutesProjectedToday => 'Projected today';

  @override
  String get airlineRoutesAssignInFleet => 'Assign one in Fleet';

  @override
  String airlineRoutesProjection(String profit, String pax) {
    return '$profit · $pax pax';
  }

  @override
  String get airlineRoutesCloseRoute => 'Close this route';

  @override
  String get airlineHubFailed => 'That did not work.';

  @override
  String airlineHubTileTooltip(String name, String blurb) {
    return '$name — $blurb';
  }

  @override
  String airlineHubTileSemantics(String name, String price) {
    return '$name, $price';
  }

  @override
  String airlineHubTileSemanticsTooExpensive(String name, String price) {
    return '$name, $price, too expensive';
  }

  @override
  String get airlineHubRotate => 'Rotate';

  @override
  String get airlineHubDemolish => 'Demolish';

  @override
  String get airlineHubGates => 'Gates';

  @override
  String get airlineHubNotOnTerminal => 'Not on a terminal';

  @override
  String get calcNothingToWorkOut => 'Nothing to work out yet.';

  @override
  String get calcUndefined => 'Undefined';

  @override
  String calcNotANumber(String text) {
    return '\"$text\" is not a number.';
  }

  @override
  String calcUnknownCharacter(String character) {
    return 'I don\'t understand \"$character\".';
  }

  @override
  String calcUnknownName(String name) {
    return 'I don\'t know \"$name\".';
  }

  @override
  String calcUnexpectedToken(String token) {
    return '\"$token\" doesn\'t belong there.';
  }

  @override
  String get calcStopsTooEarly => 'The expression stops too early.';

  @override
  String get calcBracketLeftOpen => 'A bracket is left open.';

  @override
  String calcExpectedSymbol(String symbol) {
    return 'Expected \"$symbol\".';
  }

  @override
  String calcArgCountExact(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count values',
      one: '1 value',
    );
    return '$name needs $_temp0.';
  }

  @override
  String calcArgCountRange(String name, int minCount, int maxCount) {
    return '$name needs $minCount to $maxCount values.';
  }

  @override
  String get calcFactorialWholeNumbers =>
      'Factorial only works on whole numbers from 0.';

  @override
  String get calcCombinatoricsWholeNumbers =>
      'nCr and nPr need whole numbers from 0.';

  @override
  String get audioToolsInvalidSnapshot => 'Invalid audio tools snapshot.';

  @override
  String get autoClickerPressNewHotkey => 'Press a new hotkey';

  @override
  String get autoClickerWindowsOnlyBody =>
      'Auto Clicker simulates real mouse clicks, which luma can only do in the Windows desktop app.';

  @override
  String get autoClickerClicking => 'Clicking…';

  @override
  String get autoClickerStopped => 'Stopped';

  @override
  String autoClickerClicksSoFar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clicks',
      one: '1 click',
    );
    return '$_temp0 so far';
  }

  @override
  String autoClickerStartHint(String hotkey) {
    return 'Start it, or press $hotkey from anywhere';
  }

  @override
  String get autoClickerStopClicking => 'Stop clicking';

  @override
  String get autoClickerStartClicking => 'Start clicking';

  @override
  String get autoClickerPickFixedFirst =>
      'Pick a fixed location below before starting.';

  @override
  String get autoClickerRandomHelpExact =>
      'Adds ± randomness to each click delay. Leave 0 for exact timing.';

  @override
  String autoClickerRandomHelpRange(String low, String high) {
    return 'Each click fires between $low and $high ms (never below 1 ms).';
  }

  @override
  String get autoClickerClickEvery => 'Click every';

  @override
  String get autoClickerHours => 'Hours';

  @override
  String get autoClickerMinutes => 'Minutes';

  @override
  String get autoClickerSeconds => 'Seconds';

  @override
  String get autoClickerMillis => 'Millis';

  @override
  String get autoClickerRandomOffset => 'Random offset';

  @override
  String get autoClickerMilliseconds => 'milliseconds';

  @override
  String get autoClickerMouseButton => 'Mouse button';

  @override
  String get autoClickerLeft => 'Left';

  @override
  String get autoClickerMiddle => 'Middle';

  @override
  String get autoClickerRight => 'Right';

  @override
  String get autoClickerClickType => 'Click type';

  @override
  String get autoClickerSingle => 'Single';

  @override
  String get autoClickerDouble => 'Double';

  @override
  String get autoClickerClickLocation => 'Click location';

  @override
  String get autoClickerCurrentCursor => 'Current cursor';

  @override
  String get autoClickerFixedPosition => 'Fixed position';

  @override
  String autoClickerHoldCursor(int countdown) {
    return 'Hold your cursor over the target… $countdown';
  }

  @override
  String autoClickerTarget(String x, String y) {
    return 'Target: $x, $y';
  }

  @override
  String get autoClickerNoPositionYet => 'No position set yet';

  @override
  String get autoClickerPicking => 'Picking…';

  @override
  String get autoClickerPickLocation => 'Pick location';

  @override
  String get autoClickerRepeat => 'Repeat';

  @override
  String get autoClickerUntilStopped => 'Until stopped';

  @override
  String get autoClickerSetAmount => 'Set amount';

  @override
  String get autoClickerClicksTotal => 'clicks total';

  @override
  String get autoClickerHotkeyLabel => 'Start/stop hotkey';

  @override
  String get autoClickerChange => 'Change';

  @override
  String get autoClickerHotKeyRegisterFailed =>
      'Could not register the global hotkey — another app may already be using it.';

  @override
  String get autoClickerInvalidSnapshot => 'Invalid auto clicker snapshot.';

  @override
  String get bulletinBoardNewNote => 'New Note';

  @override
  String get bulletinBoardNewChecklist => 'New Checklist';

  @override
  String bulletinBoardChecklistItem(String number) {
    return 'Item $number';
  }

  @override
  String get bulletinBoardNote => 'Note';

  @override
  String get bulletinBoardIdea => 'Idea';

  @override
  String get bulletinBoardChecklist => 'Checklist';

  @override
  String get bulletinBoardImage => 'Image';

  @override
  String get bulletinBoardNoteContentHint => 'Note content...';

  @override
  String get bulletinBoardQuickIdeaHint => 'Quick idea...';

  @override
  String get bulletinBoardAddItem => '+ Add Item';

  @override
  String get bulletinBoardNoImage => 'No image';

  @override
  String get bulletinBoardImageNotFound => 'Image not found';

  @override
  String get calcErrorHasX => 'That has an x in it — press Plot to draw it.';

  @override
  String get calcPlotNeedsExpression => 'Type something like x^2 - 3 first.';

  @override
  String get calcStorageFullFunctionNotSaved =>
      'Local storage is full, so this function was not saved.';

  @override
  String get calcConvertUnitsTooltip => 'Convert units';

  @override
  String get calcModeBasic => 'Basic';

  @override
  String get calcModeAdvanced => 'Advanced';

  @override
  String get calcSwitchToRadians => 'Switch to radians';

  @override
  String get calcSwitchToDegrees => 'Switch to degrees';

  @override
  String get calcKeypadTab => 'Keypad';

  @override
  String get calcGraphTab => 'Graph';

  @override
  String calcPlotAs(String expression) {
    return 'Plot as y = $expression';
  }

  @override
  String get calcHistoryEmpty => 'Sums you work out show up here.';

  @override
  String get calcFunctionsTitle => 'Functions';

  @override
  String get calcNothingPlotted =>
      'Nothing plotted yet. Type something with an x — like x^2 - 3 or sin(x) — and press Plot.';

  @override
  String get calcFunctionHide => 'Hide';

  @override
  String get calcFunctionShow => 'Show';

  @override
  String get calcClearTrace => 'Clear trace';

  @override
  String get calcResetView => 'Reset view';

  @override
  String get calcPlotFunctionTitle => 'Plot a function';

  @override
  String get calcEditFunctionTitle => 'Edit function';

  @override
  String get calcFunctionEmpty => 'Type a function of x first.';

  @override
  String get calcStorageFullNotSaved =>
      'Local storage is full, so this was not saved.';

  @override
  String get calcFunctionColour => 'Colour';

  @override
  String get calcPlot => 'Plot';

  @override
  String get calcConvertFrom => 'From';

  @override
  String get calcConvertTo => 'To';

  @override
  String get calcConvertEveryUnit => 'Every unit';

  @override
  String get calcConvertSwapUnits => 'Swap units';

  @override
  String get calcConvertUseInCalculator => 'Use in calculator';

  @override
  String get calcInvalidSnapshot => 'Invalid calculator snapshot.';

  @override
  String get calcCategoryLength => 'Length';

  @override
  String get calcCategoryWeight => 'Weight';

  @override
  String get calcCategoryTemperature => 'Temperature';

  @override
  String get calcCategorySpeed => 'Speed';

  @override
  String get calcCategoryArea => 'Area';

  @override
  String get calcCategoryVolume => 'Volume';

  @override
  String get calcCategoryTime => 'Time';

  @override
  String get calcCategoryData => 'Data';

  @override
  String get calcCategoryPressure => 'Pressure';

  @override
  String get calcCategoryEnergy => 'Energy';

  @override
  String get calcCategoryAngle => 'Angle';

  @override
  String get calcUnitKilometre => 'Kilometre';

  @override
  String get calcUnitMetre => 'Metre';

  @override
  String get calcUnitCentimetre => 'Centimetre';

  @override
  String get calcUnitMillimetre => 'Millimetre';

  @override
  String get calcUnitMile => 'Mile';

  @override
  String get calcUnitYard => 'Yard';

  @override
  String get calcUnitFoot => 'Foot';

  @override
  String get calcUnitInch => 'Inch';

  @override
  String get calcUnitNauticalMile => 'Nautical mile';

  @override
  String get calcUnitTonne => 'Tonne';

  @override
  String get calcUnitKilogram => 'Kilogram';

  @override
  String get calcUnitGram => 'Gram';

  @override
  String get calcUnitMilligram => 'Milligram';

  @override
  String get calcUnitPound => 'Pound';

  @override
  String get calcUnitOunce => 'Ounce';

  @override
  String get calcUnitStone => 'Stone';

  @override
  String get calcUnitCelsius => 'Celsius';

  @override
  String get calcUnitFahrenheit => 'Fahrenheit';

  @override
  String get calcUnitKelvin => 'Kelvin';

  @override
  String get calcUnitKilometresPerHour => 'Kilometres per hour';

  @override
  String get calcUnitMetresPerSecond => 'Metres per second';

  @override
  String get calcUnitMilesPerHour => 'Miles per hour';

  @override
  String get calcUnitKnot => 'Knot';

  @override
  String get calcUnitFeetPerSecond => 'Feet per second';

  @override
  String get calcUnitSquareKilometre => 'Square kilometre';

  @override
  String get calcUnitHectare => 'Hectare';

  @override
  String get calcUnitSquareMetre => 'Square metre';

  @override
  String get calcUnitSquareCentimetre => 'Square centimetre';

  @override
  String get calcUnitSquareMile => 'Square mile';

  @override
  String get calcUnitAcre => 'Acre';

  @override
  String get calcUnitSquareYard => 'Square yard';

  @override
  String get calcUnitSquareFoot => 'Square foot';

  @override
  String get calcUnitCubicMetre => 'Cubic metre';

  @override
  String get calcUnitLitre => 'Litre';

  @override
  String get calcUnitMillilitre => 'Millilitre';

  @override
  String get calcUnitGallonUs => 'Gallon (US)';

  @override
  String get calcUnitGallonUk => 'Gallon (UK)';

  @override
  String get calcUnitQuartUs => 'Quart (US)';

  @override
  String get calcUnitPintUs => 'Pint (US)';

  @override
  String get calcUnitCupUs => 'Cup (US)';

  @override
  String get calcUnitFluidOunceUs => 'Fluid ounce (US)';

  @override
  String get calcUnitTablespoonUs => 'Tablespoon (US)';

  @override
  String get calcUnitTeaspoonUs => 'Teaspoon (US)';

  @override
  String get calcUnitMillisecond => 'Millisecond';

  @override
  String get calcUnitSecond => 'Second';

  @override
  String get calcUnitMinute => 'Minute';

  @override
  String get calcUnitHour => 'Hour';

  @override
  String get calcUnitDay => 'Day';

  @override
  String get calcUnitWeek => 'Week';

  @override
  String get calcUnitMonth30Days => 'Month (30 days)';

  @override
  String get calcUnitYear365Days => 'Year (365 days)';

  @override
  String get calcUnitBit => 'Bit';

  @override
  String get calcUnitByte => 'Byte';

  @override
  String get calcUnitKilobyte => 'Kilobyte';

  @override
  String get calcUnitMegabyte => 'Megabyte';

  @override
  String get calcUnitGigabyte => 'Gigabyte';

  @override
  String get calcUnitTerabyte => 'Terabyte';

  @override
  String get calcUnitKibibyte => 'Kibibyte';

  @override
  String get calcUnitMebibyte => 'Mebibyte';

  @override
  String get calcUnitGibibyte => 'Gibibyte';

  @override
  String get calcUnitTebibyte => 'Tebibyte';

  @override
  String get calcUnitPascal => 'Pascal';

  @override
  String get calcUnitHectopascal => 'Hectopascal';

  @override
  String get calcUnitKilopascal => 'Kilopascal';

  @override
  String get calcUnitBar => 'Bar';

  @override
  String get calcUnitMillibar => 'Millibar';

  @override
  String get calcUnitAtmosphere => 'Atmosphere';

  @override
  String get calcUnitPoundPerSquareInch => 'Pound per square inch';

  @override
  String get calcUnitMillimetreOfMercury => 'Millimetre of mercury';

  @override
  String get calcUnitJoule => 'Joule';

  @override
  String get calcUnitKilojoule => 'Kilojoule';

  @override
  String get calcUnitCalorie => 'Calorie';

  @override
  String get calcUnitKilocalorie => 'Kilocalorie';

  @override
  String get calcUnitWattHour => 'Watt hour';

  @override
  String get calcUnitKilowattHour => 'Kilowatt hour';

  @override
  String get calcUnitBritishThermalUnit => 'British thermal unit';

  @override
  String get calcUnitDegree => 'Degree';

  @override
  String get calcUnitRadian => 'Radian';

  @override
  String get calcUnitGradian => 'Gradian';

  @override
  String get calcUnitTurn => 'Turn';

  @override
  String get calcUnitArcminute => 'Arcminute';

  @override
  String get calcUnitArcsecond => 'Arcsecond';

  @override
  String get calendarRepeatNone => 'Does not repeat';

  @override
  String get calendarRepeatDaily => 'Every day';

  @override
  String get calendarRepeatWeekly => 'Every week';

  @override
  String get calendarRepeatMonthly => 'Every month';

  @override
  String get calendarRepeatYearly => 'Every year';

  @override
  String get calendarViewDay => 'Day';

  @override
  String get calendarViewWeek => 'Week';

  @override
  String get calendarViewMonth => 'Month';

  @override
  String get calendarViewAgenda => 'Agenda';

  @override
  String get calendarNewEvent => 'New event';

  @override
  String get calendarAddEvent => 'Add event';

  @override
  String get calendarSearchHint => 'Search events';

  @override
  String calendarMoreCount(int count) {
    return '+$count more';
  }

  @override
  String calendarEventCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '1 event',
      zero: 'No events',
    );
    return '$_temp0';
  }

  @override
  String get calendarEmptyDayTitle => 'Empty day';

  @override
  String get calendarEmptyDaySubtitle => 'Put something fun here.';

  @override
  String get calendarSetDinnerForDay => 'Set dinner for this day';

  @override
  String get calendarDinnerLabel => 'Dinner';

  @override
  String get calendarAllDay => 'All-day';

  @override
  String get calendarAllDayStrip => 'all-day';

  @override
  String calendarAllDayDays(int count) {
    return 'All-day · $count days';
  }

  @override
  String get calendarReminderAtStart => 'At start';

  @override
  String calendarReminderDaysBefore(int count) {
    return '${count}d before';
  }

  @override
  String calendarReminderHoursBefore(int count) {
    return '${count}h before';
  }

  @override
  String calendarReminderMinutesShort(int count) {
    return '${count}m before';
  }

  @override
  String get calendarNothingComingUp => 'Nothing coming up';

  @override
  String get calendarAgendaEmptySubtitle => 'Whatever you plan shows up here.';

  @override
  String calendarNoEventsMatch(String query) {
    return 'No events match “$query”';
  }

  @override
  String get calendarSearchEmptySubtitle =>
      'Try a different title, place or note.';

  @override
  String calendarSearchResultCount(int count, String query) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results for “$query”',
      one: '1 result for “$query”',
    );
    return '$_temp0';
  }

  @override
  String get calendarEditEvent => 'Edit event';

  @override
  String get calendarEventTitleHint => 'Event title';

  @override
  String get calendarStarts => 'Starts';

  @override
  String get calendarEnds => 'Ends';

  @override
  String get calendarRepeat => 'Repeat';

  @override
  String get calendarLocation => 'Location';

  @override
  String get calendarReminder => 'Reminder';

  @override
  String get calendarAddPlace => 'Add a place';

  @override
  String get calendarAddDetails => 'Add details';

  @override
  String calendarSharedByView(String author) {
    return 'Shared by $author — view only';
  }

  @override
  String get calendarFamilyMemberFallback => 'a family member';

  @override
  String get calendarShareJustMe => 'Just me';

  @override
  String get calendarShareWholeFamily => 'Whole family';

  @override
  String get calendarShareChoosePeople => 'Choose people';

  @override
  String get calendarNoOtherMembers => 'No other family members yet.';

  @override
  String get calendarGiveTitle => 'Give the event a title.';

  @override
  String get calendarChooseShareOne =>
      'Choose at least one person to share with.';

  @override
  String get calendarDeleteEvent => 'Delete event';

  @override
  String get calendarRepeatsForever => 'Repeats forever';

  @override
  String calendarRepeatsUntil(String date) {
    return 'Until $date';
  }

  @override
  String get calendarClearEndDate => 'Clear end date';

  @override
  String get calendarSetEnd => 'Set end';

  @override
  String get calendarChangeEnd => 'Change';

  @override
  String get calendarReminderNone => 'No reminder';

  @override
  String get calendarReminderAtStartTime => 'At start time';

  @override
  String calendarReminderMinutesBefore(int count) {
    return '$count minutes before';
  }

  @override
  String get calendarReminderHourBefore => '1 hour before';

  @override
  String get calendarReminderDayBefore => '1 day before';

  @override
  String get calendarDinnerNameRequired => 'Give the dinner a name.';

  @override
  String get calendarDishNameHint => 'Dish name';

  @override
  String get calendarServings => 'Servings';

  @override
  String get calendarMinutes => 'Minutes';

  @override
  String get calendarIngredients => 'Ingredients';

  @override
  String get calendarAddIngredient => 'Add ingredient';

  @override
  String get calendarInstructions => 'Instructions';

  @override
  String get calendarInstructionsHint => 'How to make it';

  @override
  String get calendarEditDinner => 'Edit dinner';

  @override
  String get calendarSetDinner => 'Set dinner';

  @override
  String get calendarIngredientHint => 'e.g. 2 chicken breasts';

  @override
  String get calendarRemoveDinner => 'Remove dinner';

  @override
  String get calendarWhatYouNeed => 'What you need';

  @override
  String get calendarDinnerEmpty => 'No ingredients or instructions added yet.';

  @override
  String calendarServingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servings',
      one: '1 serving',
    );
    return '$_temp0';
  }

  @override
  String calendarMinutesShort(int count) {
    return '$count min';
  }

  @override
  String get cardWalletAddCard => 'Add card';

  @override
  String get cardWalletNoCardsTitle => 'No cards yet';

  @override
  String get cardWalletNoCardsSubtitle =>
      'Add your first loyalty or membership card and it shows up here, ready to scan.';

  @override
  String get cardWalletReadOnlyNotice =>
      'Cards are added on your phone, where the camera and NFC reader are. Turn on Card wallet sync and they show up here to view and present.';

  @override
  String get cardWalletTapToScan => 'Tap to scan';

  @override
  String get cardWalletNoCodeToShow => 'No code to show';

  @override
  String cardWalletValueNotValidFor(String format) {
    return 'This value isn\'t valid for $format.';
  }

  @override
  String get cardWalletEmptyTag => '(empty tag)';

  @override
  String get cardWalletEmulationNote =>
      'Tap-to-scan emulation runs on the luma mobile app. On this device you can copy the tag data or scan the QR above.';

  @override
  String get cardWalletCouldntScan => 'Couldn\'t scan';

  @override
  String get cardWalletReadyToScan => 'Ready to scan';

  @override
  String get cardWalletScanATag => 'Scan a tag';

  @override
  String get cardWalletHoldFlat =>
      'Hold your card flat against the back of your phone and keep it still — larger cards take a second to read.';

  @override
  String cardWalletScanUnexpectedError(String error) {
    return 'Something went wrong while scanning. ($error)';
  }

  @override
  String get cardWalletScanBarcodeTitle => 'Scan a barcode';

  @override
  String get cardWalletScanBarcodeHint =>
      'Point the camera at the card’s barcode or QR code.';

  @override
  String get cardWalletEditCard => 'Edit card';

  @override
  String get cardWalletCategoryOptional => 'Category (optional)';

  @override
  String get cardWalletCategoryHint => 'Loyalty, Membership, Transit…';

  @override
  String get cardWalletNfcTagData => 'NFC tag data';

  @override
  String get cardWalletCardNumberLabel => 'Card number / barcode value';

  @override
  String get cardWalletScanTag => 'Scan tag';

  @override
  String get cardWalletScan => 'Scan';

  @override
  String get cardWalletFromImage => 'From image';

  @override
  String get cardWalletNfcHintScanOrPaste =>
      'Tap “Scan tag”, or paste it (text or hex)';

  @override
  String get cardWalletNfcHintPaste => 'Paste the tag payload (text or hex)';

  @override
  String get cardWalletCodeHintScan =>
      'Scan it in above, or type it — e.g. 2601234567890';

  @override
  String get cardWalletCodeHint => 'e.g. 2601234567890';

  @override
  String get cardWalletNotesOptional => 'Notes (optional)';

  @override
  String get cardWalletNotesHint => 'PIN, member since, anything handy';

  @override
  String get cardWalletNameRequired => 'Give the card a name.';

  @override
  String get cardWalletEnterNfcData => 'Enter the NFC tag data.';

  @override
  String get cardWalletEnterCardNumber =>
      'Enter the card number / barcode value.';

  @override
  String cardWalletCantEncodeAs(String format) {
    return 'This value can\'t be encoded as $format. Pick another format, or turn detection back on.';
  }

  @override
  String cardWalletSaveFailed(String error) {
    return 'Could not save the card. ($error)';
  }

  @override
  String cardWalletScannedTag(String source) {
    return 'Scanned tag ($source)';
  }

  @override
  String get cardWalletSourceTagUid => 'tag UID';

  @override
  String get cardWalletSourceNdef => 'NDEF record';

  @override
  String get cardWalletNoCodeInImage =>
      'No barcode or QR code found in that image.';

  @override
  String cardWalletImageReadFailed(String error) {
    return 'Could not read that image. ($error)';
  }

  @override
  String cardWalletScannedFormat(String format) {
    return 'Scanned $format';
  }

  @override
  String cardWalletDetectionOff(String format) {
    return '$format · detection off';
  }

  @override
  String get cardWalletStatusWaiting =>
      'Scan or type a code and luma picks the format';

  @override
  String cardWalletRecognizedAs(String format) {
    return 'Recognized as $format';
  }

  @override
  String cardWalletNoStandardMatch(String format) {
    return 'No standard match — using $format';
  }

  @override
  String get cardWalletChange => 'Change';

  @override
  String get cardWalletAdvanced => 'Advanced';

  @override
  String get cardWalletAutoDetect => 'Detect the format automatically';

  @override
  String get cardWalletAutoDetectHint =>
      'luma reads the value and picks the matching symbology.';

  @override
  String get cardWalletFormat => 'Format';

  @override
  String get cardWalletFormatNfc => 'NFC tag';

  @override
  String get cardWalletNfcTagReady => 'NFC tag ready';

  @override
  String get cardWalletPreviewHere => 'Preview appears here';

  @override
  String cardWalletNotValidYet(String format) {
    return 'Not valid for $format yet';
  }

  @override
  String get cardWalletDeleteTitle => 'Delete card?';

  @override
  String get cardWalletDeleteBody =>
      'This removes the card from your wallet on this device.';

  @override
  String get cardWalletNfcUnavailable =>
      'NFC scanning isn\'t available on this device.';

  @override
  String get cardWalletNfcOff =>
      'NFC is off or unsupported here. Turn it on in your device settings and try again.';

  @override
  String cardWalletNfcStartFailed(String error) {
    return 'Could not start the NFC reader. ($error)';
  }

  @override
  String get cardWalletNfcNoTag =>
      'No tag detected. Hold the card flat against the back of your phone and try again.';

  @override
  String get cardWalletNfcReadFailed =>
      'Couldn\'t read that tag — it looks empty or unsupported.';

  @override
  String get cardWalletNfcPaymentCardRefused =>
      'That looks like a bank or credit card — luma won\'t copy payment cards for your security. Add a loyalty, hotel, transit or event card instead.';

  @override
  String get cardWalletNfcEmptyTag =>
      'Couldn\'t read anything off that tag — it may be empty or locked.';

  @override
  String get cityPlannerLinuxTitle => 'Not available on Linux';

  @override
  String get cityPlannerLinuxSubtitle =>
      'City Planner requires an embedded WebView that is not yet supported on this platform.';

  @override
  String get cloudFilesSessionExpired =>
      'Your session expired — sign in again under Settings → Sync.';

  @override
  String get cloudFilesSignInFirst => 'Sign in under Settings → Sync first.';

  @override
  String get cloudFilesBusy => 'Another transfer is already running.';

  @override
  String cloudFilesNotEnoughSpace(String name, String needed, String free) {
    return 'Not enough space: \"$name\" needs $needed but only $free is free.';
  }

  @override
  String get cloudFilesServerFull =>
      'The server is out of space for your account.';

  @override
  String get cloudFilesPartMissing =>
      'Part of this file is missing on the server.';

  @override
  String get cloudFilesIndexConflict =>
      'Could not update the file list — please try again.';

  @override
  String cloudFilesSizeB(String value) {
    return '$value B';
  }

  @override
  String cloudFilesSizeKb(String value) {
    return '$value KB';
  }

  @override
  String cloudFilesSizeMb(String value) {
    return '$value MB';
  }

  @override
  String cloudFilesSizeGb(String value) {
    return '$value GB';
  }

  @override
  String get cloudFilesSignedOutTitle => 'Cloud Files needs sync';

  @override
  String get cloudFilesSignedOutBody =>
      'Sign in to your sync server under Settings → Sync & account, then come back here to upload files. Files are encrypted on this device before upload — the server can never read them.';

  @override
  String get cloudFilesHeaderSubtitle =>
      'Encrypted files on your server, on every device.';

  @override
  String get cloudFilesEmptyTitle => 'No files yet';

  @override
  String get cloudFilesEmptySubtitle =>
      'Drop one in to keep it safe everywhere.';

  @override
  String get cloudFilesStorageUsed => 'Storage used';

  @override
  String cloudFilesStorageOf(String used, String quota) {
    return '$used of $quota';
  }

  @override
  String cloudFilesFreeSpace(String size) {
    return '$size free';
  }

  @override
  String cloudFilesSaveDialogTitle(String name) {
    return 'Save $name';
  }

  @override
  String cloudFilesSaved(String name) {
    return 'Saved $name';
  }

  @override
  String get cloudFilesDeleteTitle => 'Delete file?';

  @override
  String cloudFilesDeleteBody(String name, String size) {
    return 'Remove \"$name\" from the server? This frees up $size and cannot be undone.';
  }

  @override
  String cloudFilesUploadingProgress(String name, String pct) {
    return 'Uploading $name… $pct%';
  }

  @override
  String cloudFilesDownloadingProgress(String name, String pct) {
    return 'Downloading $name… $pct%';
  }

  @override
  String get dataChartAggSum => 'Sum';

  @override
  String get dataChartAverage => 'Average';

  @override
  String get dataChartAggCount => 'Count';

  @override
  String get dataChartAggMin => 'Min';

  @override
  String get dataChartAggMax => 'Max';

  @override
  String get dataChartRangeAll => 'All time';

  @override
  String get dataChartRangeLast7 => 'Last 7 days';

  @override
  String get dataChartRangeLast30 => 'Last 30 days';

  @override
  String get dataChartRangeLast90 => 'Last 90 days';

  @override
  String get dataChartRangeThisMonth => 'This month';

  @override
  String get dataChartRangeThisYear => 'This year';

  @override
  String get dataChartRangeCustom => 'Custom…';

  @override
  String get dataChartSortValueDesc => 'Value ↓';

  @override
  String get dataChartSortValueAsc => 'Value ↑';

  @override
  String get dataChartSortLabelAsc => 'Label A-Z';

  @override
  String get dataChartTypeBar => 'Bar';

  @override
  String get dataChartTypeLine => 'Line';

  @override
  String get dataChartTypeArea => 'Area';

  @override
  String get dataChartTypePie => 'Pie';

  @override
  String get dataChartTypeDonut => 'Donut';

  @override
  String get dataChartGroupBy => 'Group by';

  @override
  String get dataChartAggregation => 'Aggregation';

  @override
  String get dataChartValue => 'Value';

  @override
  String get dataChartShow => 'Show';

  @override
  String dataChartTopN(int count) {
    return 'Top $count';
  }

  @override
  String get dataChartDateColumn => 'Date column';

  @override
  String get dataChartPeriod => 'Period';

  @override
  String get dataChartGroupTags => 'Tags';

  @override
  String get dataChartUntagged => 'Untagged';

  @override
  String get dataChartEmptyGroup => '(empty)';

  @override
  String dataChartNeedsNumeric(String aggregation) {
    return 'Add a numeric column to chart values,\nor switch aggregation to \"$aggregation\".';
  }

  @override
  String get dataChartNoMatch => 'No data matches the current filters';

  @override
  String get dataChartSummaryGroups => 'Groups';

  @override
  String get dataChartSummaryTop => 'Top';

  @override
  String dataChartTitle(String aggregation, String value, String group) {
    return '$aggregation of $value by $group';
  }

  @override
  String get dataChartRowsWord => 'rows';

  @override
  String get dataChartTagWord => 'tag';

  @override
  String get dataMgmtTitle => 'Data Management';

  @override
  String get dataMgmtSubtitle =>
      'Create tables, tag entries, and build charts from your own datasets.';

  @override
  String get dataMgmtNewDatasetHint => 'New dataset name...';

  @override
  String get dataMgmtNoDatasetsTitle => 'No datasets yet';

  @override
  String get dataMgmtNoDatasetsSubtitle =>
      'Create a dataset above, or import one from CSV.';

  @override
  String dataMgmtDeleteDatasetTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get dataMgmtDeleteDatasetBody =>
      'This will permanently delete the dataset and all its rows.';

  @override
  String dataMgmtDatasetMeta(int columns, int tags) {
    String _temp0 = intl.Intl.pluralLogic(
      columns,
      locale: localeName,
      other: '$columns columns',
      one: '1 column',
    );
    String _temp1 = intl.Intl.pluralLogic(
      tags,
      locale: localeName,
      other: '$tags tags',
      one: '1 tag',
    );
    String _temp2 = intl.Intl.pluralLogic(
      tags,
      locale: localeName,
      other: '  ·  $_temp1',
      zero: '',
    );
    return '$_temp0$_temp2';
  }

  @override
  String get dataMgmtTabTable => 'Table';

  @override
  String get dataMgmtTabCharts => 'Charts';

  @override
  String get dataMgmtTags => 'Tags';

  @override
  String get dataMgmtImportCsv => 'Import CSV';

  @override
  String get dataMgmtExportCsv => 'Export CSV';

  @override
  String get dataMgmtSaveCsvTitle => 'Save CSV';

  @override
  String get dataMgmtImportedName => 'Imported';

  @override
  String get dataMgmtManageTagsTitle => 'Manage Tags';

  @override
  String get dataMgmtTagsExplainer =>
      'Tags can be attached to any row and used to group charts — e.g. tag income rows by source and see what earns the most.';

  @override
  String get dataMgmtNoTagsYet => 'No tags yet.';

  @override
  String get dataMgmtNewTag => 'New tag';

  @override
  String get dataMgmtNewTagTitle => 'New Tag';

  @override
  String get dataMgmtEditTagTitle => 'Edit Tag';

  @override
  String get dataMgmtTagNameHint => 'Tag name (e.g. Salary, Side gig)';

  @override
  String get dataMgmtNoColumnsTitle => 'No columns yet';

  @override
  String get dataMgmtNoColumnsSubtitle =>
      'Add a column to start building your table.';

  @override
  String get dataMgmtAddColumn => 'Add Column';

  @override
  String get dataMgmtEditColumnTitle => 'Edit Column';

  @override
  String get dataMgmtColumnNameHint => 'Column name';

  @override
  String get dataMgmtColumnTypeLabel => 'Type:';

  @override
  String get dataMgmtTypeText => 'Text';

  @override
  String get dataMgmtTypeNumber => 'Number';

  @override
  String get dataMgmtAddRow => 'Add Row';

  @override
  String get dataMgmtSearchRowsHint => 'Search rows...';

  @override
  String dataMgmtRowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows',
      one: '1 row',
    );
    return '$_temp0';
  }

  @override
  String dataMgmtRowCountFiltered(int shown, int total) {
    return '$shown of $total rows';
  }

  @override
  String get dataMgmtClearFilter => 'Clear filter';

  @override
  String dataMgmtStatsSub(String avg, String max) {
    return 'avg $avg  ·  max $max';
  }

  @override
  String get dataMgmtDuplicateRow => 'Duplicate row';

  @override
  String get dataMgmtEditTags => 'Edit tags';

  @override
  String get dataMgmtCreateTags => 'Create tags…';

  @override
  String get dataMgmtManageTags => 'Manage tags…';

  @override
  String get deviceHealthWindowsOnlyTitle => 'Device Health is Windows only';

  @override
  String get deviceHealthWindowsOnlySubtitle =>
      'CPU, driver and Defender data come from Windows-only APIs, so this plugin only runs there for now.';

  @override
  String get deviceHealthReadingStatus => 'Reading system status…';

  @override
  String deviceHealthChecksRun(int checked, int total) {
    return '$checked of $total checks run';
  }

  @override
  String get deviceHealthChecking => 'Checking…';

  @override
  String get deviceHealthCheckEverything => 'Check everything';

  @override
  String get deviceHealthWhatNeedsAttention => 'What needs attention';

  @override
  String get deviceHealthErrReadStatus => 'Could not read system status.';

  @override
  String get deviceHealthErrCpuRamUnavailable => 'CPU/RAM reading unavailable.';

  @override
  String get deviceHealthErrDefenderUnavailable =>
      'Couldn\'t read Windows Defender\'s status — another antivirus may be active, or the Defender service is disabled.';

  @override
  String get deviceHealthErrListProcesses => 'Could not list processes.';

  @override
  String get deviceHealthErrWingetMissing =>
      'winget is not available on this system.';

  @override
  String get deviceHealthNeedsManualUpdate =>
      'Needs a manual update — winget could not finish silently.';

  @override
  String deviceHealthIssueRamHigh(int percent) {
    return 'RAM usage is very high ($percent%).';
  }

  @override
  String deviceHealthIssueCpuHigh(int percent) {
    return 'CPU usage is very high ($percent%).';
  }

  @override
  String deviceHealthIssueBatteryDegraded(int percent) {
    return 'Battery health is significantly degraded ($percent% capacity lost).';
  }

  @override
  String deviceHealthIssueBatteryFading(int percent) {
    return 'Battery health is fading ($percent% capacity lost).';
  }

  @override
  String get deviceHealthIssueDefenderOff =>
      'Windows Defender protection is off.';

  @override
  String get deviceHealthIssueDefinitionsOld =>
      'Antivirus definitions are out of date.';

  @override
  String get deviceHealthIssueNoScan => 'No virus scan in the last 30 days.';

  @override
  String deviceHealthIssueBloatware(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count background apps commonly flagged as unnecessary.',
      one: '1 background app commonly flagged as unnecessary.',
    );
    return '$_temp0';
  }

  @override
  String deviceHealthIssueAppUpdates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count app updates available.',
      one: '1 app update available.',
    );
    return '$_temp0';
  }

  @override
  String get deviceHealthCardAppUpdatesTitle => 'App Updates';

  @override
  String get deviceHealthCardRescan => 'Rescan';

  @override
  String get deviceHealthCardScanForUpdates => 'Scan for updates';

  @override
  String get deviceHealthCardAppUpdatesNotScanned =>
      'Not scanned yet — checks winget and luma for available updates.';

  @override
  String deviceHealthCardUpdateAll(int count) {
    return 'Update all ($count)';
  }

  @override
  String deviceHealthCardUpdateSourceMayPrompt(String source) {
    return '$source, may prompt';
  }

  @override
  String get deviceHealthCardUpdateFailedHint =>
      'Couldn\'t update automatically — try updating it yourself.';

  @override
  String get deviceHealthCardAppsUpToDate =>
      'Everything luma checked is up to date.';

  @override
  String get deviceHealthCardBatteryTitle => 'Battery';

  @override
  String get deviceHealthCardNotCheckedYet => 'Not checked yet.';

  @override
  String get deviceHealthCardNoBattery =>
      'No battery detected — this looks like a desktop.';

  @override
  String deviceHealthCardBatteryHealth(int percent) {
    return 'Battery health: $percent% of design capacity remains.';
  }

  @override
  String get deviceHealthCardBatteryNoWearData =>
      'This battery doesn\'t report design/full-charge capacity, so wear can\'t be estimated.';

  @override
  String get deviceHealthBatteryDischarging => 'Discharging';

  @override
  String get deviceHealthBatteryOnAc => 'On AC power';

  @override
  String get deviceHealthBatteryFullyCharged => 'Fully charged';

  @override
  String get deviceHealthBatteryLow => 'Low';

  @override
  String get deviceHealthBatteryCritical => 'Critical';

  @override
  String get deviceHealthBatteryCharging => 'Charging';

  @override
  String get deviceHealthBatteryPartiallyCharged => 'Partially charged';

  @override
  String get deviceHealthGpuUnknownName => 'Unknown GPU';

  @override
  String get deviceHealthCardCpuRamTitle => 'CPU & RAM';

  @override
  String get deviceHealthCardDefenderTitle => 'Virus & Threat Protection';

  @override
  String get deviceHealthCardRealTimeOn => 'Real-time protection is on.';

  @override
  String get deviceHealthCardRealTimeOff => 'Real-time protection is OFF.';

  @override
  String deviceHealthCardDefenderSummary(String definitions, String lastScan) {
    return 'Definitions: $definitions · Last scan: $lastScan';
  }

  @override
  String get deviceHealthCardRelativeNever => 'never';

  @override
  String get deviceHealthCardRelativeToday => 'today';

  @override
  String get deviceHealthCardRelativeYesterday => 'yesterday';

  @override
  String deviceHealthCardRelativeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get deviceHealthCardRunQuickScan => 'Run quick scan';

  @override
  String get deviceHealthCardOpenWindowsSecurity => 'Open Windows Security';

  @override
  String get deviceHealthCardGpuTitle => 'GPU & Drivers';

  @override
  String deviceHealthCardDriverVersion(String version) {
    return 'Driver $version';
  }

  @override
  String deviceHealthCardDriverVersionDate(String version, String date) {
    return 'Driver $version · $date';
  }

  @override
  String deviceHealthCardOpenVendorTool(String vendor) {
    return 'Open $vendor update tool';
  }

  @override
  String get deviceHealthCardOpenWindowsUpdate => 'Open Windows Update';

  @override
  String get deviceHealthCardGpuDisclaimer =>
      'Windows doesn\'t expose a way to check driver freshness directly — these open the tool that actually knows. Nothing is installed automatically.';

  @override
  String get deviceHealthCardProcessesTitle => 'Background Processes';

  @override
  String get deviceHealthCardScanProcesses => 'Scan processes';

  @override
  String get deviceHealthCardProcessesNotScanned =>
      'Not scanned yet — this reads every running process, so it isn\'t run automatically.';

  @override
  String deviceHealthCardProcessesSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count processes · sorted by memory',
      one: '1 process · sorted by memory',
    );
    return '$_temp0';
  }

  @override
  String deviceHealthCardSuggested(String label) {
    return 'Suggested: $label';
  }

  @override
  String get deviceHealthCardEndProcess => 'End process';

  @override
  String deviceHealthCardEndProcessTitle(String name) {
    return 'End $name?';
  }

  @override
  String get deviceHealthCardEndProcessClosesNow =>
      'This closes the process immediately. Unsaved work in it will be lost.';

  @override
  String deviceHealthCardEndProcessWithReason(String reason) {
    return '$reason Unsaved work in this process will be lost.';
  }

  @override
  String get deviceHealthStatusGood => 'Good';

  @override
  String get deviceHealthStatusWarning => 'Needs attention';

  @override
  String get deviceHealthStatusBad => 'Poor';

  @override
  String get deviceHealthStatusNotChecked => 'Not checked';

  @override
  String get deviceHealthCardCheck => 'Check';

  @override
  String get errandsEmptyTitle => 'No errands yet';

  @override
  String get errandsEmptySubtitle =>
      'Add a recurring errand — daily, weekly, monthly or every few days — and it shows up on your checklist the day it\'s due.';

  @override
  String get errandsAddErrand => 'Add errand';

  @override
  String get errandsAllDoneToday => 'All done for today — nice work.';

  @override
  String get errandsNothingDueToday =>
      'Nothing due today. Your next errands are listed under Coming up.';

  @override
  String get errandsComingUp => 'Coming up';

  @override
  String get errandsDoneToday => 'Done today';

  @override
  String get errandsTodayTitle => 'Today\'s errands';

  @override
  String errandsDoneOfTotal(int done, int total) {
    return '$done of $total done';
  }

  @override
  String get errandsCategories => 'Categories';

  @override
  String get errandsNewCategory => 'New category';

  @override
  String get errandsEditCategoryTitle => 'Edit category';

  @override
  String errandsDaysLate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days late',
      one: '1 day late',
    );
    return '$_temp0';
  }

  @override
  String get errandsDelay => 'Delay';

  @override
  String get errandsDelayByDaysTitle => 'Delay by how many days?';

  @override
  String errandsInDays(int count) {
    return 'In $count days';
  }

  @override
  String get errandsInAWeek => 'In a week';

  @override
  String get errandsCustom => 'Custom…';

  @override
  String get errandsCustomDaysHint => 'e.g. 5';

  @override
  String get errandsRepeatDaily => 'Daily';

  @override
  String get errandsRepeatWeekly => 'Weekly';

  @override
  String get errandsRepeatMonthly => 'Monthly';

  @override
  String get errandsRepeatCustom => 'Custom';

  @override
  String errandsRepeatEveryDays(int count) {
    return 'Every $count days';
  }

  @override
  String errandsRepeatEveryWeeks(int count) {
    return 'Every $count weeks';
  }

  @override
  String errandsRepeatEveryMonths(int count) {
    return 'Every $count months';
  }

  @override
  String get errandsEditTitle => 'Edit errand';

  @override
  String get errandsNameRequired => 'Give the errand a name.';

  @override
  String get errandsIntervalInvalid =>
      'Enter a repeat interval between 1 and 365 days.';

  @override
  String errandsSaveFailed(String error) {
    return 'Could not save the errand. ($error)';
  }

  @override
  String get errandsNameHint => 'Water the plants';

  @override
  String get errandsRepeats => 'Repeats';

  @override
  String get errandsEvery => 'Every';

  @override
  String get errandsDays => 'days';

  @override
  String get errandsNextDue => 'Next due';

  @override
  String get errandsFirstDue => 'First due';

  @override
  String get errandsNotesOptional => 'Notes (optional)';

  @override
  String get errandsNotesHint => 'Which plants, which store, anything handy';

  @override
  String get errandsNoCategory => 'No category';

  @override
  String get errandsNoCategoriesYet => 'No categories yet.';

  @override
  String get errandsCategoriesHelp =>
      'Group your checklist however you like — Household, Health, Admin… Deleting a category keeps its errands.';

  @override
  String get errandsCategoryNameHint => 'Household';

  @override
  String get errandsCategoryNameRequired => 'Give the category a name.';

  @override
  String get errandsDeleteTitle => 'Delete errand?';

  @override
  String get errandsDeleteBody =>
      'This removes the errand and its schedule from this device.';

  @override
  String get errandsDeleteCategoryTitle => 'Delete category?';

  @override
  String get errandsDeleteCategoryBody =>
      'Errands in this category are kept and become uncategorized.';

  @override
  String get errandsDueTomorrow => 'Due tomorrow';

  @override
  String errandsDueInDays(int count) {
    return 'Due in $count days';
  }

  @override
  String errandsDueOn(String date) {
    return 'Due $date';
  }

  @override
  String get fileTreePickFolderTitle => 'Choose a folder or drive to scan';

  @override
  String get fileTreeNothingScanned => 'Nothing scanned yet';

  @override
  String get fileTreeNothingScannedHint =>
      'Pick a drive or folder above and luma will map out what\'s using the space.';

  @override
  String get fileTreeFolderEmpty => 'This folder is empty';

  @override
  String get fileTreeFolderEmptyHint =>
      'No files were found, or they couldn\'t be read.';

  @override
  String get fileTreeDiskUsage => 'Disk usage';

  @override
  String get fileTreeDiskUsageHint =>
      'See exactly what\'s filling up your drive.';

  @override
  String get fileTreeRescan => 'Rescan';

  @override
  String get fileTreeTotalSize => 'Total size';

  @override
  String get fileTreeFiles => 'Files';

  @override
  String get fileTreeFolders => 'Folders';

  @override
  String get fileTreeList => 'List';

  @override
  String get fileTreeDetailed => 'Detailed';

  @override
  String get fileTreeDrives => 'Drives';

  @override
  String get fileTreeMapping => 'Mapping your files…';

  @override
  String get fileTreeProgressAtBottom => 'Progress is shown at the bottom.';

  @override
  String get fileTreeIndexing => 'Indexing files…';

  @override
  String get fileTreeMeasuring => 'Measuring sizes…';

  @override
  String fileTreeItemsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items found',
      one: '1 item found',
    );
    return '$_temp0';
  }

  @override
  String fileTreeItemsProgress(String done, String total) {
    return '$done / $total items';
  }

  @override
  String fileTreeBytesScanned(String size) {
    return '$size scanned';
  }

  @override
  String get fileTreeCancelScan => 'Cancel scan';

  @override
  String get fileTreeNoFilesHere => 'No files to map in this folder.';

  @override
  String fileTreeOtherItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count other items',
      one: '1 other item',
    );
    return '($_temp0)';
  }

  @override
  String get fileViewerCouldNotReadFile => 'Could not read the selected file.';

  @override
  String fileViewerCouldNotOpen(String error) {
    return 'Could not open this file: $error';
  }

  @override
  String fileViewerOpenExternallyFailed(String message) {
    return 'Could not open externally: $message';
  }

  @override
  String get fileViewerTapToPick => 'Tap to pick a file';

  @override
  String get fileViewerFormatsHint =>
      'PDF · DOCX · XLSX · images · SVG · text & code';

  @override
  String get fileViewerOpenExternally => 'Open externally';

  @override
  String get fileViewerNoPreview => 'No preview for this file type';

  @override
  String get fileViewerOpenExternallyHint =>
      'Use \"Open externally\" to view it in its default app.';

  @override
  String get fileViewerCannotPreview =>
      'This file type can\'t be previewed here.';

  @override
  String get fileViewerUnknownExtension => 'FILE';

  @override
  String fileViewerPageOf(int page, int total) {
    return 'Page $page of $total';
  }

  @override
  String get fileViewerNoPageText => 'No text on this page';

  @override
  String get fileViewerNoPageTextHint =>
      'This page has no extractable text — it may be a scan or an image.';

  @override
  String get fileViewerNoReadableText => 'This document has no readable text';

  @override
  String get fileViewerEmptyWorksheet => 'This worksheet is empty';

  @override
  String fileViewerShowingRows(int shown, int total) {
    return 'Showing the first $shown of $total rows.';
  }

  @override
  String get fileViewerLargeFile => 'Large file — showing the first 500 KB.';

  @override
  String get fileViewerNotWordDocument =>
      'This file does not look like a Word document.';

  @override
  String get fileViewerNoDocumentBody => 'Could not find the document body.';

  @override
  String get fileViewerNoWorksheets => 'This workbook has no worksheets.';

  @override
  String freeSketchImageCouldNotOpen(String error) {
    return 'That image could not be opened: $error';
  }

  @override
  String freeSketchArtworkCouldNotOpen(String error) {
    return 'That artwork could not be opened: $error';
  }

  @override
  String get freeSketchRenameArtwork => 'Rename artwork';

  @override
  String freeSketchDeleteConfirm(String title) {
    return 'Delete \"$title\"?';
  }

  @override
  String freeSketchDeleteBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count layers',
      one: '1 layer',
    );
    return 'All $_temp0 will be removed from this device for good. Export it first if you want to keep a copy.';
  }

  @override
  String get freeSketchGallery => 'Gallery';

  @override
  String get freeSketchGallerySubtitle =>
      'Every artwork is saved on this device as you paint.';

  @override
  String get freeSketchImportImage => 'Import image';

  @override
  String get freeSketchNew => 'New';

  @override
  String get freeSketchNewArtwork => 'New artwork';

  @override
  String get freeSketchCouldNotReadGallery => 'The gallery could not be read';

  @override
  String get freeSketchGalleryEmpty => 'Your gallery is empty';

  @override
  String get freeSketchGalleryEmptyHint =>
      'Start a new artwork — pencils, inks, watercolours, markers, airbrushes and blenders, with layers, blend modes, symmetry and pressure. Export to PNG, JPEG, Photoshop or OpenRaster.';

  @override
  String freeSketchArtworkInfo(String size, int count, String updated) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count layers',
      one: '1 layer',
    );
    return '$size · $_temp0 · $updated';
  }

  @override
  String get freeSketchArtworkActions => 'Artwork actions';

  @override
  String get freeSketchDuplicate => 'Duplicate';

  @override
  String get freeSketchUntitledArtwork => 'Untitled artwork';

  @override
  String get freeSketchCanvas => 'Canvas';

  @override
  String get freeSketchBackground => 'Background';

  @override
  String get freeSketchTransparent => 'Transparent';

  @override
  String get freeSketchSwapSize => 'Swap width and height';

  @override
  String get freeSketchWidthPx => 'Width (px)';

  @override
  String get freeSketchHeightPx => 'Height (px)';

  @override
  String freeSketchCanvasMemory(String megabytes, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count layers',
      one: '1 layer',
    );
    return '$megabytes MB per layer · up to $_temp0';
  }

  @override
  String get freeSketchFirstLayerName => 'Layer 1';

  @override
  String get freeSketchSymmetryOff => 'Off';

  @override
  String get freeSketchSymmetryVertical => 'Vertical';

  @override
  String get freeSketchSymmetryHorizontal => 'Horizontal';

  @override
  String get freeSketchSymmetryQuadrant => 'Quadrant';

  @override
  String get freeSketchSymmetryRadial => 'Radial';

  @override
  String get freeSketchAdjHueSaturation => 'Hue / saturation';

  @override
  String get freeSketchAdjBrightnessContrast => 'Brightness / contrast';

  @override
  String get freeSketchAdjColorBalance => 'Color balance';

  @override
  String get freeSketchAdjBlur => 'Gaussian blur';

  @override
  String get freeSketchAdjInvert => 'Invert';

  @override
  String get freeSketchAdjDesaturate => 'Black & white';

  @override
  String get freeSketchAdjParamHue => 'Hue';

  @override
  String get freeSketchAdjParamSaturation => 'Saturation';

  @override
  String get freeSketchAdjParamLightness => 'Lightness';

  @override
  String get freeSketchAdjParamBrightness => 'Brightness';

  @override
  String get freeSketchAdjParamContrast => 'Contrast';

  @override
  String get freeSketchAdjParamCyanRed => 'Cyan ↔ Red';

  @override
  String get freeSketchAdjParamMagentaGreen => 'Magenta ↔ Green';

  @override
  String get freeSketchAdjParamYellowBlue => 'Yellow ↔ Blue';

  @override
  String get freeSketchAdjParamRadius => 'Radius';

  @override
  String get freeSketchBrushPencilHb => 'HB Pencil';

  @override
  String get freeSketchBrushPencil6b => '6B Pencil';

  @override
  String get freeSketchBrushMechanical => 'Mechanical pencil';

  @override
  String get freeSketchBrushCharcoal => 'Charcoal';

  @override
  String get freeSketchBrushPastel => 'Soft pastel';

  @override
  String get freeSketchBrushCrayon => 'Wax crayon';

  @override
  String get freeSketchBrushStudioPen => 'Studio pen';

  @override
  String get freeSketchBrushFineliner => 'Fineliner';

  @override
  String get freeSketchBrushBrushPen => 'Brush pen';

  @override
  String get freeSketchBrushCalligraphy => 'Calligraphy nib';

  @override
  String get freeSketchBrushTechnical => 'Technical pen';

  @override
  String get freeSketchBrushDryInk => 'Dry ink';

  @override
  String get freeSketchBrushRoundHard => 'Hard round';

  @override
  String get freeSketchBrushRoundSoft => 'Soft round';

  @override
  String get freeSketchBrushOil => 'Oil paint';

  @override
  String get freeSketchBrushGouache => 'Gouache';

  @override
  String get freeSketchBrushFlatAcrylic => 'Flat acrylic';

  @override
  String get freeSketchBrushPaletteKnife => 'Palette knife';

  @override
  String get freeSketchBrushWcWash => 'Watercolor wash';

  @override
  String get freeSketchBrushWcRound => 'Round watercolor';

  @override
  String get freeSketchBrushWcBleed => 'Wet bleed';

  @override
  String get freeSketchBrushWcSpatter => 'Spatter';

  @override
  String get freeSketchBrushMarker => 'Alcohol marker';

  @override
  String get freeSketchBrushHighlighter => 'Highlighter';

  @override
  String get freeSketchBrushFeltTip => 'Felt tip';

  @override
  String get freeSketchBrushAirbrush => 'Airbrush';

  @override
  String get freeSketchBrushFineAirbrush => 'Fine airbrush';

  @override
  String get freeSketchBrushSpray => 'Spray paint';

  @override
  String get freeSketchBrushSplatter => 'Splatter';

  @override
  String get freeSketchBrushSparkle => 'Sparkle';

  @override
  String get freeSketchBrushGlow => 'Glow';

  @override
  String get freeSketchBrushFoliage => 'Foliage';

  @override
  String get freeSketchBrushStipple => 'Stipple';

  @override
  String get freeSketchBrushBlendSoft => 'Soft blender';

  @override
  String get freeSketchBrushSmudge => 'Smudge';

  @override
  String get freeSketchBrushBlendBristle => 'Bristle blender';

  @override
  String get freeSketchBrushBlur => 'Blur';

  @override
  String get freeSketchCategorySketching => 'Sketching';

  @override
  String get freeSketchCategoryInking => 'Inking';

  @override
  String get freeSketchCategoryPainting => 'Painting';

  @override
  String get freeSketchCategoryWatercolor => 'Watercolor';

  @override
  String get freeSketchCategoryMarkers => 'Markers';

  @override
  String get freeSketchCategoryAirbrush => 'Airbrush';

  @override
  String get freeSketchCategoryTexture => 'Texture & effects';

  @override
  String get freeSketchCategoryBlending => 'Blending';

  @override
  String get freeSketchParamOpacity => 'Opacity';

  @override
  String get freeSketchParamFlow => 'Flow';

  @override
  String get freeSketchParamHardness => 'Hardness';

  @override
  String get freeSketchParamSpacing => 'Spacing';

  @override
  String get freeSketchParamStreamline => 'StreamLine';

  @override
  String get freeSketchParamSizePressure => 'Pressure → size';

  @override
  String get freeSketchParamFlowPressure => 'Pressure → opacity';

  @override
  String get freeSketchParamTaperStart => 'Taper start';

  @override
  String get freeSketchParamTaperEnd => 'Taper end';

  @override
  String get freeSketchParamSizeJitter => 'Size jitter';

  @override
  String get freeSketchParamAngleJitter => 'Rotation jitter';

  @override
  String get freeSketchParamScatter => 'Scatter';

  @override
  String get freeSketchParamRoundness => 'Roundness';

  @override
  String get freeSketchParamAngle => 'Angle';

  @override
  String get freeSketchParamGrain => 'Grain';

  @override
  String get freeSketchParamWetEdges => 'Wet edges';

  @override
  String get freeSketchParamColorJitter => 'Colour jitter';

  @override
  String get freeSketchParamStrength => 'Strength';

  @override
  String get freeSketchGrainNone => 'None';

  @override
  String get freeSketchGrainPaper => 'Paper';

  @override
  String get freeSketchGrainCanvas => 'Canvas';

  @override
  String get freeSketchGrainRough => 'Rough';

  @override
  String get freeSketchEnginePaints => 'Paints';

  @override
  String get freeSketchEngineSmudges => 'Smudges the colour under it';

  @override
  String get freeSketchEngineBlurs => 'Blurs what is under it';

  @override
  String get freeSketchTraitGlazes => 'glazes like a marker — overlaps darken';

  @override
  String get freeSketchTraitAddsLight => 'adds light';

  @override
  String freeSketchTraitGrain(String grain) {
    return 'with $grain grain';
  }

  @override
  String get freeSketchTraitBuildsUp => 'builds up while you hold still';

  @override
  String get freeSketchListSeparator => ', ';

  @override
  String freeSketchBrushDescription(
    String engine,
    String traits,
    String pressure,
  ) {
    return '$engine$traits. $pressure';
  }

  @override
  String get freeSketchPressureSizeAndOpacity =>
      'Pressure changes size and opacity.';

  @override
  String get freeSketchPressureSize => 'Pressure changes size.';

  @override
  String get freeSketchPressureOpacity => 'Pressure changes opacity.';

  @override
  String get freeSketchPressureNothing => 'Pressure changes nothing.';

  @override
  String get freeSketchBlendNormal => 'Normal';

  @override
  String get freeSketchBlendMultiply => 'Multiply';

  @override
  String get freeSketchBlendColorBurn => 'Color burn';

  @override
  String get freeSketchBlendDarken => 'Darken';

  @override
  String get freeSketchBlendScreen => 'Screen';

  @override
  String get freeSketchBlendColorDodge => 'Color dodge';

  @override
  String get freeSketchBlendLighten => 'Lighten';

  @override
  String get freeSketchBlendAdd => 'Add';

  @override
  String get freeSketchBlendOverlay => 'Overlay';

  @override
  String get freeSketchBlendSoftLight => 'Soft light';

  @override
  String get freeSketchBlendHardLight => 'Hard light';

  @override
  String get freeSketchBlendDifference => 'Difference';

  @override
  String get freeSketchBlendExclusion => 'Exclusion';

  @override
  String get freeSketchBlendHue => 'Hue';

  @override
  String get freeSketchBlendSaturation => 'Saturation';

  @override
  String get freeSketchBlendColor => 'Color';

  @override
  String get freeSketchBlendLuminosity => 'Luminosity';

  @override
  String get freeSketchToolBrush => 'Brush';

  @override
  String get freeSketchToolEraser => 'Eraser';

  @override
  String get freeSketchToolSmudge => 'Smudge';

  @override
  String get freeSketchToolFill => 'Fill';

  @override
  String get freeSketchToolGradient => 'Gradient';

  @override
  String get freeSketchToolShapes => 'Shapes';

  @override
  String get freeSketchToolSelection => 'Selection';

  @override
  String get freeSketchToolTransform => 'Transform';

  @override
  String get freeSketchToolEyedropper => 'Eyedropper';

  @override
  String get freeSketchShapeLine => 'Line';

  @override
  String get freeSketchShapeRectangle => 'Rectangle';

  @override
  String get freeSketchShapeEllipse => 'Ellipse';

  @override
  String get freeSketchShapePolygon => 'Polygon';

  @override
  String get freeSketchSelectionLasso => 'Lasso';

  @override
  String get freeSketchSelectionCombineNew => 'New';

  @override
  String get freeSketchSelectionCombineAdd => 'Add';

  @override
  String get freeSketchSelectionCombineSubtract => 'Subtract';

  @override
  String get freeSketchPresetScreen => 'Screen';

  @override
  String get freeSketchPresetSquare => 'Square';

  @override
  String get freeSketchPresetPortrait => 'Portrait';

  @override
  String get freeSketchPresetA4Draft => 'A4 draft';

  @override
  String get freeSketchPresetComicPage => 'Comic page';

  @override
  String get freeSketchPresetPhoneWallpaper => 'Phone wallpaper';

  @override
  String get freeSketchExportPngNote => 'Flattened, keeps transparency';

  @override
  String get freeSketchExportJpegNote => 'Flattened, smallest file';

  @override
  String get freeSketchExportPsdNote => 'Every layer, blend mode and mask';

  @override
  String get freeSketchExportOraNote => 'Layers for Krita, GIMP and MyPaint';

  @override
  String freeSketchExportDialogTitle(String format) {
    return 'Export $format';
  }

  @override
  String get freeSketchEncodeFailed => 'The image could not be encoded.';

  @override
  String get freeSketchPixelsReadFailed =>
      'The image pixels could not be read.';

  @override
  String freeSketchLayerNumber(int number) {
    return 'Layer $number';
  }

  @override
  String freeSketchCopyTitle(String title) {
    return '$title copy';
  }

  @override
  String get freeSketchNoCanvasSize => 'Document has no canvas size.';

  @override
  String get freeSketchBrushesTitle => 'Brushes';

  @override
  String freeSketchBrushesForTool(String tool) {
    return '$tool brushes';
  }

  @override
  String get freeSketchBrushLibrary => 'Library';

  @override
  String get freeSketchBrushSettings => 'Settings';

  @override
  String get freeSketchBrushCustomised => 'Customised';

  @override
  String get freeSketchInvalidSnapshot => 'Invalid sketch snapshot.';

  @override
  String get freeSketchFallbackLayerName => 'Layer';

  @override
  String get freeSketchColourTitle => 'Colour';

  @override
  String get freeSketchColourTabWheel => 'Wheel';

  @override
  String get freeSketchColourTabSliders => 'Sliders';

  @override
  String get freeSketchColourTabPalettes => 'Palettes';

  @override
  String get freeSketchColourSwapTooltip => 'Swap with secondary colour (X)';

  @override
  String get freeSketchColourSecondaryTooltip => 'Secondary colour';

  @override
  String get freeSketchColourRecent => 'Recent';

  @override
  String get freeSketchColourPairTooltip =>
      'Left: new colour · right: tap to go back to the colour you started with';

  @override
  String get freeSketchChannelHue => 'H';

  @override
  String get freeSketchChannelSaturation => 'S';

  @override
  String get freeSketchChannelBrightness => 'B';

  @override
  String get freeSketchChannelRed => 'R';

  @override
  String get freeSketchChannelGreen => 'G';

  @override
  String get freeSketchChannelBlue => 'B';

  @override
  String get freeSketchPaletteBasics => 'Basics';

  @override
  String get freeSketchPaletteSkinTones => 'Skin tones';

  @override
  String get freeSketchPaletteNature => 'Nature';

  @override
  String get freeSketchPalettePastel => 'Pastel';

  @override
  String get freeSketchPaletteGreys => 'Greys';

  @override
  String get freeSketchColourRemoveHint =>
      'Long-press or right-click to remove';

  @override
  String get freeSketchColourMyPalette => 'My palette';

  @override
  String get freeSketchColourAdd => 'Add colour';

  @override
  String get freeSketchColourPaletteEmpty => 'Save colours you reuse here.';

  @override
  String get freeSketchLayersShowPanel => 'Show layer panel';

  @override
  String get freeSketchLayerNew => 'New layer';

  @override
  String get freeSketchLayerRename => 'Rename layer';

  @override
  String get freeSketchLayerNewShortcut => 'New layer (Ctrl+Shift+N)';

  @override
  String get freeSketchLayersTitle => 'Layers';

  @override
  String get freeSketchLayersCollapse => 'Collapse';

  @override
  String get freeSketchLayerAlphaLockShort => 'α lock';

  @override
  String get freeSketchLayerHide => 'Hide layer';

  @override
  String get freeSketchLayerShow => 'Show layer';

  @override
  String get freeSketchBackgroundColour => 'Background colour';

  @override
  String get freeSketchBackgroundUseCurrent => 'Use current colour';

  @override
  String get freeSketchBackgroundWhite => 'White';

  @override
  String get freeSketchBackgroundPaper => 'Warm paper';

  @override
  String get freeSketchBackgroundCharcoal => 'Charcoal';

  @override
  String get freeSketchBackgroundTransparent => 'Background (transparent)';

  @override
  String get freeSketchBackgroundTransparentTip => 'Transparent background';

  @override
  String get freeSketchBackgroundShow => 'Show background';

  @override
  String get freeSketchBlend => 'Blend';

  @override
  String get freeSketchBlendMode => 'Blend mode';

  @override
  String get freeSketchLayerOpacity => 'Opacity';

  @override
  String get freeSketchLayerLock => 'Lock';

  @override
  String get freeSketchLayerLockLayer => 'Lock layer';

  @override
  String get freeSketchLayerAlphaLock => 'Alpha lock';

  @override
  String get freeSketchLayerClip => 'Clip';

  @override
  String get freeSketchLayerClipMask => 'Clipping mask';

  @override
  String get freeSketchLayerActions => 'Layer actions';

  @override
  String get freeSketchLayerRenameMenu => 'Rename…';

  @override
  String get freeSketchLayerDuplicateShortcut => 'Duplicate (Ctrl+J)';

  @override
  String get freeSketchLayerMergeDownShortcut => 'Merge down (Ctrl+E)';

  @override
  String get freeSketchLayerFlattenAll => 'Flatten all';

  @override
  String get freeSketchCopyShortcut => 'Copy (Ctrl+C)';

  @override
  String get freeSketchPasteAsNewLayerShortcut => 'Paste as new layer (Ctrl+V)';

  @override
  String get freeSketchLayerFillColour => 'Fill with colour';

  @override
  String get freeSketchLayerClearShortcut => 'Clear (Delete)';

  @override
  String get freeSketchLayerDelete => 'Delete layer';

  @override
  String get freeSketchToolPaintInSelection => 'Painting inside selection';

  @override
  String get freeSketchDeselect => 'Deselect';

  @override
  String get freeSketchFillTolerance => 'Tolerance';

  @override
  String get freeSketchAllLayers => 'All layers';

  @override
  String get freeSketchThisLayer => 'This layer';

  @override
  String get freeSketchFillGrow => 'Grow';

  @override
  String get freeSketchFillShrinkTip => 'Shrink fill edge';

  @override
  String get freeSketchFillGrowTip => 'Grow fill edge under line art';

  @override
  String get freeSketchGradientLinear => 'Linear';

  @override
  String get freeSketchGradientRadial => 'Radial';

  @override
  String get freeSketchGradientToTransparent => 'To transparent';

  @override
  String get freeSketchGradientToSecondary => 'To secondary';

  @override
  String get freeSketchGradientDragHint => 'Drag across the canvas';

  @override
  String get freeSketchPolygonFewerSides => 'Fewer sides';

  @override
  String get freeSketchPolygonMoreSides => 'More sides';

  @override
  String freeSketchPolygonSides(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sides',
      one: '1 side',
    );
    return '$_temp0';
  }

  @override
  String get freeSketchShapeStroke => 'Stroke';

  @override
  String get freeSketchShapeFill => 'Fill';

  @override
  String get freeSketchShapeShiftHint => 'Shift keeps it straight/square';

  @override
  String freeSketchSelectionCombineTip(String mode) {
    return '$mode selection';
  }

  @override
  String get freeSketchSelectAll => 'All';

  @override
  String get freeSketchSelectInvert => 'Invert';

  @override
  String get freeSketchCutShortcut => 'Cut (Ctrl+X)';

  @override
  String get freeSketchClearSelectionShortcut => 'Clear selection (Delete)';

  @override
  String get freeSketchTransformSelectLayerHint =>
      'Select a layer with something on it';

  @override
  String get freeSketchTransformFlipH => 'Flip horizontally';

  @override
  String get freeSketchTransformFlipV => 'Flip vertically';

  @override
  String get freeSketchTransformRotate90 => 'Rotate 90°';

  @override
  String get freeSketchTransformUniformScale =>
      'Uniform scale (Shift for free)';

  @override
  String get freeSketchTransformFreeScale => 'Free scale (Shift for uniform)';

  @override
  String get freeSketchEyedropperTip =>
      'Tip: hold Alt with any tool to pick a colour';

  @override
  String freeSketchStudioDefaultLayerName(int n) {
    return 'Layer $n';
  }

  @override
  String freeSketchLayerLocked(String name) {
    return '“$name” is locked.';
  }

  @override
  String freeSketchLayerHidden(String name) {
    return '“$name” is hidden — show it to paint on it.';
  }

  @override
  String get freeSketchStrokeModeErase => 'Erase';

  @override
  String get freeSketchStrokeModeSmudge => 'Smudge';

  @override
  String get freeSketchStrokeModeBlur => 'Blur';

  @override
  String get freeSketchUndoGradient => 'Gradient';

  @override
  String get freeSketchUndoSelect => 'Select';

  @override
  String get freeSketchUndoSelectAll => 'Select all';

  @override
  String get freeSketchUndoInvertSelection => 'Invert selection';

  @override
  String get freeSketchNothingToCopy => 'Nothing to copy on this layer.';

  @override
  String get freeSketchLayerCopied => 'Layer copied.';

  @override
  String get freeSketchSelectionCopied => 'Selection copied.';

  @override
  String get freeSketchUndoCut => 'Cut';

  @override
  String get freeSketchLayerPasted => 'Pasted';

  @override
  String get freeSketchLayerEmptyTransform =>
      'This layer is empty — nothing to transform.';

  @override
  String get freeSketchUndoTransform => 'Transform';

  @override
  String get freeSketchLayerEmptyAdjust =>
      'This layer is empty — nothing to adjust.';

  @override
  String get freeSketchUndoFill => 'Fill';

  @override
  String freeSketchFillFailed(String error) {
    return 'Fill failed: $error';
  }

  @override
  String freeSketchLayerLimit(int limit) {
    return 'This canvas size allows up to $limit layers.';
  }

  @override
  String freeSketchLayerCopyName(String name) {
    return '$name copy';
  }

  @override
  String get freeSketchUndoDuplicateLayer => 'Duplicate layer';

  @override
  String get freeSketchUndoMergeDown => 'Merge down';

  @override
  String get freeSketchLayerFlattened => 'Flattened';

  @override
  String get freeSketchUndoFlatten => 'Flatten';

  @override
  String get freeSketchUndoReorderLayers => 'Reorder layers';

  @override
  String get freeSketchUndoLayerOpacity => 'Layer opacity';

  @override
  String get freeSketchUndoFillLayer => 'Fill layer';

  @override
  String get freeSketchCanvasFlipH => 'Flip canvas horizontally';

  @override
  String get freeSketchCanvasFlipV => 'Flip canvas vertically';

  @override
  String freeSketchImageOpenFailed(String error) {
    return 'That image could not be opened: $error';
  }

  @override
  String freeSketchSaveFailed(String error) {
    return 'Could not save: $error';
  }

  @override
  String freeSketchExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get freeSketchExporting => 'Exporting…';

  @override
  String get freeSketchFilling => 'Filling…';

  @override
  String get freeSketchShowInterfaceTip => 'Show interface (Tab)';

  @override
  String get freeSketchSaving => 'Saving…';

  @override
  String get freeSketchEdited => 'Edited';

  @override
  String get freeSketchFitToScreenShortcut => 'Fit to screen (Ctrl+0)';

  @override
  String freeSketchResetRotationTip(String degrees) {
    return 'Reset rotation ($degrees°)';
  }

  @override
  String get freeSketchViewMirroredTip =>
      'View is mirrored — tap to unflip (H)';

  @override
  String get freeSketchUndoTip => 'Undo (Ctrl+Z)';

  @override
  String freeSketchUndoLabelTip(String label) {
    return 'Undo $label (Ctrl+Z)';
  }

  @override
  String get freeSketchRedoTip => 'Redo (Ctrl+Shift+Z)';

  @override
  String freeSketchRedoLabelTip(String label) {
    return 'Redo $label';
  }

  @override
  String get freeSketchPenSettings => 'Pen & input settings';

  @override
  String get freeSketchBackToGallery => 'Back to gallery';

  @override
  String get freeSketchSymmetryTip => 'Symmetry';

  @override
  String get freeSketchViewMenu => 'View';

  @override
  String get freeSketchAdjustmentsTip => 'Adjustments';

  @override
  String get freeSketchCanvasMenu => 'Canvas';

  @override
  String freeSketchRadialSegments(int n) {
    return 'Radial × $n';
  }

  @override
  String get freeSketchMirrorRadialCopies => 'Mirror radial copies';

  @override
  String get freeSketchFitToScreen => 'Fit to screen';

  @override
  String get freeSketchMirrorView => 'Mirror view';

  @override
  String get freeSketchResetRotation => 'Reset rotation';

  @override
  String freeSketchSymmetryMode(String mode) {
    return 'Symmetry: $mode';
  }

  @override
  String get freeSketchImportImageAsLayer => 'Import image as layer…';

  @override
  String freeSketchExportFormatLabel(String label, String extension) {
    return 'Export $label (.$extension)';
  }

  @override
  String get freeSketchViewFitMenu => 'Fit to screen   Ctrl+0';

  @override
  String get freeSketchViewActualMenu => 'Actual pixels   Ctrl+1';

  @override
  String get freeSketchViewMirrorMenu => 'Mirror view   H';

  @override
  String get freeSketchViewHideMenu => 'Hide interface   Tab';

  @override
  String freeSketchToolTapAgainBrushes(String tool) {
    return '$tool — tap again for brushes';
  }

  @override
  String get freeSketchBrushSize => 'Brush size';

  @override
  String get freeSketchPenInput => 'Pen & input';

  @override
  String get freeSketchPressureCurve => 'Pressure curve';

  @override
  String get freeSketchPressureSoft => 'Soft — light touch goes further';

  @override
  String get freeSketchPressureFirm => 'Firm — press harder for full strength';

  @override
  String get freeSketchPressureLinear => 'Linear';

  @override
  String get freeSketchDrawPenOnly => 'Draw with pen only';

  @override
  String get freeSketchPalmRejectionHint =>
      'Once a stylus is used, fingers pan and zoom instead of painting — palm rejection.';

  @override
  String get freeSketchShortcutsHelp =>
      'Shortcuts: B brush · E eraser · S smudge · G fill · D gradient · U shapes · L select · V transform · I eyedropper · [ ] size · X swap colours · H mirror view · Space-drag pan · R-drag rotate · Alt-click pick colour · Shift-click straight line · two-finger tap undo · three-finger tap redo.';

  @override
  String get galleryCategoryPictures => 'Pictures';

  @override
  String get galleryCategoryVideos => 'Videos';

  @override
  String get galleryCategoryScreenshots => 'Screenshots';

  @override
  String get galleryCategoryGifs => 'GIFs';

  @override
  String get galleryFolderDownloads => 'Downloads';

  @override
  String get galleryFolderCamera => 'Camera';

  @override
  String get galleryMonthJanuary => 'January';

  @override
  String get galleryMonthFebruary => 'February';

  @override
  String get galleryMonthMarch => 'March';

  @override
  String get galleryMonthApril => 'April';

  @override
  String get galleryMonthMay => 'May';

  @override
  String get galleryMonthJune => 'June';

  @override
  String get galleryMonthJuly => 'July';

  @override
  String get galleryMonthAugust => 'August';

  @override
  String get galleryMonthSeptember => 'September';

  @override
  String get galleryMonthOctober => 'October';

  @override
  String get galleryMonthNovember => 'November';

  @override
  String get galleryMonthDecember => 'December';

  @override
  String get galleryMonthShortJan => 'Jan';

  @override
  String get galleryMonthShortFeb => 'Feb';

  @override
  String get galleryMonthShortMar => 'Mar';

  @override
  String get galleryMonthShortApr => 'Apr';

  @override
  String get galleryMonthShortMay => 'May';

  @override
  String get galleryMonthShortJun => 'Jun';

  @override
  String get galleryMonthShortJul => 'Jul';

  @override
  String get galleryMonthShortAug => 'Aug';

  @override
  String get galleryMonthShortSep => 'Sep';

  @override
  String get galleryMonthShortOct => 'Oct';

  @override
  String get galleryMonthShortNov => 'Nov';

  @override
  String get galleryMonthShortDec => 'Dec';

  @override
  String galleryDateMonthDay(String month, int day) {
    return '$month $day';
  }

  @override
  String galleryDateMonthDayYear(String month, int day, int year) {
    return '$month $day, $year';
  }

  @override
  String galleryDayMonth(String month, int day) {
    return '$day $month';
  }

  @override
  String galleryDayMonthYear(String month, int day, int year) {
    return '$day $month $year';
  }

  @override
  String galleryMemoryRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String galleryDetailsDateTime(int day, String month, int year, String time) {
    return '$day $month $year, $time';
  }

  @override
  String get galleryBucketFood => 'Food';

  @override
  String get galleryBucketPets => 'Pets';

  @override
  String get galleryBucketAnimals => 'Animals';

  @override
  String get galleryBucketNature => 'Nature';

  @override
  String get galleryBucketOcean => 'Ocean';

  @override
  String get galleryBucketSky => 'Sky';

  @override
  String get galleryBucketNight => 'Night';

  @override
  String get galleryBucketArchitecture => 'Architecture';

  @override
  String get galleryBucketTransport => 'Transport';

  @override
  String get galleryBucketDocuments => 'Documents';

  @override
  String get galleryBucketCelebrations => 'Celebrations';

  @override
  String get galleryBucketArt => 'Art';

  @override
  String get galleryDetailsDiscardTitle => 'Discard your changes?';

  @override
  String get galleryDetailsDiscardBody =>
      'The name and date you typed will be lost.';

  @override
  String get galleryDetailsKeepEditing => 'Keep editing';

  @override
  String get galleryDetailsDiscard => 'Discard';

  @override
  String get galleryDetailsEditTitle => 'Edit details';

  @override
  String get galleryDetailsEditTooltip => 'Edit name and date';

  @override
  String get galleryDetailsEditDisabled =>
      'Editing is only available on the desktop app';

  @override
  String get galleryDetailsCloseTooltip => 'Close details';

  @override
  String get galleryDetailsSectionFile => 'File';

  @override
  String get galleryDetailsSectionPicture => 'Picture';

  @override
  String get galleryDetailsSectionRecognised => 'Recognised';

  @override
  String get galleryDetailsFormat => 'Format';

  @override
  String get galleryDetailsStored => 'Stored';

  @override
  String get galleryDetailsOnlineOnly => 'Online only — not on this PC';

  @override
  String get galleryDetailsFolder => 'Folder';

  @override
  String get galleryDetailsTaken => 'Taken';

  @override
  String get galleryDetailsDimensions => 'Dimensions';

  @override
  String get galleryDetailsLength => 'Length';

  @override
  String get galleryDetailsLocation => 'Location';

  @override
  String galleryDetailsFaces(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faces',
      one: '1 face',
    );
    return '$_temp0';
  }

  @override
  String get galleryDetailsFileName => 'File name';

  @override
  String get galleryDetailsDateTaken => 'Date taken';

  @override
  String galleryDetailsKeepExtension(String extension) {
    return 'Keep the .$extension ending.';
  }

  @override
  String get galleryDetailsDateNote =>
      'Written as the file’s date on disk. The photo itself is not re-saved, so nothing is re-compressed.';

  @override
  String get galleryDetailsSaving => 'Saving…';

  @override
  String get galleryDetailsCopyPath => 'Copy folder path';

  @override
  String get galleryDetailsPathCopied => 'Path copied';

  @override
  String get galleryEditNameEmpty => 'A file needs a name.';

  @override
  String get galleryEditNameTooLong =>
      'That name is too long — keep it under 250 characters.';

  @override
  String galleryEditNameIllegal(String characters) {
    return 'A file name can’t contain $characters';
  }

  @override
  String get galleryEditNameDot =>
      'A name starting with a dot would hide the file.';

  @override
  String get galleryEditNameTrailing =>
      'Names can’t end with a dot or a space.';

  @override
  String galleryEditNameReserved(String name) {
    return '“$name” is a name Windows reserves. Pick another.';
  }

  @override
  String galleryEditKeepExtension(String extension) {
    return 'Keep the .$extension ending — changing it stops the file opening.';
  }

  @override
  String get galleryEditFileGone => 'That file is no longer there.';

  @override
  String get galleryEditNameTaken =>
      'A file with that name is already in this folder.';

  @override
  String galleryEditRenameFailed(String reason) {
    return 'Windows would not rename it: $reason';
  }

  @override
  String get galleryEditDateFuture => 'That is in the future.';

  @override
  String get galleryEditDateTooOld => 'Photography is not that old.';

  @override
  String galleryEditDateFailed(String reason) {
    return 'The date could not be written: $reason';
  }

  @override
  String get galleryMapTitle => 'Photo map';

  @override
  String galleryMapPlacedSoFar(int placed) {
    return '$placed placed so far — still reading locations';
  }

  @override
  String galleryMapLocatedOfTotal(int located, int total) {
    return '$located of $total carry a location';
  }

  @override
  String get galleryMapReading => 'Reading where your photos were taken…';

  @override
  String get galleryMapEmptyTitle => 'No photos with a location';

  @override
  String get galleryMapEmptyBody =>
      'Photos only carry coordinates when the camera had location tagging switched on when they were taken.';

  @override
  String galleryMapClusterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos here',
      one: '1 photo here',
    );
    return '$_temp0';
  }

  @override
  String get galleryPageAddFolderDialogTitle => 'Add a folder to the gallery';

  @override
  String get galleryPageScanOneFolderDialogTitle => 'Scan only this folder';

  @override
  String get galleryPageNoFoldersYet =>
      'No folders found yet — let the first scan finish.';

  @override
  String get galleryPageScanOneFolder => 'Scan one folder';

  @override
  String get galleryPageScanOneFolderBody =>
      'Everything inside the folder you pick is included, sub-folders and all. Nothing else is looked at.';

  @override
  String get galleryPageWholeLibrary => 'The whole library';

  @override
  String galleryPageRenamePersonTitle(String name) {
    return 'Name for $name';
  }

  @override
  String get galleryPageRenameHint => 'e.g. Mum, Alex…';

  @override
  String galleryPageSortingProgress(int count, int total) {
    return 'Sorting photos into People and Categories — $count of $total';
  }

  @override
  String get galleryPageSortingStarting =>
      'Sorting photos into People and Categories…';

  @override
  String get galleryPageWaitingPermission => 'Waiting for permission…';

  @override
  String get galleryPageFindingPhotos => 'Finding your photos and videos…';

  @override
  String get galleryPageLibraryUnreadable => 'The library could not be read';

  @override
  String get galleryPageNoMediaYet => 'No photos or videos yet';

  @override
  String galleryPageNothingInRoot(String root) {
    return 'Nothing in $root. The gallery is only scanning that folder.';
  }

  @override
  String get galleryPageAnythingShowsHere =>
      'Anything you shoot or download shows up here.';

  @override
  String get galleryPageRescan => 'Rescan';

  @override
  String get galleryPageSectionAlbums => 'Albums';

  @override
  String get galleryPageSectionMoreAlbums => 'More albums';

  @override
  String get galleryPageSectionSmartAlbums => 'Smart albums';

  @override
  String get galleryPageMemories => 'Memories';

  @override
  String get galleryPageNoneYet => 'None yet';

  @override
  String galleryPageTripCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trips',
      one: '1 trip',
    );
    return '$_temp0';
  }

  @override
  String get galleryPagePeople => 'People';

  @override
  String get galleryPageNoneFoundYet => 'None found yet';

  @override
  String galleryPagePersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String get galleryPageCategories => 'Categories';

  @override
  String galleryPageCategoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count categories',
      one: '1 category',
    );
    return '$_temp0';
  }

  @override
  String get galleryPagePeopleAndCategories => 'People & Categories';

  @override
  String get galleryPageIncludedWithNova => 'Included with Nova';

  @override
  String galleryItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get galleryPageCategoryFallback => 'Category';

  @override
  String get galleryPageNoOneRecognised => 'No one recognised yet';

  @override
  String get galleryPagePeopleStillSorting =>
      'Still sorting the library — people appear here once a face has turned up in a few photos.';

  @override
  String get galleryPagePeopleSortHint =>
      'Sort the library from the albums screen and people who appear in a few photos together will show up here.';

  @override
  String get galleryPageNoTripsYet => 'No trips yet';

  @override
  String get galleryPageNoTripsBody =>
      'A run of photos over a few busy days — a weekend away, a holiday — shows up here on its own. Nothing to set up, and it works without Nova.';

  @override
  String get galleryPageNothingSortedYet => 'Nothing sorted yet';

  @override
  String get galleryPageStillLooking => 'Still looking through the library.';

  @override
  String get galleryPageSortToFill =>
      'Sort the library from the albums screen to fill these in.';

  @override
  String galleryPageScanCountOf(int scanned, int total) {
    return '$scanned of $total';
  }

  @override
  String galleryPageItemsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items found',
      one: '1 item found',
    );
    return '$_temp0';
  }

  @override
  String get galleryPageReadingLibrary => 'Reading your library…';

  @override
  String galleryPageItemCountReadingLocations(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items · reading locations',
      one: '1 item · reading locations',
    );
    return '$_temp0';
  }

  @override
  String get galleryPageSelectToSend => 'Select photos to send';

  @override
  String get galleryPageAddFolder => 'Add a folder';

  @override
  String get galleryPageScanOneFolderOnly => 'Scan one folder only';

  @override
  String get galleryPagePhotoMap => 'Photo map';

  @override
  String get galleryPageTapToPick => 'Tap photos to pick them';

  @override
  String galleryPageSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return '$_temp0';
  }

  @override
  String get galleryPageNothingInAlbum => 'Nothing in this album';

  @override
  String get galleryPageLandHere =>
      'Photos land here as soon as there are any.';

  @override
  String get galleryPageFolderGone => 'That folder is not there any more';

  @override
  String get galleryPageNoPictureFolders => 'No picture folders found';

  @override
  String get galleryPageNeedsAccess => 'Gallery needs access to your photos';

  @override
  String galleryPageScanRootUnreadable(String root) {
    return 'The gallery is only scanning $root, and that folder can no longer be read.';
  }

  @override
  String get galleryPageNothingFoundPoint =>
      'Nothing was found in Pictures, Videos or Downloads. Point the gallery at a folder and it will scan that instead.';

  @override
  String get galleryPageStaysOnDevice =>
      'Photos and videos stay on this device — the gallery only reads them to show them here.';

  @override
  String get galleryPageScanEverything => 'Scan everything';

  @override
  String get galleryPagePickAnotherFolder => 'Pick another folder';

  @override
  String get galleryPageAllowAccess => 'Allow access';

  @override
  String get galleryPageOpenSettings => 'Open settings';

  @override
  String galleryPageOnlyScanningRoot(String root) {
    return 'Only scanning $root and everything in it.';
  }

  @override
  String get galleryPageChange => 'Change';

  @override
  String get galleryPageLimitedAccess =>
      'Only the photos you picked are shared with luma.';

  @override
  String get galleryPageSelectMore => 'Select more';

  @override
  String galleryPageSortingPhotosProgress(int count, int total) {
    return 'Sorting photos — $count of $total';
  }

  @override
  String galleryPageReadingDetails(int count) {
    return 'Reading photo details — $count to go';
  }

  @override
  String get galleryPageUpToDate => 'People and Categories are up to date';

  @override
  String galleryPageLookedAt(int examined) {
    String _temp0 = intl.Intl.pluralLogic(
      examined,
      locale: localeName,
      other: '$examined photos',
      one: '1 photo',
    );
    return 'Looked at $_temp0.';
  }

  @override
  String galleryPageLookedAtSkipped(int examined, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      examined,
      locale: localeName,
      other: '$examined photos',
      one: '1 photo',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skipped,
      locale: localeName,
      other: '$skipped were skipped',
      one: '1 was skipped',
    );
    return 'Looked at $_temp0. $_temp1 because they are only in the cloud, or in a format that can\'t be read here — make them available offline and look again.';
  }

  @override
  String get galleryPageLookAgain => 'Look again';

  @override
  String galleryPageSmartDownloadDesktop(int pending, int megabytes) {
    String _temp0 = intl.Intl.pluralLogic(
      pending,
      locale: localeName,
      other: '$pending photos to look at.',
      one: '1 photo to look at.',
    );
    return '$_temp0 This downloads about $megabytes MB of models once (recognition and face matching); after that everything happens on this PC, offline — no photo is uploaded.';
  }

  @override
  String galleryPageSmartDownloadPhone(int pending, int megabytes) {
    String _temp0 = intl.Intl.pluralLogic(
      pending,
      locale: localeName,
      other: '$pending photos to look at.',
      one: '1 photo to look at.',
    );
    return '$_temp0 This downloads a small (~$megabytes MB) face-matching model once, so photos of the same person can be grouped — offline, and nothing is uploaded.';
  }

  @override
  String galleryPageSmartRemaining(int pending) {
    String _temp0 = intl.Intl.pluralLogic(
      pending,
      locale: localeName,
      other: '$pending photos still to look at.',
      one: '1 photo still to look at.',
    );
    return '$_temp0 Runs on this device, offline, and picks up where it left off.';
  }

  @override
  String get galleryPageTryAgain => 'Try again';

  @override
  String get galleryPageGetModels => 'Get the models';

  @override
  String get galleryPageSortThem => 'Sort them';

  @override
  String get galleryPageSmartUpsellTitle =>
      'People and Categories are a Nova extra';

  @override
  String get galleryPageSmartUpsellBodyModels =>
      'Nova groups your photos by who is in them and what is actually in the picture — food, pets, ocean, and more — using models that run on this device, offline. Nothing is uploaded.';

  @override
  String get galleryPageSmartUpsellBodyPhone =>
      'Nova groups your photos by what is in them. The full set of categories needs the phone build\'s models; this device still gets Panoramas and Places for free.';

  @override
  String galleryPageUpgradeTo(String plan) {
    return 'Upgrade to $plan';
  }

  @override
  String get gallerySmartSelfies => 'Selfies';

  @override
  String get gallerySmartGroupShots => 'Group shots';

  @override
  String get gallerySmartPanoramas => 'Panoramas';

  @override
  String get gallerySmartPlaces => 'Places';

  @override
  String galleryPersonDefaultName(int id) {
    return 'Person $id';
  }

  @override
  String galleryMediaItemDefaultName(String id) {
    return 'Item $id';
  }

  @override
  String get galleryRepoModelsNotStarted =>
      'The smart album models could not be started.';

  @override
  String get galleryRepoRenameDesktopOnly =>
      'Files can only be renamed in the desktop app.';

  @override
  String galleryViewerCouldNotOpenVideo(String message) {
    return 'Could not open the video: $message';
  }

  @override
  String get galleryViewerDefaultFolder => 'Photos';

  @override
  String galleryViewerPosition(int current, int total) {
    return '$current of $total';
  }

  @override
  String get galleryViewerFileNotOpened => 'This file could not be opened.';

  @override
  String get galleryViewerImageNotDecoded => 'This image could not be decoded.';

  @override
  String get galleryViewerCloudOnlyTitle => 'This one is only in the cloud';

  @override
  String galleryViewerCloudOnlyBody(String name) {
    return '$name is stored online and isn\'t on this PC. Showing it downloads it and keeps it here until your cloud app frees it up again.';
  }

  @override
  String galleryViewerCloudOnlyBodySized(String name, String size) {
    return '$name is stored online and isn\'t on this PC. Showing it downloads it ($size) and keeps it here until your cloud app frees it up again.';
  }

  @override
  String get galleryViewerDownloadAndShow => 'Download and show';

  @override
  String galleryViewerPlay(String duration) {
    return 'Play $duration';
  }

  @override
  String get galleryViewerSendToDevices => 'Send to my devices';

  @override
  String get galleryViewerHideDetails => 'Hide details';

  @override
  String get galleryViewerShowDetails => 'Show details';

  @override
  String get galleryModelPurposeLabelling => 'image labelling model';

  @override
  String get galleryModelPurposeFaceDetection => 'face detection model';

  @override
  String get galleryModelPurposeFaceRecognition => 'face recognition model';

  @override
  String galleryModelDownloading(String model) {
    return 'Downloading the $model';
  }

  @override
  String galleryModelHttpError(String model, int status) {
    return 'The $model could not be downloaded (HTTP $status).';
  }

  @override
  String galleryModelEmptyFile(String model) {
    return 'The $model downloaded as an empty file.';
  }

  @override
  String galleryModelDownloadFailed(String model, String error) {
    return 'The $model could not be downloaded: $error';
  }

  @override
  String get galleryModelReady => 'Ready';

  @override
  String get galleryModelStarting => 'Starting the models';

  @override
  String get gameToolsPriceTrackerBlurb => 'Your library, priced';

  @override
  String get gameToolsCs2MarketLabel => 'CS2 Market';

  @override
  String get gameToolsCs2MarketBlurb => 'Skins, priced and charted';

  @override
  String get gameToolsSellingCalculatorLabel => 'Selling Calculator';

  @override
  String get gameToolsSellingCalculatorBlurb => 'Estimate CS2 sale proceeds';

  @override
  String get gameToolsMafiaBlurb => 'Role counting';

  @override
  String gameToolsComingSoonTitle(String game) {
    return '$game tools are coming soon';
  }

  @override
  String gameToolsComingSoonSubtitle(String game) {
    return 'This is where $game helpers will live. Nothing to set up yet — they will show up here in a future update.';
  }

  @override
  String gameToolsToolCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tools',
      one: '1 tool',
    );
    return '$_temp0';
  }

  @override
  String gameToolsSectionTooltip(String label, String blurb) {
    return '$label — $blurb';
  }

  @override
  String get groceriesApiEnterFullAddress =>
      'Enter the full server address, e.g. https://groceries.example.com';

  @override
  String get groceriesApiOnlyHttp => 'Only http(s) addresses are supported.';

  @override
  String get groceriesApiPlainHttp =>
      'Plain http is only allowed for local/home-network servers. Use https:// for servers on the internet.';

  @override
  String groceriesApiServerError(String code) {
    return 'The groceries server returned an error ($code).';
  }

  @override
  String groceriesApiNeedsAccount(String section) {
    return 'Product search needs an approved luma account. Create one under Settings → $section — your shopping list itself keeps working offline.';
  }

  @override
  String get groceriesApiTimeout =>
      'The groceries server took too long to respond.';

  @override
  String groceriesApiUnreachable(String url) {
    return 'Could not reach the groceries server at $url. Check the address in settings.';
  }

  @override
  String get groceriesApiBadResponse =>
      'The groceries server sent back an unexpected response.';

  @override
  String get groceriesApiCouldNotReach =>
      'Could not reach the groceries server.';

  @override
  String get groceriesTitle => 'Groceries';

  @override
  String get groceriesGateTitle => 'Groceries List comes with Orbit and Nova';

  @override
  String get groceriesGateSubtitle =>
      'Search Jumbo, Albert Heijn, Hoogvliet and Lidl prices side by side, and build shopping lists that split themselves by store and aisle with running totals — included free with Orbit and Nova.';

  @override
  String groceriesUpgradeTo(String plan) {
    return 'Upgrade to $plan';
  }

  @override
  String get groceriesOverviewSubtitle =>
      'Search products across Jumbo, Albert Heijn, Hoogvliet and Lidl, and build shopping lists split by store.';

  @override
  String get groceriesNewList => 'New list';

  @override
  String get groceriesNoListsTitle => 'No lists yet';

  @override
  String get groceriesNoListsSubtitle =>
      'Create a list, then search products to add to it.';

  @override
  String get groceriesCreateFirstList => 'Create your first list';

  @override
  String groceriesItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String groceriesDeleteListTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get groceriesDeleteListBody =>
      'This removes the list and everything on it. This can\'t be undone.';

  @override
  String get groceriesListNameHint => 'List name';

  @override
  String get groceriesRenameList => 'Rename list';

  @override
  String get groceriesBackToLists => 'Back to lists';

  @override
  String get groceriesListFallbackTitle => 'List';

  @override
  String get groceriesAddProducts => 'Add products';

  @override
  String get groceriesNoItemsTitle => 'No items yet';

  @override
  String get groceriesNoItemsSubtitle =>
      'Search products to add them to this list.';

  @override
  String get groceriesAllStores => 'All stores';

  @override
  String get groceriesSortPriceAsc => 'Price ↑';

  @override
  String get groceriesSortPriceDesc => 'Price ↓';

  @override
  String groceriesAddedToList(String name) {
    return 'Added \"$name\" to your list';
  }

  @override
  String get groceriesBackToList => 'Back to list';

  @override
  String get groceriesServerAddress => 'Groceries server address';

  @override
  String get groceriesSearchProductsHint => 'Search products…';

  @override
  String get groceriesCouldNotLoad => 'Could not load products';

  @override
  String get groceriesNoProductsTitle => 'No products found';

  @override
  String get groceriesNoProductsSubtitle =>
      'Try a different search term, store or category filter.';

  @override
  String get groceriesAllProducts => 'All products';

  @override
  String get groceriesCategories => 'Categories';

  @override
  String get groceriesOnlyDeals => 'Only deals';

  @override
  String get groceriesSale => 'Sale';

  @override
  String get mlTabCreatureLab => 'Creature Lab';

  @override
  String get mlTabHowItWorks => 'How it works';

  @override
  String get mlSubtitle => 'Draw a body, let evolution find the movement.';

  @override
  String get mlHowStep1Title => 'Your drawing becomes a body';

  @override
  String get mlHowStep1Body =>
      'Every stroke is stamped down with a thickness and merged with the others wherever they touch. That is thinned to its centre line, which becomes a graph of bones sitting exactly on what was drawn — a ring stays a ring, a stick figure stays a stick figure. Short spikes thrown off by wobbles are pruned, bends keep a joint and straight runs do not, and the result is capped at eighteen bones so the search stays small enough to finish.';

  @override
  String get mlHowStep2Title => 'The bones get motors';

  @override
  String get mlHowStep2Body =>
      'Bones are rigid and held together by distance constraints. Where two bones meet there is a joint, and every joint is a spring-damper chasing a target angle that swings as a sine wave: rest + centre + amplitude x sin(2 pi f t + phase). A joint has a strength limit, the ground has ordinary Coulomb friction, and nothing a creature does to itself can shift its own centre of mass. Forward motion has to be pushed for.';

  @override
  String get mlHowStep3Title => 'The gait is the genome';

  @override
  String get mlHowStep3Body =>
      'One gene sets the frequency the whole body steps at, then each joint gets three: how far it swings, where in the cycle it swings, and which angle it swings around. That handful of numbers is the entire nervous system — there is no brain reacting to the world, only a rhythm, which is why a good gait looks stubborn.';

  @override
  String get mlHowStep4Title => 'Sixty of them run every generation';

  @override
  String get mlHowStep4Body =>
      'Each creature gets a twenty-five second trial, scored on metres travelled, docked for time spent with its head on the floor, with a bonus for every second saved once it crosses 50 m. The best four survive untouched, five fresh random genomes join each round to keep the population from getting stuck, and the rest are bred by tournament selection, uniform crossover and gaussian mutation.';

  @override
  String get mlHowStep5Title => 'And it climbs';

  @override
  String get mlHowStep5Body =>
      'The best line climbs fast and then flattens, because the search has found a local trick and is polishing it. The average line stays jagged and far below — that is mutation still throwing away most of its guesses. Restarting rolls new dice, and the same body often learns a completely different walk.';

  @override
  String get mlHowFooter =>
      'Everything runs on this device. The population is evaluated in background isolates, so the walk you are watching stays smooth while the next generation is being scored.';

  @override
  String get mlStepDrawCreature => 'Draw your creature';

  @override
  String get mlTooSmall => 'too small';

  @override
  String get mlSkeletonFound => 'skeleton found';

  @override
  String get mlStartFromExample => 'START FROM AN EXAMPLE';

  @override
  String get mlPresetBlob => 'Blob';

  @override
  String get mlPresetPerson => 'Person';

  @override
  String get mlPresetLetterA => 'Letter A';

  @override
  String get mlPresetSpider => 'Spider';

  @override
  String get mlPresetDog => 'Dog';

  @override
  String get mlPresetWorm => 'Worm';

  @override
  String get mlBodies => 'Bodies';

  @override
  String get mlJoints => 'Joints';

  @override
  String get mlGenes => 'Genes';

  @override
  String get mlDrawHelp =>
      'Strokes are given a thickness and joined where they touch, then thinned to a centre line: lavender capsules are the bones, green dots the joints, amber the head. Redrawing starts the search again from scratch.';

  @override
  String get mlShowDrawing => 'Show drawing';

  @override
  String get mlFollowLatest => 'Follow latest';

  @override
  String get mlStopNever => 'never';

  @override
  String get mlPauseEvolution => 'Pause evolution';

  @override
  String get mlResumeEvolution => 'Resume evolution';

  @override
  String get mlRestart => 'Restart';

  @override
  String get mlReplaySpeed => 'Replay speed';

  @override
  String get mlWorkers => 'Workers';

  @override
  String get mlStopAfter => 'Stop after';

  @override
  String get mlWatchGeneration => 'Watch generation';

  @override
  String mlGenerationNumber(String number) {
    return 'Generation $number';
  }

  @override
  String mlGenerationOf(String current, String total) {
    return 'generation $current of $total';
  }

  @override
  String mlStoppedAtLimit(String limit) {
    return 'stopped at $limit — move \"stop after\" up to carry on';
  }

  @override
  String mlBestDistance(String distance, String generation) {
    return 'best $distance m (gen $generation)';
  }

  @override
  String mlGenPerSecond(String rate) {
    return '$rate gen/s';
  }

  @override
  String mlWorkerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count workers',
      one: '1 worker',
    );
    return '$_temp0';
  }

  @override
  String mlReachedGoal(String seconds) {
    return 'reached 50 m in $seconds s';
  }

  @override
  String get mlChartHintDraw => 'Draw a creature to start the search.';

  @override
  String get mlChartHintTap =>
      'Tap the graph to watch any generation walk again.';

  @override
  String get mlFitnessTitle => 'Fitness over generations';

  @override
  String get mlLegendBest => 'Best';

  @override
  String get mlEmptyWalkTitle => 'Nothing to walk yet';

  @override
  String get mlEmptyWalkBody =>
      'Draw a body on the left and the search starts on its own.';

  @override
  String get mlHudDistance => 'DISTANCE';

  @override
  String get mlHudTime => 'TIME';

  @override
  String get mlHudHeadDown => 'HEAD DOWN';

  @override
  String mlMetres(String value) {
    return '$value m';
  }

  @override
  String mlHudTimeValue(String elapsed, String total) {
    return '$elapsed / $total s';
  }

  @override
  String mlSeconds(String value) {
    return '$value s';
  }

  @override
  String get mlBoardSemantics =>
      'Drawing board. Draw a creature with one or more strokes.';

  @override
  String get mlBoardEmptyTitle => 'Draw a body here';

  @override
  String get mlBoardEmptySubtitle => 'or start from an example below';

  @override
  String get mlChartEmpty => 'Every generation will leave a mark here.';

  @override
  String mlChartSemantics(int count, String metres) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count generations',
      one: '1 generation',
    );
    return 'Fitness over $_temp0. Best $metres metres.';
  }

  @override
  String get mlMetresAxis => 'metres';

  @override
  String mlChartGen(String number) {
    return 'gen $number';
  }

  @override
  String get mlWalkTitle => 'The walk to 50 metres';

  @override
  String get mediaDlHistoryInvalidSnapshot =>
      'Invalid download history snapshot.';

  @override
  String get mediaDlStatusDownloadingYtDlp => 'Downloading yt-dlp…';

  @override
  String get mediaDlStatusDownloadingFfmpeg => 'Downloading ffmpeg…';

  @override
  String get mediaDlStatusExtractingFfmpeg => 'Extracting ffmpeg…';

  @override
  String get mediaDlStatusReady => 'Ready';

  @override
  String get mediaDlStatusUpdatingYtDlp => 'Updating yt-dlp…';

  @override
  String get mediaDlFfmpegNotInDownload =>
      'Could not find ffmpeg.exe inside the download.';

  @override
  String get mediaDlFfmpegNotOnPath =>
      'ffmpeg was not found on your PATH. Install it via your package manager (e.g. sudo apt install ffmpeg) and try again.';

  @override
  String mediaDlHttpFailed(String status, String url) {
    return 'Download failed ($status) for $url.';
  }

  @override
  String mediaDlCouldNotReach(String url) {
    return 'Could not reach $url. Check your connection.';
  }

  @override
  String get mediaDlToolsNotReady => 'Tools are not set up yet.';

  @override
  String get mediaDlCouldNotReadInfo => 'Could not read video info.';

  @override
  String get mediaDlCouldNotParseInfo => 'Could not parse video info.';

  @override
  String get mediaDlYtDlpUnknownError => 'yt-dlp failed for an unknown reason.';

  @override
  String get mediaDlSetupTitle => 'Setting up Media Downloader';

  @override
  String get mediaDlSetupBody =>
      'Fetching yt-dlp and ffmpeg — this only happens once.';

  @override
  String get mediaDlSetupFailed => 'Could not set up yt-dlp / ffmpeg.';

  @override
  String get mediaDlPasteLinkFirst => 'Paste a YouTube link first.';

  @override
  String get mediaDlCouldNotReadLink => 'Could not read that link.';

  @override
  String get mediaDlCouldNotUpdate => 'Could not update yt-dlp.';

  @override
  String get mediaDlChooseFolderTitle => 'Choose a download folder';

  @override
  String get mediaDlChooseFolderFirst => 'Choose a download folder first.';

  @override
  String get mediaDlStarting => 'Starting…';

  @override
  String get mediaDlDownloadFailed => 'Download failed.';

  @override
  String get mediaDlIntroTitle => 'Download a video or song';

  @override
  String get mediaDlUpdateYtDlp => 'Update yt-dlp';

  @override
  String get mediaDlUpdating => 'Updating…';

  @override
  String mediaDlIntroBody(String updateLabel) {
    return 'Paste a YouTube video link to get started. If downloads start failing with a 403 error, YouTube has likely changed something — try \"$updateLabel\" above.';
  }

  @override
  String get mediaDlLinkHint => 'YouTube video link…';

  @override
  String get mediaDlFetch => 'Fetch';

  @override
  String get mediaDlResolution => 'Resolution';

  @override
  String get mediaDlAudioBitrate => 'Audio bitrate';

  @override
  String get mediaDlFormat => 'Format';

  @override
  String get mediaDlBitrate => 'Bitrate';

  @override
  String get mediaDlModeVideo => 'Video';

  @override
  String get mediaDlModeAudio => 'Audio';

  @override
  String get mediaDlModeAudioOnly => 'Audio only';

  @override
  String get mediaDlSaveTo => 'Save to';

  @override
  String get mediaDlChooseFolder => 'Choose a folder…';

  @override
  String get mediaDlWorking => 'Working…';

  @override
  String mediaDlEta(String eta) {
    return 'ETA $eta';
  }

  @override
  String mediaDlKbps(int kbps) {
    return '$kbps kbps';
  }

  @override
  String get mediaDlHistory => 'History';

  @override
  String get mediaDlHistoryEmpty => 'Nothing downloaded yet';

  @override
  String get mediaDlHistoryEmptyHint => 'Completed downloads show up here.';

  @override
  String get mediaDlOpenFolder => 'Open folder';

  @override
  String get mediaDlRemoveFromHistory => 'Remove from history';

  @override
  String get mindMapExportCanvasNotReady =>
      'The canvas is not ready to be captured.';

  @override
  String get mindMapExportEncodeFailed => 'The image could not be encoded.';

  @override
  String get mindMapExportSaveImageTitle => 'Save mind map image';

  @override
  String get mindMapExportSaveOutlineTitle => 'Save mind map outline';

  @override
  String mindMapExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get mindMapDirectionRight => 'Right';

  @override
  String get mindMapDirectionBoth => 'Both sides';

  @override
  String get mindMapDirectionDown => 'Downward';

  @override
  String mindMapDeleteMapTitle(String title) {
    return 'Delete \"$title\"?';
  }

  @override
  String get mindMapDeleteMapEmpty =>
      'This map is empty. It will be removed for good.';

  @override
  String mindMapDeleteMapNodes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'All $count nodes on this map will be removed for good.',
      one: 'All 1 node on this map will be removed for good.',
    );
    return '$_temp0';
  }

  @override
  String get mindMapNewMapHint => 'Name a new mind map';

  @override
  String get mindMapLibraryEmptyTitle => 'No mind maps yet';

  @override
  String get mindMapLibraryEmptySubtitle =>
      'Name one above. You start on the centre idea and press Tab to branch out — no dragging required.';

  @override
  String get mindMapDeleteMapTooltip => 'Delete map';

  @override
  String mindMapNodeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nodes',
      one: '1 node',
    );
    return '$_temp0';
  }

  @override
  String mindMapDeletedNamed(String label, int below) {
    String _temp0 = intl.Intl.pluralLogic(
      below,
      locale: localeName,
      other: 'Deleted \"$label\" and $below below it',
      one: 'Deleted \"$label\" and 1 below it',
      zero: 'Deleted \"$label\"',
    );
    return '$_temp0';
  }

  @override
  String mindMapDeletedUnnamed(int below) {
    String _temp0 = intl.Intl.pluralLogic(
      below,
      locale: localeName,
      other: 'Deleted a node and $below below it',
      one: 'Deleted a node and 1 below it',
      zero: 'Deleted a node',
    );
    return '$_temp0';
  }

  @override
  String get mindMapNewIdea => 'New idea';

  @override
  String mindMapExpandHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Expand $count hidden nodes',
      one: 'Expand 1 hidden node',
    );
    return '$_temp0';
  }

  @override
  String mindMapCollapseNodes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Collapse $count nodes',
      one: 'Collapse 1 node',
    );
    return '$_temp0';
  }

  @override
  String mindMapShowHidden(int count) {
    return 'Show $count hidden';
  }

  @override
  String mindMapHideCount(int count) {
    return 'Hide $count';
  }

  @override
  String get mindMapPasteOutline => 'Paste an outline';

  @override
  String get mindMapAddsAtRoot => 'Adds new branches at the root of this map.';

  @override
  String mindMapAddsUnder(String target) {
    return 'Adds under \"$target\".';
  }

  @override
  String get mindMapImportHint =>
      'Launch plan\n  Research\n    Competitors\n  Design\n  Ship';

  @override
  String get mindMapImportHelp =>
      'Indentation makes children. Tabs or spaces, bullets, numbers and Markdown headings all work. A \"> \" line becomes a note.';

  @override
  String mindMapNodesWillBeAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nodes will be added',
      one: '1 node will be added',
    );
    return '$_temp0';
  }

  @override
  String get mindMapAddToMap => 'Add to map';

  @override
  String get mindMapInspectorTitle => 'Node details';

  @override
  String get mindMapFieldLabel => 'Label';

  @override
  String get mindMapFieldNote => 'Note';

  @override
  String get mindMapFieldLink => 'Link';

  @override
  String get mindMapFieldColour => 'Colour';

  @override
  String get mindMapNoteHint => 'Anything that does not belong on the canvas';

  @override
  String get mindMapInheritColour => 'Inherit branch colour';

  @override
  String get mindMapColourSwatch => 'Colour swatch';

  @override
  String get mindMapInheritFromBranch => 'Inherit from branch';

  @override
  String get mindMapAiAllowanceUsed =>
      'You\'ve used today\'s AI allowance — more tomorrow.';

  @override
  String mindMapAiNoKey(String provider, String settings, String assistant) {
    return 'No API key saved for $provider. Add one under $settings → $assistant to use this.';
  }

  @override
  String get mindMapAiNoSuggestions =>
      'The model did not suggest anything usable. Try again.';

  @override
  String mindMapAiSheetTitle(String label) {
    return 'Expand \"$label\"';
  }

  @override
  String mindMapAiSelected(int chosen, int total) {
    return '$chosen of $total selected';
  }

  @override
  String get mindMapSuggestMore => 'Suggest more';

  @override
  String mindMapAddCount(int count) {
    return 'Add $count';
  }

  @override
  String get mindMapCannotMoveIntoSelf =>
      'A node cannot be moved inside itself.';

  @override
  String get mindMapMenuAddChild => 'Add child';

  @override
  String get mindMapMenuAddSibling => 'Add sibling';

  @override
  String get mindMapMenuDetails => 'Note, link & colour';

  @override
  String get mindMapMenuExpandAi => 'Expand with AI';

  @override
  String get mindMapMenuExpandBranch => 'Expand branch';

  @override
  String get mindMapMenuCollapseBranch => 'Collapse branch';

  @override
  String get mindMapMenuDeleteBranch => 'Delete branch';

  @override
  String get mindMapTouchChild => 'Child';

  @override
  String get mindMapTouchSibling => 'Sibling';

  @override
  String get mindMapAllMaps => 'All maps';

  @override
  String get mindMapRenameMap => 'Rename map';

  @override
  String mindMapLayoutTooltip(String direction) {
    return 'Layout: $direction';
  }

  @override
  String get mindMapFitToScreenShortcut => 'Fit to screen (Ctrl+0)';

  @override
  String get mindMapFitToScreen => 'Fit to screen';

  @override
  String get mindMapExportMenuPng => 'Image (PNG)';

  @override
  String get mindMapExportMenuMarkdown => 'Outline (Markdown)';

  @override
  String get mindMapExportMenuOpml => 'Outline (OPML)';

  @override
  String get mindMapHintChild => 'child';

  @override
  String get mindMapHintSibling => 'sibling';

  @override
  String get mindMapHintRename => 'rename';

  @override
  String get mindMapHintFold => 'fold';

  @override
  String get mindMapHintMoveAround => 'move around';

  @override
  String get mindMapHintArrows => 'Arrows';

  @override
  String get mindMapHintAltArrows => 'Alt+Arrows';

  @override
  String get mindMapHintReorder => 'reorder';

  @override
  String get mindMapHintDelete => 'delete';

  @override
  String get mindMapHintDrag => 'Drag';

  @override
  String get mindMapHintReparent => 're-parent';

  @override
  String get mindMapFirstBranchHintNarrow => 'Tap the centre node, then Child';

  @override
  String get mindMapFirstBranchHint =>
      'Select the centre node and press Tab to add your first branch';

  @override
  String get mindMapEmptyNodeLabel => 'Empty node';

  @override
  String get mcCrashAiUsageLimit =>
      'You\'ve hit today\'s AI usage limit — try again tomorrow.';

  @override
  String mcCrashAiNoKey(String provider) {
    return 'No API key set for $provider. Add one under Settings → AI Assistant.';
  }

  @override
  String get mcAssetIndexDownloadFailed =>
      'Could not download the asset index.';

  @override
  String mcAssetIndexRequestFailed(String status) {
    return 'Asset index request failed ($status).';
  }

  @override
  String get mcCurseForgeNeedsKey =>
      'CurseForge needs an API key. Add one to browse CurseForge.';

  @override
  String get mcTeamRoleOwner => 'Owner';

  @override
  String get mcTeamRoleMember => 'Member';

  @override
  String mcCurseForgeUnknownFile(String id) {
    return 'Unknown CurseForge file \"$id\".';
  }

  @override
  String get mcCurseForgeFileGone => 'CurseForge no longer has that file.';

  @override
  String get mcCurseForgeUnreachable =>
      'Could not reach CurseForge. Check your connection.';

  @override
  String get mcCurseForgeKeyRejected =>
      'CurseForge rejected the API key. Check it in the launcher settings.';

  @override
  String mcCurseForgeRequestFailed(String status) {
    return 'CurseForge request failed ($status).';
  }

  @override
  String get mcModrinthUnreachable =>
      'Could not reach Modrinth. Check your connection.';

  @override
  String mcModrinthRequestFailed(String status) {
    return 'Modrinth request failed ($status).';
  }

  @override
  String get mcSortRelevance => 'Relevance';

  @override
  String get mcSortDownloads => 'Downloads';

  @override
  String get mcSortFollows => 'Follows';

  @override
  String get mcSortNewest => 'Newest';

  @override
  String get mcSortRecentlyUpdated => 'Recently updated';

  @override
  String mcDownloadBatchFailed(int count, String details) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Failed to download $count files:',
      one: 'Failed to download 1 file:',
    );
    return '$_temp0\n$details';
  }

  @override
  String mcDownloadCouldNotReach(String url) {
    return 'Could not reach $url.';
  }

  @override
  String mcDownloadHttpError(String status, String url) {
    return 'HTTP $status for $url.';
  }

  @override
  String mcDownloadChecksumMismatch(String path) {
    return 'Checksum mismatch for $path.';
  }

  @override
  String mcDownloadFailed(String url) {
    return 'Failed to download $url.';
  }

  @override
  String mcFabricNoBuilds(String mcVersion) {
    return 'No Fabric loader builds found for Minecraft $mcVersion.';
  }

  @override
  String mcFabricProfileFailed(String loaderVersion) {
    return 'Could not fetch the Fabric $loaderVersion profile.';
  }

  @override
  String mcQuiltNoBuilds(String mcVersion) {
    return 'No Quilt loader builds found for Minecraft $mcVersion.';
  }

  @override
  String mcQuiltProfileFailed(String loaderVersion) {
    return 'Could not fetch the Quilt $loaderVersion profile.';
  }

  @override
  String get mcForgeVersionListUnreachable =>
      'Could not reach the Forge version list.';

  @override
  String get mcForgeDownloadingInstaller => 'Downloading Forge installer…';

  @override
  String get mcForgeRunningInstaller => 'Running Forge installer…';

  @override
  String mcForgeInstallerFailed(String output) {
    return 'The Forge installer failed:\n$output';
  }

  @override
  String get mcForgeInstallerNoNewProfile =>
      'The Forge installer ran but no new version profile was found.';

  @override
  String mcForgeInstallerNoProfile(String versionId) {
    return 'Forge installer did not produce $versionId.json.';
  }

  @override
  String mcForgeInstallerDownloadFailed(String version) {
    return 'Could not download the Forge $version installer.';
  }

  @override
  String get mcNeoForgeVersionListUnreachable =>
      'Could not reach the NeoForge version list.';

  @override
  String get mcNeoForgeDownloadingInstaller =>
      'Downloading NeoForge installer…';

  @override
  String get mcNeoForgeRunningInstaller => 'Running NeoForge installer…';

  @override
  String mcNeoForgeInstallerFailed(String output) {
    return 'The NeoForge installer failed:\n$output';
  }

  @override
  String get mcNeoForgeInstallerNoNewProfile =>
      'The NeoForge installer ran but no new version profile was found.';

  @override
  String mcNeoForgeInstallerNoProfile(String versionId) {
    return 'NeoForge installer did not produce $versionId.json.';
  }

  @override
  String mcNeoForgeInstallerDownloadFailed(String version) {
    return 'Could not download the NeoForge $version installer.';
  }

  @override
  String get mcLaunchCheckingUpdates => 'Checking for updates…';

  @override
  String mcLaunchVersionNotListed(String version) {
    return 'Minecraft $version is no longer listed by Mojang.';
  }

  @override
  String get mcLaunchResolvingFiles => 'Resolving base game files…';

  @override
  String get mcLaunchAssetLabel => 'asset';

  @override
  String get mcLaunchDownloadingGame => 'Downloading game files…';

  @override
  String mcLaunchDownloadingGameProgress(String done, String total) {
    return 'Downloading game files ($done/$total)…';
  }

  @override
  String mcLaunchNoLoaderVersion(String loader) {
    return 'This instance has no $loader version selected.';
  }

  @override
  String mcLaunchSettingUpLoader(String loader) {
    return 'Setting up $loader…';
  }

  @override
  String mcLaunchDownloadingLoaderLibraries(String loader) {
    return 'Downloading $loader libraries…';
  }

  @override
  String mcLaunchDownloadingLoaderLibrariesProgress(
    String loader,
    String done,
    String total,
  ) {
    return 'Downloading $loader libraries ($done/$total)…';
  }

  @override
  String get mcLaunchExtractingNatives => 'Extracting natives…';

  @override
  String get mcLaunchLaunching => 'Launching…';

  @override
  String mcLaunchUnknownLoader(String loader) {
    return 'Unknown mod loader \"$loader\".';
  }

  @override
  String mcLaunchUnsafeLibraryPath(String path) {
    return 'Refusing to download library with unsafe path \"$path\".';
  }

  @override
  String mcJavaLookingUp(String version) {
    return 'Looking up Java $version…';
  }

  @override
  String mcJavaDownloading(String version) {
    return 'Downloading Java $version…';
  }

  @override
  String mcJavaDownloadFailed(String status) {
    return 'Java download failed ($status).';
  }

  @override
  String mcJavaCouldNotDownload(String version) {
    return 'Could not download the Java $version runtime.';
  }

  @override
  String mcJavaExtracting(String version) {
    return 'Extracting Java $version…';
  }

  @override
  String mcJavaMissingJavaw(String version) {
    return 'Downloaded Java $version runtime is missing javaw.exe.';
  }

  @override
  String get mcJavaReady => 'Ready';

  @override
  String get mcJavaProviderUnreachable =>
      'Could not reach the Java runtime provider.';

  @override
  String mcJavaNoBuildFound(String version, String status) {
    return 'No Java $version build found ($status).';
  }

  @override
  String mcJavaNoBuildForWindows(String version) {
    return 'No Java $version build available for Windows x64.';
  }

  @override
  String mcGameCouldNotStartJava(String error) {
    return 'Could not start Java: $error';
  }

  @override
  String get mcCloudBackupNeedsAccount =>
      'Cloud backups need an approved luma account — create one under Settings → Sync & account.';

  @override
  String get mcCloudStorageFull => 'Not enough cloud storage space.';

  @override
  String get mcCloudBackupMissingPart =>
      'Part of this backup is missing on the server.';

  @override
  String get mcCloudBackupIndexFailed =>
      'Could not update the backup list — please try again.';

  @override
  String get mcMsAuthNotConfigured =>
      'Microsoft sign-in is not configured for this build.';

  @override
  String get mcMsAuthDeclined => 'Sign-in was declined.';

  @override
  String get mcMsAuthCodeExpired => 'The sign-in code expired. Try again.';

  @override
  String get mcMsAuthTimedOut => 'Timed out waiting for sign-in.';

  @override
  String get mcMsAuthNoXboxProfile =>
      'This Microsoft account has no Xbox profile. Create one at xbox.com and try again.';

  @override
  String get mcMsAuthUnder18 =>
      'This account is under 18 and needs a family group to sign in to Xbox services.';

  @override
  String get mcMsAuthXboxRejected => 'Xbox sign-in was rejected.';

  @override
  String get mcMsAuthNoMinecraft =>
      'This Microsoft account does not own Minecraft.';

  @override
  String mcMsAuthUnexpectedResponse(String status) {
    return 'Unexpected response ($status).';
  }

  @override
  String mcMsAuthRequestFailed(String status) {
    return 'Request failed ($status).';
  }

  @override
  String mcModInstalledInto(String title, String instance) {
    return 'Installed $title into $instance.';
  }

  @override
  String mcModInstalledWithDeps(String title, int count, String instance) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dependencies',
      one: '1 dependency',
    );
    return 'Installed $title + $_temp0 into $instance.';
  }

  @override
  String mcModNoBuildVanilla(String version) {
    return 'No build of this for $version.';
  }

  @override
  String mcModNoBuildForLoader(String version, String loader) {
    return 'No build of this for $version on $loader.';
  }

  @override
  String get mcModDepsPromptTitle => 'Install required dependencies?';

  @override
  String mcModNeedsDeps(String title) {
    return '$title needs these to work:';
  }

  @override
  String get mcModInstallAll => 'Install all';

  @override
  String get mcContentTypeMods => 'Mods';

  @override
  String get mcContentTypeResourcePacks => 'Resource Packs';

  @override
  String get mcContentTypeShaderPacks => 'Shader Packs';

  @override
  String mcModCurseForgeOnly(String title) {
    return '$title can only be downloaded from its CurseForge page — the author has turned off downloads in other launchers.';
  }

  @override
  String mcModUnsafeFileName(String filename) {
    return 'Refusing to install \"$filename\": unsafe file name.';
  }

  @override
  String mcModIncompatible(String a, String b) {
    return '$a is marked incompatible with $b.';
  }

  @override
  String get mcModpackReading => 'Reading modpack…';

  @override
  String get mcModpackNotValid =>
      'Not a valid .mrpack file (missing modrinth.index.json).';

  @override
  String get mcModpackNoMinecraftVersion =>
      'This modpack does not declare a Minecraft version.';

  @override
  String get mcModpackDefaultName => 'Imported modpack';

  @override
  String get mcModpackDownloadingFiles => 'Downloading modpack files…';

  @override
  String mcModpackDownloadingFilesProgress(String done, String total) {
    return 'Downloading modpack files ($done/$total)…';
  }

  @override
  String get mcModpackExtractingOverrides => 'Extracting overrides…';

  @override
  String get mcModpackRecording => 'Recording installed content…';

  @override
  String get mcModpackDone => 'Done';

  @override
  String mcPistonUnreachable(String url) {
    return 'Could not reach $url. Check your connection.';
  }

  @override
  String mcPistonRequestFailed(String status, String url) {
    return 'Request failed ($status) for $url.';
  }

  @override
  String get minecraftLauncherTabLibrary => 'Library';

  @override
  String get minecraftLauncherTabAccounts => 'Accounts';

  @override
  String get minecraftLauncherTabServers => 'Servers';

  @override
  String get minecraftLauncherTabSettings => 'Settings';

  @override
  String get minecraftLauncherNotWindowsTitle =>
      'Not available on this platform';

  @override
  String get minecraftLauncherNotWindowsSubtitle =>
      'Minecraft Launcher currently only supports Windows.';

  @override
  String get minecraftLauncherOfflineNeedsMicrosoft =>
      'Sign in with a Microsoft account that owns Minecraft first — offline profiles are for playing without a connection afterwards, not instead of that.';

  @override
  String get minecraftLauncherCloudBackups => 'Cloud backups';

  @override
  String minecraftLauncherBackedUpCount(int count) {
    return '$count backed up';
  }

  @override
  String get minecraftLauncherRestore => 'Restore';

  @override
  String get minecraftLauncherCurseForgeKeyTitle => 'CurseForge API key';

  @override
  String minecraftLauncherCurseForgeKeyBody(String accountOverview) {
    return 'CurseForge only answers apps that send an API key. Create a free one in the CurseForge for Studios console and paste it here. It is stored encrypted on this device, shared with $accountOverview, and only ever sent to CurseForge.';
  }

  @override
  String get minecraftLauncherCurseForgeOpenConsole =>
      'Open the CurseForge console';

  @override
  String get minecraftLauncherCurseForgePasteKeyHint => 'Paste your API key';

  @override
  String get minecraftLauncherStarting => 'Starting…';

  @override
  String minecraftLauncherStartingInstance(String name) {
    return 'Starting $name';
  }

  @override
  String get minecraftLauncherSearchHint => 'Search instances and mods…';

  @override
  String get minecraftLauncherInstances => 'Instances';

  @override
  String get minecraftLauncherMods => 'Mods';

  @override
  String get minecraftLauncherNoModsFound => 'No mods found.';

  @override
  String get minecraftLauncherNewInstance => 'New instance';

  @override
  String get minecraftLauncherCouldNotLoadVersions =>
      'Could not load Minecraft versions';

  @override
  String get minecraftLauncherInstanceNameHint => 'Instance name';

  @override
  String get minecraftLauncherModLoader => 'Mod loader';

  @override
  String get minecraftLauncherLoaderVanilla => 'Vanilla';

  @override
  String minecraftLauncherLoaderVersion(String loader) {
    return '$loader version';
  }

  @override
  String minecraftLauncherNoLoaderBuilds(String loader, String version) {
    return 'No $loader builds found for $version.';
  }

  @override
  String get minecraftLauncherShowSnapshots => 'Show snapshots';

  @override
  String get minecraftLauncherVersion => 'Version';

  @override
  String get minecraftLauncherSearchVersionsHint => 'Search versions…';

  @override
  String get minecraftLauncherVersionTypeRelease => 'Release';

  @override
  String get minecraftLauncherVersionTypeSnapshot => 'Snapshot';

  @override
  String get minecraftLauncherVersionTypeOldBeta => 'Old beta';

  @override
  String get minecraftLauncherVersionTypeOldAlpha => 'Old alpha';

  @override
  String minecraftLauncherBrowseFor(String name) {
    return 'Browse for $name';
  }

  @override
  String minecraftLauncherSearchKindHint(String kind) {
    return 'Search $kind…';
  }

  @override
  String minecraftLauncherCompatibleWith(String version) {
    return 'Compatible with $version';
  }

  @override
  String minecraftLauncherCompatibleWithLoader(String version, String loader) {
    return 'Compatible with $version · $loader';
  }

  @override
  String minecraftLauncherResultCount(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown results',
      one: '$shown result',
    );
    return '$_temp0';
  }

  @override
  String minecraftLauncherInstallInto(String name) {
    return 'Install into $name';
  }

  @override
  String get minecraftLauncherCurseForgeNeedsKey =>
      'CurseForge needs an API key';

  @override
  String get minecraftLauncherCurseForgeNeedsKeySubtitle =>
      'Add your own free key once and CurseForge mods, resource packs and shaders show up here.';

  @override
  String get minecraftLauncherAddApiKey => 'Add API key';

  @override
  String get minecraftLauncherChangeApiKey => 'Change API key';

  @override
  String get minecraftLauncherSearchFailed => 'Search failed';

  @override
  String get minecraftLauncherNoResults => 'No results';

  @override
  String get minecraftLauncherNoResultsSubtitle =>
      'Try a different search, sort, or content type.';

  @override
  String get minecraftLauncherEndOfResults => 'That is everything.';

  @override
  String get minecraftLauncherLoadMore => 'Load more';

  @override
  String get minecraftLauncherAddOfflineAccount => 'Add offline account';

  @override
  String get minecraftLauncherSignInMicrosoft => 'Sign in with Microsoft';

  @override
  String get minecraftLauncherNoAccounts => 'No accounts yet';

  @override
  String get minecraftLauncherNoAccountsSubtitle =>
      'Sign in with a Microsoft account that owns Minecraft to get started. Once you have, you can add an offline profile for playing without a connection.';

  @override
  String get minecraftLauncherMicrosoftUnavailable =>
      'Microsoft sign-in is unavailable';

  @override
  String get minecraftLauncherMicrosoftUnavailableBody =>
      'This build is missing Luma’s Microsoft app registration. Do not accept a consent screen that says Prism Launcher.';

  @override
  String get minecraftLauncherDeviceCodeInstructions =>
      'The code is shown below. Enter it on the Microsoft page that just opened:';

  @override
  String get minecraftLauncherCopyCode => 'Copy code';

  @override
  String get minecraftLauncherCodeCopied => 'Code copied.';

  @override
  String get minecraftLauncherWaitingForBrowser =>
      'Waiting for you to finish in the browser…';

  @override
  String get minecraftLauncherOpenMicrosoftSignIn => 'Open Microsoft sign-in';

  @override
  String get minecraftLauncherMicrosoftAccount => 'Microsoft account';

  @override
  String get minecraftLauncherOfflineAccount => 'Offline account';

  @override
  String get minecraftLauncherActive => 'Active';

  @override
  String get minecraftLauncherUseAccount => 'Use this account';

  @override
  String get mcLauncherInstanceNotFound => 'Instance not found';

  @override
  String get mcLauncherExportModpack => 'Export as modpack';

  @override
  String get mcLauncherDeleteInstance => 'Delete instance';

  @override
  String get mcLauncherTabContent => 'Content';

  @override
  String get mcLauncherTabWorlds => 'Worlds';

  @override
  String get mcLauncherTabScreenshots => 'Screenshots';

  @override
  String get mcLauncherTabLogs => 'Logs';

  @override
  String get mcLauncherExportModpackTitle => 'Export modpack';

  @override
  String mcLauncherExportedTo(String path) {
    return 'Exported to $path';
  }

  @override
  String mcLauncherDeleteInstanceTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get mcLauncherDeleteInstanceBody =>
      'This removes the instance from your library. World saves and other files stay on disk unless you delete them manually from the instance folder.';

  @override
  String get mcLauncherAddAccountFirst =>
      'Add an account under the Accounts tab first.';

  @override
  String get mcLauncherNeverPlayed => 'Never played';

  @override
  String mcLauncherLastPlayed(String date) {
    return 'Last played $date';
  }

  @override
  String mcLauncherTotalPlaytime(int hours, int minutes) {
    return 'Total playtime: ${hours}h ${minutes}m';
  }

  @override
  String get mcLauncherOpenFolder => 'Open folder';

  @override
  String get mcLauncherPlay => 'Play';

  @override
  String get mcLauncherCheckUpdates => 'Check updates';

  @override
  String get mcLauncherNothingInstalled => 'Nothing installed yet';

  @override
  String get mcLauncherNothingInstalledSubtitle =>
      'Browse Modrinth or CurseForge for mods, resource packs and shader packs.';

  @override
  String get mcLauncherKindMods => 'Mods';

  @override
  String get mcLauncherKindResourcePacks => 'Resource packs';

  @override
  String get mcLauncherKindShaderPacks => 'Shader packs';

  @override
  String get mcLauncherKindDatapacks => 'Data packs';

  @override
  String get mcLauncherAnalyzeWithAi => 'Analyze with AI';

  @override
  String get mcLauncherAnalyzing => 'Analyzing…';

  @override
  String get mcLauncherAiAnalysis => 'AI analysis';

  @override
  String get mcLauncherWaitingForOutput => 'Waiting for output…';

  @override
  String get mcLauncherNotRunning => 'Not running';

  @override
  String get mcLauncherNotRunningSubtitle =>
      'Launch the instance to see live output here.';

  @override
  String get mcLauncherInstanceIcon => 'Instance icon';

  @override
  String get mcLauncherMemory => 'Memory';

  @override
  String mcLauncherMemoryRange(int minMb, int maxMb) {
    return 'Min $minMb MB · Max $maxMb MB';
  }

  @override
  String get mcLauncherJavaOverride => 'Java executable override';

  @override
  String get mcLauncherJavaOverrideHint => 'Leave blank to auto-manage';

  @override
  String get mcLauncherJvmArgs => 'Extra JVM arguments';

  @override
  String get mcLauncherInstancesTitle => 'Instances';

  @override
  String get mcLauncherImportModpack => 'Import modpack';

  @override
  String get mcLauncherNewInstance => 'New instance';

  @override
  String get mcLauncherImportStarting => 'Starting…';

  @override
  String get mcLauncherNoInstances => 'No instances yet';

  @override
  String get mcLauncherNoInstancesSubtitle =>
      'Create one to install Minecraft and start playing.';

  @override
  String get mcLauncherImportingModpack => 'Importing modpack';

  @override
  String get mcLauncherNoDescription => 'This project has no description.';

  @override
  String get mcLauncherUpdatesTitle => 'Updates & conflicts';

  @override
  String get mcLauncherConflicts => 'Conflicts';

  @override
  String get mcLauncherUpdates => 'Updates';

  @override
  String get mcLauncherUpToDate => 'Everything is up to date.';

  @override
  String get mcLauncherUpdating => 'Updating…';

  @override
  String get mcLauncherUpdate => 'Update';

  @override
  String mcLauncherYearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years ago',
      one: '1 year ago',
    );
    return '$_temp0';
  }

  @override
  String mcLauncherMonthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months ago',
      one: '1 month ago',
    );
    return '$_temp0';
  }

  @override
  String mcLauncherDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String mcLauncherHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String mcLauncherMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String mcLauncherByAuthor(String author) {
    return 'by $author';
  }

  @override
  String mcLauncherUpdatedAgo(String time) {
    return 'Updated $time';
  }

  @override
  String get mcLauncherInstalled => 'Installed';

  @override
  String get mcLauncherAlreadyInstalled => 'Already installed';

  @override
  String get mcLauncherPickInstanceTitle => 'Install into which instance?';

  @override
  String get mcLauncherCreateInstanceFirst => 'Create an instance first.';

  @override
  String mcLauncherNoBuildFor(String version) {
    return 'No build of this for $version.';
  }

  @override
  String mcLauncherNoBuildForLoader(String version, String loader) {
    return 'No build of this for $version on $loader.';
  }

  @override
  String mcLauncherOpenOn(String source) {
    return 'Open on $source';
  }

  @override
  String get mcLauncherCouldNotLoadProject => 'Could not load this project';

  @override
  String get mcLauncherGallery => 'Gallery';

  @override
  String mcLauncherImageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count images',
      one: '1 image',
    );
    return '$_temp0';
  }

  @override
  String get mcLauncherStatDownloads => 'downloads';

  @override
  String get mcLauncherStatFollowers => 'followers';

  @override
  String get mcLauncherStatUpdated => 'updated';

  @override
  String get mcLauncherLinkSource => 'Source';

  @override
  String get mcLauncherLinkIssues => 'Issues';

  @override
  String get mcLauncherLinkWiki => 'Wiki';

  @override
  String get mcLauncherInstallInto => 'Install into…';

  @override
  String get mcLauncherPickInstanceTooltip =>
      'Pick an instance to install into';

  @override
  String mcLauncherInstallNewestInto(String name) {
    return 'Install the newest compatible build into $name';
  }

  @override
  String get mcLauncherChooseInstance => 'Choose instance';

  @override
  String get mcLauncherTabVersions => 'Versions';

  @override
  String mcLauncherVersionsCount(int count) {
    return 'Versions ($count)';
  }

  @override
  String get mcLauncherPickInstanceToSee =>
      'Pick an instance to see which builds fit it.';

  @override
  String mcLauncherNoBuildWorksWith(String version) {
    return 'No build of this works with $version.';
  }

  @override
  String mcLauncherNoBuildWorksWithLoader(String version, String loader) {
    return 'No build of this works with $version on $loader.';
  }

  @override
  String mcLauncherImageIndex(int index, int total) {
    return 'Image $index of $total';
  }

  @override
  String get mcLauncherRevealInFolder => 'Reveal in folder';

  @override
  String get mcLauncherCopyPath => 'Copy path';

  @override
  String get mcLauncherBackupToCloud => 'Backup to cloud';

  @override
  String mcLauncherBackedUpToCloud(String label) {
    return 'Backed up \"$label\" to the cloud.';
  }

  @override
  String get mcLauncherNoScreenshots => 'No screenshots yet';

  @override
  String get mcLauncherNoScreenshotsSubtitle =>
      'Screenshots you take in-game (F2) will show up here.';

  @override
  String get mcLauncherCouldNotOpenBrowser => 'Could not open the browser.';

  @override
  String get mcLauncherServersTitle => 'Servers';

  @override
  String get mcLauncherServersIntro =>
      'Rent a Minecraft server to play your instances with friends.';

  @override
  String get mcLauncherKineticBody =>
      'Modpack and plugin support, 24/7 support and one-click installs. Signing up through this link supports luma at no extra cost to you.';

  @override
  String get mcLauncherBrowsePlans => 'Browse plans';

  @override
  String get mcLauncherServerHostingEyebrow => 'MINECRAFT SERVER HOSTING';

  @override
  String get mcLauncherServerHostingHeadline =>
      'QUALITY HOSTING,\nFOR LOW PRICES!';

  @override
  String get mcLauncherPillSupport => '24/7 support';

  @override
  String get mcLauncherPillModSupport => 'Mod support';

  @override
  String get mcLauncherStartToday => 'START TODAY!';

  @override
  String get mcLauncherJavaRuntimes => 'Java runtimes';

  @override
  String get mcLauncherRuntimesHint =>
      'Downloaded automatically the first time an instance needs them.';

  @override
  String get mcLauncherNoRuntimes => 'None downloaded yet.';

  @override
  String get mcLauncherCurseForgeKeySaved =>
      'API key saved. Browse pages can search and install from CurseForge.';

  @override
  String get mcLauncherCurseForgeKeyAdd =>
      'Add your own API key to browse and install CurseForge content.';

  @override
  String get mcLauncherChangeApiKey => 'Change API key';

  @override
  String get mcLauncherAddApiKey => 'Add API key';

  @override
  String get mcLauncherRemoveKey => 'Remove key';

  @override
  String get mcLauncherCouldNotReadWorlds => 'Could not read worlds';

  @override
  String get mcLauncherImportWorld => 'Import world';

  @override
  String get mcLauncherNoWorlds => 'No worlds yet';

  @override
  String get mcLauncherNoWorldsSubtitle =>
      'Worlds you create in-game will show up here.';

  @override
  String mcLauncherWorldSeed(String seed) {
    return 'Seed $seed';
  }

  @override
  String get mcLauncherBackupToZip => 'Backup to zip';

  @override
  String get mcLauncherDuplicate => 'Duplicate';

  @override
  String mcLauncherBackedUpTo(String path) {
    return 'Backed up to $path';
  }

  @override
  String mcLauncherDeleteWorldTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get mcLauncherDeleteWorldBody =>
      'This permanently deletes the world folder.';

  @override
  String get moodJournalTabJournal => 'Journal';

  @override
  String get moodJournalTabCalendar => 'Calendar';

  @override
  String get moodJournalAddEntry => 'Add entry';

  @override
  String get moodJournalEmptyTitle => 'No entries yet';

  @override
  String get moodJournalEmptySubtitle =>
      'Log your mood to start tracking your patterns.';

  @override
  String get moodJournalMoodTerrible => 'Terrible';

  @override
  String get moodJournalMoodBad => 'Bad';

  @override
  String get moodJournalMoodOkay => 'Okay';

  @override
  String get moodJournalMoodGood => 'Good';

  @override
  String get moodJournalMoodGreat => 'Great';

  @override
  String get moodJournalTagWork => 'Work';

  @override
  String get moodJournalTagSleep => 'Sleep';

  @override
  String get moodJournalTagExercise => 'Exercise';

  @override
  String get moodJournalTagSocial => 'Social';

  @override
  String get moodJournalTagHealth => 'Health';

  @override
  String get moodJournalDaySun => 'S';

  @override
  String get moodJournalDayMon => 'M';

  @override
  String get moodJournalDayTue => 'T';

  @override
  String get moodJournalDayWed => 'W';

  @override
  String get moodJournalDayThu => 'T';

  @override
  String get moodJournalDayFri => 'F';

  @override
  String get moodJournalDaySat => 'S';

  @override
  String get moodJournalNoEntriesForDay => 'No entries for this day';

  @override
  String get moodJournalAddNewEntry => 'Add new entry';

  @override
  String get moodJournalEditEntry => 'Edit entry';

  @override
  String get moodJournalNewEntry => 'New entry';

  @override
  String get moodJournalSaveChanges => 'Save changes';

  @override
  String get moodJournalSaveEntry => 'Save entry';

  @override
  String get moodJournalFeelingQuestion => 'How are you feeling?';

  @override
  String get moodJournalEntryLabel => 'Journal entry';

  @override
  String get moodJournalPhotos => 'Photos';

  @override
  String get moodJournalTags => 'Tags';

  @override
  String get moodJournalNoteHint => 'What\'s on your mind?';

  @override
  String get moodJournalCustomTagHint => 'Add custom tag...';

  @override
  String get nfcRecordEditorTypeText => 'Text';

  @override
  String get nfcRecordEditorTypeLink => 'Link';

  @override
  String get nfcRecordEditorTypePhone => 'Phone';

  @override
  String get nfcRecordEditorTypeWifi => 'Wi-Fi';

  @override
  String get nfcRecordEditorTypeContact => 'Contact';

  @override
  String get nfcRecordEditorTypeApp => 'App';

  @override
  String get nfcRecordEditorTypeCustom => 'Custom';

  @override
  String get nfcRecordEditorAddTitle => 'Add record';

  @override
  String get nfcRecordEditorEditTitle => 'Edit record';

  @override
  String get nfcRecordEditorErrorText => 'Enter some text.';

  @override
  String get nfcRecordEditorErrorLink => 'Enter a valid link.';

  @override
  String get nfcRecordEditorErrorPhone => 'Enter a phone number.';

  @override
  String get nfcRecordEditorErrorEmail => 'Enter an email address.';

  @override
  String get nfcRecordEditorErrorNetwork => 'Enter the network name.';

  @override
  String get nfcRecordEditorErrorName => 'Enter a name.';

  @override
  String get nfcRecordEditorErrorPackage =>
      'Enter a package name, e.g. com.example.app.';

  @override
  String get nfcRecordEditorErrorMime => 'Enter a MIME type, e.g. text/plain.';

  @override
  String get nfcRecordEditorTextHint => 'Whatever this tag should say';

  @override
  String get nfcRecordEditorLanguageCode => 'Language code';

  @override
  String get nfcRecordEditorPhoneNumber => 'Phone number';

  @override
  String get nfcRecordEditorAddress => 'Address';

  @override
  String get nfcRecordEditorSubjectOptional => 'Subject (optional)';

  @override
  String get nfcRecordEditorBodyOptional => 'Body (optional)';

  @override
  String get nfcRecordEditorNetworkName => 'Network name (SSID)';

  @override
  String get nfcRecordEditorSecurity => 'Security';

  @override
  String get nfcRecordEditorSecurityOpen => 'Open';

  @override
  String get nfcRecordEditorWifiNote =>
      'Written as a text record most phones can read when they tap the tag — it won\'t auto-join every device the way a router\'s own Wi-Fi QR code sometimes does.';

  @override
  String get nfcRecordEditorPhoneOptional => 'Phone (optional)';

  @override
  String get nfcRecordEditorEmailOptional => 'Email (optional)';

  @override
  String get nfcRecordEditorOrganizationOptional => 'Organization (optional)';

  @override
  String get nfcRecordEditorPackageName => 'Package name';

  @override
  String get nfcRecordEditorAppHint =>
      'Find this under Settings → Apps → (the app) → Advanced → App details, on the phone that has it installed. Android offers to open or install this app when it reads the tag.';

  @override
  String get nfcRecordEditorMimeType => 'MIME type';

  @override
  String get nfcRecordEditorContent => 'Content';

  @override
  String get nfcKindPhone => 'Phone number';

  @override
  String get nfcKindWifi => 'Wi-Fi details';

  @override
  String get nfcKindContact => 'Contact card';

  @override
  String get nfcKindAppLaunch => 'App shortcut';

  @override
  String get nfcKindMime => 'Custom data';

  @override
  String get nfcKindRaw => 'Unrecognized record';

  @override
  String get nfcSummaryEmpty => 'Empty';

  @override
  String get nfcSummaryNoLink => 'No link set';

  @override
  String get nfcSummaryNoNumber => 'No number set';

  @override
  String get nfcSummaryNoAddress => 'No address set';

  @override
  String get nfcSummaryNoNetwork => 'No network set';

  @override
  String get nfcSummaryNoName => 'No name set';

  @override
  String get nfcSummaryNoPackage => 'No package set';

  @override
  String nfcSummaryRawBytes(int bytes) {
    return 'Kept as-is ($bytes bytes) — not editable';
  }

  @override
  String get nfcDuplicate => 'Duplicate';

  @override
  String get nfcAndroidOnlyTitle => 'Android only';

  @override
  String get nfcUnsupportedNotice =>
      'NFC Tag Editor needs Android\'s NFC hardware and reader APIs, so it only works on an Android phone or tablet — there\'s nothing to scan or write here.';

  @override
  String get nfcErrNotNdef =>
      'This tag doesn\'t support NDEF, so luma can\'t edit it. Most blank NFC stickers and cards do — try another tag.';

  @override
  String get nfcErrNotAvailable =>
      'NFC editing isn\'t available on this device.';

  @override
  String get nfcErrNfcOff =>
      'NFC is off or unsupported here. Turn it on in your device settings and try again.';

  @override
  String nfcErrStartFailed(String error) {
    return 'Could not start the NFC reader. ($error)';
  }

  @override
  String nfcErrCouldNotReach(String error) {
    return 'Couldn\'t reach that tag. ($error)';
  }

  @override
  String get nfcErrLocked =>
      'This tag is locked read-only and can no longer be written to.';

  @override
  String nfcErrTooBig(int bytes, int capacity) {
    return 'That\'s $bytes bytes, but this tag only holds $capacity. Remove a record and try again.';
  }

  @override
  String get nfcErrNotWritable =>
      'This tag can\'t be written to — it doesn\'t support NDEF.';

  @override
  String get nfcErrNothingToLock =>
      'This tag isn\'t NDEF-formatted, so there\'s nothing to lock.';

  @override
  String get nfcErrNoTag =>
      'No tag detected. Hold it flat against the back of your phone and try again.';

  @override
  String get nfcTabEditor => 'Editor';

  @override
  String get nfcTabTemplates => 'Templates';

  @override
  String get nfcTabHistory => 'History';

  @override
  String get nfcHeroTitle => 'Scan a tag to see what\'s on it';

  @override
  String get nfcHeroBody =>
      'Hold any NFC tag or sticker to your phone to read and edit its records — or start from scratch and write a brand-new tag.';

  @override
  String get nfcScanTag => 'Scan a tag';

  @override
  String get nfcStartFromScratch => 'Start from scratch';

  @override
  String get nfcRecordsHeading => 'Records';

  @override
  String get nfcNoRecordsTitle => 'No records yet';

  @override
  String get nfcNoRecordsBody =>
      'Add a record above — text, a link, Wi-Fi details, a contact card and more.';

  @override
  String get nfcWriteToTag => 'Write to tag';

  @override
  String get nfcWriteHint =>
      'Works on the tag you scanned or a different one — just hold whichever you want to write to when it\'s ready.';

  @override
  String get nfcStartOver => 'Start over';

  @override
  String get nfcStartOverTitle => 'Start over?';

  @override
  String get nfcStartOverBody =>
      'This clears every record in the editor. Anything already written to a tag is unaffected.';

  @override
  String get nfcWrittenLocked => 'Written and locked read-only.';

  @override
  String get nfcWritten => 'Written to the tag.';

  @override
  String get nfcWriteAnother => 'Write another';

  @override
  String get nfcWriteFailed => 'Couldn\'t write to that tag.';

  @override
  String get nfcReadFailed => 'Something went wrong reading that tag.';

  @override
  String get nfcSaveAsTemplate => 'Save as template';

  @override
  String get nfcTemplateNameHint => 'e.g. Guest Wi-Fi';

  @override
  String nfcTemplateSaved(String name) {
    return 'Saved “$name”.';
  }

  @override
  String get nfcWriteLockTitle => 'Write & lock this tag?';

  @override
  String get nfcWriteLockBody =>
      'This writes the records below, then makes the tag permanently read-only. It can never be written to again — not by luma, not by any other app.';

  @override
  String get nfcWriteLockAction => 'Write & lock';

  @override
  String get nfcWriteLockMenu => 'Write & lock (read-only)';

  @override
  String get nfcNoRecords => 'No records';

  @override
  String get nfcDeleteTemplateTitle => 'Delete template?';

  @override
  String nfcDeleteTemplateBody(String name) {
    return 'This removes “$name” — tags already written with it keep their content.';
  }

  @override
  String get nfcNoTemplatesTitle => 'No templates yet';

  @override
  String get nfcNoTemplatesBody =>
      'Build a set of records in the Editor tab, then save it here to write the same tag content again and again — handy for a batch of stickers.';

  @override
  String nfcTemplateRecordsSummary(int count, String kinds) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records',
      one: '1 record',
    );
    return '$_temp0 · $kinds';
  }

  @override
  String get nfcUseTemplate => 'Use';

  @override
  String get nfcClearHistory => 'Clear history';

  @override
  String get nfcClearHistoryTitle => 'Clear history?';

  @override
  String get nfcClearHistoryBody =>
      'Every scan and write in the list is removed. Saved templates are unaffected.';

  @override
  String get nfcNoHistoryTitle => 'No history yet';

  @override
  String get nfcNoHistoryBody =>
      'Every tag you scan or write shows up here, so you can revisit what was on it.';

  @override
  String get nfcWrittenTagTitle => 'Written tag';

  @override
  String get nfcScannedTagTitle => 'Scanned tag';

  @override
  String get nfcLoadIntoEditor => 'Load into editor';

  @override
  String nfcHistoryWrittenLine(String tech) {
    return 'Written · $tech';
  }

  @override
  String nfcHistoryScannedLine(String tech) {
    return 'Scanned · $tech';
  }

  @override
  String get nfcGenericTagName => 'NFC tag';

  @override
  String nfcHistoryTimeAndRecords(String time, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records',
      one: '1 record',
    );
    return '$time · $_temp0';
  }

  @override
  String get nfcTimeJustNow => 'Just now';

  @override
  String nfcTimeMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String nfcTimeHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String nfcTimeDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String get nfcBusyScanLabel => 'Hold a tag against your phone';

  @override
  String get nfcBusyWriteLabel => 'Hold the tag you want to write to';

  @override
  String get nfcBusyHint =>
      'Keep it flat against the back of the phone until it beeps or vibrates.';

  @override
  String get nfcTagReadOnly => 'Read-only';

  @override
  String get nfcTagBlankWillFormat => 'Blank — will format';

  @override
  String nfcTagUid(String uid) {
    return 'UID $uid';
  }

  @override
  String nfcTagBytesUsed(int used, int capacity) {
    return '$used / $capacity bytes';
  }

  @override
  String get nfcTemplateDefaultName => 'Template';

  @override
  String get nfcSnapshotInvalid => 'Invalid NFC tag editor snapshot.';

  @override
  String get priceScraperInvalidUrl => 'Invalid URL.';

  @override
  String get priceScraperUnreachable =>
      'Could not reach the URL. Check your connection.';

  @override
  String priceScraperHttpError(int status) {
    return 'The page returned an error ($status).';
  }

  @override
  String get priceScraperNoPrice =>
      'Could not find a price on this page. The site may require JavaScript or block scraping.';

  @override
  String get priceTrackerEnterUrl => 'Enter a product URL.';

  @override
  String get priceTrackerCheckFailed => 'Could not check the price.';

  @override
  String get priceTrackerTrackTitle => 'Track a product';

  @override
  String get priceTrackerTrackSubtitle =>
      'Paste a product URL and luma checks the price for you.';

  @override
  String get priceTrackerNameHint => 'Name (optional)';

  @override
  String get priceTrackerTrack => 'Track';

  @override
  String get priceTrackerTrackedItems => 'Tracked items';

  @override
  String get priceTrackerEmptyTitle => 'Nothing tracked yet';

  @override
  String get priceTrackerEmptySubtitle =>
      'Products you track are saved here with a price-history graph.';

  @override
  String get priceTrackerCheckNow => 'Check price now';

  @override
  String get priceTrackerInvalidSnapshot => 'Invalid price tracker snapshot.';

  @override
  String get qrEnterUrl => 'Enter a URL.';

  @override
  String get qrGenerateTitle => 'Generate a QR code';

  @override
  String get qrGenerateSubtitle =>
      'Paste a URL and turn it into a scannable QR code.';

  @override
  String get qrGenerate => 'Generate';

  @override
  String get qrEmptyTitle => 'No QR codes yet';

  @override
  String get qrEmptySubtitle =>
      'Codes you generate are saved here so you can reopen them anytime.';

  @override
  String get qrCopyUrl => 'Copy URL';

  @override
  String get recipeBookCouldNotLoadPhoto => 'Could not load photo.';

  @override
  String recipeBookServerError(int status) {
    return 'Server error ($status).';
  }

  @override
  String get recipeBookSignInToManage => 'Sign in to manage published recipes.';

  @override
  String get recipeBookNotFound => 'Recipe not found.';

  @override
  String get recipeBookSavedPrivately =>
      'Saved privately. Sign in under Settings → Sync to publish it.';

  @override
  String recipeBookCouldNotPublish(String error) {
    return 'Could not publish: $error';
  }

  @override
  String recipeBookCouldNotUpdatePublished(String error) {
    return 'Could not update the published copy: $error';
  }

  @override
  String get recipeBookCouldNotReachServer => 'Could not reach the server.';

  @override
  String recipeBookCouldNotPostReview(String error) {
    return 'Could not post your review: $error';
  }

  @override
  String get recipeBookSignInToReview => 'Sign in to review recipes.';

  @override
  String get recipeBookSignInToManageReviews => 'Sign in to manage reviews.';

  @override
  String get recipeBookInvalidSnapshot => 'Invalid recipe book snapshot.';

  @override
  String get recipeBookSearchHint => 'Search recipes…';

  @override
  String get recipeBookTabFavourites => 'Favourites';

  @override
  String recipeBookTabFavouritesCount(int count) {
    return 'Favourites ($count)';
  }

  @override
  String get recipeBookTabPublic => 'Public';

  @override
  String get recipeBookTabPrivate => 'Private';

  @override
  String get recipeBookCategoryBreakfast => 'Breakfast';

  @override
  String get recipeBookCategoryLunch => 'Lunch';

  @override
  String get recipeBookCategoryDinner => 'Dinner';

  @override
  String get recipeBookCategoryDessert => 'Dessert';

  @override
  String get recipeBookCategorySnack => 'Snack';

  @override
  String get recipeBookCategoryDrink => 'Drink';

  @override
  String get recipeBookCategoryBaking => 'Baking';

  @override
  String get recipeBookNoRecipesYet => 'No recipes yet';

  @override
  String get recipeBookNoRecipesFound => 'No recipes found';

  @override
  String get recipeBookAddFirstHint =>
      'Tap the + button to add your first recipe.';

  @override
  String get recipeBookTryOtherSearch => 'Try a different search or category.';

  @override
  String get recipeBookSignInToBrowseTitle =>
      'Sign in to browse public recipes';

  @override
  String get recipeBookSignInToBrowseSubtitle =>
      'Public recipes are shared through your sync account. Sign in under Settings → Sync & account to browse, publish, rate and review.';

  @override
  String get recipeBookCouldNotLoadPublic => 'Couldn\'t load public recipes';

  @override
  String get recipeBookNoPublicYet => 'No public recipes yet';

  @override
  String get recipeBookPublishFirstHint =>
      'Publish one of your recipes to get the catalogue started.';

  @override
  String get recipeBookNoFavouritesYet => 'No favourites yet';

  @override
  String get recipeBookFavouritesHint =>
      'Tap the heart on any recipe — private or public — to keep it here.';

  @override
  String get recipeBookNew => 'New';

  @override
  String get recipeBookYou => 'You';

  @override
  String get recipeBookPlanner => 'Planner';

  @override
  String get recipeCategoryBreakfast => 'Breakfast';

  @override
  String get recipeCategoryLunch => 'Lunch';

  @override
  String get recipeCategoryDinner => 'Dinner';

  @override
  String get recipeCategoryDessert => 'Dessert';

  @override
  String get recipeCategorySnack => 'Snack';

  @override
  String get recipeCategoryDrink => 'Drink';

  @override
  String get recipeCategoryBaking => 'Baking';

  @override
  String get recipeCategoryOther => 'Other';

  @override
  String get recipeUnitNone => 'Unit';

  @override
  String get recipeUnitG => 'g';

  @override
  String get recipeUnitKg => 'kg';

  @override
  String get recipeUnitMl => 'ml';

  @override
  String get recipeUnitL => 'l';

  @override
  String get recipeUnitTsp => 'tsp';

  @override
  String get recipeUnitTbsp => 'tbsp';

  @override
  String get recipeUnitCup => 'cup';

  @override
  String get recipeUnitOz => 'oz';

  @override
  String get recipeUnitLb => 'lb';

  @override
  String get recipeUnitPiece => 'piece';

  @override
  String get recipeUnitSlice => 'slice';

  @override
  String get recipeUnitPinch => 'pinch';

  @override
  String get recipeUnitToTaste => 'to taste';

  @override
  String recipeTimeMinutes(int count) {
    return '${count}m';
  }

  @override
  String recipeTimeHours(int count) {
    return '${count}h';
  }

  @override
  String recipeTimeHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String get recipeSomeone => 'Someone';

  @override
  String get recipeSharedToPublic => 'Shared to Public';

  @override
  String get recipePrivateRecipe => 'Private recipe';

  @override
  String get recipeRemoveFromPublic => 'Remove from Public';

  @override
  String recipeConfirmTitle(String action) {
    return '$action recipe?';
  }

  @override
  String recipeConfirmRemoveBody(String title) {
    return '\"$title\" will be removed from the public catalogue.';
  }

  @override
  String recipeConfirmDeleteBody(String title) {
    return '\"$title\" will be permanently deleted.';
  }

  @override
  String recipeByAuthor(String name) {
    return 'by $name';
  }

  @override
  String recipeByAuthorYou(String name) {
    return 'by $name · you';
  }

  @override
  String get recipeNoRatingsYet => 'No ratings yet';

  @override
  String recipeRatingSummary(String average, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ratings',
      one: '1 rating',
    );
    return '$average · $_temp0';
  }

  @override
  String recipeReviewsCount(int count) {
    return 'Reviews ($count)';
  }

  @override
  String get recipeBeFirstToReview => 'Be the first to review this recipe.';

  @override
  String get recipePickRatingFirst => 'Pick a star rating first.';

  @override
  String get recipeThanksForReview => 'Thanks for your review!';

  @override
  String get recipeYourReview => 'Your review';

  @override
  String get recipeWriteReview => 'Write a review';

  @override
  String get recipeReviewHint => 'Share how it turned out… (optional)';

  @override
  String get recipeAddPhoto => 'Add photo';

  @override
  String get recipeChangePhoto => 'Change photo';

  @override
  String get recipePostReview => 'Post review';

  @override
  String get recipeReviewYou => 'You';

  @override
  String recipeServingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servings',
      one: '1 serving',
    );
    return '$_temp0';
  }

  @override
  String recipePrepTime(String time) {
    return 'Prep: $time';
  }

  @override
  String recipeCookTime(String time) {
    return 'Cook: $time';
  }

  @override
  String get recipeIngredients => 'Ingredients';

  @override
  String get recipeInstructions => 'Instructions';

  @override
  String get recipeAddIngredient => 'Add ingredient';

  @override
  String get recipeAddStep => 'Add step';

  @override
  String get recipeIngredientHint => 'Ingredient';

  @override
  String get recipeAmountHint => 'Amt';

  @override
  String get recipeStepHint => 'Describe this step…';

  @override
  String get recipeTitleRequired => 'Please give your recipe a title.';

  @override
  String get recipeEditTitle => 'Edit recipe';

  @override
  String get recipeNewTitle => 'New recipe';

  @override
  String get recipeStepsTab => 'Steps';

  @override
  String get recipeSaveChanges => 'Save changes';

  @override
  String get recipeAddRecipe => 'Add recipe';

  @override
  String get recipeAddARecipe => 'Add a recipe';

  @override
  String get recipeTitleHint => 'e.g. Spaghetti Carbonara';

  @override
  String get recipeDescriptionLabel => 'Description (optional)';

  @override
  String get recipeDescriptionHint => 'A short note about this recipe…';

  @override
  String get recipeCategoryField => 'Category';

  @override
  String get recipeServingsLabel => 'Servings';

  @override
  String get recipePrepTimeLabel => 'Prep time (min)';

  @override
  String get recipeCookTimeLabel => 'Cook time (min)';

  @override
  String get recipeShareToPublic => 'Share to Public';

  @override
  String get recipeShareToPublicHint =>
      'Publish so other luma users can find, rate and review it.';

  @override
  String get recipeSignInToPublish =>
      'Sign in under Settings → Sync to publish recipes.';

  @override
  String get recipePhotoOptional => 'Photo (optional)';

  @override
  String get recipeReplacePhoto => 'Replace';

  @override
  String get recipeChoosePhoto => 'Choose photo';

  @override
  String get recipePlannerTitle => 'Meal planner';

  @override
  String get recipeThisWeek => 'This week';

  @override
  String get recipeJumpToThisWeek => 'Jump to this week';

  @override
  String get recipeWeekStartsOn => 'Week starts on';

  @override
  String get recipeNothingPlanned => 'Nothing planned yet.';

  @override
  String recipeCategoryPublic(String category) {
    return '$category · public';
  }

  @override
  String get recipeTabMyRecipes => 'My recipes';

  @override
  String get recipeTabPublic => 'Public';

  @override
  String get recipeNoRecipesYet => 'You have no recipes yet.';

  @override
  String get recipeNoMatches => 'No matches.';

  @override
  String get recipeSignInToBrowse => 'Sign in to browse public recipes.';

  @override
  String get recipeNoPublicRecipesYet => 'No public recipes yet.';

  @override
  String get recipeSearchHint => 'Search recipes…';

  @override
  String get mafiaRoleCountingTitle => 'Role Counting';

  @override
  String get mafiaRoleCountingIntro =>
      'Pick how many players are in the lobby, then check off roles as they get claimed.';

  @override
  String get mafiaRoleCountingPlayersInLobby => 'Players in lobby';

  @override
  String get mafiaRoleCountingLowCountWarning =>
      'The wiki flags its data below 7 players as possibly inaccurate — treat this count as a rough guide.';

  @override
  String mafiaRoleCountingClaimedOfTotal(int claimed, int total) {
    return '$claimed / $total claimed';
  }

  @override
  String get mafiaRoleCountingNoRoles => 'No roles for this lobby size';

  @override
  String get mafiaRoleCountingNoRolesHint => 'Try a different player count.';

  @override
  String get mafiaRoleCountingClaimed => 'Claimed';

  @override
  String get mafiaRoleCountingClaimedBy => 'Claimed by… (disguise name)';

  @override
  String get mafiaFactionTown => 'Town';

  @override
  String get mafiaFactionNeutral => 'Neutral';

  @override
  String get mafiaFactionMafia => 'Mafia';

  @override
  String get mafiaFactionVeil => 'Veil';

  @override
  String get mafiaFactionTownWin => 'Wins by eliminating the Mafia';

  @override
  String get mafiaFactionNeutralWin => 'Has its own win condition';

  @override
  String get mafiaFactionMafiaWin => 'Wins at numerical parity with the Town';

  @override
  String get mafiaFactionVeilWin => 'Wins by reaching 100% corruption';

  @override
  String get schoolCitationSourceBook => 'Book';

  @override
  String get schoolCitationSourceWebsite => 'Website';

  @override
  String get schoolCitationSourceJournalArticle => 'Journal article';

  @override
  String get schoolCitationSourceNewspaper => 'Newspaper article';

  @override
  String get schoolCitationSourceVideo => 'Video';

  @override
  String get schoolQuizLevel => 'Grade 8 · practice for the IEP test';

  @override
  String get schoolQuizBlurbRekenen =>
      'Numbers, ratios, measurement & geometry, relationships';

  @override
  String get schoolQuizBlurbTaalverzorging =>
      'Spelling, verb spelling and punctuation';

  @override
  String get schoolQuizBlurbLezen =>
      'Understanding texts, summarising, word meaning and lookup';

  @override
  String get schoolQuizBlurbEngels =>
      'Extra practice · English for upper and first-year secondary';

  @override
  String get schoolQuizBlurbAardrijkskunde =>
      'Extra practice · The Netherlands, Europe, the world and weather';

  @override
  String get schoolQuizBlurbGeschiedenis =>
      'Extra practice · The ten historical periods, from hunters to today';

  @override
  String get schoolQuizBlurbBiologie =>
      'Extra practice · Body, nature, energy and technology';

  @override
  String get schoolQuizDefaultTitle => 'Practice test grade 8';

  @override
  String get schoolQuizPickSubject => 'Pick at least one subject.';

  @override
  String schoolQuizChooseBetween(int min, int max) {
    return 'Choose between $min and $max questions.';
  }

  @override
  String get schoolQuizNotEnoughQuestions =>
      'There are not enough questions available for these subjects.';

  @override
  String schoolQuizMaxQuestionsPerPdf(int max) {
    return 'Choose at most $max questions per PDF.';
  }

  @override
  String schoolQuizInvalidCount(String subject) {
    return 'Invalid number of questions for $subject.';
  }

  @override
  String schoolQuizPdfRunningHeader(String section) {
    return 'LUMA SCHOOL  |  $section';
  }

  @override
  String get schoolQuizPdfSectionQuestions => 'Questions';

  @override
  String get schoolQuizPdfSectionAnswerSheet => 'Answer sheet';

  @override
  String schoolQuizPdfCountLine(int count, String mode) {
    return '$count questions | $mode';
  }

  @override
  String get schoolQuizPdfMixed => 'Subjects mixed';

  @override
  String get schoolQuizPdfPerSubject => 'Per subject';

  @override
  String schoolQuizPdfQuestionTitle(String number, String subject) {
    return 'Question $number - $subject';
  }

  @override
  String schoolQuizPdfQuestionTitlePassage(
    String number,
    String subject,
    String passage,
  ) {
    return 'Question $number - $subject - Text $passage';
  }

  @override
  String schoolQuizPdfPassageHeading(String number) {
    return 'Text $number';
  }

  @override
  String schoolQuizPdfPageOf(String page, String total) {
    return 'Page $page of $total';
  }

  @override
  String get schoolQuizPdfNameDateLine =>
      'Name: ........................................  Date: ........................';

  @override
  String get schoolQuizPdfInstructions =>
      'Read every question carefully. Tick the answer or fill in the requested answer. When there are several answers, the question says how many to choose.';

  @override
  String get schoolQuizPdfDisclaimer =>
      'Own practice material. Not an official IEP test or school advice.';

  @override
  String get schoolQuizPdfAnswerBlank =>
      'Answer: .....................................';

  @override
  String get schoolQuizPdfAnswersHeading => 'Answers';

  @override
  String get schoolQuizPdfAnswersNote =>
      'For marking. Keep this answer sheet separate from the questions.';

  @override
  String get schoolTabDashboard => 'Dashboard';

  @override
  String get schoolTabTimetable => 'Timetable';

  @override
  String get schoolTabAssignments => 'Assignments';

  @override
  String get schoolTabFlashcards => 'Flashcards';

  @override
  String get schoolTabPracticeTests => 'Practice tests';

  @override
  String get schoolTabFormulas => 'Formulas';

  @override
  String get schoolTabStudyTimer => 'Study timer';

  @override
  String get schoolTabGpa => 'GPA';

  @override
  String get schoolTabCitations => 'Citations';

  @override
  String get schoolPracticeTestSaveTitle => 'Save practice test as PDF';

  @override
  String get schoolPdfSaveUnsupported =>
      'Saving PDFs is not supported on this device.';

  @override
  String get schoolPriorityLow => 'Low';

  @override
  String get schoolPriorityMedium => 'Medium';

  @override
  String get schoolPriorityHigh => 'High';

  @override
  String get schoolPriority => 'Priority';

  @override
  String get schoolAssignmentsShowCompleted => 'Show completed';

  @override
  String get schoolAssignmentsAdd => 'Add assignment';

  @override
  String get schoolAssignmentsEdit => 'Edit assignment';

  @override
  String get schoolAssignmentsEmpty => 'No assignments';

  @override
  String get schoolAssignmentsEmptySub =>
      'Add homework or a tracked assignment to see it here.';

  @override
  String schoolAssignmentDue(String date) {
    return 'Due $date';
  }

  @override
  String get schoolSubject => 'Subject';

  @override
  String get schoolSubjectOptional => 'Subject (optional)';

  @override
  String get schoolCitationsNew => 'New citation';

  @override
  String get schoolCitationStyle => 'Style';

  @override
  String get schoolCitationSourceType => 'Source type';

  @override
  String get schoolCitationAuthor => 'Author (Last, First)';

  @override
  String get schoolCitationYear => 'Year';

  @override
  String get schoolCitationPublisher => 'Publisher';

  @override
  String get schoolCitationContainer => 'Website / journal name';

  @override
  String get schoolCitationVolume => 'Volume';

  @override
  String get schoolCitationIssue => 'Issue';

  @override
  String get schoolCitationPages => 'Pages';

  @override
  String get schoolCitationCity => 'City';

  @override
  String get schoolCitationAccessDate => 'Access date';

  @override
  String get schoolCitationPreviewEmpty => 'Preview will appear here.';

  @override
  String get schoolCitationSave => 'Save citation';

  @override
  String get schoolCitationsEmpty => 'No saved citations yet';

  @override
  String get schoolSubjects => 'Subjects';

  @override
  String get schoolStatDueThisWeek => 'Due this week';

  @override
  String get schoolStatOverdue => 'Overdue';

  @override
  String get schoolAddSubject => 'Add subject';

  @override
  String get schoolDashboardNoSubjects =>
      'No subjects yet. Add one to get started.';

  @override
  String get schoolDashboardNoClasses => 'No classes scheduled today.';

  @override
  String get schoolDashboardDueSoon => 'Due soon';

  @override
  String get schoolDashboardNothingDueSoon => 'Nothing due in the next 7 days.';

  @override
  String get schoolClassFallback => 'Class';

  @override
  String get schoolFormulasSearchHint => 'Search formulas';

  @override
  String get schoolFormulasAdd => 'Add formula';

  @override
  String get schoolFormulasEdit => 'Edit formula';

  @override
  String get schoolFormulasEmpty => 'No formulas yet';

  @override
  String get schoolFormulasEmptySub =>
      'Add your own formulas to build a personal reference library.';

  @override
  String get schoolFormulaExpression => 'Expression';

  @override
  String get schoolFormulaDescriptionOptional => 'Description (optional)';

  @override
  String get schoolDeckNameHint => 'New deck name';

  @override
  String get schoolFlashcardsCreateDeck => 'Create deck';

  @override
  String get schoolFlashcardsNoDecks => 'No decks yet';

  @override
  String get schoolFlashcardsNoDecksSub =>
      'Create a deck, then add cards to start studying.';

  @override
  String schoolFlashcardsCardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards',
      one: '1 card',
    );
    return '$_temp0';
  }

  @override
  String schoolFlashcardsDueNow(int count) {
    return '$count due now';
  }

  @override
  String schoolFlashcardsDeckSummary(int total, int due) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total cards',
      one: '1 card',
    );
    return '$_temp0 · $due due';
  }

  @override
  String get schoolFlashcardsAddCard => 'Add card';

  @override
  String get schoolFlashcardsEditCard => 'Edit card';

  @override
  String get schoolFlashcardsStudyNow => 'Study now';

  @override
  String get schoolFlashcardsNoCards => 'No cards in this deck';

  @override
  String get schoolFlashcardsNoCardsSub =>
      'Add a front/back card to start reviewing.';

  @override
  String schoolFlashcardsReviewStats(
    int reviews,
    int accuracy,
    String seconds,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      reviews,
      locale: localeName,
      other: '$reviews reviews',
      one: '1 review',
    );
    return '$_temp0 · $accuracy% correct · avg ${seconds}s';
  }

  @override
  String get schoolCardFront => 'Front';

  @override
  String get schoolCardBack => 'Back';

  @override
  String schoolFlashcardsCardOf(int current, int total) {
    return 'Card $current of $total';
  }

  @override
  String get schoolFlashcardsTypeAnswer => 'Type your answer';

  @override
  String get schoolFlashcardsCorrect => 'Correct';

  @override
  String get schoolFlashcardsNotQuite => 'Not quite';

  @override
  String schoolFlashcardsAnswer(String back) {
    return 'Answer: $back';
  }

  @override
  String get schoolFlashcardsCheckAnswer => 'Check answer';

  @override
  String get schoolGpaGradeCalculator => 'Grade calculator';

  @override
  String get schoolGpaOverallGpa => 'Overall GPA';

  @override
  String get schoolGpaOverallGrade => 'Overall grade';

  @override
  String get schoolGpaAddRecord => 'Add record';

  @override
  String get schoolGpaAddRecordTitle => 'Add GPA record';

  @override
  String get schoolGpaTrend => 'Trend';

  @override
  String get schoolGpaNoRecords => 'No GPA records yet';

  @override
  String get schoolGpaNoRecordsSub =>
      'Log a finished term\'s grade to start tracking your GPA.';

  @override
  String schoolGpaRecordAmerican(String term, String credits, String points) {
    return '$term · $credits credits · $points pts';
  }

  @override
  String schoolGpaRecordDutch(String term, String credits, String points) {
    return '$term · $credits credits · $points';
  }

  @override
  String get schoolGpaCreditHours => 'Credit hours';

  @override
  String get schoolGpaTermLabel => 'Term (e.g. Fall 2026)';

  @override
  String get schoolGpaFinalPercentage => 'Final percentage grade';

  @override
  String get schoolGpaFinalGrade => 'Final grade (1-10)';

  @override
  String schoolGpaPointsHelper(String points) {
    return '= $points GPA points';
  }

  @override
  String get schoolGradeNoSubjects => 'No subjects yet';

  @override
  String get schoolGradeNoSubjectsSub =>
      'Add a subject to start weighting its grade components.';

  @override
  String get schoolGradeAddComponent => 'Add component';

  @override
  String get schoolGradeEditComponent => 'Edit component';

  @override
  String get schoolGradeCurrent => 'Current grade';

  @override
  String get schoolGradeTarget => 'Target grade %';

  @override
  String schoolGradeWeightGraded(String percent) {
    return '$percent% of weight graded';
  }

  @override
  String get schoolGradeAddUngraded => 'Add ungraded components to project';

  @override
  String schoolGradeNeeded(String percent) {
    return 'Need $percent% on the rest';
  }

  @override
  String get schoolGradeNoComponents => 'No grade components yet';

  @override
  String get schoolGradeNoComponentsSub =>
      'Add weighted components like \"Midterm\" or \"Final\".';

  @override
  String schoolGradeComponentScored(
    String weight,
    String earned,
    String total,
  ) {
    return '$weight% weight · $earned/$total';
  }

  @override
  String schoolGradeComponentUngraded(String weight) {
    return '$weight% weight · not graded yet';
  }

  @override
  String get schoolGradeNameLabel => 'Name (e.g. Midterm)';

  @override
  String get schoolGradeWeightLabel => 'Weight (%)';

  @override
  String get schoolGradeScoreEarned => 'Score earned (optional)';

  @override
  String get schoolGradeOutOf => 'Out of';

  @override
  String get schoolSubjectAddTitle => 'Add subject';

  @override
  String get schoolSubjectEditTitle => 'Edit subject';

  @override
  String get schoolSubjectCreditHours => 'Credit hours';

  @override
  String get schoolSubjectGroupOther => 'Other subjects · extra practice';

  @override
  String get schoolTimetableWeeklySchedule => 'Weekly schedule';

  @override
  String get schoolTimetableAddClass => 'Add class';

  @override
  String get schoolTimetableNoClasses => 'No classes scheduled';

  @override
  String get schoolTimetableAddSubjectFirst =>
      'Add a subject first, then add its class times.';

  @override
  String get schoolTimetableTapAddClass =>
      'Tap \"Add class\" to build your weekly schedule.';

  @override
  String get schoolTimetableClass => 'Class';

  @override
  String get schoolTimetableSubject => 'Subject';

  @override
  String get schoolTimetableDay => 'Day';

  @override
  String schoolTimetableStart(String time) {
    return 'Start: $time';
  }

  @override
  String schoolTimetableEnd(String time) {
    return 'End: $time';
  }

  @override
  String get schoolTimetableLocation => 'Location (optional)';

  @override
  String get schoolTimetableInstructor => 'Instructor (optional)';

  @override
  String get schoolStudyTimeBySubject => 'Time by subject';

  @override
  String get schoolStudyNoSessionsLogged => 'No study sessions logged yet.';

  @override
  String get schoolStudyRecentSessions => 'Recent sessions';

  @override
  String get schoolStudyNoCompletedSessions => 'No completed sessions';

  @override
  String get schoolStudyNoSubject => 'No subject';

  @override
  String schoolStudySessionMeta(String date, int minutes) {
    return '$date · $minutes min';
  }

  @override
  String get schoolStudyStartStudying => 'Start studying';

  @override
  String get schoolStudySubjectOptional => 'Subject (optional)';

  @override
  String get schoolStudyStartTimer => 'Start timer';

  @override
  String get schoolStudyStudying => 'Studying';

  @override
  String get schoolPdfDefaultTitle => 'Practice test, grade 8';

  @override
  String get schoolPdfPickOneSubject => 'Choose at least one subject.';

  @override
  String schoolPdfCountRange(String name, int max) {
    return 'Choose between 1 and $max questions for $name.';
  }

  @override
  String schoolPdfMaxQuestions(int max) {
    return 'Choose at most $max questions per PDF.';
  }

  @override
  String get schoolPdfSaveCancelled => 'Saving was cancelled.';

  @override
  String schoolPdfSaved(String path) {
    return 'PDF saved: $path';
  }

  @override
  String get schoolPdfSaveFailed => 'The PDF could not be saved. Try again.';

  @override
  String get schoolPdfAsPdf => 'Practice test as PDF';

  @override
  String get schoolPdfTitle => 'Build your practice test';

  @override
  String get schoolPdfIntro =>
      'Choose one or more subjects. The PDF contains a new selection without duplicate questions, in A4 format.';

  @override
  String get schoolPdfSectionLayout => 'Title & layout';

  @override
  String get schoolPdfTitleField => 'Title on the PDF';

  @override
  String get schoolPdfSpreadTotal => 'Spread a total';

  @override
  String get schoolPdfCountPerSubject => 'Count per subject';

  @override
  String get schoolPdfTotalQuestions => 'Total number of questions';

  @override
  String schoolPdfTotalHint(int max) {
    return 'Up to $max; split as evenly as possible.';
  }

  @override
  String get schoolPdfGroupDoorstroom => 'Doorstroomtoets (transfer test)';

  @override
  String get schoolPdfOrder => 'Order';

  @override
  String get schoolPdfOrderPerSubject => 'By subject';

  @override
  String get schoolPdfOrderMixed => 'Mixed';

  @override
  String get schoolPdfOrderHelp =>
      'Questions that share a reading passage stay together. With \"By subject\", each next subject starts on a new page.';

  @override
  String get schoolPdfExtraWritingSpace => 'Extra writing space';

  @override
  String get schoolPdfAddAnswerSheet => 'Add answer sheet';

  @override
  String get schoolPdfAnswerSheetHelp =>
      'Starts on a new page after the questions.';

  @override
  String get schoolPdfExplanations => 'Explanations with the answers';

  @override
  String schoolPdfSummary(int total, int subjects, String order) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total questions',
      one: '1 question',
    );
    String _temp1 = intl.Intl.pluralLogic(
      subjects,
      locale: localeName,
      other: '$subjects subjects',
      one: '1 subject',
    );
    return '$_temp0 · $_temp1 · $order';
  }

  @override
  String get schoolPdfMaking => 'Making PDF…';

  @override
  String get schoolPdfMakeAndSave => 'Make and save PDF';

  @override
  String schoolPdfAvailable(int count) {
    return '$count available';
  }

  @override
  String schoolPdfAvailableInPdf(int count, int inPdf) {
    return '$count available · $inPdf in the PDF';
  }

  @override
  String schoolPdfCountLabel(String name) {
    return 'Questions for $name';
  }

  @override
  String get schoolTestsTitle => 'Practice tests';

  @override
  String schoolTestsIntro(String level, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total questions',
      one: '1 question',
    );
    return '$level. Our own practice questions in the question formats of the IEP, not an official IEP test. For the doorstroomtoets you practise maths, reading and language. The other subjects are extra practice. Your practice score is not test advice or a level determination. $_temp0 in the bank.';
  }

  @override
  String get schoolTestsChooseSubject => 'Choose a subject';

  @override
  String get schoolTestsGroupPractice => 'Practice for IEP';

  @override
  String get schoolTestsHowMany => 'How many questions?';

  @override
  String schoolQuestionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions',
      one: '1 question',
    );
    return '$_temp0';
  }

  @override
  String get schoolTestsWhatYouGet => 'What you get';

  @override
  String get schoolTestsWhatYouGetBody =>
      'Questions are spread evenly across the topics, so you practise different skills. Read each instruction carefully: sometimes you choose an answer, sometimes you fill something in. You only see the explanations after checking your answers.';

  @override
  String get schoolTestsChooseFirst => 'Choose a subject first';

  @override
  String schoolTestsStartTest(String subject) {
    return 'Start test $subject';
  }

  @override
  String get schoolTestsPdfBannerSub =>
      'Build a printable test with your own subjects and counts.';

  @override
  String schoolTestsSubjectMeta(int questions, int topics) {
    String _temp0 = intl.Intl.pluralLogic(
      questions,
      locale: localeName,
      other: '$questions questions',
      one: '1 question',
    );
    String _temp1 = intl.Intl.pluralLogic(
      topics,
      locale: localeName,
      other: '$topics topics',
      one: '1 topic',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String schoolTestsProgress(int number, int total, int answered) {
    return 'Question $number of $total · $answered answered';
  }

  @override
  String get schoolTestsYourAnswer => 'Your answer';

  @override
  String get schoolTestsHelperNumber =>
      'Enter the number only. Use a comma for decimals.';

  @override
  String get schoolTestsHelperWord =>
      'Enter only the requested word or the missing letters.';

  @override
  String get schoolTestsCheck => 'Check answers';

  @override
  String get schoolTestsCheckNow => 'Check answers now';

  @override
  String schoolTestsCorrectOf(int correct, int total) {
    return '$correct of $total correct';
  }

  @override
  String schoolTestsResultMeta(
    String subject,
    String duration,
    String perQuestion,
    int skipped,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      skipped,
      locale: localeName,
      other: ' · $skipped skipped',
      zero: '',
    );
    return '$subject · $duration · $perQuestion per question$_temp0';
  }

  @override
  String get schoolTestsPerTopic => 'By topic';

  @override
  String get schoolTestsNewTest => 'New test';

  @override
  String get schoolTestsOtherSubject => 'Another subject';

  @override
  String get schoolTestsAnswers => 'Answers';

  @override
  String get schoolTestsOnlyMistakes => 'Only mistakes';

  @override
  String get schoolTestsAllQuestions => 'All questions';

  @override
  String get schoolTestsAllCorrect => 'All correct';

  @override
  String get schoolTestsNoMistakes => 'No mistakes to review.';

  @override
  String get schoolTestsSkippedThis => 'You skipped this question.';

  @override
  String get schoolTestsAnsweredCorrectly => 'Answered correctly.';

  @override
  String schoolTestsYourAnswerValue(String answer) {
    return 'Your answer: $answer';
  }

  @override
  String schoolTestsCorrectAnswerValue(String answer) {
    return 'Correct answer: $answer';
  }

  @override
  String schoolTestsQuestionNumber(int number) {
    return 'Question $number';
  }

  @override
  String schoolTestsDurationSec(int seconds) {
    return '$seconds sec';
  }

  @override
  String schoolTestsDurationMinSec(int minutes, int seconds) {
    return '$minutes min $seconds sec';
  }

  @override
  String get secureChatNotReady => 'Chat encryption is not ready yet.';

  @override
  String get secureChatPeerNoKey =>
      'This person hasn\'t set up chat encryption yet — try again later.';

  @override
  String get secureChatNotSignedIn => 'Not signed in.';

  @override
  String get secureChatIdentityLoadFailed =>
      'Chat identity could not be loaded. Restore the original identity.';

  @override
  String secureChatServerError(int status) {
    return 'Server error ($status).';
  }

  @override
  String get secureChatTitle => 'End-to-end encrypted chat';

  @override
  String get secureChatPickOrInvite =>
      'Pick a conversation, or invite someone new by email.';

  @override
  String get secureChatBack => 'Chats';

  @override
  String get secureChatNeedsSyncTitle => 'Chat needs sync';

  @override
  String get secureChatNeedsSyncBody =>
      'Sign in under Settings → Sync & account to invite people and chat. Messages are end-to-end encrypted on this device — the server only ever relays ciphertext.';

  @override
  String get secureChatHeading => 'Chat';

  @override
  String get secureChatNewChat => 'New chat';

  @override
  String get secureChatInviteSent => 'Invite sent.';

  @override
  String get secureChatNoChatsYet => 'No chats yet';

  @override
  String get secureChatNoChatsHint =>
      'Invite someone with their email and say hi.';

  @override
  String get secureChatWaitingForEncryption =>
      'Waiting for them to set up encryption…';

  @override
  String get secureChatNoMessagesYet => 'No messages yet';

  @override
  String get secureChatInvites => 'Invites';

  @override
  String secureChatWantsToChat(String email) {
    return '$email wants to chat';
  }

  @override
  String get secureChatSayHello => 'Say hello';

  @override
  String get secureChatMessagesEncrypted =>
      'Messages here are end-to-end encrypted.';

  @override
  String secureChatPeerNotReady(String email) {
    return '$email hasn\'t set up chat encryption on a device yet — you\'ll be able to message them once they do.';
  }

  @override
  String get secureChatMessageHint => 'Message…';

  @override
  String get secureChatCouldNotDecrypt => 'Could not decrypt this message.';

  @override
  String get secureChatEnterValidEmail => 'Enter a valid email address.';

  @override
  String get secureChatInviteTitle => 'Start an encrypted chat';

  @override
  String get secureChatInviteBody =>
      'They\'ll see the invite in Chat → Invites the next time they open Luma. Once accepted, every message is end-to-end encrypted — only the two of you can read them.';

  @override
  String get secureChatSendInvite => 'Send invite';

  @override
  String get serverTycoonAchFirstGrand => 'First Grand';

  @override
  String get serverTycoonAchFiveFigures => 'Five Figures';

  @override
  String get serverTycoonAchSixFigures => 'Six Figures';

  @override
  String get serverTycoonAchMillionaire => 'Data Center Millionaire';

  @override
  String get serverTycoonAchTrustedHost => 'Trusted Host';

  @override
  String get serverTycoonAchWellRegarded => 'Well Regarded';

  @override
  String get serverTycoonAchIndustryLeader => 'Industry Leader';

  @override
  String get serverTycoonAchPerfectReputation => 'Perfect Reputation';

  @override
  String get serverTycoonAchOneWeekIn => 'One Week In';

  @override
  String get serverTycoonAchOneMonthIn => 'One Month In';

  @override
  String get serverTycoonAchCenturyClub => 'Century Club';

  @override
  String get serverTycoonAchOldGuard => 'Old Guard';

  @override
  String get serverTycoonAchGigabitPipe => 'Gigabit Pipe';

  @override
  String get serverTycoonAchTenGigBackbone => '10-Gig Backbone';

  @override
  String get serverTycoonAchFirstDeal => 'First Deal';

  @override
  String get serverTycoonAchDealMaker => 'Deal Maker';

  @override
  String get serverTycoonAchContractMachine => 'Contract Machine';

  @override
  String get serverTycoonAchReliableHost => 'Reliable Host';

  @override
  String get serverTycoonAchRockSolid => 'Rock Solid';

  @override
  String get serverTycoonAchGrowingFleet => 'Growing Fleet';

  @override
  String get serverTycoonAchScaledUp => 'Scaled Up';

  @override
  String get serverTycoonAchMegaFleet => 'Mega Fleet';

  @override
  String get serverTycoonAchContractLegend => 'Contract Legend';

  @override
  String get serverTycoonAchBandwidthKing => 'Bandwidth King';

  @override
  String get serverTycoonAchUnbreakable => 'Unbreakable';

  @override
  String get serverTycoonAchPrestigeMaster => 'Prestige Master';

  @override
  String get serverTycoonAchTenMillion => 'Ten Million Club';

  @override
  String serverTycoonAchEarnTotalDesc(String amount) {
    return 'Earn a lifetime total of $amount.';
  }

  @override
  String serverTycoonAchReputationDesc(int count) {
    return 'Reach $count reputation.';
  }

  @override
  String serverTycoonAchSurviveDaysDesc(int count) {
    return 'Survive $count days in business.';
  }

  @override
  String serverTycoonAchBandwidthDesc(String amount) {
    return 'Serve $amount Mbps of bandwidth at once.';
  }

  @override
  String get serverTycoonAchFirstDealDesc => 'Complete your first contract.';

  @override
  String serverTycoonAchContractsDesc(int count) {
    return 'Complete $count contracts.';
  }

  @override
  String serverTycoonAchUptimeDesc(int count) {
    return 'Keep $count consecutive days of uptime with no overloads or contract failures.';
  }

  @override
  String serverTycoonAchRigsDesc(int count) {
    return 'Own $count rigs at once.';
  }

  @override
  String get serverTycoonAchRebirthDesc => 'Rebirth for the first time.';

  @override
  String serverTycoonAchPrestigeDesc(int count) {
    return 'Reach prestige level $count.';
  }

  @override
  String get serverTycoonBoostOverclockName => 'Overclock';

  @override
  String get serverTycoonBoostOverclockDescription =>
      'Push every rig 25% past spec. Costs you 30% more power and runs hotter.';

  @override
  String get serverTycoonBoostMarketingPushName => 'Marketing Push';

  @override
  String get serverTycoonBoostMarketingPushDescription =>
      'An ad spend that brings in an extra contract offer a day and 15% better payouts.';

  @override
  String get serverTycoonBoostColdSnapName => 'Cold Snap';

  @override
  String get serverTycoonBoostColdSnapDescription =>
      'Rented portable chillers give 20% more cooling headroom and steadier hardware.';

  @override
  String get serverTycoonBoostSurgePricingName => 'Surge Pricing';

  @override
  String get serverTycoonBoostSurgePricingDescription =>
      'Charge peak rates for two days: 35% more service income while it lasts.';

  @override
  String get serverTycoonCompanyBakeryBlurb =>
      'A family bakery that just wants its menu online without the site falling over.';

  @override
  String get serverTycoonCompanyPixelPalsBlurb =>
      'Indie game studio needing bot hosting for their community Discord.';

  @override
  String get serverTycoonCompanyStreamForgeBlurb =>
      'A streamer collective that needs rock-solid voice servers for podcast night.';

  @override
  String get serverTycoonCompanyNimbusSoftBlurb =>
      'A SaaS startup outsourcing their staging API environment to you.';

  @override
  String get serverTycoonCompanyDataVaultBlurb =>
      'Backup resellers hunting for cheap-but-reliable cloud storage capacity.';

  @override
  String get serverTycoonCompanyCraftedRealmsBlurb =>
      'A Minecraft community network renting overflow player slots.';

  @override
  String get serverTycoonCompanyQuantumQuarryBlurb =>
      'Data analytics firm that wants managed databases without the ops team.';

  @override
  String get serverTycoonCompanyAegisSecureBlurb =>
      'Privacy company reselling VPN endpoints under their own brand.';

  @override
  String get serverTycoonCompanyGlobexMediaBlurb =>
      'A media conglomerate that needs CDN edge capacity near its viewers.';

  @override
  String get serverTycoonCompanyHeliosAiBlurb =>
      'AI lab renting inference capacity while their own cluster is on backorder.';

  @override
  String get serverTycoonCompanyOmniCorpBlurb =>
      'Enterprise giant. Demanding, but the checks clear and they never bounce.';

  @override
  String get serverTycoonCompanyDockerHarborBlurb =>
      'A container-native startup that needs orchestration capacity while they build their own cluster.';

  @override
  String get serverTycoonCompanyCodeForgeDevOpsBlurb =>
      'A dev tools company outsourcing their CI/CD build farm and staging APIs.';

  @override
  String get serverTycoonCompanyMegacastNetworkBlurb =>
      'A podcast network needing low-latency voice and stream relay capacity for live events.';

  @override
  String get serverTycoonCompanyStreamVerseBlurb =>
      'A streaming platform that needs edge CDN capacity and relay nodes for viewer spikes.';

  @override
  String get serverTycoonCompanyNexusContainersBlurb =>
      'Enterprise container platform renting both orchestration and backing storage capacity.';

  @override
  String get serverTycoonCompanyOmnibuildCollectiveBlurb =>
      'A conglomerate of indie studios needing CI/CD runners, game servers, and monitoring.';

  @override
  String get serverTycoonCompanyTitanCloudBlurb =>
      'A hyperscale cloud provider leasing container, database, and AI capacity during expansion.';

  @override
  String get serverTycoonCoolerStockName => 'Stock CPU Cooler';

  @override
  String get serverTycoonCoolerCustomLoopName =>
      'Custom Loop - Dual 480mm Radiator';

  @override
  String get serverTycoonCoolerRackAirHandlerName =>
      'Rack-Mount Precision Air Handler';

  @override
  String get serverTycoonCoolerActiveArrayName => '4U Active Heatsink Array';

  @override
  String get serverTycoonCoolerRearDoorName => 'Rear-Door Heat Exchanger';

  @override
  String get serverTycoonCoolerImmersionName =>
      'Two-Phase Immersion Cooling Tank';

  @override
  String get serverTycoonCoolerChillerName =>
      'Industrial Datacenter Chiller Unit';

  @override
  String get serverTycoonCoolerNoNameHeatsinkName =>
      'No-Name Aluminum Heatsink';

  @override
  String get serverTycoonCoolerPassive1UName =>
      '1U Passive Heatsink w/ Chassis Airflow';

  @override
  String get serverTycoonCoolingTypeAir => 'Air';

  @override
  String get serverTycoonCoolingTypeCustomLoop => 'Custom loop';

  @override
  String get serverTycoonCoolingTypeIndustrial => 'Industrial';

  @override
  String get serverTycoonIncidentDdosName => 'DDoS Attack';

  @override
  String get serverTycoonIncidentDdosDescription =>
      'A flood of junk traffic is choking this router\'s bandwidth.';

  @override
  String get serverTycoonIncidentDdosAction => 'Mitigate';

  @override
  String get serverTycoonIncidentOverheatName => 'Overheat Spike';

  @override
  String get serverTycoonIncidentOverheatDescription =>
      'A sudden thermal spike is throttling this rig.';

  @override
  String get serverTycoonIncidentOverheatAction => 'Emergency Cooldown';

  @override
  String get serverTycoonIncidentDriveName => 'Drive Failure';

  @override
  String get serverTycoonIncidentDriveDescription =>
      'A drive in this rig just died. Replace it to restore full service.';

  @override
  String get serverTycoonIncidentDriveAction => 'Replace Drive';

  @override
  String get serverTycoonIncidentLeakName => 'Cooling Leak';

  @override
  String get serverTycoonIncidentLeakDescription =>
      'The water cooling loop on this rig is leaking, reducing its cooling capacity.';

  @override
  String get serverTycoonIncidentLeakAction => 'Repair';

  @override
  String get serverTycoonIncidentViralName => 'Viral Demand Spike';

  @override
  String get serverTycoonIncidentViralDescription =>
      'One of your services just went viral! Extra income for the rest of the day.';

  @override
  String get serverTycoonIncidentViralAction => 'Nice!';

  @override
  String serverTycoonPlanHome(String speed) {
    return 'Home Internet - $speed';
  }

  @override
  String serverTycoonPlanBusiness(String speed) {
    return 'Business Fiber - $speed';
  }

  @override
  String serverTycoonPlanDedicated(String speed) {
    return 'Dedicated Fiber - $speed';
  }

  @override
  String serverTycoonPlanColocation(String speed) {
    return 'Colocation Uplink - $speed';
  }

  @override
  String get serverTycoonLicenseGameHosting => 'Game Hosting License';

  @override
  String get serverTycoonLicenseGameHostingDesc =>
      'Legally host Minecraft and other game servers for paying customers.';

  @override
  String get serverTycoonLicenseCloudStorage => 'Cloud Storage License';

  @override
  String get serverTycoonLicenseCloudStorageDesc =>
      'Offer paid personal cloud storage and file hosting.';

  @override
  String get serverTycoonLicenseVpnHosting => 'VPN Hosting License';

  @override
  String get serverTycoonLicenseVpnHostingDesc =>
      'Operate a VPN endpoint service for customers.';

  @override
  String get serverTycoonLicenseCdnHosting => 'CDN Hosting License';

  @override
  String get serverTycoonLicenseCdnHostingDesc =>
      'Run a CDN edge caching node for website traffic.';

  @override
  String get serverTycoonLicenseEmailHosting => 'Email Hosting License';

  @override
  String get serverTycoonLicenseEmailHostingDesc =>
      'Host business email domains and mailboxes.';

  @override
  String get serverTycoonLicenseDatabaseHosting => 'Database Hosting License';

  @override
  String get serverTycoonLicenseDatabaseHostingDesc =>
      'Offer managed database instances to customers.';

  @override
  String get serverTycoonLicenseAiHosting => 'AI Hosting License';

  @override
  String get serverTycoonLicenseAiHostingDesc =>
      'Run AI inference workloads as a paid service.';

  @override
  String get serverTycoonLicenseEnterpriseHosting =>
      'Enterprise Hosting License';

  @override
  String get serverTycoonLicenseEnterpriseHostingDesc =>
      'Qualify for enterprise and government contracts.';

  @override
  String get serverTycoonLicenseContainerHosting => 'Container Hosting License';

  @override
  String get serverTycoonLicenseContainerHostingDesc =>
      'Legally operate Docker/Kubernetes container orchestration platforms for clients.';

  @override
  String get serverTycoonLicenseStreamingHosting => 'Streaming Hosting License';

  @override
  String get serverTycoonLicenseStreamingHostingDesc =>
      'Run video stream relay and transcoding infrastructure for content creators.';

  @override
  String get serverTycoonMissionProfitableDay => 'In the Black';

  @override
  String get serverTycoonMissionProfitableDayDesc => 'Bank a net profit today.';

  @override
  String get serverTycoonMissionBigDay => 'Payday';

  @override
  String get serverTycoonMissionBigDayDesc =>
      'Bank a serious net profit in a single day.';

  @override
  String get serverTycoonMissionExpandServices => 'Spin It Up';

  @override
  String get serverTycoonMissionExpandServicesDesc =>
      'Install 2 new services today.';

  @override
  String get serverTycoonMissionGoShopping => 'Parts Run';

  @override
  String get serverTycoonMissionGoShoppingDesc => 'Buy 3 components today.';

  @override
  String get serverTycoonMissionCloseAContract => 'Delivered';

  @override
  String get serverTycoonMissionCloseAContractDesc =>
      'Complete a company contract today.';

  @override
  String get serverTycoonMissionFirefighter => 'Firefighter';

  @override
  String get serverTycoonMissionFirefighterDesc => 'Resolve 2 incidents today.';

  @override
  String get serverTycoonMissionLabWork => 'Lab Work';

  @override
  String get serverTycoonMissionLabWorkDesc =>
      'Finish a research project today.';

  @override
  String get serverTycoonMissionPushTraffic => 'Traffic Spike';

  @override
  String get serverTycoonMissionPushTrafficDesc =>
      'Serve a sustained load of traffic today.';

  @override
  String get serverTycoonMissionCleanRun => 'Clean Run';

  @override
  String get serverTycoonMissionCleanRunDesc =>
      'Get through the day with nothing overloaded.';

  @override
  String get serverTycoonNicRealtekOnboard =>
      'Realtek Gigabit Ethernet (onboard)';

  @override
  String get serverTycoonNicGenericOnboard => 'Generic Fast Ethernet (onboard)';

  @override
  String get serverTycoonPsuRedundant2000 =>
      'Redundant Server PSU 2000W (dual)';

  @override
  String get serverTycoonPsuRedundant3000Titanium =>
      'Redundant Server PSU 3000W Titanium (dual)';

  @override
  String get serverTycoonPsuHyperscale5000 =>
      'Hyperscale Rack Bus PSU 5000W (N+1)';

  @override
  String get serverTycoonPsuGeneric300 => 'Generic OEM 300W';

  @override
  String get serverTycoonPsuRedundant1200 =>
      'Redundant Server PSU 1200W (dual)';

  @override
  String get serverTycoonRamGenericDdr3Gb8 => 'Generic DDR3 8GB 1600MHz';

  @override
  String get serverTycoonRamGenericDdr3Gb4 => 'Generic DDR3 4GB 1333MHz';

  @override
  String get serverTycoonResearchBranchLab => 'R&D Lab';

  @override
  String get serverTycoonResearchBranchCompute => 'Compute';

  @override
  String get serverTycoonResearchBranchStorage => 'Storage & Data';

  @override
  String get serverTycoonResearchBranchNetworking => 'Networking';

  @override
  String get serverTycoonResearchBranchPower => 'Power & Cooling';

  @override
  String get serverTycoonResearchBranchBusiness => 'Business';

  @override
  String get serverTycoonResearchHomeLab => 'Home Lab';

  @override
  String get serverTycoonResearchHomeLabDesc =>
      'A corner of the office set aside for testing. Adds 1.0 research point per day.';

  @override
  String get serverTycoonResearchResearchWing => 'Research Wing';

  @override
  String get serverTycoonResearchResearchWingDesc =>
      'A proper lab space with bench hardware. Adds 2.5 research points per day and a second queue slot.';

  @override
  String get serverTycoonResearchRndDivision => 'R&D Division';

  @override
  String get serverTycoonResearchRndDivisionDesc =>
      'A staffed research division. Adds 6.0 research points per day and a third queue slot.';

  @override
  String get serverTycoonResearchAutomatedTelemetry => 'Automated Telemetry';

  @override
  String get serverTycoonResearchAutomatedTelemetryDesc =>
      'Rigs report their own performance data, so your fleet keeps earning while the app is closed. Away earnings pay out 15% more.';

  @override
  String get serverTycoonResearchLightsOutOperations => 'Lights-Out Operations';

  @override
  String get serverTycoonResearchLightsOutOperationsDesc =>
      'The floor runs unattended overnight. Away earnings pay out a further 20% more.';

  @override
  String get serverTycoonResearchContinuousOptimization =>
      'Continuous Optimization';

  @override
  String get serverTycoonResearchContinuousOptimizationDesc =>
      'A standing programme of incremental tuning. Each level adds 2% to all service income, and it never runs out of levels.';

  @override
  String get serverTycoonResearchKernelTuning => 'Kernel Tuning';

  @override
  String get serverTycoonResearchKernelTuningDesc =>
      'Scheduler and IRQ tuning squeeze 8% more useful work out of every CPU.';

  @override
  String get serverTycoonResearchHypervisorOptimization =>
      'Hypervisor Optimization';

  @override
  String get serverTycoonResearchHypervisorOptimizationDesc =>
      'Paravirtualised drivers and CPU pinning cut virtualisation overhead for another 12% of CPU capacity.';

  @override
  String get serverTycoonResearchOverclockProfiles => 'Overclock Profiles';

  @override
  String get serverTycoonResearchOverclockProfilesDesc =>
      'Per-chip tuned clocks add 15% CPU capacity, at the price of 10% less cooling headroom.';

  @override
  String get serverTycoonResearchSiliconBinning => 'Silicon Binning';

  @override
  String get serverTycoonResearchSiliconBinningDesc =>
      'Hand-picked chips run cooler and faster: 18% more CPU capacity and 10% more cooling headroom.';

  @override
  String get serverTycoonResearchBlockDedup => 'Block Deduplication';

  @override
  String get serverTycoonResearchBlockDedupDesc =>
      'Identical blocks are stored once, cutting the storage every service needs by 10%.';

  @override
  String get serverTycoonResearchCompressionI => 'Inline Compression';

  @override
  String get serverTycoonResearchCompressionIDesc =>
      'Compress data on the way to disk for another 12% off storage requirements.';

  @override
  String get serverTycoonResearchCompressionIi => 'Adaptive Compression';

  @override
  String get serverTycoonResearchCompressionIiDesc =>
      'Per-workload compression algorithms shave a further 15% off storage requirements.';

  @override
  String get serverTycoonResearchTieredCaching => 'Tiered Caching';

  @override
  String get serverTycoonResearchTieredCachingDesc =>
      'Hot data is served from RAM and NVMe, lifting customer satisfaction by 5%.';

  @override
  String get serverTycoonResearchMeshNetworking => 'Mesh Networking';

  @override
  String get serverTycoonResearchMeshNetworkingDesc =>
      'Learn to run a second router so rigs can be split across separate ISP connections.';

  @override
  String get serverTycoonResearchPacketShaping => 'Packet Shaping';

  @override
  String get serverTycoonResearchPacketShapingDesc =>
      'Smarter queuing trims 10% off the bandwidth every service consumes.';

  @override
  String get serverTycoonResearchBackboneRouting => 'Backbone Routing';

  @override
  String get serverTycoonResearchBackboneRoutingDesc =>
      'Advanced routing tables support a third router on the network.';

  @override
  String get serverTycoonResearchQosPrioritization => 'QoS Prioritization';

  @override
  String get serverTycoonResearchQosPrioritizationDesc =>
      'Latency-sensitive traffic goes first, lifting customer satisfaction by 4%.';

  @override
  String get serverTycoonResearchFiberBackhaul => 'Fiber Backhaul';

  @override
  String get serverTycoonResearchFiberBackhaulDesc =>
      'Dedicated backhaul lets you operate up to five routers total.';

  @override
  String get serverTycoonResearchAnycastEdge => 'Anycast Edge';

  @override
  String get serverTycoonResearchAnycastEdgeDesc =>
      'Traffic lands at the nearest edge node, cutting bandwidth needs by a further 15%.';

  @override
  String get serverTycoonResearchHyperscaleNetworking =>
      'Hyperscale Networking';

  @override
  String get serverTycoonResearchHyperscaleNetworkingDesc =>
      'Software-defined networking lets you operate up to eight routers total.';

  @override
  String get serverTycoonResearchPowerTuning => 'Power Tuning';

  @override
  String get serverTycoonResearchPowerTuningDesc =>
      'Undervolting and smarter fan curves cut your electricity bill by 10%.';

  @override
  String get serverTycoonResearchLiquidCoolingI => 'Liquid Cooling Research';

  @override
  String get serverTycoonResearchLiquidCoolingIDesc =>
      'In-house loop designs give every rig 12% more cooling headroom.';

  @override
  String get serverTycoonResearchSmartPdu => 'Smart Power Distribution';

  @override
  String get serverTycoonResearchSmartPduDesc =>
      'Rack-grade PDUs shave another 15% off the power bill.';

  @override
  String get serverTycoonResearchLiquidCoolingIi => 'Direct-to-Chip Cooling';

  @override
  String get serverTycoonResearchLiquidCoolingIiDesc =>
      'Cold plates straight onto the die add a further 15% cooling headroom.';

  @override
  String get serverTycoonResearchRenewableEnergy =>
      'Renewable Energy Contracts';

  @override
  String get serverTycoonResearchRenewableEnergyDesc =>
      'Solar and wind PPAs slash your electricity bill by another 15%.';

  @override
  String get serverTycoonResearchImmersionCooling => 'Immersion Cooling';

  @override
  String get serverTycoonResearchImmersionCoolingDesc =>
      'Whole rigs submerged in dielectric fluid: 25% more cooling headroom and far steadier temperatures.';

  @override
  String get serverTycoonResearchWasteHeatRecovery => 'Waste Heat Recovery';

  @override
  String get serverTycoonResearchWasteHeatRecoveryDesc =>
      'Sell your exhaust heat to the district network for another 12% off the power bill.';

  @override
  String get serverTycoonResearchBulkPurchasing => 'Bulk Purchasing';

  @override
  String get serverTycoonResearchBulkPurchasingDesc =>
      'Supplier deals knock 20% off the price of every new rig.';

  @override
  String get serverTycoonResearchSalesTeam => 'Sales Team';

  @override
  String get serverTycoonResearchSalesTeamDesc =>
      'A part-time sales rep lets you juggle one more company contract at a time.';

  @override
  String get serverTycoonResearchRunbookAutomation => 'Runbook Automation';

  @override
  String get serverTycoonResearchRunbookAutomationDesc =>
      'Documented, automated responses mean 20% fewer incidents reach you at all.';

  @override
  String get serverTycoonResearchSupplyChainOptimization =>
      'Supply Chain Optimization';

  @override
  String get serverTycoonResearchSupplyChainOptimizationDesc =>
      'Streamlined procurement knocks an additional 15% off every new rig.';

  @override
  String get serverTycoonResearchAccountManagers => 'Account Managers';

  @override
  String get serverTycoonResearchAccountManagersDesc =>
      'Dedicated account managers handle two additional simultaneous contracts.';

  @override
  String get serverTycoonResearchReputationManagement =>
      'Reputation Management';

  @override
  String get serverTycoonResearchReputationManagementDesc =>
      'Public status pages and proactive comms lift customer satisfaction by 4%.';

  @override
  String get serverTycoonResearchPremiumSlas => 'Premium SLAs';

  @override
  String get serverTycoonResearchPremiumSlasDesc =>
      'Guaranteed uptime tiers customers will pay for: 8% more income from every service.';

  @override
  String get serverTycoonResearchEnterpriseSales => 'Enterprise Sales Division';

  @override
  String get serverTycoonResearchEnterpriseSalesDesc =>
      'A dedicated enterprise sales team lets you manage one more contract simultaneously.';

  @override
  String get serverTycoonResearchAutoRenewal => 'Auto-Renewal Contracts';

  @override
  String get serverTycoonResearchAutoRenewalDesc =>
      'Customers roll over by default, adding 12% to all service income.';

  @override
  String get serverTycoonServiceDiscordBotName => 'Discord Bot';

  @override
  String get serverTycoonServiceDiscordBotDesc =>
      'Lightweight bots for Discord communities. Barely touches CPU or bandwidth.';

  @override
  String get serverTycoonServiceDiscordBotCapacity => 'bot instance';

  @override
  String get serverTycoonServiceStaticWebsiteName => 'Static Website';

  @override
  String get serverTycoonServiceStaticWebsiteDesc =>
      'HTML/CSS sites with no backend. Cheap to run at any scale.';

  @override
  String get serverTycoonServiceStaticWebsiteCapacity => '1k monthly visitors';

  @override
  String get serverTycoonServiceDynamicWebsiteApiName =>
      'Dynamic Website / API';

  @override
  String get serverTycoonServiceDynamicWebsiteApiDesc =>
      'Server-rendered sites and API endpoints. Needs real CPU and RAM.';

  @override
  String get serverTycoonServiceDynamicWebsiteApiCapacity => 'request tier';

  @override
  String get serverTycoonServiceMonitoringServerName => 'Monitoring Server';

  @override
  String get serverTycoonServiceMonitoringServerDesc =>
      'Uptime and metrics monitoring for other people\'s infrastructure.';

  @override
  String get serverTycoonServiceMonitoringServerCapacity => 'monitored host';

  @override
  String get serverTycoonServiceVoiceServerName => 'Voice Server';

  @override
  String get serverTycoonServiceVoiceServerDesc =>
      'Low-latency voice chat hosting (TeamSpeak/Mumble-style).';

  @override
  String get serverTycoonServiceVoiceServerCapacity => 'concurrent voice user';

  @override
  String get serverTycoonServiceMinecraftServerName => 'Minecraft Server';

  @override
  String get serverTycoonServiceMinecraftServerDesc =>
      'Heavy CPU, moderate RAM/storage/network. Latency-sensitive.';

  @override
  String get serverTycoonServiceMinecraftServerCapacity => 'player slot';

  @override
  String get serverTycoonServiceGenericGameServerName =>
      'Game Server (Survival/Sandbox)';

  @override
  String get serverTycoonServiceGenericGameServerDesc =>
      'Rust/Valheim-style dedicated servers. Heavier than Minecraft per slot.';

  @override
  String get serverTycoonServiceGenericGameServerCapacity => 'player slot';

  @override
  String get serverTycoonServiceCloudStorageName => 'Cloud Storage';

  @override
  String get serverTycoonServiceCloudStorageDesc =>
      'Personal cloud storage and file hosting. Storage-hungry, not CPU-hungry.';

  @override
  String get serverTycoonServiceCloudStorageCapacity =>
      'storage customer (~50GB)';

  @override
  String get serverTycoonServiceVpnProviderName => 'VPN Provider';

  @override
  String get serverTycoonServiceVpnProviderDesc =>
      'Encrypted tunnel endpoints for privacy-focused customers.';

  @override
  String get serverTycoonServiceVpnProviderCapacity => 'concurrent VPN user';

  @override
  String get serverTycoonServiceCdnEdgeName => 'CDN Edge Node';

  @override
  String get serverTycoonServiceCdnEdgeDesc =>
      'Caches and serves other sites\' static assets close to their users.';

  @override
  String get serverTycoonServiceCdnEdgeCapacity => 'cache tier (~100GB/day)';

  @override
  String get serverTycoonServiceEmailHostingName => 'Email Hosting';

  @override
  String get serverTycoonServiceEmailHostingDesc =>
      'Business email domains and mailboxes. Light load, steady income.';

  @override
  String get serverTycoonServiceEmailHostingCapacity => 'mailbox';

  @override
  String get serverTycoonServiceDatabaseHostingName => 'Database Hosting';

  @override
  String get serverTycoonServiceDatabaseHostingDesc =>
      'Managed database instances for other businesses.';

  @override
  String get serverTycoonServiceDatabaseHostingCapacity => 'database instance';

  @override
  String get serverTycoonServiceAiInferenceName => 'AI Inference Hosting';

  @override
  String get serverTycoonServiceAiInferenceDesc =>
      'CPU-driven inference workloads. Extremely CPU/RAM hungry.';

  @override
  String get serverTycoonServiceAiInferenceCapacity => 'inference request tier';

  @override
  String get serverTycoonServiceContainerHostingName => 'Container Hosting';

  @override
  String get serverTycoonServiceContainerHostingDesc =>
      'Docker/Kubernetes container orchestration. Balanced CPU, RAM, and storage load.';

  @override
  String get serverTycoonServiceContainerHostingCapacity => 'container pod';

  @override
  String get serverTycoonServiceStreamingRelayName => 'Streaming Relay';

  @override
  String get serverTycoonServiceStreamingRelayDesc =>
      'Video stream relay and transcoding nodes. Extremely bandwidth-hungry.';

  @override
  String get serverTycoonServiceStreamingRelayCapacity =>
      'stream relay (~500 viewers)';

  @override
  String get serverTycoonServiceCiCdRunnerName => 'CI/CD Pipeline Runner';

  @override
  String get serverTycoonServiceCiCdRunnerDesc =>
      'Hosted build and deployment runners. Bursty CPU with heavy storage I/O.';

  @override
  String get serverTycoonServiceCiCdRunnerCapacity =>
      'concurrent build pipeline';

  @override
  String get serverTycoonServiceCategoryAutomation => 'Automation';

  @override
  String get serverTycoonServiceCategoryWeb => 'Web';

  @override
  String get serverTycoonServiceCategoryOps => 'Ops';

  @override
  String get serverTycoonServiceCategoryCommunication => 'Communication';

  @override
  String get serverTycoonServiceCategoryGameHosting => 'Game Hosting';

  @override
  String get serverTycoonServiceCategoryStorage => 'Storage';

  @override
  String get serverTycoonServiceCategoryNetwork => 'Network';

  @override
  String get serverTycoonServiceCategoryData => 'Data';

  @override
  String get serverTycoonServiceCategoryAi => 'AI';

  @override
  String get serverTycoonServiceCategoryCloud => 'Cloud';

  @override
  String get serverTycoonServiceCategoryMedia => 'Media';

  @override
  String get serverTycoonServiceCategoryDevops => 'DevOps';

  @override
  String get serverTycoonStaffSysadminName => 'Jordan the Sysadmin';

  @override
  String get serverTycoonStaffSysadminDesc =>
      'Quietly resolves minor incidents (overheating, cooling leaks, DDoS) before they cost you anything.';

  @override
  String get serverTycoonStaffElectricianName => 'Sam the Electrician';

  @override
  String get serverTycoonStaffElectricianDesc =>
      'Keeps your wiring and PDUs efficient, shaving an extra 8% off your electricity bill.';

  @override
  String get serverTycoonStaffSalesRepName => 'Casey the Sales Rep';

  @override
  String get serverTycoonStaffSalesRepDesc =>
      'Drums up an extra contract offer each day and negotiates better payouts.';

  @override
  String get serverTycoonStaffSysadminSeniorName => 'Riley the Senior Sysadmin';

  @override
  String get serverTycoonStaffSysadminSeniorDesc =>
      'A seasoned ops veteran who resolves incidents with near-certainty. Stacks with Jordan.';

  @override
  String get serverTycoonStaffElectricianMasterName =>
      'Drew the Master Electrician';

  @override
  String get serverTycoonStaffElectricianMasterDesc =>
      'A licensed industrial electrician who cuts another 12% off your power bill. Stacks with Sam.';

  @override
  String get serverTycoonStaffSalesDirectorName => 'Morgan the Sales Director';

  @override
  String get serverTycoonStaffSalesDirectorDesc =>
      'A well-connected director who brings another daily offer and negotiates even harder. Stacks with Casey.';

  @override
  String get serverTycoonDriveGeneric500gbHdd => 'Generic 500GB HDD';

  @override
  String get serverTycoonDriveWdRed4tbNasHdd => 'WD Red 4TB NAS HDD';

  @override
  String get serverTycoonDriveEnterpriseSsd8tb => 'Enterprise NVMe U.2 8TB';

  @override
  String get serverTycoonDriveToshibaMg10Hdd =>
      'Toshiba MG10 20TB Enterprise HDD';

  @override
  String get serverTycoonDriveWdGold24tbHdd => 'WD Gold 24TB Enterprise HDD';

  @override
  String get serverTycoonDriveKioxiaCm7Nvme =>
      'Kioxia CM7-R 15.36TB Enterprise NVMe';

  @override
  String get serverTycoonDriveMicron9400Nvme =>
      'Micron 9400 Pro 30.72TB Enterprise NVMe';

  @override
  String get serverTycoonDriveSolidigmD5Nvme =>
      'Solidigm D5-P5336 61.44TB Enterprise NVMe';

  @override
  String get serverTycoonDriveGeneric128gbSsd => 'Generic 128GB SATA SSD';

  @override
  String get serverTycoonGradeServer => 'server';

  @override
  String get serverTycoonGradePc => 'PC';

  @override
  String serverTycoonBuildPartGradeMismatch(
    String part,
    String grade,
    String rig,
  ) {
    return '$part is $grade hardware and does not fit a $rig rig';
  }

  @override
  String serverTycoonBuildUnknownCpu(String id) {
    return 'Unknown CPU: $id';
  }

  @override
  String serverTycoonBuildUnknownMotherboard(String id) {
    return 'Unknown motherboard: $id';
  }

  @override
  String serverTycoonBuildSocketMismatch(
    String cpu,
    String cpuSocket,
    String board,
    String boardSocket,
  ) {
    return '$cpu is socket $cpuSocket, $board needs $boardSocket';
  }

  @override
  String serverTycoonBuildRamSlotsExceeded(
    String board,
    int slots,
    int sticks,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      slots,
      locale: localeName,
      other: '$slots RAM slots',
      one: '1 RAM slot',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sticks,
      locale: localeName,
      other: '$sticks sticks',
      one: '1 stick',
    );
    return '$board only has $_temp0, $_temp1 installed';
  }

  @override
  String serverTycoonBuildRamTypeMismatch(
    String stick,
    String stickType,
    String board,
    String boardType,
  ) {
    return '$stick is $stickType, $board requires $boardType';
  }

  @override
  String serverTycoonBuildEccUnsupported(String board, String stick) {
    return '$board does not support registered/ECC memory ($stick)';
  }

  @override
  String serverTycoonBuildRamCapExceeded(
    String board,
    int maxGb,
    int installedGb,
  ) {
    return '$board supports up to ${maxGb}GB RAM, ${installedGb}GB installed';
  }

  @override
  String serverTycoonBuildUnknownRam(String id) {
    return 'Unknown RAM stick: $id';
  }

  @override
  String serverTycoonBuildUnknownDrive(String id) {
    return 'Unknown drive: $id';
  }

  @override
  String serverTycoonBuildSataExceeded(String board, int ports, int drives) {
    String _temp0 = intl.Intl.pluralLogic(
      ports,
      locale: localeName,
      other: '$ports SATA ports',
      one: '1 SATA port',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drives,
      locale: localeName,
      other: '$drives drives need one',
      one: '1 drive needs one',
    );
    return '$board only has $_temp0, $_temp1';
  }

  @override
  String serverTycoonBuildM2Exceeded(String board, int slots, int drives) {
    String _temp0 = intl.Intl.pluralLogic(
      slots,
      locale: localeName,
      other: '$slots M.2 slots',
      one: '1 M.2 slot',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drives,
      locale: localeName,
      other: '$drives NVMe drives',
      one: '1 NVMe drive',
    );
    return '$board only has $_temp0, $_temp1 installed';
  }

  @override
  String serverTycoonBuildPowerExceeded(
    int watts,
    String psu,
    int ratingWatts,
  ) {
    return 'Estimated max draw ${watts}W exceeds the $psu rating of ${ratingWatts}W';
  }

  @override
  String serverTycoonDay(int day) {
    return 'Day $day';
  }

  @override
  String get serverTycoonNextDay => 'Next Day';

  @override
  String serverTycoonNextDayIn(int seconds) {
    return 'Next day in ${seconds}s';
  }

  @override
  String get serverTycoonResume => 'Resume';

  @override
  String get serverTycoonPause => 'Pause';

  @override
  String get serverTycoonBuild => 'Build';

  @override
  String get serverTycoonShop => 'Shop';

  @override
  String get serverTycoonContracts => 'Contracts';

  @override
  String get serverTycoonResearch => 'Research';

  @override
  String get serverTycoonMore => 'More';

  @override
  String get serverTycoonFitToView => 'Fit to view';

  @override
  String get serverTycoonAutoArrange => 'Auto-arrange';

  @override
  String get serverTycoonPhoneHint => 'Tap to inspect · hold to move';

  @override
  String get serverTycoonServerRig => 'Server Rig';

  @override
  String get serverTycoonPcRig => 'PC Rig';

  @override
  String get serverTycoonIncompatibleHardware =>
      'INCOMPATIBLE HARDWARE -- EARNING \$0/DAY';

  @override
  String serverTycoonDiskSpeed(String speed) {
    return 'Disk speed ($speed MB/s)';
  }

  @override
  String serverTycoonThermalThrottling(String percent) {
    return 'THERMAL THROTTLING: $percent% capacity';
  }

  @override
  String get serverTycoonStorage => 'Storage';

  @override
  String get serverTycoonHardware => 'Hardware';

  @override
  String get serverTycoonMotherboard => 'Motherboard';

  @override
  String get serverTycoonCooling => 'Cooling';

  @override
  String serverTycoonStorageGb(String gb) {
    return 'Storage (${gb}GB)';
  }

  @override
  String get serverTycoonAdd => '+ Add';

  @override
  String get serverTycoonServices => 'Services';

  @override
  String get serverTycoonNothingPluggedIn =>
      'Nothing plugged in — drag a service node onto this rig.';

  @override
  String get serverTycoonInstallService => 'Install Service';

  @override
  String get serverTycoonNetwork => 'Network';

  @override
  String get serverTycoonNotConnected => 'Not connected';

  @override
  String get serverTycoonNoFixNeeded => 'No fix needed';

  @override
  String serverTycoonFixWith(String name) {
    return 'Fix: $name';
  }

  @override
  String get serverTycoonClone => 'Clone';

  @override
  String get serverTycoonService => 'Service';

  @override
  String get serverTycoonServiceNotPluggedIn =>
      'Not plugged in — drag this node\'s port onto a rig.';

  @override
  String serverTycoonRunningOn(String name) {
    return 'Running on $name';
  }

  @override
  String get serverTycoonCapacity => 'Capacity';

  @override
  String serverTycoonMoneyPerDay(String amount) {
    return '$amount/day';
  }

  @override
  String get serverTycoonIncome => 'Income';

  @override
  String get serverTycoonSatisfaction => 'Satisfaction';

  @override
  String get serverTycoonBottleneck => 'Bottleneck';

  @override
  String get serverTycoonUnplug => 'Unplug';

  @override
  String get serverTycoonDeleteService => 'Delete service';

  @override
  String get serverTycoonRouter => 'Router';

  @override
  String get serverTycoonUpgradeToNextPlan => 'Upgrade to next plan';

  @override
  String get serverTycoonInternetPlan => 'Internet Plan';

  @override
  String serverTycoonLatencyMs(String ms) {
    return 'Latency: ${ms}ms';
  }

  @override
  String serverTycoonMonthlyPrice(String price) {
    return 'Monthly: $price';
  }

  @override
  String get serverTycoonUpgradePlan => 'Upgrade Plan';

  @override
  String get serverTycoonSelect => 'Select';

  @override
  String get serverTycoonConnectedRigs => 'Connected Rigs';

  @override
  String get serverTycoonPcRigTool => 'PC Rig';

  @override
  String get serverTycoonServerTool => 'Server';

  @override
  String get serverTycoonServiceTool => 'Service';

  @override
  String get serverTycoonResearchTool => 'Research';

  @override
  String get serverTycoonContractsTool => 'Contracts';

  @override
  String get serverTycoonGoals => 'Goals';

  @override
  String get serverTycoonBoosts => 'Boosts';

  @override
  String get serverTycoonLicenses => 'Licenses';

  @override
  String get serverTycoonAchievements => 'Achievements';

  @override
  String get serverTycoonStaff => 'Staff';

  @override
  String get serverTycoonStats => 'Stats';

  @override
  String get serverTycoonAutoAdvanceDays => 'Auto-advance days';

  @override
  String get serverTycoonScaleUp => 'Scale Up';

  @override
  String get serverTycoonReset => 'Reset';

  @override
  String get serverTycoonChange => 'Change';

  @override
  String serverTycoonSatisfactionPercent(String percent) {
    return '$percent% sat';
  }

  @override
  String serverTycoonBottleneckValue(String value) {
    return 'Bottleneck: $value';
  }

  @override
  String get serverTycoonSet => 'Set';

  @override
  String get serverTycoonResetGameTitle => 'Reset Game?';

  @override
  String get serverTycoonResetGameBody =>
      'All progress will be lost. This cannot be undone.';

  @override
  String serverTycoonScaleUpTitle(String tier) {
    return 'Scale Up to $tier?';
  }

  @override
  String serverTycoonScaleUpBody(String multiplier) {
    return 'You will keep: prestige tier, lifetime income multiplier (now ${multiplier}x), achievements, and your lifetime earnings record.\n\nYou will lose: all rigs, routers, staff, research, licenses, active contracts, inventory, current cash, reputation, and day count -- you restart from Day 0 with \$250.';
  }

  @override
  String serverTycoonAddSlot(String slot) {
    return 'Add $slot';
  }

  @override
  String serverTycoonSwapSlot(String slot) {
    return 'Swap $slot';
  }

  @override
  String serverTycoonInInventory(int count) {
    return 'In inventory x$count';
  }

  @override
  String get serverTycoonConsumerHardware => 'Consumer hardware';

  @override
  String get serverTycoonServerHardware => 'Server hardware';

  @override
  String get serverTycoonInstall => 'Install';

  @override
  String get serverTycoonBuy => 'Buy';

  @override
  String get serverTycoonSwap => 'Swap';

  @override
  String serverTycoonBuildPcRigSub(String price) {
    return '$price • a cheap box to start on';
  }

  @override
  String serverTycoonBuildServerRigSub(String price) {
    return '$price • takes server-grade parts';
  }

  @override
  String serverTycoonBuildRouterSub(String price, String used, String max) {
    return '$price • $used/$max in use';
  }

  @override
  String get serverTycoonBuildServiceSub =>
      'Drops a service node on the canvas for you to wire up';

  @override
  String get serverTycoonAutoArrangeSub =>
      'Lay the whole graph out: routers, rigs, then their services';

  @override
  String get serverTycoonAutoAdvanceSub =>
      'Roll straight into the next day instead of tapping through the report';

  @override
  String get serverTycoonDailyGoals => 'Daily goals';

  @override
  String serverTycoonDailyGoalsSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count still open today',
      zero: 'All done for today',
    );
    return '$_temp0';
  }

  @override
  String serverTycoonBoostsSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count running',
      zero: 'None running',
    );
    return '$_temp0';
  }

  @override
  String get serverTycoonStatsSub => 'Income and power history';

  @override
  String serverTycoonLicensesHeld(int count) {
    return '$count held';
  }

  @override
  String serverTycoonStaffHired(int count) {
    return '$count hired';
  }

  @override
  String serverTycoonAchievementsUnlocked(int count) {
    return '$count unlocked';
  }

  @override
  String get serverTycoonScaleUpSub =>
      'Restart bigger with a permanent income multiplier';

  @override
  String get serverTycoonResetGame => 'Reset game';

  @override
  String get serverTycoonResetGameSub => 'Start over from day zero';

  @override
  String get serverTycoonCatMotherboards => 'Motherboards';

  @override
  String serverTycoonOwnedCount(int count) {
    return 'Owned x$count';
  }

  @override
  String get serverTycoonLocked => 'Locked';

  @override
  String get serverTycoonBadgeServer => 'SERVER';

  @override
  String serverTycoonServiceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count services',
      one: '1 service',
    );
    return '$_temp0';
  }

  @override
  String serverTycoonServiceCountNoRouter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count services · no router',
      one: '1 service · no router',
    );
    return '$_temp0';
  }

  @override
  String get serverTycoonIncompatible => 'Incompatible';

  @override
  String serverTycoonRigCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rigs',
      one: '1 rig',
    );
    return '$_temp0';
  }

  @override
  String serverTycoonServiceNodeStats(
    String capacity,
    String unit,
    String income,
  ) {
    return '$capacity $unit · $income';
  }

  @override
  String get serverTycoonNotPluggedIn => 'Not plugged in';

  @override
  String get serverTycoonNoOffersToday =>
      'No offers today — build reputation and buy licenses to attract companies.';

  @override
  String get serverTycoonActive => 'Active';

  @override
  String get serverTycoonTodaysOffers => 'Today\'s Offers';

  @override
  String get serverTycoonAccept => 'Accept';

  @override
  String get serverTycoonFull => 'Full';

  @override
  String get serverTycoonErrorGeneric => 'Error';

  @override
  String serverTycoonOfferSubtitle(
    String capacity,
    String unit,
    int days,
    String payout,
    String bonus,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$capacity $unit • $_temp0 • $payout + $bonus bonus';
  }

  @override
  String serverTycoonDaysLeft(int count) {
    return '${count}d left';
  }

  @override
  String serverTycoonContractNeeds(
    String capacity,
    String unit,
    String payout,
  ) {
    return 'Needs $capacity $unit served • $payout';
  }

  @override
  String serverTycoonResearchIdle(String rate) {
    return 'Nothing in the lab — earning $rate RP/day';
  }

  @override
  String serverTycoonResearchingValue(String name) {
    return 'Researching: $name';
  }

  @override
  String serverTycoonResearchProgress(
    String accrued,
    String needed,
    String rate,
  ) {
    return '$accrued / $needed RP · $rate/day';
  }

  @override
  String serverTycoonQueuedCount(int count) {
    return '$count queued';
  }

  @override
  String serverTycoonTier(int tier) {
    return 'Tier $tier';
  }

  @override
  String serverTycoonResearchLevel(int level) {
    return 'Level $level — repeatable';
  }

  @override
  String get serverTycoonResearched => 'Researched';

  @override
  String get serverTycoonCancelResearch => 'Cancel (50% back)';

  @override
  String get serverTycoonRemoveFromQueue => 'Remove from queue';

  @override
  String serverTycoonResearchCostDays(String cost, String days) {
    return '$cost · ~${days}d';
  }

  @override
  String serverTycoonNeedsResearch(String projects) {
    return 'Needs $projects';
  }

  @override
  String serverTycoonNeedsReputation(String reputation) {
    return 'Needs $reputation reputation';
  }

  @override
  String serverTycoonLicenseSubtitle(String description, String reputation) {
    return '$description\nRequires $reputation rep';
  }

  @override
  String get serverTycoonHired => 'HIRED';

  @override
  String serverTycoonSalary(String amount) {
    return 'Salary: $amount';
  }

  @override
  String get serverTycoonRequirementsNotMet => 'Requirements not met';

  @override
  String get serverTycoonFire => 'Fire';

  @override
  String serverTycoonHire(String amount) {
    return 'Hire $amount';
  }

  @override
  String get serverTycoonIncidentMitigate => 'Mitigate';

  @override
  String get serverTycoonIncidentCooldown => 'Cooldown';

  @override
  String get serverTycoonIncidentRepair => 'Repair';

  @override
  String get serverTycoonIncidentReplaceDrive => 'Replace Drive';

  @override
  String get serverTycoonIncidentNice => 'Nice!';

  @override
  String get serverTycoonIgnore => 'Ignore';

  @override
  String get serverTycoonAchievementUnlocked => 'Achievement Unlocked';

  @override
  String get serverTycoonContractIncome => 'Contract Income';

  @override
  String get serverTycoonElectricity => 'Electricity';

  @override
  String get serverTycoonInternet => 'Internet';

  @override
  String get serverTycoonStaffSalaries => 'Staff Salaries';

  @override
  String get serverTycoonNetProfit => 'Net Profit';

  @override
  String get serverTycoonAvgSatisfaction => 'Avg Satisfaction';

  @override
  String get serverTycoonReputation => 'Reputation';

  @override
  String get serverTycoonContractEvents => 'Contract Events';

  @override
  String get serverTycoonGoalsCompleted => 'Goals Completed';

  @override
  String get serverTycoonContinue => 'Continue';

  @override
  String get serverTycoonDayReportFailedWord => 'FAILED';

  @override
  String get serverTycoonGoalsIntro =>
      'A fresh board is rolled every day. Rewards are paid the moment a goal is met.';

  @override
  String get serverTycoonNoGoalsToday => 'No goals today.';

  @override
  String serverTycoonGoalProgressReward(
    String progress,
    String target,
    String rep,
  ) {
    return '$progress / $target · +$rep rep';
  }

  @override
  String serverTycoonBoostExtend(String cost, String days) {
    return 'Extend — $cost for $days days';
  }

  @override
  String serverTycoonBoostActivate(String cost, String days) {
    return 'Activate — $cost for $days days';
  }

  @override
  String serverTycoonNetProfitLastDays(int count) {
    return 'Net profit — last $count days';
  }

  @override
  String serverTycoonPowerDrawLastDays(int count) {
    return 'Power draw — last $count days';
  }

  @override
  String get serverTycoonBestWorst => 'Best & worst';

  @override
  String get serverTycoonBestDay => 'Best day';

  @override
  String get serverTycoonWorstDay => 'Worst day';

  @override
  String serverTycoonDayAmount(int day, String amount) {
    return 'Day $day · $amount';
  }

  @override
  String get serverTycoonIncomeByService => 'Income by service';

  @override
  String get serverTycoonLifetimeEarned => 'Lifetime earned';

  @override
  String get serverTycoonDaysRun => 'Days run';

  @override
  String get serverTycoonUptimeStreak => 'Uptime streak';

  @override
  String serverTycoonUptimeDays(int count) {
    return '${count}d';
  }

  @override
  String get serverTycoonPeakBandwidth => 'Peak bandwidth';

  @override
  String get serverTycoonPeakPower => 'Peak power';

  @override
  String get serverTycoonContractsDone => 'Contracts done';

  @override
  String get serverTycoonResearchDone => 'Research done';

  @override
  String get serverTycoonResearchRate => 'Research rate';

  @override
  String serverTycoonResearchRateValue(String rate) {
    return '$rate RP/day';
  }

  @override
  String get serverTycoonRigs => 'Rigs';

  @override
  String get serverTycoonAwayRate => 'Away rate';

  @override
  String get serverTycoonNotEnoughDays => 'Not enough days yet';

  @override
  String get serverTycoonWhileYouWereAway => 'While you were away';

  @override
  String serverTycoonAwayFor(String duration, int days, String rate) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return 'Away for $duration — $_temp0 simulated at $rate% rate.';
  }

  @override
  String serverTycoonAwayCapped(int maxDays, int elapsed) {
    return 'Capped at $maxDays days — $elapsed had passed. Research the R&D Lab branch to earn more while away.';
  }

  @override
  String get serverTycoonRunningCosts => 'Running costs';

  @override
  String get serverTycoonResearchPoints => 'Research points';

  @override
  String get serverTycoonWhatHappened => 'What happened';

  @override
  String get serverTycoonBackToWork => 'Back to work';

  @override
  String serverTycoonDurationDaysHours(int days, int hours) {
    return '${days}d ${hours}h';
  }

  @override
  String serverTycoonDurationHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String serverTycoonDurationMinutes(int minutes) {
    return '${minutes}m';
  }

  @override
  String get serverTycoonEccOk => 'ECC ok';

  @override
  String serverTycoonSpecRamSlots(int slots, String maxGb) {
    return '$slots RAM slots, max ${maxGb}GB';
  }

  @override
  String serverTycoonSpecSata(String sata, String m2) {
    return '$sata SATA, $m2 M.2';
  }

  @override
  String get serverTycoonSpecRegistered => 'registered';

  @override
  String get serverTycoonSpecWaterLoop => 'water loop';

  @override
  String get serverTycoonSpecCooling => 'cooling';

  @override
  String serverTycoonReqCpuSocket(String socket) {
    return 'This board needs a $socket CPU';
  }

  @override
  String serverTycoonReqBoardSocket(String cpu, String socket) {
    return 'Your $cpu needs a $socket board';
  }

  @override
  String serverTycoonReqRam(
    String type,
    int used,
    int slots,
    String maxGb,
    String ecc,
  ) {
    return 'Takes $type · $used/$slots slots used, max ${maxGb}GB$ecc';
  }

  @override
  String get serverTycoonReqNoEcc => ', no registered/ECC';

  @override
  String serverTycoonReqPorts(int sata, int sataMax, int m2, int m2Max) {
    return 'SATA ports $sata/$sataMax · M.2 slots $m2/$m2Max used';
  }

  @override
  String serverTycoonReqPower(String watts) {
    return 'This build draws up to ${watts}W';
  }

  @override
  String serverTycoonReqHeat(String cpu, String watts) {
    return 'Your $cpu puts out ${watts}W of heat';
  }

  @override
  String serverTycoonRepoResearchCompleteLevel(String name, int level) {
    return 'Research complete: $name (level $level)';
  }

  @override
  String serverTycoonRepoResearchComplete(String name) {
    return 'Research complete: $name';
  }

  @override
  String get serverTycoonRepoUnknownResearch => 'Unknown research project';

  @override
  String get serverTycoonRepoAlreadyResearched => 'Already researched';

  @override
  String get serverTycoonRepoAlreadyQueued => 'Already queued';

  @override
  String get serverTycoonRepoMaxLevel => 'Already at maximum level';

  @override
  String serverTycoonRepoRequiresProjectFirst(String name) {
    return 'Requires $name first';
  }

  @override
  String serverTycoonRepoRequiresReputation(String reputation) {
    return 'Requires $reputation reputation';
  }

  @override
  String get serverTycoonRepoOneProjectAtATime =>
      'Only one project at a time — build the R&D Lab branch for more queue slots';

  @override
  String serverTycoonRepoResearchSlotsBusy(String slots) {
    return 'All $slots research slots are busy';
  }

  @override
  String serverTycoonRepoNotEnoughMoneyNeeds(String cost) {
    return 'Not enough money (needs $cost)';
  }

  @override
  String get serverTycoonRepoNotEnoughMoney => 'Not enough money';

  @override
  String get serverTycoonRepoNotInProgress => 'That project is not in progress';

  @override
  String get serverTycoonRepoUnknownBoost => 'Unknown boost';

  @override
  String serverTycoonRepoBoostWoreOff(String name) {
    return '$name wore off';
  }

  @override
  String get serverTycoonRepoIncidentNotFound => 'Incident not found';

  @override
  String get serverTycoonRepoIncidentNotMitigable =>
      'This incident cannot be mitigated';

  @override
  String get serverTycoonRepoIncidentNotCooled =>
      'This incident cannot be cooled down';

  @override
  String get serverTycoonRepoCooldownsUsed =>
      'Emergency cooldown already used twice today';

  @override
  String get serverTycoonRepoIncidentNotRepairable =>
      'This incident cannot be repaired';

  @override
  String get serverTycoonRepoNeedRouterFirst =>
      'You need at least one router first';

  @override
  String get serverTycoonRepoResearchRouters =>
      'Research more networking tech to run additional routers';

  @override
  String get serverTycoonRepoUnknownRig => 'Unknown rig';

  @override
  String get serverTycoonRepoUnknownRouter => 'Unknown router';

  @override
  String get serverTycoonRepoUnknownService => 'Unknown service';

  @override
  String get serverTycoonRepoUnknownNodeKind => 'Unknown node kind';

  @override
  String get serverTycoonRepoUnknownServiceType => 'Unknown service type';

  @override
  String serverTycoonRepoRequiresLicense(String license) {
    return 'Requires the $license license';
  }

  @override
  String get serverTycoonRepoServiceInstanceNotFound =>
      'Service instance not found';

  @override
  String get serverTycoonRepoSameKindConnect =>
      'Two nodes of the same type cannot be connected to each other';

  @override
  String get serverTycoonRepoCannotConnect => 'Those two cannot be connected';

  @override
  String get serverTycoonRepoNothingToDisconnect => 'Nothing to disconnect';

  @override
  String get serverTycoonRepoUnknownLicense => 'Unknown license';

  @override
  String get serverTycoonRepoAlreadyOwned => 'Already owned';

  @override
  String serverTycoonRepoRequiresLicenseFirst(String license) {
    return 'Requires the $license license first';
  }

  @override
  String get serverTycoonRepoUnknownStaff => 'Unknown staff member';

  @override
  String get serverTycoonRepoAlreadyHired => 'Already hired';

  @override
  String serverTycoonRepoRequiresResearch(String research) {
    return 'Requires the $research research';
  }

  @override
  String get serverTycoonRepoNotCurrentlyHired => 'Not currently hired';

  @override
  String get serverTycoonRepoOfferAccepted => 'Offer already accepted';

  @override
  String get serverTycoonRepoOfferExpired => 'That offer has expired';

  @override
  String serverTycoonRepoContractSlots(String slots) {
    return 'You can only run $slots contracts at once (research Sales Team for more)';
  }

  @override
  String get serverTycoonRepoUnknownCategory => 'Unknown item category';

  @override
  String get serverTycoonRepoUnknownItem => 'Unknown item';

  @override
  String get serverTycoonRepoUnknownSlot => 'Unknown component slot';

  @override
  String serverTycoonRepoPartBroken(String name, String problems) {
    return '$name installed, but it doesn\'t work: $problems. This rig will not generate income until fixed.';
  }

  @override
  String get serverTycoonRepoUnknownPlan => 'Unknown plan';

  @override
  String get serverTycoonRepoUnknownRamStick => 'Unknown RAM stick';

  @override
  String get serverTycoonRepoUnknownDrive => 'Unknown drive';

  @override
  String get serverTycoonRepoNoRamAtSlot => 'No RAM stick at that slot';

  @override
  String get serverTycoonRepoNoDriveAtSlot => 'No drive at that slot';

  @override
  String get serverTycoonRepoFixIncompatible =>
      'Fix the incompatible parts first';

  @override
  String get serverTycoonRepoNothingHoldingBack =>
      'Nothing is holding this rig back';

  @override
  String get serverTycoonRepoNoAffordableUpgrade =>
      'No affordable upgrade for that bottleneck';

  @override
  String get serverTycoonRepoFastestPlan => 'Already on the fastest plan';

  @override
  String serverTycoonRepoCloned(String cost) {
    return 'Cloned for $cost — install services on it to start earning';
  }

  @override
  String get serverTycoonRepoNothingToArrange => 'Nothing to arrange';

  @override
  String serverTycoonRepoNeedNetWorth(String amount) {
    return 'Need $amount net worth to scale up';
  }

  @override
  String serverTycoonRepoContractCompleted(
    String company,
    String bonus,
    String rep,
  ) {
    return '$company contract completed: +$bonus bonus, +$rep rep';
  }

  @override
  String serverTycoonRepoContractFailed(
    String company,
    String capacity,
    String rep,
  ) {
    return '$company contract FAILED (needed $capacity served capacity): -$rep rep';
  }

  @override
  String serverTycoonRepoMissionReward(String name, String cash, String rep) {
    return '$name: +$cash, +$rep rep';
  }

  @override
  String get sftpHostStorageAccessTitle =>
      'Other devices can\'t see your files yet';

  @override
  String get sftpHostStorageAccessBody =>
      'Android hides photos and files made by other apps until luma has \"All files access\". Until then this folder looks empty from the other device.';

  @override
  String get sftpHostWaitingForSettings => 'Waiting for Settings…';

  @override
  String get sftpHostAllowFileAccess => 'Allow file access';

  @override
  String sftpHostWantsToConnect(String name) {
    return '$name wants to connect';
  }

  @override
  String sftpHostApprovalDetail(String address) {
    return 'It is at $address and gave the right pairing password.';
  }

  @override
  String get sftpHostAllow => 'Allow';

  @override
  String get sftpHostRefuse => 'Refuse';

  @override
  String get sftpHostNoDevicesConnected => 'No devices connected';

  @override
  String sftpHostDevicesConnected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count devices connected',
      one: '1 device connected',
    );
    return '$_temp0';
  }

  @override
  String sftpHostClientTraffic(String address, String sent, String received) {
    return '$address · sent $sent · received $received';
  }

  @override
  String get sftpHostDisconnect => 'Disconnect';

  @override
  String get sftpHostChooseFolderTitle => 'Choose the folder to share';

  @override
  String get sftpHostChooseFolderFirst => 'Choose a folder to share first.';

  @override
  String get sftpHostFolderGone => 'That folder is no longer there.';

  @override
  String get sftpHostPickPort => 'Pick a port between 1024 and 65535.';

  @override
  String sftpHostPasswordTooShort(String minLength) {
    return 'A pairing password needs at least $minLength characters.';
  }

  @override
  String sftpHostValueCopied(String what) {
    return '$what copied.';
  }

  @override
  String get sftpHostFieldAddress => 'Address';

  @override
  String get sftpHostFieldPort => 'Port';

  @override
  String get sftpHostFieldPassword => 'Pairing password';

  @override
  String get sftpHostPasswordRotated =>
      'New pairing password. Devices already connected stay connected.';

  @override
  String sftpHostHostingFolder(String name) {
    return 'Hosting $name';
  }

  @override
  String get sftpHostAccessReadOnlyApproval =>
      'Read only · you approve each device';

  @override
  String get sftpHostAccessReadOnlyPassword => 'Read only · password only';

  @override
  String get sftpHostAccessReadWriteApproval =>
      'Read and write · you approve each device';

  @override
  String get sftpHostAccessReadWritePassword =>
      'Read and write · password only';

  @override
  String get sftpHostPairingInstructions =>
      'On the other device, open the SFTP plugin, add a site of type \"luma device\", and enter:';

  @override
  String get sftpHostNoNetwork => 'No network connection';

  @override
  String sftpHostOtherAddresses(String addresses) {
    return 'Other addresses on this device: $addresses';
  }

  @override
  String get sftpHostNewPassword => 'New password';

  @override
  String get sftpHostShow => 'Show';

  @override
  String get sftpHostHide => 'Hide';

  @override
  String get sftpHostSetupTitle => 'Let another device connect to this one';

  @override
  String get sftpHostSetupSubtitle =>
      'Share one folder over your network. The other device opens it in its own Servers tab.';

  @override
  String get sftpHostFolderLabel => 'Folder to share';

  @override
  String get sftpHostNoFolderChosen => 'No folder chosen yet';

  @override
  String get sftpHostChoose => 'Choose';

  @override
  String get sftpHostFolderNote =>
      'Only this folder is served. Nothing above it is reachable, and links pointing out of it are refused.';

  @override
  String get sftpHostAccessLabel => 'What the other device may do';

  @override
  String get sftpHostAccessReadOnlyTab => 'Read only';

  @override
  String get sftpHostAccessReadWriteTab => 'Read and write';

  @override
  String get sftpHostAccessReadOnlyHint =>
      'It can browse and download. Nothing on this device changes.';

  @override
  String get sftpHostAccessReadWriteHint =>
      'It can also upload, rename and delete inside the shared folder.';

  @override
  String get sftpHostApprovalToggle => 'Ask me before letting a device in';

  @override
  String get sftpHostApprovalToggleSubtitle =>
      'Even with the right password, you approve each one.';

  @override
  String get sftpHostOwnPasswordToggle => 'Choose the pairing password myself';

  @override
  String get sftpHostOwnPasswordSubtitle =>
      'Off by default — luma generates a much stronger one.';

  @override
  String sftpHostPasswordHint(String minLength) {
    return 'At least $minLength characters';
  }

  @override
  String get sftpHostPasswordTooShortWarn =>
      'Too short — this will be refused.';

  @override
  String get sftpHostPasswordWeak =>
      'Weak. Anyone who can reach this port could work it out.';

  @override
  String get sftpHostPasswordFair => 'Fair. A longer one would be better.';

  @override
  String get sftpHostPasswordStrong => 'Strong.';

  @override
  String get sftpHostStartHosting => 'Start hosting';

  @override
  String get sftpHostEmptyClients =>
      'Nothing is reading this folder. It stays shared until you press Stop or close luma.';

  @override
  String get sftpHostSecurityNote =>
      'The two devices agree on a key from the pairing password, then encrypt everything between them. luma\'s servers are not involved and never see the folder, the password or the files. Only the folder you pick is reachable. Hosting keeps running while luma is open — press Stop when you are done.';

  @override
  String get sftpHostNoAddress => 'This device has no address.';

  @override
  String get sftpHostTypePassword =>
      'Type the pairing password shown on that device.';

  @override
  String sftpHostCouldNotReach(String host, String port, String detail) {
    return 'Could not reach $host on port $port. Check that the other device is still showing its pairing screen and that both are on the same network.\n$detail';
  }

  @override
  String sftpHostConnectTimedOut(String host, String port) {
    return 'Timed out connecting to $host on port $port.';
  }

  @override
  String get sftpHostDeviceClosed => 'That device closed the connection.';

  @override
  String sftpHostCouldNotConnect(String detail) {
    return 'Could not connect to that device.\n$detail';
  }

  @override
  String get sftpHostExpectedAdmission => 'Expected to be let in first.';

  @override
  String get sftpHostNotLetIn => 'That device did not let this one in.';

  @override
  String get sftpHostDidNotAnswer =>
      'That device did not answer in time. Make sure it is still hosting.';

  @override
  String get sftpHostApprovalTimedOut =>
      'Nobody allowed this device in on the other end in time. Ask them to press Allow, then connect again.';

  @override
  String get sftpHostRefusedRequest => 'That device refused the request.';

  @override
  String get sftpHostTransferStopped => 'The transfer stopped unexpectedly.';

  @override
  String get sftpHostFolderUnreadable =>
      'That device sent a folder we could not read.';

  @override
  String get sftpHostItemUnreadable => 'That item could not be read.';

  @override
  String sftpHostReadOnlyHere(String host) {
    return '$host is sharing this folder read-only, so it cannot be changed from here.';
  }

  @override
  String sftpHostSaveFailed(String detail) {
    return 'The file could not be saved here: $detail';
  }

  @override
  String get sftpHostConnectionClosed =>
      'The connection to that device is closed.';

  @override
  String get sftpHostConnectionWasClosed => 'The connection was closed.';

  @override
  String get sftpHostRecordTooShort => 'Record too short to be authentic.';

  @override
  String get sftpHostFrameFailedAuth =>
      'A frame failed its authenticity check; the connection was closed.';

  @override
  String get sftpHostOtherVersion =>
      'The other device speaks a different version.';

  @override
  String get sftpHostWrongPasswordAttempt =>
      'A device tried to connect with the wrong pairing password.';

  @override
  String get sftpHostWrongPassword =>
      'That pairing password is not the one this device is showing.';

  @override
  String get sftpHostVersionMismatch =>
      'That device runs a different version of luma. Update both to the same version and try again.';

  @override
  String get sftpHostRefusedConnection => 'That device refused the connection.';

  @override
  String get sftpHostCouldNotProve =>
      'That device could not prove it is the one showing this pairing password. Nothing was sent to it.';

  @override
  String get sftpHostPartSalt => 'salt';

  @override
  String get sftpHostPartKey => 'key';

  @override
  String get sftpHostPartProof => 'proof';

  @override
  String sftpHostHandshakeMissing(String part) {
    return 'The handshake was missing its $part.';
  }

  @override
  String sftpHostHandshakeMalformed(String part) {
    return 'The handshake $part was malformed.';
  }

  @override
  String sftpHostHandshakeWrongSize(String part) {
    return 'The handshake $part was the wrong size.';
  }

  @override
  String get sftpHostUnnamedDevice => 'luma device';

  @override
  String get sftpHostSharedFolderName => 'Shared';

  @override
  String get sftpHostEmptyFrame => 'Empty frame.';

  @override
  String get sftpHostControlNotJson => 'Control frame was not valid JSON.';

  @override
  String get sftpHostControlNotObject => 'Control frame was not an object.';

  @override
  String get sftpHostChunkTruncated => 'Truncated chunk frame.';

  @override
  String sftpHostUnknownFrameKind(String kind) {
    return 'Unknown frame kind 0x$kind.';
  }

  @override
  String sftpHostFrameTooLarge(String length) {
    return 'Frame of $length bytes is larger than this connection allows.';
  }

  @override
  String get sftpHostExpectedHandshake => 'Expected a handshake message.';

  @override
  String sftpServerPasswordTooShort(int count) {
    return 'A pairing password needs at least $count characters.';
  }

  @override
  String sftpServerListenerStopped(String error) {
    return 'The listener stopped: $error';
  }

  @override
  String sftpServerPortInUse(int port) {
    return 'Port $port is already in use on this device. Pick another one.';
  }

  @override
  String sftpServerCouldNotListen(int port, String reason) {
    return 'Could not listen on port $port. $reason';
  }

  @override
  String sftpServerCouldNotStart(String error) {
    return 'Could not start hosting. $error';
  }

  @override
  String get sftpServerConnecting => 'Connecting…';

  @override
  String get sftpThisDeviceTitle => 'This device';

  @override
  String get sftpThisDeviceUnknown => 'Unknown';

  @override
  String get sftpThisDeviceChooseFolderTitle => 'Choose the folder to share';

  @override
  String get sftpThisDevicePasswordRotated =>
      'New pairing password. Devices already connected stay connected.';

  @override
  String sftpThisDeviceCopied(String what) {
    return '$what copied.';
  }

  @override
  String get sftpThisDeviceFieldDevice => 'Device';

  @override
  String get sftpThisDeviceFieldDeviceName => 'Device name';

  @override
  String get sftpThisDeviceFieldUser => 'User';

  @override
  String get sftpThisDeviceFieldUserName => 'User name';

  @override
  String get sftpThisDeviceFieldAddress => 'Address';

  @override
  String get sftpThisDeviceFieldPort => 'Port';

  @override
  String get sftpThisDeviceFieldPassword => 'Pairing password';

  @override
  String get sftpThisDeviceShow => 'Show';

  @override
  String get sftpThisDeviceHide => 'Hide';

  @override
  String get sftpThisDeviceNoNetwork => 'No network connection';

  @override
  String sftpThisDeviceOtherAddresses(String addresses) {
    return 'Other addresses on this device: $addresses';
  }

  @override
  String get sftpThisDeviceCredentialsTitle => 'Credentials for this device';

  @override
  String get sftpThisDeviceCredentialsHelp =>
      'On the other device open the SFTP plugin, press New site, pick \"luma device\", and enter these.';

  @override
  String get sftpThisDeviceUserNameNote =>
      'The user name is here to tell devices apart. luma pairs on the password alone — this is not an SSH login, and nothing on this device\'s account is exposed by it.';

  @override
  String get sftpThisDeviceNewPassword => 'New password';

  @override
  String get sftpThisDeviceStatusChooseTitle => 'Choose a folder to share';

  @override
  String get sftpThisDeviceStatusChooseBody =>
      'Nothing is reachable until you pick one. Only that folder is served — nothing above it.';

  @override
  String get sftpThisDeviceStatusOpeningTitle => 'Opening this device…';

  @override
  String get sftpThisDeviceStatusOpeningBody => 'Setting up the listener.';

  @override
  String get sftpThisDeviceStatusPausedTitle =>
      'Paused while luma is in the background';

  @override
  String get sftpThisDeviceStatusPausedBody =>
      'It starts again by itself when you come back to this screen.';

  @override
  String get sftpThisDeviceStatusReachableTitle =>
      'Other devices can reach this one';

  @override
  String get sftpThisDeviceStatusReachableBody =>
      'Only while this screen is open.';

  @override
  String get sftpThisDeviceStatusUnreachableTitle => 'Not reachable';

  @override
  String get sftpThisDeviceStatusFailedBody => 'Hosting could not start.';

  @override
  String get sftpThisDeviceFolderLabel => 'Folder being shared';

  @override
  String get sftpThisDeviceNoFolder => 'No folder chosen yet';

  @override
  String get sftpThisDeviceChange => 'Change';

  @override
  String get sftpThisDeviceTermsTitle => 'What the other device may do';

  @override
  String get sftpThisDeviceReadOnly => 'Read only';

  @override
  String get sftpThisDeviceReadWrite => 'Read and write';

  @override
  String get sftpThisDeviceReadOnlyHelp =>
      'It can browse and download. Nothing on this device changes.';

  @override
  String get sftpThisDeviceReadWriteHelp =>
      'It can also upload, rename and delete inside the shared folder.';

  @override
  String get sftpThisDeviceAskApproval => 'Ask me before letting a device in';

  @override
  String get sftpThisDeviceAskApprovalSub =>
      'Even with the right password, you approve each one.';

  @override
  String get sftpThisDeviceRestartNote =>
      'Changing either of these restarts the listener, so anything connected right now is dropped.';

  @override
  String get sftpThisDeviceEmptyClients =>
      'Nothing is reading this folder yet. Keep this screen open while the other device connects.';

  @override
  String get sftpThisDeviceLifetimeNote =>
      'This device is only reachable while this screen is open. Go back, or send luma to the background, and the listener closes and every connected device is dropped mid-transfer. Use the Host tab instead when a transfer needs to keep running while you do something else. The two devices agree on a key from the pairing password and encrypt everything between them; luma\'s servers are not involved and never see the folder, the password or the files.';

  @override
  String get sftpHostKeyChangedTitle => 'This server\'s key has changed';

  @override
  String get sftpHostKeyUnknownTitle => 'Unknown server key';

  @override
  String sftpHostKeyChangedBody(String host) {
    return 'A different key was trusted for $host before. Either the server was rebuilt, or something is impersonating it. Do not continue unless you know the server changed.';
  }

  @override
  String sftpHostKeyUnknownBody(String host) {
    return 'luma has never connected to $host before. Check the fingerprint against the one on the server, then decide whether to trust it.';
  }

  @override
  String get sftpPreviouslyTrusted => 'Previously trusted';

  @override
  String get sftpTrustNewKey => 'Trust the new key';

  @override
  String get sftpTrustAndConnect => 'Trust and connect';

  @override
  String get sftpConnect => 'Connect';

  @override
  String get sftpShow => 'Show';

  @override
  String get sftpHide => 'Hide';

  @override
  String get sftpRememberForSite => 'Remember it for this site';

  @override
  String get sftpEncryptedLocalNote =>
      'Encrypted on this device. Never uploaded anywhere.';

  @override
  String sftpConnectToDevice(String deviceName) {
    return 'Connect to $deviceName';
  }

  @override
  String get sftpPortRangeError => 'Port must be a number between 1 and 65535.';

  @override
  String sftpPairingPasswordRequired(String deviceName) {
    return 'Type the pairing password shown on $deviceName.';
  }

  @override
  String sftpQuickConnectFound(String address) {
    return 'Found on this network at $address. Type the port and pairing password shown on its Host tab or This device screen.';
  }

  @override
  String get sftpPortLabel => 'Port';

  @override
  String get sftpPairingPasswordLabel => 'Pairing password';

  @override
  String get sftpRememberDevicePassword =>
      'Remember the password for this device';

  @override
  String sftpDeleteOneTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String sftpDeleteManyTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count items?',
      one: 'Delete 1 item?',
    );
    return '$_temp0';
  }

  @override
  String get sftpDeleteRemoteWarning =>
      'This deletes them on the server. Folders go with everything inside them, and there is no undo.';

  @override
  String get sftpDeleteLocalWarning =>
      'This deletes them on this device. There is no undo.';

  @override
  String sftpPermissionsTitle(String name) {
    return 'Permissions for $name';
  }

  @override
  String get sftpPermissionsMode => 'Mode';

  @override
  String get sftpPermissionsHelper => 'Octal (755) or symbolic (rwxr-xr-x)';

  @override
  String get sftpPermissionsInvalid => 'Not a valid mode.';

  @override
  String get sftpLocalAppStorage => 'App storage';

  @override
  String get sftpLocalHome => 'Home';

  @override
  String sftpDropUploadTo(String name) {
    return 'Upload to $name';
  }

  @override
  String get sftpDropDownloadHere => 'Download to here';

  @override
  String get sftpFolderEmpty => 'This folder is empty.';

  @override
  String get sftpNothingToShow => 'Nothing to show.';

  @override
  String get sftpUpOneFolder => 'Up one folder';

  @override
  String get sftpPlaces => 'Places';

  @override
  String get sftpHomeFolder => 'Home folder';

  @override
  String get sftpNewFolder => 'New folder';

  @override
  String sftpSelectedOfCount(int selected, int count) {
    return '$selected of $count selected';
  }

  @override
  String sftpItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String sftpSelectEntry(String name) {
    return 'Select $name';
  }

  @override
  String sftpCouldNotFindStartFolder(String error) {
    return 'Could not find a folder to start in. $error';
  }

  @override
  String sftpCouldNotOpenFolder(String error) {
    return 'Could not open this folder. $error';
  }

  @override
  String sftpCouldNotListFolder(String error) {
    return 'Could not list this folder. $error';
  }

  @override
  String sftpPairingPasswordFor(String name) {
    return 'Pairing password for $name';
  }

  @override
  String sftpPasswordFor(String name) {
    return 'Password for $name';
  }

  @override
  String sftpPassphraseFor(String name) {
    return 'Passphrase for $name';
  }

  @override
  String get sftpTypeDevicePasswordHint =>
      'Type the password shown on that device\'s Host tab.';

  @override
  String sftpSigningInAs(String username, String host) {
    return 'Signing in as $username on $host.';
  }

  @override
  String sftpWaitingForApproval(String host) {
    return 'Waiting for someone on $host to allow this device…';
  }

  @override
  String get sftpConnectionClosed => 'The connection to the server closed.';

  @override
  String sftpConnectionClosedWithReason(String reason) {
    return 'The connection closed: $reason';
  }

  @override
  String get sftpNothingToUpload => 'Nothing to upload.';

  @override
  String sftpQueuedForUpload(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Queued $count items for upload.',
      one: 'Queued 1 item for upload.',
    );
    return '$_temp0';
  }

  @override
  String get sftpNothingToDownload => 'Nothing to download.';

  @override
  String sftpQueuedForDownload(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Queued $count items for download.',
      one: 'Queued 1 item for download.',
    );
    return '$_temp0';
  }

  @override
  String sftpCouldNotOpenName(String name, String message) {
    return 'Could not open $name. $message';
  }

  @override
  String get sftpFolderNameLabel => 'Folder name';

  @override
  String get sftpCreate => 'Create';

  @override
  String sftpCouldNotCreateFolder(String error) {
    return 'Could not create the folder. $error';
  }

  @override
  String get sftpNewNameLabel => 'New name';

  @override
  String sftpCouldNotRename(String name, String error) {
    return 'Could not rename $name. $error';
  }

  @override
  String sftpCouldNotDeleteAll(String error) {
    return 'Could not delete everything. $error';
  }

  @override
  String sftpCouldNotChangePermissions(String error) {
    return 'Could not change permissions. $error';
  }

  @override
  String sftpUploadLabel(String target) {
    return 'Upload $target';
  }

  @override
  String sftpDownloadLabel(String target) {
    return 'Download $target';
  }

  @override
  String sftpDeleteLabel(String target) {
    return 'Delete $target';
  }

  @override
  String get sftpPermissions => 'Permissions';

  @override
  String get sftpOpenSettingsSync =>
      'Open Settings → Sync & account to set this device up.';

  @override
  String get sftpAddToSharedFolder => 'Add to the shared folder';

  @override
  String sftpNameInShare(String name) {
    return '$name is in the shared folder.';
  }

  @override
  String sftpItemsInShare(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items are in the shared folder.',
      one: '1 item is in the shared folder.',
    );
    return '$_temp0';
  }

  @override
  String sftpFolderAt(String path) {
    return 'The folder is at $path';
  }

  @override
  String get sftpShareDeleteWarning =>
      'They will also disappear from the shared folder on your other devices the next time they connect.';

  @override
  String get sftpSiteManager => 'Site Manager';

  @override
  String get sftpDisconnect => 'Disconnect';

  @override
  String get sftpHostThisDevice => 'Host this device';

  @override
  String get sftpMyDevices => 'My devices';

  @override
  String get sftpServers => 'Servers';

  @override
  String get sftpHost => 'Host';

  @override
  String get sftpSharingFolderNote =>
      'Sharing a folder — any device with the pairing password can connect.';

  @override
  String get sftpHostIdleNote =>
      'Let another device connect to this one over your network.';

  @override
  String get sftpDevicesNote =>
      'One folder, mirrored across your own devices over your network.';

  @override
  String get sftpServersNote =>
      'Connect to your own server — nothing routes through luma.';

  @override
  String sftpConnectedTo(String endpoint) {
    return 'Connected to $endpoint';
  }

  @override
  String get sftpThisDevice => 'This device';

  @override
  String get sftpSharedFolder => 'Shared folder';

  @override
  String sftpShareItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Share $count items',
      one: 'Share 1 item',
    );
    return '$_temp0';
  }

  @override
  String sftpUploadItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Upload $count items',
      one: 'Upload 1 item',
    );
    return '$_temp0';
  }

  @override
  String sftpDownloadItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Download $count items',
      one: 'Download 1 item',
    );
    return '$_temp0';
  }

  @override
  String get sftpTabServer => 'Server';

  @override
  String get sftpTabQueue => 'Queue';

  @override
  String sftpQueueWithCount(int count) {
    return 'Queue ($count)';
  }

  @override
  String get sftpPutInShare => 'Put the selected files in the shared folder';

  @override
  String get sftpUploadSelected => 'Upload the selected files';

  @override
  String get sftpDownloadSelected => 'Download the selected files';

  @override
  String get sftpUpsellTitle => 'SFTP comes with Orbit and Nova';

  @override
  String get sftpUpsellBody =>
      'Connect to your own servers with a host, username, password and port, browse both sides at once, and drag files across. The connection goes straight from this device to your server — nothing passes through a luma server.';

  @override
  String sftpUpgradeTo(String plan) {
    return 'Upgrade to $plan';
  }

  @override
  String get sftpQueueNothingQueued =>
      'Nothing queued. Drag files between the two sides, or select some and use the transfer arrows.';

  @override
  String get sftpQueueTransferring => 'Transferring';

  @override
  String get sftpQueueTitle => 'Transfer queue';

  @override
  String get sftpQueueRetryAll => 'Retry all';

  @override
  String sftpQueueFilesLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files left',
      one: '1 file left',
    );
    return '$_temp0';
  }

  @override
  String sftpQueueFailedCount(int count) {
    return '$count failed';
  }

  @override
  String get sftpQueueIdle => 'Empty';

  @override
  String get sftpQueueAllDone => 'All done';

  @override
  String get sftpQueueWaiting => 'Waiting';

  @override
  String sftpQueueRunningDetail(String done, String total, String rate) {
    return '$done of $total · $rate';
  }

  @override
  String get sftpQueueStopped => 'Stopped';

  @override
  String get sftpQueueFailed => 'Failed';

  @override
  String get sftpErrNoHostName => 'This site has no host name.';

  @override
  String sftpErrCouldNotReachHost(String host, String port, String reason) {
    return 'Could not reach $host on port $port.\n$reason';
  }

  @override
  String sftpErrConnectTimedOut(String host, String port) {
    return 'Timed out connecting to $host on port $port.';
  }

  @override
  String get sftpErrHostKeyNotAccepted =>
      'The server\'s key was not accepted, so nothing was sent to it.';

  @override
  String sftpErrNoSftpChannel(String error) {
    return 'Signed in, but the server would not open an SFTP channel. Its SSH service may have the SFTP subsystem disabled.\n($error)';
  }

  @override
  String get sftpErrKeyAuthNoFile =>
      'This site is set to key authentication but no key file is chosen.';

  @override
  String sftpErrKeyNotFound(String path) {
    return 'Private key not found at $path';
  }

  @override
  String sftpErrKeyReadFailed(String error) {
    return 'Could not read the private key.\n($error)';
  }

  @override
  String get sftpErrKeyPassphraseRequired =>
      'This private key is passphrase-protected.';

  @override
  String get sftpErrPassphraseWrong =>
      'That passphrase does not unlock the private key.';

  @override
  String sftpErrNotPrivateKey(String error) {
    return 'That file is not a private key luma can read.\n($error)';
  }

  @override
  String sftpErrKeyRejected(String username) {
    return 'The server rejected that key for $username.';
  }

  @override
  String get sftpErrPasswordRejected =>
      'The server rejected that username or password.';

  @override
  String sftpErrSignInAborted(String message) {
    return 'The server closed the connection during sign-in.\n$message';
  }

  @override
  String sftpErrCouldNotSignIn(String host, String error) {
    return 'Could not sign in to $host.\n$error';
  }

  @override
  String get sftpTransferCancelled => 'Transfer cancelled';

  @override
  String get sftpSiteSnapshotInvalid => 'Invalid SFTP sites snapshot.';

  @override
  String get sftpNearbyTitle => 'On this network';

  @override
  String get sftpNearbyEmpty =>
      'No luma device on this network is hosting right now. Open the Host tab or This device on the other one and it shows up here.';

  @override
  String sftpNearbyOtherVersion(String address) {
    return '$address · runs a different version of luma — update both to connect';
  }

  @override
  String get sftpSiteNoServersTitle => 'No servers yet';

  @override
  String get sftpSiteNoServersBody =>
      'A site is one saved server — its host name, user name, password and port. luma connects straight to it from this device. To go the other way and let a device connect to this one, open This device.';

  @override
  String get sftpSiteNew => 'New site';

  @override
  String get sftpSiteManagerTitle => 'Site Manager';

  @override
  String get sftpSiteManagerSubtitle =>
      'Your servers, saved on this device only.';

  @override
  String get sftpPrivacyNote =>
      'Connections go straight from this device to your server. Nothing passes through a luma server, and saved passwords stay encrypted here — they are never synced.';

  @override
  String get sftpPasswordSavedTooltip =>
      'Password saved, encrypted on this device';

  @override
  String get sftpEditSiteTooltip => 'Edit site';

  @override
  String get sftpRemoveSiteTooltip => 'Remove site';

  @override
  String get sftpEditSiteTitle => 'Edit site';

  @override
  String get sftpChoosePrivateKey => 'Choose a private key';

  @override
  String get sftpErrHostRequired => 'A host name or IP address is required.';

  @override
  String get sftpErrUsernameRequired => 'A username is required.';

  @override
  String get sftpErrKeyFileRequired =>
      'Choose the private key file to sign in with.';

  @override
  String get sftpEndpointQuestion => 'What is on the other end';

  @override
  String get sftpTransportSshServer => 'SSH server';

  @override
  String get sftpTransportLumaDevice => 'luma device';

  @override
  String get sftpLumaDeviceHint =>
      'Another device running luma with hosting turned on. Read its address, port and pairing password off its Host tab.';

  @override
  String get sftpSshServerHint =>
      'Any server that speaks SSH — a VPS, a NAS, a Pi.';

  @override
  String get sftpSiteNameHintLuma => 'My laptop';

  @override
  String get sftpSiteNameHintServer => 'My VPS';

  @override
  String get sftpSiteFieldHost => 'Host';

  @override
  String get sftpSiteHostHint => 'example.com or 203.0.113.10';

  @override
  String get sftpSignInWith => 'Sign in with';

  @override
  String get sftpSignInSshKey => 'SSH key';

  @override
  String get sftpPairingPasswordHelper =>
      'The one shown on that device right now.';

  @override
  String get sftpKeyPassphrase => 'Key passphrase';

  @override
  String get sftpKeyPassphraseHelper =>
      'Leave empty if the key has no passphrase.';

  @override
  String get sftpSaveDeviceSecret =>
      'Save the pairing password for this device';

  @override
  String get sftpSaveKeyPassphrase => 'Save the passphrase for this site';

  @override
  String get sftpSaveSitePassword => 'Save the password for this site';

  @override
  String get sftpSaveDeviceSecretNote =>
      'Encrypted on this device — but the other device changes it every time it starts hosting.';

  @override
  String get sftpSaveSiteSecretNote =>
      'Encrypted on this device. Untick and luma asks every time you connect.';

  @override
  String get sftpOpenFolderOnConnect => 'Open this folder on connect';

  @override
  String get sftpLumaFolderHint => '/photos (optional)';

  @override
  String get sftpSftpFolderHint => '/var/www (optional)';

  @override
  String get sftpSaveSite => 'Save site';

  @override
  String get sftpNoKeyChosen => 'No private key chosen';

  @override
  String sftpShareCouldNotAdd(String name, String error) {
    return 'Could not add $name: $error';
  }

  @override
  String get sftpShareOutOfStep =>
      'Transfer got out of step; it will start again.';

  @override
  String get sftpShareMismatch =>
      'The copy that arrived did not match the original; it will be fetched again.';

  @override
  String get sftpShareDeviceWentAway => 'The device went away.';

  @override
  String sftpShareSummary(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0 · $size';
  }

  @override
  String get sftpShareFolderTitle => 'Shared folder';

  @override
  String sftpShareSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String sftpShareSummaryOnEveryDevice(String summary) {
    return '$summary · on every device';
  }

  @override
  String get sftpShareDeleteEverywhere => 'Delete everywhere';

  @override
  String get sftpShareAddFiles => 'Add files';

  @override
  String get sftpShareOpenFolderHere => 'Open the folder on this device';

  @override
  String get sftpShareRescan => 'Rescan';

  @override
  String get sftpShareDropToShare => 'Drop to share';

  @override
  String get sftpShareNothingYet => 'Nothing shared yet';

  @override
  String get sftpShareEmptyHint =>
      'Drag files in from the left, or use +. Anything here shows up in the same folder on your other devices — sent straight over your network, never through a luma server.';

  @override
  String get sftpShareOpen => 'Open';

  @override
  String get sftpShareLookingForDevices =>
      'Looking for your other devices on this network. Open luma on one of them, signed in to the same account.';

  @override
  String get sftpShareSyncOff =>
      'Device sync is off. Turn it on in Settings → Sync & account to reach your other devices.';

  @override
  String sftpShareFilesToGo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files to go',
      one: '1 file to go',
    );
    return '$_temp0';
  }

  @override
  String get sftpShareUpToDate => 'Up to date';

  @override
  String sftpShareWaitingForReturn(int count) {
    return '$count waiting for it to come back';
  }

  @override
  String get sftpShareNotOnNetwork => 'Not on this network';

  @override
  String get sftpShareFailed => 'Failed';

  @override
  String sftpShareFromDevice(String device) {
    return 'from $device';
  }

  @override
  String sftpShareToDevice(String device) {
    return 'to $device';
  }

  @override
  String get sftpShareSignInFirstTitle => 'Sign in on both devices first';

  @override
  String get sftpShareSignInFirstBody =>
      'The shared folder moves files straight between devices signed in to the same luma account, over your own network. Set up device sync under Settings → Sync & account on each device, then come back here.';

  @override
  String get sftpShareOpenSettings => 'Open settings';

  @override
  String get sendToDevicesTitle => 'Send to your devices';

  @override
  String sendToDevicesItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get sendToDevicesFolderLabel => 'Folder in the shared folder';

  @override
  String get sendToDevicesFolderHint => 'Leave empty to drop them at the top';

  @override
  String sendToDevicesCopying(int done, int total) {
    return 'Copying $done of $total…';
  }

  @override
  String get sendToDevicesNoneReadable =>
      'None of those could be read from this device.';

  @override
  String sendToDevicesOnTheWay(int count, int deviceCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    String _temp1 = intl.Intl.pluralLogic(
      deviceCount,
      locale: localeName,
      other: 'devices',
      one: 'device',
    );
    return '$_temp0 on the way to your other $_temp1.';
  }

  @override
  String sendToDevicesQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files ready',
      one: '1 file ready',
    );
    return '$_temp0 — they will go over as soon as another device is on this network.';
  }

  @override
  String get sendToDevicesNoPeers =>
      'No other device on this network right now. What you send waits in the shared folder and goes over the moment one turns up.';

  @override
  String get sendToDevicesSyncOff =>
      'Device sync is off. Turn it on in Settings → Sync & account and your other devices will pick these up.';

  @override
  String get sendToDevicesHere => 'here';

  @override
  String get sendToDevicesAway => 'away';

  @override
  String get sendToDevicesUnavailable =>
      'The shared folder is not running on this device. It comes with Orbit and Nova and needs device sync switched on under Settings → Sync & account, on this device and the one you want to send to.';

  @override
  String get bingoExportSaveTitle => 'Save BINGO cards as PDF';

  @override
  String bingoExportCardNumber(String number) {
    return 'CARD $number';
  }

  @override
  String get bingoExportInstructions => 'Mark five across, down or diagonally.';

  @override
  String get bingoExportFree => 'FREE';

  @override
  String get bingoExportFooter => 'SMALL GAMES  /  BINGO';

  @override
  String get bingoExportEncodeFailed => 'Could not encode BINGO card.';

  @override
  String get cardGamesHandHighCard => 'High card';

  @override
  String get cardGamesHandOnePair => 'One pair';

  @override
  String get cardGamesHandTwoPair => 'Two pair';

  @override
  String get cardGamesHandThreeOfKind => 'Three of a kind';

  @override
  String get cardGamesHandStraight => 'Straight';

  @override
  String get cardGamesHandFlush => 'Flush';

  @override
  String get cardGamesHandFullHouse => 'Full house';

  @override
  String get cardGamesHandFourOfKind => 'Four of a kind';

  @override
  String get cardGamesHandStraightFlush => 'Straight flush';

  @override
  String get cardGamesBjPushBlackjack => 'Push — both have blackjack.';

  @override
  String get cardGamesBjPlayerBlackjack => 'Blackjack! You win.';

  @override
  String get cardGamesBjDealerBlackjack => 'Dealer has blackjack.';

  @override
  String get cardGamesBjBust => 'Bust — dealer wins.';

  @override
  String get cardGamesBjPlayerWins => 'You win this hand!';

  @override
  String get cardGamesBjPushTie => 'Push — it is a tie.';

  @override
  String get cardGamesBjDealerWins => 'Dealer wins this hand.';

  @override
  String cardGamesPokerPlayerWins(String yours, String theirs) {
    return 'You win! $yours beats $theirs.';
  }

  @override
  String cardGamesPokerDealerWins(String yours, String theirs) {
    return 'Dealer wins. $theirs beats $yours.';
  }

  @override
  String cardGamesPokerPush(String hand) {
    return 'Push — both hands tie with $hand.';
  }

  @override
  String get cardGamesPatienceStart =>
      'Draw a card or tap a face-up card to select it.';

  @override
  String get cardGamesPatienceDrawn =>
      'Tap the drawn card, then a tableau column or foundation.';

  @override
  String get cardGamesPatienceRecycled => 'Stock recycled. Draw again.';

  @override
  String get cardGamesPatienceChooseTarget =>
      'Choose a tableau column or foundation.';

  @override
  String get cardGamesPatienceChooseAnother =>
      'Choose another column, or move the top card to a foundation.';

  @override
  String get cardGamesPatienceChooseColumn => 'Choose a tableau column.';

  @override
  String get cardGamesPatienceOnlyKing =>
      'Only a king can start an empty column.';

  @override
  String get cardGamesPatienceBuildDown =>
      'Build down by rank, alternating red and black.';

  @override
  String get cardGamesPatienceNiceMove =>
      'Nice move. Keep building the foundations.';

  @override
  String get cardGamesPatienceWon => 'You won Patience!';

  @override
  String get cardGamesPatienceMoved => 'Card moved to a foundation.';

  @override
  String get cardGamesPatienceFoundationRule =>
      'Foundations start with an ace and build up by suit.';

  @override
  String get cardGamesTableTitle => 'The card table';

  @override
  String get cardGamesAllGames => 'All games';

  @override
  String get cardGamesBackToTable => 'Back to card table';

  @override
  String get cardGamesHeader => 'SMALL GAMES  /  CARD GAMES';

  @override
  String get cardGamesNewGame => 'New game';

  @override
  String get cardGamesDealer => 'DEALER';

  @override
  String get cardGamesYouSeat => 'YOU • SEAT 1';

  @override
  String get cardGamesPullUpChair => 'PULL UP A CHAIR';

  @override
  String get cardGamesWhatToPlay => 'What will you play?';

  @override
  String get cardGamesLobbyBlurb =>
      'A quiet table, a fresh deck, and a seat reserved for you.';

  @override
  String get cardGamesPoker => 'Poker';

  @override
  String get cardGamesPokerBlurb => 'Hold your best cards. Beat the dealer.';

  @override
  String get cardGamesFiveCardDraw => 'Five-card draw';

  @override
  String get cardGamesBlackjack => 'Blackjack';

  @override
  String get cardGamesBlackjackType => 'Make 21';

  @override
  String get cardGamesBlackjackBlurb => 'Hit or stand against the dealer.';

  @override
  String get cardGamesPatience => 'Patience';

  @override
  String get cardGamesSolitaire => 'Solitaire';

  @override
  String get cardGamesPatienceBlurb => 'Build all four foundations by suit.';

  @override
  String get cardGamesDealerHand => 'DEALER HAND';

  @override
  String get cardGamesYourHand => 'YOUR HAND';

  @override
  String cardGamesDealerTotal(int total) {
    return 'Dealer: $total';
  }

  @override
  String cardGamesDealerShowing(int total) {
    return 'Dealer: $total + ?';
  }

  @override
  String cardGamesYouTotal(int total) {
    return 'You: $total';
  }

  @override
  String get cardGamesHit => 'Hit';

  @override
  String get cardGamesStand => 'Stand';

  @override
  String get cardGamesDealAgain => 'Deal again';

  @override
  String get cardGamesBlackjackHint =>
      'Get closer to 21 than the dealer without going over. Aces count as 1 or 11.';

  @override
  String get cardGamesHold => 'HOLD';

  @override
  String get cardGamesDrawCards => 'Draw cards';

  @override
  String get cardGamesPokerHint =>
      'Tap cards to hold them, then draw once. The dealer also draws once. Best five-card hand wins.';

  @override
  String get cardGamesPatienceSection => 'PATIENCE • DRAW ONE';

  @override
  String get cardGamesStock => 'Stock';

  @override
  String get cardGamesWaste => 'Waste';

  @override
  String cardGamesFoundation(String number) {
    return 'F$number';
  }

  @override
  String get cardGamesPatienceHint =>
      'Move cards down in alternating colors. Empty columns take kings. Build foundations from ace to king by suit.';

  @override
  String get smallGamesTitle => 'Small Games';

  @override
  String get smallGamesChooseGame => 'Choose a game to play.';

  @override
  String get smallGamesBingoName => 'BINGO';

  @override
  String get smallGamesBingoDescription =>
      'Draw numbers from the cage and make printable cards.';

  @override
  String get smallGamesOpenBingo => 'Open BINGO';

  @override
  String get smallGamesCardGamesName => 'Card Games';

  @override
  String get smallGamesCardGamesDescription =>
      'Take a seat at the casino table for Poker, Blackjack, or Patience.';

  @override
  String get smallGamesOpenCardGames => 'Open Card Games';

  @override
  String get smallGamesAllGames => 'All games';

  @override
  String smallGamesCalledCount(int count) {
    return '$count / 75 called';
  }

  @override
  String get smallGamesEnterQuantity => 'Enter a number from 1 to 500.';

  @override
  String smallGamesSavedCards(int count, String path) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Saved $count cards to $path',
      one: 'Saved 1 card to $path',
    );
    return '$_temp0';
  }

  @override
  String smallGamesExportFailed(String error) {
    return 'Could not export cards: $error';
  }

  @override
  String get smallGamesCageTitle => 'The draw cage';

  @override
  String get smallGamesCageSubtitle => 'Draw a ball to call the next number.';

  @override
  String get smallGamesReady => 'READY';

  @override
  String get smallGamesDrawNextBall => 'Draw next ball';

  @override
  String get smallGamesAllBallsDrawn => 'All balls drawn';

  @override
  String get smallGamesNewGame => 'New game';

  @override
  String get smallGamesCalledNumbers => 'Called numbers';

  @override
  String get smallGamesCalledNumbersHint =>
      'Every called ball stays highlighted.';

  @override
  String get smallGamesRecentDraws => 'Recent draws';

  @override
  String get smallGamesNoNumbersYet => 'No numbers called yet.';

  @override
  String get smallGamesExportTitle => 'Export BINGO cards';

  @override
  String get smallGamesExportDescription =>
      'Create one printable PDF with unique 5×5 cards, four per page in a 2×2 layout. The last page can contain fewer. Each card has a free center.';

  @override
  String get smallGamesNumberOfCards => 'Number of cards';

  @override
  String get smallGamesExportPdf => 'Export PDF';

  @override
  String get smartHomeRefreshLights => 'Refresh lights';

  @override
  String get smartHomeSubtitle =>
      'Control IKEA lamps through your DIRIGERA hub on this network.';

  @override
  String get smartHomeIkeaLamp => 'IKEA lamp';

  @override
  String get smartHomeOffline => 'Offline';

  @override
  String get smartHomeNoLampsFound => 'No IKEA lamps found';

  @override
  String get smartHomeAddLampHint =>
      'Add a lamp in the IKEA Home smart app, then refresh here.';

  @override
  String smartHomeLampsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lamps',
      one: '1 lamp',
    );
    return '$_temp0';
  }

  @override
  String get smartHomeConnectHub => 'Connect a DIRIGERA hub';

  @override
  String get smartHomeSameNetworkHint =>
      'Make sure this device and the hub are on the same home network.';

  @override
  String get smartHomeLookingForHubs => 'Looking for DIRIGERA hubs…';

  @override
  String get smartHomeHubsFound => 'Hubs found';

  @override
  String get smartHomeNoHubFound =>
      'No hub found. Check that DIRIGERA is powered on and this device is on the same home network.';

  @override
  String get smartHomeFindMyHub => 'Find my hub';

  @override
  String get smartHomeHideManualAddress => 'Hide manual address';

  @override
  String get smartHomeEnterIpManually => 'Enter IP address manually';

  @override
  String get smartHomeHubIpAddress => 'Hub IP address';

  @override
  String get smartHomeStartPairing => 'Start pairing';

  @override
  String get smartHomePressHubButton =>
      'Press the action button on the bottom of the DIRIGERA hub.';

  @override
  String get smartHomePressedButton => 'I pressed the button';

  @override
  String get smartHomePairingExpires => 'If pairing expires, start again.';

  @override
  String get smartHomeStartAgain => 'Start again';

  @override
  String get smartHomeConnected => 'DIRIGERA connected';

  @override
  String get smartHomeDisconnect => 'Disconnect';

  @override
  String get smartHomePresetsTitle => 'Presets';

  @override
  String get smartHomeNewPreset => 'New preset';

  @override
  String get smartHomePresetsEmpty =>
      'Save a group of lamps with its own brightness and color, then turn them on here with one tap.';

  @override
  String get smartHomePresetsTapHint => 'Tap a preset to turn on its lamps.';

  @override
  String smartHomeEditPreset(String name) {
    return 'Edit $name';
  }

  @override
  String smartHomePresetApplied(String name) {
    return '“$name” applied.';
  }

  @override
  String get smartHomeNewPresetTitle => 'New preset';

  @override
  String get smartHomeEditPresetTitle => 'Edit preset';

  @override
  String get smartHomeDeletePresetTitle => 'Delete preset?';

  @override
  String smartHomeDeletePresetBody(String name) {
    return '“$name” will be removed. Your lamps will not change.';
  }

  @override
  String get smartHomePresetNameLabel => 'Preset name';

  @override
  String get smartHomePresetNameHint => 'Evening';

  @override
  String get smartHomeChooseLamps => 'Choose the lamps this preset turns on.';

  @override
  String get smartHomeCouldNotSavePreset => 'Could not save this preset.';

  @override
  String get smartHomeCouldNotDeletePreset => 'Could not delete this preset.';

  @override
  String get smartHomeSavingPreset => 'Saving…';

  @override
  String get smartHomeSavePreset => 'Save preset';

  @override
  String smartHomeBrightnessPercent(int percent) {
    return 'Brightness $percent%';
  }

  @override
  String smartHomeColorIntensityPercent(int percent) {
    return 'Color intensity $percent%';
  }

  @override
  String smartHomeWhiteTemperatureKelvin(int kelvin) {
    return 'White temperature $kelvin K';
  }

  @override
  String get smartHomeNoColorSupport =>
      'This lamp does not support color changes.';

  @override
  String get smartHomeColorRed => 'Red';

  @override
  String get smartHomeColorOrange => 'Orange';

  @override
  String get smartHomeColorGreen => 'Green';

  @override
  String get smartHomeColorBlue => 'Blue';

  @override
  String get smartHomeColorPurple => 'Purple';

  @override
  String get smartHomeDefaultHubName => 'DIRIGERA hub';

  @override
  String get smartHomeEnterHubAddress =>
      'Enter the hub’s private IPv4 address from your router.';

  @override
  String get smartHomeNoPairingChallenge =>
      'The hub did not return a pairing challenge.';

  @override
  String get smartHomeNoAccessToken =>
      'The hub did not return an access token.';

  @override
  String get smartHomeInvalidDeviceList => 'Invalid hub device list.';

  @override
  String get smartHomeHubAddressMustBePrivate =>
      'The hub address must be a private IPv4 address.';

  @override
  String get smartHomeInvalidPresetLamp => 'Invalid preset lamp settings.';

  @override
  String get smartHomeLampFallbackName => 'IKEA lamp';

  @override
  String get smartHomePresetsLoadFailed =>
      'Could not load saved Smart Home presets.';

  @override
  String get smartHomeHubConnectionReadFailed =>
      'Could not read the saved hub connection from secure storage.';

  @override
  String get smartHomeDiscoverFailed =>
      'Could not search the local network for a DIRIGERA hub. Check local network permission, then try again or enter its IP address.';

  @override
  String get smartHomePresetNeedsNameAndLamp =>
      'Give the preset a name and select at least one lamp.';

  @override
  String get smartHomePresetUnsupportedSettings =>
      'A selected lamp has settings it does not support. Refresh the lamps and try again.';

  @override
  String smartHomePresetSaveFailed(String error) {
    return 'Could not save the preset. ($error)';
  }

  @override
  String smartHomePresetDeleteFailed(String error) {
    return 'Could not delete the preset. ($error)';
  }

  @override
  String get smartHomeInvalidSnapshot => 'Invalid smart home snapshot.';

  @override
  String get smartHomeLampMissing => 'Missing lamp';

  @override
  String smartHomeLampSettingsChanged(String name) {
    return '$name (settings changed)';
  }

  @override
  String get smartHomeStatusRefreshItem => 'status refresh';

  @override
  String smartHomePresetPartialApply(String name, String lamps) {
    return 'Preset \"$name\" could not fully apply: $lamps.';
  }

  @override
  String get smartHomeHubNoResponse =>
      'The DIRIGERA hub did not respond. Make sure this device and the hub are on the same home network, then find the hub again. Guest Wi-Fi or a VPN can prevent a connection.';

  @override
  String get smartHomeHubUnreachable =>
      'Could not reach the DIRIGERA hub. Check its connection and try again.';

  @override
  String get spaceColonyLinuxSubtitle =>
      'Space Colony requires an embedded WebView that is not yet supported on this platform.';

  @override
  String get steamCs2CatalogUnreachable =>
      'Could not reach the item catalog. Check your connection and try again.';

  @override
  String steamCs2CatalogHttpError(int status) {
    return 'The item catalog returned an error (HTTP $status).';
  }

  @override
  String get steamCs2CatalogUnreadable =>
      'The item catalog sent back something unreadable.';

  @override
  String get steamCs2MarketUnreachable =>
      'Could not reach the Steam Community Market. Check your connection and try again.';

  @override
  String get steamCs2MarketRateLimited =>
      'The Steam Community Market is rate limiting this device. Wait a few minutes and try again.';

  @override
  String steamCs2MarketHttpError(int status) {
    return 'The Steam Community Market could not price that item (HTTP $status).';
  }

  @override
  String get steamCs2MarketUnreadable =>
      'The Steam Community Market sent back an unreadable reply.';

  @override
  String steamCs2OfflineLoadFailed(String error) {
    return 'Could not load offline market saving: $error';
  }

  @override
  String steamCs2OfflineSaveFailed(String error) {
    return 'Could not save offline market setting: $error';
  }

  @override
  String steamCs2OfflineSyncFailed(String error) {
    return 'Could not sync offline market saving: $error';
  }

  @override
  String steamCs2CatalogUpdateFailed(String error) {
    return 'Could not update the item catalog: $error';
  }

  @override
  String steamCs2CheckPriceFailed(String error) {
    return 'Could not check that price: $error';
  }

  @override
  String get steamApiEnterIdOrUrl => 'Enter your Steam ID or profile URL.';

  @override
  String get steamApiNotSteamIdOrUrl =>
      'That does not look like a Steam ID or profile URL. Use your 17-digit ID, or the full link to your profile.';

  @override
  String steamApiUnknownProfile(String vanity) {
    return 'Steam does not know a profile called \"$vanity\". Check the name, or paste your 17-digit Steam ID instead.';
  }

  @override
  String get steamApiNoGames =>
      'Steam returned no games. Open your Steam privacy settings and set \"Game details\" to Public, then try again.';

  @override
  String get steamApiRejectedKey =>
      'Steam rejected the API key. Check it under Connect, or generate a new one at steamcommunity.com/dev/apikey.';

  @override
  String get steamApiRateLimited =>
      'Steam is rate limiting this device. Wait a few minutes and try again.';

  @override
  String steamApiUnreachable(String task) {
    String _temp0 = intl.Intl.selectLogic(task, {
      'resolveProfile': 'resolve that profile name',
      'readLibrary': 'read your library',
      'readStorePage': 'read that store page',
      'searchStore': 'search the store',
      'other': 'do that',
    });
    return 'Could not reach Steam to $_temp0. Check your connection and try again.';
  }

  @override
  String steamApiHttpError(String task, int status) {
    String _temp0 = intl.Intl.selectLogic(task, {
      'resolveProfile': 'resolve that profile name',
      'readLibrary': 'read your library',
      'readStorePage': 'read that store page',
      'searchStore': 'search the store',
      'other': 'do that',
    });
    return 'Steam could not $_temp0 (HTTP $status).';
  }

  @override
  String steamApiUnreadable(String task) {
    String _temp0 = intl.Intl.selectLogic(task, {
      'resolveProfile': 'resolve that profile name',
      'readLibrary': 'read your library',
      'readStorePage': 'read that store page',
      'searchStore': 'search the store',
      'other': 'do that',
    });
    return 'Steam sent back an unreadable reply to $_temp0.';
  }

  @override
  String get itadApiUnexpectedHistory =>
      'IsThereAnyDeal sent back an unexpected price history.';

  @override
  String get itadApiNotConfigured =>
      'The server operator has not set up price history. Ask them to add an IsThereAnyDeal key.';

  @override
  String get itadApiNeedsAccount =>
      'This needs a signed-in luma account. Sign in under Settings → Sync & account.';

  @override
  String get itadApiRateLimited =>
      'Too many price history requests right now. Wait a bit and try again.';

  @override
  String itadApiUnreachable(String task) {
    String _temp0 = intl.Intl.selectLogic(task, {
      'lookupGame': 'look that game up',
      'priceHistory': 'read that price history',
      'readGame': 'read that game',
      'other': 'do that',
    });
    return 'Could not reach the luma server to $_temp0. Check your connection and try again.';
  }

  @override
  String itadApiHttpError(String task, int status) {
    String _temp0 = intl.Intl.selectLogic(task, {
      'lookupGame': 'look that game up',
      'priceHistory': 'read that price history',
      'readGame': 'read that game',
      'other': 'do that',
    });
    return 'Could not $_temp0 (HTTP $status).';
  }

  @override
  String get steamLibraryNeverPlayed => 'Never played';

  @override
  String steamLibraryMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String steamLibraryHours(String hours) {
    return '$hours h';
  }

  @override
  String get steamRangeFiveYears => 'the last five years';

  @override
  String get steamRangeYear => 'the last year';

  @override
  String get steamRangeSixMonths => 'the last six months';

  @override
  String get steamRangeMonth => 'the last month';

  @override
  String get steamRangeWeek => 'the last week';

  @override
  String get steamRangeDay => 'the last day';

  @override
  String get steamRepoEnterApiKey => 'Enter your Steam Web API key.';

  @override
  String steamRepoConnectFailed(String error) {
    return 'Could not connect to Steam: $error';
  }

  @override
  String steamRepoRefreshFailed(String error) {
    return 'Could not refresh your library: $error';
  }

  @override
  String get cs2CalcTitle => 'CS2 Selling Calculator';

  @override
  String get cs2CalcSubtitle =>
      'See your estimated Steam Wallet proceeds after the market fees.';

  @override
  String get cs2CalcBuyerPays => 'Buyer pays';

  @override
  String get cs2CalcCurrency => 'Currency';

  @override
  String get cs2CalcYouReceive => 'You receive';

  @override
  String get cs2CalcSteamFee => 'Steam fee (5%)';

  @override
  String get cs2CalcGameFee => 'CS2 fee (10%)';

  @override
  String get cs2CalcDisclaimer =>
      'Estimate only. Fees are calculated separately and rounded down to cents, with a minimum of one cent each. Steam may handle other currencies differently.';

  @override
  String get cs2MarketOfflineTitle => 'Keep saving while offline';

  @override
  String get cs2MarketOfflineSignIn =>
      'Sign in to an approved Orbit or Nova account to enable this.';

  @override
  String get cs2MarketOfflineLoading => 'Loading the shared market tracker…';

  @override
  String get cs2MarketOfflineSaving => 'Saving your tracked listings…';

  @override
  String cs2MarketOfflineIntervalOff(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'The server checks tracked skins every $hours hours once enabled.',
      one: 'The server checks tracked skins every hour once enabled.',
    );
    return '$_temp0';
  }

  @override
  String get cs2MarketOfflineScheduled =>
      'Scheduled server checks are enabled.';

  @override
  String cs2MarketOfflineNextCheck(int hours, String time) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours',
      one: 'hour',
    );
    return 'Server checks every $_temp0 · next at $time';
  }

  @override
  String get cs2MarketSubtitleLoading => 'Loading the item catalog…';

  @override
  String get cs2MarketSubtitleNotLoaded => 'Item catalog not loaded yet.';

  @override
  String cs2MarketSubtitleCatalogued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items catalogued.',
      one: '1 item catalogued.',
    );
    return '$_temp0';
  }

  @override
  String cs2MarketSubtitleUpdatedDays(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items catalogued, updated ${days}d ago.',
      one: '1 item catalogued, updated ${days}d ago.',
    );
    return '$_temp0';
  }

  @override
  String cs2MarketSubtitleUpdatedHours(int count, int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items catalogued, updated ${hours}h ago.',
      one: '1 item catalogued, updated ${hours}h ago.',
    );
    return '$_temp0';
  }

  @override
  String cs2MarketSubtitleUpdatedJustNow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items catalogued, updated just now.',
      one: '1 item catalogued, updated just now.',
    );
    return '$_temp0';
  }

  @override
  String get cs2MarketTrackedSettings => 'Tracked settings';

  @override
  String get cs2MarketCountAsInvestments => 'Count CS2 value as investments';

  @override
  String get cs2MarketCountAsInvestmentsHint =>
      'Include tracked weapon values in Finance and the dashboard.';

  @override
  String get cs2MarketRefreshCatalog => 'Refresh catalog';

  @override
  String get cs2MarketUpdating => 'Updating…';

  @override
  String get cs2MarketRefreshPrices => 'Refresh prices';

  @override
  String get cs2MarketChecking => 'Checking…';

  @override
  String get cs2MarketBrowse => 'Browse';

  @override
  String get cs2MarketTracked => 'Tracked';

  @override
  String get cs2MarketSearchTracked =>
      'Search what you track — name, weapon, rarity';

  @override
  String get cs2MarketSearchAny =>
      'Search any CS2 item — name, weapon, rarity, case';

  @override
  String cs2MarketCheckingProgress(int done, int total) {
    return 'Checking prices — $done of $total';
  }

  @override
  String get cs2MarketDismiss => 'Dismiss';

  @override
  String get cs2MarketCatalogEmpty => 'Catalog is empty';

  @override
  String get cs2MarketCatalogEmptyHint =>
      'Refresh the catalog to load every CS2 item.';

  @override
  String get cs2MarketKeepTyping => 'Keep typing';

  @override
  String get cs2MarketKeepTypingHint =>
      'One letter matches too much of the catalog to be useful — a couple more will narrow it down.';

  @override
  String cs2MarketNoMatch(String query) {
    return 'No items match \"$query\"';
  }

  @override
  String get cs2MarketNoMatchHint =>
      'Try a weapon name, a rarity like \"Covert\", or a case name.';

  @override
  String cs2MarketTileLabelCase(String name, String rarity, String caseName) {
    return '$name, $rarity. From $caseName';
  }

  @override
  String cs2MarketTileLabelNoCase(String name, String rarity) {
    return '$name, $rarity. No case';
  }

  @override
  String cs2MarketTileLabelCasePinned(
    String name,
    String rarity,
    String caseName,
  ) {
    return '$name, $rarity. From $caseName. Pinned';
  }

  @override
  String cs2MarketTileLabelNoCasePinned(String name, String rarity) {
    return '$name, $rarity. No case. Pinned';
  }

  @override
  String get cs2MarketNoCase => 'No case';

  @override
  String get cs2MarketPinToTop => 'Pin to top';

  @override
  String get cs2MarketUnpin => 'Unpin';

  @override
  String get cs2TrackListing => 'Track this listing';

  @override
  String get cs2TrackAnotherCopy => 'Track another copy';

  @override
  String get cs2ItemSubtitleAnotherCopy =>
      'The price to measure this copy\'s gain and loss from.';

  @override
  String get cs2ItemSubtitleNewListing =>
      'Pick the grade, and the price to measure gain and loss from.';

  @override
  String get cs2ItemSetStartingPrice => 'Set starting price';

  @override
  String get cs2ItemEditStartingPrice => 'Edit starting price';

  @override
  String get cs2ItemStartingPriceSubtitle =>
      'The price this copy\'s gain and loss is measured from.';

  @override
  String get cs2ItemNotFound => 'Item not found';

  @override
  String get cs2ItemNotFoundHint =>
      'It may have dropped out of the last catalog update — try refreshing the catalog.';

  @override
  String get cs2ItemBackToMarket => 'Back to the market';

  @override
  String get cs2ItemWear => 'Wear';

  @override
  String get cs2ItemVariant => 'Variant';

  @override
  String get cs2ItemNormal => 'Normal';

  @override
  String get cs2ItemLowestListed => 'Lowest listed';

  @override
  String get cs2ItemCouldNotCheck => 'Could not check price';

  @override
  String get cs2ItemNotCheckedYet => 'Not checked yet';

  @override
  String cs2ItemMedian(String price) {
    return 'Median $price';
  }

  @override
  String get cs2ItemCheckNow => 'Check now';

  @override
  String get cs2ItemQuickCheckNotSaved =>
      'A quick check, not saved — track this listing to keep a history of its price.';

  @override
  String get cs2ItemStatusNotChecked => 'Not checked yet.';

  @override
  String get cs2ItemCheckedJustNow => 'Checked just now.';

  @override
  String cs2ItemCheckedMinutes(int minutes) {
    return 'Checked $minutes min ago.';
  }

  @override
  String cs2ItemCheckedHours(int hours) {
    return 'Checked $hours h ago.';
  }

  @override
  String cs2ItemCheckedOn(String date) {
    return 'Checked on $date.';
  }

  @override
  String cs2ItemTrackedOn(String date) {
    return 'Tracked $date';
  }

  @override
  String cs2ItemYourCopies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Your copies ($count)',
      one: 'Your copy',
    );
    return '$_temp0';
  }

  @override
  String get cs2ItemNoStartingPrice => 'No starting price set';

  @override
  String get cs2ItemSetPrice => 'Set price';

  @override
  String get cs2ItemClearPrice => 'Clear price';

  @override
  String get cs2ItemStopTrackingCopy => 'Stop tracking this copy';

  @override
  String get cs2ItemFactWeapon => 'Weapon';

  @override
  String get cs2ItemFactRarity => 'Rarity';

  @override
  String get cs2ItemFactCase => 'Case';

  @override
  String get cs2ItemFactNoCase => 'No case — collection or promo item';

  @override
  String get cs2ItemFactAvailable => 'Available for this finish';

  @override
  String get cs2ItemFactSouvenir => 'Souvenir';

  @override
  String get cs2ItemOpenOnMarket => 'Open on Steam Market';

  @override
  String get cs2ChartPriceHistory => 'Price history';

  @override
  String get cs2ChartGainLoss => 'Gain & Loss';

  @override
  String get cs2ChartNoReadings => 'No price readings available.';

  @override
  String cs2ChartGainLossUnchanged(String delta) {
    return 'Unchanged at $delta against the starting price across the readings shown.';
  }

  @override
  String cs2ChartGainLossBetween(String low, String high) {
    return 'Between $low and $high against the starting price across the readings shown.';
  }

  @override
  String get cs2ChartOneReading =>
      'One reading so far — a trend needs at least two.';

  @override
  String cs2ChartUnchangedAcrossCount(String delta, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count readings',
      one: '1 reading',
    );
    return 'Unchanged at $delta across $_temp0.';
  }

  @override
  String cs2ChartBetweenShown(String low, String high) {
    return 'Between $low and $high across the readings shown.';
  }

  @override
  String cs2ChartUnchangedShown(String price) {
    return 'Unchanged at $price across the readings shown.';
  }

  @override
  String get cs2ChartBest => 'Best';

  @override
  String get cs2ChartWorst => 'Worst';

  @override
  String get cs2ChartLowest => 'Lowest';

  @override
  String get cs2ChartHighest => 'Highest';

  @override
  String get cs2ChartNoHistory => 'No history yet';

  @override
  String get cs2ChartNoHistoryHint =>
      'Steam\'s market publishes no history of its own — track this listing and luma starts building one from here.';

  @override
  String get cs2ChartNoReadingsInRange => 'No readings in this range';

  @override
  String get cs2ChartTryWiderRange =>
      'Try a wider range, or check the price again.';

  @override
  String get steamFreeToPlay => 'Free to play';

  @override
  String get steamFreeToPlaySemantics => 'Free to play.';

  @override
  String get steamPriceNotChecked => 'Not checked yet';

  @override
  String get steamPriceNotCheckedSemantics => 'Price not checked yet.';

  @override
  String get steamPriceChecking => 'Checking…';

  @override
  String steamPriceCosts(String price) {
    return 'Costs $price.';
  }

  @override
  String get steamTrackAGame => 'Track a game';

  @override
  String get steamDismiss => 'Dismiss';

  @override
  String get steamAccountSettingsTooltip => 'Steam account settings';

  @override
  String get cs2StartPriceEnterValid => 'Enter a valid price.';

  @override
  String get cs2StartPriceGrade => 'Grade';

  @override
  String get cs2StartPriceGradeHelper =>
      'Wear and price are set together — they can\'t be changed independently once tracking starts.';

  @override
  String get cs2StartPriceGradeFixedHelper =>
      'Fixed — this baseline belongs to that exact listing.';

  @override
  String get cs2StartPriceStartingPrice => 'Starting price';

  @override
  String get cs2StartPriceStartingPriceHelper =>
      'What you paid, or the price to measure gain and loss from — not fetched from Steam.';

  @override
  String get cs2TrackedEmptyTitle => 'Nothing tracked yet';

  @override
  String get cs2TrackedEmptySubtitle =>
      'Track a listing from Browse to start watching its price — it shows up here, alongside everything else you track.';

  @override
  String cs2TrackedNoMatchTitle(String query) {
    return 'No tracked items match \"$query\"';
  }

  @override
  String get cs2TrackedNoMatchSubtitle =>
      'Try a different weapon name or rarity.';

  @override
  String get cs2TrackedTotalValue => 'Total value';

  @override
  String cs2TrackedCopiesTracked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count copies tracked',
      one: '1 copy tracked',
    );
    return '$_temp0';
  }

  @override
  String cs2TrackedGainLossCoverage(int withStart, int total) {
    return 'Gain/loss covers the $withStart of $total with a starting price set.';
  }

  @override
  String get cs2NoWearVariants => 'No wear variants';

  @override
  String get cs2RangeAll => 'All';

  @override
  String get steamAccountTitle => 'Steam account';

  @override
  String get steamAccountSubtitle => 'So luma can list the games you own.';

  @override
  String get steamAccountConnected => 'Connected';

  @override
  String steamAccountConnectedWithKey(String maskedKey) {
    return 'Connected — $maskedKey';
  }

  @override
  String get steamAccountApiKeyLabel => 'Steam Web API key';

  @override
  String get steamAccountKeyHelperConnected =>
      'Leave blank to keep the saved key.';

  @override
  String get steamAccountKeyHelperNew => 'Free, and tied to your own account.';

  @override
  String get steamAccountKeyHintReplace => 'Enter a new key to replace it';

  @override
  String get steamAccountHideKey => 'Hide key';

  @override
  String get steamAccountShowKey => 'Show key';

  @override
  String get steamAccountGetKey => 'Get a key from Steam';

  @override
  String get steamAccountIdLabel => 'Steam ID or profile URL';

  @override
  String get steamAccountIdHelper =>
      'Your 17-digit ID, or a link like steamcommunity.com/id/yourname.';

  @override
  String get steamAccountErrorNoKey => 'Paste your Steam Web API key.';

  @override
  String get steamAccountErrorNoId => 'Enter your Steam ID or profile URL.';

  @override
  String get steamAccountConnect => 'Connect';

  @override
  String get steamAccountDisconnect => 'Disconnect';

  @override
  String get steamAccountEncryptedNote =>
      'Your key is stored encrypted on this device and is sent only to Steam — never to a luma server.';

  @override
  String get steamAccountPrivacyNote =>
      'Steam only returns your library when \"Game details\" is set to Public in your privacy settings.';

  @override
  String get steamAccountHistoryNote =>
      'Price history needs a signed-in luma account too — it is fetched through the server, so no separate key is needed for it.';

  @override
  String get steamDetailNoLongerInLibraryTitle =>
      'That game is no longer in your library';

  @override
  String get steamDetailNoLongerInLibrarySubtitle =>
      'Refresh your library to see what changed.';

  @override
  String get steamDetailBackTooltip => 'Back to your library';

  @override
  String get steamDetailPriceNow => 'Price now';

  @override
  String get steamDetailCheckNow => 'Check now';

  @override
  String steamDetailWasPrice(String price) {
    return 'was $price';
  }

  @override
  String get steamDetailNeverPriced => 'This game has not been priced yet.';

  @override
  String get steamDetailCheckedJustNow => 'Checked just now.';

  @override
  String steamDetailCheckedMinutes(int count) {
    return 'Checked $count min ago.';
  }

  @override
  String steamDetailCheckedHours(int count) {
    return 'Checked $count h ago.';
  }

  @override
  String steamDetailCheckedOn(String date) {
    return 'Checked on $date.';
  }

  @override
  String get steamDetailAboutTitle => 'About this game';

  @override
  String get steamDetailTags => 'Tags';

  @override
  String get steamDetailRequirementsTitle => 'System requirements';

  @override
  String get steamDetailReadingStore => 'Reading the store page…';

  @override
  String get steamDetailNoPcRequirements =>
      'Steam lists no PC requirements for this game.';

  @override
  String get steamDetailReqMinimum => 'Minimum';

  @override
  String get steamDetailReqRecommended => 'Recommended';

  @override
  String get steamDetailDeveloper => 'Developer';

  @override
  String get steamDetailPublisher => 'Publisher';

  @override
  String get steamDetailReleased => 'Released';

  @override
  String get steamDetailPlatforms => 'Platforms';

  @override
  String get steamDetailYourPlaytime => 'Your playtime';

  @override
  String get steamDetailPlaytimeNever => 'Never played';

  @override
  String steamDetailPlaytimeMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String steamDetailPlaytimeHours(String hours) {
    return '$hours hours';
  }

  @override
  String steamDetailPlaytimeHoursWhole(int count) {
    return '$count hours';
  }

  @override
  String get steamDetailOpenOnSteam => 'Open on Steam';

  @override
  String get steamDetailStopTracking => 'Stop tracking';

  @override
  String steamDetailStopTrackingTitle(String name) {
    return 'Stop tracking $name?';
  }

  @override
  String get steamDetailStopTrackingOwned =>
      'This removes it from your tracked games and deletes its price history on this device. It is still in your Steam library, so refreshing the library later will add it back.';

  @override
  String get steamDetailStopTrackingUnowned =>
      'This removes it from your tracked games and deletes its price history on this device.';

  @override
  String get steamChartTitle => 'Price history';

  @override
  String get steamChartNoHistory => 'No price history available.';

  @override
  String get steamChartRangeFiveYears => 'the last five years';

  @override
  String get steamChartRangeYear => 'the last year';

  @override
  String get steamChartRangeSixMonths => 'the last six months';

  @override
  String get steamChartRangeMonth => 'the last month';

  @override
  String get steamChartRangeWeek => 'the last week';

  @override
  String get steamChartRangeDay => 'the last day';

  @override
  String steamChartSummaryFlat(String range, String price) {
    return 'Price history over $range: unchanged at $price.';
  }

  @override
  String steamChartSummaryRange(String range, String low, String high) {
    return 'Price history over $range: between $low and $high.';
  }

  @override
  String steamChartUnchangedAcross(String price, String range) {
    return 'Unchanged at $price across $range.';
  }

  @override
  String get steamChartLowestInRange => 'Lowest in range';

  @override
  String get steamChartHighestInRange => 'Highest in range';

  @override
  String get steamChartAllTimeLow => 'All-time low';

  @override
  String steamChartAllTimeLowSince(String date) {
    return 'All-time low ($date)';
  }

  @override
  String get steamChartFromIsThereAnyDeal =>
      'Steam price history from IsThereAnyDeal.';

  @override
  String steamChartFromIsThereAnyDealFull(String range) {
    return 'Steam price history from IsThereAnyDeal, covering all of $range.';
  }

  @override
  String steamChartShortHistory(String date, String range) {
    return 'IsThereAnyDeal has this game from $date, which is less than $range.';
  }

  @override
  String get steamChartSignInTitle => 'Sign in for price history';

  @override
  String get steamChartSignInBody =>
      'Steam only publishes what a game costs today. A signed-in luma account reads the years behind it — no extra key to find or paste in.';

  @override
  String steamChartNoHistoryOver(String range) {
    return 'No price history over $range';
  }

  @override
  String get steamChartNothingOnFile =>
      'IsThereAnyDeal has nothing on file for this game.';

  @override
  String get steamSearchSubtitle =>
      'Search the Steam store — no account needed.';

  @override
  String get steamSearchHint => 'Search for a game';

  @override
  String get steamSearchStartHint =>
      'Search by a game\'s name to start tracking its price.';

  @override
  String steamSearchCouldNot(String error) {
    return 'Could not search Steam: $error';
  }

  @override
  String steamSearchNoMatch(String query) {
    return 'No games matched \"$query\".';
  }

  @override
  String steamSearchAlreadyTracked(String name) {
    return '$name, already tracked';
  }

  @override
  String steamSearchTapToTrack(String name) {
    return '$name, tap to track';
  }

  @override
  String get steamTrackerSortPlaytime => 'Playtime';

  @override
  String get steamTrackerTitle => 'Price Tracker';

  @override
  String get steamTrackerSubtitleDisconnected =>
      'Tracking prices — connect a Steam account to bulk-add your library too.';

  @override
  String get steamTrackerSubtitleNoSync =>
      'Connected. Refresh library to import it.';

  @override
  String get steamTrackerSyncedJustNow => 'Library synced just now.';

  @override
  String steamTrackerSyncedMinutes(int count) {
    return 'Library synced $count min ago.';
  }

  @override
  String steamTrackerSyncedHours(int count) {
    return 'Library synced $count h ago.';
  }

  @override
  String steamTrackerSyncedDays(int count) {
    return 'Library synced $count d ago.';
  }

  @override
  String get steamTrackerRefreshLibrary => 'Refresh library';

  @override
  String get steamTrackerRefreshPrices => 'Refresh prices';

  @override
  String get steamTrackerSearchHint => 'Search tracked games';

  @override
  String steamTrackerCheckingPrices(int done, int total) {
    return 'Checking prices — $done of $total';
  }

  @override
  String get steamTrackerEmptyTitle => 'Track your first game';

  @override
  String get steamTrackerEmptySubtitle =>
      'Search for a game to start watching its price — no Steam account needed.';

  @override
  String steamTrackerNoMatchTitle(String query) {
    return 'No games match \"$query\"';
  }

  @override
  String get steamTrackerNoMatchSubtitle => 'Try a shorter search.';

  @override
  String steamTrackerPlaytimeMinutes(int count) {
    return '$count min';
  }

  @override
  String steamTrackerPlaytimeHours(String hours) {
    return '$hours h';
  }

  @override
  String steamTrackerPlaytimeHoursWhole(int count) {
    return '$count h';
  }

  @override
  String get steamTrackerUnplayed => 'Unplayed';

  @override
  String get subwayBuilderNotOnLinuxTitle => 'Not available on Linux';

  @override
  String get subwayBuilderNotOnLinuxSubtitle =>
      'Subway Builder requires an embedded WebView that is not yet supported on this platform.';

  @override
  String get textLibraryClassroomSignIn =>
      'Sign in to an approved luma account to use the classroom.';

  @override
  String get textLibraryClassroomOffline =>
      'Could not reach the luma server. Check your connection and try again.';

  @override
  String textLibraryClassroomFailed(int status) {
    return 'The classroom failed (HTTP $status).';
  }

  @override
  String get textLibraryClassroomMalformed =>
      'The server sent a malformed answer.';

  @override
  String get textLibraryClassroomUnknownRequest => 'Unknown classroom request.';

  @override
  String get textLibraryDefaultSubjectName => 'Subject';

  @override
  String transportTrackerConnectionError(String error) {
    return 'Connection error: $error';
  }

  @override
  String transportTrackerCouldNotConnect(String error) {
    return 'Could not connect: $error';
  }

  @override
  String transitArchivePartialUnsupported(int code) {
    return 'The transit archive does not support partial downloads (HTTP $code).';
  }

  @override
  String get transitArchiveSizeUnknown =>
      'Could not determine the archive size.';

  @override
  String get transitArchiveIndexUnreadable =>
      'The archive index is unreadable.';

  @override
  String get transitArchiveIndexUnreadableZip64 =>
      'The archive index is unreadable (zip64).';

  @override
  String transitArchiveMemberMissing(String name) {
    return '$name is not in the archive.';
  }

  @override
  String get transitRoutesEmpty => 'The route list came back empty.';

  @override
  String get transitStopsEmpty => 'The stop list came back empty.';

  @override
  String get transitStopsMissingColumns =>
      'The stop list is missing expected columns.';

  @override
  String transitFeedRateLimited(int minutes) {
    return 'The transit feed is rate-limiting this device. Pausing for $minutes min.';
  }

  @override
  String transitFeedHttpError(int code) {
    return 'Transit feed returned HTTP $code.';
  }

  @override
  String transitFeedLoadFailed(String error) {
    return 'Could not load the transit feed: $error';
  }

  @override
  String get transitModeHighSpeed => 'High-speed';

  @override
  String get transitModeTrain => 'Train';

  @override
  String get transitModeMetro => 'Metro';

  @override
  String get transitModeTram => 'Tram';

  @override
  String get transitModeBus => 'Bus';

  @override
  String get transitModeFerry => 'Ferry';

  @override
  String get transportPrefsInvalidSnapshot =>
      'Invalid transport tracker snapshot.';

  @override
  String get transportTrackerLinuxSubtitle =>
      'Transport Tracker requires an embedded WebView that is not yet supported on this platform.';

  @override
  String get transportTrackerLive => 'Live';

  @override
  String get transportTrackerConnecting => 'Connecting…';

  @override
  String get transportTrackerStopped => 'Stopped';

  @override
  String get transportTrackerIdle => 'Idle';

  @override
  String get transportTrackerStopFeedTooltip => 'Stop the live AIS feed';

  @override
  String get transportTrackerStartFeedTooltip =>
      'Start a live AIS feed for the area on screen';

  @override
  String get transportTrackerWaitingForMapTooltip =>
      'Waiting for the map to finish loading';

  @override
  String get transportTrackerStopTracking => 'Stop tracking';

  @override
  String get transportTrackerTrackView => 'Track this view';

  @override
  String get transportTrackerChooseLayersTooltip => 'Choose what to track';

  @override
  String get transportTrackerApiKeySettingsTooltip =>
      'AISStream.io API key settings';

  @override
  String transportTrackerVesselsCount(int count) {
    return 'Vessels ($count)';
  }

  @override
  String transportTrackerVesselsAndTransitCount(int vessels, int transit) {
    return 'Vessels ($vessels) · Transit ($transit)';
  }

  @override
  String get transportTrackerAddKeyToSeeShips =>
      'Add a free AISStream.io API key to see live ships.';

  @override
  String get transportTrackerConnectedWaiting =>
      'Connected — waiting for position reports. Busy shipping lanes fill in within seconds; open ocean can take longer.';

  @override
  String transportTrackerNoVesselsYet(String label) {
    return 'No vessels yet. Press \"$label\" to start the live feed for the area on screen.';
  }

  @override
  String get transportTrackerNoAisYet =>
      'No AIS messages received yet. If this stays at zero, the key may be rejected or this area may have no reporting traffic.';

  @override
  String transportTrackerAisMessagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count AIS messages received.',
      one: '1 AIS message received.',
    );
    return '$_temp0';
  }

  @override
  String transportTrackerMapLoadFailed(String error) {
    return 'The map could not load fully — check this device\'s internet connection. ($error)';
  }

  @override
  String get transportTrackerAddKeyPrompt => 'Add your free API key';

  @override
  String transportTrackerKnots(String value) {
    return '$value kn';
  }

  @override
  String get transportTrackerBackToVessels => 'Back to vessel list';

  @override
  String get transportTrackerCallSign => 'Call sign';

  @override
  String get transportTrackerSpeed => 'Speed';

  @override
  String get transportTrackerCourse => 'Course';

  @override
  String get transportTrackerHeading => 'Heading';

  @override
  String get transportTrackerDestination => 'Destination';

  @override
  String get transportTrackerDraught => 'Draught';

  @override
  String get transportTrackerPosition => 'Position';

  @override
  String get transportTrackerLastReport => 'Last report';

  @override
  String transportTrackerMetres(String value) {
    return '$value m';
  }

  @override
  String transportTrackerKmh(String value) {
    return '$value km/h';
  }

  @override
  String get transportTrackerBackToList => 'Back to list';

  @override
  String get transportTrackerLine => 'Line';

  @override
  String get transportTrackerMode => 'Mode';

  @override
  String get transportTrackerVehicleNumber => 'Vehicle #';

  @override
  String get transportTrackerOperator => 'Operator';

  @override
  String get transportTrackerLastUpdate => 'Last update';

  @override
  String get transportTrackerInterpolatedNote =>
      'Estimated from the timetable — trains do not broadcast their position in the open data, so this is interpolated between stations.';

  @override
  String get transportTrackerDownloadingStops =>
      'Downloading stop names (about 1.4 MB, once)…';

  @override
  String transportTrackerStopNamesUnavailable(String error) {
    return 'Stop names unavailable: $error';
  }

  @override
  String get transportTrackerNoPredictions =>
      'No stop predictions are published for this journey.';

  @override
  String get transportTrackerNoRemainingStops =>
      'This journey has no remaining stops.';

  @override
  String get transportTrackerNextStops => 'NEXT STOPS';

  @override
  String get transportTrackerUnknownStop => 'Unknown stop';

  @override
  String transportTrackerCountdownSeconds(int count) {
    return '$count sec';
  }

  @override
  String transportTrackerCountdownMinutes(int count) {
    return '$count min';
  }

  @override
  String transportTrackerCountdownHoursMinutes(int hours, String minutes) {
    return '$hours h $minutes min';
  }

  @override
  String transportTrackerSecondsAgo(int count) {
    return '${count}s ago';
  }

  @override
  String transportTrackerMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String transportTrackerHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String get transportTrackerLayersTitle => 'What to track';

  @override
  String get transportTrackerShips => 'Ships';

  @override
  String get transportTrackerShipsSubtitle =>
      'Live AIS vessel positions worldwide. Needs your own free AISStream.io key.';

  @override
  String get transportTrackerTransitTitle => 'Public transport — Netherlands';

  @override
  String get transportTrackerTransitSubtitle =>
      'Live trains, metros, trams, buses and ferries from the Dutch open-data feed. No key needed.';

  @override
  String get transportTrackerModes => 'Modes';

  @override
  String get transportTrackerKeyDialogTitle => 'AISStream.io API key';

  @override
  String get transportTrackerGetKeyHint =>
      'Get a free key at aisstream.io — sign in, then copy your API key from the dashboard.';

  @override
  String get transportTrackerKeyHintReplace => 'Enter a new key to replace it';

  @override
  String get transportTrackerKeyHintPaste => 'Paste your API key';

  @override
  String get transportTrackerShowKey => 'Show key';

  @override
  String get transportTrackerHideKey => 'Hide key';

  @override
  String get transportTrackerKeyPrivacyNote =>
      'Stored locally on this device only, encrypted at rest. Sent directly to aisstream.io when tracking — never to any luma server.';

  @override
  String get vesselCategoryCargo => 'Cargo';

  @override
  String get vesselCategoryTanker => 'Tanker';

  @override
  String get vesselCategoryPassenger => 'Passenger';

  @override
  String get vesselCategoryFishing => 'Fishing';

  @override
  String get vesselCategoryHighSpeed => 'High-speed craft';

  @override
  String get vesselCategoryTug => 'Tug / service';

  @override
  String get vesselCategoryLawEnforcement => 'Law enforcement';

  @override
  String get vesselCategorySearchAndRescue => 'Search & rescue';

  @override
  String get vesselCategoryPleasureCraft => 'Pleasure craft';

  @override
  String get vesselCategoryUnspecified => 'Unspecified';

  @override
  String get vesselNavUnderWayEngine => 'Under way (engine)';

  @override
  String get vesselNavAtAnchor => 'At anchor';

  @override
  String get vesselNavNotUnderCommand => 'Not under command';

  @override
  String get vesselNavRestrictedManoeuvrability => 'Restricted manoeuvrability';

  @override
  String get vesselNavConstrainedByDraught => 'Constrained by draught';

  @override
  String get vesselNavMoored => 'Moored';

  @override
  String get vesselNavAground => 'Aground';

  @override
  String get vesselNavUnderWaySailing => 'Under way (sailing)';

  @override
  String get vesselNavAisSart => 'AIS-SART (distress beacon)';

  @override
  String vesselMmsiName(int mmsi) {
    return 'MMSI $mmsi';
  }

  @override
  String get usageRangeLast7Days => 'Last week';

  @override
  String get usageRangeThisMonth => 'This month';

  @override
  String get usageRangeLast30Days => 'Last month';

  @override
  String get usageRangeCustom => 'Custom…';

  @override
  String get usageWindowsOnlyTitle => 'Windows only';

  @override
  String get usageWindowsOnlySubtitle =>
      'Usage reads the foreground window, which luma can only do in the Windows desktop app.';

  @override
  String get usageStatusPaused => 'Paused';

  @override
  String get usageStatusIdle => 'Idle';

  @override
  String usageStatusTracking(String appName) {
    return 'Tracking $appName';
  }

  @override
  String get usageSummaryTotalTracked => 'Total tracked';

  @override
  String get usageSummaryAppsUsed => 'Apps used';

  @override
  String get usageSummaryTopApp => 'Top app';

  @override
  String get usageNeedWiderRange =>
      'Pick a wider range to see a daily breakdown';

  @override
  String get usageEmptyTitle => 'No activity yet';

  @override
  String get usageEmptySubtitle =>
      'Usage will show up here once you use apps on this PC.';

  @override
  String get usageClearConfirmTitle => 'Clear all usage history?';

  @override
  String get usageClearConfirmBody =>
      'This deletes every tracked session and cannot be undone.';

  @override
  String get usageClearAllHistory => 'Clear all history';

  @override
  String get usagePauseTracking => 'Pause tracking';

  @override
  String usageSampleEvery(int seconds) {
    return 'Sample every ${seconds}s';
  }

  @override
  String usageDurationSeconds(String seconds) {
    return '${seconds}s';
  }

  @override
  String usageDurationMinutes(String minutes) {
    return '${minutes}m';
  }

  @override
  String usageDurationHours(String hours) {
    return '${hours}h';
  }

  @override
  String usageDurationHoursMinutes(String hours, String minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String get usageInvalidSnapshot => 'Invalid usage snapshot.';

  @override
  String get whiteboardToolSelect => 'Select';

  @override
  String get whiteboardToolPan => 'Pan';

  @override
  String get whiteboardToolPen => 'Pen';

  @override
  String get whiteboardToolHighlighter => 'Highlighter';

  @override
  String get whiteboardToolEraser => 'Eraser';

  @override
  String get whiteboardToolLine => 'Line';

  @override
  String get whiteboardToolArrow => 'Arrow';

  @override
  String get whiteboardToolRectangle => 'Rectangle';

  @override
  String get whiteboardToolEllipse => 'Ellipse';

  @override
  String get whiteboardToolStickyNote => 'Sticky note';

  @override
  String get whiteboardToolText => 'Text';

  @override
  String get whiteboardInkGraphite => 'Graphite';

  @override
  String get whiteboardInkRed => 'Red';

  @override
  String get whiteboardInkOrange => 'Orange';

  @override
  String get whiteboardInkGreen => 'Green';

  @override
  String get whiteboardInkBlue => 'Blue';

  @override
  String get whiteboardInkPurple => 'Purple';

  @override
  String get whiteboardInkPink => 'Pink';

  @override
  String get whiteboardWidthFine => 'Fine';

  @override
  String get whiteboardWidthMedium => 'Medium';

  @override
  String get whiteboardWidthBold => 'Bold';

  @override
  String get whiteboardExportEmpty =>
      'There is nothing on this board to export.';

  @override
  String get whiteboardExportEncodeFailed => 'The image could not be encoded.';

  @override
  String get whiteboardExportDialogTitle => 'Save whiteboard image';

  @override
  String whiteboardToolTooltip(String label, String shortcut) {
    return '$label ($shortcut)';
  }

  @override
  String get whiteboardUndoTooltip => 'Undo (Ctrl+Z)';

  @override
  String get whiteboardRedoTooltip => 'Redo (Ctrl+Shift+Z)';

  @override
  String get whiteboardDeleteSelectionTooltip => 'Delete selection (Del)';

  @override
  String whiteboardInkSemantics(String name) {
    return '$name ink';
  }

  @override
  String whiteboardStrokeTooltip(String name) {
    return '$name stroke';
  }

  @override
  String get whiteboardZoomOut => 'Zoom out';

  @override
  String get whiteboardZoomIn => 'Zoom in';

  @override
  String get whiteboardResetZoomTooltip => 'Reset zoom (Ctrl+0)';

  @override
  String get whiteboardShowGrid => 'Show grid';

  @override
  String get whiteboardHideGrid => 'Hide grid';

  @override
  String get whiteboardExportPng => 'Export as PNG';

  @override
  String get whiteboardClearBoardTooltip => 'Clear board';

  @override
  String whiteboardItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get whiteboardBackTooltip => 'Back to boards (Esc)';

  @override
  String get whiteboardNewStickyNote => 'New sticky note';

  @override
  String get whiteboardNewText => 'New text';

  @override
  String get whiteboardEditNote => 'Edit note';

  @override
  String get whiteboardEditText => 'Edit text';

  @override
  String get whiteboardTextLabel => 'Text';

  @override
  String get whiteboardNewLineHint => 'Shift+Enter for a new line';

  @override
  String get whiteboardClearTitle => 'Clear the board?';

  @override
  String whiteboardClearContent(int count, String title) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'All $count things on \"$title\" will be removed. You can undo this straight afterwards.',
      one:
          'The only thing on \"$title\" will be removed. You can undo this straight afterwards.',
    );
    return '$_temp0';
  }

  @override
  String whiteboardExportFailed(String error) {
    return 'Could not export the board: $error';
  }

  @override
  String get whiteboardNameHint => 'Name a new whiteboard';

  @override
  String get whiteboardEmptyTitle => 'No whiteboards yet';

  @override
  String get whiteboardEmptySubtitle =>
      'Name one above and start drawing. Pen, shapes, arrows and sticky notes, with the whole board saved as you go.';

  @override
  String get whiteboardRenameTooltip => 'Rename board';

  @override
  String get whiteboardDeleteBoardTooltip => 'Delete board';

  @override
  String whiteboardDeleteBoardTitle(String title) {
    return 'Delete \"$title\"?';
  }

  @override
  String whiteboardDeleteBoardContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'All $count things drawn on this board will be removed for good. This cannot be undone.',
      one:
          'The only thing drawn on this board will be removed for good. This cannot be undone.',
      zero: 'This board is empty. It will be removed for good.',
    );
    return '$_temp0';
  }

  @override
  String get speedTestTryAgain => 'Try Again';

  @override
  String get speedTestStart => 'Start Test';

  @override
  String get speedTestTesting => 'Testing — please wait…';

  @override
  String get speedTestFailed =>
      'Test failed. Check your connection and try again.';

  @override
  String get speedTestReady => 'Ready';

  @override
  String get speedTestPinging => 'Pinging…';

  @override
  String get speedTestDownloading => 'Downloading';

  @override
  String get speedTestUploading => 'Uploading';

  @override
  String get speedTestCheckingNetwork => 'Checking network…';

  @override
  String get speedTestShowName => 'Show name';

  @override
  String get speedTestShowDetails => 'Show details';

  @override
  String get speedTestPing => 'Ping';

  @override
  String get speedTestClearHistoryTitle => 'Clear history?';

  @override
  String get speedTestClearHistoryContent =>
      'All past speed test results will be deleted.';

  @override
  String get speedTestClearAll => 'Clear all';

  @override
  String get speedTestNoTests => 'No tests yet';

  @override
  String get speedTestNoTestsSubtitle =>
      'Run your first speed test to start tracking your connection over time.';

  @override
  String get speedTestDownloadHistory => 'Download speed (Mbps)';

  @override
  String get speedTestUploadHistory => 'Upload speed (Mbps)';

  @override
  String get speedTestNetworkWifi => 'Wi-Fi';

  @override
  String speedTestNetworkWithName(String network, String name) {
    return '$network · $name';
  }

  @override
  String get speedTestNetworkEthernet => 'Ethernet';

  @override
  String get speedTestNetworkMobileData => 'Mobile data';

  @override
  String speedTestNetworkMobileGeneration(String generation) {
    return 'Mobile data · $generation';
  }

  @override
  String get speedTestNetworkVpn => 'VPN';

  @override
  String get speedTestNetworkOffline => 'No connection';

  @override
  String get speedTestNetworkUnknown => 'Unknown network';

  @override
  String get wifiSpeedTestInvalidSnapshot => 'Invalid speed test snapshot.';

  @override
  String get worthCounterInvalidSnapshot => 'Invalid worth counter snapshot.';

  @override
  String get worthCounterAddProduct => 'Add product';

  @override
  String get worthCounterNoProducts => 'No products yet';

  @override
  String get worthCounterEmptySubtitle =>
      'Add a product with what one is worth, then count them up with + and -. The total value shows at the bottom.';

  @override
  String get worthCounterDeleteProductTitle => 'Delete product?';

  @override
  String worthCounterDeleteProductBody(String name) {
    return 'This removes \"$name\" and its count from the tally.';
  }

  @override
  String get worthCounterResetAllTitle => 'Reset every count?';

  @override
  String get worthCounterResetAllBody =>
      'All products stay in the list, but their counts go back to zero.';

  @override
  String get worthCounterEditProduct => 'Edit product';

  @override
  String get worthCounterResetCount => 'Reset count';

  @override
  String get worthCounterResetAll => 'Reset all';

  @override
  String get worthCounterResetAllCounts => 'Reset all counts';

  @override
  String get worthCounterOneLess => 'One less';

  @override
  String get worthCounterOneMore => 'One more';

  @override
  String worthCounterItemsCounted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items counted',
      one: '1 item counted',
    );
    return '$_temp0';
  }

  @override
  String worthCounterPricePerItem(String price) {
    return '$price each';
  }

  @override
  String get worthCounterNameRequired => 'Give the product a name.';

  @override
  String get worthCounterPriceInvalid => 'Enter what one is worth, e.g. 2.50.';

  @override
  String get worthCounterWorthPerItemLabel => 'Worth per item (€)';

  @override
  String get worthCounterNameHint => 'e.g. Coffee';

  @override
  String get worthCounterPriceHint => 'e.g. 2.00';

  @override
  String get financeSeedCategoryGroceries => 'Groceries';

  @override
  String get financeSeedCategoryEatingOut => 'Eating out';

  @override
  String get financeSeedCategoryClothing => 'Clothing';

  @override
  String get financeSeedCategoryTransport => 'Transport';

  @override
  String get financeSeedCategorySubscriptions => 'Subscriptions';

  @override
  String get financeSeedCategoryHousing => 'Housing';

  @override
  String get financeSeedCategoryUtilities => 'Utilities';

  @override
  String get financeSeedCategoryHealth => 'Health & care';

  @override
  String get financeSeedCategoryEntertainment => 'Entertainment';

  @override
  String get financeSeedCategoryShopping => 'Shopping';

  @override
  String get financeTabTransactions => 'Transactions';

  @override
  String get financeTabPots => 'Pots';

  @override
  String get financeTabRecurring => 'Recurring';

  @override
  String get financeTabDebts => 'Debts';

  @override
  String get financeTabStocks => 'Stocks';

  @override
  String get financeTabReports => 'Reports';

  @override
  String get financeExistingTransaction => 'Existing transaction';

  @override
  String get financeImportMatchChanged =>
      'This match changed. Review the entry again.';

  @override
  String get financeManualAllocationNote => 'Manual allocation';

  @override
  String financeDividendNote(String ticker) {
    return 'Dividend $ticker';
  }

  @override
  String financeDebtRepaymentNote(String name) {
    return 'Repayment: $name';
  }

  @override
  String financeDebtRepaidToMeNote(String name) {
    return 'Repaid to me: $name';
  }

  @override
  String get financeDebtBalanceAdjustmentNote => 'Balance adjustment';

  @override
  String get financeAutoAllocationNote => 'Auto-allocation';

  @override
  String get financeUnknownMerchant => 'Unknown merchant';

  @override
  String get financeAllocationLabel => 'Allocation';

  @override
  String get financeTypeIncome => 'Income';

  @override
  String get financeTypeExpense => 'Expense';

  @override
  String get financeImportOr => 'or';

  @override
  String financeImportFileType(String type) {
    return '$type file';
  }

  @override
  String get financeImportHintAbnAmro =>
      'Download transactions as TXT (tab-separated).';

  @override
  String get financeImportHintRabobank =>
      'Download the CSV transaction overview.';

  @override
  String get financeImportHintBunq => 'Export a EUR account statement as CSV.';

  @override
  String get financeImportHintSns =>
      'Download transactions from Mijn SNS as CSV.';

  @override
  String get financeImportHintKnab => 'Use Search and download to export CSV.';

  @override
  String get financeMainPotName => 'Main';

  @override
  String financeImportSelectStatementTitle(String bank) {
    return 'Select $bank statement';
  }

  @override
  String get financeImportNoTransactions =>
      'No transactions found in the selected file.';

  @override
  String financeImportReadFailed(String detail) {
    return 'Failed to read file: $detail';
  }

  @override
  String get financeImportTitle => 'Import data';

  @override
  String get financeImportIntro =>
      'Select your bank and an exported statement. Review transactions before adding them.';

  @override
  String financeImportWrongFileType(String fileType, String bank) {
    return 'Select a $fileType export from $bank.';
  }

  @override
  String get financeImportIncompleteUtf16 => 'Incomplete UTF-16 statement.';

  @override
  String get financeImportUnexpectedAfterQuote =>
      'Unexpected text after a quoted field.';

  @override
  String get financeImportUnclosedQuote => 'Unclosed quote in statement.';

  @override
  String get financeReviewEntryTitle => 'Review entry';

  @override
  String financeReviewSavedSkipped(int saved, int skipped) {
    return '$saved saved · $skipped skipped';
  }

  @override
  String get financeReviewMerchant => 'Merchant';

  @override
  String get financeReviewCompany => 'Company';

  @override
  String financeReviewMatchSubtitle(String date, String status) {
    return '$date · $status';
  }

  @override
  String get financeReviewAlreadyRecorded => 'Already recorded';

  @override
  String get financeReviewRecurringPayment => 'Recurring payment';

  @override
  String get financeReviewPossibleMatches => 'Possible matches';

  @override
  String get financeReviewMatchHelp =>
      'Select the same payment to count it once. Existing entries keep their pot and category.';

  @override
  String get financeReviewPot => 'Pot';

  @override
  String get financeReviewSkip => 'Skip';

  @override
  String get financeReviewAddNext => 'Add & next';

  @override
  String get financeReviewMatchNext => 'Match & next';

  @override
  String get financeNoCategory => 'No category';

  @override
  String get financeReviewPickCompany => 'Pick a company (optional)';

  @override
  String get financeReviewSearchCompanies => 'Search companies';

  @override
  String get financeEntryAmountInvalid =>
      'Enter a valid amount greater than zero.';

  @override
  String get financeEntryEdit => 'Edit entry';

  @override
  String get financeEntryNew => 'New entry';

  @override
  String get financeEntryAllocationToPot => 'Allocation to a pot';

  @override
  String get financeKindExpense => 'Expense';

  @override
  String get financeKindIncome => 'Income';

  @override
  String get financeCompany => 'Company';

  @override
  String get financePot => 'Pot';

  @override
  String get financeFromMainBalance => 'From main balance';

  @override
  String get financeToMainBalance => 'To main balance';

  @override
  String get financeNoteOptional => 'Note (optional)';

  @override
  String get financeNoteHint => 'e.g. weekly groceries';

  @override
  String get financeSaveChanges => 'Save changes';

  @override
  String get financeAddEntry => 'Add entry';

  @override
  String get financeSearchCompanies => 'Search companies';

  @override
  String get financePickCompany => 'Pick a company (optional)';

  @override
  String get financePickDate => 'Pick a date';

  @override
  String get financeNoExpensesThisMonth => 'No expenses this month';

  @override
  String get financeNetWorthComeBack =>
      'Come back tomorrow to start seeing your net worth trend.';

  @override
  String get financeIncomeThisMonth => 'Income this month';

  @override
  String get financeSpentThisMonth => 'Spent this month';

  @override
  String get financeCashFlowForecast => 'Cash-flow forecast';

  @override
  String get financeBudgets => 'Budgets';

  @override
  String get financeDashboard => 'Dashboard';

  @override
  String get financePots => 'Pots';

  @override
  String get financeOverviewNoPots =>
      'No pots yet — make one in the Pots tab and split your money up.';

  @override
  String get financeThisWeek => 'This week';

  @override
  String get financeInvestments => 'Investments';

  @override
  String get financeUpcoming => 'Upcoming';

  @override
  String get financeAddGraph => 'Add Graph';

  @override
  String get financeGraphNetWorth => 'Net Worth Over Time';

  @override
  String get financeGraphCategorySpending => 'Spending by Category';

  @override
  String get financeGraphIncomeVsExpense => 'Income vs Expense';

  @override
  String get financeGraphUnknown => 'Unknown Graph';

  @override
  String get financeGraphLineChart => 'Line Chart';

  @override
  String get financeGraphPieChart => 'Pie Chart';

  @override
  String get financeGraphBarChart => 'Bar Chart';

  @override
  String get financeGraphChart => 'Chart';

  @override
  String get financeNetWorth => 'Net worth';

  @override
  String get financeAvailable => 'Available';

  @override
  String get financeInPots => 'In pots';

  @override
  String get financeDebts => 'Debts';

  @override
  String get financeOwedToYou => 'Owed to you';

  @override
  String get financeYouOwe => 'You owe';

  @override
  String get financeNoSpendingThisWeek => 'No spending recorded yet this week.';

  @override
  String get financeSpentThisWeek => 'Spent this week';

  @override
  String get financeUncategorized => 'Uncategorized';

  @override
  String get financePortfolioValue => 'Portfolio value';

  @override
  String get financeGainLoss => 'Gain / loss';

  @override
  String get financeCadenceWeekly => 'Weekly';

  @override
  String get financeCadenceMonthly => 'Monthly';

  @override
  String financeUpcomingNext(String cadence, String date) {
    return '$cadence · next $date';
  }

  @override
  String get financeUpcomingEmpty =>
      'No fixed costs or income yet — add them in the Recurring tab.';

  @override
  String get financeAddDebt => 'Add debt';

  @override
  String get financeDebtsEmpty => 'No debts tracked';

  @override
  String get financeDebtsEmptySubtitle =>
      'Add a student loan, a mortgage, or money a friend owes you to see when it\'s paid off.';

  @override
  String get financePaidOff => 'Paid off';

  @override
  String get financeFullyRepaid => 'Fully repaid';

  @override
  String get financeRepaid => 'Repaid';

  @override
  String get financeDebtsSetMonthlyPayment =>
      'Set a monthly payment to see when it\'s paid off.';

  @override
  String financeDebtsDoesNotCoverInterest(String amount) {
    return '$amount/month doesn\'t cover the interest.';
  }

  @override
  String financeDebtsPayoffOutlook(
    String verb,
    String date,
    int count,
    String interest,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count payments',
      one: '1 payment',
    );
    return '$verb by $date · $_temp0$interest';
  }

  @override
  String financeDebtsInterest(String amount) {
    return '$amount interest';
  }

  @override
  String financeDebtsProgressPaid(String percent, String outlook) {
    return '$percent% paid · $outlook';
  }

  @override
  String financeDebtsProgressRepaid(String percent, String outlook) {
    return '$percent% repaid · $outlook';
  }

  @override
  String financeDebtsOfTotal(String amount) {
    return 'of $amount';
  }

  @override
  String financeDebtsInterestRate(String rate) {
    return '$rate% a year';
  }

  @override
  String financeDebtsMonthlyAmount(String amount) {
    return '$amount/month';
  }

  @override
  String get financeDebtsLogPayment => 'Log payment';

  @override
  String get financeDebtsLogRepayment => 'Log repayment';

  @override
  String get financeDebtsUpdateBalance => 'Update balance';

  @override
  String get financeDebtsPaymentHistory => 'Payment history';

  @override
  String financeDebtsDeleteTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get financeDebtsDeleteMessage =>
      'Its payment history goes too. Payments already booked in your transactions stay there.';

  @override
  String get financeEditDebt => 'Edit debt';

  @override
  String get financeDebtsIOwe => 'I owe';

  @override
  String get financeDebtsOwedToMe => 'Owed to me';

  @override
  String get financeDebtsNameHintOwe => 'e.g. Student loan (DUO)';

  @override
  String get financeDebtsNameHintOwed => 'e.g. Sam — concert tickets';

  @override
  String get financeDebtsOriginalAmount => 'Original amount';

  @override
  String get financeDebtsInterestOptional => 'Interest (optional)';

  @override
  String get financeDebtsPerYear => '% / year';

  @override
  String get financeDebtsMonthlyPayment => 'Monthly payment';

  @override
  String get financeDebtsStarted => 'Started';

  @override
  String get financeDebtsNameAmountRequired =>
      'Give it a name and an amount above €0.';

  @override
  String get financeDebtsNumbersRequired =>
      'Interest and monthly payment must be numbers.';

  @override
  String financeDebtsPaymentOn(String name) {
    return 'Payment on $name';
  }

  @override
  String financeDebtsRepaymentFrom(String name) {
    return 'Repayment from $name';
  }

  @override
  String get financeDebtsLog => 'Log';

  @override
  String get financeDebtsAmountAboveZero => 'Enter an amount above €0.';

  @override
  String get financeDebtsBookExpense =>
      'Also book it as an expense from my main balance';

  @override
  String get financeDebtsBookIncome =>
      'Also book it as income to my main balance';

  @override
  String get financeDebtsEnterBalance => 'Enter the balance as an amount.';

  @override
  String get financeDebtsAdjustExplainer =>
      'Type the balance from your latest statement. The difference is recorded as an adjustment (interest, fees) and doesn\'t touch your transactions.';

  @override
  String get financeDebtsCurrentBalance => 'Current balance';

  @override
  String financeDebtsHistoryTitle(String name) {
    return '$name — history';
  }

  @override
  String get financeDebtsNoPayments => 'No payments logged yet.';

  @override
  String get financeDebtsPaymentBooked => 'Payment (booked)';

  @override
  String get financeDebtsPayment => 'Payment';

  @override
  String get financePlanningNoBudgets => 'No budgets yet';

  @override
  String financePlanningSpentOfBudget(
    String spent,
    String budget,
    String month,
  ) {
    return '$spent of $budget · $month';
  }

  @override
  String get financePlanningSetBudgets => 'Set budgets';

  @override
  String get financePlanningBudgetsHint =>
      'Give categories a monthly limit and see how close you are.';

  @override
  String financePlanningOver(String amount) {
    return '$amount over';
  }

  @override
  String financePlanningLeft(String amount) {
    return '$amount left';
  }

  @override
  String get financePlanningBudgetsTitle => 'Monthly budgets';

  @override
  String get financePlanningBudgetsEditHint =>
      'Leave a category empty for no limit.';

  @override
  String get financePlanningNoLimit => 'No limit';

  @override
  String financePlanningNotAnAmount(String text, String name) {
    return '\"$text\" for $name isn\'t an amount.';
  }

  @override
  String financeForecastAvailableIn(int days) {
    return 'Available in $days days';
  }

  @override
  String get financeForecast30Days => '30d';

  @override
  String get financeForecast90Days => '90d';

  @override
  String financeForecastBelowZero(
    String date,
    String lowest,
    String lowestDate,
  ) {
    return 'Heading below €0 on $date — lowest $lowest on $lowestDate.';
  }

  @override
  String financeForecastLowest(String amount, String date) {
    return 'Lowest point $amount on $date.';
  }

  @override
  String get financeForecastNothingScheduled =>
      'Nothing scheduled — add fixed costs and income in the Recurring tab.';

  @override
  String get financePlanningGoalReached => 'Goal reached';

  @override
  String financePlanningGoalShortWasDue(String amount, String date) {
    return '$amount short · was due $date';
  }

  @override
  String financePlanningGoalMonthly(String amount, String month) {
    return '$amount/month until $month';
  }

  @override
  String financePlanningGoalToGo(String amount) {
    return '$amount to go';
  }

  @override
  String financePlanningGoalTarget(String amount) {
    return 'Goal $amount';
  }

  @override
  String financePlanningGoalPercent(String percent, String amount) {
    return '$percent of $amount';
  }

  @override
  String get financePotDetailEmpty => 'Nothing in this pot yet.';

  @override
  String get financePotDetailBalanceOverTime => 'Balance over time';

  @override
  String get financePotDetailTransactions => 'Transactions';

  @override
  String get financePotDetailSpendingByCategory => 'Spending by category';

  @override
  String get financePotDetailUncategorized => 'Uncategorized';

  @override
  String get financePotDetailIncome => 'Income';

  @override
  String get financePotDetailAllocation => 'Allocation';

  @override
  String financePotsAvailableToAllocate(String amount) {
    return 'Available to allocate: $amount';
  }

  @override
  String get financePotsNewPot => 'New pot';

  @override
  String get financePotsEmptyTitle => 'No pots yet';

  @override
  String get financePotsEmptySubtitle =>
      'Create pots like \"Rent\", \"Groceries\" or \"Holiday\" to divide your money.';

  @override
  String get financePotsAddMoney => 'Add money';

  @override
  String get financePotsBalance => 'Balance';

  @override
  String financePotsDeleteTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get financePotsDeleteBody =>
      'Entries assigned to this pot will move back to your main balance.';

  @override
  String financePotsAddMoneyTitle(String name) {
    return 'Add money to \"$name\"';
  }

  @override
  String get financePotsGoalNotPositive =>
      'The goal has to be an amount above €0.';

  @override
  String get financePotsEditPot => 'Edit pot';

  @override
  String get financePotsNameHint => 'Pot name (e.g. Holiday)';

  @override
  String get financePotsColor => 'Color';

  @override
  String get financePotsIcon => 'Icon';

  @override
  String get financePotsSavingsGoal => 'Savings goal (optional)';

  @override
  String get financePotsNoGoal => 'No goal';

  @override
  String get financePotsReachBy => 'Reach it by';

  @override
  String get financePotsAnyTime => 'Any time';

  @override
  String get financeRecurringApplyDue => 'Apply due now';

  @override
  String financeRecurringApplied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Applied $count due entries.',
      one: 'Applied 1 due entry.',
    );
    return '$_temp0';
  }

  @override
  String get financeRecurringFixedHeader => 'Fixed costs & income';

  @override
  String get financeRecurringEmpty =>
      'Add things like rent, Spotify, or your paycheck.';

  @override
  String get financeRecurringAutoHeader => 'Automatic distribution';

  @override
  String get financeRecurringCreatePotFirst => 'Create a pot first.';

  @override
  String get financeRecurringAutoHint =>
      'Automatically move money from your main balance into pots, weekly or monthly.';

  @override
  String get financeRecurringNoRules => 'No distribution rules yet.';

  @override
  String financeRecurringBillsDueSoon(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bills due soon',
      one: '1 bill due soon',
    );
    return '$_temp0';
  }

  @override
  String get financeRecurringOverdue => 'Overdue';

  @override
  String get financeRecurringDueToday => 'Due today';

  @override
  String get financeRecurringDueTomorrow => 'Due tomorrow';

  @override
  String financeRecurringDueInDays(int days) {
    return 'Due in $days days';
  }

  @override
  String get financeRecurringWeekly => 'Weekly';

  @override
  String get financeRecurringMonthly => 'Monthly';

  @override
  String financeRecurringRowSubtitle(String cadence, String date) {
    return '$cadence · next $date';
  }

  @override
  String financeRecurringRowBillSubtitle(
    String cadence,
    int days,
    String date,
  ) {
    return '$cadence · Bill, remind me $days days before · next $date';
  }

  @override
  String financeRecurringToPot(String name) {
    return 'To $name';
  }

  @override
  String get financeRecurringPotFallback => 'pot';

  @override
  String get financeRecurringNewEntry => 'New recurring entry';

  @override
  String get financeRecurringFixedCost => 'Fixed cost';

  @override
  String get financeRecurringFixedIncome => 'Fixed income';

  @override
  String get financeRecurringNameHint => 'e.g. Spotify';

  @override
  String get financeRecurringRepeats => 'Repeats';

  @override
  String get financeRecurringFirstDue => 'First due date';

  @override
  String get financeRecurringPotOptional => 'Pot (optional)';

  @override
  String get financeRecurringFromMain => 'From main balance';

  @override
  String get financeRecurringToMain => 'To main balance';

  @override
  String get financeRecurringCategoryOptional => 'Category (optional)';

  @override
  String get financeRecurringNoCategory => 'No category';

  @override
  String get financeRecurringTreatAsBill =>
      'Treat as a bill/subscription — show it in \"due soon\"';

  @override
  String get financeRecurringRemindDays =>
      'Remind me this many days before it\'s due';

  @override
  String get financeRecurringEnterNameAndAmount =>
      'Enter a name and a valid amount.';

  @override
  String get financeRecurringInvalidReminder =>
      'Enter a valid number of reminder days.';

  @override
  String get financeRecurringNewRule => 'New distribution rule';

  @override
  String get financeRecurringPot => 'Pot';

  @override
  String get financeRecurringAmountType => 'Amount type';

  @override
  String get financeRecurringFixedEuro => 'Fixed €';

  @override
  String get financeRecurringPercentOfBalance => '% of balance';

  @override
  String get financeRecurringAmountPerPeriod => 'Amount per period';

  @override
  String get financeRecurringPercent => 'Percent';

  @override
  String get financeRecurringPercentHint => 'e.g. 25';

  @override
  String get financeRecurringFirstRun => 'First run date';

  @override
  String get financeRecurringEnterValidAmount => 'Enter a valid amount.';

  @override
  String get financeRecurringPercentRange =>
      'Enter a percentage between 0 and 100.';

  @override
  String get financeRecurringAddRule => 'Add rule';

  @override
  String financeSubsPossibleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count possible subscriptions',
      one: '1 possible subscription',
    );
    return '$_temp0';
  }

  @override
  String financeSubsMonthlyEstimate(String amount) {
    return '≈ $amount/month';
  }

  @override
  String get financeSubsExplainer =>
      'These charges repeat on a schedule but aren\'t tracked yet.';

  @override
  String get financeSubsCadenceWeekly => 'Weekly';

  @override
  String get financeSubsCadenceMonthly => 'Monthly';

  @override
  String financeSubsRowDetail(
    String cadence,
    String amount,
    String count,
    String date,
  ) {
    return '$cadence · $amount · seen $count× · last $date';
  }

  @override
  String get financeSubsNotSubscription => 'Not a subscription';

  @override
  String financeSubsTrackedSnack(String name, String date) {
    return '$name is now a bill, next due $date.';
  }

  @override
  String get financeSubsTrackAsBill => 'Track as bill';

  @override
  String get financeReportsNothingToExport =>
      'Nothing to export in this period.';

  @override
  String get financeReportsExportTitle => 'Export transactions';

  @override
  String financeReportsExported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Exported $count transactions.',
      one: 'Exported 1 transaction.',
    );
    return '$_temp0';
  }

  @override
  String financeReportsExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get financeReportsExporting => 'Exporting…';

  @override
  String get financeReportsMonthTab => 'Month';

  @override
  String get financeReportsYearTab => 'Year';

  @override
  String get financeReportsIncome => 'Income';

  @override
  String get financeReportsSpent => 'Spent';

  @override
  String get financeReportsNet => 'Net';

  @override
  String get financeReportsSavingsRate => 'Savings rate';

  @override
  String get financeReportsSavingsRateNote => 'Share of income not spent';

  @override
  String get financeReportsLastMonth => 'last month';

  @override
  String get financeReportsLastYear => 'last year';

  @override
  String financeReportsVsPrevious(String delta, String period) {
    return '$delta vs $period';
  }

  @override
  String get financeReportsSpendingByCategory => 'Spending by category';

  @override
  String get financeReportsComparedMonth => 'Compared with the month before.';

  @override
  String get financeReportsComparedYear => 'Compared with the year before.';

  @override
  String get financeReportsNoSpending => 'No spending in this period.';

  @override
  String get financeReportsUncategorized => 'Uncategorized';

  @override
  String financeReportsPercentOfSpending(int percent) {
    return '$percent% of spending';
  }

  @override
  String financeReportsOverBudget(String amount) {
    return '$amount over budget';
  }

  @override
  String financeReportsWithinBudget(String amount) {
    return 'within $amount budget';
  }

  @override
  String get financeReportsTopMerchants => 'Top merchants';

  @override
  String get financeReportsMonthByMonth => 'Month by month';

  @override
  String get financeReportsYearNotStarted => 'This year hasn\'t started yet.';

  @override
  String get financeReconTitle => 'Statement reconciliation';

  @override
  String get financeReconEndBeforeStart =>
      'The closing date must be on or after the start date.';

  @override
  String get financeReconInvalidBalances =>
      'Enter valid opening and closing balances in euros.';

  @override
  String get financeReconIntro =>
      'Enter the opening balance immediately before the start date and the closing balance at the end of the closing date. Luma includes income and expenses across all pots; allocations between pots do not change this balance.';

  @override
  String get financeReconStartDate => 'Start date';

  @override
  String get financeReconClosingDate => 'Closing date';

  @override
  String get financeReconOpeningBalance => 'Statement opening balance';

  @override
  String get financeReconClosingBalance => 'Statement closing balance';

  @override
  String get financeReconLoadEntries => 'Load statement entries';

  @override
  String get financeReconReplaceEntries => 'Replace statement entries';

  @override
  String get financeReconClearEntries => 'Clear statement entries';

  @override
  String get financeReconOptionalHelp =>
      'Optional: read an exported transaction file to locate entries. Enter the statement balances above; loading a file adds nothing.';

  @override
  String financeReconEntriesLoaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count statement entries loaded.',
      one: '1 statement entry loaded.',
    );
    return '$_temp0 Use the dates of the full statement period above.';
  }

  @override
  String get financeReconReadMerchantsFailed => 'Unable to read merchants.';

  @override
  String get financeReconReadTransactionsFailed =>
      'Unable to read transactions.';

  @override
  String get financeReconCompare => 'Compare balances';

  @override
  String financeReconCalculatedClosing(String amount) {
    return 'Calculated closing balance: $amount';
  }

  @override
  String financeReconStatementClosing(String amount) {
    return 'Statement closing balance: $amount';
  }

  @override
  String get financeReconMatch => 'Balances match';

  @override
  String financeReconDifferenceLower(String amount) {
    return 'Difference: $amount (Luma is lower)';
  }

  @override
  String financeReconDifferenceHigher(String amount) {
    return 'Difference: $amount (Luma is higher)';
  }

  @override
  String get financeReconCheckHint =>
      'Check the opening balance, dates and included entries. If you track multiple bank accounts, exclude movements belonging to other accounts below. Suggestions do not prove an entry is wrong.';

  @override
  String financeReconClosingFromFile(String amount) {
    return 'Closing from file entries: $amount';
  }

  @override
  String get financeReconFileDoesNotReach =>
      'The file entries and opening balance do not reach the statement closing balance. Check that the export covers the whole period.';

  @override
  String financeReconOutsidePeriod(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file entries are outside the selected period.',
      one: '1 file entry is outside the selected period.',
    );
    return '$_temp0';
  }

  @override
  String financeReconMatchedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count entries paired by date, direction and amount. Descriptions may differ; shifted booking dates appear as unmatched.',
      one:
          '1 entry paired by date, direction and amount. Descriptions may differ; shifted booking dates appear as unmatched.',
    );
    return '$_temp0';
  }

  @override
  String financeReconReviewPairs(int count) {
    return 'Review pairs with different descriptions ($count)';
  }

  @override
  String financeReconLumaEntry(String note) {
    return 'Luma: $note';
  }

  @override
  String financeReconStatementSubtitle(String description, String details) {
    return 'Statement: $description\n$details';
  }

  @override
  String financeReconPossiblyMissing(int count) {
    return 'Possibly missing from Luma ($count)';
  }

  @override
  String get financeReconReviewMissing => 'Review missing entries for import';

  @override
  String financeReconNotPaired(int count) {
    return 'Luma entries not paired with statement ($count)';
  }

  @override
  String get financeReconNoUnmatched => 'No unmatched entries.';

  @override
  String financeReconDuplicateTitle(int count, String note) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries: $note',
      one: '1 entry: $note',
    );
    return '$_temp0';
  }

  @override
  String get financeReconSameDescription => 'Same description';

  @override
  String financeReconDuplicateDetail(String date, String amount, String ids) {
    return '$date · $amount each · IDs $ids';
  }

  @override
  String financeReconPossibleDuplicates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Possible duplicates ($count groups)',
      one: 'Possible duplicates (1 group)',
    );
    return '$_temp0';
  }

  @override
  String get financeReconRemovalExplains =>
      'Entries whose removal would explain the difference';

  @override
  String get financeReconReviewIncluded => 'Review included cash entries';

  @override
  String get financeReconNoCashEntries => 'No cash entries in this period.';

  @override
  String get financeReconIncludeAll => 'Include all entries again';

  @override
  String financeReconKindId(String kind, int id) {
    return '$kind #$id';
  }

  @override
  String get financeReconKindIncome => 'Income';

  @override
  String get financeReconKindExpense => 'Expense';

  @override
  String get financeReconKindAllocation => 'Allocation';

  @override
  String get financeReconMainPot => 'Main';

  @override
  String get financeStocksNoChartDataAvailable => 'No chart data available.';

  @override
  String get financeStocksNoChartData => 'No chart data.';

  @override
  String get financeStocksPricesUpdated => 'Prices updated.';

  @override
  String financeStocksUpdatedWithFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Updated, but $count tickers could not be fetched.',
      one: 'Updated, but 1 ticker could not be fetched.',
    );
    return '$_temp0';
  }

  @override
  String financeStocksPortfolio(String amount) {
    return 'Portfolio $amount';
  }

  @override
  String get financeStocksUpdatingPrices => 'Updating prices…';

  @override
  String get financeStocksAtCostNoQuote => 'At cost price — no live quote yet';

  @override
  String financeStocksPricesAsOf(String stamp) {
    return 'Prices as of $stamp';
  }

  @override
  String get financeStocksForeignNotConverted =>
      'Some foreign prices aren\'t converted to euros yet';

  @override
  String financeStocksDividendsButton(String amount) {
    return 'Dividends $amount';
  }

  @override
  String get financeStocksRefreshing => 'Refreshing…';

  @override
  String get financeStocksAddHolding => 'Add holding';

  @override
  String get financeStocksNoHoldings => 'No holdings yet';

  @override
  String get financeStocksNoHoldingsHint =>
      'Add a stock like AAPL or ASML to watch its price.';

  @override
  String financeStocksRemoveTitle(String ticker) {
    return 'Remove $ticker?';
  }

  @override
  String get financeStocksDividendsKept => 'Its dividend history is kept.';

  @override
  String get financeStocksAllHoldings => 'All holdings';

  @override
  String financeStocksHoldingsCombined(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count holdings combined',
      one: '1 holding combined',
    );
    return '$_temp0';
  }

  @override
  String get financeStocksShowAll => 'Show all';

  @override
  String financeStocksHoldingLine(String shares, String price, String details) {
    return '$shares @ $price$details';
  }

  @override
  String get financeStocksAtCost => '(cost)';

  @override
  String get financeStocksNoFxRate => 'no FX rate';

  @override
  String get financeStocksLogDividend => 'Log dividend';

  @override
  String get financeStocksEnterHoldingFields =>
      'Enter a ticker, number of shares and avg cost.';

  @override
  String get financeStocksTicker => 'Ticker';

  @override
  String get financeStocksTickerHint => 'e.g. AAPL or ASML.NL';

  @override
  String get financeStocksNameOptional => 'Name (optional)';

  @override
  String get financeStocksNameHint => 'auto-filled if blank';

  @override
  String get financeStocksShares => 'Shares';

  @override
  String get financeStocksSharesHint => 'e.g. 10';

  @override
  String get financeStocksAvgCost =>
      'Average cost per share, in the stock\'s own currency';

  @override
  String get financeStocksEnterAmount => 'Enter the amount you received.';

  @override
  String financeStocksDividendFrom(String ticker) {
    return 'Dividend from $ticker';
  }

  @override
  String get financeStocksLog => 'Log';

  @override
  String get financeStocksReceived => 'Received (after tax, in euros)';

  @override
  String get financeStocksPaidOn => 'Paid on';

  @override
  String get financeStocksNoteOptional => 'Note (optional)';

  @override
  String get financeStocksAlsoIncome =>
      'Also add it to my main balance as income';

  @override
  String get financeStocksDividendsTitle => 'Dividends';

  @override
  String financeStocksDividendTotals(String thisYear, String allTime) {
    return '$thisYear this year · $allTime all time';
  }

  @override
  String get financeStocksLogOneHint => 'Log one from a holding\'s ⋮ menu.';

  @override
  String get financeTxnImportData => 'Import data';

  @override
  String get financeTxnAddEntry => 'Add entry';

  @override
  String get financeTxnEmptySubtitle =>
      'Add what you spent or earned and it shows up here.';

  @override
  String get financeTxnNoMatchTitle => 'No matching entries';

  @override
  String get financeTxnNoMatchSubtitle =>
      'Try a different search or clear the filters.';

  @override
  String get financeTxnClearFilters => 'Clear filters';

  @override
  String get financeTxnSearchHint => 'Search notes, companies, categories…';

  @override
  String get financeTxnReconcile => 'Reconcile statement';

  @override
  String get financeTxnCategoryAll => 'All categories';

  @override
  String get financeTxnPotAll => 'All pots';

  @override
  String get financeTxnPot => 'Pot';

  @override
  String get financeTxnAllTypes => 'All types';

  @override
  String get financeTxnKindExpenses => 'Expenses';

  @override
  String get financeTxnKindIncome => 'Income';

  @override
  String get financeTxnKindAllocations => 'Allocations';

  @override
  String get financeTxnExpenseTitle => 'Expense';

  @override
  String get financeTxnAllocationTitle => 'Allocation';

  @override
  String financeTxnEntriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
    );
    return '$_temp0';
  }

  @override
  String get financeTxnSummaryIn => 'In';

  @override
  String get financeTxnSummaryOut => 'Out';

  @override
  String get financeTxnSummaryNet => 'Net';

  @override
  String get financeTxnDuplicate => 'Duplicate';

  @override
  String syncLabelHomeLayout(String family) {
    return 'Home layout ($family)';
  }

  @override
  String get syncLabelFamilyDesktop => 'desktop';

  @override
  String get syncLabelFamilyPhone => 'phone';

  @override
  String get syncLabelAssistantMemory => 'Assistant memory';

  @override
  String get syncLabelAiUsage => 'AI Usage (agents, library & usage)';

  @override
  String get syncLabelQrCodes => 'QR codes';

  @override
  String get syncLabelMindMaps => 'Mind maps';

  @override
  String get syncLabelWhiteboards => 'Whiteboards';

  @override
  String get syncLabelSteamTools => 'Steam Tools';

  @override
  String get syncLabelServerTycoon => 'Server Tycoon';

  @override
  String get syncLabelSmartHomePresets => 'Smart Home presets';

  @override
  String get syncLabelAudioToolsEq => 'Audio Tools EQ';

  @override
  String get syncLabelSftpSites => 'SFTP sites';

  @override
  String get syncLabelMediaDownloaderHistory => 'Media downloader history';

  @override
  String get splashDevBuild => 'Dev build';

  @override
  String get splashFreeEdition => 'Free edition';

  @override
  String splashPlanEdition(String plan) {
    return '$plan edition';
  }

  @override
  String get p2pDebugLogEmpty => 'No debug log yet.';

  @override
  String p2pDebugLogReadFailed(String error) {
    return 'Could not read debug log: $error';
  }

  @override
  String p2pLinkConnectionError(String error) {
    return 'Connection error: $error';
  }

  @override
  String p2pLinkInvalidFrame(String error) {
    return 'Invalid frame: $error';
  }

  @override
  String get p2pLinkMalformedControl => 'Malformed control message.';

  @override
  String get p2pLinkMalformedBlob => 'Malformed blob header.';

  @override
  String get p2pLinkMalformedShareChunk => 'Malformed share chunk header.';

  @override
  String get p2pLinkHandshakeNotSameAccount =>
      'Handshake failed: not the same account.';

  @override
  String get p2pSetUpSyncFirst => 'Set up device sync first.';

  @override
  String get p2pAccountNotReady => 'Account not ready.';

  @override
  String p2pCouldNotStartDiscovery(String error) {
    return 'Could not start discovery: $error';
  }

  @override
  String p2pCouldNotResolvePeer(String name) {
    return 'Could not resolve $name.';
  }

  @override
  String p2pCouldNotConnectTo(String endpoint, String error) {
    return 'Could not connect to $endpoint ($error).';
  }

  @override
  String get p2pUnknownDevice => 'Unknown device';

  @override
  String get p2pDefaultDeviceName => 'luma device';

  @override
  String get securityRequiresHttps =>
      'Private server connections require HTTPS.';

  @override
  String get petAutoClickerBackToPet => 'Back to pet';

  @override
  String get petAutoClickerIntervalTitle => 'INTERVAL';

  @override
  String get petAutoClickerClickTitle => 'CLICK';

  @override
  String get petAutoClickerLocationRepeatTitle => 'LOCATION & REPEAT';

  @override
  String get petAutoClickerMilliseconds => 'Milliseconds';

  @override
  String get petAutoClickerDoubleClick => 'Double click';

  @override
  String get petAutoClickerCursor => 'Cursor';

  @override
  String get petAutoClickerFixed => 'Fixed';

  @override
  String get petAutoClickerNoPointSelected => 'No point selected';

  @override
  String petAutoClickerMoveCursor(int seconds) {
    return 'Move cursor… $seconds';
  }

  @override
  String get petAutoClickerPickPoint => 'Pick point';

  @override
  String get petAutoClickerStopAfterAmount => 'Stop after a set amount';

  @override
  String get petAutoClickerNumberOfClicks => 'Number of clicks';

  @override
  String petAutoClickerClicksDone(String count) {
    return '$count CLICKS';
  }

  @override
  String petAutoClickerReady(String hotKey) {
    return 'READY · $hotKey';
  }

  @override
  String get secretStoreVerificationFailed =>
      'Secure storage verification failed.';

  @override
  String get secretStoreConflictingKeys =>
      'Conflicting encryption keys; restore requires review.';

  @override
  String get secretStoreInvalidKey => 'Invalid stored encryption key.';

  @override
  String get devicesSetupTitle => 'Sync directly between devices';

  @override
  String get devicesSetupBody =>
      'No server needed — just an email + password shared between your devices, used only to recognize each other over Wi-Fi. Already have a luma cloud account? Sign in above instead and this turns on automatically.';

  @override
  String get devicesErrorInvalidEmail => 'Enter a valid email address.';

  @override
  String get devicesErrorPasswordShort =>
      'Use at least 10 characters — this password also protects your encrypted data.';

  @override
  String get devicesEnableTitle => 'Enable device sync';

  @override
  String get devicesEnableBody =>
      'Enter the same email and password on every device you want to pair — they never leave this device or touch a server. They just prove your devices belong to the same person.';

  @override
  String get devicesPasswordWarning =>
      'If you mistype the password while pairing a second device, it just won\'t be recognized as the same account — there\'s no server to check against or reset it with.';

  @override
  String devicesLocalOnly(String email) {
    return 'Local only — $email (not backed up anywhere)';
  }

  @override
  String get devicesTurnOff => 'Turn off';

  @override
  String get devicesConnectedHeading => 'Connected';

  @override
  String get devicesNoneConnected => 'No devices connected yet.';

  @override
  String get devicesNearby => 'Nearby';

  @override
  String get devicesTurnOnDiscovery =>
      'Turn on discovery to find other devices on this Wi-Fi.';

  @override
  String get devicesSearching => 'Searching… no other devices found yet.';

  @override
  String get devicesSameNetworkHint =>
      'Both devices must be on the same network. On mobile data (5G/4G)? Use a hotspot instead.';

  @override
  String get devicesHowHotspot => 'How?';

  @override
  String get devicesConnectManually => 'Connect manually…';

  @override
  String get devicesAutoSync => 'Auto-sync';

  @override
  String get devicesAutoSyncHint =>
      'Auto-sync pushes changes to connected devices within a couple of seconds. Off, you tap a device and choose Sync now.';

  @override
  String get devicesViewDebugLog => 'View debug log';

  @override
  String get devicesThisDevice => 'This device';

  @override
  String devicesIpHint(String addresses) {
    return 'IP: $addresses — the other device must be on the same network to find this one.';
  }

  @override
  String devicesListeningOnPort(String name, String port) {
    return '$name · listening on port $port';
  }

  @override
  String get devicesSync => 'Sync';

  @override
  String get devicesDisconnect => 'Disconnect';

  @override
  String get devicesConnect => 'Connect';

  @override
  String get devicesHotspotTitle => 'No shared Wi-Fi? Use a hotspot';

  @override
  String get devicesHotspotBody =>
      'Discovery only finds devices on the same network. If your phone is on mobile data instead of Wi-Fi, there\'s no LAN to find each other on — turn on the phone\'s own hotspot instead and have the other device join it. Once both are on that one network, everything here works exactly the same.';

  @override
  String get devicesHotspotStep1 =>
      'On the phone: Settings → Network & internet → Hotspot & tethering → turn on Wi-Fi hotspot.';

  @override
  String get devicesHotspotStep2 =>
      'On the other device: connect to that hotspot\'s Wi-Fi network like any other.';

  @override
  String get devicesHotspotStep3 =>
      'Come back here and turn discovery on (or off and back on) on both devices.';

  @override
  String get devicesGotIt => 'Got it';

  @override
  String get devicesDebugLogTitle => 'P2P debug log';

  @override
  String get devicesTurnOffTitle => 'Turn off device sync?';

  @override
  String get devicesTurnOffBody =>
      'This disconnects every paired device and forgets this device\'s sync identity. You can set it up again any time with the same email and password.';

  @override
  String get devicesErrorHostPort => 'Enter a host and a valid port (1–65535).';

  @override
  String get devicesConnectManualTitle => 'Connect manually';

  @override
  String get devicesManualBody =>
      'Use this when discovery can\'t see the other device — e.g. a firewall is blocking mDNS. Enter the address it shows on its Devices screen.';

  @override
  String get devicesHost => 'Host';

  @override
  String get devicesPort => 'Port';

  @override
  String get settingsAccentLavender => 'Lavender';

  @override
  String get settingsAccentIndigo => 'Indigo';

  @override
  String get settingsAccentOcean => 'Ocean';

  @override
  String get settingsAccentTeal => 'Teal';

  @override
  String get settingsAccentForest => 'Forest';

  @override
  String get settingsAccentAmber => 'Amber';

  @override
  String get settingsAccentCoral => 'Coral';

  @override
  String get settingsAccentRose => 'Rose';

  @override
  String get settingsHomeScreenTitle => 'Your home screen';

  @override
  String get settingsHomeScreenSub =>
      'Arrange and resize tiles, pin your favorites, and choose what you see. Layouts sync within the same device format.';

  @override
  String get settingsHomeScreenEdit => 'Edit home screen';

  @override
  String get syncSettingsHeadline => 'Keep your stuff on every device';

  @override
  String get syncSettingsSignedOutBody =>
      'Set up an account to sync features between devices — with Google, GitHub, or an email and password. Everything is encrypted on this device before it leaves; nothing is synced until you turn it on per feature. You can also skip the server entirely and pair devices over your own network.';

  @override
  String get syncSettingsSessionExpired =>
      'Your cloud session expired — please sign in again.';

  @override
  String get syncSettingsSetUpAccount => 'Set up account';

  @override
  String get syncSettingsEnterCode => 'Enter code';

  @override
  String syncSettingsPendingEmailCode(String email) {
    return '$email is waiting to be approved. Enter the 6-digit code we emailed you to finish signing in. Until then this device does not contact the server at all, and the plugins that need it stay switched off.';
  }

  @override
  String syncSettingsPendingApproval(String email) {
    return '$email is waiting for the server operator to approve it. There is nothing to do in the meantime — just sign in once they have. Until then this device does not contact the server at all, and the plugins that need it stay switched off.';
  }

  @override
  String get syncSettingsResendCode => 'Resend code';

  @override
  String get syncSettingsUseDifferentEmail => 'Use a different email';

  @override
  String get syncSettingsSyncedToCloud => 'Synced to the cloud';

  @override
  String syncSettingsSyncedToCloudWith(String providers) {
    return 'Synced to the cloud — sign in with $providers';
  }

  @override
  String get syncSettingsProviderSeparator => ' or ';

  @override
  String get syncSettingsLocalOnly =>
      'Local only — syncs directly between your devices, no server';

  @override
  String get syncSettingsBackUpToServer => 'Back up to a server…';

  @override
  String get syncSettingsWhatSyncs => 'What syncs from this device';

  @override
  String get syncSettingsWhatSyncsBody =>
      'Everything is off by default. Only what you switch on here leaves this device — encrypted with your password before upload. When you first enable a feature that already has synced data, the server copy replaces this device\'s copy.';

  @override
  String get syncSettingsAutomaticTooltip =>
      'Preferences, assistant memory and matching-device home layouts always sync — this can\'t be turned off.';

  @override
  String get syncSettingsAlwaysOn => 'Always on';

  @override
  String syncSettingsPlanSyncsOn(String label, String plan) {
    return '$label syncs on the $plan plan and above.';
  }

  @override
  String syncSettingsPlanBadge(String plan) {
    return '$plan plan';
  }

  @override
  String syncSettingsStopSyncingTitle(String label) {
    return 'Stop syncing $label?';
  }

  @override
  String syncSettingsStopSyncingBody(String label) {
    return 'This device stops uploading $label. Do you also want to delete the copy stored on the server? (Other devices that still sync $label may upload it again.)';
  }

  @override
  String get syncSettingsKeepOnServer => 'Keep on server';

  @override
  String get syncSettingsDeleteFromServer => 'Delete from server';

  @override
  String syncSettingsPlanNeededTitle(String plan) {
    return '$plan plan needed';
  }

  @override
  String syncSettingsPlanNeededBody(String label, String plan) {
    return '$label syncs to the server on the $plan plan and above. It keeps working on this device either way — only syncing it between devices needs the plan.';
  }

  @override
  String get syncSettingsSeePlans => 'See plans';

  @override
  String get syncSettingsLimitTitle => 'Sync limit reached';

  @override
  String syncSettingsLimitBody(int limit) {
    String _temp0 = intl.Intl.pluralLogic(
      limit,
      locale: localeName,
      other: '$limit features',
      one: '1 feature',
    );
    return 'Your plan allows syncing up to $_temp0 to the server at once. Turn one off, or upgrade your plan to sync more.';
  }

  @override
  String get syncSettingsUpgradePlan => 'Upgrade plan';

  @override
  String get syncSettingsStorage => 'Storage';

  @override
  String get syncSettingsSyncToSeeUsage => 'Sync to see usage';

  @override
  String syncSettingsUsedOf(String used, String quota) {
    return '$used of $quota used';
  }

  @override
  String get syncSettingsNothingSavedYet =>
      'Nothing saved on the server yet — turn something on below to back it up.';

  @override
  String get syncSettingsSyncing => 'Syncing…';

  @override
  String get syncSettingsSyncFailed => 'Sync failed.';

  @override
  String get syncSettingsNotSyncedYet => 'Not synced yet.';

  @override
  String syncSettingsLastSynced(String time) {
    return 'Last synced $time';
  }

  @override
  String get syncSettingsSyncNow => 'Sync now';

  @override
  String get syncSettingsSyncAll => 'Sync all';

  @override
  String get syncSettingsChangePassword => 'Change password';

  @override
  String get syncSettingsCurrentPassword => 'Current password';

  @override
  String get syncSettingsNewPassword => 'New password';

  @override
  String get syncSettingsConfirmNewPassword => 'Confirm new password';

  @override
  String get syncSettingsPasswordReencryptNote =>
      'All synced data is re-encrypted with the new password. Other devices will ask you to sign in again.';

  @override
  String get syncSettingsPasswordTooShort => 'Use at least 10 characters.';

  @override
  String get syncSettingsPasswordMismatch => 'New passwords do not match.';

  @override
  String get syncSettingsDevicesSignedInTitle => 'Devices signed in';

  @override
  String get syncSettingsDevicesSignedIn => 'Devices signed in…';

  @override
  String get syncSettingsAskDeleteData => 'Ask to delete my data…';

  @override
  String get syncSettingsDeleteAccount => 'Delete account…';

  @override
  String get syncSettingsDataSyncsDirectly =>
      'This data syncs directly with paired devices — see Devices below to connect one and turn it off.';

  @override
  String get syncSettingsRecoveryKeySetUp =>
      'Recovery key set up — forgetting your password will not cost you your synced data.';

  @override
  String get syncSettingsRecoveryKeyMissing =>
      'No recovery key. If you forget your password, resetting it erases your synced data on the server.';

  @override
  String get syncSettingsManage => 'Manage…';

  @override
  String get syncSettingsSetUp => 'Set up…';

  @override
  String get syncSettingsRecoveryKeyCopied => 'Recovery key copied.';

  @override
  String get syncSettingsRecoveryKeyWriteDown =>
      'Write this down or keep it in a password manager. luma does not keep a copy and cannot show it again.';

  @override
  String get syncSettingsRecoveryKeyFooter =>
      'If you forget your password, enter this key on the reset screen and your synced data stays.';

  @override
  String get syncSettingsRecoveryKeySaved => 'I saved it';

  @override
  String get syncSettingsRecoveryKeyTitle => 'Recovery key';

  @override
  String get syncSettingsYourRecoveryKey => 'Your recovery key';

  @override
  String get syncSettingsRecoveryHasKeyBody =>
      'This account has a recovery key. If you lost it, make a new one — the old key stops working the moment you do.';

  @override
  String get syncSettingsRecoveryNoKeyBody =>
      'Your synced data is encrypted with a key that comes from your password, so nobody — not even the server — can read it. That also means a forgotten password normally erases it.\n\nA recovery key is a second way in. Keep it somewhere safe, and a password reset keeps all your synced data.';

  @override
  String get syncSettingsMakeNewKey => 'Make a new key';

  @override
  String get syncSettingsCreateRecoveryKey => 'Create recovery key';

  @override
  String get syncSettingsUnknownDevice => 'Unknown device';

  @override
  String get syncSettingsThisDevice => 'This device';

  @override
  String syncSettingsSignedInOn(String date) {
    return 'Signed in $date';
  }

  @override
  String get syncSettingsCurrentSession => 'Current';

  @override
  String get syncSettingsRevoke => 'Revoke';

  @override
  String get syncSettingsNoOtherSessions => 'No other active sessions.';

  @override
  String get syncSettingsDeletionPending =>
      'Data deletion requested — waiting for the server operator to decide.';

  @override
  String get syncSettingsDeletionDeclined =>
      'The server operator declined your data-deletion request.';

  @override
  String syncSettingsDeletionSentNothingDeleted(String date) {
    return 'Sent $date. Nothing has been deleted yet.';
  }

  @override
  String syncSettingsDeletionDecided(String date) {
    return 'Decided $date.';
  }

  @override
  String syncSettingsDeletionDecidedWithNote(String date, String note) {
    return 'Decided $date. They wrote: “$note”';
  }

  @override
  String get syncSettingsWithdraw => 'Withdraw';

  @override
  String get syncSettingsDeletionWithdrawn => 'Deletion request withdrawn.';

  @override
  String get syncSettingsAskDeleteTitle => 'Ask to delete my data';

  @override
  String get syncSettingsDeletionPendingBody =>
      'You already have a request waiting for a decision. Withdraw it from the Sync & account panel if you want to send a different one.';

  @override
  String get syncSettingsDeletionRequestBody =>
      'This sends a request to the server operator to delete your account and every synced snapshot the server holds. Nothing is deleted until they accept it, and the data on your devices is never touched.';

  @override
  String get syncSettingsWhyOptional => 'Why? (optional)';

  @override
  String get syncSettingsWhyHint => 'You don\'t have to give a reason.';

  @override
  String get syncSettingsSendRequest => 'Send request';

  @override
  String get syncSettingsRequestSent => 'Request sent to the server operator.';

  @override
  String get syncSettingsDeleteAccountTitle => 'Delete account?';

  @override
  String get syncSettingsDeleteAccountBody =>
      'This permanently deletes your account and every synced snapshot from the server. Data on your devices is not touched. Enter your password to confirm.';

  @override
  String get syncSettingsDeleteForever => 'Delete forever';

  @override
  String syncCollectionHomeLayout(Object family) {
    return 'Home layout ($family)';
  }

  @override
  String get syncCollectionSettings => 'Settings';

  @override
  String get syncCollectionAssistantMemory => 'Assistant memory';

  @override
  String get syncCollectionNotes => 'Notes';

  @override
  String get syncCollectionFinance => 'Finance';

  @override
  String get syncCollectionPasswords => 'Passwords';

  @override
  String get syncCollectionCalendar => 'Calendar';

  @override
  String get syncCollectionBulletinBoard => 'Bulletin board';

  @override
  String get syncCollectionQrCodes => 'QR codes';

  @override
  String get syncCollectionCardWallet => 'Card wallet';

  @override
  String get syncCollectionErrands => 'Errands';

  @override
  String get syncCollectionDataManagement => 'Data management';

  @override
  String get syncCollectionMoodJournal => 'Mood journal';

  @override
  String get syncCollectionAiUsage => 'AI Usage (agents, library & usage)';

  @override
  String get syncCollectionSchool => 'School';

  @override
  String get syncCollectionMindMaps => 'Mind maps';

  @override
  String get syncCollectionWhiteboards => 'Whiteboards';

  @override
  String get syncCollectionTextLibrary => 'Text library';

  @override
  String get syncCollectionPriceTracker => 'Price tracker';

  @override
  String get syncCollectionWifiSpeedTest => 'Wi-Fi speed test';

  @override
  String get syncCollectionGroceries => 'Groceries';

  @override
  String get syncCollectionAirlineTycoon => 'Airline Tycoon';

  @override
  String get syncCollectionSteamTools => 'Steam Tools';

  @override
  String get syncCollectionServerTycoon => 'Server Tycoon';

  @override
  String get syncCollectionRecipeBook => 'Recipe book';

  @override
  String get syncCollectionMinecraftLauncher => 'Minecraft launcher';

  @override
  String get syncCollectionUsage => 'Usage';

  @override
  String get syncCollectionFreeSketch => 'Free Sketch';

  @override
  String get syncCollectionSmartHomePresets => 'Smart Home presets';

  @override
  String get syncCollectionAudioToolsEq => 'Audio Tools EQ';

  @override
  String get syncCollectionAutoClicker => 'Auto Clicker';

  @override
  String get syncCollectionCalculator => 'Calculator';

  @override
  String get syncCollectionWorthCounter => 'Worth counter';

  @override
  String get syncCollectionNfcTagEditor => 'NFC tag editor';

  @override
  String get syncCollectionSftpSites => 'SFTP sites';

  @override
  String get syncCollectionMediaDownloaderHistory => 'Media downloader history';

  @override
  String get syncCollectionTransportTracker => 'Transport tracker';

  @override
  String get syncSettingsDeletionReasonLabel => 'Why? (optional)';

  @override
  String get syncSettingsDeletionReasonHint =>
      'You don\'t have to give a reason.';

  @override
  String get sceneAirlineTycoonDismissAwayReport => 'Dismiss away report';

  @override
  String get sceneAirlineTycoonDismissMessage => 'Dismiss message';

  @override
  String get sceneAirlineTycoonConfirmDemolition => 'Confirm demolition';

  @override
  String get sceneAirlineTycoonEarlier => 'Earlier';

  @override
  String get sceneAirlineTycoonDragOntoAStand => 'Drag onto a stand';

  @override
  String get sceneAirlineTycoonJetBridge => 'Jet bridge';

  @override
  String get sceneAirlineTycoonCancelFlight => 'Cancel flight';

  @override
  String get sceneAirlineTycoonLumaAirport => 'Luma Airport';

  @override
  String get sceneAirlineTycoonPreparingYourAirport =>
      'Preparing your airport…';

  @override
  String get sceneAirlineTycoonScenePreviewNoSave => 'SCENE PREVIEW · NO SAVE';

  @override
  String get sceneAirlineTycoonAirport => 'Airport';

  @override
  String get sceneAirlineTycoonDay10000 => 'DAY 1 · 00:00';

  @override
  String get sceneAirlineTycoonResumeAirportSpace => 'Resume airport (Space)';

  @override
  String get sceneAirlineTycoonResumeAirport => 'Resume airport';

  @override
  String get sceneAirlineTycoonSimulationSpeed => 'Simulation speed';

  @override
  String get sceneAirlineTycoonNormalSpeed1 => 'Normal speed (1)';

  @override
  String get sceneAirlineTycoonFast2 => 'Fast (2)';

  @override
  String get sceneAirlineTycoonFastest3 => 'Fastest (3)';

  @override
  String get sceneAirlineTycoonViewMode => 'View mode';

  @override
  String get sceneAirlineTycoonAirfieldRunwaysStandsAndBuildingsT =>
      'Airfield: runways, stands and buildings (T)';

  @override
  String get sceneAirlineTycoonAirportModeZoomInOnTheTerminalAndFurnishIt =>
      'Airport mode: zoom in on the terminal and furnish its halls (T)';

  @override
  String get sceneAirlineTycoonFitAirport => 'Fit airport';

  @override
  String get sceneAirlineTycoonResetCamera => 'Reset camera';

  @override
  String get sceneAirlineTycoonTerminalCutawayC => 'Terminal cutaway (C)';

  @override
  String get sceneAirlineTycoonTerminalCutaway => 'Terminal cutaway';

  @override
  String get sceneAirlineTycoonConstructionGridG => 'Construction grid (G)';

  @override
  String get sceneAirlineTycoonConstructionGrid => 'Construction grid';

  @override
  String get sceneAirlineTycoonPerformanceStatsF3 => 'Performance stats (F3)';

  @override
  String get sceneAirlineTycoonPerformanceStats => 'Performance stats';

  @override
  String get sceneAirlineTycoonClosePanelEsc => 'Close panel (Esc)';

  @override
  String get sceneAirlineTycoonClosePanel => 'Close panel';

  @override
  String get sceneAirlineTycoonYourFirstDeparture => 'Your first departure';

  @override
  String get sceneAirlineTycoonSignARegionalAirlineOrOpenYourOwnRoute =>
      'Sign a regional airline or open your own route.';

  @override
  String get sceneAirlineTycoonCheckTheFlightSchedule =>
      'Check the flight schedule.';

  @override
  String get sceneAirlineTycoonResumeYourAirportAndFollowTheTurnaround =>
      'Resume your airport and follow the turnaround.';

  @override
  String get sceneAirlineTycoonMeetTheAirlines => 'Meet the airlines';

  @override
  String get sceneAirlineTycoonRotate90R => 'Rotate 90° (R)';

  @override
  String get sceneAirlineTycoonCancelConstructionEsc =>
      'Cancel construction (Esc)';

  @override
  String get sceneAirlineTycoonCancelConstruction => 'Cancel construction';

  @override
  String get sceneAirlineTycoonAirportPanels => 'Airport panels';

  @override
  String get sceneAirlineTycoonCloseEsc => 'Close (Esc)';

  @override
  String get sceneAirlineTycoonCloseBuildingWindow => 'Close building window';

  @override
  String get sceneAirlineTycoonBuildingSections => 'Building sections';

  @override
  String get sceneAirlineTycoonNorth => 'North';

  @override
  String get sceneAirlineTycoonN => 'N ↑';

  @override
  String get sceneTextLibraryBuildingYourLibrary => 'Building your library…';

  @override
  String get sceneTextLibraryPreviousShelf => 'Previous shelf';

  @override
  String get sceneTextLibraryNextShelf => 'Next shelf';

  @override
  String get sceneTextLibraryForward => 'Forward';

  @override
  String get sceneTextLibraryTurnLeft => 'Turn left';

  @override
  String get sceneTextLibraryTurnRight => 'Turn right';

  @override
  String get sceneTextLibraryPreviousPage => 'Previous page';

  @override
  String get sceneTextLibraryNextPage => 'Next page';

  @override
  String syncServiceSyncLimitExceeded(Object limit) {
    return 'Your plan allows syncing up to $limit features at once. Upgrade your plan to sync more.';
  }

  @override
  String syncServicePlanRequired(Object label, Object plan) {
    return '$label syncs on the $plan plan and above.';
  }

  @override
  String get syncOAuthSignInCancelled => 'Sign-in cancelled.';

  @override
  String get syncOAuthBrowserTimeout =>
      'Timed out waiting for the browser. Please try again.';

  @override
  String get syncOAuthDidNotComplete => 'That sign-in did not complete.';

  @override
  String get syncServiceApprovalNotPending =>
      'No account is waiting for approval on this device.';

  @override
  String get syncServiceEmailVerificationNotPending =>
      'No email verification is pending on this device.';

  @override
  String get syncServiceRecoveryKeyIncomplete =>
      'That recovery key is not complete. It is 8 groups of 4 letters and digits.';

  @override
  String get syncServiceNoRecoveryKey =>
      'This account has no recovery key. Leave the field empty to reset anyway; the synced copies on the server are erased.';

  @override
  String get syncServiceRecoveryKeyMismatch =>
      'That recovery key does not belong to this account. Nothing was changed.';

  @override
  String get syncServiceApprovedAccountRequired =>
      'Sign in with an approved account first.';

  @override
  String get syncServiceWrongDevicePassword =>
      'Wrong password for this device\'s existing device-sync identity.';

  @override
  String get syncServicePasswordReencryptFailed =>
      'Password changed, but some synced data could not be re-encrypted. The old key was retained in this device\'s secure storage for recovery. Keep this device and its data.';

  @override
  String get syncCollectionInvalidSnapshot => 'Invalid snapshot.';

  @override
  String get syncCollectionSnapshotNewerVersion =>
      'This snapshot came from a newer app version. Update the app on this device first.';

  @override
  String syncCollectionPasswordDecryptFailed(Object entryId) {
    return 'Could not decrypt password entry $entryId for sync (corrupt data or changed key file).';
  }

  @override
  String get syncCollectionTotpDecryptFailed =>
      'Could not decrypt TOTP entry for sync.';

  @override
  String get syncCollectionSnapshotMissingPassword =>
      'Missing password in vault snapshot.';

  @override
  String get syncCollectionSnapshotUnreadableTotp =>
      'Unreadable TOTP in vault snapshot.';

  @override
  String get syncSnapshotCollectionMismatch =>
      'Snapshot does not match collection.';

  @override
  String get securityUnsupportedEncryptedData => 'Unsupported encrypted data.';

  @override
  String get securityInvalidEncryptionKeyLength =>
      'Invalid encryption key length.';

  @override
  String get cs2MarketTitle => 'CS2 Market';

  @override
  String get aiDetectorVerdictGeneratedClaude => 'Generated by Claude';

  @override
  String get aiDetectorVerdictVeryLikelyHuman => 'Very likely human-written';

  @override
  String get aiDetectorVerdictLikelyHuman => 'Likely human-written';

  @override
  String get aiDetectorVerdictMixed => 'Mixed signals';

  @override
  String get aiDetectorVerdictLikelyAi => 'Likely AI-generated';

  @override
  String get aiDetectorVerdictVeryLikelyAi => 'Very likely AI-generated';

  @override
  String get aiDetectorHighlightEmDash => 'Em dash';

  @override
  String get aiDetectorHighlightPassiveVoice => 'Passive voice';

  @override
  String get aiDetectorHighlightTransitionOpener => 'Transition opener';

  @override
  String get aiDetectorHighlightAiFavoritePhrase => 'AI-favourite phrase';

  @override
  String get aiDetectorHighlightAssistantBoilerplate => 'Assistant boilerplate';

  @override
  String get aiDetectorHighlightClaudeSignature => 'Claude signature';

  @override
  String get aiDetectorHighlightClaudeWatermark => 'Claude watermark';

  @override
  String get airportErrorUnknownZone => 'Unknown zone.';

  @override
  String get airportErrorLargerFloor =>
      'Drag over a larger piece of floor: 2 m at least.';

  @override
  String get airportErrorNoPaintedZone => 'No zone painted there.';

  @override
  String get airportErrorZoneInsideTerminal =>
      'Zone the floor inside the terminal.';

  @override
  String get airportErrorBuildingGone => 'That building no longer exists.';

  @override
  String get airportErrorHighestLevel => 'Already at the highest level.';

  @override
  String get airportErrorUpgradeCash => 'Not enough cash for this upgrade.';

  @override
  String get airportErrorUnknownBuilding => 'Unknown building.';

  @override
  String get airportErrorBoundary =>
      'Build inside the airport boundary (±4 km).';

  @override
  String get airportErrorBeyondLand =>
      'The building extends beyond airport land.';

  @override
  String get airportErrorUseTerminalZones =>
      'Build a terminal and zone its floor instead.';

  @override
  String get airportErrorBridgeMainHall =>
      'A jet bridge needs this stand to touch the main hall.';

  @override
  String get airportErrorConstructionCash =>
      'Not enough cash for this construction.';

  @override
  String get airportErrorFinishOperations =>
      'Cancel imminent flights and finish active operations before changing airport infrastructure.';

  @override
  String get airportErrorRemoveFurnishings =>
      'Remove the terminal furnishings first.';

  @override
  String get airportErrorUnknownVehicle => 'Unknown vehicle.';

  @override
  String get airportErrorVehicleCost => 'A service vehicle costs €120,000.';

  @override
  String get airportErrorSelectDepot =>
      'Select a vehicle depot to buy service vehicles.';

  @override
  String get airportErrorConnectDepot =>
      'Connect that vehicle depot to a service road first.';

  @override
  String get airportErrorSelectConnectedDepot =>
      'Select a connected vehicle depot to buy service vehicles.';

  @override
  String get airportErrorOfferGone => 'This offer is no longer available.';

  @override
  String get airportErrorContractFlying =>
      'This airline is still flying its current contract.';

  @override
  String get airportErrorChooseStand => 'Choose an aircraft stand.';

  @override
  String get airportErrorStandRunway =>
      'That stand is not connected to a long enough runway.';

  @override
  String get airportErrorPlanAhead => 'Plan at least 30 minutes ahead.';

  @override
  String get airportErrorUnknownFlight => 'Unknown flight.';

  @override
  String get airportErrorMoveBeforeArrival =>
      'Only flights that have not arrived yet can be moved.';

  @override
  String get airportErrorAircraftBusy =>
      'The aircraft is busy with another flight at that time.';

  @override
  String get airportErrorUnscheduleBeforeArrival =>
      'Only flights that have not arrived yet can be unscheduled.';

  @override
  String get airportErrorNoContract => 'No active contract.';

  @override
  String get airportErrorAllFlightsPlanned =>
      'Every flight of this contract is planned.';

  @override
  String get airportErrorChooseAircraftRoute =>
      'Choose an available aircraft and active route.';

  @override
  String get airportErrorDepartureWindow =>
      'Choose a departure between 90 minutes and seven days from now.';

  @override
  String get airportErrorMaintenance => 'This aircraft is in maintenance.';

  @override
  String get airportErrorUnknownDestination => 'Unknown destination.';

  @override
  String get airportErrorBeyondRange =>
      'This destination is beyond the aircraft range.';

  @override
  String get airportErrorAircraftScheduled =>
      'The aircraft is already scheduled or still returning from another flight.';

  @override
  String get airportErrorNoFreeStand =>
      'No compatible connected stand is free in this time slot.';

  @override
  String get airportErrorFlightClosed => 'That flight is already closed.';

  @override
  String get airportErrorFinishTurnaround =>
      'An active turnaround must finish before it can be removed.';

  @override
  String get airportErrorSaveVersion => 'Unsupported airport save version';

  @override
  String aiDetectorNeedsSentences(int count) {
    return 'Needs at least $count sentences to measure.';
  }

  @override
  String aiDetectorNeedsWords(int count) {
    return 'Needs at least $count words to measure.';
  }

  @override
  String aiDetectorNeedsLines(int count) {
    return 'Needs at least $count lines to measure.';
  }

  @override
  String aiDetectorNeedsParagraphs(int count) {
    return 'Needs at least $count paragraphs to measure.';
  }

  @override
  String get aiDetectorTriggerBurstiness => 'Sentence-length variation';

  @override
  String get aiDetectorTriggerBurstinessStrong =>
      'Very uniform sentence lengths';

  @override
  String get aiDetectorTriggerPhraseFound => 'AI-favourite phrases';

  @override
  String get aiDetectorTriggerPhraseNone => 'No AI-favourite phrasing';

  @override
  String get aiDetectorTriggerExtremesFound => 'No short or long sentences';

  @override
  String get aiDetectorTriggerExtremesNone =>
      'Sentence lengths reach both extremes';

  @override
  String get aiDetectorTriggerImpersonal => 'Impersonal register';

  @override
  String get aiDetectorTriggerPersonal => 'Personal register';

  @override
  String get aiDetectorTriggerChatFound => 'Chat-answer formatting';

  @override
  String get aiDetectorTriggerChatNone => 'No chat-answer formatting';

  @override
  String get aiDetectorTriggerContrastFound =>
      'Corrective-contrast constructions';

  @override
  String get aiDetectorTriggerContrastNone => 'No corrective-contrast habit';

  @override
  String get aiDetectorTriggerOpeners => 'Transition-word openers';

  @override
  String get aiDetectorTriggerContractionsMissing => 'Missing contractions';

  @override
  String get aiDetectorTriggerContractionsNatural => 'Natural contraction use';

  @override
  String get aiDetectorTriggerEmDash => 'Em-dash overuse';

  @override
  String get aiDetectorTriggerPassive => 'Passive-voice density';

  @override
  String get aiDetectorTriggerParagraphsUniform => 'Uniform paragraphs';

  @override
  String get aiDetectorTriggerParagraphsVaried => 'Varied paragraphs';

  @override
  String get aiDetectorTriggerRepeatedOpeners => 'Repeated sentence openers';

  @override
  String get aiDetectorTriggerWatermarkFound => 'Claude watermark found';

  @override
  String get aiDetectorTriggerClaudeSignature => 'Claude signature in the text';

  @override
  String get aiDetectorTriggerAssistantBoilerplate => 'Assistant boilerplate';

  @override
  String get aiDetectorTriggerNoWatermark => 'No Claude watermark';

  @override
  String aiDetectorWatermarkExplanation(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invisible characters',
      one: 'one invisible character',
    );
    return 'The text carries $_temp0 that take up no space on screen but travel with the text through every copy and paste. Typing cannot produce them. luma reads that hidden payload as Claude’s watermark, which is why the verdict names Claude instead of hedging at \"AI-generated\".';
  }

  @override
  String get aiDetectorSignatureExplanation =>
      'The text identifies its own author — it names Claude or Anthropic in a product context, not as an ordinary person’s name. That is a direct attribution, so it outranks every style statistic below it.';

  @override
  String get aiDetectorAssistantExplanation =>
      'Stock chat-assistant phrasing shows the text came out of a conversation with a model. It does not say which model, so the verdict stays unnamed — this only raises the score.';

  @override
  String get aiDetectorNoWatermarkExplanation =>
      'No invisible watermark characters and no self-reference to Claude. That is not a clean bill of health: plenty of generated text carries no signature at all, so the style checks below still do the work.';

  @override
  String get aiDetectorBurstinessExplanationHigh =>
      'Every sentence hovers around the same length. Human writing usually swings between short punches and long rambles; steady lengths suggest one generator keeping a consistent rhythm.';

  @override
  String get aiDetectorBurstinessExplanationLow =>
      'Sentence lengths vary naturally, which human writers do and models find hard to fake.';

  @override
  String get aiDetectorPhraseExplanationHigh =>
      'These words and constructions appear far more often in model-generated prose than in everyday human writing. Each chip below is a literal match in your text.';

  @override
  String get aiDetectorPhraseExplanationLow =>
      'None of the stock phrases models lean on were found. That is not a point in the text’s favour — plenty of generated writing avoids them — so this check abstains rather than voting the score down.';

  @override
  String get aiDetectorExtremesExplanationHigh =>
      'Not one sentence is genuinely short and not one genuinely runs on. People write both without thinking about it; a generator settles into a safe middle band and stays there.';

  @override
  String get aiDetectorExtremesExplanationLow =>
      'The text contains both clipped sentences and long ones, the way unedited human writing usually does.';

  @override
  String get aiDetectorVoiceExplanationHigh =>
      'Nobody is on the page — barely an \"I\", \"we\" or \"you\", no casual wording, no direct questions. Generated prose defaults to this detached register. Formal human writing does too, which is why this counts for less than the rhythm checks.';

  @override
  String get aiDetectorVoiceExplanationLow =>
      'The text speaks in a personal voice, with pronouns and casual wording that generated prose rarely reaches for unprompted.';

  @override
  String get aiDetectorFormattingExplanationHigh =>
      'The text is laid out the way a chat model answers: headings, bullet runs and bolded labels. That structure travels with the text when it is pasted somewhere else.';

  @override
  String get aiDetectorFormattingExplanationLow =>
      'The text reads as prose rather than a formatted chat answer. Plenty of generated text is prose too, so this only counts when it fires.';

  @override
  String get aiDetectorContrastExplanationHigh =>
      'Sentences that set up a wrong answer only to knock it down — \"not just X, but Y\", \"the real question is\" — are the rhetorical move current models use to sound insightful.';

  @override
  String get aiDetectorContrastExplanationLow =>
      'None of the set-up-and-knock-down constructions models favour were found. Their absence means nothing on its own.';

  @override
  String aiDetectorOpenersExplanationHigh(int used, int total) {
    return '$used of $total sentences start with a formal connective. Essay-bot structure opens sections with \"Moreover,\" and \"Furthermore,\" far more than people do.';
  }

  @override
  String get aiDetectorOpenersExplanationLow =>
      'Sentences do not lean on formal connectives to start. That on its own says nothing about who wrote them.';

  @override
  String get aiDetectorContractionsExplanationHigh =>
      'Almost no contracted forms (\"don’t\", \"it’s\"). Generated text defaults to the stiffer un-contracted register.';

  @override
  String get aiDetectorContractionsExplanationLow =>
      'Contractions appear at a natural human rate.';

  @override
  String get aiDetectorDashExplanationHigh =>
      'Em dashes pepper the text well past what typical human prose uses — a much-memed model habit.';

  @override
  String get aiDetectorDashExplanationLow =>
      'Em-dash use is within normal range.';

  @override
  String get aiDetectorDashExplanationNone =>
      'No em dashes present, which proves nothing either way.';

  @override
  String get aiDetectorPassiveExplanationHigh =>
      'Heavy passive construction (\"was designed to\", \"is considered\") keeps agency out of sentences — common in generated prose.';

  @override
  String get aiDetectorPassiveExplanationLow =>
      'Passive voice stays at a normal level, which is true of most generated text as well.';

  @override
  String get aiDetectorParagraphExplanationHigh =>
      'All paragraphs are nearly the same size, like content poured evenly into containers. Human drafts lurch between short and long.';

  @override
  String get aiDetectorParagraphExplanationLow =>
      'Paragraph sizes differ naturally.';

  @override
  String aiDetectorRepeatedOpenersExplanationHigh(String word, int count) {
    return '\"$word\" opens $count sentences. Real writers rarely hammer one opener; template-driven generation does.';
  }

  @override
  String get aiDetectorRepeatedOpenersExplanationLow =>
      'Sentence openers are varied, as they are in most writing of either origin.';

  @override
  String get aiDetectorPhraseNoMatches => 'no matches';

  @override
  String get aiDetectorPhraseSoftMatch => 'soft';

  @override
  String aiDetectorPhraseMatchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matches',
      one: '1 match',
    );
    return '$_temp0';
  }

  @override
  String aiDetectorPhraseWeightedRate(String rate) {
    return '$rate weighted per 1000 words';
  }

  @override
  String get aiDetectorEvidenceNoHiddenSignature =>
      'no hidden characters, no signature';

  @override
  String airportErrorNoUpgrade(String building) {
    return '$building has no such upgrade.';
  }

  @override
  String airportErrorPlaceInside(String hall) {
    return 'Place this completely inside the $hall.';
  }

  @override
  String airportErrorOverlap(String building) {
    return 'This overlaps $building.';
  }

  @override
  String airportErrorConnectedServiceFirst(String building) {
    return 'Provide a connected $building first.';
  }

  @override
  String airportErrorNoHaulStand(String haul) {
    return 'No connected $haul stand with a long enough runway.';
  }

  @override
  String airportErrorStandAircraft(String building, String aircraft) {
    return '$building cannot take the $aircraft.';
  }

  @override
  String airportErrorHorizon(int days) {
    return 'The timetable only reaches $days days ahead.';
  }

  @override
  String airportErrorCarrierSlot(String carrier, String slot) {
    return '$carrier wants this flight to start in $slot.';
  }

  @override
  String airportErrorStandBusy(String time) {
    return 'That stand is busy at $time.';
  }

  @override
  String airportErrorCarrierFlightsSlot(String carrier, String slot) {
    return '$carrier wants its flights to start in $slot.';
  }

  @override
  String airportErrorStartDay(int day) {
    return 'This series has to start by day $day.';
  }

  @override
  String airportErrorCharterDay(int day) {
    return 'Charter flights have to fly by day $day.';
  }

  @override
  String airportErrorConnectedServiceRequired(String building) {
    return 'A connected $building is required.';
  }

  @override
  String get airportArrivalHall => 'arrival hall';

  @override
  String get airportDepartureHall => 'departure hall';

  @override
  String get airportMainHall => 'main hall';

  @override
  String get airportTerminal => 'terminal';

  @override
  String airportClock(int day, String time) {
    return 'day $day $time';
  }

  @override
  String get airportArrivalZoneHelp =>
      'This goes in the arrival hall, where passengers come in, buy a ticket, check in and go through security. Zone a piece of floor as the arrival hall first.';

  @override
  String get airportDepartureZoneHelp =>
      'This goes in the departure hall, where arriving passengers collect their bags, clear customs and leave. Zone a piece of floor as the departure hall first.';

  @override
  String get airportMainInArrival =>
      'Shops, food, seating and gates go in the main hall. This floor is zoned as the arrival hall, which only takes the entrance, tickets, check-in and security.';

  @override
  String get airportMainInDeparture =>
      'Shops, food, seating and gates go in the main hall. This floor is zoned as the departure hall, which only takes baggage reclaim, customs and check-out.';

  @override
  String get airportFacilityRunwayName => 'Runway · 1,800 m';

  @override
  String get airportFacilityRunwayDescription =>
      'Regional runway. Connect it to stands with taxiways.';

  @override
  String get airportFacilityRunwayMediumName => 'Runway · 2,600 m';

  @override
  String get airportFacilityRunwayMediumDescription =>
      'Supports narrowbody aircraft.';

  @override
  String get airportFacilityRunwayLongName => 'Runway · 3,400 m';

  @override
  String get airportFacilityRunwayLongDescription =>
      'Supports long-haul widebodies.';

  @override
  String get airportFacilityTaxiwayName => 'Taxiway';

  @override
  String get airportFacilityTaxiwayDescription =>
      'Connect touching taxiways between a runway and a stand.';

  @override
  String get airportFacilityStandRegionalName => 'Regional stand';

  @override
  String get airportFacilityStandRegionalDescription =>
      'Turboprops and regional jets up to 45 t. Needs taxiway, service road and a nearby boarding gate.';

  @override
  String get airportFacilityStandName => 'Remote stand';

  @override
  String get airportFacilityStandDescription =>
      'Any aircraft. Passengers ride a bus. Needs taxiway, service road and a nearby boarding gate.';

  @override
  String get airportFacilityStandContactName => 'Contact stand · jet bridge';

  @override
  String get airportFacilityStandContactDescription =>
      'Build against a terminal. Passengers walk on board: no bus, faster boarding, happier travellers.';

  @override
  String get airportFacilityServiceRoadName => 'Service road';

  @override
  String get airportFacilityServiceRoadDescription =>
      'Connect vehicle depots and services to aircraft stands.';

  @override
  String get airportFacilityTerminalName => 'Terminal';

  @override
  String get airportFacilityTerminalDescription =>
      'One hall for the whole terminal. Build as many as you need side by side, then zone the floor for free in airport mode: arrival on the road side, main hall in the middle, departure for arriving passengers.';

  @override
  String get airportFacilityTerminalLandsideName => 'Arrival hall';

  @override
  String get airportFacilityTerminalLandsideDescription =>
      'The old separate arrival hall. Zone a terminal floor instead.';

  @override
  String get airportFacilityTerminalReclaimName => 'Departure hall';

  @override
  String get airportFacilityTerminalReclaimDescription =>
      'The old separate departure hall. Zone a terminal floor instead.';

  @override
  String get airportFacilityHangarName => 'Maintenance hangar';

  @override
  String get airportFacilityHangarDescription =>
      'Connected hangars reduce aircraft maintenance costs.';

  @override
  String get airportFacilityFuelDepotName => 'Fuel depot';

  @override
  String get airportFacilityFuelDepotDescription =>
      'Fuel supply for ground-service trucks.';

  @override
  String get airportFacilityBaggageName => 'Baggage facility';

  @override
  String get airportFacilityBaggageDescription =>
      'Baggage handling for every departure.';

  @override
  String get airportFacilityVehicleDepotName => 'Vehicle depot';

  @override
  String get airportFacilityVehicleDepotDescription =>
      'Select this depot to buy service vehicles; connect it to a service road.';

  @override
  String get airportFacilityTowerName => 'Control tower';

  @override
  String get airportFacilityTowerDescription =>
      'Airport landmark and flight control centre.';

  @override
  String get airportFacilityEntranceName => 'Entrance';

  @override
  String get airportFacilityEntranceDescription =>
      'The way in from the kerb, in the arrival hall.';

  @override
  String get airportFacilityCheckInName => 'Check-in desks';

  @override
  String get airportFacilityCheckInDescription =>
      'Process 8 passengers per game minute.';

  @override
  String get airportFacilityInfoDeskName => 'Information desk';

  @override
  String get airportFacilityInfoDeskDescription =>
      'Staff who answer questions and point the way: every connected desk lifts passenger satisfaction across the terminal.';

  @override
  String get airportFacilityCheckInCounterName => 'Staffed check-in counter';

  @override
  String get airportFacilityCheckInCounterDescription =>
      'Two agents with a bag drop: 10 passengers per game minute. Counts as check-in desks.';

  @override
  String get airportFacilityTicketMachineName => 'Ticket machine';

  @override
  String get airportFacilityTicketMachineDescription =>
      'Self check-in beside the desks: 4 passengers per game minute.';

  @override
  String get airportFacilitySecurityName => 'Security lane';

  @override
  String get airportFacilitySecurityDescription =>
      'Passport and bag checks between the arrival hall and the main hall: 6 passengers per game minute. Required.';

  @override
  String get airportFacilityCustomsName => 'Customs';

  @override
  String get airportFacilityCustomsDescription =>
      'Arriving passengers clear customs here, 6 per game minute. Required.';

  @override
  String get airportFacilityCheckOutName => 'Arrivals check-out';

  @override
  String get airportFacilityCheckOutDescription =>
      'The way out: arriving passengers check out here and leave through the nearest door to the kerb, 10 per game minute. Required.';

  @override
  String get airportFacilitySeatingName => 'Seating';

  @override
  String get airportFacilitySeatingDescription =>
      'Comfort for waiting passengers.';

  @override
  String get airportFacilityToiletsName => 'Toilets';

  @override
  String get airportFacilityToiletsDescription =>
      'Essential passenger amenity.';

  @override
  String get airportFacilityBoardingGateName => 'Boarding gate';

  @override
  String get airportFacilityBoardingGateDescription =>
      'Place within 25 m of an aircraft stand.';

  @override
  String get airportFacilityCafeName => 'Café';

  @override
  String get airportFacilityCafeDescription =>
      'Passenger satisfaction and retail income.';

  @override
  String get airportFacilityVendingMachineName => 'Vending machine';

  @override
  String get airportFacilityVendingMachineDescription =>
      'Quick snacks instead of the café: €3 per passenger, one minute each.';

  @override
  String get airportFacilityPerfumeShopName => 'Perfume boutique';

  @override
  String get airportFacilityPerfumeShopDescription =>
      'Few buyers, large baskets: one passenger in four spends €90 here.';

  @override
  String get airportFacilityFlowerShopName => 'Flower shop';

  @override
  String get airportFacilityFlowerShopDescription =>
      'Fresh bouquets after security: €16 per passenger, two minutes each.';

  @override
  String get airportFacilityFoodShopName => 'Duty-free food & drink';

  @override
  String get airportFacilityFoodShopDescription =>
      'Snacks, sweets and a chilled drinks wall after security: €20 per passenger, two and a half minutes each.';

  @override
  String get airportFacilityKioskName => 'Newsstand kiosk';

  @override
  String get airportFacilityKioskDescription =>
      'A staffed till for papers and snacks after security: €9 per passenger, ninety seconds each.';

  @override
  String get airportFacilityRestaurantName => 'Restaurant';

  @override
  String get airportFacilityRestaurantDescription =>
      'Sit-down dining instead of the café: €26 per passenger, five minutes, and a happier wait.';

  @override
  String get airportFacilityCoffeeToGoName => 'Coffee to-go';

  @override
  String get airportFacilityCoffeeToGoDescription =>
      'A quick espresso stop after security: €6 per passenger, ninety seconds each.';

  @override
  String get airportFacilityFoodCartName => 'Food cart';

  @override
  String get airportFacilityFoodCartDescription =>
      'A cheap grab-and-go stall for tight corners: €4 per passenger, one minute each.';

  @override
  String get airportFacilityShopName => 'Duty-free shop';

  @override
  String get airportFacilityShopDescription =>
      'Passengers browse after security: €14 retail income each.';

  @override
  String get airportFacilityClothingShopName => 'Fashion boutique';

  @override
  String get airportFacilityClothingShopDescription =>
      'Duty-free clothing after security: €18 per passenger, three minutes each.';

  @override
  String get airportFacilityLuxuryBoutiqueName => 'Luxury boutique';

  @override
  String get airportFacilityLuxuryBoutiqueDescription =>
      'Premium knitwear after security: €26 per passenger, four minutes each, and a calmer wait.';

  @override
  String get airportFacilityLoungeName => 'Premium lounge';

  @override
  String get airportFacilityLoungeDescription =>
      'Waiting area that earns €20 per passenger and lifts their mood.';

  @override
  String get airportFacilityBaggageCarouselName => 'Baggage carousel';

  @override
  String airportFacilityBaggageCarouselDescription(int capacity) {
    return 'Arrivals of medium and long-haul contracts collect their bags here. Up to $capacity people at once.';
  }

  @override
  String get airportFacilityVipLoungeName => 'VIP lounge & bar';

  @override
  String get airportFacilityVipLoungeDescription =>
      'First-class waiting area: €35 per passenger and a much happier wait.';

  @override
  String get airportFacilityBinsName => 'Recycling bins';

  @override
  String get airportFacilityBinsDescription =>
      'Waste, paper and bottles. A clean terminal keeps passengers happy: each set adds 4% cleanliness, from 60% up to 100%.';

  @override
  String get airportFacilityArcadeName => 'Arcade';

  @override
  String get airportFacilityArcadeDescription =>
      'Cabinets, air hockey and a claw machine: €12 per passenger, and a big mood boost for the wait.';

  @override
  String get airportFacilityCasinoName => 'Casino';

  @override
  String get airportFacilityCasinoDescription =>
      'Slots, roulette and card tables: €40 per passenger, and a strong mood boost for the wait.';

  @override
  String get airportFacilityPlantName => 'Palm planter';

  @override
  String get airportFacilityPlantDescription =>
      'Decor. Every piece in a terminal lifts passenger mood a little.';

  @override
  String get airportFacilityFountainName => 'Fountain';

  @override
  String get airportFacilityFountainDescription =>
      'Decor centrepiece. Lifts passenger mood.';

  @override
  String get airportFacilityInfoBoardName => 'Flight information board';

  @override
  String get airportFacilityInfoBoardDescription =>
      'Decor. Passengers find their gate with less stress.';

  @override
  String get airportFacilityInfoPanelName => 'Flight info screen';

  @override
  String get airportFacilityInfoPanelDescription =>
      'A small pedestal departures screen. Cheaper decor with the same stress-easing effect as a full board.';

  @override
  String get sceneAssetStudioAirformAssetStudio => 'Airform Asset Studio';

  @override
  String get sceneAssetStudioAirform => 'Airform';

  @override
  String get sceneAssetStudioAssetStudio => 'Asset Studio';

  @override
  String get sceneAssetStudioSavedLocally => 'Saved locally';

  @override
  String get sceneAssetStudioQuickGuide => 'Quick guide';

  @override
  String get sceneAssetStudioExportModel => 'Export model';

  @override
  String get sceneAssetStudioAirportAssets => 'AIRPORT ASSETS';

  @override
  String get sceneAssetStudioProcedural => 'Procedural';

  @override
  String get sceneAssetStudioTerminalCollectionAssets =>
      'Terminal collection assets';

  @override
  String get sceneAssetStudioTerminalCollection => 'TERMINAL COLLECTION';

  @override
  String get sceneAssetStudioModelWorkspace => 'Model workspace';

  @override
  String get sceneAssetStudioWorkspaceView => 'Workspace view';

  @override
  String get sceneAssetStudioSourceCode => 'Source code';

  @override
  String get sceneAssetStudioCameraView => 'Camera view';

  @override
  String get sceneAssetStudioIsometric => 'Isometric';

  @override
  String get sceneAssetStudioFrontView => 'Front view';

  @override
  String get sceneAssetStudioRightView => 'Right view';

  @override
  String get sceneAssetStudioBackView => 'Back view';

  @override
  String get sceneAssetStudioTopView => 'Top view';

  @override
  String get sceneAssetStudioExpandViewport => 'Expand viewport';

  @override
  String get sceneAssetStudioLivePreview => 'LIVE PREVIEW';

  @override
  String get sceneAssetStudio1Unit1Meter => '1 unit = 1 meter';

  @override
  String get sceneAssetStudioResetToIsometricView => 'Reset to isometric view';

  @override
  String get sceneAssetStudioIsometricViewF => 'Isometric view (F)';

  @override
  String get sceneAssetStudioTop => 'TOP';

  @override
  String get sceneAssetStudioFront => 'FRONT';

  @override
  String get sceneAssetStudioRight => 'RIGHT';

  @override
  String get sceneAssetStudioYUp => 'Y UP';

  @override
  String get sceneAssetStudioViewportTools => 'Viewport tools';

  @override
  String get sceneAssetStudioOrbitTool => 'Orbit tool';

  @override
  String get sceneAssetStudioOrbitO => 'Orbit (O)';

  @override
  String get sceneAssetStudioPanTool => 'Pan tool';

  @override
  String get sceneAssetStudioPanH => 'Pan (H)';

  @override
  String get sceneAssetStudioToggleFootprintDimensions =>
      'Toggle footprint dimensions';

  @override
  String get sceneAssetStudioFootprintBoundsB => 'Footprint bounds (B)';

  @override
  String get sceneAssetStudioToggleGroundGrid => 'Toggle ground grid';

  @override
  String get sceneAssetStudioGridG => 'Grid (G)';

  @override
  String get sceneAssetStudioYUpCoordinateSystem => 'Y-up coordinate system';

  @override
  String get sceneAssetStudioDragToOrbit => 'Drag to orbit';

  @override
  String get sceneAssetStudioScrollToZoom => 'Scroll to zoom';

  @override
  String get sceneAssetStudioStartTurntable => 'Start turntable';

  @override
  String get sceneAssetStudioAutoOrbit => 'Auto orbit';

  @override
  String get sceneAssetStudioSavePreviewImage => 'Save preview image';

  @override
  String get sceneAssetStudioResetCameraF => 'Reset camera (F)';

  @override
  String get sceneAssetStudioOnlyDonorHelpersNoTexturesFontsOrExternalA =>
      'Only donor helpers. No textures, fonts, or external assets.';

  @override
  String get sceneAssetStudioViewWiring => 'View wiring';

  @override
  String get sceneAssetStudioRenderStyle => 'Render style';

  @override
  String get sceneAssetStudioSolid => 'Solid';

  @override
  String get sceneAssetStudioWireframe => 'Wireframe';

  @override
  String get sceneAssetStudioQuarterTurnRotation => 'Quarter-turn rotation';

  @override
  String get sceneAssetStudioJavascript => 'JavaScript';

  @override
  String get sceneAssetStudioStaticGeometryDonorHelpers =>
      'Static geometry / Donor helpers';

  @override
  String get sceneAssetStudioCopyFullSnippet => 'Copy full snippet';

  @override
  String get sceneAssetStudioModelInspector => 'Model inspector';

  @override
  String get sceneAssetStudioInspector => 'Inspector';

  @override
  String get sceneAssetStudioProperties => 'Properties';

  @override
  String get sceneAssetStudioChecks => 'Checks';

  @override
  String get sceneAssetStudioMeters => 'METERS';

  @override
  String get sceneAssetStudioWidth => 'Width';

  @override
  String get sceneAssetStudioWidthInMeters => 'Width in meters';

  @override
  String get sceneAssetStudioDepthInMeters => 'Depth in meters';

  @override
  String get sceneAssetStudioModelHeight => 'Model height';

  @override
  String get sceneAssetStudioColorPalette => 'Color palette';

  @override
  String get sceneAssetStudioVertexColors => 'VERTEX COLORS';

  @override
  String get sceneAssetStudioModelColorPalette => 'Model color palette';

  @override
  String get sceneAssetStudioCopyColorValue => 'Copy color value';

  @override
  String get sceneAssetStudioSceneSettings => 'Scene settings';

  @override
  String get sceneAssetStudioGroundGrid => 'Ground grid';

  @override
  String get sceneAssetStudioFootprintBounds => 'Footprint bounds';

  @override
  String get sceneAssetStudioScreenEmission => 'Screen emission';

  @override
  String get sceneAssetStudioBuiltToFitYourTerminal =>
      'Built to fit your terminal.';

  @override
  String get sceneAssetStudioLowPolyAndMadeToFitYourWorld =>
      'Low-poly and made to fit your world.';

  @override
  String get sceneAssetStudioGeometryChecks => 'Geometry checks';

  @override
  String get sceneAssetStudioRealChecksOnYourLiveModel =>
      'Real checks on your live model.';

  @override
  String get sceneAssetStudioUsesPreviewHelpersConfirmWith =>
      'Uses preview helpers. Confirm with';

  @override
  String get sceneAssetStudioAirportmodelsBakeG => 'AirportModels.bake(g)';

  @override
  String get sceneAssetStudioInYourDonorBeforeShipping =>
      'in your donor before shipping.';

  @override
  String get sceneAssetStudioResetToDefaults => 'Reset to defaults';

  @override
  String get sceneAssetStudioRunChecksAgain => 'Run checks again';

  @override
  String get sceneAssetStudioV10 => 'v1.0';

  @override
  String get sceneAssetStudioPreparingGeometry => 'Preparing geometry';

  @override
  String get sceneAssetStudioHelperCalls => 'helper calls';

  @override
  String get sceneAssetStudioTriangles => 'triangles';

  @override
  String get sceneAssetStudioTextures => 'textures';

  @override
  String get sceneAssetStudioThreeJs => 'THREE.JS';

  @override
  String get sceneAssetStudioWebgl => 'WEBGL';

  @override
  String get sceneAssetStudioDismissNotification => 'Dismiss notification';

  @override
  String get sceneAssetStudioCloseDialog => 'Close dialog';

  @override
  String get sceneAssetStudioExportSections => 'Export sections';

  @override
  String get sceneAssetStudioModelFunction => 'Model function';

  @override
  String get sceneAssetStudioJs => 'JS';

  @override
  String get sceneAssetStudioIntegration => 'Integration';

  @override
  String get sceneAssetStudioJsDart => 'JS + DART';

  @override
  String get sceneAssetStudioFindYourAngle => 'Find your angle';

  @override
  String get sceneAssetStudioDragToOrbitScrollToZoomOrHoldShiftWhileDra =>
      'Drag to orbit, scroll to zoom, or hold Shift while dragging to pan. Use the view menu for precise front, side, and top views.';

  @override
  String get sceneAssetStudioMakeSureItFits => 'Make sure it fits';

  @override
  String get sceneAssetStudioAdjustTheFootprintInMetersOpenChecksToInsp =>
      'Adjust the footprint in meters. Open Checks to inspect bounds, color attributes, and the helper-call budget.';

  @override
  String get sceneAssetStudioGrid => 'Grid';

  @override
  String get sceneAssetStudioBounds => 'Bounds';

  @override
  String get sceneAssetStudioGiveItAHome => 'Give it a home';

  @override
  String get sceneAssetStudioExportTheFunctionIntoYourExistingHelperSco =>
      'Export the function into your existing helper scope, add the JavaScript facility branch, and register the Dart catalog entry. Bake with your donor before shipping.';

  @override
  String get sceneAssetStudioThePreviewAdapterUsesCenteredBoxesAndSizeS =>
      'The preview adapter uses centered boxes and size-sided light meshes. Your model has no external files, materials, or per-frame geometry allocations. Settings are saved in this browser.';

  @override
  String get sceneCityPlannerMetroplanStadsplanner =>
      'MetroPlan — City Planner';

  @override
  String get sceneCityPlannerMetroplan => 'MetroPlan';

  @override
  String get sceneCityPlanner1Jan1925 => 'Jan 1, 1925';

  @override
  String get sceneCityPlannerPauze => 'Pause';

  @override
  String get sceneCityPlannerNormaal => 'Normal';

  @override
  String get sceneCityPlannerSnel => 'Fast';

  @override
  String get sceneCityPlannerZeerSnel => 'Very fast';

  @override
  String get sceneCityPlannerStadsfase => 'City phase';

  @override
  String get sceneCityPlannerFase1Dorp => 'Phase 1 · Village';

  @override
  String get sceneCityPlannerDataWeergaveHeatmap => 'Data view (heatmap)';

  @override
  String get sceneCityPlannerOpslaanLaden => 'Save & load';

  @override
  String get sceneCityPlannerNieuweKaart => 'New map';

  @override
  String get sceneCityPlannerRechtermuisknop => 'Right-click';

  @override
  String get sceneCityPlannerSchuiven => 'pan ·';

  @override
  String get sceneCityPlannerScroll => 'scroll';

  @override
  String get sceneCityPlannerZoomen => 'zoom ·';

  @override
  String get sceneCityPlannerGrid => 'grid ·';

  @override
  String get sceneCityPlannerSnappen => 'snap ·';

  @override
  String get sceneCityPlannerAlt => 'Alt';

  @override
  String get sceneCityPlannerVrijPlaatsen => 'free placement';

  @override
  String get sceneCityPlannerInspecteur => 'Inspector';

  @override
  String get sceneCityPlannerOnderzoek => 'Research';

  @override
  String get sceneCityPlannerFinanciN => 'Finances';

  @override
  String get sceneCityPlannerBeleid => 'Policy';

  @override
  String get sceneCityPlannerOv => 'Transit';

  @override
  String get sceneCityPlannerStad => 'City';

  @override
  String get sceneCityPlannerGemiddeldeTevredenheid => 'Average satisfaction';

  @override
  String get sceneCityPlannerMaandelijksSaldo => 'Monthly balance';

  @override
  String get sceneCityPlannerWoningmarkt => 'Housing market';

  @override
  String get sceneCityPlannerVerkeersdrukte => 'Traffic congestion';

  @override
  String get sceneCityPlannerOnderwijsdekking => 'Education coverage';

  @override
  String get sceneCityPlannerZorgdekking => 'Healthcare coverage';

  @override
  String get sceneCityPlannerMilieuLuchtkwaliteit =>
      'Environment / air quality';

  @override
  String get sceneCityPlannerElektriciteit => 'Electricity';

  @override
  String get sceneCityPlannerDrinkwater => 'Drinking water';

  @override
  String get sceneCityPlannerVoedsel => 'Food';

  @override
  String get sceneCityPlannerSluiten => 'Close';

  @override
  String get sceneCityPlannerOpslaanAmpLaden => 'Save &amp; load';

  @override
  String get sceneCityPlannerBergenBlokkerenDitTrac =>
      'Mountains block this route.';

  @override
  String get sceneCityPlannerRotondePastHierNiet =>
      'A roundabout won’t fit here.';

  @override
  String get sceneCityPlannerWegsegmentVerwijderd => 'Road segment removed.';

  @override
  String get sceneCityPlannerHierKunJeNietBouwenWaterBergWegOfBezet =>
      'You can’t build here (water, mountain, road, or occupied).';

  @override
  String get sceneCityPlannerDeVormMoetNAaneengeslotenGeheelZijn =>
      'The shape must be one connected piece.';

  @override
  String get sceneCityPlannerLetOpDitGebouwHeeftNogGeenWegHetWerktPasAl =>
      'Note: this building has no road yet. It will work once a road is beside it.';

  @override
  String get sceneCityPlannerHaltesMoetenOpEenWegLiggen =>
      'Stops must be on a road.';

  @override
  String get sceneCityPlannerOnvoldoendeGeldVoorDezeHalte =>
      'Not enough money for this stop.';

  @override
  String get sceneCityPlannerEenLijnHeeftMinstens2HaltesNodig =>
      'A line needs at least 2 stops.';

  @override
  String get sceneCityPlannerSpelOpgeslagen => 'Game saved.';

  @override
  String get sceneCityPlannerOpslaanMislukt => 'Save failed:';

  @override
  String get sceneCityPlannerGeenOpgeslagenSpelGevonden =>
      'No saved game found.';

  @override
  String get sceneCityPlannerSaveBestandBeschadigd => 'Save file is damaged.';

  @override
  String get sceneCityPlannerDezeSaveKomtVanEenOudereVersieOfAndereKaar =>
      'This save is from an older version or a different map size and can’t be loaded.';

  @override
  String get sceneCityPlannerSpelGeladen => 'Game loaded.';

  @override
  String get sceneCityPlannerSandboxEenLeegWitCanvasOnbeperktGeldAllesO =>
      'Sandbox! An empty white canvas: unlimited money, everything unlocked. Build your dream city.';

  @override
  String get sceneCityPlannerNieuweKaartBeginMetEenWegHuizenEenAkkerEnE =>
      'New map! Start with a road, houses, a field, and a water pump.';

  @override
  String get sceneCityPlannerLijnVerwijderen => 'Delete line';

  @override
  String get sceneCityPlannerSaveVerwijderen => 'Delete save';

  @override
  String get sceneCityPlannerDezeSaveVerwijderen => 'Delete this save?';

  @override
  String get sceneCityPlannerSleepVrijOverDeKaartDeEngineMaaktErAutomat =>
      'Drag freely across the map — the engine automatically turns it into a smooth road. Crossing roads become intersections.';

  @override
  String get sceneCityPlannerKlikOmEenRotondeTePlaatsenSluitErWegenOpAa =>
      'Click to place a roundabout; connect roads to it.';

  @override
  String get sceneCityPlannerKlikHaltesOpWegenDubbelklikOfEnterOmDeLijn =>
      'Click stops on roads; double-click or press Enter to finish the line.';

  @override
  String get sceneCityPlannerOnvoldoendeGeld => 'Not enough money.';

  @override
  String get sceneCityPlannerKlikOpEenGebouwOmHetTeInspecterenEnAanTePa =>
      'Click a building to inspect and adjust it.';

  @override
  String get sceneCityPlannerTips => 'Tips:';

  @override
  String get sceneCityPlannerTekenGebouwenInElkeVormDoorCellenTeSlepen =>
      '· Draw buildings in any shape by dragging cells.';

  @override
  String get sceneCityPlannerGebouwenHebbenEenWegNodigEnStroomWaterViaD =>
      '· Buildings need a road, plus power and water through the road network.';

  @override
  String get sceneCityPlannerGebruikDeHeatmapsAnalyseOfRechtsbovenOmPro =>
      '· Use heatmaps (Analysis or top right) to find problems.';

  @override
  String get sceneSpaceColonySol10800 => 'Sol 1 · 08:00';

  @override
  String get sceneSpaceColonyGettingStarted => 'Getting Started';

  @override
  String get sceneSpaceColonyDemolishMode => '🧨 Demolish mode';

  @override
  String get sceneSpaceColonyColony => 'Colony';

  @override
  String get sceneSpaceColonyResearch => '🔬 Research';

  @override
  String get sceneSpaceColonySendRoverToRuins => '🛰️ Send Rover to Ruins';

  @override
  String get sceneSpaceColonySave => '💾 Save';

  @override
  String get sceneSpaceColonyLoad => '📂 Load';

  @override
  String get sceneSpaceColonyTutorial => '❓ Tutorial';

  @override
  String get sceneSpaceColonyDragWasdToPanScrollToZoomClickToBuildRight =>
      'Drag / WASD to pan · scroll to zoom · click to build · right-click cancels · hover tiles for info · click a colonist for their stats. Place mining rigs on ore (orange) or crystal (purple) deposits, water extractors on ice (light blue). Ancient ruins (dusty violet) can be explored with a rover from a Vehicle Garage.';

  @override
  String get sceneSpaceColonyMinimap => 'Minimap';

  @override
  String get sceneSpaceColonyColonists => 'Colonists';

  @override
  String get sceneSpaceColonyEventLog => 'Event log';

  @override
  String get sceneSpaceColonyWelcomeToSpaceColony =>
      '🚀 Welcome to Space Colony';

  @override
  String get sceneSpaceColonyYouVeLandedWith3ColonistsALandingModuleASm =>
      'You’ve landed with 3 colonists, a landing module, a small battery, a solar panel and basic materials. Your job: keep everyone alive and grow a self-sufficient colony.';

  @override
  String get sceneSpaceColonyBeforeAnythingElse => 'Before anything else';

  @override
  String get sceneSpaceColonyPlaceTheseFiveBuildingsWithoutThemYourColo =>
      ', place these five buildings — without them your colony will run out of power, air or water within a day or two:';

  @override
  String get sceneSpaceColonySolarPanel => 'Solar Panel';

  @override
  String get sceneSpaceColonyPowerDuringTheDay => '— power during the day.';

  @override
  String get sceneSpaceColonyStoresPowerSoSystemsKeepRunningAtNight =>
      '— stores power so systems keep running at night.';

  @override
  String get sceneSpaceColonyOxygenGenerator => 'Oxygen Generator';

  @override
  String get sceneSpaceColonyTurnsWaterIntoBreathableAir =>
      '— turns water into breathable air.';

  @override
  String get sceneSpaceColonyWaterExtractor => 'Water Extractor';

  @override
  String get sceneSpaceColonyPlaceItOnAnIceFieldLightBlueTilesForAWater =>
      '— place it on an ice field (light blue tiles) for a water supply.';

  @override
  String get sceneSpaceColonyMiningRig => 'Mining Rig';

  @override
  String get sceneSpaceColonyPlaceItOnAMetalDepositOrangeTilesSoYouCanK =>
      '— place it on a metal deposit (orange tiles) so you can keep building.';

  @override
  String get sceneSpaceColonyWatchTheResourceBarAtTheTopAnythingShownIn =>
      'Watch the resource bar at the top — anything shown in red is running low. Ore and crystal deposits run out over time, so keep exploring for new ones. Click any colonist’s name to see their full stats. Reopen this any time with the ❓ Tutorial button.';

  @override
  String get sceneSpaceColonyLetSGo => 'Let’s go!';

  @override
  String get sceneSpaceColonySciencePoints => 'Science points:';

  @override
  String get sceneSpaceColonyProducedByLaboratories =>
      '(produced by Laboratories)';

  @override
  String get sceneSpaceColonyColonyLost => 'COLONY LOST';

  @override
  String get sceneSpaceColonyAllColonistsHavePerished =>
      'All colonists have perished.';

  @override
  String get sceneSpaceColonyNewColony => 'New Colony';

  @override
  String get sceneSpaceColonyHungerOSleepHappyHealth =>
      'hunger / O₂ / sleep / happy / health';

  @override
  String get sceneSpaceColonyNextSkillUp => '· next skill-up: %';

  @override
  String get sceneSpaceColonySkills => 'Skills';

  @override
  String get sceneSpaceColonyHp => 'HP /';

  @override
  String get sceneSubwayBuilderDayTimeWeekday => 'Day · time · weekday';

  @override
  String get sceneSubwayBuilderWeather => 'Weather';

  @override
  String get sceneSubwayBuilderTreasury => 'Treasury';

  @override
  String get sceneSubwayBuilderDailyTransitRiders => 'Daily transit riders';

  @override
  String get sceneSubwayBuilderShareOfAllCommutesOnYourNetwork =>
      'Share of all commutes on your network';

  @override
  String get sceneSubwayBuilderPauseSpace => 'Pause (Space)';

  @override
  String get sceneSubwayBuilder1RealSecond1InGameMinute =>
      '1 real second = 1 in-game minute';

  @override
  String get sceneSubwayBuilder6InGameMinutesSecond =>
      '6 in-game minutes/second';

  @override
  String get sceneSubwayBuilder30InGameMinutesSecond =>
      '30 in-game minutes/second';

  @override
  String get sceneSubwayBuilderTiltTheCameraFor3DBuildings =>
      'Tilt the camera for 3D buildings';

  @override
  String get sceneSubwayBuilder3D => '3D';

  @override
  String get sceneSubwayBuilderNetworkAnalysis => 'Network analysis';

  @override
  String get sceneSubwayBuilderChangeLocation => 'Change location';

  @override
  String get sceneSubwayBuilderPlayTogetherCoOp => 'Play together (co-op)';

  @override
  String get sceneSubwayBuilderCoOp => 'Co-op';

  @override
  String get sceneSubwayBuilderToggleDarkLightTheme =>
      'Toggle dark / light theme';

  @override
  String get sceneSubwayBuilderHowToPlay => 'How to play';

  @override
  String get sceneSubwayBuilderCloseMenu => 'Close menu';

  @override
  String get sceneSubwayBuilderShortHopsFastTunnelsAnywhere =>
      'Short hops, fast, tunnels anywhere';

  @override
  String get sceneSubwayBuilderShortHopsCheapRunsOnStreets =>
      'Short hops, cheap, runs on streets';

  @override
  String get sceneSubwayBuilderAnyDistanceCheapestSlow =>
      'Any distance, cheapest, slow';

  @override
  String get sceneSubwayBuilderLongHopsOnRealStationsAndTracks =>
      'Long hops on real stations and tracks';

  @override
  String get sceneSubwayBuilderVeryLongHopsVeryFastFewStopsRealStationsAn =>
      'Very long hops, very fast, few stops — real stations and tracks';

  @override
  String get sceneSubwayBuilderSelectPan => 'Select / pan';

  @override
  String get sceneSubwayBuilderDrawLine => 'Draw line';

  @override
  String get sceneSubwayBuilderBulldoze => 'Bulldoze';

  @override
  String get sceneSubwayBuilderFetchEveryOfficialRailwayStationCurrentlyO =>
      'Fetch every official railway station currently on screen';

  @override
  String get sceneSubwayBuilderLoadStations => 'Load stations';

  @override
  String get sceneSubwayBuilderDataViews => 'Data views';

  @override
  String get sceneSubwayBuilderResidents => 'Residents';

  @override
  String get sceneSubwayBuilderJobs => 'Jobs';

  @override
  String get sceneSubwayBuilderStopReach => 'Stop reach';

  @override
  String get sceneSubwayBuilderLineLoad => 'Line load';

  @override
  String get sceneSubwayBuilderLines => 'Lines';

  @override
  String get sceneSubwayBuilderNewLine => 'New line';

  @override
  String get sceneSubwayBuilderTakeLoan => 'Take loan';

  @override
  String get sceneSubwayBuilderRepay => 'Repay';

  @override
  String get sceneSubwayBuilderRendering => 'Rendering';

  @override
  String get sceneSubwayBuilder3DBuildings => '3D buildings';

  @override
  String get sceneSubwayBuilder2DMode => '2D mode';

  @override
  String get sceneSubwayBuilderRenderDistance => 'Render distance';

  @override
  String get sceneSubwayBuilderLodDistance => 'LOD distance';

  @override
  String get sceneSubwayBuilderMenu => 'Menu';

  @override
  String get sceneSubwayBuilderToggle2DMode => 'Toggle 2D mode';

  @override
  String get sceneSubwayBuilder2D => '2D';

  @override
  String get sceneSubwayBuilderSurveying => 'Surveying';

  @override
  String get sceneSubwayBuilderWelcomeBackTo => 'Welcome back to';

  @override
  String get sceneSubwayBuilderStillSyncingWithTheHost =>
      'Still syncing with the host…';

  @override
  String get sceneSubwayBuilderClickOneOfTheTwoEndStationsOf =>
      'Click one of the two end stations of';

  @override
  String get sceneSubwayBuilderSurveyingTheRailCorridor =>
      'Surveying the rail corridor…';

  @override
  String get sceneSubwayBuilderAlreadyOnThisDraft => 'Already on this draft';

  @override
  String get sceneSubwayBuilderTreasuryIsInTheRedConsiderALoanOrHigherFar =>
      'Treasury is in the red — consider a loan or higher fares';

  @override
  String get sceneSubwayBuilderCouldNotConnectToTheRoom =>
      'Could not connect to the room:';

  @override
  String get sceneSubwayBuilderCouldNotReachTheCoOpServer =>
      'Could not reach the co-op server';

  @override
  String get sceneSubwayBuilderLostConnectionToTheRoomReconnecting =>
      'Lost connection to the room — reconnecting…';

  @override
  String get sceneSubwayBuilderRunningTheClockForThisRoom =>
      'Running the clock for this room';

  @override
  String get sceneSubwayBuilderCouldNotJoinThatRoom =>
      'Could not join that room:';

  @override
  String get sceneSubwayBuilderTravellingTo => 'Travelling to';

  @override
  String get sceneSubwayBuilderJoinedRoom => 'Joined room';

  @override
  String get sceneSubwayBuilderLoadACityFirst => 'Load a city first';

  @override
  String get sceneSubwayBuilderCouldNotCreateARoom =>
      'Could not create a room:';

  @override
  String get sceneSubwayBuilderRoom => 'Room';

  @override
  String get sceneSubwayBuilderNoLinesYetPickAModePlaceStopsThenConnectTh =>
      'No lines yet. Pick a mode, place stops, then connect them with the Line tool.';

  @override
  String get sceneSubwayBuilderToggleOvernight22000500Service =>
      'Toggle overnight (22:00–05:00) service';

  @override
  String get sceneSubwayBuilderToggleWeekendService => 'Toggle weekend service';

  @override
  String get sceneSubwayBuilderRoomCode => 'Room code';

  @override
  String get sceneSubwayBuilderSearchAnyCityTownOrAddress =>
      'Search any city, town or address…';

  @override
  String get sceneSubwayBuilderTakeA => 'Take a';

  @override
  String get sceneSubwayBuilderLineDrawingCancelled => 'Line drawing cancelled';

  @override
  String get sceneSubwayBuilderLeftTheCoOpRoom => 'Left the co-op room';

  @override
  String get sceneSubwayBuilderInviteSent => 'Invite sent';

  @override
  String get sceneSubwayBuilderCouldNotSendInvite => 'Could not send invite:';

  @override
  String get sceneSubwayBuilderEnterARoomCode => 'Enter a room code';

  @override
  String get sceneSubwayBuilderTurnOff2DModeInSettingsToTiltTheCamera =>
      'Turn off 2D mode in Settings to tilt the camera';

  @override
  String get sceneSubwayBuilderLoadingOfficialStationsInView =>
      'Loading official stations in view…';

  @override
  String get sceneSubwayBuilderStationLookupFailedTheMapDataServiceIsBusy =>
      'Station lookup failed — the map data service is busy, try again';

  @override
  String get sceneSubwayBuilderNoNewOfficialStationsFoundInView =>
      'No new official stations found in view';

  @override
  String get sceneSubwayBuilderOnlyWhoeverIsRunningTheClockManagesTheTrea =>
      'Only whoever is running the clock manages the treasury';

  @override
  String aiDetectorHiddenCharacterEvidence(String name, int count) {
    return '\"$name ×$count (hidden)\"';
  }

  @override
  String aiDetectorSignatureEvidence(String name, int count) {
    return '$name ×$count';
  }

  @override
  String aiDetectorAssistantEvidence(String name, int count) {
    return '\"$name ×$count\"';
  }

  @override
  String get aiDetectorInvisibleSoftHyphen => 'soft hyphen';

  @override
  String get aiDetectorInvisibleGraphemeJoiner => 'combining grapheme joiner';

  @override
  String get aiDetectorInvisibleMongolianSeparator =>
      'Mongolian vowel separator';

  @override
  String get aiDetectorInvisibleZeroWidthSpace => 'zero-width space';

  @override
  String get aiDetectorInvisibleZeroWidthNonJoiner => 'zero-width non-joiner';

  @override
  String get aiDetectorInvisibleZeroWidthJoiner => 'zero-width joiner';

  @override
  String get aiDetectorInvisibleWordJoiner => 'word joiner';

  @override
  String get aiDetectorInvisibleFunctionApplication => 'function application';

  @override
  String get aiDetectorInvisibleTimes => 'invisible times';

  @override
  String get aiDetectorInvisibleSeparator => 'invisible separator';

  @override
  String get aiDetectorInvisiblePlus => 'invisible plus';

  @override
  String get aiDetectorInvisibleNoBreakSpace => 'zero-width no-break space';

  @override
  String get aiDetectorInvisibleUnicodeTag => 'Unicode tag character';

  @override
  String get aiDetectorInvisibleVariationSelector => 'variation selector';

  @override
  String get aiDetectorEvidenceClaudeAi => 'claude.ai referenced';

  @override
  String get aiDetectorEvidenceAnthropic => 'Anthropic named';

  @override
  String get aiDetectorEvidenceClaudeModel => 'Claude model id';

  @override
  String get aiDetectorEvidenceClaudeSelfReference => 'Claude self-reference';

  @override
  String get aiDetectorEvidenceAsAnAi => '\"As an AI\" disclaimer';

  @override
  String get aiDetectorEvidenceCapabilityDisclaimer => 'capability disclaimer';

  @override
  String get aiDetectorEvidenceChatSignOff => 'chat sign-off';

  @override
  String get aiDetectorEvidenceContrastNotJust =>
      '\"not just X, but Y\" construction';

  @override
  String get aiDetectorEvidenceContrastNotAbout =>
      '\"it is not X; it is Y\" construction';

  @override
  String get aiDetectorEvidenceContrastIsntJust =>
      '\"isn’t just\" construction';

  @override
  String get aiDetectorEvidenceContrastStagedReveal => 'staged reveal';

  @override
  String get aiDetectorEvidenceContrastThatsPoint =>
      '\"that’s the point\" close';

  @override
  String get aiDetectorEvidenceContrastHeresThing =>
      '\"here’s the thing\" pivot';

  @override
  String aiDetectorEvidenceSentenceRange(int min, int max) {
    return 'sentences range $min–$max words';
  }

  @override
  String aiDetectorEvidenceVariationIndex(String index) {
    return 'variation index $index (low = uniform)';
  }

  @override
  String aiDetectorPhraseEvidence(String phrase, int count, String soft) {
    String _temp0 = intl.Intl.selectLogic(soft, {
      'true': ' (soft)',
      'other': '',
    });
    return '“$phrase” ×$count$_temp0';
  }

  @override
  String aiDetectorEvidenceShortSentences(int short, int total) {
    return '$short of $total sentences under 6 words';
  }

  @override
  String aiDetectorEvidenceLongSentences(int long, int total) {
    return '$long of $total sentences over 27 words';
  }

  @override
  String aiDetectorEvidenceVoiceCounts(
    int pronouns,
    int informal,
    int questions,
  ) {
    return '$pronouns personal pronouns, $informal casual words, $questions questions';
  }

  @override
  String aiDetectorEvidenceVoiceRate(String rate) {
    return '$rate per 1000 words (low = impersonal)';
  }

  @override
  String aiDetectorEvidenceMarkdownHeadings(int count) {
    return '$count Markdown headings';
  }

  @override
  String aiDetectorEvidenceBulletLines(int count) {
    return '$count bullet or numbered lines';
  }

  @override
  String aiDetectorEvidenceBoldLeads(int count) {
    return '$count bold lead-ins';
  }

  @override
  String aiDetectorEvidenceLabelLines(int count) {
    return '$count \"Label: text\" lines';
  }

  @override
  String get aiDetectorEvidencePlainProse => 'plain prose, no list scaffolding';

  @override
  String aiDetectorEvidenceScaffoldLines(int count, int total) {
    return '$count of $total lines are scaffolding';
  }

  @override
  String aiDetectorEvidenceContrast(String label, int count) {
    return '$label ×$count';
  }

  @override
  String get aiDetectorEvidenceNoneFound => 'none found';

  @override
  String aiDetectorEvidencePerThousand(String rate) {
    return '$rate per 1000 words';
  }

  @override
  String aiDetectorEvidenceOpener(String word, int count) {
    return '$word ×$count at sentence start';
  }

  @override
  String get aiDetectorEvidenceNoneUsed => 'none used';

  @override
  String aiDetectorEvidenceContractions(int count, int words) {
    return '$count contractions in $words words';
  }

  @override
  String aiDetectorEvidenceEmDashes(int count, String rate) {
    return '$count em dashes ($rate per 1000 words)';
  }

  @override
  String aiDetectorEvidencePassive(int count, String rate) {
    return '$count passive constructions ($rate per 100 words)';
  }

  @override
  String aiDetectorEvidenceParagraphSizes(int count, String sizes) {
    return '$count paragraphs: $sizes';
  }

  @override
  String aiDetectorEvidenceRepeatedOpener(String word, int count, int total) {
    return '\"$word\" starts $count of $total sentences';
  }

  @override
  String get aiDetectorRepeatedOpenersNotEnough =>
      'Not enough distinctive sentence starts to measure.';

  @override
  String aiDetectorHighlightPhraseNote(String phrase) {
    return 'Stock LLM phrase “$phrase”';
  }

  @override
  String aiDetectorHighlightContrastNote(String label) {
    return 'Corrective contrast: $label';
  }

  @override
  String aiDetectorHighlightSignatureNote(String label) {
    return '$label';
  }

  @override
  String aiDetectorHighlightAssistantNote(String label) {
    return '$label';
  }

  @override
  String get aiDetectorHighlightPassiveNote => 'Passive construction';

  @override
  String aiDetectorHighlightOpenerNote(String word) {
    return 'Sentence opens with “$word”';
  }

  @override
  String get aiDetectorHighlightEmDashNote => 'Em dash';

  @override
  String aiDetectorHighlightHiddenNote(String name) {
    return 'Hidden $name inside this word';
  }

  @override
  String get mcLauncherJvmArgsHint =>
      'Optional JVM arguments, for example: -XX:+UseG1GC';

  @override
  String get airportUpgradeBoardingLanes => 'Boarding lanes';

  @override
  String get airportUpgradeBoardingLanesEffect =>
      'One more lane of passengers boards at the same time.';

  @override
  String get airportUpgradeBoardingSpeed => 'Boarding speed';

  @override
  String get airportUpgradeBoardingSpeedEffect =>
      'Each lane boards 1.5 more passengers per minute.';

  @override
  String get airportUpgradeSurfaceLighting => 'Surface & lighting';

  @override
  String get airportUpgradeSurfaceLightingEffect =>
      'Landings and take-offs clear the runway 15% faster per level.';

  @override
  String get airportUpgradeAsphalt => 'Asphalt';

  @override
  String get airportUpgradeAsphaltStandsEffect =>
      'Ground handling and boarding are 15% faster per level.';

  @override
  String get airportUpgradeQuality => 'Quality';

  @override
  String get airportUpgradeQualityEffect =>
      'Counts as one more decoration per level.';

  @override
  String get airportUpgradeStockStaff => 'Stock & staff';

  @override
  String get airportUpgradeStockStaffEffect =>
      '15% more sales and 25% quicker service per level.';

  @override
  String get airportUpgradeComfort => 'Comfort';

  @override
  String get airportUpgradeComfortEffect =>
      '+1% satisfaction and 15% more income per level.';

  @override
  String get airportUpgradeStaff => 'Staff';

  @override
  String get airportUpgradeInfoDeskEffect =>
      'Each level counts as another staffed desk.';

  @override
  String get airportUpgradeStaffEffect =>
      'Passengers are processed 25% faster per level.';

  @override
  String get airportUpgradeAsphaltTaxiwayEffect =>
      'Aircraft taxi 10% faster per level.';

  @override
  String get airportUpgradeComfortTerminalEffect =>
      'Passengers are 1% happier per level, averaged over sections.';

  @override
  String get airportUpgradeEquipment => 'Equipment';

  @override
  String get airportUpgradeEquipmentEffect =>
      'Ground services dispatched from here are 20% faster per level.';

  @override
  String get airportUpgradeRadar => 'Radar';

  @override
  String get airportUpgradeRadarEffect =>
      'Approaches take 10% less time per level.';

  @override
  String get airportUpgradeService => 'Service';

  @override
  String get airportUpgradeServiceEffect =>
      'Each level counts as another set of bins.';

  @override
  String get airportUpgradeBeltSpeed => 'Belt speed';

  @override
  String get airportUpgradeBeltSpeedEffect =>
      'Passengers collect their bags 25% faster per level.';

  @override
  String get airportSlotEarlyMorning => 'Early morning';

  @override
  String get airportSlotMorning => 'Morning';

  @override
  String get airportSlotAfternoon => 'Afternoon';

  @override
  String get airportSlotEvening => 'Evening';

  @override
  String get airportSlotAnyTime => 'Any time';

  @override
  String get airportHaulShort => 'Short haul';

  @override
  String get airportHaulMedium => 'Medium haul';

  @override
  String get airportHaulLong => 'Long haul';

  @override
  String get airportLedgerConstruction => 'Construction';

  @override
  String get airportLedgerVehicles => 'Vehicles';

  @override
  String get airportLedgerPenalty => 'Penalty';

  @override
  String get airportLedgerUpkeep => 'Upkeep';

  @override
  String get airportLedgerService => 'Service';

  @override
  String get airportLedgerLease => 'Lease';

  @override
  String get airportLedgerHandling => 'Handling';

  @override
  String get airportLedgerRetail => 'Retail';

  @override
  String get airportLedgerCargo => 'Cargo';

  @override
  String get airportLedgerFuel => 'Fuel';

  @override
  String get airportLedgerCrew => 'Crew';

  @override
  String get airportLedgerLanding => 'Landing';

  @override
  String get airportLedgerMaintenance => 'Maintenance';

  @override
  String get airportLedgerTickets => 'Tickets';

  @override
  String get airportLedgerDay => 'Day';

  @override
  String get airportLedgerBoarded => 'Boarded';

  @override
  String get airportLedgerDelay => 'Delay';

  @override
  String get airportLedgerFee => 'Fee';

  @override
  String get airportLedgerNoTransactions =>
      'Your transactions will appear here.';

  @override
  String get airportIssueCancelledByOperator => 'Cancelled by operator';

  @override
  String get airportIssueContractCancelled => 'Contract cancelled';

  @override
  String get airportIssueStandRemoved => 'Stand removed';

  @override
  String get airportIssueAirportAccessDisconnected =>
      'Airport access is disconnected';

  @override
  String get airportIssueAircraftUnavailable => 'Aircraft unavailable';

  @override
  String get airportIssueWaitingForStand => 'Waiting for stand';

  @override
  String get airportIssueWaitingForRunwayClearance =>
      'Waiting for runway clearance';

  @override
  String get airportIssueWaitingForTaxiwayClearance =>
      'Waiting for taxiway clearance';

  @override
  String get airportIssueRequiredContractFacilityUnavailable =>
      'A required contract facility is unavailable';

  @override
  String airportIssueTerminalNeeds(Object facility) {
    return 'The terminal needs $facility';
  }

  @override
  String get airportIssueWaitingForGroundServices =>
      'Waiting for ground services';

  @override
  String get airportIssuePassengersStillInTerminal =>
      'Passengers are still in the terminal';

  @override
  String get airportIssueWaitingForPushbackTug => 'Waiting for pushback tug';

  @override
  String airportLedgerDemolished(Object facility) {
    return 'Demolished $facility';
  }

  @override
  String airportLedgerPurchasedVehicle(Object vehicle) {
    return 'Purchased $vehicle vehicle';
  }

  @override
  String get airportLedgerInfrastructureUpkeep =>
      'Airport infrastructure upkeep';

  @override
  String get airportLedgerVehicleStaffingMaintenance =>
      'Vehicle staffing and maintenance';

  @override
  String airportLedgerUnplannedFlights(Object carrier, Object count) {
    return '$carrier: $count unplanned flights';
  }

  @override
  String airportLedgerLateIncompleteService(Object flightId) {
    return 'Late or incomplete service $flightId';
  }

  @override
  String airportLedgerGroundServices(Object flightId) {
    return 'Ground services $flightId';
  }

  @override
  String airportLedgerCargoFlight(Object flightId) {
    return 'Cargo $flightId';
  }

  @override
  String airportLedgerFlightFuel(Object flightId) {
    return 'Flight fuel $flightId';
  }

  @override
  String airportLedgerFlightCrew(Object flightId) {
    return 'Flight crew $flightId';
  }

  @override
  String airportLedgerLandingFlight(Object flightId) {
    return 'Landing $flightId';
  }

  @override
  String airportLedgerFlightMaintenance(Object flightId) {
    return 'Flight maintenance $flightId';
  }

  @override
  String airportLedgerHeavyCheck(Object registration) {
    return 'Heavy check $registration';
  }

  @override
  String airportLedgerLeaseAircraft(Object registration) {
    return 'Lease $registration';
  }

  @override
  String airportLedgerContractHandling(Object carrier, Object flightId) {
    return '$carrier $flightId';
  }

  @override
  String airportLedgerTicketFlight(
    Object destination,
    Object flightId,
    Object returnSuffix,
  ) {
    return '$destination $flightId$returnSuffix';
  }

  @override
  String airportLedgerUpgradeLevel(
    Object facility,
    Object attribute,
    Object level,
  ) {
    return '$facility: $attribute level $level';
  }

  @override
  String get airportLedgerReturnSuffix => 'return';

  @override
  String airportLedgerBuiltFacility(Object facility) {
    return 'Built $facility';
  }

  @override
  String airportLedgerFacilitySales(Object facility) {
    return 'Sales at $facility';
  }

  @override
  String get airportVehicleFuel => 'Fuel truck';

  @override
  String get airportVehicleBaggage => 'Baggage tug';

  @override
  String get airportVehicleBus => 'Passenger bus';

  @override
  String get airportVehiclePushback => 'Pushback tug';

  @override
  String get syncCryptoCorruptedRecoveryEnvelope =>
      'The recovery envelope is corrupted.';

  @override
  String get syncCryptoCorruptedRecoveryKeyBox =>
      'The recovery key box is corrupted.';

  @override
  String get syncCryptoCorruptedSnapshot => 'The sync snapshot is corrupted.';

  @override
  String get syncCryptoAuthenticationFailed =>
      'The encrypted data could not be authenticated.';

  @override
  String get syncCryptoUnrecognizedEncryptedData =>
      'The encrypted data format is not recognized.';

  @override
  String get syncCryptoDifferentPassword =>
      'Could not decrypt. It was encrypted with a different password.';

  @override
  String get syncStateInvalid => 'The sync state is invalid.';

  @override
  String get syncStateReadFailed =>
      'The sync state could not be read. Keep the file for recovery.';

  @override
  String get syncStateInvalidEncryptionKey =>
      'The sync encryption key is invalid.';

  @override
  String get syncStateRestoreCredentials =>
      'The sync state is invalid. Restore the original credentials.';

  @override
  String get mcNbtExpectedCompound => 'Expected a root compound tag.';

  @override
  String mcNbtUnknownTag(Object type, Object position) {
    return 'Unknown NBT tag type $type at byte $position.';
  }

  @override
  String mcWorldNoLongerExists(Object folderName) {
    return 'World \"$folderName\" no longer exists.';
  }

  @override
  String get aiUsageUnknownModel => 'Unknown model';

  @override
  String sceneAirlineTycoonUpgradeAttributeToLevel(
    String attribute,
    String level,
  ) {
    return 'Upgrade $attribute to level $level';
  }

  @override
  String sceneAirlineTycoonCancelPenalty(String cost) {
    return 'Cancel: $cost penalty';
  }

  @override
  String sceneAirlineTycoonDemolishFacilityQuestion(String facility) {
    return 'Demolish $facility?';
  }

  @override
  String sceneAirlineTycoonDemolishRefund(String refund) {
    return 'You get $refund back. This cannot be undone.';
  }

  @override
  String sceneAirlineTycoonCarrierStartsInSlot(String carrier, String slot) {
    return '$carrier starts in $slot';
  }

  @override
  String sceneAssetStudioRotateToDegrees(String degrees) {
    return 'Rotate to $degrees degrees';
  }

  @override
  String sceneCityPlannerInsufficientFunds(String amount) {
    return 'Not enough money: $amount needed.';
  }

  @override
  String sceneCityPlannerMustBuildByWater(String building) {
    return '$building must be built beside water.';
  }

  @override
  String sceneCityPlannerLinePausedDepot(String type) {
    return 'Line created but paused: build a $type depot first.';
  }

  @override
  String sceneCityPlannerLineRuns(String line) {
    return '$line is running! Manage frequency in the public transport panel.';
  }

  @override
  String sceneSubwayWelcomeBack(String place, String day) {
    return 'Welcome back to $place — day $day';
  }

  @override
  String sceneSubwayDeleteLineQuestion(String line) {
    return 'Delete $line?';
  }

  @override
  String sceneSubwayStationLeased(String station, String cost) {
    return '$station leased · $cost';
  }

  @override
  String sceneSubwayStationBuilt(String station, String cost) {
    return '$station built · $cost';
  }

  @override
  String sceneSubwayLineRemoved(String line, String refund) {
    return '$line removed · $refund refunded';
  }

  @override
  String sceneSubwayLineExtended(String line, String station) {
    return '$line extended to $station';
  }

  @override
  String sceneSubwayStationModeStop(String station, String mode) {
    return '$station is a $mode stop — switch mode to connect it';
  }

  @override
  String sceneSubwaySelectLineEndpoint(String line) {
    return 'Click one of the two end stations of $line';
  }

  @override
  String sceneSubwayStationDemolished(String station, String refund) {
    return '$station demolished · $refund refunded';
  }

  @override
  String sceneSubwayRouteHopsMax(Object mode, Object maxKm) {
    return '$mode hops max $maxKm km between stops — add a stop in between, or use Train for long distances';
  }

  @override
  String get sceneSubwayRouteNoRailConnection =>
      'No rail connection exists between these stations';

  @override
  String get sceneSubwayRouteNoStreetRoute =>
      'No street route between these stops';

  @override
  String get sceneSubwayStationInOpenWater => 'That’s open water';

  @override
  String sceneSubwayPlaceModeStopsOnStreet(Object mode) {
    return 'Place $mode stops on a street';
  }

  @override
  String get sceneSubwayNotEnoughFunds => 'Not enough funds';

  @override
  String sceneSubwayModeServicesRealRailStations(Object mode) {
    return '$mode services only call at real railway stations — click one';
  }

  @override
  String sceneSubwayModeServicesHighlightedRailStations(Object mode) {
    return '$mode services only call at real railway stations — click a highlighted one';
  }

  @override
  String get sceneSubwayLineRequiresTwoStops =>
      'A line needs at least two stops';

  @override
  String get sceneSubwayUnknownLineOrStation => 'Unknown line or station';

  @override
  String get sceneSubwayStopDifferentMode =>
      'That stop belongs to a different mode';

  @override
  String get sceneSubwayStopAlreadyOnLine => 'Already on this line';

  @override
  String get sceneSubwayUnknownStation => 'Unknown station';

  @override
  String get sceneSubwayUnknownLine => 'Unknown line';

  @override
  String sceneSubwayLineFleetLimit(Object maxVehicles) {
    return 'Line is at its fleet limit ($maxVehicles)';
  }

  @override
  String get sceneSubwayLineRequiresVehicle =>
      'A line needs at least one vehicle';

  @override
  String get sceneSubwayNoOutstandingLoans => 'No outstanding loans';

  @override
  String sceneSubwayDraftStopsCost(Object count, Object distance, Object cost) {
    return '$count stops · $distance · $cost — Enter to build, Esc to cancel.';
  }

  @override
  String sceneSubwayDraftStopsCostTunnel(
    Object count,
    Object distance,
    Object cost,
  ) {
    return '$count stops · $distance · $cost (incl. underwater tunnelling) — Enter to build, Esc to cancel.';
  }

  @override
  String sceneSubwayLineOpened(Object line, Object cost) {
    return '$line opened — $cost, two vehicles included';
  }

  @override
  String sceneSubwayLineOpenedTunnel(Object line, Object cost) {
    return '$line opened — $cost, two vehicles included, including underwater tunnelling';
  }

  @override
  String get sceneSubwayOfficialStationLoadedOne => '1 official station loaded';

  @override
  String sceneSubwayOfficialStationsLoaded(Object count) {
    return '$count official stations loaded';
  }

  @override
  String sceneSubwayJoinedRoomCode(Object code) {
    return 'Joined room $code';
  }

  @override
  String sceneSubwayRoomCreatedReady(Object code) {
    return 'Room $code created — start building';
  }

  @override
  String sceneSubwayRoomCreatedShare(Object code) {
    return 'Room $code created — share the code or invite a contact';
  }

  @override
  String sceneSubwayCouldNotConnectRoom(Object error) {
    return 'Could not connect to the room: $error';
  }

  @override
  String sceneSubwayCouldNotJoinRoom(Object error) {
    return 'Could not join that room: $error';
  }

  @override
  String sceneSubwayCouldNotCreateRoom(Object error) {
    return 'Could not create a room: $error';
  }

  @override
  String sceneSubwayCouldNotSendInvite(Object error) {
    return 'Could not send invite: $error';
  }

  @override
  String sceneSubwayGrantAwarded(Object label, Object amount) {
    return '$label: $amount to build with';
  }

  @override
  String sceneSubwayLoanReceived(Object amount) {
    return '$amount loan received';
  }

  @override
  String get sceneSubwayDeleteLineRefundDetails =>
      'You get 25% of construction plus vehicle resale back.';

  @override
  String get sceneSubwayAchievementCommuterFavourite => 'Commuter favourite';

  @override
  String get sceneSubwayAchievementCommuterFavouriteSub => '1,000 daily riders';

  @override
  String get sceneSubwayAchievementCityMover => 'City mover';

  @override
  String get sceneSubwayAchievementCityMoverSub => '25,000 daily riders';

  @override
  String get sceneSubwayAchievementMetropolisMachine => 'Metropolis machine';

  @override
  String get sceneSubwayAchievementMetropolisMachineSub =>
      '100,000 daily riders';

  @override
  String get sceneSubwayAchievementNetworkEffect => 'Network effect';

  @override
  String get sceneSubwayAchievementNetworkEffectSub => '10 stations in service';

  @override
  String get sceneSubwayAchievementEveryCorner => 'On every corner';

  @override
  String get sceneSubwayAchievementEveryCornerSub => '40 stations in service';

  @override
  String get sceneSubwayAchievementGoingDistance => 'Going the distance';

  @override
  String get sceneSubwayAchievementGoingDistanceSub => '50 km of routes';

  @override
  String get sceneSubwayAchievementSteelSpine => 'Steel spine';

  @override
  String get sceneSubwayAchievementSteelSpineSub => '250 km of routes';

  @override
  String get sceneSubwayAchievementFullSpectrum => 'Full spectrum';

  @override
  String get sceneSubwayAchievementFullSpectrumSub =>
      'All five modes in service';

  @override
  String get sceneSubwayAchievementUnderRiver => 'Under the river';

  @override
  String get sceneSubwayAchievementUnderRiverSub => 'A tunnel under open water';

  @override
  String get sceneSubwayAchievementIntercityExpress => 'Intercity express';

  @override
  String get sceneSubwayAchievementIntercityExpressSub =>
      'Two real stations 15+ km apart on one line';

  @override
  String get sceneSubwayAchievementAirportLink => 'Airport link';

  @override
  String get sceneSubwayAchievementAirportLinkSub =>
      'An airport station on the network';

  @override
  String get sceneSubwayAchievementRingLine => 'Ring line';

  @override
  String get sceneSubwayAchievementRingLineSub =>
      'A line that loops back on itself';

  @override
  String get sceneSubwayAchievementBulletService => 'Bullet service';

  @override
  String get sceneSubwayAchievementBulletServiceSub =>
      'A high-speed line in operation';

  @override
  String get sceneSubwayAchievementCityNeverSleeps => 'The city never sleeps';

  @override
  String get sceneSubwayAchievementCityNeverSleepsSub =>
      '10,000 riders with every line running all night';

  @override
  String get sceneSubwayAchievementInTheBlack => 'In the black';

  @override
  String get sceneSubwayAchievementInTheBlackSub =>
      'A profitable day with 5,000+ riders';

  @override
  String get sceneSubwayMilestoneCityHall => 'City Hall takes notice';

  @override
  String get sceneSubwayMilestoneStateGrant => 'State transit grant';

  @override
  String get sceneSubwayMilestoneFederalGrant => 'Federal infrastructure grant';

  @override
  String get sceneSubwayMilestoneTransitCityAward => 'Transit City award';

  @override
  String get sceneSubwayMilestoneWorldMetroFund => 'World-class metro fund';

  @override
  String get sceneSubwayMilestoneTransitCapital =>
      'Transit capital of the world';

  @override
  String get sceneSubwayLineColorRed => 'Red';

  @override
  String get sceneSubwayLineColorBlue => 'Blue';

  @override
  String get sceneSubwayLineColorGreen => 'Green';

  @override
  String get sceneSubwayLineColorOrange => 'Orange';

  @override
  String get sceneSubwayLineColorPurple => 'Purple';

  @override
  String get sceneSubwayLineColorYellow => 'Yellow';

  @override
  String get sceneSubwayLineColorTeal => 'Teal';

  @override
  String get sceneSubwayLineColorPink => 'Pink';

  @override
  String get sceneSubwayLineColorLime => 'Lime';

  @override
  String get sceneSubwayLineColorIndigo => 'Indigo';

  @override
  String get sceneSubwayLineColorAmber => 'Amber';

  @override
  String get sceneSubwayLineColorCyan => 'Cyan';

  @override
  String get sceneSubwayVehicleTrain => 'train';

  @override
  String get sceneSubwayVehicleTram => 'tram';

  @override
  String get sceneSubwayVehicleBus => 'bus';

  @override
  String sceneSubwayLinePanelModeSpeed(Object mode, Object speed) {
    return 'Mode $mode · $speed km/h';
  }

  @override
  String sceneSubwayLinePanelStopsLength(Object count, Object length) {
    return 'Stops $count · length $length';
  }

  @override
  String sceneSubwayLinePanelFleetHeadway(
    Object count,
    Object vehicle,
    Object headway,
  ) {
    return 'Fleet $count ${vehicle}s · headway $headway';
  }

  @override
  String sceneSubwayLinePanelRidersRevenue(Object count, Object revenue) {
    return 'Riders $count/day · revenue $revenue/day';
  }

  @override
  String sceneSubwayLinePanelPeakCrowding(Object percent) {
    return 'Peak crowding $percent%';
  }

  @override
  String sceneSubwayLinePanelDelays(Object factor) {
    return 'Delays ×$factor';
  }

  @override
  String sceneSubwayLinePanelDisruption(Object label) {
    return '$label — service is slowed until it clears';
  }

  @override
  String get sceneSubwayLinePanelServiceWindow => 'Service window';

  @override
  String get sceneSubwayLinePanelNight => 'Night';

  @override
  String get sceneSubwayLinePanelWeekend => 'Weekend';

  @override
  String get sceneSubwayLinePanelExtend => 'Extend';

  @override
  String get sceneSubwayStatsTransitShare => 'Transit share';

  @override
  String get sceneSubwayStatsDailyRiders => 'Daily riders';

  @override
  String get sceneSubwayStatsCoverage => 'Coverage';

  @override
  String get sceneSubwayStatsResidentsNearStop => 'residents near a stop';

  @override
  String get sceneSubwayStatsTransfers => 'Transfers';

  @override
  String get sceneSubwayStatsAvgTransitTrip => 'Avg transit trip';

  @override
  String get sceneSubwayStatsAvgCarTrip => 'Avg car trip';

  @override
  String get sceneSubwayStatsRouteLength => 'Route length';

  @override
  String get sceneSubwayStatsStops => 'Stops';

  @override
  String get sceneSubwayStatsFleet => 'Fleet';

  @override
  String get sceneSubwayStatsSpentToDate => 'Spent to date';

  @override
  String sceneSubwayStatsTransitLegend(Object percent) {
    return 'Transit $percent%';
  }

  @override
  String sceneSubwayStatsDrivingLegend(Object percent) {
    return 'Driving $percent%';
  }

  @override
  String get sceneSubwayStatsBoardingsByMode => 'Boardings by mode';

  @override
  String get sceneSubwayStatsBusiestStops => 'Busiest stops';

  @override
  String get sceneSubwayStatsPlayDaysForData => 'Play a few days for data…';

  @override
  String get sceneSubwayCoopSignedOut =>
      'Co-op rooms are tied to your Luma account — that’s what makes invites and room membership work. Sign in from the app’s account settings, then come back here.';

  @override
  String sceneSubwayCoopRoomCodeTitle(Object code) {
    return 'Co-op — room $code';
  }

  @override
  String get sceneSubwayCoopRoomCodeDescription =>
      'Anyone with the code (or an invite) can join and build on this network with you.';

  @override
  String get sceneSubwayCoopClockYou =>
      'You’re currently running the clock for this room.';

  @override
  String get sceneSubwayCoopClockPeer =>
      'A fellow builder is currently running the clock — you’ll pick it up automatically if they leave.';

  @override
  String get sceneSubwayCoopInviteContact => 'Invite a chat contact';

  @override
  String sceneSubwayCoopNoChatContacts(Object code) {
    return 'No chat contacts yet — set up the Chat plugin first, or just share the room code $code directly.';
  }

  @override
  String get sceneSubwayCoopInviteInstruction =>
      'Sends them a chat message with the room code — they still need to tap Join.';

  @override
  String get sceneSubwayCoopLoadingContacts => 'Loading your chat contacts…';

  @override
  String get sceneSubwayCoopLoadingRooms => 'Loading your rooms…';

  @override
  String get sceneSubwayCoopRoomsEmpty =>
      'Build on the same network as friends — invite via chat, or share a room code. Whoever’s connected keeps the clock running; leave and rejoin any time.';

  @override
  String get sceneSubwayCoopCreateRoom => 'Create a new room';

  @override
  String get sceneSubwayCoopJoinByCode => '— or join by code —';

  @override
  String get sceneSubwayCoopJoinRoom => 'Join room';

  @override
  String sceneSubwayCoopMemberCountOne(Object count) {
    return '$count member';
  }

  @override
  String sceneSubwayCoopMemberCountMany(Object count) {
    return '$count members';
  }

  @override
  String get sceneSubwayCoopRoomYours => 'yours';

  @override
  String get sceneSubwayCoopOpenRoom => 'Open';

  @override
  String get sceneSubwayCoopNoRoom => 'No room';

  @override
  String get sftpHostWindowsPermissionsUnsupported =>
      'This device does not support POSIX permissions.';

  @override
  String serverTycoonGeneratedPcRigName(Object id) {
    return 'Rig $id';
  }

  @override
  String serverTycoonGeneratedServerRigName(Object id) {
    return 'Server $id';
  }

  @override
  String serverTycoonGeneratedRouterName(Object id) {
    return 'Router $id';
  }

  @override
  String get sftpHostTooManyPairingFailures =>
      'Too many wrong pairing passwords came from this device. Wait a few minutes, or show a new pairing password and use that.';

  @override
  String sftpHostTooManyDevices(Object maxClients) {
    return 'This device already has $maxClients devices connected. Disconnect one there and try again.';
  }

  @override
  String get githubConnectTokenHint => 'ghp_… or github_pat_…';

  @override
  String get mcWorldModeSurvival => 'Survival';

  @override
  String get mcWorldModeCreative => 'Creative';

  @override
  String get mcWorldModeAdventure => 'Adventure';

  @override
  String get mcWorldModeSpectator => 'Spectator';

  @override
  String get sceneAirlineTycoonStageApproach => 'On approach';

  @override
  String get sceneAirlineTycoonStagePositioning => 'Towed to the stand';

  @override
  String get sceneAirlineTycoonStageToHangar => 'Towed to the hangar';

  @override
  String get sceneAirlineTycoonStageLanding => 'Landing';

  @override
  String get sceneAirlineTycoonStagePushback => 'Pushing back';

  @override
  String get sceneAirlineTycoonStageBoarding => 'Boarding';

  @override
  String get sceneAirlineTycoonStageTaxiIn => 'Taxiing to stand';

  @override
  String get sceneAirlineTycoonStageTaxiOut => 'Taxiing to runway';

  @override
  String get sceneAirlineTycoonStageUnloading => 'Unloading passengers';

  @override
  String get sceneAirlineTycoonStageServicing => 'Ground services';

  @override
  String get sceneAirlineTycoonStageDeparting => 'Taking off';

  @override
  String get sceneAirlineTycoonStageRemote => 'Flying the route';

  @override
  String get sceneAirlineTycoonStageAwaitingStand => 'Waiting for a stand';

  @override
  String get sceneAirlineTycoonStageAwaitingAirport =>
      'Waiting for airport access';

  @override
  String sceneAirlineTycoonStandName(Object code) {
    return 'Stand $code';
  }

  @override
  String get sceneAirlineTycoonUnassignedStand => 'Unassigned stand';

  @override
  String sceneAirlineTycoonContractCharter(Object flights) {
    return 'Charter · $flights flight(s)';
  }

  @override
  String sceneAirlineTycoonContractDaily(Object flights) {
    return 'Daily · $flights days';
  }

  @override
  String sceneSubwayMilestoneShareReached(Object grant, Object share) {
    return '$share% transit share reached — $grant grant awarded!';
  }

  @override
  String sceneSubwayAchievementBonus(Object grant, Object sub) {
    return '$sub — $grant bonus';
  }

  @override
  String sceneSubwayCrowdingGrantReduced(Object grant, Object label) {
    return '$label — crowding cut the surge payout to $grant';
  }

  @override
  String sceneSubwaySurgeGrant(Object grant, Object label) {
    return '$label brought a surge: +$grant';
  }

  @override
  String get cardWalletNameHintExample => 'Albert Heijn loyalty card';

  @override
  String get sceneCityPlannerDataGras => 'Grass';

  @override
  String get sceneCityPlannerDataBos => 'Forest';

  @override
  String get sceneCityPlannerDataHeuvels => 'Hills';

  @override
  String get sceneCityPlannerDataBergen => 'Mountains';

  @override
  String get sceneCityPlannerDataRivier => 'River';

  @override
  String get sceneCityPlannerDataMeer => 'Lake';

  @override
  String get sceneCityPlannerDataKustwater => 'Coastal water';

  @override
  String get sceneCityPlannerDataZand => 'Sand';

  @override
  String get sceneCityPlannerDataLandbouwgrond => 'Farmland';

  @override
  String get sceneCityPlannerDataKleineStraat => 'Small street';

  @override
  String get sceneCityPlannerDataNormaleWeg => 'Standard road';

  @override
  String get sceneCityPlannerDataHoofdweg => 'Main road';

  @override
  String get sceneCityPlannerDataSnelweg => 'Highway';

  @override
  String get sceneCityPlannerDataLeeg => 'Empty';

  @override
  String get sceneCityPlannerDataWonen => 'Residential';

  @override
  String get sceneCityPlannerDataLuxeWonen => 'Luxury residential';

  @override
  String get sceneCityPlannerDataStudentenwoningen => 'Student housing';

  @override
  String get sceneCityPlannerDataWinkel => 'Shop';

  @override
  String get sceneCityPlannerDataRestaurant => 'Restaurant';

  @override
  String get sceneCityPlannerDataKantoor => 'Office';

  @override
  String get sceneCityPlannerDataIndustrie => 'Industry';

  @override
  String get sceneCityPlannerDataOpslag => 'Storage';

  @override
  String get sceneCityPlannerDataPubliekeFunctie => 'Public services';

  @override
  String get sceneCityPlannerDataHuis => 'House';

  @override
  String get sceneCityPlannerDataAppartement => 'Apartment';

  @override
  String get sceneCityPlannerDataFlat => 'Apartment block';

  @override
  String get sceneCityPlannerDataWoontoren => 'Residential tower';

  @override
  String get sceneCityPlannerDataLuxeWoning => 'Luxury home';

  @override
  String get sceneCityPlannerDataStudentenwoning => 'Student residence';

  @override
  String get sceneCityPlannerDataSupermarkt => 'Supermarket';

  @override
  String get sceneCityPlannerDataWinkelcentrum => 'Shopping mall';

  @override
  String get sceneCityPlannerDataFabriek => 'Factory';

  @override
  String get sceneCityPlannerDataMagazijn => 'Warehouse';

  @override
  String get sceneCityPlannerDataTechnologiebedrijf => 'Technology company';

  @override
  String get sceneCityPlannerDataAkker => 'Crop field';

  @override
  String get sceneCityPlannerDataBoerderij => 'Farm';

  @override
  String get sceneCityPlannerDataKas => 'Greenhouse';

  @override
  String get sceneCityPlannerDataVerticalFarm => 'Vertical farm';

  @override
  String get sceneCityPlannerDataVoedselfabriek => 'Food factory';

  @override
  String get sceneCityPlannerDataBasisschool => 'Primary school';

  @override
  String get sceneCityPlannerDataMiddelbareSchool => 'Secondary school';

  @override
  String get sceneCityPlannerDataUniversiteit => 'University';

  @override
  String get sceneCityPlannerDataHuisartsenpost => 'Medical clinic';

  @override
  String get sceneCityPlannerDataZiekenhuis => 'Hospital';

  @override
  String get sceneCityPlannerDataPolitiebureau => 'Police station';

  @override
  String get sceneCityPlannerDataBrandweerkazerne => 'Fire station';

  @override
  String get sceneCityPlannerDataGemeentehuis => 'Town hall';

  @override
  String get sceneCityPlannerDataPark => 'Park';

  @override
  String get sceneCityPlannerDataKolencentrale => 'Coal power plant';

  @override
  String get sceneCityPlannerDataGascentrale => 'Gas power plant';

  @override
  String get sceneCityPlannerDataWindmolen => 'Wind turbine';

  @override
  String get sceneCityPlannerDataZonnepark => 'Solar farm';

  @override
  String get sceneCityPlannerDataWaterkrachtcentrale =>
      'Hydroelectric power plant';

  @override
  String get sceneCityPlannerDataKerncentrale => 'Nuclear power plant';

  @override
  String get sceneCityPlannerDataFusiereactor => 'Fusion reactor';

  @override
  String get sceneCityPlannerDataBatterijopslag => 'Battery storage';

  @override
  String get sceneCityPlannerDataWaterpomp => 'Water pump';

  @override
  String get sceneCityPlannerDataWaterzuivering => 'Water treatment plant';

  @override
  String get sceneCityPlannerDataRioolwaterzuivering =>
      'Sewage treatment plant';

  @override
  String get sceneCityPlannerDataVuilstortplaats => 'Landfill';

  @override
  String get sceneCityPlannerDataRecyclingcentrum => 'Recycling center';

  @override
  String get sceneCityPlannerDataAfvalenergiecentrale =>
      'Waste-to-energy plant';

  @override
  String get sceneCityPlannerDataParkeerterrein => 'Parking lot';

  @override
  String get sceneCityPlannerDataParkeergarage => 'Parking garage';

  @override
  String get sceneCityPlannerDataBusdepot => 'Bus depot';

  @override
  String get sceneCityPlannerDataTramremise => 'Tram depot';

  @override
  String get sceneCityPlannerDataMetrodepot => 'Metro depot';

  @override
  String get sceneCityPlannerDataTreinstation => 'Train station';

  @override
  String get sceneCityPlannerDataLuchthaven => 'Airport';

  @override
  String get sceneCityPlannerDataHaven => 'Port';

  @override
  String get sceneCityPlannerDataBuslijn => 'Bus line';

  @override
  String get sceneCityPlannerDataTramlijn => 'Tram line';

  @override
  String get sceneCityPlannerDataMetrolijn => 'Metro line';

  @override
  String get sceneCityPlannerDataTreinlijn => 'Train line';

  @override
  String get sceneCityPlannerDataDorp => 'Village';

  @override
  String get sceneCityPlannerDataGemeente => 'Municipality';

  @override
  String get sceneCityPlannerDataStad => 'City';

  @override
  String get sceneCityPlannerDataMetropool => 'Metropolis';

  @override
  String get sceneCityPlannerDataToekomststad => 'Future city';

  @override
  String get sceneCityPlannerDataVerkeerslichten => 'Traffic lights';

  @override
  String get sceneCityPlannerData15WegcapaciteitOpKruispunten =>
      '+15% road capacity at intersections.';

  @override
  String get sceneCityPlannerDataRotondes => 'Roundabouts';

  @override
  String get sceneCityPlannerData10DoorstromingOpAlleWegen =>
      '+10% traffic flow on all roads.';

  @override
  String get sceneCityPlannerDataTramnetwerk => 'Tram network';

  @override
  String get sceneCityPlannerDataOntgrendeltTramsEnTramremises =>
      'Unlocks trams and tram depots.';

  @override
  String get sceneCityPlannerDataSnelwegen => 'Highways';

  @override
  String get sceneCityPlannerDataOntgrendeltSnelwegen => 'Unlocks highways.';

  @override
  String get sceneCityPlannerDataParkeergarages => 'Parking garages';

  @override
  String get sceneCityPlannerDataOntgrendeltMeerlaagsParkeren =>
      'Unlocks multi-storey parking.';

  @override
  String get sceneCityPlannerDataMetro => 'Metro';

  @override
  String get sceneCityPlannerDataOntgrendeltMetrolijnen =>
      'Unlocks metro lines.';

  @override
  String get sceneCityPlannerDataSpoorwegen => 'Railways';

  @override
  String get sceneCityPlannerDataOntgrendeltTreinenEnStations =>
      'Unlocks trains and stations.';

  @override
  String get sceneCityPlannerDataLuchtvaart => 'Aviation';

  @override
  String get sceneCityPlannerDataOntgrendeltDeLuchthavenToerisme =>
      'Unlocks the airport (tourism).';

  @override
  String get sceneCityPlannerDataHavenlogistiek => 'Port logistics';

  @override
  String get sceneCityPlannerDataOntgrendeltDeHavenMaterialenToerisme =>
      'Unlocks the port (materials + tourism).';

  @override
  String get sceneCityPlannerDataAiVerkeersbeheer => 'AI traffic management';

  @override
  String get sceneCityPlannerData30Wegcapaciteit20Files =>
      '+30% road capacity, −20% congestion.';

  @override
  String get sceneCityPlannerDataAutonomeVoertuigen => 'Autonomous vehicles';

  @override
  String get sceneCityPlannerData25ParkeerbehoefteSnellereReistijden =>
      '−25% parking demand, shorter travel times.';

  @override
  String get sceneCityPlannerDataModernBeton => 'Modern concrete';

  @override
  String get sceneCityPlannerData10Bouwkosten => '−10% construction costs.';

  @override
  String get sceneCityPlannerDataPrefabBouw => 'Prefabricated construction';

  @override
  String get sceneCityPlannerData15Bouwkosten => '−15% construction costs.';

  @override
  String get sceneCityPlannerDataWolkenkrabbers => 'Skyscrapers';

  @override
  String get sceneCityPlannerDataOntgrendeltWoontorensTot40Verdiepingen =>
      'Unlocks residential towers up to 40 floors.';

  @override
  String get sceneCityPlannerDataSlimmeGebouwen => 'Smart buildings';

  @override
  String get sceneCityPlannerData20EnergieEnWaterverbruikVanGebouwen =>
      '−20% building energy and water use.';

  @override
  String get sceneCityPlannerDataWindenergie => 'Wind energy';

  @override
  String get sceneCityPlannerDataOntgrendeltWindmolens =>
      'Unlocks wind turbines.';

  @override
  String get sceneCityPlannerDataZonneEnergie => 'Solar energy';

  @override
  String get sceneCityPlannerDataOntgrendeltZonneparken =>
      'Unlocks solar farms.';

  @override
  String get sceneCityPlannerDataGascentrales => 'Gas power plants';

  @override
  String get sceneCityPlannerDataOntgrendeltGascentralesSchonerDanKolen =>
      'Unlocks gas power plants (cleaner than coal).';

  @override
  String get sceneCityPlannerDataWaterkracht => 'Hydropower';

  @override
  String get sceneCityPlannerDataOntgrendeltWaterkrachtcentralesAanWater =>
      'Unlocks hydroelectric plants (beside water).';

  @override
  String get sceneCityPlannerDataEnergieopslag => 'Energy storage';

  @override
  String
  get sceneCityPlannerDataOntgrendeltBatterijenDemptSchommelingenVanWindZon =>
      'Unlocks batteries: smooths wind/solar fluctuations.';

  @override
  String get sceneCityPlannerDataKernenergie => 'Nuclear energy';

  @override
  String get sceneCityPlannerDataOntgrendeltKerncentrales =>
      'Unlocks nuclear power plants.';

  @override
  String get sceneCityPlannerDataFusieEnergie => 'Fusion energy';

  @override
  String get sceneCityPlannerDataOntgrendeltDeFusiereactor =>
      'Unlocks the fusion reactor.';

  @override
  String get sceneCityPlannerDataOntgrendeltGroteDrinkwaterzuivering =>
      'Unlocks large drinking-water treatment plants.';

  @override
  String get sceneCityPlannerDataModernRiool => 'Modern sewers';

  @override
  String
  get sceneCityPlannerDataOntgrendeltRioolwaterzuiveringMinderVervuiling =>
      'Unlocks sewage treatment (less pollution).';

  @override
  String get sceneCityPlannerDataRecycling => 'Recycling';

  @override
  String get sceneCityPlannerDataOntgrendeltHetRecyclingcentrum =>
      'Unlocks the recycling center.';

  @override
  String get sceneCityPlannerDataAfvalenergie => 'Waste energy';

  @override
  String get sceneCityPlannerDataOntgrendeltDeAfvalenergiecentrale =>
      'Unlocks the waste-to-energy plant.';

  @override
  String get sceneCityPlannerDataGroeneDaken => 'Green roofs';

  @override
  String get sceneCityPlannerData15VervuilingInWoongebieden =>
      '−15% pollution in residential areas.';

  @override
  String get sceneCityPlannerDataNatuurbeheer => 'Nature management';

  @override
  String get sceneCityPlannerDataParkenEnBosWerken50Sterker =>
      'Parks and forests are 50% more effective.';

  @override
  String get sceneCityPlannerDataVerticalFarming => 'Vertical farming';

  @override
  String get sceneCityPlannerDataOntgrendeltVerticalFarmsInDeStad =>
      'Unlocks vertical farms in the city.';

  @override
  String get sceneCityPlannerDataBeterOnderwijs => 'Better education';

  @override
  String get sceneCityPlannerData25SchoolcapaciteitEnKwaliteit =>
      '+25% school capacity and quality.';

  @override
  String get sceneCityPlannerDataModerneZorg => 'Modern healthcare';

  @override
  String get sceneCityPlannerData25ZorgcapaciteitGezondereInwoners =>
      '+25% healthcare capacity, healthier residents.';

  @override
  String get sceneCityPlannerDataSocialeWoningbouw => 'Social housing';

  @override
  String get sceneCityPlannerDataGoedkoperWonenTevredenheidLageInkomens =>
      'Cheaper housing: happier low-income residents.';

  @override
  String get sceneCityPlannerDataSubsidieZonnepanelen => 'Solar panel subsidy';

  @override
  String get sceneCityPlannerDataGebouwenWekkenZelfWatStroomOp8Netvraag =>
      'Buildings generate some power (−8% grid demand).';

  @override
  String get sceneCityPlannerDataBelastingOpVervuiling => 'Pollution tax';

  @override
  String
  get sceneCityPlannerDataExtraInkomsten10Industrieproductie15Vervuiling =>
      'Extra revenue, −10% industrial output, −15% pollution.';

  @override
  String get sceneCityPlannerDataKernenergieVerbieden => 'Ban nuclear energy';

  @override
  String
  get sceneCityPlannerDataKerncentralesWordenUitgeschakeldSommigeInwonersBlijAnderenNiet =>
      'Nuclear plants are disabled. Some residents approve, others do not.';

  @override
  String get sceneCityPlannerDataLokaleLandbouwStimuleren =>
      'Support local agriculture';

  @override
  String get sceneCityPlannerData25OpbrengstVanAkkersKassenEnBoerderijen =>
      '+25% yield from fields, greenhouses and farms.';

  @override
  String get sceneCityPlannerDataGoedkopeVoedselimport => 'Cheap food imports';

  @override
  String
  get sceneCityPlannerDataVoedseltekortenWordenGoedkoperOpgevangen40Importkosten =>
      'Food shortages cost less to cover (−40% import costs).';

  @override
  String get sceneCityPlannerDataBenzinebelasting => 'Fuel tax';

  @override
  String get sceneCityPlannerDataInkomsten10AutoverkeerKleineTevredenheid =>
      'Revenue, −10% car traffic, slight loss of satisfaction.';

  @override
  String get sceneCityPlannerDataElektrischRijdenStimuleren =>
      'Encourage electric vehicles';

  @override
  String get sceneCityPlannerData30VerkeersvervuilingEnergievraag =>
      '−30% traffic pollution, higher energy demand.';

  @override
  String get sceneCityPlannerDataOvSubsidie => 'Public transport subsidy';

  @override
  String get sceneCityPlannerDataGratisErOV40OVGebruikMinderFiles =>
      'Free or cheaper public transport: +40% use, less congestion.';

  @override
  String get sceneCityPlannerDataGroeneGebouwenVerplicht =>
      'Require green buildings';

  @override
  String get sceneCityPlannerData15Bouwkosten20EnergieverbruikNieuweGebouwen =>
      '+15% construction costs, −20% energy use in new buildings.';

  @override
  String get sceneCityPlannerDataGoedkopeWoningbouw => 'Affordable housing';

  @override
  String
  get sceneCityPlannerDataTevredenheidEnSnellereMigratieBijWoningtekort =>
      'Higher satisfaction and faster migration during housing shortages.';

  @override
  String get sceneCityPlannerDataKaartweergaveNormaal => 'Map view: normal';

  @override
  String get sceneCityPlannerDataHeatmapVerkeersdrukte => 'Heatmap: traffic';

  @override
  String get sceneCityPlannerDataHeatmapGeluid => 'Heatmap: noise';

  @override
  String get sceneCityPlannerDataHeatmapLuchtkwaliteit =>
      'Heatmap: air quality';

  @override
  String get sceneCityPlannerDataHeatmapGeluk => 'Heatmap: happiness';

  @override
  String get sceneCityPlannerDataHeatmapGrondwaarde => 'Heatmap: land value';

  @override
  String get sceneCityPlannerDataHeatmapOVBereikbaarheid =>
      'Heatmap: transit access';

  @override
  String get sceneCityPlannerDataHeatmapOnderwijs => 'Heatmap: education';

  @override
  String get sceneCityPlannerDataHeatmapGezondheid => 'Heatmap: health';

  @override
  String get sceneCityPlannerDataHeatmapVeiligheid => 'Heatmap: safety';

  @override
  String get sceneCityPlannerDataHeatmapGroen => 'Heatmap: green space';

  @override
  String get sceneCityPlannerDataHeatmapEnergienet => 'Heatmap: power grid';

  @override
  String get sceneCityPlannerDataHeatmapWaternet => 'Heatmap: water network';

  @override
  String get sceneCityPlannerDataEgaliserenGras => 'Level land (→ grass)';

  @override
  String get sceneCityPlannerDataMaaktBosHeuvelZandBouwrijp =>
      'Prepares forests, hills and sand for construction.';

  @override
  String get sceneCityPlannerDataWaterGraven => 'Dig water';

  @override
  String get sceneCityPlannerDataGraaftEenMeerOfKanaal =>
      'Digs a lake or canal.';

  @override
  String get sceneCityPlannerDataBosPlanten => 'Plant forest';

  @override
  String get sceneCityPlannerDataPlantBosMinderVervuilingMooierWonen =>
      'Plants forests: less pollution, nicer homes.';

  @override
  String get sceneCityPlannerDataVruchtbareGrondVoorAkkers =>
      'Fertile land for crops.';

  @override
  String get sceneSpaceColonyDataLandingModule => 'Landing Module';

  @override
  String
  get sceneSpaceColonyDataYourStartingHomeGeneratesATrickleOfPowerAndSheltersColonists =>
      'Your starting home. Generates a trickle of power and shelters colonists.';

  @override
  String get sceneSpaceColonyDataSolarPanel => 'Solar Panel';

  @override
  String get sceneSpaceColonyData6PowerDuringTheDay =>
      '+6 power during the day.';

  @override
  String get sceneSpaceColonyDataWindTurbine => 'Wind Turbine';

  @override
  String get sceneSpaceColonyData4PowerDayAndNightBoostedDuringDustStorms =>
      '+4 power day and night. Boosted during dust storms.';

  @override
  String get sceneSpaceColonyDataBattery => 'Battery';

  @override
  String get sceneSpaceColonyDataStores120PowerForTheNight =>
      'Stores 120 power for the night.';

  @override
  String get sceneSpaceColonyDataGeothermalPlant => 'Geothermal Plant';

  @override
  String get sceneSpaceColonyData18PowerMustBeBuiltOnALavaZone =>
      '+18 power. Must be built on a lava zone.';

  @override
  String get sceneSpaceColonyDataNuclearReactor => 'Nuclear Reactor';

  @override
  String get sceneSpaceColonyData45PowerDayAndNight =>
      '+45 power, day and night.';

  @override
  String get sceneSpaceColonyDataOxygenGenerator => 'Oxygen Generator';

  @override
  String get sceneSpaceColonyDataElectrolysesWater6OHUsesPowerAndALittleWater =>
      'Electrolyses water: +6 O₂/h, uses power and a little water.';

  @override
  String get sceneSpaceColonyDataWaterExtractor => 'Water Extractor';

  @override
  String get sceneSpaceColonyData5WaterHMustBeBuiltOnAnIceField =>
      '+5 water/h. Must be built on an ice field.';

  @override
  String get sceneSpaceColonyDataWaterRecycler => 'Water Recycler';

  @override
  String get sceneSpaceColonyData25WaterHAnywhereReclaimedFromWaste =>
      '+2.5 water/h anywhere, reclaimed from waste.';

  @override
  String get sceneSpaceColonyDataGreenhouse => 'Greenhouse';

  @override
  String
  get sceneSpaceColonyData3FoodAnd1OPerHourUsesWaterFarmingSkillBoostsYield =>
      '+3 food and +1 O₂ per hour. Uses water. Farming skill boosts yield.';

  @override
  String get sceneSpaceColonyDataHydroponicFarm => 'Hydroponic Farm';

  @override
  String get sceneSpaceColonyData7FoodHHighDensityFarming =>
      '+7 food/h high-density farming.';

  @override
  String get sceneSpaceColonyDataMiningRig => 'Mining Rig';

  @override
  String
  get sceneSpaceColonyData25MetalHMustBeOnAMetalDepositMiningSkillBoostsYield =>
      '+2.5 metal/h. Must be on a metal deposit. Mining skill boosts yield.';

  @override
  String get sceneSpaceColonyDataCrystalExtractor => 'Crystal Extractor';

  @override
  String get sceneSpaceColonyData08AlienCrystalHMustBeOnACrystalDeposit =>
      '+0.8 alien crystal/h. Must be on a crystal deposit.';

  @override
  String get sceneSpaceColonyDataGlassworks => 'Glassworks';

  @override
  String get sceneSpaceColonyDataSmeltsSand2GlassH =>
      'Smelts sand: +2 glass/h.';

  @override
  String get sceneSpaceColonyDataElectronicsFab => 'Electronics Fab';

  @override
  String get sceneSpaceColonyData15ElectronicsHConsumes1MetalH =>
      '+1.5 electronics/h, consumes 1 metal/h.';

  @override
  String get sceneSpaceColonyDataLivingQuarters => 'Living Quarters';

  @override
  String get sceneSpaceColonyDataHouses3ColonistsAndLetsThemSleepComfortably =>
      'Houses 3 colonists and lets them sleep comfortably.';

  @override
  String get sceneSpaceColonyDataPark => 'Park';

  @override
  String
  get sceneSpaceColonyDataAGreenOasisAmongTheDustSlowlyBoostsColonistHappinessNoResearchRequired =>
      'A green oasis among the dust. Slowly boosts colonist happiness. No research required.';

  @override
  String get sceneSpaceColonyDataLaboratory => 'Laboratory';

  @override
  String get sceneSpaceColonyData15ScienceHScienceSkillBoostsOutput =>
      '+1.5 science/h. Science skill boosts output.';

  @override
  String get sceneSpaceColonyDataMedicalBay => 'Medical Bay';

  @override
  String get sceneSpaceColonyDataSlowlyHealsSickAndInjuredColonists =>
      'Slowly heals sick and injured colonists.';

  @override
  String get sceneSpaceColonyDataStorageDepot => 'Storage Depot';

  @override
  String get sceneSpaceColonyData150CapacityForAllMaterials =>
      '+150 capacity for all materials.';

  @override
  String get sceneSpaceColonyDataDroneBay => 'Drone Bay';

  @override
  String get sceneSpaceColonyDataAutomation25OutputFromAllProducersStacks =>
      'Automation: +25% output from all producers (stacks).';

  @override
  String get sceneSpaceColonyDataTradeBeacon => 'Trade Beacon';

  @override
  String
  get sceneSpaceColonyDataEvery24hSells5CrystalToEarthFor20Metal10GlassAnd6Electronics =>
      'Every 24h, sells 5 crystal to Earth for 20 metal, 10 glass and 6 electronics.';

  @override
  String get sceneSpaceColonyDataVehicleGarage => 'Vehicle Garage';

  @override
  String
  get sceneSpaceColonyDataUnlocksRoverDispatchSendARoverToExploreAnAncientRuinsTileForAOneTimeReward =>
      'Unlocks rover dispatch: send a rover to explore an Ancient Ruins tile for a one-time reward.';

  @override
  String get sceneSpaceColonyDataObservatory => 'Observatory';

  @override
  String
  get sceneSpaceColonyData1ScienceHAndGivesEarlyWarningOfIncomingMeteorsHalvingTheDamageTheyDeal =>
      '+1 science/h and gives early warning of incoming meteors, halving the damage they deal.';

  @override
  String get sceneSpaceColonyDataDefenseTurret => 'Defense Turret';

  @override
  String
  get sceneSpaceColonyDataAutomaticallyShootsDownIncomingMeteorsBeforeTheyHit75InterceptChance =>
      'Automatically shoots down incoming meteors before they hit — 75% intercept chance.';

  @override
  String get sceneSpaceColonyDataWindTurbines => 'Wind Turbines';

  @override
  String get sceneSpaceColonyDataEnergy => 'Energy';

  @override
  String get sceneSpaceColonyDataUnlocksWindPowerWorksAtNight =>
      'Unlocks wind power, works at night.';

  @override
  String get sceneSpaceColonyDataGeothermalPower => 'Geothermal Power';

  @override
  String get sceneSpaceColonyDataUnlocksGeothermalPlantsOnLavaZones =>
      'Unlocks geothermal plants on lava zones.';

  @override
  String get sceneSpaceColonyDataNuclearPower => 'Nuclear Power';

  @override
  String get sceneSpaceColonyDataUnlocksTheNuclearReactor =>
      'Unlocks the nuclear reactor.';

  @override
  String get sceneSpaceColonyDataHydroponics => 'Hydroponics';

  @override
  String get sceneSpaceColonyDataBiology => 'Biology';

  @override
  String get sceneSpaceColonyDataUnlocksHighYieldHydroponicFarms =>
      'Unlocks high-yield hydroponic farms.';

  @override
  String get sceneSpaceColonyDataWaterRecycling => 'Water Recycling';

  @override
  String get sceneSpaceColonyDataUnlocksWaterRecyclersNoIceNeeded =>
      'Unlocks water recyclers (no ice needed).';

  @override
  String get sceneSpaceColonyDataMedicine => 'Medicine';

  @override
  String get sceneSpaceColonyDataUnlocksTheMedicalBay =>
      'Unlocks the medical bay.';

  @override
  String get sceneSpaceColonyDataCrystalExtraction => 'Crystal Extraction';

  @override
  String get sceneSpaceColonyDataEngineering => 'Engineering';

  @override
  String get sceneSpaceColonyDataUnlocksCrystalExtractors =>
      'Unlocks crystal extractors.';

  @override
  String get sceneSpaceColonyDataImprovedBatteries => 'Improved Batteries';

  @override
  String get sceneSpaceColonyDataBatteriesStore60Power =>
      'Batteries store +60 power.';

  @override
  String get sceneSpaceColonyDataRobotics => 'Robotics';

  @override
  String get sceneSpaceColonyDataUnlocksDroneBays25Production =>
      'Unlocks drone bays (+25% production).';

  @override
  String get sceneSpaceColonyDataOrbitalTrade => 'Orbital Trade';

  @override
  String get sceneSpaceColonyDataSpace => 'Space';

  @override
  String get sceneSpaceColonyDataUnlocksTheTradeBeacon =>
      'Unlocks the trade beacon.';

  @override
  String get sceneSpaceColonyDataExplorationRovers => 'Exploration Rovers';

  @override
  String
  get sceneSpaceColonyDataUnlocksTheVehicleGarageAndObservatoryLettingYouExploreAncientRuins =>
      'Unlocks the Vehicle Garage and Observatory, letting you explore Ancient Ruins.';

  @override
  String get sceneSpaceColonyDataAdvancedMining => 'Advanced Mining';

  @override
  String get sceneSpaceColonyData50OutputFromMiningRigsAndCrystalExtractors =>
      '+50% output from mining rigs and crystal extractors.';

  @override
  String get sceneSpaceColonyDataDefenseSystems => 'Defense Systems';

  @override
  String
  get sceneSpaceColonyDataUnlocksTheDefenseTurretWhichShootsDownIncomingMeteors =>
      'Unlocks the Defense Turret, which shoots down incoming meteors.';

  @override
  String get sceneSpaceColonyDataTerraforming => 'Terraforming';

  @override
  String
  get sceneSpaceColonyDataCapstoneTechYourColonyIsNowAdvancedEnoughToBeginTerraformingThePlanet =>
      'Capstone tech: your colony is now advanced enough to begin terraforming the planet.';

  @override
  String sceneCityPlannerDrawBuildingShape(Object building, Object cost) {
    return 'Drag cells to draw the shape of your $building. Cost: $cost per cell per floor.';
  }

  @override
  String sceneCityPlannerAvailableFromPhase(Object name, Object phase) {
    return 'Available from phase $phase ($name).';
  }

  @override
  String sceneSubwayVehicleBuyTitle(Object cost, Object vehicle) {
    return 'Buy a $vehicle ($cost)';
  }

  @override
  String sceneSubwayVehicleSellTitle(Object vehicle) {
    return 'Sell a $vehicle';
  }

  @override
  String get sceneCityPlannerMonthJanuary => 'Jan';

  @override
  String get sceneCityPlannerMonthFebruary => 'Feb';

  @override
  String get sceneCityPlannerMonthMarch => 'Mar';

  @override
  String get sceneCityPlannerMonthApril => 'Apr';

  @override
  String get sceneCityPlannerMonthMay => 'May';

  @override
  String get sceneCityPlannerMonthJune => 'Jun';

  @override
  String get sceneCityPlannerMonthJuly => 'Jul';

  @override
  String get sceneCityPlannerMonthAugust => 'Aug';

  @override
  String get sceneCityPlannerMonthSeptember => 'Sep';

  @override
  String get sceneCityPlannerMonthOctober => 'Oct';

  @override
  String get sceneCityPlannerMonthNovember => 'Nov';

  @override
  String get sceneCityPlannerMonthDecember => 'Dec';

  @override
  String sceneCityPlannerSaveFailed(Object error) {
    return 'Could not save: $error';
  }

  @override
  String get schoolFormulaDefaultCategory => 'Custom';

  @override
  String get marketplaceLoadFailedDetail =>
      'Check your connection, then try again.';

  @override
  String fileTreeErrorDetail(Object detail) {
    return 'Scan failed: $detail';
  }

  @override
  String get sceneSpaceColonyStatusBroken => 'BROKEN — click to repair (2🔩)';

  @override
  String get sceneSpaceColonyStatusDepleted =>
      'DEPLETED — deposit ran dry, demolish to reclaim the tile';

  @override
  String get sceneSpaceColonyStatusOnline => 'online';

  @override
  String get sceneSpaceColonyStatusNoPowerInput => 'no power/input';

  @override
  String get sceneSpaceColonyColonistNeedsTitle =>
      'hunger / O₂ / sleep / happy / health';

  @override
  String sceneSpaceColonyClockFormat(Object sol, Object time) {
    return 'Sol $sol · $time';
  }

  @override
  String sceneSpaceColonyLogTimestamp(Object message, Object sol, Object time) {
    return '[Sol $sol $time] $message';
  }

  @override
  String sceneSpaceColonyCostLabel(Object resources) {
    return 'Cost: $resources';
  }

  @override
  String sceneSpaceColonyRequiresResearch(Object technology) {
    return '(requires $technology)';
  }

  @override
  String get sceneSpaceColonyMeterHunger => 'Hunger';

  @override
  String get sceneSpaceColonyMeterOxygen => 'Oxygen';

  @override
  String get sceneSpaceColonyMeterSleep => 'Sleep';

  @override
  String get sceneSpaceColonyMeterHappiness => 'Happiness';

  @override
  String get sceneSpaceColonyMeterHealth => 'Health';

  @override
  String sceneSpaceColonyPowerLabel(Object power) {
    return 'Power $power';
  }

  @override
  String sceneCityPlannerNewsResearchCompleted(Object technology) {
    return '🔬 Research completed: $technology';
  }

  @override
  String sceneCityPlannerNewsPhaseGrowth(Object name, Object phase) {
    return '🏙 Your city has grown to phase $phase: $name! New buildings unlocked.';
  }

  @override
  String get sceneCityPlannerNewsBankruptcy =>
      '💸 The city is nearing bankruptcy! Lower spending or raise taxes.';

  @override
  String get sceneCityPlannerNewsPowerOutage =>
      '⚡ Power outage! The grid is overloaded — parts of the city are without power.';

  @override
  String get sceneCityPlannerNewsDrought =>
      '🌵 Drought! Water demand is approaching supply. Build more pumps or treatment plants.';

  @override
  String get sceneCityPlannerNewsCloudyWeek =>
      '🌥 A week of cloudy weather: wind and solar power are producing less.';

  @override
  String get sceneCityPlannerNewsFoodShortage =>
      '🌾 Food shortage looming: imports are becoming more expensive this month.';

  @override
  String sceneCityPlannerNewsRegionalGrant(Object amount) {
    return '🎉 Regional grant received: € $amount.';
  }

  @override
  String get sceneCityPlannerNewsEconomicDownturn =>
      '📉 Economic downturn: business tax revenue is 20% lower this month.';

  @override
  String sceneCityPlannerNewsBuildingFire(Object building) {
    return '🔥 Fire at $building! Without nearby fire services, the building is destroyed.';
  }

  @override
  String get sceneSpaceColonyEventMeteorWarningNote =>
      '(the Observatory softened the impact)';

  @override
  String get sceneSpaceColonyEventLandingSuccess =>
      'Landing successful. Sol 1 begins on an unexplored world.';

  @override
  String get sceneSpaceColonyEventSurvivalTip =>
      'Keep oxygen, food and power positive to survive.';

  @override
  String get sceneSpaceColonyEventMoraleLow =>
      '😠 Morale is dangerously low — production is suffering.';

  @override
  String sceneSpaceColonyEventDepositDepleted(
    Object building,
    Object resource,
  ) {
    return 'The $resource deposit under your $building ran dry — it is now idle. Relocate or demolish it.';
  }

  @override
  String sceneSpaceColonyEventDepositExhausted(Object resource) {
    return '⛏️ A $resource deposit has been exhausted!';
  }

  @override
  String sceneSpaceColonyEventRecoveredMedical(Object colonist) {
    return '$colonist recovered in the medical bay.';
  }

  @override
  String sceneSpaceColonyEventRecovered(Object colonist) {
    return '$colonist recovered.';
  }

  @override
  String sceneSpaceColonyEventSkillImproved(
    Object colonist,
    Object level,
    Object skill,
  ) {
    return '$colonist improved $skill to $level.';
  }

  @override
  String sceneSpaceColonyEventColonistDied(Object colonist) {
    return '$colonist has died.';
  }

  @override
  String sceneSpaceColonyEventNewColonist(Object name) {
    return 'A new colonist, $name, has arrived from Earth!';
  }

  @override
  String get sceneSpaceColonyEventTradeBeacon =>
      'Trade beacon: sold 5 crystal → +20 metal, +10 glass, +6 electronics.';

  @override
  String get sceneSpaceColonyEventDustStormPassed =>
      'The dust storm has passed.';

  @override
  String get sceneSpaceColonyEventSolarFlareOver =>
      'Solar flare over — power generation restored.';

  @override
  String get sceneSpaceColonyAlertMoraleLow =>
      '😠 Morale is dangerously low — production is suffering.';

  @override
  String get sceneSpaceColonyAlertDustStorm =>
      '🌪️ Dust storm! Solar output halved.';

  @override
  String get sceneSpaceColonyEventDustStorm =>
      'A dust storm rolls in. Solar panels degraded, wind turbines boosted.';

  @override
  String get sceneSpaceColonyAlertSolarFlare =>
      '☀️ Solar flare! Generation −80%.';

  @override
  String get sceneSpaceColonyEventSolarFlare =>
      'Solar flare detected! All power generation crippled temporarily.';

  @override
  String sceneSpaceColonyAlertBuildingBreakdown(Object building) {
    return '🔧 $building broke down!';
  }

  @override
  String sceneSpaceColonyEventBuildingFailure(Object building) {
    return '$building suffered an equipment failure. Click it to repair (2 metal).';
  }

  @override
  String sceneSpaceColonyAlertColonistIll(Object colonist) {
    return '🤒 $colonist fell ill.';
  }

  @override
  String sceneSpaceColonyEventColonistIll(Object colonist) {
    return '$colonist caught an alien microbe. A medical bay would help.';
  }

  @override
  String sceneSpaceColonyEventMeteorIntercepted(Object building) {
    return 'Defense turret shot down a meteor before it could hit the $building.';
  }

  @override
  String get sceneSpaceColonyAlertMeteorIntercepted =>
      '🛡️ Meteor intercepted!';

  @override
  String sceneSpaceColonyEventMeteorDestroyed(Object building) {
    return 'A meteor destroyed the $building!';
  }

  @override
  String sceneSpaceColonyAlertMeteorDestroyed(Object building) {
    return '☄️ Meteor strike destroyed $building!';
  }

  @override
  String sceneSpaceColonyEventMeteorDamage(
    Object building,
    Object observatoryNote,
  ) {
    return 'Meteor shower damaged the $building$observatoryNote';
  }

  @override
  String get sceneSpaceColonyAlertMeteorShower => '☄️ Meteor shower!';

  @override
  String sceneSpaceColonyEventScavengedMetal(Object amount) {
    return 'Scavengers found $amount metal in old meteor debris.';
  }

  @override
  String get sceneSpaceColonyAlertCannotBuild => 'Can’t build here.';

  @override
  String get sceneSpaceColonyAlertNotEnoughMaterials => 'Not enough materials.';

  @override
  String sceneSpaceColonyEventBuildingBuilt(Object building) {
    return 'Built $building.';
  }

  @override
  String sceneSpaceColonyEventRoverData(Object science) {
    return 'Rover salvaged ancient data: +$science science.';
  }

  @override
  String sceneSpaceColonyAlertRoverData(Object science) {
    return '🛰️ Rover returned with +$science science!';
  }

  @override
  String sceneSpaceColonyEventRoverCrystal(Object amount) {
    return 'Rover recovered $amount alien crystal from the ruins.';
  }

  @override
  String sceneSpaceColonyAlertRoverCrystal(Object amount) {
    return '🛰️ Rover recovered $amount alien crystal!';
  }

  @override
  String sceneSpaceColonyEventRoverMaterials(Object glass, Object metal) {
    return 'Rover salvaged $metal metal and $glass glass.';
  }

  @override
  String get sceneSpaceColonyAlertRoverMaterials =>
      '🛰️ Rover salvaged materials!';

  @override
  String sceneSpaceColonyEventRoverTech(Object technology) {
    return 'Rover uncovered ancient knowledge — unlocked $technology for free!';
  }

  @override
  String sceneSpaceColonyAlertRoverTech(Object technology) {
    return '🛰️ Ancient tech insight: $technology unlocked!';
  }

  @override
  String get sceneSpaceColonyEventRoverScience =>
      'Rover salvaged +30 science from the ruins.';

  @override
  String get sceneSpaceColonyAlertRoverScience =>
      '🛰️ Rover returned with +30 science!';

  @override
  String get sceneSpaceColonyAlertRoverNeedsPower =>
      'Not enough power (need 15) to dispatch the rover.';

  @override
  String get sceneSpaceColonyAlertRoverChooseRuins =>
      'Choose an Ancient Ruins tile (dusty violet) for the rover.';

  @override
  String sceneSpaceColonyEventBuildingDemolished(Object building) {
    return 'Demolished $building.';
  }

  @override
  String sceneSpaceColonyEventBuildingRepaired(Object building) {
    return 'Repaired $building.';
  }

  @override
  String get sceneSpaceColonyAlertRepairNeedsMetal => 'Need 2 metal to repair.';

  @override
  String get sceneSpaceColonyAlertSendRover =>
      'Click an Ancient Ruins tile (dusty violet) to send the rover.';

  @override
  String sceneSpaceColonyEventResearchComplete(Object technology) {
    return 'Research complete: $technology!';
  }

  @override
  String get sceneSpaceColonyAlertTerraformUnlocked =>
      '🌍 Terraforming unlocked — your colony’s future is secured!';

  @override
  String get sceneSpaceColonyEventTerraformAchievement =>
      'Achievement: Terraforming research complete. Long-term survival assured.';

  @override
  String get sceneSpaceColonyEventGameSaved => 'Game saved.';

  @override
  String get sceneSpaceColonyEventGameLoaded => 'Game loaded.';

  @override
  String get sceneSpaceColonyAlertNoSave => 'No save found.';

  @override
  String get sceneSubwayCouldNotReachCoopServer =>
      'Could not reach the co-op server';

  @override
  String get sceneSubwayLostConnectionReconnecting =>
      'Lost connection to the room — reconnecting…';

  @override
  String get sceneSubwayClockAuthorityRunning =>
      'Running the clock for this room';

  @override
  String sceneSubwayTravellingToPlace(Object place) {
    return 'Travelling to $place…';
  }

  @override
  String sceneSubwayJoinedRoom(Object code) {
    return 'Joined room $code';
  }

  @override
  String sceneSubwayRoomCreatedStartBuilding(Object code) {
    return 'Room $code created — start building';
  }

  @override
  String get sceneSubwayLoadCityFirst => 'Load a city first';

  @override
  String sceneSubwayRoomCreatedShareCode(Object code) {
    return 'Room $code created — share the code or invite a contact';
  }

  @override
  String sceneSubwayInviteChatMessage(Object code) {
    return 'Join my Subway Builder co-op room — open Subway Builder, tap Co-op → Join, and enter code $code.';
  }

  @override
  String sceneSubwayFailedToSendInvite(Object error) {
    return 'Failed to send the invite message: $error';
  }

  @override
  String get sceneSubwayStillSyncing => 'Still syncing with the host…';

  @override
  String sceneSubwaySurveyingPlace(Object place) {
    return 'Surveying $place… reading OpenStreetMap land use, water and neighbourhoods';
  }

  @override
  String get sceneSubwayTracingStreets =>
      'Tracing streets and railways… fetching real rail data';

  @override
  String get sceneSubwaySurveyingRailCorridor => 'Surveying the rail corridor…';

  @override
  String get sceneSubwayAlreadyOnDraft => 'Already on this draft';

  @override
  String get sceneSubwayNativeBridgeTimedOut => 'Native bridge timed out';

  @override
  String get sceneSubwayNativeBridgeUnavailable =>
      'Native bridge not available';

  @override
  String get schoolQuizSubjectRekenen => 'Maths';

  @override
  String get schoolQuizSubjectTaalverzorging => 'Language conventions';

  @override
  String get schoolQuizSubjectLezen => 'Reading comprehension';

  @override
  String get schoolQuizSubjectEngels => 'English';

  @override
  String get schoolQuizSubjectAardrijkskunde => 'Geography';

  @override
  String get schoolQuizSubjectGeschiedenis => 'History';

  @override
  String get schoolQuizSubjectBiologie => 'Nature & technology';

  @override
  String sceneSubwayUiClockDay(String day, String weekday) {
    return 'Day $day · $weekday';
  }

  @override
  String get sceneSubwayUiRushHour => 'rush';

  @override
  String get sceneSubwayUiNight => 'night';

  @override
  String sceneSubwayUiSurfaceSlowdown(String factor) {
    return '— surface transit slowed ×$factor';
  }

  @override
  String sceneSubwayUiAchievementSummary(String done, String total) {
    return '$done / $total unlocked — real facts about the network you actually built.';
  }

  @override
  String sceneSubwayUiLoanOwed(String amount) {
    return '$amount owed';
  }

  @override
  String get sceneSubwayUiNoDebt => 'No debt';

  @override
  String sceneSubwayUiFundingSubsidy(String amount) {
    return '$amount/day operating subsidy';
  }

  @override
  String sceneSubwayUiLoanQuestion(String amount) {
    return 'Take a $amount loan?';
  }

  @override
  String get sceneSubwayUiLoanInterest =>
      'Interest accrues daily at 0.06% of the outstanding amount.';

  @override
  String sceneSubwayUiBoardings(String count) {
    return 'Boardings $count/day';
  }

  @override
  String get sceneSubwayUiSelectHint =>
      'Click a stop or line to inspect it. Drag to pan, scroll to zoom, right-drag to rotate.';

  @override
  String sceneSubwayUiRailStationHint(String mode) {
    return '$mode services only call at real stations, highlighted on the map. Click one to lease it.';
  }

  @override
  String get sceneSubwayUiMetroStationHint =>
      'Click the map to dig a metro station. Denser areas cost more.';

  @override
  String sceneSubwayUiStreetStationHint(String mode) {
    return 'Click near a street to place a $mode stop — it snaps to the road.';
  }

  @override
  String get sceneSubwayUiRailLineHint =>
      'Click real stations in order — the route follows existing tracks. Enter to finish, or click the first station again to close a loop.';

  @override
  String get sceneSubwayUiMetroLineHint =>
      'Click stations in order to bore tunnels between them. Enter to finish, or click the first station again to close a loop.';

  @override
  String get sceneSubwayUiStreetLineHint =>
      'Click stops in order — the route follows real streets. Enter to finish, or click the first stop again to close a loop.';

  @override
  String get sceneSubwayUiBulldozeHint =>
      'Click a stop to demolish it (25% refund). Click a line to remove the whole line.';

  @override
  String sceneSubwayUiExtendNextStop(String line) {
    return 'Extending $line — click the next stop. Esc to stop.';
  }

  @override
  String sceneSubwayUiExtendNewStop(String line) {
    return 'Extending $line: click a stop at either end, then the new stop.';
  }

  @override
  String sceneSubwayUiDraftCost(String count, String distance, String cost) {
    return '$count stops · $distance · $cost — Enter to build, Esc to cancel.';
  }

  @override
  String sceneSubwayUiDraftCostWater(
    String count,
    String distance,
    String cost,
  ) {
    return '$count stops · $distance · $cost (incl. underwater tunnelling) — Enter to build, Esc to cancel.';
  }

  @override
  String get sceneSubwaySeasonSpring => 'Spring';

  @override
  String get sceneSubwaySeasonSummer => 'Summer';

  @override
  String get sceneSubwaySeasonAutumn => 'Autumn';

  @override
  String get sceneSubwaySeasonWinter => 'Winter';

  @override
  String get sceneSubwayWeatherClear => 'Clear';

  @override
  String get sceneSubwayWeatherCloudy => 'Cloudy';

  @override
  String get sceneSubwayWeatherRain => 'Rain';

  @override
  String get sceneSubwayWeatherStorm => 'Storm';

  @override
  String get sceneSubwayWeatherSnow => 'Snow';

  @override
  String get sceneSubwayWeatherHeatwave => 'Heatwave';

  @override
  String get sceneSubwayWeatherFog => 'Fog';

  @override
  String get sceneSubwayDisruptionSignalFailure => 'Signal failure';

  @override
  String get sceneSubwayDisruptionTrackFault => 'Track fault';

  @override
  String get sceneSubwayDisruptionPowerOutage => 'Power outage';

  @override
  String get sceneSubwayDisruptionStaffShortage => 'Staff shortage';

  @override
  String get sceneSubwayDisruptionStalledVehicle => 'Stalled vehicle';

  @override
  String get sceneSubwayEventStadiumMatch => 'Stadium match';

  @override
  String get sceneSubwayEventArenaConcert => 'Arena concert';

  @override
  String get sceneSubwayEventStreetFestival => 'Street festival';

  @override
  String get sceneSubwayEventTradeConvention => 'Trade convention';

  @override
  String get sceneSubwayEventNightMarket => 'Night market';

  @override
  String get sceneSubwayEventMarathonFinish => 'Marathon finish';

  @override
  String get sceneSubwayEventFireworksShow => 'Fireworks show';

  @override
  String get sceneSubwayEventFootballDerby => 'Football derby';

  @override
  String sceneSubwayWeatherNews(Object weather) {
    return '$weather weather';
  }

  @override
  String sceneSubwayWeatherSlowedNews(Object weather) {
    return '$weather weather — surface transit is slowed';
  }

  @override
  String sceneSubwayDisruptionNews(
    Object disruption,
    Object line,
    Object hours,
  ) {
    return '⚠️ $disruption on $line — expect delays for ~${hours}h';
  }

  @override
  String sceneSubwayEventNews(Object event, Object station) {
    return '🎪 $event near $station tonight — expect a crowd surge!';
  }

  @override
  String sceneSubwayEventDayReport(Object event, Object station) {
    return '$event at $station';
  }

  @override
  String get sceneSubwayUiRealStation => 'real station';

  @override
  String get sceneSubwayUiNoLinesYet => 'none yet';

  @override
  String get sceneSubwayUiPlayTogether => 'Play together';

  @override
  String get sceneSubwayUiLeaveRoom => 'Leave room';

  @override
  String get sceneSubwayUiYourRooms => 'Your rooms';

  @override
  String get sceneSubwayUiYourCities => 'Your cities';

  @override
  String get sceneSubwayUiDeleteSave => 'delete save';

  @override
  String get sceneSubwayUiPlacePickerDescription =>
      'Pick any real place on Earth and build the transit it deserves';

  @override
  String get sceneSubwayUiFeaturedCities => 'Featured cities';

  @override
  String get sceneSubwayUiBackToMap => 'Back to the map';

  @override
  String get sceneSubwayUiNoPlacesFound => 'No places found.';

  @override
  String sceneAirlineTycoonClockDay(Object day) {
    return 'DAY $day';
  }

  @override
  String sceneAirlineTycoonMoveFacilityTitle(Object facility, Object rotation) {
    return 'Move $facility · $rotation°';
  }

  @override
  String sceneAirlineTycoonPlaceFacilityTitle(
    Object facility,
    Object rotation,
  ) {
    return 'Place $facility · $rotation°';
  }

  @override
  String sceneAirlineTycoonPlaceFacilityCostTitle(
    Object facility,
    Object cost,
    Object rotation,
  ) {
    return 'Place $facility · $cost · $rotation°';
  }

  @override
  String sceneAirlineTycoonConsecutiveDays(Object count) {
    return '$count days in a row';
  }

  @override
  String get sceneAirlineTycoonPlacementInstruction =>
      'Click to place · Drag to move · Right-drag to orbit';

  @override
  String sceneAirlineTycoonCashStatus(Object cash) {
    return 'Cash $cash';
  }

  @override
  String get sceneAirlineTycoonClickToConfirm => 'Click to confirm';

  @override
  String sceneAirlineTycoonSceneStartFailure(Object details) {
    return 'The 3D airport could not start. $details Update your graphics driver or Android System WebView, then reopen the airport.';
  }

  @override
  String get sceneAirlineTycoonAirportMissingAsset =>
      'A bundled scene asset is missing.';

  @override
  String get sceneAirlineTycoonAirportLabel => 'Airport';

  @override
  String get sceneAirlineTycoonZoneRubOut => 'Drag over a zone to rub it out';

  @override
  String sceneAirlineTycoonZoneMarkType(Object zone) {
    return 'Drag over the terminal floor to zone it as the $zone';
  }

  @override
  String get sceneAirlineTycoonAirfieldLabel => 'Airfield';

  @override
  String get sceneAirlineTycoonDaytimeTitle => 'Daytime';

  @override
  String get sceneAirlineTycoonNightTitle => 'Night: the airport lights are on';

  @override
  String get sceneAirlineTycoonResumeTitle => 'Resume airport (Space)';

  @override
  String get sceneAirlineTycoonPauseTitle => 'Pause airport (Space)';

  @override
  String get sceneAirlineTycoonResumeLabel => 'Resume airport';

  @override
  String get sceneAirlineTycoonPauseLabel => 'Pause airport';

  @override
  String get sceneAirlineTycoonQualityHighTitle =>
      'Quality: high (click for performance)';

  @override
  String get sceneAirlineTycoonQualityPerformanceTitle =>
      'Quality: performance (click for high)';

  @override
  String get sceneAirlineTycoonReleaseToPlace => 'Release to place';

  @override
  String get sceneAirlineTycoonOpenPlanningLabel => 'Open planning';

  @override
  String get sceneAirlineTycoonPanelBuild => 'Build';

  @override
  String get sceneAirlineTycoonPanelContracts => 'Contracts';

  @override
  String get sceneAirlineTycoonPanelPlanning => 'Planning';

  @override
  String get sceneAirlineTycoonPanelFleet => 'Fleet';

  @override
  String get sceneAirlineTycoonPanelRoutes => 'Routes';

  @override
  String get sceneAirlineTycoonPanelSchedule => 'Schedule';

  @override
  String get sceneAirlineTycoonPanelFinances => 'Finances';

  @override
  String sceneCityPlannerRidersPerDay(Object count) {
    return '$count/day';
  }

  @override
  String get sceneCityPlannerRidersLabel => 'Riders';

  @override
  String get sceneCityPlannerActiveLabel => 'Active';

  @override
  String get sceneCityPlannerPausedLabel => 'Paused';

  @override
  String get sceneCityPlannerLowFrequency => 'Low frequency';

  @override
  String get sceneCityPlannerNormalFrequency => 'Normal frequency';

  @override
  String get sceneCityPlannerHighFrequency => 'High frequency';

  @override
  String get sceneCityPlannerNoLines => 'No lines yet.';

  @override
  String sceneCityPlannerPhaseLabel(Object phase, Object name) {
    return 'Phase $phase · $name';
  }

  @override
  String get sceneAssetStudioSessionWorkspace => 'Session workspace';

  @override
  String get sceneAssetStudioDragToPan => 'Drag to pan';

  @override
  String get sceneAssetStudioPauseTurntable => 'Pause turntable';

  @override
  String get sceneAssetStudioFootprintTight => 'Footprint-tight';

  @override
  String get sceneAssetStudioBoundsAllRotations =>
      'Inside the bounds at all 4 rotations';

  @override
  String get sceneAssetStudioGroundedAtZero => 'Grounded at y = 0';

  @override
  String get sceneAssetStudioNoGeometryBelowGround =>
      'No geometry below the ground';

  @override
  String get sceneAssetStudioWithinHeightLimit => 'Within the height limit';

  @override
  String get sceneAssetStudioVertexColorsOnly => 'Vertex colors only';

  @override
  String get sceneAssetStudioNoModelTexturesOrFonts =>
      'No model textures or font assets';

  @override
  String get sceneAssetStudioLocalGeometryMergePassed =>
      'Local geometry merge passed';

  @override
  String get sceneAssetStudioStaticMeshesBakedTransforms =>
      'Static meshes with baked transforms';

  @override
  String get sceneAssetStudioGeometryChecksPassed => 'Geometry checks passed';

  @override
  String get sceneAssetStudioReviewGeometryChecks => 'Review geometry checks';

  @override
  String sceneAssetStudioHeightCheckDetail(String height, String maximum) {
    return '$height m of a $maximum m maximum';
  }

  @override
  String sceneAssetStudioHelperCallBudget(String calls) {
    return 'Under the $calls-call geometry budget';
  }

  @override
  String get sceneAssetStudioInteractiveModelAria =>
      'Interactive 3D model. Drag to orbit and scroll to zoom.';

  @override
  String get sceneAssetStudioClipboardUnavailable =>
      'Clipboard unavailable. Use Download .js instead.';

  @override
  String get sceneAssetStudioModelFunctionCopied => 'Model function copied';

  @override
  String get sceneAssetStudioWebglPreviewRequired =>
      'A WebGL preview is required to save an image.';

  @override
  String get sceneAssetStudioModelRestored =>
      'Model restored to the original specification';

  @override
  String get sceneAssetStudioLiveValidationWebglRequired =>
      'Live validation requires a WebGL-enabled browser.';

  @override
  String get sceneAssetStudioAllGeometryChecksPassed =>
      'All 6 geometry checks passed';

  @override
  String get sceneAssetStudioGeometryCheckNeedsAttention =>
      'A geometry check needs attention';

  @override
  String sceneAssetStudioFileDownloaded(String filename) {
    return '$filename downloaded';
  }

  @override
  String sceneAssetStudioLoadedAsset(String name) {
    return 'Loaded $name';
  }

  @override
  String sceneAssetStudioPreviewSaved(String filename) {
    return 'Preview saved as $filename';
  }

  @override
  String get sceneAssetStudioCatalogJewelryStoreName => 'Jewelry Store';

  @override
  String get sceneAssetStudioCatalogJewelryStoreDescription =>
      'Premium airport boutique selling jewelry, watches and luxury accessories.';

  @override
  String get sceneAssetStudioCatalogJewelryStoreKeywords =>
      'Gilded vitrines, royal necklace bust, timepiece gallery & consultation desk';

  @override
  String get sceneAssetStudioCategoryRetail => 'retail';

  @override
  String get sceneAssetStudioCatalogOneWayCustomsName => 'One-Way Customs';

  @override
  String get sceneAssetStudioCatalogOneWayCustomsDescription =>
      'One-way customs control where arriving passengers are checked before continuing.';

  @override
  String get sceneAssetStudioCatalogOneWayCustomsKeywords =>
      'Floor directional arrows, glass lane, officer & clearance gate';

  @override
  String get sceneAssetStudioCategorySecurity => 'security';

  @override
  String get sceneAssetStudioCatalogCoffeeToGoName => 'Coffee To-Go';

  @override
  String get sceneAssetStudioCatalogCoffeeToGoDescription =>
      'Quick takeaway coffee, hot drinks and snacks for passengers on the move.';

  @override
  String get sceneAssetStudioCatalogCoffeeToGoKeywords =>
      'Three-wall kiosk shell, espresso machine, barista & blade sign';

  @override
  String get sceneAssetStudioCategoryFood => 'food';

  @override
  String get sceneAssetStudioCatalogAirportArcadeName => 'Arcade';

  @override
  String get sceneAssetStudioCatalogAirportArcadeDescription =>
      'An entertainment arcade where passengers can play games while waiting for their flights.';

  @override
  String get sceneAssetStudioCatalogAirportArcadeKeywords =>
      'Neon marquee, 5 retro cabinets, twin racer cockpits, air hockey & dance stage';

  @override
  String get sceneAssetStudioCategoryEntertainment => 'entertainment';

  @override
  String get sceneAssetStudioCatalogAirportCasinoName => 'Casino Lounge';

  @override
  String get sceneAssetStudioCatalogAirportCasinoDescription =>
      'A glamorous airside casino with slots, gaming tables and a cocktail bar for long layovers.';

  @override
  String get sceneAssetStudioCatalogAirportCasinoKeywords =>
      'Gold columns, slot banks, card tables & a cocktail bar';

  @override
  String get sceneAssetStudioCatalogFlowerShopName => 'Flower Shop';

  @override
  String get sceneAssetStudioCatalogFlowerShopDescription =>
      'Airport florist selling fresh flowers, bouquets, plants and small gifts.';

  @override
  String get sceneAssetStudioCatalogFlowerShopKeywords =>
      'Pergola entrance, flower wall, bouquet table & cooled cabinet';

  @override
  String get sceneAssetStudioCatalogCustomsCheckerName => 'Customs Check';

  @override
  String get sceneAssetStudioCatalogCustomsCheckerDescription =>
      'Customs checkpoint for inspecting arriving passengers and their baggage.';

  @override
  String get sceneAssetStudioCatalogCustomsCheckerKeywords =>
      'Officer check, manual baggage table, controlled customs lane';

  @override
  String get sceneAssetStudioCatalogFoodCartName => 'Food Cart';

  @override
  String get sceneAssetStudioCatalogFoodCartDescription =>
      'A small staffed cart selling quick food, snacks and drinks.';

  @override
  String get sceneAssetStudioCatalogFoodCartKeywords =>
      'Wheeled cart, glass pastry case, canopy & coffee station';

  @override
  String get sceneAssetStudioCatalogFlightInfoPanelName => 'Flight Info Panel';

  @override
  String get sceneAssetStudioCatalogFlightInfoPanelDescription =>
      'Compact terminal display showing upcoming flights and gates.';

  @override
  String get sceneAssetStudioCatalogFlightInfoPanelKeywords =>
      'Single portrait screen, slim pedestal, five flight rows';

  @override
  String get sceneAssetStudioCategoryPassenger => 'passenger';

  @override
  String get sceneAssetStudioCatalogFlightInformationBoardName =>
      'Flight Information Board';

  @override
  String get sceneAssetStudioCatalogFlightInformationBoardDescription =>
      'Displays upcoming flights, departure times, gates and current status.';

  @override
  String get sceneAssetStudioCatalogFlightInformationBoardKeywords =>
      'Double-sided FIDS, flight rows, status colors, twin clock';

  @override
  String get sceneAssetStudioCatalogTrashBinsName => 'Trash Bins';

  @override
  String get sceneAssetStudioCatalogTrashBinsDescription =>
      'Waste and recycling bins for keeping the terminal clean.';

  @override
  String get sceneAssetStudioCatalogTrashBinsKeywords =>
      'Three-stream station, distinct chute mouths, color-coded bands';

  @override
  String get sceneAssetStudioCategoryInterior => 'interior';

  @override
  String get sceneAssetStudioCatalogInformationDeskName => 'Information Desk';

  @override
  String get sceneAssetStudioCatalogInformationDeskDescription =>
      'Airport information center with staffed assistance and self-service information.';

  @override
  String get sceneAssetStudioCatalogInformationDeskKeywords =>
      'Two staffed positions, two employees, separate self-service screen';

  @override
  String get sceneAssetStudioCatalogAirportRestaurantName => 'Restaurant';

  @override
  String get sceneAssetStudioCatalogAirportRestaurantDescription =>
      'Full-service airport restaurant offering seated dining and freshly prepared meals.';

  @override
  String get sceneAssetStudioCatalogAirportRestaurantKeywords =>
      'Hosted entrance, varied dining, bar & open kitchen';

  @override
  String get sceneAssetStudioCatalogPerfumeCornerShopName => 'Perfume Shop';

  @override
  String get sceneAssetStudioCatalogPerfumeCornerShopDescription =>
      'Luxury duty-free fragrances and perfume in a premium corner store.';

  @override
  String get sceneAssetStudioCatalogPerfumeCornerShopKeywords =>
      'L-shaped corner frontage, window vignettes, tester trays';

  @override
  String get sceneAssetStudioCatalogDutyFreeFoodDrinksName =>
      'Duty Free Food & Drinks';

  @override
  String get sceneAssetStudioCatalogDutyFreeFoodDrinksDescription =>
      'Airport duty-free shop selling food, snacks and drinks.';

  @override
  String get sceneAssetStudioCatalogDutyFreeFoodDrinksKeywords =>
      'Open storefront, stocked aisles, chilled drinks wall';

  @override
  String get sceneAssetStudioCatalogCheckoutCounterName => 'Checkout';

  @override
  String get sceneAssetStudioCatalogCheckoutCounterDescription =>
      'Staffed retail checkout where passengers pay for their purchases.';

  @override
  String get sceneAssetStudioCatalogCheckoutCounterKeywords =>
      'Staffed till, card terminal, bagging bay & short queue';

  @override
  String get sceneAssetStudioCatalogCheckInCounterName => 'Check-in Counter';

  @override
  String get sceneAssetStudioCatalogCheckInCounterDescription =>
      'Staffed airline check-in counter for passengers and checked baggage.';

  @override
  String get sceneAssetStudioCatalogCheckInCounterKeywords =>
      'Staffed desk, baggage belt & scale, guided queue';

  @override
  String get sceneAssetStudioCatalogVipLoungeName => 'VIP Lounge';

  @override
  String get sceneAssetStudioCatalogVipLoungeDescription =>
      'Exclusive first-class airport lounge with luxury seating and refreshments.';

  @override
  String get sceneAssetStudioCatalogVipLoungeKeywords =>
      'Smoked walnut, velvet Chesterfields, cocktail bar & departures screen';

  @override
  String get sceneAssetStudioCatalogCozyClothingName => 'Noir & Co. Atelier';

  @override
  String get sceneAssetStudioCatalogCozyClothingDescription =>
      'Dark, elegant luxury fashion boutique for departing passengers.';

  @override
  String get sceneAssetStudioCatalogCozyClothingKeywords =>
      'Espresso timber, burnished brass, velvet salon lounge';

  @override
  String get sceneAssetStudioCatalogDutyFreeClothingName =>
      'Duty Free Clothing';

  @override
  String get sceneAssetStudioCatalogDutyFreeClothingDescription =>
      'Airport fashion and clothing store for departing passengers.';

  @override
  String get sceneAssetStudioCatalogDutyFreeClothingKeywords =>
      'Walk-in storefront, racks and mannequins, checkout';

  @override
  String get sceneAssetStudioCatalogBaggageCarouselName => 'Baggage carousel';

  @override
  String get sceneAssetStudioCatalogBaggageCarouselDescription =>
      'Collect arriving passenger baggage from the reclaim carousel.';

  @override
  String get sceneAssetStudioCatalogBaggageCarouselKeywords =>
      'Stadium belt, metal trough edge, claim pylon';

  @override
  String get sceneAssetStudioCatalogWaitingSeatsName => 'Waiting area seats';

  @override
  String get sceneAssetStudioCatalogWaitingSeatsDescription =>
      'Passenger seating for airport waiting areas and departure gates.';

  @override
  String get sceneAssetStudioCatalogWaitingSeatsKeywords =>
      'Four seats, shared beam, five armrests';

  @override
  String get sceneAssetStudioCatalogVendingMachineName => 'Vending machine';

  @override
  String get sceneAssetStudioCatalogVendingMachineDescription =>
      'Snacks and drinks for passengers.';

  @override
  String get sceneAssetStudioCatalogVendingMachineKeywords =>
      'Glass display, three stocked shelves, interface column';

  @override
  String get sceneAssetStudioCatalogTicketMachineName => 'Ticket machine';

  @override
  String get sceneAssetStudioCatalogTicketMachineDescription =>
      'Self-service ticketing for the terminal.';

  @override
  String get sceneAssetStudioCatalogTicketMachineKeywords =>
      'Slanted screen, card reader, receipt slot';

  @override
  String get sceneAssetStudioColorWarmIvory => 'Warm ivory';

  @override
  String get sceneAssetStudioColorDarkLuxury => 'Dark luxury';

  @override
  String get sceneAssetStudioColorChampagneGold => 'Champagne gold';

  @override
  String get sceneAssetStudioColorVelvetEmerald => 'Velvet emerald';

  @override
  String get sceneAssetStudioColorVelvetBurgundy => 'Velvet burgundy';

  @override
  String get sceneAssetStudioColorJewelryCoolLight => 'Jewelry cool light';

  @override
  String get sceneAssetStudioColorBody => 'Body';

  @override
  String get sceneAssetStudioColorTealAccent => 'Teal accent';

  @override
  String get sceneAssetStudioColorScreen => 'Screen';

  @override
  String get sceneAssetStudioColorEmission => 'Emission';

  @override
  String get sceneAssetStudioColorBase => 'Base';

  @override
  String get sceneAssetStudioColorSafetyStrip => 'Safety strip';

  @override
  String get sceneAssetStudioColorSmokedWalnut => 'Smoked walnut';

  @override
  String get sceneAssetStudioColorAcousticCharcoal => 'Acoustic charcoal';

  @override
  String get sceneAssetStudioColorBurnishedBrass => 'Burnished brass';

  @override
  String get sceneAssetStudioColorBordeauxVelvet => 'Bordeaux velvet';

  @override
  String get sceneAssetStudioColorCognacLeather => 'Cognac leather';

  @override
  String get sceneAssetStudioColorAmberDownlight => 'Amber downlight';

  @override
  String get sceneAssetStudioColorKioskIvory => 'Kiosk ivory';

  @override
  String get sceneAssetStudioColorRoastWood => 'Roast wood';

  @override
  String get sceneAssetStudioColorEspresso => 'Espresso';

  @override
  String get sceneAssetStudioColorBeanBrown => 'Bean brown';

  @override
  String get sceneAssetStudioColorApronGreen => 'Apron green';

  @override
  String get sceneAssetStudioColorWarmLight => 'Warm light';

  @override
  String get sceneAssetStudioColorArcadeDark => 'Arcade dark';

  @override
  String get sceneAssetStudioColorNeonPurple => 'Neon purple';

  @override
  String get sceneAssetStudioColorLaserPink => 'Laser pink';

  @override
  String get sceneAssetStudioColorCyberBlue => 'Cyber blue';

  @override
  String get sceneAssetStudioColorNeonGlow => 'Neon glow';

  @override
  String get sceneAssetStudioColorSpeedYellow => 'Speed yellow';

  @override
  String get sceneAssetStudioColorCasinoCharcoal => 'Casino charcoal';

  @override
  String get sceneAssetStudioColorDeepRed => 'Deep red';

  @override
  String get sceneAssetStudioColorCasinoGold => 'Casino gold';

  @override
  String get sceneAssetStudioColorTableGreen => 'Table green';

  @override
  String get sceneAssetStudioColorMidnightBlue => 'Midnight blue';

  @override
  String get sceneAssetStudioColorWarmGlow => 'Warm glow';

  @override
  String sceneAssetStudioColorCopied(String color) {
    return '$color color copied';
  }

  @override
  String sceneAssetStudioSourceCodeAria(String filename) {
    return '$filename source code';
  }

  @override
  String sceneAssetStudioCatalogFootprint(String width, String depth) {
    return 'Catalog footprint: $width x $depth m. The model accepts your donor\'s w and d parameters.';
  }
}
