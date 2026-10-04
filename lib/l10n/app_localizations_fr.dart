// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class LFr extends L {
  LFr([String locale = 'fr']) : super(locale);

  @override
  String get settingsTrackBackendAiUsage =>
      'Suivre l’utilisation de l’IA côté serveur';

  @override
  String get settingsTrackBackendAiUsageSub =>
      'Inclure dans Utilisation de l’IA les nouveaux appels des fonctions de l’application via le serveur Luma. Désactivé par défaut.';

  @override
  String get trayOpen => 'Ouvrir luma';

  @override
  String get trayQuit => 'Quitter luma';

  @override
  String get navHome => 'Accueil';

  @override
  String get navFileConverter => 'Convertisseur de fichiers';

  @override
  String get navFinance => 'Finances';

  @override
  String get navPasswordManager => 'Gestionnaire de mots de passe';

  @override
  String get navNotes => 'Notes';

  @override
  String get navAssistant => 'Assistant';

  @override
  String get navPlugins => 'Plugins';

  @override
  String get tabClose => 'Fermer l\'onglet';

  @override
  String get tabNew => 'Nouvel onglet';

  @override
  String get tabOpenPlugin => 'Ouvrir un autre plugin';

  @override
  String get navSettings => 'Paramètres';

  @override
  String get navAccount => 'Compte';

  @override
  String get navConvert => 'Convertir';

  @override
  String get navVault => 'Coffre';

  @override
  String get navMore => 'Plus';

  @override
  String get shellPluginUnavailable => 'Plugin indisponible';

  @override
  String get shellStorageLimitMsg =>
      'Vous avez atteint votre limite de stockage. Les nouvelles données ne seront ni enregistrées ni synchronisées tant que vous n\'aurez pas libéré d\'espace.';

  @override
  String get shellStorageManage => 'Gérer';

  @override
  String get shellStorageDismiss => 'Fermer';

  @override
  String get settingsAppearance => 'Apparence';

  @override
  String get settingsAppearanceSub => 'Faites de luma le vôtre.';

  @override
  String get settingsTheme => 'Thème';

  @override
  String get settingsAccentColor => 'Couleur d\'accent';

  @override
  String get settingsThemeStyle => 'Style de thème';

  @override
  String get settingsThemeStyleDefault => 'Par défaut';

  @override
  String get settingsThemeStyleDefaultSub =>
      'luma tel quel — des surfaces nettes et votre accent choisi.';

  @override
  String get settingsThemeStyleCoffee => 'Café';

  @override
  String get settingsThemeStyleCoffeeSub =>
      'Expresso et crème, des formes plus douces et des grains qui dérivent en fond.';

  @override
  String get settingsThemeStyleLocked => 'Orbit ou Nova';

  @override
  String get settingsThemeStyleUpgrade =>
      'Café fait partie d\'Orbit et Nova. Passez à l\'offre supérieure pour le servir.';

  @override
  String get settingsAccentCoffeeNote =>
      'Café apporte sa propre palette : le sélecteur d\'accent est en pause tant qu\'il est actif.';

  @override
  String get settingsGeneral => 'Général';

  @override
  String get settingsGeneralSub => 'Le comportement de l\'application.';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsOpenOnLaunch => 'Ouvrir au démarrage';

  @override
  String get settingsHideAmounts => 'Masquer les montants sur l\'accueil';

  @override
  String get settingsHideAmountsSub =>
      'Masque les solds sur le tableau de bord contre les regards indiscrets.';

  @override
  String get settingsLockPasswords => 'Verrouiller les mots de passe';

  @override
  String get settingsLockPasswordsSub =>
      'Exige un code PIN à 8 chiffres pour consulter ou modifier les identifiants enregistrés.';

  @override
  String get settingsAmericanGpa => 'Échelle GPA américaine';

  @override
  String get settingsAmericanGpaSub =>
      'Utiliser le système GPA américain sur 4.0 dans le plugin École au lieu de l\'échelle néerlandaise de 1 à 10.';

  @override
  String get settingsAiAssistant => 'Assistant IA';

  @override
  String get settingsAiAssistantSub =>
      'Connectez votre propre clé API Anthropic.';

  @override
  String get settingsAbout => 'À propos';

  @override
  String get settingsResetDefaults => 'Réinitialiser';

  @override
  String get settingsResetTitle => 'Réinitialiser les paramètres ?';

  @override
  String get settingsResetContent =>
      'Cela restaure le thème, la couleur d\'accent et les autres préférences à leurs valeurs par défaut.';

  @override
  String get settingsResetCancel => 'Annuler';

  @override
  String get settingsResetConfirm => 'Réinitialiser';

  @override
  String get settingsCheckUpdates => 'Rechercher des mises à jour';

  @override
  String get settingsOpenSourceLicenses => 'Licences open source';

  @override
  String get settingsSystem => 'Système';

  @override
  String get settingsLight => 'Clair';

  @override
  String get settingsDark => 'Sombre';

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
  String get langSystemDefault => 'Système';

  @override
  String get homeGreetingMorning => 'Bonjour';

  @override
  String get homeGreetingAfternoon => 'Bon après-midi';

  @override
  String get homeGreetingEvening => 'Bonsoir';

  @override
  String get homeNetWorth => 'Valeur nette';

  @override
  String get homeAtAGlance => 'En un coup d\'œil';

  @override
  String get homeJumpBackIn => 'Reprendre';

  @override
  String get homeRecentActivity => 'Activité récente';

  @override
  String get homeIncomeMonth => 'Revenus ce mois-ci';

  @override
  String get homeSpentMonth => 'Dépensé ce mois-ci';

  @override
  String get homeInPots => 'Dans les tirelires';

  @override
  String get homeInvestments => 'Investissements';

  @override
  String get homeAskAssistant => 'Demander à l\'assistant';

  @override
  String get homeAskAssistantSub => 'Discutez avec l\'assistant IA';

  @override
  String get homeFinance => 'Finances';

  @override
  String get homeFinanceSub => 'Budgets, tirelires & actions';

  @override
  String get homeFileConverter => 'Convertisseur de fichiers';

  @override
  String get homeFileConverterSub => 'Convertir images & fichiers';

  @override
  String get homeSettings => 'Paramètres';

  @override
  String get homeSettingsSub => 'Thème, couleurs & plus';

  @override
  String get homeNoTransactions =>
      'Rien ici pour l\'instant — ajoutez une transaction dans l\'onglet Finances et elle apparaîtra ici.';

  @override
  String get homeIncome => 'Revenu';

  @override
  String get homeExpense => 'Dépense';

  @override
  String get homeAllocation => 'Allocation';

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
  String get pinEnterNew => 'Saisissez un nouveau code PIN à 8 chiffres';

  @override
  String get pinVerify => 'Confirmez le nouveau code PIN';

  @override
  String get pinEnterDisable => 'Saisissez le code PIN pour désactiver';

  @override
  String get pinNotMatch => 'Les codes PIN ne correspondent pas.';

  @override
  String get pinIncorrect => 'Code PIN incorrect.';

  @override
  String aboutVersionRelease(String version) {
    return 'Version $version · un outil local épuré';
  }

  @override
  String get aboutVersionDev =>
      'Version de développement · un outil local épuré';

  @override
  String get petSearchHint => 'Rechercher plugins et pages';

  @override
  String get petMoodIdle => 'On ouvre quoi ?';

  @override
  String get petMoodCurious => 'Oh, je regarde…';

  @override
  String get petMoodHappy => 'Ça chatouille.';

  @override
  String get petMoodDelighted => 'Quelle belle journée !';

  @override
  String get petMoodSleepy => 'Encore debout ? Moi aussi.';

  @override
  String get petNoResults => 'Rien à ce nom';

  @override
  String get petNoResultsHint =>
      'Essaie un mot plus court, ou juste un morceau.';

  @override
  String get petSectionJumpTo => 'ALLER À';

  @override
  String get petSectionResults => 'RÉSULTATS';

  @override
  String get petKindPlugin => 'Plugin';

  @override
  String get petKindPage => 'Page';

  @override
  String get petHintMove => 'naviguer';

  @override
  String get petHintOpen => 'ouvrir';

  @override
  String get petHintClose => 'fermer';

  @override
  String get petClose => 'Fermer';

  @override
  String get petPatsTooltip => 'Caresses données';

  @override
  String petPatLabel(String name) {
    return 'Caresser $name';
  }

  @override
  String get petSettingsTitle => 'compagnon luma';

  @override
  String get petSettingsSubtitle =>
      'Appuie sur le raccourci n\'importe où pour appeler le compagnon, puis tape pour aller à une page ou un plugin.';

  @override
  String get petSettingsHotkey => 'Appeler de partout';

  @override
  String get petSettingsHotkeyTaken =>
      'Une autre app possède déjà ce raccourci : il ne marche que si luma est au premier plan. Choisis-en un autre ci-dessous.';

  @override
  String get petSettingsRebind => 'Changer';

  @override
  String get petSettingsRebindTitle => 'Appuie sur un nouveau raccourci';

  @override
  String get petSettingsRebindSave => 'Utiliser';

  @override
  String get petSettingsName => 'Nom';

  @override
  String get petSettingsSummon => 'Ouvrir le compagnon';

  @override
  String get petSettingsSummonHint =>
      'Ouvre le panneau tout de suite, sans raccourci clavier.';

  @override
  String get monthJan => 'janv.';

  @override
  String get monthFeb => 'févr.';

  @override
  String get monthMar => 'mars';

  @override
  String get monthApr => 'avr.';

  @override
  String get monthMay => 'mai';

  @override
  String get monthJun => 'juin';

  @override
  String get monthJul => 'juil.';

  @override
  String get monthAug => 'août';

  @override
  String get monthSep => 'sept.';

  @override
  String get monthOct => 'oct.';

  @override
  String get monthNov => 'nov.';

  @override
  String get monthDec => 'déc.';

  @override
  String get weekdayMon => 'lundi';

  @override
  String get weekdayTue => 'mardi';

  @override
  String get weekdayWed => 'mercredi';

  @override
  String get weekdayThu => 'jeudi';

  @override
  String get weekdayFri => 'vendredi';

  @override
  String get weekdaySat => 'samedi';

  @override
  String get weekdaySun => 'dimanche';

  @override
  String planSuffix(String name) {
    return 'Formule $name';
  }

  @override
  String get assistantNewChat => 'Nouvelle discussion';

  @override
  String get assistantSearchChats => 'Rechercher';

  @override
  String get assistantStarred => 'Favoris';

  @override
  String get assistantRecents => 'Récents';

  @override
  String get assistantNoChats => 'Aucune discussion';

  @override
  String get assistantNoMatches => 'Aucun résultat';

  @override
  String get assistantGreetingMorning => 'Bonjour';

  @override
  String get assistantGreetingAfternoon => 'Bon après-midi';

  @override
  String get assistantGreetingEvening => 'Bonsoir';

  @override
  String assistantGreetingMorningName(String name) {
    return 'Bonjour, $name';
  }

  @override
  String assistantGreetingAfternoonName(String name) {
    return 'Bon après-midi, $name';
  }

  @override
  String assistantGreetingEveningName(String name) {
    return 'Bonsoir, $name';
  }

  @override
  String get assistantHowCanIHelp =>
      'Comment puis-je vous aider aujourd\'hui ?';

  @override
  String get assistantReplyHint => 'Répondre à luma…';

  @override
  String get assistantOutOfMessages =>
      'Vous n\'avez plus de messages pour l\'instant';

  @override
  String get assistantCopy => 'Copier';

  @override
  String get assistantCopied => 'Copié';

  @override
  String get assistantStar => 'Ajouter aux favoris';

  @override
  String get assistantUnstar => 'Retirer des favoris';

  @override
  String get assistantRename => 'Renommer';

  @override
  String get assistantDelete => 'Supprimer';

  @override
  String get assistantSuggestPlugin => 'Trouver un plugin';

  @override
  String get assistantSuggestQr => 'Créer un QR code';

  @override
  String get assistantSuggestWeek => 'Planifier ma semaine';

  @override
  String get assistantSuggestNote => 'Écrire une note';

  @override
  String get assistantSuggestPluginPrompt =>
      'Quel plugin luma m\'aiderait avec ';

  @override
  String get assistantSuggestQrPrompt => 'Crée un QR code pour ';

  @override
  String get assistantSuggestWeekPrompt =>
      'Qu\'y a-t-il dans mon agenda cette semaine ?';

  @override
  String get assistantSuggestNotePrompt => 'Enregistre une note qui dit ';

  @override
  String get assistantToggleSidebar => 'Afficher/masquer la barre latérale';

  @override
  String get assistantChats => 'Discussions';

  @override
  String get assistantUsage => 'Utilisation';

  @override
  String get assistantContextWindow => 'Fenêtre de contexte';

  @override
  String get assistantUsageLimits => 'Limites d\'utilisation';

  @override
  String get assistantFiveHourLimit => 'Limite sur 5 heures';

  @override
  String get assistantWeeklyLimit => 'Hebdomadaire';

  @override
  String get assistantDailyMessages => 'Aujourd\'hui';

  @override
  String assistantMessagesOf(int used, int limit) {
    return '$used messages sur $limit';
  }

  @override
  String get assistantLastReply => 'Dernière réponse';

  @override
  String assistantTokensInOut(String input, String output) {
    return '$input en entrée · $output en sortie';
  }

  @override
  String get assistantNoLimits =>
      'Fonctionne sur cet appareil — aucune limite d\'utilisation';

  @override
  String get assistantUsageUnavailable =>
      'Utilisation indisponible — vérifiez votre connexion';

  @override
  String get assistantDetailedBreakdown => 'Voir le détail';

  @override
  String get assistantNoRepliesYet =>
      'Pas encore de réponse dans cette discussion';

  @override
  String get assistantMenuUsage => 'Utilisation';

  @override
  String get assistantMenuSettings => 'Paramètres';

  @override
  String get assistantMenuAgents => 'Agents';

  @override
  String get assistantYourUsage => 'Votre utilisation';

  @override
  String get assistantUsageHeadlinePlenty =>
      'Encore de la marge. Discutez librement.';

  @override
  String get assistantUsageHeadlineOnTrack =>
      'Tout va bien, il vous reste de la marge.';

  @override
  String get assistantUsageHeadlineClose =>
      'Attention : vous approchez d\'une limite.';

  @override
  String get assistantUsageHeadlineOut =>
      'Vous avez atteint une limite. Elle se libère au fil du temps.';

  @override
  String get assistantUsageLumaAi => 'Luma AI';

  @override
  String get assistantUsageLumaAiSubtitle =>
      'Aurora, Nebula et Pulsar, via votre compte luma';

  @override
  String get assistantUsageCurrentSession => 'Session en cours';

  @override
  String get assistantUsageRollingFiveHours => 'Fenêtre glissante de 5 heures';

  @override
  String get assistantUsageThisWeek => 'Cette semaine';

  @override
  String get assistantUsageRollingWeek => 'Fenêtre glissante de 7 jours';

  @override
  String get assistantUsageLumaAssistant => 'Luma Assistant';

  @override
  String get assistantUsageLumaAssistantSubtitle =>
      'Modèle Qwen sur l’appareil';

  @override
  String get assistantUsageWebSearch => 'Recherches Web';

  @override
  String assistantUsageCountOf(int used, int limit) {
    return '$used sur $limit';
  }

  @override
  String assistantUsagePercentUsed(int percent) {
    return '$percent % utilisé';
  }

  @override
  String get assistantUsageLumaSupport => 'Luma Support';

  @override
  String get assistantUsageResetsDaily => 'Réinitialisé à minuit';

  @override
  String get assistantUsageApiKeys => 'Vos clés API';

  @override
  String get assistantUsageApiKeysSubtitle =>
      'Vos propres clés API ; les crédits et limites du fournisseur s\'appliquent';

  @override
  String get assistantUsageUnlimited => 'Illimité dans Luma';

  @override
  String get assistantUsageByModel => 'Messages par modèle';

  @override
  String get assistantUsageByModelSubtitle =>
      'Messages réussis sur cet appareil, comptés par modèle.';

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
  String get assistantUsageNoMessages => 'Pas encore de messages';

  @override
  String get assistantUsageStorage => 'Stockage';

  @override
  String get assistantUsageMemoryStorage => 'Mémoire de l\'assistant';

  @override
  String get assistantUsageMemoryStorageCaption =>
      'Synchronisée avec votre compte sur toutes les offres et comptée dans le stockage serveur';

  @override
  String get assistantUsageServerStorage => 'Stockage serveur';

  @override
  String assistantUsageStorageOf(String used, String quota) {
    return '$used sur $quota';
  }

  @override
  String get assistantSettingsChat => 'Discussion';

  @override
  String get assistantSettingsMemory => 'Mémoire';

  @override
  String get assistantSettingsUser => 'Utilisateur';

  @override
  String get assistantSettingsLanguage => 'Langue des réponses';

  @override
  String get assistantSettingsLanguageHint =>
      'La langue dans laquelle l\'assistant vous répond.';

  @override
  String get assistantSettingsLanguageAuto => 'Comme ma langue';

  @override
  String get assistantSettingsFont => 'Police';

  @override
  String get assistantSettingsFontHint =>
      'La police des réponses de l\'assistant.';

  @override
  String get assistantFontSerif => 'Serif';

  @override
  String get assistantFontSans => 'Sans';

  @override
  String get assistantFontMono => 'Mono';

  @override
  String get assistantSettingsTextSize => 'Taille du texte';

  @override
  String get assistantSettingsTextSizeHint =>
      'Taille du texte de la discussion.';

  @override
  String get assistantTextSmall => 'Petit';

  @override
  String get assistantTextMedium => 'Moyen';

  @override
  String get assistantTextLarge => 'Grand';

  @override
  String get assistantSettingsPreview => 'Aperçu';

  @override
  String get assistantSettingsPreviewText =>
      'Voici à quoi ressembleront les réponses. **Gras**, *italique* et `code` suivent votre choix.';

  @override
  String get assistantMemoryUse => 'Utiliser la mémoire';

  @override
  String get assistantMemoryUseHint =>
      'Laissez l\'assistant se souvenir de vous d\'une discussion à l\'autre et s\'en servir quand c\'est utile.';

  @override
  String assistantMemorySyncNote(String size) {
    return 'Synchronisée avec votre compte sur toutes les offres · $size de stockage serveur';
  }

  @override
  String get assistantMemoryAdd => 'Ajouter un souvenir';

  @override
  String get assistantMemoryEdit => 'Modifier le souvenir';

  @override
  String get assistantMemoryEmpty => 'Rien de mémorisé pour le moment';

  @override
  String get assistantMemoryEmptyHint =>
      'Parlez de vous à l\'assistant dans une discussion, ou ajoutez un souvenir ici.';

  @override
  String get assistantMemoryYou => 'Vous';

  @override
  String get assistantMemoryTopics => 'Sujets';

  @override
  String get assistantMemoryAreas => 'Domaines';

  @override
  String assistantMemoryUpdated(String date) {
    return 'Mis à jour le $date';
  }

  @override
  String get assistantMemoryClear => 'Effacer toute la mémoire';

  @override
  String get assistantMemoryClearTitle => 'Effacer toute la mémoire ?';

  @override
  String get assistantMemoryClearBody =>
      'L\'assistant oublie tout ce qu\'il avait retenu, sur tous vos appareils. Votre profil dans l\'onglet Utilisateur est conservé.';

  @override
  String get assistantMemoryTitle => 'Titre';

  @override
  String get assistantMemoryTitleHint => 'ex. Matériel';

  @override
  String get assistantMemoryDescription => 'Résumé';

  @override
  String get assistantMemoryDescriptionHint =>
      'Une ligne, affichée dans la liste';

  @override
  String get assistantMemoryBody => 'À retenir';

  @override
  String get assistantMemoryBodyHint => 'Un fait par ligne';

  @override
  String get assistantProfileCallMe =>
      'Comment l\'assistant doit-il vous appeler ?';

  @override
  String get assistantProfileCallMeHint => 'Votre prénom ou surnom';

  @override
  String get assistantProfileOccupation => 'Que faites-vous ?';

  @override
  String get assistantProfileOccupationHint =>
      'ex. étudiant, développeur de jeux indépendant';

  @override
  String get assistantProfileSummary => 'À propos de vous';

  @override
  String get assistantProfileSummaryHint =>
      'Quelques phrases que l\'assistant doit toujours connaître';

  @override
  String get assistantProfileInstructions =>
      'Comment l\'assistant doit-il répondre ?';

  @override
  String get assistantProfileInstructionsHint =>
      'ex. soyez bref, expliquez le code étape par étape';

  @override
  String get assistantProfileSave => 'Enregistrer';

  @override
  String get assistantProfileSaved => 'Enregistré';

  @override
  String get assistantAgentsComingSoon => 'Bientôt';

  @override
  String get assistantAgentsSubtitle =>
      'Les agents que vous avez créés dans le plugin AI Usage. Les lancer depuis l\'assistant arrive bientôt.';

  @override
  String get assistantAgentsEmpty => 'Pas encore d\'agents';

  @override
  String get assistantAgentsEmptyHint =>
      'Créez-en un dans l\'onglet Agents du plugin AI Usage et il apparaîtra ici.';

  @override
  String get assistantAgentsOpenBuilder => 'Ouvrir AI Usage';

  @override
  String get assistantAgentsNoDescription => 'Aucune description';

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
  String get assistantAddMenu => 'Ajouter';

  @override
  String get assistantModePlan => 'Mode plan';

  @override
  String get assistantModePlanHint => 'Obtenez un plan avant toute action';

  @override
  String get assistantModeResearch => 'Recherche approfondie';

  @override
  String get assistantModeResearchHint =>
      'Plusieurs agents enquêtent puis font leur rapport';

  @override
  String get assistantModeResearchUnavailable =>
      'Passez à Nebula, Pulsar ou Luma Assistant';

  @override
  String get assistantModePicture => 'Image';

  @override
  String assistantModePictureHint(int percent) {
    return 'Créer une image · utilise $percent% de votre limite hebdomadaire';
  }

  @override
  String get assistantModePictureUnavailable =>
      'Nécessite un compte luma connecté';

  @override
  String get assistantModeOff => 'Désactiver';

  @override
  String get assistantPlanComposerHint => 'Que dois-je planifier ?';

  @override
  String get assistantResearchComposerHint =>
      'Que doivent rechercher les agents ?';

  @override
  String get assistantPictureComposerHint => 'Décrivez l\'image';

  @override
  String get assistantResearchPlanning => 'Préparation de la recherche…';

  @override
  String assistantResearchProgress(int done, int total) {
    return '$done agents sur $total ont terminé';
  }

  @override
  String get assistantResearchParallel => 'Les agents travaillent en parallèle';

  @override
  String get assistantResearchSequential =>
      'Les agents se relaient sur cet appareil';

  @override
  String get assistantResearchWriting => 'Rédaction de la réponse…';

  @override
  String get assistantPictureDrawing => 'Création de votre image…';

  @override
  String get assistantPictureMissing =>
      'Cette image n\'est pas sur cet appareil';

  @override
  String get textLibraryMcMailbox => 'Boîte aux lettres';

  @override
  String textLibraryMcMailWaiting(String count) {
    return 'Lettres en attente : $count';
  }

  @override
  String textLibraryMcMailNext(String minutes) {
    return 'Prochaine lettre dans $minutes min';
  }

  @override
  String get textLibraryMcTakeLetter => 'Prendre la lettre';

  @override
  String get textLibraryMcNewMail => 'Vous avez du courrier !';

  @override
  String get textLibraryMcNewMailBody => 'Une lettre attend dans la boîte';

  @override
  String get textLibraryMcLetterOpen => 'Cliquez sur la lettre pour l’ouvrir';

  @override
  String get textLibraryMcLetterTitle => 'Cher lecteur,';

  @override
  String get textLibraryMcLetterBody =>
      'Merci de prendre soin de la bibliothèque. Voici un petit quelque chose pour votre coffre.';

  @override
  String get textLibraryMcLetterSign => '— La Poste de la bibliothèque';

  @override
  String get textLibraryMcLetterTake => 'Prendre les pièces';

  @override
  String textLibraryMcCoins(String count) {
    return '$count pièces';
  }

  @override
  String get textLibraryMcHandHint =>
      'Rangez les pièces dans votre coffre, dans la bibliothèque près du feu';

  @override
  String get textLibraryMcVault => 'Coffre-fort';

  @override
  String get textLibraryMcVaultOpen => 'Ouvrir le coffre';

  @override
  String textLibraryMcVaultPut(String count) {
    return 'Ranger $count pièces dans le coffre';
  }

  @override
  String textLibraryMcVaultDeposited(String count) {
    return '+$count pièces rangées';
  }

  @override
  String get textLibraryMcVaultEmpty =>
      'Rien ici pour l’instant. La poste apporte des pièces toutes les demi-heures.';

  @override
  String get textLibraryMcTraderName => 'Marchand ambulant';

  @override
  String get textLibraryMcTraderArrived => 'Un marchand ambulant est arrivé';

  @override
  String get textLibraryMcTraderArrivedBody =>
      'Son étal est ouvert devant la maison';

  @override
  String get textLibraryMcTraderLeaving => 'Le marchand remballe';

  @override
  String textLibraryMcTraderLeavingBody(String minutes) {
    return 'Il part dans $minutes min';
  }

  @override
  String get textLibraryMcTraderGone => 'Le marchand ambulant est reparti';

  @override
  String get textLibraryMcTraderTrade => 'Commercer avec le marchand ambulant';

  @override
  String get textLibraryMcTraderStall => 'Étal de marché';

  @override
  String textLibraryMcTraderAway(String minutes) {
    return 'Le marchand revient dans $minutes min';
  }

  @override
  String get textLibraryMcTraderBusy => 'Le marchand s’installe';

  @override
  String get textLibraryMcPetDog => 'Caresser le chien';

  @override
  String get textLibraryMcPetCat => 'Caresser le chat';

  @override
  String get textLibraryMcPetFish => 'Nourrir le poisson';

  @override
  String textLibraryMcShopLeaves(String minutes) {
    return 'Part dans $minutes min';
  }

  @override
  String textLibraryMcShopBuy(String count) {
    return 'Acheter pour $count pièces';
  }

  @override
  String get textLibraryMcShopTooPoor => 'Pas assez de pièces';

  @override
  String textLibraryMcShopOwned(String count) {
    return 'Dans votre caisse : $count';
  }

  @override
  String textLibraryMcShopPlaced(String count) {
    return 'Placés : $count';
  }

  @override
  String textLibraryMcShopWallet(String total, String hand, String vault) {
    return '$total pièces · en main $hand · au coffre $vault';
  }

  @override
  String textLibraryMcShopBought(String item) {
    return 'Acheté : $item';
  }

  @override
  String get textLibraryMcShopBoughtBody => 'Appuyez sur B pour le placer';

  @override
  String get textLibraryMcShopBoughtTouch =>
      'Touchez-le dans la barre pour le placer';

  @override
  String get textLibraryMcWhereInside => 'Pour l’intérieur';

  @override
  String get textLibraryMcWhereOutside => 'Pour l’extérieur';

  @override
  String get textLibraryMcWhereBoth => 'Pour l’intérieur ou l’extérieur';

  @override
  String get textLibraryMcItemBed => 'Lit douillet';

  @override
  String get textLibraryMcItemAquarium => 'Aquarium';

  @override
  String get textLibraryMcItemGramophone => 'Gramophone';

  @override
  String get textLibraryMcItemCandelabra => 'Candélabre';

  @override
  String get textLibraryMcItemSwing => 'Balancelle';

  @override
  String get textLibraryMcItemBirdbath => 'Bain pour oiseaux';

  @override
  String get textLibraryMcItemBeehive => 'Ruche sur poteau';

  @override
  String get textLibraryMcItemTelescope => 'Télescope';

  @override
  String get textLibraryMcDescBed =>
      'Un lit en épicéa avec un édredon en patchwork. Vous pouvez vous y allonger.';

  @override
  String get textLibraryMcDescAquarium =>
      'Un aquarium éclairé avec du sable, du varech et trois poissons tropicaux.';

  @override
  String get textLibraryMcDescGramophone =>
      'Joue un petit air de boîte à musique quand vous cliquez dessus.';

  @override
  String get textLibraryMcDescCandelabra =>
      'En fer forgé, avec trois bougies vacillantes.';

  @override
  String get textLibraryMcDescSwing =>
      'Un banc à lattes suspendu à des chaînes qui se balance au vent. Asseyez-vous dessus.';

  @override
  String get textLibraryMcDescBirdbath =>
      'Un socle en pierre avec une vasque d’eau peu profonde.';

  @override
  String get textLibraryMcDescBeehive =>
      'Un nid d’abeilles sur un poteau, avec des abeilles qui bourdonnent autour.';

  @override
  String get textLibraryMcDescTelescope =>
      'Regardez à travers le ciel et la mer de nuages.';

  @override
  String get textLibraryMcBuildHint =>
      'Cliquez pour placer · R pour tourner · clic droit sur un objet pour le ramasser · B pour terminer';

  @override
  String get textLibraryMcBuildHintTouch =>
      'Touchez le sol pour le placer · marchez avec les flèches';

  @override
  String get textLibraryMcPickHint =>
      'Cliquez sur un objet pour le remettre dans votre caisse · B pour terminer';

  @override
  String get textLibraryMcCrateHint =>
      'Appuyez sur B pour placer vos nouveaux meubles';

  @override
  String get textLibraryMcBuildRotate => 'Tourner (R)';

  @override
  String get textLibraryMcBuildPick => 'Ramasser (X)';

  @override
  String get textLibraryMcBuildDone => 'Terminé (B)';

  @override
  String get textLibraryMcCantPlace => 'Ça ne rentre pas ici';

  @override
  String get textLibraryMcPutBack => 'De retour dans votre caisse';

  @override
  String textLibraryMcPutBackBody(String item) {
    return '$item ne rentrait plus';
  }

  @override
  String get textLibraryMcLieDown => 'S’allonger';

  @override
  String get textLibraryMcPlayMusic => 'Jouer un air';

  @override
  String get textLibraryMcStopMusic => 'Arrêter la musique';

  @override
  String get textLibraryMcLookThrough => 'Regarder dans le télescope';

  @override
  String get textLibraryMcStepBack => 'Reculer';

  @override
  String get textLibraryMcScopeHint =>
      'Bougez la souris pour regarder autour · Maj ou Espace pour reculer';

  @override
  String get textLibraryMcPcTitle => 'Bureau des critiques';

  @override
  String get textLibraryMcPcUse => 'Utiliser l’ordinateur';

  @override
  String get textLibraryMcPcIntro =>
      'Envoyez un livre que vous avez écrit au critique. Un bon livre rapporte de 1 à 50 pièces ; sinon, la lettre apporte des conseils pour l’améliorer.';

  @override
  String get textLibraryMcPcPick => 'Choisissez un livre à envoyer :';

  @override
  String get textLibraryMcPcNoBooks =>
      'Aucun livre à envoyer pour l’instant. Écrivez-en un d’abord.';

  @override
  String get textLibraryMcPcSend => 'Envoyer au critique';

  @override
  String get textLibraryMcPcSending => 'Envoi…';

  @override
  String get textLibraryMcPcSent => 'Votre livre a été envoyé !';

  @override
  String textLibraryMcPcSentBody(String minutes) {
    return 'Il va être évalué. Une lettre arrivera dans votre boîte demain, dans environ $minutes min.';
  }

  @override
  String textLibraryMcPcWaiting(String title) {
    return 'En attente de la critique de « $title »';
  }

  @override
  String textLibraryMcPcWaitingBody(String minutes) {
    return 'La lettre arrive dans environ $minutes min. Le critique lit un livre à la fois.';
  }

  @override
  String get textLibraryMcPcSame =>
      'Cette version a déjà été critiquée. Modifiez le livre pour l’envoyer à nouveau.';

  @override
  String get textLibraryMcPcFailed => 'Impossible de l’envoyer';

  @override
  String get textLibraryMcPcTimeout =>
      'Le critique a mis trop de temps. Réessayez plus tard.';

  @override
  String get textLibraryMcPcLogOff => 'Se déconnecter';

  @override
  String get textLibraryMcReviewArrived => 'Votre critique est arrivée';

  @override
  String get textLibraryMcReviewArrivedBody =>
      'La lettre est dans la boîte aux lettres';

  @override
  String textLibraryMcReviewTitle(String title) {
    return 'Une critique de « $title »';
  }

  @override
  String get textLibraryMcReviewTips => 'Pour l’améliorer :';

  @override
  String get textLibraryMcReviewNoBetter =>
      'Il se lit bien, mais il n’est pas meilleur que la dernière fois : pas de nouvelles pièces.';

  @override
  String get textLibraryMcReviewSign => '— Le bureau des critiques';

  @override
  String get textLibraryMcReviewThanks => 'Merci';

  @override
  String get textLibraryMcReviewEmpty => 'Ce livre est vide.';

  @override
  String get textLibraryMcReviewSignIn =>
      'Connectez-vous à un compte luma approuvé pour envoyer des livres au critique.';

  @override
  String get textLibraryMcReviewUnreachable =>
      'Impossible de joindre le serveur luma. Vérifiez votre connexion et réessayez.';

  @override
  String get textLibraryMcClassroom => 'Salle de classe';

  @override
  String get textLibraryMcClassLocked => 'Fermée à clé';

  @override
  String get textLibraryMcClassLockedNova =>
      'La salle de classe fait partie de Nova';

  @override
  String get textLibraryMcClassLockedSignin =>
      'Connecte-toi à un compte luma pour l’ouvrir';

  @override
  String get textLibraryMcClassLockedOffline =>
      'Le serveur luma est injoignable pour le moment';

  @override
  String get textLibraryMcClassDown => 'Descendre à la cave';

  @override
  String get textLibraryMcClassUp => 'Monter à l’échelle';

  @override
  String get textLibraryMcClassSit => 'S’asseoir pour un cours';

  @override
  String get textLibraryMcClassBoard => 'Tableau noir';

  @override
  String get textLibraryMcClassCountryTitle =>
      'Dans quel pays vas-tu à l’école ?';

  @override
  String get textLibraryMcClassCountryNote =>
      'Tu ne peux le choisir qu’une seule fois.';

  @override
  String get textLibraryMcClassCountryOther => 'Ailleurs';

  @override
  String get textLibraryMcClassCountryName => 'Pays';

  @override
  String get textLibraryMcClassCountrySet => 'Choisir le pays';

  @override
  String textLibraryMcClassCountryConfirm(String name) {
    return 'Choisir $name comme pays ? Tu ne pourras plus le changer.';
  }

  @override
  String textLibraryMcClassCountryIs(String name) {
    return 'Pays : $name';
  }

  @override
  String get textLibraryMcClassSchool => 'École';

  @override
  String get textLibraryMcClassYear => 'Classe';

  @override
  String get textLibraryMcClassLevel => 'Filière';

  @override
  String get textLibraryMcClassSubject => 'Matière';

  @override
  String get textLibraryMcClassPublisher => 'Manuel (éditeur)';

  @override
  String get textLibraryMcClassChapter => 'Chapitre';

  @override
  String get textLibraryMcClassParagraph => 'Section';

  @override
  String get textLibraryMcClassTopic => 'De quoi parle la section ?';

  @override
  String get textLibraryMcClassTopicHint => 'ex. le théorème de Pythagore';

  @override
  String get textLibraryMcClassStart => 'Commencer le cours';

  @override
  String get textLibraryMcClassNeedAll =>
      'Remplis tous les champs pour commencer.';

  @override
  String get textLibraryMcClassAsking => 'Le professeur écrit une question…';

  @override
  String textLibraryMcClassQuestion(String number) {
    return 'Question $number';
  }

  @override
  String get textLibraryMcClassAnswerHint => 'Ta réponse';

  @override
  String get textLibraryMcClassNext => 'Question suivante';

  @override
  String get textLibraryMcClassPrev => 'Précédente';

  @override
  String get textLibraryMcClassSkip => 'Passer';

  @override
  String get textLibraryMcClassHandIn => 'Rendre';

  @override
  String get textLibraryMcClassLeave => 'Partir';

  @override
  String get textLibraryMcClassSkipped => 'Passée';

  @override
  String get textLibraryMcClassChecking => 'Le professeur corrige ton travail…';

  @override
  String get textLibraryMcClassNothing =>
      'Réponds d’abord à au moins une question.';

  @override
  String textLibraryMcClassHandInConfirm(String count) {
    return 'Rendre $count réponses ? Les questions passées ne sont pas corrigées.';
  }

  @override
  String get textLibraryMcClassLast =>
      'C’était la dernière question de ce cours.';

  @override
  String get textLibraryMcClassCorrect => 'Juste';

  @override
  String get textLibraryMcClassPartly => 'En partie juste';

  @override
  String get textLibraryMcClassWrong => 'Pas juste';

  @override
  String get textLibraryMcClassUnchecked => 'Non corrigée';

  @override
  String textLibraryMcClassScore(String right, String partly, String wrong) {
    return '$right justes, $partly en partie, $wrong fausses';
  }

  @override
  String get textLibraryMcClassYourAnswer => 'Toi';

  @override
  String get textLibraryMcClassModel => 'Réponse';

  @override
  String get textLibraryMcClassAgain => 'Même section encore';

  @override
  String get textLibraryMcClassNew => 'Nouveau cours';

  @override
  String get textLibraryMcClassFailed => 'Ça n’a pas marché';

  @override
  String get textLibraryMcClassRetry => 'Réessayer';

  @override
  String get textLibraryMcClassTimeout =>
      'Le professeur a mis trop de temps. Réessaie.';

  @override
  String get textLibraryMcClassCancel => 'Annuler';

  @override
  String get textLibraryMcClassOk => 'OK';

  @override
  String get pluginAddToHomeScreen => 'Ajouter à l\'écran d\'accueil';

  @override
  String get pluginAddToHomeScreenUnsupported =>
      'Votre lanceur ne peut pas ajouter de widgets depuis une app. Appuyez longuement sur l\'écran d\'accueil, ouvrez Widgets et choisissez luma.';
}
