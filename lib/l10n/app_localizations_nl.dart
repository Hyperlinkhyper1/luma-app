// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class LNl extends L {
  LNl([String locale = 'nl']) : super(locale);

  @override
  String get navHome => 'Start';

  @override
  String get navFileConverter => 'Bestanden omzetten';

  @override
  String get navFinance => 'Geld';

  @override
  String get navPasswordManager => 'Wachtwoorden';

  @override
  String get navNotes => 'Notities';

  @override
  String get navAssistant => 'Assistent';

  @override
  String get navPlugins => 'Plugins';

  @override
  String get navSettings => 'Instellingen';

  @override
  String get navAccount => 'Account';

  @override
  String get navConvert => 'Omzetten';

  @override
  String get navVault => 'Kluis';

  @override
  String get navMore => 'Meer';

  @override
  String get shellPluginUnavailable => 'Deze plugin is er even niet';

  @override
  String get shellStorageLimitMsg =>
      'Je ruimte is op. Ruim wat op en we gaan weer opslaan en syncen.';

  @override
  String get shellStorageManage => 'Opruimen';

  @override
  String get shellStorageDismiss => 'Later';

  @override
  String get settingsAppearance => 'Uiterlijk';

  @override
  String get settingsAppearanceSub => 'Maak luma lekker van jou.';

  @override
  String get settingsTheme => 'Thema';

  @override
  String get settingsAccentColor => 'Kleur';

  @override
  String get settingsThemeStyle => 'Themastijl';

  @override
  String get settingsThemeStyleDefault => 'Standaard';

  @override
  String get settingsThemeStyleDefaultSub =>
      'Gewoon luma zoals je hem kent — simpel, in jouw kleur.';

  @override
  String get settingsThemeStyleCoffee => 'Koffie';

  @override
  String get settingsThemeStyleCoffeeSub =>
      'Warme bruintinten, zachte hoekjes, koffieboontjes die rondzweven.';

  @override
  String get settingsThemeStyleLocked => 'Orbit of Nova';

  @override
  String get settingsThemeStyleUpgrade =>
      'Koffie zit bij Orbit en Nova. Neem een van die en je kunt hem aanzetten.';

  @override
  String get settingsAccentCoffeeNote =>
      'Koffie heeft z\'n eigen kleuren, dus je kunt even geen kleur kiezen.';

  @override
  String get settingsGeneral => 'Algemeen';

  @override
  String get settingsGeneralSub =>
      'Kleine dingetjes die bepalen hoe de app doet.';

  @override
  String get settingsLanguage => 'Taal';

  @override
  String get settingsOpenOnLaunch => 'Openen bij opstarten';

  @override
  String get settingsHideAmounts => 'Geld verbergen op Start';

  @override
  String get settingsHideAmountsSub =>
      'Verberg je geld op Start, voor als iemand meekijkt.';

  @override
  String get settingsLockPasswords => 'Wachtwoorden op slot';

  @override
  String get settingsLockPasswordsSub =>
      'Vraag om een PIN van 8 cijfers voordat je je opgeslagen logins ziet.';

  @override
  String get settingsAmericanGpa => 'Amerikaanse cijfers';

  @override
  String get settingsAmericanGpaSub =>
      'Gebruik Amerikaanse 4.0-cijfers in School, in plaats van Nederlandse 1-tot-10\'tjes.';

  @override
  String get settingsAiAssistant => 'AI-assistent';

  @override
  String get settingsAiAssistantSub =>
      'Stop je eigen Anthropic-sleutel erin en kletsen maar.';

  @override
  String get settingsAbout => 'Over';

  @override
  String get settingsResetDefaults => 'Alles terugzetten';

  @override
  String get settingsResetTitle => 'Opnieuw beginnen?';

  @override
  String get settingsResetContent =>
      'Dit zet je thema, kleur en andere kleine keuzes weer terug naar het begin.';

  @override
  String get settingsResetCancel => 'Laat maar';

  @override
  String get settingsResetConfirm => 'Ja, resetten';

  @override
  String get settingsCheckUpdates => 'Zoeken naar updates';

  @override
  String get settingsOpenSourceLicenses => 'Open source licenties';

  @override
  String get settingsSystem => 'Systeem';

  @override
  String get settingsLight => 'Licht';

  @override
  String get settingsDark => 'Donker';

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
  String get langSystemDefault => 'Systeem';

  @override
  String get homeGreetingMorning => 'Goedemorgen';

  @override
  String get homeGreetingAfternoon => 'Hé, hallo';

  @override
  String get homeGreetingEvening => 'Goedenavond';

  @override
  String get homeNetWorth => 'Alles bij elkaar';

  @override
  String get homeAtAGlance => 'Hoe het ervoor staat';

  @override
  String get homeJumpBackIn => 'Ga verder waar je was';

  @override
  String get homeRecentActivity => 'Waar je mee bezig was';

  @override
  String get homeIncomeMonth => 'Binnen deze maand';

  @override
  String get homeSpentMonth => 'Uit deze maand';

  @override
  String get homeInPots => 'Apart gezet in potjes';

  @override
  String get homeInvestments => 'Beleggingen';

  @override
  String get homeAskAssistant => 'Vraag de assistent';

  @override
  String get homeAskAssistantSub => 'Klets even, vraag wat je wilt';

  @override
  String get homeFinance => 'Geld';

  @override
  String get homeFinanceSub => 'Je geld, potjes & aandelen';

  @override
  String get homeFileConverter => 'Bestanden omzetten';

  @override
  String get homeFileConverterSub => 'Klus met plaatjes & bestanden';

  @override
  String get homeSettings => 'Instellingen';

  @override
  String get homeSettingsSub => 'Kleuren, thema & spul';

  @override
  String get homeNoTransactions =>
      'Nog rustig hier — zet wat in Geld en het verschijnt vanzelf hier.';

  @override
  String get homeIncome => 'Erbij';

  @override
  String get homeExpense => 'Eraf';

  @override
  String get homeAllocation => 'Verdeeld';

  @override
  String homeSaveFailed(String error) {
    return 'Je startpagina kon niet worden opgeslagen: $error';
  }

  @override
  String get homeAddSheetTitle => 'Maak ruimte voor wat belangrijk is';

  @override
  String get homeEditLayout => 'Indeling bewerken';

  @override
  String get homeEditingTitle => 'Maak het je gemakkelijk';

  @override
  String get homePhoneLayout => 'Telefoonindeling';

  @override
  String get homeDesktopLayout => 'Indeling voor desktop en laptop';

  @override
  String get homeResetDashboard => 'Oorspronkelijk dashboard herstellen';

  @override
  String get homeAddTile => 'Tegel toevoegen';

  @override
  String get homeSaveLayout => 'Indeling opslaan';

  @override
  String get homeEdit => 'Startpagina bewerken';

  @override
  String get homeDragHint =>
      'Sleep een tegel aan de titel. Sleep de onderste hoek om de grootte te wijzigen. Tegels klikken op hun plaats; overlappende tegels schuiven omlaag.';

  @override
  String get homeUnavailable => 'Niet beschikbaar';

  @override
  String get homeInspiration => 'Een beetje inspiratie';

  @override
  String get homeEditSummary => 'Samenvatting bewerken';

  @override
  String get homeCashBalance => 'Kassaldo';

  @override
  String get homeCustomText => 'Eigen tekst';

  @override
  String get homeSummaryTitle => 'Begroetingssamenvatting';

  @override
  String get homeSummaryDescription =>
      'Je begroeting staat altijd bovenaan. Kies wat eronder verschijnt.';

  @override
  String get homeShowInGreeting => 'Tonen in begroeting';

  @override
  String get homeSummaryLabel => 'Label';

  @override
  String get homeSummaryLabelHint => 'Focus van vandaag';

  @override
  String get homeSummaryText => 'Tekst';

  @override
  String get homeSummaryTextHint => 'Maak tijd voor wat belangrijk is.';

  @override
  String get homeApply => 'Toepassen';

  @override
  String get commonCancel => 'Annuleren';

  @override
  String get homeTileShortcut => 'Appsnelkoppeling';

  @override
  String get homeTileRecentActivity => 'Recente activiteit';

  @override
  String get homeTileFinanceOverview => 'Financieel overzicht';

  @override
  String get homeTilePinnedNote => 'Vastgezette notitie';

  @override
  String get homeTilePluginShortcut => 'Pluginsnelkoppeling';

  @override
  String get homeTileMinecraftInstance => 'Minecraft-instantie';

  @override
  String get homeTileErrands => 'Terugkerende taken';

  @override
  String get homeTileStockChart => 'Aandelengrafiek';

  @override
  String get homeTileGithubActivity => 'GitHub-activiteit';

  @override
  String get homeTileGithubIssues => 'GitHub-issues';

  @override
  String get homeTileAiUsage => 'AI-gebruik';

  @override
  String get homeTileCalculator => 'Rekenmachine';

  @override
  String get homeTileClockDate => 'Klok en datum';

  @override
  String get homeTileFocusTimer => 'Focustimer';

  @override
  String get homeTileQuickActions => 'Snelle acties';

  @override
  String get pinEnterNew => 'Bedenk een nieuwe PIN van 8 cijfers';

  @override
  String get pinVerify => 'Typ hem nog een keertje';

  @override
  String get pinEnterDisable => 'Typ je PIN om hem uit te zetten';

  @override
  String get pinNotMatch => 'Die PINs zijn niet hetzelfde.';

  @override
  String get pinIncorrect => 'Nee, verkeerde PIN.';

  @override
  String aboutVersionRelease(String version) {
    return 'Versie $version · een kleine app die je spullen bij je houdt';
  }

  @override
  String get aboutVersionDev =>
      'Testversie · met liefde gemaakt op iemands laptop';

  @override
  String get petSearchHint => 'Zoek plugins en pagina\'s';

  @override
  String get petMoodIdle => 'Wat gaan we openen?';

  @override
  String get petMoodCurious => 'Oeh, even kijken…';

  @override
  String get petMoodHappy => 'Dat kietelt.';

  @override
  String get petMoodDelighted => 'Beste dag ooit!';

  @override
  String get petMoodSleepy => 'Nog wakker? Ik ook.';

  @override
  String get petNoResults => 'Niets met die naam';

  @override
  String get petNoResultsHint =>
      'Probeer een korter woord, of een stukje ervan.';

  @override
  String get petSectionJumpTo => 'SPRING NAAR';

  @override
  String get petSectionResults => 'RESULTATEN';

  @override
  String get petKindPlugin => 'Plugin';

  @override
  String get petKindPage => 'Pagina';

  @override
  String get petHintMove => 'kiezen';

  @override
  String get petHintOpen => 'openen';

  @override
  String get petHintClose => 'sluiten';

  @override
  String get petClose => 'Sluiten';

  @override
  String get petPatsTooltip => 'Aaitjes gegeven';

  @override
  String petPatLabel(String name) {
    return 'Aai $name';
  }

  @override
  String get petSettingsTitle => 'luma-huisdier';

  @override
  String get petSettingsSubtitle =>
      'Druk overal op de sneltoets om het huisdier te roepen en typ om naar een pagina of plugin te springen.';

  @override
  String get petSettingsHotkey => 'Overal oproepen';

  @override
  String get petSettingsHotkeyTaken =>
      'Een andere app heeft deze sneltoets al, dus hij werkt alleen als luma vooraan staat. Kies hieronder een andere.';

  @override
  String get petSettingsRebind => 'Wijzigen';

  @override
  String get petSettingsRebindTitle => 'Druk een nieuwe sneltoets';

  @override
  String get petSettingsRebindSave => 'Gebruiken';

  @override
  String get petSettingsName => 'Naam';

  @override
  String get petSettingsSummon => 'Huisdier openen';

  @override
  String get petSettingsSummonHint =>
      'Zet het paneel meteen open — zonder sneltoets.';

  @override
  String get monthJan => 'jan';

  @override
  String get monthFeb => 'feb';

  @override
  String get monthMar => 'mrt';

  @override
  String get monthApr => 'apr';

  @override
  String get monthMay => 'mei';

  @override
  String get monthJun => 'jun';

  @override
  String get monthJul => 'jul';

  @override
  String get monthAug => 'aug';

  @override
  String get monthSep => 'sep';

  @override
  String get monthOct => 'okt';

  @override
  String get monthNov => 'nov';

  @override
  String get monthDec => 'dec';

  @override
  String get weekdayMon => 'maandag';

  @override
  String get weekdayTue => 'dinsdag';

  @override
  String get weekdayWed => 'woensdag';

  @override
  String get weekdayThu => 'donderdag';

  @override
  String get weekdayFri => 'vrijdag';

  @override
  String get weekdaySat => 'zaterdag';

  @override
  String get weekdaySun => 'zondag';

  @override
  String planSuffix(String name) {
    return '$name abonnement';
  }

  @override
  String get assistantNewChat => 'Nieuwe chat';

  @override
  String get assistantSearchChats => 'Chats zoeken';

  @override
  String get assistantStarred => 'Met ster';

  @override
  String get assistantRecents => 'Recent';

  @override
  String get assistantNoChats => 'Nog geen chats';

  @override
  String get assistantNoMatches => 'Geen chats gevonden';

  @override
  String get assistantGreetingMorning => 'Goedemorgen';

  @override
  String get assistantGreetingAfternoon => 'Goedemiddag';

  @override
  String get assistantGreetingEvening => 'Goedenavond';

  @override
  String assistantGreetingMorningName(String name) {
    return 'Goedemorgen, $name';
  }

  @override
  String assistantGreetingAfternoonName(String name) {
    return 'Goedemiddag, $name';
  }

  @override
  String assistantGreetingEveningName(String name) {
    return 'Goedenavond, $name';
  }

  @override
  String get assistantHowCanIHelp => 'Waarmee kan ik je vandaag helpen?';

  @override
  String get assistantReplyHint => 'Antwoord aan luma…';

  @override
  String get assistantOutOfMessages => 'Je berichten zijn voorlopig op';

  @override
  String get assistantCopy => 'Kopiëren';

  @override
  String get assistantCopied => 'Gekopieerd';

  @override
  String get assistantStar => 'Ster geven';

  @override
  String get assistantUnstar => 'Ster verwijderen';

  @override
  String get assistantRename => 'Naam wijzigen';

  @override
  String get assistantDelete => 'Verwijderen';

  @override
  String get assistantSuggestPlugin => 'Plugin zoeken';

  @override
  String get assistantSuggestQr => 'QR-code maken';

  @override
  String get assistantSuggestWeek => 'Plan mijn week';

  @override
  String get assistantSuggestNote => 'Notitie schrijven';

  @override
  String get assistantSuggestPluginPrompt => 'Welke luma-plugin helpt me met ';

  @override
  String get assistantSuggestQrPrompt => 'Maak een QR-code voor ';

  @override
  String get assistantSuggestWeekPrompt =>
      'Wat staat er deze week in mijn agenda?';

  @override
  String get assistantSuggestNotePrompt => 'Sla een notitie op met ';

  @override
  String get assistantToggleSidebar => 'Zijbalk tonen/verbergen';

  @override
  String get assistantChats => 'Chats';

  @override
  String get assistantUsage => 'Gebruik';

  @override
  String get assistantContextWindow => 'Contextvenster';

  @override
  String get assistantUsageLimits => 'Gebruikslimieten';

  @override
  String get assistantFiveHourLimit => 'Limiet per 5 uur';

  @override
  String get assistantWeeklyLimit => 'Wekelijks';

  @override
  String get assistantDailyMessages => 'Vandaag';

  @override
  String assistantMessagesOf(int used, int limit) {
    return '$used van $limit berichten';
  }

  @override
  String get assistantLastReply => 'Laatste antwoord';

  @override
  String assistantTokensInOut(String input, String output) {
    return '$input in · $output uit';
  }

  @override
  String get assistantNoLimits =>
      'Draait op dit apparaat — geen gebruikslimieten';

  @override
  String get assistantUsageUnavailable =>
      'Gebruik niet beschikbaar — controleer je verbinding';

  @override
  String get assistantDetailedBreakdown => 'Gedetailleerd overzicht bekijken';

  @override
  String get assistantNoRepliesYet => 'Nog geen antwoorden in deze chat';

  @override
  String get assistantMenuUsage => 'Gebruik';

  @override
  String get assistantMenuSettings => 'Instellingen';

  @override
  String get assistantMenuAgents => 'Agents';

  @override
  String get assistantYourUsage => 'Jouw gebruik';

  @override
  String get assistantUsageHeadlinePlenty =>
      'Nog genoeg ruimte. Chat maar raak.';

  @override
  String get assistantUsageHeadlineOnTrack => 'Je zit goed, met ruimte over.';

  @override
  String get assistantUsageHeadlineClose =>
      'Let op. Je zit dicht bij een limiet.';

  @override
  String get assistantUsageHeadlineOut =>
      'Je hebt een limiet bereikt. Die komt vanzelf weer vrij.';

  @override
  String get assistantUsageLumaAi => 'Luma AI';

  @override
  String get assistantUsageLumaAiSubtitle =>
      'Aurora, Nebula en Pulsar, via je luma-account';

  @override
  String get assistantUsageCurrentSession => 'Huidige sessie';

  @override
  String get assistantUsageRollingFiveHours =>
      'Voortschrijdend venster van 5 uur';

  @override
  String get assistantUsageThisWeek => 'Deze week';

  @override
  String get assistantUsageRollingWeek => 'Voortschrijdend venster van 7 dagen';

  @override
  String get assistantUsageLumaAssistant => 'Luma Assistant';

  @override
  String get assistantUsageLumaAssistantSubtitle => 'Qwen-model op je apparaat';

  @override
  String get assistantUsageWebSearch => 'Zoekopdrachten op het web';

  @override
  String assistantUsageCountOf(int used, int limit) {
    return '$used van $limit';
  }

  @override
  String assistantUsagePercentUsed(int percent) {
    return '$percent% gebruikt';
  }

  @override
  String get assistantUsageLumaSupport => 'Luma Support';

  @override
  String get assistantUsageResetsDaily => 'Wordt om middernacht gereset';

  @override
  String get assistantUsageApiKeys => 'Je API-sleutels';

  @override
  String get assistantUsageApiKeysSubtitle =>
      'Je eigen API-sleutels; tegoed en limieten van de provider blijven gelden';

  @override
  String get assistantUsageUnlimited => 'Onbeperkt in Luma';

  @override
  String get assistantUsageByModel => 'Berichten per model';

  @override
  String get assistantUsageByModelSubtitle =>
      'Geslaagde berichten op dit apparaat, per model geteld.';

  @override
  String assistantUsageMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count berichten',
      one: '1 bericht',
    );
    return '$_temp0';
  }

  @override
  String get assistantUsageNoMessages => 'Nog geen berichten';

  @override
  String get assistantUsageStorage => 'Opslag';

  @override
  String get assistantUsageMemoryStorage => 'Geheugen van de assistent';

  @override
  String get assistantUsageMemoryStorageCaption =>
      'Synchroniseert met je account op elk abonnement en telt mee voor serveropslag';

  @override
  String get assistantUsageServerStorage => 'Serveropslag';

  @override
  String assistantUsageStorageOf(String used, String quota) {
    return '$used van $quota';
  }

  @override
  String get assistantSettingsChat => 'Chat';

  @override
  String get assistantSettingsMemory => 'Geheugen';

  @override
  String get assistantSettingsUser => 'Gebruiker';

  @override
  String get assistantSettingsLanguage => 'Taal van antwoorden';

  @override
  String get assistantSettingsLanguageHint =>
      'De taal waarin de assistent je antwoordt.';

  @override
  String get assistantSettingsLanguageAuto => 'Zelfde als mijn taal';

  @override
  String get assistantSettingsFont => 'Lettertype';

  @override
  String get assistantSettingsFontHint =>
      'Het lettertype van de antwoorden van de assistent.';

  @override
  String get assistantFontSerif => 'Schreef';

  @override
  String get assistantFontSans => 'Schreefloos';

  @override
  String get assistantFontMono => 'Mono';

  @override
  String get assistantSettingsTextSize => 'Tekstgrootte';

  @override
  String get assistantSettingsTextSizeHint => 'Grootte van de gesprekstekst.';

  @override
  String get assistantTextSmall => 'Klein';

  @override
  String get assistantTextMedium => 'Normaal';

  @override
  String get assistantTextLarge => 'Groot';

  @override
  String get assistantSettingsPreview => 'Voorbeeld';

  @override
  String get assistantSettingsPreviewText =>
      'Zo zien antwoorden eruit. **Vet**, *cursief* en `code` volgen je keuze.';

  @override
  String get assistantMemoryUse => 'Geheugen gebruiken';

  @override
  String get assistantMemoryUseHint =>
      'Laat de assistent dingen over je onthouden tussen chats en ze gebruiken wanneer dat helpt.';

  @override
  String assistantMemorySyncNote(String size) {
    return 'Gesynchroniseerd met je account op elk abonnement · $size serveropslag';
  }

  @override
  String get assistantMemoryAdd => 'Herinnering toevoegen';

  @override
  String get assistantMemoryEdit => 'Herinnering bewerken';

  @override
  String get assistantMemoryEmpty => 'Nog niets onthouden';

  @override
  String get assistantMemoryEmptyHint =>
      'Vertel de assistent in een chat over jezelf, of voeg hier een herinnering toe.';

  @override
  String get assistantMemoryYou => 'Jij';

  @override
  String get assistantMemoryTopics => 'Onderwerpen';

  @override
  String get assistantMemoryAreas => 'Gebieden';

  @override
  String assistantMemoryUpdated(String date) {
    return 'Bijgewerkt $date';
  }

  @override
  String get assistantMemoryClear => 'Al het geheugen wissen';

  @override
  String get assistantMemoryClearTitle => 'Al het geheugen wissen?';

  @override
  String get assistantMemoryClearBody =>
      'De assistent vergeet alles wat hij onthouden had, op elk apparaat. Je profiel op het tabblad Gebruiker blijft staan.';

  @override
  String get assistantMemoryTitle => 'Titel';

  @override
  String get assistantMemoryTitleHint => 'bijv. Hardware';

  @override
  String get assistantMemoryDescription => 'Samenvatting';

  @override
  String get assistantMemoryDescriptionHint =>
      'Eén regel, zichtbaar in de lijst';

  @override
  String get assistantMemoryBody => 'Wat te onthouden';

  @override
  String get assistantMemoryBodyHint => 'Eén feit per regel';

  @override
  String get assistantProfileCallMe => 'Hoe moet de assistent je noemen?';

  @override
  String get assistantProfileCallMeHint => 'Je naam of bijnaam';

  @override
  String get assistantProfileOccupation => 'Wat doe je?';

  @override
  String get assistantProfileOccupationHint =>
      'bijv. student, indie-gameontwikkelaar';

  @override
  String get assistantProfileSummary => 'Over jou';

  @override
  String get assistantProfileSummaryHint =>
      'Een paar zinnen die de assistent altijd moet weten';

  @override
  String get assistantProfileInstructions =>
      'Hoe moet de assistent antwoorden?';

  @override
  String get assistantProfileInstructionsHint =>
      'bijv. houd het kort, leg code stap voor stap uit';

  @override
  String get assistantProfileSave => 'Opslaan';

  @override
  String get assistantProfileSaved => 'Opgeslagen';

  @override
  String get assistantAgentsComingSoon => 'Binnenkort';

  @override
  String get assistantAgentsSubtitle =>
      'Agents die je in de AI Usage-plugin hebt gemaakt. Ze vanuit de assistent gebruiken komt binnenkort.';

  @override
  String get assistantAgentsEmpty => 'Nog geen agents';

  @override
  String get assistantAgentsEmptyHint =>
      'Maak er een op het tabblad Agents van de AI Usage-plugin en hij verschijnt hier.';

  @override
  String get assistantAgentsOpenBuilder => 'AI Usage openen';

  @override
  String get assistantAgentsNoDescription => 'Geen beschrijving';

  @override
  String get textLibraryBack => 'Terug';

  @override
  String get textLibraryBodyHint => 'Schrijf je tekst…';

  @override
  String get textLibraryBold => 'Vet';

  @override
  String get textLibraryCancel => 'Annuleren';

  @override
  String get textLibraryClearFormatting => 'Opmaak wissen';

  @override
  String get textLibraryColor => 'Kleur';

  @override
  String get textLibraryCover => 'Omslag';

  @override
  String get textLibraryCreate => 'Maken';

  @override
  String get textLibraryDefaultInk => 'Standaardinktkleur';

  @override
  String get textLibraryDelete => 'Verwijderen';

  @override
  String textLibraryDeleteSubjectTitle(String name) {
    return 'Onderwerp ‘$name’ verwijderen?';
  }

  @override
  String textLibraryDeleteSubjectBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count teksten',
      one: 'één tekst',
      zero: 'geen teksten',
    );
    return 'Dit onderwerp en $_temp0 verwijderen?';
  }

  @override
  String get textLibraryDeleteTextBody =>
      'Deze tekst wordt definitief verwijderd.';

  @override
  String textLibraryDeleteTextTitle(String title) {
    return '‘$title’ verwijderen?';
  }

  @override
  String textLibraryEdited(String date) {
    return 'Bewerkt op $date';
  }

  @override
  String get textLibraryInk => 'Inkt';

  @override
  String get textLibraryItalic => 'Cursief';

  @override
  String textLibraryMcBooks(String count) {
    return '$count boeken';
  }

  @override
  String get textLibraryMcBuild => 'Bouwen';

  @override
  String get textLibraryMcBuiltIn => 'Ingebouwd';

  @override
  String get textLibraryMcBurn => 'Verbranden';

  @override
  String get textLibraryMcBurnConfirm =>
      'Dit boek verbranden? Dit kan niet ongedaan worden gemaakt.';

  @override
  String get textLibraryMcChooseSlot => 'Kies een plek in de boekenkast';

  @override
  String get textLibraryMcDone => 'Klaar';

  @override
  String get textLibraryMcDownload => 'Minecraft-bestanden downloaden';

  @override
  String get textLibraryMcDownloadFailed =>
      'Minecraft-bestanden konden niet worden gedownload.';

  @override
  String get textLibraryMcDownloadNote =>
      'Minecraft-bestanden worden gedownload van Mojang en op dit apparaat bewaard.';

  @override
  String get textLibraryMcEmptyHall =>
      'Je hal is leeg. Maak een onderwerp om te beginnen.';

  @override
  String get textLibraryMcEmptySlot => 'Lege plek';

  @override
  String get textLibraryMcFailedAndroid =>
      'De Minecraft-bibliotheek kon niet worden geopend op Android.';

  @override
  String get textLibraryMcFailedWindows =>
      'De Minecraft-bibliotheek kon niet worden geopend op Windows.';

  @override
  String get textLibraryMcLoading => 'Minecraft-bibliotheek laden…';

  @override
  String get textLibraryMcLost =>
      'De verbinding met de Minecraft-bibliotheek is verbroken.';

  @override
  String get textLibraryMcMoveHint =>
      'Verplaats dit boek naar een andere boekenkast.';

  @override
  String get textLibraryMcNewCase => 'Nieuwe vitrine';

  @override
  String get textLibraryMcNewCaseTitle => 'Vitrine maken';

  @override
  String textLibraryMcPage(String page, String total) {
    return 'Pagina $page van $total';
  }

  @override
  String get textLibraryMcQuality => 'Weergavekwaliteit';

  @override
  String get textLibraryMcQualityHigh => 'Hoog';

  @override
  String get textLibraryMcQualityLow => 'Laag';

  @override
  String get textLibraryMcRedo => 'Opnieuw';

  @override
  String get textLibraryMcRetry => 'Opnieuw proberen';

  @override
  String get textLibraryMcSaveFailed => 'Het boek kon niet worden opgeslagen.';

  @override
  String get textLibraryMcSettings => 'Halinstellingen';

  @override
  String textLibraryMcShelfPage(String page, String total) {
    return 'Boekenkastpagina $page van $total';
  }

  @override
  String get textLibraryMcSign => 'Boek ondertekenen';

  @override
  String get textLibraryMcSignAndShelve => 'Ondertekenen en in de kast zetten';

  @override
  String get textLibraryMcSignTitle => 'Dit boek ondertekenen?';

  @override
  String get textLibraryMcTime => 'Tijd';

  @override
  String get textLibraryMcTimeClock => 'Mijn klok';

  @override
  String get textLibraryMcTimeCycle => 'Dag en nacht';

  @override
  String get textLibraryMcTimeDay => 'Altijd dag';

  @override
  String get textLibraryMcTimeNight => 'Altijd nacht';

  @override
  String get textLibraryMcUndo => 'Ongedaan maken';

  @override
  String get textLibraryMcUntitled => 'Zonder titel';

  @override
  String textLibraryMcVanilla(String version) {
    return 'Minecraft $version';
  }

  @override
  String get textLibraryMcWalkHint =>
      'WASD om te lopen · klik om rond te kijken · klik op een boekenkast, stoel of deur om hem te gebruiken · Esc laat de muis los';

  @override
  String get textLibraryMcLookHint => 'Klik om rond te kijken';

  @override
  String get textLibraryMcStandHint => 'Shift of spatie om op te staan';

  @override
  String get textLibraryMcStandUp => 'Opstaan';

  @override
  String get textLibraryMcSit => 'Ga zitten';

  @override
  String get textLibraryMcOpenDoor => 'Doe de deur open';

  @override
  String get textLibraryMcCloseDoor => 'Doe de deur dicht';

  @override
  String textLibraryMcSkinCurrent(String name) {
    return 'Skin: $name';
  }

  @override
  String get textLibraryMcSkinDefault => 'Standaardskin';

  @override
  String get textLibraryMcSkinYours => 'je eigen';

  @override
  String get textLibraryMcSkinImport => 'Skin importeren…';

  @override
  String get textLibraryMcSkinName => 'Minecraft-naam…';

  @override
  String get textLibraryMcSkinNameTitle => 'Je Minecraft-gebruikersnaam';

  @override
  String get textLibraryMcSkinNameHint => 'Gebruikersnaam';

  @override
  String get textLibraryMcSkinUse => 'Skin gebruiken';

  @override
  String get textLibraryMcSkinFailed => 'Die skin kon niet geladen worden.';

  @override
  String get textLibraryMcWriteHint => 'Schrijf je boek hier…';

  @override
  String get textLibraryModeClassic => 'Klassiek';

  @override
  String get textLibraryModeMinecraft => 'Minecraft-hal';

  @override
  String get textLibraryMoveTo => 'Verplaatsen naar';

  @override
  String get textLibraryMoveToTitle => 'Tekst naar een onderwerp verplaatsen';

  @override
  String get textLibraryNewSubject => 'Nieuw onderwerp';

  @override
  String get textLibraryNewText => 'Nieuwe tekst';

  @override
  String textLibraryNoMatches(String query) {
    return 'Geen teksten gevonden voor ‘$query’';
  }

  @override
  String get textLibraryNoSubjects => 'Nog geen onderwerpen';

  @override
  String get textLibraryNoSubjectsSub =>
      'Maak een onderwerp om je teksten te ordenen.';

  @override
  String get textLibraryNoTexts => 'Nog geen teksten';

  @override
  String get textLibraryNoTextsSub =>
      'Voeg een tekst aan dit onderwerp toe om te beginnen.';

  @override
  String get textLibraryRename => 'Naam wijzigen';

  @override
  String get textLibraryRenameSubject => 'Onderwerp hernoemen';

  @override
  String get textLibrarySave => 'Opslaan';

  @override
  String get textLibrarySaved => 'Opgeslagen';

  @override
  String get textLibrarySaving => 'Opslaan…';

  @override
  String get textLibrarySearchHint => 'Teksten zoeken';

  @override
  String get textLibrarySpineHint => 'Een kort label op de rug van het boek';

  @override
  String get textLibrarySpineLabel => 'Ruglabel';

  @override
  String get textLibraryStrike => 'Doorhalen';

  @override
  String get textLibrarySubjectNameHint => 'Naam van onderwerp';

  @override
  String get textLibrarySubjectNameRequired => 'Voer een onderwerpnaam in.';

  @override
  String get textLibrarySubjects => 'Onderwerpen';

  @override
  String textLibraryTextCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count teksten',
      one: '1 tekst',
    );
    return '$_temp0';
  }

  @override
  String get textLibraryTitleHint => 'Titel';

  @override
  String get textLibraryUnderline => 'Onderstrepen';
}
