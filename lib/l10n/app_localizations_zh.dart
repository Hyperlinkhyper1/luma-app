// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class LZh extends L {
  LZh([String locale = 'zh']) : super(locale);

  @override
  String get trayOpen => '打开 luma';

  @override
  String get trayQuit => '退出 luma';

  @override
  String get navHome => '首页';

  @override
  String get navFileConverter => '文件转换器';

  @override
  String get navFinance => '财务';

  @override
  String get navPasswordManager => '密码管理';

  @override
  String get navNotes => '笔记';

  @override
  String get navAssistant => '助手';

  @override
  String get navPlugins => '插件';

  @override
  String get navSettings => '设置';

  @override
  String get navAccount => '账户';

  @override
  String get navConvert => '转换';

  @override
  String get navVault => '保险库';

  @override
  String get navMore => '更多';

  @override
  String get shellPluginUnavailable => '插件不可用';

  @override
  String get shellStorageLimitMsg => '您已达到存储上限。在释放空间之前，新数据不会被保存或同步。';

  @override
  String get shellStorageManage => '管理';

  @override
  String get shellStorageDismiss => '关闭';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsAppearanceSub => '让 luma 属于你。';

  @override
  String get settingsTheme => '主题';

  @override
  String get settingsAccentColor => '强调色';

  @override
  String get settingsThemeStyle => '主题风格';

  @override
  String get settingsThemeStyleDefault => '默认';

  @override
  String get settingsThemeStyleDefaultSub => 'luma 的原本样子——干净的表面和你选择的强调色。';

  @override
  String get settingsThemeStyleCoffee => '咖啡';

  @override
  String get settingsThemeStyleCoffeeSub => '浓缩与奶油、更柔和的形状，还有在背后缓缓飘过的咖啡豆。';

  @override
  String get settingsThemeStyleLocked => 'Orbit 或 Nova';

  @override
  String get settingsThemeStyleUpgrade => '咖啡主题属于 Orbit 和 Nova。升级即可享用。';

  @override
  String get settingsAccentCoffeeNote => '咖啡主题自带配色，启用时强调色选择器会暂停。';

  @override
  String get settingsGeneral => '通用';

  @override
  String get settingsGeneralSub => '应用的运行方式。';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsOpenOnLaunch => '启动时打开';

  @override
  String get settingsHideAmounts => '在首页隐藏金额';

  @override
  String get settingsHideAmountsSub => '在仪表盘上遮掩余额，防止旁人窥视。';

  @override
  String get settingsLockPasswords => '锁定密码';

  @override
  String get settingsLockPasswordsSub => '需要 8 位 PIN 码才能查看或编辑已保存的凭据。';

  @override
  String get settingsAmericanGpa => '美式 GPA 制度';

  @override
  String get settingsAmericanGpaSub => '在“学校”插件中使用美国 4.0 GPA 制度，而不是荷兰 1-10 分制。';

  @override
  String get settingsAiAssistant => 'AI 助手';

  @override
  String get settingsAiAssistantSub => '连接你自己的 Anthropic API 密钥。';

  @override
  String get settingsAbout => '关于';

  @override
  String get settingsResetDefaults => '恢复默认设置';

  @override
  String get settingsResetTitle => '重置设置？';

  @override
  String get settingsResetContent => '这将把主题、强调色和其他偏好恢复为默认值。';

  @override
  String get settingsResetCancel => '取消';

  @override
  String get settingsResetConfirm => '重置';

  @override
  String get settingsCheckUpdates => '检查更新';

  @override
  String get settingsOpenSourceLicenses => '开源许可';

  @override
  String get settingsSystem => '跟随系统';

  @override
  String get settingsLight => '浅色';

  @override
  String get settingsDark => '深色';

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
  String get langSystemDefault => '跟随系统';

  @override
  String get homeGreetingMorning => '早上好';

  @override
  String get homeGreetingAfternoon => '下午好';

  @override
  String get homeGreetingEvening => '晚上好';

  @override
  String get homeNetWorth => '净资产';

  @override
  String get homeAtAGlance => '概览';

  @override
  String get homeJumpBackIn => '继续使用';

  @override
  String get homeRecentActivity => '近期活动';

  @override
  String get homeIncomeMonth => '本月收入';

  @override
  String get homeSpentMonth => '本月支出';

  @override
  String get homeInPots => '储蓄罐中';

  @override
  String get homeInvestments => '投资';

  @override
  String get homeAskAssistant => '询问助手';

  @override
  String get homeAskAssistantSub => '与 AI 助手对话';

  @override
  String get homeFinance => '财务';

  @override
  String get homeFinanceSub => '预算、储蓄罐与股票';

  @override
  String get homeFileConverter => '文件转换器';

  @override
  String get homeFileConverterSub => '转换图片和文件';

  @override
  String get homeSettings => '设置';

  @override
  String get homeSettingsSub => '主题、颜色等';

  @override
  String get homeNoTransactions => '暂无内容 — 在财务标签页添加一笔交易，它会显示在这里。';

  @override
  String get homeIncome => '收入';

  @override
  String get homeExpense => '支出';

  @override
  String get homeAllocation => '分配';

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
  String get pinEnterNew => '输入新的 8 位 PIN 码';

  @override
  String get pinVerify => '确认新 PIN 码';

  @override
  String get pinEnterDisable => '输入 PIN 码以禁用';

  @override
  String get pinNotMatch => 'PIN 码不匹配。';

  @override
  String get pinIncorrect => 'PIN 码不正确。';

  @override
  String aboutVersionRelease(String version) {
    return '版本 $version · 简洁的本地工具';
  }

  @override
  String get aboutVersionDev => '开发版 · 简洁的本地工具';

  @override
  String get petSearchHint => '搜索插件和页面';

  @override
  String get petMoodIdle => '要打开什么呢？';

  @override
  String get petMoodCurious => '唔，我找找…';

  @override
  String get petMoodHappy => '好痒呀。';

  @override
  String get petMoodDelighted => '今天最开心！';

  @override
  String get petMoodSleepy => '还没睡？我也是。';

  @override
  String get petNoResults => '没有这个名字';

  @override
  String get petNoResultsHint => '试试更短的词，或者其中一部分。';

  @override
  String get petSectionJumpTo => '快速前往';

  @override
  String get petSectionResults => '搜索结果';

  @override
  String get petKindPlugin => '插件';

  @override
  String get petKindPage => '页面';

  @override
  String get petHintMove => '选择';

  @override
  String get petHintOpen => '打开';

  @override
  String get petHintClose => '关闭';

  @override
  String get petClose => '关闭';

  @override
  String get petPatsTooltip => '摸过的次数';

  @override
  String petPatLabel(String name) {
    return '摸摸 $name';
  }

  @override
  String get petSettingsTitle => 'luma 宠物';

  @override
  String get petSettingsSubtitle => '在任何地方按下快捷键唤出宠物，输入即可跳到任意页面或插件。';

  @override
  String get petSettingsHotkey => '随时唤出';

  @override
  String get petSettingsHotkeyTaken => '快捷键已被其他应用占用，只有 luma 在前台时才有效。请在下方换一个。';

  @override
  String get petSettingsRebind => '更改';

  @override
  String get petSettingsRebindTitle => '按下新的快捷键';

  @override
  String get petSettingsRebindSave => '使用';

  @override
  String get petSettingsName => '名字';

  @override
  String get petSettingsSummon => '立即打开宠物';

  @override
  String get petSettingsSummonHint => '不需要快捷键，立刻弹出面板。';

  @override
  String get monthJan => '1月';

  @override
  String get monthFeb => '2月';

  @override
  String get monthMar => '3月';

  @override
  String get monthApr => '4月';

  @override
  String get monthMay => '5月';

  @override
  String get monthJun => '6月';

  @override
  String get monthJul => '7月';

  @override
  String get monthAug => '8月';

  @override
  String get monthSep => '9月';

  @override
  String get monthOct => '10月';

  @override
  String get monthNov => '11月';

  @override
  String get monthDec => '12月';

  @override
  String get weekdayMon => '星期一';

  @override
  String get weekdayTue => '星期二';

  @override
  String get weekdayWed => '星期三';

  @override
  String get weekdayThu => '星期四';

  @override
  String get weekdayFri => '星期五';

  @override
  String get weekdaySat => '星期六';

  @override
  String get weekdaySun => '星期日';

  @override
  String planSuffix(String name) {
    return '$name 套餐';
  }

  @override
  String get assistantNewChat => '新对话';

  @override
  String get assistantSearchChats => '搜索对话';

  @override
  String get assistantStarred => '已加星标';

  @override
  String get assistantRecents => '最近';

  @override
  String get assistantNoChats => '还没有对话';

  @override
  String get assistantNoMatches => '没有匹配的对话';

  @override
  String get assistantGreetingMorning => '早上好';

  @override
  String get assistantGreetingAfternoon => '下午好';

  @override
  String get assistantGreetingEvening => '晚上好';

  @override
  String assistantGreetingMorningName(String name) {
    return '早上好，$name';
  }

  @override
  String assistantGreetingAfternoonName(String name) {
    return '下午好，$name';
  }

  @override
  String assistantGreetingEveningName(String name) {
    return '晚上好，$name';
  }

  @override
  String get assistantHowCanIHelp => '今天有什么可以帮你？';

  @override
  String get assistantReplyHint => '回复 luma…';

  @override
  String get assistantOutOfMessages => '你的消息次数暂时用完了';

  @override
  String get assistantCopy => '复制';

  @override
  String get assistantCopied => '已复制';

  @override
  String get assistantStar => '加星标';

  @override
  String get assistantUnstar => '取消星标';

  @override
  String get assistantRename => '重命名';

  @override
  String get assistantDelete => '删除';

  @override
  String get assistantSuggestPlugin => '查找插件';

  @override
  String get assistantSuggestQr => '生成二维码';

  @override
  String get assistantSuggestWeek => '规划我的一周';

  @override
  String get assistantSuggestNote => '写一条笔记';

  @override
  String get assistantSuggestPluginPrompt => '哪个 luma 插件能帮我';

  @override
  String get assistantSuggestQrPrompt => '为以下内容生成二维码：';

  @override
  String get assistantSuggestWeekPrompt => '我这周的日程有哪些？';

  @override
  String get assistantSuggestNotePrompt => '保存一条笔记，内容是：';

  @override
  String get assistantToggleSidebar => '切换侧边栏';

  @override
  String get assistantChats => '对话';

  @override
  String get assistantUsage => '用量';

  @override
  String get assistantContextWindow => '上下文窗口';

  @override
  String get assistantUsageLimits => '用量限制';

  @override
  String get assistantFiveHourLimit => '5 小时限额';

  @override
  String get assistantWeeklyLimit => '每周';

  @override
  String get assistantDailyMessages => '今天';

  @override
  String assistantMessagesOf(int used, int limit) {
    return '已用 $used / $limit 条消息';
  }

  @override
  String get assistantLastReply => '上一条回复';

  @override
  String assistantTokensInOut(String input, String output) {
    return '输入 $input · 输出 $output';
  }

  @override
  String get assistantNoLimits => '在本设备上运行 — 无用量限制';

  @override
  String get assistantUsageUnavailable => '无法获取用量 — 请检查网络连接';

  @override
  String get assistantDetailedBreakdown => '查看详细明细';

  @override
  String get assistantNoRepliesYet => '此对话还没有回复';

  @override
  String get assistantMenuUsage => '用量';

  @override
  String get assistantMenuSettings => '设置';

  @override
  String get assistantMenuAgents => '智能体';

  @override
  String get assistantYourUsage => '你的用量';

  @override
  String get assistantUsageHeadlinePlenty => '还有充足额度，尽情聊吧。';

  @override
  String get assistantUsageHeadlineOnTrack => '进度正常，还有余量。';

  @override
  String get assistantUsageHeadlineClose => '注意：你快要达到上限了。';

  @override
  String get assistantUsageHeadlineOut => '你已达到上限，时间窗口滚动后会重新释放。';

  @override
  String get assistantUsageLumaAi => 'Luma AI';

  @override
  String get assistantUsageLumaAiSubtitle =>
      '通过你的 luma 账户使用 Aurora、Nebula 和 Pulsar';

  @override
  String get assistantUsageCurrentSession => '当前会话';

  @override
  String get assistantUsageRollingFiveHours => '滚动 5 小时窗口';

  @override
  String get assistantUsageThisWeek => '本周';

  @override
  String get assistantUsageRollingWeek => '滚动 7 天窗口';

  @override
  String get assistantUsageLumaAssistant => 'Luma Assistant';

  @override
  String get assistantUsageLumaAssistantSubtitle => '设备端 Qwen 模型';

  @override
  String get assistantUsageWebSearch => '网页搜索';

  @override
  String assistantUsageCountOf(int used, int limit) {
    return '已用 $used / $limit';
  }

  @override
  String assistantUsagePercentUsed(int percent) {
    return '已用 $percent%';
  }

  @override
  String get assistantUsageLumaSupport => 'Luma Support';

  @override
  String get assistantUsageResetsDaily => '午夜重置';

  @override
  String get assistantUsageApiKeys => '你的 API 密钥';

  @override
  String get assistantUsageApiKeysSubtitle => '使用自己的 API 密钥；服务商的额度和限制仍然适用';

  @override
  String get assistantUsageUnlimited => 'Luma 内不限量';

  @override
  String get assistantUsageByModel => '按模型统计的消息';

  @override
  String get assistantUsageByModelSubtitle => '此设备上各模型成功发送的消息数。';

  @override
  String assistantUsageMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条消息',
    );
    return '$_temp0';
  }

  @override
  String get assistantUsageNoMessages => '还没有消息';

  @override
  String get assistantUsageStorage => '存储';

  @override
  String get assistantUsageMemoryStorage => '助手记忆';

  @override
  String get assistantUsageMemoryStorageCaption => '在所有套餐中随账户同步，并计入服务器存储';

  @override
  String get assistantUsageServerStorage => '服务器存储';

  @override
  String assistantUsageStorageOf(String used, String quota) {
    return '$used / $quota';
  }

  @override
  String get assistantSettingsChat => '聊天';

  @override
  String get assistantSettingsMemory => '记忆';

  @override
  String get assistantSettingsUser => '用户';

  @override
  String get assistantSettingsLanguage => '回复语言';

  @override
  String get assistantSettingsLanguageHint => '助手回复你时使用的语言。';

  @override
  String get assistantSettingsLanguageAuto => '跟随我的语言';

  @override
  String get assistantSettingsFont => '字体';

  @override
  String get assistantSettingsFontHint => '助手回复所用的字体。';

  @override
  String get assistantFontSerif => '衬线';

  @override
  String get assistantFontSans => '无衬线';

  @override
  String get assistantFontMono => '等宽';

  @override
  String get assistantSettingsTextSize => '文字大小';

  @override
  String get assistantSettingsTextSizeHint => '对话文字的大小。';

  @override
  String get assistantTextSmall => '小';

  @override
  String get assistantTextMedium => '中';

  @override
  String get assistantTextLarge => '大';

  @override
  String get assistantSettingsPreview => '预览';

  @override
  String get assistantSettingsPreviewText =>
      '回复会像这样显示。**粗体**、*斜体* 和 `代码` 都会跟随你的选择。';

  @override
  String get assistantMemoryUse => '使用记忆';

  @override
  String get assistantMemoryUseHint => '让助手在不同对话之间记住关于你的信息，并在有帮助时使用。';

  @override
  String assistantMemorySyncNote(String size) {
    return '在所有套餐中同步到你的账户 · 占用 $size 服务器存储';
  }

  @override
  String get assistantMemoryAdd => '添加记忆';

  @override
  String get assistantMemoryEdit => '编辑记忆';

  @override
  String get assistantMemoryEmpty => '还没有任何记忆';

  @override
  String get assistantMemoryEmptyHint => '在对话中向助手介绍你自己，或在这里添加记忆。';

  @override
  String get assistantMemoryYou => '你';

  @override
  String get assistantMemoryTopics => '主题';

  @override
  String get assistantMemoryAreas => '领域';

  @override
  String assistantMemoryUpdated(String date) {
    return '更新于 $date';
  }

  @override
  String get assistantMemoryClear => '删除所有记忆';

  @override
  String get assistantMemoryClearTitle => '删除所有记忆？';

  @override
  String get assistantMemoryClearBody => '助手会在所有设备上忘记它记住的一切。“用户”标签中的个人资料会保留。';

  @override
  String get assistantMemoryTitle => '标题';

  @override
  String get assistantMemoryTitleHint => '例如：硬件';

  @override
  String get assistantMemoryDescription => '摘要';

  @override
  String get assistantMemoryDescriptionHint => '一行，显示在列表中';

  @override
  String get assistantMemoryBody => '要记住的内容';

  @override
  String get assistantMemoryBodyHint => '每行一条';

  @override
  String get assistantProfileCallMe => '助手应该怎么称呼你？';

  @override
  String get assistantProfileCallMeHint => '你的名字或昵称';

  @override
  String get assistantProfileOccupation => '你是做什么的？';

  @override
  String get assistantProfileOccupationHint => '例如：学生、独立游戏开发者';

  @override
  String get assistantProfileSummary => '关于你';

  @override
  String get assistantProfileSummaryHint => '助手应始终了解的几句话';

  @override
  String get assistantProfileInstructions => '助手应该如何回复？';

  @override
  String get assistantProfileInstructionsHint => '例如：简短一些，逐步解释代码';

  @override
  String get assistantProfileSave => '保存';

  @override
  String get assistantProfileSaved => '已保存';

  @override
  String get assistantAgentsComingSoon => '即将推出';

  @override
  String get assistantAgentsSubtitle => '你在 AI Usage 插件中创建的智能体。即将支持从助手中运行它们。';

  @override
  String get assistantAgentsEmpty => '还没有智能体';

  @override
  String get assistantAgentsEmptyHint => '在 AI Usage 插件的“智能体”标签中创建一个，它就会显示在这里。';

  @override
  String get assistantAgentsOpenBuilder => '打开 AI Usage';

  @override
  String get assistantAgentsNoDescription => '无描述';

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
}
