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
    return 'Impossible d’enregistrer votre accueil : $error';
  }

  @override
  String get homeAddSheetTitle => 'Faites de la place pour l’essentiel';

  @override
  String get homeEditLayout => 'Modifier la disposition';

  @override
  String get homeEditingTitle => 'Installez-vous chez vous';

  @override
  String get homePhoneLayout => 'Disposition téléphone';

  @override
  String get homeDesktopLayout => 'Disposition ordinateur et portable';

  @override
  String get homeResetDashboard => 'Rétablir le tableau de bord d’origine';

  @override
  String get homeAddTile => 'Ajouter une tuile';

  @override
  String get homeSaveLayout => 'Enregistrer la disposition';

  @override
  String get homeEdit => 'Modifier l’accueil';

  @override
  String get homeDragHint =>
      'Faites glisser une tuile par son titre. Faites glisser son coin inférieur pour la redimensionner. Tout s’aligne automatiquement ; les tuiles qui se chevauchent descendent.';

  @override
  String get homeUnavailable => 'Indisponible';

  @override
  String get homeInspiration => 'Un peu d’inspiration';

  @override
  String get homeEditSummary => 'Modifier le résumé';

  @override
  String get homeCashBalance => 'Solde en espèces';

  @override
  String get homeCustomText => 'Texte personnalisé';

  @override
  String get homeSummaryTitle => 'Résumé d’accueil';

  @override
  String get homeSummaryDescription =>
      'Votre message d’accueil reste toujours en haut. Choisissez ce qui s’affiche en dessous.';

  @override
  String get homeShowInGreeting => 'Afficher dans le message d’accueil';

  @override
  String get homeSummaryLabel => 'Libellé';

  @override
  String get homeSummaryLabelHint => 'Priorité du jour';

  @override
  String get homeSummaryText => 'Texte';

  @override
  String get homeSummaryTextHint => 'Prenez le temps pour l’essentiel.';

  @override
  String get homeApply => 'Appliquer';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get homeTileShortcut => 'Raccourci d’application';

  @override
  String get homeTileRecentActivity => 'Activité récente';

  @override
  String get homeTileFinanceOverview => 'Aperçu des finances';

  @override
  String get homeTilePinnedNote => 'Note épinglée';

  @override
  String get homeTilePluginShortcut => 'Raccourci de module';

  @override
  String get homeTileMinecraftInstance => 'Instance Minecraft';

  @override
  String get homeTileErrands => 'Courses';

  @override
  String get homeTileStockChart => 'Graphique boursier';

  @override
  String get homeTileGithubActivity => 'Activité GitHub';

  @override
  String get homeTileGithubIssues => 'Tickets GitHub';

  @override
  String get homeTileAiUsage => 'Utilisation de l’IA';

  @override
  String get homeTileCalculator => 'Calculatrice';

  @override
  String get homeTileClockDate => 'Horloge et date';

  @override
  String get homeTileFocusTimer => 'Minuteur de concentration';

  @override
  String get homeTileQuickActions => 'Actions rapides';

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
  String get textLibraryBack => 'Retour';

  @override
  String get textLibraryBodyHint => 'Écrivez votre texte…';

  @override
  String get textLibraryBold => 'Gras';

  @override
  String get textLibraryCancel => 'Annuler';

  @override
  String get textLibraryClearFormatting => 'Effacer la mise en forme';

  @override
  String get textLibraryColor => 'Couleur';

  @override
  String get textLibraryCover => 'Couverture';

  @override
  String get textLibraryCreate => 'Créer';

  @override
  String get textLibraryDefaultInk => 'Encre par défaut';

  @override
  String get textLibraryDelete => 'Supprimer';

  @override
  String textLibraryDeleteSubjectTitle(String name) {
    return 'Supprimer le sujet « $name » ?';
  }

  @override
  String textLibraryDeleteSubjectBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ses $count textes',
      one: 'son unique texte',
      zero: 'aucun texte',
    );
    return 'Supprimer ce sujet et $_temp0 ?';
  }

  @override
  String get textLibraryDeleteTextBody =>
      'Ce texte sera définitivement supprimé.';

  @override
  String textLibraryDeleteTextTitle(String title) {
    return 'Supprimer « $title » ?';
  }

  @override
  String textLibraryEdited(String date) {
    return 'Modifié le $date';
  }

  @override
  String get textLibraryInk => 'Encre';

  @override
  String get textLibraryItalic => 'Italique';

  @override
  String textLibraryMcBooks(String count) {
    return '$count livres';
  }

  @override
  String get textLibraryMcBuild => 'Construire';

  @override
  String get textLibraryMcBuiltIn => 'Intégré';

  @override
  String get textLibraryMcBurn => 'Brûler';

  @override
  String get textLibraryMcBurnConfirm =>
      'Brûler ce livre ? Cette action est irréversible.';

  @override
  String get textLibraryMcChooseSlot =>
      'Choisissez un emplacement sur l’étagère';

  @override
  String get textLibraryMcDone => 'Terminé';

  @override
  String get textLibraryMcDownload => 'Télécharger les ressources Minecraft';

  @override
  String get textLibraryMcDownloadFailed =>
      'Impossible de télécharger les ressources Minecraft.';

  @override
  String get textLibraryMcDownloadNote =>
      'Les ressources Minecraft sont téléchargées depuis Mojang et mises en cache sur cet appareil.';

  @override
  String get textLibraryMcEmptyHall =>
      'Votre salle est vide. Créez un sujet pour commencer.';

  @override
  String get textLibraryMcEmptySlot => 'Emplacement vide';

  @override
  String get textLibraryMcFailedAndroid =>
      'Impossible d’ouvrir la bibliothèque Minecraft sur Android.';

  @override
  String get textLibraryMcFailedWindows =>
      'Impossible d’ouvrir la bibliothèque Minecraft sur Windows.';

  @override
  String get textLibraryMcLoading => 'Chargement de la bibliothèque Minecraft…';

  @override
  String get textLibraryMcLost =>
      'La connexion à la bibliothèque Minecraft a été perdue.';

  @override
  String get textLibraryMcMoveHint =>
      'Déplacer ce livre vers une autre étagère.';

  @override
  String get textLibraryMcNewCase => 'Nouveau meuble';

  @override
  String get textLibraryMcNewCaseTitle => 'Créer un meuble';

  @override
  String textLibraryMcPage(String page, String total) {
    return 'Page $page sur $total';
  }

  @override
  String get textLibraryMcQuality => 'Qualité de rendu';

  @override
  String get textLibraryMcQualityHigh => 'Élevée';

  @override
  String get textLibraryMcQualityLow => 'Faible';

  @override
  String get textLibraryMcRedo => 'Rétablir';

  @override
  String get textLibraryMcRetry => 'Réessayer';

  @override
  String get textLibraryMcSaveFailed => 'Impossible d’enregistrer le livre.';

  @override
  String get textLibraryMcSettings => 'Paramètres de la salle';

  @override
  String textLibraryMcShelfPage(String page, String total) {
    return 'Page d’étagère $page sur $total';
  }

  @override
  String get textLibraryMcSign => 'Signer le livre';

  @override
  String get textLibraryMcSignAndShelve => 'Signer et ranger';

  @override
  String get textLibraryMcSignTitle => 'Signer ce livre ?';

  @override
  String get textLibraryMcTime => 'Heure';

  @override
  String get textLibraryMcTimeClock => 'Mon horloge';

  @override
  String get textLibraryMcTimeCycle => 'Jour et nuit';

  @override
  String get textLibraryMcTimeDay => 'Toujours le jour';

  @override
  String get textLibraryMcTimeNight => 'Toujours la nuit';

  @override
  String get textLibraryMcUndo => 'Annuler';

  @override
  String get textLibraryMcUntitled => 'Sans titre';

  @override
  String textLibraryMcVanilla(String version) {
    return 'Minecraft $version';
  }

  @override
  String get textLibraryMcWalkHint =>
      'WASD pour marcher · cliquez pour regarder autour · cliquez sur une bibliothèque, une chaise ou une porte pour l’utiliser · Échap libère la souris';

  @override
  String get textLibraryMcLookHint => 'Cliquez pour regarder autour';

  @override
  String get textLibraryMcStandHint => 'Maj ou Espace pour vous lever';

  @override
  String get textLibraryMcStandUp => 'Se lever';

  @override
  String get textLibraryMcSit => 'S’asseoir';

  @override
  String get textLibraryMcOpenDoor => 'Ouvrir la porte';

  @override
  String get textLibraryMcCloseDoor => 'Fermer la porte';

  @override
  String get textLibraryMcOpenDrawer => 'Ouvrir le tiroir';

  @override
  String get textLibraryMcCloseDrawer => 'Fermer le tiroir';

  @override
  String get textLibraryMcShapes => 'Formes';

  @override
  String get textLibraryMcShapeCircle => 'Cercle';

  @override
  String get textLibraryMcShapeSquare => 'Carré';

  @override
  String get textLibraryMcShapeTriangle => 'Triangle';

  @override
  String get textLibraryMcShapeStar => 'Étoile';

  @override
  String get textLibraryMcShapeHeart => 'Cœur';

  @override
  String get textLibraryMcShapeLine => 'Ligne';

  @override
  String get textLibraryMcShapeFill => 'Plein ou contour';

  @override
  String get textLibraryMcDrawHint =>
      'glissez sur la page pour la dessiner · clic droit sur un dessin pour le supprimer';

  @override
  String textLibraryMcSkinCurrent(String name) {
    return 'Apparence : $name';
  }

  @override
  String get textLibraryMcSkinDefault => 'Peau par défaut';

  @override
  String get textLibraryMcSkinYours => 'la vôtre';

  @override
  String get textLibraryMcSkinImport => 'Importer une peau…';

  @override
  String get textLibraryMcSkinName => 'Nom Minecraft…';

  @override
  String get textLibraryMcSkinNameTitle => 'Votre pseudo Minecraft';

  @override
  String get textLibraryMcSkinNameHint => 'Pseudo';

  @override
  String get textLibraryMcSkinUse => 'Utiliser la peau';

  @override
  String get textLibraryMcSkinFailed => 'Impossible de charger cette peau.';

  @override
  String get textLibraryMcWriteHint => 'Écrivez votre livre ici…';

  @override
  String get textLibraryModeClassic => 'Classique';

  @override
  String get textLibraryModeMinecraft => 'Salle Minecraft';

  @override
  String get textLibraryMoveTo => 'Déplacer vers';

  @override
  String get textLibraryMoveToTitle => 'Déplacer le texte vers un sujet';

  @override
  String get textLibraryNewSubject => 'Nouveau sujet';

  @override
  String get textLibraryNewText => 'Nouveau texte';

  @override
  String textLibraryNoMatches(String query) {
    return 'Aucun texte ne correspond à « $query »';
  }

  @override
  String get textLibraryNoSubjects => 'Aucun sujet pour le moment';

  @override
  String get textLibraryNoSubjectsSub =>
      'Créez un sujet pour organiser vos textes.';

  @override
  String get textLibraryNoTexts => 'Aucun texte pour le moment';

  @override
  String get textLibraryNoTextsSub =>
      'Ajoutez un texte à ce sujet pour commencer.';

  @override
  String get textLibraryRename => 'Renommer';

  @override
  String get textLibraryRenameSubject => 'Renommer le sujet';

  @override
  String get textLibrarySave => 'Enregistrer';

  @override
  String get textLibrarySaved => 'Enregistré';

  @override
  String get textLibrarySaving => 'Enregistrement…';

  @override
  String get textLibrarySearchHint => 'Rechercher des textes';

  @override
  String get textLibrarySpineHint =>
      'Un court libellé affiché sur le dos du livre';

  @override
  String get textLibrarySpineLabel => 'Libellé du dos';

  @override
  String get textLibraryStrike => 'Barré';

  @override
  String get textLibrarySubjectNameHint => 'Nom du sujet';

  @override
  String get textLibrarySubjectNameRequired => 'Saisissez un nom de sujet.';

  @override
  String get textLibrarySubjects => 'Sujets';

  @override
  String textLibraryTextCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count textes',
      one: '1 texte',
    );
    return '$_temp0';
  }

  @override
  String get textLibraryTitleHint => 'Titre';

  @override
  String get textLibraryUnderline => 'Souligné';

  @override
  String get audioToolsTitle => 'Outils audio';

  @override
  String get audioToolsSubtitle =>
      'Façonnez votre voix avec un égaliseur et envoyez-la vers Discord, OBS ou toute application qui utilise un micro.';

  @override
  String get audioToolsWindowsOnly => 'Windows uniquement';

  @override
  String get audioToolsWindowsOnlyBody =>
      'Outils audio achemine votre micro en temps réel, ce que luma ne peut faire que dans l\'application de bureau Windows.';

  @override
  String get audioToolsStart => 'Démarrer';

  @override
  String get audioToolsStop => 'Arrêter';

  @override
  String get audioToolsLive => 'En direct';

  @override
  String get audioToolsOff => 'Désactivé';

  @override
  String get audioToolsRouting => 'Routage';

  @override
  String get audioToolsMicrophone => 'Microphone';

  @override
  String get audioToolsSendTo => 'Envoyer vers';

  @override
  String audioToolsWindowsDefault(String name) {
    return 'Par défaut de Windows ($name)';
  }

  @override
  String get audioToolsWindowsDefaultPlain => 'Par défaut de Windows';

  @override
  String get audioToolsRefreshDevices => 'Actualiser les appareils';

  @override
  String get audioToolsVirtualCableTag => 'Câble virtuel';

  @override
  String get audioToolsNotACable =>
      'Cette sortie est un haut-parleur, pas un câble virtuel : les autres applications ne l\'entendront pas comme un micro.';

  @override
  String get audioToolsHearMyself => 'M\'entendre';

  @override
  String get audioToolsHearMyselfBody =>
      'Diffuser aussi le résultat sur vos haut-parleurs ou votre casque par défaut.';

  @override
  String get audioToolsBypass => 'Contourner l\'égaliseur';

  @override
  String get audioToolsBypassBody =>
      'Envoyer votre voix sans traitement, pour comparer.';

  @override
  String get audioToolsAutoStart => 'Démarrer avec luma';

  @override
  String get audioToolsAutoStartBody =>
      'Activer le modificateur de voix dès l\'ouverture de luma.';

  @override
  String get audioToolsDiscordTitle => 'Utiliser dans Discord';

  @override
  String get audioToolsCableFound => 'Câble virtuel détecté';

  @override
  String get audioToolsCableMissingTitle =>
      'Configuration unique : un câble virtuel';

  @override
  String get audioToolsCableMissingBody =>
      'Windows ne peut pas ajouter de nouveau micro sans pilote, donc luma envoie votre voix traitée via un câble virtuel gratuit. Installez VB-CABLE une fois, puis revenez ici. Discord, OBS et les jeux le verront comme un micro.';

  @override
  String get audioToolsGetCable => 'Obtenir VB-CABLE';

  @override
  String get audioToolsInstalledCheck => 'Je l\'ai installé';

  @override
  String audioToolsStepSendTo(String device) {
    return 'Réglez « Envoyer vers » sur $device.';
  }

  @override
  String get audioToolsUseCable => 'Utiliser';

  @override
  String audioToolsStepDiscord(String device) {
    return 'Dans Discord, ouvrez Paramètres → Voix et vidéo et réglez Périphérique d\'entrée sur $device.';
  }

  @override
  String get audioToolsStepStart =>
      'Appuyez sur Démarrer. Si l\'effet semble étouffé, désactivez la suppression de bruit de Discord.';

  @override
  String get audioToolsErrDeviceMissing =>
      'Ce périphérique audio n\'est plus connecté. Choisissez-en un autre.';

  @override
  String get audioToolsErrDeviceInUse =>
      'Une autre application utilise ce périphérique en mode exclusif.';

  @override
  String get audioToolsErrDeviceLost =>
      'Le périphérique audio a été déconnecté, le modificateur de voix s\'est donc arrêté.';

  @override
  String get audioToolsErrMicBlocked =>
      'Windows bloque le microphone. Activez « Autoriser les applications de bureau à accéder à votre microphone » dans les paramètres de confidentialité.';

  @override
  String get audioToolsErrFailed =>
      'Impossible de démarrer l\'audio. Essayez un autre périphérique.';

  @override
  String get audioToolsOpenSettings => 'Ouvrir les paramètres';

  @override
  String get audioToolsDismiss => 'Ignorer';

  @override
  String get audioToolsEqualizer => 'Égaliseur';

  @override
  String get audioToolsReset => 'Réinitialiser';

  @override
  String get audioToolsEqHint =>
      'Faites glisser un point pour façonner votre voix. Faites défiler sur le graphique pour élargir ou resserrer la bande sélectionnée.';

  @override
  String get audioToolsPreamp => 'Préampli';

  @override
  String get audioToolsFrequency => 'Fréquence';

  @override
  String get audioToolsGain => 'Gain';

  @override
  String get audioToolsWidth => 'Largeur (Q)';

  @override
  String get audioToolsBandOn => 'Activé';

  @override
  String get audioToolsTypeHighPass => 'Coupe-bas';

  @override
  String get audioToolsTypeLowShelf => 'Plateau bas';

  @override
  String get audioToolsTypePeak => 'Cloche';

  @override
  String get audioToolsTypeHighShelf => 'Plateau haut';

  @override
  String get audioToolsTypeLowPass => 'Coupe-haut';

  @override
  String get audioToolsPresetFlat => 'Plat';

  @override
  String get audioToolsPresetClear => 'Clair';

  @override
  String get audioToolsPresetDeep => 'Grave';

  @override
  String get audioToolsPresetRadio => 'Radio';

  @override
  String get audioToolsPresetTelephone => 'Téléphone';

  @override
  String get audioToolsPresetMegaphone => 'Mégaphone';

  @override
  String get audioToolsPresetMuffled => 'À travers un mur';

  @override
  String get audioToolsPresetTiny => 'Minuscule';

  @override
  String get audioToolsPresetCustom => 'Personnalisé';

  @override
  String get audioToolsSystemTitle => 'Utiliser dans Discord';

  @override
  String audioToolsSystemBody(String mic) {
    return 'luma peut appliquer l\'égaliseur directement sur $mic, pour que Discord, OBS et les jeux l\'entendent sans logiciel supplémentaire. Windows demande une autorisation administrateur une seule fois. Le son peut couper quelques secondes pendant que luma effectue la bascule et vérifie que le micro fonctionne toujours ; sinon, luma rétablit immédiatement le micro.';
  }

  @override
  String get audioToolsSystemEnable => 'Activer pour ce micro';

  @override
  String audioToolsSystemActive(String mic) {
    return 'Activé pour $mic';
  }

  @override
  String get audioToolsSystemPaused => 'En pause';

  @override
  String get audioToolsSystemEveryApp =>
      'Égaliseur dans toutes les applications';

  @override
  String get audioToolsSystemEveryAppBody =>
      'La mise en pause ne demande aucune autorisation administrateur et conserve toute la configuration.';

  @override
  String audioToolsSystemDiscordHint(String mic) {
    return 'Dans Discord, gardez $mic comme périphérique d\'entrée. Si l\'égaliseur semble étouffé, désactivez la suppression de bruit et le contrôle automatique du gain de Discord.';
  }

  @override
  String get audioToolsSystemOutdated =>
      'luma a mis à jour son moteur d\'égaliseur. Appliquez la mise à jour pour garder ce micro synchronisé.';

  @override
  String get audioToolsSystemUpdate => 'Mettre à jour';

  @override
  String get audioToolsSystemRemove => 'Désactiver et restaurer';

  @override
  String get audioToolsSystemCancelled =>
      'Windows n\'a pas accordé l\'autorisation, donc rien n\'a changé.';

  @override
  String get audioToolsSystemFailed =>
      'Cela n\'a pas fonctionné, et le micro est resté tel quel.';

  @override
  String get audioToolsSystemRestart =>
      'Presque terminé : redémarrez votre PC pour que Windows prenne la modification en compte.';

  @override
  String get audioToolsSystemNoDevice =>
      'Ce micro n\'est pas connecté pour le moment.';

  @override
  String get audioToolsSystemIncompatible =>
      'Windows ne peut pas exécuter l\'égaliseur de luma sur ce micro, donc luma l\'a remis exactement dans son état initial. Il fonctionne toujours normalement. Vous pouvez continuer à utiliser l\'égaliseur dans luma.';

  @override
  String get audioToolsSystemMicSilent =>
      'luma n\'a pas pu enregistrer depuis ce micro pour le tester, donc rien n\'a changé. Fermez les applications qui pourraient l\'utiliser et vérifiez que Windows autorise les applications à accéder au micro.';

  @override
  String get audioToolsSystemMissing =>
      'Des composants de luma sont manquants. Réinstallez luma et réessayez.';

  @override
  String get audioToolsSystemNoMic =>
      'Aucun microphone détecté. Branchez-en un et actualisez la liste des périphériques.';

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

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonRemove => 'Retirer';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonOk => 'OK';

  @override
  String get commonDone => 'Terminé';

  @override
  String get commonAdd => 'Ajouter';

  @override
  String get commonEdit => 'Modifier';

  @override
  String get commonRename => 'Renommer';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonTryAgain => 'Réessayer';

  @override
  String get commonBack => 'Retour';

  @override
  String get commonNext => 'Suivant';

  @override
  String get commonPrevious => 'Précédent';

  @override
  String get commonContinue => 'Continuer';

  @override
  String get commonConfirm => 'Confirmer';

  @override
  String get commonYes => 'Oui';

  @override
  String get commonNo => 'Non';

  @override
  String get commonCopy => 'Copier';

  @override
  String get commonCopied => 'Copié';

  @override
  String get commonCopiedToClipboard => 'Copié dans le presse-papiers';

  @override
  String get commonPaste => 'Coller';

  @override
  String get commonSearch => 'Rechercher';

  @override
  String get commonSearchHint => 'Rechercher…';

  @override
  String get commonRefresh => 'Actualiser';

  @override
  String get commonLoading => 'Chargement…';

  @override
  String get commonOpen => 'Ouvrir';

  @override
  String get commonCreate => 'Créer';

  @override
  String get commonImport => 'Importer';

  @override
  String get commonExport => 'Exporter';

  @override
  String get commonShare => 'Partager';

  @override
  String get commonDownload => 'Télécharger';

  @override
  String get commonUpload => 'Téléverser';

  @override
  String get commonSettings => 'Paramètres';

  @override
  String get commonName => 'Nom';

  @override
  String get commonTitle => 'Titre';

  @override
  String get commonDescription => 'Description';

  @override
  String get commonNotes => 'Notes';

  @override
  String get commonDate => 'Date';

  @override
  String get commonTime => 'Heure';

  @override
  String get commonAmount => 'Montant';

  @override
  String get commonTotal => 'Total';

  @override
  String get commonAll => 'Tout';

  @override
  String get commonNone => 'Aucun';

  @override
  String get commonOther => 'Autre';

  @override
  String get commonUnknown => 'Inconnu';

  @override
  String get commonUntitled => 'Sans titre';

  @override
  String get commonOn => 'Activé';

  @override
  String get commonOff => 'Désactivé';

  @override
  String get commonEnable => 'Activer';

  @override
  String get commonDisable => 'Désactiver';

  @override
  String get commonStart => 'Démarrer';

  @override
  String get commonStop => 'Arrêter';

  @override
  String get commonPause => 'Pause';

  @override
  String get commonResume => 'Reprendre';

  @override
  String get commonReset => 'Réinitialiser';

  @override
  String get commonClear => 'Effacer';

  @override
  String get commonApply => 'Appliquer';

  @override
  String get commonSend => 'Envoyer';

  @override
  String get commonUndo => 'Annuler';

  @override
  String get commonRedo => 'Rétablir';

  @override
  String get commonMore => 'Plus';

  @override
  String get commonShowMore => 'Afficher plus';

  @override
  String get commonShowLess => 'Afficher moins';

  @override
  String get commonError => 'Erreur';

  @override
  String commonErrorDetail(String error) {
    return 'Une erreur s\'est produite : $error';
  }

  @override
  String get commonSomethingWentWrong => 'Une erreur s\'est produite';

  @override
  String get commonSaved => 'Enregistré';

  @override
  String get commonDeleted => 'Supprimé';

  @override
  String get commonNothingHereYet => 'Rien pour l\'instant';

  @override
  String get commonNoResults => 'Aucun résultat';

  @override
  String get commonToday => 'Aujourd\'hui';

  @override
  String get commonYesterday => 'Hier';

  @override
  String get commonTomorrow => 'Demain';

  @override
  String get commonNever => 'Jamais';

  @override
  String get commonJustNow => 'À l\'instant';

  @override
  String commonMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count minutes',
      one: 'il y a 1 minute',
    );
    return '$_temp0';
  }

  @override
  String commonHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count heures',
      one: 'il y a 1 heure',
    );
    return '$_temp0';
  }

  @override
  String commonDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count jours',
      one: 'il y a 1 jour',
    );
    return '$_temp0';
  }

  @override
  String get commonRequired => 'Obligatoire';

  @override
  String get commonOptional => 'Facultatif';

  @override
  String get commonDetails => 'Détails';

  @override
  String get commonHistory => 'Historique';

  @override
  String get commonOverview => 'Vue d\'ensemble';

  @override
  String get commonPreview => 'Aperçu';

  @override
  String get commonHelp => 'Aide';

  @override
  String get commonSelectAll => 'Tout sélectionner';

  @override
  String get commonBrowse => 'Parcourir';

  @override
  String get commonChooseFile => 'Choisir un fichier';

  @override
  String get commonChooseFolder => 'Choisir un dossier';

  @override
  String get commonInstall => 'Installer';

  @override
  String get commonUninstall => 'Désinstaller';

  @override
  String get commonUpdate => 'Mettre à jour';

  @override
  String get commonSignIn => 'Se connecter';

  @override
  String get commonSignOut => 'Se déconnecter';

  @override
  String get commonEmail => 'E-mail';

  @override
  String get commonPassword => 'Mot de passe';

  @override
  String get commonUsername => 'Nom d\'utilisateur';

  @override
  String get commonCategory => 'Catégorie';

  @override
  String get commonType => 'Type';

  @override
  String get commonSize => 'Taille';

  @override
  String get commonStatus => 'Statut';

  @override
  String get commonPrice => 'Prix';

  @override
  String get commonQuantity => 'Quantité';

  @override
  String get commonColor => 'Couleur';

  @override
  String get commonIcon => 'Icône';

  @override
  String get commonFilter => 'Filtrer';

  @override
  String get commonSort => 'Trier';

  @override
  String get commonAccountRequired => 'Compte requis';

  @override
  String get marketplaceLoadFailed =>
      'La liste des plugins n\'a pas pu être chargée';

  @override
  String get marketplaceEmpty => 'Aucun plugin disponible pour l\'instant';

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
  String get marketplaceNoMatches => 'Aucun résultat pour ces filtres';

  @override
  String get marketplaceSearchHint => 'Rechercher un plugin...';

  @override
  String get marketplaceSortRelevance => 'Pertinence';

  @override
  String get marketplaceSortNameAsc => 'Nom (A-Z)';

  @override
  String get marketplaceSortNameDesc => 'Nom (Z-A)';

  @override
  String marketplaceSortBy(String option) {
    return 'Trier par : $option';
  }

  @override
  String get marketplaceRemovePlugin => 'Retirer le plugin';

  @override
  String get marketplaceUpdateAvailable => 'Mise à jour disponible';

  @override
  String get marketplaceUpdating => 'Mise à jour…';

  @override
  String get marketplaceDownloading => 'Téléchargement…';

  @override
  String get marketplaceUpdated => 'Mis à jour';

  @override
  String get marketplaceInstalled => 'Installé';

  @override
  String get marketplaceAbout => 'À propos';

  @override
  String get marketplaceScreenshots => 'Captures d\'écran';

  @override
  String marketplaceRepoUnreachable(String error) {
    return 'Impossible de joindre le dépôt de plugins. Vérifiez votre connexion.\n($error)';
  }

  @override
  String marketplaceRepoError(int status) {
    return 'Le dépôt de plugins a renvoyé une erreur ($status).';
  }

  @override
  String get pluginNameAccountOverview => 'Aperçu du compte';

  @override
  String get pluginNameAiDetector => 'Détecteur d\'IA';

  @override
  String get pluginNameAiUsage => 'Utilisation de l\'IA';

  @override
  String get pluginNameAirlineTycoon => 'Magnat de l\'aviation';

  @override
  String get pluginNameAudioTools => 'Outils audio';

  @override
  String get pluginNameAutoClicker => 'Autoclic';

  @override
  String get pluginNameBulletinBoard => 'Panneau d\'affichage';

  @override
  String get pluginNameCalculator => 'Calculatrice';

  @override
  String get pluginNameCalendar => 'Calendrier';

  @override
  String get pluginNameCardWallet => 'Portefeuille de cartes';

  @override
  String get pluginNameCityPlanner => 'Urbaniste';

  @override
  String get pluginNameCloudFiles => 'Fichiers cloud';

  @override
  String get pluginNameDataManagement => 'Gestion de données';

  @override
  String get pluginNameDeviceHealth => 'Santé de l\'appareil';

  @override
  String get pluginNameErrandManager => 'Gestionnaire de corvées';

  @override
  String get pluginNameFileTree => 'Arborescence des fichiers';

  @override
  String get pluginNameFileViewer => 'Visionneuse de fichiers';

  @override
  String get pluginNameFreeSketch => 'Croquis libre';

  @override
  String get pluginNameGallery => 'Galerie';

  @override
  String get pluginNameGameTools => 'Outils de jeux';

  @override
  String get pluginNameGroceriesList => 'Liste de courses';

  @override
  String get pluginNameMachineLearning => 'Apprentissage automatique';

  @override
  String get pluginNameMindMap => 'Carte mentale';

  @override
  String get pluginNameMinecraftLauncher => 'Lanceur Minecraft';

  @override
  String get pluginNameMoodJournal => 'Journal d\'humeur';

  @override
  String get pluginNameNfcTagEditor => 'Éditeur de tags NFC';

  @override
  String get pluginNamePriceTracker => 'Suivi des prix';

  @override
  String get pluginNameQrCodeGenerator => 'Générateur de QR codes';

  @override
  String get pluginNameRecipeBook => 'Livre de recettes';

  @override
  String get pluginNameSchool => 'École';

  @override
  String get pluginNameSecureChat => 'Chat';

  @override
  String get pluginNameServerTycoon => 'Magnat de l\'hébergement serveur';

  @override
  String get pluginNameSftp => 'SFTP';

  @override
  String get pluginNameSmallGames => 'Petits jeux';

  @override
  String get pluginNameSmartHome => 'Maison connectée';

  @override
  String get pluginNameSpaceColony => 'Colonie spatiale';

  @override
  String get pluginNameSubwayBuilder => 'Bâtisseur de métro';

  @override
  String get pluginNameTextLibrary => 'Bibliothèque de textes';

  @override
  String get pluginNameTransportTracker => 'Suivi des transports';

  @override
  String get pluginNameUsage => 'Utilisation';

  @override
  String get pluginNameWhiteboard => 'Tableau blanc';

  @override
  String get pluginNameWifiSpeedTest => 'Test de débit Wi-Fi';

  @override
  String get pluginNameWorthCounter => 'Compteur de valeur';

  @override
  String get pluginNameYoutubeDownloader => 'Téléchargeur de médias';

  @override
  String get pluginTagUtility => 'Utilitaires';

  @override
  String get pluginTagShopping => 'Shopping';

  @override
  String get pluginTagSystem => 'Système';

  @override
  String get pluginTagDocuments => 'Documents';

  @override
  String get pluginTagProductivity => 'Productivité';

  @override
  String get pluginTagSync => 'Synchronisation';

  @override
  String get pluginTagData => 'Données';

  @override
  String get pluginTagGames => 'Jeux';

  @override
  String get pluginTagSimulation => 'Simulation';

  @override
  String get pluginTagWellness => 'Bien-être';

  @override
  String get pluginTagAnalytics => 'Analytique';

  @override
  String get pluginTagAi => 'IA';

  @override
  String get pluginTagWriting => 'Écriture';

  @override
  String get pluginTagMedia => 'Médias';

  @override
  String get pluginTagAudio => 'Audio';

  @override
  String get pluginTagAutomation => 'Automatisation';

  @override
  String get pluginTagEducation => 'Éducation';

  @override
  String get pluginTagNetwork => 'Réseau';

  @override
  String get pluginTagSocial => 'Social';

  @override
  String get pluginTagNova => 'Nova';

  @override
  String get pluginTagFood => 'Cuisine';

  @override
  String get pluginTagPhotos => 'Photos';

  @override
  String get pluginTagTravel => 'Voyage';

  @override
  String get pluginTagFinance => 'Finances';

  @override
  String get pluginTagDeveloper => 'Développeur';

  @override
  String get pluginTagMinecraft => 'Minecraft';

  @override
  String get pluginTagPaid => 'Payant';

  @override
  String get pluginTagFree => 'Gratuit';

  @override
  String get accountTabProfile => 'Profil';

  @override
  String get accountTabStats => 'Statistiques';

  @override
  String get accountProfileSubtitle => 'Votre apparence sur cet appareil.';

  @override
  String get accountSyncTitle => 'Synchronisation et compte';

  @override
  String get accountSyncSubtitle =>
      'Vos données sur chaque appareil, ainsi que les appareils liés à celui-ci.';

  @override
  String get accountStorageTitle => 'Stockage';

  @override
  String get accountStorageSubtitle => 'L\'espace que luma occupe ici.';

  @override
  String get accountPlanTitle => 'Forfait';

  @override
  String get accountPlanSubtitle => 'Votre choix et ce qu\'il comprend.';

  @override
  String get accountFamilySubtitle => 'Partagez votre agenda avec vos proches.';

  @override
  String get accountProfilePicture => 'Photo de profil';

  @override
  String get accountProfilePictureNote =>
      'Uniquement sur cet appareil — personne d\'autre ne la voit.';

  @override
  String get accountChangePhoto => 'Changer la photo';

  @override
  String get accountChoosePhoto => 'Choisir une photo';

  @override
  String get accountLocalStorage => 'Stockage local';

  @override
  String accountUsedLocally(String size) {
    return '$size utilisés localement';
  }

  @override
  String get accountWhatUsingSpace => 'Qu\'est-ce qui occupe de l\'espace ?';

  @override
  String get accountNothingCounted => 'Rien n\'a encore été compté.';

  @override
  String get accountChangePlan => 'Changer de forfait';

  @override
  String get accountNoFamilyYet => 'Pas encore de famille';

  @override
  String get accountStartFamilyHint =>
      'Créez-en une pour partager votre agenda.';

  @override
  String get accountCreateFamily => 'Créer une famille';

  @override
  String get accountManageFamily => 'Gérer la famille';

  @override
  String get familyTitle => 'Famille';

  @override
  String get familyBackToAccount => 'Retour au compte';

  @override
  String get familyStartTitle => 'Créer une famille';

  @override
  String get familyStartSubtitle =>
      'Invitez vos proches et organisez-vous ensemble.';

  @override
  String get familyNameLabel => 'Nom de la famille';

  @override
  String get familyEnterName => 'Saisissez un nom de famille.';

  @override
  String get familyCreate => 'Créer la famille';

  @override
  String familySlotsUsed(String used, String limit) {
    return '$used sur $limit places utilisées';
  }

  @override
  String get familyMembers => 'Membres';

  @override
  String get familyPendingInvites => 'Invitations en attente';

  @override
  String get familyInviteTitle => 'Inviter par e-mail';

  @override
  String get familyNoInvites => 'Aucune invitation en attente.';

  @override
  String get familyDeleteFamily => 'Supprimer la famille';

  @override
  String get familyLeaveFamily => 'Quitter la famille';

  @override
  String get familyRemoveMemberTitle => 'Retirer le membre ?';

  @override
  String get familyRemoveMemberBody =>
      'Il perdra immédiatement l\'accès aux événements partagés.';

  @override
  String get familyLeaveTitle => 'Quitter la famille ?';

  @override
  String get familyLeaveBody =>
      'Vous perdrez l\'accès aux événements partagés.';

  @override
  String get familyLeaveConfirm => 'Quitter';

  @override
  String get familyDeleteTitle => 'Supprimer la famille ?';

  @override
  String get familyDeleteBody =>
      'Cela supprime tous les membres et tous les événements partagés. Cette action est irréversible.';

  @override
  String get familyRoleOwner => 'Propriétaire';

  @override
  String get familyRoleYou => 'Vous';

  @override
  String get familyRoleMember => 'Membre';

  @override
  String get familyPending => 'En attente';

  @override
  String get familyInviteInvalidEmail => 'Saisissez une adresse e-mail valide.';

  @override
  String get familyInviteInfo =>
      'Ils verront l\'invitation dans leur boîte de réception (icône en haut à droite) la prochaine fois qu\'ils ouvriront Luma.';

  @override
  String get familyInviteSend => 'Envoyer l\'invitation';

  @override
  String get loginBarrierLabel => 'Se connecter';

  @override
  String get loginEnterValidEmail => 'Saisissez une adresse e-mail valide.';

  @override
  String get loginPasswordTooShort =>
      'Utilisez au moins 10 caractères : ce mot de passe protège vos données chiffrées.';

  @override
  String get loginEnterPassword => 'Saisissez votre mot de passe.';

  @override
  String get loginPasswordsMismatch =>
      'Les mots de passe ne correspondent pas.';

  @override
  String get loginEmailNotVerified =>
      'Votre e-mail n\'est pas encore vérifié. Nous vous avons envoyé un nouveau code.';

  @override
  String get loginEnterSixDigitCode =>
      'Saisissez le code à 6 chiffres reçu par e-mail.';

  @override
  String get loginCouldNotOpenBrowser =>
      'Impossible d\'ouvrir votre navigateur. Copiez le lien ci-dessous et ouvrez-le vous-même.';

  @override
  String get loginSignInIncomplete => 'La connexion n\'a pas abouti.';

  @override
  String get loginChoosePassphrase => 'Choisissez une phrase secrète.';

  @override
  String get loginEnterPassphrase =>
      'Saisissez votre phrase secrète luma pour déverrouiller vos données.';

  @override
  String get loginPassphraseTooShort =>
      'Utilisez au moins 10 caractères : cette phrase secrète chiffre vos données.';

  @override
  String get loginPassphrasesMismatch =>
      'Les phrases secrètes ne correspondent pas.';

  @override
  String get loginPasswordResetDone =>
      'Votre mot de passe a été réinitialisé. Connectez-vous avec votre nouveau mot de passe.';

  @override
  String get loginLinkCopied => 'Lien copié dans le presse-papiers.';

  @override
  String get loginShow => 'Afficher';

  @override
  String get loginHide => 'Masquer';

  @override
  String get loginWelcomeBack => 'Bon retour';

  @override
  String get loginMakeAccount => 'Créez votre compte';

  @override
  String get loginSetUpLocalSync => 'Configurer la synchro locale uniquement';

  @override
  String get loginSignInSubtitle =>
      'Connectez-vous et récupérez vos données depuis vos autres appareils.';

  @override
  String get loginCreateSubtitle =>
      'Un compte, tous vos appareils — verrouillé avant de quitter celui-ci.';

  @override
  String get loginLocalSubtitle =>
      'Pas de serveur, pas de compte. Les appareils s\'associent directement sur votre propre réseau.';

  @override
  String get loginCreateAccount => 'Créer un compte';

  @override
  String get loginConfirmPassword => 'Confirmer le mot de passe';

  @override
  String get loginForgotPassword => 'Mot de passe oublié ?';

  @override
  String get loginServerAddress => 'Adresse du serveur';

  @override
  String get loginSetUp => 'Configurer';

  @override
  String get loginUseLocalOnly => 'Utiliser la synchro locale uniquement';

  @override
  String get loginUseLumaAccount => 'Utiliser plutôt un compte luma';

  @override
  String get loginSelfHostedServer => 'Serveur auto-hébergé';

  @override
  String get loginContinueInBrowser => 'Continuez dans votre navigateur';

  @override
  String loginOpenedInBrowser(String provider) {
    return 'Nous avons ouvert $provider dans votre navigateur. Terminez là-bas, puis revenez : cette page se mettra à jour toute seule.';
  }

  @override
  String get loginYourProvider => 'votre fournisseur';

  @override
  String get loginReopenPage => 'Rouvrir la page';

  @override
  String get loginCopyLink => 'Copier le lien';

  @override
  String get loginCancelAndGoBack => 'Annuler et revenir';

  @override
  String get loginOneLastThing => 'Une dernière chose';

  @override
  String get loginUnlockYourData => 'Déverrouillez vos données';

  @override
  String loginNewAccountExplain(String provider) {
    return '$provider a prouvé qui vous êtes, mais cela ne peut pas déverrouiller vos données : seule une phrase secrète que vous seul connaissez le peut. Choisissez-en une maintenant ; vous en aurez besoin sur chaque appareil.';
  }

  @override
  String loginExistingAccountExplain(String provider) {
    return 'Ce compte existe déjà, donc $provider vous y a connecté directement. Saisissez la phrase secrète luma que vous avez configurée — celle que vous taperiez pour vous connecter avec un mot de passe.';
  }

  @override
  String get loginChoosePassphraseLabel => 'Choisissez une phrase secrète';

  @override
  String get loginYourPassphrase => 'Votre phrase secrète luma';

  @override
  String get loginConfirmPassphrase => 'Confirmer la phrase secrète';

  @override
  String get loginUnlockAndSignIn => 'Déverrouiller et se connecter';

  @override
  String get loginUseDifferentAccount => 'Utiliser un autre compte';

  @override
  String get loginAlmostThere => 'Presque terminé';

  @override
  String get loginNeedsApproval =>
      'Votre compte doit être approuvé avant que vous puissiez vous connecter.';

  @override
  String get loginBackToSignIn => 'Retour à la connexion';

  @override
  String get loginCheckYourEmail => 'Vérifiez votre e-mail';

  @override
  String loginCodeSentTo(String email) {
    return 'Nous avons envoyé un code à 6 chiffres à $email. Saisissez-le ci-dessous pour vérifier votre compte.';
  }

  @override
  String get loginSixDigitCode => 'Code à 6 chiffres';

  @override
  String get loginVerifyAndSignIn => 'Vérifier et se connecter';

  @override
  String get loginSending => 'Envoi…';

  @override
  String get loginResendCode => 'Renvoyer le code';

  @override
  String get loginUseDifferentEmail => 'Utiliser un autre e-mail';

  @override
  String get loginForgotTitle => 'Mot de passe oublié ?';

  @override
  String get loginForgotSubtitle =>
      'Saisissez l\'e-mail de votre compte et nous vous enverrons un code à 6 chiffres pour choisir un nouveau mot de passe. Le code est valable 15 minutes.';

  @override
  String get loginSendCode => 'Envoyer le code';

  @override
  String get loginChooseNewPassword => 'Choisissez un nouveau mot de passe';

  @override
  String loginResetSubtitle(String email) {
    return 'Si $email possède un compte, un code à 6 chiffres est en route. Saisissez-le dans les 15 minutes, avec votre nouveau mot de passe.';
  }

  @override
  String get loginRecoveryKey =>
      'Clé de récupération (conserve vos données synchronisées)';

  @override
  String get loginNewPassword => 'Nouveau mot de passe';

  @override
  String get loginConfirmNewPassword => 'Confirmer le nouveau mot de passe';

  @override
  String get loginResetAndSignIn =>
      'Réinitialiser le mot de passe et se connecter';

  @override
  String get loginSendNewCode => 'Envoyer un nouveau code';

  @override
  String get loginStrengthTooShort => 'Trop court';

  @override
  String get loginStrengthWeak => 'Faible';

  @override
  String get loginStrengthGood => 'Bon';

  @override
  String get loginStrengthStrong => 'Fort';

  @override
  String get loginBrandTagline =>
      'Tout ce que vous conservez ici,\nsur chaque appareil que vous utilisez.';

  @override
  String get loginBrandPointEncrypted =>
      'Chiffré sur cet appareil avant de le quitter.';

  @override
  String get loginBrandPointPerFeature =>
      'Rien n\'est synchronisé tant que vous ne l\'activez pas, fonction par fonction.';

  @override
  String get loginBrandPointSkipServer =>
      'Ou évitez complètement le serveur et associez-vous via votre propre réseau.';

  @override
  String get loginBrandNotEvenUs =>
      'Même nous ne pouvons pas lire vos données.';

  @override
  String loginContinueWith(String provider) {
    return 'Continuer avec $provider';
  }

  @override
  String get loginOrWithEmail => 'ou avec votre e-mail';

  @override
  String get loginKeyWarning =>
      'Tout est chiffré avec ceci avant de quitter l\'appareil. Si vous l\'oubliez, vous pouvez le réinitialiser par e-mail, mais les copies synchronisées sur le serveur sont effacées : seules les données encore présentes sur vos appareils reviennent.';

  @override
  String get loginResetWithRecoveryKey =>
      'Votre clé de récupération déverrouille vos données synchronisées : elles restent sur le serveur et sont rechiffrées avec votre nouveau mot de passe. Chaque appareil est déconnecté et les récupère avec le nouveau mot de passe.';

  @override
  String get loginResetWithoutRecoveryKey =>
      'Vos données synchronisées sont verrouillées avec votre ancien mot de passe. Sans votre clé de récupération, une réinitialisation efface les copies sur le serveur et déconnecte tous les appareils. Ce qui est encore sur vos appareils sera de nouveau envoyé une fois connectés avec le nouveau mot de passe.';

  @override
  String loginAgreeLegal(String terms, String privacy) {
    return 'En continuant, vous acceptez nos $terms et notre $privacy.';
  }

  @override
  String get loginTermsOfService => 'Conditions d\'utilisation';

  @override
  String get loginPrivacyPolicy => 'Politique de confidentialité';

  @override
  String get planPriceFree => 'Gratuit';

  @override
  String get planPriceOrbit => '3 \$ / mois';

  @override
  String get planPriceNova => '6 \$ / mois';

  @override
  String get planCoreBlurb =>
      'Toutes les bases, directement sur votre appareil.';

  @override
  String get planOrbitBlurb =>
      'Plus de fonctions synchronisées, SFTP, liste de courses et le thème Coffee.';

  @override
  String get planNovaBlurb =>
      'Tout synchronisé sur chaque appareil, plus les outils premium.';

  @override
  String planFeatureSyncUpTo(int count) {
    return 'Synchronisez jusqu\'à $count fonctions sur vos appareils, chiffrées de bout en bout';
  }

  @override
  String get planFeatureEveryPlugin =>
      'Chaque plugin fonctionne gratuitement sur votre appareil';

  @override
  String planFeatureFamilyRoom(int count) {
    return 'Place pour $count personnes dans votre famille';
  }

  @override
  String get planFeatureAiCoreExchange =>
      'Analyses AI Detector : chacune échange 10 % de votre limite IA hebdomadaire';

  @override
  String planFeatureStorage(int mb) {
    return '$mb Mo d\'espace de synchronisation';
  }

  @override
  String get planFeatureAiOrbit =>
      '10 analyses AI Detector par semaine, puis 4 % de votre limite IA hebdomadaire chacune';

  @override
  String get planFeatureAiNova =>
      '30 analyses AI Detector par semaine, puis 2 % de votre limite IA hebdomadaire chacune';

  @override
  String get planFeatureOrbitAirline =>
      'Retrouvez votre compagnie Airline Tycoon d\'un appareil à l\'autre';

  @override
  String get planFeatureOrbitCs2 => 'Prix du marché CS2 dans Steam Tools';

  @override
  String get planFeatureOrbitSftp =>
      'Client SFTP et dossier partagé entre vos appareils';

  @override
  String get planFeatureOrbitGroceries =>
      'Liste de courses avec les prix de Jumbo, Albert Heijn, Hoogvliet et Lidl';

  @override
  String get planFeatureOrbitCoffee => 'Le thème Coffee';

  @override
  String get planFeatureNovaEverythingSync =>
      'Synchronisez tout sur tous vos appareils, chiffré de bout en bout';

  @override
  String get planFeatureNovaAssistant =>
      'Mode plan de l\'Assistant, recherche approfondie et création d\'images';

  @override
  String get planFeatureNovaGallery => 'Personnes et catégories de la galerie';

  @override
  String get planFeatureNovaClassroom =>
      'Tuteur de classe dans la salle de la Bibliothèque de textes';

  @override
  String get planFeatureNovaEverythingOrbit =>
      'Tout ce qui est dans Orbit, y compris le thème Coffee';

  @override
  String get planCodeEnterCode => 'Saisissez un code d\'accès.';

  @override
  String planCodeUnlockTitle(String plan) {
    return 'Débloquer $plan';
  }

  @override
  String planCodeBody(String plan) {
    return 'Saisissez votre code d\'accès. Il débloque $plan pendant 30 jours, puis vous repassez automatiquement sur Core.';
  }

  @override
  String get planCodeHint => 'Code d\'accès';

  @override
  String get planCodeUnlockButton => 'Débloquer';

  @override
  String get passwordResetChooseNew => 'Choisissez un nouveau mot de passe.';

  @override
  String passwordResetMinLengthError(int min) {
    return 'Utilisez au moins $min caractères.';
  }

  @override
  String get passwordResetMismatch =>
      'Les deux mots de passe ne correspondent pas.';

  @override
  String get passwordResetTitle => 'Choisissez un nouveau mot de passe';

  @override
  String get passwordResetBodyNoEmail =>
      'L\'opérateur du serveur a réinitialisé le mot de passe de ce compte, l\'ancien ne fonctionne plus.';

  @override
  String passwordResetBodyWithEmail(String email) {
    return 'L\'opérateur du serveur a réinitialisé le mot de passe de $email, l\'ancien ne fonctionne plus.';
  }

  @override
  String get passwordResetSyncNote =>
      'Définissez-en un nouveau ici et luma rechiffrera vos données synchronisées avec lui, donc rien n\'est perdu. Vos autres appareils demanderont le nouveau mot de passe à leur prochaine synchronisation.';

  @override
  String get passwordResetNewPassword => 'Nouveau mot de passe';

  @override
  String passwordResetMinHelper(int min) {
    return 'Au moins $min caractères.';
  }

  @override
  String get passwordResetRepeatPassword => 'Répétez le nouveau mot de passe';

  @override
  String get passwordResetSubmit => 'Définir le nouveau mot de passe';

  @override
  String get passwordResetLockedNote =>
      'Tout le reste de luma reste verrouillé tant que ce n\'est pas fait. Vos données locales sur cet appareil ne sont pas modifiées.';

  @override
  String get passwordResetShowPassword => 'Afficher le mot de passe';

  @override
  String get passwordResetHidePassword => 'Masquer le mot de passe';

  @override
  String get planSelectionBackTooltip => 'Retour au compte';

  @override
  String get planSelectionTitle => 'Choisissez votre formule';

  @override
  String get planSelectionSubtitle =>
      'Sélectionnez la formule qui vous convient le mieux.';

  @override
  String get planSelectionInvalidCode => 'Ce code d\'accès n\'est pas valide.';

  @override
  String planCreditsNotOpen(String tokens, String price) {
    return 'L\'achat de crédits n\'est pas encore ouvert : $tokens jetons pour $price seront disponibles une fois les paiements configurés.';
  }

  @override
  String get planCreditsHeader => 'CRÉDITS IA PONCTUELS';

  @override
  String get planCreditsBody =>
      'Des jetons supplémentaires pour quand la limite IA de votre formule est atteinte. Ils n\'expirent jamais.';

  @override
  String planCreditsBodyWithBalance(String balance) {
    return 'Des jetons supplémentaires pour quand la limite IA de votre formule est atteinte. Il vous reste $balance. Ils n\'expirent jamais.';
  }

  @override
  String planCreditsPackTokens(String tokens) {
    return '$tokens jetons';
  }

  @override
  String planCreditsBuy(String price) {
    return '$price · Acheter';
  }

  @override
  String planTokenAmountMillions(String amount) {
    return '$amount M jetons';
  }

  @override
  String planTokenAmountThousands(String amount) {
    return '$amount K jetons';
  }

  @override
  String get planCurrentBadge => 'Actuel';

  @override
  String planRevertsToCore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '1 jour',
    );
    return 'Retour à Core dans $_temp0';
  }

  @override
  String get planWhatYouGet => 'CE QUE VOUS OBTENEZ';

  @override
  String get planYourCurrentPlan => 'Votre formule actuelle';

  @override
  String planSelectPlan(String plan) {
    return 'Choisir $plan';
  }

  @override
  String get statsNetWorthTitle => 'Patrimoine net';

  @override
  String get statsNetWorthSubtitle =>
      'Tout ce que vous avez gagné depuis le début du suivi.';

  @override
  String get statsTravelTitle => 'Voyages';

  @override
  String get statsTravelSubtitle =>
      'Les pays que vous avez visités, sur une carte.';

  @override
  String get statsTotalIncomeAllTime => 'Revenus totaux de tous les temps';

  @override
  String get statsSpent => 'Dépensé';

  @override
  String get statsKept => 'Économisé';

  @override
  String get statsPerMonth => 'Par mois';

  @override
  String get statsTotalIncome => 'Revenus totaux';

  @override
  String get statsTotalSpent => 'Total dépensé';

  @override
  String statsKeptOfIncome(String amount, String percent) {
    return '$amount · $percent % des revenus';
  }

  @override
  String get statsAverageIncomePerMonth => 'Revenu mensuel moyen';

  @override
  String get statsEntriesLogged => 'Entrées enregistrées';

  @override
  String get statsTrackingSince => 'Suivi depuis';

  @override
  String get statsNoEntriesYet => 'Aucune entrée pour l\'instant';

  @override
  String get statsCountriesVisited => 'Pays visités';

  @override
  String statsVisitedSoFar(int count) {
    return '$count jusqu\'ici';
  }

  @override
  String statsVisitedOfTotal(int visited, int total, String percent) {
    return '$visited sur $total · $percent % du monde';
  }

  @override
  String get statsMapButton => 'Carte';

  @override
  String get travelMapTitle => 'Carte des voyages';

  @override
  String get travelResetZoom => 'Réinitialiser le zoom';

  @override
  String get travelFullscreen => 'Plein écran';

  @override
  String get travelMapLoadFailed => 'La carte n\'a pas pu être chargée';

  @override
  String get travelClearTitle => 'Effacer la carte ?';

  @override
  String get travelClearBody =>
      'Tous les pays marqués comme visités seront désélectionnés.';

  @override
  String travelSummaryOfTotal(int total, String percent) {
    return 'sur $total pays · $percent % du monde';
  }

  @override
  String get travelRegionAfrica => 'Afrique';

  @override
  String get travelRegionAsia => 'Asie';

  @override
  String get travelRegionEurope => 'Europe';

  @override
  String get travelRegionNorthAmerica => 'Amérique du Nord';

  @override
  String get travelRegionOceania => 'Océanie';

  @override
  String get travelRegionSouthAmerica => 'Amérique du Sud';

  @override
  String get travelRegionOther => 'Autre';

  @override
  String travelRegionPill(String region, int visited, int total) {
    return '$region $visited/$total';
  }

  @override
  String get travelMapHint =>
      'Touchez un pays pour le marquer comme visité, touchez-le à nouveau pour le retirer. Pincez pour zoomer, ou ouvrez la carte en plein écran.';

  @override
  String get travelOpenFullscreen => 'Ouvrir en plein écran';

  @override
  String get travelCountriesTitle => 'Pays';

  @override
  String travelCountriesCount(int count) {
    return 'Pays · $count';
  }

  @override
  String get travelClearAll => 'Tout effacer';

  @override
  String get travelSearchCountry => 'Rechercher un pays';

  @override
  String travelNoCountryMatch(String query) {
    return 'Aucun pays ne correspond à « $query ».';
  }

  @override
  String travelFullscreenCount(int visited, int total) {
    return '$visited sur $total visités';
  }

  @override
  String get pinMustBe8Digits =>
      'Le code PIN doit comporter exactement 8 chiffres.';

  @override
  String get serverGateSetUpAccount => 'Créer un compte';

  @override
  String get serverGateEnterCode => 'Saisir le code';

  @override
  String serverGatePendingEmail(String email) {
    return 'Votre compte ($email) attend encore une approbation. Saisissez le code à 6 chiffres que nous vous avons envoyé par e-mail pour finaliser la connexion — d\'ici là, nous ne touchons pas du tout au serveur.';
  }

  @override
  String serverGatePendingApproval(String email) {
    return 'Votre compte ($email) attend l\'accord du propriétaire du serveur. Rien à faire de votre côté : connectez-vous simplement une fois qu\'il l\'aura donné ; d\'ici là, nous ne touchons pas au serveur.';
  }

  @override
  String get serverGateExpired =>
      'Ce compte a perdu son approbation. Une fois de nouveau approuvé, connectez-vous et cela se réactive.';

  @override
  String serverGateSetupHint(String description) {
    return '$description Créez un compte dans Paramètres → Synchronisation et compte, touchez le lien reçu par e-mail, puis connectez-vous.';
  }

  @override
  String get serverGateCloudFilesTitle =>
      'Cloud Files nécessite un compte approuvé';

  @override
  String get serverGateCloudFilesDescription =>
      'Cloud Files conserve vos fichiers sur le serveur luma, verrouillés d\'abord sur cet appareil.';

  @override
  String get serverGateChatTitle => 'Le chat nécessite un compte approuvé';

  @override
  String get serverGateChatDescription =>
      'Le chat fait transiter les messages verrouillés entre comptes par le serveur luma.';

  @override
  String get titleBarMinimize => 'Réduire';

  @override
  String get titleBarMaximize => 'Agrandir';

  @override
  String get titleBarRestore => 'Restaurer';

  @override
  String get licensePoweredByFlutter => 'Propulsé par Flutter';

  @override
  String get splashTagline => 'L\'application utilitaire';

  @override
  String get splashStarting => 'Démarrage de luma';

  @override
  String get updateNoTestBuilds =>
      'Pas de mises à jour sur les versions de test — celle-ci est faite main.';

  @override
  String updateUpToDate(String version) {
    return 'Vous êtes à jour ($version). Parfait !';
  }

  @override
  String updateDownloadNotReady(String version) {
    return 'luma $version est sorti, mais le téléchargement n\'est pas encore prêt. Patientez quelques minutes et réessayez.';
  }

  @override
  String updateNewVersionTitle(String version) {
    return 'Une nouvelle version de luma est disponible — $version';
  }

  @override
  String updateReadyBody(String current) {
    return 'Une nouvelle version de luma est prête à être installée.\n\nVous avez $current.';
  }

  @override
  String updateWhatsNew(String current, String version) {
    return 'Vous avez $current. Voici les nouveautés de $version :';
  }

  @override
  String get updateLater => 'Plus tard';

  @override
  String get updateInstallIt => 'Installer';

  @override
  String get updateFailedGeneric =>
      'La mise à jour a échoué. Réessayez plus tard.';

  @override
  String get updateAndroidBlocked =>
      'Android a bloqué l\'installation — autorisez « Installer des applis inconnues » pour luma dans les paramètres système, puis réessayez.';

  @override
  String get updateDownloadFailed =>
      'Échec du téléchargement. Vérifiez la connexion et la source de la mise à jour.';

  @override
  String updateServerHttpError(String code) {
    return 'Le serveur a renvoyé HTTP $code pour l\'installateur.';
  }

  @override
  String updateOpenInstallerFailed(String message) {
    return 'Impossible d\'ouvrir l\'installateur : $message';
  }

  @override
  String updateStartInstallerFailed(String error) {
    return 'Impossible de lancer l\'installateur : $error';
  }

  @override
  String get updateTitle => 'Mise à jour de luma';

  @override
  String get updateDontClose =>
      'Ne fermez pas luma : il redémarrera tout seul.';

  @override
  String get updateStageDownloading => 'Téléchargement de la mise à jour';

  @override
  String get updateStageVerifying => 'Vérification des fichiers';

  @override
  String get updateStagePreparing => 'Préparation de l\'installateur';

  @override
  String get updateRestarting => 'Redémarrage de luma';

  @override
  String get familyInboxTitle => 'Boîte de réception';

  @override
  String familyInboxPendingInvites(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invitations en attente',
      one: '1 invitation en attente',
    );
    return '$_temp0';
  }

  @override
  String get familyInboxEmptySubtitle =>
      'Les messages de luma et les invitations familiales apparaîtront ici.';

  @override
  String get familyInboxNew => 'Nouveau';

  @override
  String familyInboxFromLuma(String date) {
    return 'De la part de luma · $date';
  }

  @override
  String familyInboxInvitedBy(String email) {
    return 'Invité par $email';
  }

  @override
  String familyInboxSentOn(String date) {
    return 'Envoyée le $date';
  }

  @override
  String familyInboxExpiresOn(String date) {
    return 'Expire le $date';
  }

  @override
  String get familyInboxAccept => 'Accepter';

  @override
  String get familyInboxDecline => 'Refuser';

  @override
  String familyLimitExceeded(int limit) {
    String _temp0 = intl.Intl.pluralLogic(
      limit,
      locale: localeName,
      other:
          'Ce forfait familial autorise jusqu\'à $limit membres. Passez au forfait supérieur du propriétaire pour en ajouter davantage.',
      one:
          'Ce forfait familial autorise 1 membre au maximum. Passez au forfait supérieur du propriétaire pour en ajouter davantage.',
    );
    return '$_temp0';
  }

  @override
  String get familyNotInFamily => 'Vous ne faites pas partie d\'une famille.';

  @override
  String get familyNotSignedIn => 'Non connecté.';

  @override
  String familyApiServerError(String status) {
    return 'Erreur du serveur ($status).';
  }

  @override
  String get aiSettingsLocalNotAvailableIos =>
      'Le modèle sur l\'appareil n\'est pas disponible sur iOS. Choisissez un autre modèle ci-dessus.';

  @override
  String get aiSettingsRetentionNotice =>
      'La rétention zéro des données du modèle hébergé doit être activée sur le compte du fournisseur derrière la clé API, y compris pour une clé serveur partagée. Luma ne peut ni modifier ni vérifier ce paramètre. Les requêtes OpenAI désactivent le stockage des réponses, mais cela ne remplace pas l\'approbation du fournisseur. Mistral utilise son point de terminaison de chat sans état. Le Qwen sur l\'appareil n\'envoie aucune requête à un fournisseur de modèle ; Luma enregistre toutefois l\'historique des discussions sur cet appareil.';

  @override
  String aiSettingsLocalModelTitle(String model) {
    return 'Assistant Luma · $model sur l\'appareil';
  }

  @override
  String aiSettingsLocalModelBlurb(String size) {
    return 'Téléchargez une seule fois le modèle de $size pour utiliser l\'assistant hors ligne. Les requêtes s\'exécutent sur cet appareil ; les actions en ligne, comme les téléchargements de plugins et les cours du marché, nécessitent toujours Internet. Qwen est fourni sous Apache-2.0.';
  }

  @override
  String get aiSettingsDownloadingModel => 'Téléchargement du modèle…';

  @override
  String aiSettingsDownloadingModelPercent(String percent) {
    return 'Téléchargement du modèle… $percent %';
  }

  @override
  String aiSettingsDownloadFailed(String error) {
    return 'Échec du téléchargement : $error';
  }

  @override
  String get aiSettingsModelReady => 'Modèle téléchargé et prêt';

  @override
  String get aiSettingsDownloadModel => 'Télécharger le modèle';

  @override
  String get aiSettingsModelUsage => 'Utilisation des modèles';

  @override
  String get aiSettingsModelUsageSubtitle =>
      'Messages envoyés avec succès avec chaque modèle sur cet appareil.';

  @override
  String get aiSettingsNoMessagesYet => 'Aucun message envoyé pour l\'instant.';

  @override
  String get aiSettingsKeySaved => 'Clé API enregistrée.';

  @override
  String get aiSettingsEnterKeyFirst => 'Saisissez d\'abord une clé API.';

  @override
  String get aiSettingsConnectionWorks => 'La connexion fonctionne.';

  @override
  String aiSettingsCouldNotVerifyKey(String error) {
    return 'Impossible de vérifier la clé : $error';
  }

  @override
  String get aiSettingsKeyRemoved => 'Clé API supprimée.';

  @override
  String get aiSettingsRemoveKeyTitle => 'Supprimer la clé API ?';

  @override
  String aiSettingsRemoveKeyBody(String provider) {
    return 'Vous ne pourrez pas discuter avec $provider tant que vous n\'aurez pas ajouté une autre clé.';
  }

  @override
  String get aiSettingsRemoveKey => 'Supprimer la clé';

  @override
  String get aiSettingsTestConnection => 'Tester la connexion';

  @override
  String get aiSettingsSharedKeyAvailable =>
      'Clé partagée disponible depuis votre serveur de synchronisation';

  @override
  String get aiSettingsHintReplaceKey =>
      'Saisissez une nouvelle clé pour la remplacer';

  @override
  String get aiSettingsHintOverrideSharedKey =>
      'Saisissez votre propre clé pour remplacer la clé partagée';

  @override
  String aiSettingsSharedKeyExplanation(String provider) {
    return 'L\'administrateur de votre serveur de synchronisation a configuré une clé $provider partagée, vous n\'en avez donc pas besoin : les discussions transitent par votre serveur de synchronisation, qui conserve la clé ; elle n\'est jamais envoyée à cet appareil. Saisissez ci-dessus votre propre clé pour contourner le serveur et parler directement à $provider.';
  }

  @override
  String aiSettingsLocalKeyExplanation(String provider) {
    return 'Stocké uniquement sur cet appareil, chiffré au repos. Envoyé directement à $provider lors des discussions — jamais à un serveur luma.';
  }

  @override
  String get assistantNeedsAccountTitle => 'Créez un compte pour continuer';

  @override
  String get assistantNeedsAccountBody =>
      'Configurez un compte luma — simplement un e-mail et un mot de passe, sans serveur — avant de discuter avec l\'assistant.';

  @override
  String get assistantSetUpAccount => 'Configurer le compte';

  @override
  String get assistantRenameTitle => 'Renommer la conversation';

  @override
  String assistantDeleteTitle(String title) {
    return 'Supprimer « $title » ?';
  }

  @override
  String get assistantDeleteBody =>
      'Cela supprime la conversation et ses messages.';

  @override
  String get assistantModelUnused => 'Non utilisé';

  @override
  String assistantModelMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count msg',
      one: '1 msg',
    );
    return '$_temp0';
  }

  @override
  String get assistantModelsHeader => 'Modèles';

  @override
  String get assistantApiKeyHeader => 'Clé API';

  @override
  String get assistantWouldntWakeUp => 'L\'assistant ne se réveille pas';

  @override
  String get assistantDownloadTitle => 'Télécharger Luma Assistant';

  @override
  String get assistantDownloadUnsupported =>
      'Le modèle embarqué n\'est pas disponible sur cette plateforme.';

  @override
  String assistantDownloadingModel(String model, String size) {
    return 'Téléchargement de $model ($size)…';
  }

  @override
  String assistantDownloadPrompt(String model, String size) {
    return 'Téléchargez $model ($size) pour commencer à discuter. Il fonctionne sur cet appareil.';
  }

  @override
  String get assistantChooseAnotherModel =>
      'Choisissez un autre modèle dans le sélecteur ci-dessous.';

  @override
  String get assistantDownloadingModelShort => 'Téléchargement du modèle…';

  @override
  String get assistantDownloadModel => 'Télécharger le modèle';

  @override
  String assistantDownloadFailed(String error) {
    return 'Échec du téléchargement : $error';
  }

  @override
  String get assistantModelUnavailableTitle =>
      'Ce modèle n\'est pas encore disponible';

  @override
  String get assistantModelUnavailableBody =>
      'Ajoutez votre propre clé API dans les Paramètres pour l\'utiliser — stockée uniquement sur cet appareil — ou choisissez un autre modèle ci-dessous.';

  @override
  String get assistantOpenSettings => 'Ouvrir les paramètres';

  @override
  String get assistantIAddedKey => 'J\'ai ajouté une clé';

  @override
  String assistantNoApiKeyYet(String provider) {
    return 'Aucune clé API $provider enregistrée — ajoutez-en une dans les Paramètres.';
  }

  @override
  String get assistantPictureNeedsAccount =>
      'Le mode image nécessite que cet appareil soit connecté à un compte luma approuvé.';

  @override
  String get assistantResearchAgentsEmpty =>
      'Les agents de recherche n\'ont rien renvoyé.';

  @override
  String get assistantNewConversation => 'Nouvelle conversation';

  @override
  String get aiClientNoReply => 'Je n\'ai pas pu trouver de réponse à cela.';

  @override
  String get aiClientTooManySteps =>
      'Je n\'ai pas pu terminer — trop d\'étapes d\'outils.';

  @override
  String aiClientUnreachable(String provider, String error) {
    return 'Impossible de joindre $provider — vérifiez votre connexion.\n($error)';
  }

  @override
  String aiClientNoConnection(String provider) {
    return 'Impossible de joindre $provider — vérifiez votre connexion.';
  }

  @override
  String aiClientKeyRejected(String provider) {
    return '$provider a refusé la clé API. Vérifiez-la dans les paramètres.';
  }

  @override
  String get aiClientRateLimited =>
      'Trop de requêtes — réessayez dans un instant.';

  @override
  String aiClientApiError(String provider, int status) {
    return '$provider a renvoyé une erreur ($status).';
  }

  @override
  String get aiClientLumaSignIn => 'Reconnectez-vous pour utiliser Luma AI.';

  @override
  String aiClientLumaImageFailed(int status) {
    return 'Luma AI n\'a pas pu dessiner cela ($status).';
  }

  @override
  String get aiClientLumaBrokenImage =>
      'Luma AI a renvoyé une image endommagée.';

  @override
  String aiLocalModelMissing(String model) {
    return 'Téléchargez $model dans les paramètres de l\'assistant avant d\'utiliser le modèle sur l\'appareil.';
  }

  @override
  String aiLocalModelFailed(String error) {
    return 'Le modèle sur l\'appareil n\'a pas pu répondre : $error';
  }

  @override
  String get chatProviderLocalName => 'Assistant Luma (Qwen sur l\'appareil)';

  @override
  String get chatBubbleOpenInQrGenerator => 'Ouvrir dans le générateur de QR';

  @override
  String get chatCodeLanguagePlainText => 'texte';

  @override
  String get assistantModelDamaged =>
      'Le fichier du modèle est incomplet ou endommagé. Téléchargez-le à nouveau.';

  @override
  String get assistantModelDownloadInvalid =>
      'Le téléchargement du modèle n\'a pas produit de fichier valide.';

  @override
  String get converterHubPickTool => 'Choisissez un outil pour commencer.';

  @override
  String get converterHubAudioTitle => 'Convertisseur audio';

  @override
  String get converterHubPictureTitle => 'Convertisseur d\'images';

  @override
  String get converterHubVideoTitle => 'Convertisseur vidéo';

  @override
  String get converterHubDownscalerTitle => 'Réducteur d\'images';

  @override
  String get converterHubDownscalerSubtitle =>
      'Réduisez vos images à votre façon';

  @override
  String get converterHubVideoDownscalerTitle => 'Réducteur de vidéos';

  @override
  String get converterHubVideoDownscalerSubtitle =>
      'Réduisez la taille de vos vidéos';

  @override
  String get converterHubImageEditorTitle => 'Éditeur d\'images';

  @override
  String get converterHubImageEditorSubtitle => 'Découpez les fonds blancs';

  @override
  String get converterHubAudioEditorTitle => 'Éditeur audio';

  @override
  String get converterHubAudioEditorSubtitle => 'Coupez et peaufinez votre son';

  @override
  String get converterHubCollageTitle => 'Créateur de collages';

  @override
  String get converterHubCollageSubtitle => 'Assemblez vos photos';

  @override
  String get converterHubOtherSubtitle =>
      'Mondes et constructions Minecraft, casseur et réparateur de fichiers';

  @override
  String get converterBadgeAudio => 'AUDIO';

  @override
  String get converterBadgeImage => 'IMAGE';

  @override
  String get converterBadgeVideo => 'VIDÉO';

  @override
  String get converterBadgeOptimize => 'OPTIMISER';

  @override
  String get converterBadgeEdit => 'ÉDITER';

  @override
  String get converterBadgeCreate => 'CRÉER';

  @override
  String get converterBadgeOther => 'AUTRE';

  @override
  String get converterChange => 'Changer';

  @override
  String get converterSigPngImage => 'Image PNG';

  @override
  String get converterSigJpegImage => 'Image JPEG';

  @override
  String get converterSigGifImage => 'Image GIF';

  @override
  String get converterSigBmpImage => 'Image BMP';

  @override
  String get converterSigTiffImage => 'Image TIFF';

  @override
  String get converterSigWebpImage => 'Image WebP';

  @override
  String get converterSigWindowsIcon => 'Icône Windows';

  @override
  String get converterSigPhotoshopDocument => 'Document Photoshop';

  @override
  String get converterSigAvifHeicImage => 'Image AVIF/HEIC';

  @override
  String get converterSigPdfDocument => 'Document PDF';

  @override
  String get converterSigRichTextDocument => 'Document RTF';

  @override
  String get converterSigLegacyOfficeDocument => 'Document Office ancien';

  @override
  String get converterSigZipArchive => 'Archive ZIP';

  @override
  String get converterSigEmptyZipArchive => 'Archive ZIP vide';

  @override
  String get converterSigRarArchive => 'Archive RAR';

  @override
  String get converterSig7ZipArchive => 'Archive 7-Zip';

  @override
  String get converterSigGzipArchive => 'Archive GZip';

  @override
  String get converterSigBzip2Archive => 'Archive BZip2';

  @override
  String get converterSigXzArchive => 'Archive XZ';

  @override
  String get converterSigZstdArchive => 'Archive Zstandard';

  @override
  String get converterSigTarArchive => 'Archive TAR';

  @override
  String get converterSigWavAudio => 'Audio WAV';

  @override
  String get converterSigAviVideo => 'Vidéo AVI';

  @override
  String get converterSigMp3Audio => 'Audio MP3';

  @override
  String get converterSigMp4Video => 'Vidéo MP4';

  @override
  String get converterSigFlacAudio => 'Audio FLAC';

  @override
  String get converterSigOggMedia => 'Média Ogg';

  @override
  String get converterSigMatroskaVideo => 'Vidéo Matroska';

  @override
  String get converterSigMidiFile => 'Fichier MIDI';

  @override
  String get converterSigWindowsExecutable => 'Exécutable Windows';

  @override
  String get converterSigElfBinary => 'Binaire ELF';

  @override
  String get converterSigSqliteDatabase => 'Base de données SQLite';

  @override
  String get converterSigWebAssemblyModule => 'Module WebAssembly';

  @override
  String get converterSigJavaClass => 'Classe Java';

  @override
  String get converterSigTrueTypeFont => 'Police TrueType';

  @override
  String get converterSigOpenTypeFont => 'Police OpenType';

  @override
  String get converterSigWoffFont => 'Police WOFF';

  @override
  String get converterSigWoff2Font => 'Police WOFF2';

  @override
  String get converterSigMinecraftNbt => 'NBT Minecraft (gzip)';

  @override
  String get converterSigLumaRecipe => 'Recette de récupération luma';

  @override
  String get converterDamageBitRotLabel => 'Pourriture de bits';

  @override
  String get converterDamageScrambleLabel => 'Brouillage';

  @override
  String get converterDamageShuffleLabel => 'Mélange de blocs';

  @override
  String get converterDamageHeaderSmashLabel => 'Écrasement de l\'en-tête';

  @override
  String get converterDamageTruncateLabel => 'Troncature';

  @override
  String get converterDamageJunkLabel => 'Injection de données parasites';

  @override
  String get converterDamageBitRotDesc =>
      'Des octets isolés sont retournés au hasard, comme le fait un disque défaillant.';

  @override
  String get converterDamageScrambleDesc =>
      'Toute une zone est transformée en bruit par XOR. Plus rien ne peut la lire.';

  @override
  String get converterDamageShuffleDesc =>
      'Des morceaux du fichier sont permutés. La structure survit, pas le sens.';

  @override
  String get converterDamageHeaderSmashDesc =>
      'Les premiers octets sont effacés : impossible de savoir de quel fichier il s\'agit.';

  @override
  String get converterDamageTruncateDesc =>
      'La fin est coupée, comme si la copie ne s\'était jamais terminée.';

  @override
  String get converterDamageJunkDesc =>
      'Des octets aléatoires sont insérés, décalant tout ce qui suit.';

  @override
  String get converterPresetLight => 'Léger';

  @override
  String get converterPresetMedium => 'Moyen';

  @override
  String get converterPresetHeavy => 'Fort';

  @override
  String get converterPresetTotal => 'Total';

  @override
  String get converterPresetLightHint =>
      'Souvent encore ouvrable, mais faussé par endroits.';

  @override
  String get converterPresetMediumHint =>
      'La plupart des lecteurs refuseront de l\'ouvrir.';

  @override
  String get converterPresetHeavyHint => 'Complètement cassé.';

  @override
  String get converterPresetTotalHint => 'Il ne reste rien de reconnaissable.';

  @override
  String converterCorruptTooSmall(int size) {
    return 'Ce fichier ne fait que $size octets — trop petit pour être corrompu de façon intéressante.';
  }

  @override
  String get converterCorruptPickStyle =>
      'Choisissez au moins un type de dommage.';

  @override
  String converterCorruptStyleSkipped(String style) {
    return '$style a été ignoré : le fichier est trop petit pour cela.';
  }

  @override
  String get converterCorruptNothingApplied =>
      'Rien n\'a pu être appliqué à un fichier aussi petit.';

  @override
  String get converterCorruptNoRecipeRearranged =>
      'Ces types de dommages réorganisent et masquent les octets sans les supprimer. Sans la recette, personne ne peut lire le fichier, mais les données sont techniquement encore là. Ajoutez Écrasement de l\'en-tête ou Troncature si vous voulez vraiment effacer des octets.';

  @override
  String get converterCorruptNoRecipeDestroyed =>
      'Aucune recette n\'a été créée et des octets ont été détruits. Cela ne peut être annulé par rien, pas même par luma.';

  @override
  String converterOpFlipped(int count, String range) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count octets retournés',
      one: '1 octet retourné',
    );
    return '$_temp0 sur $range';
  }

  @override
  String converterOpScrambled(String range) {
    return '$range brouillé avec un flux de clés';
  }

  @override
  String converterOpShuffled(int count, String size, String offset) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mélange de $count blocs',
      one: 'Mélange de 1 bloc',
    );
    return '$_temp0 de $size à partir de $offset';
  }

  @override
  String converterOpWiped(String range) {
    return 'Effacé : $range';
  }

  @override
  String converterOpCutOff(String offset) {
    return 'Fichier coupé à $offset';
  }

  @override
  String converterOpInjected(String size, String offset) {
    return '$size de données parasites injectées à $offset';
  }

  @override
  String converterRecipeUnknownStep(String type) {
    return 'Étape de dommage inconnue « $type ».';
  }

  @override
  String converterRecipeMissingField(String key) {
    return 'L\'étape de la recette n\'a pas de « $key ».';
  }

  @override
  String get converterRecipeNotReadable =>
      'Ce n\'est pas une recette .lumafix lisible.';

  @override
  String get converterRecipeNotLuma =>
      'Ce fichier n\'est pas une recette de récupération luma.';

  @override
  String converterRecipeNewerVersion(int version) {
    return 'Cette recette a été créée par une version plus récente de luma (format $version). Mettez l\'application à jour pour l\'utiliser.';
  }

  @override
  String get converterRecipeNoSteps =>
      'La recette ne contient aucune étape à annuler.';

  @override
  String get converterRecipeWipedUnrecorded =>
      'Cette étape a effacé des octets qui n\'ont jamais été enregistrés.';

  @override
  String get converterRecipeCutUnrecorded =>
      'Cette étape a coupé des octets qui n\'ont jamais été enregistrés.';

  @override
  String get converterRecipeShorter =>
      'Le fichier est plus court que ce que la recette attend.';

  @override
  String get converterRepairRecipeMismatch =>
      'Cette recette a été créée pour un autre fichier que celui que vous avez ouvert. L\'annuler quand même donnera presque certainement n\'importe quoi.';

  @override
  String converterRepairRecipeWrongSize(String recipeSize, String openedSize) {
    return 'Cette recette correspond à un fichier de $recipeSize, mais celui que vous avez ouvert fait $openedSize. Choisissez la paire correspondante.';
  }

  @override
  String converterRepairLostSteps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count étapes',
      one: '1 étape',
    );
    return 'Cette recette contient $_temp0 qui ont détruit des octets sans les enregistrer ; l\'original ne peut donc pas être reconstruit à partir d\'elle.';
  }

  @override
  String converterRepairUndid(String step) {
    return 'Annulé : $step';
  }

  @override
  String get converterRepairChecksumExact =>
      'Le résultat correspond exactement à la somme de contrôle d\'origine : c\'est le fichier qui a été corrompu, octet pour octet.';

  @override
  String get converterRepairChecksumChanged =>
      'Le fichier reconstruit ne correspond pas à la somme de contrôle enregistrée lors de la corruption : quelque chose d\'autre l\'a modifié depuis.';

  @override
  String get converterRepairFormatRecipe => 'Restauré depuis la recette';

  @override
  String get converterRepairEmpty =>
      'Ce fichier est vide : il n\'y a rien à réparer.';

  @override
  String converterRepairFoundHeader(String label, String size) {
    return 'L\'en-tête $label a été trouvé à $size dans le fichier ; tout ce qui le précédait a été supprimé.';
  }

  @override
  String converterRepairFoundStart(String label, String size) {
    return 'Un fichier $label commence à $size dans le fichier ; tout ce qui le précédait a été supprimé.';
  }

  @override
  String converterRepairHeaderGone(String ext, String label) {
    return 'L\'en-tête a disparu : rien dans les octets n\'indique de quoi il s\'agit. On se fie au nom .$ext et on le traite comme un fichier $label.';
  }

  @override
  String get converterRepairNoSignature =>
      'Ce fichier ne commence par aucune signature que luma reconnaisse, et son nom ne donne pas non plus d\'indice. Seules les vérifications générales ont été effectuées.';

  @override
  String converterRepairExtMismatch(String ext, String label, String newExt) {
    return 'Le fichier s\'appelle .$ext mais son contenu est un fichier $label. L\'enregistrer en .$newExt permettra de nouveau de l\'ouvrir.';
  }

  @override
  String converterRepairGenericOnly(String label) {
    return 'luma sait qu\'il s\'agit d\'un fichier $label, mais n\'a pas de réparateur structurel pour ce format : seules les vérifications générales ont été effectuées.';
  }

  @override
  String get converterRepairFormatUnknown => 'Format inconnu';

  @override
  String converterRepairTrimmed(String size) {
    return '$size de remplissage de zéros retirés de la fin, ce que laisse une copie interrompue.';
  }

  @override
  String get converterRepairPaddingOnly =>
      'Une fois le remplissage de zéros retiré, il ne restait que du bourrage.';

  @override
  String get converterRepairNothingChanged =>
      'Rien à modifier : la structure est déjà correcte.';

  @override
  String get repairBmpTooShort =>
      'Un BMP a besoin d’au moins un en-tête de fichier de 14 octets et d’un en-tête DIB.';

  @override
  String get repairBmpMagicRewritten => 'Octets magiques « BM » réécrits.';

  @override
  String repairBmpSizeCorrected(int declared, int actual) {
    return 'Champ de taille du fichier corrigé de $declared à $actual.';
  }

  @override
  String repairBmpDibUnknown(int size) {
    return 'La taille de l’en-tête DIB vaut $size, ce qui ne correspond à aucune structure BMP connue. La largeur, la hauteur et la profondeur de couleur sont irrécupérables.';
  }

  @override
  String repairBmpDimensionsImpossible(int width, int height, int bpp) {
    return 'L’en-tête DIB indique $width×$height à $bpp bpp, ce qui n’est pas possible. Ces valeurs ne sont stockées nulle part ailleurs.';
  }

  @override
  String repairBmpImageInfo(int width, int height, int bpp) {
    return 'Image : $width×$height à $bpp bpp.';
  }

  @override
  String repairBmpOffsetRecalculated(int expected, int declared) {
    return 'Décalage des données de pixels recalculé à $expected (il valait $declared).';
  }

  @override
  String repairBmpPadded(String size) {
    return '$size de lignes de pixels manquantes ont été complétées en noir pour que l’image s’ouvre ; le bas de l’image est perdu.';
  }

  @override
  String repairBmpTrimmed(String size) {
    return '$size d’octets au-delà de la fin des données de pixels ont été retirés.';
  }

  @override
  String get repairGifTooShort =>
      'Un GIF a besoin d’au moins 13 octets d’en-tête ; celui-ci en a moins.';

  @override
  String get repairGifSignatureRewritten => 'Signature « GIF » réécrite.';

  @override
  String get repairGifVersionRestored => 'Version rétablie à « 89a ».';

  @override
  String repairGifScreenSizeBad(int width, int height) {
    return 'La taille de l’écran logique est $width×$height, valeur qu’aucun décodeur n’accepte. Les dimensions réelles ne sont enregistrées nulle part ailleurs.';
  }

  @override
  String repairGifScreenSizeInfo(int width, int height) {
    return 'Écran logique : $width×$height.';
  }

  @override
  String repairGifTableTruncated(String size) {
    return 'La table de couleurs globale est déclarée à $size, mais le fichier se termine avant.';
  }

  @override
  String repairGifJunkTrimmed(String size) {
    return '$size de données parasites après la fin du GIF ont été retirées.';
  }

  @override
  String get repairGifTrailerAppended => 'Octet de fin 0x3B manquant ajouté.';

  @override
  String repairJpegJunkDropped(String size) {
    return '$size de données parasites devant l’image ont été supprimées.';
  }

  @override
  String get repairJpegTooShort =>
      'Le fichier est trop court pour être un JPEG.';

  @override
  String get repairJpegSoiRewritten =>
      'Marqueur de début d’image FFD8 manquant rétabli.';

  @override
  String repairJpegMarkerExpected(String offset, String byte) {
    return 'Un marqueur était attendu à $offset, mais on a trouvé $byte.';
  }

  @override
  String repairJpegSegmentPastEnd(String offset) {
    return 'Le segment à $offset dépasse la fin du fichier.';
  }

  @override
  String get repairJpegNoSegments =>
      'Aucun segment JPEG lisible n’a survécu : les tables de quantification et de Huffman ont disparu et ne peuvent pas être devinées.';

  @override
  String get repairJpegNoScan =>
      'Le fichier n’atteint jamais son balayage d’image (SOS) : il y a un en-tête mais aucune image à décoder.';

  @override
  String get repairJpegEoiAppended =>
      'Marqueur de fin d’image FFD9 manquant ajouté.';

  @override
  String repairJpegTrailingTrimmed(String size) {
    return '$size de données parasites après le marqueur de fin ont été retirées.';
  }

  @override
  String repairMp3TagTooBig(String size) {
    return 'La balise ID3 annonce $size mais le fichier est plus petit : la balise a été supprimée et l’audio conservé.';
  }

  @override
  String repairMp3TagKept(String size) {
    return 'Balise ID3 de $size au début conservée.';
  }

  @override
  String get repairMp3NoFrames =>
      'Aucune suite de trames audio MPEG valides n’a été trouvée dans le fichier. Il ne reste aucun audio à sauver.';

  @override
  String repairMp3JunkSkipped(String size) {
    return '$size de données parasites avant la première vraie trame audio ont été ignorées.';
  }

  @override
  String repairMp3DamagedStretch(String offset) {
    return 'Un passage endommagé à $offset a été ignoré ; la lecture y sera saccadée.';
  }

  @override
  String get repairMp3FramesStop =>
      'Les trames deviennent illisibles juste après l’en-tête.';

  @override
  String repairMp3FramesSurvived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trames audio conservées.',
      one: '1 trame audio conservée.',
    );
    return '$_temp0';
  }

  @override
  String repairMp3CutTail(String size) {
    return '$size d’octets non lisibles ont été coupés à la fin.';
  }

  @override
  String get repairMp4TooShort =>
      'Le fichier est trop court pour contenir ne serait-ce qu’une box.';

  @override
  String repairMp4JunkDropped(String size) {
    return '$size de données parasites avant la box ftyp ont été supprimées.';
  }

  @override
  String get repairMp4NoFtyp =>
      'Il n’y a pas de box ftyp : le type exact de MP4 est inconnu. La structure des box a tout de même été vérifiée.';

  @override
  String repairMp4UnreadableBox(String offset) {
    return 'Nom de box illisible à $offset — l’analyse s’arrête ici.';
  }

  @override
  String repairMp4BoxClamped(
    String type,
    String offset,
    String claimed,
    String available,
  ) {
    return 'La box « $type » à $offset annonce $claimed, mais seulement $available suivent — ramenée à la taille réelle.';
  }

  @override
  String repairMp4BoxesParsed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count box de premier niveau analysées.',
      one: '1 box de premier niveau analysée.',
    );
    return '$_temp0';
  }

  @override
  String repairMp4MoovMisplaced(String offset) {
    return 'Une box moov existe à $offset, mais la chaîne des box ne l’atteint jamais. Certains lecteurs la trouveront tout de même en scannant.';
  }

  @override
  String get repairMp4NoMoov =>
      'Il n’y a pas de box moov. Cette box est l’index de tous les échantillons vidéo et audio du fichier ; sans elle, les données ne peuvent pas être lues. La récupérer nécessite un fichier intact enregistré par le même appareil.';

  @override
  String get repairMp4NoMdat =>
      'Aucune box mdat trouvée : il ne reste peut-être aucune donnée multimédia.';

  @override
  String get repairMp4ClampExplain =>
      'Limiter la taille d’une box évite aux lecteurs de dépasser la fin ; cela ne restitue pas ce qui a été coupé.';

  @override
  String repairMp4TailTrimmed(String size) {
    return '$size de fin illisible ont été retirés.';
  }

  @override
  String repairMp4TrailingTrimmed(String size) {
    return '$size de données parasites en fin de fichier ont été retirées.';
  }

  @override
  String get repairPdfHeaderAdded => 'En-tête « %PDF-1.7 » manquant rétabli.';

  @override
  String repairPdfJunkDropped(String size) {
    return '$size de données parasites avant l’en-tête PDF ont été supprimées.';
  }

  @override
  String get repairPdfNoObjects =>
      'Aucun objet PDF trouvé. Il ne reste aucune structure de document à indexer.';

  @override
  String repairPdfObjectsIntact(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count objets encore intacts trouvés.',
      one: '1 objet encore intact trouvé.',
    );
    return '$_temp0';
  }

  @override
  String get repairPdfEncrypted =>
      'Le document est chiffré. L’index peut être reconstruit, mais le lecteur demandera toujours le mot de passe de protection.';

  @override
  String get repairPdfNoCatalog =>
      'Aucun catalogue de document (/Type /Catalog) n’a survécu : rien ne pointe vers l’arbre des pages. Les lecteurs ouvriront le fichier sans trouver de pages.';

  @override
  String repairPdfCatalogFound(int root) {
    return 'Le catalogue du document est l’objet $root.';
  }

  @override
  String repairPdfFreeSlots(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count emplacements d’objets étaient vides et ont dû être marqués libres. Ce qu’ils contenaient est perdu.',
      one:
          '1 emplacement d’objet était vide et a dû être marqué libre. Ce qu’il contenait est perdu.',
    );
    return '$_temp0';
  }

  @override
  String get repairPdfXrefRebuilt =>
      'Table de références croisées reconstruite et nouveau trailer ajouté.';

  @override
  String get repairPdfXrefFromScratch =>
      'Table de références croisées et trailer créés de zéro : le fichier n’en avait aucun.';

  @override
  String get repairPngTooShort => 'Le fichier est trop court pour être un PNG.';

  @override
  String get repairPngSignatureRewritten =>
      'Signature PNG de 8 octets réécrite.';

  @override
  String repairPngUnreadableChunk(String offset) {
    return 'Nom de chunk illisible à $offset — l’analyse s’arrête ici.';
  }

  @override
  String repairPngChunkPastEnd(String type, String offset, int length) {
    return 'Le chunk « $type » à $offset annonce $length octets, mais le fichier se termine avant.';
  }

  @override
  String get repairPngNoIhdr =>
      'Aucun chunk d’en-tête IHDR n’a survécu : la taille de l’image et le type de couleur ont disparu, et rien ne peut les reconstruire.';

  @override
  String repairPngCrcRecomputed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count sommes de contrôle de chunk erronées recalculées : les données de pixels qui les suivent peuvent encore être fausses, mais les lecteurs cesseront de rejeter le fichier.',
      one:
          '1 somme de contrôle de chunk erronée recalculée : les données de pixels qui la suivent peuvent encore être fausses, mais les lecteurs cesseront de rejeter le fichier.',
    );
    return '$_temp0';
  }

  @override
  String repairPngCutAtLastChunk(String size) {
    return 'Fichier coupé au dernier chunk lisible ; $size de fin inutilisable supprimés.';
  }

  @override
  String repairPngJunkAfterIend(String size) {
    return '$size de données parasites après IEND ont été retirées.';
  }

  @override
  String get repairPngNoChunks => 'Le fichier ne contient plus aucun chunk.';

  @override
  String get repairPngIendAppended => 'Chunk de fin IEND manquant ajouté.';

  @override
  String get repairRiffTooShort =>
      'Un fichier RIFF a besoin d’un en-tête d’au moins 12 octets ; celui-ci en a moins.';

  @override
  String get repairRiffMagicRewritten => 'Octets magiques « RIFF » réécrits.';

  @override
  String get repairRiffUnreadableForm =>
      'Le type de formulaire RIFF est illisible et aucun nom de chunk connu n’a survécu : impossible de savoir ce que ce fichier était.';

  @override
  String repairRiffFormRestored(String form) {
    return 'Type de formulaire rétabli à « $form ».';
  }

  @override
  String repairRiffLengthCorrected(int declared, int actual) {
    return 'Champ de longueur RIFF corrigé de $declared à $actual.';
  }

  @override
  String repairRiffUnreadableChunk(String offset) {
    return 'Nom de chunk illisible à $offset — arrêt ici.';
  }

  @override
  String repairRiffChunkClamped(String id, String claimed, String available) {
    return 'Le chunk « $id » annonce $claimed mais seulement $available sont présents — raccourci en conséquence.';
  }

  @override
  String get repairRiffNoFmt =>
      'Le chunk « fmt  » a disparu : la fréquence d’échantillonnage, le nombre de canaux et la profondeur de bits sont inconnus, et ne peuvent pas être déduits des seuls échantillons.';

  @override
  String repairRiffTrailingTrimmed(String size) {
    return '$size d’octets après le dernier chunk valide ont été retirés.';
  }

  @override
  String repairZipSkipped(String size, String offset) {
    return '$size d’octets illisibles ignorés avant l’entrée à $offset.';
  }

  @override
  String get repairZipNoEntries =>
      'Aucune entrée récupérable n’a été trouvée : tous les en-têtes de fichiers locaux ont disparu, il n’y a plus rien pour reconstruire l’archive.';

  @override
  String repairZipDamagedEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count entrées étaient trop endommagées pour être utilisées et ont été exclues de l’archive reconstruite.',
      one:
          '1 entrée était trop endommagée pour être utilisée et a été exclue de l’archive reconstruite.',
    );
    return '$_temp0';
  }

  @override
  String repairZipCentralRebuilt(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Répertoire central manquant reconstruit à partir de $count en-têtes de fichiers locaux.',
      one:
          'Répertoire central manquant reconstruit à partir de 1 en-tête de fichier local.',
    );
    return '$_temp0';
  }

  @override
  String repairZipCentralRewritten(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Répertoire central et enregistrement de fin d’archive réécrits autour de $count entrées récupérées.',
      one:
          'Répertoire central et enregistrement de fin d’archive réécrits autour de 1 entrée récupérée.',
    );
    return '$_temp0';
  }

  @override
  String repairZipUndecompressable(String name) {
    return '« $name » n’a pas pu être décompressé du tout — supprimé.';
  }

  @override
  String repairZipUnsupportedMethod(String name, int method) {
    return '« $name » utilise la méthode de compression $method, que luma ne peut pas décompresser. Il a été copié tel quel.';
  }

  @override
  String repairZipChecksumMismatch(String name) {
    return '« $name » ne correspond pas à sa somme de contrôle : le contenu est endommagé, mais l’entrée a été conservée pour que vous voyiez ce qu’il en reste.';
  }

  @override
  String repairZipOfficeComplete(String ext) {
    return 'Toutes les parties nécessaires à un .$ext sont présentes : il devrait s’ouvrir.';
  }

  @override
  String repairZipOfficeMissing(String ext, String missing) {
    return 'Le .$ext manque encore $missing. Ces parties contiennent le document lui-même, et rien ne peut les régénérer.';
  }

  @override
  String get converterSaveDialogTitle => 'Enregistrer l’image convertie';

  @override
  String converterSaved(String path) {
    return 'Enregistré dans $path';
  }

  @override
  String converterReplacedOriginal(String path) {
    return 'Original remplacé : $path';
  }

  @override
  String converterDownloaded(String name) {
    return '$name téléchargé';
  }

  @override
  String get converterSaveUnsupported =>
      'L’enregistrement de fichiers n’est pas pris en charge sur cette plateforme.';

  @override
  String get converterReplaceUnsupported =>
      'Le remplacement de fichiers n’est pas pris en charge sur cette plateforme.';

  @override
  String get converterReplaceUnsupportedWeb =>
      'Le remplacement de fichiers n’est pas pris en charge sur le web.';

  @override
  String get downscalerCouldNotRead => 'Impossible de lire cette image.';

  @override
  String get converterImageCouldNotRead =>
      'Impossible de lire cette image : elle est peut-être corrompue ou non prise en charge.';

  @override
  String get ffmpegInstallDesktopOnly =>
      'L\'installation automatique n\'est disponible que sous Windows. Ajoutez ffmpeg à votre PATH manuellement.';

  @override
  String ffmpegDownloadFailed(int status) {
    return 'Échec du téléchargement (HTTP $status). Vérifiez votre connexion et réessayez.';
  }

  @override
  String get ffmpegArchiveMissingExe =>
      'L\'archive téléchargée ne contient pas ffmpeg.exe.';

  @override
  String ffmpegInstallFailed(String error) {
    return 'Échec de l\'installation : $error';
  }

  @override
  String get ffmpegInstalledNotStarted =>
      'Installé, mais ffmpeg n\'a toujours pas pu démarrer.';

  @override
  String get ffmpegStillNotFound => 'Toujours introuvable.';

  @override
  String get ffmpegNotFound =>
      'ffmpeg est introuvable. Placez ffmpeg(.exe) à côté de l\'application ou dans le PATH du système, puis réessayez.';

  @override
  String get ffmpegNotFoundShort => 'ffmpeg est introuvable.';

  @override
  String ffmpegFailedExitCode(int code) {
    return 'ffmpeg a échoué (code de sortie $code).';
  }

  @override
  String ffmpegFailedWithDetail(String detail) {
    return 'ffmpeg a échoué : $detail';
  }

  @override
  String get ffmpegStubDesktopOnly =>
      'L\'installation de ffmpeg n\'est disponible que dans l\'application de bureau.';

  @override
  String get ffmpegAudioVideoDesktopOnly =>
      'La conversion audio et vidéo n\'est disponible que dans l\'application de bureau.';

  @override
  String get ffmpegVideoDesktopOnly =>
      'La conversion vidéo n\'est disponible que dans l\'application de bureau.';

  @override
  String get ffmpegSetupTitle => 'ffmpeg est requis';

  @override
  String get ffmpegSetupBodyInstall =>
      'Les outils audio et vidéo ont besoin de ffmpeg. Installez-le une fois et luma continuera de l\'utiliser.';

  @override
  String get ffmpegSetupBodyManual =>
      'Les outils audio et vidéo ont besoin de ffmpeg dans votre PATH. L\'installation automatique n\'est disponible que sous Windows.';

  @override
  String get ffmpegSetupPreparing => 'Préparation…';

  @override
  String ffmpegSetupDownloading(String percent) {
    return 'Téléchargement de ffmpeg… $percent %';
  }

  @override
  String get ffmpegSetupInstall => 'Installer ffmpeg';

  @override
  String get ffmpegSetupChecking => 'Vérification…';

  @override
  String get ffmpegSetupRecheck => 'Revérifier';

  @override
  String get converterSaveCancelled => 'Enregistrement annulé.';

  @override
  String get schematicLitematicNoRegions =>
      'Ce fichier .litematic ne contient aucune région.';

  @override
  String get schematicLitematicNoReadableRegions =>
      'Aucune des régions de ce fichier .litematic n\'a pu être lue.';

  @override
  String schematicLitematicMergedRegions(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count régions',
      one: '1 région',
    );
    return 'La source contenait $_temp0 ; elles ont été fusionnées en un seul bloc de $size.';
  }

  @override
  String get schematicLitematicConvertedName => 'Converti avec luma';

  @override
  String get schematicLitematicMainRegion => 'Principale';

  @override
  String get schematicMceditMissingSize =>
      'Ce fichier .schematic n\'a pas ses balises Width/Height/Length.';

  @override
  String get schematicMceditNoBlocks =>
      'Ce fichier .schematic ne contient pas de tableau Blocks.';

  @override
  String schematicMceditUnmappedIds(int count, String list) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count anciens identifiants de bloc n\'avaient pas d\'équivalent moderne et sont devenus de l\'air (ids $list).',
      one:
          '1 ancien identifiant de bloc n\'avait pas d\'équivalent moderne et est devenu de l\'air (id $list).',
    );
    return '$_temp0';
  }

  @override
  String get schematicMceditTileEntities =>
      'Le contenu des entités de bloc (inventaires de coffres, textes de panneaux) n\'est pas transféré.';

  @override
  String schematicMceditUnmappedTypes(int count, String list) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count types de blocs n\'existaient pas avant Minecraft 1.13 et sont devenus de la pierre ($list).',
      one:
          '1 type de bloc n\'existait pas avant Minecraft 1.13 et est devenu de la pierre ($list).',
    );
    return '$_temp0';
  }

  @override
  String schematicMceditInexactStates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count états de bloc ont gardé le bon bloc mais ont perdu leur orientation ou leur variante.',
      one:
          '1 état de bloc a gardé le bon bloc mais a perdu son orientation ou sa variante.',
    );
    return '$_temp0';
  }

  @override
  String get schematicMcstructureNoSize =>
      'Ce fichier .mcstructure n\'a pas de balise size.';

  @override
  String get schematicMcstructureNoIndices =>
      'Ce fichier .mcstructure n\'a pas d\'index de blocs.';

  @override
  String get schematicMcstructureNoPalette =>
      'Ce fichier .mcstructure n\'a pas de palette de blocs.';

  @override
  String get schematicBedrockApproximate =>
      'Bedrock et Java n\'ont pas le même vocabulaire de blocs, donc cette conversion est approximative.';

  @override
  String schematicBedrockReadApproximate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count entrées de palette avaient des propriétés que Java ne possède pas.',
      one: '1 entrée de palette avait des propriétés que Java ne possède pas.',
    );
    return '$_temp0';
  }

  @override
  String schematicBedrockWriteApproximate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count entrées de palette ont perdu une propriété que Bedrock ne possède pas.',
      one:
          '1 entrée de palette a perdu une propriété que Bedrock ne possède pas.',
    );
    return '$_temp0';
  }

  @override
  String schematicMcstructureTooLarge(String size) {
    return 'Cette construction fait $size. Une structure Bedrock enregistre chaque position dans deux listes d\'index, donc une structure de cette taille serait inutilisablement lourde, et Bedrock ne charge que 64 blocs par côté. Convertissez plutôt en .litematic ou .schem.';
  }

  @override
  String get schematicMcstructureSplitNeeded =>
      'Les blocs de structure Bedrock ne chargent que 64×64×64 à la fois, cette construction devra donc être découpée en jeu.';

  @override
  String get schematicFormatSpongeDescription => 'Schéma Sponge (WorldEdit)';

  @override
  String get schematicFormatMceditDescription => 'MCEdit ancien';

  @override
  String get schematicFormatStructureDescription => 'Bloc de structure vanilla';

  @override
  String get schematicFormatMcstructureDescription => 'Structure Bedrock';

  @override
  String get schematicEmptyArea =>
      'Ce fichier déclare une zone vide, il n\'y a donc rien à convertir.';

  @override
  String schematicVolumeTooLarge(
    int width,
    int height,
    int length,
    int millions,
  ) {
    return 'Cette construction fait $width×$height×$length, ce qui dépasse les $millions millions de blocs que le convertisseur peut contenir en mémoire.';
  }

  @override
  String get schematicPaletteTooLarge =>
      'Cette construction utilise plus de 65535 états de blocs distincts, soit plus que le convertisseur ne peut gérer.';

  @override
  String get schematicNotRecognised =>
      'Ce fichier n\'est pas un schéma, une structure ou un litematic Minecraft que luma reconnaît.';

  @override
  String get schematicLegacyPaletteLoss =>
      'Le format ancien n\'a pas de palette : les constructions avec de nombreuses variantes de blocs perdent ici le plus de détails.';

  @override
  String get schematicSpongeMissingSize =>
      'Ce fichier .schem n\'a pas ses balises Width/Height/Length.';

  @override
  String get schematicSpongeV3NoBlocks =>
      'Ce fichier .schem version 3 n\'a pas de balise Blocks.';

  @override
  String get schematicSpongeNoPalette =>
      'Ce fichier .schem n\'a ni palette de blocs ni données de blocs.';

  @override
  String get schematicSpongeTruncatedValue =>
      'Les données de blocs se terminent au milieu d\'une valeur.';

  @override
  String get schematicSpongeCorrupt => 'Les données de blocs sont corrompues.';

  @override
  String schematicSpongeShortBlocks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocs',
      one: '1 bloc',
    );
    return 'Les données de blocs s\'arrêtent $_temp0 avant la taille déclarée ; le reste a été rempli d\'air.';
  }

  @override
  String get schematicStructureNoSize =>
      'Ce fichier .nbt n\'a pas de balise size, ce n\'est donc pas un fichier de structure.';

  @override
  String get schematicStructureNoPalette =>
      'Ce fichier de structure n\'a pas de palette.';

  @override
  String schematicStructureOutOfBounds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocs se trouvaient',
      one: '1 bloc se trouvait',
    );
    return '$_temp0 hors de la taille déclarée et ont été ignorés.';
  }

  @override
  String schematicStructureTooLarge(
    int width,
    int height,
    int length,
    int limit,
  ) {
    return 'Cette construction fait $width×$height×$length. Un fichier de structure vanilla stocke chaque position séparément, un fichier de cette taille serait donc inutilisablement lourd, et un bloc de structure ne charge que $limit blocs par côté. Convertissez plutôt en .litematic ou .schem.';
  }

  @override
  String schematicStructureTooLong(
    int width,
    int height,
    int length,
    int limit,
  ) {
    return 'Cette construction fait $width×$height×$length, au-delà de la limite de $limit blocs qu\'un bloc de structure peut charger. Elle devra être découpée en jeu.';
  }

  @override
  String get schematicNbtNotCompoundRoot =>
      'La racine NBT n\'est pas une balise de type compound.';

  @override
  String get schematicNbtNotNbt =>
      'Ceci ne ressemble pas à un fichier NBT : la racine n\'est pas une balise compound.';

  @override
  String schematicNbtUnknownTag(int type, int position) {
    return 'Type de balise NBT inconnu $type à l\'octet $position.';
  }

  @override
  String schematicNbtTruncated(int length, int position) {
    return 'Le fichier est tronqué ou n\'est pas un NBT valide (longueur incorrecte $length à l\'octet $position).';
  }

  @override
  String get textureNoInstallation =>
      'Aucune installation de Minecraft trouvée sur cet appareil.';

  @override
  String get textureFileNoBlockTextures =>
      'Ce fichier ne contient aucune texture de bloc.';

  @override
  String textureCouldNotRead(String error) {
    return 'Impossible de lire les textures de blocs : $error';
  }

  @override
  String textureCouldNotDownload(String error) {
    return 'Impossible de télécharger les textures de blocs : $error';
  }

  @override
  String get textureNeedsFilesystem =>
      'Les textures de blocs nécessitent un système de fichiers pour être lues.';

  @override
  String get textureDownloadUnsupported =>
      'Les textures de blocs ne peuvent être téléchargées que sur ordinateur et Android.';

  @override
  String get textureMojangBadVersionId =>
      'Mojang a renvoyé un identifiant de version inutilisable.';

  @override
  String get textureCouldNotReachMojang =>
      'Impossible de joindre Mojang. Vérifiez votre connexion et réessayez.';

  @override
  String textureManifestStatus(int code) {
    return 'Mojang a renvoyé $code pour le manifeste de versions.';
  }

  @override
  String textureClientStatus(int code) {
    return 'Mojang a renvoyé $code pour le téléchargement du client.';
  }

  @override
  String get textureManifestNoRelease =>
      'Le manifeste de versions de Mojang n\'indique aucune version stable actuelle.';

  @override
  String get textureManifestMalformed =>
      'Le manifeste de versions de Mojang est mal formé.';

  @override
  String textureManifestNoEntry(String version) {
    return 'Le manifeste de Mojang ne contient aucune entrée pour $version.';
  }

  @override
  String textureVersionNoClient(String version) {
    return 'La version $version n\'a pas de téléchargement client.';
  }

  @override
  String get textureDownloadFailed =>
      'Impossible de télécharger les textures. Vérifiez votre connexion et réessayez.';

  @override
  String textureDownloadEndedEarly(int received, int expected) {
    return 'Le téléchargement s\'est arrêté trop tôt : $received octets sur $expected reçus.';
  }

  @override
  String get textureChecksumMismatch =>
      'Le fichier téléchargé ne correspond pas à la somme de contrôle de Mojang.';

  @override
  String get textureStageAskingVersion =>
      'Demande à Mojang quelle version est la plus récente…';

  @override
  String get textureStageUsingCopy =>
      'Utilisation de la copie déjà téléchargée.';

  @override
  String textureStageDownloading(String version) {
    return 'Téléchargement de Minecraft $version…';
  }

  @override
  String get textureStageVerifying => 'Vérification du téléchargement…';

  @override
  String get textureStageReading => 'Lecture des textures de blocs…';

  @override
  String get audioEditorTitle => 'Éditeur audio';

  @override
  String get audioEditorSubtitle =>
      'Coupez, égalisez et prévisualisez le son avant l\'export';

  @override
  String get audioEditorPickPrompt => 'Touchez pour choisir un audio';

  @override
  String get audioEditorEditAnother => 'Modifier un autre';

  @override
  String get audioEditorReadingWaveform =>
      'Lecture de l\'audio et création de la forme d\'onde…';

  @override
  String get audioEditorNoFilePath =>
      'Impossible de lire le chemin du fichier — la modification nécessite l\'application de bureau.';

  @override
  String get audioEditorCannotRead => 'Impossible de lire ce fichier audio.';

  @override
  String audioEditorLoadFailed(String error) {
    return 'Impossible de charger ce fichier : $error';
  }

  @override
  String get audioEditorEverythingCut =>
      'Tout a été coupé — supprimez d\'abord une coupe.';

  @override
  String get audioEditorPreviewDesktopOnly =>
      'La lecture de prévisualisation n\'est disponible que dans l\'application de bureau.';

  @override
  String audioEditorPreviewFailed(String error) {
    return 'Impossible de lire la prévisualisation : $error';
  }

  @override
  String audioEditorSaveFailed(String error) {
    return 'Impossible d\'enregistrer : $error';
  }

  @override
  String get audioEditorCutTitle => 'Couper & rogner';

  @override
  String get audioEditorCutSubtitle =>
      'Faites glisser sur la forme d\'onde pour sélectionner une plage, puis coupez-la ou ne gardez que la sélection.';

  @override
  String audioEditorSelectionRange(String start, String end) {
    return 'Sélection  $start – $end';
  }

  @override
  String audioEditorOutputOfTotal(String output, String total) {
    return 'Sortie $output sur $total';
  }

  @override
  String get audioEditorCutSelection => 'Couper la sélection';

  @override
  String get audioEditorKeepSelection => 'Garder seulement la sélection';

  @override
  String get audioEditorClearCuts => 'Effacer toutes les coupes';

  @override
  String get audioEditorEqualizerTitle => 'Égaliseur';

  @override
  String get audioEditorEqualizerSubtitle =>
      'Amplifiez ou atténuez chaque bande jusqu\'à 12 dB.';

  @override
  String get audioEditorReset => 'Réinitialiser';

  @override
  String get audioEditorPresetFlat => 'Plat';

  @override
  String get audioEditorPresetBassBoost => 'Renforcement des basses';

  @override
  String get audioEditorPresetVocal => 'Voix';

  @override
  String get audioEditorPresetTreble => 'Aigus';

  @override
  String get audioEditorEffectsTitle => 'Effets';

  @override
  String get audioEditorVolume => 'Volume';

  @override
  String get audioEditorSpeed => 'Vitesse';

  @override
  String get audioEditorFadeIn => 'Fondu d\'entrée';

  @override
  String get audioEditorFadeOut => 'Fondu de sortie';

  @override
  String get audioEditorPreviewRenderHint =>
      'Génère vos modifications, puis joue le résultat.';

  @override
  String get audioEditorPreviewExactHint =>
      'Écoutez exactement ce qui sera exporté.';

  @override
  String get audioEditorMakeEditToExport =>
      'Faites une modification ci-dessus pour activer l\'export.';

  @override
  String get audioEditorGenerateSave => 'Générer et enregistrer';

  @override
  String get collageMakerTitle => 'Créateur de collages';

  @override
  String get collageMakerSubtitle =>
      'Créez des collages de photos avec des modèles';

  @override
  String get collageMakerImportPrompt => 'Importez des photos pour commencer';

  @override
  String get collageMakerImportedPhotos => 'Photos importées';

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
  String get collageMakerChooseLayout => 'Choisissez une mise en page';

  @override
  String get collageMakerNewShape => 'Nouvelle forme';

  @override
  String get collageMakerCanvas => 'Canevas';

  @override
  String collageMakerSlotsFilled(int slots, int filled) {
    return '$slots emplacements · $filled remplis';
  }

  @override
  String get collageMakerDropHere => 'Déposez ici';

  @override
  String get collageMakerDragPhoto => 'Faites glisser une photo';

  @override
  String get collageMakerSettings => 'Paramètres';

  @override
  String get collageMakerAspectRatio => 'Format';

  @override
  String get collageMakerBackground => 'Arrière-plan';

  @override
  String get collageMakerGap => 'Espace';

  @override
  String get collageMakerRadius => 'Rayon';

  @override
  String get collageMakerBgWhite => 'Blanc';

  @override
  String get collageMakerBgBlack => 'Noir';

  @override
  String get collageMakerBgTransparent => 'Transparent';

  @override
  String get collageMakerBgDark => 'Sombre';

  @override
  String get collageMakerTplTwoHorizontal => '2 horizontaux';

  @override
  String get collageMakerTplTwoVertical => '2 verticaux';

  @override
  String get collageMakerTplThreeColumn => '3 colonnes';

  @override
  String get collageMakerTplTwoByTwo => 'Grille 2×2';

  @override
  String get collageMakerTplLShape => 'Forme en L';

  @override
  String get collageMakerTplHeroStrip => 'Héros + bande';

  @override
  String get collageMakerTplThreeByThree => 'Grille 3×3';

  @override
  String get collageMakerTplMosaic => 'Mosaïque';

  @override
  String get collageMakerTplPanorama => 'Panorama';

  @override
  String get collageMakerTplCross => 'Croix';

  @override
  String get collageMakerTplThreeRow => '3 lignes';

  @override
  String get collageMakerTplFourColumn => '4 colonnes';

  @override
  String get collageMakerTplRightLShape => 'Forme en L inversée';

  @override
  String get collageMakerTplStripHero => 'Bande + héros';

  @override
  String get collageMakerTplSidebar => 'Barre latérale';

  @override
  String get collageMakerTplFilmstrip => 'Bande de film';

  @override
  String get collageMakerTplFrame => 'Cadre';

  @override
  String get collageMakerTplWindowpane => 'Carreaux';

  @override
  String get collageMakerTplCascade => 'Cascade';

  @override
  String get collageMakerDownloadPng => 'Télécharger le PNG';

  @override
  String get collageMakerExportPng => 'Exporter le PNG';

  @override
  String get collageMakerReset => 'Réinitialiser';

  @override
  String get collageMakerNewCollage => 'Nouveau collage';

  @override
  String collageMakerExportFailed(String error) {
    return 'Échec de l\'export : $error';
  }

  @override
  String get collageShapeTitle => 'Concevez votre mise en page';

  @override
  String get collageShapeSubtitle =>
      'Ajoutez, déplacez et redimensionnez des cadres pour créer votre forme';

  @override
  String get collageShapeLayout => 'Mise en page';

  @override
  String collageShapeFrameCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cadres',
      one: '1 cadre',
    );
    return '$_temp0';
  }

  @override
  String get collageShapeName => 'Nom';

  @override
  String get collageShapeNameHint => 'ex. Ma mise en page';

  @override
  String get collageShapeSave => 'Enregistrer la forme';

  @override
  String get collageShapeAddFrame => 'Ajouter un cadre';

  @override
  String get collageShapeSplitHorizontal => 'Diviser ↔';

  @override
  String get collageShapeSplitVertical => 'Diviser ↕';

  @override
  String get collageShapeDelete => 'Supprimer';

  @override
  String get collageShapeClearAll => 'Tout effacer';

  @override
  String get collageShapeSnap => 'Aligner sur la grille';

  @override
  String get collageShapeEmptyHint =>
      'Touchez « Ajouter un cadre » pour commencer à créer votre forme';

  @override
  String get downscalerTitle => 'Réducteur d\'image';

  @override
  String get downscalerSubtitle =>
      'Réduisez la taille des fichiers image avec des optimisations cumulables';

  @override
  String get downscalerPickPrompt => 'Touchez pour choisir une image';

  @override
  String get downscalerPickFormats => 'PNG ou JPEG';

  @override
  String get downscalerOptimizeAnother => 'Optimiser une autre';

  @override
  String get downscalerReadFailed =>
      'Impossible de lire le fichier sélectionné.';

  @override
  String get downscalerDecodeFailed =>
      'Impossible de lire cette image : elle est peut-être corrompue ou non prise en charge.';

  @override
  String downscalerEstimateFailed(String error) {
    return 'Impossible d\'estimer la taille : $error';
  }

  @override
  String get downscalerOptimizations => 'Optimisations';

  @override
  String get downscalerOptimizationsHint =>
      'Combinez-les librement. Survolez pour les détails ; les puces indiquent ce que chacune économise seule.';

  @override
  String get downscalerScale => 'Échelle';

  @override
  String get downscalerColors => 'Couleurs';

  @override
  String get downscalerDithering => 'Tramage';

  @override
  String get downscalerDepth => 'Profondeur';

  @override
  String get downscalerBits32 => '32 bits';

  @override
  String get downscalerBits16 => '16 bits';

  @override
  String get downscalerBits8 => '8 bits';

  @override
  String get downscalerOriginal => 'Original';

  @override
  String downscalerEstimated(String format) {
    return 'Estimé ($format)';
  }

  @override
  String downscalerSavesPercent(String percent, String size) {
    return 'Économise $percent % ($size)';
  }

  @override
  String downscalerLargerPercent(String percent) {
    return '$percent % plus grand que l\'original';
  }

  @override
  String get downscalerOptimizeDownload => 'Optimiser et télécharger';

  @override
  String get downscalerOptimizeSave => 'Optimiser et enregistrer';

  @override
  String get downscalerOptimizeReplace => 'Optimiser et remplacer l\'original';

  @override
  String get downscalerSelectOne => 'Sélectionnez au moins une optimisation';

  @override
  String get downscalerResizeTitle => 'Redimensionner la résolution';

  @override
  String get downscalerResizeDesc =>
      'Réduisez les dimensions en pixels. Moins de pixels est généralement le plus gros gain de taille.';

  @override
  String get downscalerColorDepthTitle => 'Réduire la profondeur des couleurs';

  @override
  String get downscalerColorDepthDesc =>
      'Convertit l\'image vers une petite palette de couleurs (par ex. 64 ou 16 couleurs). Idéal pour les graphiques plats et les captures d\'écran.';

  @override
  String get downscalerBitDepthTitle => 'Réduire la profondeur de bits';

  @override
  String get downscalerBitDepthDesc =>
      'Conserve moins de bits par canal de couleur (32 → 16 → 8 bits). Légères bandes, mais bien meilleure compression.';

  @override
  String get downscalerStripMetadataTitle => 'Supprimer les métadonnées';

  @override
  String get downscalerStripMetadataDesc =>
      'Supprime le profil ICC intégré, les données EXIF et les blocs de texte. Aucun changement visible.';

  @override
  String get downscalerRemoveAlphaTitle => 'Supprimer le canal alpha';

  @override
  String get downscalerRemoveAlphaDesc =>
      'Supprime le canal de transparence. Proposé uniquement si l\'image est entièrement opaque, donc sans perte.';

  @override
  String get downscalerRemoveAlphaDisabled =>
      'Indisponible — cette image n\'a pas de canal alpha ou utilise une vraie transparence.';

  @override
  String get downscalerTrimTitle => 'Rogner les bordures transparentes';

  @override
  String get downscalerTrimDesc =>
      'Recadre les bords entièrement transparents autour de l\'image.';

  @override
  String get downscalerTrimDisabled =>
      'Indisponible — aucune bordure transparente à rogner.';

  @override
  String get downscalerPngRecompressTitle => 'Recompression PNG sans perte';

  @override
  String get downscalerPngRecompressDesc =>
      'Réencode le PNG avec une compression maximale. Sans risque, aucun changement visible.';

  @override
  String get downscalerToWebpTitle => 'Convertir en WebP';

  @override
  String get downscalerToWebpDesc =>
      'Encode le résultat en WebP, souvent bien plus petit qu\'un PNG.';

  @override
  String get downscalerToWebpDisabled =>
      'Indisponible — WebP nécessite ffmpeg (application de bureau uniquement).';

  @override
  String get convFileReadFailed => 'Impossible de lire le fichier sélectionné.';

  @override
  String get convTapToPickFile => 'Touchez pour choisir un fichier';

  @override
  String get convOtherSubtitle =>
      'Petits outils qui ne rentrent nulle part ailleurs';

  @override
  String get convOtherMinecraftWorld => 'Convertisseur de mondes Minecraft';

  @override
  String get convOtherMinecraftWorldSub =>
      'Java ↔ Bedrock · versions, entités, joueurs et statistiques';

  @override
  String get convOtherMinecraftSchematics => 'Schémas Minecraft';

  @override
  String get convOtherBadgeDamage => 'DÉGÂTS';

  @override
  String get convOtherBadgeRepair => 'RÉPARATION';

  @override
  String get convOtherCorruptor => 'Corrupteur de fichiers';

  @override
  String get convOtherCorruptorSub =>
      'Casser un fichier exprès — le réparer plus tard, ou non';

  @override
  String get convOtherFixer => 'Réparateur de fichiers';

  @override
  String get convOtherFixerSub =>
      'Restaurer un fichier, ou réparer un fichier endommagé';

  @override
  String get convOtherFooter =>
      'L\'outil de schémas convertit l\'un des cinq formats de blocs en n\'importe quel autre et affiche la construction en 3D avant l\'enregistrement. Le corrupteur et le réparateur vont de pair : corrompez avec une recette et le réparateur reconstruit l\'original octet par octet, ou donnez-lui un fichier endommagé quelconque et il reconstruit la structure qu\'il peut.';

  @override
  String get convCorruptorSubtitle =>
      'Casser un fichier exprès, et garder la clé pour le restaurer';

  @override
  String get convCorruptPickSubtitle =>
      'N\'importe quel fichier — l\'original n\'est jamais modifié';

  @override
  String get convCorruptDamageLabel => 'Dégâts';

  @override
  String get convCorruptPickMany => 'Choisissez-en un ou plusieurs';

  @override
  String get convCorruptHowHard => 'Intensité';

  @override
  String convCorruptSeed(String seed) {
    return 'Graine $seed';
  }

  @override
  String get convCorruptNewSeed => 'Nouvelle graine';

  @override
  String get convCorruptButton => 'Corrompre le fichier';

  @override
  String get convCorruptNoRecipeWarning =>
      'Aucune recette de restauration ne sera écrite. Personne, luma compris, ne pourra annuler cela.';

  @override
  String get convCorruptSaveCorrupted => 'Enregistrer le fichier corrompu';

  @override
  String get convCorruptDownloadCorrupted => 'Télécharger le fichier corrompu';

  @override
  String get convCorruptKeepRecipe =>
      'Gardez la recette en lieu sûr : c\'est la seule chose qui peut annuler cela.';

  @override
  String get convCorruptSaveRecipe => 'Enregistrer la recette .lumafix';

  @override
  String get convCorruptDownloadRecipe => 'Télécharger la recette .lumafix';

  @override
  String get convCorruptAnother => 'Corrompre un autre fichier';

  @override
  String get convCorruptRecoverable => 'Réversible';

  @override
  String get convCorruptPermanent => 'Définitif';

  @override
  String get convCorruptRecipeTitle => 'Écrire une recette de restauration';

  @override
  String get convCorruptRecipeOn =>
      'Un fichier .lumafix enregistre chaque modification, afin que le réparateur reconstruise l\'original à l\'identique.';

  @override
  String get convCorruptRecipeOff =>
      'Rien n\'est enregistré. Les dégâts sont définitifs.';

  @override
  String convCorruptUnexpectedError(String error) {
    return 'Un problème est survenu lors de la corruption de ce fichier : $error';
  }

  @override
  String get convFixPickTitle => 'Touchez pour choisir le fichier endommagé';

  @override
  String get convFixPickSubtitle =>
      'Images · archives · documents · audio · vidéo';

  @override
  String get convFixerSubtitle =>
      'Annuler ce qu\'a fait le corrupteur, ou réparer un fichier endommagé';

  @override
  String get convFixRecipeReadFailed => 'Impossible de lire la recette.';

  @override
  String convFixUnexpectedError(String error) {
    return 'Un problème est survenu lors de la réparation de ce fichier : $error';
  }

  @override
  String get convFixBestEffort => 'Réparation au mieux';

  @override
  String get convFixExactRestore =>
      'Restauration exacte à partir de la recette';

  @override
  String get convFixNoRecipeBody =>
      'Aucune recette chargée : luma va déterminer le type du fichier et reconstruire la structure possible. Les en-têtes, sommes de contrôle et index peuvent revenir ; les octets écrasés ne le peuvent pas.';

  @override
  String convFixRecipeInfo(String age, String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count étapes',
      one: '1 étape',
    );
    return 'Enregistrée $age pour « $name » en $_temp0. L\'original revient octet par octet.';
  }

  @override
  String get convFixAgeJustNow => 'à l\'instant';

  @override
  String convFixAgeMinutes(int count) {
    return 'il y a $count min';
  }

  @override
  String convFixAgeHours(int count) {
    return 'il y a $count h';
  }

  @override
  String convFixAgeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count jours',
      one: 'il y a 1 jour',
    );
    return '$_temp0';
  }

  @override
  String get convFixLoadRecipe => 'Charger une recette .lumafix';

  @override
  String get convFixAnalyseRepair => 'Analyser et réparer';

  @override
  String get convFixRestoreOriginal => 'Restaurer l\'original';

  @override
  String get convFixDownloadRepaired => 'Télécharger le fichier réparé';

  @override
  String get convFixSaveRepaired => 'Enregistrer le fichier réparé';

  @override
  String get convFixAnother => 'Réparer un autre';

  @override
  String get convFixRestoredExactly => 'Restauré à l\'identique';

  @override
  String convFixRepairsApplied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count réparations appliquées',
      one: '1 réparation appliquée',
    );
    return '$_temp0';
  }

  @override
  String get convFixNothingToRepair => 'Rien à réparer';

  @override
  String convFixSizeInOut(String from, String to) {
    return '$from en entrée · $to en sortie';
  }

  @override
  String get convFixStructuralWarning =>
      'Une réparation structurelle remet le conteneur en ordre. Elle ne peut pas inventer un contenu écrasé : vérifiez le résultat avant de vous y fier.';

  @override
  String get convMediaAudioTitle => 'Convertisseur audio';

  @override
  String get convMediaAudioSubtitle =>
      'Convertir entre MP3, OGG, FLAC, M4A, WAV et AAC';

  @override
  String get convMediaVideoTitle => 'Convertisseur vidéo';

  @override
  String get convMediaVideoSubtitle =>
      'Convertir entre MP4, MOV, WEBM, OGV, MPG, M4V (ou en M4A)';

  @override
  String get convMediaNoFilePath =>
      'Impossible de lire le chemin du fichier : la conversion nécessite l\'application de bureau.';

  @override
  String convMediaConvertFailed(String error) {
    return 'Un problème est survenu pendant la conversion : $error';
  }

  @override
  String get convMediaConvertTo => 'Convertir en';

  @override
  String get convMediaQuality => 'Qualité';

  @override
  String get convMediaQualitySmaller => 'Plus petit';

  @override
  String get convMediaQualityBalanced => 'Équilibré';

  @override
  String get convMediaQualityHigh => 'Élevée';

  @override
  String get convMediaConvertSave => 'Convertir et enregistrer';

  @override
  String get convMediaConvertAnother => 'Convertir un autre';

  @override
  String convImgEditUnexpectedError(String error) {
    return 'Un problème est survenu : $error';
  }

  @override
  String get convImgEditCantRead => 'Impossible de lire cette image.';

  @override
  String convImgEditSaveFailed(String error) {
    return 'Impossible d\'enregistrer : $error';
  }

  @override
  String get convImgEditTitle => 'Éditeur d\'images';

  @override
  String get convImgEditSubtitle =>
      'Pivoter, ajuster, filtrer et supprimer les arrière-plans';

  @override
  String get convImgEditPickTitle => 'Touchez pour choisir une image';

  @override
  String get convImgEditSaveReplace => 'Enregistrer et remplacer l\'original';

  @override
  String get convImgEditDownloadPng => 'Télécharger le PNG';

  @override
  String get convImgEditSavePng => 'Enregistrer le PNG';

  @override
  String get convImgEditResetEdits => 'Réinitialiser les modifications';

  @override
  String get convImgEditAnother => 'Modifier une autre';

  @override
  String get convImgEditMetadata => 'Métadonnées';

  @override
  String get convImgEditTransform => 'Transformer';

  @override
  String get convImgEditAdjustments => 'Réglages';

  @override
  String get convImgEditFilters => 'Filtres';

  @override
  String get convImgEditBgRemoval => 'Suppression de l\'arrière-plan';

  @override
  String get convImgEditBgRemovalBody =>
      'Rendre les pixels blancs transparents. Augmentez la tolérance pour inclure aussi les pixels blanc cassé.';

  @override
  String get convImgEditRotateLeft => 'Pivoter à gauche';

  @override
  String get convImgEditRotateRight => 'Pivoter à droite';

  @override
  String get convImgEditFlipHorizontal => 'Retourner horizontalement';

  @override
  String get convImgEditFlipVertical => 'Retourner verticalement';

  @override
  String get convImgEditBrightness => 'Luminosité';

  @override
  String get convImgEditContrast => 'Contraste';

  @override
  String get convImgEditSaturation => 'Saturation';

  @override
  String get convImgEditFilterGrayscale => 'Niveaux de gris';

  @override
  String get convImgEditFilterSepia => 'Sépia';

  @override
  String get convImgEditFilterInvert => 'Inverser';

  @override
  String get convImgEditTolerance => 'Tolérance';

  @override
  String get convImgEditRemoveAllMeta => 'Tout supprimer';

  @override
  String get convImgEditMetaExisting =>
      'Cette image contient déjà des métadonnées. Modifiez-les ci-dessous ou supprimez-les toutes.';

  @override
  String get convImgEditMetaNew =>
      'Ajoutez un titre, un auteur ou une mention de copyright au fichier enregistré.';

  @override
  String get convImgEditAuthor => 'Auteur';

  @override
  String get convImgEditCopyright => 'Copyright';

  @override
  String get convImgEditNotSet => 'Non défini';

  @override
  String get pictureConvUnsupported =>
      'Ce fichier n\'est pas une image prise en charge (PNG, JPG, BMP, TIFF, ICO, SVG ou OIP).';

  @override
  String get pictureConvSubtitle =>
      'Convertir entre PNG, JPG, BMP, TIFF, ICO, SVG et OIP';

  @override
  String get pictureConvSvgVector =>
      'Le SVG est vectoriel : il sera rastérisé à une taille nette avant la conversion.';

  @override
  String get pictureConvConvertDownload => 'Convertir et télécharger';

  @override
  String get schemConvTitle => 'Schémas Minecraft';

  @override
  String get schemConvSubtitle =>
      'Convertir entre schem, litematic, schematic, nbt et mcstructure';

  @override
  String get schemConvPickPrompt => 'Touchez pour choisir une construction';

  @override
  String get schemConvReading => 'Lecture de la construction…';

  @override
  String schemConvReadFailed(String error) {
    return 'Une erreur s\'est produite pendant la lecture de ce fichier : $error';
  }

  @override
  String get schemConvBedrockNote =>
      'Bedrock utilise des identifiants et des états de blocs différents de Java, donc cette conversion est une traduction au mieux.';

  @override
  String get schemConvConvertDownload => 'Convertir et télécharger';

  @override
  String get schemConvWorthKnowing => 'Bon à savoir';

  @override
  String schemConvBlockCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocs',
      one: '1 bloc',
    );
    return '$_temp0';
  }

  @override
  String get schemConvPreview3d => 'Aperçu 3D';

  @override
  String get schemConvPreviewHint =>
      'Glisser pour orbiter · défiler pour zoomer';

  @override
  String get schemConvMaterials => 'Matériaux';

  @override
  String get schemConvStatBlocks => 'Blocs';

  @override
  String get schemConvStatVolume => 'Volume';

  @override
  String get schemConvStatBlockTypes => 'Types de blocs';

  @override
  String get schemConvNoBlocks => 'Cette construction ne contient aucun bloc.';

  @override
  String get schemConvShowFewer => 'Afficher moins';

  @override
  String schemConvShowAll(int count) {
    return 'Afficher les $count types de blocs';
  }

  @override
  String get schemViewerEmpty =>
      'Rien à afficher : cette construction ne contient que de l\'air.';

  @override
  String schemViewerSemantics(int width, int height, int length) {
    return 'Aperçu 3D de la construction, $width sur $height sur $length blocs. Faites glisser pour faire pivoter, ou utilisez les boutons de rotation et de zoom ci-dessous.';
  }

  @override
  String schemViewerSimplified(int stride) {
    return 'Cette construction est trop grande pour être dessinée bloc par bloc, l\'aperçu est donc simplifié $stride× — le fichier converti conserve chaque bloc.';
  }

  @override
  String schemViewerDownloadProgress(
    String stage,
    String received,
    String total,
  ) {
    return '$stage $received sur $total';
  }

  @override
  String schemViewerTexturesFrom(String source, int count) {
    return 'Textures de $source ($count blocs)';
  }

  @override
  String schemViewerFlatColours(String size) {
    return 'Couleurs unies : Minecraft introuvable. Téléchargez les textures depuis Mojang (~$size) ou utilisez votre propre copie.';
  }

  @override
  String schemViewerFailureFallback(String failure) {
    return '$failure Affichage des couleurs de blocs unies.';
  }

  @override
  String get schemViewerDownloadTextures => 'Télécharger les textures';

  @override
  String get schemViewerUseInstall => 'Utiliser mon installation';

  @override
  String get schemViewerLayers => 'Couches';

  @override
  String schemViewerLayerRange(int startY, int endY) {
    return 'Y $startY–$endY';
  }

  @override
  String get schemViewerZoomOut => 'Dézoomer';

  @override
  String get schemViewerZoomIn => 'Zoomer';

  @override
  String get schemViewerResetView => 'Réinitialiser la vue';

  @override
  String get vidDownNoPath =>
      'Impossible de lire le chemin du fichier : la réduction vidéo nécessite l\'application de bureau.';

  @override
  String get vidDownProbeFailed =>
      'Impossible de lire cette vidéo : elle n\'est peut-être pas prise en charge ou ffmpeg est absent.';

  @override
  String vidDownEstimateFailed(String error) {
    return 'Impossible d\'estimer la taille : $error';
  }

  @override
  String get vidDownSubtitle =>
      'Compressez et réduisez la vidéo avec des optimisations cumulables';

  @override
  String get vidDownPickPrompt => 'Touchez pour choisir une vidéo';

  @override
  String get vidDownShrinkAnother => 'Réduire une autre';

  @override
  String get vidDownShrinkDownload => 'Réduire et télécharger';

  @override
  String get vidDownShrinkSave => 'Réduire et enregistrer';

  @override
  String get vidDownOptimizationsHint =>
      'Combinez-en autant que vous voulez. Survolez une option pour les détails.';

  @override
  String get vidDownMaxHeight => 'Hauteur max.';

  @override
  String get vidDownFrameRate => 'Images/s';

  @override
  String get vidDownAudio => 'Audio';

  @override
  String get vidDownCrfHigh => 'Haute qualité';

  @override
  String get vidDownCrfSmallest => 'Le plus petit';

  @override
  String vidDownCrfLabel(String word, int crf) {
    return '$word · CRF $crf';
  }

  @override
  String get vidDownResizeTitle => 'Réduire la résolution';

  @override
  String get vidDownResizeBody =>
      'Limite la hauteur de l\'image (ex. 1080p → 720p) en gardant les proportions. Le meilleur moyen de réduire la taille des vidéos haute résolution.';

  @override
  String get vidDownQualityTitle => 'Qualité (CRF)';

  @override
  String get vidDownQualityBody =>
      'Le principal réglage de compression. Une valeur basse conserve plus de détails ; une valeur haute donne un fichier beaucoup plus petit.';

  @override
  String get vidDownFpsTitle => 'Limite d\'images par seconde';

  @override
  String get vidDownFpsBody =>
      'Limite le nombre d\'images par seconde (ex. 60 → 30). Invisible pour la plupart des vidéos et réduit nettement la taille.';

  @override
  String get vidDownH265Title => 'Réencoder en H.265';

  @override
  String get vidDownH265Body =>
      'Utilise le codec HEVC plus récent : environ 40 à 50 % plus petit que H.264 à qualité égale, mais plus lent à encoder et moins compatible avec les anciens lecteurs.';

  @override
  String get vidDownAudioBitrateTitle => 'Réduire le débit audio';

  @override
  String get vidDownAudioBitrateBody =>
      'Réencode la bande son à un débit plus faible (ex. 96 kbit/s).';

  @override
  String get vidDownNoAudio =>
      'Indisponible : cette vidéo n\'a pas de piste audio.';

  @override
  String get vidDownRemoveAudioTitle => 'Supprimer la piste audio';

  @override
  String get vidDownRemoveAudioBody =>
      'Supprime tout le son, idéal pour les captures d\'écran et les clips muets.';

  @override
  String get vidDownStripTitle => 'Supprimer les métadonnées';

  @override
  String get vidDownStripBody =>
      'Supprime les métadonnées intégrées et les marqueurs de chapitres. Aucun changement visible.';

  @override
  String get vidDownWebmTitle => 'Convertir en WebM (VP9)';

  @override
  String get vidDownWebmBody =>
      'Réencode en codec VP9/WebM : souvent plus petit que H.264 et idéal pour le web. Encodage plus lent ; produit un fichier .webm.';

  @override
  String vidDownSmaller(String percent, String saved) {
    return '≈ $percent % plus petit (économie de $saved)';
  }

  @override
  String vidDownLarger(String percent) {
    return '≈ $percent % plus grand que l\'original';
  }

  @override
  String vidDownSampleNote(String seconds) {
    return 'Estimé à partir d\'un extrait de $seconds s : la taille finale peut varier.';
  }

  @override
  String get worldConvPickFolderTitle =>
      'Sélectionnez le dossier du monde contenant level.dat';

  @override
  String get worldConvPickArchiveTitle =>
      'Sélectionnez un monde Minecraft exporté';

  @override
  String get worldConvReading => 'Lecture du monde…';

  @override
  String get worldConvPickOutputTitle =>
      'Choisissez où enregistrer le monde converti';

  @override
  String get worldConvSubtitle =>
      'Java ↔ Bedrock · terrain, entités et données des joueurs';

  @override
  String get worldConvPlatformUnsupported =>
      'La conversion de mondes est disponible sous Windows et Linux.';

  @override
  String get worldConvIntro =>
      'Fermez ce monde dans Minecraft avant de convertir. Choisissez son dossier ou un fichier .mcworld / .zip exporté, ou collez son chemin ci-dessous. L\'original reste inchangé.';

  @override
  String get worldConvChooseFolder => 'Choisir le dossier du monde';

  @override
  String get worldConvChooseArchive => 'Choisir un fichier .mcworld';

  @override
  String get worldConvPathLabel =>
      'Chemin du dossier du monde ou de .mcworld / .zip';

  @override
  String get worldConvPathHint => 'Collez un chemin ici';

  @override
  String get worldConvLoad => 'Charger le monde';

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
      other: '$entities entités',
      one: '1 entité',
    );
    String _temp1 = intl.Intl.pluralLogic(
      localPlayers,
      locale: localeName,
      other: '$localPlayers joueurs locaux',
      one: '1 joueur local',
    );
    String _temp2 = intl.Intl.pluralLogic(
      remotePlayers,
      locale: localeName,
      other: '$remotePlayers joueurs supplémentaires',
      one: '1 joueur supplémentaire',
    );
    return '$edition · $_temp0 · $_temp1 · $_temp2';
  }

  @override
  String get worldConvTargetVersion => 'Version Minecraft cible';

  @override
  String get worldConvVersionNote =>
      'Formats de versions Java 1.8.8–26.3 et Bedrock 1.12–1.26.60. Les cibles antérieures à Java 1.13 ou Bedrock 1.18.30 exigent d\'exclure les entités et les joueurs. Les enregistrements incompatibles sélectionnés provoquent une erreur. Les dimensions personnalisées sont refusées.';

  @override
  String get worldConvEntitiesTitle => 'Convertir les entités';

  @override
  String get worldConvEntitiesBody =>
      'Monstres, animaux de compagnie, villageois, véhicules et passagers. Chaque entité source doit correspondre à un enregistrement de sortie enregistré, sans quoi la conversion échoue. Les projectiles encore en vol sont listés mais non transférés.';

  @override
  String get worldConvPlayersTitle => 'Convertir les joueurs';

  @override
  String worldConvPlayersMultiple(int count) {
    return 'Ce monde contient $count enregistrements de joueurs supplémentaires. Désactivez « Convertir les joueurs » pour convertir le terrain et les entités. Déplacer ces joueurs nécessite des correspondances de comptes.';
  }

  @override
  String get worldConvPlayersSingle =>
      'Inventaire, équipement et position du joueur solo. Les joueurs supplémentaires nécessitent des correspondances de comptes et provoquent une erreur s\'ils sont sélectionnés.';

  @override
  String get worldConvStatsTitle => 'Conserver les statistiques';

  @override
  String get worldConvStatsBody =>
      'Les statistiques Java sont archivées pour une reconversion vers Java. Bedrock n\'a pas de format de statistiques par monde compatible.';

  @override
  String get worldConvChooseOutput => 'Choisir l\'emplacement de sortie';

  @override
  String worldConvAlreadyEdition(String edition) {
    return 'Ce monde est déjà en $edition. Choisissez l\'autre édition pour le convertir.';
  }

  @override
  String get worldConvConvertVerify => 'Convertir et vérifier le monde';

  @override
  String worldConvSaved(String path) {
    return 'Enregistré dans $path';
  }

  @override
  String worldConvEntitiesVerified(int count) {
    return '$count enregistrements d\'entités vérifiés.';
  }

  @override
  String get worldConvEntitiesExcluded => 'Entités exclues.';

  @override
  String get pictureConvRasterizeFailed => 'Impossible de rastériser le SVG.';

  @override
  String get worldEditionJava => 'Édition Java';

  @override
  String get worldEditionBedrock => 'Édition Bedrock';

  @override
  String worldConvEntityUnrepresentable(
    String target,
    String entity,
    String minimum,
  ) {
    return '$target ne peut pas représenter $entity. Choisissez $minimum ou une version plus récente, ou excluez les entités.';
  }

  @override
  String get worldConvInvalidEntityPosition =>
      'Position d\'entité invalide dans l\'audit du monde.';

  @override
  String get worldConvWrongTargetVersion =>
      'Le monde enregistré a la mauvaise version cible.';

  @override
  String get worldConvAdditionalPlayers =>
      'Les joueurs supplémentaires nécessitent des correspondances Java UUID / Bedrock XUID. La conversion des joueurs ne prend actuellement en charge que les mondes solo.';

  @override
  String get worldConvLocalPlayerMissing =>
      'Le joueur local n\'a pas été transféré.';

  @override
  String get worldConvPlayersRemain =>
      'Des données de joueurs exclues subsistent dans le résultat.';

  @override
  String get worldConvEntitiesRemain =>
      'Des entités exclues subsistent dans le résultat.';

  @override
  String worldConvEntityVerificationFailed(String detail) {
    return 'Le transfert des entités a échoué à la vérification : $detail. Le monde converti n\'a pas été enregistré. Votre source est inchangée.';
  }

  @override
  String get worldConvUnsupportedPlatform =>
      'La conversion de mondes nécessite Windows ou Linux.';

  @override
  String get worldConvEngineMissing =>
      'Le moteur de conversion de mondes est absent de cette version. Installez une version de bureau contenant le convertisseur de mondes.';

  @override
  String worldConvEngineStopped(String code) {
    return 'Le moteur de conversion de mondes s\'est arrêté de façon inattendue (code de sortie $code). Le monde d\'origine n\'a pas été modifié.';
  }

  @override
  String get worldConvMissingAudit => 'Audit du monde enregistré manquant.';

  @override
  String get worldConvVersionEngineMissing =>
      'Le moteur de version de Minecraft est absent de cette version. Installez une version de bureau contenant les deux moteurs de conversion de mondes.';

  @override
  String worldConvVersionConversionFailed(String detail) {
    return 'Échec de la conversion de version : $detail';
  }

  @override
  String worldConvExitCodeDetail(String code) {
    return 'code de sortie $code';
  }

  @override
  String get worldConvLinkedFiles =>
      'Les fichiers de monde liés ne sont pas pris en charge.';

  @override
  String get worldConvProgressCopy =>
      'Ouverture d\'une copie temporaire du monde source…';

  @override
  String get worldConvProgressChecking =>
      'Vérification des entités et des joueurs…';

  @override
  String get worldConvChooseOtherEdition =>
      'Choisissez l\'autre édition de Minecraft.';

  @override
  String get worldConvProgressConverting =>
      'Conversion du terrain, des conteneurs et des données sélectionnées…';

  @override
  String worldConvProgressTerrain(String target) {
    return 'Conversion du terrain vers $target…';
  }

  @override
  String get worldConvProgressVerifying =>
      'Vérification des entités dans le monde enregistré…';

  @override
  String worldConvProgressAdapting(String target) {
    return 'Adaptation des données sélectionnées à $target…';
  }

  @override
  String get worldConvOutputInsideSource =>
      'Choisissez un dossier de sortie en dehors de votre monde source.';

  @override
  String get worldConvOutputExists =>
      'Le chemin de sortie existe déjà. Choisissez un nouveau nom.';

  @override
  String get worldConvJavaTooOldForRecords =>
      'Les cibles Java antérieures à 1.13 ne peuvent pas stocker en toute sécurité les données d\'entités et de joueurs. Choisissez Java 1.13 ou une version plus récente, ou désactivez « Convertir les entités » et « Convertir les joueurs ». Le monde d\'origine n\'a pas été modifié.';

  @override
  String get worldConvBedrockTooOldForRecords =>
      'Les cibles Bedrock antérieures à 1.18.30 nécessitent un ancien stockage des entités et joueurs que ce convertisseur ne peut pas écrire en toute sécurité. Choisissez une cible plus récente ou excluez ces données. Le monde d\'origine n\'a pas été modifié.';

  @override
  String get worldConvOlderJavaCannotRead =>
      'Cette cible Java plus ancienne ne peut pas lire en toute sécurité les schémas d\'entités et de joueurs plus récents sélectionnés. Choisissez une version Java plus récente ou excluez ces données. Le monde d\'origine n\'a pas été modifié.';

  @override
  String get worldConvUnsupportedTarget => 'Version cible non prise en charge.';

  @override
  String get worldConvChooseWorldSource =>
      'Choisissez un dossier de monde ou un fichier .mcworld / .zip exporté.';

  @override
  String get worldConvMissingLevelDat =>
      'Le monde sélectionné n\'a pas de level.dat.';

  @override
  String get worldConvNoJavaStats =>
      'Aucune statistique de monde Java n\'était présente. Les statistiques de compte Bedrock ne sont pas stockées dans le monde.';

  @override
  String get worldConvJavaStatsRestored =>
      'Statistiques Java restaurées depuis l\'archive.';

  @override
  String get worldConvJavaStatsArchived =>
      'Statistiques Java archivées pour une future conversion vers Java. Bedrock ne peut pas les afficher.';

  @override
  String get worldConvArchiveUnsafePath =>
      'L\'archive du monde contient un chemin de fichier non sécurisé.';

  @override
  String get worldConvArchiveDuplicatePath =>
      'L\'archive du monde contient des chemins de fichiers en double.';

  @override
  String get worldConvArchiveLinkedFiles =>
      'Les fichiers liés dans les archives de mondes ne sont pas pris en charge.';

  @override
  String get worldConvArchiveNeedsOneLevel =>
      'L\'archive doit contenir exactement un monde avec level.dat.';

  @override
  String worldConvArchiveTruncated(String path) {
    return 'L\'archive du monde contient un fichier tronqué : $path';
  }

  @override
  String worldConvArchiveDamaged(String path) {
    return 'L\'archive du monde contient un fichier endommagé : $path';
  }

  @override
  String get homeGithubUnavailable => 'GitHub est indisponible.';

  @override
  String get homeGithubConnectHint =>
      'Connectez GitHub pour voir votre activité et vos dépôts privés. Votre jeton reste sur cet appareil.';

  @override
  String get homeGithubConnect => 'Connecter GitHub';

  @override
  String get homeGithubRefresh => 'Actualiser GitHub';

  @override
  String get homeGithubRecentIssues => 'Tickets récents';

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
      'Aucun ticket récent dans l\'instantané du compte connecté.';

  @override
  String get homeGithubOpenFailed => 'Impossible d\'ouvrir GitHub.';

  @override
  String get homeGithubNoHistory =>
      'L\'historique des contributions n\'est pas encore disponible.';

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
      'Année passée · inclut l\'activité privée autorisée par votre jeton';

  @override
  String get homeStocksFinanceUnavailable => 'Finances indisponibles.';

  @override
  String get homeStocksLoadFailed => 'Impossible de charger vos positions.';

  @override
  String get homeStocksAddHoldings =>
      'Ajoutez des positions dans Finances, ou choisissez un ticker dans les paramètres de cette tuile.';

  @override
  String get homeStocksRefreshPrices => 'Actualiser les cours';

  @override
  String get homeStocksHistoryUnavailable =>
      'Historique des cours indisponible. Essayez d\'actualiser.';

  @override
  String get homeAiUsageUnavailable =>
      'L\'utilisation de l\'IA est indisponible.';

  @override
  String get homeAiUsageNewTokens => 'nouveaux jetons · 7 derniers jours';

  @override
  String homeAiUsageTurns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tours',
      one: '1 tour',
    );
    return '$_temp0 dans les outils IA locaux';
  }

  @override
  String get homeAiUsageReadFailed =>
      'Impossible de lire les enregistrements d\'utilisation.';

  @override
  String get homeAiUsageScanHint =>
      'Analysez cet appareil pour importer les journaux de session IA pris en charge.';

  @override
  String get homeAiUsageScanFailed => 'Échec de l\'analyse. Réessayez.';

  @override
  String get homeAiUsageScanning => 'Analyse…';

  @override
  String get homeAiUsageScan => 'Analyser l\'utilisation';

  @override
  String get homeAiUsageLocalNote =>
      'Enregistrements de session locaux ; exclut les rejeux d\'entrée en cache.';

  @override
  String get homeLayoutDifferentFormat =>
      'Cette disposition de l’accueil appartient à un autre format d’appareil.';

  @override
  String get homeTileInvalid => 'Tuile d’accueil invalide.';

  @override
  String get homeTileDuplicate => 'Tuile d’accueil en double.';

  @override
  String get homeLayoutInvalid => 'Disposition d’accueil invalide.';

  @override
  String homeLayoutLoadFailed(String error) {
    return 'Votre disposition enregistrée n’a pas pu être chargée. $error';
  }

  @override
  String get homeConnectFinancesSummary =>
      'Connectez vos finances pour voir ce résumé.';

  @override
  String get homeCouldNotLoadInvestments =>
      'Impossible de charger les placements.';

  @override
  String get homeCouldNotLoadFinances => 'Impossible de charger les finances.';

  @override
  String get homeShortcutPasswords => 'Mots de passe';

  @override
  String get homeShortcutAssistantSubtitle =>
      'Discutez, demandez ce que vous voulez';

  @override
  String get homeShortcutFinanceSubtitle =>
      'Votre argent, cagnottes et actions';

  @override
  String get homeShortcutConverterSubtitle => 'Transformez images et fichiers';

  @override
  String get homeShortcutSettingsSubtitle => 'Couleurs, thème et plus';

  @override
  String get homeShortcutNotesSubtitle => 'Vos idées, à portée de main';

  @override
  String get homeShortcutPasswordsSubtitle => 'Gardez vos secrets en sécurité';

  @override
  String get homeShortcutPluginsSubtitle =>
      'Découvrez votre prochain petit assistant';

  @override
  String get homeNothingRecentYet =>
      'Rien pour le moment. Votre prochain chapitre commence avec votre première transaction.';

  @override
  String get homeRecentTransactionsEmpty =>
      'Vos transactions récentes apparaîtront ici.';

  @override
  String get homeCouldNotLoadRecentActivity =>
      'Impossible de charger l’activité récente.';

  @override
  String get homeActivityIncome => 'Revenu';

  @override
  String get homeActivityExpense => 'Dépense';

  @override
  String get homeResizeTileSemantics =>
      'Redimensionner la tuile. Utilisez le menu de la tuile pour une taille précise.';

  @override
  String get homeEmptyGridTitle => 'Un espace pour votre quotidien';

  @override
  String get homeEmptyGridBody =>
      'Ajoutez des notes, raccourcis, graphiques et petits outils.';

  @override
  String get homeAddFirstTile => 'Ajouter votre première tuile';

  @override
  String get homeSectionRecent => 'Ce que vous avez fait';

  @override
  String homeEditTileTooltip(String title) {
    return 'Modifier $title';
  }

  @override
  String get homeTileConfigure => 'Configurer';

  @override
  String get homeTilePositionSize => 'Position et taille';

  @override
  String get homeTileRemove => 'Supprimer la tuile';

  @override
  String get homePositionColumn => 'Colonne';

  @override
  String get homePositionRow => 'Ligne';

  @override
  String get homePositionWidth => 'Largeur en colonnes';

  @override
  String get homePositionHeight => 'Hauteur en lignes';

  @override
  String get homePositionHint =>
      'Les positions commencent à 1. Les tuiles s’alignent sur la grille et se déplacent automatiquement.';

  @override
  String get homeChooseShortcut => 'Choisir un raccourci';

  @override
  String get homeChooseNote => 'Choisir une note';

  @override
  String get homeUntitledNote => 'Note sans titre';

  @override
  String get homeCreateNoteFirst => 'Créez d’abord une note dans Notes.';

  @override
  String get homeChoosePlugin => 'Choisir un plug-in';

  @override
  String get homeInstallPluginFirst =>
      'Installez d’abord un plug-in depuis la boutique.';

  @override
  String get homeChooseInstance => 'Choisir une instance';

  @override
  String get homeCreateInstanceFirst =>
      'Créez d’abord une instance dans Lanceur Minecraft.';

  @override
  String get homeStockSymbolInput =>
      'Symbole boursier (vide pour toutes les positions)';

  @override
  String get homeTimerMinutesInput => 'Minutes du minuteur (1–1440)';

  @override
  String get homeRepositoryInput => 'Dépôt : propriétaire/nom (vide pour tous)';

  @override
  String get homeQuickConvertFiles => 'Convertir des fichiers';

  @override
  String get homeQuickFinances => 'Finances';

  @override
  String get homeTileUnavailable =>
      'Cette tuile n’est pas disponible dans cette version.';

  @override
  String get homeCouldNotLoadPlugins =>
      'Impossible de charger les plug-ins installés.';

  @override
  String homeInstallPluginToUse(String name) {
    return 'Installez $name pour utiliser cette tuile.';
  }

  @override
  String get homeNoteTileEmpty =>
      'Choisissez une note dans les paramètres de cette tuile. Les notes doivent être synchronisées séparément pour apparaître sur un autre appareil.';

  @override
  String get homeChoosePluginInSettings =>
      'Choisissez un plug-in installé dans les paramètres de la tuile.';

  @override
  String get homeCouldNotLoadErrands => 'Impossible de charger les tâches.';

  @override
  String get homeErrandsEmpty =>
      'Ajoutez vos tâches récurrentes dans le plug-in Tâches.';

  @override
  String get homeErrandDueToday => 'À faire aujourd’hui';

  @override
  String homeErrandUpdateFailed(String error) {
    return 'Impossible de mettre à jour la tâche : $error';
  }

  @override
  String get homeMinecraftAddAccount =>
      'Ajoutez d’abord un compte dans Lanceur Minecraft.';

  @override
  String homeLaunchFailed(String error) {
    return 'Échec du lancement : $error';
  }

  @override
  String get homeMinecraftPreparing => 'Préparation…';

  @override
  String get homeMinecraftRunning => 'En cours';

  @override
  String get homeMinecraftPlayNow => 'Jouer maintenant';

  @override
  String get homeChooseInstanceInSettings =>
      'Choisissez une instance disponible sur cet appareil dans les paramètres de la tuile.';

  @override
  String get homeCalcHint => 'ex. (42 + 8) / 2';

  @override
  String get homeTimeIsUp => 'Le temps est écoulé. Prenez une pause.';

  @override
  String get homeTimerHint => 'Un petit espace pour vous concentrer.';

  @override
  String get homeAvailableBalance => 'SOLDE DISPONIBLE';

  @override
  String homeInPotsAmount(String amount) {
    return 'Dans les tirelires  $amount';
  }

  @override
  String homeTotalCashAmount(String amount) {
    return 'Total en liquide  $amount';
  }

  @override
  String get notesNewNoteTooltip => 'Nouvelle note';

  @override
  String get notesNewNoteButton => '+ Nouvelle note';

  @override
  String get notesNoNotesYet => 'Pas encore de notes';

  @override
  String get notesBackTooltip => 'Retour aux notes';

  @override
  String get notesAddChecklistTooltip => 'Ajouter un élément à la liste';

  @override
  String get notesJotHint => 'Notez quelque chose…';

  @override
  String get notesTapEditToAdd =>
      'Appuyez sur Modifier pour ajouter du contenu.';

  @override
  String get notesNoneSelected => 'Aucune note sélectionnée';

  @override
  String get notesCreateToStart => 'Créez une nouvelle note pour commencer.';

  @override
  String get passwordsUnreadableCredential => 'Identifiant illisible';

  @override
  String get passwordsErrorEnterService => 'Saisissez le nom du service.';

  @override
  String get passwordsErrorEnterEmail => 'Saisissez l\'e-mail.';

  @override
  String get passwordsErrorEnterPassword => 'Saisissez le mot de passe.';

  @override
  String get passwordsErrorInvalidTotp =>
      'Ce n\'est pas un secret 2FA valide (il doit être en base32, ex. JBSWY3DPEHPK3PXP).';

  @override
  String passwordsErrorPickImage(String error) {
    return 'Échec de la sélection de l\'image : $error';
  }

  @override
  String get passwordsWeakTitle => 'Mot de passe faible';

  @override
  String get passwordsWeakBody =>
      'Ce mot de passe figure sur une liste de mots de passe extrêmement courants ou déjà compromis. Quiconque possède cette liste pourrait le deviner. Utilisez le bouton de génération pour un mot de passe fort, ou enregistrez-le quand même.';

  @override
  String get passwordsSaveAnyway => 'Enregistrer quand même';

  @override
  String get passwordsUploadPng => 'Importer un PNG';

  @override
  String get passwordsGenerateTooltip => 'Générer un mot de passe aléatoire';

  @override
  String get passwordsShow => 'Afficher';

  @override
  String get passwordsHide => 'Masquer';

  @override
  String get passwordsReveal => 'Révéler';

  @override
  String get passwordsNewCredential => 'Nouvel identifiant';

  @override
  String get passwordsEditCredential => 'Modifier l\'identifiant';

  @override
  String get passwordsFieldService => 'Service *';

  @override
  String get passwordsFieldIconOptional => 'Icône (facultatif)';

  @override
  String get passwordsFieldEmail => 'E-mail *';

  @override
  String get passwordsFieldPassword => 'Mot de passe *';

  @override
  String get passwordsFieldUsername => 'Nom d\'utilisateur (facultatif)';

  @override
  String get passwordsFieldPhone => 'Numéro de téléphone (facultatif)';

  @override
  String get passwordsFieldInfo => 'Infos (facultatif)';

  @override
  String get passwordsFieldTotp => 'Secret 2FA (facultatif)';

  @override
  String get passwordsHintService => 'ex. Netflix';

  @override
  String get passwordsHintIcon => 'ex. 🍿';

  @override
  String get passwordsHintUsername => 'ex. ayden31';

  @override
  String get passwordsHintPhone => 'ex. +33 6 12 34 56 78';

  @override
  String get passwordsHintInfo =>
      'Question de sécurité, codes de récupération, notes…';

  @override
  String get passwordsHintTotp =>
      'Clé base32 de la configuration « manuelle » (si le QR code ne fonctionne pas)';

  @override
  String get passwordsSaveChanges => 'Enregistrer les modifications';

  @override
  String get passwordsAddCredential => 'Ajouter un identifiant';

  @override
  String get passwordsSearchHint =>
      'Rechercher par service, e-mail ou nom d\'utilisateur';

  @override
  String get passwordsEmptyTitle =>
      'Aucun mot de passe enregistré pour l\'instant';

  @override
  String get passwordsEmptySubtitle =>
      'Les mots de passe et les secrets 2FA sont chiffrés sur cet appareil.';

  @override
  String get passwordsNoMatches => 'Aucun résultat';

  @override
  String passwordsNoMatchesSubtitle(String query) {
    return 'Aucun identifiant ne ressemble à « $query ».';
  }

  @override
  String get passwordsTotpCode => 'Code 2FA';

  @override
  String passwordsCopiedToast(String label) {
    return '$label copié';
  }

  @override
  String get passwordsEnterPinToUnlock =>
      'Saisissez le code PIN pour déverrouiller';

  @override
  String get passwordsIncorrectPin => 'Code PIN incorrect';

  @override
  String get passwordsDeleteTitle => 'Supprimer l\'identifiant ?';

  @override
  String passwordsDeleteBody(String service) {
    return 'Cela supprimera définitivement l\'identifiant enregistré pour « $service ».';
  }

  @override
  String get passwordsCopyPassword => 'Copier le mot de passe';

  @override
  String get passwordsCopyEmail => 'Copier l\'e-mail';

  @override
  String get passwordsCopyUsername => 'Copier le nom d\'utilisateur';

  @override
  String get passwordsCopyTotp => 'Copier le code 2FA';

  @override
  String get passwordsDecryptFailed =>
      '⚠ Déchiffrement impossible — données corrompues ou fichier de clé modifié';

  @override
  String get passwordsInvalidSecret => 'Secret invalide';

  @override
  String get passwordsPhone => 'Téléphone';

  @override
  String get passwordsInfo => 'Infos';

  @override
  String get passwordsBreachedWarning =>
      'Ce mot de passe a été trouvé dans une fuite de données connue — changez-le partout où vous l\'utilisez.';

  @override
  String get nativeWebviewNoHost =>
      'Cette version n\'a pas d\'hôte WebView natif.';

  @override
  String get accountOverviewPasteTokenFirst =>
      'Collez d\'abord un jeton d\'accès personnel.';

  @override
  String get accountOverviewStageIdle => 'Inactif';

  @override
  String get accountOverviewStageProfile => 'Lecture de votre profil';

  @override
  String get accountOverviewStageRepos => 'Liste des dépôts';

  @override
  String get accountOverviewStageContributions => 'Comptage des contributions';

  @override
  String get accountOverviewStageDownloads =>
      'Calcul des téléchargements des versions';

  @override
  String get accountOverviewStageIssues =>
      'Collecte des tickets et des demandes de fusion';

  @override
  String get accountOverviewStageActions =>
      'Récupération des exécutions de workflow';

  @override
  String get accountOverviewStageBilling =>
      'Lecture de l\'utilisation et des quotas';

  @override
  String accountOverviewWarnContributions(String error) {
    return 'Graphique des contributions indisponible : $error';
  }

  @override
  String accountOverviewWarnDownloads(String error) {
    return 'Téléchargements des versions indisponibles : $error';
  }

  @override
  String accountOverviewWarnIssues(String error) {
    return 'Tickets et demandes de fusion indisponibles : $error';
  }

  @override
  String accountOverviewWarnWorkflowRuns(String error) {
    return 'Exécutions de workflow indisponibles : $error';
  }

  @override
  String accountOverviewWarnBilling(String error) {
    return 'Utilisation et quotas indisponibles : $error';
  }

  @override
  String get accountOverviewSectionRepositories => 'Dépôts';

  @override
  String get accountOverviewSectionIssues => 'Tickets et PR';

  @override
  String get accountOverviewSectionActions => 'Actions';

  @override
  String get accountOverviewSectionUsage => 'Utilisation';

  @override
  String get accountOverviewSectionMcContent => 'Contenu MC';

  @override
  String get accountOverviewSectionVideos => 'Vidéos';

  @override
  String get accountOverviewSectionAnalytics => 'Analyses';

  @override
  String get accountOverviewSectionStats => 'Statistiques';

  @override
  String get accountOverviewBlurbOverview => 'Commits, étoiles, activité';

  @override
  String get accountOverviewBlurbRepositories =>
      'Chaque dépôt que vous possédez';

  @override
  String get accountOverviewBlurbIssues => 'Ce qui reste ouvert pour vous';

  @override
  String get accountOverviewBlurbActions => 'Exécutions de workflow et état';

  @override
  String get accountOverviewBlurbUsage => 'Copilot, stockage, calcul';

  @override
  String get accountOverviewBlurbYoutubeOverview => 'Abonnés, vues, vidéos';

  @override
  String get accountOverviewBlurbYoutubeVideos => 'Chaque envoi récent';

  @override
  String get accountOverviewBlurbYoutubeAnalytics =>
      'Temps de visionnage, trafic, abonnés';

  @override
  String get accountOverviewBlurbSpotifyStats =>
      'Meilleurs titres, écoutes récentes, bibliothèque';

  @override
  String get accountOverviewConnected => 'Connecté';

  @override
  String get accountOverviewNotSetUp => 'Non configuré';

  @override
  String accountOverviewServiceTooltip(String service, String status) {
    return '$service — $status';
  }

  @override
  String accountOverviewSectionListLabel(String service) {
    return 'Liste des sections $service';
  }

  @override
  String accountOverviewSectionTooltip(String label, String blurb) {
    return '$label — $blurb';
  }

  @override
  String get accountOverviewMoreServicesComing => 'D\'autres services arrivent';

  @override
  String get accountOverviewExpandSidebar => 'Développer la barre latérale';

  @override
  String get accountOverviewCollapseSidebar => 'Réduire la barre latérale';

  @override
  String get accountOverviewCollapse => 'Réduire';

  @override
  String get accountOverviewRefreshing => 'Actualisation…';

  @override
  String accountOverviewStageInProgress(String stage) {
    return '$stage…';
  }

  @override
  String accountOverviewStepOf(int step, int total) {
    return 'Étape $step sur $total';
  }

  @override
  String get accountOverviewAccountSettings => 'Paramètres du compte';

  @override
  String get accountOverviewConnectGithubTitle =>
      'Connectez votre compte GitHub';

  @override
  String get accountOverviewConnectGithubSubtitle =>
      'Consultez vos commits, étoiles, téléchargements, dépôts, tickets et exécutions de workflow en un seul endroit, ainsi que vos quotas Copilot, de stockage et de calcul.';

  @override
  String get accountOverviewConnectGithubButton => 'Connecter GitHub';

  @override
  String get accountOverviewGithubPrivacy =>
      'luma stocke votre jeton d\'accès personnel chiffré sur cet appareil et communique directement avec api.github.com. Rien de votre compte GitHub n\'est envoyé à un serveur luma, et aucun compte n\'est nécessaire pour utiliser ce plugin.';

  @override
  String get accountOverviewConnectYoutubeTitle =>
      'Connectez votre chaîne YouTube';

  @override
  String get accountOverviewConnectYoutubeSubtitle =>
      'Consultez vos abonnés, vos vues, vos envois récents et des analyses détaillées — temps de visionnage, sources de trafic et tendances des abonnés — en un seul endroit.';

  @override
  String get accountOverviewConnectYoutubeButton => 'Connecter YouTube';

  @override
  String get accountOverviewYoutubePrivacy =>
      'luma stocke vos identifiants OAuth Google chiffrés sur cet appareil et communique directement avec Google. Rien de votre compte n\'est envoyé à un serveur luma, et aucun compte luma n\'est nécessaire pour utiliser ce plugin.';

  @override
  String get accountOverviewGithubRateLimited =>
      'Limite de requêtes GitHub atteinte. Réessayez dans un instant.';

  @override
  String accountOverviewGithubRateLimitResets(String time) {
    return 'Limite de requêtes GitHub atteinte. Elle sera réinitialisée à $time.';
  }

  @override
  String get accountOverviewGithubTokenRejected =>
      'GitHub a refusé le jeton. Il a peut-être expiré ou été révoqué.';

  @override
  String accountOverviewGithubRefused(String path) {
    return 'GitHub a refusé $path. Le jeton n\'a probablement pas le droit requis.';
  }

  @override
  String accountOverviewGithubHttpError(String code, String path) {
    return 'GitHub a renvoyé HTTP $code pour $path.';
  }

  @override
  String get accountOverviewGithubUnexpectedProfile =>
      'GitHub a renvoyé des données de profil inattendues.';

  @override
  String get accountOverviewGithubUnexpectedGraphql =>
      'GitHub a renvoyé une réponse GraphQL inattendue.';

  @override
  String get accountOverviewGithubContributionsFailed =>
      'GitHub n\'a pas pu lire votre graphique de contributions.';

  @override
  String get accountOverviewBillingItemActionsMinutes => 'minutes Actions';

  @override
  String get accountOverviewBillingItemSharedStorage => 'stockage partagé';

  @override
  String get accountOverviewBillingItemCopilot => 'utilisation de Copilot';

  @override
  String get accountOverviewGithubBillingNoAccess =>
      'Ce jeton ne peut pas lire la facturation. Un jeton classique a besoin du droit \"user\" ; un jeton à permissions fines a besoin de l\'autorisation \"Plan\" (lecture seule).';

  @override
  String accountOverviewGithubBillingMissing(String items) {
    return 'GitHub n\'a pas renvoyé $items pour ce compte.';
  }

  @override
  String get accountOverviewGithubWorkflowDefault => 'Workflow';

  @override
  String get accountOverviewCopilotUnitDefault => 'requêtes';

  @override
  String get accountOverviewModrinthNoUser =>
      'Modrinth n\'a aucun utilisateur portant ce nom.';

  @override
  String get accountOverviewModrinthTokenRejected =>
      'Modrinth a refusé le jeton. Vérifiez qu\'il a le droit analytics.';

  @override
  String get accountOverviewModrinthRateLimited =>
      'Limite de requêtes Modrinth atteinte. Réessayez dans un instant.';

  @override
  String accountOverviewModrinthHttpError(String code) {
    return 'Modrinth a renvoyé HTTP $code.';
  }

  @override
  String get accountOverviewModrinthUnexpectedPayload =>
      'Modrinth a renvoyé des données utilisateur inattendues.';

  @override
  String get accountOverviewCurseforgeKeyRejected =>
      'CurseForge a refusé la clé API. Générez-en une dans la console CurseForge for Studios.';

  @override
  String accountOverviewCurseforgeHttpError(String code) {
    return 'CurseForge a renvoyé HTTP $code.';
  }

  @override
  String get accountOverviewCurseforgeNeedKey =>
      'Ajoutez d\'abord votre clé API CurseForge.';

  @override
  String get accountOverviewCurseforgeBadSlug =>
      'Cela ne ressemble pas à une URL ou un identifiant de projet CurseForge.';

  @override
  String accountOverviewCurseforgeNoProject(String slug) {
    return 'CurseForge n\'a aucun projet nommé \"$slug\".';
  }

  @override
  String get accountOverviewCurseforgeNeedAuthor =>
      'Ajoutez votre identifiant d\'auteur CurseForge, ou suivez les projets individuellement.';

  @override
  String get accountOverviewCurseforgeNeedKeyToInclude =>
      'Ajoutez une clé API CurseForge pour l\'inclure.';

  @override
  String get accountOverviewModrinthNeedUsername =>
      'Ajoutez votre nom d\'utilisateur Modrinth pour l\'inclure.';

  @override
  String get accountOverviewPmcNeedUsername =>
      'Ajoutez votre nom d\'utilisateur Planet Minecraft pour l\'inclure.';

  @override
  String get accountOverviewPmcNeedsBrowser =>
      'Planet Minecraft nécessite un navigateur intégré, indisponible sur cette plateforme.';

  @override
  String get accountOverviewCurseforgeTrackedProjects => 'projets suivis';

  @override
  String get accountOverviewSpotifyUnknownArtist => 'Artiste inconnu';

  @override
  String get accountOverviewSpotifyUnknownTrack => 'Titre inconnu';

  @override
  String accountOverviewSpotifyHttpError(String code) {
    return 'Spotify a renvoyé HTTP $code.';
  }

  @override
  String get accountOverviewSpotifyOAuthTimedOut =>
      'Délai d\'attente dépassé pour Spotify. Essayez de vous reconnecter.';

  @override
  String get accountOverviewSpotifyConnectedPage =>
      'Spotify est connecté. Revenez à luma.';

  @override
  String get accountOverviewSpotifyFailedPage =>
      'La connexion à Spotify a échoué. Revenez à luma.';

  @override
  String accountOverviewSpotifyDeclined(String error) {
    return 'Spotify a refusé : $error';
  }

  @override
  String get accountOverviewSpotifyInvalidResponse =>
      'La réponse de connexion Spotify était invalide.';

  @override
  String get accountOverviewSpotifyNoAccessToken =>
      'Spotify n\'a pas renvoyé de jeton d\'accès.';

  @override
  String get accountOverviewSpotifyCouldNotOpenPage =>
      'Impossible d\'ouvrir la page de connexion Spotify.';

  @override
  String accountOverviewSpotifyReadSavedFailed(String error) {
    return 'Impossible de lire la connexion Spotify enregistrée : $error';
  }

  @override
  String get accountOverviewSpotifyEnterClientId =>
      'Saisissez votre ID client Spotify.';

  @override
  String get accountOverviewSpotifyNoRefreshToken =>
      'Spotify n\'a pas renvoyé de jeton d\'actualisation.';

  @override
  String get accountOverviewSpotifyAccountDefault => 'Compte Spotify';

  @override
  String get accountOverviewSpotifyNotConnected =>
      'Spotify n\'est pas connecté.';

  @override
  String get accountOverviewSpotifyConnectionChanged =>
      'La connexion Spotify a changé pendant l\'actualisation.';

  @override
  String get accountOverviewSpotifyPaginationStalled =>
      'La pagination des écoutes récentes n\'a pas avancé.';

  @override
  String get accountOverviewSpotifyHistoryGap =>
      'L\'historique Spotify ne remonte pas jusqu\'à la dernière écoute comptée. Certaines écoutes peuvent manquer.';

  @override
  String accountOverviewSpotifyWarningListeningTotal(String error) {
    return 'Total d\'écoute : $error';
  }

  @override
  String accountOverviewSpotifyWarningRecentPlays(String error) {
    return 'Écoutes récentes : $error';
  }

  @override
  String accountOverviewSpotifyWarningLabeled(String label, String error) {
    return '$label : $error';
  }

  @override
  String get accountOverviewSpotifyTopArtists => 'Artistes les plus écoutés';

  @override
  String get accountOverviewSpotifyTopTracks => 'Titres les plus écoutés';

  @override
  String get accountOverviewSpotifySavedTracks => 'Titres enregistrés';

  @override
  String get accountOverviewSpotifyPlaylists => 'Playlists';

  @override
  String accountOverviewSpotifyRefreshFailed(String error) {
    return 'Impossible d\'actualiser Spotify : $error';
  }

  @override
  String get accountOverviewKindSubmission => 'soumission';

  @override
  String get accountOverviewKindMod => 'mod';

  @override
  String get accountOverviewKindModpack => 'modpack';

  @override
  String get accountOverviewKindSkin => 'skin';

  @override
  String get accountOverviewKindProject => 'projet';

  @override
  String get accountOverviewKindResourcePack => 'pack de ressources';

  @override
  String get accountOverviewKindDataPack => 'pack de données';

  @override
  String get accountOverviewKindBlog => 'blog';

  @override
  String get accountOverviewKindServer => 'serveur';

  @override
  String get accountOverviewKindCollection => 'collection';

  @override
  String get accountOverviewKindCustomization => 'personnalisation';

  @override
  String get accountOverviewKindAddon => 'extension';

  @override
  String get accountOverviewKindShader => 'shader';

  @override
  String get accountOverviewKindWorld => 'monde';

  @override
  String get accountOverviewJustNow => 'à l\'instant';

  @override
  String accountOverviewMonthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count mois',
      one: 'il y a 1 mois',
    );
    return '$_temp0';
  }

  @override
  String accountOverviewYearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count ans',
      one: 'il y a 1 an',
    );
    return '$_temp0';
  }

  @override
  String get accountOverviewTimeUnknown => 'inconnu';

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
    return '$seconds s';
  }

  @override
  String accountOverviewDurationMinutesSeconds(String minutes, String seconds) {
    return '$minutes min $seconds s';
  }

  @override
  String accountOverviewDurationHoursMinutes(String hours, String minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get accountOverviewWeekdayMonShort => 'lun.';

  @override
  String get accountOverviewWeekdayWedShort => 'mer.';

  @override
  String get accountOverviewWeekdayFriShort => 'ven.';

  @override
  String get accountOverviewAllowanceUsedUp => 'Allocation épuisée';

  @override
  String get accountOverviewNearAllowance => 'Proche de votre allocation';

  @override
  String get accountOverviewNoIncludedAllowance =>
      'GitHub n\'a pas indiqué d\'allocation incluse.';

  @override
  String get accountOverviewSetAllowance => 'Définir';

  @override
  String accountOverviewAllowanceIncluded(String unit, String total) {
    return '$unit sur $total $unit inclus';
  }

  @override
  String accountOverviewMeterSemantics(
    String label,
    String used,
    String total,
    String unit,
    String percent,
  ) {
    return '$label : $used sur $total $unit utilisés, $percent';
  }

  @override
  String accountOverviewStatSemantics(String label, String value) {
    return '$label : $value';
  }

  @override
  String accountOverviewStatSemanticsCaption(
    String label,
    String value,
    String caption,
  ) {
    return '$label : $value. $caption';
  }

  @override
  String get accountOverviewNoContributionData =>
      'Aucune donnée de contribution pour l\'instant.';

  @override
  String accountOverviewNoContributionsOn(String date) {
    return 'Aucune contribution le $date';
  }

  @override
  String accountOverviewContributionsOn(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contributions le $date',
      one: '1 contribution le $date',
    );
    return '$_temp0';
  }

  @override
  String get accountOverviewLess => 'Moins';

  @override
  String get accountOverviewRunFilterAll => 'Toutes les exécutions';

  @override
  String get accountOverviewFailed => 'Échec';

  @override
  String get accountOverviewRunFilterInProgress => 'En cours';

  @override
  String get accountOverviewRunFilterSucceeded => 'Réussies';

  @override
  String get accountOverviewNoWorkflowRuns => 'Aucune exécution de workflow';

  @override
  String get accountOverviewNoWorkflowRunsSub =>
      'luma vérifie vos douze dépôts les plus récemment poussés. Les exécutions apparaissent ici dès qu\'un d\'eux a un historique CI.';

  @override
  String get accountOverviewNoRunsMatch => 'Aucune exécution correspondante';

  @override
  String accountOverviewNoRunsMatchSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Effacez le filtre pour voir les $count exécutions.',
      one: 'Effacez le filtre pour voir l\'unique exécution.',
    );
    return '$_temp0';
  }

  @override
  String get accountOverviewSuccessRate => 'Taux de réussite';

  @override
  String get accountOverviewNoCompletedRuns => 'aucune exécution terminée';

  @override
  String get accountOverviewOfRecentCompletedRuns =>
      'des exécutions terminées récentes';

  @override
  String get accountOverviewRunsSeen => 'Exécutions vues';

  @override
  String get accountOverviewMostRecentFirst => 'les plus récentes d\'abord';

  @override
  String accountOverviewRunsInProgress(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count en cours',
      one: '1 en cours',
    );
    return '$_temp0';
  }

  @override
  String get accountOverviewInThisWindow => 'sur cette période';

  @override
  String get accountOverviewAverageDuration => 'Durée moyenne';

  @override
  String get accountOverviewPerCompletedRun => 'par exécution terminée';

  @override
  String get accountOverviewFilterByRepository => 'Filtrer par dépôt';

  @override
  String get accountOverviewAllRepositories => 'Tous les dépôts';

  @override
  String get githubConnectTitle => 'Connecter GitHub';

  @override
  String get githubReconnectTitle => 'Reconnecter GitHub';

  @override
  String githubConnectConnectedNotice(String login, String tokenEnd) {
    return 'Connecté en tant que $login avec un jeton se terminant par $tokenEnd. Coller un nouveau jeton le remplace.';
  }

  @override
  String get githubConnectTokenLabel => 'Jeton d\'accès personnel';

  @override
  String get githubConnectShowToken => 'Afficher le jeton';

  @override
  String get githubConnectHideToken => 'Masquer le jeton';

  @override
  String get githubConnectTokenPrivacy =>
      'Le jeton est chiffré sur cet appareil et envoyé uniquement à api.github.com. Il n\'atteint jamais un serveur luma.';

  @override
  String get githubConnectAction => 'Connecter';

  @override
  String get githubConnectDisconnect => 'Déconnecter';

  @override
  String get githubConnectScopesTitle => 'Permissions à cocher';

  @override
  String get githubConnectScopeRepo =>
      'Dépôts privés, leurs tickets et leurs exécutions de workflows';

  @override
  String get githubConnectScopeReadUser => 'Profil, abonnés, contributions';

  @override
  String get githubConnectScopeUser =>
      'Utilisation, stockage et quotas Copilot';

  @override
  String get githubConnectFineGrainedNote =>
      'Un jeton à granularité fine a besoin des autorisations équivalentes en lecture seule, plus « Plan ».';

  @override
  String get githubConnectOpenTokenSettings =>
      'Ouvrir les paramètres de jeton GitHub';

  @override
  String get githubDisconnectTitle => 'Déconnecter GitHub ?';

  @override
  String get githubDisconnectBody =>
      'Le jeton enregistré et tous les chiffres en cache sont supprimés de cet appareil. Votre compte GitHub, lui, n\'est pas modifié.';

  @override
  String get githubDisconnectKeep => 'Garder';

  @override
  String get githubAllowanceTitle => 'Vos quotas mensuels';

  @override
  String get githubAllowanceIntro =>
      'GitHub indique ce que vous avez utilisé, mais pas toujours ce que comprend votre forfait. Renseignez les chiffres de votre page de facturation pour que les jauges affichent une barre ; laissez-en un vide et l\'utilisation brute s\'affiche à la place.';

  @override
  String get githubAllowanceOpenBilling => 'Ouvrir la facturation GitHub';

  @override
  String get githubAllowanceCopilotLabel => 'Quota Copilot';

  @override
  String get githubAllowanceCopilotHelper =>
      'Crédits IA ou requêtes premium inclus par mois';

  @override
  String get githubAllowanceStorageLabel => 'Quota de stockage';

  @override
  String get githubAllowanceStorageHelper =>
      'Stockage Packages et Actions inclus, en Go';

  @override
  String get githubAllowanceMinutesLabel => 'Quota de calcul Actions';

  @override
  String get githubAllowanceMinutesHelper =>
      'Minutes de workflow incluses par mois';

  @override
  String get githubAllowanceHint => 'Laisser vide si vous ne savez pas';

  @override
  String get githubOpenIssues => 'Tickets ouverts';

  @override
  String get githubOpenPrs => 'PR ouvertes';

  @override
  String get githubMergedPrs => 'PR fusionnées';

  @override
  String get githubClosedIssues => 'Tickets fermés';

  @override
  String get githubIssuesFilterAll => 'Tout';

  @override
  String get githubIssuesFilterMerged => 'Fusionnés';

  @override
  String get githubIssuesFilterClosed => 'Fermés';

  @override
  String get githubCaptionYouOpened => 'ouverts par vous';

  @override
  String get githubCaptionAwaitingReview => 'en attente de revue';

  @override
  String get githubCaptionAllTime => 'depuis le début';

  @override
  String get githubIssuesEmptyTitle => 'Rien à afficher pour l\'instant';

  @override
  String get githubIssuesEmptySubtitle =>
      'Les tickets et pull requests auxquels vous participez apparaissent ici après une actualisation.';

  @override
  String githubIssuesNothingInFilter(String filter) {
    return 'Rien dans $filter';
  }

  @override
  String get githubIssuesPickAnotherFilter =>
      'Choisissez un autre filtre pour voir le reste.';

  @override
  String get githubStatusMergedPr => 'Pull request fusionnée';

  @override
  String get githubStatusClosedPr => 'Pull request fermée';

  @override
  String get githubStatusDraftPr => 'Pull request brouillon';

  @override
  String get githubStatusOpenPr => 'Pull request ouverte';

  @override
  String get githubStatusOpenIssue => 'Ticket ouvert';

  @override
  String get githubStatusClosedIssue => 'Ticket fermé';

  @override
  String githubIssueRowMeta(String repo, String number, String when) {
    return '$repo #$number  ·  mis à jour $when';
  }

  @override
  String githubIssueCommentsSemantic(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count commentaires',
      one: '1 commentaire',
    );
    return '$_temp0';
  }

  @override
  String get githubContributions => 'Contributions';

  @override
  String githubContributionsInLastYear(String count) {
    return '$count au cours de la dernière année';
  }

  @override
  String get githubContributionsYearActivity =>
      'L\'activité de la dernière année';

  @override
  String get githubTopRepositories => 'Principaux dépôts';

  @override
  String get githubByStars => 'Par étoiles';

  @override
  String get githubViewAll => 'Tout voir';

  @override
  String get githubLanguages => 'Langages';

  @override
  String get githubByRepoCount => 'Par nombre de dépôts';

  @override
  String get githubLatestRuns => 'Dernières exécutions de workflows';

  @override
  String get githubNoRepositoriesYet => 'Aucun dépôt pour l\'instant.';

  @override
  String get githubNoLanguagesYet => 'Aucun langage détecté pour l\'instant.';

  @override
  String get githubNoRunsFound =>
      'Aucune exécution de workflow trouvée dans vos dépôts les plus récemment poussés.';

  @override
  String get githubNotRefreshedYet => 'Pas encore actualisé';

  @override
  String githubUpdated(String when) {
    return 'Mis à jour $when';
  }

  @override
  String get githubProfile => 'Profil';

  @override
  String githubFollowers(String count) {
    return '$count abonnés';
  }

  @override
  String githubFollowing(String count) {
    return '$count abonnements';
  }

  @override
  String githubCompanySemantic(String name) {
    return 'Entreprise $name';
  }

  @override
  String githubLocationSemantic(String name) {
    return 'Lieu $name';
  }

  @override
  String githubJoined(String date) {
    return 'Inscrit le $date';
  }

  @override
  String githubAvatarSemantic(String login) {
    return 'Avatar de $login';
  }

  @override
  String githubCurrentStreakSemantic(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Série actuelle de $days jours',
      one: 'Série actuelle de 1 jour',
    );
    return '$_temp0';
  }

  @override
  String githubLongestStreakSemantic(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Plus longue série de $days jours',
      one: 'Plus longue série de 1 jour',
    );
    return '$_temp0';
  }

  @override
  String githubStreakCurrent(String days) {
    return '$days j de suite';
  }

  @override
  String githubStreakBest(String days) {
    return '$days j record';
  }

  @override
  String get githubCommits => 'Commits';

  @override
  String githubPrivateCountPlus(String count) {
    return '+$count privés';
  }

  @override
  String get githubInLastYear => 'au cours de la dernière année';

  @override
  String get githubStarsEarned => 'Étoiles obtenues';

  @override
  String githubAcrossRepos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dépôts',
      one: '1 dépôt',
    );
    return 'dans $_temp0';
  }

  @override
  String get githubRepositories => 'Dépôts';

  @override
  String githubPrivateCount(String count) {
    return '$count privés';
  }

  @override
  String get githubDownloads => 'Téléchargements';

  @override
  String get githubReleaseAssets => 'fichiers de version';

  @override
  String githubClosedCount(String count) {
    return '$count fermés';
  }

  @override
  String githubOpenCount(String count) {
    return '$count ouverts';
  }

  @override
  String get githubForks => 'Forks';

  @override
  String get githubOfYourRepos => 'de vos dépôts';

  @override
  String get githubRecent => 'récents';

  @override
  String get githubWorkflowRuns => 'Exécutions de workflows';

  @override
  String get githubRunStatusInProgress => 'En cours';

  @override
  String get githubRunStatusSucceeded => 'Réussi';

  @override
  String get githubRunStatusFailed => 'Échec';

  @override
  String get githubRunStatusCancelled => 'Annulé';

  @override
  String get githubRunStatusSkipped => 'Ignoré';

  @override
  String get githubRunStatusUnknown => 'Inconnu';

  @override
  String get githubRepoSortRecentlyPushed => 'Poussés récemment';

  @override
  String get githubRepoSortStars => 'Étoiles';

  @override
  String get githubRepoFilterSources => 'Originaux';

  @override
  String get githubPrivate => 'Privé';

  @override
  String get githubPublic => 'Public';

  @override
  String get githubFork => 'Fork';

  @override
  String get githubArchived => 'Archivé';

  @override
  String get githubRepoSearchHint => 'Rechercher un dépôt';

  @override
  String get githubRepoSortTooltip => 'Trier les dépôts';

  @override
  String get githubReposEmptyTitle => 'Aucun dépôt';

  @override
  String get githubReposEmptySubtitle =>
      'Actualisez une fois que votre compte contient des dépôts, ou élargissez les permissions du jeton pour inclure les dépôts privés.';

  @override
  String get githubReposNothingMatches => 'Rien ne correspond à ce filtre';

  @override
  String githubReposNoMatch(String query) {
    return 'Aucun dépôt ne correspond à « $query »';
  }

  @override
  String get githubReposTryDifferent =>
      'Essayez un autre filtre ou une recherche plus courte.';

  @override
  String githubReposCountOf(int shown, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$shown sur $total dépôts',
      one: '$shown sur 1 dépôt',
    );
    return '$_temp0';
  }

  @override
  String get githubReposStarsInView => 'Étoiles affichées';

  @override
  String get githubReposDownloadsInView => 'Téléchargements affichés';

  @override
  String get githubReposSizeInView => 'Taille affichée';

  @override
  String githubStarsCount(String count) {
    return '$count étoiles';
  }

  @override
  String githubForksCount(String count) {
    return '$count forks';
  }

  @override
  String githubOpenIssuesAndPrsCount(String count) {
    return '$count tickets et pull requests ouverts';
  }

  @override
  String githubReleaseDownloadsCount(String count) {
    return '$count téléchargements de versions';
  }

  @override
  String githubSizeSemantic(String size) {
    return 'Taille $size';
  }

  @override
  String get ghUsageBillingUnavailable =>
      'Les données de facturation ne sont pas disponibles pour ce jeton.';

  @override
  String get ghUsageReconnect => 'Reconnecter';

  @override
  String get ghUsageThisPeriod => 'Cette période de facturation';

  @override
  String get ghUsageCopilotUsage => 'Utilisation de Copilot';

  @override
  String ghUsageCopilotSpend(String amount) {
    return 'Facturé au-delà du forfait inclus : $amount';
  }

  @override
  String get ghUsageNoCopilotSpend => 'Rien facturé au-delà du forfait inclus.';

  @override
  String get ghUsageStorage => 'Stockage';

  @override
  String get ghUsageStorageSubtitle =>
      'Artefacts Actions, dépôts privés uniquement';

  @override
  String get ghUsageSharedStorage => 'Stockage partagé';

  @override
  String ghUsageStoragePartial(int counted, int total) {
    return 'Décompte des $counted dépôts privés les plus récemment actifs parmi vos $total. Les dépôts publics ne sont jamais comptés et sont donc entièrement exclus.';
  }

  @override
  String get ghUsageStorageSummed =>
      'Additionné directement à partir des artefacts Actions de chaque dépôt privé — GitHub n\'a pas d\'API pour le stockage Packages, qui n\'est donc pas inclus.';

  @override
  String get ghUsagePackagesBandwidth => 'Bande passante Packages';

  @override
  String get ghUsageWorkflowCompute => 'Calcul des workflows';

  @override
  String get ghUsageActionsSubtitle => 'Minutes GitHub Actions';

  @override
  String get ghUsageActionsMinutes => 'Minutes Actions';

  @override
  String get ghUsageUnitMinutes => 'minutes';

  @override
  String ghUsageMinutesBilled(String minutes) {
    return '$minutes minutes facturées au-delà du forfait.';
  }

  @override
  String get ghUsageAdjustAllowances => 'Ajuster vos quotas';

  @override
  String get ghUsageFootnote =>
      'GitHub indique la consommation, mais pas toujours le quota qui va avec. Les jauges sans barre attendent un chiffre de votre page de facturation.';

  @override
  String get ghUsageDaysLeft => 'Jours restants dans le cycle';

  @override
  String get ghUsageUntilReset => 'avant la réinitialisation des jauges';

  @override
  String get ghUsageBilledThisPeriod => 'Facturé cette période';

  @override
  String get ghUsageBeyondIncluded => 'au-delà des quotas inclus';

  @override
  String get ghUsageUsageLines => 'Lignes d\'utilisation';

  @override
  String get ghUsageProductsWithActivity => 'produits avec activité';

  @override
  String get ghUsageByRunner => 'Par runner';

  @override
  String get ghUsageNoBillable =>
      'Aucune utilisation facturable signalée pour cette période.';

  @override
  String get ghUsageConnectForBreakdown =>
      'Connectez un jeton pouvant lire la facturation pour voir le détail.';

  @override
  String get ghUsageBreakdownTitle => 'Détail de l\'utilisation';

  @override
  String get ghUsageBreakdownSubtitle =>
      'Totaux par produit pour cette période de facturation';

  @override
  String get ghUsageColProduct => 'Produit';

  @override
  String get ghUsageColQuantity => 'Quantité';

  @override
  String get ghUsageColBilled => 'Facturé';

  @override
  String get mcAll => 'Tout';

  @override
  String get mcMetricDownloads => 'Téléchargements';

  @override
  String get mcMetricFollowers => 'Abonnés';

  @override
  String get mcMetricViews => 'Vues';

  @override
  String mcChartSemantics(
    String metric,
    String fromDate,
    String toDate,
    String low,
    String high,
  ) {
    return '$metric du $fromDate au $toDate : de $low à $high';
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
      other: '$days jours',
      one: '1 jour',
    );
    return 'Gain quotidien sur $_temp0, avec un pic à $peak';
  }

  @override
  String mcGainTooltip(String count) {
    return '+$count téléchargements';
  }

  @override
  String get mcChartNoHistory => 'Pas encore d\'historique';

  @override
  String get mcChartOneDay => 'Un seul jour enregistré pour l\'instant';

  @override
  String get mcChartCollecting =>
      'Ces plateformes publient un total cumulé et aucun historique, donc luma enregistre un point par jour. La courbe apparaît dès qu\'il y en a deux.';

  @override
  String get mcViewProjects => 'Projets';

  @override
  String get mcViewTrends => 'Tendances';

  @override
  String get mcPlatformSettings => 'Paramètres des plateformes';

  @override
  String get mcViaEmbeddedBrowser => 'via le navigateur intégré';

  @override
  String mcReadingPlatform(String platform) {
    return 'Lecture de $platform…';
  }

  @override
  String get mcCombinedLibrary => 'Bibliothèque combinée';

  @override
  String get mcCombinedLibrarySubtitle =>
      'CurseForge et Modrinth, additionnés.';

  @override
  String get mcCurseforgeModrinthCombined => 'CurseForge et Modrinth combinés';

  @override
  String get mcTotalDownloads => 'Total des téléchargements';

  @override
  String get mcAcrossBothPlatforms => 'sur les deux plateformes';

  @override
  String get mcLast30Days => '30 derniers jours';

  @override
  String get mcDownloadsGained => 'téléchargements gagnés';

  @override
  String get mcStillCollecting => 'collecte en cours';

  @override
  String get mcFollowersCaption => 'abonnés et pouces levés';

  @override
  String mcProjectsSplit(int cf, int mr) {
    return '$cf CF · $mr MR';
  }

  @override
  String get mcNothingToShowYet => 'Rien à afficher pour l\'instant.';

  @override
  String mcSemDownloads(int count) {
    return '$count téléchargements';
  }

  @override
  String mcSemFollowers(int count) {
    return '$count abonnés';
  }

  @override
  String mcSemViews(int count) {
    return '$count vues';
  }

  @override
  String mcProjectsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count projets',
      one: '1 projet',
    );
    return '$_temp0';
  }

  @override
  String mcUpdatedRelative(String when) {
    return 'mis à jour $when';
  }

  @override
  String get mcSetUp => 'Configurer';

  @override
  String get mcSetUpPlatforms => 'Configurer les plateformes';

  @override
  String get mcStateNotSetUp => 'Non configuré';

  @override
  String get mcStateConnected => 'Connecté';

  @override
  String get mcStateUnavailable => 'Indisponible';

  @override
  String get mcPmcKeptSeparate =>
      'Séparé — PMC compte les vues, et ses skins, blogs et constructions ne sont pas des mods.';

  @override
  String get mcPmcAddUsername =>
      'Ajoutez votre nom d\'utilisateur Planet Minecraft pour l\'inclure.';

  @override
  String get mcPmcApproximate =>
      'Planet Minecraft arrondit les vues et téléchargements au-delà de mille sur les pages de liste (« 1.1k »), donc ces totaux sont approximatifs. Les diamants et favoris sont exacts.';

  @override
  String get mcPmcViewsDownloadsOverTime =>
      'Vues et téléchargements dans le temps';

  @override
  String get mcRecordedOnePointPerDay =>
      'Enregistré par luma, un point par jour';

  @override
  String get mcApproximate => 'approximatif';

  @override
  String get mcAcrossSubmissions => 'sur l\'ensemble des publications';

  @override
  String get mcExact => 'exact';

  @override
  String get mcDiamonds => 'Diamants';

  @override
  String get mcFavourites => 'Favoris';

  @override
  String mcFavouritesCount(int count) {
    return '$count favoris';
  }

  @override
  String mcSubmissionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count publications',
      one: '1 publication',
    );
    return '$_temp0';
  }

  @override
  String get mcFindProject => 'Rechercher un projet';

  @override
  String get mcNoProjectsYet => 'Aucun projet pour l\'instant';

  @override
  String get mcNothingMatchesFilter => 'Aucun résultat pour ce filtre';

  @override
  String get mcSetUpToPullProjects =>
      'Configurez une plateforme et actualisez pour importer vos projets.';

  @override
  String get mcTryDifferentFilter =>
      'Essayez une autre plateforme ou une recherche plus courte.';

  @override
  String get mcBadgeRounded => 'arrondi';

  @override
  String get mcDownloadsOverTime => 'Téléchargements dans le temps';

  @override
  String get mcHoverBarTopProjects =>
      'Survolez une barre pour voir les principaux projets du jour';

  @override
  String get mcDownloadsGainedPerDay => 'Téléchargements gagnés par jour';

  @override
  String mcPlatformDownloads(String platform) {
    return 'Téléchargements $platform';
  }

  @override
  String get mcPmcViews => 'Vues PMC';

  @override
  String get mcPmcApproximateSubtitle =>
      'Approximatif — PMC arrondit les chiffres au-delà de mille';

  @override
  String get mcPmcDownloads => 'Téléchargements PMC';

  @override
  String mcSinceDate(String date) {
    return 'depuis le $date';
  }

  @override
  String get mcSetupTitle => 'Suivez vos contenus Minecraft';

  @override
  String get mcSetupSubtitle =>
      'Regroupez CurseForge, Modrinth et Planet Minecraft dans un seul tableau de bord : téléchargements, abonnés, vues et tendances dans le temps.';

  @override
  String get mcReqModrinthTitle => 'Modrinth — nom d\'utilisateur seulement';

  @override
  String get mcReqModrinthBody =>
      'Les totaux sont publics. Un jeton est facultatif et ne débloque que l\'historique réel des téléchargements.';

  @override
  String get mcReqCurseforgeTitle => 'CurseForge — clé API requise';

  @override
  String get mcReqCurseforgeBody =>
      'CurseForge ne fournit rien de façon anonyme. Ajoutez une clé, plus soit votre identifiant d\'auteur numérique, soit les liens de vos projets.';

  @override
  String get mcReqPmcTitle => 'Planet Minecraft — nom d\'utilisateur seulement';

  @override
  String get mcReqPmcBody =>
      'PMC n\'a pas d\'API, donc luma lit votre profil public dans un navigateur intégré. Windows et Android uniquement.';

  @override
  String get mcSetupPlatformsTitle => 'Plateformes Minecraft';

  @override
  String get mcSetupModrinthNote => 'Public : un nom d’utilisateur suffit.';

  @override
  String get mcSetupModrinthUsername => 'Nom d’utilisateur Modrinth';

  @override
  String get mcSetupModrinthUsernameHint => 'p. ex. jellysquid3';

  @override
  String get mcSetupModrinthToken => 'Jeton d’accès (facultatif)';

  @override
  String get mcSetupModrinthTokenHelper =>
      'Nécessaire uniquement pour l’historique réel des téléchargements. Sans lui, luma construit le graphique à partir d’instantanés quotidiens.';

  @override
  String get mcSetupModrinthTokenLink => 'Paramètres du jeton Modrinth';

  @override
  String get mcSetupCurseNote =>
      'Nécessite une clé API : CurseForge ne renvoie rien sans elle.';

  @override
  String get mcSetupCurseKey => 'Clé API CurseForge';

  @override
  String get mcSetupCurseKeyHint => 'x-api-key depuis la console Studios';

  @override
  String get mcSetupCurseKeysLink => 'Clés API CurseForge';

  @override
  String get mcSetupTestingKey => 'Test en cours…';

  @override
  String get mcSetupTestKey => 'Tester la clé';

  @override
  String get mcSetupEnterKeyFirst => 'Saisissez d’abord une clé.';

  @override
  String get mcSetupKeyWorks =>
      'La clé fonctionne : CurseForge a répondu HTTP 200.';

  @override
  String get mcSetupAuthorId => 'ID de l’auteur (facultatif)';

  @override
  String get mcSetupAuthorIdHint => 'ID numérique, p. ex. 123456';

  @override
  String get mcSetupAuthorIdHelper =>
      'CurseForge filtre par ID numérique et ne propose pas de recherche par nom d’utilisateur. Laissez vide et suivez les projets un par un.';

  @override
  String get mcSetupTrackTitle => 'Suivre un seul projet';

  @override
  String get mcSetupTrackHint =>
      'Collez l’URL ou le slug d’un projet CurseForge';

  @override
  String get mcSetupTrack => 'Suivre';

  @override
  String mcSetupNowTracking(String name) {
    return 'Suivi de $name activé.';
  }

  @override
  String mcSetupStopTracking(String id) {
    return 'Arrêter de suivre #$id';
  }

  @override
  String get mcSetupCurseConsole => 'Console CurseForge';

  @override
  String get mcSetupPmcNote =>
      'Pas d’API : lecture de votre profil public dans un navigateur intégré.';

  @override
  String get mcSetupPmcUsername => 'Nom d’utilisateur Planet Minecraft';

  @override
  String get mcSetupPmcUsernameHint => 'p. ex. cyprezz';

  @override
  String get mcSetupPmcUnsupported =>
      'Cette plateforme n’a pas de moteur de navigateur intégré : Planet Minecraft ne peut pas être lu ici. Windows et Android le peuvent.';

  @override
  String get mcSetupPrivacy =>
      'Chaque clé est chiffrée sur cet appareil et envoyée uniquement à la plateforme à laquelle elle appartient. Rien n’atteint un serveur luma.';

  @override
  String get mcSetupDisconnectAll => 'Tout déconnecter';

  @override
  String get mcSetupDisconnectTitle => 'Déconnecter toutes les plateformes ?';

  @override
  String get mcSetupDisconnectBody =>
      'Les clés enregistrées, les chiffres en cache et l’historique des téléchargements enregistré par luma seront tous supprimés de cet appareil. Cet historique ne peut pas être récupéré : CurseForge et Planet Minecraft ne publient aucune donnée passée.';

  @override
  String get accountOverviewKeepIt => 'Garder';

  @override
  String get accountOverviewDisconnect => 'Déconnecter';

  @override
  String get accountOverviewOneTimeSetup => 'Configuration unique';

  @override
  String get pmcBrowserNotReady =>
      'Le navigateur intégré n’est pas encore prêt.';

  @override
  String get pmcDidNotFinishLoading =>
      'Planet Minecraft n’a pas fini de charger. Cloudflare peut demander une vérification pour cet appareil.';

  @override
  String get spotifyConnectTitle => 'Connecter Spotify';

  @override
  String get spotifyAccountSettingsTitle => 'Paramètres du compte Spotify';

  @override
  String spotifyConnectedAs(String name) {
    return 'Connecté en tant que $name.';
  }

  @override
  String get spotifyDisconnectNote =>
      'La déconnexion supprime le total d’écoute enregistré sur cet appareil.';

  @override
  String get spotifyClientIdLabel => 'ID client Spotify';

  @override
  String get spotifyClientIdHint => 'Collez votre ID client';

  @override
  String get spotifySetupSteps =>
      '1. Créez une application dans le Spotify Developer Dashboard (Web API).\n2. Ajoutez http://127.0.0.1/callback comme URI de redirection. Spotify permet à luma d’utiliser un port dynamique pour cette adresse de bouclage.\n3. Copiez ici l’ID client de l’application, puis connectez-vous via votre navigateur. Une application en mode développement nécessite Spotify Premium.';

  @override
  String get spotifyOpenDashboard => 'Ouvrir le Spotify Developer Dashboard';

  @override
  String get spotifyTokensNote =>
      'Les jetons restent dans le stockage sécurisé de cet appareil. luma lit directement vos données Spotify.';

  @override
  String get spotifyReconnect => 'Reconnecter';

  @override
  String get spotifySignIn => 'Se connecter avec Spotify';

  @override
  String get spotifyEmptyTitle => 'Connectez votre compte Spotify';

  @override
  String get spotifyEmptySubtitle =>
      'Consultez vos artistes et titres les plus écoutés, vos écoutes récentes, vos titres enregistrés, vos playlists et les statistiques de votre profil.';

  @override
  String get spotifyStatFollowers => 'Abonnés';

  @override
  String get spotifyStatSavedTracks => 'Titres enregistrés';

  @override
  String get spotifyStatPlaylists => 'Playlists';

  @override
  String get spotifyStatTrackedMinutes => 'Minutes suivies';

  @override
  String spotifyMinutesShort(int count) {
    return '$count min';
  }

  @override
  String get spotifyWaitingForPlays => 'En attente des écoutes récentes';

  @override
  String spotifyFromDate(String date) {
    return 'Depuis le $date';
  }

  @override
  String get spotifyEstimateNote =>
      'Estimé à partir de la durée complète des titres dans les écoutes récentes disponibles sur Spotify. Actualisez régulièrement pour garder le total à jour.';

  @override
  String get spotifyFavoritesTitle => 'Vos favoris';

  @override
  String get spotifyFavoritesSubtitle =>
      'Classements Spotify pour la période sélectionnée';

  @override
  String get spotifyRangeShort => '4 dernières semaines';

  @override
  String get spotifyRangeMedium => '6 derniers mois';

  @override
  String get spotifyRangeLong => 'Long terme';

  @override
  String spotifyUpdatedAgo(String time) {
    return 'Mis à jour $time';
  }

  @override
  String get spotifyRefreshToLoad =>
      'Actualisez pour charger vos statistiques Spotify.';

  @override
  String get spotifyTopArtists => 'Artistes les plus écoutés';

  @override
  String get spotifyTopTracks => 'Titres les plus écoutés';

  @override
  String get spotifyRecentlyPlayed => 'Écoutés récemment';

  @override
  String get spotifyNoTopArtists =>
      'Aucun artiste disponible pour cette période.';

  @override
  String get spotifyNoTopTracks => 'Aucun titre disponible pour cette période.';

  @override
  String get spotifyNoRecentTracks => 'Aucun titre récent disponible.';

  @override
  String get youtubeAnalyticsLoading => 'Chargement des statistiques…';

  @override
  String get youtubeAnalyticsEmpty =>
      'Pas encore de statistiques. Actualisez pour récupérer les 90 derniers jours.';

  @override
  String get youtubeMetricViews => 'Vues';

  @override
  String get youtubeMetricWatchTime => 'Temps de visionnage';

  @override
  String get youtubeLast90Days => '90 derniers jours';

  @override
  String get youtubeLast90DaysCaption => '90 derniers jours';

  @override
  String get youtubeWatchTimeSubtitle =>
      'Minutes visionnées, 90 derniers jours';

  @override
  String get youtubeUnitViews => 'vues';

  @override
  String get youtubeUnitMinutes => 'minutes';

  @override
  String get youtubeAvgViewDuration => 'Durée moy. de visionnage';

  @override
  String get youtubeNetSubscribers => 'Abonnés nets';

  @override
  String get youtubeTrafficSources => 'Sources de trafic';

  @override
  String get youtubeTrafficSourcesSubtitle =>
      'D’où viennent les vues, 90 derniers jours';

  @override
  String get youtubeNoTrafficData => 'Pas encore de données de trafic.';

  @override
  String get youtubeChartNotEnoughData => 'Pas encore assez de données.';

  @override
  String youtubeChartSemantics(
    String unit,
    String start,
    String end,
    String low,
    String high,
  ) {
    return '$unit du $start au $end : de $low à $high';
  }

  @override
  String youtubeChartTooltip(String value, String unit, String date) {
    return '$value $unit\n$date';
  }

  @override
  String get youtubeReconnectTitle => 'Reconnecter YouTube';

  @override
  String get youtubeYourChannel => 'votre chaîne';

  @override
  String youtubeConnectedAs(String channel) {
    return 'Connecté en tant que $channel. Se reconnecter remplace les identifiants enregistrés.';
  }

  @override
  String get youtubeClientId => 'ID client';

  @override
  String get youtubeClientSecret => 'Secret client';

  @override
  String get youtubeCredentialsNote =>
      'Ces informations sont chiffrées et stockées sur cet appareil. La connexion ouvre une page de connexion Google dans votre navigateur ; rien de votre compte n’atteint un serveur luma.';

  @override
  String get youtubeSignIn => 'Se connecter avec Google';

  @override
  String get youtubeDisconnectTitle => 'Déconnecter YouTube ?';

  @override
  String get youtubeDisconnectBody =>
      'Les identifiants enregistrés et tous les chiffres en cache sont supprimés de cet appareil. Votre compte Google, lui, n’est pas touché.';

  @override
  String get youtubeSetupStep1 =>
      'Créez un projet dans la Google Cloud Console.';

  @override
  String get youtubeSetupStep2 =>
      'Sous « OAuth consent screen », réglez-le sur Testing et ajoutez votre propre compte Google comme utilisateur test.';

  @override
  String get youtubeSetupStep3 =>
      'Sous « Library », activez « YouTube Data API v3 » et « YouTube Analytics API ».';

  @override
  String get youtubeSetupStep4 =>
      'Sous « Credentials », créez un ID client OAuth de type « Desktop app », puis collez son ID et son secret ci-dessus.';

  @override
  String get youtubeOpenConsole => 'Ouvrir la Google Cloud Console';

  @override
  String get youtubeNotRefreshedYet => 'Pas encore actualisé';

  @override
  String youtubeUpdatedAgo(String when) {
    return 'Mis à jour $when';
  }

  @override
  String get youtubeSubscribersHidden => 'Abonnés masqués';

  @override
  String youtubeSubscribersCount(String formatted) {
    return '$formatted abonnés';
  }

  @override
  String get youtubeSubscriberCountHiddenSemantic => 'Nombre d\'abonnés masqué';

  @override
  String youtubeSubscribersExact(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count abonnés',
      one: '1 abonné',
    );
    return '$_temp0';
  }

  @override
  String youtubeChannelSince(String date) {
    return 'Depuis le $date';
  }

  @override
  String youtubeChannelCreated(String date) {
    return 'Chaîne créée le $date';
  }

  @override
  String get youtubeChannelButton => 'Chaîne';

  @override
  String get youtubeStatTotalViews => 'Total des vues';

  @override
  String get youtubeStatAllTime => 'depuis toujours';

  @override
  String get youtubeStatSubscribers => 'Abonnés';

  @override
  String get youtubeStatHidden => 'Masqué';

  @override
  String get youtubeStatWatchTime => 'Temps de visionnage';

  @override
  String get youtubeStatLast90Days => '90 derniers jours';

  @override
  String get youtubeStatNetSubscribers => 'Abonnés nets';

  @override
  String get youtubeStatViews => 'Vues';

  @override
  String get youtubeRecentUploads => 'Envois récents';

  @override
  String get youtubeViewAll => 'Tout voir';

  @override
  String get youtubeNoVideosYet => 'Aucune vidéo pour l\'instant.';

  @override
  String youtubeAvatarSemantic(String title) {
    return 'Avatar de $title';
  }

  @override
  String youtubeViewsExact(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vues',
      one: '1 vue',
    );
    return '$_temp0';
  }

  @override
  String youtubeLikesExact(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count j\'aime',
      one: '1 j\'aime',
    );
    return '$_temp0';
  }

  @override
  String youtubeVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vidéos',
      one: '1 vidéo',
    );
    return '$_temp0';
  }

  @override
  String get youtubeSortNewest => 'Plus récentes';

  @override
  String get youtubeSortMostViewed => 'Plus vues';

  @override
  String get youtubeSortMostLiked => 'Plus aimées';

  @override
  String get youtubeUploadsTitle => 'Envois';

  @override
  String get youtubeTrafficAdvertising => 'Publicité';

  @override
  String get youtubeTrafficAnnotations => 'Annotations';

  @override
  String get youtubeTrafficCampaignCards => 'Cartes de campagne';

  @override
  String get youtubeTrafficEndScreens => 'Écrans de fin';

  @override
  String get youtubeTrafficExternalSites => 'Sites externes';

  @override
  String get youtubeTrafficEmbeddedPlayer => 'Lecteur intégré';

  @override
  String get youtubeTrafficDirectOrUnknown => 'Direct ou inconnu';

  @override
  String get youtubeTrafficNotifications => 'Notifications';

  @override
  String get youtubeTrafficPlaylists => 'Playlists';

  @override
  String get youtubeTrafficPromoted => 'Contenu promu';

  @override
  String get youtubeTrafficSuggestedVideos => 'Vidéos suggérées';

  @override
  String get youtubeTrafficSubscriptionFeed => 'Flux des abonnements';

  @override
  String get youtubeTrafficChannelPage => 'Page de la chaîne';

  @override
  String get youtubeTrafficOtherPages => 'Autres pages YouTube';

  @override
  String get youtubeTrafficYoutubeSearch => 'Recherche YouTube';

  @override
  String get youtubeTrafficShortsFeed => 'Flux Shorts';

  @override
  String get youtubeApiRejectedToken => 'Google a refusé le jeton d\'accès.';

  @override
  String get youtubeApiForbidden =>
      'Google a refusé la requête. La chaîne n\'a peut-être pas encore de statistiques disponibles, ou l\'API doit peut-être être activée dans votre projet Google Cloud.';

  @override
  String youtubeApiHttpStatus(String status) {
    return 'Google a renvoyé HTTP $status.';
  }

  @override
  String get youtubeApiNoChannel =>
      'Ce compte Google n\'a pas de chaîne YouTube.';

  @override
  String get youtubeOAuthTimeout =>
      'Délai dépassé en attendant la redirection de Google. Réessayez de vous connecter.';

  @override
  String youtubeOAuthDeclined(String error) {
    return 'Google a refusé la demande : $error';
  }

  @override
  String get youtubeOAuthStateMismatch =>
      'La réponse de Google ne correspond pas à cette demande.';

  @override
  String get youtubeOAuthNoCode =>
      'Google n\'a pas renvoyé de code d\'autorisation.';

  @override
  String get youtubeOAuthLandingConnected => 'Vous êtes connecté';

  @override
  String get youtubeOAuthLandingClose =>
      'Vous pouvez fermer cet onglet et revenir à luma.';

  @override
  String youtubeOAuthRejected(String description) {
    return 'Google a rejeté la demande : $description';
  }

  @override
  String get youtubeOAuthNoAccessToken =>
      'Google n\'a pas renvoyé de jeton d\'accès.';

  @override
  String get youtubeOAuthNoRefreshToken =>
      'Google n\'a pas renvoyé de jeton d\'actualisation. Retirez l\'accès de luma sur myaccount.google.com/permissions puis réessayez de vous connecter.';

  @override
  String get youtubeStageChannel => 'Lecture de votre chaîne';

  @override
  String get youtubeStageVideos => 'Liste des vidéos récentes';

  @override
  String get youtubeStageAnalytics => 'Récupération des statistiques';

  @override
  String get youtubeEnterCredentialsFirst =>
      'Saisissez d\'abord l\'ID client et le secret client.';

  @override
  String get youtubeNotConnected => 'YouTube n\'est pas connecté.';

  @override
  String youtubeWarnVideos(String error) {
    return 'Vidéos récentes indisponibles : $error';
  }

  @override
  String youtubeWarnAnalytics(String error) {
    return 'Statistiques indisponibles : $error';
  }

  @override
  String get aiDetectorClipboardEmpty => 'Votre presse-papiers est vide.';

  @override
  String aiDetectorTabHighlights(int count) {
    return 'Passages  $count';
  }

  @override
  String aiDetectorTabSignals(int count) {
    return 'Signaux  $count';
  }

  @override
  String get aiDetectorDisclaimer =>
      'Analyse de style heuristique — calculs sur la longueur des phrases et le choix des mots, qui ne prouvent rien. Un texte humain soigné peut sembler écrit par une machine ; une sortie de machine retouchée peut sembler humaine. Un verdict nommé repose sur une signature que le texte porte lui-même, et une signature peut être retirée ou falsifiée. Les statistiques s\'exécutent sur cet appareil. Si vous êtes connecté, le texte est aussi envoyé au serveur luma pour une évaluation par un modèle d\'IA.';

  @override
  String get aiDetectorInputTitle => 'Analyser un texte';

  @override
  String get aiDetectorInputSubtitle =>
      'Statistiques de style et recherche de filigrane Claude.';

  @override
  String get aiDetectorOnDevice => 'Sur l\'appareil';

  @override
  String aiDetectorReviewsLeft(int remaining, int limit) {
    return '$remaining/$limit analyses IA restantes cette semaine';
  }

  @override
  String aiDetectorReviewsCost(int percent) {
    return 'Les analyses coûtent $percent % de votre limite hebdomadaire';
  }

  @override
  String get aiDetectorHint =>
      'Collez le texte à vérifier — une dissertation, un e-mail, un avis produit…';

  @override
  String aiDetectorWordsShort(int words, int minWords) {
    return '$words mots sur $minWords — les statistiques de style ont besoin d\'un peu plus de texte.';
  }

  @override
  String aiDetectorWordsReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mots prêts à être analysés.',
      one: '1 mot prêt à être analysé.',
    );
    return '$_temp0';
  }

  @override
  String get aiDetectorReview => 'Analyser';

  @override
  String get aiDetectorAiLikelihood => 'Probabilité IA';

  @override
  String aiDetectorGaugeSemantic(int score, String verdict) {
    return 'Probabilité IA $score sur 100. $verdict.';
  }

  @override
  String get aiDetectorWatermarkMatch => 'Filigrane détecté';

  @override
  String get aiDetectorSummarySigned =>
      'Le texte se signe lui-même : l\'analyse a trouvé les marques cachées dans lesquelles un filigrane Claude est porté, il s\'agit donc d\'une attribution et non d\'une supposition sur le style.';

  @override
  String aiDetectorSummaryBased(int words, int sentences) {
    return 'Basé sur $words mots répartis en $sentences phrases.';
  }

  @override
  String get aiDetectorSummaryShort =>
      'Échantillon court — considérez chaque signal comme une indication plutôt qu\'une mesure.';

  @override
  String get aiDetectorStatWords => 'mots';

  @override
  String get aiDetectorStatSentences => 'phrases';

  @override
  String get aiDetectorStatAvgWords => 'mots/phrase en moyenne';

  @override
  String get aiDetectorStatFlagged => 'passages signalés';

  @override
  String get aiDetectorDeepCheckTitle => 'Analyse par modèle IA';

  @override
  String get aiDetectorDeepCheckSignIn =>
      'Connectez-vous à un compte luma approuvé pour aussi faire analyser le texte par un modèle IA. Ci-dessous, l\'analyse sur l\'appareil.';

  @override
  String get aiDetectorDeepCheckReading => 'Le modèle IA lit le texte…';

  @override
  String aiDetectorDeepCheckExhausted(int percent) {
    return 'Plus d\'analyses incluses cette semaine. Échangez $percent % de votre limite hebdomadaire Luma AI pour en lancer une de plus.';
  }

  @override
  String get aiDetectorDeepCheckIntro =>
      'Où et comment le texte paraît généré par une IA, selon le modèle IA.';

  @override
  String aiDetectorChargeExchanged(int percent) {
    return 'Où et comment le texte paraît généré par une IA, selon le modèle IA. $percent % de votre limite hebdomadaire échangés.';
  }

  @override
  String aiDetectorChargeUsed(int used, int included) {
    return 'Où et comment le texte paraît généré par une IA, selon le modèle IA. $used analyses incluses sur $included utilisées cette semaine.';
  }

  @override
  String get aiDetectorRunReview => 'Lancer l\'analyse IA';

  @override
  String aiDetectorExchangeWeekly(int percent) {
    return 'Échanger $percent % de la semaine';
  }

  @override
  String aiDetectorPassageSemantic(int percent, String passage) {
    return '$percent % de chances d\'être généré par IA : $passage';
  }

  @override
  String aiDetectorHighlightSemantic(String note, String passage) {
    return '$note : $passage';
  }

  @override
  String get aiDetectorNothingFlagged => 'Rien de signalé';

  @override
  String get aiDetectorNothingFlaggedBody =>
      'Aucune formule toute faite, aucun caractère caché, aucune ouverture formulaïque. Chaque passage de ce texte semble écrit à la main.';

  @override
  String get aiDetectorHighlightsTitle =>
      'Tout ce que les contrôles ont relevé, marqué sur place';

  @override
  String get aiDetectorHighlightsLegend =>
      'Chaque marque est stylisée selon son poids, pas seulement par la couleur : ondulée pour une signature, pleine pour un indice fort, pointillée pour un indice léger.';

  @override
  String aiDetectorTruncated(int limit) {
    return 'Affichage des $limit premiers caractères. Le score et les signaux ci-dessous couvrent tout le texte.';
  }

  @override
  String get aiDetectorSignalsNothing =>
      'Rien de suspect — longueurs variées, aucune formule toute faite, aucun filigrane. Ressemble à une écriture humaine.';

  @override
  String get aiDetectorQuietChecks => 'Contrôles sans résultat';

  @override
  String aiDetectorQuietOneWay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count contrôles n\'ont rien trouvé — un tiret signifie que ce contrôle ne joue que contre un texte, donc ne rien trouver ne le fait pas trancher',
      one:
          '1 contrôle n\'a rien trouvé — un tiret signifie que ce contrôle ne joue que contre un texte, donc ne rien trouver ne le fait pas trancher',
    );
    return '$_temp0';
  }

  @override
  String aiDetectorQuietNothing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contrôles n\'ont rien trouvé qui mérite d\'être signalé',
      one: '1 contrôle n\'a rien trouvé qui mérite d\'être signalé',
    );
    return '$_temp0';
  }

  @override
  String get aiDetectorMatch => 'correspondance';

  @override
  String get aiReviewSignInRequired =>
      'Connectez-vous à un compte luma approuvé pour utiliser la vérification approfondie.';

  @override
  String get aiReviewUnreachable =>
      'Impossible de joindre le serveur luma. Vérifiez votre connexion et réessayez.';

  @override
  String aiReviewFailedStatus(int status) {
    return 'La vérification approfondie a échoué (HTTP $status).';
  }

  @override
  String get aiReviewMalformed => 'Le serveur a envoyé un résultat mal formé.';

  @override
  String aiUsageSyncOsDevice(String os) {
    return 'Appareil $os';
  }

  @override
  String get aiUsageSyncAnotherDevice => 'Un autre appareil';

  @override
  String get aiAgentHeader => 'Créateur d\'agents';

  @override
  String aiAgentHeaderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count agents',
      one: '1 agent',
    );
    return '$_temp0 · spécialistes réutilisables pour Codex, Claude Code et opencode';
  }

  @override
  String get aiAgentNew => 'Nouvel agent';

  @override
  String get aiAgentEmptyTitle => 'Aucun agent pour l\'instant';

  @override
  String get aiAgentEmptyBody =>
      'Donnez à une tâche répétitive son propre spécialiste.';

  @override
  String get aiAgentCreate => 'Créer un agent';

  @override
  String get aiAgentSpecialistSubtitle => 'Agent spécialisé';

  @override
  String get aiAgentDeleteTitle => 'Supprimer l\'agent ?';

  @override
  String aiAgentDeleteBody(String name) {
    return '« $name » sera supprimé de Luma.';
  }

  @override
  String get aiAgentSaved => 'Agent enregistré';

  @override
  String aiAgentPromptCopied(String target) {
    return 'Prompt copié — collez-le dans $target';
  }

  @override
  String aiAgentExportDialogTitle(String target, String file) {
    return 'Exporter $target $file';
  }

  @override
  String aiAgentExported(String target, String file) {
    return '$target $file exporté';
  }

  @override
  String aiAgentChooseProjectFolder(String target) {
    return 'Choisir le dossier de projet $target';
  }

  @override
  String aiAgentReplaceTitle(String file) {
    return 'Remplacer le fichier $file existant ?';
  }

  @override
  String aiAgentReplaceBody(String path) {
    return '$path existe déjà dans ce projet.';
  }

  @override
  String get aiAgentReplace => 'Remplacer';

  @override
  String aiAgentInstalledAt(String path) {
    return 'Installé dans $path';
  }

  @override
  String get aiAgentEdit => 'Modifier l\'agent';

  @override
  String get aiAgentDeleteTooltip => 'Supprimer l\'agent';

  @override
  String get aiAgentNameHint => 'Relecteur de code Flutter';

  @override
  String get aiAgentFieldDescription => 'Description courte';

  @override
  String get aiAgentDescriptionHint => 'À quoi sert ce spécialiste';

  @override
  String get aiAgentFieldModel => 'Modèle préféré (facultatif)';

  @override
  String get aiAgentModelHint =>
      'sonnet pour Claude Code, anthropic/claude-sonnet-5 pour opencode';

  @override
  String get aiAgentFieldInstructions => 'Instructions';

  @override
  String get aiAgentInstructionsHint =>
      'Vous êtes un spécialiste…\n\nDécrivez la mission, les limites et la démarche de raisonnement.';

  @override
  String get aiAgentFieldOutput => 'Format de sortie (facultatif)';

  @override
  String get aiAgentOutputHint =>
      'Constats regroupés par gravité, avec références au fichier et à la ligne';

  @override
  String get aiAgentLibraryContext => 'Contexte de la bibliothèque';

  @override
  String get aiAgentLibraryContextHelp =>
      'Les notes sélectionnées sont intégrées lorsque vous copiez ou exportez cet agent.';

  @override
  String get aiAgentLibraryEmpty =>
      'Créez d\'abord des notes Markdown dans l\'onglet Bibliothèque.';

  @override
  String get aiAgentUseWith => 'Utiliser avec';

  @override
  String get aiAgentCopyPrompt => 'Copier le prompt';

  @override
  String aiAgentExportFile(String file) {
    return 'Exporter $file';
  }

  @override
  String aiAgentInstallFor(String target) {
    return 'Installer pour $target';
  }

  @override
  String get aiAgentSave => 'Enregistrer l\'agent';

  @override
  String get aiUsageSaving => 'Enregistrement…';

  @override
  String get aiMarkdownNoteLabel => 'Note Markdown';

  @override
  String get aiLibrarySaved => 'Note Markdown enregistrée';

  @override
  String get aiLibraryImportTitle => 'Importer une note Markdown';

  @override
  String aiLibraryImported(String name) {
    return '$name importé — enregistrez-le pour l\'ajouter à la bibliothèque';
  }

  @override
  String get aiLibraryExportTitle => 'Exporter la note Markdown';

  @override
  String aiLibraryExported(String name) {
    return '$name exporté';
  }

  @override
  String get aiLibraryDeleteTitle => 'Supprimer la note Markdown ?';

  @override
  String aiLibraryDeleteBody(String title) {
    return '« $title » sera supprimé de la bibliothèque.';
  }

  @override
  String get aiLibraryHeader => 'Bibliothèque Markdown';

  @override
  String aiLibraryHeaderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes',
      one: '1 note',
    );
    return '$_temp0 · contexte réutilisable pour vos agents';
  }

  @override
  String get aiLibraryNewNote => 'Nouvelle note';

  @override
  String get aiLibraryEmptyTitle => 'Votre bibliothèque est vide';

  @override
  String get aiLibraryEmptyBody =>
      'Enregistrez ici vos prompts, le contexte du projet et vos listes de contrôle.';

  @override
  String get aiLibraryCreateNote => 'Créer une note';

  @override
  String get aiLibraryNewEditorTitle => 'Nouvelle note Markdown';

  @override
  String get aiLibraryEditNote => 'Modifier la note';

  @override
  String get aiLibraryExportMdTooltip => 'Exporter en .md';

  @override
  String get aiLibraryDeleteNoteTooltip => 'Supprimer la note';

  @override
  String get aiLibraryTitleHint => 'Conventions du projet';

  @override
  String get aiLibraryFieldTags => 'Étiquettes';

  @override
  String get aiLibraryTagsHint => 'flutter, conventions, projet';

  @override
  String get aiLibraryContent => 'Contenu';

  @override
  String get aiLibraryNothingWritten => 'Rien n\'a encore été écrit.';

  @override
  String get aiLibraryBodyHint =>
      '# Instructions\n\nÉcrivez du contexte réutilisable en Markdown…';

  @override
  String get aiLibrarySaveNote => 'Enregistrer la note';

  @override
  String get aiUsageNoLogsTitle =>
      'Aucun journal d\'utilisation d\'IA local trouvé';

  @override
  String get aiUsageNoLogsSubtitle =>
      'Utilisation de l\'IA lit les journaux de session de Claude Code (~/.claude/projects), Codex CLI (~/.codex/sessions), Antigravity (~/.gemini/antigravity), OpenCode (~/.local/share/opencode) et Freebuff (~/.config/freebuff-desktop/projects) sur cet appareil, et enregistre chaque appel de l\'Assistant de luma. Rien ne quitte l\'appareil sauf si vous activez la synchronisation de l\'utilisation de l\'IA dans les Paramètres, qui ajoute aussi vos autres appareils. Utilisez l\'un de ces outils ici, puis relancez l\'analyse.';

  @override
  String get aiUsageRescan => 'Relancer l\'analyse';

  @override
  String get aiUsageSettingsTitle => 'Paramètres d\'utilisation';

  @override
  String get aiUsageCombineByCompany => 'Regrouper les modèles par entreprise';

  @override
  String get aiUsageCombineByCompanyHint =>
      'Regroupe chaque modèle d\'une même entreprise sur une seule ligne';

  @override
  String get aiUsageSorting => 'Tri';

  @override
  String get aiUsageSortingHint =>
      'Critère de tri de chaque tableau et graphique';

  @override
  String get aiUsageSortModels => 'Modèles (camembert + tableau)';

  @override
  String get aiUsageSortProjects => 'Principaux projets';

  @override
  String get aiUsageSortProviders => 'Fournisseurs (OpenCode)';

  @override
  String get aiUsageRescanTooltip =>
      'Relancer l\'analyse des journaux d\'utilisation locaux';

  @override
  String get aiUsageDisplaySettingsTooltip =>
      'Paramètres d\'affichage de l\'utilisation';

  @override
  String aiUsageStatusUpToDate(String time, String synced) {
    return 'À jour · $time$synced';
  }

  @override
  String aiUsageStatusNewTurns(int count, String time, String synced) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouveaux tours',
      one: '1 nouveau tour',
    );
    return '$_temp0 · $time$synced';
  }

  @override
  String aiUsageStatusSyncedDevices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count autres appareils',
      one: '1 autre appareil',
    );
    return ' · dont $_temp0';
  }

  @override
  String get aiUsageDevicesTooltipHeader =>
      'Utilisation cumulée sur vos appareils :';

  @override
  String get aiUsageThisDevice => 'Cet appareil';

  @override
  String aiUsageDeviceLine(String name, int count, String synced) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tours',
      one: '1 tour',
    );
    return '$name · $_temp0 · synchronisé $synced';
  }

  @override
  String get aiUsageSourceAntigravityEst => 'Antigravity (est.)';

  @override
  String get aiUsageNoUsageTitle =>
      'Aucune utilisation enregistrée sur cette période';

  @override
  String get aiUsageNoUsageSubtitle =>
      'Essayez une période plus large, ou utilisez l\'un des outils pris en charge puis relancez l\'analyse.';

  @override
  String aiUsageNoUsageSourceSubtitle(String source) {
    return 'Essayez une période plus large, ou utilisez $source puis relancez l\'analyse.';
  }

  @override
  String get aiUsageTotalTokens => 'Total de jetons';

  @override
  String get aiUsageTotalTokensTooltip =>
      'Uniquement les nouveaux jetons : entrée + sortie + premières écritures de cache. Les lectures de cache ne sont pas incluses (voir la carte correspondante). Une longue session relit presque à chaque tour le même contexte grandissant, ce qui compterait sinon la même conversation encore et encore.';

  @override
  String get aiUsageCacheReads => 'Lectures du cache';

  @override
  String get aiUsageCacheReadsTooltip =>
      'Contexte en cache relu sur tous les tours de la période : réel et facturé, mais à tarif fortement réduit, et non compté dans « Total de jetons » car il s\'agit de réutilisation de contenu et non de contenu nouveau.';

  @override
  String get aiUsageEstCost => 'Coût est.';

  @override
  String get aiUsageEstCostTooltip =>
      'Coût estimé aux tarifs de l\'API, y compris les lectures/écritures de cache au tarif réduit. Cela reflète donc plus d\'utilisation que « Total de jetons » seul. Les abonnements (Max/Pro) sont facturés différemment de cette estimation par jeton.';

  @override
  String get aiUsageTurns => 'Tours';

  @override
  String get aiUsageSessions => 'Sessions';

  @override
  String get aiUsageTopCompany => 'Entreprise principale';

  @override
  String get aiUsageTopModel => 'Modèle principal';

  @override
  String get aiUsageUnbillableNote =>
      '* exclut l\'utilisation des modèles hors des tarifs connus de leur fournisseur';

  @override
  String get aiUsageAntigravityNote =>
      'Les chiffres d\'Antigravity sont estimés à partir de la longueur des messages. L\'outil n\'enregistre pas l\'utilisation réelle de jetons en local. Ils ne sont pas exacts comme ceux de Claude Code/Codex CLI. Le coût (marqué ~) n\'apparaît que pour les modèles Gemini/Claude reconnus, et c\'est une estimation plus approximative que les deux autres sources.';

  @override
  String get aiUsagePickWiderRange =>
      'Choisissez une période plus large pour voir le détail par jour';

  @override
  String get aiUsageCompanies => 'Entreprises';

  @override
  String get aiUsageModels => 'Modèles';

  @override
  String aiUsageSortedBy(String metric) {
    return 'Trié par $metric';
  }

  @override
  String get aiUsageSwitchToAllHeatmap =>
      'Passez sur « Tout » pour voir votre carte de contributions annuelle';

  @override
  String get aiUsageLongestSession => 'Session la plus longue';

  @override
  String get aiUsagePriciestSession => 'Session la plus coûteuse';

  @override
  String get aiUsageLongestStreak => 'Plus longue série';

  @override
  String aiUsageStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '1 jour',
    );
    return '$_temp0';
  }

  @override
  String aiUsageDurationDaysHours(int days, int hours) {
    return '$days j $hours h';
  }

  @override
  String aiUsageDurationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String aiUsageDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get aiUsageOther => 'Autre';

  @override
  String aiUsageTooltipDay(
    String day,
    String input,
    String output,
    String cacheRead,
    String cacheWrite,
    String cost,
  ) {
    return '$day\nEntrée : $input\nSortie : $output\nLecture du cache : $cacheRead\nÉcriture du cache : $cacheWrite\n$cost';
  }

  @override
  String get aiUsageInput => 'Entrée';

  @override
  String get aiUsageOutput => 'Sortie';

  @override
  String get aiUsageCacheWrite => 'Écriture du cache';

  @override
  String get aiUsageAvgHourly => 'Répartition horaire moyenne';

  @override
  String get aiUsageAnthropicPeakTooltip =>
      'Anthropic a publié cette plage horaire pour Claude Code en mars 2026 ; la réduction des limites de débit a été levée pour Pro/Max le 6 mai 2026, mais ces heures sont toujours souvent citées.';

  @override
  String aiUsageAnthropicPeak(String start, String end) {
    return 'Pic Anthropic : $start–$end';
  }

  @override
  String get aiUsageHourlyHint =>
      'Jetons par heure, en moyenne sur les jours de la période, heure locale. Les barres en surbrillance tombent dans la plage ci-dessus (jours de semaine, 5h–11h HP).';

  @override
  String aiUsageHourlyTooltip(String hour, String tokens, String turns) {
    return '$hour\n$tokens jetons/jour en moy.\n$turns tours/jour en moy.';
  }

  @override
  String get aiUsageNoProjectData =>
      'Aucune donnée de projet sur cette période';

  @override
  String aiUsageTopProjectsBy(String metric) {
    return 'Principaux projets par $metric';
  }

  @override
  String get aiUsageProjectSourceNote =>
      'Claude Code, Codex CLI et OpenCode uniquement. Antigravity n\'a pas de source de projet fiable et est regroupé sous « Projet inconnu ».';

  @override
  String get aiUsageUnknownProject => 'Projet inconnu';

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
      other: '$turns tours',
      one: '1 tour',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sessions,
      locale: localeName,
      other: '$sessions sessions',
      one: '1 session',
    );
    return 'Entrée : $input · Sortie : $output\n$_temp0 · $_temp1';
  }

  @override
  String get aiUsageNoProviderData =>
      'Aucune donnée de fournisseur sur cette période';

  @override
  String aiUsageProvidersBy(String metric) {
    return 'Fournisseurs par $metric';
  }

  @override
  String get aiUsageProvidersHint =>
      'Vers quel fournisseur chaque tour OpenCode a été acheminé. Chaque fournisseur est tarifé comme s\'il était utilisé avec une clé d\'API payante classique, y compris les modèles « gratuits » d\'OpenCode et tout fournisseur que cette application ne connaît pas spécifiquement. Les deux sont affichés à un tarif estimé plutôt que pris au pied de la lettre ou affichés comme n/d. Un fournisseur qui tourne réellement sur votre propre matériel (Ollama, llama.cpp, ...) affiche toujours un vrai \$0.00.';

  @override
  String aiUsageModelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modèles',
      one: '1 modèle',
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
      other: '$turns tours',
      one: '1 tour',
    );
    return 'Entrée : $input · Sortie : $output\nLectures du cache : $cacheRead\n$_temp0 · $models';
  }

  @override
  String get aiUsageNotApplicable => 'n/d';

  @override
  String get aiUsageCompany => 'Entreprise';

  @override
  String get aiUsageModel => 'Modèle';

  @override
  String get aiUsageCompanyHeaderTip =>
      'Quelle entreprise a conçu les modèles utilisés';

  @override
  String get aiUsageModelHeaderTip =>
      'Quel modèle a été utilisé et de quel outil local il provient';

  @override
  String get aiUsageTurnsHeaderTip =>
      'Nombre de réponses IA distinctes (appels d\'API) effectuées avec ce modèle';

  @override
  String get aiUsageTokens => 'Jetons';

  @override
  String get aiUsageTokensHeaderTip =>
      'Uniquement les nouveaux jetons : entrée + sortie + premières écritures de cache. Exclut les lectures de cache (réutilisation répétée du contexte précédent). Voir la carte Lectures du cache ci-dessus pour ce chiffre.';

  @override
  String get aiUsageCost => 'Coût';

  @override
  String get aiUsageCostHeaderTip =>
      'Coût en USD indiqué par le fournisseur pour les appels de luma lorsqu\'il est disponible ; sinon une estimation au tarif de l\'API du modèle ou du fournisseur. « n/d » signifie qu\'aucun coût n\'a pu être déterminé.';

  @override
  String get aiUsageHeatmapTitle => 'Carte de contributions';

  @override
  String get aiUsageHeatmapHint =>
      'Intensité quotidienne des jetons sur la dernière année. Survolez un jour pour les détails.';

  @override
  String get aiUsageNoUsageYet =>
      'Aucune utilisation enregistrée pour l\'instant';

  @override
  String aiUsageHeatmapCellTooltip(String date, String tokens, String cost) {
    return '$date\n$tokens jetons · $cost';
  }

  @override
  String aiUsageHeatmapEmptyTooltip(String date) {
    return '$date\nAucune utilisation';
  }

  @override
  String get aiUsageLess => 'Moins';

  @override
  String get aiUsageSectionUsage => 'Utilisation de l\'IA';

  @override
  String get aiUsageSectionUsageBlurb => 'Ta propre consommation de jetons';

  @override
  String get aiUsageSectionLeaderboard => 'Classement';

  @override
  String get aiUsageSectionLeaderboardBlurb => 'Tous les modèles, classés';

  @override
  String get aiUsageSectionOpenSource => 'Open source';

  @override
  String get aiUsageSectionOpenSourceBlurb =>
      'Ce que ton matériel peut faire tourner';

  @override
  String get aiUsageSectionLibrary => 'Bibliothèque';

  @override
  String get aiUsageSectionLibraryBlurb => 'Contexte Markdown réutilisable';

  @override
  String get aiUsageSectionAgents => 'Agents';

  @override
  String get aiUsageSectionAgentsBlurb => 'Codex, Claude Code et opencode';

  @override
  String get aiUsageSectionTests => 'Tests';

  @override
  String get aiUsageSectionTestsBlurb => 'Expériences en cours';

  @override
  String get aiUsageSectionAssets => 'Ressources';

  @override
  String get aiUsageSectionAssetsBlurb => 'Libre d\'utilisation';

  @override
  String get aiUsageSidebarExpand => 'Développer la barre latérale';

  @override
  String get aiUsageSidebarCollapse => 'Réduire la barre latérale';

  @override
  String get aiUsageSidebarCollapseShort => 'Réduire';

  @override
  String aiUsageSectionTooltip(String label, String blurb) {
    return '$label — $blurb';
  }

  @override
  String get aiUsageRangeLast7Days => '7j';

  @override
  String get aiUsageRangeLast30Days => '30j';

  @override
  String get aiUsageRangeAll => 'Tout';

  @override
  String get aiUsageUnknownProvider => 'inconnu';

  @override
  String get aiUsageSortTokens => 'Jetons';

  @override
  String get aiUsageSortTurns => 'Tours';

  @override
  String get aiUsageSortCost => 'Coût';

  @override
  String get aiUsageCompanyLocal => 'Local';

  @override
  String get aiUsageUntitledNote => 'Note sans titre';

  @override
  String get aiUsageUntitledAgent => 'Agent sans titre';

  @override
  String get aiAgentTargetFileSubagent => 'sous-agent';

  @override
  String get aiAgentTargetFileAgent => 'agent';

  @override
  String get aiUsageEffortUnspecified => 'Non précisé';

  @override
  String get aiUsageEffortMinimal => 'Minimal';

  @override
  String get aiUsageEffortLow => 'Faible';

  @override
  String get aiUsageEffortMedium => 'Moyen';

  @override
  String get aiUsageEffortHigh => 'Élevé';

  @override
  String get aiUsageEffortExtraHigh => 'Très élevé';

  @override
  String get aiUsageEffortMax => 'Maximal';

  @override
  String get aiUsageEffortBreakdownTitle => 'Répartition de l\'effort Claude';

  @override
  String get aiUsageEffortBreakdownBlurb =>
      'Le niveau de réflexion demandé à chaque modèle Claude, selon les tours et les jetons dépensés.';

  @override
  String aiUsageEffortTurns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tours',
      one: '1 tour',
    );
    return '$_temp0';
  }

  @override
  String aiUsageAssetsIntro(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count modèles procéduraux du jeu d\'aéroport. Ouvrez-en un pour l\'inspecter en 3D, ou téléchargez-le en fichier HTML.',
      one:
          '1 modèle procédural du jeu d\'aéroport. Ouvrez-le pour l\'inspecter en 3D, ou téléchargez-le en fichier HTML.',
    );
    return '$_temp0';
  }

  @override
  String get aiUsageAssetsSearchHint => 'Rechercher des modèles';

  @override
  String get aiUsageAssetsClearSearch => 'Effacer la recherche';

  @override
  String get aiUsageAssetsCategoryAll => 'Tous';

  @override
  String get aiUsageAssetsCategoryRetail => 'Commerces';

  @override
  String get aiUsageAssetsCategoryFood => 'Restauration';

  @override
  String get aiUsageAssetsCategoryEntertainment => 'Loisirs';

  @override
  String get aiUsageAssetsCategorySecurity => 'Sécurité';

  @override
  String get aiUsageAssetsCategoryPassenger => 'Passagers';

  @override
  String get aiUsageAssetsNoMatch => 'Aucun modèle correspondant';

  @override
  String get aiUsageAssetsNoMatchHint =>
      'Essayez un autre nom ou effacez le filtre.';

  @override
  String aiUsageAssetOpenLabel(String name) {
    return 'Ouvrir $name';
  }

  @override
  String get aiUsageAssetsLoadFailed => 'Impossible de charger les ressources';

  @override
  String get aiUsageAssetBackTooltip => 'Retour aux ressources';

  @override
  String get aiUsageAssetDownloadHtmlTooltip =>
      'Un seul fichier HTML qui ouvre ce modèle hors ligne dans n\'importe quel navigateur';

  @override
  String get aiUsageAssetDownloadHtml => 'Télécharger en HTML';

  @override
  String aiUsageAssetSaved(String fileName) {
    return '$fileName enregistré';
  }

  @override
  String aiUsageAssetSaveFailed(String error) {
    return 'Enregistrement impossible : $error';
  }

  @override
  String aiUsageAssetSaveDialogTitle(String name) {
    return 'Enregistrer $name';
  }

  @override
  String get aiUsageAssetStudioUnsupported =>
      'Le studio 3D fonctionne sous Windows et Android';

  @override
  String get aiUsageAssetStudioUnsupportedHint =>
      'Téléchargez le HTML pour ouvrir ce modèle dans n\'importe quel navigateur — il fonctionne hors ligne.';

  @override
  String get aiUsageAssetStudioUnavailable => 'Studio indisponible';

  @override
  String aiUsageAssetStudioPrepareFailed(String error) {
    return 'Impossible de préparer le studio : $error';
  }

  @override
  String aiCatalogServerError(String status) {
    return 'Le serveur n\'a pas pu renvoyer le classement des modèles (HTTP $status).';
  }

  @override
  String get aiCatalogMalformedResponse => 'Réponse du classement mal formée.';

  @override
  String get aiCompareTitle => 'Comparer des modèles';

  @override
  String get aiComparePickTwo => 'Choisissez au moins deux modèles à comparer.';

  @override
  String get aiCompareAddHint =>
      'Ajoutez des modèles pour les comparer côte à côte.';

  @override
  String get aiCompareAddTooltip => 'Ajouter un modèle';

  @override
  String get aiCompareAddModel => 'Ajouter un modèle';

  @override
  String get aiCompareNotEnoughRatings =>
      'Pas assez de notes communes pour tracer un radar pour cette sélection.';

  @override
  String get aiLeaderboardMetricIntelligence => 'Indice d\'intelligence';

  @override
  String get aiLeaderboardMetricReasoning => 'Indice de raisonnement';

  @override
  String get aiLeaderboardMetricCoding => 'Indice de code';

  @override
  String get aiLeaderboardMetricAgent => 'Indice d\'agent';

  @override
  String get aiLeaderboardMetricMath => 'Indice de mathématiques';

  @override
  String get aiLeaderboardMetricBlendedPrice => 'Prix mixte 8:1';

  @override
  String get aiLeaderboardMetricAveragePrice => 'Prix moyen';

  @override
  String get aiLeaderboardMetricInputPrice => 'Prix d\'entrée';

  @override
  String get aiLeaderboardMetricOutputPrice => 'Prix de sortie';

  @override
  String get aiLeaderboardMetricParameters => 'Paramètres';

  @override
  String get aiLeaderboardMetricContext => 'Longueur du contexte';

  @override
  String get aiLeaderboardMetricSpeed => 'Vitesse';

  @override
  String get aiLeaderboardMetricLatency => 'Temps jusqu\'au premier jeton';

  @override
  String get aiLeaderboardUnitTokens => 'jetons';

  @override
  String get aiLeaderboardColumnRank => 'RANG';

  @override
  String get aiLeaderboardColumnRankHelp => 'Position dans le tri actuel';

  @override
  String get aiLeaderboardColumnName => 'MODÈLE';

  @override
  String get aiLeaderboardColumnNameHelp =>
      'Nom du modèle et fournisseur qui le propose';

  @override
  String get aiLeaderboardColumnIntelligence => 'INTELLIGENCE';

  @override
  String get aiLeaderboardColumnIntelligenceHelp =>
      'Indice d\'intelligence d\'Artificial Analysis : le score composite de tous les benchmarks qu\'il exécute, au meilleur niveau de raisonnement du modèle';

  @override
  String get aiLeaderboardColumnCoding => 'CODE';

  @override
  String get aiLeaderboardColumnCodingHelp =>
      'Benchmarks de génération et de correction de code';

  @override
  String get aiLeaderboardColumnAgent => 'AGENT';

  @override
  String get aiLeaderboardColumnAgentHelp =>
      'Benchmarks d\'utilisation d\'outils sur le long terme et de tâches en plusieurs étapes';

  @override
  String get aiLeaderboardColumnCodeArenaHelp =>
      'Elo en confrontation directe fondé sur les préférences humaines sur des tâches de code';

  @override
  String get aiLeaderboardColumnParams => 'PARAMS';

  @override
  String get aiLeaderboardColumnParamsHelp =>
      'Nombre total de paramètres, en milliards. Connu uniquement pour les modèles à poids ouverts';

  @override
  String get aiLeaderboardColumnContext => 'CONTEXTE';

  @override
  String get aiLeaderboardColumnContextHelp =>
      'Plus grande entrée acceptée par le modèle, en jetons';

  @override
  String get aiLeaderboardColumnPrice => 'PRIX \$/M';

  @override
  String get aiLeaderboardColumnPriceHelp =>
      'Prix d\'entrée et de sortie moyennés, en USD par million de jetons';

  @override
  String get aiLeaderboardColumnLicense => 'LICENCE';

  @override
  String get aiLeaderboardColumnLicenseHelp =>
      'Le cadenas ouvert signifie que les poids sont téléchargeables';

  @override
  String get aiLeaderboardGraphEmptyTitle => 'Pas encore de données de modèles';

  @override
  String get aiLeaderboardGraphEmptySubtitle =>
      'Le graphique a besoin du catalogue de modèles pour s\'afficher.';

  @override
  String aiLeaderboardGraphNotEnough(String x, String y) {
    return 'Pas assez de modèles ont à la fois $x et $y pour tracer le graphique.';
  }

  @override
  String get aiLeaderboardGraphXAxis => 'AXE X';

  @override
  String get aiLeaderboardGraphYAxis => 'AXE Y';

  @override
  String get aiLeaderboardGraphVendors => 'FOURNISSEURS';

  @override
  String get aiLeaderboardGraphHighlight => 'MODÈLES EN ÉVIDENCE';

  @override
  String get aiLeaderboardGraphHighlightHint =>
      'Choisis des modèles à mettre en évidence sur le graphique.';

  @override
  String get aiLeaderboardGraphLogScale => 'Échelle logarithmique';

  @override
  String aiLeaderboardGraphPlotted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modèles tracés',
      one: '1 modèle tracé',
    );
    return '$_temp0';
  }

  @override
  String get aiLeaderboardTabTable => 'Tableau';

  @override
  String get aiLeaderboardTabGraph => 'Graphique';

  @override
  String get aiLeaderboardTabInsights => 'Analyses';

  @override
  String get aiLeaderboardCompare => 'Comparer';

  @override
  String get aiLeaderboardEffortMinimal => 'Minimal';

  @override
  String get aiLeaderboardEffortLow => 'Faible';

  @override
  String get aiLeaderboardEffortMedium => 'Moyen';

  @override
  String get aiLeaderboardEffortHigh => 'Élevé';

  @override
  String get aiLeaderboardEffortXhigh => 'Très élevé';

  @override
  String get aiLeaderboardEffortMax => 'Maximum';

  @override
  String get aiLeaderboardInsightsEmptySubtitle =>
      'Les analyses ont besoin du catalogue de modèles pour se construire.';

  @override
  String get aiLeaderboardInsightsEyebrowEfficiency => 'EFFICACITÉ';

  @override
  String get aiLeaderboardInsightsPriceVsPerformance => 'Prix et performance';

  @override
  String aiLeaderboardInsightsFrontierBlurb(String metric) {
    return 'Coût mixte (8:1 entrée/sortie) par rapport à $metric. Les modèles sur la courbe sont efficaces au sens de Pareto : aucun autre n\'est à la fois moins cher et au moins aussi bon.';
  }

  @override
  String get aiLeaderboardInsightsEyebrowBestByTask => 'LE MEILLEUR PAR TÂCHE';

  @override
  String get aiLeaderboardInsightsCategoryLeaders => 'Leaders par catégorie';

  @override
  String get aiLeaderboardInsightsEyebrowResearch => 'RECHERCHE';

  @override
  String get aiLeaderboardInsightsLatestNews => 'Dernières actualités';

  @override
  String get aiLeaderboardInsightsScoreAxis => 'Axe du score';

  @override
  String aiLeaderboardInsightsNotEnoughPriced(String metric) {
    return 'Pas encore assez de modèles tarifés évalués sur $metric.';
  }

  @override
  String get aiLeaderboardInsightsBlendedCostAxis =>
      'Coût mixte \$/1M jetons (8:1 entrée/sortie)';

  @override
  String get aiLeaderboardInsightsTaskReasoning => 'Meilleur en raisonnement';

  @override
  String get aiLeaderboardInsightsTaskCoding => 'Meilleur en code';

  @override
  String get aiLeaderboardInsightsTaskAgents => 'Meilleur pour les agents';

  @override
  String get aiLeaderboardInsightsTaskFastest => 'Le plus rapide';

  @override
  String get aiLeaderboardInsightsTaskCheapest => 'Frontière la moins chère';

  @override
  String get aiLeaderboardInsightsTaskLargest => 'Plus grand contexte';

  @override
  String get aiLeaderboardInsightsNewBadge => 'NOUVEAU';

  @override
  String get aiLeaderboardDetailFallbackTitle => 'Modèle';

  @override
  String get aiLeaderboardDetailCompareTooltip =>
      'Comparer avec d\'autres modèles';

  @override
  String get aiLeaderboardDetailNoLongerListed =>
      'Ce modèle ne figure plus dans la liste.';

  @override
  String get aiLeaderboardDetailProprietary =>
      'Propriétaire — accès API uniquement';

  @override
  String get aiLeaderboardDetailOpenWeights => 'Poids ouverts';

  @override
  String aiLeaderboardDetailOpenWeightsLicensed(String license) {
    return 'Poids ouverts · $license';
  }

  @override
  String aiLeaderboardDetailReleased(String date) {
    return 'Sorti $date';
  }

  @override
  String aiLeaderboardDetailKnowledgeCutoff(String date) {
    return 'Date limite des connaissances $date';
  }

  @override
  String aiLeaderboardDetailParamsTag(String params) {
    return '$params paramètres';
  }

  @override
  String get aiLeaderboardDetailRatingIntelligence => 'Intelligence';

  @override
  String get aiLeaderboardDetailRatingIntelligenceHelp =>
      'Indice d\'intelligence d\'Artificial Analysis, au meilleur niveau d\'effort';

  @override
  String get aiLeaderboardDetailRatingReasoning => 'Raisonnement';

  @override
  String get aiLeaderboardDetailRatingReasoningHelp =>
      'Raisonnement et connaissances de niveau master';

  @override
  String get aiLeaderboardDetailRatingCoding => 'Code';

  @override
  String get aiLeaderboardDetailRatingCodingHelp =>
      'Génération et correction de code';

  @override
  String get aiLeaderboardDetailRatingAgent => 'Agent';

  @override
  String get aiLeaderboardDetailRatingAgentHelp =>
      'Utilisation d\'outils sur le long terme';

  @override
  String get aiLeaderboardDetailRatingCodeArenaHelp =>
      'Elo de préférence de code en confrontation directe';

  @override
  String get aiLeaderboardDetailRatingMath => 'Mathématiques';

  @override
  String get aiLeaderboardDetailRatingMathHelp =>
      'Mathématiques de niveau compétition';

  @override
  String aiLeaderboardDetailTokensCount(String tokens) {
    return '$tokens jetons';
  }

  @override
  String aiLeaderboardDetailPricePerMTokens(String price) {
    return '$price/M jetons';
  }

  @override
  String get aiLeaderboardDetailContextWindow => 'Fenêtre de contexte';

  @override
  String get aiLeaderboardDetailMaxOutput => 'Sortie max.';

  @override
  String get aiLeaderboardDetailInputPrice => 'Prix d\'entrée';

  @override
  String get aiLeaderboardDetailOutputPrice => 'Prix de sortie';

  @override
  String get aiLeaderboardDetailCacheRead => 'Lecture du cache';

  @override
  String get aiLeaderboardDetailEffortLevels => 'Niveaux d\'effort';

  @override
  String get aiLeaderboardDetailLicence => 'Licence';

  @override
  String get aiLeaderboardDetailSpecifications => 'CARACTÉRISTIQUES';

  @override
  String get aiLeaderboardDetailEffortTitle =>
      'EFFORT PAR RAPPORT AUX JETONS UTILISÉS';

  @override
  String get aiLeaderboardDetailEffortBlurb =>
      'De combien chaque niveau d\'effort de raisonnement gagne en intelligence, et le nombre de jetons consommés pour y parvenir.';

  @override
  String get aiLeaderboardDetailIntelligenceAxis => 'Indice d\'intelligence';

  @override
  String aiLeaderboardDetailIndexOnly(String index) {
    return 'Indice $index';
  }

  @override
  String aiLeaderboardDetailIndexTokens(String index, String tokens) {
    return 'Indice $index · $tokens tok';
  }

  @override
  String aiLeaderboardDetailTokenLine(String label, String tokens) {
    return '$label : $tokens tok';
  }

  @override
  String get aiLeaderboardTableEmptyTitle => 'Pas encore de données de modèles';

  @override
  String get aiLeaderboardTableLoadFailed =>
      'Le classement n\'a pas pu être chargé. Réessaie, ou demande à l\'administrateur du serveur d\'actualiser le catalogue de modèles.';

  @override
  String get aiLeaderboardTableSignInHint =>
      'Le classement est téléchargé depuis le serveur luma. Connecte-toi à un compte approuvé pour le récupérer ; il reste ensuite en cache pour une consultation hors ligne.';

  @override
  String get aiLeaderboardTableRefreshing => 'Actualisation…';

  @override
  String get aiLeaderboardTableNoMatch =>
      'Aucun modèle ne correspond à ces filtres.';

  @override
  String get aiLeaderboardTableSearchHint => 'Rechercher des modèles';

  @override
  String get aiLeaderboardTableOpenWeights => 'Poids ouverts';

  @override
  String get aiLeaderboardTableOpenWeightsTooltip =>
      'Afficher uniquement les modèles dont tu peux télécharger les poids';

  @override
  String get aiLeaderboardTableDetailed => 'Détaillé';

  @override
  String get aiLeaderboardTableDetailedTooltip =>
      'Une ligne par modèle et par niveau d\'effort, pour que chaque niveau soit classé sur ses propres scores';

  @override
  String aiLeaderboardTableModelsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modèles',
      one: '1 modèle',
    );
    return '$_temp0';
  }

  @override
  String aiLeaderboardTableVariantsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count variantes',
      one: '1 variante',
    );
    return '$_temp0';
  }

  @override
  String aiLeaderboardTableShownOfModels(int shown, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total modèles',
      one: '1 modèle',
    );
    return '$shown sur $_temp0';
  }

  @override
  String aiLeaderboardTableShownOfVariants(int shown, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total variantes',
      one: '1 variante',
    );
    return '$shown sur $_temp0';
  }

  @override
  String get aiLeaderboardOriginNotLoaded => 'pas encore chargé';

  @override
  String get aiLeaderboardOriginCached => 'depuis ta dernière synchronisation';

  @override
  String get aiLeaderboardOriginServer => 'depuis le serveur luma';

  @override
  String aiLeaderboardFreshnessText(String time, String origin) {
    return '$time · $origin';
  }

  @override
  String aiLeaderboardFreshnessTooltip(String text) {
    return 'Données des modèles $text';
  }

  @override
  String get aiLeaderboardTableFilterProvider => 'Filtrer par fournisseur';

  @override
  String get aiLeaderboardTableAllProviders => 'Tous les fournisseurs';

  @override
  String get aiLeaderboardTableSortBy => 'Trier par';

  @override
  String aiLeaderboardTableSortedDescending(String column) {
    return '$column, trié par ordre décroissant';
  }

  @override
  String aiLeaderboardTableSortedAscending(String column) {
    return '$column, trié par ordre croissant';
  }

  @override
  String aiLeaderboardTableNotSorted(String column) {
    return '$column, non trié';
  }

  @override
  String get aiLeaderboardTableArena => 'Arène';

  @override
  String aiLeaderboardCardPricePerM(String price) {
    return '$price /M';
  }

  @override
  String aiLeaderboardCardContext(String tokens) {
    return '$tokens de contexte';
  }

  @override
  String aiLeaderboardCardParams(String params) {
    return '$params paramètres';
  }

  @override
  String get aiOsEmptyTitle => 'Pas encore de modèles à poids ouverts';

  @override
  String get aiOsEmptySubtitle =>
      'Ce calculateur dimensionne les modèles dont vous pouvez télécharger les poids. Aucun modèle du catalogue actuel n’a un nombre de paramètres connu — actualisez le classement et réessayez.';

  @override
  String get aiOsWhatCanRunIt => 'CE QUI PEUT LE FAIRE TOURNER';

  @override
  String get aiOsFootnote =>
      'La mémoire des poids est un calcul exact. Le coût du contexte est estimé à partir du nombre de paramètres — le catalogue ne donne pas le nombre de couches ni la forme de l’attention de chaque modèle, donc un modèle à conception inhabituelle s’écartera. Gardez une marge.';

  @override
  String get aiOsFieldModel => 'Modèle';

  @override
  String get aiOsFieldQuantization => 'Quantification';

  @override
  String get aiOsFieldContext => 'Contexte';

  @override
  String get aiOsKv8bit => 'KV 8 bits';

  @override
  String get aiOsKv8bitTooltip =>
      'Stocker le cache du contexte sur 8 bits au lieu de 16 — cela divise à peu près par deux le coût du contexte.';

  @override
  String get aiOsGbOfMemory => 'Go de mémoire';

  @override
  String get aiOsPartWeights => 'Poids';

  @override
  String get aiOsPartContextCache => 'Cache du contexte';

  @override
  String get aiOsPartRuntime => 'Exécution';

  @override
  String get aiOsVerdictRunsWell => 'Fonctionne bien';

  @override
  String get aiOsVerdictTightFit => 'Juste';

  @override
  String get aiOsVerdictSpills => 'Déborde en RAM';

  @override
  String get aiOsVerdictWontRun => 'Ne tourne pas';

  @override
  String get aiOsUnified => 'unifiée';

  @override
  String get aiOsUnifiedTooltip =>
      'Mémoire CPU/GPU partagée — c’est la part qu’un modèle peut réellement utiliser, et non le total de la machine.';

  @override
  String aiOsBitsPerWeight(String bits) {
    return '$bits bit';
  }

  @override
  String get aiOsQuantFp16 =>
      'Pleine précision. Le format d’origine des poids.';

  @override
  String get aiOsQuantQ8 =>
      'Presque sans perte. Le choix sûr lorsque cela tient en mémoire.';

  @override
  String get aiOsQuantQ6 => 'Très proche de Q8, nettement plus petit.';

  @override
  String get aiOsQuantQ5 => 'Légère perte de qualité, bon équilibre.';

  @override
  String get aiOsQuantQ4 =>
      'Le choix habituel. Perte de qualité réelle mais modeste.';

  @override
  String get aiOsQuantQ3 =>
      'Perte de qualité visible. Pour faire tenir un palier au-dessus.';

  @override
  String get aiOsQuantIq2 =>
      'Forte perte. Dernier recours pour que cela tienne.';

  @override
  String aiBenchmarkServerFailed(String what, int status) {
    return 'Le serveur n’a pas pu renvoyer $what (HTTP $status).';
  }

  @override
  String get aiBenchmarkWhatList => 'la liste des benchmarks';

  @override
  String get aiBenchmarkWhatScene => 'la scène de benchmark';

  @override
  String get aiBenchmarkWhatPreview => 'l’aperçu du benchmark';

  @override
  String get aiBenchmarkWhatArtwork => 'l’illustration du benchmark';

  @override
  String get aiBenchmarkMalformed => 'Réponse de benchmark mal formée.';

  @override
  String aiBenchmarkUnknownId(String id) {
    return 'Benchmark inconnu « $id ».';
  }

  @override
  String get aiBenchmarkSignInToDownload =>
      'Connectez-vous à un compte luma approuvé pour télécharger ce benchmark.';

  @override
  String get aiBenchmarkIntegrityFailed =>
      'La scène téléchargée n’a pas réussi le contrôle d’intégrité.';

  @override
  String get aiBenchmarkSelectModel => 'Choisir un modèle';

  @override
  String get aiBenchmarkViewList => 'Liste';

  @override
  String get aiBenchmarkViewBanners => 'Bannières';

  @override
  String aiBenchmarkNoMatch(String query) {
    return 'Aucun modèle ne correspond à « $query »';
  }

  @override
  String get aiBenchmarkTryShorterSearch =>
      'Essayez une recherche plus courte.';

  @override
  String get aiBenchmarkNoEntries => 'Aucun élément pour l’instant';

  @override
  String get aiBenchmarkSignInToFetch =>
      'Les modèles sont téléchargés depuis le serveur luma. Connectez-vous à un compte approuvé pour les récupérer.';

  @override
  String aiBenchmarkDownloading(String model) {
    return 'Téléchargement de $model…';
  }

  @override
  String aiBenchmarkCouldNotLoad(String model) {
    return 'Impossible de charger $model';
  }

  @override
  String get aiBenchmarkDownloadFailed => 'Le téléchargement a échoué.';

  @override
  String aiBenchmarkLoadFailedDetail(String error) {
    return '$error Les modèles sont mis en cache après le premier téléchargement, donc une nouvelle tentative suffit en général.';
  }

  @override
  String get aiBenchmarkBackToModels => 'Retour aux modèles';

  @override
  String get aiBenchmarkOpenInBrowser => 'Ouvrir dans le navigateur';

  @override
  String get aiBenchmarkCouldNotOpenBrowser =>
      'Impossible d’ouvrir un navigateur.';

  @override
  String get aiCathedralTitle => 'Test de la cathédrale';

  @override
  String get aiCathedralHeading => 'Modèle de référence';

  @override
  String get aiCathedralIntro =>
      'Une cathédrale modélisée en 3D au format .glb, un fichier par modèle. Tournez, zoomez et déplacez-vous pour l’inspecter.';

  @override
  String get aiCathedralEmptyNone =>
      'Aucun modèle de cathédrale n’a encore été ajouté.';

  @override
  String get aiCathedralUnsupportedTitle =>
      'Non disponible sur cette plateforme';

  @override
  String get aiCathedralUnsupportedBody =>
      'Le test de la cathédrale nécessite un ordinateur Windows. La prise en charge mobile et Linux arrive bientôt.';

  @override
  String get aiCruiseTitle => 'Test du paquebot';

  @override
  String get aiCruiseIntro =>
      'Explorez un paquebot vide à échelle humaine, de la promenade des canots de sauvetage aux ponts supérieurs à ciel ouvert.';

  @override
  String get aiCruiseGptDescription =>
      'MSC Virtuosa en mer : parcourez les ponts extérieurs et la promenade des canots de sauvetage du pont 7, avec cycle jour/nuit, météo et vues depuis les navettes.';

  @override
  String get aiCruiseOpusDescription =>
      'MSC Virtuosa à l’échelle réelle sur une mer WebGPU : parcourez les ponts extérieurs et la promenade des canots de sauvetage du pont 7, prenez une navette au niveau de la mer, survolez le navire en drone ou amarrez au port, avec cycle jour/nuit, nuages volumétriques, pluie, brouillard et orages.';

  @override
  String get aiCruiseWindowsOnlyTitle => 'Ordinateur Windows requis';

  @override
  String get aiCruiseWindowsOnlyBody =>
      'Le test du paquebot utilise le clavier et la souris dans l’application Windows.';

  @override
  String get aiCruiseCouldNotLoad => 'Impossible de charger ce paquebot';

  @override
  String get aiCruiseCouldNotStart => 'Impossible de démarrer le paquebot';

  @override
  String get aiCruiseTimeout => 'Le navire n’a pas fini de charger. Réessayez.';

  @override
  String get aiCruiseRendererFailed =>
      'Le moteur de rendu du paquebot n’a pas pu démarrer.';

  @override
  String get aiTestsKeyboardTitle => 'Test du clavier';

  @override
  String get aiTestsEngineTitle => 'Test du moteur';

  @override
  String get aiTestsPagodaTitle => 'Test de la pagode';

  @override
  String get aiTestsBenchmarkModelHeading => 'Modèle de benchmark';

  @override
  String get aiTestsBenchmarkSceneHeading => 'Scène de benchmark';

  @override
  String get aiTestsKeyboardIntro =>
      'Un clavier conçu comme une scène interactive, un par modèle.';

  @override
  String get aiTestsEngineIntro =>
      'V8 en coupe — un benchmark 3D temps réel d\'un moteur V8 à vilebrequin en croix, avec pistons entraînés par le vilebrequin, arbres à cames à demi-vitesse, soupapes synchronisées, effets de combustion et un benchmark FPS de 30 secondes.';

  @override
  String get aiTestsPagodaIntro =>
      'Fête du printemps à la pagode à cinq étages — un benchmark de jardin en voxels interactif avec terrain procédural, éléments animés et éclairage dynamique.';

  @override
  String get aiTestsSelectModel => 'Choisir un modèle';

  @override
  String get aiTestsListView => 'Liste';

  @override
  String get aiTestsBannersView => 'Bannières';

  @override
  String aiTestsNoModelsMatch(String query) {
    return 'Aucun modèle ne correspond à \"$query\"';
  }

  @override
  String get aiTestsTryShorterSearch => 'Essayez une recherche plus courte.';

  @override
  String get aiTestsKeyboardNoEntries => 'Aucune entrée pour l\'instant';

  @override
  String get aiTestsKeyboardNoScenes =>
      'Aucune scène de clavier n\'a encore été ajoutée.';

  @override
  String get aiTestsScenesSignInHint =>
      'Les scènes sont téléchargées depuis le serveur luma. Connectez-vous à un compte approuvé pour les récupérer.';

  @override
  String get aiTestsNoBenchmarksYet => 'Aucun benchmark pour l\'instant';

  @override
  String get aiTestsBenchmarkListFailed =>
      'La liste des benchmarks n\'a pas pu être chargée. Réessayez ou demandez à l\'administrateur du serveur d\'ajouter des scènes.';

  @override
  String get aiTestsBenchmarksSignInHint =>
      'Les benchmarks sont téléchargés depuis le serveur luma. Connectez-vous à un compte approuvé pour les récupérer.';

  @override
  String get aiTestsRefreshing => 'Actualisation…';

  @override
  String get aiTestsEngineBundledHeading => 'Moteurs intégrés';

  @override
  String get aiTestsEngineOnlineHeading => 'Benchmarks en ligne';

  @override
  String aiTestsEngineNoBundledMatch(String query) {
    return 'Aucune entrée intégrée ne correspond à \"$query\".';
  }

  @override
  String aiTestsEngineDescProcedural(String model) {
    return 'V8 à vilebrequin en croix procédural généré par $model.';
  }

  @override
  String aiTestsEngineDescStudy(String model) {
    return 'Étude interactive de moteur V8 générée par $model.';
  }

  @override
  String get aiTestsNotAvailableOnPlatform =>
      'Non disponible sur cette plateforme';

  @override
  String aiTestsNeedsWindowsDesktop(String test) {
    return '$test nécessite un ordinateur Windows. La prise en charge mobile et Linux arrive bientôt.';
  }

  @override
  String aiTestsDownloadingModel(String model) {
    return 'Téléchargement de $model…';
  }

  @override
  String aiTestsCouldNotLoadModel(String model) {
    return 'Impossible de charger $model';
  }

  @override
  String get aiTestsDownloadFailed => 'Le téléchargement a échoué.';

  @override
  String aiTestsSceneLoadFailedBody(String error) {
    return '$error Les scènes sont mises en cache après le premier téléchargement, donc un nouvel essai suffit généralement.';
  }

  @override
  String aiTestsByVendor(String vendor) {
    return 'par $vendor';
  }

  @override
  String get aiTestsPagodaDescStep5 =>
      'Benchmark de jardin en voxels StepFun Step 5 Preview';

  @override
  String get aiTestsPagodaDescIndependent =>
      'Benchmark de jardin en voxels indépendant';

  @override
  String get aiTestsPagodaDescSpaceBunny =>
      'Benchmark de jardin en voxels indépendant — île volante, cascades célestes et pagode à cinq étages';

  @override
  String get aiTestsPagodaDescSonnetXhigh =>
      'Sonnet 5.5 avec un effort de raisonnement extra-élevé — une île-jardin flottante avec une cascade et une pagode à cinq étages';

  @override
  String get aiTestsPagodaDescGptSolXhigh =>
      'GPT 6.1 Sol avec un effort de raisonnement extra-élevé — jardin en voxels de fête du printemps avec une pagode à cinq étages';

  @override
  String get aiTestsPagodaDescGptSolLow =>
      'GPT 6.1 Sol avec un effort de raisonnement faible — jardin en voxels de fête du printemps avec une pagode à cinq étages';

  @override
  String get aiTestPagodaTitle => 'Test de la pagode';

  @override
  String get aiTestEngineTitle => 'Test du moteur';

  @override
  String get aiTestPcTitle => 'Test PC';

  @override
  String get aiTestCathedralTitle => 'Test de la cathédrale';

  @override
  String get aiTestKeyboardTitle => 'Test du clavier';

  @override
  String get aiTestServerRackTitle => 'Test de baie serveur';

  @override
  String get aiTestCruiseShipTitle => 'Test du navire de croisière';

  @override
  String get aiTestWebsiteLandingTitle => 'Page d\'accueil de site web';

  @override
  String get aiTestSportsCarTitle => 'Test de voiture de sport';

  @override
  String get aiTestTrainWorldTitle => 'Test du monde ferroviaire';

  @override
  String get aiTestWorldTimelineTitle => 'Test de chronologie mondiale';

  @override
  String get aiTestFluidSimTitle => 'Test de simulation de fluides';

  @override
  String get aiTestGalaxyTitle => 'Test de galaxie';

  @override
  String get aiTestCruisePortTitle => 'Test du port de croisière';

  @override
  String get aiTestOpenScreen => 'Ouvrir l\'écran de test';

  @override
  String get aiTestNewOpenScreen => 'Nouveau · Ouvrir l\'écran de test';

  @override
  String get aiTestsBlurb =>
      'Espace de travail pour les expériences pas encore prêtes à devenir une section à part entière.';

  @override
  String get aiTestBenchmarkScene => 'Scène de benchmark';

  @override
  String get aiTestBenchmarkModel => 'Modèle de benchmark';

  @override
  String get aiTestSelectModel => 'Choisir un modèle';

  @override
  String get aiTestViewList => 'Liste';

  @override
  String get aiTestViewBanners => 'Bannières';

  @override
  String get aiTestNotAvailablePlatform =>
      'Non disponible sur cette plateforme';

  @override
  String aiTestNoMatch(String query) {
    return 'Aucun modèle ne correspond à « $query »';
  }

  @override
  String get aiTestTrySearchShorter => 'Essayez une recherche plus courte.';

  @override
  String aiTestDownloadingModel(String model) {
    return 'Téléchargement de $model…';
  }

  @override
  String aiTestCouldNotLoadModel(String model) {
    return 'Impossible de charger $model';
  }

  @override
  String aiTestLoadFailedBody(String error) {
    return '$error Les scènes sont mises en cache après le premier téléchargement, donc un nouvel essai suffit généralement.';
  }

  @override
  String get aiTestDownloadFailed => 'Le téléchargement a échoué.';

  @override
  String get aiTestPcBlurb =>
      'Explorez des PC de jeu 3D interactifs avec séquences de mise sous tension, éclairage RGB et commandes matérielles.';

  @override
  String get aiTestPcBundledDesc =>
      'HELIX 01 — une vitrine en ivoire et aluminium avec boucle liquide sur mesure, verre articulé, vue éclatée et commandes d\'alimentation/RGB.';

  @override
  String get aiTestPcPlatformBody =>
      'Le test PC nécessite un ordinateur de bureau Windows. La prise en charge mobile et Linux arrive bientôt.';

  @override
  String get aiTestPcEmptyCanRefresh =>
      'La liste des benchmarks n\'a pas pu être chargée. Réessayez ou demandez à l\'administrateur du serveur d\'ajouter des scènes.';

  @override
  String get aiTestEmptyNoAccount =>
      'Les benchmarks se téléchargent depuis le serveur luma. Connectez-vous à un compte approuvé pour les récupérer.';

  @override
  String get aiTestNoScenesYet =>
      'Aucune scène n\'a encore été ajoutée à ce test.';

  @override
  String get aiTestScenesDownloadNoAccount =>
      'Les scènes se téléchargent depuis le serveur luma. Connectez-vous à un compte approuvé pour les récupérer.';

  @override
  String aiTestScenePlatformBody(String title) {
    return '$title nécessite un ordinateur de bureau Windows. La prise en charge mobile et Linux arrive bientôt.';
  }

  @override
  String get aiTestSportsCarBlurb =>
      'Une voiture de sport originale : configurateur de studio et essai routier.';

  @override
  String get aiTestTrainWorldBlurb =>
      'Un petit chemin de fer avec trois trains tenus à distance par des signaux.';

  @override
  String get aiTestWorldTimelineBlurb =>
      'Une animation SVG du monde depuis sa formation jusqu\'à aujourd\'hui.';

  @override
  String get aiTestFluidSimBlurb =>
      'De l\'eau 3D en temps réel dans un aquarium en verre que vous pouvez remuer et incliner.';

  @override
  String get aiTestGalaxyBlurb =>
      'Un voyage spatial à travers une galaxie spirale générée de manière procédurale.';

  @override
  String get aiTestCruisePortBlurb =>
      'Un paquebot amarré à Lisbonne, sous l\'Alfama.';

  @override
  String get aiTestWebsiteLandingBlurb =>
      'Une page d\'accueil responsive pour un café, avec des interactions fonctionnelles.';

  @override
  String get aiTestServerRackBlurb =>
      'Une baie 42U complète et une vue d\'un seul serveur : l\'architecture macro de la disposition des machines dans une baie, et l\'architecture micro du matériel d\'un châssis.';

  @override
  String get aiTestRackPlatformBody =>
      'Le test de baie serveur nécessite un ordinateur de bureau Windows.';

  @override
  String get aiTestRackSonnetLowDesc =>
      'Baie 42U complète et inspection d\'un seul serveur par Sonnet 5.5 Low.';

  @override
  String get aiTestRackSonnetXhighDesc =>
      'Une baie 42U de neuf serveurs inspectables ; chacun glisse sur ses rails vers une vue ouverte d\'un seul serveur, avec modes éclaté, coupe et flux d\'air.';

  @override
  String get aiTestRackSonnetHighDesc =>
      'Une baie 42U aux unités étiquetées qui s\'ouvre sur une vue détaillée de chaque serveur, avec simulation du flux d\'air.';

  @override
  String get aiTestRackOpusLowDesc =>
      'Une baie 42U câblée de neuf serveurs répartis en cinq archétypes ; chacun glisse en une lame à châssis ouvert, avec vues éclatée, coupée et de flux d\'air tenant compte des obstacles.';

  @override
  String get aiTestRackOpusXhighDesc =>
      'Une baie 42U câblée et à budget électrique, avec neuf serveurs aux neuf agencements différents ; chacun se déverrouille, glisse sur ses rails et s\'ouvre en lame survolable, avec vues éclatée, coupée et de flux d\'air résolu.';

  @override
  String get aiTestRackMuseDesc =>
      'RACKSCOPE·42U : une baie câblée avec un navigateur d\'unités et une vue inspectable d\'un seul serveur.';

  @override
  String get airlineBuildingApronName => 'Aire de trafic';

  @override
  String get airlineBuildingApronBlurb =>
      'Aire de stationnement et de roulage revêtue. Les hangars et dépôts de carburant fonctionnent mieux à proximité.';

  @override
  String get airlineBuildingGateName => 'Porte';

  @override
  String get airlineBuildingGateBlurb =>
      'Un poste de stationnement pour une ligne. Ne fonctionne que s\'il touche un terminal.';

  @override
  String get airlineBuildingTerminalName => 'Aérogare';

  @override
  String get airlineBuildingTerminalBlurb =>
      'Bâtiment passagers. Les portes doivent le toucher pour être utilisables.';

  @override
  String get airlineBuildingRunwayShortName => 'Piste courte';

  @override
  String get airlineBuildingRunwayShortBlurb =>
      '1 800 m. Réservée aux turbopropulseurs et petits avions régionaux.';

  @override
  String get airlineBuildingRunwayMediumName => 'Piste moyenne';

  @override
  String get airlineBuildingRunwayMediumBlurb =>
      '2 600 m. Ouvre la voie aux monocouloirs et aux plus petits gros-porteurs.';

  @override
  String get airlineBuildingRunwayLongName => 'Piste longue';

  @override
  String get airlineBuildingRunwayLongBlurb =>
      '3 400 m. Tout jusqu\'à l\'A380 peut l\'utiliser.';

  @override
  String get airlineBuildingHangarName => 'Hangar';

  @override
  String get airlineBuildingHangarBlurb =>
      'Réduit la maintenance. Plus utile lorsqu\'il donne sur l\'aire de trafic.';

  @override
  String get airlineBuildingFuelDepotName => 'Dépôt de carburant';

  @override
  String get airlineBuildingFuelDepotBlurb =>
      'Achète le carburant en gros. Plus utile lorsqu\'il donne sur l\'aire de trafic.';

  @override
  String get airlineBuildingCargoName => 'Terminal cargo';

  @override
  String get airlineBuildingCargoBlurb =>
      'Vend l\'espace de soute sous la cabine sur chaque vol.';

  @override
  String get airlineBuildingLoungeName => 'Salon';

  @override
  String get airlineBuildingLoungeBlurb =>
      'Tarifs premium sur long-courrier. Doit toucher un terminal.';

  @override
  String get airlineSlotAnyTime => 'à tout moment';

  @override
  String get airlineErrRestoreBalance =>
      'Rétablissez un solde positif avant d\'acquérir des avions.';

  @override
  String get airlineErrNotEnoughCashAircraft =>
      'Pas assez d\'argent pour cet avion.';

  @override
  String get airlineErrLeaseWeek =>
      'Il vous faut d\'abord au moins une semaine de loyers en banque.';

  @override
  String get airlineErrCancelFlightsFirst =>
      'Annulez les vols programmés et attendez le retour de cet avion avant de le rendre.';

  @override
  String get airlineErrNoSuchAircraft => 'Cet avion n\'existe pas.';

  @override
  String get airlineErrRouteUnavailable => 'Cette ligne n\'est pas disponible.';

  @override
  String airlineErrOutOfRange(
    String model,
    String city,
    String km,
    String rangeKm,
  ) {
    return '$model ne peut pas atteindre $city — $km km pour une autonomie de $rangeKm km.';
  }

  @override
  String airlineErrRunwayTooShort(String model, String needM, String longestM) {
    return '$model a besoin de $needM m de piste ; votre plus longue fait $longestM m.';
  }

  @override
  String get airlineErrUnknownDestination => 'Destination inconnue.';

  @override
  String get airlineErrOwnHub => 'C\'est votre propre hub.';

  @override
  String airlineErrAlreadyFly(String city) {
    return 'Vous desservez déjà $city.';
  }

  @override
  String airlineErrGatesTaken(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count portes',
      one: '1 porte',
    );
    return 'Toutes les portes utilisables sont occupées. Vous avez $_temp0 qui ne touche pas de terminal — rapprochez-les d\'un terminal pour les utiliser.';
  }

  @override
  String get airlineErrNeedGate =>
      'Il vous faut une autre porte à côté d\'un terminal pour ajouter une ligne.';

  @override
  String get airlineErrNotEnoughCashLaunch =>
      'Pas assez d\'argent pour lancer la ligne.';

  @override
  String get airlineErrDoesNotFit => 'Cela ne rentre pas sur le terrain.';

  @override
  String get airlineErrAlreadyBuilt => 'Il y a déjà une construction ici.';

  @override
  String airlineErrCannotAffordBuilding(String name) {
    return 'Pas assez d\'argent pour $name.';
  }

  @override
  String get airlineErrNothingToDemolish => 'Rien à démolir ici.';

  @override
  String get airlineErrFieldAtLimit => 'Le terrain a déjà atteint sa limite.';

  @override
  String get airlineErrNotEnoughCashLand =>
      'Pas assez d\'argent pour acheter plus de terrain.';

  @override
  String get airlineErrSaveUnreadable =>
      'Impossible de lire la sauvegarde de l\'aéroport. Le fichier d\'origine a été conservé.';

  @override
  String get airlineErrSaveStorageUnavailable =>
      'Le stockage de la sauvegarde de l\'aéroport est indisponible.';

  @override
  String get airlineErrSaveFailed =>
      'Impossible d\'enregistrer cet aéroport. La progression est encore en mémoire ; vérifiez l\'espace de stockage disponible.';

  @override
  String airlineEventAdvanced(String minutes) {
    return 'Les opérations de l\'aéroport ont avancé de $minutes minutes de jeu.';
  }

  @override
  String airlineEventHeavyCheck(String registration, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours',
      one: '1 jour',
    );
    return '$registration est entré en visite lourde ($_temp0).';
  }

  @override
  String get airlineErrStartAirportFirst => 'Créez d\'abord un aéroport.';

  @override
  String get airlineErrSelectBuildingFirst =>
      'Sélectionnez d\'abord un bâtiment.';

  @override
  String get airlineErrCatalogUnavailable =>
      'Le catalogue des aéroports est indisponible.';

  @override
  String get airlineErrChooseSpeed => 'Choisissez 1×, 4× ou 12×.';

  @override
  String get airlineErrUnknownCommand => 'Commande d\'aéroport inconnue.';

  @override
  String get airlineErrInvalidCommand => 'Commande d\'aéroport invalide.';

  @override
  String get airlineErrNoPanel => 'Ce panneau n\'existe pas.';

  @override
  String get airlineTabFleet => 'Flotte';

  @override
  String get airlineTabRoutes => 'Lignes';

  @override
  String get airlineTabHub => 'Hub';

  @override
  String get airlineTabFinances => 'Finances';

  @override
  String get airlinePause => 'Pause';

  @override
  String get airlineResume => 'Reprendre';

  @override
  String airlineDaySemantics(int day) {
    return 'Jour $day';
  }

  @override
  String airlineSpeedSemantics(int speed) {
    return 'Vitesse ${speed}x';
  }

  @override
  String get airlineTakeOff => 'Décoller';

  @override
  String get airlineChooseHubToContinue => 'Choisissez un hub pour continuer.';

  @override
  String get airlineStartAirlineTitle => 'Créer une compagnie aérienne';

  @override
  String get airlinePickHubBlurb =>
      'Choisissez un aéroport de base. Tous vos vols partiront de là, et c\'est le terrain que vous développerez.';

  @override
  String get airlineNameLabel => 'Nom de la compagnie';

  @override
  String get airlineHomeHubLabel => 'Hub de base';

  @override
  String airlineHubOptionDetail(String name, String runway, String country) {
    return '$name · piste de $runway m · $country';
  }

  @override
  String get airlineBackToAirport => 'Retour à l\'aéroport';

  @override
  String get airlineRoutesEstimateNote =>
      'Les estimations de lignes supposent une utilisation des avions sur toute la journée. Les revenus de l\'aéroport viennent des vols que vous programmez.';

  @override
  String get airlineSceneStartFailedWindows =>
      'L\'aéroport n\'a pas démarré. Vérifiez que Microsoft Edge WebView2 Runtime est installé, puis réessayez.';

  @override
  String get airlineSceneStartFailedAndroid =>
      'L\'aéroport n\'a pas démarré. Mettez à jour Android System WebView, puis réessayez.';

  @override
  String get airlineSceneConnectionLost =>
      'Connexion à l\'aéroport interrompue. Réessayez pour vous reconnecter.';

  @override
  String get airlineSceneWebglFailed => 'WebGL n\'a pas pu être initialisé.';

  @override
  String airlineSceneLoadFailed(String error) {
    return 'Impossible de charger l\'aéroport intégré : $error';
  }

  @override
  String get airlineReloadAirport => 'Recharger l\'aéroport';

  @override
  String get airlineAwayTitle => 'Pendant votre absence';

  @override
  String airlineAwayDuration(String duration, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '1 jour',
    );
    return '$duration d\'absence · $_temp0 de vol';
  }

  @override
  String get airlineAwayEarned => 'gagnés';

  @override
  String get airlineAwayLost => 'perdus';

  @override
  String get airlineAwayIncome => 'Revenus';

  @override
  String get airlineAwayCosts => 'Coûts';

  @override
  String get airlineAwayPassengers => 'Passagers';

  @override
  String get airlineAwayOfflineRate => 'Taux hors ligne';

  @override
  String airlineAwayCapped(int elapsed, int maxDays) {
    String _temp0 = intl.Intl.pluralLogic(
      elapsed,
      locale: localeName,
      other: '$elapsed jours se sont écoulés',
      one: '1 jour s\'est écoulé',
    );
    return '$_temp0, mais une absence ne rapporte que pour $maxDays jours au maximum. Le reste n\'a pas été volé.';
  }

  @override
  String get airlineBackToWork => 'Retour au travail';

  @override
  String get airlineLabelDay => 'Jour';

  @override
  String get airlineLabelSeats => 'Sièges';

  @override
  String get airlineLabelRange => 'Autonomie';

  @override
  String get airlineLabelHours => 'Heures';

  @override
  String get airlineLabelLease => 'Location';

  @override
  String get airlineLabelResale => 'Valeur de revente';

  @override
  String get airlineLabelCruise => 'Vitesse de croisière';

  @override
  String get airlineLabelRunway => 'Piste';

  @override
  String get airlineLabelAircraft => 'Avions';

  @override
  String get airlineLabelRoutes => 'Routes';

  @override
  String get airlineLabelDistance => 'Distance';

  @override
  String get airlineLabelDailyDemand => 'Demande quotidienne';

  @override
  String get airlineLabelFairFare => 'Tarif juste';

  @override
  String get airlineLabelRunwayThere => 'Piste à destination';

  @override
  String get airlineLabelType => 'Type';

  @override
  String get airlineLabelMaintenance => 'Maintenance';

  @override
  String get airlineLabelFuel => 'Carburant';

  @override
  String get airlineLabelUpkeep => 'Entretien';

  @override
  String airlineFactPerDay(String amount) {
    return '$amount/jour';
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
  String get airlineRunwayNone => 'aucune';

  @override
  String get airlineFinCash => 'Trésorerie';

  @override
  String get airlineFinChartEmpty =>
      'Gérez l\'entreprise quelques jours et le graphique du solde apparaîtra ici.';

  @override
  String get airlineFinSoFar => 'La compagnie jusqu\'ici';

  @override
  String airlineFinDayHeading(String day) {
    return 'Jour $day';
  }

  @override
  String get airlineFinStatFlightsFlown => 'Vols effectués';

  @override
  String get airlineFinStatPassengers => 'Passagers transportés';

  @override
  String get airlineFinStatFuelPrice => 'Prix du carburant';

  @override
  String get airlineFinLineTickets => 'Billets';

  @override
  String get airlineFinLineCargo => 'Fret';

  @override
  String get airlineFinLineCrew => 'Équipage';

  @override
  String get airlineFinLineAirportFees => 'Redevances aéroportuaires';

  @override
  String get airlineFinLineHubUpkeep => 'Entretien du hub';

  @override
  String get airlineFinLineLeasePayments => 'Paiements de location';

  @override
  String airlineFinDaySummary(String flights, String passengers) {
    return '$flights vols · $passengers passagers';
  }

  @override
  String get airlineFinFieldTitle => 'Le terrain';

  @override
  String airlineFinLandAtMax(String size) {
    return 'Votre terrain fait $size sur $size — le plus grand que l\'autorité aéroportuaire puisse vous vendre.';
  }

  @override
  String airlineFinLandGrow(String size) {
    return 'Votre terrain fait $size sur $size. En acheter davantage vous laisse la place pour un terminal de plus et les portes qui vont avec.';
  }

  @override
  String get airlineFinAtLimit => 'À la limite';

  @override
  String airlineFinBuyLand(String price) {
    return 'Acheter du terrain · $price';
  }

  @override
  String airlineFleetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count avions',
      one: '1 avion',
      zero: 'Aucun avion',
    );
    return '$_temp0';
  }

  @override
  String get airlineFleetAcquire => 'Acquérir';

  @override
  String get airlineFleetEmptyTitle => 'Votre hangar est vide';

  @override
  String get airlineFleetEmptySubtitle =>
      'Achetez ou louez un avion pour commencer à voler.';

  @override
  String get airlineFleetBrowse => 'Parcourir les avions';

  @override
  String airlineFleetInCheck(String days) {
    return 'En révision · ${days}j';
  }

  @override
  String airlineFleetDetail(String registration, String maker) {
    return '$registration · $maker';
  }

  @override
  String airlineFleetDetailLeased(String registration, String maker) {
    return '$registration · $maker · en location';
  }

  @override
  String get airlineFleetReturnTitle => 'Rendre cet avion ?';

  @override
  String get airlineFleetSellTitle => 'Vendre cet avion ?';

  @override
  String airlineFleetReturnBody(String registration) {
    return '$registration retourne au bailleur. Le paiement quotidien s\'arrête.';
  }

  @override
  String airlineFleetSellBody(String registration, String value, String price) {
    return '$registration se vend $value, bien en dessous des $price qu\'il a coûté.';
  }

  @override
  String get airlineFleetKeepIt => 'Garder';

  @override
  String get airlineFleetReturn => 'Rendre';

  @override
  String get airlineFleetSell => 'Vendre';

  @override
  String get airlineFleetOpenRouteFirst => 'Ouvrez d\'abord une route';

  @override
  String get airlineFleetUnassigned => 'Non affecté';

  @override
  String get airlineMarketTitle => 'Marché des avions';

  @override
  String airlineMarketJoinedFleet(String name) {
    return '$name a rejoint la flotte.';
  }

  @override
  String airlineMarketNeedsRunway(String needed, String longest) {
    return 'Nécessite $needed de piste ; votre plus longue fait $longest. Vous pouvez tout de même l\'acheter et agrandir la piste.';
  }

  @override
  String get airlineMarketLease => 'Louer';

  @override
  String get airlineMarketBuy => 'Acheter';

  @override
  String get airlineRoutesEmptyTitle => 'Pas encore de routes';

  @override
  String get airlineRoutesEmptySubtitle =>
      'Touchez un aéroport sur la carte pour ouvrir votre première route.';

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
      other: '$gates portes',
      one: '1 porte',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get airlineRoutesNoUsableAircraft =>
      'Aucun appareil du catalogue ne peut assurer cette liaison depuis votre hub pour l\'instant : il vous faut une piste plus longue, ou ce trajet dépasse tous les avions que vous pouvez acheter.';

  @override
  String airlineRoutesCanBeFlownBy(String names) {
    return 'Peut être assuré par : $names.';
  }

  @override
  String airlineRoutesCanBeFlownByMore(String names, String more) {
    return 'Peut être assuré par : $names et $more autres.';
  }

  @override
  String airlineRoutesOpenRoute(String price) {
    return 'Ouvrir la route · $price';
  }

  @override
  String airlineRoutesPax(String count) {
    return '$count pax';
  }

  @override
  String get airlineRoutesNoAircraft => 'aucun avion';

  @override
  String airlineRoutesAssigned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count affectés',
      one: '1 affecté',
    );
    return '$_temp0';
  }

  @override
  String get airlineRoutesFare => 'Tarif';

  @override
  String get airlineRoutesCabinFilled => 'Cabine remplie';

  @override
  String get airlineRoutesNoAircraftAssigned => 'Aucun avion affecté';

  @override
  String get airlineRoutesProjectedToday => 'Prévision du jour';

  @override
  String get airlineRoutesAssignInFleet => 'Affectez-en un dans la flotte';

  @override
  String airlineRoutesProjection(String profit, String pax) {
    return '$profit · $pax pax';
  }

  @override
  String get airlineRoutesCloseRoute => 'Fermer cette route';

  @override
  String get airlineHubFailed => 'Cela n\'a pas fonctionné.';

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
    return '$name, $price, trop cher';
  }

  @override
  String get airlineHubRotate => 'Pivoter';

  @override
  String get airlineHubDemolish => 'Démolir';

  @override
  String get airlineHubGates => 'Portes';

  @override
  String get airlineHubNotOnTerminal => 'Pas relié à un terminal';

  @override
  String get calcNothingToWorkOut => 'Rien à calculer pour l\'instant.';

  @override
  String get calcUndefined => 'Indéfini';

  @override
  String calcNotANumber(String text) {
    return '\"$text\" n\'est pas un nombre.';
  }

  @override
  String calcUnknownCharacter(String character) {
    return 'Je ne comprends pas \"$character\".';
  }

  @override
  String calcUnknownName(String name) {
    return 'Je ne connais pas \"$name\".';
  }

  @override
  String calcUnexpectedToken(String token) {
    return '\"$token\" n\'est pas à sa place.';
  }

  @override
  String get calcStopsTooEarly => 'L\'expression s\'arrête trop tôt.';

  @override
  String get calcBracketLeftOpen => 'Une parenthèse est restée ouverte.';

  @override
  String calcExpectedSymbol(String symbol) {
    return '\"$symbol\" attendu.';
  }

  @override
  String calcArgCountExact(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valeurs',
      one: '1 valeur',
    );
    return '$name nécessite $_temp0.';
  }

  @override
  String calcArgCountRange(String name, int minCount, int maxCount) {
    return '$name nécessite de $minCount à $maxCount valeurs.';
  }

  @override
  String get calcFactorialWholeNumbers =>
      'La factorielle ne fonctionne que sur des entiers à partir de 0.';

  @override
  String get calcCombinatoricsWholeNumbers =>
      'nCr et nPr nécessitent des entiers à partir de 0.';

  @override
  String get audioToolsInvalidSnapshot =>
      'Instantané des outils audio invalide.';

  @override
  String get autoClickerPressNewHotkey => 'Appuyez sur un nouveau raccourci';

  @override
  String get autoClickerWindowsOnlyBody =>
      'Auto Clicker simule de vrais clics de souris, ce que luma ne peut faire que dans l\'application de bureau Windows.';

  @override
  String get autoClickerClicking => 'Clics en cours…';

  @override
  String get autoClickerStopped => 'Arrêté';

  @override
  String autoClickerClicksSoFar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clics',
      one: '1 clic',
    );
    return '$_temp0 jusqu\'ici';
  }

  @override
  String autoClickerStartHint(String hotkey) {
    return 'Démarrez-le, ou appuyez sur $hotkey depuis n\'importe où';
  }

  @override
  String get autoClickerStopClicking => 'Arrêter les clics';

  @override
  String get autoClickerStartClicking => 'Démarrer les clics';

  @override
  String get autoClickerPickFixedFirst =>
      'Choisissez d\'abord un emplacement fixe ci-dessous avant de démarrer.';

  @override
  String get autoClickerRandomHelpExact =>
      'Ajoute une variation ± au délai de chaque clic. Laissez 0 pour un timing exact.';

  @override
  String autoClickerRandomHelpRange(String low, String high) {
    return 'Chaque clic se déclenche entre $low et $high ms (au minimum 1 ms).';
  }

  @override
  String get autoClickerClickEvery => 'Cliquer toutes les';

  @override
  String get autoClickerHours => 'Heures';

  @override
  String get autoClickerMinutes => 'Minutes';

  @override
  String get autoClickerSeconds => 'Secondes';

  @override
  String get autoClickerMillis => 'Ms';

  @override
  String get autoClickerRandomOffset => 'Décalage aléatoire';

  @override
  String get autoClickerMilliseconds => 'millisecondes';

  @override
  String get autoClickerMouseButton => 'Bouton de la souris';

  @override
  String get autoClickerLeft => 'Gauche';

  @override
  String get autoClickerMiddle => 'Milieu';

  @override
  String get autoClickerRight => 'Droit';

  @override
  String get autoClickerClickType => 'Type de clic';

  @override
  String get autoClickerSingle => 'Simple';

  @override
  String get autoClickerDouble => 'Double';

  @override
  String get autoClickerClickLocation => 'Emplacement du clic';

  @override
  String get autoClickerCurrentCursor => 'Curseur actuel';

  @override
  String get autoClickerFixedPosition => 'Position fixe';

  @override
  String autoClickerHoldCursor(int countdown) {
    return 'Placez votre curseur sur la cible… $countdown';
  }

  @override
  String autoClickerTarget(String x, String y) {
    return 'Cible : $x, $y';
  }

  @override
  String get autoClickerNoPositionYet =>
      'Aucune position définie pour l\'instant';

  @override
  String get autoClickerPicking => 'Sélection…';

  @override
  String get autoClickerPickLocation => 'Choisir l\'emplacement';

  @override
  String get autoClickerRepeat => 'Répéter';

  @override
  String get autoClickerUntilStopped => 'Jusqu\'à l\'arrêt';

  @override
  String get autoClickerSetAmount => 'Nombre défini';

  @override
  String get autoClickerClicksTotal => 'clics au total';

  @override
  String get autoClickerHotkeyLabel => 'Raccourci démarrer/arrêter';

  @override
  String get autoClickerChange => 'Modifier';

  @override
  String get autoClickerHotKeyRegisterFailed =>
      'Impossible d\'enregistrer le raccourci global — une autre application l\'utilise peut-être déjà.';

  @override
  String get autoClickerInvalidSnapshot =>
      'Instantané de l\'auto-clic invalide.';

  @override
  String get bulletinBoardNewNote => 'Nouvelle note';

  @override
  String get bulletinBoardNewChecklist => 'Nouvelle liste de contrôle';

  @override
  String bulletinBoardChecklistItem(String number) {
    return 'Élément $number';
  }

  @override
  String get bulletinBoardNote => 'Note';

  @override
  String get bulletinBoardIdea => 'Idée';

  @override
  String get bulletinBoardChecklist => 'Liste de contrôle';

  @override
  String get bulletinBoardImage => 'Image';

  @override
  String get bulletinBoardNoteContentHint => 'Contenu de la note...';

  @override
  String get bulletinBoardQuickIdeaHint => 'Idée rapide...';

  @override
  String get bulletinBoardAddItem => '+ Ajouter un élément';

  @override
  String get bulletinBoardNoImage => 'Aucune image';

  @override
  String get bulletinBoardImageNotFound => 'Image introuvable';

  @override
  String get calcErrorHasX =>
      'Il y a un x dedans — appuyez sur Tracer pour le dessiner.';

  @override
  String get calcPlotNeedsExpression =>
      'Saisissez d\'abord quelque chose comme x^2 - 3.';

  @override
  String get calcStorageFullFunctionNotSaved =>
      'Le stockage local est plein, donc cette fonction n\'a pas été enregistrée.';

  @override
  String get calcConvertUnitsTooltip => 'Convertir les unités';

  @override
  String get calcModeBasic => 'Basique';

  @override
  String get calcModeAdvanced => 'Avancé';

  @override
  String get calcSwitchToRadians => 'Passer en radians';

  @override
  String get calcSwitchToDegrees => 'Passer en degrés';

  @override
  String get calcKeypadTab => 'Clavier';

  @override
  String get calcGraphTab => 'Graphique';

  @override
  String calcPlotAs(String expression) {
    return 'Tracer comme y = $expression';
  }

  @override
  String get calcHistoryEmpty =>
      'Les calculs que vous effectuez apparaissent ici.';

  @override
  String get calcFunctionsTitle => 'Fonctions';

  @override
  String get calcNothingPlotted =>
      'Rien n\'est encore tracé. Saisissez quelque chose avec un x — comme x^2 - 3 ou sin(x) — puis appuyez sur Tracer.';

  @override
  String get calcFunctionHide => 'Masquer';

  @override
  String get calcFunctionShow => 'Afficher';

  @override
  String get calcClearTrace => 'Effacer la trace';

  @override
  String get calcResetView => 'Réinitialiser la vue';

  @override
  String get calcPlotFunctionTitle => 'Tracer une fonction';

  @override
  String get calcEditFunctionTitle => 'Modifier la fonction';

  @override
  String get calcFunctionEmpty => 'Saisissez d\'abord une fonction de x.';

  @override
  String get calcStorageFullNotSaved =>
      'Le stockage local est plein, donc ceci n\'a pas été enregistré.';

  @override
  String get calcFunctionColour => 'Couleur';

  @override
  String get calcPlot => 'Tracer';

  @override
  String get calcConvertFrom => 'De';

  @override
  String get calcConvertTo => 'À';

  @override
  String get calcConvertEveryUnit => 'Toutes les unités';

  @override
  String get calcConvertSwapUnits => 'Inverser les unités';

  @override
  String get calcConvertUseInCalculator => 'Utiliser dans la calculatrice';

  @override
  String get calcInvalidSnapshot => 'Instantané de calculatrice non valide.';

  @override
  String get calcCategoryLength => 'Longueur';

  @override
  String get calcCategoryWeight => 'Masse';

  @override
  String get calcCategoryTemperature => 'Température';

  @override
  String get calcCategorySpeed => 'Vitesse';

  @override
  String get calcCategoryArea => 'Superficie';

  @override
  String get calcCategoryVolume => 'Volume';

  @override
  String get calcCategoryTime => 'Temps';

  @override
  String get calcCategoryData => 'Données';

  @override
  String get calcCategoryPressure => 'Pression';

  @override
  String get calcCategoryEnergy => 'Énergie';

  @override
  String get calcCategoryAngle => 'Angle';

  @override
  String get calcUnitKilometre => 'Kilomètre';

  @override
  String get calcUnitMetre => 'Mètre';

  @override
  String get calcUnitCentimetre => 'Centimètre';

  @override
  String get calcUnitMillimetre => 'Millimètre';

  @override
  String get calcUnitMile => 'Mile';

  @override
  String get calcUnitYard => 'Yard';

  @override
  String get calcUnitFoot => 'Pied';

  @override
  String get calcUnitInch => 'Pouce';

  @override
  String get calcUnitNauticalMile => 'Mille nautique';

  @override
  String get calcUnitTonne => 'Tonne';

  @override
  String get calcUnitKilogram => 'Kilogramme';

  @override
  String get calcUnitGram => 'Gramme';

  @override
  String get calcUnitMilligram => 'Milligramme';

  @override
  String get calcUnitPound => 'Livre';

  @override
  String get calcUnitOunce => 'Once';

  @override
  String get calcUnitStone => 'Stone';

  @override
  String get calcUnitCelsius => 'Celsius';

  @override
  String get calcUnitFahrenheit => 'Fahrenheit';

  @override
  String get calcUnitKelvin => 'Kelvin';

  @override
  String get calcUnitKilometresPerHour => 'Kilomètres par heure';

  @override
  String get calcUnitMetresPerSecond => 'Mètres par seconde';

  @override
  String get calcUnitMilesPerHour => 'Miles par heure';

  @override
  String get calcUnitKnot => 'Nœud';

  @override
  String get calcUnitFeetPerSecond => 'Pieds par seconde';

  @override
  String get calcUnitSquareKilometre => 'Kilomètre carré';

  @override
  String get calcUnitHectare => 'Hectare';

  @override
  String get calcUnitSquareMetre => 'Mètre carré';

  @override
  String get calcUnitSquareCentimetre => 'Centimètre carré';

  @override
  String get calcUnitSquareMile => 'Mile carré';

  @override
  String get calcUnitAcre => 'Acre';

  @override
  String get calcUnitSquareYard => 'Yard carré';

  @override
  String get calcUnitSquareFoot => 'Pied carré';

  @override
  String get calcUnitCubicMetre => 'Mètre cube';

  @override
  String get calcUnitLitre => 'Litre';

  @override
  String get calcUnitMillilitre => 'Millilitre';

  @override
  String get calcUnitGallonUs => 'Gallon (US)';

  @override
  String get calcUnitGallonUk => 'Gallon (R.-U.)';

  @override
  String get calcUnitQuartUs => 'Quart (US)';

  @override
  String get calcUnitPintUs => 'Pinte (US)';

  @override
  String get calcUnitCupUs => 'Tasse (US)';

  @override
  String get calcUnitFluidOunceUs => 'Once liquide (US)';

  @override
  String get calcUnitTablespoonUs => 'Cuillère à soupe (US)';

  @override
  String get calcUnitTeaspoonUs => 'Cuillère à café (US)';

  @override
  String get calcUnitMillisecond => 'Milliseconde';

  @override
  String get calcUnitSecond => 'Seconde';

  @override
  String get calcUnitMinute => 'Minute';

  @override
  String get calcUnitHour => 'Heure';

  @override
  String get calcUnitDay => 'Jour';

  @override
  String get calcUnitWeek => 'Semaine';

  @override
  String get calcUnitMonth30Days => 'Mois (30 jours)';

  @override
  String get calcUnitYear365Days => 'Année (365 jours)';

  @override
  String get calcUnitBit => 'Bit';

  @override
  String get calcUnitByte => 'Octet';

  @override
  String get calcUnitKilobyte => 'Kilo-octet';

  @override
  String get calcUnitMegabyte => 'Mégaoctet';

  @override
  String get calcUnitGigabyte => 'Gigaoctet';

  @override
  String get calcUnitTerabyte => 'Téraoctet';

  @override
  String get calcUnitKibibyte => 'Kibioctet';

  @override
  String get calcUnitMebibyte => 'Mébioctet';

  @override
  String get calcUnitGibibyte => 'Gibioctet';

  @override
  String get calcUnitTebibyte => 'Tébioctet';

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
  String get calcUnitAtmosphere => 'Atmosphère';

  @override
  String get calcUnitPoundPerSquareInch => 'Livre par pouce carré';

  @override
  String get calcUnitMillimetreOfMercury => 'Millimètre de mercure';

  @override
  String get calcUnitJoule => 'Joule';

  @override
  String get calcUnitKilojoule => 'Kilojoule';

  @override
  String get calcUnitCalorie => 'Calorie';

  @override
  String get calcUnitKilocalorie => 'Kilocalorie';

  @override
  String get calcUnitWattHour => 'Wattheure';

  @override
  String get calcUnitKilowattHour => 'Kilowattheure';

  @override
  String get calcUnitBritishThermalUnit => 'Unité thermique britannique';

  @override
  String get calcUnitDegree => 'Degré';

  @override
  String get calcUnitRadian => 'Radian';

  @override
  String get calcUnitGradian => 'Grade';

  @override
  String get calcUnitTurn => 'Tour';

  @override
  String get calcUnitArcminute => 'Minute d\'arc';

  @override
  String get calcUnitArcsecond => 'Seconde d\'arc';

  @override
  String get calendarRepeatNone => 'Ne se répète pas';

  @override
  String get calendarRepeatDaily => 'Tous les jours';

  @override
  String get calendarRepeatWeekly => 'Chaque semaine';

  @override
  String get calendarRepeatMonthly => 'Chaque mois';

  @override
  String get calendarRepeatYearly => 'Chaque année';

  @override
  String get calendarViewDay => 'Jour';

  @override
  String get calendarViewWeek => 'Semaine';

  @override
  String get calendarViewMonth => 'Mois';

  @override
  String get calendarViewAgenda => 'Agenda';

  @override
  String get calendarNewEvent => 'Nouvel événement';

  @override
  String get calendarAddEvent => 'Ajouter un événement';

  @override
  String get calendarSearchHint => 'Rechercher des événements';

  @override
  String calendarMoreCount(int count) {
    return '+$count de plus';
  }

  @override
  String calendarEventCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count événements',
      one: '1 événement',
      zero: 'Aucun événement',
    );
    return '$_temp0';
  }

  @override
  String get calendarEmptyDayTitle => 'Journée vide';

  @override
  String get calendarEmptyDaySubtitle =>
      'Ajoutez quelque chose d’agréable ici.';

  @override
  String get calendarSetDinnerForDay => 'Définir le dîner de ce jour';

  @override
  String get calendarDinnerLabel => 'Dîner';

  @override
  String get calendarAllDay => 'Toute la journée';

  @override
  String get calendarAllDayStrip => 'toute la journée';

  @override
  String calendarAllDayDays(int count) {
    return 'Toute la journée · $count jours';
  }

  @override
  String get calendarReminderAtStart => 'Au début';

  @override
  String calendarReminderDaysBefore(int count) {
    return '$count j avant';
  }

  @override
  String calendarReminderHoursBefore(int count) {
    return '$count h avant';
  }

  @override
  String calendarReminderMinutesShort(int count) {
    return '$count min avant';
  }

  @override
  String get calendarNothingComingUp => 'Rien à venir';

  @override
  String get calendarAgendaEmptySubtitle =>
      'Ce que vous prévoyez apparaît ici.';

  @override
  String calendarNoEventsMatch(String query) {
    return 'Aucun événement pour « $query »';
  }

  @override
  String get calendarSearchEmptySubtitle =>
      'Essayez un autre titre, lieu ou note.';

  @override
  String calendarSearchResultCount(int count, String query) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count résultats pour « $query »',
      one: '1 résultat pour « $query »',
    );
    return '$_temp0';
  }

  @override
  String get calendarEditEvent => 'Modifier l’événement';

  @override
  String get calendarEventTitleHint => 'Titre de l’événement';

  @override
  String get calendarStarts => 'Début';

  @override
  String get calendarEnds => 'Fin';

  @override
  String get calendarRepeat => 'Répéter';

  @override
  String get calendarLocation => 'Lieu';

  @override
  String get calendarReminder => 'Rappel';

  @override
  String get calendarAddPlace => 'Ajouter un lieu';

  @override
  String get calendarAddDetails => 'Ajouter des détails';

  @override
  String calendarSharedByView(String author) {
    return 'Partagé par $author — lecture seule';
  }

  @override
  String get calendarFamilyMemberFallback => 'un membre de la famille';

  @override
  String get calendarShareJustMe => 'Moi seul';

  @override
  String get calendarShareWholeFamily => 'Toute la famille';

  @override
  String get calendarShareChoosePeople => 'Choisir des personnes';

  @override
  String get calendarNoOtherMembers =>
      'Aucun autre membre de la famille pour l’instant.';

  @override
  String get calendarGiveTitle => 'Donnez un titre à l’événement.';

  @override
  String get calendarChooseShareOne =>
      'Choisissez au moins une personne avec qui partager.';

  @override
  String get calendarDeleteEvent => 'Supprimer l’événement';

  @override
  String get calendarRepeatsForever => 'Se répète indéfiniment';

  @override
  String calendarRepeatsUntil(String date) {
    return 'Jusqu’au $date';
  }

  @override
  String get calendarClearEndDate => 'Effacer la date de fin';

  @override
  String get calendarSetEnd => 'Définir la fin';

  @override
  String get calendarChangeEnd => 'Modifier';

  @override
  String get calendarReminderNone => 'Aucun rappel';

  @override
  String get calendarReminderAtStartTime => 'Au moment du début';

  @override
  String calendarReminderMinutesBefore(int count) {
    return '$count minutes avant';
  }

  @override
  String get calendarReminderHourBefore => '1 heure avant';

  @override
  String get calendarReminderDayBefore => '1 jour avant';

  @override
  String get calendarDinnerNameRequired => 'Donnez un nom au dîner.';

  @override
  String get calendarDishNameHint => 'Nom du plat';

  @override
  String get calendarServings => 'Portions';

  @override
  String get calendarMinutes => 'Minutes';

  @override
  String get calendarIngredients => 'Ingrédients';

  @override
  String get calendarAddIngredient => 'Ajouter un ingrédient';

  @override
  String get calendarInstructions => 'Préparation';

  @override
  String get calendarInstructionsHint => 'Comment le préparer';

  @override
  String get calendarEditDinner => 'Modifier le dîner';

  @override
  String get calendarSetDinner => 'Définir le dîner';

  @override
  String get calendarIngredientHint => 'p. ex. 2 blancs de poulet';

  @override
  String get calendarRemoveDinner => 'Supprimer le dîner';

  @override
  String get calendarWhatYouNeed => 'Ce qu’il vous faut';

  @override
  String get calendarDinnerEmpty =>
      'Aucun ingrédient ni préparation pour l’instant.';

  @override
  String calendarServingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count portions',
      one: '1 portion',
    );
    return '$_temp0';
  }

  @override
  String calendarMinutesShort(int count) {
    return '$count min';
  }

  @override
  String get cardWalletAddCard => 'Ajouter une carte';

  @override
  String get cardWalletNoCardsTitle => 'Aucune carte pour l\'instant';

  @override
  String get cardWalletNoCardsSubtitle =>
      'Ajoute ta première carte de fidélité ou d\'adhérent et elle apparaîtra ici, prête à être scannée.';

  @override
  String get cardWalletReadOnlyNotice =>
      'Les cartes s\'ajoutent sur ton téléphone, où se trouvent l\'appareil photo et le lecteur NFC. Active la synchronisation du portefeuille de cartes et elles apparaissent ici pour être consultées et présentées.';

  @override
  String get cardWalletTapToScan => 'Toucher pour scanner';

  @override
  String get cardWalletNoCodeToShow => 'Aucun code à afficher';

  @override
  String cardWalletValueNotValidFor(String format) {
    return 'Cette valeur n\'est pas valide pour $format.';
  }

  @override
  String get cardWalletEmptyTag => '(puce vide)';

  @override
  String get cardWalletEmulationNote =>
      'L\'émulation de lecture sans contact fonctionne dans l\'application mobile luma. Sur cet appareil, tu peux copier les données de la puce ou scanner le QR code ci-dessus.';

  @override
  String get cardWalletCouldntScan => 'Échec du scan';

  @override
  String get cardWalletReadyToScan => 'Prêt à scanner';

  @override
  String get cardWalletScanATag => 'Scanner une puce';

  @override
  String get cardWalletHoldFlat =>
      'Plaque ta carte à plat contre l\'arrière de ton téléphone et garde-la immobile : les cartes plus grandes mettent une seconde à se lire.';

  @override
  String cardWalletScanUnexpectedError(String error) {
    return 'Une erreur s\'est produite pendant le scan. ($error)';
  }

  @override
  String get cardWalletScanBarcodeTitle => 'Scanner un code-barres';

  @override
  String get cardWalletScanBarcodeHint =>
      'Dirige la caméra vers le code-barres ou le QR code de la carte.';

  @override
  String get cardWalletEditCard => 'Modifier la carte';

  @override
  String get cardWalletCategoryOptional => 'Catégorie (facultatif)';

  @override
  String get cardWalletCategoryHint => 'Fidélité, Adhésion, Transport…';

  @override
  String get cardWalletNfcTagData => 'Données de la puce NFC';

  @override
  String get cardWalletCardNumberLabel =>
      'Numéro de carte / valeur du code-barres';

  @override
  String get cardWalletScanTag => 'Scanner la puce';

  @override
  String get cardWalletScan => 'Scanner';

  @override
  String get cardWalletFromImage => 'Depuis une image';

  @override
  String get cardWalletNfcHintScanOrPaste =>
      'Appuie sur « Scanner la puce », ou colle-la (texte ou hexadécimal)';

  @override
  String get cardWalletNfcHintPaste =>
      'Colle le contenu de la puce (texte ou hexadécimal)';

  @override
  String get cardWalletCodeHintScan =>
      'Scanne-le ci-dessus ou tape-le, p. ex. 2601234567890';

  @override
  String get cardWalletCodeHint => 'p. ex. 2601234567890';

  @override
  String get cardWalletNotesOptional => 'Notes (facultatif)';

  @override
  String get cardWalletNotesHint =>
      'Code PIN, membre depuis, tout ce qui est utile';

  @override
  String get cardWalletNameRequired => 'Donne un nom à la carte.';

  @override
  String get cardWalletEnterNfcData => 'Saisis les données de la puce NFC.';

  @override
  String get cardWalletEnterCardNumber =>
      'Saisis le numéro de carte ou la valeur du code-barres.';

  @override
  String cardWalletCantEncodeAs(String format) {
    return 'Cette valeur ne peut pas être encodée en $format. Choisis un autre format ou réactive la détection.';
  }

  @override
  String cardWalletSaveFailed(String error) {
    return 'Impossible d\'enregistrer la carte. ($error)';
  }

  @override
  String cardWalletScannedTag(String source) {
    return 'Puce scannée ($source)';
  }

  @override
  String get cardWalletSourceTagUid => 'UID de la puce';

  @override
  String get cardWalletSourceNdef => 'enregistrement NDEF';

  @override
  String get cardWalletNoCodeInImage =>
      'Aucun code-barres ni QR code trouvé dans cette image.';

  @override
  String cardWalletImageReadFailed(String error) {
    return 'Impossible de lire cette image. ($error)';
  }

  @override
  String cardWalletScannedFormat(String format) {
    return '$format scanné';
  }

  @override
  String cardWalletDetectionOff(String format) {
    return '$format · détection désactivée';
  }

  @override
  String get cardWalletStatusWaiting =>
      'Scanne ou tape un code et luma choisit le format';

  @override
  String cardWalletRecognizedAs(String format) {
    return 'Reconnu comme $format';
  }

  @override
  String cardWalletNoStandardMatch(String format) {
    return 'Aucune correspondance standard — utilisation de $format';
  }

  @override
  String get cardWalletChange => 'Modifier';

  @override
  String get cardWalletAdvanced => 'Avancé';

  @override
  String get cardWalletAutoDetect => 'Détecter automatiquement le format';

  @override
  String get cardWalletAutoDetectHint =>
      'luma lit la valeur et choisit le type de code correspondant.';

  @override
  String get cardWalletFormat => 'Format';

  @override
  String get cardWalletFormatNfc => 'Puce NFC';

  @override
  String get cardWalletNfcTagReady => 'Puce NFC prête';

  @override
  String get cardWalletPreviewHere => 'L\'aperçu apparaît ici';

  @override
  String cardWalletNotValidYet(String format) {
    return 'Pas encore valide pour $format';
  }

  @override
  String get cardWalletDeleteTitle => 'Supprimer la carte ?';

  @override
  String get cardWalletDeleteBody =>
      'Cela supprime la carte de ton portefeuille sur cet appareil.';

  @override
  String get cardWalletNfcUnavailable =>
      'La lecture NFC n\'est pas disponible sur cet appareil.';

  @override
  String get cardWalletNfcOff =>
      'Le NFC est désactivé ou non pris en charge ici. Active-le dans les réglages de ton appareil et réessaie.';

  @override
  String cardWalletNfcStartFailed(String error) {
    return 'Impossible de démarrer le lecteur NFC. ($error)';
  }

  @override
  String get cardWalletNfcNoTag =>
      'Aucune puce détectée. Plaque la carte à plat contre l\'arrière du téléphone et réessaie.';

  @override
  String get cardWalletNfcReadFailed =>
      'Impossible de lire cette puce : elle semble vide ou non prise en charge.';

  @override
  String get cardWalletNfcPaymentCardRefused =>
      'Cela ressemble à une carte bancaire ou de crédit : luma ne copie pas les cartes de paiement, pour ta sécurité. Ajoute plutôt une carte de fidélité, d\'hôtel, de transport ou d\'événement.';

  @override
  String get cardWalletNfcEmptyTag =>
      'Impossible de lire quoi que ce soit sur cette puce : elle est peut-être vide ou verrouillée.';

  @override
  String get cityPlannerLinuxTitle => 'Non disponible sous Linux';

  @override
  String get cityPlannerLinuxSubtitle =>
      'City Planner nécessite une WebView intégrée, pas encore prise en charge sur cette plateforme.';

  @override
  String get cloudFilesSessionExpired =>
      'Votre session a expiré — reconnectez-vous dans Paramètres → Synchronisation.';

  @override
  String get cloudFilesSignInFirst =>
      'Connectez-vous d\'abord dans Paramètres → Synchronisation.';

  @override
  String get cloudFilesBusy => 'Un autre transfert est déjà en cours.';

  @override
  String cloudFilesNotEnoughSpace(String name, String needed, String free) {
    return 'Espace insuffisant : « $name » nécessite $needed, mais seulement $free sont libres.';
  }

  @override
  String get cloudFilesServerFull =>
      'Le serveur n\'a plus d\'espace pour votre compte.';

  @override
  String get cloudFilesPartMissing =>
      'Une partie de ce fichier est absente du serveur.';

  @override
  String get cloudFilesIndexConflict =>
      'Impossible de mettre à jour la liste des fichiers — réessayez.';

  @override
  String cloudFilesSizeB(String value) {
    return '$value o';
  }

  @override
  String cloudFilesSizeKb(String value) {
    return '$value Ko';
  }

  @override
  String cloudFilesSizeMb(String value) {
    return '$value Mo';
  }

  @override
  String cloudFilesSizeGb(String value) {
    return '$value Go';
  }

  @override
  String get cloudFilesSignedOutTitle =>
      'Cloud Files nécessite la synchronisation';

  @override
  String get cloudFilesSignedOutBody =>
      'Connectez-vous à votre serveur de synchronisation dans Paramètres → Synchronisation et compte, puis revenez ici pour envoyer des fichiers. Les fichiers sont chiffrés sur cet appareil avant l\'envoi — le serveur ne peut jamais les lire.';

  @override
  String get cloudFilesHeaderSubtitle =>
      'Fichiers chiffrés sur votre serveur, sur chaque appareil.';

  @override
  String get cloudFilesEmptyTitle => 'Aucun fichier pour l\'instant';

  @override
  String get cloudFilesEmptySubtitle =>
      'Ajoutez-en un pour le garder en sécurité partout.';

  @override
  String get cloudFilesStorageUsed => 'Stockage utilisé';

  @override
  String cloudFilesStorageOf(String used, String quota) {
    return '$used sur $quota';
  }

  @override
  String cloudFilesFreeSpace(String size) {
    return '$size libres';
  }

  @override
  String cloudFilesSaveDialogTitle(String name) {
    return 'Enregistrer $name';
  }

  @override
  String cloudFilesSaved(String name) {
    return '$name enregistré';
  }

  @override
  String get cloudFilesDeleteTitle => 'Supprimer le fichier ?';

  @override
  String cloudFilesDeleteBody(String name, String size) {
    return 'Supprimer « $name » du serveur ? Cela libère $size et est irréversible.';
  }

  @override
  String cloudFilesUploadingProgress(String name, String pct) {
    return 'Envoi de $name… $pct %';
  }

  @override
  String cloudFilesDownloadingProgress(String name, String pct) {
    return 'Téléchargement de $name… $pct %';
  }

  @override
  String get dataChartAggSum => 'Somme';

  @override
  String get dataChartAverage => 'Moyenne';

  @override
  String get dataChartAggCount => 'Nombre';

  @override
  String get dataChartAggMin => 'Min';

  @override
  String get dataChartAggMax => 'Max';

  @override
  String get dataChartRangeAll => 'Toute la période';

  @override
  String get dataChartRangeLast7 => '7 derniers jours';

  @override
  String get dataChartRangeLast30 => '30 derniers jours';

  @override
  String get dataChartRangeLast90 => '90 derniers jours';

  @override
  String get dataChartRangeThisMonth => 'Ce mois-ci';

  @override
  String get dataChartRangeThisYear => 'Cette année';

  @override
  String get dataChartRangeCustom => 'Personnalisée…';

  @override
  String get dataChartSortValueDesc => 'Valeur ↓';

  @override
  String get dataChartSortValueAsc => 'Valeur ↑';

  @override
  String get dataChartSortLabelAsc => 'Libellé A-Z';

  @override
  String get dataChartTypeBar => 'Barres';

  @override
  String get dataChartTypeLine => 'Courbe';

  @override
  String get dataChartTypeArea => 'Aires';

  @override
  String get dataChartTypePie => 'Secteurs';

  @override
  String get dataChartTypeDonut => 'Anneau';

  @override
  String get dataChartGroupBy => 'Grouper par';

  @override
  String get dataChartAggregation => 'Agrégation';

  @override
  String get dataChartValue => 'Valeur';

  @override
  String get dataChartShow => 'Afficher';

  @override
  String dataChartTopN(int count) {
    return 'Top $count';
  }

  @override
  String get dataChartDateColumn => 'Colonne de date';

  @override
  String get dataChartPeriod => 'Période';

  @override
  String get dataChartGroupTags => 'Étiquettes';

  @override
  String get dataChartUntagged => 'Sans étiquette';

  @override
  String get dataChartEmptyGroup => '(vide)';

  @override
  String dataChartNeedsNumeric(String aggregation) {
    return 'Ajoutez une colonne numérique pour afficher les valeurs,\nou passez l\'agrégation sur « $aggregation ».';
  }

  @override
  String get dataChartNoMatch =>
      'Aucune donnée ne correspond aux filtres actuels';

  @override
  String get dataChartSummaryGroups => 'Groupes';

  @override
  String get dataChartSummaryTop => 'Premier';

  @override
  String dataChartTitle(String aggregation, String value, String group) {
    return '$aggregation de $value par $group';
  }

  @override
  String get dataChartRowsWord => 'lignes';

  @override
  String get dataChartTagWord => 'étiquette';

  @override
  String get dataMgmtTitle => 'Gestion des données';

  @override
  String get dataMgmtSubtitle =>
      'Créez des tableaux, étiquetez des entrées et tracez des graphiques à partir de vos propres jeux de données.';

  @override
  String get dataMgmtNewDatasetHint => 'Nom du nouveau jeu de données...';

  @override
  String get dataMgmtNoDatasetsTitle => 'Aucun jeu de données pour l\'instant';

  @override
  String get dataMgmtNoDatasetsSubtitle =>
      'Créez un jeu de données ci-dessus ou importez-en un depuis un CSV.';

  @override
  String dataMgmtDeleteDatasetTitle(String name) {
    return 'Supprimer \"$name\" ?';
  }

  @override
  String get dataMgmtDeleteDatasetBody =>
      'Cela supprimera définitivement le jeu de données et toutes ses lignes.';

  @override
  String dataMgmtDatasetMeta(int columns, int tags) {
    String _temp0 = intl.Intl.pluralLogic(
      columns,
      locale: localeName,
      other: '$columns colonnes',
      one: '1 colonne',
    );
    String _temp1 = intl.Intl.pluralLogic(
      tags,
      locale: localeName,
      other: '$tags étiquettes',
      one: '1 étiquette',
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
  String get dataMgmtTabTable => 'Tableau';

  @override
  String get dataMgmtTabCharts => 'Graphiques';

  @override
  String get dataMgmtTags => 'Étiquettes';

  @override
  String get dataMgmtImportCsv => 'Importer un CSV';

  @override
  String get dataMgmtExportCsv => 'Exporter un CSV';

  @override
  String get dataMgmtSaveCsvTitle => 'Enregistrer le CSV';

  @override
  String get dataMgmtImportedName => 'Importé';

  @override
  String get dataMgmtManageTagsTitle => 'Gérer les étiquettes';

  @override
  String get dataMgmtTagsExplainer =>
      'Les étiquettes peuvent être ajoutées à n\'importe quelle ligne et servir à regrouper les graphiques — par exemple, étiqueter les revenus par source pour voir ce qui rapporte le plus.';

  @override
  String get dataMgmtNoTagsYet => 'Aucune étiquette pour l\'instant.';

  @override
  String get dataMgmtNewTag => 'Nouvelle étiquette';

  @override
  String get dataMgmtNewTagTitle => 'Nouvelle étiquette';

  @override
  String get dataMgmtEditTagTitle => 'Modifier l\'étiquette';

  @override
  String get dataMgmtTagNameHint =>
      'Nom de l\'étiquette (ex. Salaire, Petit boulot)';

  @override
  String get dataMgmtNoColumnsTitle => 'Aucune colonne pour l\'instant';

  @override
  String get dataMgmtNoColumnsSubtitle =>
      'Ajoutez une colonne pour commencer à construire votre tableau.';

  @override
  String get dataMgmtAddColumn => 'Ajouter une colonne';

  @override
  String get dataMgmtEditColumnTitle => 'Modifier la colonne';

  @override
  String get dataMgmtColumnNameHint => 'Nom de la colonne';

  @override
  String get dataMgmtColumnTypeLabel => 'Type :';

  @override
  String get dataMgmtTypeText => 'Texte';

  @override
  String get dataMgmtTypeNumber => 'Nombre';

  @override
  String get dataMgmtAddRow => 'Ajouter une ligne';

  @override
  String get dataMgmtSearchRowsHint => 'Rechercher des lignes...';

  @override
  String dataMgmtRowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lignes',
      one: '1 ligne',
    );
    return '$_temp0';
  }

  @override
  String dataMgmtRowCountFiltered(int shown, int total) {
    return '$shown sur $total lignes';
  }

  @override
  String get dataMgmtClearFilter => 'Effacer le filtre';

  @override
  String dataMgmtStatsSub(String avg, String max) {
    return 'moy. $avg  ·  max $max';
  }

  @override
  String get dataMgmtDuplicateRow => 'Dupliquer la ligne';

  @override
  String get dataMgmtEditTags => 'Modifier les étiquettes';

  @override
  String get dataMgmtCreateTags => 'Créer des étiquettes…';

  @override
  String get dataMgmtManageTags => 'Gérer les étiquettes…';

  @override
  String get deviceHealthWindowsOnlyTitle =>
      'Device Health n\'est disponible que sous Windows';

  @override
  String get deviceHealthWindowsOnlySubtitle =>
      'Les données CPU, pilotes et Defender proviennent d\'API réservées à Windows : ce module ne fonctionne donc que là-bas pour le moment.';

  @override
  String get deviceHealthReadingStatus => 'Lecture de l\'état du système…';

  @override
  String deviceHealthChecksRun(int checked, int total) {
    return '$checked sur $total vérifications effectuées';
  }

  @override
  String get deviceHealthChecking => 'Vérification…';

  @override
  String get deviceHealthCheckEverything => 'Tout vérifier';

  @override
  String get deviceHealthWhatNeedsAttention => 'Points à traiter';

  @override
  String get deviceHealthErrReadStatus =>
      'Impossible de lire l\'état du système.';

  @override
  String get deviceHealthErrCpuRamUnavailable =>
      'Lecture CPU/RAM indisponible.';

  @override
  String get deviceHealthErrDefenderUnavailable =>
      'Impossible de lire l\'état de Windows Defender : un autre antivirus est peut-être actif, ou le service Defender est désactivé.';

  @override
  String get deviceHealthErrListProcesses =>
      'Impossible de lister les processus.';

  @override
  String get deviceHealthErrWingetMissing =>
      'winget n\'est pas disponible sur ce système.';

  @override
  String get deviceHealthNeedsManualUpdate =>
      'Mise à jour manuelle requise — winget n\'a pas pu terminer silencieusement.';

  @override
  String deviceHealthIssueRamHigh(int percent) {
    return 'L\'utilisation de la RAM est très élevée ($percent %).';
  }

  @override
  String deviceHealthIssueCpuHigh(int percent) {
    return 'L\'utilisation du processeur est très élevée ($percent %).';
  }

  @override
  String deviceHealthIssueBatteryDegraded(int percent) {
    return 'La santé de la batterie est fortement dégradée ($percent % de capacité perdue).';
  }

  @override
  String deviceHealthIssueBatteryFading(int percent) {
    return 'La santé de la batterie diminue ($percent % de capacité perdue).';
  }

  @override
  String get deviceHealthIssueDefenderOff =>
      'La protection de Windows Defender est désactivée.';

  @override
  String get deviceHealthIssueDefinitionsOld =>
      'Les définitions antivirus sont obsolètes.';

  @override
  String get deviceHealthIssueNoScan =>
      'Aucune analyse antivirus au cours des 30 derniers jours.';

  @override
  String deviceHealthIssueBloatware(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count applications en arrière-plan souvent jugées inutiles.',
      one: '1 application en arrière-plan souvent jugée inutile.',
    );
    return '$_temp0';
  }

  @override
  String deviceHealthIssueAppUpdates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mises à jour d\'applications disponibles.',
      one: '1 mise à jour d\'application disponible.',
    );
    return '$_temp0';
  }

  @override
  String get deviceHealthCardAppUpdatesTitle => 'Mises à jour des apps';

  @override
  String get deviceHealthCardRescan => 'Relancer l\'analyse';

  @override
  String get deviceHealthCardScanForUpdates => 'Rechercher les mises à jour';

  @override
  String get deviceHealthCardAppUpdatesNotScanned =>
      'Pas encore analysé — vérifie winget et luma pour les mises à jour disponibles.';

  @override
  String deviceHealthCardUpdateAll(int count) {
    return 'Tout mettre à jour ($count)';
  }

  @override
  String deviceHealthCardUpdateSourceMayPrompt(String source) {
    return '$source, peut demander une confirmation';
  }

  @override
  String get deviceHealthCardUpdateFailedHint =>
      'Mise à jour automatique impossible — essayez de la mettre à jour vous-même.';

  @override
  String get deviceHealthCardAppsUpToDate =>
      'Tout ce que luma a vérifié est à jour.';

  @override
  String get deviceHealthCardBatteryTitle => 'Batterie';

  @override
  String get deviceHealthCardNotCheckedYet => 'Pas encore vérifié.';

  @override
  String get deviceHealthCardNoBattery =>
      'Aucune batterie détectée — il s\'agit probablement d\'un ordinateur de bureau.';

  @override
  String deviceHealthCardBatteryHealth(int percent) {
    return 'Santé de la batterie : $percent % de la capacité d\'origine restante.';
  }

  @override
  String get deviceHealthCardBatteryNoWearData =>
      'Cette batterie ne signale pas sa capacité d\'origine ni sa capacité pleine : l\'usure ne peut pas être estimée.';

  @override
  String get deviceHealthBatteryDischarging => 'En décharge';

  @override
  String get deviceHealthBatteryOnAc => 'Sur secteur';

  @override
  String get deviceHealthBatteryFullyCharged => 'Entièrement chargée';

  @override
  String get deviceHealthBatteryLow => 'Faible';

  @override
  String get deviceHealthBatteryCritical => 'Critique';

  @override
  String get deviceHealthBatteryCharging => 'En charge';

  @override
  String get deviceHealthBatteryPartiallyCharged => 'Partiellement chargée';

  @override
  String get deviceHealthGpuUnknownName => 'GPU inconnu';

  @override
  String get deviceHealthCardCpuRamTitle => 'CPU et RAM';

  @override
  String get deviceHealthCardDefenderTitle =>
      'Protection contre les virus et menaces';

  @override
  String get deviceHealthCardRealTimeOn =>
      'La protection en temps réel est activée.';

  @override
  String get deviceHealthCardRealTimeOff =>
      'La protection en temps réel est DÉSACTIVÉE.';

  @override
  String deviceHealthCardDefenderSummary(String definitions, String lastScan) {
    return 'Définitions : $definitions · Dernière analyse : $lastScan';
  }

  @override
  String get deviceHealthCardRelativeNever => 'jamais';

  @override
  String get deviceHealthCardRelativeToday => 'aujourd\'hui';

  @override
  String get deviceHealthCardRelativeYesterday => 'hier';

  @override
  String deviceHealthCardRelativeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count jours',
      one: 'il y a 1 jour',
    );
    return '$_temp0';
  }

  @override
  String get deviceHealthCardRunQuickScan => 'Lancer une analyse rapide';

  @override
  String get deviceHealthCardOpenWindowsSecurity => 'Ouvrir Sécurité Windows';

  @override
  String get deviceHealthCardGpuTitle => 'GPU et pilotes';

  @override
  String deviceHealthCardDriverVersion(String version) {
    return 'Pilote $version';
  }

  @override
  String deviceHealthCardDriverVersionDate(String version, String date) {
    return 'Pilote $version · $date';
  }

  @override
  String deviceHealthCardOpenVendorTool(String vendor) {
    return 'Ouvrir l\'outil de mise à jour $vendor';
  }

  @override
  String get deviceHealthCardOpenWindowsUpdate => 'Ouvrir Windows Update';

  @override
  String get deviceHealthCardGpuDisclaimer =>
      'Windows ne permet pas de vérifier directement si un pilote est récent : ces boutons ouvrent l\'outil qui le sait. Rien n\'est installé automatiquement.';

  @override
  String get deviceHealthCardProcessesTitle => 'Processus en arrière-plan';

  @override
  String get deviceHealthCardScanProcesses => 'Analyser les processus';

  @override
  String get deviceHealthCardProcessesNotScanned =>
      'Pas encore analysé — cela lit chaque processus en cours, donc ce n\'est pas lancé automatiquement.';

  @override
  String deviceHealthCardProcessesSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count processus · trié par mémoire',
      one: '1 processus · trié par mémoire',
    );
    return '$_temp0';
  }

  @override
  String deviceHealthCardSuggested(String label) {
    return 'Suggéré : $label';
  }

  @override
  String get deviceHealthCardEndProcess => 'Arrêter le processus';

  @override
  String deviceHealthCardEndProcessTitle(String name) {
    return 'Arrêter $name ?';
  }

  @override
  String get deviceHealthCardEndProcessClosesNow =>
      'Cela ferme immédiatement le processus. Le travail non enregistré sera perdu.';

  @override
  String deviceHealthCardEndProcessWithReason(String reason) {
    return '$reason Le travail non enregistré dans ce processus sera perdu.';
  }

  @override
  String get deviceHealthStatusGood => 'Bon';

  @override
  String get deviceHealthStatusWarning => 'À surveiller';

  @override
  String get deviceHealthStatusBad => 'Mauvais';

  @override
  String get deviceHealthStatusNotChecked => 'Non vérifié';

  @override
  String get deviceHealthCardCheck => 'Vérifier';

  @override
  String get errandsEmptyTitle => 'Aucune corvée pour le moment';

  @override
  String get errandsEmptySubtitle =>
      'Ajoutez une corvée récurrente — quotidienne, hebdomadaire, mensuelle ou tous les quelques jours — elle apparaît sur votre liste le jour prévu.';

  @override
  String get errandsAddErrand => 'Ajouter une corvée';

  @override
  String get errandsAllDoneToday =>
      'Tout est fait pour aujourd\'hui — bien joué.';

  @override
  String get errandsNothingDueToday =>
      'Rien à faire aujourd\'hui. Vos prochaines corvées sont listées sous À venir.';

  @override
  String get errandsComingUp => 'À venir';

  @override
  String get errandsDoneToday => 'Faites aujourd\'hui';

  @override
  String get errandsTodayTitle => 'Corvées du jour';

  @override
  String errandsDoneOfTotal(int done, int total) {
    return '$done sur $total faites';
  }

  @override
  String get errandsCategories => 'Catégories';

  @override
  String get errandsNewCategory => 'Nouvelle catégorie';

  @override
  String get errandsEditCategoryTitle => 'Modifier la catégorie';

  @override
  String errandsDaysLate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours de retard',
      one: '1 jour de retard',
    );
    return '$_temp0';
  }

  @override
  String get errandsDelay => 'Reporter';

  @override
  String get errandsDelayByDaysTitle => 'Reporter de combien de jours ?';

  @override
  String errandsInDays(int count) {
    return 'Dans $count jours';
  }

  @override
  String get errandsInAWeek => 'Dans une semaine';

  @override
  String get errandsCustom => 'Personnalisé…';

  @override
  String get errandsCustomDaysHint => 'ex. 5';

  @override
  String get errandsRepeatDaily => 'Chaque jour';

  @override
  String get errandsRepeatWeekly => 'Chaque semaine';

  @override
  String get errandsRepeatMonthly => 'Chaque mois';

  @override
  String get errandsRepeatCustom => 'Personnalisé';

  @override
  String errandsRepeatEveryDays(int count) {
    return 'Tous les $count jours';
  }

  @override
  String errandsRepeatEveryWeeks(int count) {
    return 'Toutes les $count semaines';
  }

  @override
  String errandsRepeatEveryMonths(int count) {
    return 'Tous les $count mois';
  }

  @override
  String get errandsEditTitle => 'Modifier la corvée';

  @override
  String get errandsNameRequired => 'Donnez un nom à la corvée.';

  @override
  String get errandsIntervalInvalid =>
      'Saisissez un intervalle de répétition entre 1 et 365 jours.';

  @override
  String errandsSaveFailed(String error) {
    return 'Impossible d\'enregistrer la corvée. ($error)';
  }

  @override
  String get errandsNameHint => 'Arroser les plantes';

  @override
  String get errandsRepeats => 'Répétition';

  @override
  String get errandsEvery => 'Tous les';

  @override
  String get errandsDays => 'jours';

  @override
  String get errandsNextDue => 'Prochaine échéance';

  @override
  String get errandsFirstDue => 'Première échéance';

  @override
  String get errandsNotesOptional => 'Notes (facultatif)';

  @override
  String get errandsNotesHint =>
      'Quelles plantes, quel magasin, tout ce qui peut aider';

  @override
  String get errandsNoCategory => 'Aucune catégorie';

  @override
  String get errandsNoCategoriesYet => 'Aucune catégorie pour le moment.';

  @override
  String get errandsCategoriesHelp =>
      'Regroupez votre liste comme vous voulez — Maison, Santé, Administratif… Supprimer une catégorie conserve ses corvées.';

  @override
  String get errandsCategoryNameHint => 'Maison';

  @override
  String get errandsCategoryNameRequired => 'Donnez un nom à la catégorie.';

  @override
  String get errandsDeleteTitle => 'Supprimer la corvée ?';

  @override
  String get errandsDeleteBody =>
      'Cela supprime la corvée et son planning de cet appareil.';

  @override
  String get errandsDeleteCategoryTitle => 'Supprimer la catégorie ?';

  @override
  String get errandsDeleteCategoryBody =>
      'Les corvées de cette catégorie sont conservées et deviennent sans catégorie.';

  @override
  String get errandsDueTomorrow => 'À faire demain';

  @override
  String errandsDueInDays(int count) {
    return 'À faire dans $count jours';
  }

  @override
  String errandsDueOn(String date) {
    return 'À faire le $date';
  }

  @override
  String get fileTreePickFolderTitle =>
      'Choisissez un dossier ou un lecteur à analyser';

  @override
  String get fileTreeNothingScanned => 'Rien d\'analysé pour l\'instant';

  @override
  String get fileTreeNothingScannedHint =>
      'Choisissez un lecteur ou un dossier ci-dessus et luma cartographiera ce qui occupe l\'espace.';

  @override
  String get fileTreeFolderEmpty => 'Ce dossier est vide';

  @override
  String get fileTreeFolderEmptyHint =>
      'Aucun fichier trouvé, ou ils n\'ont pas pu être lus.';

  @override
  String get fileTreeDiskUsage => 'Utilisation du disque';

  @override
  String get fileTreeDiskUsageHint =>
      'Voyez exactement ce qui remplit votre disque.';

  @override
  String get fileTreeRescan => 'Relancer l\'analyse';

  @override
  String get fileTreeTotalSize => 'Taille totale';

  @override
  String get fileTreeFiles => 'Fichiers';

  @override
  String get fileTreeFolders => 'Dossiers';

  @override
  String get fileTreeList => 'Liste';

  @override
  String get fileTreeDetailed => 'Détaillé';

  @override
  String get fileTreeDrives => 'Lecteurs';

  @override
  String get fileTreeMapping => 'Cartographie de vos fichiers…';

  @override
  String get fileTreeProgressAtBottom => 'La progression s\'affiche en bas.';

  @override
  String get fileTreeIndexing => 'Indexation des fichiers…';

  @override
  String get fileTreeMeasuring => 'Mesure des tailles…';

  @override
  String fileTreeItemsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments trouvés',
      one: '1 élément trouvé',
    );
    return '$_temp0';
  }

  @override
  String fileTreeItemsProgress(String done, String total) {
    return '$done / $total éléments';
  }

  @override
  String fileTreeBytesScanned(String size) {
    return '$size analysés';
  }

  @override
  String get fileTreeCancelScan => 'Annuler l\'analyse';

  @override
  String get fileTreeNoFilesHere =>
      'Aucun fichier à cartographier dans ce dossier.';

  @override
  String fileTreeOtherItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count autres éléments',
      one: '1 autre élément',
    );
    return '($_temp0)';
  }

  @override
  String get fileViewerCouldNotReadFile =>
      'Impossible de lire le fichier sélectionné.';

  @override
  String fileViewerCouldNotOpen(String error) {
    return 'Impossible d\'ouvrir ce fichier : $error';
  }

  @override
  String fileViewerOpenExternallyFailed(String message) {
    return 'Impossible d\'ouvrir à l\'extérieur : $message';
  }

  @override
  String get fileViewerTapToPick => 'Touchez pour choisir un fichier';

  @override
  String get fileViewerFormatsHint =>
      'PDF · DOCX · XLSX · images · SVG · texte et code';

  @override
  String get fileViewerOpenExternally => 'Ouvrir à l\'extérieur';

  @override
  String get fileViewerNoPreview => 'Aucun aperçu pour ce type de fichier';

  @override
  String get fileViewerOpenExternallyHint =>
      'Utilisez « Ouvrir à l\'extérieur » pour l\'afficher dans son application par défaut.';

  @override
  String get fileViewerCannotPreview =>
      'Ce type de fichier ne peut pas être prévisualisé ici.';

  @override
  String get fileViewerUnknownExtension => 'FICHIER';

  @override
  String fileViewerPageOf(int page, int total) {
    return 'Page $page sur $total';
  }

  @override
  String get fileViewerNoPageText => 'Aucun texte sur cette page';

  @override
  String get fileViewerNoPageTextHint =>
      'Cette page ne contient pas de texte extractible : il s\'agit peut-être d\'une numérisation ou d\'une image.';

  @override
  String get fileViewerNoReadableText =>
      'Ce document ne contient aucun texte lisible';

  @override
  String get fileViewerEmptyWorksheet => 'Cette feuille de calcul est vide';

  @override
  String fileViewerShowingRows(int shown, int total) {
    return 'Affichage des $shown premières lignes sur $total.';
  }

  @override
  String get fileViewerLargeFile =>
      'Fichier volumineux — affichage des 500 premiers Ko.';

  @override
  String get fileViewerNotWordDocument =>
      'Ce fichier ne ressemble pas à un document Word.';

  @override
  String get fileViewerNoDocumentBody =>
      'Impossible de trouver le corps du document.';

  @override
  String get fileViewerNoWorksheets =>
      'Ce classeur ne contient aucune feuille.';

  @override
  String freeSketchImageCouldNotOpen(String error) {
    return 'Impossible d\'ouvrir cette image : $error';
  }

  @override
  String freeSketchArtworkCouldNotOpen(String error) {
    return 'Impossible d\'ouvrir cette œuvre : $error';
  }

  @override
  String get freeSketchRenameArtwork => 'Renommer l\'œuvre';

  @override
  String freeSketchDeleteConfirm(String title) {
    return 'Supprimer « $title » ?';
  }

  @override
  String freeSketchDeleteBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count calques',
      one: '1 calque',
    );
    return '$_temp0 seront supprimés définitivement de cet appareil. Exportez-le d\'abord si vous voulez en garder une copie.';
  }

  @override
  String get freeSketchGallery => 'Galerie';

  @override
  String get freeSketchGallerySubtitle =>
      'Chaque œuvre est enregistrée sur cet appareil au fil de votre création.';

  @override
  String get freeSketchImportImage => 'Importer une image';

  @override
  String get freeSketchNew => 'Nouveau';

  @override
  String get freeSketchNewArtwork => 'Nouvelle œuvre';

  @override
  String get freeSketchCouldNotReadGallery => 'La galerie n\'a pas pu être lue';

  @override
  String get freeSketchGalleryEmpty => 'Votre galerie est vide';

  @override
  String get freeSketchGalleryEmptyHint =>
      'Commencez une nouvelle œuvre : crayons, encres, aquarelles, marqueurs, aérographes et estompes, avec calques, modes de fusion, symétrie et pression. Exportez en PNG, JPEG, Photoshop ou OpenRaster.';

  @override
  String freeSketchArtworkInfo(String size, int count, String updated) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count calques',
      one: '1 calque',
    );
    return '$size · $_temp0 · $updated';
  }

  @override
  String get freeSketchArtworkActions => 'Actions sur l\'œuvre';

  @override
  String get freeSketchDuplicate => 'Dupliquer';

  @override
  String get freeSketchUntitledArtwork => 'Œuvre sans titre';

  @override
  String get freeSketchCanvas => 'Toile';

  @override
  String get freeSketchBackground => 'Arrière-plan';

  @override
  String get freeSketchTransparent => 'Transparent';

  @override
  String get freeSketchSwapSize => 'Inverser largeur et hauteur';

  @override
  String get freeSketchWidthPx => 'Largeur (px)';

  @override
  String get freeSketchHeightPx => 'Hauteur (px)';

  @override
  String freeSketchCanvasMemory(String megabytes, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count calques',
      one: '1 calque',
    );
    return '$megabytes Mo par calque · jusqu\'à $_temp0';
  }

  @override
  String get freeSketchFirstLayerName => 'Calque 1';

  @override
  String get freeSketchSymmetryOff => 'Désactivée';

  @override
  String get freeSketchSymmetryVertical => 'Verticale';

  @override
  String get freeSketchSymmetryHorizontal => 'Horizontale';

  @override
  String get freeSketchSymmetryQuadrant => 'Quadrant';

  @override
  String get freeSketchSymmetryRadial => 'Radiale';

  @override
  String get freeSketchAdjHueSaturation => 'Teinte / saturation';

  @override
  String get freeSketchAdjBrightnessContrast => 'Luminosité / contraste';

  @override
  String get freeSketchAdjColorBalance => 'Équilibre des couleurs';

  @override
  String get freeSketchAdjBlur => 'Flou gaussien';

  @override
  String get freeSketchAdjInvert => 'Inverser';

  @override
  String get freeSketchAdjDesaturate => 'Noir et blanc';

  @override
  String get freeSketchAdjParamHue => 'Teinte';

  @override
  String get freeSketchAdjParamSaturation => 'Saturation';

  @override
  String get freeSketchAdjParamLightness => 'Luminosité';

  @override
  String get freeSketchAdjParamBrightness => 'Luminosité';

  @override
  String get freeSketchAdjParamContrast => 'Contraste';

  @override
  String get freeSketchAdjParamCyanRed => 'Cyan ↔ Rouge';

  @override
  String get freeSketchAdjParamMagentaGreen => 'Magenta ↔ Vert';

  @override
  String get freeSketchAdjParamYellowBlue => 'Jaune ↔ Bleu';

  @override
  String get freeSketchAdjParamRadius => 'Rayon';

  @override
  String get freeSketchBrushPencilHb => 'Crayon HB';

  @override
  String get freeSketchBrushPencil6b => 'Crayon 6B';

  @override
  String get freeSketchBrushMechanical => 'Porte-mine';

  @override
  String get freeSketchBrushCharcoal => 'Fusain';

  @override
  String get freeSketchBrushPastel => 'Pastel tendre';

  @override
  String get freeSketchBrushCrayon => 'Crayon gras';

  @override
  String get freeSketchBrushStudioPen => 'Stylo studio';

  @override
  String get freeSketchBrushFineliner => 'Feutre fin';

  @override
  String get freeSketchBrushBrushPen => 'Stylo pinceau';

  @override
  String get freeSketchBrushCalligraphy => 'Plume calligraphique';

  @override
  String get freeSketchBrushTechnical => 'Stylo technique';

  @override
  String get freeSketchBrushDryInk => 'Encre sèche';

  @override
  String get freeSketchBrushRoundHard => 'Rond dur';

  @override
  String get freeSketchBrushRoundSoft => 'Rond doux';

  @override
  String get freeSketchBrushOil => 'Peinture à l\'huile';

  @override
  String get freeSketchBrushGouache => 'Gouache';

  @override
  String get freeSketchBrushFlatAcrylic => 'Acrylique plat';

  @override
  String get freeSketchBrushPaletteKnife => 'Couteau à palette';

  @override
  String get freeSketchBrushWcWash => 'Lavis aquarelle';

  @override
  String get freeSketchBrushWcRound => 'Aquarelle ronde';

  @override
  String get freeSketchBrushWcBleed => 'Diffusion humide';

  @override
  String get freeSketchBrushWcSpatter => 'Éclaboussure';

  @override
  String get freeSketchBrushMarker => 'Marqueur à alcool';

  @override
  String get freeSketchBrushHighlighter => 'Surligneur';

  @override
  String get freeSketchBrushFeltTip => 'Feutre';

  @override
  String get freeSketchBrushAirbrush => 'Aérographe';

  @override
  String get freeSketchBrushFineAirbrush => 'Aérographe fin';

  @override
  String get freeSketchBrushSpray => 'Peinture en bombe';

  @override
  String get freeSketchBrushSplatter => 'Éclaboussures';

  @override
  String get freeSketchBrushSparkle => 'Scintillement';

  @override
  String get freeSketchBrushGlow => 'Lueur';

  @override
  String get freeSketchBrushFoliage => 'Feuillage';

  @override
  String get freeSketchBrushStipple => 'Pointillé';

  @override
  String get freeSketchBrushBlendSoft => 'Estompe douce';

  @override
  String get freeSketchBrushSmudge => 'Estompe';

  @override
  String get freeSketchBrushBlendBristle => 'Estompe à poils';

  @override
  String get freeSketchBrushBlur => 'Flou';

  @override
  String get freeSketchCategorySketching => 'Croquis';

  @override
  String get freeSketchCategoryInking => 'Encrage';

  @override
  String get freeSketchCategoryPainting => 'Peinture';

  @override
  String get freeSketchCategoryWatercolor => 'Aquarelle';

  @override
  String get freeSketchCategoryMarkers => 'Marqueurs';

  @override
  String get freeSketchCategoryAirbrush => 'Aérographe';

  @override
  String get freeSketchCategoryTexture => 'Textures et effets';

  @override
  String get freeSketchCategoryBlending => 'Mélange';

  @override
  String get freeSketchParamOpacity => 'Opacité';

  @override
  String get freeSketchParamFlow => 'Débit';

  @override
  String get freeSketchParamHardness => 'Dureté';

  @override
  String get freeSketchParamSpacing => 'Espacement';

  @override
  String get freeSketchParamStreamline => 'StreamLine';

  @override
  String get freeSketchParamSizePressure => 'Pression → taille';

  @override
  String get freeSketchParamFlowPressure => 'Pression → opacité';

  @override
  String get freeSketchParamTaperStart => 'Début de fuite';

  @override
  String get freeSketchParamTaperEnd => 'Fin de fuite';

  @override
  String get freeSketchParamSizeJitter => 'Variation de taille';

  @override
  String get freeSketchParamAngleJitter => 'Variation de rotation';

  @override
  String get freeSketchParamScatter => 'Dispersion';

  @override
  String get freeSketchParamRoundness => 'Rondeur';

  @override
  String get freeSketchParamAngle => 'Angle';

  @override
  String get freeSketchParamGrain => 'Grain';

  @override
  String get freeSketchParamWetEdges => 'Bords humides';

  @override
  String get freeSketchParamColorJitter => 'Variation de couleur';

  @override
  String get freeSketchParamStrength => 'Intensité';

  @override
  String get freeSketchGrainNone => 'Aucun';

  @override
  String get freeSketchGrainPaper => 'Papier';

  @override
  String get freeSketchGrainCanvas => 'Toile';

  @override
  String get freeSketchGrainRough => 'Rugueux';

  @override
  String get freeSketchEnginePaints => 'Peint';

  @override
  String get freeSketchEngineSmudges => 'Étale la couleur dessous';

  @override
  String get freeSketchEngineBlurs => 'Floute ce qui est dessous';

  @override
  String get freeSketchTraitGlazes =>
      'se superpose comme un marqueur — les chevauchements s\'assombrissent';

  @override
  String get freeSketchTraitAddsLight => 'ajoute de la lumière';

  @override
  String freeSketchTraitGrain(String grain) {
    return 'avec un grain $grain';
  }

  @override
  String get freeSketchTraitBuildsUp => 's\'accumule quand on reste immobile';

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
      'La pression modifie la taille et l\'opacité.';

  @override
  String get freeSketchPressureSize => 'La pression modifie la taille.';

  @override
  String get freeSketchPressureOpacity => 'La pression modifie l\'opacité.';

  @override
  String get freeSketchPressureNothing => 'La pression ne modifie rien.';

  @override
  String get freeSketchBlendNormal => 'Normal';

  @override
  String get freeSketchBlendMultiply => 'Produit';

  @override
  String get freeSketchBlendColorBurn => 'Densité couleur -';

  @override
  String get freeSketchBlendDarken => 'Obscurcir';

  @override
  String get freeSketchBlendScreen => 'Écran';

  @override
  String get freeSketchBlendColorDodge => 'Densité couleur +';

  @override
  String get freeSketchBlendLighten => 'Éclaircir';

  @override
  String get freeSketchBlendAdd => 'Ajouter';

  @override
  String get freeSketchBlendOverlay => 'Incrustation';

  @override
  String get freeSketchBlendSoftLight => 'Lumière douce';

  @override
  String get freeSketchBlendHardLight => 'Lumière crue';

  @override
  String get freeSketchBlendDifference => 'Différence';

  @override
  String get freeSketchBlendExclusion => 'Exclusion';

  @override
  String get freeSketchBlendHue => 'Teinte';

  @override
  String get freeSketchBlendSaturation => 'Saturation';

  @override
  String get freeSketchBlendColor => 'Couleur';

  @override
  String get freeSketchBlendLuminosity => 'Luminosité';

  @override
  String get freeSketchToolBrush => 'Pinceau';

  @override
  String get freeSketchToolEraser => 'Gomme';

  @override
  String get freeSketchToolSmudge => 'Doigt';

  @override
  String get freeSketchToolFill => 'Remplissage';

  @override
  String get freeSketchToolGradient => 'Dégradé';

  @override
  String get freeSketchToolShapes => 'Formes';

  @override
  String get freeSketchToolSelection => 'Sélection';

  @override
  String get freeSketchToolTransform => 'Transformer';

  @override
  String get freeSketchToolEyedropper => 'Pipette';

  @override
  String get freeSketchShapeLine => 'Ligne';

  @override
  String get freeSketchShapeRectangle => 'Rectangle';

  @override
  String get freeSketchShapeEllipse => 'Ellipse';

  @override
  String get freeSketchShapePolygon => 'Polygone';

  @override
  String get freeSketchSelectionLasso => 'Lasso';

  @override
  String get freeSketchSelectionCombineNew => 'Nouvelle';

  @override
  String get freeSketchSelectionCombineAdd => 'Ajouter';

  @override
  String get freeSketchSelectionCombineSubtract => 'Soustraire';

  @override
  String get freeSketchPresetScreen => 'Écran';

  @override
  String get freeSketchPresetSquare => 'Carré';

  @override
  String get freeSketchPresetPortrait => 'Portrait';

  @override
  String get freeSketchPresetA4Draft => 'Brouillon A4';

  @override
  String get freeSketchPresetComicPage => 'Page de BD';

  @override
  String get freeSketchPresetPhoneWallpaper => 'Fond d\'écran téléphone';

  @override
  String get freeSketchExportPngNote => 'Aplati, garde la transparence';

  @override
  String get freeSketchExportJpegNote => 'Aplati, fichier le plus petit';

  @override
  String get freeSketchExportPsdNote =>
      'Tous les calques, modes de fusion et masques';

  @override
  String get freeSketchExportOraNote => 'Calques pour Krita, GIMP et MyPaint';

  @override
  String freeSketchExportDialogTitle(String format) {
    return 'Exporter $format';
  }

  @override
  String get freeSketchEncodeFailed => 'L\'image n\'a pas pu être encodée.';

  @override
  String get freeSketchPixelsReadFailed =>
      'Les pixels de l\'image n\'ont pas pu être lus.';

  @override
  String freeSketchLayerNumber(int number) {
    return 'Calque $number';
  }

  @override
  String freeSketchCopyTitle(String title) {
    return '$title (copie)';
  }

  @override
  String get freeSketchNoCanvasSize =>
      'Le document n\'a pas de taille de toile.';

  @override
  String get freeSketchBrushesTitle => 'Pinceaux';

  @override
  String freeSketchBrushesForTool(String tool) {
    return 'Pinceaux : $tool';
  }

  @override
  String get freeSketchBrushLibrary => 'Bibliothèque';

  @override
  String get freeSketchBrushSettings => 'Réglages';

  @override
  String get freeSketchBrushCustomised => 'Personnalisé';

  @override
  String get freeSketchInvalidSnapshot => 'Instantané de croquis non valide.';

  @override
  String get freeSketchFallbackLayerName => 'Calque';

  @override
  String get freeSketchColourTitle => 'Couleur';

  @override
  String get freeSketchColourTabWheel => 'Roue';

  @override
  String get freeSketchColourTabSliders => 'Curseurs';

  @override
  String get freeSketchColourTabPalettes => 'Palettes';

  @override
  String get freeSketchColourSwapTooltip =>
      'Échanger avec la couleur secondaire (X)';

  @override
  String get freeSketchColourSecondaryTooltip => 'Couleur secondaire';

  @override
  String get freeSketchColourRecent => 'Récentes';

  @override
  String get freeSketchColourPairTooltip =>
      'Gauche : nouvelle couleur · droite : toucher pour revenir à la couleur de départ';

  @override
  String get freeSketchChannelHue => 'T';

  @override
  String get freeSketchChannelSaturation => 'S';

  @override
  String get freeSketchChannelBrightness => 'L';

  @override
  String get freeSketchChannelRed => 'R';

  @override
  String get freeSketchChannelGreen => 'V';

  @override
  String get freeSketchChannelBlue => 'B';

  @override
  String get freeSketchPaletteBasics => 'Base';

  @override
  String get freeSketchPaletteSkinTones => 'Teintes de peau';

  @override
  String get freeSketchPaletteNature => 'Nature';

  @override
  String get freeSketchPalettePastel => 'Pastel';

  @override
  String get freeSketchPaletteGreys => 'Gris';

  @override
  String get freeSketchColourRemoveHint =>
      'Appui long ou clic droit pour supprimer';

  @override
  String get freeSketchColourMyPalette => 'Ma palette';

  @override
  String get freeSketchColourAdd => 'Ajouter une couleur';

  @override
  String get freeSketchColourPaletteEmpty =>
      'Enregistrez ici les couleurs que vous réutilisez.';

  @override
  String get freeSketchLayersShowPanel => 'Afficher le panneau des calques';

  @override
  String get freeSketchLayerNew => 'Nouveau calque';

  @override
  String get freeSketchLayerRename => 'Renommer le calque';

  @override
  String get freeSketchLayerNewShortcut => 'Nouveau calque (Ctrl+Maj+N)';

  @override
  String get freeSketchLayersTitle => 'Calques';

  @override
  String get freeSketchLayersCollapse => 'Réduire';

  @override
  String get freeSketchLayerAlphaLockShort => 'α verr.';

  @override
  String get freeSketchLayerHide => 'Masquer le calque';

  @override
  String get freeSketchLayerShow => 'Afficher le calque';

  @override
  String get freeSketchBackgroundColour => 'Couleur d\'arrière-plan';

  @override
  String get freeSketchBackgroundUseCurrent => 'Utiliser la couleur actuelle';

  @override
  String get freeSketchBackgroundWhite => 'Blanc';

  @override
  String get freeSketchBackgroundPaper => 'Papier chaud';

  @override
  String get freeSketchBackgroundCharcoal => 'Charbon';

  @override
  String get freeSketchBackgroundTransparent => 'Arrière-plan (transparent)';

  @override
  String get freeSketchBackgroundTransparentTip => 'Arrière-plan transparent';

  @override
  String get freeSketchBackgroundShow => 'Afficher l\'arrière-plan';

  @override
  String get freeSketchBlend => 'Fusion';

  @override
  String get freeSketchBlendMode => 'Mode de fusion';

  @override
  String get freeSketchLayerOpacity => 'Opacité';

  @override
  String get freeSketchLayerLock => 'Verrouiller';

  @override
  String get freeSketchLayerLockLayer => 'Verrouiller le calque';

  @override
  String get freeSketchLayerAlphaLock => 'Verrou alpha';

  @override
  String get freeSketchLayerClip => 'Écrêter';

  @override
  String get freeSketchLayerClipMask => 'Masque d\'écrêtage';

  @override
  String get freeSketchLayerActions => 'Actions du calque';

  @override
  String get freeSketchLayerRenameMenu => 'Renommer…';

  @override
  String get freeSketchLayerDuplicateShortcut => 'Dupliquer (Ctrl+J)';

  @override
  String get freeSketchLayerMergeDownShortcut =>
      'Fusionner avec le calque inférieur (Ctrl+E)';

  @override
  String get freeSketchLayerFlattenAll => 'Tout aplatir';

  @override
  String get freeSketchCopyShortcut => 'Copier (Ctrl+C)';

  @override
  String get freeSketchPasteAsNewLayerShortcut =>
      'Coller comme nouveau calque (Ctrl+V)';

  @override
  String get freeSketchLayerFillColour => 'Remplir avec la couleur';

  @override
  String get freeSketchLayerClearShortcut => 'Effacer (Suppr)';

  @override
  String get freeSketchLayerDelete => 'Supprimer le calque';

  @override
  String get freeSketchToolPaintInSelection => 'Peindre dans la sélection';

  @override
  String get freeSketchDeselect => 'Désélectionner';

  @override
  String get freeSketchFillTolerance => 'Tolérance';

  @override
  String get freeSketchAllLayers => 'Tous les calques';

  @override
  String get freeSketchThisLayer => 'Ce calque';

  @override
  String get freeSketchFillGrow => 'Élargir';

  @override
  String get freeSketchFillShrinkTip => 'Réduire le bord du remplissage';

  @override
  String get freeSketchFillGrowTip =>
      'Élargir le bord du remplissage sous les traits';

  @override
  String get freeSketchGradientLinear => 'Linéaire';

  @override
  String get freeSketchGradientRadial => 'Radial';

  @override
  String get freeSketchGradientToTransparent => 'Vers transparent';

  @override
  String get freeSketchGradientToSecondary => 'Vers secondaire';

  @override
  String get freeSketchGradientDragHint => 'Faites glisser sur la toile';

  @override
  String get freeSketchPolygonFewerSides => 'Moins de côtés';

  @override
  String get freeSketchPolygonMoreSides => 'Plus de côtés';

  @override
  String freeSketchPolygonSides(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count côtés',
      one: '1 côté',
    );
    return '$_temp0';
  }

  @override
  String get freeSketchShapeStroke => 'Contour';

  @override
  String get freeSketchShapeFill => 'Remplissage';

  @override
  String get freeSketchShapeShiftHint => 'Maj conserve la forme droite/carrée';

  @override
  String freeSketchSelectionCombineTip(String mode) {
    return 'Sélection $mode';
  }

  @override
  String get freeSketchSelectAll => 'Tout';

  @override
  String get freeSketchSelectInvert => 'Inverser';

  @override
  String get freeSketchCutShortcut => 'Couper (Ctrl+X)';

  @override
  String get freeSketchClearSelectionShortcut => 'Effacer la sélection (Suppr)';

  @override
  String get freeSketchTransformSelectLayerHint =>
      'Sélectionnez un calque contenant quelque chose';

  @override
  String get freeSketchTransformFlipH => 'Retourner horizontalement';

  @override
  String get freeSketchTransformFlipV => 'Retourner verticalement';

  @override
  String get freeSketchTransformRotate90 => 'Pivoter de 90°';

  @override
  String get freeSketchTransformUniformScale =>
      'Échelle uniforme (Maj pour libre)';

  @override
  String get freeSketchTransformFreeScale =>
      'Échelle libre (Maj pour uniforme)';

  @override
  String get freeSketchEyedropperTip =>
      'Astuce : maintenez Alt avec n\'importe quel outil pour prélever une couleur';

  @override
  String freeSketchStudioDefaultLayerName(int n) {
    return 'Calque $n';
  }

  @override
  String freeSketchLayerLocked(String name) {
    return '« $name » est verrouillé.';
  }

  @override
  String freeSketchLayerHidden(String name) {
    return '« $name » est masqué — affichez-le pour peindre dessus.';
  }

  @override
  String get freeSketchStrokeModeErase => 'Gomme';

  @override
  String get freeSketchStrokeModeSmudge => 'Estomper';

  @override
  String get freeSketchStrokeModeBlur => 'Flou';

  @override
  String get freeSketchUndoGradient => 'Dégradé';

  @override
  String get freeSketchUndoSelect => 'Sélection';

  @override
  String get freeSketchUndoSelectAll => 'Tout sélectionner';

  @override
  String get freeSketchUndoInvertSelection => 'Inverser la sélection';

  @override
  String get freeSketchNothingToCopy => 'Rien à copier sur ce calque.';

  @override
  String get freeSketchLayerCopied => 'Calque copié.';

  @override
  String get freeSketchSelectionCopied => 'Sélection copiée.';

  @override
  String get freeSketchUndoCut => 'Couper';

  @override
  String get freeSketchLayerPasted => 'Collé';

  @override
  String get freeSketchLayerEmptyTransform =>
      'Ce calque est vide — rien à transformer.';

  @override
  String get freeSketchUndoTransform => 'Transformer';

  @override
  String get freeSketchLayerEmptyAdjust =>
      'Ce calque est vide — rien à ajuster.';

  @override
  String get freeSketchUndoFill => 'Remplissage';

  @override
  String freeSketchFillFailed(String error) {
    return 'Échec du remplissage : $error';
  }

  @override
  String freeSketchLayerLimit(int limit) {
    return 'Cette taille de toile permet jusqu\'à $limit calques.';
  }

  @override
  String freeSketchLayerCopyName(String name) {
    return '$name copie';
  }

  @override
  String get freeSketchUndoDuplicateLayer => 'Dupliquer le calque';

  @override
  String get freeSketchUndoMergeDown => 'Fusionner avec le calque inférieur';

  @override
  String get freeSketchLayerFlattened => 'Aplati';

  @override
  String get freeSketchUndoFlatten => 'Aplatir';

  @override
  String get freeSketchUndoReorderLayers => 'Réordonner les calques';

  @override
  String get freeSketchUndoLayerOpacity => 'Opacité du calque';

  @override
  String get freeSketchUndoFillLayer => 'Remplir le calque';

  @override
  String get freeSketchCanvasFlipH => 'Retourner la toile horizontalement';

  @override
  String get freeSketchCanvasFlipV => 'Retourner la toile verticalement';

  @override
  String freeSketchImageOpenFailed(String error) {
    return 'Impossible d\'ouvrir cette image : $error';
  }

  @override
  String freeSketchSaveFailed(String error) {
    return 'Impossible d\'enregistrer : $error';
  }

  @override
  String freeSketchExportFailed(String error) {
    return 'Échec de l\'exportation : $error';
  }

  @override
  String get freeSketchExporting => 'Exportation…';

  @override
  String get freeSketchFilling => 'Remplissage…';

  @override
  String get freeSketchShowInterfaceTip => 'Afficher l\'interface (Tab)';

  @override
  String get freeSketchSaving => 'Enregistrement…';

  @override
  String get freeSketchEdited => 'Modifié';

  @override
  String get freeSketchFitToScreenShortcut => 'Ajuster à l\'écran (Ctrl+0)';

  @override
  String freeSketchResetRotationTip(String degrees) {
    return 'Réinitialiser la rotation ($degrees°)';
  }

  @override
  String get freeSketchViewMirroredTip =>
      'La vue est en miroir — touchez pour annuler (H)';

  @override
  String get freeSketchUndoTip => 'Annuler (Ctrl+Z)';

  @override
  String freeSketchUndoLabelTip(String label) {
    return 'Annuler $label (Ctrl+Z)';
  }

  @override
  String get freeSketchRedoTip => 'Rétablir (Ctrl+Maj+Z)';

  @override
  String freeSketchRedoLabelTip(String label) {
    return 'Rétablir $label';
  }

  @override
  String get freeSketchPenSettings => 'Réglages du stylet et de la saisie';

  @override
  String get freeSketchBackToGallery => 'Retour à la galerie';

  @override
  String get freeSketchSymmetryTip => 'Symétrie';

  @override
  String get freeSketchViewMenu => 'Affichage';

  @override
  String get freeSketchAdjustmentsTip => 'Réglages';

  @override
  String get freeSketchCanvasMenu => 'Toile';

  @override
  String freeSketchRadialSegments(int n) {
    return 'Radial × $n';
  }

  @override
  String get freeSketchMirrorRadialCopies => 'Refléter les copies radiales';

  @override
  String get freeSketchFitToScreen => 'Ajuster à l\'écran';

  @override
  String get freeSketchMirrorView => 'Refléter la vue';

  @override
  String get freeSketchResetRotation => 'Réinitialiser la rotation';

  @override
  String freeSketchSymmetryMode(String mode) {
    return 'Symétrie : $mode';
  }

  @override
  String get freeSketchImportImageAsLayer => 'Importer une image comme calque…';

  @override
  String freeSketchExportFormatLabel(String label, String extension) {
    return 'Exporter en $label (.$extension)';
  }

  @override
  String get freeSketchViewFitMenu => 'Ajuster à l\'écran   Ctrl+0';

  @override
  String get freeSketchViewActualMenu => 'Pixels réels   Ctrl+1';

  @override
  String get freeSketchViewMirrorMenu => 'Refléter la vue   H';

  @override
  String get freeSketchViewHideMenu => 'Masquer l\'interface   Tab';

  @override
  String freeSketchToolTapAgainBrushes(String tool) {
    return '$tool — touchez à nouveau pour les pinceaux';
  }

  @override
  String get freeSketchBrushSize => 'Taille du pinceau';

  @override
  String get freeSketchPenInput => 'Stylet et saisie';

  @override
  String get freeSketchPressureCurve => 'Courbe de pression';

  @override
  String get freeSketchPressureSoft =>
      'Doux — une pression légère va plus loin';

  @override
  String get freeSketchPressureFirm =>
      'Ferme — appuyez plus fort pour une intensité maximale';

  @override
  String get freeSketchPressureLinear => 'Linéaire';

  @override
  String get freeSketchDrawPenOnly => 'Dessiner uniquement au stylet';

  @override
  String get freeSketchPalmRejectionHint =>
      'Une fois le stylet utilisé, les doigts déplacent et zooment au lieu de peindre — rejet de la paume.';

  @override
  String get freeSketchShortcutsHelp =>
      'Raccourcis : B pinceau · E gomme · S estomper · G remplir · D dégradé · U formes · L sélection · V transformer · I pipette · [ ] taille · X inverser les couleurs · H refléter la vue · Espace-glisser pour déplacer · R-glisser pour pivoter · Alt-clic pour prélever une couleur · Maj-clic pour une ligne droite · tapotement à deux doigts pour annuler · tapotement à trois doigts pour rétablir.';

  @override
  String get galleryCategoryPictures => 'Photos';

  @override
  String get galleryCategoryVideos => 'Vidéos';

  @override
  String get galleryCategoryScreenshots => 'Captures d’écran';

  @override
  String get galleryCategoryGifs => 'GIF';

  @override
  String get galleryFolderDownloads => 'Téléchargements';

  @override
  String get galleryFolderCamera => 'Appareil photo';

  @override
  String get galleryMonthJanuary => 'janvier';

  @override
  String get galleryMonthFebruary => 'février';

  @override
  String get galleryMonthMarch => 'mars';

  @override
  String get galleryMonthApril => 'avril';

  @override
  String get galleryMonthMay => 'mai';

  @override
  String get galleryMonthJune => 'juin';

  @override
  String get galleryMonthJuly => 'juillet';

  @override
  String get galleryMonthAugust => 'août';

  @override
  String get galleryMonthSeptember => 'septembre';

  @override
  String get galleryMonthOctober => 'octobre';

  @override
  String get galleryMonthNovember => 'novembre';

  @override
  String get galleryMonthDecember => 'décembre';

  @override
  String get galleryMonthShortJan => 'janv.';

  @override
  String get galleryMonthShortFeb => 'févr.';

  @override
  String get galleryMonthShortMar => 'mars';

  @override
  String get galleryMonthShortApr => 'avr.';

  @override
  String get galleryMonthShortMay => 'mai';

  @override
  String get galleryMonthShortJun => 'juin';

  @override
  String get galleryMonthShortJul => 'juil.';

  @override
  String get galleryMonthShortAug => 'août';

  @override
  String get galleryMonthShortSep => 'sept.';

  @override
  String get galleryMonthShortOct => 'oct.';

  @override
  String get galleryMonthShortNov => 'nov.';

  @override
  String get galleryMonthShortDec => 'déc.';

  @override
  String galleryDateMonthDay(String month, int day) {
    return '$day $month';
  }

  @override
  String galleryDateMonthDayYear(String month, int day, int year) {
    return '$day $month $year';
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
  String get galleryBucketFood => 'Repas';

  @override
  String get galleryBucketPets => 'Animaux de compagnie';

  @override
  String get galleryBucketAnimals => 'Animaux';

  @override
  String get galleryBucketNature => 'Nature';

  @override
  String get galleryBucketOcean => 'Océan';

  @override
  String get galleryBucketSky => 'Ciel';

  @override
  String get galleryBucketNight => 'Nuit';

  @override
  String get galleryBucketArchitecture => 'Architecture';

  @override
  String get galleryBucketTransport => 'Transports';

  @override
  String get galleryBucketDocuments => 'Documents';

  @override
  String get galleryBucketCelebrations => 'Fêtes';

  @override
  String get galleryBucketArt => 'Art';

  @override
  String get galleryDetailsDiscardTitle => 'Abandonner vos modifications ?';

  @override
  String get galleryDetailsDiscardBody =>
      'Le nom et la date que vous avez saisis seront perdus.';

  @override
  String get galleryDetailsKeepEditing => 'Continuer la modification';

  @override
  String get galleryDetailsDiscard => 'Abandonner';

  @override
  String get galleryDetailsEditTitle => 'Modifier les détails';

  @override
  String get galleryDetailsEditTooltip => 'Modifier le nom et la date';

  @override
  String get galleryDetailsEditDisabled =>
      'La modification n’est disponible que dans l’application de bureau';

  @override
  String get galleryDetailsCloseTooltip => 'Fermer les détails';

  @override
  String get galleryDetailsSectionFile => 'Fichier';

  @override
  String get galleryDetailsSectionPicture => 'Photo';

  @override
  String get galleryDetailsSectionRecognised => 'Reconnu';

  @override
  String get galleryDetailsFormat => 'Format';

  @override
  String get galleryDetailsStored => 'Stockage';

  @override
  String get galleryDetailsOnlineOnly => 'En ligne uniquement — pas sur ce PC';

  @override
  String get galleryDetailsFolder => 'Dossier';

  @override
  String get galleryDetailsTaken => 'Prise le';

  @override
  String get galleryDetailsDimensions => 'Dimensions';

  @override
  String get galleryDetailsLength => 'Durée';

  @override
  String get galleryDetailsLocation => 'Lieu';

  @override
  String galleryDetailsFaces(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count visages',
      one: '1 visage',
    );
    return '$_temp0';
  }

  @override
  String get galleryDetailsFileName => 'Nom du fichier';

  @override
  String get galleryDetailsDateTaken => 'Date de prise de vue';

  @override
  String galleryDetailsKeepExtension(String extension) {
    return 'Gardez l’extension .$extension.';
  }

  @override
  String get galleryDetailsDateNote =>
      'Enregistrée comme date du fichier sur le disque. La photo elle-même n’est pas réenregistrée, donc rien n’est recompressé.';

  @override
  String get galleryDetailsSaving => 'Enregistrement…';

  @override
  String get galleryDetailsCopyPath => 'Copier le chemin du dossier';

  @override
  String get galleryDetailsPathCopied => 'Chemin copié';

  @override
  String get galleryEditNameEmpty => 'Un fichier doit avoir un nom.';

  @override
  String get galleryEditNameTooLong =>
      'Ce nom est trop long — gardez-le sous 250 caractères.';

  @override
  String galleryEditNameIllegal(String characters) {
    return 'Un nom de fichier ne peut pas contenir $characters';
  }

  @override
  String get galleryEditNameDot =>
      'Un nom commençant par un point cacherait le fichier.';

  @override
  String get galleryEditNameTrailing =>
      'Les noms ne peuvent pas se terminer par un point ou une espace.';

  @override
  String galleryEditNameReserved(String name) {
    return '« $name » est un nom réservé par Windows. Choisissez-en un autre.';
  }

  @override
  String galleryEditKeepExtension(String extension) {
    return 'Gardez l’extension .$extension — la modifier empêche l’ouverture du fichier.';
  }

  @override
  String get galleryEditFileGone => 'Ce fichier n’est plus là.';

  @override
  String get galleryEditNameTaken =>
      'Un fichier portant ce nom existe déjà dans ce dossier.';

  @override
  String galleryEditRenameFailed(String reason) {
    return 'Windows n’a pas pu le renommer : $reason';
  }

  @override
  String get galleryEditDateFuture => 'Cette date est dans le futur.';

  @override
  String get galleryEditDateTooOld =>
      'La photographie n’existait pas encore à cette date.';

  @override
  String galleryEditDateFailed(String reason) {
    return 'La date n’a pas pu être enregistrée : $reason';
  }

  @override
  String get galleryMapTitle => 'Carte des photos';

  @override
  String galleryMapPlacedSoFar(int placed) {
    return '$placed placées pour l’instant — lecture des lieux en cours';
  }

  @override
  String galleryMapLocatedOfTotal(int located, int total) {
    return '$located sur $total ont un lieu';
  }

  @override
  String get galleryMapReading =>
      'Lecture des lieux où vos photos ont été prises…';

  @override
  String get galleryMapEmptyTitle => 'Aucune photo avec un lieu';

  @override
  String get galleryMapEmptyBody =>
      'Les photos ne contiennent des coordonnées que si le géomarquage était activé sur l’appareil au moment de la prise de vue.';

  @override
  String galleryMapClusterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos ici',
      one: '1 photo ici',
    );
    return '$_temp0';
  }

  @override
  String get galleryPageAddFolderDialogTitle =>
      'Ajouter un dossier à la galerie';

  @override
  String get galleryPageScanOneFolderDialogTitle =>
      'Analyser uniquement ce dossier';

  @override
  String get galleryPageNoFoldersYet =>
      'Aucun dossier trouvé pour l\'instant — attendez la fin du premier scan.';

  @override
  String get galleryPageScanOneFolder => 'Analyser un dossier';

  @override
  String get galleryPageScanOneFolderBody =>
      'Tout ce qui se trouve dans le dossier choisi est inclus, sous-dossiers compris. Rien d\'autre n\'est examiné.';

  @override
  String get galleryPageWholeLibrary => 'Toute la bibliothèque';

  @override
  String galleryPageRenamePersonTitle(String name) {
    return 'Nom pour $name';
  }

  @override
  String get galleryPageRenameHint => 'ex. Maman, Alex…';

  @override
  String galleryPageSortingProgress(int count, int total) {
    return 'Tri des photos dans Personnes et Catégories — $count sur $total';
  }

  @override
  String get galleryPageSortingStarting =>
      'Tri des photos dans Personnes et Catégories…';

  @override
  String get galleryPageWaitingPermission => 'En attente de l\'autorisation…';

  @override
  String get galleryPageFindingPhotos => 'Recherche de vos photos et vidéos…';

  @override
  String get galleryPageLibraryUnreadable =>
      'La bibliothèque n\'a pas pu être lue';

  @override
  String get galleryPageNoMediaYet => 'Aucune photo ni vidéo pour l\'instant';

  @override
  String galleryPageNothingInRoot(String root) {
    return 'Rien dans $root. La galerie n\'analyse que ce dossier.';
  }

  @override
  String get galleryPageAnythingShowsHere =>
      'Tout ce que vous prenez ou téléchargez apparaît ici.';

  @override
  String get galleryPageRescan => 'Réanalyser';

  @override
  String get galleryPageSectionAlbums => 'Albums';

  @override
  String get galleryPageSectionMoreAlbums => 'Autres albums';

  @override
  String get galleryPageSectionSmartAlbums => 'Albums intelligents';

  @override
  String get galleryPageMemories => 'Souvenirs';

  @override
  String get galleryPageNoneYet => 'Aucun pour l\'instant';

  @override
  String galleryPageTripCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voyages',
      one: '1 voyage',
    );
    return '$_temp0';
  }

  @override
  String get galleryPagePeople => 'Personnes';

  @override
  String get galleryPageNoneFoundYet => 'Rien trouvé pour l\'instant';

  @override
  String galleryPagePersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personnes',
      one: '1 personne',
    );
    return '$_temp0';
  }

  @override
  String get galleryPageCategories => 'Catégories';

  @override
  String galleryPageCategoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count catégories',
      one: '1 catégorie',
    );
    return '$_temp0';
  }

  @override
  String get galleryPagePeopleAndCategories => 'Personnes et catégories';

  @override
  String get galleryPageIncludedWithNova => 'Inclus avec Nova';

  @override
  String galleryItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments',
      one: '1 élément',
    );
    return '$_temp0';
  }

  @override
  String get galleryPageCategoryFallback => 'Catégorie';

  @override
  String get galleryPageNoOneRecognised => 'Personne n\'a encore été reconnu';

  @override
  String get galleryPagePeopleStillSorting =>
      'Tri de la bibliothèque en cours : les personnes apparaissent ici dès qu\'un visage figure dans quelques photos.';

  @override
  String get galleryPagePeopleSortHint =>
      'Triez la bibliothèque depuis l\'écran des albums : les personnes qui apparaissent ensemble dans quelques photos seront affichées ici.';

  @override
  String get galleryPageNoTripsYet => 'Aucun voyage pour l\'instant';

  @override
  String get galleryPageNoTripsBody =>
      'Une série de photos prises pendant quelques jours chargés — un week-end, des vacances — apparaît ici automatiquement. Rien à configurer, et cela fonctionne sans Nova.';

  @override
  String get galleryPageNothingSortedYet => 'Rien n\'est encore trié';

  @override
  String get galleryPageStillLooking => 'Analyse de la bibliothèque en cours.';

  @override
  String get galleryPageSortToFill =>
      'Triez la bibliothèque depuis l\'écran des albums pour les remplir.';

  @override
  String galleryPageScanCountOf(int scanned, int total) {
    return '$scanned sur $total';
  }

  @override
  String galleryPageItemsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments trouvés',
      one: '1 élément trouvé',
    );
    return '$_temp0';
  }

  @override
  String get galleryPageReadingLibrary => 'Lecture de votre bibliothèque…';

  @override
  String galleryPageItemCountReadingLocations(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments · lecture des lieux',
      one: '1 élément · lecture des lieux',
    );
    return '$_temp0';
  }

  @override
  String get galleryPageSelectToSend => 'Sélectionner des photos à envoyer';

  @override
  String get galleryPageAddFolder => 'Ajouter un dossier';

  @override
  String get galleryPageScanOneFolderOnly => 'Analyser un seul dossier';

  @override
  String get galleryPagePhotoMap => 'Carte des photos';

  @override
  String get galleryPageTapToPick => 'Touchez les photos pour les choisir';

  @override
  String galleryPageSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sélectionnés',
      one: '1 sélectionné',
    );
    return '$_temp0';
  }

  @override
  String get galleryPageNothingInAlbum => 'Rien dans cet album';

  @override
  String get galleryPageLandHere =>
      'Les photos apparaissent ici dès qu\'il y en a.';

  @override
  String get galleryPageFolderGone => 'Ce dossier n\'existe plus';

  @override
  String get galleryPageNoPictureFolders => 'Aucun dossier d\'images trouvé';

  @override
  String get galleryPageNeedsAccess =>
      'La galerie a besoin d\'accéder à vos photos';

  @override
  String galleryPageScanRootUnreadable(String root) {
    return 'La galerie n\'analyse que $root, et ce dossier ne peut plus être lu.';
  }

  @override
  String get galleryPageNothingFoundPoint =>
      'Rien n\'a été trouvé dans Images, Vidéos ou Téléchargements. Indiquez un dossier à la galerie et elle l\'analysera à la place.';

  @override
  String get galleryPageStaysOnDevice =>
      'Les photos et vidéos restent sur cet appareil : la galerie ne les lit que pour les afficher ici.';

  @override
  String get galleryPageScanEverything => 'Tout analyser';

  @override
  String get galleryPagePickAnotherFolder => 'Choisir un autre dossier';

  @override
  String get galleryPageAllowAccess => 'Autoriser l\'accès';

  @override
  String get galleryPageOpenSettings => 'Ouvrir les paramètres';

  @override
  String galleryPageOnlyScanningRoot(String root) {
    return 'Analyse uniquement $root et tout ce qu\'il contient.';
  }

  @override
  String get galleryPageChange => 'Modifier';

  @override
  String get galleryPageLimitedAccess =>
      'Seules les photos que vous avez choisies sont partagées avec luma.';

  @override
  String get galleryPageSelectMore => 'En sélectionner d\'autres';

  @override
  String galleryPageSortingPhotosProgress(int count, int total) {
    return 'Tri des photos — $count sur $total';
  }

  @override
  String galleryPageReadingDetails(int count) {
    return 'Lecture des détails des photos — encore $count';
  }

  @override
  String get galleryPageUpToDate => 'Personnes et catégories sont à jour';

  @override
  String galleryPageLookedAt(int examined) {
    String _temp0 = intl.Intl.pluralLogic(
      examined,
      locale: localeName,
      other: '$examined photos examinées.',
      one: '1 photo examinée.',
    );
    return '$_temp0';
  }

  @override
  String galleryPageLookedAtSkipped(int examined, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      examined,
      locale: localeName,
      other: '$examined photos examinées',
      one: '1 photo examinée',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skipped,
      locale: localeName,
      other: '$skipped ont été ignorées',
      one: '1 a été ignorée',
    );
    return '$_temp0. $_temp1 car elles sont uniquement dans le cloud ou dans un format illisible ici : rendez-les disponibles hors ligne et relancez l\'analyse.';
  }

  @override
  String get galleryPageLookAgain => 'Analyser à nouveau';

  @override
  String galleryPageSmartDownloadDesktop(int pending, int megabytes) {
    String _temp0 = intl.Intl.pluralLogic(
      pending,
      locale: localeName,
      other: '$pending photos à examiner.',
      one: '1 photo à examiner.',
    );
    return '$_temp0 Cela télécharge une seule fois environ $megabytes Mo de modèles (reconnaissance et correspondance des visages) ; ensuite, tout se passe sur ce PC, hors ligne — aucune photo n\'est envoyée.';
  }

  @override
  String galleryPageSmartDownloadPhone(int pending, int megabytes) {
    String _temp0 = intl.Intl.pluralLogic(
      pending,
      locale: localeName,
      other: '$pending photos à examiner.',
      one: '1 photo à examiner.',
    );
    return '$_temp0 Cela télécharge une seule fois un petit modèle (~$megabytes Mo) de correspondance des visages, pour regrouper les photos d\'une même personne — hors ligne, et rien n\'est envoyé.';
  }

  @override
  String galleryPageSmartRemaining(int pending) {
    String _temp0 = intl.Intl.pluralLogic(
      pending,
      locale: localeName,
      other: '$pending photos restent à examiner.',
      one: '1 photo reste à examiner.',
    );
    return '$_temp0 S\'exécute sur cet appareil, hors ligne, et reprend là où elle s\'est arrêtée.';
  }

  @override
  String get galleryPageTryAgain => 'Réessayer';

  @override
  String get galleryPageGetModels => 'Télécharger les modèles';

  @override
  String get galleryPageSortThem => 'Les trier';

  @override
  String get galleryPageSmartUpsellTitle =>
      'Personnes et catégories sont un plus de Nova';

  @override
  String get galleryPageSmartUpsellBodyModels =>
      'Nova regroupe vos photos selon les personnes présentes et ce qui figure réellement sur l\'image — nourriture, animaux, océan et plus encore — grâce à des modèles qui tournent hors ligne sur cet appareil. Rien n\'est envoyé.';

  @override
  String get galleryPageSmartUpsellBodyPhone =>
      'Nova regroupe vos photos selon leur contenu. Le jeu complet de catégories nécessite les modèles de la version téléphone ; cet appareil obtient tout de même Panoramas et Lieux gratuitement.';

  @override
  String galleryPageUpgradeTo(String plan) {
    return 'Passer à $plan';
  }

  @override
  String get gallerySmartSelfies => 'Autoportraits';

  @override
  String get gallerySmartGroupShots => 'Photos de groupe';

  @override
  String get gallerySmartPanoramas => 'Panoramas';

  @override
  String get gallerySmartPlaces => 'Lieux';

  @override
  String galleryPersonDefaultName(int id) {
    return 'Personne $id';
  }

  @override
  String galleryMediaItemDefaultName(String id) {
    return 'Élément $id';
  }

  @override
  String get galleryRepoModelsNotStarted =>
      'Les modèles des albums intelligents n\'ont pas pu être démarrés.';

  @override
  String get galleryRepoRenameDesktopOnly =>
      'Les fichiers ne peuvent être renommés que dans l\'application de bureau.';

  @override
  String galleryViewerCouldNotOpenVideo(String message) {
    return 'Impossible d\'ouvrir la vidéo : $message';
  }

  @override
  String get galleryViewerDefaultFolder => 'Photos';

  @override
  String galleryViewerPosition(int current, int total) {
    return '$current sur $total';
  }

  @override
  String get galleryViewerFileNotOpened =>
      'Ce fichier n\'a pas pu être ouvert.';

  @override
  String get galleryViewerImageNotDecoded =>
      'Cette image n\'a pas pu être décodée.';

  @override
  String get galleryViewerCloudOnlyTitle => 'Celui-ci n\'est que dans le cloud';

  @override
  String galleryViewerCloudOnlyBody(String name) {
    return '$name est stocké en ligne et ne se trouve pas sur ce PC. L\'afficher le télécharge et le garde ici jusqu\'à ce que votre application cloud le libère à nouveau.';
  }

  @override
  String galleryViewerCloudOnlyBodySized(String name, String size) {
    return '$name est stocké en ligne et ne se trouve pas sur ce PC. L\'afficher le télécharge ($size) et le garde ici jusqu\'à ce que votre application cloud le libère à nouveau.';
  }

  @override
  String get galleryViewerDownloadAndShow => 'Télécharger et afficher';

  @override
  String galleryViewerPlay(String duration) {
    return 'Lire $duration';
  }

  @override
  String get galleryViewerSendToDevices => 'Envoyer à mes appareils';

  @override
  String get galleryViewerHideDetails => 'Masquer les détails';

  @override
  String get galleryViewerShowDetails => 'Afficher les détails';

  @override
  String get galleryModelPurposeLabelling => 'modèle d\'étiquetage d\'images';

  @override
  String get galleryModelPurposeFaceDetection =>
      'modèle de détection de visages';

  @override
  String get galleryModelPurposeFaceRecognition =>
      'modèle de reconnaissance faciale';

  @override
  String galleryModelDownloading(String model) {
    return 'Téléchargement du $model';
  }

  @override
  String galleryModelHttpError(String model, int status) {
    return 'Le $model n\'a pas pu être téléchargé (HTTP $status).';
  }

  @override
  String galleryModelEmptyFile(String model) {
    return 'Le $model a été téléchargé sous forme de fichier vide.';
  }

  @override
  String galleryModelDownloadFailed(String model, String error) {
    return 'Le $model n\'a pas pu être téléchargé : $error';
  }

  @override
  String get galleryModelReady => 'Prêt';

  @override
  String get galleryModelStarting => 'Démarrage des modèles';

  @override
  String get gameToolsPriceTrackerBlurb => 'Votre bibliothèque, avec les prix';

  @override
  String get gameToolsCs2MarketLabel => 'Marché CS2';

  @override
  String get gameToolsCs2MarketBlurb => 'Skins, prix et graphiques';

  @override
  String get gameToolsSellingCalculatorLabel => 'Calculateur de vente';

  @override
  String get gameToolsSellingCalculatorBlurb =>
      'Estimer les gains de vente CS2';

  @override
  String get gameToolsMafiaBlurb => 'Comptage des rôles';

  @override
  String gameToolsComingSoonTitle(String game) {
    return 'Les outils $game arrivent bientôt';
  }

  @override
  String gameToolsComingSoonSubtitle(String game) {
    return 'C\'est ici que se trouveront les aides pour $game. Rien à configurer pour l\'instant — elles apparaîtront ici dans une future mise à jour.';
  }

  @override
  String gameToolsToolCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count outils',
      one: '1 outil',
    );
    return '$_temp0';
  }

  @override
  String gameToolsSectionTooltip(String label, String blurb) {
    return '$label — $blurb';
  }

  @override
  String get groceriesApiEnterFullAddress =>
      'Saisissez l\'adresse complète du serveur, par ex. https://groceries.example.com';

  @override
  String get groceriesApiOnlyHttp =>
      'Seules les adresses http(s) sont prises en charge.';

  @override
  String get groceriesApiPlainHttp =>
      'Le http simple n\'est autorisé que pour les serveurs locaux ou du réseau domestique. Utilisez https:// pour les serveurs sur Internet.';

  @override
  String groceriesApiServerError(String code) {
    return 'Le serveur de courses a renvoyé une erreur ($code).';
  }

  @override
  String groceriesApiNeedsAccount(String section) {
    return 'La recherche de produits nécessite un compte luma approuvé. Créez-en un dans Paramètres → $section — votre liste de courses continue de fonctionner hors ligne.';
  }

  @override
  String get groceriesApiTimeout =>
      'Le serveur de courses a mis trop de temps à répondre.';

  @override
  String groceriesApiUnreachable(String url) {
    return 'Impossible de joindre le serveur de courses à $url. Vérifiez l\'adresse dans les paramètres.';
  }

  @override
  String get groceriesApiBadResponse =>
      'Le serveur de courses a renvoyé une réponse inattendue.';

  @override
  String get groceriesApiCouldNotReach =>
      'Impossible de joindre le serveur de courses.';

  @override
  String get groceriesTitle => 'Courses';

  @override
  String get groceriesGateTitle =>
      'La liste de courses est incluse avec Orbit et Nova';

  @override
  String get groceriesGateSubtitle =>
      'Comparez les prix de Jumbo, Albert Heijn, Hoogvliet et Lidl côte à côte, et créez des listes de courses qui se répartissent d\'elles-mêmes par magasin et par rayon, avec les totaux en continu — inclus gratuitement avec Orbit et Nova.';

  @override
  String groceriesUpgradeTo(String plan) {
    return 'Passer à $plan';
  }

  @override
  String get groceriesOverviewSubtitle =>
      'Recherchez des produits chez Jumbo, Albert Heijn, Hoogvliet et Lidl, et créez des listes de courses réparties par magasin.';

  @override
  String get groceriesNewList => 'Nouvelle liste';

  @override
  String get groceriesNoListsTitle => 'Aucune liste pour l\'instant';

  @override
  String get groceriesNoListsSubtitle =>
      'Créez une liste, puis recherchez des produits à y ajouter.';

  @override
  String get groceriesCreateFirstList => 'Créer votre première liste';

  @override
  String groceriesItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles',
      one: '1 article',
    );
    return '$_temp0';
  }

  @override
  String groceriesDeleteListTitle(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get groceriesDeleteListBody =>
      'Cela supprime la liste et tout ce qu\'elle contient. Cette action est irréversible.';

  @override
  String get groceriesListNameHint => 'Nom de la liste';

  @override
  String get groceriesRenameList => 'Renommer la liste';

  @override
  String get groceriesBackToLists => 'Retour aux listes';

  @override
  String get groceriesListFallbackTitle => 'Liste';

  @override
  String get groceriesAddProducts => 'Ajouter des produits';

  @override
  String get groceriesNoItemsTitle => 'Aucun article pour l\'instant';

  @override
  String get groceriesNoItemsSubtitle =>
      'Recherchez des produits pour les ajouter à cette liste.';

  @override
  String get groceriesAllStores => 'Tous les magasins';

  @override
  String get groceriesSortPriceAsc => 'Prix ↑';

  @override
  String get groceriesSortPriceDesc => 'Prix ↓';

  @override
  String groceriesAddedToList(String name) {
    return '« $name » ajouté à votre liste';
  }

  @override
  String get groceriesBackToList => 'Retour à la liste';

  @override
  String get groceriesServerAddress => 'Adresse du serveur de courses';

  @override
  String get groceriesSearchProductsHint => 'Rechercher des produits…';

  @override
  String get groceriesCouldNotLoad => 'Impossible de charger les produits';

  @override
  String get groceriesNoProductsTitle => 'Aucun produit trouvé';

  @override
  String get groceriesNoProductsSubtitle =>
      'Essayez un autre terme de recherche, magasin ou filtre de catégorie.';

  @override
  String get groceriesAllProducts => 'Tous les produits';

  @override
  String get groceriesCategories => 'Catégories';

  @override
  String get groceriesOnlyDeals => 'Promotions uniquement';

  @override
  String get groceriesSale => 'Promo';

  @override
  String get mlTabCreatureLab => 'Laboratoire de créatures';

  @override
  String get mlTabHowItWorks => 'Fonctionnement';

  @override
  String get mlSubtitle =>
      'Dessinez un corps, laissez l\'évolution trouver le mouvement.';

  @override
  String get mlHowStep1Title => 'Votre dessin devient un corps';

  @override
  String get mlHowStep1Body =>
      'Chaque trait est tamponné avec une épaisseur et fusionné avec les autres là où ils se touchent. L\'ensemble est aminci jusqu\'à sa ligne centrale, ce qui forme un graphe d\'os posé exactement sur ce qui a été dessiné : un anneau reste un anneau, un bonhomme en bâtonnets reste un bonhomme en bâtonnets. Les petites pointes dues aux tremblements sont élaguées, les courbes gardent une articulation et les segments droits non, et le résultat est limité à dix-huit os pour que la recherche reste assez petite pour aboutir.';

  @override
  String get mlHowStep2Title => 'Les os reçoivent des moteurs';

  @override
  String get mlHowStep2Body =>
      'Les os sont rigides et maintenus ensemble par des contraintes de distance. Là où deux os se rejoignent se trouve une articulation, et chaque articulation est un ressort-amortisseur qui poursuit un angle cible oscillant comme une onde sinusoïdale : repos + centre + amplitude x sin(2 pi f t + phase). Une articulation a une limite de résistance, le sol a un frottement de Coulomb ordinaire, et rien de ce que la créature fait à elle-même ne peut déplacer son centre de masse. Le mouvement vers l\'avant doit être forcé.';

  @override
  String get mlHowStep3Title => 'La démarche est le génome';

  @override
  String get mlHowStep3Body =>
      'Un gène fixe la fréquence à laquelle tout le corps fait ses pas, puis chaque articulation en reçoit trois : son amplitude, sa position dans le cycle et l\'angle autour duquel elle oscille. Cette poignée de nombres constitue tout le système nerveux. Il n\'y a pas de cerveau qui réagit au monde, seulement un rythme, ce qui explique qu\'une bonne démarche paraisse obstinée.';

  @override
  String get mlHowStep4Title =>
      'Soixante d\'entre eux tournent à chaque génération';

  @override
  String get mlHowStep4Body =>
      'Chaque créature a un essai de vingt-cinq secondes, noté selon les mètres parcourus, pénalisé pour le temps passé la tête au sol, avec un bonus pour chaque seconde gagnée une fois les 50 m franchis. Les quatre meilleurs survivent sans changement, cinq génomes aléatoires neufs rejoignent chaque tour pour éviter que la population ne stagne, et le reste est issu de sélection par tournoi, de croisement uniforme et de mutation gaussienne.';

  @override
  String get mlHowStep5Title => 'Et ça grimpe';

  @override
  String get mlHowStep5Body =>
      'La meilleure courbe monte vite puis s\'aplatit, parce que la recherche a trouvé une astuce locale et la peaufine. La courbe moyenne reste irrégulière et bien plus basse : c\'est la mutation qui jette encore la plupart de ses essais. Recommencer relance les dés, et le même corps apprend souvent une marche complètement différente.';

  @override
  String get mlHowFooter =>
      'Tout fonctionne sur cet appareil. La population est évaluée dans des isolats d\'arrière-plan, pour que la marche que vous regardez reste fluide pendant que la génération suivante est notée.';

  @override
  String get mlStepDrawCreature => 'Dessinez votre créature';

  @override
  String get mlTooSmall => 'trop petit';

  @override
  String get mlSkeletonFound => 'squelette trouvé';

  @override
  String get mlStartFromExample => 'PARTIR D\'UN EXEMPLE';

  @override
  String get mlPresetBlob => 'Blob';

  @override
  String get mlPresetPerson => 'Personne';

  @override
  String get mlPresetLetterA => 'Lettre A';

  @override
  String get mlPresetSpider => 'Araignée';

  @override
  String get mlPresetDog => 'Chien';

  @override
  String get mlPresetWorm => 'Ver';

  @override
  String get mlBodies => 'Corps';

  @override
  String get mlJoints => 'Articulations';

  @override
  String get mlGenes => 'Gènes';

  @override
  String get mlDrawHelp =>
      'Les traits reçoivent une épaisseur et sont reliés là où ils se touchent, puis amincis jusqu\'à une ligne centrale : les capsules lavande sont les os, les points verts les articulations, l\'ambre la tête. Redessiner relance la recherche depuis le début.';

  @override
  String get mlShowDrawing => 'Afficher le dessin';

  @override
  String get mlFollowLatest => 'Suivre le dernier';

  @override
  String get mlStopNever => 'jamais';

  @override
  String get mlPauseEvolution => 'Suspendre l\'évolution';

  @override
  String get mlResumeEvolution => 'Reprendre l\'évolution';

  @override
  String get mlRestart => 'Recommencer';

  @override
  String get mlReplaySpeed => 'Vitesse de rejeu';

  @override
  String get mlWorkers => 'Travailleurs';

  @override
  String get mlStopAfter => 'Arrêter après';

  @override
  String get mlWatchGeneration => 'Voir la génération';

  @override
  String mlGenerationNumber(String number) {
    return 'Génération $number';
  }

  @override
  String mlGenerationOf(String current, String total) {
    return 'génération $current sur $total';
  }

  @override
  String mlStoppedAtLimit(String limit) {
    return 'arrêté à $limit — augmentez « arrêter après » pour continuer';
  }

  @override
  String mlBestDistance(String distance, String generation) {
    return 'meilleur $distance m (gén. $generation)';
  }

  @override
  String mlGenPerSecond(String rate) {
    return '$rate gén/s';
  }

  @override
  String mlWorkerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count travailleurs',
      one: '1 travailleur',
    );
    return '$_temp0';
  }

  @override
  String mlReachedGoal(String seconds) {
    return '50 m atteints en $seconds s';
  }

  @override
  String get mlChartHintDraw =>
      'Dessinez une créature pour lancer la recherche.';

  @override
  String get mlChartHintTap =>
      'Touchez le graphique pour revoir la marche de n\'importe quelle génération.';

  @override
  String get mlFitnessTitle => 'Performance au fil des générations';

  @override
  String get mlLegendBest => 'Meilleur';

  @override
  String get mlEmptyWalkTitle => 'Rien à faire marcher pour l\'instant';

  @override
  String get mlEmptyWalkBody =>
      'Dessinez un corps à gauche et la recherche démarre toute seule.';

  @override
  String get mlHudDistance => 'DISTANCE';

  @override
  String get mlHudTime => 'TEMPS';

  @override
  String get mlHudHeadDown => 'TÊTE BASSE';

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
      'Zone de dessin. Dessinez une créature avec un ou plusieurs traits.';

  @override
  String get mlBoardEmptyTitle => 'Dessinez un corps ici';

  @override
  String get mlBoardEmptySubtitle => 'ou partez d\'un exemple ci-dessous';

  @override
  String get mlChartEmpty => 'Chaque génération laissera une trace ici.';

  @override
  String mlChartSemantics(int count, String metres) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count générations',
      one: '1 génération',
    );
    return 'Performance sur $_temp0. Meilleur : $metres mètres.';
  }

  @override
  String get mlMetresAxis => 'mètres';

  @override
  String mlChartGen(String number) {
    return 'gén. $number';
  }

  @override
  String get mlWalkTitle => 'La marche jusqu\'à 50 mètres';

  @override
  String get mediaDlHistoryInvalidSnapshot =>
      'Instantané de l\'historique de téléchargement invalide.';

  @override
  String get mediaDlStatusDownloadingYtDlp => 'Téléchargement de yt-dlp…';

  @override
  String get mediaDlStatusDownloadingFfmpeg => 'Téléchargement de ffmpeg…';

  @override
  String get mediaDlStatusExtractingFfmpeg => 'Extraction de ffmpeg…';

  @override
  String get mediaDlStatusReady => 'Prêt';

  @override
  String get mediaDlStatusUpdatingYtDlp => 'Mise à jour de yt-dlp…';

  @override
  String get mediaDlFfmpegNotInDownload =>
      'Impossible de trouver ffmpeg.exe dans le téléchargement.';

  @override
  String get mediaDlFfmpegNotOnPath =>
      'ffmpeg est introuvable dans votre PATH. Installez-le avec votre gestionnaire de paquets (par ex. sudo apt install ffmpeg), puis réessayez.';

  @override
  String mediaDlHttpFailed(String status, String url) {
    return 'Échec du téléchargement ($status) pour $url.';
  }

  @override
  String mediaDlCouldNotReach(String url) {
    return 'Impossible d\'atteindre $url. Vérifiez votre connexion.';
  }

  @override
  String get mediaDlToolsNotReady =>
      'Les outils ne sont pas encore configurés.';

  @override
  String get mediaDlCouldNotReadInfo =>
      'Impossible de lire les informations de la vidéo.';

  @override
  String get mediaDlCouldNotParseInfo =>
      'Impossible d\'analyser les informations de la vidéo.';

  @override
  String get mediaDlYtDlpUnknownError =>
      'yt-dlp a échoué pour une raison inconnue.';

  @override
  String get mediaDlSetupTitle => 'Configuration de Media Downloader';

  @override
  String get mediaDlSetupBody =>
      'Récupération de yt-dlp et ffmpeg — cela ne se produit qu\'une fois.';

  @override
  String get mediaDlSetupFailed => 'Impossible de configurer yt-dlp / ffmpeg.';

  @override
  String get mediaDlPasteLinkFirst => 'Collez d\'abord un lien YouTube.';

  @override
  String get mediaDlCouldNotReadLink => 'Impossible de lire ce lien.';

  @override
  String get mediaDlCouldNotUpdate => 'Impossible de mettre à jour yt-dlp.';

  @override
  String get mediaDlChooseFolderTitle => 'Choisir un dossier de téléchargement';

  @override
  String get mediaDlChooseFolderFirst =>
      'Choisissez d\'abord un dossier de téléchargement.';

  @override
  String get mediaDlStarting => 'Démarrage…';

  @override
  String get mediaDlDownloadFailed => 'Échec du téléchargement.';

  @override
  String get mediaDlIntroTitle => 'Télécharger une vidéo ou un morceau';

  @override
  String get mediaDlUpdateYtDlp => 'Mettre à jour yt-dlp';

  @override
  String get mediaDlUpdating => 'Mise à jour…';

  @override
  String mediaDlIntroBody(String updateLabel) {
    return 'Collez un lien de vidéo YouTube pour commencer. Si les téléchargements échouent avec une erreur 403, YouTube a probablement changé quelque chose : essayez « $updateLabel » ci-dessus.';
  }

  @override
  String get mediaDlLinkHint => 'Lien de vidéo YouTube…';

  @override
  String get mediaDlFetch => 'Récupérer';

  @override
  String get mediaDlResolution => 'Résolution';

  @override
  String get mediaDlAudioBitrate => 'Débit audio';

  @override
  String get mediaDlFormat => 'Format';

  @override
  String get mediaDlBitrate => 'Débit';

  @override
  String get mediaDlModeVideo => 'Vidéo';

  @override
  String get mediaDlModeAudio => 'Audio';

  @override
  String get mediaDlModeAudioOnly => 'Audio uniquement';

  @override
  String get mediaDlSaveTo => 'Enregistrer dans';

  @override
  String get mediaDlChooseFolder => 'Choisir un dossier…';

  @override
  String get mediaDlWorking => 'En cours…';

  @override
  String mediaDlEta(String eta) {
    return 'ETA $eta';
  }

  @override
  String mediaDlKbps(int kbps) {
    return '$kbps kbit/s';
  }

  @override
  String get mediaDlHistory => 'Historique';

  @override
  String get mediaDlHistoryEmpty => 'Rien n\'a encore été téléchargé';

  @override
  String get mediaDlHistoryEmptyHint =>
      'Les téléchargements terminés apparaissent ici.';

  @override
  String get mediaDlOpenFolder => 'Ouvrir le dossier';

  @override
  String get mediaDlRemoveFromHistory => 'Retirer de l\'historique';

  @override
  String get mindMapExportCanvasNotReady =>
      'Le canevas n\'est pas encore prêt à être capturé.';

  @override
  String get mindMapExportEncodeFailed => 'L\'image n\'a pas pu être encodée.';

  @override
  String get mindMapExportSaveImageTitle =>
      'Enregistrer l\'image de la carte mentale';

  @override
  String get mindMapExportSaveOutlineTitle =>
      'Enregistrer le plan de la carte mentale';

  @override
  String mindMapExportFailed(String error) {
    return 'Échec de l\'exportation : $error';
  }

  @override
  String get mindMapDirectionRight => 'Droite';

  @override
  String get mindMapDirectionBoth => 'Des deux côtés';

  @override
  String get mindMapDirectionDown => 'Vers le bas';

  @override
  String mindMapDeleteMapTitle(String title) {
    return 'Supprimer « $title » ?';
  }

  @override
  String get mindMapDeleteMapEmpty =>
      'Cette carte est vide. Elle sera supprimée définitivement.';

  @override
  String mindMapDeleteMapNodes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Les $count nœuds de cette carte seront supprimés définitivement.',
      one: 'Le 1 nœud de cette carte sera supprimé définitivement.',
    );
    return '$_temp0';
  }

  @override
  String get mindMapNewMapHint => 'Nommez une nouvelle carte mentale';

  @override
  String get mindMapLibraryEmptyTitle => 'Aucune carte mentale pour l\'instant';

  @override
  String get mindMapLibraryEmptySubtitle =>
      'Nommez-en une ci-dessus. Vous commencez sur l\'idée centrale et appuyez sur Tab pour ramifier — inutile de glisser.';

  @override
  String get mindMapDeleteMapTooltip => 'Supprimer la carte';

  @override
  String mindMapNodeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nœuds',
      one: '1 nœud',
    );
    return '$_temp0';
  }

  @override
  String mindMapDeletedNamed(String label, int below) {
    String _temp0 = intl.Intl.pluralLogic(
      below,
      locale: localeName,
      other: '« $label » et $below en dessous supprimés',
      one: '« $label » et 1 en dessous supprimés',
      zero: '« $label » supprimé',
    );
    return '$_temp0';
  }

  @override
  String mindMapDeletedUnnamed(int below) {
    String _temp0 = intl.Intl.pluralLogic(
      below,
      locale: localeName,
      other: 'Un nœud et $below en dessous supprimés',
      one: 'Un nœud et 1 en dessous supprimés',
      zero: 'Un nœud supprimé',
    );
    return '$_temp0';
  }

  @override
  String get mindMapNewIdea => 'Nouvelle idée';

  @override
  String mindMapExpandHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Déplier $count nœuds masqués',
      one: 'Déplier 1 nœud masqué',
    );
    return '$_temp0';
  }

  @override
  String mindMapCollapseNodes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Replier $count nœuds',
      one: 'Replier 1 nœud',
    );
    return '$_temp0';
  }

  @override
  String mindMapShowHidden(int count) {
    return 'Afficher $count masqués';
  }

  @override
  String mindMapHideCount(int count) {
    return 'Masquer $count';
  }

  @override
  String get mindMapPasteOutline => 'Coller un plan';

  @override
  String get mindMapAddsAtRoot =>
      'Ajoute de nouvelles branches à la racine de cette carte.';

  @override
  String mindMapAddsUnder(String target) {
    return 'Ajoute sous « $target ».';
  }

  @override
  String get mindMapImportHint =>
      'Plan de lancement\n  Recherche\n    Concurrents\n  Conception\n  Livraison';

  @override
  String get mindMapImportHelp =>
      'L\'indentation crée les enfants. Tabulations ou espaces, puces, numéros et titres Markdown fonctionnent tous. Une ligne \"> \" devient une note.';

  @override
  String mindMapNodesWillBeAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nœuds seront ajoutés',
      one: '1 nœud sera ajouté',
    );
    return '$_temp0';
  }

  @override
  String get mindMapAddToMap => 'Ajouter à la carte';

  @override
  String get mindMapInspectorTitle => 'Détails du nœud';

  @override
  String get mindMapFieldLabel => 'Libellé';

  @override
  String get mindMapFieldNote => 'Note';

  @override
  String get mindMapFieldLink => 'Lien';

  @override
  String get mindMapFieldColour => 'Couleur';

  @override
  String get mindMapNoteHint => 'Tout ce qui n\'a pas sa place sur le canevas';

  @override
  String get mindMapInheritColour => 'Hériter de la couleur de la branche';

  @override
  String get mindMapColourSwatch => 'Nuance de couleur';

  @override
  String get mindMapInheritFromBranch => 'Hériter de la branche';

  @override
  String get mindMapAiAllowanceUsed =>
      'Vous avez utilisé votre quota d\'IA du jour — davantage demain.';

  @override
  String mindMapAiNoKey(String provider, String settings, String assistant) {
    return 'Aucune clé API enregistrée pour $provider. Ajoutez-en une dans $settings → $assistant pour utiliser cette fonction.';
  }

  @override
  String get mindMapAiNoSuggestions =>
      'Le modèle n\'a rien proposé d\'utilisable. Réessayez.';

  @override
  String mindMapAiSheetTitle(String label) {
    return 'Développer « $label »';
  }

  @override
  String mindMapAiSelected(int chosen, int total) {
    return '$chosen sur $total sélectionné(s)';
  }

  @override
  String get mindMapSuggestMore => 'Proposer davantage';

  @override
  String mindMapAddCount(int count) {
    return 'Ajouter $count';
  }

  @override
  String get mindMapCannotMoveIntoSelf =>
      'Un nœud ne peut pas être déplacé dans lui-même.';

  @override
  String get mindMapMenuAddChild => 'Ajouter un enfant';

  @override
  String get mindMapMenuAddSibling => 'Ajouter un frère';

  @override
  String get mindMapMenuDetails => 'Note, lien et couleur';

  @override
  String get mindMapMenuExpandAi => 'Développer avec l\'IA';

  @override
  String get mindMapMenuExpandBranch => 'Déplier la branche';

  @override
  String get mindMapMenuCollapseBranch => 'Replier la branche';

  @override
  String get mindMapMenuDeleteBranch => 'Supprimer la branche';

  @override
  String get mindMapTouchChild => 'Enfant';

  @override
  String get mindMapTouchSibling => 'Frère';

  @override
  String get mindMapAllMaps => 'Toutes les cartes';

  @override
  String get mindMapRenameMap => 'Renommer la carte';

  @override
  String mindMapLayoutTooltip(String direction) {
    return 'Disposition : $direction';
  }

  @override
  String get mindMapFitToScreenShortcut => 'Ajuster à l\'écran (Ctrl+0)';

  @override
  String get mindMapFitToScreen => 'Ajuster à l\'écran';

  @override
  String get mindMapExportMenuPng => 'Image (PNG)';

  @override
  String get mindMapExportMenuMarkdown => 'Plan (Markdown)';

  @override
  String get mindMapExportMenuOpml => 'Plan (OPML)';

  @override
  String get mindMapHintChild => 'enfant';

  @override
  String get mindMapHintSibling => 'frère';

  @override
  String get mindMapHintRename => 'renommer';

  @override
  String get mindMapHintFold => 'replier';

  @override
  String get mindMapHintMoveAround => 'se déplacer';

  @override
  String get mindMapHintArrows => 'Flèches';

  @override
  String get mindMapHintAltArrows => 'Alt+Flèches';

  @override
  String get mindMapHintReorder => 'réordonner';

  @override
  String get mindMapHintDelete => 'supprimer';

  @override
  String get mindMapHintDrag => 'Glisser';

  @override
  String get mindMapHintReparent => 'changer de parent';

  @override
  String get mindMapFirstBranchHintNarrow =>
      'Touchez le nœud central, puis Enfant';

  @override
  String get mindMapFirstBranchHint =>
      'Sélectionnez le nœud central et appuyez sur Tab pour ajouter votre première branche';

  @override
  String get mindMapEmptyNodeLabel => 'Nœud vide';

  @override
  String get mcCrashAiUsageLimit =>
      'Vous avez atteint la limite d\'utilisation de l\'IA pour aujourd\'hui — réessayez demain.';

  @override
  String mcCrashAiNoKey(String provider) {
    return 'Aucune clé API définie pour $provider. Ajoutez-en une dans Paramètres → Assistant IA.';
  }

  @override
  String get mcAssetIndexDownloadFailed =>
      'Impossible de télécharger l\'index des ressources.';

  @override
  String mcAssetIndexRequestFailed(String status) {
    return 'La requête d\'index des ressources a échoué ($status).';
  }

  @override
  String get mcCurseForgeNeedsKey =>
      'CurseForge nécessite une clé API. Ajoutez-en une pour parcourir CurseForge.';

  @override
  String get mcTeamRoleOwner => 'Propriétaire';

  @override
  String get mcTeamRoleMember => 'Membre';

  @override
  String mcCurseForgeUnknownFile(String id) {
    return 'Fichier CurseForge inconnu « $id ».';
  }

  @override
  String get mcCurseForgeFileGone => 'CurseForge n\'a plus ce fichier.';

  @override
  String get mcCurseForgeUnreachable =>
      'Impossible de joindre CurseForge. Vérifiez votre connexion.';

  @override
  String get mcCurseForgeKeyRejected =>
      'CurseForge a rejeté la clé API. Vérifiez-la dans les paramètres du lanceur.';

  @override
  String mcCurseForgeRequestFailed(String status) {
    return 'La requête CurseForge a échoué ($status).';
  }

  @override
  String get mcModrinthUnreachable =>
      'Impossible de joindre Modrinth. Vérifiez votre connexion.';

  @override
  String mcModrinthRequestFailed(String status) {
    return 'La requête Modrinth a échoué ($status).';
  }

  @override
  String get mcSortRelevance => 'Pertinence';

  @override
  String get mcSortDownloads => 'Téléchargements';

  @override
  String get mcSortFollows => 'Abonnés';

  @override
  String get mcSortNewest => 'Plus récents';

  @override
  String get mcSortRecentlyUpdated => 'Mis à jour récemment';

  @override
  String mcDownloadBatchFailed(int count, String details) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Échec du téléchargement de $count fichiers :',
      one: 'Échec du téléchargement d\'un fichier :',
    );
    return '$_temp0\n$details';
  }

  @override
  String mcDownloadCouldNotReach(String url) {
    return 'Impossible de joindre $url.';
  }

  @override
  String mcDownloadHttpError(String status, String url) {
    return 'HTTP $status pour $url.';
  }

  @override
  String mcDownloadChecksumMismatch(String path) {
    return 'Somme de contrôle incorrecte pour $path.';
  }

  @override
  String mcDownloadFailed(String url) {
    return 'Échec du téléchargement de $url.';
  }

  @override
  String mcFabricNoBuilds(String mcVersion) {
    return 'Aucune version du chargeur Fabric trouvée pour Minecraft $mcVersion.';
  }

  @override
  String mcFabricProfileFailed(String loaderVersion) {
    return 'Impossible de récupérer le profil Fabric $loaderVersion.';
  }

  @override
  String mcQuiltNoBuilds(String mcVersion) {
    return 'Aucune version du chargeur Quilt trouvée pour Minecraft $mcVersion.';
  }

  @override
  String mcQuiltProfileFailed(String loaderVersion) {
    return 'Impossible de récupérer le profil Quilt $loaderVersion.';
  }

  @override
  String get mcForgeVersionListUnreachable =>
      'Impossible de joindre la liste des versions de Forge.';

  @override
  String get mcForgeDownloadingInstaller =>
      'Téléchargement de l\'installateur Forge…';

  @override
  String get mcForgeRunningInstaller => 'Exécution de l\'installateur Forge…';

  @override
  String mcForgeInstallerFailed(String output) {
    return 'L\'installateur Forge a échoué :\n$output';
  }

  @override
  String get mcForgeInstallerNoNewProfile =>
      'L\'installateur Forge s\'est exécuté, mais aucun nouveau profil de version n\'a été trouvé.';

  @override
  String mcForgeInstallerNoProfile(String versionId) {
    return 'L\'installateur Forge n\'a pas produit $versionId.json.';
  }

  @override
  String mcForgeInstallerDownloadFailed(String version) {
    return 'Impossible de télécharger l\'installateur Forge $version.';
  }

  @override
  String get mcNeoForgeVersionListUnreachable =>
      'Impossible de joindre la liste des versions de NeoForge.';

  @override
  String get mcNeoForgeDownloadingInstaller =>
      'Téléchargement de l\'installateur NeoForge…';

  @override
  String get mcNeoForgeRunningInstaller =>
      'Exécution de l\'installateur NeoForge…';

  @override
  String mcNeoForgeInstallerFailed(String output) {
    return 'L\'installateur NeoForge a échoué :\n$output';
  }

  @override
  String get mcNeoForgeInstallerNoNewProfile =>
      'L\'installateur NeoForge s\'est exécuté, mais aucun nouveau profil de version n\'a été trouvé.';

  @override
  String mcNeoForgeInstallerNoProfile(String versionId) {
    return 'L\'installateur NeoForge n\'a pas produit $versionId.json.';
  }

  @override
  String mcNeoForgeInstallerDownloadFailed(String version) {
    return 'Impossible de télécharger l\'installateur NeoForge $version.';
  }

  @override
  String get mcLaunchCheckingUpdates => 'Recherche de mises à jour…';

  @override
  String mcLaunchVersionNotListed(String version) {
    return 'Minecraft $version n\'est plus listé par Mojang.';
  }

  @override
  String get mcLaunchResolvingFiles =>
      'Résolution des fichiers de base du jeu…';

  @override
  String get mcLaunchAssetLabel => 'ressource';

  @override
  String get mcLaunchDownloadingGame => 'Téléchargement des fichiers du jeu…';

  @override
  String mcLaunchDownloadingGameProgress(String done, String total) {
    return 'Téléchargement des fichiers du jeu ($done/$total)…';
  }

  @override
  String mcLaunchNoLoaderVersion(String loader) {
    return 'Cette instance n\'a aucune version de $loader sélectionnée.';
  }

  @override
  String mcLaunchSettingUpLoader(String loader) {
    return 'Configuration de $loader…';
  }

  @override
  String mcLaunchDownloadingLoaderLibraries(String loader) {
    return 'Téléchargement des bibliothèques $loader…';
  }

  @override
  String mcLaunchDownloadingLoaderLibrariesProgress(
    String loader,
    String done,
    String total,
  ) {
    return 'Téléchargement des bibliothèques $loader ($done/$total)…';
  }

  @override
  String get mcLaunchExtractingNatives =>
      'Extraction des bibliothèques natives…';

  @override
  String get mcLaunchLaunching => 'Lancement…';

  @override
  String mcLaunchUnknownLoader(String loader) {
    return 'Chargeur de mods inconnu « $loader ».';
  }

  @override
  String mcLaunchUnsafeLibraryPath(String path) {
    return 'Téléchargement de la bibliothèque refusé, chemin non sûr « $path ».';
  }

  @override
  String mcJavaLookingUp(String version) {
    return 'Recherche de Java $version…';
  }

  @override
  String mcJavaDownloading(String version) {
    return 'Téléchargement de Java $version…';
  }

  @override
  String mcJavaDownloadFailed(String status) {
    return 'Échec du téléchargement de Java ($status).';
  }

  @override
  String mcJavaCouldNotDownload(String version) {
    return 'Impossible de télécharger l\'environnement d\'exécution Java $version.';
  }

  @override
  String mcJavaExtracting(String version) {
    return 'Extraction de Java $version…';
  }

  @override
  String mcJavaMissingJavaw(String version) {
    return 'L\'environnement Java $version téléchargé ne contient pas javaw.exe.';
  }

  @override
  String get mcJavaReady => 'Prêt';

  @override
  String get mcJavaProviderUnreachable =>
      'Impossible de joindre le fournisseur de l\'environnement Java.';

  @override
  String mcJavaNoBuildFound(String version, String status) {
    return 'Aucune version Java $version trouvée ($status).';
  }

  @override
  String mcJavaNoBuildForWindows(String version) {
    return 'Aucune version Java $version disponible pour Windows x64.';
  }

  @override
  String mcGameCouldNotStartJava(String error) {
    return 'Impossible de démarrer Java : $error';
  }

  @override
  String get mcCloudBackupNeedsAccount =>
      'Les sauvegardes cloud nécessitent un compte luma approuvé — créez-en un dans Paramètres → Synchronisation et compte.';

  @override
  String get mcCloudStorageFull => 'Espace de stockage cloud insuffisant.';

  @override
  String get mcCloudBackupMissingPart =>
      'Une partie de cette sauvegarde est absente du serveur.';

  @override
  String get mcCloudBackupIndexFailed =>
      'Impossible de mettre à jour la liste des sauvegardes — réessayez.';

  @override
  String get mcMsAuthNotConfigured =>
      'La connexion Microsoft n\'est pas configurée pour cette version.';

  @override
  String get mcMsAuthDeclined => 'La connexion a été refusée.';

  @override
  String get mcMsAuthCodeExpired => 'Le code de connexion a expiré. Réessayez.';

  @override
  String get mcMsAuthTimedOut => 'Délai dépassé en attendant la connexion.';

  @override
  String get mcMsAuthNoXboxProfile =>
      'Ce compte Microsoft n\'a pas de profil Xbox. Créez-en un sur xbox.com et réessayez.';

  @override
  String get mcMsAuthUnder18 =>
      'Ce compte a moins de 18 ans et nécessite un groupe familial pour se connecter aux services Xbox.';

  @override
  String get mcMsAuthXboxRejected => 'La connexion Xbox a été rejetée.';

  @override
  String get mcMsAuthNoMinecraft =>
      'Ce compte Microsoft ne possède pas Minecraft.';

  @override
  String mcMsAuthUnexpectedResponse(String status) {
    return 'Réponse inattendue ($status).';
  }

  @override
  String mcMsAuthRequestFailed(String status) {
    return 'La requête a échoué ($status).';
  }

  @override
  String mcModInstalledInto(String title, String instance) {
    return '$title installé dans $instance.';
  }

  @override
  String mcModInstalledWithDeps(String title, int count, String instance) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dépendances',
      one: '1 dépendance',
    );
    return '$title + $_temp0 installé(es) dans $instance.';
  }

  @override
  String mcModNoBuildVanilla(String version) {
    return 'Aucune version de ceci pour $version.';
  }

  @override
  String mcModNoBuildForLoader(String version, String loader) {
    return 'Aucune version de ceci pour $version avec $loader.';
  }

  @override
  String get mcModDepsPromptTitle => 'Installer les dépendances requises ?';

  @override
  String mcModNeedsDeps(String title) {
    return '$title a besoin de ceux-ci pour fonctionner :';
  }

  @override
  String get mcModInstallAll => 'Tout installer';

  @override
  String get mcContentTypeMods => 'Mods';

  @override
  String get mcContentTypeResourcePacks => 'Packs de ressources';

  @override
  String get mcContentTypeShaderPacks => 'Packs de shaders';

  @override
  String mcModCurseForgeOnly(String title) {
    return '$title ne peut être téléchargé que depuis sa page CurseForge : l\'auteur a désactivé les téléchargements dans les autres lanceurs.';
  }

  @override
  String mcModUnsafeFileName(String filename) {
    return 'Installation de « $filename » refusée : nom de fichier non sûr.';
  }

  @override
  String mcModIncompatible(String a, String b) {
    return '$a est signalé comme incompatible avec $b.';
  }

  @override
  String get mcModpackReading => 'Lecture du modpack…';

  @override
  String get mcModpackNotValid =>
      'Fichier .mrpack non valide (modrinth.index.json manquant).';

  @override
  String get mcModpackNoMinecraftVersion =>
      'Ce modpack ne déclare aucune version de Minecraft.';

  @override
  String get mcModpackDefaultName => 'Modpack importé';

  @override
  String get mcModpackDownloadingFiles =>
      'Téléchargement des fichiers du modpack…';

  @override
  String mcModpackDownloadingFilesProgress(String done, String total) {
    return 'Téléchargement des fichiers du modpack ($done/$total)…';
  }

  @override
  String get mcModpackExtractingOverrides => 'Extraction des overrides…';

  @override
  String get mcModpackRecording => 'Enregistrement du contenu installé…';

  @override
  String get mcModpackDone => 'Terminé';

  @override
  String mcPistonUnreachable(String url) {
    return 'Impossible de joindre $url. Vérifiez votre connexion.';
  }

  @override
  String mcPistonRequestFailed(String status, String url) {
    return 'La requête a échoué ($status) pour $url.';
  }

  @override
  String get minecraftLauncherTabLibrary => 'Bibliothèque';

  @override
  String get minecraftLauncherTabAccounts => 'Comptes';

  @override
  String get minecraftLauncherTabServers => 'Serveurs';

  @override
  String get minecraftLauncherTabSettings => 'Paramètres';

  @override
  String get minecraftLauncherNotWindowsTitle =>
      'Non disponible sur cette plateforme';

  @override
  String get minecraftLauncherNotWindowsSubtitle =>
      'Minecraft Launcher ne prend actuellement en charge que Windows.';

  @override
  String get minecraftLauncherOfflineNeedsMicrosoft =>
      'Connectez-vous d\'abord avec un compte Microsoft qui possède Minecraft — les profils hors ligne servent à jouer ensuite sans connexion, pas à la place de cela.';

  @override
  String get minecraftLauncherCloudBackups => 'Sauvegardes cloud';

  @override
  String minecraftLauncherBackedUpCount(int count) {
    return '$count sauvegardé(s)';
  }

  @override
  String get minecraftLauncherRestore => 'Restaurer';

  @override
  String get minecraftLauncherCurseForgeKeyTitle => 'Clé API CurseForge';

  @override
  String minecraftLauncherCurseForgeKeyBody(String accountOverview) {
    return 'CurseForge ne répond qu\'aux applications qui envoient une clé API. Créez-en une gratuitement dans la console CurseForge for Studios et collez-la ici. Elle est stockée chiffrée sur cet appareil, partagée avec $accountOverview, et n\'est envoyée qu\'à CurseForge.';
  }

  @override
  String get minecraftLauncherCurseForgeOpenConsole =>
      'Ouvrir la console CurseForge';

  @override
  String get minecraftLauncherCurseForgePasteKeyHint => 'Collez votre clé API';

  @override
  String get minecraftLauncherStarting => 'Démarrage…';

  @override
  String minecraftLauncherStartingInstance(String name) {
    return 'Démarrage de $name';
  }

  @override
  String get minecraftLauncherSearchHint =>
      'Rechercher des instances et des mods…';

  @override
  String get minecraftLauncherInstances => 'Instances';

  @override
  String get minecraftLauncherMods => 'Mods';

  @override
  String get minecraftLauncherNoModsFound => 'Aucun mod trouvé.';

  @override
  String get minecraftLauncherNewInstance => 'Nouvelle instance';

  @override
  String get minecraftLauncherCouldNotLoadVersions =>
      'Impossible de charger les versions de Minecraft';

  @override
  String get minecraftLauncherInstanceNameHint => 'Nom de l\'instance';

  @override
  String get minecraftLauncherModLoader => 'Chargeur de mods';

  @override
  String get minecraftLauncherLoaderVanilla => 'Vanilla';

  @override
  String minecraftLauncherLoaderVersion(String loader) {
    return 'Version de $loader';
  }

  @override
  String minecraftLauncherNoLoaderBuilds(String loader, String version) {
    return 'Aucune build $loader trouvée pour $version.';
  }

  @override
  String get minecraftLauncherShowSnapshots => 'Afficher les instantanés';

  @override
  String get minecraftLauncherVersion => 'Version';

  @override
  String get minecraftLauncherSearchVersionsHint => 'Rechercher des versions…';

  @override
  String get minecraftLauncherVersionTypeRelease => 'Version finale';

  @override
  String get minecraftLauncherVersionTypeSnapshot => 'Instantané';

  @override
  String get minecraftLauncherVersionTypeOldBeta => 'Ancienne bêta';

  @override
  String get minecraftLauncherVersionTypeOldAlpha => 'Ancienne alpha';

  @override
  String minecraftLauncherBrowseFor(String name) {
    return 'Parcourir pour $name';
  }

  @override
  String minecraftLauncherSearchKindHint(String kind) {
    return 'Rechercher $kind…';
  }

  @override
  String minecraftLauncherCompatibleWith(String version) {
    return 'Compatible avec $version';
  }

  @override
  String minecraftLauncherCompatibleWithLoader(String version, String loader) {
    return 'Compatible avec $version · $loader';
  }

  @override
  String minecraftLauncherResultCount(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown résultats',
      one: '$shown résultat',
    );
    return '$_temp0';
  }

  @override
  String minecraftLauncherInstallInto(String name) {
    return 'Installer dans $name';
  }

  @override
  String get minecraftLauncherCurseForgeNeedsKey =>
      'CurseForge nécessite une clé API';

  @override
  String get minecraftLauncherCurseForgeNeedsKeySubtitle =>
      'Ajoutez votre propre clé gratuite une seule fois et les mods, packs de ressources et shaders CurseForge apparaîtront ici.';

  @override
  String get minecraftLauncherAddApiKey => 'Ajouter une clé API';

  @override
  String get minecraftLauncherChangeApiKey => 'Modifier la clé API';

  @override
  String get minecraftLauncherSearchFailed => 'Échec de la recherche';

  @override
  String get minecraftLauncherNoResults => 'Aucun résultat';

  @override
  String get minecraftLauncherNoResultsSubtitle =>
      'Essayez une autre recherche, un autre tri ou un autre type de contenu.';

  @override
  String get minecraftLauncherEndOfResults => 'C\'est tout.';

  @override
  String get minecraftLauncherLoadMore => 'Charger plus';

  @override
  String get minecraftLauncherAddOfflineAccount =>
      'Ajouter un compte hors ligne';

  @override
  String get minecraftLauncherSignInMicrosoft => 'Se connecter avec Microsoft';

  @override
  String get minecraftLauncherNoAccounts => 'Aucun compte pour le moment';

  @override
  String get minecraftLauncherNoAccountsSubtitle =>
      'Connectez-vous avec un compte Microsoft qui possède Minecraft pour commencer. Ensuite, vous pourrez ajouter un profil hors ligne pour jouer sans connexion.';

  @override
  String get minecraftLauncherMicrosoftUnavailable =>
      'La connexion Microsoft est indisponible';

  @override
  String get minecraftLauncherMicrosoftUnavailableBody =>
      'Cette version n\'a pas l\'enregistrement d\'application Microsoft de Luma. N\'acceptez pas un écran de consentement qui mentionne Prism Launcher.';

  @override
  String get minecraftLauncherDeviceCodeInstructions =>
      'Le code est affiché ci-dessous. Saisissez-le sur la page Microsoft qui vient de s\'ouvrir :';

  @override
  String get minecraftLauncherCopyCode => 'Copier le code';

  @override
  String get minecraftLauncherCodeCopied => 'Code copié.';

  @override
  String get minecraftLauncherWaitingForBrowser =>
      'En attente de la fin de la connexion dans le navigateur…';

  @override
  String get minecraftLauncherOpenMicrosoftSignIn =>
      'Ouvrir la connexion Microsoft';

  @override
  String get minecraftLauncherMicrosoftAccount => 'Compte Microsoft';

  @override
  String get minecraftLauncherOfflineAccount => 'Compte hors ligne';

  @override
  String get minecraftLauncherActive => 'Active';

  @override
  String get minecraftLauncherUseAccount => 'Utiliser ce compte';

  @override
  String get mcLauncherInstanceNotFound => 'Instance introuvable';

  @override
  String get mcLauncherExportModpack => 'Exporter comme modpack';

  @override
  String get mcLauncherDeleteInstance => 'Supprimer l\'instance';

  @override
  String get mcLauncherTabContent => 'Contenu';

  @override
  String get mcLauncherTabWorlds => 'Mondes';

  @override
  String get mcLauncherTabScreenshots => 'Captures d\'écran';

  @override
  String get mcLauncherTabLogs => 'Journaux';

  @override
  String get mcLauncherExportModpackTitle => 'Exporter le modpack';

  @override
  String mcLauncherExportedTo(String path) {
    return 'Exporté vers $path';
  }

  @override
  String mcLauncherDeleteInstanceTitle(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get mcLauncherDeleteInstanceBody =>
      'Cela retire l\'instance de votre bibliothèque. Les sauvegardes des mondes et les autres fichiers restent sur le disque, sauf si vous les supprimez manuellement depuis le dossier de l\'instance.';

  @override
  String get mcLauncherAddAccountFirst =>
      'Ajoutez d\'abord un compte dans l\'onglet Comptes.';

  @override
  String get mcLauncherNeverPlayed => 'Jamais joué';

  @override
  String mcLauncherLastPlayed(String date) {
    return 'Dernière partie : $date';
  }

  @override
  String mcLauncherTotalPlaytime(int hours, int minutes) {
    return 'Temps de jeu total : $hours h $minutes min';
  }

  @override
  String get mcLauncherOpenFolder => 'Ouvrir le dossier';

  @override
  String get mcLauncherPlay => 'Jouer';

  @override
  String get mcLauncherCheckUpdates => 'Vérifier les mises à jour';

  @override
  String get mcLauncherNothingInstalled => 'Rien d\'installé pour l\'instant';

  @override
  String get mcLauncherNothingInstalledSubtitle =>
      'Parcourez Modrinth ou CurseForge pour trouver des mods, packs de ressources et packs de shaders.';

  @override
  String get mcLauncherKindMods => 'Mods';

  @override
  String get mcLauncherKindResourcePacks => 'Packs de ressources';

  @override
  String get mcLauncherKindShaderPacks => 'Packs de shaders';

  @override
  String get mcLauncherKindDatapacks => 'Packs de données';

  @override
  String get mcLauncherAnalyzeWithAi => 'Analyser avec l\'IA';

  @override
  String get mcLauncherAnalyzing => 'Analyse en cours…';

  @override
  String get mcLauncherAiAnalysis => 'Analyse IA';

  @override
  String get mcLauncherWaitingForOutput => 'En attente de sortie…';

  @override
  String get mcLauncherNotRunning => 'Non lancé';

  @override
  String get mcLauncherNotRunningSubtitle =>
      'Lancez l\'instance pour voir la sortie en direct ici.';

  @override
  String get mcLauncherInstanceIcon => 'Icône de l\'instance';

  @override
  String get mcLauncherMemory => 'Mémoire';

  @override
  String mcLauncherMemoryRange(int minMb, int maxMb) {
    return 'Min $minMb Mo · Max $maxMb Mo';
  }

  @override
  String get mcLauncherJavaOverride => 'Exécutable Java personnalisé';

  @override
  String get mcLauncherJavaOverrideHint =>
      'Laisser vide pour une gestion automatique';

  @override
  String get mcLauncherJvmArgs => 'Arguments JVM supplémentaires';

  @override
  String get mcLauncherInstancesTitle => 'Instances';

  @override
  String get mcLauncherImportModpack => 'Importer un modpack';

  @override
  String get mcLauncherNewInstance => 'Nouvelle instance';

  @override
  String get mcLauncherImportStarting => 'Démarrage…';

  @override
  String get mcLauncherNoInstances => 'Aucune instance pour l\'instant';

  @override
  String get mcLauncherNoInstancesSubtitle =>
      'Créez-en une pour installer Minecraft et commencer à jouer.';

  @override
  String get mcLauncherImportingModpack => 'Importation du modpack';

  @override
  String get mcLauncherNoDescription => 'Ce projet n\'a pas de description.';

  @override
  String get mcLauncherUpdatesTitle => 'Mises à jour et conflits';

  @override
  String get mcLauncherConflicts => 'Conflits';

  @override
  String get mcLauncherUpdates => 'Mises à jour';

  @override
  String get mcLauncherUpToDate => 'Tout est à jour.';

  @override
  String get mcLauncherUpdating => 'Mise à jour…';

  @override
  String get mcLauncherUpdate => 'Mettre à jour';

  @override
  String mcLauncherYearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count ans',
      one: 'il y a 1 an',
    );
    return '$_temp0';
  }

  @override
  String mcLauncherMonthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count mois',
      one: 'il y a 1 mois',
    );
    return '$_temp0';
  }

  @override
  String mcLauncherDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count jours',
      one: 'il y a 1 jour',
    );
    return '$_temp0';
  }

  @override
  String mcLauncherHoursAgo(int count) {
    return 'il y a $count h';
  }

  @override
  String mcLauncherMinutesAgo(int count) {
    return 'il y a $count min';
  }

  @override
  String mcLauncherByAuthor(String author) {
    return 'par $author';
  }

  @override
  String mcLauncherUpdatedAgo(String time) {
    return 'Mis à jour $time';
  }

  @override
  String get mcLauncherInstalled => 'Installé';

  @override
  String get mcLauncherAlreadyInstalled => 'Déjà installé';

  @override
  String get mcLauncherPickInstanceTitle => 'Installer dans quelle instance ?';

  @override
  String get mcLauncherCreateInstanceFirst => 'Créez d\'abord une instance.';

  @override
  String mcLauncherNoBuildFor(String version) {
    return 'Aucune version de ceci pour $version.';
  }

  @override
  String mcLauncherNoBuildForLoader(String version, String loader) {
    return 'Aucune version de ceci pour $version avec $loader.';
  }

  @override
  String mcLauncherOpenOn(String source) {
    return 'Ouvrir sur $source';
  }

  @override
  String get mcLauncherCouldNotLoadProject => 'Impossible de charger ce projet';

  @override
  String get mcLauncherGallery => 'Galerie';

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
  String get mcLauncherStatDownloads => 'téléchargements';

  @override
  String get mcLauncherStatFollowers => 'abonnés';

  @override
  String get mcLauncherStatUpdated => 'mis à jour';

  @override
  String get mcLauncherLinkSource => 'Source';

  @override
  String get mcLauncherLinkIssues => 'Problèmes';

  @override
  String get mcLauncherLinkWiki => 'Wiki';

  @override
  String get mcLauncherInstallInto => 'Installer dans…';

  @override
  String get mcLauncherPickInstanceTooltip =>
      'Choisissez une instance où installer';

  @override
  String mcLauncherInstallNewestInto(String name) {
    return 'Installer la version compatible la plus récente dans $name';
  }

  @override
  String get mcLauncherChooseInstance => 'Choisir l\'instance';

  @override
  String get mcLauncherTabVersions => 'Versions';

  @override
  String mcLauncherVersionsCount(int count) {
    return 'Versions ($count)';
  }

  @override
  String get mcLauncherPickInstanceToSee =>
      'Choisissez une instance pour voir les versions compatibles.';

  @override
  String mcLauncherNoBuildWorksWith(String version) {
    return 'Aucune version de ceci ne fonctionne avec $version.';
  }

  @override
  String mcLauncherNoBuildWorksWithLoader(String version, String loader) {
    return 'Aucune version de ceci ne fonctionne avec $version et $loader.';
  }

  @override
  String mcLauncherImageIndex(int index, int total) {
    return 'Image $index sur $total';
  }

  @override
  String get mcLauncherRevealInFolder => 'Afficher dans le dossier';

  @override
  String get mcLauncherCopyPath => 'Copier le chemin';

  @override
  String get mcLauncherBackupToCloud => 'Sauvegarder dans le cloud';

  @override
  String mcLauncherBackedUpToCloud(String label) {
    return '« $label » sauvegardé dans le cloud.';
  }

  @override
  String get mcLauncherNoScreenshots =>
      'Aucune capture d\'écran pour l\'instant';

  @override
  String get mcLauncherNoScreenshotsSubtitle =>
      'Les captures d\'écran prises en jeu (F2) apparaîtront ici.';

  @override
  String get mcLauncherCouldNotOpenBrowser =>
      'Impossible d\'ouvrir le navigateur.';

  @override
  String get mcLauncherServersTitle => 'Serveurs';

  @override
  String get mcLauncherServersIntro =>
      'Louez un serveur Minecraft pour jouer à vos instances entre amis.';

  @override
  String get mcLauncherKineticBody =>
      'Prise en charge des modpacks et des plugins, assistance 24h/24 et installations en un clic. S\'inscrire via ce lien soutient luma sans frais supplémentaires pour vous.';

  @override
  String get mcLauncherBrowsePlans => 'Voir les offres';

  @override
  String get mcLauncherServerHostingEyebrow =>
      'HÉBERGEMENT DE SERVEURS MINECRAFT';

  @override
  String get mcLauncherServerHostingHeadline =>
      'HÉBERGEMENT DE QUALITÉ,\nPETITS PRIX !';

  @override
  String get mcLauncherPillSupport => 'Assistance 24h/24';

  @override
  String get mcLauncherPillModSupport => 'Prise en charge des mods';

  @override
  String get mcLauncherStartToday => 'COMMENCEZ AUJOURD\'HUI !';

  @override
  String get mcLauncherJavaRuntimes => 'Environnements Java';

  @override
  String get mcLauncherRuntimesHint =>
      'Téléchargés automatiquement la première fois qu\'une instance en a besoin.';

  @override
  String get mcLauncherNoRuntimes => 'Aucun téléchargé pour l\'instant.';

  @override
  String get mcLauncherCurseForgeKeySaved =>
      'Clé API enregistrée. Les pages de navigation peuvent rechercher et installer depuis CurseForge.';

  @override
  String get mcLauncherCurseForgeKeyAdd =>
      'Ajoutez votre propre clé API pour parcourir et installer du contenu CurseForge.';

  @override
  String get mcLauncherChangeApiKey => 'Modifier la clé API';

  @override
  String get mcLauncherAddApiKey => 'Ajouter une clé API';

  @override
  String get mcLauncherRemoveKey => 'Supprimer la clé';

  @override
  String get mcLauncherCouldNotReadWorlds => 'Impossible de lire les mondes';

  @override
  String get mcLauncherImportWorld => 'Importer un monde';

  @override
  String get mcLauncherNoWorlds => 'Aucun monde pour l\'instant';

  @override
  String get mcLauncherNoWorldsSubtitle =>
      'Les mondes que vous créez en jeu apparaîtront ici.';

  @override
  String mcLauncherWorldSeed(String seed) {
    return 'Graine $seed';
  }

  @override
  String get mcLauncherBackupToZip => 'Sauvegarder en zip';

  @override
  String get mcLauncherDuplicate => 'Dupliquer';

  @override
  String mcLauncherBackedUpTo(String path) {
    return 'Sauvegardé dans $path';
  }

  @override
  String mcLauncherDeleteWorldTitle(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get mcLauncherDeleteWorldBody =>
      'Cela supprime définitivement le dossier du monde.';

  @override
  String get moodJournalTabJournal => 'Journal';

  @override
  String get moodJournalTabCalendar => 'Calendrier';

  @override
  String get moodJournalAddEntry => 'Ajouter une entrée';

  @override
  String get moodJournalEmptyTitle => 'Aucune entrée pour l\'instant';

  @override
  String get moodJournalEmptySubtitle =>
      'Notez votre humeur pour commencer à suivre vos habitudes.';

  @override
  String get moodJournalMoodTerrible => 'Horrible';

  @override
  String get moodJournalMoodBad => 'Mauvais';

  @override
  String get moodJournalMoodOkay => 'Moyen';

  @override
  String get moodJournalMoodGood => 'Bien';

  @override
  String get moodJournalMoodGreat => 'Super';

  @override
  String get moodJournalTagWork => 'Travail';

  @override
  String get moodJournalTagSleep => 'Sommeil';

  @override
  String get moodJournalTagExercise => 'Sport';

  @override
  String get moodJournalTagSocial => 'Social';

  @override
  String get moodJournalTagHealth => 'Santé';

  @override
  String get moodJournalDaySun => 'D';

  @override
  String get moodJournalDayMon => 'L';

  @override
  String get moodJournalDayTue => 'M';

  @override
  String get moodJournalDayWed => 'M';

  @override
  String get moodJournalDayThu => 'J';

  @override
  String get moodJournalDayFri => 'V';

  @override
  String get moodJournalDaySat => 'S';

  @override
  String get moodJournalNoEntriesForDay => 'Aucune entrée pour ce jour';

  @override
  String get moodJournalAddNewEntry => 'Ajouter une nouvelle entrée';

  @override
  String get moodJournalEditEntry => 'Modifier l\'entrée';

  @override
  String get moodJournalNewEntry => 'Nouvelle entrée';

  @override
  String get moodJournalSaveChanges => 'Enregistrer les modifications';

  @override
  String get moodJournalSaveEntry => 'Enregistrer l\'entrée';

  @override
  String get moodJournalFeelingQuestion => 'Comment vous sentez-vous ?';

  @override
  String get moodJournalEntryLabel => 'Entrée de journal';

  @override
  String get moodJournalPhotos => 'Photos';

  @override
  String get moodJournalTags => 'Étiquettes';

  @override
  String get moodJournalNoteHint => 'À quoi pensez-vous ?';

  @override
  String get moodJournalCustomTagHint => 'Ajouter une étiquette...';

  @override
  String get nfcRecordEditorTypeText => 'Texte';

  @override
  String get nfcRecordEditorTypeLink => 'Lien';

  @override
  String get nfcRecordEditorTypePhone => 'Téléphone';

  @override
  String get nfcRecordEditorTypeWifi => 'Wi-Fi';

  @override
  String get nfcRecordEditorTypeContact => 'Contact';

  @override
  String get nfcRecordEditorTypeApp => 'Appli';

  @override
  String get nfcRecordEditorTypeCustom => 'Personnalisé';

  @override
  String get nfcRecordEditorAddTitle => 'Ajouter un enregistrement';

  @override
  String get nfcRecordEditorEditTitle => 'Modifier l\'enregistrement';

  @override
  String get nfcRecordEditorErrorText => 'Saisissez du texte.';

  @override
  String get nfcRecordEditorErrorLink => 'Saisissez un lien valide.';

  @override
  String get nfcRecordEditorErrorPhone => 'Saisissez un numéro de téléphone.';

  @override
  String get nfcRecordEditorErrorEmail => 'Saisissez une adresse e-mail.';

  @override
  String get nfcRecordEditorErrorNetwork => 'Saisissez le nom du réseau.';

  @override
  String get nfcRecordEditorErrorName => 'Saisissez un nom.';

  @override
  String get nfcRecordEditorErrorPackage =>
      'Saisissez un nom de package, p. ex. com.example.app.';

  @override
  String get nfcRecordEditorErrorMime =>
      'Saisissez un type MIME, p. ex. text/plain.';

  @override
  String get nfcRecordEditorTextHint => 'Ce que cette étiquette doit afficher';

  @override
  String get nfcRecordEditorLanguageCode => 'Code de langue';

  @override
  String get nfcRecordEditorPhoneNumber => 'Numéro de téléphone';

  @override
  String get nfcRecordEditorAddress => 'Adresse';

  @override
  String get nfcRecordEditorSubjectOptional => 'Objet (facultatif)';

  @override
  String get nfcRecordEditorBodyOptional => 'Corps (facultatif)';

  @override
  String get nfcRecordEditorNetworkName => 'Nom du réseau (SSID)';

  @override
  String get nfcRecordEditorSecurity => 'Sécurité';

  @override
  String get nfcRecordEditorSecurityOpen => 'Ouvert';

  @override
  String get nfcRecordEditorWifiNote =>
      'Écrit comme un enregistrement texte que la plupart des téléphones peuvent lire en touchant l\'étiquette. Il ne rejoint pas automatiquement tous les appareils, contrairement au code QR Wi-Fi de certains routeurs.';

  @override
  String get nfcRecordEditorPhoneOptional => 'Téléphone (facultatif)';

  @override
  String get nfcRecordEditorEmailOptional => 'E-mail (facultatif)';

  @override
  String get nfcRecordEditorOrganizationOptional => 'Organisation (facultatif)';

  @override
  String get nfcRecordEditorPackageName => 'Nom du package';

  @override
  String get nfcRecordEditorAppHint =>
      'Vous le trouvez dans Paramètres → Applications → (l\'application) → Avancé → Détails de l\'application, sur le téléphone où elle est installée. Android propose d\'ouvrir ou d\'installer cette application lorsqu\'il lit l\'étiquette.';

  @override
  String get nfcRecordEditorMimeType => 'Type MIME';

  @override
  String get nfcRecordEditorContent => 'Contenu';

  @override
  String get nfcKindPhone => 'Numéro de téléphone';

  @override
  String get nfcKindWifi => 'Détails Wi-Fi';

  @override
  String get nfcKindContact => 'Carte de contact';

  @override
  String get nfcKindAppLaunch => 'Raccourci d\'application';

  @override
  String get nfcKindMime => 'Données personnalisées';

  @override
  String get nfcKindRaw => 'Enregistrement non reconnu';

  @override
  String get nfcSummaryEmpty => 'Vide';

  @override
  String get nfcSummaryNoLink => 'Aucun lien défini';

  @override
  String get nfcSummaryNoNumber => 'Aucun numéro défini';

  @override
  String get nfcSummaryNoAddress => 'Aucune adresse définie';

  @override
  String get nfcSummaryNoNetwork => 'Aucun réseau défini';

  @override
  String get nfcSummaryNoName => 'Aucun nom défini';

  @override
  String get nfcSummaryNoPackage => 'Aucun paquet défini';

  @override
  String nfcSummaryRawBytes(int bytes) {
    return 'Conservé tel quel ($bytes octets) — non modifiable';
  }

  @override
  String get nfcDuplicate => 'Dupliquer';

  @override
  String get nfcAndroidOnlyTitle => 'Android uniquement';

  @override
  String get nfcUnsupportedNotice =>
      'NFC Tag Editor a besoin du matériel NFC et des API de lecture d\'Android, il ne fonctionne donc que sur un téléphone ou une tablette Android — il n\'y a rien à scanner ni à écrire ici.';

  @override
  String get nfcErrNotNdef =>
      'Ce tag ne prend pas en charge NDEF, donc luma ne peut pas le modifier. La plupart des autocollants et cartes NFC vierges le permettent — essayez un autre tag.';

  @override
  String get nfcErrNotAvailable =>
      'La modification NFC n\'est pas disponible sur cet appareil.';

  @override
  String get nfcErrNfcOff =>
      'Le NFC est désactivé ou non pris en charge ici. Activez-le dans les paramètres de l\'appareil et réessayez.';

  @override
  String nfcErrStartFailed(String error) {
    return 'Impossible de démarrer le lecteur NFC. ($error)';
  }

  @override
  String nfcErrCouldNotReach(String error) {
    return 'Impossible de joindre ce tag. ($error)';
  }

  @override
  String get nfcErrLocked =>
      'Ce tag est verrouillé en lecture seule et ne peut plus être écrit.';

  @override
  String nfcErrTooBig(int bytes, int capacity) {
    return 'Cela fait $bytes octets, mais ce tag n\'en contient que $capacity. Supprimez un enregistrement et réessayez.';
  }

  @override
  String get nfcErrNotWritable =>
      'Impossible d\'écrire sur ce tag : il ne prend pas en charge NDEF.';

  @override
  String get nfcErrNothingToLock =>
      'Ce tag n\'est pas formaté en NDEF, il n\'y a donc rien à verrouiller.';

  @override
  String get nfcErrNoTag =>
      'Aucun tag détecté. Posez-le à plat contre l\'arrière de votre téléphone et réessayez.';

  @override
  String get nfcTabEditor => 'Éditeur';

  @override
  String get nfcTabTemplates => 'Modèles';

  @override
  String get nfcTabHistory => 'Historique';

  @override
  String get nfcHeroTitle => 'Scannez un tag pour voir ce qu\'il contient';

  @override
  String get nfcHeroBody =>
      'Approchez n\'importe quel tag ou autocollant NFC de votre téléphone pour lire et modifier ses enregistrements, ou partez de zéro et écrivez un tout nouveau tag.';

  @override
  String get nfcScanTag => 'Scanner un tag';

  @override
  String get nfcStartFromScratch => 'Partir de zéro';

  @override
  String get nfcRecordsHeading => 'Enregistrements';

  @override
  String get nfcNoRecordsTitle => 'Aucun enregistrement pour l\'instant';

  @override
  String get nfcNoRecordsBody =>
      'Ajoutez un enregistrement ci-dessus : texte, lien, détails Wi-Fi, carte de contact et plus encore.';

  @override
  String get nfcWriteToTag => 'Écrire sur le tag';

  @override
  String get nfcWriteHint =>
      'Fonctionne avec le tag scanné ou un autre : il suffit de approcher celui sur lequel vous voulez écrire, quand vous êtes prêt.';

  @override
  String get nfcStartOver => 'Recommencer';

  @override
  String get nfcStartOverTitle => 'Recommencer?';

  @override
  String get nfcStartOverBody =>
      'Cela efface tous les enregistrements de l\'éditeur. Ce qui est déjà écrit sur un tag n\'est pas modifié.';

  @override
  String get nfcWrittenLocked => 'Écrit et verrouillé en lecture seule.';

  @override
  String get nfcWritten => 'Écrit sur le tag.';

  @override
  String get nfcWriteAnother => 'Écrire un autre';

  @override
  String get nfcWriteFailed => 'Impossible d\'écrire sur ce tag.';

  @override
  String get nfcReadFailed =>
      'Une erreur est survenue lors de la lecture de ce tag.';

  @override
  String get nfcSaveAsTemplate => 'Enregistrer comme modèle';

  @override
  String get nfcTemplateNameHint => 'p. ex. Wi-Fi invités';

  @override
  String nfcTemplateSaved(String name) {
    return '« $name » enregistré.';
  }

  @override
  String get nfcWriteLockTitle => 'Écrire et verrouiller ce tag?';

  @override
  String get nfcWriteLockBody =>
      'Cela écrit les enregistrements ci-dessous, puis rend le tag définitivement en lecture seule. Il ne pourra plus jamais être écrit, ni par luma ni par une autre application.';

  @override
  String get nfcWriteLockAction => 'Écrire et verrouiller';

  @override
  String get nfcWriteLockMenu => 'Écrire et verrouiller (lecture seule)';

  @override
  String get nfcNoRecords => 'Aucun enregistrement';

  @override
  String get nfcDeleteTemplateTitle => 'Supprimer le modèle?';

  @override
  String nfcDeleteTemplateBody(String name) {
    return 'Cela supprime « $name ». Les tags déjà écrits avec ce modèle conservent leur contenu.';
  }

  @override
  String get nfcNoTemplatesTitle => 'Aucun modèle pour l\'instant';

  @override
  String get nfcNoTemplatesBody =>
      'Créez un ensemble d\'enregistrements dans l\'onglet Éditeur, puis enregistrez-le ici pour écrire le même contenu sur des tags à volonté, pratique pour un lot d\'autocollants.';

  @override
  String nfcTemplateRecordsSummary(int count, String kinds) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enregistrements',
      one: '1 enregistrement',
    );
    return '$_temp0 · $kinds';
  }

  @override
  String get nfcUseTemplate => 'Utiliser';

  @override
  String get nfcClearHistory => 'Effacer l\'historique';

  @override
  String get nfcClearHistoryTitle => 'Effacer l\'historique?';

  @override
  String get nfcClearHistoryBody =>
      'Chaque lecture et écriture de la liste est supprimée. Les modèles enregistrés ne sont pas touchés.';

  @override
  String get nfcNoHistoryTitle => 'Pas encore d\'historique';

  @override
  String get nfcNoHistoryBody =>
      'Chaque tag scanné ou écrit apparaît ici, pour que vous puissiez revoir son contenu.';

  @override
  String get nfcWrittenTagTitle => 'Tag écrit';

  @override
  String get nfcScannedTagTitle => 'Tag scanné';

  @override
  String get nfcLoadIntoEditor => 'Charger dans l\'éditeur';

  @override
  String nfcHistoryWrittenLine(String tech) {
    return 'Écrit · $tech';
  }

  @override
  String nfcHistoryScannedLine(String tech) {
    return 'Scanné · $tech';
  }

  @override
  String get nfcGenericTagName => 'Tag NFC';

  @override
  String nfcHistoryTimeAndRecords(String time, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enregistrements',
      one: '1 enregistrement',
    );
    return '$time · $_temp0';
  }

  @override
  String get nfcTimeJustNow => 'À l\'instant';

  @override
  String nfcTimeMinutesAgo(int count) {
    return 'il y a $count min';
  }

  @override
  String nfcTimeHoursAgo(int count) {
    return 'il y a $count h';
  }

  @override
  String nfcTimeDaysAgo(int count) {
    return 'il y a $count j';
  }

  @override
  String get nfcBusyScanLabel => 'Approchez un tag de votre téléphone';

  @override
  String get nfcBusyWriteLabel =>
      'Approchez le tag sur lequel vous voulez écrire';

  @override
  String get nfcBusyHint =>
      'Gardez-le à plat contre l\'arrière du téléphone jusqu\'à ce qu\'il émette un bip ou vibre.';

  @override
  String get nfcTagReadOnly => 'Lecture seule';

  @override
  String get nfcTagBlankWillFormat => 'Vierge — sera formaté';

  @override
  String nfcTagUid(String uid) {
    return 'UID $uid';
  }

  @override
  String nfcTagBytesUsed(int used, int capacity) {
    return '$used / $capacity octets';
  }

  @override
  String get nfcTemplateDefaultName => 'Modèle';

  @override
  String get nfcSnapshotInvalid =>
      'Instantané de l\'éditeur de tags NFC non valide.';

  @override
  String get priceScraperInvalidUrl => 'URL invalide.';

  @override
  String get priceScraperUnreachable =>
      'Impossible d\'atteindre l\'URL. Vérifiez votre connexion.';

  @override
  String priceScraperHttpError(int status) {
    return 'La page a renvoyé une erreur ($status).';
  }

  @override
  String get priceScraperNoPrice =>
      'Impossible de trouver un prix sur cette page. Le site nécessite peut-être JavaScript ou bloque l\'extraction.';

  @override
  String get priceTrackerEnterUrl => 'Saisissez l\'URL d\'un produit.';

  @override
  String get priceTrackerCheckFailed => 'Impossible de vérifier le prix.';

  @override
  String get priceTrackerTrackTitle => 'Suivre un produit';

  @override
  String get priceTrackerTrackSubtitle =>
      'Collez l\'URL d\'un produit et luma vérifie le prix pour vous.';

  @override
  String get priceTrackerNameHint => 'Nom (facultatif)';

  @override
  String get priceTrackerTrack => 'Suivre';

  @override
  String get priceTrackerTrackedItems => 'Articles suivis';

  @override
  String get priceTrackerEmptyTitle => 'Rien de suivi pour l\'instant';

  @override
  String get priceTrackerEmptySubtitle =>
      'Les produits que vous suivez sont enregistrés ici avec un graphique de l\'historique des prix.';

  @override
  String get priceTrackerCheckNow => 'Vérifier le prix maintenant';

  @override
  String get priceTrackerInvalidSnapshot =>
      'Instantané du suivi des prix invalide.';

  @override
  String get qrEnterUrl => 'Saisissez une URL.';

  @override
  String get qrGenerateTitle => 'Générer un code QR';

  @override
  String get qrGenerateSubtitle =>
      'Collez une URL et transformez-la en code QR scannable.';

  @override
  String get qrGenerate => 'Générer';

  @override
  String get qrEmptyTitle => 'Aucun code QR pour l\'instant';

  @override
  String get qrEmptySubtitle =>
      'Les codes que vous générez sont enregistrés ici pour pouvoir les rouvrir à tout moment.';

  @override
  String get qrCopyUrl => 'Copier l\'URL';

  @override
  String get recipeBookCouldNotLoadPhoto => 'Impossible de charger la photo.';

  @override
  String recipeBookServerError(int status) {
    return 'Erreur du serveur ($status).';
  }

  @override
  String get recipeBookSignInToManage =>
      'Connectez-vous pour gérer les recettes publiées.';

  @override
  String get recipeBookNotFound => 'Recette introuvable.';

  @override
  String get recipeBookSavedPrivately =>
      'Enregistrée en privé. Connectez-vous dans Paramètres → Synchronisation pour la publier.';

  @override
  String recipeBookCouldNotPublish(String error) {
    return 'Impossible de publier : $error';
  }

  @override
  String recipeBookCouldNotUpdatePublished(String error) {
    return 'Impossible de mettre à jour la version publiée : $error';
  }

  @override
  String get recipeBookCouldNotReachServer =>
      'Impossible de joindre le serveur.';

  @override
  String recipeBookCouldNotPostReview(String error) {
    return 'Impossible de publier votre avis : $error';
  }

  @override
  String get recipeBookSignInToReview =>
      'Connectez-vous pour évaluer les recettes.';

  @override
  String get recipeBookSignInToManageReviews =>
      'Connectez-vous pour gérer les avis.';

  @override
  String get recipeBookInvalidSnapshot =>
      'Instantané du livre de recettes invalide.';

  @override
  String get recipeBookSearchHint => 'Rechercher des recettes…';

  @override
  String get recipeBookTabFavourites => 'Favoris';

  @override
  String recipeBookTabFavouritesCount(int count) {
    return 'Favoris ($count)';
  }

  @override
  String get recipeBookTabPublic => 'Publiques';

  @override
  String get recipeBookTabPrivate => 'Privées';

  @override
  String get recipeBookCategoryBreakfast => 'Petit-déjeuner';

  @override
  String get recipeBookCategoryLunch => 'Déjeuner';

  @override
  String get recipeBookCategoryDinner => 'Dîner';

  @override
  String get recipeBookCategoryDessert => 'Dessert';

  @override
  String get recipeBookCategorySnack => 'En-cas';

  @override
  String get recipeBookCategoryDrink => 'Boisson';

  @override
  String get recipeBookCategoryBaking => 'Pâtisserie';

  @override
  String get recipeBookNoRecipesYet => 'Aucune recette pour l\'instant';

  @override
  String get recipeBookNoRecipesFound => 'Aucune recette trouvée';

  @override
  String get recipeBookAddFirstHint =>
      'Appuyez sur le bouton + pour ajouter votre première recette.';

  @override
  String get recipeBookTryOtherSearch =>
      'Essayez une autre recherche ou catégorie.';

  @override
  String get recipeBookSignInToBrowseTitle =>
      'Connectez-vous pour parcourir les recettes publiques';

  @override
  String get recipeBookSignInToBrowseSubtitle =>
      'Les recettes publiques sont partagées via votre compte de synchronisation. Connectez-vous dans Paramètres → Synchronisation et compte pour parcourir, publier, noter et commenter.';

  @override
  String get recipeBookCouldNotLoadPublic =>
      'Impossible de charger les recettes publiques';

  @override
  String get recipeBookNoPublicYet => 'Aucune recette publique pour l\'instant';

  @override
  String get recipeBookPublishFirstHint =>
      'Publiez l\'une de vos recettes pour lancer le catalogue.';

  @override
  String get recipeBookNoFavouritesYet => 'Aucun favori pour l\'instant';

  @override
  String get recipeBookFavouritesHint =>
      'Appuyez sur le cœur d\'une recette — privée ou publique — pour la garder ici.';

  @override
  String get recipeBookNew => 'Nouveau';

  @override
  String get recipeBookYou => 'Vous';

  @override
  String get recipeBookPlanner => 'Planificateur';

  @override
  String get recipeCategoryBreakfast => 'Petit-déjeuner';

  @override
  String get recipeCategoryLunch => 'Déjeuner';

  @override
  String get recipeCategoryDinner => 'Dîner';

  @override
  String get recipeCategoryDessert => 'Dessert';

  @override
  String get recipeCategorySnack => 'Snack';

  @override
  String get recipeCategoryDrink => 'Boisson';

  @override
  String get recipeCategoryBaking => 'Pâtisserie';

  @override
  String get recipeCategoryOther => 'Autre';

  @override
  String get recipeUnitNone => 'Unité';

  @override
  String get recipeUnitG => 'g';

  @override
  String get recipeUnitKg => 'kg';

  @override
  String get recipeUnitMl => 'ml';

  @override
  String get recipeUnitL => 'l';

  @override
  String get recipeUnitTsp => 'cc';

  @override
  String get recipeUnitTbsp => 'c. à soupe';

  @override
  String get recipeUnitCup => 'tasse';

  @override
  String get recipeUnitOz => 'oz';

  @override
  String get recipeUnitLb => 'lb';

  @override
  String get recipeUnitPiece => 'pièce';

  @override
  String get recipeUnitSlice => 'tranche';

  @override
  String get recipeUnitPinch => 'pincée';

  @override
  String get recipeUnitToTaste => 'à goût';

  @override
  String recipeTimeMinutes(int count) {
    return '$count min';
  }

  @override
  String recipeTimeHours(int count) {
    return '$count h';
  }

  @override
  String recipeTimeHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get recipeSomeone => 'Quelqu\'un';

  @override
  String get recipeSharedToPublic => 'Partagé dans Public';

  @override
  String get recipePrivateRecipe => 'Recette privée';

  @override
  String get recipeRemoveFromPublic => 'Retirer de Public';

  @override
  String recipeConfirmTitle(String action) {
    return '$action la recette ?';
  }

  @override
  String recipeConfirmRemoveBody(String title) {
    return '\"$title\" sera retiré du catalogue public.';
  }

  @override
  String recipeConfirmDeleteBody(String title) {
    return '\"$title\" sera définitivement supprimé.';
  }

  @override
  String recipeByAuthor(String name) {
    return 'par $name';
  }

  @override
  String recipeByAuthorYou(String name) {
    return 'par $name · vous';
  }

  @override
  String get recipeNoRatingsYet => 'Pas encore d\'évaluations';

  @override
  String recipeRatingSummary(String average, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count évaluations',
      one: '1 évaluation',
    );
    return '$average · $_temp0';
  }

  @override
  String recipeReviewsCount(int count) {
    return 'Avis ($count)';
  }

  @override
  String get recipeBeFirstToReview =>
      'Soyez le premier à évaluer cette recette.';

  @override
  String get recipePickRatingFirst =>
      'Choisissez d\'abord une note en étoiles.';

  @override
  String get recipeThanksForReview => 'Merci pour votre avis !';

  @override
  String get recipeYourReview => 'Votre avis';

  @override
  String get recipeWriteReview => 'Écrire un avis';

  @override
  String get recipeReviewHint => 'Partagez le résultat… (facultatif)';

  @override
  String get recipeAddPhoto => 'Ajouter une photo';

  @override
  String get recipeChangePhoto => 'Changer la photo';

  @override
  String get recipePostReview => 'Publier l\'avis';

  @override
  String get recipeReviewYou => 'Vous';

  @override
  String recipeServingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count portions',
      one: '1 portion',
    );
    return '$_temp0';
  }

  @override
  String recipePrepTime(String time) {
    return 'Préparation : $time';
  }

  @override
  String recipeCookTime(String time) {
    return 'Cuisson : $time';
  }

  @override
  String get recipeIngredients => 'Ingrédients';

  @override
  String get recipeInstructions => 'Préparation';

  @override
  String get recipeAddIngredient => 'Ajouter un ingrédient';

  @override
  String get recipeAddStep => 'Ajouter une étape';

  @override
  String get recipeIngredientHint => 'Ingrédient';

  @override
  String get recipeAmountHint => 'Qté';

  @override
  String get recipeStepHint => 'Décrivez cette étape…';

  @override
  String get recipeTitleRequired => 'Donnez un titre à votre recette.';

  @override
  String get recipeEditTitle => 'Modifier la recette';

  @override
  String get recipeNewTitle => 'Nouvelle recette';

  @override
  String get recipeStepsTab => 'Étapes';

  @override
  String get recipeSaveChanges => 'Enregistrer les modifications';

  @override
  String get recipeAddRecipe => 'Ajouter la recette';

  @override
  String get recipeAddARecipe => 'Ajouter une recette';

  @override
  String get recipeTitleHint => 'ex. Spaghetti carbonara';

  @override
  String get recipeDescriptionLabel => 'Description (facultatif)';

  @override
  String get recipeDescriptionHint => 'Une courte note sur cette recette…';

  @override
  String get recipeCategoryField => 'Catégorie';

  @override
  String get recipeServingsLabel => 'Portions';

  @override
  String get recipePrepTimeLabel => 'Temps de préparation (min)';

  @override
  String get recipeCookTimeLabel => 'Temps de cuisson (min)';

  @override
  String get recipeShareToPublic => 'Partager sur Public';

  @override
  String get recipeShareToPublicHint =>
      'Publiez-le pour que d\'autres utilisateurs de luma le trouvent, le notent et le commentent.';

  @override
  String get recipeSignInToPublish =>
      'Connectez-vous dans Paramètres → Synchronisation pour publier des recettes.';

  @override
  String get recipePhotoOptional => 'Photo (facultatif)';

  @override
  String get recipeReplacePhoto => 'Remplacer';

  @override
  String get recipeChoosePhoto => 'Choisir une photo';

  @override
  String get recipePlannerTitle => 'Planificateur de repas';

  @override
  String get recipeThisWeek => 'Cette semaine';

  @override
  String get recipeJumpToThisWeek => 'Aller à cette semaine';

  @override
  String get recipeWeekStartsOn => 'La semaine commence le';

  @override
  String get recipeNothingPlanned => 'Rien de prévu pour l\'instant.';

  @override
  String recipeCategoryPublic(String category) {
    return '$category · public';
  }

  @override
  String get recipeTabMyRecipes => 'Mes recettes';

  @override
  String get recipeTabPublic => 'Public';

  @override
  String get recipeNoRecipesYet => 'Vous n\'avez pas encore de recettes.';

  @override
  String get recipeNoMatches => 'Aucun résultat.';

  @override
  String get recipeSignInToBrowse =>
      'Connectez-vous pour parcourir les recettes publiques.';

  @override
  String get recipeNoPublicRecipesYet => 'Pas encore de recettes publiques.';

  @override
  String get recipeSearchHint => 'Rechercher des recettes…';

  @override
  String get mafiaRoleCountingTitle => 'Comptage des rôles';

  @override
  String get mafiaRoleCountingIntro =>
      'Choisissez le nombre de joueurs dans le lobby, puis cochez les rôles au fur et à mesure qu\'ils sont réclamés.';

  @override
  String get mafiaRoleCountingPlayersInLobby => 'Joueurs dans le lobby';

  @override
  String get mafiaRoleCountingLowCountWarning =>
      'Le wiki signale que ses données pour moins de 7 joueurs peuvent être inexactes : considérez ce nombre comme une estimation.';

  @override
  String mafiaRoleCountingClaimedOfTotal(int claimed, int total) {
    return '$claimed / $total réclamés';
  }

  @override
  String get mafiaRoleCountingNoRoles =>
      'Aucun rôle pour cette taille de lobby';

  @override
  String get mafiaRoleCountingNoRolesHint =>
      'Essayez un autre nombre de joueurs.';

  @override
  String get mafiaRoleCountingClaimed => 'Réclamé';

  @override
  String get mafiaRoleCountingClaimedBy => 'Réclamé par… (nom de déguisement)';

  @override
  String get mafiaFactionTown => 'Village';

  @override
  String get mafiaFactionNeutral => 'Neutre';

  @override
  String get mafiaFactionMafia => 'Mafia';

  @override
  String get mafiaFactionVeil => 'Voile';

  @override
  String get mafiaFactionTownWin => 'Gagne en éliminant la Mafia';

  @override
  String get mafiaFactionNeutralWin => 'A sa propre condition de victoire';

  @override
  String get mafiaFactionMafiaWin =>
      'Gagne à égalité numérique avec le Village';

  @override
  String get mafiaFactionVeilWin => 'Gagne en atteignant 100 % de corruption';

  @override
  String get schoolCitationSourceBook => 'Livre';

  @override
  String get schoolCitationSourceWebsite => 'Site web';

  @override
  String get schoolCitationSourceJournalArticle => 'Article de revue';

  @override
  String get schoolCitationSourceNewspaper => 'Article de journal';

  @override
  String get schoolCitationSourceVideo => 'Vidéo';

  @override
  String get schoolQuizLevel => 'Groupe 8 · entraînement pour le test IEP';

  @override
  String get schoolQuizBlurbRekenen =>
      'Nombres, rapports, mesure et géométrie, relations';

  @override
  String get schoolQuizBlurbTaalverzorging =>
      'Orthographe, accord des verbes et ponctuation';

  @override
  String get schoolQuizBlurbLezen =>
      'Comprendre des textes, résumer, sens des mots et recherche';

  @override
  String get schoolQuizBlurbEngels =>
      'Exercices supplémentaires · Anglais pour le secondaire supérieur et la première année';

  @override
  String get schoolQuizBlurbAardrijkskunde =>
      'Exercices supplémentaires · Pays-Bas, Europe, monde et météo';

  @override
  String get schoolQuizBlurbGeschiedenis =>
      'Exercices supplémentaires · Les dix époques, des chasseurs à aujourd\'hui';

  @override
  String get schoolQuizBlurbBiologie =>
      'Exercices supplémentaires · Corps, nature, énergie et technique';

  @override
  String get schoolQuizDefaultTitle => 'Test d\'entraînement, groupe 8';

  @override
  String get schoolQuizPickSubject => 'Choisissez au moins une matière.';

  @override
  String schoolQuizChooseBetween(int min, int max) {
    return 'Choisissez entre $min et $max questions.';
  }

  @override
  String get schoolQuizNotEnoughQuestions =>
      'Il n\'y a pas assez de questions disponibles pour ces matières.';

  @override
  String schoolQuizMaxQuestionsPerPdf(int max) {
    return 'Choisissez au maximum $max questions par PDF.';
  }

  @override
  String schoolQuizInvalidCount(String subject) {
    return 'Nombre de questions non valide pour $subject.';
  }

  @override
  String schoolQuizPdfRunningHeader(String section) {
    return 'LUMA SCHOOL  |  $section';
  }

  @override
  String get schoolQuizPdfSectionQuestions => 'Questions';

  @override
  String get schoolQuizPdfSectionAnswerSheet => 'Feuille de réponses';

  @override
  String schoolQuizPdfCountLine(int count, String mode) {
    return '$count questions | $mode';
  }

  @override
  String get schoolQuizPdfMixed => 'Matières mélangées';

  @override
  String get schoolQuizPdfPerSubject => 'Par matière';

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
    return 'Question $number - $subject - Texte $passage';
  }

  @override
  String schoolQuizPdfPassageHeading(String number) {
    return 'Texte $number';
  }

  @override
  String schoolQuizPdfPageOf(String page, String total) {
    return 'Page $page sur $total';
  }

  @override
  String get schoolQuizPdfNameDateLine =>
      'Nom : ........................................  Date : ........................';

  @override
  String get schoolQuizPdfInstructions =>
      'Lis bien chaque question. Coche la réponse ou écris la réponse demandée. Lorsqu\'il y a plusieurs réponses, la question indique combien en choisir.';

  @override
  String get schoolQuizPdfDisclaimer =>
      'Matériel d\'entraînement personnel. Ni test IEP officiel ni conseil scolaire.';

  @override
  String get schoolQuizPdfAnswerBlank =>
      'Réponse : .....................................';

  @override
  String get schoolQuizPdfAnswersHeading => 'Réponses';

  @override
  String get schoolQuizPdfAnswersNote =>
      'Pour la correction. Gardez cette feuille de réponses séparée des questions.';

  @override
  String get schoolTabDashboard => 'Tableau de bord';

  @override
  String get schoolTabTimetable => 'Emploi du temps';

  @override
  String get schoolTabAssignments => 'Devoirs';

  @override
  String get schoolTabFlashcards => 'Cartes mémoire';

  @override
  String get schoolTabPracticeTests => 'Tests d\'entraînement';

  @override
  String get schoolTabFormulas => 'Formules';

  @override
  String get schoolTabStudyTimer => 'Minuteur d\'étude';

  @override
  String get schoolTabGpa => 'GPA';

  @override
  String get schoolTabCitations => 'Citations';

  @override
  String get schoolPracticeTestSaveTitle =>
      'Enregistrer le test d\'entraînement en PDF';

  @override
  String get schoolPdfSaveUnsupported =>
      'L\'enregistrement de PDF n\'est pas pris en charge sur cet appareil.';

  @override
  String get schoolPriorityLow => 'Faible';

  @override
  String get schoolPriorityMedium => 'Moyenne';

  @override
  String get schoolPriorityHigh => 'Élevée';

  @override
  String get schoolPriority => 'Priorité';

  @override
  String get schoolAssignmentsShowCompleted => 'Afficher les terminés';

  @override
  String get schoolAssignmentsAdd => 'Ajouter un devoir';

  @override
  String get schoolAssignmentsEdit => 'Modifier le devoir';

  @override
  String get schoolAssignmentsEmpty => 'Aucun devoir';

  @override
  String get schoolAssignmentsEmptySub =>
      'Ajoutez des devoirs ou une tâche suivie pour les voir ici.';

  @override
  String schoolAssignmentDue(String date) {
    return 'À rendre le $date';
  }

  @override
  String get schoolSubject => 'Matière';

  @override
  String get schoolSubjectOptional => 'Matière (facultatif)';

  @override
  String get schoolCitationsNew => 'Nouvelle citation';

  @override
  String get schoolCitationStyle => 'Style';

  @override
  String get schoolCitationSourceType => 'Type de source';

  @override
  String get schoolCitationAuthor => 'Auteur (nom, prénom)';

  @override
  String get schoolCitationYear => 'Année';

  @override
  String get schoolCitationPublisher => 'Éditeur';

  @override
  String get schoolCitationContainer => 'Site web / revue';

  @override
  String get schoolCitationVolume => 'Volume';

  @override
  String get schoolCitationIssue => 'Numéro';

  @override
  String get schoolCitationPages => 'Pages';

  @override
  String get schoolCitationCity => 'Ville';

  @override
  String get schoolCitationAccessDate => 'Date d\'accès';

  @override
  String get schoolCitationPreviewEmpty => 'L\'aperçu apparaîtra ici.';

  @override
  String get schoolCitationSave => 'Enregistrer la citation';

  @override
  String get schoolCitationsEmpty => 'Aucune citation enregistrée';

  @override
  String get schoolSubjects => 'Matières';

  @override
  String get schoolStatDueThisWeek => 'À rendre cette semaine';

  @override
  String get schoolStatOverdue => 'En retard';

  @override
  String get schoolAddSubject => 'Ajouter une matière';

  @override
  String get schoolDashboardNoSubjects =>
      'Aucune matière pour l\'instant. Ajoutez-en une pour commencer.';

  @override
  String get schoolDashboardNoClasses => 'Aucun cours prévu aujourd\'hui.';

  @override
  String get schoolDashboardDueSoon => 'À rendre bientôt';

  @override
  String get schoolDashboardNothingDueSoon =>
      'Rien à rendre dans les 7 prochains jours.';

  @override
  String get schoolClassFallback => 'Cours';

  @override
  String get schoolFormulasSearchHint => 'Rechercher des formules';

  @override
  String get schoolFormulasAdd => 'Ajouter une formule';

  @override
  String get schoolFormulasEdit => 'Modifier la formule';

  @override
  String get schoolFormulasEmpty => 'Aucune formule pour l\'instant';

  @override
  String get schoolFormulasEmptySub =>
      'Ajoutez vos propres formules pour créer votre bibliothèque de référence.';

  @override
  String get schoolFormulaExpression => 'Expression';

  @override
  String get schoolFormulaDescriptionOptional => 'Description (facultative)';

  @override
  String get schoolDeckNameHint => 'Nom du nouveau paquet';

  @override
  String get schoolFlashcardsCreateDeck => 'Créer un paquet';

  @override
  String get schoolFlashcardsNoDecks => 'Aucun paquet pour l\'instant';

  @override
  String get schoolFlashcardsNoDecksSub =>
      'Créez un paquet, puis ajoutez des cartes pour commencer à réviser.';

  @override
  String schoolFlashcardsCardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cartes',
      one: '1 carte',
    );
    return '$_temp0';
  }

  @override
  String schoolFlashcardsDueNow(int count) {
    return '$count à réviser';
  }

  @override
  String schoolFlashcardsDeckSummary(int total, int due) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total cartes',
      one: '1 carte',
    );
    return '$_temp0 · $due à réviser';
  }

  @override
  String get schoolFlashcardsAddCard => 'Ajouter une carte';

  @override
  String get schoolFlashcardsEditCard => 'Modifier la carte';

  @override
  String get schoolFlashcardsStudyNow => 'Étudier maintenant';

  @override
  String get schoolFlashcardsNoCards => 'Aucune carte dans ce paquet';

  @override
  String get schoolFlashcardsNoCardsSub =>
      'Ajoutez une carte recto/verso pour commencer à réviser.';

  @override
  String schoolFlashcardsReviewStats(
    int reviews,
    int accuracy,
    String seconds,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      reviews,
      locale: localeName,
      other: '$reviews révisions',
      one: '1 révision',
    );
    return '$_temp0 · $accuracy % correct · moy. $seconds s';
  }

  @override
  String get schoolCardFront => 'Recto';

  @override
  String get schoolCardBack => 'Verso';

  @override
  String schoolFlashcardsCardOf(int current, int total) {
    return 'Carte $current sur $total';
  }

  @override
  String get schoolFlashcardsTypeAnswer => 'Tapez votre réponse';

  @override
  String get schoolFlashcardsCorrect => 'Correct';

  @override
  String get schoolFlashcardsNotQuite => 'Pas tout à fait';

  @override
  String schoolFlashcardsAnswer(String back) {
    return 'Réponse : $back';
  }

  @override
  String get schoolFlashcardsCheckAnswer => 'Vérifier la réponse';

  @override
  String get schoolGpaGradeCalculator => 'Calculateur de notes';

  @override
  String get schoolGpaOverallGpa => 'GPA global';

  @override
  String get schoolGpaOverallGrade => 'Moyenne générale';

  @override
  String get schoolGpaAddRecord => 'Ajouter un résultat';

  @override
  String get schoolGpaAddRecordTitle => 'Ajouter un résultat GPA';

  @override
  String get schoolGpaTrend => 'Tendance';

  @override
  String get schoolGpaNoRecords => 'Aucun résultat GPA pour l\'instant';

  @override
  String get schoolGpaNoRecordsSub =>
      'Enregistrez la note d\'un trimestre terminé pour suivre votre GPA.';

  @override
  String schoolGpaRecordAmerican(String term, String credits, String points) {
    return '$term · $credits crédits · $points pts';
  }

  @override
  String schoolGpaRecordDutch(String term, String credits, String points) {
    return '$term · $credits crédits · $points';
  }

  @override
  String get schoolGpaCreditHours => 'Crédits';

  @override
  String get schoolGpaTermLabel => 'Trimestre (p. ex. automne 2026)';

  @override
  String get schoolGpaFinalPercentage => 'Note finale en pourcentage';

  @override
  String get schoolGpaFinalGrade => 'Note finale (1-10)';

  @override
  String schoolGpaPointsHelper(String points) {
    return '= $points points GPA';
  }

  @override
  String get schoolGradeNoSubjects => 'Aucune matière pour l\'instant';

  @override
  String get schoolGradeNoSubjectsSub =>
      'Ajoutez une matière pour commencer à pondérer ses composantes de notes.';

  @override
  String get schoolGradeAddComponent => 'Ajouter un élément';

  @override
  String get schoolGradeEditComponent => 'Modifier l\'élément';

  @override
  String get schoolGradeCurrent => 'Note actuelle';

  @override
  String get schoolGradeTarget => 'Note cible en %';

  @override
  String schoolGradeWeightGraded(String percent) {
    return '$percent % de la pondération notée';
  }

  @override
  String get schoolGradeAddUngraded =>
      'Ajoutez des éléments non notés pour faire une projection';

  @override
  String schoolGradeNeeded(String percent) {
    return 'Il faut $percent % sur le reste';
  }

  @override
  String get schoolGradeNoComponents => 'Aucun élément de note pour l\'instant';

  @override
  String get schoolGradeNoComponentsSub =>
      'Ajoutez des éléments pondérés comme « Partiel » ou « Examen final ».';

  @override
  String schoolGradeComponentScored(
    String weight,
    String earned,
    String total,
  ) {
    return '$weight % de pondération · $earned/$total';
  }

  @override
  String schoolGradeComponentUngraded(String weight) {
    return '$weight % de pondération · pas encore noté';
  }

  @override
  String get schoolGradeNameLabel => 'Nom (p. ex. partiel)';

  @override
  String get schoolGradeWeightLabel => 'Pondération (%)';

  @override
  String get schoolGradeScoreEarned => 'Score obtenu (facultatif)';

  @override
  String get schoolGradeOutOf => 'Sur';

  @override
  String get schoolSubjectAddTitle => 'Ajouter une matière';

  @override
  String get schoolSubjectEditTitle => 'Modifier la matière';

  @override
  String get schoolSubjectCreditHours => 'Crédits';

  @override
  String get schoolSubjectGroupOther =>
      'Autres matières · entraînement supplémentaire';

  @override
  String get schoolTimetableWeeklySchedule => 'Emploi du temps hebdomadaire';

  @override
  String get schoolTimetableAddClass => 'Ajouter un cours';

  @override
  String get schoolTimetableNoClasses => 'Aucun cours programmé';

  @override
  String get schoolTimetableAddSubjectFirst =>
      'Ajoutez d\'abord une matière, puis ses horaires de cours.';

  @override
  String get schoolTimetableTapAddClass =>
      'Appuyez sur « Ajouter un cours » pour créer votre emploi du temps.';

  @override
  String get schoolTimetableClass => 'Cours';

  @override
  String get schoolTimetableSubject => 'Matière';

  @override
  String get schoolTimetableDay => 'Jour';

  @override
  String schoolTimetableStart(String time) {
    return 'Début : $time';
  }

  @override
  String schoolTimetableEnd(String time) {
    return 'Fin : $time';
  }

  @override
  String get schoolTimetableLocation => 'Lieu (facultatif)';

  @override
  String get schoolTimetableInstructor => 'Enseignant (facultatif)';

  @override
  String get schoolStudyTimeBySubject => 'Temps par matière';

  @override
  String get schoolStudyNoSessionsLogged =>
      'Aucune session d\'étude enregistrée pour l\'instant.';

  @override
  String get schoolStudyRecentSessions => 'Sessions récentes';

  @override
  String get schoolStudyNoCompletedSessions => 'Aucune session terminée';

  @override
  String get schoolStudyNoSubject => 'Aucune matière';

  @override
  String schoolStudySessionMeta(String date, int minutes) {
    return '$date · $minutes min';
  }

  @override
  String get schoolStudyStartStudying => 'Commencer à étudier';

  @override
  String get schoolStudySubjectOptional => 'Matière (facultatif)';

  @override
  String get schoolStudyStartTimer => 'Démarrer le minuteur';

  @override
  String get schoolStudyStudying => 'En étude';

  @override
  String get schoolPdfDefaultTitle => 'Test d\'entraînement, groupe 8';

  @override
  String get schoolPdfPickOneSubject => 'Choisissez au moins une matière.';

  @override
  String schoolPdfCountRange(String name, int max) {
    return 'Choisissez entre 1 et $max questions pour $name.';
  }

  @override
  String schoolPdfMaxQuestions(int max) {
    return 'Choisissez au maximum $max questions par PDF.';
  }

  @override
  String get schoolPdfSaveCancelled => 'Enregistrement annulé.';

  @override
  String schoolPdfSaved(String path) {
    return 'PDF enregistré : $path';
  }

  @override
  String get schoolPdfSaveFailed =>
      'Le PDF n\'a pas pu être enregistré. Réessayez.';

  @override
  String get schoolPdfAsPdf => 'Test d\'entraînement en PDF';

  @override
  String get schoolPdfTitle => 'Composez votre test d\'entraînement';

  @override
  String get schoolPdfIntro =>
      'Choisissez une ou plusieurs matières. Le PDF contient une nouvelle sélection sans questions en double, au format A4.';

  @override
  String get schoolPdfSectionLayout => 'Titre et mise en page';

  @override
  String get schoolPdfTitleField => 'Titre du PDF';

  @override
  String get schoolPdfSpreadTotal => 'Répartir un total';

  @override
  String get schoolPdfCountPerSubject => 'Nombre par matière';

  @override
  String get schoolPdfTotalQuestions => 'Nombre total de questions';

  @override
  String schoolPdfTotalHint(int max) {
    return 'Jusqu\'à $max ; réparti aussi équitablement que possible.';
  }

  @override
  String get schoolPdfGroupDoorstroom => 'Doorstroomtoets (test de passage)';

  @override
  String get schoolPdfOrder => 'Ordre';

  @override
  String get schoolPdfOrderPerSubject => 'Par matière';

  @override
  String get schoolPdfOrderMixed => 'Mélangé';

  @override
  String get schoolPdfOrderHelp =>
      'Les questions liées au même texte restent groupées. Avec « Par matière », chaque matière suivante commence sur une nouvelle page.';

  @override
  String get schoolPdfExtraWritingSpace => 'Espace d\'écriture supplémentaire';

  @override
  String get schoolPdfAddAnswerSheet => 'Ajouter une feuille de réponses';

  @override
  String get schoolPdfAnswerSheetHelp =>
      'Commence sur une nouvelle page après les questions.';

  @override
  String get schoolPdfExplanations => 'Explications des réponses';

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
      other: '$subjects matières',
      one: '1 matière',
    );
    return '$_temp0 · $_temp1 · $order';
  }

  @override
  String get schoolPdfMaking => 'Création du PDF…';

  @override
  String get schoolPdfMakeAndSave => 'Créer et enregistrer le PDF';

  @override
  String schoolPdfAvailable(int count) {
    return '$count disponibles';
  }

  @override
  String schoolPdfAvailableInPdf(int count, int inPdf) {
    return '$count disponibles · $inPdf dans le PDF';
  }

  @override
  String schoolPdfCountLabel(String name) {
    return 'Nombre de questions pour $name';
  }

  @override
  String get schoolTestsTitle => 'Tests d\'entraînement';

  @override
  String schoolTestsIntro(String level, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total questions',
      one: '1 question',
    );
    return '$level. Questions d\'entraînement propres, dans les formats de l\'IEP, et non un test IEP officiel. Pour la doorstroomtoets, vous vous entraînez en calcul, lecture et langue. Les autres matières sont un entraînement supplémentaire. Votre score d\'entraînement n\'est ni un avis de test ni une détermination de niveau. $_temp0 dans la banque.';
  }

  @override
  String get schoolTestsChooseSubject => 'Choisissez une matière';

  @override
  String get schoolTestsGroupPractice => 'Entraînement à l\'IEP';

  @override
  String get schoolTestsHowMany => 'Combien de questions ?';

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
  String get schoolTestsWhatYouGet => 'Ce que vous obtenez';

  @override
  String get schoolTestsWhatYouGetBody =>
      'Les questions sont réparties équitablement entre les thèmes, pour vous entraîner à différentes compétences. Lisez bien chaque consigne : parfois vous choisissez une réponse, parfois vous complétez. Vous ne voyez les explications qu\'après la correction.';

  @override
  String get schoolTestsChooseFirst => 'Choisissez d\'abord une matière';

  @override
  String schoolTestsStartTest(String subject) {
    return 'Commencer le test $subject';
  }

  @override
  String get schoolTestsPdfBannerSub =>
      'Composez un test imprimable avec vos propres matières et nombres de questions.';

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
      other: '$topics thèmes',
      one: '1 thème',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String schoolTestsProgress(int number, int total, int answered) {
    return 'Question $number sur $total · réponses : $answered';
  }

  @override
  String get schoolTestsYourAnswer => 'Votre réponse';

  @override
  String get schoolTestsHelperNumber =>
      'Saisissez uniquement le nombre. Utilisez une virgule pour les décimales.';

  @override
  String get schoolTestsHelperWord =>
      'Saisissez uniquement le mot demandé ou les lettres manquantes.';

  @override
  String get schoolTestsCheck => 'Corriger';

  @override
  String get schoolTestsCheckNow => 'Corriger maintenant';

  @override
  String schoolTestsCorrectOf(int correct, int total) {
    return '$correct sur $total juste(s)';
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
      other: ' · $skipped passée(s)',
      zero: '',
    );
    return '$subject · $duration · $perQuestion par question$_temp0';
  }

  @override
  String get schoolTestsPerTopic => 'Par thème';

  @override
  String get schoolTestsNewTest => 'Nouveau test';

  @override
  String get schoolTestsOtherSubject => 'Autre matière';

  @override
  String get schoolTestsAnswers => 'Réponses';

  @override
  String get schoolTestsOnlyMistakes => 'Erreurs seulement';

  @override
  String get schoolTestsAllQuestions => 'Toutes les questions';

  @override
  String get schoolTestsAllCorrect => 'Tout juste';

  @override
  String get schoolTestsNoMistakes => 'Aucune erreur à revoir.';

  @override
  String get schoolTestsSkippedThis => 'Vous avez passé cette question.';

  @override
  String get schoolTestsAnsweredCorrectly => 'Bonne réponse.';

  @override
  String schoolTestsYourAnswerValue(String answer) {
    return 'Votre réponse : $answer';
  }

  @override
  String schoolTestsCorrectAnswerValue(String answer) {
    return 'Bonne réponse : $answer';
  }

  @override
  String schoolTestsQuestionNumber(int number) {
    return 'Question $number';
  }

  @override
  String schoolTestsDurationSec(int seconds) {
    return '$seconds s';
  }

  @override
  String schoolTestsDurationMinSec(int minutes, int seconds) {
    return '$minutes min $seconds s';
  }

  @override
  String get secureChatNotReady =>
      'Le chiffrement du chat n\'est pas encore prêt.';

  @override
  String get secureChatPeerNoKey =>
      'Cette personne n\'a pas encore configuré le chiffrement du chat — réessayez plus tard.';

  @override
  String get secureChatNotSignedIn => 'Non connecté.';

  @override
  String get secureChatIdentityLoadFailed =>
      'L\'identité du chat n\'a pas pu être chargée. Restaurez l\'identité d\'origine.';

  @override
  String secureChatServerError(int status) {
    return 'Erreur du serveur ($status).';
  }

  @override
  String get secureChatTitle => 'Chat chiffré de bout en bout';

  @override
  String get secureChatPickOrInvite =>
      'Choisissez une conversation ou invitez quelqu\'un par e-mail.';

  @override
  String get secureChatBack => 'Discussions';

  @override
  String get secureChatNeedsSyncTitle => 'Le chat nécessite la synchronisation';

  @override
  String get secureChatNeedsSyncBody =>
      'Connectez-vous dans Paramètres → Synchronisation et compte pour inviter des personnes et discuter. Les messages sont chiffrés de bout en bout sur cet appareil : le serveur ne transmet que du texte chiffré.';

  @override
  String get secureChatHeading => 'Chat';

  @override
  String get secureChatNewChat => 'Nouvelle discussion';

  @override
  String get secureChatInviteSent => 'Invitation envoyée.';

  @override
  String get secureChatNoChatsYet => 'Aucune discussion pour l\'instant';

  @override
  String get secureChatNoChatsHint =>
      'Invitez quelqu\'un avec son e-mail et dites bonjour.';

  @override
  String get secureChatWaitingForEncryption =>
      'En attente de la configuration du chiffrement…';

  @override
  String get secureChatNoMessagesYet => 'Aucun message pour l\'instant';

  @override
  String get secureChatInvites => 'Invitations';

  @override
  String secureChatWantsToChat(String email) {
    return '$email souhaite discuter';
  }

  @override
  String get secureChatSayHello => 'Dites bonjour';

  @override
  String get secureChatMessagesEncrypted =>
      'Les messages ici sont chiffrés de bout en bout.';

  @override
  String secureChatPeerNotReady(String email) {
    return '$email n\'a pas encore configuré le chiffrement du chat sur un appareil — vous pourrez lui écrire dès qu\'il l\'aura fait.';
  }

  @override
  String get secureChatMessageHint => 'Message…';

  @override
  String get secureChatCouldNotDecrypt =>
      'Impossible de déchiffrer ce message.';

  @override
  String get secureChatEnterValidEmail =>
      'Saisissez une adresse e-mail valide.';

  @override
  String get secureChatInviteTitle => 'Démarrer une discussion chiffrée';

  @override
  String get secureChatInviteBody =>
      'Ils verront l\'invitation dans Chat → Invitations la prochaine fois qu\'ils ouvriront Luma. Une fois acceptée, chaque message est chiffré de bout en bout : vous seuls pouvez les lire.';

  @override
  String get secureChatSendInvite => 'Envoyer l\'invitation';

  @override
  String get serverTycoonAchFirstGrand => 'Premier millier';

  @override
  String get serverTycoonAchFiveFigures => 'Cinq chiffres';

  @override
  String get serverTycoonAchSixFigures => 'Six chiffres';

  @override
  String get serverTycoonAchMillionaire => 'Millionnaire du datacenter';

  @override
  String get serverTycoonAchTrustedHost => 'Hébergeur de confiance';

  @override
  String get serverTycoonAchWellRegarded => 'Bien considéré';

  @override
  String get serverTycoonAchIndustryLeader => 'Leader du secteur';

  @override
  String get serverTycoonAchPerfectReputation => 'Réputation parfaite';

  @override
  String get serverTycoonAchOneWeekIn => 'Une semaine d\'activité';

  @override
  String get serverTycoonAchOneMonthIn => 'Un mois d\'activité';

  @override
  String get serverTycoonAchCenturyClub => 'Club des cent';

  @override
  String get serverTycoonAchOldGuard => 'Vieille garde';

  @override
  String get serverTycoonAchGigabitPipe => 'Tuyau gigabit';

  @override
  String get serverTycoonAchTenGigBackbone => 'Épine dorsale 10 Gig';

  @override
  String get serverTycoonAchFirstDeal => 'Premier contrat';

  @override
  String get serverTycoonAchDealMaker => 'Faiseur d\'affaires';

  @override
  String get serverTycoonAchContractMachine => 'Machine à contrats';

  @override
  String get serverTycoonAchReliableHost => 'Hébergeur fiable';

  @override
  String get serverTycoonAchRockSolid => 'Solide comme un roc';

  @override
  String get serverTycoonAchGrowingFleet => 'Flotte en croissance';

  @override
  String get serverTycoonAchScaledUp => 'Mise à l\'échelle';

  @override
  String get serverTycoonAchMegaFleet => 'Méga flotte';

  @override
  String get serverTycoonAchContractLegend => 'Légende des contrats';

  @override
  String get serverTycoonAchBandwidthKing => 'Roi de la bande passante';

  @override
  String get serverTycoonAchUnbreakable => 'Incassable';

  @override
  String get serverTycoonAchPrestigeMaster => 'Maître du prestige';

  @override
  String get serverTycoonAchTenMillion => 'Club des dix millions';

  @override
  String serverTycoonAchEarnTotalDesc(String amount) {
    return 'Gagnez un total de $amount sur toute la partie.';
  }

  @override
  String serverTycoonAchReputationDesc(int count) {
    return 'Atteignez $count de réputation.';
  }

  @override
  String serverTycoonAchSurviveDaysDesc(int count) {
    return 'Survivez $count jours en affaires.';
  }

  @override
  String serverTycoonAchBandwidthDesc(String amount) {
    return 'Servez $amount Mbit/s de bande passante en même temps.';
  }

  @override
  String get serverTycoonAchFirstDealDesc => 'Terminez votre premier contrat.';

  @override
  String serverTycoonAchContractsDesc(int count) {
    return 'Terminez $count contrats.';
  }

  @override
  String serverTycoonAchUptimeDesc(int count) {
    return 'Maintenez $count jours consécutifs de disponibilité sans surcharge ni échec de contrat.';
  }

  @override
  String serverTycoonAchRigsDesc(int count) {
    return 'Possédez $count serveurs à la fois.';
  }

  @override
  String get serverTycoonAchRebirthDesc => 'Renaissance pour la première fois.';

  @override
  String serverTycoonAchPrestigeDesc(int count) {
    return 'Atteignez le niveau de prestige $count.';
  }

  @override
  String get serverTycoonBoostOverclockName => 'Overclocking';

  @override
  String get serverTycoonBoostOverclockDescription =>
      'Poussez chaque serveur à 25 % au-delà des specs. Consomme 30 % d\'énergie en plus et chauffe davantage.';

  @override
  String get serverTycoonBoostMarketingPushName => 'Campagne marketing';

  @override
  String get serverTycoonBoostMarketingPushDescription =>
      'Une dépense publicitaire qui rapporte une offre de contrat supplémentaire par jour et des paiements meilleurs de 15 %.';

  @override
  String get serverTycoonBoostColdSnapName => 'Vague de froid';

  @override
  String get serverTycoonBoostColdSnapDescription =>
      'Des refroidisseurs portables loués offrent 20 % de marge de refroidissement en plus et un matériel plus stable.';

  @override
  String get serverTycoonBoostSurgePricingName => 'Tarifs de pointe';

  @override
  String get serverTycoonBoostSurgePricingDescription =>
      'Pratiquez des tarifs de pointe pendant deux jours : 35 % de revenus de service en plus pendant cette période.';

  @override
  String get serverTycoonCompanyBakeryBlurb =>
      'Une boulangerie familiale qui veut juste mettre son menu en ligne sans que le site plante.';

  @override
  String get serverTycoonCompanyPixelPalsBlurb =>
      'Studio de jeux indépendant qui cherche un hébergement de bots pour son Discord communautaire.';

  @override
  String get serverTycoonCompanyStreamForgeBlurb =>
      'Un collectif de streamers qui a besoin de serveurs vocaux à toute épreuve pour la soirée podcast.';

  @override
  String get serverTycoonCompanyNimbusSoftBlurb =>
      'Une startup SaaS qui vous confie son environnement d\'API de staging.';

  @override
  String get serverTycoonCompanyDataVaultBlurb =>
      'Revendeurs de sauvegardes à la recherche d\'un stockage cloud bon marché mais fiable.';

  @override
  String get serverTycoonCompanyCraftedRealmsBlurb =>
      'Un réseau communautaire Minecraft qui loue des places de joueurs en surplus.';

  @override
  String get serverTycoonCompanyQuantumQuarryBlurb =>
      'Cabinet d\'analyse de données qui veut des bases de données gérées sans équipe d\'exploitation.';

  @override
  String get serverTycoonCompanyAegisSecureBlurb =>
      'Entreprise de confidentialité qui revend des points d\'accès VPN sous sa propre marque.';

  @override
  String get serverTycoonCompanyGlobexMediaBlurb =>
      'Un groupe de médias qui a besoin de capacité CDN en périphérie, près de ses spectateurs.';

  @override
  String get serverTycoonCompanyHeliosAiBlurb =>
      'Laboratoire d\'IA qui loue de la capacité d\'inférence pendant que son propre cluster est en rupture.';

  @override
  String get serverTycoonCompanyOmniCorpBlurb =>
      'Géant de l\'entreprise. Exigeant, mais les chèques passent toujours et ne sont jamais refusés.';

  @override
  String get serverTycoonCompanyDockerHarborBlurb =>
      'Une startup native des conteneurs qui a besoin de capacité d\'orchestration le temps de construire son propre cluster.';

  @override
  String get serverTycoonCompanyCodeForgeDevOpsBlurb =>
      'Une entreprise d\'outils de développement qui externalise sa ferme de build CI/CD et ses API de staging.';

  @override
  String get serverTycoonCompanyMegacastNetworkBlurb =>
      'Un réseau de podcasts qui a besoin de voix à faible latence et de relais de flux pour ses événements en direct.';

  @override
  String get serverTycoonCompanyStreamVerseBlurb =>
      'Une plateforme de streaming qui a besoin de capacité CDN en périphérie et de nœuds relais pour les pics d\'audience.';

  @override
  String get serverTycoonCompanyNexusContainersBlurb =>
      'Plateforme de conteneurs d\'entreprise qui loue à la fois de la capacité d\'orchestration et de stockage de sauvegarde.';

  @override
  String get serverTycoonCompanyOmnibuildCollectiveBlurb =>
      'Un regroupement de studios indépendants qui a besoin d\'exécuteurs CI/CD, de serveurs de jeu et de supervision.';

  @override
  String get serverTycoonCompanyTitanCloudBlurb =>
      'Un fournisseur cloud hyperscale qui loue de la capacité de conteneurs, de bases de données et d\'IA pendant son expansion.';

  @override
  String get serverTycoonCoolerStockName => 'Refroidisseur CPU d\'origine';

  @override
  String get serverTycoonCoolerCustomLoopName =>
      'Circuit d\'eau personnalisé - double radiateur 480 mm';

  @override
  String get serverTycoonCoolerRackAirHandlerName =>
      'Unité de traitement d\'air de précision pour baie';

  @override
  String get serverTycoonCoolerActiveArrayName =>
      'Réseau de dissipateurs actifs 4U';

  @override
  String get serverTycoonCoolerRearDoorName =>
      'Échangeur thermique de porte arrière';

  @override
  String get serverTycoonCoolerImmersionName =>
      'Cuve de refroidissement par immersion biphasée';

  @override
  String get serverTycoonCoolerChillerName =>
      'Groupe refroidisseur industriel pour datacenter';

  @override
  String get serverTycoonCoolerNoNameHeatsinkName =>
      'Dissipateur en aluminium sans marque';

  @override
  String get serverTycoonCoolerPassive1UName =>
      'Dissipateur passif 1U avec flux d\'air du châssis';

  @override
  String get serverTycoonCoolingTypeAir => 'Air';

  @override
  String get serverTycoonCoolingTypeCustomLoop => 'Circuit personnalisé';

  @override
  String get serverTycoonCoolingTypeIndustrial => 'Industriel';

  @override
  String get serverTycoonIncidentDdosName => 'Attaque DDoS';

  @override
  String get serverTycoonIncidentDdosDescription =>
      'Un déluge de trafic parasite étouffe la bande passante de ce routeur.';

  @override
  String get serverTycoonIncidentDdosAction => 'Atténuer';

  @override
  String get serverTycoonIncidentOverheatName => 'Pic de surchauffe';

  @override
  String get serverTycoonIncidentOverheatDescription =>
      'Un pic thermique soudain bride ce serveur.';

  @override
  String get serverTycoonIncidentOverheatAction => 'Refroidissement d\'urgence';

  @override
  String get serverTycoonIncidentDriveName => 'Panne de disque';

  @override
  String get serverTycoonIncidentDriveDescription =>
      'Un disque de ce serveur vient de tomber en panne. Remplacez-le pour rétablir le service complet.';

  @override
  String get serverTycoonIncidentDriveAction => 'Remplacer le disque';

  @override
  String get serverTycoonIncidentLeakName => 'Fuite de refroidissement';

  @override
  String get serverTycoonIncidentLeakDescription =>
      'La boucle de refroidissement à eau de ce serveur fuit, ce qui réduit sa capacité de refroidissement.';

  @override
  String get serverTycoonIncidentLeakAction => 'Réparer';

  @override
  String get serverTycoonIncidentViralName => 'Pic de demande viral';

  @override
  String get serverTycoonIncidentViralDescription =>
      'Un de vos services vient de devenir viral ! Revenus supplémentaires pour le reste de la journée.';

  @override
  String get serverTycoonIncidentViralAction => 'Super !';

  @override
  String serverTycoonPlanHome(String speed) {
    return 'Internet domestique - $speed';
  }

  @override
  String serverTycoonPlanBusiness(String speed) {
    return 'Fibre professionnelle - $speed';
  }

  @override
  String serverTycoonPlanDedicated(String speed) {
    return 'Fibre dédiée - $speed';
  }

  @override
  String serverTycoonPlanColocation(String speed) {
    return 'Liaison montante en colocation - $speed';
  }

  @override
  String get serverTycoonLicenseGameHosting => 'Licence d\'hébergement de jeux';

  @override
  String get serverTycoonLicenseGameHostingDesc =>
      'Héberger légalement Minecraft et d\'autres serveurs de jeux pour des clients payants.';

  @override
  String get serverTycoonLicenseCloudStorage => 'Licence de stockage cloud';

  @override
  String get serverTycoonLicenseCloudStorageDesc =>
      'Proposez un stockage cloud personnel et un hébergement de fichiers payants.';

  @override
  String get serverTycoonLicenseVpnHosting => 'Licence d\'hébergement VPN';

  @override
  String get serverTycoonLicenseVpnHostingDesc =>
      'Exploitez un service de point d\'accès VPN pour les clients.';

  @override
  String get serverTycoonLicenseCdnHosting => 'Licence d\'hébergement CDN';

  @override
  String get serverTycoonLicenseCdnHostingDesc =>
      'Exploitez un nœud de cache de périphérie CDN pour le trafic web.';

  @override
  String get serverTycoonLicenseEmailHosting => 'Licence d\'hébergement e-mail';

  @override
  String get serverTycoonLicenseEmailHostingDesc =>
      'Hébergez des domaines e-mail et des boîtes aux lettres professionnels.';

  @override
  String get serverTycoonLicenseDatabaseHosting =>
      'Licence d\'hébergement de bases de données';

  @override
  String get serverTycoonLicenseDatabaseHostingDesc =>
      'Proposez des instances de base de données gérées aux clients.';

  @override
  String get serverTycoonLicenseAiHosting => 'Licence d\'hébergement IA';

  @override
  String get serverTycoonLicenseAiHostingDesc =>
      'Exécutez des charges d\'inférence IA comme service payant.';

  @override
  String get serverTycoonLicenseEnterpriseHosting =>
      'Licence d\'hébergement entreprise';

  @override
  String get serverTycoonLicenseEnterpriseHostingDesc =>
      'Accédez aux contrats avec les entreprises et les administrations.';

  @override
  String get serverTycoonLicenseContainerHosting =>
      'Licence d\'hébergement de conteneurs';

  @override
  String get serverTycoonLicenseContainerHostingDesc =>
      'Exploitez légalement des plateformes d\'orchestration de conteneurs Docker/Kubernetes pour des clients.';

  @override
  String get serverTycoonLicenseStreamingHosting =>
      'Licence d\'hébergement de streaming';

  @override
  String get serverTycoonLicenseStreamingHostingDesc =>
      'Exploitez une infrastructure de relais et de transcodage vidéo pour les créateurs de contenu.';

  @override
  String get serverTycoonMissionProfitableDay => 'Dans le vert';

  @override
  String get serverTycoonMissionProfitableDayDesc =>
      'Dégagez un bénéfice net aujourd\'hui.';

  @override
  String get serverTycoonMissionBigDay => 'Jour de paie';

  @override
  String get serverTycoonMissionBigDayDesc =>
      'Dégagez un bénéfice net important en une seule journée.';

  @override
  String get serverTycoonMissionExpandServices => 'Mettez-le en route';

  @override
  String get serverTycoonMissionExpandServicesDesc =>
      'Installez 2 nouveaux services aujourd\'hui.';

  @override
  String get serverTycoonMissionGoShopping => 'Course aux pièces';

  @override
  String get serverTycoonMissionGoShoppingDesc =>
      'Achetez 3 composants aujourd\'hui.';

  @override
  String get serverTycoonMissionCloseAContract => 'Livré';

  @override
  String get serverTycoonMissionCloseAContractDesc =>
      'Terminez un contrat d\'entreprise aujourd\'hui.';

  @override
  String get serverTycoonMissionFirefighter => 'Pompier';

  @override
  String get serverTycoonMissionFirefighterDesc =>
      'Résolvez 2 incidents aujourd\'hui.';

  @override
  String get serverTycoonMissionLabWork => 'Travail de labo';

  @override
  String get serverTycoonMissionLabWorkDesc =>
      'Terminez un projet de recherche aujourd\'hui.';

  @override
  String get serverTycoonMissionPushTraffic => 'Pic de trafic';

  @override
  String get serverTycoonMissionPushTrafficDesc =>
      'Assurez un trafic soutenu aujourd\'hui.';

  @override
  String get serverTycoonMissionCleanRun => 'Journée sans accroc';

  @override
  String get serverTycoonMissionCleanRunDesc =>
      'Traversez la journée sans aucune surcharge.';

  @override
  String get serverTycoonNicRealtekOnboard =>
      'Ethernet gigabit Realtek (intégré)';

  @override
  String get serverTycoonNicGenericOnboard =>
      'Fast Ethernet générique (intégré)';

  @override
  String get serverTycoonPsuRedundant2000 =>
      'Alimentation serveur redondante 2000 W (double)';

  @override
  String get serverTycoonPsuRedundant3000Titanium =>
      'Alimentation serveur redondante 3000 W Titanium (double)';

  @override
  String get serverTycoonPsuHyperscale5000 =>
      'Alimentation de rack hyperscale 5000 W (N+1)';

  @override
  String get serverTycoonPsuGeneric300 => 'OEM générique 300 W';

  @override
  String get serverTycoonPsuRedundant1200 =>
      'Alimentation serveur redondante 1200 W (double)';

  @override
  String get serverTycoonRamGenericDdr3Gb8 => 'DDR3 générique 8 Go 1600 MHz';

  @override
  String get serverTycoonRamGenericDdr3Gb4 => 'DDR3 générique 4 Go 1333 MHz';

  @override
  String get serverTycoonResearchBranchLab => 'Labo R&D';

  @override
  String get serverTycoonResearchBranchCompute => 'Calcul';

  @override
  String get serverTycoonResearchBranchStorage => 'Stockage et données';

  @override
  String get serverTycoonResearchBranchNetworking => 'Réseau';

  @override
  String get serverTycoonResearchBranchPower => 'Énergie et refroidissement';

  @override
  String get serverTycoonResearchBranchBusiness => 'Affaires';

  @override
  String get serverTycoonResearchHomeLab => 'Labo maison';

  @override
  String get serverTycoonResearchHomeLabDesc =>
      'Un coin du bureau réservé aux tests. Ajoute 1,0 point de recherche par jour.';

  @override
  String get serverTycoonResearchResearchWing => 'Aile de recherche';

  @override
  String get serverTycoonResearchResearchWingDesc =>
      'Un vrai espace de laboratoire équipé de postes de travail. Ajoute 2,5 points de recherche par jour et un deuxième emplacement de file d\'attente.';

  @override
  String get serverTycoonResearchRndDivision => 'Division R&D';

  @override
  String get serverTycoonResearchRndDivisionDesc =>
      'Une division de recherche dotée de personnel. Ajoute 6,0 points de recherche par jour et un troisième emplacement de file d\'attente.';

  @override
  String get serverTycoonResearchAutomatedTelemetry => 'Télémétrie automatisée';

  @override
  String get serverTycoonResearchAutomatedTelemetryDesc =>
      'Les machines transmettent leurs propres données de performance : votre parc continue de rapporter même lorsque l\'application est fermée. Les gains hors ligne sont majorés de 15 %.';

  @override
  String get serverTycoonResearchLightsOutOperations =>
      'Exploitation sans personnel';

  @override
  String get serverTycoonResearchLightsOutOperationsDesc =>
      'La salle fonctionne sans surveillance pendant la nuit. Les gains hors ligne sont majorés de 20 % supplémentaires.';

  @override
  String get serverTycoonResearchContinuousOptimization =>
      'Optimisation continue';

  @override
  String get serverTycoonResearchContinuousOptimizationDesc =>
      'Un programme permanent d\'ajustements progressifs. Chaque niveau ajoute 2 % à tous les revenus de service, et il n\'y a jamais de niveau final.';

  @override
  String get serverTycoonResearchKernelTuning => 'Réglage du noyau';

  @override
  String get serverTycoonResearchKernelTuningDesc =>
      'Le réglage de l\'ordonnanceur et des IRQ tire 8 % de travail utile en plus de chaque processeur.';

  @override
  String get serverTycoonResearchHypervisorOptimization =>
      'Optimisation de l\'hyperviseur';

  @override
  String get serverTycoonResearchHypervisorOptimizationDesc =>
      'Les pilotes paravirtualisés et l\'épinglage CPU réduisent la surcharge de virtualisation, libérant 12 % de capacité CPU supplémentaire.';

  @override
  String get serverTycoonResearchOverclockProfiles => 'Profils d\'overclocking';

  @override
  String get serverTycoonResearchOverclockProfilesDesc =>
      'Des fréquences réglées pour chaque puce ajoutent 15 % de capacité CPU, au prix de 10 % de marge de refroidissement en moins.';

  @override
  String get serverTycoonResearchSiliconBinning => 'Tri des puces';

  @override
  String get serverTycoonResearchSiliconBinningDesc =>
      'Des puces sélectionnées à la main tournent plus frais et plus vite : 18 % de capacité CPU en plus et 10 % de marge de refroidissement en plus.';

  @override
  String get serverTycoonResearchBlockDedup => 'Déduplication par blocs';

  @override
  String get serverTycoonResearchBlockDedupDesc =>
      'Les blocs identiques ne sont stockés qu\'une fois, réduisant de 10 % l\'espace de stockage requis par chaque service.';

  @override
  String get serverTycoonResearchCompressionI => 'Compression en ligne';

  @override
  String get serverTycoonResearchCompressionIDesc =>
      'Compresse les données à l\'écriture sur le disque, pour 12 % de besoins de stockage en moins.';

  @override
  String get serverTycoonResearchCompressionIi => 'Compression adaptative';

  @override
  String get serverTycoonResearchCompressionIiDesc =>
      'Des algorithmes de compression adaptés à chaque charge réduisent encore de 15 % les besoins de stockage.';

  @override
  String get serverTycoonResearchTieredCaching => 'Cache à plusieurs niveaux';

  @override
  String get serverTycoonResearchTieredCachingDesc =>
      'Les données sollicitées sont servies depuis la RAM et le NVMe, ce qui augmente la satisfaction client de 5 %.';

  @override
  String get serverTycoonResearchMeshNetworking => 'Réseau maillé';

  @override
  String get serverTycoonResearchMeshNetworkingDesc =>
      'Apprenez à exploiter un second routeur pour répartir les machines sur des connexions FAI distinctes.';

  @override
  String get serverTycoonResearchPacketShaping => 'Mise en forme des paquets';

  @override
  String get serverTycoonResearchPacketShapingDesc =>
      'Une file d\'attente plus intelligente réduit de 10 % la bande passante consommée par chaque service.';

  @override
  String get serverTycoonResearchBackboneRouting => 'Routage dorsal';

  @override
  String get serverTycoonResearchBackboneRoutingDesc =>
      'Des tables de routage avancées permettent un troisième routeur sur le réseau.';

  @override
  String get serverTycoonResearchQosPrioritization => 'Priorisation QoS';

  @override
  String get serverTycoonResearchQosPrioritizationDesc =>
      'Le trafic sensible à la latence passe en premier, ce qui augmente la satisfaction client de 4 %.';

  @override
  String get serverTycoonResearchFiberBackhaul => 'Backhaul fibre';

  @override
  String get serverTycoonResearchFiberBackhaulDesc =>
      'Une liaison dorsale dédiée vous permet d\'exploiter jusqu\'à cinq routeurs au total.';

  @override
  String get serverTycoonResearchAnycastEdge => 'Edge Anycast';

  @override
  String get serverTycoonResearchAnycastEdgeDesc =>
      'Le trafic atterrit sur le nœud périphérique le plus proche, réduisant encore de 15 % les besoins en bande passante.';

  @override
  String get serverTycoonResearchHyperscaleNetworking => 'Réseau hyperscale';

  @override
  String get serverTycoonResearchHyperscaleNetworkingDesc =>
      'Le réseau défini par logiciel vous permet d\'exploiter jusqu\'à huit routeurs au total.';

  @override
  String get serverTycoonResearchPowerTuning => 'Réglage de l\'alimentation';

  @override
  String get serverTycoonResearchPowerTuningDesc =>
      'La sous-tension et des courbes de ventilateur plus intelligentes réduisent votre facture d\'électricité de 10 %.';

  @override
  String get serverTycoonResearchLiquidCoolingI =>
      'Recherche sur le refroidissement liquide';

  @override
  String get serverTycoonResearchLiquidCoolingIDesc =>
      'Des circuits conçus en interne offrent à chaque machine 12 % de marge de refroidissement en plus.';

  @override
  String get serverTycoonResearchSmartPdu =>
      'Distribution électrique intelligente';

  @override
  String get serverTycoonResearchSmartPduDesc =>
      'Des PDU de qualité rack réduisent encore de 15 % la facture d\'énergie.';

  @override
  String get serverTycoonResearchLiquidCoolingIi =>
      'Refroidissement direct sur puce';

  @override
  String get serverTycoonResearchLiquidCoolingIiDesc =>
      'Des plaques froides posées directement sur la puce ajoutent 15 % de marge de refroidissement.';

  @override
  String get serverTycoonResearchRenewableEnergy =>
      'Contrats d\'énergie renouvelable';

  @override
  String get serverTycoonResearchRenewableEnergyDesc =>
      'Des contrats d\'achat d\'énergie solaire et éolienne réduisent encore de 15 % votre facture d\'électricité.';

  @override
  String get serverTycoonResearchImmersionCooling =>
      'Refroidissement par immersion';

  @override
  String get serverTycoonResearchImmersionCoolingDesc =>
      'Des machines entières immergées dans un fluide diélectrique : 25 % de marge de refroidissement en plus et des températures bien plus stables.';

  @override
  String get serverTycoonResearchWasteHeatRecovery =>
      'Récupération de chaleur fatale';

  @override
  String get serverTycoonResearchWasteHeatRecoveryDesc =>
      'Vendez votre chaleur rejetée au réseau de chauffage urbain pour 12 % de facture d\'énergie en moins.';

  @override
  String get serverTycoonResearchBulkPurchasing => 'Achats en gros';

  @override
  String get serverTycoonResearchBulkPurchasingDesc =>
      'Les accords fournisseurs réduisent de 20 % le prix de chaque nouvelle machine.';

  @override
  String get serverTycoonResearchSalesTeam => 'Équipe commerciale';

  @override
  String get serverTycoonResearchSalesTeamDesc =>
      'Un commercial à temps partiel vous permet de gérer un contrat d\'entreprise de plus à la fois.';

  @override
  String get serverTycoonResearchRunbookAutomation =>
      'Automatisation des runbooks';

  @override
  String get serverTycoonResearchRunbookAutomationDesc =>
      'Des réponses documentées et automatisées font que 20 % d\'incidents en moins vous parviennent.';

  @override
  String get serverTycoonResearchSupplyChainOptimization =>
      'Optimisation de la chaîne d\'approvisionnement';

  @override
  String get serverTycoonResearchSupplyChainOptimizationDesc =>
      'Des achats rationalisés réduisent encore de 15 % le prix de chaque nouvelle machine.';

  @override
  String get serverTycoonResearchAccountManagers => 'Gestionnaires de comptes';

  @override
  String get serverTycoonResearchAccountManagersDesc =>
      'Des gestionnaires de comptes dédiés gèrent deux contrats supplémentaires simultanément.';

  @override
  String get serverTycoonResearchReputationManagement =>
      'Gestion de la réputation';

  @override
  String get serverTycoonResearchReputationManagementDesc =>
      'Des pages d\'état publiques et une communication proactive augmentent la satisfaction client de 4 %.';

  @override
  String get serverTycoonResearchPremiumSlas => 'SLA premium';

  @override
  String get serverTycoonResearchPremiumSlasDesc =>
      'Des niveaux de disponibilité garantis que les clients paieront : 8 % de revenus en plus pour chaque service.';

  @override
  String get serverTycoonResearchEnterpriseSales =>
      'Division ventes grands comptes';

  @override
  String get serverTycoonResearchEnterpriseSalesDesc =>
      'Une équipe commerciale dédiée aux grands comptes vous permet de gérer un contrat de plus simultanément.';

  @override
  String get serverTycoonResearchAutoRenewal =>
      'Contrats à renouvellement automatique';

  @override
  String get serverTycoonResearchAutoRenewalDesc =>
      'Les clients sont renouvelés par défaut, ce qui ajoute 12 % à tous les revenus de service.';

  @override
  String get serverTycoonServiceDiscordBotName => 'Bot Discord';

  @override
  String get serverTycoonServiceDiscordBotDesc =>
      'Des bots légers pour les communautés Discord. Ils consomment à peine le CPU ou la bande passante.';

  @override
  String get serverTycoonServiceDiscordBotCapacity => 'instance de bot';

  @override
  String get serverTycoonServiceStaticWebsiteName => 'Site web statique';

  @override
  String get serverTycoonServiceStaticWebsiteDesc =>
      'Sites HTML/CSS sans backend. Peu coûteux à faire tourner à toute échelle.';

  @override
  String get serverTycoonServiceStaticWebsiteCapacity =>
      '1 000 visiteurs par mois';

  @override
  String get serverTycoonServiceDynamicWebsiteApiName =>
      'Site web dynamique / API';

  @override
  String get serverTycoonServiceDynamicWebsiteApiDesc =>
      'Sites rendus côté serveur et points de terminaison d\'API. Nécessitent un vrai CPU et de la RAM.';

  @override
  String get serverTycoonServiceDynamicWebsiteApiCapacity =>
      'niveau de requêtes';

  @override
  String get serverTycoonServiceMonitoringServerName =>
      'Serveur de supervision';

  @override
  String get serverTycoonServiceMonitoringServerDesc =>
      'Supervision de disponibilité et de métriques pour l\'infrastructure d\'autrui.';

  @override
  String get serverTycoonServiceMonitoringServerCapacity => 'hôte supervisé';

  @override
  String get serverTycoonServiceVoiceServerName => 'Serveur vocal';

  @override
  String get serverTycoonServiceVoiceServerDesc =>
      'Hébergement de chat vocal à faible latence (type TeamSpeak/Mumble).';

  @override
  String get serverTycoonServiceVoiceServerCapacity =>
      'utilisateur vocal simultané';

  @override
  String get serverTycoonServiceMinecraftServerName => 'Serveur Minecraft';

  @override
  String get serverTycoonServiceMinecraftServerDesc =>
      'CPU très sollicité, RAM/stockage/réseau modérés. Sensible à la latence.';

  @override
  String get serverTycoonServiceMinecraftServerCapacity => 'emplacement joueur';

  @override
  String get serverTycoonServiceGenericGameServerName =>
      'Serveur de jeu (survie/bac à sable)';

  @override
  String get serverTycoonServiceGenericGameServerDesc =>
      'Serveurs dédiés façon Rust/Valheim. Plus lourds que Minecraft par emplacement.';

  @override
  String get serverTycoonServiceGenericGameServerCapacity =>
      'emplacement joueur';

  @override
  String get serverTycoonServiceCloudStorageName => 'Stockage cloud';

  @override
  String get serverTycoonServiceCloudStorageDesc =>
      'Stockage cloud personnel et hébergement de fichiers. Gourmand en stockage, pas en CPU.';

  @override
  String get serverTycoonServiceCloudStorageCapacity =>
      'client de stockage (~50 Go)';

  @override
  String get serverTycoonServiceVpnProviderName => 'Fournisseur VPN';

  @override
  String get serverTycoonServiceVpnProviderDesc =>
      'Points de terminaison de tunnels chiffrés pour les clients soucieux de leur vie privée.';

  @override
  String get serverTycoonServiceVpnProviderCapacity =>
      'utilisateur VPN simultané';

  @override
  String get serverTycoonServiceCdnEdgeName => 'Nœud périphérique CDN';

  @override
  String get serverTycoonServiceCdnEdgeDesc =>
      'Met en cache et sert les ressources statiques d\'autres sites au plus près de leurs utilisateurs.';

  @override
  String get serverTycoonServiceCdnEdgeCapacity =>
      'niveau de cache (~100 Go/jour)';

  @override
  String get serverTycoonServiceEmailHostingName => 'Hébergement e-mail';

  @override
  String get serverTycoonServiceEmailHostingDesc =>
      'Domaines e-mail professionnels et boîtes aux lettres. Charge légère, revenus réguliers.';

  @override
  String get serverTycoonServiceEmailHostingCapacity => 'boîte aux lettres';

  @override
  String get serverTycoonServiceDatabaseHostingName =>
      'Hébergement de bases de données';

  @override
  String get serverTycoonServiceDatabaseHostingDesc =>
      'Instances de bases de données gérées pour d\'autres entreprises.';

  @override
  String get serverTycoonServiceDatabaseHostingCapacity =>
      'instance de base de données';

  @override
  String get serverTycoonServiceAiInferenceName =>
      'Hébergement d\'inférence IA';

  @override
  String get serverTycoonServiceAiInferenceDesc =>
      'Charges d\'inférence sur CPU. Extrêmement gourmandes en CPU et en RAM.';

  @override
  String get serverTycoonServiceAiInferenceCapacity =>
      'niveau de requêtes d\'inférence';

  @override
  String get serverTycoonServiceContainerHostingName =>
      'Hébergement de conteneurs';

  @override
  String get serverTycoonServiceContainerHostingDesc =>
      'Orchestration de conteneurs Docker/Kubernetes. Charge équilibrée entre CPU, RAM et stockage.';

  @override
  String get serverTycoonServiceContainerHostingCapacity => 'pod de conteneur';

  @override
  String get serverTycoonServiceStreamingRelayName => 'Relais de streaming';

  @override
  String get serverTycoonServiceStreamingRelayDesc =>
      'Nœuds de relais et de transcodage de flux vidéo. Extrêmement gourmands en bande passante.';

  @override
  String get serverTycoonServiceStreamingRelayCapacity =>
      'relais de flux (~500 spectateurs)';

  @override
  String get serverTycoonServiceCiCdRunnerName => 'Exécuteur de pipeline CI/CD';

  @override
  String get serverTycoonServiceCiCdRunnerDesc =>
      'Exécuteurs de build et de déploiement hébergés. CPU à pics de charge avec forte activité d\'E/S sur le stockage.';

  @override
  String get serverTycoonServiceCiCdRunnerCapacity =>
      'pipeline de build simultané';

  @override
  String get serverTycoonServiceCategoryAutomation => 'Automatisation';

  @override
  String get serverTycoonServiceCategoryWeb => 'Web';

  @override
  String get serverTycoonServiceCategoryOps => 'Exploitation';

  @override
  String get serverTycoonServiceCategoryCommunication => 'Communication';

  @override
  String get serverTycoonServiceCategoryGameHosting => 'Hébergement de jeux';

  @override
  String get serverTycoonServiceCategoryStorage => 'Stockage';

  @override
  String get serverTycoonServiceCategoryNetwork => 'Réseau';

  @override
  String get serverTycoonServiceCategoryData => 'Données';

  @override
  String get serverTycoonServiceCategoryAi => 'IA';

  @override
  String get serverTycoonServiceCategoryCloud => 'Cloud';

  @override
  String get serverTycoonServiceCategoryMedia => 'Médias';

  @override
  String get serverTycoonServiceCategoryDevops => 'DevOps';

  @override
  String get serverTycoonStaffSysadminName =>
      'Jordan, l\'administrateur système';

  @override
  String get serverTycoonStaffSysadminDesc =>
      'Règle discrètement les incidents mineurs (surchauffe, fuites de refroidissement, DDoS) avant qu\'ils ne vous coûtent quoi que ce soit.';

  @override
  String get serverTycoonStaffElectricianName => 'Sam, l\'électricien';

  @override
  String get serverTycoonStaffElectricianDesc =>
      'Garde votre câblage et vos PDU efficaces, et réduit encore de 8 % votre facture d\'électricité.';

  @override
  String get serverTycoonStaffSalesRepName => 'Casey, le commercial';

  @override
  String get serverTycoonStaffSalesRepDesc =>
      'Décroche chaque jour une offre de contrat supplémentaire et négocie de meilleurs versements.';

  @override
  String get serverTycoonStaffSysadminSeniorName =>
      'Riley, administrateur système senior';

  @override
  String get serverTycoonStaffSysadminSeniorDesc =>
      'Un vétéran des opérations expérimenté qui résout les incidents à coup sûr. Se cumule avec Jordan.';

  @override
  String get serverTycoonStaffElectricianMasterName =>
      'Drew, maître électricien';

  @override
  String get serverTycoonStaffElectricianMasterDesc =>
      'Un électricien industriel agréé qui réduit encore de 12 % votre facture d\'électricité. Se cumule avec Sam.';

  @override
  String get serverTycoonStaffSalesDirectorName =>
      'Morgan, directeur commercial';

  @override
  String get serverTycoonStaffSalesDirectorDesc =>
      'Un directeur bien introduit qui apporte une offre quotidienne supplémentaire et négocie encore plus dur. Se cumule avec Casey.';

  @override
  String get serverTycoonDriveGeneric500gbHdd => 'HDD générique 500 Go';

  @override
  String get serverTycoonDriveWdRed4tbNasHdd => 'HDD NAS WD Red 4 To';

  @override
  String get serverTycoonDriveEnterpriseSsd8tb => 'NVMe U.2 entreprise 8 To';

  @override
  String get serverTycoonDriveToshibaMg10Hdd =>
      'HDD entreprise Toshiba MG10 20 To';

  @override
  String get serverTycoonDriveWdGold24tbHdd => 'HDD entreprise WD Gold 24 To';

  @override
  String get serverTycoonDriveKioxiaCm7Nvme =>
      'NVMe entreprise Kioxia CM7-R 15,36 To';

  @override
  String get serverTycoonDriveMicron9400Nvme =>
      'NVMe entreprise Micron 9400 Pro 30,72 To';

  @override
  String get serverTycoonDriveSolidigmD5Nvme =>
      'NVMe entreprise Solidigm D5-P5336 61,44 To';

  @override
  String get serverTycoonDriveGeneric128gbSsd => 'SSD SATA générique 128 Go';

  @override
  String get serverTycoonGradeServer => 'serveur';

  @override
  String get serverTycoonGradePc => 'PC';

  @override
  String serverTycoonBuildPartGradeMismatch(
    String part,
    String grade,
    String rig,
  ) {
    return '$part est du matériel $grade et ne convient pas à un rig $rig';
  }

  @override
  String serverTycoonBuildUnknownCpu(String id) {
    return 'CPU inconnu : $id';
  }

  @override
  String serverTycoonBuildUnknownMotherboard(String id) {
    return 'Carte mère inconnue : $id';
  }

  @override
  String serverTycoonBuildSocketMismatch(
    String cpu,
    String cpuSocket,
    String board,
    String boardSocket,
  ) {
    return '$cpu utilise le socket $cpuSocket, $board nécessite $boardSocket';
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
      other: '$slots emplacements RAM',
      one: '1 emplacement RAM',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sticks,
      locale: localeName,
      other: '$sticks barrettes sont installées',
      one: '1 barrette est installée',
    );
    return '$board ne possède que $_temp0, et $_temp1';
  }

  @override
  String serverTycoonBuildRamTypeMismatch(
    String stick,
    String stickType,
    String board,
    String boardType,
  ) {
    return '$stick est en $stickType, $board nécessite $boardType';
  }

  @override
  String serverTycoonBuildEccUnsupported(String board, String stick) {
    return '$board ne prend pas en charge la mémoire enregistrée/ECC ($stick)';
  }

  @override
  String serverTycoonBuildRamCapExceeded(
    String board,
    int maxGb,
    int installedGb,
  ) {
    return '$board prend en charge jusqu\'à $maxGb Go de RAM, $installedGb Go installés';
  }

  @override
  String serverTycoonBuildUnknownRam(String id) {
    return 'Barrette RAM inconnue : $id';
  }

  @override
  String serverTycoonBuildUnknownDrive(String id) {
    return 'Disque inconnu : $id';
  }

  @override
  String serverTycoonBuildSataExceeded(String board, int ports, int drives) {
    String _temp0 = intl.Intl.pluralLogic(
      ports,
      locale: localeName,
      other: '$ports ports SATA',
      one: '1 port SATA',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drives,
      locale: localeName,
      other: '$drives disques en nécessitent',
      one: '1 disque en nécessite',
    );
    return '$board ne possède que $_temp0, alors que $_temp1 un';
  }

  @override
  String serverTycoonBuildM2Exceeded(String board, int slots, int drives) {
    String _temp0 = intl.Intl.pluralLogic(
      slots,
      locale: localeName,
      other: '$slots emplacements M.2',
      one: '1 emplacement M.2',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drives,
      locale: localeName,
      other: '$drives disques NVMe sont installés',
      one: '1 disque NVMe est installé',
    );
    return '$board ne possède que $_temp0, et $_temp1';
  }

  @override
  String serverTycoonBuildPowerExceeded(
    int watts,
    String psu,
    int ratingWatts,
  ) {
    return 'La consommation maximale estimée de $watts W dépasse la puissance de $psu ($ratingWatts W)';
  }

  @override
  String serverTycoonDay(int day) {
    return 'Jour $day';
  }

  @override
  String get serverTycoonNextDay => 'Jour suivant';

  @override
  String serverTycoonNextDayIn(int seconds) {
    return 'Jour suivant dans $seconds s';
  }

  @override
  String get serverTycoonResume => 'Reprendre';

  @override
  String get serverTycoonPause => 'Pause';

  @override
  String get serverTycoonBuild => 'Construire';

  @override
  String get serverTycoonShop => 'Boutique';

  @override
  String get serverTycoonContracts => 'Contrats';

  @override
  String get serverTycoonResearch => 'Recherche';

  @override
  String get serverTycoonMore => 'Plus';

  @override
  String get serverTycoonFitToView => 'Ajuster à la vue';

  @override
  String get serverTycoonAutoArrange => 'Disposition auto';

  @override
  String get serverTycoonPhoneHint =>
      'Touchez pour inspecter · maintenez pour déplacer';

  @override
  String get serverTycoonServerRig => 'Rig serveur';

  @override
  String get serverTycoonPcRig => 'Rig PC';

  @override
  String get serverTycoonIncompatibleHardware =>
      'MATÉRIEL INCOMPATIBLE -- GAIN \$0/JOUR';

  @override
  String serverTycoonDiskSpeed(String speed) {
    return 'Vitesse du disque ($speed Mo/s)';
  }

  @override
  String serverTycoonThermalThrottling(String percent) {
    return 'BRIDAGE THERMIQUE : $percent % de capacité';
  }

  @override
  String get serverTycoonStorage => 'Stockage';

  @override
  String get serverTycoonHardware => 'Matériel';

  @override
  String get serverTycoonMotherboard => 'Carte mère';

  @override
  String get serverTycoonCooling => 'Refroidissement';

  @override
  String serverTycoonStorageGb(String gb) {
    return 'Stockage ($gb Go)';
  }

  @override
  String get serverTycoonAdd => '+ Ajouter';

  @override
  String get serverTycoonServices => 'Services';

  @override
  String get serverTycoonNothingPluggedIn =>
      'Rien de branché — faites glisser un nœud de service sur ce rig.';

  @override
  String get serverTycoonInstallService => 'Installer un service';

  @override
  String get serverTycoonNetwork => 'Réseau';

  @override
  String get serverTycoonNotConnected => 'Non connecté';

  @override
  String get serverTycoonNoFixNeeded => 'Aucune correction nécessaire';

  @override
  String serverTycoonFixWith(String name) {
    return 'Corriger : $name';
  }

  @override
  String get serverTycoonClone => 'Cloner';

  @override
  String get serverTycoonService => 'Service';

  @override
  String get serverTycoonServiceNotPluggedIn =>
      'Non branché — faites glisser le port de ce nœud sur un rig.';

  @override
  String serverTycoonRunningOn(String name) {
    return 'Fonctionne sur $name';
  }

  @override
  String get serverTycoonCapacity => 'Capacité';

  @override
  String serverTycoonMoneyPerDay(String amount) {
    return '$amount/jour';
  }

  @override
  String get serverTycoonIncome => 'Revenus';

  @override
  String get serverTycoonSatisfaction => 'Satisfaction';

  @override
  String get serverTycoonBottleneck => 'Goulot d\'étranglement';

  @override
  String get serverTycoonUnplug => 'Débrancher';

  @override
  String get serverTycoonDeleteService => 'Supprimer le service';

  @override
  String get serverTycoonRouter => 'Routeur';

  @override
  String get serverTycoonUpgradeToNextPlan => 'Passer au forfait supérieur';

  @override
  String get serverTycoonInternetPlan => 'Forfait internet';

  @override
  String serverTycoonLatencyMs(String ms) {
    return 'Latence : $ms ms';
  }

  @override
  String serverTycoonMonthlyPrice(String price) {
    return 'Mensuel : $price';
  }

  @override
  String get serverTycoonUpgradePlan => 'Changer de forfait';

  @override
  String get serverTycoonSelect => 'Choisir';

  @override
  String get serverTycoonConnectedRigs => 'Rigs connectés';

  @override
  String get serverTycoonPcRigTool => 'Rig PC';

  @override
  String get serverTycoonServerTool => 'Serveur';

  @override
  String get serverTycoonServiceTool => 'Service';

  @override
  String get serverTycoonResearchTool => 'Recherche';

  @override
  String get serverTycoonContractsTool => 'Contrats';

  @override
  String get serverTycoonGoals => 'Objectifs';

  @override
  String get serverTycoonBoosts => 'Bonus';

  @override
  String get serverTycoonLicenses => 'Licences';

  @override
  String get serverTycoonAchievements => 'Succès';

  @override
  String get serverTycoonStaff => 'Personnel';

  @override
  String get serverTycoonStats => 'Statistiques';

  @override
  String get serverTycoonAutoAdvanceDays => 'Passer automatiquement les jours';

  @override
  String get serverTycoonScaleUp => 'Monter en puissance';

  @override
  String get serverTycoonReset => 'Réinitialiser';

  @override
  String get serverTycoonChange => 'Changer';

  @override
  String serverTycoonSatisfactionPercent(String percent) {
    return '$percent % sat.';
  }

  @override
  String serverTycoonBottleneckValue(String value) {
    return 'Goulot : $value';
  }

  @override
  String get serverTycoonSet => 'Définir';

  @override
  String get serverTycoonResetGameTitle => 'Réinitialiser la partie ?';

  @override
  String get serverTycoonResetGameBody =>
      'Toute progression sera perdue. Cette action est irréversible.';

  @override
  String serverTycoonScaleUpTitle(String tier) {
    return 'Monter en puissance vers $tier ?';
  }

  @override
  String serverTycoonScaleUpBody(String multiplier) {
    return 'Vous conservez : le niveau de prestige, le multiplicateur de revenus à vie (désormais ${multiplier}x), les succès et votre historique de gains.\n\nVous perdez : tous les rigs, routeurs, personnel, recherches, licences, contrats en cours, inventaire, liquidités, réputation et nombre de jours -- vous repartez du jour 0 avec 250 \$.';
  }

  @override
  String serverTycoonAddSlot(String slot) {
    return 'Ajouter $slot';
  }

  @override
  String serverTycoonSwapSlot(String slot) {
    return 'Remplacer $slot';
  }

  @override
  String serverTycoonInInventory(int count) {
    return 'En stock x$count';
  }

  @override
  String get serverTycoonConsumerHardware => 'Matériel grand public';

  @override
  String get serverTycoonServerHardware => 'Matériel serveur';

  @override
  String get serverTycoonInstall => 'Installer';

  @override
  String get serverTycoonBuy => 'Acheter';

  @override
  String get serverTycoonSwap => 'Remplacer';

  @override
  String serverTycoonBuildPcRigSub(String price) {
    return '$price • une machine bon marché pour débuter';
  }

  @override
  String serverTycoonBuildServerRigSub(String price) {
    return '$price • accepte les pièces de qualité serveur';
  }

  @override
  String serverTycoonBuildRouterSub(String price, String used, String max) {
    return '$price • $used/$max utilisés';
  }

  @override
  String get serverTycoonBuildServiceSub =>
      'Place un nœud de service sur la zone pour le connecter';

  @override
  String get serverTycoonAutoArrangeSub =>
      'Dispose tout le graphe : routeurs, rigs, puis leurs services';

  @override
  String get serverTycoonAutoAdvanceSub =>
      'Passer directement au jour suivant sans parcourir le rapport';

  @override
  String get serverTycoonDailyGoals => 'Objectifs du jour';

  @override
  String serverTycoonDailyGoalsSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count encore ouverts aujourd\'hui',
      zero: 'Tout est fait pour aujourd\'hui',
    );
    return '$_temp0';
  }

  @override
  String serverTycoonBoostsSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count en cours',
      zero: 'Aucun en cours',
    );
    return '$_temp0';
  }

  @override
  String get serverTycoonStatsSub =>
      'Historique des revenus et de la puissance';

  @override
  String serverTycoonLicensesHeld(int count) {
    return '$count détenues';
  }

  @override
  String serverTycoonStaffHired(int count) {
    return '$count embauchés';
  }

  @override
  String serverTycoonAchievementsUnlocked(int count) {
    return '$count débloqués';
  }

  @override
  String get serverTycoonScaleUpSub =>
      'Recommencer plus grand avec un multiplicateur de revenus permanent';

  @override
  String get serverTycoonResetGame => 'Réinitialiser la partie';

  @override
  String get serverTycoonResetGameSub => 'Recommencer depuis le jour zéro';

  @override
  String get serverTycoonCatMotherboards => 'Cartes mères';

  @override
  String serverTycoonOwnedCount(int count) {
    return 'Possédé x$count';
  }

  @override
  String get serverTycoonLocked => 'Verrouillé';

  @override
  String get serverTycoonBadgeServer => 'SERVEUR';

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
      other: '$count services · pas de routeur',
      one: '1 service · pas de routeur',
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
  String get serverTycoonNotPluggedIn => 'Non branché';

  @override
  String get serverTycoonNoOffersToday =>
      'Aucune offre aujourd\'hui — développez votre réputation et achetez des licences pour attirer des entreprises.';

  @override
  String get serverTycoonActive => 'En cours';

  @override
  String get serverTycoonTodaysOffers => 'Offres du jour';

  @override
  String get serverTycoonAccept => 'Accepter';

  @override
  String get serverTycoonFull => 'Complet';

  @override
  String get serverTycoonErrorGeneric => 'Erreur';

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
      other: '$days jours',
      one: '1 jour',
    );
    return '$capacity $unit • $_temp0 • $payout + $bonus de prime';
  }

  @override
  String serverTycoonDaysLeft(int count) {
    return '$count j restants';
  }

  @override
  String serverTycoonContractNeeds(
    String capacity,
    String unit,
    String payout,
  ) {
    return 'Requiert $capacity $unit servis • $payout';
  }

  @override
  String serverTycoonResearchIdle(String rate) {
    return 'Rien au labo — gain de $rate RP/jour';
  }

  @override
  String serverTycoonResearchingValue(String name) {
    return 'Recherche en cours : $name';
  }

  @override
  String serverTycoonResearchProgress(
    String accrued,
    String needed,
    String rate,
  ) {
    return '$accrued / $needed RP · $rate/jour';
  }

  @override
  String serverTycoonQueuedCount(int count) {
    return '$count en file';
  }

  @override
  String serverTycoonTier(int tier) {
    return 'Palier $tier';
  }

  @override
  String serverTycoonResearchLevel(int level) {
    return 'Niveau $level — répétable';
  }

  @override
  String get serverTycoonResearched => 'Recherché';

  @override
  String get serverTycoonCancelResearch => 'Annuler (50 % remboursés)';

  @override
  String get serverTycoonRemoveFromQueue => 'Retirer de la file';

  @override
  String serverTycoonResearchCostDays(String cost, String days) {
    return '$cost · ~${days}j';
  }

  @override
  String serverTycoonNeedsResearch(String projects) {
    return 'Nécessite $projects';
  }

  @override
  String serverTycoonNeedsReputation(String reputation) {
    return 'Nécessite $reputation de réputation';
  }

  @override
  String serverTycoonLicenseSubtitle(String description, String reputation) {
    return '$description\nNécessite $reputation de rép.';
  }

  @override
  String get serverTycoonHired => 'EMBAUCHÉ';

  @override
  String serverTycoonSalary(String amount) {
    return 'Salaire : $amount';
  }

  @override
  String get serverTycoonRequirementsNotMet => 'Conditions non remplies';

  @override
  String get serverTycoonFire => 'Licencier';

  @override
  String serverTycoonHire(String amount) {
    return 'Embaucher $amount';
  }

  @override
  String get serverTycoonIncidentMitigate => 'Atténuer';

  @override
  String get serverTycoonIncidentCooldown => 'Refroidir';

  @override
  String get serverTycoonIncidentRepair => 'Réparer';

  @override
  String get serverTycoonIncidentReplaceDrive => 'Remplacer le disque';

  @override
  String get serverTycoonIncidentNice => 'Super !';

  @override
  String get serverTycoonIgnore => 'Ignorer';

  @override
  String get serverTycoonAchievementUnlocked => 'Succès débloqué';

  @override
  String get serverTycoonContractIncome => 'Revenus des contrats';

  @override
  String get serverTycoonElectricity => 'Électricité';

  @override
  String get serverTycoonInternet => 'Internet';

  @override
  String get serverTycoonStaffSalaries => 'Salaires du personnel';

  @override
  String get serverTycoonNetProfit => 'Bénéfice net';

  @override
  String get serverTycoonAvgSatisfaction => 'Satisfaction moyenne';

  @override
  String get serverTycoonReputation => 'Réputation';

  @override
  String get serverTycoonContractEvents => 'Événements de contrat';

  @override
  String get serverTycoonGoalsCompleted => 'Objectifs atteints';

  @override
  String get serverTycoonContinue => 'Continuer';

  @override
  String get serverTycoonDayReportFailedWord => 'ÉCHOUÉ';

  @override
  String get serverTycoonGoalsIntro =>
      'Une nouvelle liste est générée chaque jour. Les récompenses sont versées dès qu\'un objectif est atteint.';

  @override
  String get serverTycoonNoGoalsToday => 'Aucun objectif aujourd\'hui.';

  @override
  String serverTycoonGoalProgressReward(
    String progress,
    String target,
    String rep,
  ) {
    return '$progress / $target · +$rep rép.';
  }

  @override
  String serverTycoonBoostExtend(String cost, String days) {
    return 'Prolonger — $cost pour $days jours';
  }

  @override
  String serverTycoonBoostActivate(String cost, String days) {
    return 'Activer — $cost pour $days jours';
  }

  @override
  String serverTycoonNetProfitLastDays(int count) {
    return 'Bénéfice net — $count derniers jours';
  }

  @override
  String serverTycoonPowerDrawLastDays(int count) {
    return 'Consommation — $count derniers jours';
  }

  @override
  String get serverTycoonBestWorst => 'Meilleur et pire';

  @override
  String get serverTycoonBestDay => 'Meilleur jour';

  @override
  String get serverTycoonWorstDay => 'Pire jour';

  @override
  String serverTycoonDayAmount(int day, String amount) {
    return 'Jour $day · $amount';
  }

  @override
  String get serverTycoonIncomeByService => 'Revenus par service';

  @override
  String get serverTycoonLifetimeEarned => 'Total gagné';

  @override
  String get serverTycoonDaysRun => 'Jours joués';

  @override
  String get serverTycoonUptimeStreak => 'Série de disponibilité';

  @override
  String serverTycoonUptimeDays(int count) {
    return '$count j';
  }

  @override
  String get serverTycoonPeakBandwidth => 'Bande passante max.';

  @override
  String get serverTycoonPeakPower => 'Puissance max.';

  @override
  String get serverTycoonContractsDone => 'Contrats terminés';

  @override
  String get serverTycoonResearchDone => 'Recherches terminées';

  @override
  String get serverTycoonResearchRate => 'Vitesse de recherche';

  @override
  String serverTycoonResearchRateValue(String rate) {
    return '$rate RP/jour';
  }

  @override
  String get serverTycoonRigs => 'Rigs';

  @override
  String get serverTycoonAwayRate => 'Taux d\'absence';

  @override
  String get serverTycoonNotEnoughDays => 'Pas encore assez de jours';

  @override
  String get serverTycoonWhileYouWereAway => 'Pendant votre absence';

  @override
  String serverTycoonAwayFor(String duration, int days, String rate) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours simulés',
      one: '1 jour simulé',
    );
    return 'Absent pendant $duration — $_temp0 à $rate % de taux.';
  }

  @override
  String serverTycoonAwayCapped(int maxDays, int elapsed) {
    return 'Plafonné à $maxDays jours — $elapsed s\'étaient écoulés. Recherchez la branche R&D Lab pour gagner davantage pendant votre absence.';
  }

  @override
  String get serverTycoonRunningCosts => 'Frais de fonctionnement';

  @override
  String get serverTycoonResearchPoints => 'Points de recherche';

  @override
  String get serverTycoonWhatHappened => 'Ce qui s\'est passé';

  @override
  String get serverTycoonBackToWork => 'Retour au travail';

  @override
  String serverTycoonDurationDaysHours(int days, int hours) {
    return '$days j $hours h';
  }

  @override
  String serverTycoonDurationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String serverTycoonDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get serverTycoonEccOk => 'ECC ok';

  @override
  String serverTycoonSpecRamSlots(int slots, String maxGb) {
    return '$slots emplacements RAM, max $maxGb Go';
  }

  @override
  String serverTycoonSpecSata(String sata, String m2) {
    return '$sata SATA, $m2 M.2';
  }

  @override
  String get serverTycoonSpecRegistered => 'enregistré';

  @override
  String get serverTycoonSpecWaterLoop => 'boucle à eau';

  @override
  String get serverTycoonSpecCooling => 'refroidissement';

  @override
  String serverTycoonReqCpuSocket(String socket) {
    return 'Cette carte nécessite un processeur $socket';
  }

  @override
  String serverTycoonReqBoardSocket(String cpu, String socket) {
    return 'Votre $cpu nécessite une carte $socket';
  }

  @override
  String serverTycoonReqRam(
    String type,
    int used,
    int slots,
    String maxGb,
    String ecc,
  ) {
    return 'Accepte $type · $used/$slots emplacements utilisés, max $maxGb Go$ecc';
  }

  @override
  String get serverTycoonReqNoEcc => ', ni enregistré ni ECC';

  @override
  String serverTycoonReqPorts(int sata, int sataMax, int m2, int m2Max) {
    return 'Ports SATA $sata/$sataMax · emplacements M.2 $m2/$m2Max utilisés';
  }

  @override
  String serverTycoonReqPower(String watts) {
    return 'Cette configuration consomme jusqu\'à $watts W';
  }

  @override
  String serverTycoonReqHeat(String cpu, String watts) {
    return 'Votre $cpu dégage $watts W de chaleur';
  }

  @override
  String serverTycoonRepoResearchCompleteLevel(String name, int level) {
    return 'Recherche terminée : $name (niveau $level)';
  }

  @override
  String serverTycoonRepoResearchComplete(String name) {
    return 'Recherche terminée : $name';
  }

  @override
  String get serverTycoonRepoUnknownResearch => 'Projet de recherche inconnu';

  @override
  String get serverTycoonRepoAlreadyResearched => 'Déjà recherché';

  @override
  String get serverTycoonRepoAlreadyQueued => 'Déjà en file d\'attente';

  @override
  String get serverTycoonRepoMaxLevel => 'Déjà au niveau maximum';

  @override
  String serverTycoonRepoRequiresProjectFirst(String name) {
    return 'Nécessite d\'abord $name';
  }

  @override
  String serverTycoonRepoRequiresReputation(String reputation) {
    return 'Nécessite $reputation de réputation';
  }

  @override
  String get serverTycoonRepoOneProjectAtATime =>
      'Un seul projet à la fois — construisez la branche Labo R&D pour avoir plus d\'emplacements de file';

  @override
  String serverTycoonRepoResearchSlotsBusy(String slots) {
    return 'Les $slots emplacements de recherche sont tous occupés';
  }

  @override
  String serverTycoonRepoNotEnoughMoneyNeeds(String cost) {
    return 'Pas assez d\'argent (il faut $cost)';
  }

  @override
  String get serverTycoonRepoNotEnoughMoney => 'Pas assez d\'argent';

  @override
  String get serverTycoonRepoNotInProgress => 'Ce projet n\'est pas en cours';

  @override
  String get serverTycoonRepoUnknownBoost => 'Boost inconnu';

  @override
  String serverTycoonRepoBoostWoreOff(String name) {
    return '$name a pris fin';
  }

  @override
  String get serverTycoonRepoIncidentNotFound => 'Incident introuvable';

  @override
  String get serverTycoonRepoIncidentNotMitigable =>
      'Cet incident ne peut pas être atténué';

  @override
  String get serverTycoonRepoIncidentNotCooled =>
      'Cet incident ne peut pas être refroidi';

  @override
  String get serverTycoonRepoCooldownsUsed =>
      'Refroidissement d\'urgence déjà utilisé deux fois aujourd\'hui';

  @override
  String get serverTycoonRepoIncidentNotRepairable =>
      'Cet incident ne peut pas être réparé';

  @override
  String get serverTycoonRepoNeedRouterFirst =>
      'Il vous faut d\'abord au moins un routeur';

  @override
  String get serverTycoonRepoResearchRouters =>
      'Recherchez de meilleures technologies réseau pour faire fonctionner d\'autres routeurs';

  @override
  String get serverTycoonRepoUnknownRig => 'Machine inconnue';

  @override
  String get serverTycoonRepoUnknownRouter => 'Routeur inconnu';

  @override
  String get serverTycoonRepoUnknownService => 'Service inconnu';

  @override
  String get serverTycoonRepoUnknownNodeKind => 'Type de nœud inconnu';

  @override
  String get serverTycoonRepoUnknownServiceType => 'Type de service inconnu';

  @override
  String serverTycoonRepoRequiresLicense(String license) {
    return 'Nécessite la licence $license';
  }

  @override
  String get serverTycoonRepoServiceInstanceNotFound =>
      'Instance de service introuvable';

  @override
  String get serverTycoonRepoSameKindConnect =>
      'Deux nœuds du même type ne peuvent pas être reliés entre eux';

  @override
  String get serverTycoonRepoCannotConnect =>
      'Ces deux éléments ne peuvent pas être reliés';

  @override
  String get serverTycoonRepoNothingToDisconnect => 'Rien à déconnecter';

  @override
  String get serverTycoonRepoUnknownLicense => 'Licence inconnue';

  @override
  String get serverTycoonRepoAlreadyOwned => 'Déjà possédé';

  @override
  String serverTycoonRepoRequiresLicenseFirst(String license) {
    return 'Nécessite d\'abord la licence $license';
  }

  @override
  String get serverTycoonRepoUnknownStaff => 'Membre du personnel inconnu';

  @override
  String get serverTycoonRepoAlreadyHired => 'Déjà embauché';

  @override
  String serverTycoonRepoRequiresResearch(String research) {
    return 'Nécessite la recherche $research';
  }

  @override
  String get serverTycoonRepoNotCurrentlyHired => 'Actuellement non embauché';

  @override
  String get serverTycoonRepoOfferAccepted => 'Offre déjà acceptée';

  @override
  String get serverTycoonRepoOfferExpired => 'Cette offre a expiré';

  @override
  String serverTycoonRepoContractSlots(String slots) {
    return 'Vous ne pouvez gérer que $slots contrats à la fois (recherchez Sales Team pour en avoir plus)';
  }

  @override
  String get serverTycoonRepoUnknownCategory => 'Catégorie d\'article inconnue';

  @override
  String get serverTycoonRepoUnknownItem => 'Article inconnu';

  @override
  String get serverTycoonRepoUnknownSlot => 'Emplacement de composant inconnu';

  @override
  String serverTycoonRepoPartBroken(String name, String problems) {
    return '$name est installé, mais ne fonctionne pas : $problems. Cette machine ne rapportera rien tant que le problème n\'est pas résolu.';
  }

  @override
  String get serverTycoonRepoUnknownPlan => 'Forfait inconnu';

  @override
  String get serverTycoonRepoUnknownRamStick => 'Barrette de RAM inconnue';

  @override
  String get serverTycoonRepoUnknownDrive => 'Disque inconnu';

  @override
  String get serverTycoonRepoNoRamAtSlot =>
      'Aucune barrette de RAM à cet emplacement';

  @override
  String get serverTycoonRepoNoDriveAtSlot => 'Aucun disque à cet emplacement';

  @override
  String get serverTycoonRepoFixIncompatible =>
      'Corrigez d\'abord les composants incompatibles';

  @override
  String get serverTycoonRepoNothingHoldingBack =>
      'Rien ne ralentit cette machine';

  @override
  String get serverTycoonRepoNoAffordableUpgrade =>
      'Aucune mise à niveau abordable pour ce goulot d\'étranglement';

  @override
  String get serverTycoonRepoFastestPlan =>
      'Déjà sur le forfait le plus rapide';

  @override
  String serverTycoonRepoCloned(String cost) {
    return 'Clonée pour $cost — installez-y des services pour commencer à gagner de l\'argent';
  }

  @override
  String get serverTycoonRepoNothingToArrange => 'Rien à disposer';

  @override
  String serverTycoonRepoNeedNetWorth(String amount) {
    return 'Il faut $amount de valeur nette pour monter en échelle';
  }

  @override
  String serverTycoonRepoContractCompleted(
    String company,
    String bonus,
    String rep,
  ) {
    return 'Contrat $company terminé : +$bonus de prime, +$rep de réputation';
  }

  @override
  String serverTycoonRepoContractFailed(
    String company,
    String capacity,
    String rep,
  ) {
    return 'Contrat $company ÉCHOUÉ (il fallait $capacity de capacité servie) : -$rep de réputation';
  }

  @override
  String serverTycoonRepoMissionReward(String name, String cash, String rep) {
    return '$name : +$cash, +$rep de réputation';
  }

  @override
  String get sftpHostStorageAccessTitle =>
      'Les autres appareils ne voient pas encore vos fichiers';

  @override
  String get sftpHostStorageAccessBody =>
      'Android masque les photos et fichiers créés par d\'autres applis tant que luma n\'a pas l\'« Accès à tous les fichiers ». D\'ici là, ce dossier paraît vide sur l\'autre appareil.';

  @override
  String get sftpHostWaitingForSettings => 'En attente des paramètres…';

  @override
  String get sftpHostAllowFileAccess => 'Autoriser l\'accès aux fichiers';

  @override
  String sftpHostWantsToConnect(String name) {
    return '$name veut se connecter';
  }

  @override
  String sftpHostApprovalDetail(String address) {
    return 'Il se trouve à $address et a donné le bon mot de passe d\'appairage.';
  }

  @override
  String get sftpHostAllow => 'Autoriser';

  @override
  String get sftpHostRefuse => 'Refuser';

  @override
  String get sftpHostNoDevicesConnected => 'Aucun appareil connecté';

  @override
  String sftpHostDevicesConnected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count appareils connectés',
      one: '1 appareil connecté',
    );
    return '$_temp0';
  }

  @override
  String sftpHostClientTraffic(String address, String sent, String received) {
    return '$address · envoyé $sent · reçu $received';
  }

  @override
  String get sftpHostDisconnect => 'Déconnecter';

  @override
  String get sftpHostChooseFolderTitle => 'Choisissez le dossier à partager';

  @override
  String get sftpHostChooseFolderFirst =>
      'Choisissez d\'abord un dossier à partager.';

  @override
  String get sftpHostFolderGone => 'Ce dossier n\'existe plus.';

  @override
  String get sftpHostPickPort => 'Choisissez un port entre 1024 et 65535.';

  @override
  String sftpHostPasswordTooShort(String minLength) {
    return 'Un mot de passe d\'appairage doit contenir au moins $minLength caractères.';
  }

  @override
  String sftpHostValueCopied(String what) {
    return '$what copié.';
  }

  @override
  String get sftpHostFieldAddress => 'Adresse';

  @override
  String get sftpHostFieldPort => 'Port';

  @override
  String get sftpHostFieldPassword => 'Mot de passe d\'appairage';

  @override
  String get sftpHostPasswordRotated =>
      'Nouveau mot de passe d\'appairage. Les appareils déjà connectés le restent.';

  @override
  String sftpHostHostingFolder(String name) {
    return 'Partage $name';
  }

  @override
  String get sftpHostAccessReadOnlyApproval =>
      'Lecture seule · vous approuvez chaque appareil';

  @override
  String get sftpHostAccessReadOnlyPassword =>
      'Lecture seule · mot de passe seulement';

  @override
  String get sftpHostAccessReadWriteApproval =>
      'Lecture et écriture · vous approuvez chaque appareil';

  @override
  String get sftpHostAccessReadWritePassword =>
      'Lecture et écriture · mot de passe seulement';

  @override
  String get sftpHostPairingInstructions =>
      'Sur l\'autre appareil, ouvrez le plugin SFTP, ajoutez un site de type « appareil luma » et saisissez :';

  @override
  String get sftpHostNoNetwork => 'Pas de connexion réseau';

  @override
  String sftpHostOtherAddresses(String addresses) {
    return 'Autres adresses de cet appareil : $addresses';
  }

  @override
  String get sftpHostNewPassword => 'Nouveau mot de passe';

  @override
  String get sftpHostShow => 'Afficher';

  @override
  String get sftpHostHide => 'Masquer';

  @override
  String get sftpHostSetupTitle =>
      'Laisser un autre appareil se connecter à celui-ci';

  @override
  String get sftpHostSetupSubtitle =>
      'Partagez un dossier via votre réseau. L\'autre appareil l\'ouvre dans son propre onglet Serveurs.';

  @override
  String get sftpHostFolderLabel => 'Dossier à partager';

  @override
  String get sftpHostNoFolderChosen => 'Aucun dossier choisi';

  @override
  String get sftpHostChoose => 'Choisir';

  @override
  String get sftpHostFolderNote =>
      'Seul ce dossier est partagé. Rien au-dessus n\'est accessible, et les liens qui sortent de ce dossier sont refusés.';

  @override
  String get sftpHostAccessLabel => 'Ce que l\'autre appareil peut faire';

  @override
  String get sftpHostAccessReadOnlyTab => 'Lecture seule';

  @override
  String get sftpHostAccessReadWriteTab => 'Lecture et écriture';

  @override
  String get sftpHostAccessReadOnlyHint =>
      'Il peut parcourir et télécharger. Rien ne change sur cet appareil.';

  @override
  String get sftpHostAccessReadWriteHint =>
      'Il peut aussi téléverser, renommer et supprimer dans le dossier partagé.';

  @override
  String get sftpHostApprovalToggle =>
      'Me demander avant d\'autoriser un appareil';

  @override
  String get sftpHostApprovalToggleSubtitle =>
      'Même avec le bon mot de passe, vous approuvez chacun d\'eux.';

  @override
  String get sftpHostOwnPasswordToggle =>
      'Choisir moi-même le mot de passe d\'appairage';

  @override
  String get sftpHostOwnPasswordSubtitle =>
      'Désactivé par défaut : luma en génère un bien plus robuste.';

  @override
  String sftpHostPasswordHint(String minLength) {
    return 'Au moins $minLength caractères';
  }

  @override
  String get sftpHostPasswordTooShortWarn =>
      'Trop court : ce mot de passe sera refusé.';

  @override
  String get sftpHostPasswordWeak =>
      'Faible. Quiconque peut atteindre ce port pourrait le deviner.';

  @override
  String get sftpHostPasswordFair =>
      'Correct. Un mot de passe plus long serait préférable.';

  @override
  String get sftpHostPasswordStrong => 'Robuste.';

  @override
  String get sftpHostStartHosting => 'Commencer le partage';

  @override
  String get sftpHostEmptyClients =>
      'Personne ne lit ce dossier. Il reste partagé jusqu\'à ce que vous appuyiez sur Arrêter ou fermiez luma.';

  @override
  String get sftpHostSecurityNote =>
      'Les deux appareils s\'accordent sur une clé à partir du mot de passe d\'appairage, puis chiffrent tout ce qui circule entre eux. Les serveurs de luma ne sont pas impliqués et ne voient jamais le dossier, le mot de passe ni les fichiers. Seul le dossier que vous choisissez est accessible. Le partage continue tant que luma est ouvert : appuyez sur Arrêter quand vous avez terminé.';

  @override
  String get sftpHostNoAddress => 'Cet appareil n\'a pas d\'adresse.';

  @override
  String get sftpHostTypePassword =>
      'Saisissez le mot de passe d\'appairage affiché sur cet appareil.';

  @override
  String sftpHostCouldNotReach(String host, String port, String detail) {
    return 'Impossible de joindre $host sur le port $port. Vérifiez que l\'autre appareil affiche encore son écran d\'appairage et que les deux sont sur le même réseau.\n$detail';
  }

  @override
  String sftpHostConnectTimedOut(String host, String port) {
    return 'Délai dépassé lors de la connexion à $host sur le port $port.';
  }

  @override
  String get sftpHostDeviceClosed => 'Cet appareil a fermé la connexion.';

  @override
  String sftpHostCouldNotConnect(String detail) {
    return 'Impossible de se connecter à cet appareil.\n$detail';
  }

  @override
  String get sftpHostExpectedAdmission =>
      'Autorisation d\'entrée attendue en premier.';

  @override
  String get sftpHostNotLetIn =>
      'Cet appareil ne vous a pas autorisé à entrer.';

  @override
  String get sftpHostDidNotAnswer =>
      'Cet appareil n\'a pas répondu à temps. Vérifiez qu\'il partage toujours.';

  @override
  String get sftpHostApprovalTimedOut =>
      'Personne de l\'autre côté n\'a autorisé cet appareil à temps. Demandez-leur d\'appuyer sur Autoriser, puis reconnectez-vous.';

  @override
  String get sftpHostRefusedRequest => 'Cet appareil a refusé la demande.';

  @override
  String get sftpHostTransferStopped =>
      'Le transfert s\'est arrêté de façon inattendue.';

  @override
  String get sftpHostFolderUnreadable =>
      'Cet appareil a envoyé un dossier que nous n\'avons pas pu lire.';

  @override
  String get sftpHostItemUnreadable => 'Cet élément n\'a pas pu être lu.';

  @override
  String sftpHostReadOnlyHere(String host) {
    return '$host partage ce dossier en lecture seule : il ne peut pas être modifié d\'ici.';
  }

  @override
  String sftpHostSaveFailed(String detail) {
    return 'Le fichier n\'a pas pu être enregistré ici : $detail';
  }

  @override
  String get sftpHostConnectionClosed =>
      'La connexion à cet appareil est fermée.';

  @override
  String get sftpHostConnectionWasClosed => 'La connexion a été fermée.';

  @override
  String get sftpHostRecordTooShort =>
      'Enregistrement trop court pour être authentique.';

  @override
  String get sftpHostFrameFailedAuth =>
      'Une trame a échoué au contrôle d\'authenticité ; la connexion a été fermée.';

  @override
  String get sftpHostOtherVersion =>
      'L\'autre appareil utilise une autre version.';

  @override
  String get sftpHostWrongPasswordAttempt =>
      'Un appareil a tenté de se connecter avec un mauvais mot de passe d\'appairage.';

  @override
  String get sftpHostWrongPassword =>
      'Ce mot de passe d\'appairage n\'est pas celui affiché par cet appareil.';

  @override
  String get sftpHostVersionMismatch =>
      'Cet appareil utilise une autre version de luma. Mettez les deux appareils à jour vers la même version et réessayez.';

  @override
  String get sftpHostRefusedConnection => 'Cet appareil a refusé la connexion.';

  @override
  String get sftpHostCouldNotProve =>
      'Cet appareil n\'a pas pu prouver qu\'il est celui qui affiche ce mot de passe d\'appairage. Rien ne lui a été envoyé.';

  @override
  String get sftpHostPartSalt => 'sel';

  @override
  String get sftpHostPartKey => 'clé';

  @override
  String get sftpHostPartProof => 'preuve';

  @override
  String sftpHostHandshakeMissing(String part) {
    return 'Le champ $part manque dans la poignée de main.';
  }

  @override
  String sftpHostHandshakeMalformed(String part) {
    return 'Le champ $part de la poignée de main est mal formé.';
  }

  @override
  String sftpHostHandshakeWrongSize(String part) {
    return 'Le champ $part de la poignée de main a la mauvaise taille.';
  }

  @override
  String get sftpHostUnnamedDevice => 'appareil luma';

  @override
  String get sftpHostSharedFolderName => 'Partagé';

  @override
  String get sftpHostEmptyFrame => 'Trame vide.';

  @override
  String get sftpHostControlNotJson =>
      'La trame de contrôle n\'était pas du JSON valide.';

  @override
  String get sftpHostControlNotObject =>
      'La trame de contrôle n\'était pas un objet.';

  @override
  String get sftpHostChunkTruncated => 'Trame de données tronquée.';

  @override
  String sftpHostUnknownFrameKind(String kind) {
    return 'Type de trame inconnu 0x$kind.';
  }

  @override
  String sftpHostFrameTooLarge(String length) {
    return 'La trame de $length octets dépasse ce que cette connexion autorise.';
  }

  @override
  String get sftpHostExpectedHandshake =>
      'Un message de poignée de main était attendu.';

  @override
  String sftpServerPasswordTooShort(int count) {
    return 'Un mot de passe d\'appairage doit comporter au moins $count caractères.';
  }

  @override
  String sftpServerListenerStopped(String error) {
    return 'L\'écouteur s\'est arrêté : $error';
  }

  @override
  String sftpServerPortInUse(int port) {
    return 'Le port $port est déjà utilisé sur cet appareil. Choisissez-en un autre.';
  }

  @override
  String sftpServerCouldNotListen(int port, String reason) {
    return 'Impossible d\'écouter sur le port $port. $reason';
  }

  @override
  String sftpServerCouldNotStart(String error) {
    return 'Impossible de démarrer le partage. $error';
  }

  @override
  String get sftpServerConnecting => 'Connexion…';

  @override
  String get sftpThisDeviceTitle => 'Cet appareil';

  @override
  String get sftpThisDeviceUnknown => 'Inconnu';

  @override
  String get sftpThisDeviceChooseFolderTitle =>
      'Choisissez le dossier à partager';

  @override
  String get sftpThisDevicePasswordRotated =>
      'Nouveau mot de passe d\'appairage. Les appareils déjà connectés le restent.';

  @override
  String sftpThisDeviceCopied(String what) {
    return '$what copié.';
  }

  @override
  String get sftpThisDeviceFieldDevice => 'Appareil';

  @override
  String get sftpThisDeviceFieldDeviceName => 'Nom de l\'appareil';

  @override
  String get sftpThisDeviceFieldUser => 'Utilisateur';

  @override
  String get sftpThisDeviceFieldUserName => 'Nom d\'utilisateur';

  @override
  String get sftpThisDeviceFieldAddress => 'Adresse';

  @override
  String get sftpThisDeviceFieldPort => 'Port';

  @override
  String get sftpThisDeviceFieldPassword => 'Mot de passe d\'appairage';

  @override
  String get sftpThisDeviceShow => 'Afficher';

  @override
  String get sftpThisDeviceHide => 'Masquer';

  @override
  String get sftpThisDeviceNoNetwork => 'Aucune connexion réseau';

  @override
  String sftpThisDeviceOtherAddresses(String addresses) {
    return 'Autres adresses de cet appareil : $addresses';
  }

  @override
  String get sftpThisDeviceCredentialsTitle => 'Identifiants de cet appareil';

  @override
  String get sftpThisDeviceCredentialsHelp =>
      'Sur l\'autre appareil, ouvrez le plugin SFTP, appuyez sur Nouveau site, choisissez « appareil luma » et saisissez-les.';

  @override
  String get sftpThisDeviceUserNameNote =>
      'Le nom d\'utilisateur sert à distinguer les appareils. luma s\'appaire uniquement avec le mot de passe : ce n\'est pas une connexion SSH, et rien du compte de cet appareil n\'est exposé.';

  @override
  String get sftpThisDeviceNewPassword => 'Nouveau mot de passe';

  @override
  String get sftpThisDeviceStatusChooseTitle =>
      'Choisissez un dossier à partager';

  @override
  String get sftpThisDeviceStatusChooseBody =>
      'Rien n\'est accessible tant que vous n\'en choisissez pas un. Seul ce dossier est partagé, rien au-dessus.';

  @override
  String get sftpThisDeviceStatusOpeningTitle => 'Ouverture de cet appareil…';

  @override
  String get sftpThisDeviceStatusOpeningBody => 'Configuration de l\'écouteur.';

  @override
  String get sftpThisDeviceStatusPausedTitle =>
      'En pause pendant que luma est en arrière-plan';

  @override
  String get sftpThisDeviceStatusPausedBody =>
      'Il redémarre automatiquement quand vous revenez à cet écran.';

  @override
  String get sftpThisDeviceStatusReachableTitle =>
      'D\'autres appareils peuvent accéder à celui-ci';

  @override
  String get sftpThisDeviceStatusReachableBody =>
      'Uniquement tant que cet écran est ouvert.';

  @override
  String get sftpThisDeviceStatusUnreachableTitle => 'Non accessible';

  @override
  String get sftpThisDeviceStatusFailedBody =>
      'Le partage n\'a pas pu démarrer.';

  @override
  String get sftpThisDeviceFolderLabel => 'Dossier partagé';

  @override
  String get sftpThisDeviceNoFolder => 'Aucun dossier choisi pour l\'instant';

  @override
  String get sftpThisDeviceChange => 'Modifier';

  @override
  String get sftpThisDeviceTermsTitle => 'Ce que l\'autre appareil peut faire';

  @override
  String get sftpThisDeviceReadOnly => 'Lecture seule';

  @override
  String get sftpThisDeviceReadWrite => 'Lecture et écriture';

  @override
  String get sftpThisDeviceReadOnlyHelp =>
      'Il peut parcourir et télécharger. Rien sur cet appareil ne change.';

  @override
  String get sftpThisDeviceReadWriteHelp =>
      'Il peut aussi envoyer, renommer et supprimer dans le dossier partagé.';

  @override
  String get sftpThisDeviceAskApproval =>
      'Me demander avant d\'accepter un appareil';

  @override
  String get sftpThisDeviceAskApprovalSub =>
      'Même avec le bon mot de passe, vous approuvez chaque appareil.';

  @override
  String get sftpThisDeviceRestartNote =>
      'Modifier l\'un de ces réglages redémarre l\'écouteur, et tout ce qui est connecté est alors déconnecté.';

  @override
  String get sftpThisDeviceEmptyClients =>
      'Rien ne lit encore ce dossier. Gardez cet écran ouvert pendant que l\'autre appareil se connecte.';

  @override
  String get sftpThisDeviceLifetimeNote =>
      'Cet appareil n\'est accessible que tant que cet écran est ouvert. Revenez en arrière, ou passez luma en arrière-plan, et l\'écouteur se ferme : tous les appareils connectés sont déconnectés en plein transfert. Utilisez plutôt l\'onglet Hôte lorsqu\'un transfert doit continuer pendant que vous faites autre chose. Les deux appareils se mettent d\'accord sur une clé à partir du mot de passe d\'appairage et chiffrent tout entre eux ; les serveurs de luma n\'interviennent pas et ne voient jamais le dossier, le mot de passe ni les fichiers.';

  @override
  String get sftpHostKeyChangedTitle => 'La clé de ce serveur a changé';

  @override
  String get sftpHostKeyUnknownTitle => 'Clé de serveur inconnue';

  @override
  String sftpHostKeyChangedBody(String host) {
    return 'Une autre clé était auparavant approuvée pour $host. Soit le serveur a été reconstruit, soit quelque chose se fait passer pour lui. Ne continuez pas sauf si vous savez que le serveur a changé.';
  }

  @override
  String sftpHostKeyUnknownBody(String host) {
    return 'luma ne s\'est jamais connecté à $host auparavant. Comparez l\'empreinte à celle du serveur, puis décidez si vous lui faites confiance.';
  }

  @override
  String get sftpPreviouslyTrusted => 'Précédemment approuvée';

  @override
  String get sftpTrustNewKey => 'Faire confiance à la nouvelle clé';

  @override
  String get sftpTrustAndConnect => 'Approuver et se connecter';

  @override
  String get sftpConnect => 'Se connecter';

  @override
  String get sftpShow => 'Afficher';

  @override
  String get sftpHide => 'Masquer';

  @override
  String get sftpRememberForSite => 'Mémoriser pour ce site';

  @override
  String get sftpEncryptedLocalNote =>
      'Chiffré sur cet appareil. Jamais envoyé nulle part.';

  @override
  String sftpConnectToDevice(String deviceName) {
    return 'Se connecter à $deviceName';
  }

  @override
  String get sftpPortRangeError =>
      'Le port doit être un nombre compris entre 1 et 65535.';

  @override
  String sftpPairingPasswordRequired(String deviceName) {
    return 'Saisissez le mot de passe d\'appairage affiché sur $deviceName.';
  }

  @override
  String sftpQuickConnectFound(String address) {
    return 'Trouvé sur ce réseau à $address. Saisissez le port et le mot de passe d\'appairage affichés dans l\'onglet Host ou sur l\'écran Cet appareil.';
  }

  @override
  String get sftpPortLabel => 'Port';

  @override
  String get sftpPairingPasswordLabel => 'Mot de passe d\'appairage';

  @override
  String get sftpRememberDevicePassword =>
      'Mémoriser le mot de passe pour cet appareil';

  @override
  String sftpDeleteOneTitle(String name) {
    return 'Supprimer $name ?';
  }

  @override
  String sftpDeleteManyTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Supprimer $count éléments ?',
      one: 'Supprimer 1 élément ?',
    );
    return '$_temp0';
  }

  @override
  String get sftpDeleteRemoteWarning =>
      'Ils seront supprimés sur le serveur. Les dossiers entraînent la suppression de tout leur contenu, et cette action est irréversible.';

  @override
  String get sftpDeleteLocalWarning =>
      'Ils seront supprimés sur cet appareil. Cette action est irréversible.';

  @override
  String sftpPermissionsTitle(String name) {
    return 'Autorisations pour $name';
  }

  @override
  String get sftpPermissionsMode => 'Mode';

  @override
  String get sftpPermissionsHelper => 'Octal (755) ou symbolique (rwxr-xr-x)';

  @override
  String get sftpPermissionsInvalid => 'Mode non valide.';

  @override
  String get sftpLocalAppStorage => 'Stockage de l\'application';

  @override
  String get sftpLocalHome => 'Dossier personnel';

  @override
  String sftpDropUploadTo(String name) {
    return 'Importer vers $name';
  }

  @override
  String get sftpDropDownloadHere => 'Télécharger ici';

  @override
  String get sftpFolderEmpty => 'Ce dossier est vide.';

  @override
  String get sftpNothingToShow => 'Rien à afficher.';

  @override
  String get sftpUpOneFolder => 'Dossier parent';

  @override
  String get sftpPlaces => 'Emplacements';

  @override
  String get sftpHomeFolder => 'Dossier personnel';

  @override
  String get sftpNewFolder => 'Nouveau dossier';

  @override
  String sftpSelectedOfCount(int selected, int count) {
    return '$selected sur $count sélectionné(s)';
  }

  @override
  String sftpItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments',
      one: '1 élément',
    );
    return '$_temp0';
  }

  @override
  String sftpSelectEntry(String name) {
    return 'Sélectionner $name';
  }

  @override
  String sftpCouldNotFindStartFolder(String error) {
    return 'Impossible de trouver un dossier de départ. $error';
  }

  @override
  String sftpCouldNotOpenFolder(String error) {
    return 'Impossible d\'ouvrir ce dossier. $error';
  }

  @override
  String sftpCouldNotListFolder(String error) {
    return 'Impossible de lister ce dossier. $error';
  }

  @override
  String sftpPairingPasswordFor(String name) {
    return 'Mot de passe d\'appairage pour $name';
  }

  @override
  String sftpPasswordFor(String name) {
    return 'Mot de passe pour $name';
  }

  @override
  String sftpPassphraseFor(String name) {
    return 'Phrase de passe pour $name';
  }

  @override
  String get sftpTypeDevicePasswordHint =>
      'Saisissez le mot de passe affiché dans l\'onglet Host de cet appareil.';

  @override
  String sftpSigningInAs(String username, String host) {
    return 'Connexion en tant que $username sur $host.';
  }

  @override
  String sftpWaitingForApproval(String host) {
    return 'En attente de l\'autorisation de quelqu\'un sur $host…';
  }

  @override
  String get sftpConnectionClosed => 'La connexion au serveur a été fermée.';

  @override
  String sftpConnectionClosedWithReason(String reason) {
    return 'La connexion a été fermée : $reason';
  }

  @override
  String get sftpNothingToUpload => 'Rien à importer.';

  @override
  String sftpQueuedForUpload(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments ajoutés à la file d\'importation.',
      one: '1 élément ajouté à la file d\'importation.',
    );
    return '$_temp0';
  }

  @override
  String get sftpNothingToDownload => 'Rien à télécharger.';

  @override
  String sftpQueuedForDownload(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments ajoutés à la file de téléchargement.',
      one: '1 élément ajouté à la file de téléchargement.',
    );
    return '$_temp0';
  }

  @override
  String sftpCouldNotOpenName(String name, String message) {
    return 'Impossible d\'ouvrir $name. $message';
  }

  @override
  String get sftpFolderNameLabel => 'Nom du dossier';

  @override
  String get sftpCreate => 'Créer';

  @override
  String sftpCouldNotCreateFolder(String error) {
    return 'Impossible de créer le dossier. $error';
  }

  @override
  String get sftpNewNameLabel => 'Nouveau nom';

  @override
  String sftpCouldNotRename(String name, String error) {
    return 'Impossible de renommer $name. $error';
  }

  @override
  String sftpCouldNotDeleteAll(String error) {
    return 'Impossible de tout supprimer. $error';
  }

  @override
  String sftpCouldNotChangePermissions(String error) {
    return 'Impossible de modifier les autorisations. $error';
  }

  @override
  String sftpUploadLabel(String target) {
    return 'Importer $target';
  }

  @override
  String sftpDownloadLabel(String target) {
    return 'Télécharger $target';
  }

  @override
  String sftpDeleteLabel(String target) {
    return 'Supprimer $target';
  }

  @override
  String get sftpPermissions => 'Autorisations';

  @override
  String get sftpOpenSettingsSync =>
      'Ouvrez Paramètres → Synchro et compte pour configurer cet appareil.';

  @override
  String get sftpAddToSharedFolder => 'Ajouter au dossier partagé';

  @override
  String sftpNameInShare(String name) {
    return '$name est dans le dossier partagé.';
  }

  @override
  String sftpItemsInShare(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments sont dans le dossier partagé.',
      one: '1 élément est dans le dossier partagé.',
    );
    return '$_temp0';
  }

  @override
  String sftpFolderAt(String path) {
    return 'Le dossier se trouve à $path';
  }

  @override
  String get sftpShareDeleteWarning =>
      'Ils disparaîtront aussi du dossier partagé sur vos autres appareils à leur prochaine connexion.';

  @override
  String get sftpSiteManager => 'Gestionnaire de sites';

  @override
  String get sftpDisconnect => 'Déconnecter';

  @override
  String get sftpHostThisDevice => 'Héberger cet appareil';

  @override
  String get sftpMyDevices => 'Mes appareils';

  @override
  String get sftpServers => 'Serveurs';

  @override
  String get sftpHost => 'Hôte';

  @override
  String get sftpSharingFolderNote =>
      'Un dossier est partagé — tout appareil disposant du mot de passe d\'appairage peut se connecter.';

  @override
  String get sftpHostIdleNote =>
      'Laissez un autre appareil se connecter à celui-ci via votre réseau.';

  @override
  String get sftpDevicesNote =>
      'Un seul dossier, synchronisé sur vos appareils via votre réseau.';

  @override
  String get sftpServersNote =>
      'Connectez-vous à votre propre serveur — rien ne transite par luma.';

  @override
  String sftpConnectedTo(String endpoint) {
    return 'Connecté à $endpoint';
  }

  @override
  String get sftpThisDevice => 'Cet appareil';

  @override
  String get sftpSharedFolder => 'Dossier partagé';

  @override
  String sftpShareItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Partager $count éléments',
      one: 'Partager 1 élément',
    );
    return '$_temp0';
  }

  @override
  String sftpUploadItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Importer $count éléments',
      one: 'Importer 1 élément',
    );
    return '$_temp0';
  }

  @override
  String sftpDownloadItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Télécharger $count éléments',
      one: 'Télécharger 1 élément',
    );
    return '$_temp0';
  }

  @override
  String get sftpTabServer => 'Serveur';

  @override
  String get sftpTabQueue => 'File d\'attente';

  @override
  String sftpQueueWithCount(int count) {
    return 'File d\'attente ($count)';
  }

  @override
  String get sftpPutInShare =>
      'Placer les fichiers sélectionnés dans le dossier partagé';

  @override
  String get sftpUploadSelected => 'Importer les fichiers sélectionnés';

  @override
  String get sftpDownloadSelected => 'Télécharger les fichiers sélectionnés';

  @override
  String get sftpUpsellTitle => 'SFTP est inclus dans Orbit et Nova';

  @override
  String get sftpUpsellBody =>
      'Connectez-vous à vos propres serveurs avec un hôte, un nom d\'utilisateur, un mot de passe et un port, parcourez les deux côtés à la fois et glissez-déposez les fichiers. La connexion va directement de cet appareil à votre serveur — rien ne passe par un serveur luma.';

  @override
  String sftpUpgradeTo(String plan) {
    return 'Passer à $plan';
  }

  @override
  String get sftpQueueNothingQueued =>
      'Rien dans la file. Faites glisser des fichiers d\'un côté à l\'autre, ou sélectionnez-en et utilisez les flèches de transfert.';

  @override
  String get sftpQueueTransferring => 'Transfert en cours';

  @override
  String get sftpQueueTitle => 'File de transfert';

  @override
  String get sftpQueueRetryAll => 'Tout réessayer';

  @override
  String sftpQueueFilesLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers restants',
      one: '1 fichier restant',
    );
    return '$_temp0';
  }

  @override
  String sftpQueueFailedCount(int count) {
    return '$count échec(s)';
  }

  @override
  String get sftpQueueIdle => 'Vide';

  @override
  String get sftpQueueAllDone => 'Tout est terminé';

  @override
  String get sftpQueueWaiting => 'En attente';

  @override
  String sftpQueueRunningDetail(String done, String total, String rate) {
    return '$done sur $total · $rate';
  }

  @override
  String get sftpQueueStopped => 'Arrêté';

  @override
  String get sftpQueueFailed => 'Échec';

  @override
  String get sftpErrNoHostName => 'Ce site n\'a pas de nom d\'hôte.';

  @override
  String sftpErrCouldNotReachHost(String host, String port, String reason) {
    return 'Impossible de joindre $host sur le port $port.\n$reason';
  }

  @override
  String sftpErrConnectTimedOut(String host, String port) {
    return 'Délai dépassé lors de la connexion à $host sur le port $port.';
  }

  @override
  String get sftpErrHostKeyNotAccepted =>
      'La clé du serveur n\'a pas été acceptée, rien ne lui a donc été envoyé.';

  @override
  String sftpErrNoSftpChannel(String error) {
    return 'Connecté, mais le serveur n\'a pas ouvert de canal SFTP. Le sous-système SFTP de son service SSH est peut-être désactivé.\n($error)';
  }

  @override
  String get sftpErrKeyAuthNoFile =>
      'Ce site utilise l\'authentification par clé, mais aucun fichier de clé n\'est choisi.';

  @override
  String sftpErrKeyNotFound(String path) {
    return 'Clé privée introuvable à $path';
  }

  @override
  String sftpErrKeyReadFailed(String error) {
    return 'Impossible de lire la clé privée.\n($error)';
  }

  @override
  String get sftpErrKeyPassphraseRequired =>
      'Cette clé privée est protégée par une phrase secrète.';

  @override
  String get sftpErrPassphraseWrong =>
      'Cette phrase secrète ne déverrouille pas la clé privée.';

  @override
  String sftpErrNotPrivateKey(String error) {
    return 'Ce fichier n\'est pas une clé privée que luma peut lire.\n($error)';
  }

  @override
  String sftpErrKeyRejected(String username) {
    return 'Le serveur a rejeté cette clé pour $username.';
  }

  @override
  String get sftpErrPasswordRejected =>
      'Le serveur a rejeté ce nom d\'utilisateur ou ce mot de passe.';

  @override
  String sftpErrSignInAborted(String message) {
    return 'Le serveur a fermé la connexion pendant l\'authentification.\n$message';
  }

  @override
  String sftpErrCouldNotSignIn(String host, String error) {
    return 'Impossible de se connecter à $host.\n$error';
  }

  @override
  String get sftpTransferCancelled => 'Transfert annulé';

  @override
  String get sftpSiteSnapshotInvalid => 'Instantané des sites SFTP non valide.';

  @override
  String get sftpNearbyTitle => 'Sur ce réseau';

  @override
  String get sftpNearbyEmpty =>
      'Aucun appareil luma de ce réseau n\'héberge actuellement. Ouvrez l\'onglet Hôte ou Cet appareil sur l\'autre, et il apparaîtra ici.';

  @override
  String sftpNearbyOtherVersion(String address) {
    return '$address · utilise une autre version de luma — mettez les deux à jour pour vous connecter';
  }

  @override
  String get sftpSiteNoServersTitle => 'Aucun serveur pour l\'instant';

  @override
  String get sftpSiteNoServersBody =>
      'Un site est un serveur enregistré : son nom d\'hôte, son nom d\'utilisateur, son mot de passe et son port. luma s\'y connecte directement depuis cet appareil. Pour faire l\'inverse et permettre à un autre appareil de se connecter à celui-ci, ouvrez Cet appareil.';

  @override
  String get sftpSiteNew => 'Nouveau site';

  @override
  String get sftpSiteManagerTitle => 'Gestionnaire de sites';

  @override
  String get sftpSiteManagerSubtitle =>
      'Vos serveurs, enregistrés uniquement sur cet appareil.';

  @override
  String get sftpPrivacyNote =>
      'Les connexions vont directement de cet appareil à votre serveur. Rien ne passe par un serveur luma, et les mots de passe enregistrés restent chiffrés ici : ils ne sont jamais synchronisés.';

  @override
  String get sftpPasswordSavedTooltip =>
      'Mot de passe enregistré, chiffré sur cet appareil';

  @override
  String get sftpEditSiteTooltip => 'Modifier le site';

  @override
  String get sftpRemoveSiteTooltip => 'Supprimer le site';

  @override
  String get sftpEditSiteTitle => 'Modifier le site';

  @override
  String get sftpChoosePrivateKey => 'Choisir une clé privée';

  @override
  String get sftpErrHostRequired =>
      'Un nom d\'hôte ou une adresse IP est requis.';

  @override
  String get sftpErrUsernameRequired => 'Un nom d\'utilisateur est requis.';

  @override
  String get sftpErrKeyFileRequired =>
      'Choisissez le fichier de clé privée avec lequel vous connecter.';

  @override
  String get sftpEndpointQuestion => 'Ce qui se trouve à l\'autre bout';

  @override
  String get sftpTransportSshServer => 'Serveur SSH';

  @override
  String get sftpTransportLumaDevice => 'Appareil luma';

  @override
  String get sftpLumaDeviceHint =>
      'Un autre appareil avec luma dont l\'hébergement est activé. Lisez son adresse, son port et son mot de passe d\'appairage dans son onglet Hôte.';

  @override
  String get sftpSshServerHint =>
      'Tout serveur parlant SSH : un VPS, un NAS, un Pi.';

  @override
  String get sftpSiteNameHintLuma => 'Mon ordinateur portable';

  @override
  String get sftpSiteNameHintServer => 'Mon VPS';

  @override
  String get sftpSiteFieldHost => 'Hôte';

  @override
  String get sftpSiteHostHint => 'example.com ou 203.0.113.10';

  @override
  String get sftpSignInWith => 'Se connecter avec';

  @override
  String get sftpSignInSshKey => 'Clé SSH';

  @override
  String get sftpPairingPasswordHelper =>
      'Celui affiché sur cet appareil en ce moment.';

  @override
  String get sftpKeyPassphrase => 'Phrase secrète de la clé';

  @override
  String get sftpKeyPassphraseHelper =>
      'Laissez vide si la clé n\'a pas de phrase secrète.';

  @override
  String get sftpSaveDeviceSecret =>
      'Enregistrer le mot de passe d\'appairage pour cet appareil';

  @override
  String get sftpSaveKeyPassphrase =>
      'Enregistrer la phrase secrète pour ce site';

  @override
  String get sftpSaveSitePassword => 'Enregistrer le mot de passe pour ce site';

  @override
  String get sftpSaveDeviceSecretNote =>
      'Chiffré sur cet appareil, mais l\'autre appareil le change à chaque démarrage de l\'hébergement.';

  @override
  String get sftpSaveSiteSecretNote =>
      'Chiffré sur cet appareil. Décochez la case et luma vous le demandera à chaque connexion.';

  @override
  String get sftpOpenFolderOnConnect => 'Ouvrir ce dossier à la connexion';

  @override
  String get sftpLumaFolderHint => '/photos (facultatif)';

  @override
  String get sftpSftpFolderHint => '/var/www (facultatif)';

  @override
  String get sftpSaveSite => 'Enregistrer le site';

  @override
  String get sftpNoKeyChosen => 'Aucune clé privée choisie';

  @override
  String sftpShareCouldNotAdd(String name, String error) {
    return 'Impossible d\'ajouter $name : $error';
  }

  @override
  String get sftpShareOutOfStep =>
      'Le transfert s\'est désynchronisé ; il va recommencer.';

  @override
  String get sftpShareMismatch =>
      'La copie reçue ne correspond pas à l\'original ; elle sera de nouveau récupérée.';

  @override
  String get sftpShareDeviceWentAway => 'L\'appareil s\'est déconnecté.';

  @override
  String sftpShareSummary(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers',
      one: '1 fichier',
    );
    return '$_temp0 · $size';
  }

  @override
  String get sftpShareFolderTitle => 'Dossier partagé';

  @override
  String sftpShareSelectedCount(int count) {
    return '$count sélectionné(s)';
  }

  @override
  String sftpShareSummaryOnEveryDevice(String summary) {
    return '$summary · sur chaque appareil';
  }

  @override
  String get sftpShareDeleteEverywhere => 'Supprimer partout';

  @override
  String get sftpShareAddFiles => 'Ajouter des fichiers';

  @override
  String get sftpShareOpenFolderHere => 'Ouvrir le dossier sur cet appareil';

  @override
  String get sftpShareRescan => 'Analyser à nouveau';

  @override
  String get sftpShareDropToShare => 'Déposer pour partager';

  @override
  String get sftpShareNothingYet => 'Rien n\'est encore partagé';

  @override
  String get sftpShareEmptyHint =>
      'Faites glisser des fichiers depuis la gauche, ou utilisez +. Tout ce qui est ici apparaît dans le même dossier sur vos autres appareils, envoyé directement via votre réseau, jamais par un serveur luma.';

  @override
  String get sftpShareOpen => 'Ouvrir';

  @override
  String get sftpShareLookingForDevices =>
      'Recherche de vos autres appareils sur ce réseau. Ouvrez luma sur l\'un d\'eux, connecté au même compte.';

  @override
  String get sftpShareSyncOff =>
      'La synchronisation des appareils est désactivée. Activez-la dans Paramètres → Synchronisation et compte pour atteindre vos autres appareils.';

  @override
  String sftpShareFilesToGo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers restants',
      one: '1 fichier restant',
    );
    return '$_temp0';
  }

  @override
  String get sftpShareUpToDate => 'À jour';

  @override
  String sftpShareWaitingForReturn(int count) {
    return '$count en attente de son retour';
  }

  @override
  String get sftpShareNotOnNetwork => 'Pas sur ce réseau';

  @override
  String get sftpShareFailed => 'Échec';

  @override
  String sftpShareFromDevice(String device) {
    return 'depuis $device';
  }

  @override
  String sftpShareToDevice(String device) {
    return 'vers $device';
  }

  @override
  String get sftpShareSignInFirstTitle =>
      'Connectez-vous d\'abord sur les deux appareils';

  @override
  String get sftpShareSignInFirstBody =>
      'Le dossier partagé déplace les fichiers directement entre les appareils connectés au même compte luma, via votre propre réseau. Configurez la synchronisation des appareils dans Paramètres → Synchronisation et compte sur chaque appareil, puis revenez ici.';

  @override
  String get sftpShareOpenSettings => 'Ouvrir les paramètres';

  @override
  String get sendToDevicesTitle => 'Envoyer à vos appareils';

  @override
  String sendToDevicesItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments',
      one: '1 élément',
    );
    return '$_temp0';
  }

  @override
  String get sendToDevicesFolderLabel => 'Dossier dans le dossier partagé';

  @override
  String get sendToDevicesFolderHint =>
      'Laissez vide pour les déposer à la racine';

  @override
  String sendToDevicesCopying(int done, int total) {
    return 'Copie de $done sur $total…';
  }

  @override
  String get sendToDevicesNoneReadable =>
      'Impossible de lire aucun de ces éléments sur cet appareil.';

  @override
  String sendToDevicesOnTheWay(int count, int deviceCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers',
      one: '1 fichier',
    );
    String _temp1 = intl.Intl.pluralLogic(
      deviceCount,
      locale: localeName,
      other: 'appareils',
      one: 'appareil',
    );
    return '$_temp0 en route vers vos autres $_temp1.';
  }

  @override
  String sendToDevicesQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers prêts',
      one: '1 fichier prêt',
    );
    return '$_temp0 — ils partiront dès qu\'un autre appareil sera sur ce réseau.';
  }

  @override
  String get sendToDevicesNoPeers =>
      'Aucun autre appareil sur ce réseau pour le moment. Ce que vous envoyez attend dans le dossier partagé et partira dès qu\'un appareil apparaîtra.';

  @override
  String get sendToDevicesSyncOff =>
      'La synchronisation des appareils est désactivée. Activez-la dans Paramètres → Synchronisation et compte, et vos autres appareils récupéreront ces fichiers.';

  @override
  String get sendToDevicesHere => 'ici';

  @override
  String get sendToDevicesAway => 'absent';

  @override
  String get sendToDevicesUnavailable =>
      'Le dossier partagé ne tourne pas sur cet appareil. Il est inclus avec Orbit et Nova et nécessite que la synchronisation des appareils soit activée dans Paramètres → Synchronisation et compte, sur cet appareil et sur celui vers lequel vous voulez envoyer.';

  @override
  String get bingoExportSaveTitle => 'Enregistrer les cartons BINGO en PDF';

  @override
  String bingoExportCardNumber(String number) {
    return 'CARTON $number';
  }

  @override
  String get bingoExportInstructions =>
      'Marquez cinq cases alignées, horizontalement, verticalement ou en diagonale.';

  @override
  String get bingoExportFree => 'LIBRE';

  @override
  String get bingoExportFooter => 'PETITS JEUX  /  BINGO';

  @override
  String get bingoExportEncodeFailed =>
      'Impossible d\'encoder le carton BINGO.';

  @override
  String get cardGamesHandHighCard => 'Carte haute';

  @override
  String get cardGamesHandOnePair => 'Une paire';

  @override
  String get cardGamesHandTwoPair => 'Deux paires';

  @override
  String get cardGamesHandThreeOfKind => 'Brelan';

  @override
  String get cardGamesHandStraight => 'Quinte';

  @override
  String get cardGamesHandFlush => 'Couleur';

  @override
  String get cardGamesHandFullHouse => 'Full';

  @override
  String get cardGamesHandFourOfKind => 'Carré';

  @override
  String get cardGamesHandStraightFlush => 'Quinte flush';

  @override
  String get cardGamesBjPushBlackjack => 'Égalité — les deux ont un blackjack.';

  @override
  String get cardGamesBjPlayerBlackjack => 'Blackjack ! Vous gagnez.';

  @override
  String get cardGamesBjDealerBlackjack => 'Le croupier a un blackjack.';

  @override
  String get cardGamesBjBust => 'Dépassé — le croupier gagne.';

  @override
  String get cardGamesBjPlayerWins => 'Vous gagnez cette main !';

  @override
  String get cardGamesBjPushTie => 'Égalité.';

  @override
  String get cardGamesBjDealerWins => 'Le croupier gagne cette main.';

  @override
  String cardGamesPokerPlayerWins(String yours, String theirs) {
    return 'Vous gagnez ! $yours bat $theirs.';
  }

  @override
  String cardGamesPokerDealerWins(String yours, String theirs) {
    return 'Le croupier gagne. $theirs bat $yours.';
  }

  @override
  String cardGamesPokerPush(String hand) {
    return 'Égalité — les deux mains ont $hand.';
  }

  @override
  String get cardGamesPatienceStart =>
      'Piochez une carte ou touchez une carte visible pour la sélectionner.';

  @override
  String get cardGamesPatienceDrawn =>
      'Touchez la carte piochée, puis une colonne ou une fondation.';

  @override
  String get cardGamesPatienceRecycled => 'Pioche recyclée. Piochez à nouveau.';

  @override
  String get cardGamesPatienceChooseTarget =>
      'Choisissez une colonne ou une fondation.';

  @override
  String get cardGamesPatienceChooseAnother =>
      'Choisissez une autre colonne, ou déplacez la carte du dessus vers une fondation.';

  @override
  String get cardGamesPatienceChooseColumn => 'Choisissez une colonne.';

  @override
  String get cardGamesPatienceOnlyKing =>
      'Seul un roi peut commencer une colonne vide.';

  @override
  String get cardGamesPatienceBuildDown =>
      'Construisez en descendant par valeur, en alternant rouge et noir.';

  @override
  String get cardGamesPatienceNiceMove =>
      'Bien joué. Continuez à construire les fondations.';

  @override
  String get cardGamesPatienceWon => 'Vous avez gagné Patience !';

  @override
  String get cardGamesPatienceMoved => 'Carte déplacée vers une fondation.';

  @override
  String get cardGamesPatienceFoundationRule =>
      'Les fondations commencent par un as et se construisent par couleur.';

  @override
  String get cardGamesTableTitle => 'La table de cartes';

  @override
  String get cardGamesAllGames => 'Tous les jeux';

  @override
  String get cardGamesBackToTable => 'Retour à la table de cartes';

  @override
  String get cardGamesHeader => 'PETITS JEUX  /  JEUX DE CARTES';

  @override
  String get cardGamesNewGame => 'Nouvelle partie';

  @override
  String get cardGamesDealer => 'CROUPIER';

  @override
  String get cardGamesYouSeat => 'VOUS • PLACE 1';

  @override
  String get cardGamesPullUpChair => 'PRENEZ PLACE';

  @override
  String get cardGamesWhatToPlay => 'À quel jeu jouez-vous ?';

  @override
  String get cardGamesLobbyBlurb =>
      'Une table calme, un jeu neuf et une place réservée pour vous.';

  @override
  String get cardGamesPoker => 'Poker';

  @override
  String get cardGamesPokerBlurb =>
      'Gardez vos meilleures cartes. Battez le croupier.';

  @override
  String get cardGamesFiveCardDraw => 'Pioche à cinq cartes';

  @override
  String get cardGamesBlackjack => 'Blackjack';

  @override
  String get cardGamesBlackjackType => 'Atteindre 21';

  @override
  String get cardGamesBlackjackBlurb => 'Tirez ou restez contre le croupier.';

  @override
  String get cardGamesPatience => 'Patience';

  @override
  String get cardGamesSolitaire => 'Solitaire';

  @override
  String get cardGamesPatienceBlurb =>
      'Construisez les quatre fondations par couleur.';

  @override
  String get cardGamesDealerHand => 'MAIN DU CROUPIER';

  @override
  String get cardGamesYourHand => 'VOTRE MAIN';

  @override
  String cardGamesDealerTotal(int total) {
    return 'Croupier : $total';
  }

  @override
  String cardGamesDealerShowing(int total) {
    return 'Croupier : $total + ?';
  }

  @override
  String cardGamesYouTotal(int total) {
    return 'Vous : $total';
  }

  @override
  String get cardGamesHit => 'Carte';

  @override
  String get cardGamesStand => 'Rester';

  @override
  String get cardGamesDealAgain => 'Redistribuer';

  @override
  String get cardGamesBlackjackHint =>
      'Approchez-vous de 21 plus que le croupier sans le dépasser. Les as valent 1 ou 11.';

  @override
  String get cardGamesHold => 'GARDER';

  @override
  String get cardGamesDrawCards => 'Piocher des cartes';

  @override
  String get cardGamesPokerHint =>
      'Touchez les cartes pour les garder, puis piochez une fois. Le croupier pioche aussi une fois. La meilleure main de cinq cartes gagne.';

  @override
  String get cardGamesPatienceSection => 'PATIENCE • PIOCHER UNE';

  @override
  String get cardGamesStock => 'Pioche';

  @override
  String get cardGamesWaste => 'Défausse';

  @override
  String cardGamesFoundation(String number) {
    return 'F$number';
  }

  @override
  String get cardGamesPatienceHint =>
      'Descendez les cartes en alternant les couleurs. Les colonnes vides accueillent les rois. Construisez les fondations de l\'as au roi, par couleur.';

  @override
  String get smallGamesTitle => 'Petits jeux';

  @override
  String get smallGamesChooseGame => 'Choisissez un jeu à jouer.';

  @override
  String get smallGamesBingoName => 'BINGO';

  @override
  String get smallGamesBingoDescription =>
      'Tirez des numéros de la cage et créez des cartes imprimables.';

  @override
  String get smallGamesOpenBingo => 'Ouvrir BINGO';

  @override
  String get smallGamesCardGamesName => 'Jeux de cartes';

  @override
  String get smallGamesCardGamesDescription =>
      'Installez-vous à la table du casino pour le poker, le blackjack ou la patience.';

  @override
  String get smallGamesOpenCardGames => 'Ouvrir les jeux de cartes';

  @override
  String get smallGamesAllGames => 'Tous les jeux';

  @override
  String smallGamesCalledCount(int count) {
    return '$count / 75 appelés';
  }

  @override
  String get smallGamesEnterQuantity => 'Saisissez un nombre de 1 à 500.';

  @override
  String smallGamesSavedCards(int count, String path) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cartes enregistrées dans $path',
      one: '1 carte enregistrée dans $path',
    );
    return '$_temp0';
  }

  @override
  String smallGamesExportFailed(String error) {
    return 'Impossible d’exporter les cartes : $error';
  }

  @override
  String get smallGamesCageTitle => 'La cage de tirage';

  @override
  String get smallGamesCageSubtitle =>
      'Tirez une boule pour annoncer le numéro suivant.';

  @override
  String get smallGamesReady => 'PRÊT';

  @override
  String get smallGamesDrawNextBall => 'Tirer la boule suivante';

  @override
  String get smallGamesAllBallsDrawn => 'Toutes les boules ont été tirées';

  @override
  String get smallGamesNewGame => 'Nouvelle partie';

  @override
  String get smallGamesCalledNumbers => 'Numéros appelés';

  @override
  String get smallGamesCalledNumbersHint =>
      'Chaque boule appelée reste en surbrillance.';

  @override
  String get smallGamesRecentDraws => 'Tirages récents';

  @override
  String get smallGamesNoNumbersYet => 'Aucun numéro appelé pour l’instant.';

  @override
  String get smallGamesExportTitle => 'Exporter les cartes BINGO';

  @override
  String get smallGamesExportDescription =>
      'Créez un seul PDF imprimable avec des cartes 5×5 uniques, quatre par page en disposition 2×2. La dernière page peut en contenir moins. Chaque carte a une case centrale libre.';

  @override
  String get smallGamesNumberOfCards => 'Nombre de cartes';

  @override
  String get smallGamesExportPdf => 'Exporter en PDF';

  @override
  String get smartHomeRefreshLights => 'Actualiser les lampes';

  @override
  String get smartHomeSubtitle =>
      'Contrôlez vos lampes IKEA via votre hub DIRIGERA sur ce réseau.';

  @override
  String get smartHomeIkeaLamp => 'Lampe IKEA';

  @override
  String get smartHomeOffline => 'Hors ligne';

  @override
  String get smartHomeNoLampsFound => 'Aucune lampe IKEA trouvée';

  @override
  String get smartHomeAddLampHint =>
      'Ajoutez une lampe dans l’application IKEA Home, puis actualisez ici.';

  @override
  String smartHomeLampsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lampes',
      one: '1 lampe',
    );
    return '$_temp0';
  }

  @override
  String get smartHomeConnectHub => 'Connecter un hub DIRIGERA';

  @override
  String get smartHomeSameNetworkHint =>
      'Vérifiez que cet appareil et le hub sont sur le même réseau domestique.';

  @override
  String get smartHomeLookingForHubs => 'Recherche de hubs DIRIGERA…';

  @override
  String get smartHomeHubsFound => 'Hubs trouvés';

  @override
  String get smartHomeNoHubFound =>
      'Aucun hub trouvé. Vérifiez que DIRIGERA est allumé et que cet appareil est sur le même réseau domestique.';

  @override
  String get smartHomeFindMyHub => 'Rechercher mon hub';

  @override
  String get smartHomeHideManualAddress => 'Masquer l’adresse manuelle';

  @override
  String get smartHomeEnterIpManually => 'Saisir l’adresse IP manuellement';

  @override
  String get smartHomeHubIpAddress => 'Adresse IP du hub';

  @override
  String get smartHomeStartPairing => 'Démarrer l’appairage';

  @override
  String get smartHomePressHubButton =>
      'Appuyez sur le bouton d’action situé sous le hub DIRIGERA.';

  @override
  String get smartHomePressedButton => 'J’ai appuyé sur le bouton';

  @override
  String get smartHomePairingExpires => 'Si l’appairage expire, recommencez.';

  @override
  String get smartHomeStartAgain => 'Recommencer';

  @override
  String get smartHomeConnected => 'DIRIGERA connecté';

  @override
  String get smartHomeDisconnect => 'Déconnecter';

  @override
  String get smartHomePresetsTitle => 'Préréglages';

  @override
  String get smartHomeNewPreset => 'Nouveau préréglage';

  @override
  String get smartHomePresetsEmpty =>
      'Enregistrez un groupe de lampes avec leur propre luminosité et couleur, puis allumez-les ici d’une seule pression.';

  @override
  String get smartHomePresetsTapHint =>
      'Touchez un préréglage pour allumer ses lampes.';

  @override
  String smartHomeEditPreset(String name) {
    return 'Modifier $name';
  }

  @override
  String smartHomePresetApplied(String name) {
    return '« $name » appliqué.';
  }

  @override
  String get smartHomeNewPresetTitle => 'Nouveau préréglage';

  @override
  String get smartHomeEditPresetTitle => 'Modifier le préréglage';

  @override
  String get smartHomeDeletePresetTitle => 'Supprimer le préréglage ?';

  @override
  String smartHomeDeletePresetBody(String name) {
    return '« $name » sera supprimé. Vos lampes ne changeront pas.';
  }

  @override
  String get smartHomePresetNameLabel => 'Nom du préréglage';

  @override
  String get smartHomePresetNameHint => 'Soirée';

  @override
  String get smartHomeChooseLamps =>
      'Choisissez les lampes que ce préréglage allume.';

  @override
  String get smartHomeCouldNotSavePreset =>
      'Impossible d’enregistrer ce préréglage.';

  @override
  String get smartHomeCouldNotDeletePreset =>
      'Impossible de supprimer ce préréglage.';

  @override
  String get smartHomeSavingPreset => 'Enregistrement…';

  @override
  String get smartHomeSavePreset => 'Enregistrer le préréglage';

  @override
  String smartHomeBrightnessPercent(int percent) {
    return 'Luminosité $percent %';
  }

  @override
  String smartHomeColorIntensityPercent(int percent) {
    return 'Intensité de la couleur $percent %';
  }

  @override
  String smartHomeWhiteTemperatureKelvin(int kelvin) {
    return 'Température de blanc $kelvin K';
  }

  @override
  String get smartHomeNoColorSupport =>
      'Cette lampe ne prend pas en charge le changement de couleur.';

  @override
  String get smartHomeColorRed => 'Rouge';

  @override
  String get smartHomeColorOrange => 'Orange';

  @override
  String get smartHomeColorGreen => 'Vert';

  @override
  String get smartHomeColorBlue => 'Bleu';

  @override
  String get smartHomeColorPurple => 'Violet';

  @override
  String get smartHomeDefaultHubName => 'Hub DIRIGERA';

  @override
  String get smartHomeEnterHubAddress =>
      'Saisissez l’adresse IPv4 privée du hub, visible dans votre routeur.';

  @override
  String get smartHomeNoPairingChallenge =>
      'Le hub n’a pas renvoyé de demande d’appairage.';

  @override
  String get smartHomeNoAccessToken =>
      'Le hub n’a pas renvoyé de jeton d’accès.';

  @override
  String get smartHomeInvalidDeviceList => 'Liste d’appareils du hub invalide.';

  @override
  String get smartHomeHubAddressMustBePrivate =>
      'L’adresse du hub doit être une adresse IPv4 privée.';

  @override
  String get smartHomeInvalidPresetLamp =>
      'Réglages de lampe du préréglage invalides.';

  @override
  String get smartHomeLampFallbackName => 'lampe IKEA';

  @override
  String get smartHomePresetsLoadFailed =>
      'Impossible de charger les préréglages Smart Home enregistrés.';

  @override
  String get smartHomeHubConnectionReadFailed =>
      'Impossible de lire la connexion au hub enregistrée depuis le stockage sécurisé.';

  @override
  String get smartHomeDiscoverFailed =>
      'Impossible de rechercher un hub DIRIGERA sur le réseau local. Vérifiez l\'autorisation du réseau local, puis réessayez ou saisissez son adresse IP.';

  @override
  String get smartHomePresetNeedsNameAndLamp =>
      'Donnez un nom au préréglage et sélectionnez au moins une lampe.';

  @override
  String get smartHomePresetUnsupportedSettings =>
      'Une lampe sélectionnée a des réglages qu\'elle ne prend pas en charge. Actualisez les lampes et réessayez.';

  @override
  String smartHomePresetSaveFailed(String error) {
    return 'Impossible d\'enregistrer le préréglage. ($error)';
  }

  @override
  String smartHomePresetDeleteFailed(String error) {
    return 'Impossible de supprimer le préréglage. ($error)';
  }

  @override
  String get smartHomeInvalidSnapshot => 'Instantané Smart Home invalide.';

  @override
  String get smartHomeLampMissing => 'Lampe introuvable';

  @override
  String smartHomeLampSettingsChanged(String name) {
    return '$name (réglages modifiés)';
  }

  @override
  String get smartHomeStatusRefreshItem => 'actualisation de l\'état';

  @override
  String smartHomePresetPartialApply(String name, String lamps) {
    return 'Le préréglage \"$name\" n\'a pas pu être entièrement appliqué : $lamps.';
  }

  @override
  String get smartHomeHubNoResponse =>
      'Le hub DIRIGERA n\'a pas répondu. Vérifiez que cet appareil et le hub sont sur le même réseau domestique, puis recherchez de nouveau le hub. Le Wi-Fi invité ou un VPN peut empêcher la connexion.';

  @override
  String get smartHomeHubUnreachable =>
      'Impossible de joindre le hub DIRIGERA. Vérifiez sa connexion et réessayez.';

  @override
  String get spaceColonyLinuxSubtitle =>
      'Space Colony nécessite une WebView intégrée, pas encore prise en charge sur cette plateforme.';

  @override
  String get steamCs2CatalogUnreachable =>
      'Impossible de joindre le catalogue d\'objets. Vérifiez votre connexion et réessayez.';

  @override
  String steamCs2CatalogHttpError(int status) {
    return 'Le catalogue d\'objets a renvoyé une erreur (HTTP $status).';
  }

  @override
  String get steamCs2CatalogUnreadable =>
      'Le catalogue d\'objets a renvoyé des données illisibles.';

  @override
  String get steamCs2MarketUnreachable =>
      'Impossible de joindre le marché communautaire Steam. Vérifiez votre connexion et réessayez.';

  @override
  String get steamCs2MarketRateLimited =>
      'Le marché communautaire Steam limite les requêtes de cet appareil. Patientez quelques minutes et réessayez.';

  @override
  String steamCs2MarketHttpError(int status) {
    return 'Le marché communautaire Steam n\'a pas pu évaluer cet objet (HTTP $status).';
  }

  @override
  String get steamCs2MarketUnreadable =>
      'Le marché communautaire Steam a renvoyé une réponse illisible.';

  @override
  String steamCs2OfflineLoadFailed(String error) {
    return 'Impossible de charger l\'épargne de marché hors ligne : $error';
  }

  @override
  String steamCs2OfflineSaveFailed(String error) {
    return 'Impossible d\'enregistrer le réglage du marché hors ligne : $error';
  }

  @override
  String steamCs2OfflineSyncFailed(String error) {
    return 'Impossible de synchroniser l\'épargne de marché hors ligne : $error';
  }

  @override
  String steamCs2CatalogUpdateFailed(String error) {
    return 'Impossible de mettre à jour le catalogue d\'objets : $error';
  }

  @override
  String steamCs2CheckPriceFailed(String error) {
    return 'Impossible de vérifier ce prix : $error';
  }

  @override
  String get steamApiEnterIdOrUrl =>
      'Saisissez votre identifiant Steam ou l\'URL de votre profil.';

  @override
  String get steamApiNotSteamIdOrUrl =>
      'Cela ne ressemble pas à un identifiant Steam ni à l\'URL d\'un profil. Utilisez votre identifiant à 17 chiffres ou le lien complet de votre profil.';

  @override
  String steamApiUnknownProfile(String vanity) {
    return 'Steam ne connaît aucun profil nommé \"$vanity\". Vérifiez le nom ou collez plutôt votre identifiant Steam à 17 chiffres.';
  }

  @override
  String get steamApiNoGames =>
      'Steam n\'a renvoyé aucun jeu. Ouvrez vos paramètres de confidentialité Steam, réglez « Détails des jeux » sur Public, puis réessayez.';

  @override
  String get steamApiRejectedKey =>
      'Steam a rejeté la clé API. Vérifiez-la dans Connexion, ou générez-en une nouvelle sur steamcommunity.com/dev/apikey.';

  @override
  String get steamApiRateLimited =>
      'Steam limite les requêtes de cet appareil. Patientez quelques minutes et réessayez.';

  @override
  String steamApiUnreachable(String task) {
    String _temp0 = intl.Intl.selectLogic(task, {
      'resolveProfile': 'trouver ce nom de profil',
      'readLibrary': 'lire votre bibliothèque',
      'readStorePage': 'lire cette page du magasin',
      'searchStore': 'rechercher dans la boutique',
      'other': 'faire cela',
    });
    return 'Impossible de joindre Steam pour $_temp0. Vérifiez votre connexion et réessayez.';
  }

  @override
  String steamApiHttpError(String task, int status) {
    String _temp0 = intl.Intl.selectLogic(task, {
      'resolveProfile': 'trouver ce nom de profil',
      'readLibrary': 'lire votre bibliothèque',
      'readStorePage': 'lire cette page du magasin',
      'searchStore': 'rechercher dans la boutique',
      'other': 'faire cela',
    });
    return 'Steam n\'a pas pu $_temp0 (HTTP $status).';
  }

  @override
  String steamApiUnreadable(String task) {
    String _temp0 = intl.Intl.selectLogic(task, {
      'resolveProfile': 'trouver ce nom de profil',
      'readLibrary': 'lire votre bibliothèque',
      'readStorePage': 'lire cette page du magasin',
      'searchStore': 'rechercher dans la boutique',
      'other': 'faire cela',
    });
    return 'Steam a renvoyé une réponse illisible pour $_temp0.';
  }

  @override
  String get itadApiUnexpectedHistory =>
      'IsThereAnyDeal a renvoyé un historique de prix inattendu.';

  @override
  String get itadApiNotConfigured =>
      'L\'opérateur du serveur n\'a pas configuré l\'historique des prix. Demandez-lui d\'ajouter une clé IsThereAnyDeal.';

  @override
  String get itadApiNeedsAccount =>
      'Cela nécessite un compte luma connecté. Connectez-vous sous Paramètres → Synchronisation et compte.';

  @override
  String get itadApiRateLimited =>
      'Trop de requêtes d\'historique des prix en ce moment. Patientez un peu et réessayez.';

  @override
  String itadApiUnreachable(String task) {
    String _temp0 = intl.Intl.selectLogic(task, {
      'lookupGame': 'rechercher ce jeu',
      'priceHistory': 'lire cet historique des prix',
      'readGame': 'lire ce jeu',
      'other': 'faire cela',
    });
    return 'Impossible de joindre le serveur luma pour $_temp0. Vérifiez votre connexion et réessayez.';
  }

  @override
  String itadApiHttpError(String task, int status) {
    String _temp0 = intl.Intl.selectLogic(task, {
      'lookupGame': 'rechercher ce jeu',
      'priceHistory': 'lire cet historique des prix',
      'readGame': 'lire ce jeu',
      'other': 'faire cela',
    });
    return 'Impossible de $_temp0 (HTTP $status).';
  }

  @override
  String get steamLibraryNeverPlayed => 'Jamais joué';

  @override
  String steamLibraryMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String steamLibraryHours(String hours) {
    return '$hours h';
  }

  @override
  String get steamRangeFiveYears => 'les cinq dernières années';

  @override
  String get steamRangeYear => 'la dernière année';

  @override
  String get steamRangeSixMonths => 'les six derniers mois';

  @override
  String get steamRangeMonth => 'le dernier mois';

  @override
  String get steamRangeWeek => 'la dernière semaine';

  @override
  String get steamRangeDay => 'le dernier jour';

  @override
  String get steamRepoEnterApiKey => 'Saisissez votre clé API Steam Web.';

  @override
  String steamRepoConnectFailed(String error) {
    return 'Impossible de se connecter à Steam : $error';
  }

  @override
  String steamRepoRefreshFailed(String error) {
    return 'Impossible d\'actualiser votre bibliothèque : $error';
  }

  @override
  String get cs2CalcTitle => 'Calculateur de vente CS2';

  @override
  String get cs2CalcSubtitle =>
      'Voyez le montant estimé reçu sur votre portefeuille Steam après les frais du marché.';

  @override
  String get cs2CalcBuyerPays => 'Prix payé par l\'acheteur';

  @override
  String get cs2CalcCurrency => 'Devise';

  @override
  String get cs2CalcYouReceive => 'Vous recevez';

  @override
  String get cs2CalcSteamFee => 'Frais Steam (5 %)';

  @override
  String get cs2CalcGameFee => 'Frais CS2 (10 %)';

  @override
  String get cs2CalcDisclaimer =>
      'Estimation uniquement. Les frais sont calculés séparément, arrondis au centime inférieur, avec un minimum d\'un centime chacun. Steam peut traiter d\'autres devises différemment.';

  @override
  String get cs2MarketOfflineTitle => 'Continuer l\'enregistrement hors ligne';

  @override
  String get cs2MarketOfflineSignIn =>
      'Connectez-vous à un compte Orbit ou Nova approuvé pour activer cette option.';

  @override
  String get cs2MarketOfflineLoading =>
      'Chargement du suivi de marché partagé…';

  @override
  String get cs2MarketOfflineSaving =>
      'Enregistrement de vos annonces suivies…';

  @override
  String cs2MarketOfflineIntervalOff(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other:
          'Le serveur vérifie les skins suivis toutes les $hours heures une fois activé.',
      one: 'Le serveur vérifie les skins suivis chaque heure une fois activé.',
    );
    return '$_temp0';
  }

  @override
  String get cs2MarketOfflineScheduled =>
      'Les vérifications programmées du serveur sont activées.';

  @override
  String cs2MarketOfflineNextCheck(int hours, String time) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'toutes les $hours heures',
      one: 'chaque heure',
    );
    return 'Le serveur vérifie $_temp0 · prochaine à $time';
  }

  @override
  String get cs2MarketSubtitleLoading => 'Chargement du catalogue d\'objets…';

  @override
  String get cs2MarketSubtitleNotLoaded =>
      'Catalogue d\'objets pas encore chargé.';

  @override
  String cs2MarketSubtitleCatalogued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count objets catalogués.',
      one: '1 objet catalogué.',
    );
    return '$_temp0';
  }

  @override
  String cs2MarketSubtitleUpdatedDays(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count objets catalogués, mis à jour il y a $days j.',
      one: '1 objet catalogué, mis à jour il y a $days j.',
    );
    return '$_temp0';
  }

  @override
  String cs2MarketSubtitleUpdatedHours(int count, int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count objets catalogués, mis à jour il y a $hours h.',
      one: '1 objet catalogué, mis à jour il y a $hours h.',
    );
    return '$_temp0';
  }

  @override
  String cs2MarketSubtitleUpdatedJustNow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count objets catalogués, mis à jour à l\'instant.',
      one: '1 objet catalogué, mis à jour à l\'instant.',
    );
    return '$_temp0';
  }

  @override
  String get cs2MarketTrackedSettings => 'Paramètres du suivi';

  @override
  String get cs2MarketCountAsInvestments =>
      'Compter la valeur CS2 comme investissements';

  @override
  String get cs2MarketCountAsInvestmentsHint =>
      'Inclure les valeurs des armes suivies dans Finances et le tableau de bord.';

  @override
  String get cs2MarketRefreshCatalog => 'Actualiser le catalogue';

  @override
  String get cs2MarketUpdating => 'Mise à jour…';

  @override
  String get cs2MarketRefreshPrices => 'Actualiser les prix';

  @override
  String get cs2MarketChecking => 'Vérification…';

  @override
  String get cs2MarketBrowse => 'Parcourir';

  @override
  String get cs2MarketTracked => 'Suivis';

  @override
  String get cs2MarketSearchTracked =>
      'Rechercher parmi vos suivis : nom, arme, rareté';

  @override
  String get cs2MarketSearchAny =>
      'Rechercher un objet CS2 : nom, arme, rareté, caisse';

  @override
  String cs2MarketCheckingProgress(int done, int total) {
    return 'Vérification des prix — $done sur $total';
  }

  @override
  String get cs2MarketDismiss => 'Ignorer';

  @override
  String get cs2MarketCatalogEmpty => 'Le catalogue est vide';

  @override
  String get cs2MarketCatalogEmptyHint =>
      'Actualisez le catalogue pour charger tous les objets CS2.';

  @override
  String get cs2MarketKeepTyping => 'Continuez de taper';

  @override
  String get cs2MarketKeepTypingHint =>
      'Une seule lettre correspond à trop d\'objets pour être utile — quelques lettres de plus suffiront.';

  @override
  String cs2MarketNoMatch(String query) {
    return 'Aucun objet ne correspond à « $query »';
  }

  @override
  String get cs2MarketNoMatchHint =>
      'Essayez un nom d\'arme, une rareté comme « Covert », ou un nom de caisse.';

  @override
  String cs2MarketTileLabelCase(String name, String rarity, String caseName) {
    return '$name, $rarity. De la caisse $caseName';
  }

  @override
  String cs2MarketTileLabelNoCase(String name, String rarity) {
    return '$name, $rarity. Aucune caisse';
  }

  @override
  String cs2MarketTileLabelCasePinned(
    String name,
    String rarity,
    String caseName,
  ) {
    return '$name, $rarity. De la caisse $caseName. Épinglé';
  }

  @override
  String cs2MarketTileLabelNoCasePinned(String name, String rarity) {
    return '$name, $rarity. Aucune caisse. Épinglé';
  }

  @override
  String get cs2MarketNoCase => 'Aucune caisse';

  @override
  String get cs2MarketPinToTop => 'Épingler en haut';

  @override
  String get cs2MarketUnpin => 'Désépingler';

  @override
  String get cs2TrackListing => 'Suivre cette annonce';

  @override
  String get cs2TrackAnotherCopy => 'Suivre un autre exemplaire';

  @override
  String get cs2ItemSubtitleAnotherCopy =>
      'Le prix à partir duquel mesurer les gains et pertes de cet exemplaire.';

  @override
  String get cs2ItemSubtitleNewListing =>
      'Choisissez l\'état et le prix à partir duquel mesurer les gains et pertes.';

  @override
  String get cs2ItemSetStartingPrice => 'Définir le prix de départ';

  @override
  String get cs2ItemEditStartingPrice => 'Modifier le prix de départ';

  @override
  String get cs2ItemStartingPriceSubtitle =>
      'Le prix à partir duquel sont mesurés les gains et pertes de cet exemplaire.';

  @override
  String get cs2ItemNotFound => 'Objet introuvable';

  @override
  String get cs2ItemNotFoundHint =>
      'Il a peut-être disparu lors de la dernière mise à jour du catalogue — essayez d\'actualiser le catalogue.';

  @override
  String get cs2ItemBackToMarket => 'Retour au marché';

  @override
  String get cs2ItemWear => 'Usure';

  @override
  String get cs2ItemVariant => 'Variante';

  @override
  String get cs2ItemNormal => 'Normal';

  @override
  String get cs2ItemLowestListed => 'Offre la plus basse';

  @override
  String get cs2ItemCouldNotCheck => 'Impossible de vérifier le prix';

  @override
  String get cs2ItemNotCheckedYet => 'Pas encore vérifié';

  @override
  String cs2ItemMedian(String price) {
    return 'Médiane $price';
  }

  @override
  String get cs2ItemCheckNow => 'Vérifier maintenant';

  @override
  String get cs2ItemQuickCheckNotSaved =>
      'Une vérification rapide, non enregistrée — suivez cette annonce pour conserver l\'historique de son prix.';

  @override
  String get cs2ItemStatusNotChecked => 'Pas encore vérifié.';

  @override
  String get cs2ItemCheckedJustNow => 'Vérifié à l\'instant.';

  @override
  String cs2ItemCheckedMinutes(int minutes) {
    return 'Vérifié il y a $minutes min.';
  }

  @override
  String cs2ItemCheckedHours(int hours) {
    return 'Vérifié il y a $hours h.';
  }

  @override
  String cs2ItemCheckedOn(String date) {
    return 'Vérifié le $date.';
  }

  @override
  String cs2ItemTrackedOn(String date) {
    return 'Suivi depuis le $date';
  }

  @override
  String cs2ItemYourCopies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vos exemplaires ($count)',
      one: 'Votre exemplaire',
    );
    return '$_temp0';
  }

  @override
  String get cs2ItemNoStartingPrice => 'Aucun prix de départ défini';

  @override
  String get cs2ItemSetPrice => 'Définir le prix';

  @override
  String get cs2ItemClearPrice => 'Effacer le prix';

  @override
  String get cs2ItemStopTrackingCopy => 'Arrêter le suivi de cet exemplaire';

  @override
  String get cs2ItemFactWeapon => 'Arme';

  @override
  String get cs2ItemFactRarity => 'Rareté';

  @override
  String get cs2ItemFactCase => 'Caisse';

  @override
  String get cs2ItemFactNoCase =>
      'Aucune caisse — objet de collection ou promotionnel';

  @override
  String get cs2ItemFactAvailable => 'Disponible pour cette finition';

  @override
  String get cs2ItemFactSouvenir => 'Souvenir';

  @override
  String get cs2ItemOpenOnMarket => 'Ouvrir sur le marché Steam';

  @override
  String get cs2ChartPriceHistory => 'Historique des prix';

  @override
  String get cs2ChartGainLoss => 'Gains et pertes';

  @override
  String get cs2ChartNoReadings => 'Aucune mesure de prix disponible.';

  @override
  String cs2ChartGainLossUnchanged(String delta) {
    return 'Inchangé à $delta par rapport au prix de départ sur les mesures affichées.';
  }

  @override
  String cs2ChartGainLossBetween(String low, String high) {
    return 'Entre $low et $high par rapport au prix de départ sur les mesures affichées.';
  }

  @override
  String get cs2ChartOneReading =>
      'Une seule mesure pour l\'instant — une tendance en exige au moins deux.';

  @override
  String cs2ChartUnchangedAcrossCount(String delta, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mesures',
      one: '1 mesure',
    );
    return 'Inchangé à $delta sur $_temp0.';
  }

  @override
  String cs2ChartBetweenShown(String low, String high) {
    return 'Entre $low et $high sur les mesures affichées.';
  }

  @override
  String cs2ChartUnchangedShown(String price) {
    return 'Inchangé à $price sur les mesures affichées.';
  }

  @override
  String get cs2ChartBest => 'Meilleur';

  @override
  String get cs2ChartWorst => 'Pire';

  @override
  String get cs2ChartLowest => 'Plus bas';

  @override
  String get cs2ChartHighest => 'Plus haut';

  @override
  String get cs2ChartNoHistory => 'Pas encore d\'historique';

  @override
  String get cs2ChartNoHistoryHint =>
      'Le marché Steam ne publie aucun historique — suivez cette annonce et luma commencera à en créer un à partir de maintenant.';

  @override
  String get cs2ChartNoReadingsInRange => 'Aucune mesure sur cette période';

  @override
  String get cs2ChartTryWiderRange =>
      'Essayez une période plus large, ou vérifiez à nouveau le prix.';

  @override
  String get steamFreeToPlay => 'Gratuit';

  @override
  String get steamFreeToPlaySemantics => 'Gratuit.';

  @override
  String get steamPriceNotChecked => 'Pas encore vérifié';

  @override
  String get steamPriceNotCheckedSemantics => 'Prix pas encore vérifié.';

  @override
  String get steamPriceChecking => 'Vérification…';

  @override
  String steamPriceCosts(String price) {
    return 'Coûte $price.';
  }

  @override
  String get steamTrackAGame => 'Suivre un jeu';

  @override
  String get steamDismiss => 'Ignorer';

  @override
  String get steamAccountSettingsTooltip => 'Paramètres du compte Steam';

  @override
  String get cs2StartPriceEnterValid => 'Saisissez un prix valide.';

  @override
  String get cs2StartPriceGrade => 'Niveau d\'usure';

  @override
  String get cs2StartPriceGradeHelper =>
      'L\'usure et le prix sont définis ensemble — ils ne peuvent plus être modifiés séparément une fois le suivi commencé.';

  @override
  String get cs2StartPriceGradeFixedHelper =>
      'Fixe — cette référence correspond à cette annonce exacte.';

  @override
  String get cs2StartPriceStartingPrice => 'Prix de départ';

  @override
  String get cs2StartPriceStartingPriceHelper =>
      'Ce que vous avez payé, ou le prix de référence pour calculer gains et pertes — non récupéré depuis Steam.';

  @override
  String get cs2TrackedEmptyTitle => 'Rien de suivi pour l\'instant';

  @override
  String get cs2TrackedEmptySubtitle =>
      'Suivez une annonce depuis Parcourir pour surveiller son prix : elle apparaîtra ici avec le reste.';

  @override
  String cs2TrackedNoMatchTitle(String query) {
    return 'Aucun élément suivi ne correspond à « $query »';
  }

  @override
  String get cs2TrackedNoMatchSubtitle =>
      'Essayez un autre nom d\'arme ou une autre rareté.';

  @override
  String get cs2TrackedTotalValue => 'Valeur totale';

  @override
  String cs2TrackedCopiesTracked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count exemplaires suivis',
      one: '1 exemplaire suivi',
    );
    return '$_temp0';
  }

  @override
  String cs2TrackedGainLossCoverage(int withStart, int total) {
    return 'Gains/pertes concernent les $withStart sur $total ayant un prix de départ.';
  }

  @override
  String get cs2NoWearVariants => 'Aucune variante d\'usure';

  @override
  String get cs2RangeAll => 'Tout';

  @override
  String get steamAccountTitle => 'Compte Steam';

  @override
  String get steamAccountSubtitle =>
      'Pour que luma puisse afficher les jeux que vous possédez.';

  @override
  String get steamAccountConnected => 'Connecté';

  @override
  String steamAccountConnectedWithKey(String maskedKey) {
    return 'Connecté — $maskedKey';
  }

  @override
  String get steamAccountApiKeyLabel => 'Clé d\'API Web Steam';

  @override
  String get steamAccountKeyHelperConnected =>
      'Laissez vide pour conserver la clé enregistrée.';

  @override
  String get steamAccountKeyHelperNew =>
      'Gratuite, et liée à votre propre compte.';

  @override
  String get steamAccountKeyHintReplace =>
      'Saisissez une nouvelle clé pour la remplacer';

  @override
  String get steamAccountHideKey => 'Masquer la clé';

  @override
  String get steamAccountShowKey => 'Afficher la clé';

  @override
  String get steamAccountGetKey => 'Obtenir une clé auprès de Steam';

  @override
  String get steamAccountIdLabel => 'ID Steam ou URL du profil';

  @override
  String get steamAccountIdHelper =>
      'Votre identifiant à 17 chiffres, ou un lien comme steamcommunity.com/id/votrenom.';

  @override
  String get steamAccountErrorNoKey => 'Collez votre clé d\'API Web Steam.';

  @override
  String get steamAccountErrorNoId =>
      'Saisissez votre ID Steam ou l\'URL de votre profil.';

  @override
  String get steamAccountConnect => 'Connecter';

  @override
  String get steamAccountDisconnect => 'Déconnecter';

  @override
  String get steamAccountEncryptedNote =>
      'Votre clé est stockée chiffrée sur cet appareil et envoyée uniquement à Steam, jamais à un serveur luma.';

  @override
  String get steamAccountPrivacyNote =>
      'Steam ne renvoie votre bibliothèque que si « Détails des jeux » est réglé sur Public dans vos paramètres de confidentialité.';

  @override
  String get steamAccountHistoryNote =>
      'L\'historique des prix nécessite aussi un compte luma connecté — il est récupéré via le serveur, donc aucune clé séparée n\'est nécessaire.';

  @override
  String get steamDetailNoLongerInLibraryTitle =>
      'Ce jeu ne figure plus dans votre bibliothèque';

  @override
  String get steamDetailNoLongerInLibrarySubtitle =>
      'Actualisez votre bibliothèque pour voir ce qui a changé.';

  @override
  String get steamDetailBackTooltip => 'Retour à votre bibliothèque';

  @override
  String get steamDetailPriceNow => 'Prix actuel';

  @override
  String get steamDetailCheckNow => 'Vérifier maintenant';

  @override
  String steamDetailWasPrice(String price) {
    return 'était $price';
  }

  @override
  String get steamDetailNeverPriced =>
      'Ce jeu n\'a pas encore de prix vérifié.';

  @override
  String get steamDetailCheckedJustNow => 'Vérifié à l\'instant.';

  @override
  String steamDetailCheckedMinutes(int count) {
    return 'Vérifié il y a $count min.';
  }

  @override
  String steamDetailCheckedHours(int count) {
    return 'Vérifié il y a $count h.';
  }

  @override
  String steamDetailCheckedOn(String date) {
    return 'Vérifié le $date.';
  }

  @override
  String get steamDetailAboutTitle => 'À propos de ce jeu';

  @override
  String get steamDetailTags => 'Étiquettes';

  @override
  String get steamDetailRequirementsTitle => 'Configuration requise';

  @override
  String get steamDetailReadingStore => 'Lecture de la page du magasin…';

  @override
  String get steamDetailNoPcRequirements =>
      'Steam n\'indique aucune configuration requise PC pour ce jeu.';

  @override
  String get steamDetailReqMinimum => 'Minimale';

  @override
  String get steamDetailReqRecommended => 'Recommandée';

  @override
  String get steamDetailDeveloper => 'Développeur';

  @override
  String get steamDetailPublisher => 'Éditeur';

  @override
  String get steamDetailReleased => 'Sortie';

  @override
  String get steamDetailPlatforms => 'Plateformes';

  @override
  String get steamDetailYourPlaytime => 'Votre temps de jeu';

  @override
  String get steamDetailPlaytimeNever => 'Jamais joué';

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
    return '$hours heures';
  }

  @override
  String steamDetailPlaytimeHoursWhole(int count) {
    return '$count heures';
  }

  @override
  String get steamDetailOpenOnSteam => 'Ouvrir sur Steam';

  @override
  String get steamDetailStopTracking => 'Arrêter le suivi';

  @override
  String steamDetailStopTrackingTitle(String name) {
    return 'Arrêter de suivre $name ?';
  }

  @override
  String get steamDetailStopTrackingOwned =>
      'Cela le retire de vos jeux suivis et supprime son historique de prix sur cet appareil. Il figure toujours dans votre bibliothèque Steam, donc l\'actualiser plus tard le rajoutera.';

  @override
  String get steamDetailStopTrackingUnowned =>
      'Cela le retire de vos jeux suivis et supprime son historique de prix sur cet appareil.';

  @override
  String get steamChartTitle => 'Historique des prix';

  @override
  String get steamChartNoHistory => 'Aucun historique de prix disponible.';

  @override
  String get steamChartRangeFiveYears => 'les cinq dernières années';

  @override
  String get steamChartRangeYear => 'la dernière année';

  @override
  String get steamChartRangeSixMonths => 'les six derniers mois';

  @override
  String get steamChartRangeMonth => 'le dernier mois';

  @override
  String get steamChartRangeWeek => 'la dernière semaine';

  @override
  String get steamChartRangeDay => 'le dernier jour';

  @override
  String steamChartSummaryFlat(String range, String price) {
    return 'Historique des prix sur $range : inchangé à $price.';
  }

  @override
  String steamChartSummaryRange(String range, String low, String high) {
    return 'Historique des prix sur $range : entre $low et $high.';
  }

  @override
  String steamChartUnchangedAcross(String price, String range) {
    return 'Inchangé à $price sur $range.';
  }

  @override
  String get steamChartLowestInRange => 'Plus bas sur la période';

  @override
  String get steamChartHighestInRange => 'Plus haut sur la période';

  @override
  String get steamChartAllTimeLow => 'Plus bas historique';

  @override
  String steamChartAllTimeLowSince(String date) {
    return 'Plus bas historique ($date)';
  }

  @override
  String get steamChartFromIsThereAnyDeal =>
      'Historique des prix Steam via IsThereAnyDeal.';

  @override
  String steamChartFromIsThereAnyDealFull(String range) {
    return 'Historique des prix Steam via IsThereAnyDeal, couvrant toute la période $range.';
  }

  @override
  String steamChartShortHistory(String date, String range) {
    return 'IsThereAnyDeal a ce jeu depuis le $date, soit moins que $range.';
  }

  @override
  String get steamChartSignInTitle =>
      'Connectez-vous pour l\'historique des prix';

  @override
  String get steamChartSignInBody =>
      'Steam ne publie que le prix actuel d\'un jeu. Un compte luma connecté récupère les années précédentes, sans clé supplémentaire à trouver ou à saisir.';

  @override
  String steamChartNoHistoryOver(String range) {
    return 'Aucun historique des prix sur $range';
  }

  @override
  String get steamChartNothingOnFile =>
      'IsThereAnyDeal n\'a rien en dossier pour ce jeu.';

  @override
  String get steamSearchSubtitle =>
      'Recherchez dans la boutique Steam — aucun compte requis.';

  @override
  String get steamSearchHint => 'Rechercher un jeu';

  @override
  String get steamSearchStartHint =>
      'Recherchez le nom d\'un jeu pour commencer à suivre son prix.';

  @override
  String steamSearchCouldNot(String error) {
    return 'Impossible de rechercher sur Steam : $error';
  }

  @override
  String steamSearchNoMatch(String query) {
    return 'Aucun jeu ne correspond à « $query ».';
  }

  @override
  String steamSearchAlreadyTracked(String name) {
    return '$name, déjà suivi';
  }

  @override
  String steamSearchTapToTrack(String name) {
    return '$name, appuyez pour suivre';
  }

  @override
  String get steamTrackerSortPlaytime => 'Temps de jeu';

  @override
  String get steamTrackerTitle => 'Suivi des prix';

  @override
  String get steamTrackerSubtitleDisconnected =>
      'Suivi des prix — connectez un compte Steam pour ajouter aussi votre bibliothèque en bloc.';

  @override
  String get steamTrackerSubtitleNoSync =>
      'Connecté. Actualisez la bibliothèque pour l\'importer.';

  @override
  String get steamTrackerSyncedJustNow =>
      'Bibliothèque synchronisée à l\'instant.';

  @override
  String steamTrackerSyncedMinutes(int count) {
    return 'Bibliothèque synchronisée il y a $count min.';
  }

  @override
  String steamTrackerSyncedHours(int count) {
    return 'Bibliothèque synchronisée il y a $count h.';
  }

  @override
  String steamTrackerSyncedDays(int count) {
    return 'Bibliothèque synchronisée il y a $count j.';
  }

  @override
  String get steamTrackerRefreshLibrary => 'Actualiser la bibliothèque';

  @override
  String get steamTrackerRefreshPrices => 'Actualiser les prix';

  @override
  String get steamTrackerSearchHint => 'Rechercher les jeux suivis';

  @override
  String steamTrackerCheckingPrices(int done, int total) {
    return 'Vérification des prix — $done sur $total';
  }

  @override
  String get steamTrackerEmptyTitle => 'Suivez votre premier jeu';

  @override
  String get steamTrackerEmptySubtitle =>
      'Recherchez un jeu pour surveiller son prix — aucun compte Steam requis.';

  @override
  String steamTrackerNoMatchTitle(String query) {
    return 'Aucun jeu ne correspond à « $query »';
  }

  @override
  String get steamTrackerNoMatchSubtitle =>
      'Essayez une recherche plus courte.';

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
  String get steamTrackerUnplayed => 'Non joué';

  @override
  String get subwayBuilderNotOnLinuxTitle => 'Non disponible sous Linux';

  @override
  String get subwayBuilderNotOnLinuxSubtitle =>
      'Subway Builder nécessite une WebView intégrée, qui n\'est pas encore prise en charge sur cette plateforme.';

  @override
  String get textLibraryClassroomSignIn =>
      'Connectez-vous à un compte luma approuvé pour utiliser la salle de classe.';

  @override
  String get textLibraryClassroomOffline =>
      'Impossible de joindre le serveur luma. Vérifiez votre connexion et réessayez.';

  @override
  String textLibraryClassroomFailed(int status) {
    return 'La salle de classe a échoué (HTTP $status).';
  }

  @override
  String get textLibraryClassroomMalformed =>
      'Le serveur a envoyé une réponse mal formée.';

  @override
  String get textLibraryClassroomUnknownRequest =>
      'Requête de salle de classe inconnue.';

  @override
  String get textLibraryDefaultSubjectName => 'Matière';

  @override
  String transportTrackerConnectionError(String error) {
    return 'Erreur de connexion : $error';
  }

  @override
  String transportTrackerCouldNotConnect(String error) {
    return 'Connexion impossible : $error';
  }

  @override
  String transitArchivePartialUnsupported(int code) {
    return 'L\'archive des transports ne prend pas en charge les téléchargements partiels (HTTP $code).';
  }

  @override
  String get transitArchiveSizeUnknown =>
      'Impossible de déterminer la taille de l\'archive.';

  @override
  String get transitArchiveIndexUnreadable =>
      'L\'index de l\'archive est illisible.';

  @override
  String get transitArchiveIndexUnreadableZip64 =>
      'L\'index de l\'archive est illisible (zip64).';

  @override
  String transitArchiveMemberMissing(String name) {
    return '$name n\'est pas dans l\'archive.';
  }

  @override
  String get transitRoutesEmpty => 'La liste des lignes est vide.';

  @override
  String get transitStopsEmpty => 'La liste des arrêts est vide.';

  @override
  String get transitStopsMissingColumns =>
      'La liste des arrêts ne contient pas les colonnes attendues.';

  @override
  String transitFeedRateLimited(int minutes) {
    return 'Le flux de transport limite les requêtes de cet appareil. Pause de $minutes min.';
  }

  @override
  String transitFeedHttpError(int code) {
    return 'Le flux de transport a renvoyé HTTP $code.';
  }

  @override
  String transitFeedLoadFailed(String error) {
    return 'Impossible de charger le flux de transport : $error';
  }

  @override
  String get transitModeHighSpeed => 'Grande vitesse';

  @override
  String get transitModeTrain => 'Train';

  @override
  String get transitModeMetro => 'Métro';

  @override
  String get transitModeTram => 'Tram';

  @override
  String get transitModeBus => 'Bus';

  @override
  String get transitModeFerry => 'Ferry';

  @override
  String get transportPrefsInvalidSnapshot =>
      'Instantané du suivi des transports invalide.';

  @override
  String get transportTrackerLinuxSubtitle =>
      'Transport Tracker nécessite une WebView intégrée, qui n\'est pas encore prise en charge sur cette plateforme.';

  @override
  String get transportTrackerLive => 'En direct';

  @override
  String get transportTrackerConnecting => 'Connexion…';

  @override
  String get transportTrackerStopped => 'Arrêté';

  @override
  String get transportTrackerIdle => 'Inactif';

  @override
  String get transportTrackerStopFeedTooltip => 'Arrêter le flux AIS en direct';

  @override
  String get transportTrackerStartFeedTooltip =>
      'Démarrer un flux AIS en direct pour la zone affichée';

  @override
  String get transportTrackerWaitingForMapTooltip =>
      'En attente du chargement de la carte';

  @override
  String get transportTrackerStopTracking => 'Arrêter le suivi';

  @override
  String get transportTrackerTrackView => 'Suivre cette vue';

  @override
  String get transportTrackerChooseLayersTooltip =>
      'Choisir ce qu\'il faut suivre';

  @override
  String get transportTrackerApiKeySettingsTooltip =>
      'Paramètres de la clé API AISStream.io';

  @override
  String transportTrackerVesselsCount(int count) {
    return 'Navires ($count)';
  }

  @override
  String transportTrackerVesselsAndTransitCount(int vessels, int transit) {
    return 'Navires ($vessels) · Transports ($transit)';
  }

  @override
  String get transportTrackerAddKeyToSeeShips =>
      'Ajoutez une clé API AISStream.io gratuite pour voir les navires en direct.';

  @override
  String get transportTrackerConnectedWaiting =>
      'Connecté — en attente de positions. Les routes maritimes fréquentées se remplissent en quelques secondes ; le large peut prendre plus de temps.';

  @override
  String transportTrackerNoVesselsYet(String label) {
    return 'Aucun navire pour l\'instant. Appuyez sur « $label » pour démarrer le flux en direct de la zone affichée.';
  }

  @override
  String get transportTrackerNoAisYet =>
      'Aucun message AIS reçu pour l\'instant. Si ce nombre reste à zéro, la clé est peut-être refusée ou cette zone n\'a pas de trafic signalé.';

  @override
  String transportTrackerAisMessagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages AIS reçus.',
      one: '1 message AIS reçu.',
    );
    return '$_temp0';
  }

  @override
  String transportTrackerMapLoadFailed(String error) {
    return 'La carte n\'a pas pu se charger complètement : vérifiez la connexion internet de cet appareil. ($error)';
  }

  @override
  String get transportTrackerAddKeyPrompt => 'Ajoutez votre clé API gratuite';

  @override
  String transportTrackerKnots(String value) {
    return '$value nœuds';
  }

  @override
  String get transportTrackerBackToVessels => 'Retour à la liste des navires';

  @override
  String get transportTrackerCallSign => 'Indicatif d\'appel';

  @override
  String get transportTrackerSpeed => 'Vitesse';

  @override
  String get transportTrackerCourse => 'Cap';

  @override
  String get transportTrackerHeading => 'Cap réel';

  @override
  String get transportTrackerDestination => 'Destination';

  @override
  String get transportTrackerDraught => 'Tirant d\'eau';

  @override
  String get transportTrackerPosition => 'Position';

  @override
  String get transportTrackerLastReport => 'Dernier signal';

  @override
  String transportTrackerMetres(String value) {
    return '$value m';
  }

  @override
  String transportTrackerKmh(String value) {
    return '$value km/h';
  }

  @override
  String get transportTrackerBackToList => 'Retour à la liste';

  @override
  String get transportTrackerLine => 'Ligne';

  @override
  String get transportTrackerMode => 'Mode';

  @override
  String get transportTrackerVehicleNumber => 'Numéro du véhicule';

  @override
  String get transportTrackerOperator => 'Exploitant';

  @override
  String get transportTrackerLastUpdate => 'Dernière mise à jour';

  @override
  String get transportTrackerInterpolatedNote =>
      'Estimé à partir de l\'horaire : les trains ne diffusent pas leur position dans les données ouvertes, elle est donc interpolée entre les gares.';

  @override
  String get transportTrackerDownloadingStops =>
      'Téléchargement des noms d\'arrêts (environ 1,4 Mo, une seule fois)…';

  @override
  String transportTrackerStopNamesUnavailable(String error) {
    return 'Noms d\'arrêts indisponibles : $error';
  }

  @override
  String get transportTrackerNoPredictions =>
      'Aucune prévision d\'arrêt n\'est publiée pour ce trajet.';

  @override
  String get transportTrackerNoRemainingStops =>
      'Ce trajet n\'a plus d\'arrêts.';

  @override
  String get transportTrackerNextStops => 'PROCHAINS ARRÊTS';

  @override
  String get transportTrackerUnknownStop => 'Arrêt inconnu';

  @override
  String transportTrackerCountdownSeconds(int count) {
    return '$count s';
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
    return 'il y a $count s';
  }

  @override
  String transportTrackerMinutesAgo(int count) {
    return 'il y a $count min';
  }

  @override
  String transportTrackerHoursAgo(int count) {
    return 'il y a $count h';
  }

  @override
  String get transportTrackerLayersTitle => 'Ce qu\'il faut suivre';

  @override
  String get transportTrackerShips => 'Navires';

  @override
  String get transportTrackerShipsSubtitle =>
      'Positions AIS des navires en direct dans le monde entier. Nécessite votre propre clé AISStream.io gratuite.';

  @override
  String get transportTrackerTransitTitle => 'Transports en commun — Pays-Bas';

  @override
  String get transportTrackerTransitSubtitle =>
      'Trains, métros, tramways, bus et ferries en direct, issus du flux open data néerlandais. Aucune clé nécessaire.';

  @override
  String get transportTrackerModes => 'Modes';

  @override
  String get transportTrackerKeyDialogTitle => 'Clé API AISStream.io';

  @override
  String get transportTrackerGetKeyHint =>
      'Obtenez une clé gratuite sur aisstream.io : connectez-vous, puis copiez votre clé API depuis le tableau de bord.';

  @override
  String get transportTrackerKeyHintReplace =>
      'Saisissez une nouvelle clé pour la remplacer';

  @override
  String get transportTrackerKeyHintPaste => 'Collez votre clé API';

  @override
  String get transportTrackerShowKey => 'Afficher la clé';

  @override
  String get transportTrackerHideKey => 'Masquer la clé';

  @override
  String get transportTrackerKeyPrivacyNote =>
      'Stockée uniquement sur cet appareil, chiffrée au repos. Envoyée directement à aisstream.io pendant le suivi, jamais à un serveur luma.';

  @override
  String get vesselCategoryCargo => 'Cargo';

  @override
  String get vesselCategoryTanker => 'Pétrolier';

  @override
  String get vesselCategoryPassenger => 'Passagers';

  @override
  String get vesselCategoryFishing => 'Pêche';

  @override
  String get vesselCategoryHighSpeed => 'Navire à grande vitesse';

  @override
  String get vesselCategoryTug => 'Remorqueur / service';

  @override
  String get vesselCategoryLawEnforcement => 'Forces de l’ordre';

  @override
  String get vesselCategorySearchAndRescue => 'Recherche et sauvetage';

  @override
  String get vesselCategoryPleasureCraft => 'Plaisance';

  @override
  String get vesselCategoryUnspecified => 'Non précisé';

  @override
  String get vesselNavUnderWayEngine => 'En route (moteur)';

  @override
  String get vesselNavAtAnchor => 'Au mouillage';

  @override
  String get vesselNavNotUnderCommand => 'Non maître de sa manœuvre';

  @override
  String get vesselNavRestrictedManoeuvrability =>
      'Capacité de manœuvre restreinte';

  @override
  String get vesselNavConstrainedByDraught => 'Limité par son tirant d’eau';

  @override
  String get vesselNavMoored => 'Amarré';

  @override
  String get vesselNavAground => 'Échoué';

  @override
  String get vesselNavUnderWaySailing => 'En route (voile)';

  @override
  String get vesselNavAisSart => 'AIS-SART (balise de détresse)';

  @override
  String vesselMmsiName(int mmsi) {
    return 'MMSI $mmsi';
  }

  @override
  String get usageRangeLast7Days => 'Semaine passée';

  @override
  String get usageRangeThisMonth => 'Ce mois-ci';

  @override
  String get usageRangeLast30Days => 'Mois passé';

  @override
  String get usageRangeCustom => 'Personnalisé…';

  @override
  String get usageWindowsOnlyTitle => 'Windows uniquement';

  @override
  String get usageWindowsOnlySubtitle =>
      'Le suivi d’utilisation lit la fenêtre active, ce que luma ne peut faire que dans l’application de bureau Windows.';

  @override
  String get usageStatusPaused => 'En pause';

  @override
  String get usageStatusIdle => 'Inactif';

  @override
  String usageStatusTracking(String appName) {
    return 'Suit $appName';
  }

  @override
  String get usageSummaryTotalTracked => 'Temps suivi total';

  @override
  String get usageSummaryAppsUsed => 'Applications utilisées';

  @override
  String get usageSummaryTopApp => 'Appli principale';

  @override
  String get usageNeedWiderRange =>
      'Choisissez une période plus large pour voir le détail par jour';

  @override
  String get usageEmptyTitle => 'Aucune activité pour l’instant';

  @override
  String get usageEmptySubtitle =>
      'Votre utilisation apparaîtra ici dès que vous utiliserez des applications sur ce PC.';

  @override
  String get usageClearConfirmTitle =>
      'Effacer tout l’historique d’utilisation ?';

  @override
  String get usageClearConfirmBody =>
      'Cela supprime toutes les sessions suivies et est irréversible.';

  @override
  String get usageClearAllHistory => 'Effacer tout l’historique';

  @override
  String get usagePauseTracking => 'Mettre le suivi en pause';

  @override
  String usageSampleEvery(int seconds) {
    return 'Échantillonnage toutes les $seconds s';
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
  String get usageInvalidSnapshot => 'Instantané d’utilisation invalide.';

  @override
  String get whiteboardToolSelect => 'Sélection';

  @override
  String get whiteboardToolPan => 'Déplacer';

  @override
  String get whiteboardToolPen => 'Stylo';

  @override
  String get whiteboardToolHighlighter => 'Surligneur';

  @override
  String get whiteboardToolEraser => 'Gomme';

  @override
  String get whiteboardToolLine => 'Ligne';

  @override
  String get whiteboardToolArrow => 'Flèche';

  @override
  String get whiteboardToolRectangle => 'Rectangle';

  @override
  String get whiteboardToolEllipse => 'Ellipse';

  @override
  String get whiteboardToolStickyNote => 'Note adhésive';

  @override
  String get whiteboardToolText => 'Texte';

  @override
  String get whiteboardInkGraphite => 'Graphite';

  @override
  String get whiteboardInkRed => 'Rouge';

  @override
  String get whiteboardInkOrange => 'Orange';

  @override
  String get whiteboardInkGreen => 'Vert';

  @override
  String get whiteboardInkBlue => 'Bleu';

  @override
  String get whiteboardInkPurple => 'Violet';

  @override
  String get whiteboardInkPink => 'Rose';

  @override
  String get whiteboardWidthFine => 'Fin';

  @override
  String get whiteboardWidthMedium => 'Moyen';

  @override
  String get whiteboardWidthBold => 'Épais';

  @override
  String get whiteboardExportEmpty =>
      'Il n’y a rien à exporter sur ce tableau.';

  @override
  String get whiteboardExportEncodeFailed => 'L’image n’a pas pu être encodée.';

  @override
  String get whiteboardExportDialogTitle => 'Enregistrer l’image du tableau';

  @override
  String whiteboardToolTooltip(String label, String shortcut) {
    return '$label ($shortcut)';
  }

  @override
  String get whiteboardUndoTooltip => 'Annuler (Ctrl+Z)';

  @override
  String get whiteboardRedoTooltip => 'Rétablir (Ctrl+Maj+Z)';

  @override
  String get whiteboardDeleteSelectionTooltip =>
      'Supprimer la sélection (Suppr)';

  @override
  String whiteboardInkSemantics(String name) {
    return 'Encre $name';
  }

  @override
  String whiteboardStrokeTooltip(String name) {
    return 'Épaisseur $name';
  }

  @override
  String get whiteboardZoomOut => 'Dézoomer';

  @override
  String get whiteboardZoomIn => 'Zoomer';

  @override
  String get whiteboardResetZoomTooltip => 'Réinitialiser le zoom (Ctrl+0)';

  @override
  String get whiteboardShowGrid => 'Afficher la grille';

  @override
  String get whiteboardHideGrid => 'Masquer la grille';

  @override
  String get whiteboardExportPng => 'Exporter en PNG';

  @override
  String get whiteboardClearBoardTooltip => 'Effacer le tableau';

  @override
  String whiteboardItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments',
      one: '1 élément',
    );
    return '$_temp0';
  }

  @override
  String get whiteboardBackTooltip => 'Retour aux tableaux (Échap)';

  @override
  String get whiteboardNewStickyNote => 'Nouvelle note adhésive';

  @override
  String get whiteboardNewText => 'Nouveau texte';

  @override
  String get whiteboardEditNote => 'Modifier la note';

  @override
  String get whiteboardEditText => 'Modifier le texte';

  @override
  String get whiteboardTextLabel => 'Texte';

  @override
  String get whiteboardNewLineHint => 'Maj+Entrée pour une nouvelle ligne';

  @override
  String get whiteboardClearTitle => 'Effacer le tableau ?';

  @override
  String whiteboardClearContent(int count, String title) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Les $count éléments de \"$title\" seront supprimés. Vous pouvez annuler cette action juste après.',
      one:
          'Le seul élément de \"$title\" sera supprimé. Vous pouvez annuler cette action juste après.',
    );
    return '$_temp0';
  }

  @override
  String whiteboardExportFailed(String error) {
    return 'Impossible d’exporter le tableau : $error';
  }

  @override
  String get whiteboardNameHint => 'Nommez un nouveau tableau';

  @override
  String get whiteboardEmptyTitle => 'Aucun tableau pour l’instant';

  @override
  String get whiteboardEmptySubtitle =>
      'Nommez-en un ci-dessus et commencez à dessiner. Stylo, formes, flèches et notes adhésives, le tout enregistré au fur et à mesure.';

  @override
  String get whiteboardRenameTooltip => 'Renommer le tableau';

  @override
  String get whiteboardDeleteBoardTooltip => 'Supprimer le tableau';

  @override
  String whiteboardDeleteBoardTitle(String title) {
    return 'Supprimer « $title » ?';
  }

  @override
  String whiteboardDeleteBoardContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Les $count éléments de ce tableau seront supprimés définitivement. Cette action est irréversible.',
      one:
          'Le seul élément de ce tableau sera supprimé définitivement. Cette action est irréversible.',
      zero: 'Ce tableau est vide. Il sera supprimé définitivement.',
    );
    return '$_temp0';
  }

  @override
  String get speedTestTryAgain => 'Réessayer';

  @override
  String get speedTestStart => 'Lancer le test';

  @override
  String get speedTestTesting => 'Test en cours — veuillez patienter…';

  @override
  String get speedTestFailed =>
      'Le test a échoué. Vérifiez votre connexion et réessayez.';

  @override
  String get speedTestReady => 'Prêt';

  @override
  String get speedTestPinging => 'Ping en cours…';

  @override
  String get speedTestDownloading => 'Téléchargement';

  @override
  String get speedTestUploading => 'Envoi';

  @override
  String get speedTestCheckingNetwork => 'Vérification du réseau…';

  @override
  String get speedTestShowName => 'Afficher le nom';

  @override
  String get speedTestShowDetails => 'Afficher les détails';

  @override
  String get speedTestPing => 'Ping';

  @override
  String get speedTestClearHistoryTitle => 'Effacer l’historique ?';

  @override
  String get speedTestClearHistoryContent =>
      'Tous les résultats de tests de vitesse précédents seront supprimés.';

  @override
  String get speedTestClearAll => 'Tout effacer';

  @override
  String get speedTestNoTests => 'Aucun test pour l’instant';

  @override
  String get speedTestNoTestsSubtitle =>
      'Lancez votre premier test de vitesse pour suivre votre connexion dans le temps.';

  @override
  String get speedTestDownloadHistory => 'Débit de téléchargement (Mbps)';

  @override
  String get speedTestUploadHistory => 'Débit d’envoi (Mbps)';

  @override
  String get speedTestNetworkWifi => 'Wi-Fi';

  @override
  String speedTestNetworkWithName(String network, String name) {
    return '$network · $name';
  }

  @override
  String get speedTestNetworkEthernet => 'Ethernet';

  @override
  String get speedTestNetworkMobileData => 'Données mobiles';

  @override
  String speedTestNetworkMobileGeneration(String generation) {
    return 'Données mobiles · $generation';
  }

  @override
  String get speedTestNetworkVpn => 'VPN';

  @override
  String get speedTestNetworkOffline => 'Pas de connexion';

  @override
  String get speedTestNetworkUnknown => 'Réseau inconnu';

  @override
  String get wifiSpeedTestInvalidSnapshot =>
      'Instantané du test de vitesse invalide.';

  @override
  String get worthCounterInvalidSnapshot =>
      'Instantané du compteur de valeur invalide.';

  @override
  String get worthCounterAddProduct => 'Ajouter un produit';

  @override
  String get worthCounterNoProducts => 'Aucun produit pour l’instant';

  @override
  String get worthCounterEmptySubtitle =>
      'Ajoutez un produit avec la valeur d’un article, puis comptez-les avec + et -. La valeur totale s’affiche en bas.';

  @override
  String get worthCounterDeleteProductTitle => 'Supprimer le produit ?';

  @override
  String worthCounterDeleteProductBody(String name) {
    return 'Cela supprime « $name » et son compte du total.';
  }

  @override
  String get worthCounterResetAllTitle => 'Réinitialiser tous les comptes ?';

  @override
  String get worthCounterResetAllBody =>
      'Tous les produits restent dans la liste, mais leurs comptes reviennent à zéro.';

  @override
  String get worthCounterEditProduct => 'Modifier le produit';

  @override
  String get worthCounterResetCount => 'Réinitialiser le compte';

  @override
  String get worthCounterResetAll => 'Tout réinitialiser';

  @override
  String get worthCounterResetAllCounts => 'Réinitialiser tous les comptes';

  @override
  String get worthCounterOneLess => 'Un de moins';

  @override
  String get worthCounterOneMore => 'Un de plus';

  @override
  String worthCounterItemsCounted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles comptés',
      one: '1 article compté',
    );
    return '$_temp0';
  }

  @override
  String worthCounterPricePerItem(String price) {
    return '$price l’unité';
  }

  @override
  String get worthCounterNameRequired => 'Donnez un nom au produit.';

  @override
  String get worthCounterPriceInvalid =>
      'Saisissez la valeur d’un article, par ex. 2,50.';

  @override
  String get worthCounterWorthPerItemLabel => 'Valeur unitaire (€)';

  @override
  String get worthCounterNameHint => 'par ex. Café';

  @override
  String get worthCounterPriceHint => 'par ex. 2,00';

  @override
  String get financeSeedCategoryGroceries => 'Courses';

  @override
  String get financeSeedCategoryEatingOut => 'Restaurants';

  @override
  String get financeSeedCategoryClothing => 'Vêtements';

  @override
  String get financeSeedCategoryTransport => 'Transport';

  @override
  String get financeSeedCategorySubscriptions => 'Abonnements';

  @override
  String get financeSeedCategoryHousing => 'Logement';

  @override
  String get financeSeedCategoryUtilities => 'Services publics';

  @override
  String get financeSeedCategoryHealth => 'Santé & soins';

  @override
  String get financeSeedCategoryEntertainment => 'Loisirs';

  @override
  String get financeSeedCategoryShopping => 'Achats';

  @override
  String get financeTabTransactions => 'Transactions';

  @override
  String get financeTabPots => 'Cagnottes';

  @override
  String get financeTabRecurring => 'Récurrent';

  @override
  String get financeTabDebts => 'Dettes';

  @override
  String get financeTabStocks => 'Actions';

  @override
  String get financeTabReports => 'Rapports';

  @override
  String get financeExistingTransaction => 'Transaction existante';

  @override
  String get financeImportMatchChanged =>
      'Cette correspondance a changé. Vérifiez à nouveau l’entrée.';

  @override
  String get financeManualAllocationNote => 'Répartition manuelle';

  @override
  String financeDividendNote(String ticker) {
    return 'Dividende $ticker';
  }

  @override
  String financeDebtRepaymentNote(String name) {
    return 'Remboursement : $name';
  }

  @override
  String financeDebtRepaidToMeNote(String name) {
    return 'Remboursé : $name';
  }

  @override
  String get financeDebtBalanceAdjustmentNote => 'Correction du solde';

  @override
  String get financeAutoAllocationNote => 'Répartition automatique';

  @override
  String get financeUnknownMerchant => 'Commerçant inconnu';

  @override
  String get financeAllocationLabel => 'Répartition';

  @override
  String get financeTypeIncome => 'Revenu';

  @override
  String get financeTypeExpense => 'Dépense';

  @override
  String get financeImportOr => 'ou';

  @override
  String financeImportFileType(String type) {
    return 'fichier $type';
  }

  @override
  String get financeImportHintAbnAmro =>
      'Téléchargez les transactions au format TXT (séparées par des tabulations).';

  @override
  String get financeImportHintRabobank =>
      'Téléchargez le récapitulatif des transactions au format CSV.';

  @override
  String get financeImportHintBunq =>
      'Exportez un relevé du compte en EUR au format CSV.';

  @override
  String get financeImportHintSns =>
      'Téléchargez les transactions depuis Mijn SNS au format CSV.';

  @override
  String get financeImportHintKnab =>
      'Utilisez « Rechercher et télécharger » pour exporter au format CSV.';

  @override
  String get financeMainPotName => 'Principal';

  @override
  String financeImportSelectStatementTitle(String bank) {
    return 'Sélectionner le relevé $bank';
  }

  @override
  String get financeImportNoTransactions =>
      'Aucune transaction trouvée dans le fichier sélectionné.';

  @override
  String financeImportReadFailed(String detail) {
    return 'Échec de la lecture du fichier : $detail';
  }

  @override
  String get financeImportTitle => 'Importer des données';

  @override
  String get financeImportIntro =>
      'Sélectionnez votre banque et un relevé exporté. Vérifiez les transactions avant de les ajouter.';

  @override
  String financeImportWrongFileType(String fileType, String bank) {
    return 'Sélectionnez un export $fileType de $bank.';
  }

  @override
  String get financeImportIncompleteUtf16 => 'Relevé UTF-16 incomplet.';

  @override
  String get financeImportUnexpectedAfterQuote =>
      'Texte inattendu après un champ entre guillemets.';

  @override
  String get financeImportUnclosedQuote =>
      'Guillemet non fermé dans le relevé.';

  @override
  String get financeReviewEntryTitle => 'Vérifier l’entrée';

  @override
  String financeReviewSavedSkipped(int saved, int skipped) {
    return '$saved enregistrées · $skipped ignorées';
  }

  @override
  String get financeReviewMerchant => 'Commerçant';

  @override
  String get financeReviewCompany => 'Entreprise';

  @override
  String financeReviewMatchSubtitle(String date, String status) {
    return '$date · $status';
  }

  @override
  String get financeReviewAlreadyRecorded => 'Déjà enregistrée';

  @override
  String get financeReviewRecurringPayment => 'Paiement récurrent';

  @override
  String get financeReviewPossibleMatches => 'Correspondances possibles';

  @override
  String get financeReviewMatchHelp =>
      'Sélectionnez le même paiement pour ne le compter qu’une fois. Les entrées existantes conservent leur cagnotte et leur catégorie.';

  @override
  String get financeReviewPot => 'Cagnotte';

  @override
  String get financeReviewSkip => 'Ignorer';

  @override
  String get financeReviewAddNext => 'Ajouter et suivant';

  @override
  String get financeReviewMatchNext => 'Associer et suivant';

  @override
  String get financeNoCategory => 'Aucune catégorie';

  @override
  String get financeReviewPickCompany => 'Choisir une entreprise (facultatif)';

  @override
  String get financeReviewSearchCompanies => 'Rechercher des entreprises';

  @override
  String get financeEntryAmountInvalid =>
      'Saisissez un montant valide supérieur à zéro.';

  @override
  String get financeEntryEdit => 'Modifier l\'opération';

  @override
  String get financeEntryNew => 'Nouvelle opération';

  @override
  String get financeEntryAllocationToPot => 'Affectation à une cagnotte';

  @override
  String get financeKindExpense => 'Dépense';

  @override
  String get financeKindIncome => 'Revenu';

  @override
  String get financeCompany => 'Entreprise';

  @override
  String get financePot => 'Cagnotte';

  @override
  String get financeFromMainBalance => 'Depuis le solde principal';

  @override
  String get financeToMainBalance => 'Vers le solde principal';

  @override
  String get financeNoteOptional => 'Note (facultatif)';

  @override
  String get financeNoteHint => 'ex. courses de la semaine';

  @override
  String get financeSaveChanges => 'Enregistrer les modifications';

  @override
  String get financeAddEntry => 'Ajouter l\'opération';

  @override
  String get financeSearchCompanies => 'Rechercher des entreprises';

  @override
  String get financePickCompany => 'Choisir une entreprise (facultatif)';

  @override
  String get financePickDate => 'Choisir une date';

  @override
  String get financeNoExpensesThisMonth => 'Aucune dépense ce mois-ci';

  @override
  String get financeNetWorthComeBack =>
      'Revenez demain pour voir l\'évolution de votre patrimoine.';

  @override
  String get financeIncomeThisMonth => 'Revenus de ce mois';

  @override
  String get financeSpentThisMonth => 'Dépensé ce mois-ci';

  @override
  String get financeCashFlowForecast => 'Prévision de trésorerie';

  @override
  String get financeBudgets => 'Budgets';

  @override
  String get financeDashboard => 'Tableau de bord';

  @override
  String get financePots => 'Cagnottes';

  @override
  String get financeOverviewNoPots =>
      'Aucune cagnotte pour l\'instant — créez-en une dans l\'onglet Cagnottes et répartissez votre argent.';

  @override
  String get financeThisWeek => 'Cette semaine';

  @override
  String get financeInvestments => 'Investissements';

  @override
  String get financeUpcoming => 'À venir';

  @override
  String get financeAddGraph => 'Ajouter un graphique';

  @override
  String get financeGraphNetWorth => 'Patrimoine dans le temps';

  @override
  String get financeGraphCategorySpending => 'Dépenses par catégorie';

  @override
  String get financeGraphIncomeVsExpense => 'Revenus vs dépenses';

  @override
  String get financeGraphUnknown => 'Graphique inconnu';

  @override
  String get financeGraphLineChart => 'Graphique en courbes';

  @override
  String get financeGraphPieChart => 'Graphique circulaire';

  @override
  String get financeGraphBarChart => 'Graphique à barres';

  @override
  String get financeGraphChart => 'Graphique';

  @override
  String get financeNetWorth => 'Patrimoine';

  @override
  String get financeAvailable => 'Disponible';

  @override
  String get financeInPots => 'Dans les cagnottes';

  @override
  String get financeDebts => 'Dettes';

  @override
  String get financeOwedToYou => 'Vous est dû';

  @override
  String get financeYouOwe => 'Vous devez';

  @override
  String get financeNoSpendingThisWeek =>
      'Aucune dépense enregistrée cette semaine.';

  @override
  String get financeSpentThisWeek => 'Dépensé cette semaine';

  @override
  String get financeUncategorized => 'Sans catégorie';

  @override
  String get financePortfolioValue => 'Valeur du portefeuille';

  @override
  String get financeGainLoss => 'Gain / perte';

  @override
  String get financeCadenceWeekly => 'Hebdomadaire';

  @override
  String get financeCadenceMonthly => 'Mensuel';

  @override
  String financeUpcomingNext(String cadence, String date) {
    return '$cadence · prochain $date';
  }

  @override
  String get financeUpcomingEmpty =>
      'Aucune charge ou revenu fixe pour l\'instant — ajoutez-les dans l\'onglet Récurrent.';

  @override
  String get financeAddDebt => 'Ajouter une dette';

  @override
  String get financeDebtsEmpty => 'Aucune dette suivie';

  @override
  String get financeDebtsEmptySubtitle =>
      'Ajoutez un prêt étudiant, un emprunt immobilier ou une somme qu\'un ami vous doit pour voir quand elle sera remboursée.';

  @override
  String get financePaidOff => 'Remboursé';

  @override
  String get financeFullyRepaid => 'Entièrement remboursé';

  @override
  String get financeRepaid => 'Remboursé';

  @override
  String get financeDebtsSetMonthlyPayment =>
      'Définissez un montant mensuel pour voir quand il sera remboursé.';

  @override
  String financeDebtsDoesNotCoverInterest(String amount) {
    return '$amount/mois ne couvre pas les intérêts.';
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
      other: '$count paiements',
      one: '1 paiement',
    );
    return '$verb en $date · $_temp0$interest';
  }

  @override
  String financeDebtsInterest(String amount) {
    return '$amount d\'intérêts';
  }

  @override
  String financeDebtsProgressPaid(String percent, String outlook) {
    return '$percent% remboursé · $outlook';
  }

  @override
  String financeDebtsProgressRepaid(String percent, String outlook) {
    return '$percent% remboursé · $outlook';
  }

  @override
  String financeDebtsOfTotal(String amount) {
    return 'sur $amount';
  }

  @override
  String financeDebtsInterestRate(String rate) {
    return '$rate % par an';
  }

  @override
  String financeDebtsMonthlyAmount(String amount) {
    return '$amount/mois';
  }

  @override
  String get financeDebtsLogPayment => 'Enregistrer un paiement';

  @override
  String get financeDebtsLogRepayment => 'Enregistrer un remboursement';

  @override
  String get financeDebtsUpdateBalance => 'Mettre à jour le solde';

  @override
  String get financeDebtsPaymentHistory => 'Historique des paiements';

  @override
  String financeDebtsDeleteTitle(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get financeDebtsDeleteMessage =>
      'Son historique de paiements sera supprimé aussi. Les paiements déjà enregistrés dans vos transactions y restent.';

  @override
  String get financeEditDebt => 'Modifier la dette';

  @override
  String get financeDebtsIOwe => 'Je dois';

  @override
  String get financeDebtsOwedToMe => 'On me doit';

  @override
  String get financeDebtsNameHintOwe => 'ex. Prêt étudiant (DUO)';

  @override
  String get financeDebtsNameHintOwed => 'ex. Sam — billets de concert';

  @override
  String get financeDebtsOriginalAmount => 'Montant initial';

  @override
  String get financeDebtsInterestOptional => 'Intérêts (facultatif)';

  @override
  String get financeDebtsPerYear => '% / an';

  @override
  String get financeDebtsMonthlyPayment => 'Mensualité';

  @override
  String get financeDebtsStarted => 'Début';

  @override
  String get financeDebtsNameAmountRequired =>
      'Donnez-lui un nom et un montant supérieur à 0 €.';

  @override
  String get financeDebtsNumbersRequired =>
      'Les intérêts et la mensualité doivent être des nombres.';

  @override
  String financeDebtsPaymentOn(String name) {
    return 'Paiement pour $name';
  }

  @override
  String financeDebtsRepaymentFrom(String name) {
    return 'Remboursement de $name';
  }

  @override
  String get financeDebtsLog => 'Enregistrer';

  @override
  String get financeDebtsAmountAboveZero =>
      'Saisissez un montant supérieur à 0 €.';

  @override
  String get financeDebtsBookExpense =>
      'L\'enregistrer aussi comme dépense du solde principal';

  @override
  String get financeDebtsBookIncome =>
      'L\'enregistrer aussi comme revenu du solde principal';

  @override
  String get financeDebtsEnterBalance =>
      'Saisissez le solde sous forme de montant.';

  @override
  String get financeDebtsAdjustExplainer =>
      'Saisissez le solde de votre dernier relevé. La différence est enregistrée comme un ajustement (intérêts, frais) sans toucher à vos transactions.';

  @override
  String get financeDebtsCurrentBalance => 'Solde actuel';

  @override
  String financeDebtsHistoryTitle(String name) {
    return '$name — historique';
  }

  @override
  String get financeDebtsNoPayments =>
      'Aucun paiement enregistré pour l\'instant.';

  @override
  String get financeDebtsPaymentBooked => 'Paiement (enregistré)';

  @override
  String get financeDebtsPayment => 'Paiement';

  @override
  String get financePlanningNoBudgets => 'Pas encore de budgets';

  @override
  String financePlanningSpentOfBudget(
    String spent,
    String budget,
    String month,
  ) {
    return '$spent sur $budget · $month';
  }

  @override
  String get financePlanningSetBudgets => 'Définir les budgets';

  @override
  String get financePlanningBudgetsHint =>
      'Donnez une limite mensuelle aux catégories et voyez où vous en êtes.';

  @override
  String financePlanningOver(String amount) {
    return '$amount de trop';
  }

  @override
  String financePlanningLeft(String amount) {
    return '$amount restant';
  }

  @override
  String get financePlanningBudgetsTitle => 'Budgets mensuels';

  @override
  String get financePlanningBudgetsEditHint =>
      'Laissez une catégorie vide pour ne fixer aucune limite.';

  @override
  String get financePlanningNoLimit => 'Aucune limite';

  @override
  String financePlanningNotAnAmount(String text, String name) {
    return '« $text » pour $name n\'est pas un montant.';
  }

  @override
  String financeForecastAvailableIn(int days) {
    return 'Disponible dans $days jours';
  }

  @override
  String get financeForecast30Days => '30j';

  @override
  String get financeForecast90Days => '90j';

  @override
  String financeForecastBelowZero(
    String date,
    String lowest,
    String lowestDate,
  ) {
    return 'Passera sous 0 € le $date — plus bas $lowest le $lowestDate.';
  }

  @override
  String financeForecastLowest(String amount, String date) {
    return 'Point le plus bas $amount le $date.';
  }

  @override
  String get financeForecastNothingScheduled =>
      'Rien de prévu — ajoutez charges fixes et revenus dans l\'onglet Récurrent.';

  @override
  String get financePlanningGoalReached => 'Objectif atteint';

  @override
  String financePlanningGoalShortWasDue(String amount, String date) {
    return '$amount manquants · était dû le $date';
  }

  @override
  String financePlanningGoalMonthly(String amount, String month) {
    return '$amount/mois jusqu\'en $month';
  }

  @override
  String financePlanningGoalToGo(String amount) {
    return 'Reste $amount';
  }

  @override
  String financePlanningGoalTarget(String amount) {
    return 'Objectif $amount';
  }

  @override
  String financePlanningGoalPercent(String percent, String amount) {
    return '$percent sur $amount';
  }

  @override
  String get financePotDetailEmpty =>
      'Rien dans cette cagnotte pour le moment.';

  @override
  String get financePotDetailBalanceOverTime => 'Solde au fil du temps';

  @override
  String get financePotDetailTransactions => 'Transactions';

  @override
  String get financePotDetailSpendingByCategory => 'Dépenses par catégorie';

  @override
  String get financePotDetailUncategorized => 'Sans catégorie';

  @override
  String get financePotDetailIncome => 'Revenu';

  @override
  String get financePotDetailAllocation => 'Affectation';

  @override
  String financePotsAvailableToAllocate(String amount) {
    return 'Disponible à affecter : $amount';
  }

  @override
  String get financePotsNewPot => 'Nouvelle cagnotte';

  @override
  String get financePotsEmptyTitle => 'Pas encore de cagnottes';

  @override
  String get financePotsEmptySubtitle =>
      'Créez des cagnottes comme « Loyer », « Courses » ou « Vacances » pour répartir votre argent.';

  @override
  String get financePotsAddMoney => 'Ajouter de l\'argent';

  @override
  String get financePotsBalance => 'Solde';

  @override
  String financePotsDeleteTitle(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get financePotsDeleteBody =>
      'Les opérations affectées à cette cagnotte reviendront à votre solde principal.';

  @override
  String financePotsAddMoneyTitle(String name) {
    return 'Ajouter de l\'argent à « $name »';
  }

  @override
  String get financePotsGoalNotPositive =>
      'L\'objectif doit être un montant supérieur à 0 €.';

  @override
  String get financePotsEditPot => 'Modifier la cagnotte';

  @override
  String get financePotsNameHint => 'Nom de la cagnotte (ex. Vacances)';

  @override
  String get financePotsColor => 'Couleur';

  @override
  String get financePotsIcon => 'Icône';

  @override
  String get financePotsSavingsGoal => 'Objectif d\'épargne (facultatif)';

  @override
  String get financePotsNoGoal => 'Aucun objectif';

  @override
  String get financePotsReachBy => 'Atteindre d\'ici le';

  @override
  String get financePotsAnyTime => 'À tout moment';

  @override
  String get financeRecurringApplyDue => 'Appliquer les échéances';

  @override
  String financeRecurringApplied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count échéances appliquées.',
      one: '1 échéance appliquée.',
    );
    return '$_temp0';
  }

  @override
  String get financeRecurringFixedHeader => 'Charges fixes et revenus';

  @override
  String get financeRecurringEmpty =>
      'Ajoutez des éléments comme le loyer, Spotify ou votre salaire.';

  @override
  String get financeRecurringAutoHeader => 'Répartition automatique';

  @override
  String get financeRecurringCreatePotFirst => 'Créez d\'abord une cagnotte.';

  @override
  String get financeRecurringAutoHint =>
      'Transférez automatiquement de l\'argent de votre solde principal vers les cagnottes, chaque semaine ou chaque mois.';

  @override
  String get financeRecurringNoRules =>
      'Aucune règle de répartition pour l\'instant.';

  @override
  String financeRecurringBillsDueSoon(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count factures à échéance proche',
      one: '1 facture à échéance proche',
    );
    return '$_temp0';
  }

  @override
  String get financeRecurringOverdue => 'En retard';

  @override
  String get financeRecurringDueToday => 'Échéance aujourd\'hui';

  @override
  String get financeRecurringDueTomorrow => 'Échéance demain';

  @override
  String financeRecurringDueInDays(int days) {
    return 'Échéance dans $days jours';
  }

  @override
  String get financeRecurringWeekly => 'Chaque semaine';

  @override
  String get financeRecurringMonthly => 'Chaque mois';

  @override
  String financeRecurringRowSubtitle(String cadence, String date) {
    return '$cadence · prochaine le $date';
  }

  @override
  String financeRecurringRowBillSubtitle(
    String cadence,
    int days,
    String date,
  ) {
    return '$cadence · Facture, rappel $days jours avant · prochaine le $date';
  }

  @override
  String financeRecurringToPot(String name) {
    return 'Vers $name';
  }

  @override
  String get financeRecurringPotFallback => 'cagnotte';

  @override
  String get financeRecurringNewEntry => 'Nouvelle opération récurrente';

  @override
  String get financeRecurringFixedCost => 'Charge fixe';

  @override
  String get financeRecurringFixedIncome => 'Revenu fixe';

  @override
  String get financeRecurringNameHint => 'ex. Spotify';

  @override
  String get financeRecurringRepeats => 'Répétition';

  @override
  String get financeRecurringFirstDue => 'Première échéance';

  @override
  String get financeRecurringPotOptional => 'Cagnotte (facultatif)';

  @override
  String get financeRecurringFromMain => 'Depuis le solde principal';

  @override
  String get financeRecurringToMain => 'Vers le solde principal';

  @override
  String get financeRecurringCategoryOptional => 'Catégorie (facultatif)';

  @override
  String get financeRecurringNoCategory => 'Aucune catégorie';

  @override
  String get financeRecurringTreatAsBill =>
      'Traiter comme une facture/un abonnement — l\'afficher dans « bientôt dues »';

  @override
  String get financeRecurringRemindDays =>
      'Me rappeler ce nombre de jours avant l\'échéance';

  @override
  String get financeRecurringEnterNameAndAmount =>
      'Saisissez un nom et un montant valide.';

  @override
  String get financeRecurringInvalidReminder =>
      'Saisissez un nombre de jours de rappel valide.';

  @override
  String get financeRecurringNewRule => 'Nouvelle règle de répartition';

  @override
  String get financeRecurringPot => 'Cagnotte';

  @override
  String get financeRecurringAmountType => 'Type de montant';

  @override
  String get financeRecurringFixedEuro => 'Fixe €';

  @override
  String get financeRecurringPercentOfBalance => '% du solde';

  @override
  String get financeRecurringAmountPerPeriod => 'Montant par période';

  @override
  String get financeRecurringPercent => 'Pourcentage';

  @override
  String get financeRecurringPercentHint => 'ex. 25';

  @override
  String get financeRecurringFirstRun => 'Date de la première exécution';

  @override
  String get financeRecurringEnterValidAmount => 'Saisissez un montant valide.';

  @override
  String get financeRecurringPercentRange =>
      'Saisissez un pourcentage entre 0 et 100.';

  @override
  String get financeRecurringAddRule => 'Ajouter la règle';

  @override
  String financeSubsPossibleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count abonnements possibles',
      one: '1 abonnement possible',
    );
    return '$_temp0';
  }

  @override
  String financeSubsMonthlyEstimate(String amount) {
    return '≈ $amount/mois';
  }

  @override
  String get financeSubsExplainer =>
      'Ces paiements se répètent régulièrement mais ne sont pas encore suivis.';

  @override
  String get financeSubsCadenceWeekly => 'Hebdomadaire';

  @override
  String get financeSubsCadenceMonthly => 'Mensuel';

  @override
  String financeSubsRowDetail(
    String cadence,
    String amount,
    String count,
    String date,
  ) {
    return '$cadence · $amount · vu $count× · dernier $date';
  }

  @override
  String get financeSubsNotSubscription => 'Pas un abonnement';

  @override
  String financeSubsTrackedSnack(String name, String date) {
    return '$name est maintenant une facture, prochaine échéance le $date.';
  }

  @override
  String get financeSubsTrackAsBill => 'Suivre comme facture';

  @override
  String get financeReportsNothingToExport =>
      'Rien à exporter pour cette période.';

  @override
  String get financeReportsExportTitle => 'Exporter les transactions';

  @override
  String financeReportsExported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions exportées.',
      one: '1 transaction exportée.',
    );
    return '$_temp0';
  }

  @override
  String financeReportsExportFailed(String error) {
    return 'Échec de l\'exportation : $error';
  }

  @override
  String get financeReportsExporting => 'Exportation…';

  @override
  String get financeReportsMonthTab => 'Mois';

  @override
  String get financeReportsYearTab => 'Année';

  @override
  String get financeReportsIncome => 'Revenus';

  @override
  String get financeReportsSpent => 'Dépenses';

  @override
  String get financeReportsNet => 'Net';

  @override
  String get financeReportsSavingsRate => 'Taux d\'épargne';

  @override
  String get financeReportsSavingsRateNote => 'Part des revenus non dépensée';

  @override
  String get financeReportsLastMonth => 'le mois dernier';

  @override
  String get financeReportsLastYear => 'l\'année dernière';

  @override
  String financeReportsVsPrevious(String delta, String period) {
    return '$delta par rapport à $period';
  }

  @override
  String get financeReportsSpendingByCategory => 'Dépenses par catégorie';

  @override
  String get financeReportsComparedMonth => 'Comparé au mois précédent.';

  @override
  String get financeReportsComparedYear => 'Comparé à l\'année précédente.';

  @override
  String get financeReportsNoSpending => 'Aucune dépense sur cette période.';

  @override
  String get financeReportsUncategorized => 'Sans catégorie';

  @override
  String financeReportsPercentOfSpending(int percent) {
    return '$percent % des dépenses';
  }

  @override
  String financeReportsOverBudget(String amount) {
    return '$amount au-dessus du budget';
  }

  @override
  String financeReportsWithinBudget(String amount) {
    return 'dans le budget de $amount';
  }

  @override
  String get financeReportsTopMerchants => 'Principaux marchands';

  @override
  String get financeReportsMonthByMonth => 'Mois par mois';

  @override
  String get financeReportsYearNotStarted =>
      'Cette année n\'a pas encore commencé.';

  @override
  String get financeReconTitle => 'Rapprochement du relevé';

  @override
  String get financeReconEndBeforeStart =>
      'La date de clôture doit être égale ou postérieure à la date de début.';

  @override
  String get financeReconInvalidBalances =>
      'Saisissez des soldes d\'ouverture et de clôture valides en euros.';

  @override
  String get financeReconIntro =>
      'Saisissez le solde d\'ouverture juste avant la date de début et le solde de clôture à la fin de la date de clôture. Luma prend en compte les revenus et dépenses de tous les pots ; les allocations entre pots ne modifient pas ce solde.';

  @override
  String get financeReconStartDate => 'Date de début';

  @override
  String get financeReconClosingDate => 'Date de clôture';

  @override
  String get financeReconOpeningBalance => 'Solde d\'ouverture du relevé';

  @override
  String get financeReconClosingBalance => 'Solde de clôture du relevé';

  @override
  String get financeReconLoadEntries => 'Charger les lignes du relevé';

  @override
  String get financeReconReplaceEntries => 'Remplacer les lignes du relevé';

  @override
  String get financeReconClearEntries => 'Effacer les lignes du relevé';

  @override
  String get financeReconOptionalHelp =>
      'Facultatif : lisez un fichier de transactions exporté pour repérer des lignes. Saisissez les soldes du relevé ci-dessus ; charger un fichier n\'ajoute rien.';

  @override
  String financeReconEntriesLoaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lignes de relevé chargées.',
      one: '1 ligne de relevé chargée.',
    );
    return '$_temp0 Utilisez les dates de toute la période du relevé ci-dessus.';
  }

  @override
  String get financeReconReadMerchantsFailed =>
      'Impossible de lire les marchands.';

  @override
  String get financeReconReadTransactionsFailed =>
      'Impossible de lire les transactions.';

  @override
  String get financeReconCompare => 'Comparer les soldes';

  @override
  String financeReconCalculatedClosing(String amount) {
    return 'Solde de clôture calculé : $amount';
  }

  @override
  String financeReconStatementClosing(String amount) {
    return 'Solde de clôture du relevé : $amount';
  }

  @override
  String get financeReconMatch => 'Les soldes correspondent';

  @override
  String financeReconDifferenceLower(String amount) {
    return 'Écart : $amount (Luma est plus bas)';
  }

  @override
  String financeReconDifferenceHigher(String amount) {
    return 'Écart : $amount (Luma est plus haut)';
  }

  @override
  String get financeReconCheckHint =>
      'Vérifiez le solde d\'ouverture, les dates et les lignes incluses. Si vous suivez plusieurs comptes bancaires, excluez ci-dessous les mouvements appartenant à d\'autres comptes. Les suggestions ne prouvent pas qu\'une ligne est erronée.';

  @override
  String financeReconClosingFromFile(String amount) {
    return 'Clôture d\'après les lignes du fichier : $amount';
  }

  @override
  String get financeReconFileDoesNotReach =>
      'Les lignes du fichier et le solde d\'ouverture n\'atteignent pas le solde de clôture du relevé. Vérifiez que l\'export couvre toute la période.';

  @override
  String financeReconOutsidePeriod(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lignes du fichier sont hors de la période sélectionnée.',
      one: '1 ligne du fichier est hors de la période sélectionnée.',
    );
    return '$_temp0';
  }

  @override
  String financeReconMatchedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count lignes associées par date, sens et montant. Les descriptions peuvent différer ; les dates de comptabilisation décalées apparaissent comme non associées.',
      one:
          '1 ligne associée par date, sens et montant. Les descriptions peuvent différer ; les dates de comptabilisation décalées apparaissent comme non associées.',
    );
    return '$_temp0';
  }

  @override
  String financeReconReviewPairs(int count) {
    return 'Vérifier les paires aux descriptions différentes ($count)';
  }

  @override
  String financeReconLumaEntry(String note) {
    return 'Luma : $note';
  }

  @override
  String financeReconStatementSubtitle(String description, String details) {
    return 'Relevé : $description\n$details';
  }

  @override
  String financeReconPossiblyMissing(int count) {
    return 'Peut-être absent de Luma ($count)';
  }

  @override
  String get financeReconReviewMissing =>
      'Vérifier les lignes manquantes à importer';

  @override
  String financeReconNotPaired(int count) {
    return 'Entrées Luma non associées au relevé ($count)';
  }

  @override
  String get financeReconNoUnmatched => 'Aucune ligne non associée.';

  @override
  String financeReconDuplicateTitle(int count, String note) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lignes : $note',
      one: '1 ligne : $note',
    );
    return '$_temp0';
  }

  @override
  String get financeReconSameDescription => 'Même description';

  @override
  String financeReconDuplicateDetail(String date, String amount, String ids) {
    return '$date · $amount chacune · IDs $ids';
  }

  @override
  String financeReconPossibleDuplicates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Doublons possibles ($count groupes)',
      one: 'Doublons possibles (1 groupe)',
    );
    return '$_temp0';
  }

  @override
  String get financeReconRemovalExplains =>
      'Lignes dont la suppression expliquerait l\'écart';

  @override
  String get financeReconReviewIncluded =>
      'Vérifier les lignes de trésorerie incluses';

  @override
  String get financeReconNoCashEntries =>
      'Aucune ligne de trésorerie sur cette période.';

  @override
  String get financeReconIncludeAll => 'Inclure à nouveau toutes les lignes';

  @override
  String financeReconKindId(String kind, int id) {
    return '$kind n° $id';
  }

  @override
  String get financeReconKindIncome => 'Revenu';

  @override
  String get financeReconKindExpense => 'Dépense';

  @override
  String get financeReconKindAllocation => 'Allocation';

  @override
  String get financeReconMainPot => 'Principal';

  @override
  String get financeStocksNoChartDataAvailable =>
      'Aucune donnée de graphique disponible.';

  @override
  String get financeStocksNoChartData => 'Pas de données de graphique.';

  @override
  String get financeStocksPricesUpdated => 'Cours mis à jour.';

  @override
  String financeStocksUpdatedWithFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mis à jour, mais $count symboles n’ont pas pu être récupérés.',
      one: 'Mis à jour, mais 1 symbole n’a pas pu être récupéré.',
    );
    return '$_temp0';
  }

  @override
  String financeStocksPortfolio(String amount) {
    return 'Portefeuille $amount';
  }

  @override
  String get financeStocksUpdatingPrices => 'Mise à jour des cours…';

  @override
  String get financeStocksAtCostNoQuote =>
      'Au prix d\'achat — pas encore de cours en direct';

  @override
  String financeStocksPricesAsOf(String stamp) {
    return 'Cours au $stamp';
  }

  @override
  String get financeStocksForeignNotConverted =>
      'Certains cours étrangers ne sont pas encore convertis en euros';

  @override
  String financeStocksDividendsButton(String amount) {
    return 'Dividendes $amount';
  }

  @override
  String get financeStocksRefreshing => 'Actualisation…';

  @override
  String get financeStocksAddHolding => 'Ajouter une position';

  @override
  String get financeStocksNoHoldings => 'Aucune position pour l\'instant';

  @override
  String get financeStocksNoHoldingsHint =>
      'Ajoutez une action comme AAPL ou ASML pour suivre son cours.';

  @override
  String financeStocksRemoveTitle(String ticker) {
    return 'Supprimer $ticker ?';
  }

  @override
  String get financeStocksDividendsKept =>
      'Son historique de dividendes est conservé.';

  @override
  String get financeStocksAllHoldings => 'Toutes les positions';

  @override
  String financeStocksHoldingsCombined(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count positions combinées',
      one: '1 position combinée',
    );
    return '$_temp0';
  }

  @override
  String get financeStocksShowAll => 'Tout afficher';

  @override
  String financeStocksHoldingLine(String shares, String price, String details) {
    return '$shares @ $price$details';
  }

  @override
  String get financeStocksAtCost => '(coût)';

  @override
  String get financeStocksNoFxRate => 'pas de taux de change';

  @override
  String get financeStocksLogDividend => 'Enregistrer un dividende';

  @override
  String get financeStocksEnterHoldingFields =>
      'Saisissez un symbole, un nombre d\'actions et un coût moyen.';

  @override
  String get financeStocksTicker => 'Symbole';

  @override
  String get financeStocksTickerHint => 'p. ex. AAPL ou ASML.NL';

  @override
  String get financeStocksNameOptional => 'Nom (facultatif)';

  @override
  String get financeStocksNameHint => 'rempli automatiquement si vide';

  @override
  String get financeStocksShares => 'Actions';

  @override
  String get financeStocksSharesHint => 'p. ex. 10';

  @override
  String get financeStocksAvgCost =>
      'Coût moyen par action, dans la devise propre à l\'action';

  @override
  String get financeStocksEnterAmount => 'Saisissez le montant reçu.';

  @override
  String financeStocksDividendFrom(String ticker) {
    return 'Dividende de $ticker';
  }

  @override
  String get financeStocksLog => 'Enregistrer';

  @override
  String get financeStocksReceived => 'Reçu (après impôt, en euros)';

  @override
  String get financeStocksPaidOn => 'Versé le';

  @override
  String get financeStocksNoteOptional => 'Note (facultatif)';

  @override
  String get financeStocksAlsoIncome =>
      'L\'ajouter aussi à mon solde principal comme revenu';

  @override
  String get financeStocksDividendsTitle => 'Dividendes';

  @override
  String financeStocksDividendTotals(String thisYear, String allTime) {
    return '$thisYear cette année · $allTime au total';
  }

  @override
  String get financeStocksLogOneHint =>
      'Enregistrez-en un depuis le menu ⋮ d\'une position.';

  @override
  String get financeTxnImportData => 'Importer des données';

  @override
  String get financeTxnAddEntry => 'Ajouter une entrée';

  @override
  String get financeTxnEmptySubtitle =>
      'Ajoutez vos dépenses ou vos revenus et ils apparaîtront ici.';

  @override
  String get financeTxnNoMatchTitle => 'Aucune entrée correspondante';

  @override
  String get financeTxnNoMatchSubtitle =>
      'Essayez une autre recherche ou effacez les filtres.';

  @override
  String get financeTxnClearFilters => 'Effacer les filtres';

  @override
  String get financeTxnSearchHint => 'Rechercher notes, sociétés, catégories…';

  @override
  String get financeTxnReconcile => 'Rapprocher le relevé';

  @override
  String get financeTxnCategoryAll => 'Toutes les catégories';

  @override
  String get financeTxnPotAll => 'Toutes les cagnottes';

  @override
  String get financeTxnPot => 'Cagnotte';

  @override
  String get financeTxnAllTypes => 'Tous les types';

  @override
  String get financeTxnKindExpenses => 'Dépenses';

  @override
  String get financeTxnKindIncome => 'Revenus';

  @override
  String get financeTxnKindAllocations => 'Affectations';

  @override
  String get financeTxnExpenseTitle => 'Dépense';

  @override
  String get financeTxnAllocationTitle => 'Affectation';

  @override
  String financeTxnEntriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entrées',
      one: '1 entrée',
    );
    return '$_temp0';
  }

  @override
  String get financeTxnSummaryIn => 'Entrées';

  @override
  String get financeTxnSummaryOut => 'Sorties';

  @override
  String get financeTxnSummaryNet => 'Net';

  @override
  String get financeTxnDuplicate => 'Dupliquer';

  @override
  String syncLabelHomeLayout(String family) {
    return 'Disposition de l\'accueil ($family)';
  }

  @override
  String get syncLabelFamilyDesktop => 'bureau';

  @override
  String get syncLabelFamilyPhone => 'téléphone';

  @override
  String get syncLabelAssistantMemory => 'Mémoire de l\'assistant';

  @override
  String get syncLabelAiUsage =>
      'Utilisation de l\'IA (agents, bibliothèque et utilisation)';

  @override
  String get syncLabelQrCodes => 'Codes QR';

  @override
  String get syncLabelMindMaps => 'Cartes mentales';

  @override
  String get syncLabelWhiteboards => 'Tableaux blancs';

  @override
  String get syncLabelSteamTools => 'Outils Steam';

  @override
  String get syncLabelServerTycoon => 'Server Tycoon';

  @override
  String get syncLabelSmartHomePresets => 'Préréglages de la maison connectée';

  @override
  String get syncLabelAudioToolsEq => 'Égaliseur des outils audio';

  @override
  String get syncLabelSftpSites => 'Sites SFTP';

  @override
  String get syncLabelMediaDownloaderHistory =>
      'Historique du téléchargeur de médias';

  @override
  String get splashDevBuild => 'Version de développement';

  @override
  String get splashFreeEdition => 'Édition gratuite';

  @override
  String splashPlanEdition(String plan) {
    return 'Édition $plan';
  }

  @override
  String get p2pDebugLogEmpty => 'Pas encore de journal de débogage.';

  @override
  String p2pDebugLogReadFailed(String error) {
    return 'Impossible de lire le journal de débogage : $error';
  }

  @override
  String p2pLinkConnectionError(String error) {
    return 'Erreur de connexion : $error';
  }

  @override
  String p2pLinkInvalidFrame(String error) {
    return 'Trame invalide : $error';
  }

  @override
  String get p2pLinkMalformedControl => 'Message de contrôle malformé.';

  @override
  String get p2pLinkMalformedBlob => 'En-tête de blob malformé.';

  @override
  String get p2pLinkMalformedShareChunk =>
      'En-tête de fragment partagé malformé.';

  @override
  String get p2pLinkHandshakeNotSameAccount =>
      'Échec de la poignée de main : ce n\'est pas le même compte.';

  @override
  String get p2pSetUpSyncFirst =>
      'Configurez d\'abord la synchronisation des appareils.';

  @override
  String get p2pAccountNotReady => 'Compte pas encore prêt.';

  @override
  String p2pCouldNotStartDiscovery(String error) {
    return 'Impossible de démarrer la recherche : $error';
  }

  @override
  String p2pCouldNotResolvePeer(String name) {
    return 'Impossible de trouver $name.';
  }

  @override
  String p2pCouldNotConnectTo(String endpoint, String error) {
    return 'Connexion à $endpoint impossible ($error).';
  }

  @override
  String get p2pUnknownDevice => 'Appareil inconnu';

  @override
  String get p2pDefaultDeviceName => 'appareil luma';

  @override
  String get securityRequiresHttps =>
      'Les connexions au serveur privé exigent HTTPS.';

  @override
  String get petAutoClickerBackToPet => 'Retour au compagnon';

  @override
  String get petAutoClickerIntervalTitle => 'INTERVALLE';

  @override
  String get petAutoClickerClickTitle => 'CLIC';

  @override
  String get petAutoClickerLocationRepeatTitle => 'EMPLACEMENT & RÉPÉTITION';

  @override
  String get petAutoClickerMilliseconds => 'Millisecondes';

  @override
  String get petAutoClickerDoubleClick => 'Double clic';

  @override
  String get petAutoClickerCursor => 'Curseur';

  @override
  String get petAutoClickerFixed => 'Fixe';

  @override
  String get petAutoClickerNoPointSelected => 'Aucun point choisi';

  @override
  String petAutoClickerMoveCursor(int seconds) {
    return 'Déplacez le curseur… $seconds';
  }

  @override
  String get petAutoClickerPickPoint => 'Choisir le point';

  @override
  String get petAutoClickerStopAfterAmount => 'Arrêter après un nombre défini';

  @override
  String get petAutoClickerNumberOfClicks => 'Nombre de clics';

  @override
  String petAutoClickerClicksDone(String count) {
    return '$count CLICS';
  }

  @override
  String petAutoClickerReady(String hotKey) {
    return 'PRÊT · $hotKey';
  }

  @override
  String get secretStoreVerificationFailed =>
      'La vérification du stockage sécurisé a échoué.';

  @override
  String get secretStoreConflictingKeys =>
      'Clés de chiffrement en conflit ; la restauration nécessite une vérification.';

  @override
  String get secretStoreInvalidKey =>
      'Clé de chiffrement enregistrée invalide.';

  @override
  String get devicesSetupTitle => 'Synchroniser directement entre appareils';

  @override
  String get devicesSetupBody =>
      'Aucun serveur requis : seulement un e-mail et un mot de passe partagés entre vos appareils, utilisés uniquement pour se reconnaître en Wi-Fi. Vous avez déjà un compte cloud luma ? Connectez-vous ci-dessus, cela s\'activera automatiquement.';

  @override
  String get devicesErrorInvalidEmail => 'Saisissez une adresse e-mail valide.';

  @override
  String get devicesErrorPasswordShort =>
      'Utilisez au moins 10 caractères : ce mot de passe protège aussi vos données chiffrées.';

  @override
  String get devicesEnableTitle => 'Activer la synchronisation des appareils';

  @override
  String get devicesEnableBody =>
      'Saisissez le même e-mail et mot de passe sur chaque appareil à associer : ils ne quittent jamais cet appareil et ne touchent aucun serveur. Ils prouvent seulement que vos appareils appartiennent à la même personne.';

  @override
  String get devicesPasswordWarning =>
      'Si vous vous trompez de mot de passe en associant un second appareil, il ne sera simplement pas reconnu comme le même compte — il n\'existe aucun serveur pour le vérifier ou le réinitialiser.';

  @override
  String devicesLocalOnly(String email) {
    return 'Local uniquement — $email (aucune sauvegarde)';
  }

  @override
  String get devicesTurnOff => 'Désactiver';

  @override
  String get devicesConnectedHeading => 'Connectés';

  @override
  String get devicesNoneConnected => 'Aucun appareil connecté pour le moment.';

  @override
  String get devicesNearby => 'À proximité';

  @override
  String get devicesTurnOnDiscovery =>
      'Activez la détection pour trouver d\'autres appareils sur ce Wi-Fi.';

  @override
  String get devicesSearching =>
      'Recherche… aucun autre appareil trouvé pour le moment.';

  @override
  String get devicesSameNetworkHint =>
      'Les deux appareils doivent être sur le même réseau. Vous êtes en données mobiles (5G/4G) ? Utilisez plutôt un point d\'accès.';

  @override
  String get devicesHowHotspot => 'Comment ?';

  @override
  String get devicesConnectManually => 'Connecter manuellement…';

  @override
  String get devicesAutoSync => 'Synchro auto';

  @override
  String get devicesAutoSyncHint =>
      'La synchro auto envoie les modifications aux appareils connectés en quelques secondes. Désactivée, vous touchez un appareil et choisissez « Synchroniser maintenant ».';

  @override
  String get devicesViewDebugLog => 'Voir le journal de débogage';

  @override
  String get devicesThisDevice => 'Cet appareil';

  @override
  String devicesIpHint(String addresses) {
    return 'IP : $addresses — l\'autre appareil doit être sur le même réseau pour trouver celui-ci.';
  }

  @override
  String devicesListeningOnPort(String name, String port) {
    return '$name · à l\'écoute sur le port $port';
  }

  @override
  String get devicesSync => 'Synchroniser';

  @override
  String get devicesDisconnect => 'Déconnecter';

  @override
  String get devicesConnect => 'Connecter';

  @override
  String get devicesHotspotTitle =>
      'Pas de Wi-Fi commun ? Utilisez un point d\'accès';

  @override
  String get devicesHotspotBody =>
      'La détection ne trouve que les appareils sur le même réseau. Si votre téléphone utilise les données mobiles au lieu du Wi-Fi, il n\'y a pas de réseau local où se trouver : activez plutôt le point d\'accès du téléphone et connectez-y l\'autre appareil. Une fois que les deux sont sur ce réseau, tout fonctionne exactement de la même manière.';

  @override
  String get devicesHotspotStep1 =>
      'Sur le téléphone : Paramètres → Réseau et Internet → Point d\'accès et partage de connexion → activez le point d\'accès Wi-Fi.';

  @override
  String get devicesHotspotStep2 =>
      'Sur l\'autre appareil : connectez-vous au réseau Wi-Fi de ce point d\'accès, comme à n\'importe quel autre.';

  @override
  String get devicesHotspotStep3 =>
      'Revenez ici et activez la détection (ou désactivez-la puis réactivez-la) sur les deux appareils.';

  @override
  String get devicesGotIt => 'Compris';

  @override
  String get devicesDebugLogTitle => 'Journal de débogage P2P';

  @override
  String get devicesTurnOffTitle =>
      'Désactiver la synchronisation des appareils ?';

  @override
  String get devicesTurnOffBody =>
      'Cela déconnecte tous les appareils associés et oublie l\'identité de synchronisation de cet appareil. Vous pouvez la reconfigurer à tout moment avec le même e-mail et mot de passe.';

  @override
  String get devicesErrorHostPort =>
      'Saisissez un hôte et un port valide (1–65535).';

  @override
  String get devicesConnectManualTitle => 'Connexion manuelle';

  @override
  String get devicesManualBody =>
      'À utiliser quand la détection ne voit pas l\'autre appareil, par exemple si un pare-feu bloque mDNS. Saisissez l\'adresse affichée sur son écran Appareils.';

  @override
  String get devicesHost => 'Hôte';

  @override
  String get devicesPort => 'Port';

  @override
  String get settingsAccentLavender => 'Lavande';

  @override
  String get settingsAccentIndigo => 'Indigo';

  @override
  String get settingsAccentOcean => 'Océan';

  @override
  String get settingsAccentTeal => 'Sarcelle';

  @override
  String get settingsAccentForest => 'Forêt';

  @override
  String get settingsAccentAmber => 'Ambre';

  @override
  String get settingsAccentCoral => 'Corail';

  @override
  String get settingsAccentRose => 'Rose';

  @override
  String get settingsHomeScreenTitle => 'Votre écran d\'accueil';

  @override
  String get settingsHomeScreenSub =>
      'Organisez et redimensionnez les tuiles, épinglez vos favoris et choisissez ce que vous voyez. Les dispositions se synchronisent au sein du même format d\'appareil.';

  @override
  String get settingsHomeScreenEdit => 'Modifier l\'écran d\'accueil';

  @override
  String get syncSettingsHeadline => 'Gardez vos affaires sur chaque appareil';

  @override
  String get syncSettingsSignedOutBody =>
      'Créez un compte pour synchroniser les fonctions entre vos appareils, avec Google, GitHub, ou une adresse e-mail et un mot de passe. Tout est chiffré sur cet appareil avant d\'être envoyé ; rien n\'est synchronisé tant que vous ne l\'activez pas fonction par fonction. Vous pouvez aussi ignorer le serveur et jumeler vos appareils via votre propre réseau.';

  @override
  String get syncSettingsSessionExpired =>
      'Votre session cloud a expiré : veuillez vous reconnecter.';

  @override
  String get syncSettingsSetUpAccount => 'Configurer le compte';

  @override
  String get syncSettingsEnterCode => 'Saisir le code';

  @override
  String syncSettingsPendingEmailCode(String email) {
    return '$email est en attente d\'approbation. Saisissez le code à 6 chiffres que nous vous avons envoyé par e-mail pour finir la connexion. Jusque-là, cet appareil ne contacte pas du tout le serveur, et les extensions qui en ont besoin restent désactivées.';
  }

  @override
  String syncSettingsPendingApproval(String email) {
    return '$email attend que l\'opérateur du serveur l\'approuve. Il n\'y a rien à faire en attendant : connectez-vous simplement une fois qu\'il l\'aura fait. Jusque-là, cet appareil ne contacte pas du tout le serveur, et les extensions qui en ont besoin restent désactivées.';
  }

  @override
  String get syncSettingsResendCode => 'Renvoyer le code';

  @override
  String get syncSettingsUseDifferentEmail =>
      'Utiliser une autre adresse e-mail';

  @override
  String get syncSettingsSyncedToCloud => 'Synchronisé avec le cloud';

  @override
  String syncSettingsSyncedToCloudWith(String providers) {
    return 'Synchronisé avec le cloud — connectez-vous avec $providers';
  }

  @override
  String get syncSettingsProviderSeparator => ' ou ';

  @override
  String get syncSettingsLocalOnly =>
      'Local uniquement — synchronisation directe entre vos appareils, sans serveur';

  @override
  String get syncSettingsBackUpToServer => 'Sauvegarder sur un serveur…';

  @override
  String get syncSettingsWhatSyncs =>
      'Ce qui se synchronise depuis cet appareil';

  @override
  String get syncSettingsWhatSyncsBody =>
      'Tout est désactivé par défaut. Seul ce que vous activez ici quitte cet appareil, chiffré avec votre mot de passe avant l\'envoi. Lorsque vous activez pour la première fois une fonction qui a déjà des données synchronisées, la copie du serveur remplace celle de cet appareil.';

  @override
  String get syncSettingsAutomaticTooltip =>
      'Les préférences, la mémoire de l\'assistant et les dispositions d\'accueil des appareils correspondants se synchronisent toujours — cela ne peut pas être désactivé.';

  @override
  String get syncSettingsAlwaysOn => 'Toujours actif';

  @override
  String syncSettingsPlanSyncsOn(String label, String plan) {
    return '$label se synchronise à partir du forfait $plan.';
  }

  @override
  String syncSettingsPlanBadge(String plan) {
    return 'Forfait $plan';
  }

  @override
  String syncSettingsStopSyncingTitle(String label) {
    return 'Arrêter la synchronisation de $label ?';
  }

  @override
  String syncSettingsStopSyncingBody(String label) {
    return 'Cet appareil arrête d\'envoyer $label. Voulez-vous aussi supprimer la copie stockée sur le serveur ? (Les autres appareils qui synchronisent encore $label pourraient la renvoyer.)';
  }

  @override
  String get syncSettingsKeepOnServer => 'Conserver sur le serveur';

  @override
  String get syncSettingsDeleteFromServer => 'Supprimer du serveur';

  @override
  String syncSettingsPlanNeededTitle(String plan) {
    return 'Forfait $plan requis';
  }

  @override
  String syncSettingsPlanNeededBody(String label, String plan) {
    return '$label se synchronise avec le serveur à partir du forfait $plan. Cela continue de fonctionner sur cet appareil dans tous les cas : seule la synchronisation entre appareils nécessite le forfait.';
  }

  @override
  String get syncSettingsSeePlans => 'Voir les forfaits';

  @override
  String get syncSettingsLimitTitle => 'Limite de synchronisation atteinte';

  @override
  String syncSettingsLimitBody(int limit) {
    String _temp0 = intl.Intl.pluralLogic(
      limit,
      locale: localeName,
      other: '$limit fonctionnalités',
      one: '1 fonctionnalité',
    );
    return 'Votre forfait permet de synchroniser jusqu\'à $_temp0 avec le serveur à la fois. Désactivez-en une ou passez à un forfait supérieur pour en synchroniser davantage.';
  }

  @override
  String get syncSettingsUpgradePlan => 'Passer à un forfait supérieur';

  @override
  String get syncSettingsStorage => 'Stockage';

  @override
  String get syncSettingsSyncToSeeUsage =>
      'Synchronisez pour voir l\'utilisation';

  @override
  String syncSettingsUsedOf(String used, String quota) {
    return '$used sur $quota utilisés';
  }

  @override
  String get syncSettingsNothingSavedYet =>
      'Rien n\'est encore enregistré sur le serveur : activez un élément ci-dessous pour le sauvegarder.';

  @override
  String get syncSettingsSyncing => 'Synchronisation…';

  @override
  String get syncSettingsSyncFailed => 'Échec de la synchronisation.';

  @override
  String get syncSettingsNotSyncedYet => 'Pas encore synchronisé.';

  @override
  String syncSettingsLastSynced(String time) {
    return 'Dernière synchronisation : $time';
  }

  @override
  String get syncSettingsSyncNow => 'Synchroniser maintenant';

  @override
  String get syncSettingsSyncAll => 'Tout synchroniser';

  @override
  String get syncSettingsChangePassword => 'Changer le mot de passe';

  @override
  String get syncSettingsCurrentPassword => 'Mot de passe actuel';

  @override
  String get syncSettingsNewPassword => 'Nouveau mot de passe';

  @override
  String get syncSettingsConfirmNewPassword =>
      'Confirmer le nouveau mot de passe';

  @override
  String get syncSettingsPasswordReencryptNote =>
      'Toutes les données synchronisées sont rechiffrées avec le nouveau mot de passe. Les autres appareils vous demanderont de vous reconnecter.';

  @override
  String get syncSettingsPasswordTooShort => 'Utilisez au moins 10 caractères.';

  @override
  String get syncSettingsPasswordMismatch =>
      'Les nouveaux mots de passe ne correspondent pas.';

  @override
  String get syncSettingsDevicesSignedInTitle => 'Appareils connectés';

  @override
  String get syncSettingsDevicesSignedIn => 'Appareils connectés…';

  @override
  String get syncSettingsAskDeleteData =>
      'Demander la suppression de mes données…';

  @override
  String get syncSettingsDeleteAccount => 'Supprimer le compte…';

  @override
  String get syncSettingsDataSyncsDirectly =>
      'Ces données se synchronisent directement avec les appareils jumelés : voir Appareils ci-dessous pour en connecter un ou le désactiver.';

  @override
  String get syncSettingsRecoveryKeySetUp =>
      'Clé de récupération configurée : oublier votre mot de passe ne vous fera pas perdre vos données synchronisées.';

  @override
  String get syncSettingsRecoveryKeyMissing =>
      'Aucune clé de récupération. Si vous oubliez votre mot de passe, le réinitialiser efface vos données synchronisées sur le serveur.';

  @override
  String get syncSettingsManage => 'Gérer…';

  @override
  String get syncSettingsSetUp => 'Configurer…';

  @override
  String get syncSettingsRecoveryKeyCopied => 'Clé de récupération copiée.';

  @override
  String get syncSettingsRecoveryKeyWriteDown =>
      'Notez-la ou conservez-la dans un gestionnaire de mots de passe. luma ne garde pas de copie et ne pourra pas la réafficher.';

  @override
  String get syncSettingsRecoveryKeyFooter =>
      'Si vous oubliez votre mot de passe, saisissez cette clé sur l\'écran de réinitialisation et vos données synchronisées resteront.';

  @override
  String get syncSettingsRecoveryKeySaved => 'Je l\'ai enregistrée';

  @override
  String get syncSettingsRecoveryKeyTitle => 'Clé de récupération';

  @override
  String get syncSettingsYourRecoveryKey => 'Votre clé de récupération';

  @override
  String get syncSettingsRecoveryHasKeyBody =>
      'Ce compte a une clé de récupération. Si vous l\'avez perdue, créez-en une nouvelle : l\'ancienne cesse de fonctionner dès que vous le faites.';

  @override
  String get syncSettingsRecoveryNoKeyBody =>
      'Vos données synchronisées sont chiffrées avec une clé issue de votre mot de passe, donc personne, pas même le serveur, ne peut les lire. Cela signifie aussi qu\'un mot de passe oublié les efface en général.\n\nUne clé de récupération est un second moyen d\'accès. Conservez-la en lieu sûr : une réinitialisation du mot de passe conservera alors toutes vos données synchronisées.';

  @override
  String get syncSettingsMakeNewKey => 'Créer une nouvelle clé';

  @override
  String get syncSettingsCreateRecoveryKey => 'Créer une clé de récupération';

  @override
  String get syncSettingsUnknownDevice => 'Appareil inconnu';

  @override
  String get syncSettingsThisDevice => 'Cet appareil';

  @override
  String syncSettingsSignedInOn(String date) {
    return 'Connecté le $date';
  }

  @override
  String get syncSettingsCurrentSession => 'Actuel';

  @override
  String get syncSettingsRevoke => 'Révoquer';

  @override
  String get syncSettingsNoOtherSessions => 'Aucune autre session active.';

  @override
  String get syncSettingsDeletionPending =>
      'Suppression des données demandée : en attente de la décision de l\'opérateur du serveur.';

  @override
  String get syncSettingsDeletionDeclined =>
      'L\'opérateur du serveur a refusé votre demande de suppression de données.';

  @override
  String syncSettingsDeletionSentNothingDeleted(String date) {
    return 'Envoyée le $date. Rien n\'a encore été supprimé.';
  }

  @override
  String syncSettingsDeletionDecided(String date) {
    return 'Décidée le $date.';
  }

  @override
  String syncSettingsDeletionDecidedWithNote(String date, String note) {
    return 'Décidée le $date. Message : « $note »';
  }

  @override
  String get syncSettingsWithdraw => 'Retirer';

  @override
  String get syncSettingsDeletionWithdrawn => 'Demande de suppression retirée.';

  @override
  String get syncSettingsAskDeleteTitle =>
      'Demander la suppression de mes données';

  @override
  String get syncSettingsDeletionPendingBody =>
      'Vous avez déjà une demande en attente de décision. Retirez-la depuis le panneau Synchronisation et compte si vous souhaitez en envoyer une autre.';

  @override
  String get syncSettingsDeletionRequestBody =>
      'Cela envoie à l\'opérateur du serveur une demande de suppression de votre compte et de toutes les copies synchronisées conservées par le serveur. Rien n\'est supprimé tant qu\'il ne l\'a pas acceptée, et les données de vos appareils ne sont jamais touchées.';

  @override
  String get syncSettingsWhyOptional => 'Pourquoi ? (facultatif)';

  @override
  String get syncSettingsWhyHint =>
      'Vous n\'êtes pas obligé d\'indiquer une raison.';

  @override
  String get syncSettingsSendRequest => 'Envoyer la demande';

  @override
  String get syncSettingsRequestSent =>
      'Demande envoyée à l\'opérateur du serveur.';

  @override
  String get syncSettingsDeleteAccountTitle => 'Supprimer le compte ?';

  @override
  String get syncSettingsDeleteAccountBody =>
      'Cela supprime définitivement votre compte et toutes les copies synchronisées du serveur. Les données de vos appareils ne sont pas touchées. Saisissez votre mot de passe pour confirmer.';

  @override
  String get syncSettingsDeleteForever => 'Supprimer définitivement';

  @override
  String syncCollectionHomeLayout(Object family) {
    return 'Disposition de l\'accueil ($family)';
  }

  @override
  String get syncCollectionSettings => 'Paramètres';

  @override
  String get syncCollectionAssistantMemory => 'Mémoire de l\'assistant';

  @override
  String get syncCollectionNotes => 'Notes';

  @override
  String get syncCollectionFinance => 'Finances';

  @override
  String get syncCollectionPasswords => 'Mots de passe';

  @override
  String get syncCollectionCalendar => 'Calendrier';

  @override
  String get syncCollectionBulletinBoard => 'Tableau d\'affichage';

  @override
  String get syncCollectionQrCodes => 'Codes QR';

  @override
  String get syncCollectionCardWallet => 'Portefeuille de cartes';

  @override
  String get syncCollectionErrands => 'Courses et tâches';

  @override
  String get syncCollectionDataManagement => 'Gestion des données';

  @override
  String get syncCollectionMoodJournal => 'Journal d\'humeur';

  @override
  String get syncCollectionAiUsage =>
      'Utilisation de l\'IA (agents, bibliothèque et usage)';

  @override
  String get syncCollectionSchool => 'École';

  @override
  String get syncCollectionMindMaps => 'Cartes mentales';

  @override
  String get syncCollectionWhiteboards => 'Tableaux blancs';

  @override
  String get syncCollectionTextLibrary => 'Bibliothèque de textes';

  @override
  String get syncCollectionPriceTracker => 'Suivi des prix';

  @override
  String get syncCollectionWifiSpeedTest => 'Test de débit Wi-Fi';

  @override
  String get syncCollectionGroceries => 'Courses alimentaires';

  @override
  String get syncCollectionAirlineTycoon => 'Magnat de l’aviation';

  @override
  String get syncCollectionSteamTools => 'Outils Steam';

  @override
  String get syncCollectionServerTycoon => 'Magnat de l’hébergement serveur';

  @override
  String get syncCollectionRecipeBook => 'Livre de recettes';

  @override
  String get syncCollectionMinecraftLauncher => 'Lanceur Minecraft';

  @override
  String get syncCollectionUsage => 'Utilisation';

  @override
  String get syncCollectionFreeSketch => 'Croquis libre';

  @override
  String get syncCollectionSmartHomePresets =>
      'Préréglages de maison connectée';

  @override
  String get syncCollectionAudioToolsEq => 'Égaliseur Audio Tools';

  @override
  String get syncCollectionAutoClicker => 'Clic automatique';

  @override
  String get syncCollectionCalculator => 'Calculatrice';

  @override
  String get syncCollectionWorthCounter => 'Compteur de valeur';

  @override
  String get syncCollectionNfcTagEditor => 'Éditeur de tags NFC';

  @override
  String get syncCollectionSftpSites => 'Sites SFTP';

  @override
  String get syncCollectionMediaDownloaderHistory =>
      'Historique des téléchargements multimédias';

  @override
  String get syncCollectionTransportTracker => 'Suivi des transports';

  @override
  String get syncSettingsDeletionReasonLabel => 'Pourquoi ? (facultatif)';

  @override
  String get syncSettingsDeletionReasonHint =>
      'Vous n\'avez pas à donner de raison.';

  @override
  String get sceneAirlineTycoonDismissAwayReport =>
      'Fermer le rapport d’absence';

  @override
  String get sceneAirlineTycoonDismissMessage => 'Fermer le message';

  @override
  String get sceneAirlineTycoonConfirmDemolition => 'Confirmer la démolition';

  @override
  String get sceneAirlineTycoonEarlier => 'Plus tôt';

  @override
  String get sceneAirlineTycoonDragOntoAStand =>
      'Glisser vers une aire de stationnement';

  @override
  String get sceneAirlineTycoonJetBridge => 'Passerelle d’embarquement';

  @override
  String get sceneAirlineTycoonCancelFlight => 'Annuler le vol';

  @override
  String get sceneAirlineTycoonLumaAirport => 'Aéroport Luma';

  @override
  String get sceneAirlineTycoonPreparingYourAirport =>
      'Préparation de votre aéroport…';

  @override
  String get sceneAirlineTycoonScenePreviewNoSave =>
      'APERÇU DE LA SCÈNE · SANS SAUVEGARDE';

  @override
  String get sceneAirlineTycoonAirport => 'Aéroport';

  @override
  String get sceneAirlineTycoonDay10000 => 'JOUR 1 · 00:00';

  @override
  String get sceneAirlineTycoonResumeAirportSpace =>
      'Reprendre l’aéroport (Espace)';

  @override
  String get sceneAirlineTycoonResumeAirport => 'Reprendre l’aéroport';

  @override
  String get sceneAirlineTycoonSimulationSpeed => 'Vitesse de simulation';

  @override
  String get sceneAirlineTycoonNormalSpeed1 => 'Vitesse normale (1)';

  @override
  String get sceneAirlineTycoonFast2 => 'Rapide (2)';

  @override
  String get sceneAirlineTycoonFastest3 => 'Vitesse maximale (3)';

  @override
  String get sceneAirlineTycoonViewMode => 'Mode d’affichage';

  @override
  String get sceneAirlineTycoonAirfieldRunwaysStandsAndBuildingsT =>
      'Terrain d’aviation : pistes, stationnements et bâtiments (T)';

  @override
  String get sceneAirlineTycoonAirportModeZoomInOnTheTerminalAndFurnishIt =>
      'Mode aéroport : zoomer sur le terminal et aménager ses halls (T)';

  @override
  String get sceneAirlineTycoonFitAirport => 'Afficher tout l’aéroport';

  @override
  String get sceneAirlineTycoonResetCamera => 'Réinitialiser la caméra';

  @override
  String get sceneAirlineTycoonTerminalCutawayC =>
      'Vue en coupe du terminal (C)';

  @override
  String get sceneAirlineTycoonTerminalCutaway => 'Vue en coupe du terminal';

  @override
  String get sceneAirlineTycoonConstructionGridG =>
      'Grille de construction (G)';

  @override
  String get sceneAirlineTycoonConstructionGrid => 'Grille de construction';

  @override
  String get sceneAirlineTycoonPerformanceStatsF3 =>
      'Statistiques de performance (F3)';

  @override
  String get sceneAirlineTycoonPerformanceStats =>
      'Statistiques de performance';

  @override
  String get sceneAirlineTycoonClosePanelEsc => 'Fermer le panneau (Échap)';

  @override
  String get sceneAirlineTycoonClosePanel => 'Fermer le panneau';

  @override
  String get sceneAirlineTycoonYourFirstDeparture => 'Votre premier départ';

  @override
  String get sceneAirlineTycoonSignARegionalAirlineOrOpenYourOwnRoute =>
      'Signer avec une compagnie régionale ou ouvrir votre propre ligne.';

  @override
  String get sceneAirlineTycoonCheckTheFlightSchedule =>
      'Consulter le programme des vols.';

  @override
  String get sceneAirlineTycoonResumeYourAirportAndFollowTheTurnaround =>
      'Reprendre votre aéroport et suivre la rotation de l’avion.';

  @override
  String get sceneAirlineTycoonMeetTheAirlines =>
      'Rencontrer les compagnies aériennes';

  @override
  String get sceneAirlineTycoonRotate90R => 'Tourner de 90° (R)';

  @override
  String get sceneAirlineTycoonCancelConstructionEsc =>
      'Annuler la construction (Échap)';

  @override
  String get sceneAirlineTycoonCancelConstruction => 'Annuler la construction';

  @override
  String get sceneAirlineTycoonAirportPanels => 'Panneaux de l’aéroport';

  @override
  String get sceneAirlineTycoonCloseEsc => 'Fermer (Échap)';

  @override
  String get sceneAirlineTycoonCloseBuildingWindow =>
      'Fermer la fenêtre du bâtiment';

  @override
  String get sceneAirlineTycoonBuildingSections => 'Sections du bâtiment';

  @override
  String get sceneAirlineTycoonNorth => 'Nord';

  @override
  String get sceneAirlineTycoonN => 'N ↑';

  @override
  String get sceneTextLibraryBuildingYourLibrary =>
      'Construction de votre bibliothèque…';

  @override
  String get sceneTextLibraryPreviousShelf => 'Étagère précédente';

  @override
  String get sceneTextLibraryNextShelf => 'Étagère suivante';

  @override
  String get sceneTextLibraryForward => 'Avancer';

  @override
  String get sceneTextLibraryTurnLeft => 'Tourner à gauche';

  @override
  String get sceneTextLibraryTurnRight => 'Tourner à droite';

  @override
  String get sceneTextLibraryPreviousPage => 'Page précédente';

  @override
  String get sceneTextLibraryNextPage => 'Page suivante';

  @override
  String syncServiceSyncLimitExceeded(Object limit) {
    return 'Votre offre permet de synchroniser jusqu\'à $limit fonctionnalités à la fois. Passez à une offre supérieure pour en synchroniser davantage.';
  }

  @override
  String syncServicePlanRequired(Object label, Object plan) {
    return '$label se synchronise avec l\'offre $plan ou une offre supérieure.';
  }

  @override
  String get syncOAuthSignInCancelled => 'Connexion annulée.';

  @override
  String get syncOAuthBrowserTimeout =>
      'Le navigateur a mis trop de temps à répondre. Réessayez.';

  @override
  String get syncOAuthDidNotComplete => 'La connexion n\'a pas abouti.';

  @override
  String get syncServiceApprovalNotPending =>
      'Aucun compte de cet appareil n\'attend une approbation.';

  @override
  String get syncServiceEmailVerificationNotPending =>
      'Aucune vérification par e-mail n\'est en attente sur cet appareil.';

  @override
  String get syncServiceRecoveryKeyIncomplete =>
      'La clé de récupération est incomplète. Elle comporte 8 groupes de 4 lettres et chiffres.';

  @override
  String get syncServiceNoRecoveryKey =>
      'Ce compte n\'a pas de clé de récupération. Laissez le champ vide pour continuer la réinitialisation ; les copies synchronisées sur le serveur seront effacées.';

  @override
  String get syncServiceRecoveryKeyMismatch =>
      'Cette clé de récupération ne correspond pas à ce compte. Aucune modification n\'a été effectuée.';

  @override
  String get syncServiceApprovedAccountRequired =>
      'Connectez-vous d\'abord avec un compte approuvé.';

  @override
  String get syncServiceWrongDevicePassword =>
      'Mot de passe incorrect pour l\'identité de synchronisation existante de cet appareil.';

  @override
  String get syncServicePasswordReencryptFailed =>
      'Le mot de passe a changé, mais certaines données synchronisées n\'ont pas pu être rechiffrées. L\'ancienne clé a été conservée dans le stockage sécurisé de cet appareil pour permettre la récupération. Gardez cet appareil et ses données.';

  @override
  String get syncCollectionInvalidSnapshot => 'Instantané non valide.';

  @override
  String get syncCollectionSnapshotNewerVersion =>
      'Cet instantané provient d\'une version plus récente de l\'application. Mettez d\'abord à jour l\'application sur cet appareil.';

  @override
  String syncCollectionPasswordDecryptFailed(Object entryId) {
    return 'Impossible de déchiffrer l\'entrée de mot de passe $entryId pour la synchronisation (données corrompues ou fichier de clé modifié).';
  }

  @override
  String get syncCollectionTotpDecryptFailed =>
      'Impossible de déchiffrer l\'entrée TOTP pour la synchronisation.';

  @override
  String get syncCollectionSnapshotMissingPassword =>
      'Mot de passe manquant dans l\'instantané du coffre.';

  @override
  String get syncCollectionSnapshotUnreadableTotp =>
      'Le TOTP de l\'instantané du coffre est illisible.';

  @override
  String get syncSnapshotCollectionMismatch =>
      'L\'instantané ne correspond pas à cette collection.';

  @override
  String get securityUnsupportedEncryptedData =>
      'Données chiffrées non prises en charge.';

  @override
  String get securityInvalidEncryptionKeyLength =>
      'Longueur de clé de chiffrement non valide.';

  @override
  String get cs2MarketTitle => 'Marché CS2';

  @override
  String get aiDetectorVerdictGeneratedClaude => 'Généré par Claude';

  @override
  String get aiDetectorVerdictVeryLikelyHuman =>
      'Très probablement écrit par une personne';

  @override
  String get aiDetectorVerdictLikelyHuman =>
      'Probablement écrit par une personne';

  @override
  String get aiDetectorVerdictMixed => 'Signaux mitigés';

  @override
  String get aiDetectorVerdictLikelyAi => 'Probablement généré par l\'IA';

  @override
  String get aiDetectorVerdictVeryLikelyAi =>
      'Très probablement généré par l\'IA';

  @override
  String get aiDetectorHighlightEmDash => 'Tiret cadratin';

  @override
  String get aiDetectorHighlightPassiveVoice => 'Voix passive';

  @override
  String get aiDetectorHighlightTransitionOpener =>
      'Début par un mot de transition';

  @override
  String get aiDetectorHighlightAiFavoritePhrase =>
      'Expression typique de l\'IA';

  @override
  String get aiDetectorHighlightAssistantBoilerplate =>
      'Formulation standard d\'assistant';

  @override
  String get aiDetectorHighlightClaudeSignature => 'Signature Claude';

  @override
  String get aiDetectorHighlightClaudeWatermark => 'Filigrane Claude';

  @override
  String get airportErrorUnknownZone => 'Zone inconnue.';

  @override
  String get airportErrorLargerFloor =>
      'Tracer une zone de sol plus grande : au moins 2 m.';

  @override
  String get airportErrorNoPaintedZone => 'Aucune zone tracée ici.';

  @override
  String get airportErrorZoneInsideTerminal =>
      'Définir la zone à l’intérieur du terminal.';

  @override
  String get airportErrorBuildingGone => 'Ce bâtiment n’existe plus.';

  @override
  String get airportErrorHighestLevel => 'Le niveau maximal est déjà atteint.';

  @override
  String get airportErrorUpgradeCash =>
      'Fonds insuffisants pour cette amélioration.';

  @override
  String get airportErrorUnknownBuilding => 'Bâtiment inconnu.';

  @override
  String get airportErrorBoundary =>
      'Construire dans les limites de l’aéroport (±4 km).';

  @override
  String get airportErrorBeyondLand =>
      'Le bâtiment dépasse le terrain de l’aéroport.';

  @override
  String get airportErrorUseTerminalZones =>
      'Construire un terminal et diviser son sol en zones.';

  @override
  String get airportErrorBridgeMainHall =>
      'Pour une passerelle, ce stationnement doit toucher le hall principal.';

  @override
  String get airportErrorConstructionCash =>
      'Fonds insuffisants pour cette construction.';

  @override
  String get airportErrorFinishOperations =>
      'Annuler les vols imminents et terminer les opérations en cours avant de modifier l’infrastructure.';

  @override
  String get airportErrorRemoveFurnishings =>
      'Retirer d’abord le mobilier du terminal.';

  @override
  String get airportErrorUnknownVehicle => 'Véhicule inconnu.';

  @override
  String get airportErrorVehicleCost =>
      'Un véhicule de service coûte 120 000 €.';

  @override
  String get airportErrorSelectDepot =>
      'Sélectionner un dépôt pour acheter des véhicules de service.';

  @override
  String get airportErrorConnectDepot =>
      'Relier d’abord ce dépôt à une voie de service.';

  @override
  String get airportErrorSelectConnectedDepot =>
      'Sélectionner un dépôt connecté pour acheter des véhicules de service.';

  @override
  String get airportErrorOfferGone => 'Cette offre n’est plus disponible.';

  @override
  String get airportErrorContractFlying =>
      'Cette compagnie exécute encore son contrat actuel.';

  @override
  String get airportErrorChooseStand =>
      'Choisir une aire de stationnement pour l’avion.';

  @override
  String get airportErrorStandRunway =>
      'Ce stationnement n’est pas relié à une piste assez longue.';

  @override
  String get airportErrorPlanAhead =>
      'Planifier au moins 30 minutes à l’avance.';

  @override
  String get airportErrorUnknownFlight => 'Vol inconnu.';

  @override
  String get airportErrorMoveBeforeArrival =>
      'Seuls les vols pas encore arrivés peuvent être déplacés.';

  @override
  String get airportErrorAircraftBusy =>
      'L’avion est occupé par un autre vol à ce moment.';

  @override
  String get airportErrorUnscheduleBeforeArrival =>
      'Seuls les vols pas encore arrivés peuvent être retirés du programme.';

  @override
  String get airportErrorNoContract => 'Aucun contrat actif.';

  @override
  String get airportErrorAllFlightsPlanned =>
      'Tous les vols de ce contrat sont programmés.';

  @override
  String get airportErrorChooseAircraftRoute =>
      'Choisir un avion disponible et une ligne active.';

  @override
  String get airportErrorDepartureWindow =>
      'Choisir un départ entre 90 minutes et sept jours à partir de maintenant.';

  @override
  String get airportErrorMaintenance => 'Cet avion est en maintenance.';

  @override
  String get airportErrorUnknownDestination => 'Destination inconnue.';

  @override
  String get airportErrorBeyondRange =>
      'Cette destination est hors de portée de l’avion.';

  @override
  String get airportErrorAircraftScheduled =>
      'L’avion est déjà programmé ou revient encore d’un autre vol.';

  @override
  String get airportErrorNoFreeStand =>
      'Aucun stationnement compatible et connecté n’est libre sur ce créneau.';

  @override
  String get airportErrorFlightClosed => 'Ce vol est déjà clôturé.';

  @override
  String get airportErrorFinishTurnaround =>
      'Une rotation en cours doit se terminer avant d’être supprimée.';

  @override
  String get airportErrorSaveVersion =>
      'Version de sauvegarde de l’aéroport non prise en charge';

  @override
  String aiDetectorNeedsSentences(int count) {
    return 'Il faut au moins $count phrases pour effectuer la mesure.';
  }

  @override
  String aiDetectorNeedsWords(int count) {
    return 'Il faut au moins $count mots pour effectuer la mesure.';
  }

  @override
  String aiDetectorNeedsLines(int count) {
    return 'Il faut au moins $count lignes pour effectuer la mesure.';
  }

  @override
  String aiDetectorNeedsParagraphs(int count) {
    return 'Il faut au moins $count paragraphes pour effectuer la mesure.';
  }

  @override
  String get aiDetectorTriggerBurstiness =>
      'Variation de la longueur des phrases';

  @override
  String get aiDetectorTriggerBurstinessStrong =>
      'Longueur des phrases très uniforme';

  @override
  String get aiDetectorTriggerPhraseFound => 'Expressions typiques de l\'IA';

  @override
  String get aiDetectorTriggerPhraseNone =>
      'Aucune expression typique de l\'IA';

  @override
  String get aiDetectorTriggerExtremesFound => 'Aucune phrase courte ou longue';

  @override
  String get aiDetectorTriggerExtremesNone =>
      'Les phrases couvrent les deux extrêmes';

  @override
  String get aiDetectorTriggerImpersonal => 'Style impersonnel';

  @override
  String get aiDetectorTriggerPersonal => 'Style personnel';

  @override
  String get aiDetectorTriggerChatFound =>
      'Mise en forme d\'une réponse de chat';

  @override
  String get aiDetectorTriggerChatNone =>
      'Aucune mise en forme de réponse de chat';

  @override
  String get aiDetectorTriggerContrastFound =>
      'Constructions d\'opposition corrective';

  @override
  String get aiDetectorTriggerContrastNone =>
      'Aucune habitude d\'opposition corrective';

  @override
  String get aiDetectorTriggerOpeners => 'Phrases ouvertes par un connecteur';

  @override
  String get aiDetectorTriggerContractionsMissing => 'Contractions manquantes';

  @override
  String get aiDetectorTriggerContractionsNatural =>
      'Usage naturel des contractions';

  @override
  String get aiDetectorTriggerEmDash => 'Usage excessif du tiret cadratin';

  @override
  String get aiDetectorTriggerPassive => 'Densité de la voix passive';

  @override
  String get aiDetectorTriggerParagraphsUniform => 'Paragraphes uniformes';

  @override
  String get aiDetectorTriggerParagraphsVaried => 'Paragraphes variés';

  @override
  String get aiDetectorTriggerRepeatedOpeners => 'Débuts de phrase répétés';

  @override
  String get aiDetectorTriggerWatermarkFound => 'Filigrane Claude détecté';

  @override
  String get aiDetectorTriggerClaudeSignature =>
      'Signature Claude dans le texte';

  @override
  String get aiDetectorTriggerAssistantBoilerplate =>
      'Formulation standard d\'assistant';

  @override
  String get aiDetectorTriggerNoWatermark => 'Aucun filigrane Claude';

  @override
  String aiDetectorWatermarkExplanation(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count caractères invisibles',
      one: 'un caractère invisible',
    );
    return 'Le texte contient $_temp0 qui ne prend pas de place à l’écran, mais accompagne le texte à chaque copier-coller. La saisie ne le produit pas. luma interprète cette charge cachée comme le filigrane de Claude ; le verdict nomme donc Claude plutôt que de rester sur « généré par IA ».';
  }

  @override
  String get aiDetectorSignatureExplanation =>
      'Le texte identifie son auteur : il nomme Claude ou Anthropic dans un contexte de produit, et non comme le nom d’une personne. Cette attribution directe prime sur les statistiques de style ci-dessous.';

  @override
  String get aiDetectorAssistantExplanation =>
      'Les formulations typiques d’un assistant de chat indiquent que le texte provient d’une conversation avec un modèle. Elles n’identifient pas lequel ; le verdict reste anonyme et seul le score augmente.';

  @override
  String get aiDetectorNoWatermarkExplanation =>
      'Aucun caractère de filigrane invisible ni autoréférence à Claude. Cela ne garantit pas une origine humaine : beaucoup de textes générés ne portent aucune signature. Les vérifications de style restent donc utiles.';

  @override
  String get aiDetectorBurstinessExplanationHigh =>
      'Les phrases ont presque toutes la même longueur. L’écriture humaine alterne généralement phrases courtes et longues ; cette régularité suggère un générateur au rythme constant.';

  @override
  String get aiDetectorBurstinessExplanationLow =>
      'La longueur des phrases varie naturellement, comme chez les auteurs humains, ce que les modèles imitent difficilement.';

  @override
  String get aiDetectorPhraseExplanationHigh =>
      'Ces mots et constructions apparaissent bien plus souvent dans les textes générés que dans l’écriture humaine courante. Chaque étiquette ci-dessous correspond à une occurrence littérale de votre texte.';

  @override
  String get aiDetectorPhraseExplanationLow =>
      'Aucune expression typique des modèles n’a été trouvée. Ce n’est pas une preuve en faveur du texte : beaucoup de textes générés les évitent. Ce contrôle s’abstient plutôt que de réduire le score.';

  @override
  String get aiDetectorExtremesExplanationHigh =>
      'Aucune phrase n’est vraiment courte ni vraiment longue. Les personnes utilisent naturellement les deux ; un générateur tend à rester dans une plage moyenne sûre.';

  @override
  String get aiDetectorExtremesExplanationLow =>
      'Le texte contient des phrases brèves et longues, comme l’écriture humaine non retouchée.';

  @override
  String get aiDetectorVoiceExplanationHigh =>
      'On trouve à peine « je », « nous » ou « vous », du langage familier ou des questions directes. Les modèles adoptent souvent ce registre distant. L’écriture humaine formelle aussi ; ce signal pèse donc moins que le rythme.';

  @override
  String get aiDetectorVoiceExplanationLow =>
      'Le texte utilise une voix personnelle, avec des pronoms et un langage familier que les modèles emploient rarement sans consigne.';

  @override
  String get aiDetectorFormattingExplanationHigh =>
      'Le texte ressemble à une réponse de chat : titres, listes et étiquettes en gras. Cette structure reste présente après un copier-coller ailleurs.';

  @override
  String get aiDetectorFormattingExplanationLow =>
      'Le texte ressemble à de la prose plutôt qu’à une réponse de chat mise en forme. Beaucoup de textes générés sont aussi de la prose ; ce signal ne compte donc que lorsqu’il se déclenche.';

  @override
  String get aiDetectorContrastExplanationHigh =>
      'Les phrases qui posent une réponse pour la réfuter — « pas seulement X, mais Y », « la vraie question est » — sont un procédé fréquent des modèles pour paraître perspicaces.';

  @override
  String get aiDetectorContrastExplanationLow =>
      'Aucune construction de mise en place puis de réfutation typique des modèles n’a été trouvée. Leur absence ne prouve rien à elle seule.';

  @override
  String aiDetectorOpenersExplanationHigh(int used, int total) {
    return '$used phrases sur $total commencent par un connecteur formel. Les textes de modèles ouvrent les sections avec « Moreover, » et « Furthermore, » bien plus souvent que les personnes.';
  }

  @override
  String get aiDetectorOpenersExplanationLow =>
      'Les phrases ne s’appuient pas sur des connecteurs formels au début. Cela ne suffit pas à identifier leur auteur.';

  @override
  String get aiDetectorContractionsExplanationHigh =>
      'Il y a très peu de contractions anglaises comme « don’t » ou « it’s ». Les textes générés utilisent souvent des formes complètes plus rigides.';

  @override
  String get aiDetectorContractionsExplanationLow =>
      'Les contractions apparaissent à une fréquence naturelle chez les humains.';

  @override
  String get aiDetectorDashExplanationHigh =>
      'Les tirets cadratins sont bien plus fréquents que dans la prose humaine habituelle, une habitude connue des modèles.';

  @override
  String get aiDetectorDashExplanationLow =>
      'L’usage des tirets cadratins reste dans la plage normale.';

  @override
  String get aiDetectorDashExplanationNone =>
      'Aucun tiret cadratin ; cela ne prouve rien dans un sens ou dans l’autre.';

  @override
  String get aiDetectorPassiveExplanationHigh =>
      'L’usage fréquent du passif, comme « was designed to » ou « is considered », masque l’auteur de l’action ; c’est courant dans les textes générés.';

  @override
  String get aiDetectorPassiveExplanationLow =>
      'Le passif reste à un niveau normal, ce qui est aussi vrai de la plupart des textes générés.';

  @override
  String get aiDetectorParagraphExplanationHigh =>
      'Les paragraphes ont presque tous la même taille, comme un contenu réparti uniformément. Les brouillons humains alternent davantage le court et le long.';

  @override
  String get aiDetectorParagraphExplanationLow =>
      'La longueur des paragraphes varie naturellement.';

  @override
  String aiDetectorRepeatedOpenersExplanationHigh(String word, int count) {
    return '« $word » ouvre $count phrases. Les auteurs humains répètent rarement autant la même ouverture ; la génération par modèles le fait.';
  }

  @override
  String get aiDetectorRepeatedOpenersExplanationLow =>
      'Les débuts de phrases sont variés, comme dans la plupart des textes, quelle que soit leur origine.';

  @override
  String get aiDetectorPhraseNoMatches => 'aucune correspondance';

  @override
  String get aiDetectorPhraseSoftMatch => 'faible';

  @override
  String aiDetectorPhraseMatchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count correspondances',
      one: '1 correspondance',
    );
    return '$_temp0';
  }

  @override
  String aiDetectorPhraseWeightedRate(String rate) {
    return '$rate pondérées pour 1000 mots';
  }

  @override
  String get aiDetectorEvidenceNoHiddenSignature =>
      'aucun caractère caché ni signature';

  @override
  String airportErrorNoUpgrade(String building) {
    return '$building ne propose pas cette amélioration.';
  }

  @override
  String airportErrorPlaceInside(String hall) {
    return 'Placer ceci entièrement dans $hall.';
  }

  @override
  String airportErrorOverlap(String building) {
    return 'Ceci chevauche $building.';
  }

  @override
  String airportErrorConnectedServiceFirst(String building) {
    return 'Prévoir d’abord $building connecté.';
  }

  @override
  String airportErrorNoHaulStand(String haul) {
    return 'Aucun stationnement connecté pour $haul avec une piste assez longue.';
  }

  @override
  String airportErrorStandAircraft(String building, String aircraft) {
    return '$building ne peut pas accueillir le $aircraft.';
  }

  @override
  String airportErrorHorizon(int days) {
    return 'Le programme ne couvre que les $days prochains jours.';
  }

  @override
  String airportErrorCarrierSlot(String carrier, String slot) {
    return '$carrier souhaite que ce vol commence dans $slot.';
  }

  @override
  String airportErrorStandBusy(String time) {
    return 'Ce stationnement est occupé à $time.';
  }

  @override
  String airportErrorCarrierFlightsSlot(String carrier, String slot) {
    return '$carrier souhaite que ses vols commencent dans $slot.';
  }

  @override
  String airportErrorStartDay(int day) {
    return 'Cette série doit commencer au plus tard au jour $day.';
  }

  @override
  String airportErrorCharterDay(int day) {
    return 'Les vols charter doivent partir au plus tard au jour $day.';
  }

  @override
  String airportErrorConnectedServiceRequired(String building) {
    return 'Un bâtiment $building connecté est requis.';
  }

  @override
  String get airportArrivalHall => 'hall d’entrée';

  @override
  String get airportDepartureHall => 'hall de sortie';

  @override
  String get airportMainHall => 'hall principal';

  @override
  String get airportTerminal => 'terminal';

  @override
  String airportClock(int day, String time) {
    return 'jour $day $time';
  }

  @override
  String get airportArrivalZoneHelp =>
      'Ceci va dans le hall d’entrée, où les passagers entrent, achètent un billet, s’enregistrent et passent la sécurité. Définir d’abord une zone de sol comme hall d’entrée.';

  @override
  String get airportDepartureZoneHelp =>
      'Ceci va dans le hall de sortie, où les passagers arrivés récupèrent leurs bagages, passent la douane et quittent l’aéroport. Définir d’abord une zone comme hall de sortie.';

  @override
  String get airportMainInArrival =>
      'Les boutiques, restaurants, sièges et portes vont dans le hall principal. Cette zone est le hall d’entrée, réservé à l’entrée, aux billets, à l’enregistrement et à la sécurité.';

  @override
  String get airportMainInDeparture =>
      'Les boutiques, restaurants, sièges et portes vont dans le hall principal. Cette zone est le hall de sortie, réservé aux bagages, à la douane et à la sortie.';

  @override
  String get airportFacilityRunwayName => 'Piste · 1 800 m';

  @override
  String get airportFacilityRunwayDescription =>
      'Piste régionale. La relier aux stationnements par des voies de circulation.';

  @override
  String get airportFacilityRunwayMediumName => 'Piste · 2 600 m';

  @override
  String get airportFacilityRunwayMediumDescription =>
      'Accueille les avions à fuselage étroit.';

  @override
  String get airportFacilityRunwayLongName => 'Piste · 3 400 m';

  @override
  String get airportFacilityRunwayLongDescription =>
      'Accueille les gros-porteurs long-courriers.';

  @override
  String get airportFacilityTaxiwayName => 'Voie de circulation';

  @override
  String get airportFacilityTaxiwayDescription =>
      'Relier des voies de circulation contiguës entre une piste et un stationnement.';

  @override
  String get airportFacilityStandRegionalName => 'Stationnement régional';

  @override
  String get airportFacilityStandRegionalDescription =>
      'Turbopropulseurs et jets régionaux jusqu’à 45 t. Nécessite une voie de circulation, une voie de service et une porte proche.';

  @override
  String get airportFacilityStandName => 'Stationnement éloigné';

  @override
  String get airportFacilityStandDescription =>
      'Tout avion. Les passagers prennent un bus. Nécessite une voie de circulation, une voie de service et une porte proche.';

  @override
  String get airportFacilityStandContactName =>
      'Stationnement au contact · passerelle';

  @override
  String get airportFacilityStandContactDescription =>
      'Construire contre un terminal. Embarquement à pied : pas de bus, plus rapide et voyageurs plus satisfaits.';

  @override
  String get airportFacilityServiceRoadName => 'Voie de service';

  @override
  String get airportFacilityServiceRoadDescription =>
      'Relier les dépôts et services aux stationnements des avions.';

  @override
  String get airportFacilityTerminalName => 'Terminal';

  @override
  String get airportFacilityTerminalDescription =>
      'Un hall pour tout le terminal. Construire autant de halls voisins que nécessaire, puis diviser gratuitement le sol en mode aéroport : entrée côté route, hall principal au milieu et sortie pour les passagers arrivés.';

  @override
  String get airportFacilityTerminalLandsideName => 'Hall d’entrée';

  @override
  String get airportFacilityTerminalLandsideDescription =>
      'L’ancien hall d’entrée séparé. Diviser plutôt le sol d’un terminal en zones.';

  @override
  String get airportFacilityTerminalReclaimName => 'Hall de sortie';

  @override
  String get airportFacilityTerminalReclaimDescription =>
      'L’ancien hall de sortie séparé. Diviser plutôt le sol d’un terminal en zones.';

  @override
  String get airportFacilityHangarName => 'Hangar de maintenance';

  @override
  String get airportFacilityHangarDescription =>
      'Les hangars connectés réduisent les coûts de maintenance des avions.';

  @override
  String get airportFacilityFuelDepotName => 'Dépôt de carburant';

  @override
  String get airportFacilityFuelDepotDescription =>
      'Carburant pour les véhicules de service au sol.';

  @override
  String get airportFacilityBaggageName => 'Service de bagages';

  @override
  String get airportFacilityBaggageDescription =>
      'Traitement des bagages pour chaque départ.';

  @override
  String get airportFacilityVehicleDepotName => 'Dépôt de véhicules';

  @override
  String get airportFacilityVehicleDepotDescription =>
      'Sélectionner ce dépôt pour acheter des véhicules de service et le relier à une voie de service.';

  @override
  String get airportFacilityTowerName => 'Tour de contrôle';

  @override
  String get airportFacilityTowerDescription =>
      'Repère de l’aéroport et centre de contrôle des vols.';

  @override
  String get airportFacilityEntranceName => 'Entrée';

  @override
  String get airportFacilityEntranceDescription =>
      'L’entrée depuis le trottoir, dans le hall d’entrée.';

  @override
  String get airportFacilityCheckInName => 'Comptoirs d’enregistrement';

  @override
  String get airportFacilityCheckInDescription =>
      'Traite 8 passagers par minute de jeu.';

  @override
  String get airportFacilityInfoDeskName => 'Comptoir d’information';

  @override
  String get airportFacilityInfoDeskDescription =>
      'Le personnel répond aux questions et indique le chemin. Chaque comptoir connecté améliore la satisfaction dans tout le terminal.';

  @override
  String get airportFacilityCheckInCounterName =>
      'Comptoir d’enregistrement avec personnel';

  @override
  String get airportFacilityCheckInCounterDescription =>
      'Deux agents avec dépôt des bagages : 10 passagers par minute de jeu. Compte comme des comptoirs d’enregistrement.';

  @override
  String get airportFacilityTicketMachineName => 'Borne de billets';

  @override
  String get airportFacilityTicketMachineDescription =>
      'Enregistrement autonome près des comptoirs : 4 passagers par minute de jeu.';

  @override
  String get airportFacilitySecurityName => 'File de sécurité';

  @override
  String get airportFacilitySecurityDescription =>
      'Contrôle des passeports et bagages entre le hall d’entrée et le hall principal : 6 passagers par minute de jeu. Obligatoire.';

  @override
  String get airportFacilityCustomsName => 'Douane';

  @override
  String get airportFacilityCustomsDescription =>
      'Les passagers arrivés passent la douane ici : 6 par minute de jeu. Obligatoire.';

  @override
  String get airportFacilityCheckOutName => 'Sortie des arrivées';

  @override
  String get airportFacilityCheckOutDescription =>
      'La sortie : les passagers arrivés passent ici et rejoignent le trottoir par la porte la plus proche. 10 par minute de jeu. Obligatoire.';

  @override
  String get airportFacilitySeatingName => 'Sièges';

  @override
  String get airportFacilitySeatingDescription =>
      'Confort pour les passagers en attente.';

  @override
  String get airportFacilityToiletsName => 'Toilettes';

  @override
  String get airportFacilityToiletsDescription =>
      'Équipement essentiel pour les passagers.';

  @override
  String get airportFacilityBoardingGateName => 'Porte d’embarquement';

  @override
  String get airportFacilityBoardingGateDescription =>
      'Placer à moins de 25 m d’un stationnement d’avion.';

  @override
  String get airportFacilityCafeName => 'Café';

  @override
  String get airportFacilityCafeDescription =>
      'Satisfaction des passagers et revenus commerciaux.';

  @override
  String get airportFacilityVendingMachineName => 'Distributeur automatique';

  @override
  String get airportFacilityVendingMachineDescription =>
      'Collations rapides à la place du café : 3 € par passager, une minute chacun.';

  @override
  String get airportFacilityPerfumeShopName => 'Parfumerie';

  @override
  String get airportFacilityPerfumeShopDescription =>
      'Peu d’acheteurs, gros paniers : un passager sur quatre dépense 90 € ici.';

  @override
  String get airportFacilityFlowerShopName => 'Fleuriste';

  @override
  String get airportFacilityFlowerShopDescription =>
      'Bouquets frais après la sécurité : 16 € par passager, deux minutes chacun.';

  @override
  String get airportFacilityFoodShopName =>
      'Alimentation et boissons hors taxes';

  @override
  String get airportFacilityFoodShopDescription =>
      'Collations, confiseries et boissons fraîches après la sécurité : 20 € par passager, deux minutes et demie chacun.';

  @override
  String get airportFacilityKioskName => 'Kiosque à journaux';

  @override
  String get airportFacilityKioskDescription =>
      'Caisse avec personnel pour journaux et collations après la sécurité : 9 € par passager, quatre-vingt-dix secondes chacun.';

  @override
  String get airportFacilityRestaurantName => 'Restaurant';

  @override
  String get airportFacilityRestaurantDescription =>
      'Repas assis à la place du café : 26 € par passager, cinq minutes et une attente plus agréable.';

  @override
  String get airportFacilityCoffeeToGoName => 'Café à emporter';

  @override
  String get airportFacilityCoffeeToGoDescription =>
      'Un espresso rapide après la sécurité : 6 € par passager, quatre-vingt-dix secondes chacun.';

  @override
  String get airportFacilityFoodCartName => 'Chariot de restauration';

  @override
  String get airportFacilityFoodCartDescription =>
      'Un stand économique à emporter pour les petits espaces : 4 € par passager, une minute chacun.';

  @override
  String get airportFacilityShopName => 'Boutique hors taxes';

  @override
  String get airportFacilityShopDescription =>
      'Les passagers font leurs achats après la sécurité : 14 € de revenus par personne.';

  @override
  String get airportFacilityClothingShopName => 'Boutique de mode';

  @override
  String get airportFacilityClothingShopDescription =>
      'Vêtements hors taxes après la sécurité : 18 € par passager, trois minutes chacun.';

  @override
  String get airportFacilityLuxuryBoutiqueName => 'Boutique de luxe';

  @override
  String get airportFacilityLuxuryBoutiqueDescription =>
      'Maille haut de gamme après la sécurité : 26 € par passager, quatre minutes et une attente plus sereine.';

  @override
  String get airportFacilityLoungeName => 'Salon haut de gamme';

  @override
  String get airportFacilityLoungeDescription =>
      'Salle d’attente rapportant 20 € par passager et améliorant leur humeur.';

  @override
  String get airportFacilityBaggageCarouselName => 'Carrousel à bagages';

  @override
  String airportFacilityBaggageCarouselDescription(int capacity) {
    return 'Les passagers des contrats moyen et long-courriers récupèrent leurs bagages ici. Jusqu’à $capacity personnes à la fois.';
  }

  @override
  String get airportFacilityVipLoungeName => 'Salon et bar VIP';

  @override
  String get airportFacilityVipLoungeDescription =>
      'Salle d’attente de première classe : 35 € par passager et une attente bien plus agréable.';

  @override
  String get airportFacilityBinsName => 'Bacs de recyclage';

  @override
  String get airportFacilityBinsDescription =>
      'Déchets, papier et bouteilles. Un terminal propre satisfait les passagers : chaque ensemble ajoute 4 % de propreté, de 60 % jusqu’à 100 %.';

  @override
  String get airportFacilityArcadeName => 'Salle d’arcade';

  @override
  String get airportFacilityArcadeDescription =>
      'Bornes, air hockey et machine à pinces : 12 € par passager et une nette amélioration de l’humeur pendant l’attente.';

  @override
  String get airportFacilityCasinoName => 'Casino';

  @override
  String get airportFacilityCasinoDescription =>
      'Machines à sous, roulette et tables de cartes : 40 € par passager et une forte amélioration de l’humeur pendant l’attente.';

  @override
  String get airportFacilityPlantName => 'Bac à palmier';

  @override
  String get airportFacilityPlantDescription =>
      'Décoration. Chaque élément du terminal améliore un peu l’humeur.';

  @override
  String get airportFacilityFountainName => 'Fontaine';

  @override
  String get airportFacilityFountainDescription =>
      'Pièce décorative centrale. Améliore l’humeur des passagers.';

  @override
  String get airportFacilityInfoBoardName => 'Tableau d’information des vols';

  @override
  String get airportFacilityInfoBoardDescription =>
      'Décoration. Les passagers trouvent leur porte avec moins de stress.';

  @override
  String get airportFacilityInfoPanelName => 'Écran d’information des vols';

  @override
  String get airportFacilityInfoPanelDescription =>
      'Petit écran des départs sur un socle. Décoration moins chère avec le même effet apaisant qu’un grand tableau.';

  @override
  String get sceneAssetStudioAirformAssetStudio =>
      'Airform Studio de ressources';

  @override
  String get sceneAssetStudioAirform => 'Airform';

  @override
  String get sceneAssetStudioAssetStudio => 'Studio de ressources';

  @override
  String get sceneAssetStudioSavedLocally => 'Enregistré localement';

  @override
  String get sceneAssetStudioQuickGuide => 'Guide rapide';

  @override
  String get sceneAssetStudioExportModel => 'Exporter le modèle';

  @override
  String get sceneAssetStudioAirportAssets => 'RESSOURCES DE L\'AÉROPORT';

  @override
  String get sceneAssetStudioProcedural => 'Procédural';

  @override
  String get sceneAssetStudioTerminalCollectionAssets =>
      'Ressources de la collection du terminal';

  @override
  String get sceneAssetStudioTerminalCollection => 'COLLECTION DU TERMINAL';

  @override
  String get sceneAssetStudioModelWorkspace => 'Espace de travail du modèle';

  @override
  String get sceneAssetStudioWorkspaceView => 'Vue de l\'espace de travail';

  @override
  String get sceneAssetStudioSourceCode => 'Code source';

  @override
  String get sceneAssetStudioCameraView => 'Vue de la caméra';

  @override
  String get sceneAssetStudioIsometric => 'Isométrique';

  @override
  String get sceneAssetStudioFrontView => 'Vue de face';

  @override
  String get sceneAssetStudioRightView => 'Vue de droite';

  @override
  String get sceneAssetStudioBackView => 'Vue arrière';

  @override
  String get sceneAssetStudioTopView => 'Vue de dessus';

  @override
  String get sceneAssetStudioExpandViewport => 'Agrandir la zone d\'affichage';

  @override
  String get sceneAssetStudioLivePreview => 'APERÇU EN DIRECT';

  @override
  String get sceneAssetStudio1Unit1Meter => '1 unité = 1 mètre';

  @override
  String get sceneAssetStudioResetToIsometricView =>
      'Rétablir la vue isométrique';

  @override
  String get sceneAssetStudioIsometricViewF => 'Vue isométrique (F)';

  @override
  String get sceneAssetStudioTop => 'DESSUS';

  @override
  String get sceneAssetStudioFront => 'AVANT';

  @override
  String get sceneAssetStudioRight => 'DROITE';

  @override
  String get sceneAssetStudioYUp => 'Y VERS LE HAUT';

  @override
  String get sceneAssetStudioViewportTools => 'Outils de la zone d\'affichage';

  @override
  String get sceneAssetStudioOrbitTool => 'Outil d\'orbite';

  @override
  String get sceneAssetStudioOrbitO => 'Orbiter (O)';

  @override
  String get sceneAssetStudioPanTool => 'Outil de déplacement';

  @override
  String get sceneAssetStudioPanH => 'Déplacer (H)';

  @override
  String get sceneAssetStudioToggleFootprintDimensions =>
      'Afficher/masquer les dimensions de l\'emprise';

  @override
  String get sceneAssetStudioFootprintBoundsB => 'Limites de l\'emprise (B)';

  @override
  String get sceneAssetStudioToggleGroundGrid =>
      'Afficher/masquer la grille au sol';

  @override
  String get sceneAssetStudioGridG => 'Grille (G)';

  @override
  String get sceneAssetStudioYUpCoordinateSystem =>
      'Repère avec l\'axe Y vers le haut';

  @override
  String get sceneAssetStudioDragToOrbit => 'Faites glisser pour orbiter';

  @override
  String get sceneAssetStudioScrollToZoom => 'Faites défiler pour zoomer';

  @override
  String get sceneAssetStudioStartTurntable => 'Lancer la rotation';

  @override
  String get sceneAssetStudioAutoOrbit => 'Orbite automatique';

  @override
  String get sceneAssetStudioSavePreviewImage =>
      'Enregistrer l\'image d\'aperçu';

  @override
  String get sceneAssetStudioResetCameraF => 'Réinitialiser la caméra (F)';

  @override
  String get sceneAssetStudioOnlyDonorHelpersNoTexturesFontsOrExternalA =>
      'Assistants du donneur uniquement. Sans textures, polices ni ressources externes.';

  @override
  String get sceneAssetStudioViewWiring => 'Connexions de la vue';

  @override
  String get sceneAssetStudioRenderStyle => 'Style de rendu';

  @override
  String get sceneAssetStudioSolid => 'Plein';

  @override
  String get sceneAssetStudioWireframe => 'Filaire';

  @override
  String get sceneAssetStudioQuarterTurnRotation =>
      'Rotation d\'un quart de tour';

  @override
  String get sceneAssetStudioJavascript => 'JavaScript';

  @override
  String get sceneAssetStudioStaticGeometryDonorHelpers =>
      'Géométrie statique / assistants du donneur';

  @override
  String get sceneAssetStudioCopyFullSnippet => 'Copier l\'extrait complet';

  @override
  String get sceneAssetStudioModelInspector => 'Inspecteur de modèle';

  @override
  String get sceneAssetStudioInspector => 'Inspecteur';

  @override
  String get sceneAssetStudioProperties => 'Propriétés';

  @override
  String get sceneAssetStudioChecks => 'Vérifications';

  @override
  String get sceneAssetStudioMeters => 'MÈTRES';

  @override
  String get sceneAssetStudioWidth => 'Largeur';

  @override
  String get sceneAssetStudioWidthInMeters => 'Largeur en mètres';

  @override
  String get sceneAssetStudioDepthInMeters => 'Profondeur en mètres';

  @override
  String get sceneAssetStudioModelHeight => 'Hauteur du modèle';

  @override
  String get sceneAssetStudioColorPalette => 'Palette de couleurs';

  @override
  String get sceneAssetStudioVertexColors => 'COULEURS DES SOMMETS';

  @override
  String get sceneAssetStudioModelColorPalette =>
      'Palette de couleurs du modèle';

  @override
  String get sceneAssetStudioCopyColorValue => 'Copier la valeur de couleur';

  @override
  String get sceneAssetStudioSceneSettings => 'Paramètres de scène';

  @override
  String get sceneAssetStudioGroundGrid => 'Grille au sol';

  @override
  String get sceneAssetStudioFootprintBounds => 'Limites de l\'emprise';

  @override
  String get sceneAssetStudioScreenEmission => 'Émission de l\'écran';

  @override
  String get sceneAssetStudioBuiltToFitYourTerminal =>
      'Conçu pour s\'adapter à votre terminal.';

  @override
  String get sceneAssetStudioLowPolyAndMadeToFitYourWorld =>
      'Low-poly et conçu pour votre monde.';

  @override
  String get sceneAssetStudioGeometryChecks => 'Vérifications de la géométrie';

  @override
  String get sceneAssetStudioRealChecksOnYourLiveModel =>
      'Vérifications réelles sur votre modèle actuel.';

  @override
  String get sceneAssetStudioUsesPreviewHelpersConfirmWith =>
      'Utilise les assistants d\'aperçu. Confirmez avec';

  @override
  String get sceneAssetStudioAirportmodelsBakeG => 'AirportModels.bake(g)';

  @override
  String get sceneAssetStudioInYourDonorBeforeShipping =>
      'dans votre donneur avant la publication.';

  @override
  String get sceneAssetStudioResetToDefaults =>
      'Rétablir les valeurs par défaut';

  @override
  String get sceneAssetStudioRunChecksAgain => 'Relancer les vérifications';

  @override
  String get sceneAssetStudioV10 => 'v1.0';

  @override
  String get sceneAssetStudioPreparingGeometry => 'Préparation de la géométrie';

  @override
  String get sceneAssetStudioHelperCalls => 'appels d\'assistants';

  @override
  String get sceneAssetStudioTriangles => 'triangles';

  @override
  String get sceneAssetStudioTextures => 'textures';

  @override
  String get sceneAssetStudioThreeJs => 'THREE.JS';

  @override
  String get sceneAssetStudioWebgl => 'WEBGL';

  @override
  String get sceneAssetStudioDismissNotification => 'Ignorer la notification';

  @override
  String get sceneAssetStudioCloseDialog => 'Fermer la boîte de dialogue';

  @override
  String get sceneAssetStudioExportSections => 'Exporter les sections';

  @override
  String get sceneAssetStudioModelFunction => 'Fonction du modèle';

  @override
  String get sceneAssetStudioJs => 'JS';

  @override
  String get sceneAssetStudioIntegration => 'Intégration';

  @override
  String get sceneAssetStudioJsDart => 'JS + DART';

  @override
  String get sceneAssetStudioFindYourAngle => 'Trouvez votre angle';

  @override
  String get sceneAssetStudioDragToOrbitScrollToZoomOrHoldShiftWhileDra =>
      'Faites glisser pour orbiter, faites défiler pour zoomer ou maintenez Maj enfoncée pendant le déplacement pour faire un panoramique. Utilisez le menu d\'affichage pour obtenir des vues précises de face, de côté et de dessus.';

  @override
  String get sceneAssetStudioMakeSureItFits => 'Vérifiez que tout tient';

  @override
  String get sceneAssetStudioAdjustTheFootprintInMetersOpenChecksToInsp =>
      'Réglez l\'emprise en mètres. Ouvrez Vérifications pour examiner les limites, les attributs de couleur et le budget d\'appels aux assistants.';

  @override
  String get sceneAssetStudioGrid => 'Grille';

  @override
  String get sceneAssetStudioBounds => 'Limites';

  @override
  String get sceneAssetStudioGiveItAHome => 'Trouvez-lui une place';

  @override
  String get sceneAssetStudioExportTheFunctionIntoYourExistingHelperSco =>
      'Exportez la fonction dans votre espace d\'assistants actuel, ajoutez la branche d\'installation JavaScript et inscrivez l\'entrée du catalogue Dart. Compilez avec votre donneur avant la publication.';

  @override
  String get sceneAssetStudioThePreviewAdapterUsesCenteredBoxesAndSizeS =>
      'L\'adaptateur d\'aperçu utilise des boîtes centrées et des maillages lumineux dont les côtés suivent les dimensions. Le modèle n\'a aucun fichier externe, matériau ni allocation de géométrie à chaque image. Les paramètres sont enregistrés dans ce navigateur.';

  @override
  String get sceneCityPlannerMetroplanStadsplanner => 'MetroPlan — Urbaniste';

  @override
  String get sceneCityPlannerMetroplan => 'MetroPlan';

  @override
  String get sceneCityPlanner1Jan1925 => '1 janv. 1925';

  @override
  String get sceneCityPlannerPauze => 'Pause';

  @override
  String get sceneCityPlannerNormaal => 'Normal';

  @override
  String get sceneCityPlannerSnel => 'Rapide';

  @override
  String get sceneCityPlannerZeerSnel => 'Très rapide';

  @override
  String get sceneCityPlannerStadsfase => 'Phase de la ville';

  @override
  String get sceneCityPlannerFase1Dorp => 'Phase 1 · Village';

  @override
  String get sceneCityPlannerDataWeergaveHeatmap =>
      'Vue des données (carte thermique)';

  @override
  String get sceneCityPlannerOpslaanLaden => 'Enregistrer et charger';

  @override
  String get sceneCityPlannerNieuweKaart => 'Nouvelle carte';

  @override
  String get sceneCityPlannerRechtermuisknop => 'Clic droit';

  @override
  String get sceneCityPlannerSchuiven => 'déplacer ·';

  @override
  String get sceneCityPlannerScroll => 'défilement';

  @override
  String get sceneCityPlannerZoomen => 'zoom ·';

  @override
  String get sceneCityPlannerGrid => 'grille ·';

  @override
  String get sceneCityPlannerSnappen => 'aligner ·';

  @override
  String get sceneCityPlannerAlt => 'Alt';

  @override
  String get sceneCityPlannerVrijPlaatsen => 'placement libre';

  @override
  String get sceneCityPlannerInspecteur => 'Inspecteur';

  @override
  String get sceneCityPlannerOnderzoek => 'Recherche';

  @override
  String get sceneCityPlannerFinanciN => 'Finances';

  @override
  String get sceneCityPlannerBeleid => 'Politique';

  @override
  String get sceneCityPlannerOv => 'Transports';

  @override
  String get sceneCityPlannerStad => 'Ville';

  @override
  String get sceneCityPlannerGemiddeldeTevredenheid => 'Satisfaction moyenne';

  @override
  String get sceneCityPlannerMaandelijksSaldo => 'Solde mensuel';

  @override
  String get sceneCityPlannerWoningmarkt => 'Marché du logement';

  @override
  String get sceneCityPlannerVerkeersdrukte => 'Congestion routière';

  @override
  String get sceneCityPlannerOnderwijsdekking => 'Couverture scolaire';

  @override
  String get sceneCityPlannerZorgdekking => 'Couverture médicale';

  @override
  String get sceneCityPlannerMilieuLuchtkwaliteit =>
      'Environnement / qualité de l’air';

  @override
  String get sceneCityPlannerElektriciteit => 'Électricité';

  @override
  String get sceneCityPlannerDrinkwater => 'Eau potable';

  @override
  String get sceneCityPlannerVoedsel => 'Nourriture';

  @override
  String get sceneCityPlannerSluiten => 'Fermer';

  @override
  String get sceneCityPlannerOpslaanAmpLaden => 'Enregistrer et charger';

  @override
  String get sceneCityPlannerBergenBlokkerenDitTrac =>
      'Les montagnes bloquent cet itinéraire.';

  @override
  String get sceneCityPlannerRotondePastHierNiet =>
      'Un rond-point ne peut pas être placé ici.';

  @override
  String get sceneCityPlannerWegsegmentVerwijderd =>
      'Segment de route supprimé.';

  @override
  String get sceneCityPlannerHierKunJeNietBouwenWaterBergWegOfBezet =>
      'Impossible de construire ici (eau, montagne, route ou zone occupée).';

  @override
  String get sceneCityPlannerDeVormMoetNAaneengeslotenGeheelZijn =>
      'La forme doit être d’un seul tenant.';

  @override
  String get sceneCityPlannerLetOpDitGebouwHeeftNogGeenWegHetWerktPasAl =>
      'Attention : ce bâtiment n’a pas encore de route. Il fonctionnera lorsqu’une route sera adjacente.';

  @override
  String get sceneCityPlannerHaltesMoetenOpEenWegLiggen =>
      'Les arrêts doivent être sur une route.';

  @override
  String get sceneCityPlannerOnvoldoendeGeldVoorDezeHalte =>
      'Fonds insuffisants pour cet arrêt.';

  @override
  String get sceneCityPlannerEenLijnHeeftMinstens2HaltesNodig =>
      'Une ligne nécessite au moins 2 arrêts.';

  @override
  String get sceneCityPlannerSpelOpgeslagen => 'Partie enregistrée.';

  @override
  String get sceneCityPlannerOpslaanMislukt => 'Échec de l’enregistrement :';

  @override
  String get sceneCityPlannerGeenOpgeslagenSpelGevonden =>
      'Aucune partie enregistrée trouvée.';

  @override
  String get sceneCityPlannerSaveBestandBeschadigd =>
      'Fichier de sauvegarde endommagé.';

  @override
  String get sceneCityPlannerDezeSaveKomtVanEenOudereVersieOfAndereKaar =>
      'Cette sauvegarde provient d’une ancienne version ou d’une autre taille de carte et ne peut pas être chargée.';

  @override
  String get sceneCityPlannerSpelGeladen => 'Partie chargée.';

  @override
  String get sceneCityPlannerSandboxEenLeegWitCanvasOnbeperktGeldAllesO =>
      'Bac à sable ! Une toile blanche vide : argent illimité, tout est débloqué. Construisez la ville de vos rêves.';

  @override
  String get sceneCityPlannerNieuweKaartBeginMetEenWegHuizenEenAkkerEnE =>
      'Nouvelle carte ! Commencez par une route, des maisons, un champ et une pompe à eau.';

  @override
  String get sceneCityPlannerLijnVerwijderen => 'Supprimer la ligne';

  @override
  String get sceneCityPlannerSaveVerwijderen => 'Supprimer la sauvegarde';

  @override
  String get sceneCityPlannerDezeSaveVerwijderen =>
      'Supprimer cette sauvegarde ?';

  @override
  String get sceneCityPlannerSleepVrijOverDeKaartDeEngineMaaktErAutomat =>
      'Faites glisser librement sur la carte — le moteur crée automatiquement une route fluide. Les routes croisées deviennent des carrefours.';

  @override
  String get sceneCityPlannerKlikOmEenRotondeTePlaatsenSluitErWegenOpAa =>
      'Cliquez pour placer un rond-point et reliez-y des routes.';

  @override
  String get sceneCityPlannerKlikHaltesOpWegenDubbelklikOfEnterOmDeLijn =>
      'Cliquez sur des arrêts le long des routes ; double-cliquez ou appuyez sur Entrée pour terminer la ligne.';

  @override
  String get sceneCityPlannerOnvoldoendeGeld => 'Fonds insuffisants.';

  @override
  String get sceneCityPlannerKlikOpEenGebouwOmHetTeInspecterenEnAanTePa =>
      'Cliquez sur un bâtiment pour l’inspecter et le modifier.';

  @override
  String get sceneCityPlannerTips => 'Conseils :';

  @override
  String get sceneCityPlannerTekenGebouwenInElkeVormDoorCellenTeSlepen =>
      '· Dessinez des bâtiments de toutes formes en faisant glisser les cellules.';

  @override
  String get sceneCityPlannerGebouwenHebbenEenWegNodigEnStroomWaterViaD =>
      '· Les bâtiments ont besoin d’une route, ainsi que d’électricité et d’eau via le réseau routier.';

  @override
  String get sceneCityPlannerGebruikDeHeatmapsAnalyseOfRechtsbovenOmPro =>
      '· Utilisez les cartes thermiques (Analyse ou en haut à droite) pour repérer les problèmes.';

  @override
  String get sceneSpaceColonySol10800 => 'Sol 1 · 08:00';

  @override
  String get sceneSpaceColonyGettingStarted => 'Bien démarrer';

  @override
  String get sceneSpaceColonyDemolishMode => '🧨 Mode démolition';

  @override
  String get sceneSpaceColonyColony => 'Colonie';

  @override
  String get sceneSpaceColonyResearch => '🔬 Recherche';

  @override
  String get sceneSpaceColonySendRoverToRuins =>
      '🛰️ Envoyer le rover aux ruines';

  @override
  String get sceneSpaceColonySave => '💾 Enregistrer';

  @override
  String get sceneSpaceColonyLoad => '📂 Charger';

  @override
  String get sceneSpaceColonyTutorial => '❓ Tutoriel';

  @override
  String get sceneSpaceColonyDragWasdToPanScrollToZoomClickToBuildRight =>
      'Faites glisser / WASD pour déplacer · faites défiler pour zoomer · cliquez pour construire · clic droit pour annuler · survolez les cases pour les détails · cliquez sur un colon pour ses statistiques. Placez des foreuses sur les gisements de minerai (orange) ou de cristal (violet), des extracteurs d’eau sur la glace (bleu clair). Les ruines anciennes (violet poussiéreux) s’explorent en rover depuis un garage de véhicules.';

  @override
  String get sceneSpaceColonyMinimap => 'Minicarte';

  @override
  String get sceneSpaceColonyColonists => 'Colons';

  @override
  String get sceneSpaceColonyEventLog => 'Journal des événements';

  @override
  String get sceneSpaceColonyWelcomeToSpaceColony =>
      '🚀 Bienvenue dans Space Colony';

  @override
  String get sceneSpaceColonyYouVeLandedWith3ColonistsALandingModuleASm =>
      'Vous avez atterri avec 3 colons, un module d’atterrissage, une petite batterie, un panneau solaire et des matériaux de base. Gardez tout le monde en vie et développez une colonie autonome.';

  @override
  String get sceneSpaceColonyBeforeAnythingElse => 'Avant toute chose';

  @override
  String get sceneSpaceColonyPlaceTheseFiveBuildingsWithoutThemYourColo =>
      ', placez ces cinq bâtiments — sans eux, votre colonie manquera d’énergie, d’air ou d’eau en un jour ou deux :';

  @override
  String get sceneSpaceColonySolarPanel => 'Panneau solaire';

  @override
  String get sceneSpaceColonyPowerDuringTheDay =>
      '— fournit de l’énergie le jour.';

  @override
  String get sceneSpaceColonyStoresPowerSoSystemsKeepRunningAtNight =>
      '— stocke l’énergie pour faire fonctionner les systèmes la nuit.';

  @override
  String get sceneSpaceColonyOxygenGenerator => 'Générateur d’oxygène';

  @override
  String get sceneSpaceColonyTurnsWaterIntoBreathableAir =>
      '— transforme l’eau en air respirable.';

  @override
  String get sceneSpaceColonyWaterExtractor => 'Extracteur d’eau';

  @override
  String get sceneSpaceColonyPlaceItOnAnIceFieldLightBlueTilesForAWater =>
      '— placez-le sur une zone glacée (cases bleu clair) pour obtenir de l’eau.';

  @override
  String get sceneSpaceColonyMiningRig => 'Foreuse';

  @override
  String get sceneSpaceColonyPlaceItOnAMetalDepositOrangeTilesSoYouCanK =>
      '— placez-la sur un gisement de métal (orange) pour continuer à construire.';

  @override
  String get sceneSpaceColonyWatchTheResourceBarAtTheTopAnythingShownIn =>
      'Surveillez la barre des ressources en haut : le rouge indique une pénurie. Les gisements de minerai et de cristal s’épuisent ; explorez pour en trouver d’autres. Cliquez sur le nom d’un colon pour afficher ses statistiques. Rouvrez ceci avec le bouton ❓ Tutoriel.';

  @override
  String get sceneSpaceColonyLetSGo => 'C’est parti !';

  @override
  String get sceneSpaceColonySciencePoints => 'Points de science :';

  @override
  String get sceneSpaceColonyProducedByLaboratories =>
      '(produits par les laboratoires)';

  @override
  String get sceneSpaceColonyColonyLost => 'COLONIE PERDUE';

  @override
  String get sceneSpaceColonyAllColonistsHavePerished =>
      'Tous les colons ont péri.';

  @override
  String get sceneSpaceColonyNewColony => 'Nouvelle colonie';

  @override
  String get sceneSpaceColonyHungerOSleepHappyHealth =>
      'faim / O₂ / sommeil / bonheur / santé';

  @override
  String get sceneSpaceColonyNextSkillUp => '· prochaine compétence : %';

  @override
  String get sceneSpaceColonySkills => 'Compétences';

  @override
  String get sceneSpaceColonyHp => 'PV /';

  @override
  String get sceneSubwayBuilderDayTimeWeekday =>
      'Jour · heure · jour de la semaine';

  @override
  String get sceneSubwayBuilderWeather => 'Météo';

  @override
  String get sceneSubwayBuilderTreasury => 'Trésorerie';

  @override
  String get sceneSubwayBuilderDailyTransitRiders => 'Voyageurs quotidiens';

  @override
  String get sceneSubwayBuilderShareOfAllCommutesOnYourNetwork =>
      'Part des trajets domicile-travail sur votre réseau';

  @override
  String get sceneSubwayBuilderPauseSpace => 'Pause (Espace)';

  @override
  String get sceneSubwayBuilder1RealSecond1InGameMinute =>
      '1 seconde réelle = 1 minute de jeu';

  @override
  String get sceneSubwayBuilder6InGameMinutesSecond =>
      '6 minutes de jeu/seconde';

  @override
  String get sceneSubwayBuilder30InGameMinutesSecond =>
      '30 minutes de jeu/seconde';

  @override
  String get sceneSubwayBuilderTiltTheCameraFor3DBuildings =>
      'Inclinez la caméra pour voir les bâtiments en 3D';

  @override
  String get sceneSubwayBuilder3D => '3D';

  @override
  String get sceneSubwayBuilderNetworkAnalysis => 'Analyse du réseau';

  @override
  String get sceneSubwayBuilderChangeLocation => 'Changer de lieu';

  @override
  String get sceneSubwayBuilderPlayTogetherCoOp => 'Jouer ensemble (coop)';

  @override
  String get sceneSubwayBuilderCoOp => 'Coop';

  @override
  String get sceneSubwayBuilderToggleDarkLightTheme =>
      'Basculer entre thème sombre et clair';

  @override
  String get sceneSubwayBuilderHowToPlay => 'Comment jouer';

  @override
  String get sceneSubwayBuilderCloseMenu => 'Fermer le menu';

  @override
  String get sceneSubwayBuilderShortHopsFastTunnelsAnywhere =>
      'Trajets courts, rapides, tunnels partout';

  @override
  String get sceneSubwayBuilderShortHopsCheapRunsOnStreets =>
      'Trajets courts, économiques, dans les rues';

  @override
  String get sceneSubwayBuilderAnyDistanceCheapestSlow =>
      'Toutes distances, le moins cher, lent';

  @override
  String get sceneSubwayBuilderLongHopsOnRealStationsAndTracks =>
      'Longs trajets sur de vraies gares et voies';

  @override
  String get sceneSubwayBuilderVeryLongHopsVeryFastFewStopsRealStationsAn =>
      'Très longs trajets, très rapides, peu d’arrêts — vraies gares et voies';

  @override
  String get sceneSubwayBuilderSelectPan => 'Sélectionner / déplacer';

  @override
  String get sceneSubwayBuilderDrawLine => 'Tracer une ligne';

  @override
  String get sceneSubwayBuilderBulldoze => 'Démolir';

  @override
  String get sceneSubwayBuilderFetchEveryOfficialRailwayStationCurrentlyO =>
      'Récupérer toutes les gares officielles actuellement visibles';

  @override
  String get sceneSubwayBuilderLoadStations => 'Charger les gares';

  @override
  String get sceneSubwayBuilderDataViews => 'Vues des données';

  @override
  String get sceneSubwayBuilderResidents => 'Habitants';

  @override
  String get sceneSubwayBuilderJobs => 'Emplois';

  @override
  String get sceneSubwayBuilderStopReach => 'Portée des arrêts';

  @override
  String get sceneSubwayBuilderLineLoad => 'Charge de la ligne';

  @override
  String get sceneSubwayBuilderLines => 'Lignes';

  @override
  String get sceneSubwayBuilderNewLine => 'Nouvelle ligne';

  @override
  String get sceneSubwayBuilderTakeLoan => 'Emprunter';

  @override
  String get sceneSubwayBuilderRepay => 'Rembourser';

  @override
  String get sceneSubwayBuilderRendering => 'Rendu';

  @override
  String get sceneSubwayBuilder3DBuildings => 'Bâtiments 3D';

  @override
  String get sceneSubwayBuilder2DMode => 'Mode 2D';

  @override
  String get sceneSubwayBuilderRenderDistance => 'Distance de rendu';

  @override
  String get sceneSubwayBuilderLodDistance => 'Distance LOD';

  @override
  String get sceneSubwayBuilderMenu => 'Menu';

  @override
  String get sceneSubwayBuilderToggle2DMode => 'Basculer le mode 2D';

  @override
  String get sceneSubwayBuilder2D => '2D';

  @override
  String get sceneSubwayBuilderSurveying => 'Repérage';

  @override
  String get sceneSubwayBuilderWelcomeBackTo => 'Bon retour à';

  @override
  String get sceneSubwayBuilderStillSyncingWithTheHost =>
      'Synchronisation avec l’hôte en cours…';

  @override
  String get sceneSubwayBuilderClickOneOfTheTwoEndStationsOf =>
      'Cliquez sur l’une des deux gares terminus de';

  @override
  String get sceneSubwayBuilderSurveyingTheRailCorridor =>
      'Repérage du corridor ferroviaire…';

  @override
  String get sceneSubwayBuilderAlreadyOnThisDraft => 'Déjà dans ce brouillon';

  @override
  String get sceneSubwayBuilderTreasuryIsInTheRedConsiderALoanOrHigherFar =>
      'La trésorerie est dans le rouge — envisagez un emprunt ou une hausse des tarifs';

  @override
  String get sceneSubwayBuilderCouldNotConnectToTheRoom =>
      'Impossible de se connecter à la salle :';

  @override
  String get sceneSubwayBuilderCouldNotReachTheCoOpServer =>
      'Serveur coopératif inaccessible';

  @override
  String get sceneSubwayBuilderLostConnectionToTheRoomReconnecting =>
      'Connexion à la salle perdue — reconnexion…';

  @override
  String get sceneSubwayBuilderRunningTheClockForThisRoom =>
      'Gestion de l’horloge de cette salle';

  @override
  String get sceneSubwayBuilderCouldNotJoinThatRoom =>
      'Impossible de rejoindre cette salle :';

  @override
  String get sceneSubwayBuilderTravellingTo => 'En route vers';

  @override
  String get sceneSubwayBuilderJoinedRoom => 'Salle rejointe';

  @override
  String get sceneSubwayBuilderLoadACityFirst => 'Chargez d’abord une ville';

  @override
  String get sceneSubwayBuilderCouldNotCreateARoom =>
      'Impossible de créer une salle :';

  @override
  String get sceneSubwayBuilderRoom => 'Salle';

  @override
  String get sceneSubwayBuilderNoLinesYetPickAModePlaceStopsThenConnectTh =>
      'Aucune ligne pour l’instant. Choisissez un mode, placez des arrêts, puis reliez-les avec l’outil Ligne.';

  @override
  String get sceneSubwayBuilderToggleOvernight22000500Service =>
      'Activer le service de nuit (22:00–05:00)';

  @override
  String get sceneSubwayBuilderToggleWeekendService =>
      'Activer le service du week-end';

  @override
  String get sceneSubwayBuilderRoomCode => 'Code de salle';

  @override
  String get sceneSubwayBuilderSearchAnyCityTownOrAddress =>
      'Rechercher une ville, un village ou une adresse…';

  @override
  String get sceneSubwayBuilderTakeA => 'Prendre un';

  @override
  String get sceneSubwayBuilderLineDrawingCancelled => 'Tracé de ligne annulé';

  @override
  String get sceneSubwayBuilderLeftTheCoOpRoom => 'Salle coop quittée';

  @override
  String get sceneSubwayBuilderInviteSent => 'Invitation envoyée';

  @override
  String get sceneSubwayBuilderCouldNotSendInvite =>
      'Impossible d’envoyer l’invitation :';

  @override
  String get sceneSubwayBuilderEnterARoomCode => 'Saisissez un code de salle';

  @override
  String get sceneSubwayBuilderTurnOff2DModeInSettingsToTiltTheCamera =>
      'Désactivez le mode 2D dans les paramètres pour incliner la caméra';

  @override
  String get sceneSubwayBuilderLoadingOfficialStationsInView =>
      'Chargement des gares officielles visibles…';

  @override
  String get sceneSubwayBuilderStationLookupFailedTheMapDataServiceIsBusy =>
      'Échec de recherche des gares — le service cartographique est occupé, réessayez';

  @override
  String get sceneSubwayBuilderNoNewOfficialStationsFoundInView =>
      'Aucune nouvelle gare officielle trouvée';

  @override
  String get sceneSubwayBuilderOnlyWhoeverIsRunningTheClockManagesTheTrea =>
      'Seule la personne qui gère l’horloge contrôle la trésorerie.';

  @override
  String aiDetectorHiddenCharacterEvidence(String name, int count) {
    return '« $name ×$count (caché) »';
  }

  @override
  String aiDetectorSignatureEvidence(String name, int count) {
    return '« $name ×$count »';
  }

  @override
  String aiDetectorAssistantEvidence(String name, int count) {
    return '« $name ×$count »';
  }

  @override
  String get aiDetectorInvisibleSoftHyphen => 'trait d’union conditionnel';

  @override
  String get aiDetectorInvisibleGraphemeJoiner =>
      'jonction de graphèmes combinés';

  @override
  String get aiDetectorInvisibleMongolianSeparator =>
      'séparateur de voyelles mongoles';

  @override
  String get aiDetectorInvisibleZeroWidthSpace => 'espace sans chasse';

  @override
  String get aiDetectorInvisibleZeroWidthNonJoiner => 'antiliant sans chasse';

  @override
  String get aiDetectorInvisibleZeroWidthJoiner => 'liant sans chasse';

  @override
  String get aiDetectorInvisibleWordJoiner => 'liant de mots';

  @override
  String get aiDetectorInvisibleFunctionApplication =>
      'application de fonction';

  @override
  String get aiDetectorInvisibleTimes => 'multiplication invisible';

  @override
  String get aiDetectorInvisibleSeparator => 'séparateur invisible';

  @override
  String get aiDetectorInvisiblePlus => 'addition invisible';

  @override
  String get aiDetectorInvisibleNoBreakSpace => 'espace insécable sans chasse';

  @override
  String get aiDetectorInvisibleUnicodeTag => 'caractère de balise Unicode';

  @override
  String get aiDetectorInvisibleVariationSelector => 'sélecteur de variante';

  @override
  String get aiDetectorEvidenceClaudeAi => 'référence à claude.ai';

  @override
  String get aiDetectorEvidenceAnthropic => 'Anthropic nommé';

  @override
  String get aiDetectorEvidenceClaudeModel => 'identifiant de modèle Claude';

  @override
  String get aiDetectorEvidenceClaudeSelfReference => 'autoréférence à Claude';

  @override
  String get aiDetectorEvidenceAsAnAi => 'avertissement « As an AI »';

  @override
  String get aiDetectorEvidenceCapabilityDisclaimer =>
      'avertissement sur les capacités';

  @override
  String get aiDetectorEvidenceChatSignOff => 'formule de fin de chat';

  @override
  String get aiDetectorEvidenceContrastNotJust =>
      'construction « pas seulement X, mais Y »';

  @override
  String get aiDetectorEvidenceContrastNotAbout =>
      'construction « ce n’est pas X ; c’est Y »';

  @override
  String get aiDetectorEvidenceContrastIsntJust =>
      'construction « n’est pas seulement »';

  @override
  String get aiDetectorEvidenceContrastStagedReveal =>
      'révélation mise en scène';

  @override
  String get aiDetectorEvidenceContrastThatsPoint =>
      'conclusion « voilà l’essentiel »';

  @override
  String get aiDetectorEvidenceContrastHeresThing =>
      'transition « voici le problème »';

  @override
  String aiDetectorEvidenceSentenceRange(int min, int max) {
    return 'les phrases comptent de $min à $max mots';
  }

  @override
  String aiDetectorEvidenceVariationIndex(String index) {
    return 'indice de variation $index (faible = uniforme)';
  }

  @override
  String aiDetectorPhraseEvidence(String phrase, int count, String soft) {
    String _temp0 = intl.Intl.selectLogic(soft, {
      'true': ' (faible)',
      'other': '',
    });
    return '« $phrase » ×$count$_temp0';
  }

  @override
  String aiDetectorEvidenceShortSentences(int short, int total) {
    return '$short phrases sur $total comptent moins de 6 mots';
  }

  @override
  String aiDetectorEvidenceLongSentences(int long, int total) {
    return '$long phrases sur $total comptent plus de 27 mots';
  }

  @override
  String aiDetectorEvidenceVoiceCounts(
    int pronouns,
    int informal,
    int questions,
  ) {
    return '$pronouns pronoms personnels, $informal mots familiers, $questions questions';
  }

  @override
  String aiDetectorEvidenceVoiceRate(String rate) {
    return '$rate pour 1000 mots (faible = impersonnel)';
  }

  @override
  String aiDetectorEvidenceMarkdownHeadings(int count) {
    return '$count titres Markdown';
  }

  @override
  String aiDetectorEvidenceBulletLines(int count) {
    return '$count lignes à puces ou numérotées';
  }

  @override
  String aiDetectorEvidenceBoldLeads(int count) {
    return '$count introductions en gras';
  }

  @override
  String aiDetectorEvidenceLabelLines(int count) {
    return '$count lignes « Étiquette : texte »';
  }

  @override
  String get aiDetectorEvidencePlainProse =>
      'prose simple, sans structure de liste';

  @override
  String aiDetectorEvidenceScaffoldLines(int count, int total) {
    return '$count lignes sur $total structurent le texte';
  }

  @override
  String aiDetectorEvidenceContrast(String label, int count) {
    return '$label ×$count';
  }

  @override
  String get aiDetectorEvidenceNoneFound => 'aucun trouvé';

  @override
  String aiDetectorEvidencePerThousand(String rate) {
    return '$rate pour 1000 mots';
  }

  @override
  String aiDetectorEvidenceOpener(String word, int count) {
    return '$word ×$count en début de phrase';
  }

  @override
  String get aiDetectorEvidenceNoneUsed => 'aucun utilisé';

  @override
  String aiDetectorEvidenceContractions(int count, int words) {
    return '$count contractions dans $words mots';
  }

  @override
  String aiDetectorEvidenceEmDashes(int count, String rate) {
    return '$count tirets cadratins ($rate pour 1000 mots)';
  }

  @override
  String aiDetectorEvidencePassive(int count, String rate) {
    return '$count constructions passives ($rate pour 100 mots)';
  }

  @override
  String aiDetectorEvidenceParagraphSizes(int count, String sizes) {
    return '$count paragraphes : $sizes';
  }

  @override
  String aiDetectorEvidenceRepeatedOpener(String word, int count, int total) {
    return '« $word » ouvre $count phrases sur $total';
  }

  @override
  String get aiDetectorRepeatedOpenersNotEnough =>
      'Pas assez de débuts de phrases distinctifs pour mesurer.';

  @override
  String aiDetectorHighlightPhraseNote(String phrase) {
    return 'Expression typique de LLM : « $phrase »';
  }

  @override
  String aiDetectorHighlightContrastNote(String label) {
    return 'Contraste correctif : $label';
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
  String get aiDetectorHighlightPassiveNote => 'Construction passive';

  @override
  String aiDetectorHighlightOpenerNote(String word) {
    return 'La phrase commence par « $word »';
  }

  @override
  String get aiDetectorHighlightEmDashNote => 'Tiret cadratin';

  @override
  String aiDetectorHighlightHiddenNote(String name) {
    return '$name caché dans ce mot';
  }

  @override
  String get mcLauncherJvmArgsHint =>
      'Arguments JVM facultatifs, par exemple : -XX:+UseG1GC';

  @override
  String get airportUpgradeBoardingLanes => 'Files d’embarquement';

  @override
  String get airportUpgradeBoardingLanesEffect =>
      'Une file supplémentaire embarque davantage de passagers en même temps.';

  @override
  String get airportUpgradeBoardingSpeed => 'Vitesse d’embarquement';

  @override
  String get airportUpgradeBoardingSpeedEffect =>
      'Chaque file embarque 1,5 passager de plus par minute.';

  @override
  String get airportUpgradeSurfaceLighting => 'Revêtement et éclairage';

  @override
  String get airportUpgradeSurfaceLightingEffect =>
      'Les atterrissages et décollages libèrent la piste 15 % plus vite par niveau.';

  @override
  String get airportUpgradeAsphalt => 'Asphalte';

  @override
  String get airportUpgradeAsphaltStandsEffect =>
      'L’assistance au sol et l’embarquement sont 15 % plus rapides par niveau.';

  @override
  String get airportUpgradeQuality => 'Qualité';

  @override
  String get airportUpgradeQualityEffect =>
      'Compte comme une décoration supplémentaire par niveau.';

  @override
  String get airportUpgradeStockStaff => 'Stock et personnel';

  @override
  String get airportUpgradeStockStaffEffect =>
      '15 % de ventes en plus et un service 25 % plus rapide par niveau.';

  @override
  String get airportUpgradeComfort => 'Confort';

  @override
  String get airportUpgradeComfortEffect =>
      '+1 % de satisfaction et 15 % de revenus en plus par niveau.';

  @override
  String get airportUpgradeStaff => 'Personnel';

  @override
  String get airportUpgradeInfoDeskEffect =>
      'Chaque niveau compte comme un comptoir supplémentaire avec personnel.';

  @override
  String get airportUpgradeStaffEffect =>
      'Les passagers sont traités 25 % plus vite par niveau.';

  @override
  String get airportUpgradeAsphaltTaxiwayEffect =>
      'Les avions roulent 10 % plus vite par niveau.';

  @override
  String get airportUpgradeComfortTerminalEffect =>
      'Les passagers sont 1 % plus satisfaits par niveau, en moyenne sur les sections.';

  @override
  String get airportUpgradeEquipment => 'Équipement';

  @override
  String get airportUpgradeEquipmentEffect =>
      'Les services au sol envoyés d’ici sont 20 % plus rapides par niveau.';

  @override
  String get airportUpgradeRadar => 'Radar';

  @override
  String get airportUpgradeRadarEffect =>
      'Les approches prennent 10 % de temps en moins par niveau.';

  @override
  String get airportUpgradeService => 'Service';

  @override
  String get airportUpgradeServiceEffect =>
      'Chaque niveau compte comme un jeu de poubelles supplémentaire.';

  @override
  String get airportUpgradeBeltSpeed => 'Vitesse du tapis';

  @override
  String get airportUpgradeBeltSpeedEffect =>
      'Les passagers récupèrent leurs bagages 25 % plus vite par niveau.';

  @override
  String get airportSlotEarlyMorning => 'Tôt le matin';

  @override
  String get airportSlotMorning => 'Matin';

  @override
  String get airportSlotAfternoon => 'Après-midi';

  @override
  String get airportSlotEvening => 'Soir';

  @override
  String get airportSlotAnyTime => 'À tout moment';

  @override
  String get airportHaulShort => 'Court-courrier';

  @override
  String get airportHaulMedium => 'Moyen-courrier';

  @override
  String get airportHaulLong => 'Long-courrier';

  @override
  String get airportLedgerConstruction => 'Construction';

  @override
  String get airportLedgerVehicles => 'Véhicules';

  @override
  String get airportLedgerPenalty => 'Pénalité';

  @override
  String get airportLedgerUpkeep => 'Entretien';

  @override
  String get airportLedgerService => 'Service';

  @override
  String get airportLedgerLease => 'Location';

  @override
  String get airportLedgerHandling => 'Assistance au sol';

  @override
  String get airportLedgerRetail => 'Commerce';

  @override
  String get airportLedgerCargo => 'Fret';

  @override
  String get airportLedgerFuel => 'Carburant';

  @override
  String get airportLedgerCrew => 'Équipage';

  @override
  String get airportLedgerLanding => 'Atterrissage';

  @override
  String get airportLedgerMaintenance => 'Maintenance';

  @override
  String get airportLedgerTickets => 'Billets';

  @override
  String get airportLedgerDay => 'Jour';

  @override
  String get airportLedgerBoarded => 'Embarqués';

  @override
  String get airportLedgerDelay => 'Retard';

  @override
  String get airportLedgerFee => 'Tarif';

  @override
  String get airportLedgerNoTransactions =>
      'Vos transactions apparaîtront ici.';

  @override
  String get airportIssueCancelledByOperator => 'Annulé par l’exploitant';

  @override
  String get airportIssueContractCancelled => 'Contrat annulé';

  @override
  String get airportIssueStandRemoved => 'Poste supprimé';

  @override
  String get airportIssueAirportAccessDisconnected =>
      'L’accès à l’aéroport est déconnecté';

  @override
  String get airportIssueAircraftUnavailable => 'Avion indisponible';

  @override
  String get airportIssueWaitingForStand => 'En attente d’un poste';

  @override
  String get airportIssueWaitingForRunwayClearance =>
      'En attente de l’autorisation de piste';

  @override
  String get airportIssueWaitingForTaxiwayClearance =>
      'En attente de l’autorisation de voie de circulation';

  @override
  String get airportIssueRequiredContractFacilityUnavailable =>
      'Une installation requise par le contrat est indisponible';

  @override
  String airportIssueTerminalNeeds(Object facility) {
    return 'Le terminal a besoin de $facility';
  }

  @override
  String get airportIssueWaitingForGroundServices =>
      'En attente des services au sol';

  @override
  String get airportIssuePassengersStillInTerminal =>
      'Des passagers sont encore dans le terminal';

  @override
  String get airportIssueWaitingForPushbackTug =>
      'En attente du tracteur de repoussage';

  @override
  String airportLedgerDemolished(Object facility) {
    return '$facility démoli';
  }

  @override
  String airportLedgerPurchasedVehicle(Object vehicle) {
    return 'Véhicule $vehicle acheté';
  }

  @override
  String get airportLedgerInfrastructureUpkeep =>
      'Entretien des infrastructures aéroportuaires';

  @override
  String get airportLedgerVehicleStaffingMaintenance =>
      'Personnel et entretien des véhicules';

  @override
  String airportLedgerUnplannedFlights(Object carrier, Object count) {
    return '$carrier : $count vols non planifiés';
  }

  @override
  String airportLedgerLateIncompleteService(Object flightId) {
    return 'Service en retard ou incomplet $flightId';
  }

  @override
  String airportLedgerGroundServices(Object flightId) {
    return 'Services au sol $flightId';
  }

  @override
  String airportLedgerCargoFlight(Object flightId) {
    return 'Fret $flightId';
  }

  @override
  String airportLedgerFlightFuel(Object flightId) {
    return 'Carburant du vol $flightId';
  }

  @override
  String airportLedgerFlightCrew(Object flightId) {
    return 'Équipage du vol $flightId';
  }

  @override
  String airportLedgerLandingFlight(Object flightId) {
    return 'Atterrissage $flightId';
  }

  @override
  String airportLedgerFlightMaintenance(Object flightId) {
    return 'Maintenance du vol $flightId';
  }

  @override
  String airportLedgerHeavyCheck(Object registration) {
    return 'Grande révision $registration';
  }

  @override
  String airportLedgerLeaseAircraft(Object registration) {
    return 'Location $registration';
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
    return '$facility : niveau $level $attribute';
  }

  @override
  String get airportLedgerReturnSuffix => 'retour';

  @override
  String airportLedgerBuiltFacility(Object facility) {
    return '$facility construit';
  }

  @override
  String airportLedgerFacilitySales(Object facility) {
    return 'Ventes de $facility';
  }

  @override
  String get airportVehicleFuel => 'Camion-citerne';

  @override
  String get airportVehicleBaggage => 'Tracteur à bagages';

  @override
  String get airportVehicleBus => 'Bus passagers';

  @override
  String get airportVehiclePushback => 'Tracteur de repoussage';

  @override
  String get syncCryptoCorruptedRecoveryEnvelope =>
      'L’enveloppe de récupération est corrompue.';

  @override
  String get syncCryptoCorruptedRecoveryKeyBox =>
      'Le conteneur de la clé de récupération est corrompu.';

  @override
  String get syncCryptoCorruptedSnapshot =>
      'L’instantané de synchronisation est corrompu.';

  @override
  String get syncCryptoAuthenticationFailed =>
      'Les données chiffrées n’ont pas pu être authentifiées.';

  @override
  String get syncCryptoUnrecognizedEncryptedData =>
      'Le format des données chiffrées n’est pas reconnu.';

  @override
  String get syncCryptoDifferentPassword =>
      'Déchiffrement impossible. Les données ont été chiffrées avec un autre mot de passe.';

  @override
  String get syncStateInvalid => 'L’état de synchronisation est invalide.';

  @override
  String get syncStateReadFailed =>
      'Impossible de lire l’état de synchronisation. Conservez le fichier pour sa récupération.';

  @override
  String get syncStateInvalidEncryptionKey =>
      'La clé de chiffrement de synchronisation est invalide.';

  @override
  String get syncStateRestoreCredentials =>
      'L’état de synchronisation est invalide. Restaurez les identifiants d’origine.';

  @override
  String get mcNbtExpectedCompound =>
      'Une balise compound racine était attendue.';

  @override
  String mcNbtUnknownTag(Object type, Object position) {
    return 'Type de balise NBT inconnu $type à l’octet $position.';
  }

  @override
  String mcWorldNoLongerExists(Object folderName) {
    return 'Le monde « $folderName » n’existe plus.';
  }

  @override
  String get aiUsageUnknownModel => 'Modèle inconnu';

  @override
  String sceneAirlineTycoonUpgradeAttributeToLevel(
    String attribute,
    String level,
  ) {
    return 'Améliorer $attribute au niveau $level';
  }

  @override
  String sceneAirlineTycoonCancelPenalty(String cost) {
    return 'Annuler : pénalité de $cost';
  }

  @override
  String sceneAirlineTycoonDemolishFacilityQuestion(String facility) {
    return 'Démolir $facility ?';
  }

  @override
  String sceneAirlineTycoonDemolishRefund(String refund) {
    return 'Vous récupérez $refund. Cette action est irréversible.';
  }

  @override
  String sceneAirlineTycoonCarrierStartsInSlot(String carrier, String slot) {
    return '$carrier commence dans $slot';
  }

  @override
  String sceneAssetStudioRotateToDegrees(String degrees) {
    return 'Tourner à $degrees degrés';
  }

  @override
  String sceneCityPlannerInsufficientFunds(String amount) {
    return 'Fonds insuffisants : $amount nécessaires.';
  }

  @override
  String sceneCityPlannerMustBuildByWater(String building) {
    return '$building doit être construit au bord de l’eau.';
  }

  @override
  String sceneCityPlannerLinePausedDepot(String type) {
    return 'Ligne créée mais en pause : construire d’abord un dépôt de $type.';
  }

  @override
  String sceneCityPlannerLineRuns(String line) {
    return '$line circule ! Gérer la fréquence dans le panneau des transports publics.';
  }

  @override
  String sceneSubwayWelcomeBack(String place, String day) {
    return 'Bon retour à $place — jour $day';
  }

  @override
  String sceneSubwayDeleteLineQuestion(String line) {
    return 'Supprimer $line ?';
  }

  @override
  String sceneSubwayStationLeased(String station, String cost) {
    return '$station louée · $cost';
  }

  @override
  String sceneSubwayStationBuilt(String station, String cost) {
    return '$station construite · $cost';
  }

  @override
  String sceneSubwayLineRemoved(String line, String refund) {
    return '$line supprimée · $refund remboursés';
  }

  @override
  String sceneSubwayLineExtended(String line, String station) {
    return '$line prolongée jusqu’à $station';
  }

  @override
  String sceneSubwayStationModeStop(String station, String mode) {
    return '$station est un arrêt de $mode ; changer de mode pour le connecter';
  }

  @override
  String sceneSubwaySelectLineEndpoint(String line) {
    return 'Cliquer sur l’une des deux stations terminales de $line';
  }

  @override
  String sceneSubwayStationDemolished(String station, String refund) {
    return '$station démolie · $refund remboursés';
  }

  @override
  String sceneSubwayRouteHopsMax(Object mode, Object maxKm) {
    return '$mode : $maxKm km maximum entre deux arrêts — ajoutez un arrêt intermédiaire ou prenez le train pour les longues distances';
  }

  @override
  String get sceneSubwayRouteNoRailConnection =>
      'Aucune liaison ferroviaire n’existe entre ces stations';

  @override
  String get sceneSubwayRouteNoStreetRoute =>
      'Aucun itinéraire routier entre ces arrêts';

  @override
  String get sceneSubwayStationInOpenWater => 'C’est de l’eau libre';

  @override
  String sceneSubwayPlaceModeStopsOnStreet(Object mode) {
    return 'Placez les arrêts $mode dans une rue';
  }

  @override
  String get sceneSubwayNotEnoughFunds => 'Fonds insuffisants';

  @override
  String sceneSubwayModeServicesRealRailStations(Object mode) {
    return 'Les services $mode ne s’arrêtent qu’aux vraies gares — cliquez sur une gare';
  }

  @override
  String sceneSubwayModeServicesHighlightedRailStations(Object mode) {
    return 'Les services $mode ne s’arrêtent qu’aux vraies gares — cliquez sur une gare en surbrillance';
  }

  @override
  String get sceneSubwayLineRequiresTwoStops =>
      'Une ligne nécessite au moins deux arrêts';

  @override
  String get sceneSubwayUnknownLineOrStation => 'Ligne ou arrêt inconnu';

  @override
  String get sceneSubwayStopDifferentMode =>
      'Cet arrêt appartient à un autre mode de transport';

  @override
  String get sceneSubwayStopAlreadyOnLine =>
      'Cet arrêt est déjà sur cette ligne';

  @override
  String get sceneSubwayUnknownStation => 'Station inconnue';

  @override
  String get sceneSubwayUnknownLine => 'Ligne inconnue';

  @override
  String sceneSubwayLineFleetLimit(Object maxVehicles) {
    return 'La ligne a atteint sa limite de véhicules ($maxVehicles)';
  }

  @override
  String get sceneSubwayLineRequiresVehicle =>
      'Une ligne nécessite au moins un véhicule';

  @override
  String get sceneSubwayNoOutstandingLoans => 'Aucun prêt en cours';

  @override
  String sceneSubwayDraftStopsCost(Object count, Object distance, Object cost) {
    return '$count arrêts · $distance · $cost — Entrée pour construire, Échap pour annuler.';
  }

  @override
  String sceneSubwayDraftStopsCostTunnel(
    Object count,
    Object distance,
    Object cost,
  ) {
    return '$count arrêts · $distance · $cost (tunnel sous-marin inclus) — Entrée pour construire, Échap pour annuler.';
  }

  @override
  String sceneSubwayLineOpened(Object line, Object cost) {
    return 'Ligne $line ouverte — $cost, deux véhicules inclus';
  }

  @override
  String sceneSubwayLineOpenedTunnel(Object line, Object cost) {
    return 'Ligne $line ouverte — $cost, deux véhicules et un tunnel sous-marin inclus';
  }

  @override
  String get sceneSubwayOfficialStationLoadedOne =>
      '1 station officielle chargée';

  @override
  String sceneSubwayOfficialStationsLoaded(Object count) {
    return '$count stations officielles chargées';
  }

  @override
  String sceneSubwayJoinedRoomCode(Object code) {
    return 'Salle $code rejointe';
  }

  @override
  String sceneSubwayRoomCreatedReady(Object code) {
    return 'Salle $code créée — commencez à construire';
  }

  @override
  String sceneSubwayRoomCreatedShare(Object code) {
    return 'Salle $code créée — partagez le code ou invitez un contact';
  }

  @override
  String sceneSubwayCouldNotConnectRoom(Object error) {
    return 'Connexion à la salle impossible : $error';
  }

  @override
  String sceneSubwayCouldNotJoinRoom(Object error) {
    return 'Impossible de rejoindre cette salle : $error';
  }

  @override
  String sceneSubwayCouldNotCreateRoom(Object error) {
    return 'Impossible de créer une salle : $error';
  }

  @override
  String sceneSubwayCouldNotSendInvite(Object error) {
    return 'Impossible d’envoyer l’invitation : $error';
  }

  @override
  String sceneSubwayGrantAwarded(Object label, Object amount) {
    return '$label : $amount pour construire';
  }

  @override
  String sceneSubwayLoanReceived(Object amount) {
    return 'Prêt de $amount reçu';
  }

  @override
  String get sceneSubwayDeleteLineRefundDetails =>
      'Vous récupérez 25 % du coût de construction ainsi que la valeur de revente des véhicules.';

  @override
  String get sceneSubwayAchievementCommuterFavourite =>
      'Chouchou des navetteurs';

  @override
  String get sceneSubwayAchievementCommuterFavouriteSub =>
      '1 000 voyageurs par jour';

  @override
  String get sceneSubwayAchievementCityMover => 'La ville en mouvement';

  @override
  String get sceneSubwayAchievementCityMoverSub => '25 000 voyageurs par jour';

  @override
  String get sceneSubwayAchievementMetropolisMachine =>
      'Machine métropolitaine';

  @override
  String get sceneSubwayAchievementMetropolisMachineSub =>
      '100 000 voyageurs par jour';

  @override
  String get sceneSubwayAchievementNetworkEffect => 'Effet réseau';

  @override
  String get sceneSubwayAchievementNetworkEffectSub => '10 stations en service';

  @override
  String get sceneSubwayAchievementEveryCorner => 'À chaque coin de rue';

  @override
  String get sceneSubwayAchievementEveryCornerSub => '40 stations en service';

  @override
  String get sceneSubwayAchievementGoingDistance => 'Sur toute la distance';

  @override
  String get sceneSubwayAchievementGoingDistanceSub => '50 km de lignes';

  @override
  String get sceneSubwayAchievementSteelSpine => 'Épine d’acier';

  @override
  String get sceneSubwayAchievementSteelSpineSub => '250 km de lignes';

  @override
  String get sceneSubwayAchievementFullSpectrum => 'Toute la gamme';

  @override
  String get sceneSubwayAchievementFullSpectrumSub =>
      'Les cinq modes en service';

  @override
  String get sceneSubwayAchievementUnderRiver => 'Sous la rivière';

  @override
  String get sceneSubwayAchievementUnderRiverSub =>
      'Un tunnel sous l’eau libre';

  @override
  String get sceneSubwayAchievementIntercityExpress => 'Express interurbain';

  @override
  String get sceneSubwayAchievementIntercityExpressSub =>
      'Deux vraies gares distantes de plus de 15 km sur une ligne';

  @override
  String get sceneSubwayAchievementAirportLink => 'Liaison avec l’aéroport';

  @override
  String get sceneSubwayAchievementAirportLinkSub =>
      'Une gare d’aéroport sur le réseau';

  @override
  String get sceneSubwayAchievementRingLine => 'Ligne circulaire';

  @override
  String get sceneSubwayAchievementRingLineSub =>
      'Une ligne qui revient à son point de départ';

  @override
  String get sceneSubwayAchievementBulletService => 'Service grande vitesse';

  @override
  String get sceneSubwayAchievementBulletServiceSub =>
      'Une ligne à grande vitesse en service';

  @override
  String get sceneSubwayAchievementCityNeverSleeps => 'La ville ne dort jamais';

  @override
  String get sceneSubwayAchievementCityNeverSleepsSub =>
      '10 000 voyageurs avec toutes les lignes en service toute la nuit';

  @override
  String get sceneSubwayAchievementInTheBlack => 'Dans le vert';

  @override
  String get sceneSubwayAchievementInTheBlackSub =>
      'Une journée rentable avec plus de 5 000 voyageurs';

  @override
  String get sceneSubwayMilestoneCityHall => 'La mairie vous remarque';

  @override
  String get sceneSubwayMilestoneStateGrant =>
      'Subvention régionale aux transports';

  @override
  String get sceneSubwayMilestoneFederalGrant =>
      'Subvention fédérale aux infrastructures';

  @override
  String get sceneSubwayMilestoneTransitCityAward =>
      'Prix Ville des transports';

  @override
  String get sceneSubwayMilestoneWorldMetroFund =>
      'Fonds métro de classe mondiale';

  @override
  String get sceneSubwayMilestoneTransitCapital =>
      'Capitale mondiale des transports';

  @override
  String get sceneSubwayLineColorRed => 'Rouge';

  @override
  String get sceneSubwayLineColorBlue => 'Bleu';

  @override
  String get sceneSubwayLineColorGreen => 'Vert';

  @override
  String get sceneSubwayLineColorOrange => 'Orange';

  @override
  String get sceneSubwayLineColorPurple => 'Violet';

  @override
  String get sceneSubwayLineColorYellow => 'Jaune';

  @override
  String get sceneSubwayLineColorTeal => 'Sarcelle';

  @override
  String get sceneSubwayLineColorPink => 'Rose';

  @override
  String get sceneSubwayLineColorLime => 'Citron vert';

  @override
  String get sceneSubwayLineColorIndigo => 'Indigo';

  @override
  String get sceneSubwayLineColorAmber => 'Ambre';

  @override
  String get sceneSubwayLineColorCyan => 'Cyan';

  @override
  String get sceneSubwayVehicleTrain => 'train';

  @override
  String get sceneSubwayVehicleTram => 'tramway';

  @override
  String get sceneSubwayVehicleBus => 'bus';

  @override
  String sceneSubwayLinePanelModeSpeed(Object mode, Object speed) {
    return 'Mode $mode · $speed km/h';
  }

  @override
  String sceneSubwayLinePanelStopsLength(Object count, Object length) {
    return 'Arrêts $count · longueur $length';
  }

  @override
  String sceneSubwayLinePanelFleetHeadway(
    Object count,
    Object vehicle,
    Object headway,
  ) {
    return 'Flotte : $count ${vehicle}s · intervalle $headway';
  }

  @override
  String sceneSubwayLinePanelRidersRevenue(Object count, Object revenue) {
    return 'Voyageurs $count/jour · recettes $revenue/jour';
  }

  @override
  String sceneSubwayLinePanelPeakCrowding(Object percent) {
    return 'Saturation maximale $percent %';
  }

  @override
  String sceneSubwayLinePanelDelays(Object factor) {
    return 'Retards ×$factor';
  }

  @override
  String sceneSubwayLinePanelDisruption(Object label) {
    return '$label — le service est ralenti jusqu’à la fin de l’incident';
  }

  @override
  String get sceneSubwayLinePanelServiceWindow => 'Période de service';

  @override
  String get sceneSubwayLinePanelNight => 'Nuit';

  @override
  String get sceneSubwayLinePanelWeekend => 'Week-end';

  @override
  String get sceneSubwayLinePanelExtend => 'Prolonger';

  @override
  String get sceneSubwayStatsTransitShare => 'Part des transports en commun';

  @override
  String get sceneSubwayStatsDailyRiders => 'Voyageurs quotidiens';

  @override
  String get sceneSubwayStatsCoverage => 'Couverture';

  @override
  String get sceneSubwayStatsResidentsNearStop => 'habitants près d’un arrêt';

  @override
  String get sceneSubwayStatsTransfers => 'Correspondances';

  @override
  String get sceneSubwayStatsAvgTransitTrip =>
      'Trajet moyen en transport en commun';

  @override
  String get sceneSubwayStatsAvgCarTrip => 'Trajet moyen en voiture';

  @override
  String get sceneSubwayStatsRouteLength => 'Longueur des lignes';

  @override
  String get sceneSubwayStatsStops => 'Arrêts';

  @override
  String get sceneSubwayStatsFleet => 'Flotte';

  @override
  String get sceneSubwayStatsSpentToDate => 'Dépenses à ce jour';

  @override
  String sceneSubwayStatsTransitLegend(Object percent) {
    return 'Transports en commun $percent %';
  }

  @override
  String sceneSubwayStatsDrivingLegend(Object percent) {
    return 'Voiture $percent %';
  }

  @override
  String get sceneSubwayStatsBoardingsByMode => 'Montées par mode';

  @override
  String get sceneSubwayStatsBusiestStops => 'Arrêts les plus fréquentés';

  @override
  String get sceneSubwayStatsPlayDaysForData =>
      'Jouez quelques jours pour obtenir des données…';

  @override
  String get sceneSubwayCoopSignedOut =>
      'Les salons coop sont liés à votre compte Luma pour gérer les invitations et les membres. Connectez-vous dans les paramètres du compte de l’application, puis revenez ici.';

  @override
  String sceneSubwayCoopRoomCodeTitle(Object code) {
    return 'Coop — salle $code';
  }

  @override
  String get sceneSubwayCoopRoomCodeDescription =>
      'Toute personne disposant du code ou d’une invitation peut rejoindre et construire ce réseau avec vous.';

  @override
  String get sceneSubwayCoopClockYou =>
      'Vous gérez actuellement l’horloge de cette salle.';

  @override
  String get sceneSubwayCoopClockPeer =>
      'Un autre joueur gère l’horloge — vous la reprendrez automatiquement s’il part.';

  @override
  String get sceneSubwayCoopInviteContact => 'Inviter un contact du chat';

  @override
  String sceneSubwayCoopNoChatContacts(Object code) {
    return 'Aucun contact de chat — configurez le plugin Chat ou partagez directement le code $code.';
  }

  @override
  String get sceneSubwayCoopInviteInstruction =>
      'Leur envoie le code de la salle par chat — ils doivent encore appuyer sur Rejoindre.';

  @override
  String get sceneSubwayCoopLoadingContacts =>
      'Chargement de vos contacts du chat…';

  @override
  String get sceneSubwayCoopLoadingRooms => 'Chargement de vos salles…';

  @override
  String get sceneSubwayCoopRoomsEmpty =>
      'Construisez le même réseau avec vos amis — invitez-les par chat ou partagez un code. Les joueurs connectés maintiennent l’horloge ; vous pouvez partir et revenir à tout moment.';

  @override
  String get sceneSubwayCoopCreateRoom => 'Créer une salle';

  @override
  String get sceneSubwayCoopJoinByCode => '— ou rejoignez avec un code —';

  @override
  String get sceneSubwayCoopJoinRoom => 'Rejoindre la salle';

  @override
  String sceneSubwayCoopMemberCountOne(Object count) {
    return '$count membre';
  }

  @override
  String sceneSubwayCoopMemberCountMany(Object count) {
    return '$count membres';
  }

  @override
  String get sceneSubwayCoopRoomYours => 'la vôtre';

  @override
  String get sceneSubwayCoopOpenRoom => 'Ouvrir';

  @override
  String get sceneSubwayCoopNoRoom => 'Aucune salle';

  @override
  String get sftpHostWindowsPermissionsUnsupported =>
      'Cet appareil ne prend pas en charge les permissions POSIX.';

  @override
  String serverTycoonGeneratedPcRigName(Object id) {
    return 'Rig $id';
  }

  @override
  String serverTycoonGeneratedServerRigName(Object id) {
    return 'Serveur $id';
  }

  @override
  String serverTycoonGeneratedRouterName(Object id) {
    return 'Routeur $id';
  }

  @override
  String get sftpHostTooManyPairingFailures =>
      'Trop de mots de passe d’association incorrects ont été saisis depuis cet appareil. Attendez quelques minutes ou affichez un nouveau mot de passe et utilisez-le.';

  @override
  String sftpHostTooManyDevices(Object maxClients) {
    return 'Cet appareil a déjà $maxClients appareils connectés. Déconnectez-en un, puis réessayez.';
  }

  @override
  String get githubConnectTokenHint => 'ghp_… ou github_pat_…';

  @override
  String get mcWorldModeSurvival => 'Survie';

  @override
  String get mcWorldModeCreative => 'Créatif';

  @override
  String get mcWorldModeAdventure => 'Aventure';

  @override
  String get mcWorldModeSpectator => 'Spectateur';

  @override
  String get sceneAirlineTycoonStageApproach => 'En approche';

  @override
  String get sceneAirlineTycoonStagePositioning => 'Remorqué jusqu’au poste';

  @override
  String get sceneAirlineTycoonStageToHangar => 'Remorqué jusqu’au hangar';

  @override
  String get sceneAirlineTycoonStageLanding => 'Atterrissage';

  @override
  String get sceneAirlineTycoonStagePushback => 'Repoussage';

  @override
  String get sceneAirlineTycoonStageBoarding => 'Embarquement';

  @override
  String get sceneAirlineTycoonStageTaxiIn => 'Roulage vers le poste';

  @override
  String get sceneAirlineTycoonStageTaxiOut => 'Roulage vers la piste';

  @override
  String get sceneAirlineTycoonStageUnloading => 'Débarquement des passagers';

  @override
  String get sceneAirlineTycoonStageServicing => 'Services au sol';

  @override
  String get sceneAirlineTycoonStageDeparting => 'Décollage';

  @override
  String get sceneAirlineTycoonStageRemote => 'En vol';

  @override
  String get sceneAirlineTycoonStageAwaitingStand => 'En attente d’un poste';

  @override
  String get sceneAirlineTycoonStageAwaitingAirport =>
      'En attente d’accès à l’aéroport';

  @override
  String sceneAirlineTycoonStandName(Object code) {
    return 'Poste $code';
  }

  @override
  String get sceneAirlineTycoonUnassignedStand => 'Aucun poste attribué';

  @override
  String sceneAirlineTycoonContractCharter(Object flights) {
    return 'Charter · $flights vol(s)';
  }

  @override
  String sceneAirlineTycoonContractDaily(Object flights) {
    return 'Quotidien · $flights jours';
  }

  @override
  String sceneSubwayMilestoneShareReached(Object grant, Object share) {
    return '$share % de part des transports atteints — subvention de $grant accordée !';
  }

  @override
  String sceneSubwayAchievementBonus(Object grant, Object sub) {
    return '$sub — bonus de $grant';
  }

  @override
  String sceneSubwayCrowdingGrantReduced(Object grant, Object label) {
    return '$label — l’affluence a réduit la prime à $grant';
  }

  @override
  String sceneSubwaySurgeGrant(Object grant, Object label) {
    return '$label a provoqué un pic : +$grant';
  }

  @override
  String get cardWalletNameHintExample => 'Carte de fidélité Albert Heijn';

  @override
  String get sceneCityPlannerDataGras => 'Herbe';

  @override
  String get sceneCityPlannerDataBos => 'Forêt';

  @override
  String get sceneCityPlannerDataHeuvels => 'Collines';

  @override
  String get sceneCityPlannerDataBergen => 'Montagnes';

  @override
  String get sceneCityPlannerDataRivier => 'Rivière';

  @override
  String get sceneCityPlannerDataMeer => 'Lac';

  @override
  String get sceneCityPlannerDataKustwater => 'Eaux côtières';

  @override
  String get sceneCityPlannerDataZand => 'Sable';

  @override
  String get sceneCityPlannerDataLandbouwgrond => 'Terres agricoles';

  @override
  String get sceneCityPlannerDataKleineStraat => 'Petite rue';

  @override
  String get sceneCityPlannerDataNormaleWeg => 'Route normale';

  @override
  String get sceneCityPlannerDataHoofdweg => 'Route principale';

  @override
  String get sceneCityPlannerDataSnelweg => 'Autoroute';

  @override
  String get sceneCityPlannerDataLeeg => 'Vide';

  @override
  String get sceneCityPlannerDataWonen => 'Résidentiel';

  @override
  String get sceneCityPlannerDataLuxeWonen => 'Résidentiel de luxe';

  @override
  String get sceneCityPlannerDataStudentenwoningen => 'Logements étudiants';

  @override
  String get sceneCityPlannerDataWinkel => 'Boutique';

  @override
  String get sceneCityPlannerDataRestaurant => 'Restaurant';

  @override
  String get sceneCityPlannerDataKantoor => 'Bureau';

  @override
  String get sceneCityPlannerDataIndustrie => 'Industrie';

  @override
  String get sceneCityPlannerDataOpslag => 'Stockage';

  @override
  String get sceneCityPlannerDataPubliekeFunctie => 'Services publics';

  @override
  String get sceneCityPlannerDataHuis => 'Maison';

  @override
  String get sceneCityPlannerDataAppartement => 'Appartement';

  @override
  String get sceneCityPlannerDataFlat => 'Immeuble résidentiel';

  @override
  String get sceneCityPlannerDataWoontoren => 'Tour résidentielle';

  @override
  String get sceneCityPlannerDataLuxeWoning => 'Maison de luxe';

  @override
  String get sceneCityPlannerDataStudentenwoning => 'Résidence étudiante';

  @override
  String get sceneCityPlannerDataSupermarkt => 'Supermarché';

  @override
  String get sceneCityPlannerDataWinkelcentrum => 'Centre commercial';

  @override
  String get sceneCityPlannerDataFabriek => 'Usine';

  @override
  String get sceneCityPlannerDataMagazijn => 'Entrepôt';

  @override
  String get sceneCityPlannerDataTechnologiebedrijf =>
      'Entreprise technologique';

  @override
  String get sceneCityPlannerDataAkker => 'Champ cultivé';

  @override
  String get sceneCityPlannerDataBoerderij => 'Ferme';

  @override
  String get sceneCityPlannerDataKas => 'Serre';

  @override
  String get sceneCityPlannerDataVerticalFarm => 'Ferme verticale';

  @override
  String get sceneCityPlannerDataVoedselfabriek => 'Usine alimentaire';

  @override
  String get sceneCityPlannerDataBasisschool => 'École primaire';

  @override
  String get sceneCityPlannerDataMiddelbareSchool => 'Établissement secondaire';

  @override
  String get sceneCityPlannerDataUniversiteit => 'Université';

  @override
  String get sceneCityPlannerDataHuisartsenpost => 'Cabinet médical';

  @override
  String get sceneCityPlannerDataZiekenhuis => 'Hôpital';

  @override
  String get sceneCityPlannerDataPolitiebureau => 'Commissariat';

  @override
  String get sceneCityPlannerDataBrandweerkazerne => 'Caserne de pompiers';

  @override
  String get sceneCityPlannerDataGemeentehuis => 'Hôtel de ville';

  @override
  String get sceneCityPlannerDataPark => 'Parc';

  @override
  String get sceneCityPlannerDataKolencentrale => 'Centrale à charbon';

  @override
  String get sceneCityPlannerDataGascentrale => 'Centrale à gaz';

  @override
  String get sceneCityPlannerDataWindmolen => 'Éolienne';

  @override
  String get sceneCityPlannerDataZonnepark => 'Parc solaire';

  @override
  String get sceneCityPlannerDataWaterkrachtcentrale =>
      'Centrale hydroélectrique';

  @override
  String get sceneCityPlannerDataKerncentrale => 'Centrale nucléaire';

  @override
  String get sceneCityPlannerDataFusiereactor => 'Réacteur à fusion';

  @override
  String get sceneCityPlannerDataBatterijopslag => 'Stockage par batteries';

  @override
  String get sceneCityPlannerDataWaterpomp => 'Pompe à eau';

  @override
  String get sceneCityPlannerDataWaterzuivering =>
      'Usine de traitement de l’eau';

  @override
  String get sceneCityPlannerDataRioolwaterzuivering => 'Station d’épuration';

  @override
  String get sceneCityPlannerDataVuilstortplaats => 'Décharge';

  @override
  String get sceneCityPlannerDataRecyclingcentrum => 'Centre de recyclage';

  @override
  String get sceneCityPlannerDataAfvalenergiecentrale =>
      'Usine de valorisation énergétique';

  @override
  String get sceneCityPlannerDataParkeerterrein => 'Parking';

  @override
  String get sceneCityPlannerDataParkeergarage => 'Parking à étages';

  @override
  String get sceneCityPlannerDataBusdepot => 'Dépôt de bus';

  @override
  String get sceneCityPlannerDataTramremise => 'Dépôt de tramways';

  @override
  String get sceneCityPlannerDataMetrodepot => 'Dépôt de métro';

  @override
  String get sceneCityPlannerDataTreinstation => 'Gare';

  @override
  String get sceneCityPlannerDataLuchthaven => 'Aéroport';

  @override
  String get sceneCityPlannerDataHaven => 'Port';

  @override
  String get sceneCityPlannerDataBuslijn => 'Ligne de bus';

  @override
  String get sceneCityPlannerDataTramlijn => 'Ligne de tramway';

  @override
  String get sceneCityPlannerDataMetrolijn => 'Ligne de métro';

  @override
  String get sceneCityPlannerDataTreinlijn => 'Ligne ferroviaire';

  @override
  String get sceneCityPlannerDataDorp => 'Village';

  @override
  String get sceneCityPlannerDataGemeente => 'Commune';

  @override
  String get sceneCityPlannerDataStad => 'Ville';

  @override
  String get sceneCityPlannerDataMetropool => 'Métropole';

  @override
  String get sceneCityPlannerDataToekomststad => 'Ville du futur';

  @override
  String get sceneCityPlannerDataVerkeerslichten => 'Feux de circulation';

  @override
  String get sceneCityPlannerData15WegcapaciteitOpKruispunten =>
      '+15% de capacité routière aux intersections.';

  @override
  String get sceneCityPlannerDataRotondes => 'Ronds-points';

  @override
  String get sceneCityPlannerData10DoorstromingOpAlleWegen =>
      '+10% de fluidité sur toutes les routes.';

  @override
  String get sceneCityPlannerDataTramnetwerk => 'Réseau de tramways';

  @override
  String get sceneCityPlannerDataOntgrendeltTramsEnTramremises =>
      'Débloque les tramways et leurs dépôts.';

  @override
  String get sceneCityPlannerDataSnelwegen => 'Autoroutes';

  @override
  String get sceneCityPlannerDataOntgrendeltSnelwegen =>
      'Débloque les autoroutes.';

  @override
  String get sceneCityPlannerDataParkeergarages => 'Parkings à étages';

  @override
  String get sceneCityPlannerDataOntgrendeltMeerlaagsParkeren =>
      'Débloque le stationnement à étages.';

  @override
  String get sceneCityPlannerDataMetro => 'Métro';

  @override
  String get sceneCityPlannerDataOntgrendeltMetrolijnen =>
      'Débloque les lignes de métro.';

  @override
  String get sceneCityPlannerDataSpoorwegen => 'Chemins de fer';

  @override
  String get sceneCityPlannerDataOntgrendeltTreinenEnStations =>
      'Débloque les trains et les gares.';

  @override
  String get sceneCityPlannerDataLuchtvaart => 'Aviation';

  @override
  String get sceneCityPlannerDataOntgrendeltDeLuchthavenToerisme =>
      'Débloque l’aéroport (tourisme).';

  @override
  String get sceneCityPlannerDataHavenlogistiek => 'Logistique portuaire';

  @override
  String get sceneCityPlannerDataOntgrendeltDeHavenMaterialenToerisme =>
      'Débloque le port (matériaux + tourisme).';

  @override
  String get sceneCityPlannerDataAiVerkeersbeheer => 'Gestion du trafic par IA';

  @override
  String get sceneCityPlannerData30Wegcapaciteit20Files =>
      '+30% de capacité routière, −20% d’embouteillages.';

  @override
  String get sceneCityPlannerDataAutonomeVoertuigen => 'Véhicules autonomes';

  @override
  String get sceneCityPlannerData25ParkeerbehoefteSnellereReistijden =>
      '−25% de besoin de stationnement, trajets plus rapides.';

  @override
  String get sceneCityPlannerDataModernBeton => 'Béton moderne';

  @override
  String get sceneCityPlannerData10Bouwkosten =>
      '−10% de coûts de construction.';

  @override
  String get sceneCityPlannerDataPrefabBouw => 'Construction préfabriquée';

  @override
  String get sceneCityPlannerData15Bouwkosten =>
      '−15% de coûts de construction.';

  @override
  String get sceneCityPlannerDataWolkenkrabbers => 'Gratte-ciel';

  @override
  String get sceneCityPlannerDataOntgrendeltWoontorensTot40Verdiepingen =>
      'Débloque les tours résidentielles de 40 étages maximum.';

  @override
  String get sceneCityPlannerDataSlimmeGebouwen => 'Bâtiments intelligents';

  @override
  String get sceneCityPlannerData20EnergieEnWaterverbruikVanGebouwen =>
      '−20% de consommation d’énergie et d’eau des bâtiments.';

  @override
  String get sceneCityPlannerDataWindenergie => 'Énergie éolienne';

  @override
  String get sceneCityPlannerDataOntgrendeltWindmolens =>
      'Débloque les éoliennes.';

  @override
  String get sceneCityPlannerDataZonneEnergie => 'Énergie solaire';

  @override
  String get sceneCityPlannerDataOntgrendeltZonneparken =>
      'Débloque les parcs solaires.';

  @override
  String get sceneCityPlannerDataGascentrales => 'Centrales à gaz';

  @override
  String get sceneCityPlannerDataOntgrendeltGascentralesSchonerDanKolen =>
      'Débloque les centrales à gaz (plus propres que le charbon).';

  @override
  String get sceneCityPlannerDataWaterkracht => 'Hydroélectricité';

  @override
  String get sceneCityPlannerDataOntgrendeltWaterkrachtcentralesAanWater =>
      'Débloque les centrales hydroélectriques (au bord de l’eau).';

  @override
  String get sceneCityPlannerDataEnergieopslag => 'Stockage d’énergie';

  @override
  String
  get sceneCityPlannerDataOntgrendeltBatterijenDemptSchommelingenVanWindZon =>
      'Débloque les batteries : atténue les fluctuations éoliennes et solaires.';

  @override
  String get sceneCityPlannerDataKernenergie => 'Énergie nucléaire';

  @override
  String get sceneCityPlannerDataOntgrendeltKerncentrales =>
      'Débloque les centrales nucléaires.';

  @override
  String get sceneCityPlannerDataFusieEnergie => 'Énergie de fusion';

  @override
  String get sceneCityPlannerDataOntgrendeltDeFusiereactor =>
      'Débloque le réacteur à fusion.';

  @override
  String get sceneCityPlannerDataOntgrendeltGroteDrinkwaterzuivering =>
      'Débloque les grandes usines de traitement d’eau potable.';

  @override
  String get sceneCityPlannerDataModernRiool => 'Égouts modernes';

  @override
  String
  get sceneCityPlannerDataOntgrendeltRioolwaterzuiveringMinderVervuiling =>
      'Débloque le traitement des eaux usées (moins de pollution).';

  @override
  String get sceneCityPlannerDataRecycling => 'Recyclage';

  @override
  String get sceneCityPlannerDataOntgrendeltHetRecyclingcentrum =>
      'Débloque le centre de recyclage.';

  @override
  String get sceneCityPlannerDataAfvalenergie => 'Énergie des déchets';

  @override
  String get sceneCityPlannerDataOntgrendeltDeAfvalenergiecentrale =>
      'Débloque l’usine de valorisation énergétique.';

  @override
  String get sceneCityPlannerDataGroeneDaken => 'Toitures végétalisées';

  @override
  String get sceneCityPlannerData15VervuilingInWoongebieden =>
      '−15% de pollution dans les zones résidentielles.';

  @override
  String get sceneCityPlannerDataNatuurbeheer => 'Gestion de la nature';

  @override
  String get sceneCityPlannerDataParkenEnBosWerken50Sterker =>
      'Les parcs et forêts sont 50% plus efficaces.';

  @override
  String get sceneCityPlannerDataVerticalFarming => 'Agriculture verticale';

  @override
  String get sceneCityPlannerDataOntgrendeltVerticalFarmsInDeStad =>
      'Débloque les fermes verticales en ville.';

  @override
  String get sceneCityPlannerDataBeterOnderwijs => 'Meilleure éducation';

  @override
  String get sceneCityPlannerData25SchoolcapaciteitEnKwaliteit =>
      '+25% de capacité et de qualité scolaires.';

  @override
  String get sceneCityPlannerDataModerneZorg => 'Soins modernes';

  @override
  String get sceneCityPlannerData25ZorgcapaciteitGezondereInwoners =>
      '+25% de capacité de soins, habitants en meilleure santé.';

  @override
  String get sceneCityPlannerDataSocialeWoningbouw => 'Logement social';

  @override
  String get sceneCityPlannerDataGoedkoperWonenTevredenheidLageInkomens =>
      'Logements moins chers : satisfaction accrue des faibles revenus.';

  @override
  String get sceneCityPlannerDataSubsidieZonnepanelen =>
      'Subvention des panneaux solaires';

  @override
  String get sceneCityPlannerDataGebouwenWekkenZelfWatStroomOp8Netvraag =>
      'Les bâtiments produisent de l’électricité (−8% de demande du réseau).';

  @override
  String get sceneCityPlannerDataBelastingOpVervuiling =>
      'Taxe sur la pollution';

  @override
  String
  get sceneCityPlannerDataExtraInkomsten10Industrieproductie15Vervuiling =>
      'Revenus supplémentaires, −10% de production industrielle, −15% de pollution.';

  @override
  String get sceneCityPlannerDataKernenergieVerbieden =>
      'Interdire l’énergie nucléaire';

  @override
  String
  get sceneCityPlannerDataKerncentralesWordenUitgeschakeldSommigeInwonersBlijAnderenNiet =>
      'Les centrales nucléaires sont arrêtées. Certains habitants approuvent, d’autres non.';

  @override
  String get sceneCityPlannerDataLokaleLandbouwStimuleren =>
      'Soutenir l’agriculture locale';

  @override
  String get sceneCityPlannerData25OpbrengstVanAkkersKassenEnBoerderijen =>
      '+25% de rendement des champs, serres et fermes.';

  @override
  String get sceneCityPlannerDataGoedkopeVoedselimport =>
      'Importations alimentaires bon marché';

  @override
  String
  get sceneCityPlannerDataVoedseltekortenWordenGoedkoperOpgevangen40Importkosten =>
      'Les pénuries alimentaires coûtent moins cher à compenser (−40% de coûts d’importation).';

  @override
  String get sceneCityPlannerDataBenzinebelasting => 'Taxe sur le carburant';

  @override
  String get sceneCityPlannerDataInkomsten10AutoverkeerKleineTevredenheid =>
      'Revenus, −10% de trafic automobile, légère baisse de satisfaction.';

  @override
  String get sceneCityPlannerDataElektrischRijdenStimuleren =>
      'Encourager les véhicules électriques';

  @override
  String get sceneCityPlannerData30VerkeersvervuilingEnergievraag =>
      '−30% de pollution routière, demande d’énergie accrue.';

  @override
  String get sceneCityPlannerDataOvSubsidie =>
      'Subvention des transports publics';

  @override
  String get sceneCityPlannerDataGratisErOV40OVGebruikMinderFiles =>
      'Transports publics gratuits ou moins chers : +40% d’utilisation, moins d’embouteillages.';

  @override
  String get sceneCityPlannerDataGroeneGebouwenVerplicht =>
      'Imposer des bâtiments écologiques';

  @override
  String get sceneCityPlannerData15Bouwkosten20EnergieverbruikNieuweGebouwen =>
      '+15% de coûts de construction, −20% de consommation d’énergie des nouveaux bâtiments.';

  @override
  String get sceneCityPlannerDataGoedkopeWoningbouw => 'Logements abordables';

  @override
  String
  get sceneCityPlannerDataTevredenheidEnSnellereMigratieBijWoningtekort =>
      'Satisfaction accrue et migration plus rapide en cas de pénurie de logements.';

  @override
  String get sceneCityPlannerDataKaartweergaveNormaal => 'Carte : normale';

  @override
  String get sceneCityPlannerDataHeatmapVerkeersdrukte =>
      'Carte thermique : trafic';

  @override
  String get sceneCityPlannerDataHeatmapGeluid => 'Carte thermique : bruit';

  @override
  String get sceneCityPlannerDataHeatmapLuchtkwaliteit =>
      'Carte thermique : qualité de l’air';

  @override
  String get sceneCityPlannerDataHeatmapGeluk => 'Carte thermique : bonheur';

  @override
  String get sceneCityPlannerDataHeatmapGrondwaarde =>
      'Carte thermique : valeur foncière';

  @override
  String get sceneCityPlannerDataHeatmapOVBereikbaarheid =>
      'Carte thermique : accès aux transports';

  @override
  String get sceneCityPlannerDataHeatmapOnderwijs =>
      'Carte thermique : éducation';

  @override
  String get sceneCityPlannerDataHeatmapGezondheid => 'Carte thermique : santé';

  @override
  String get sceneCityPlannerDataHeatmapVeiligheid =>
      'Carte thermique : sécurité';

  @override
  String get sceneCityPlannerDataHeatmapGroen =>
      'Carte thermique : espaces verts';

  @override
  String get sceneCityPlannerDataHeatmapEnergienet =>
      'Carte thermique : réseau électrique';

  @override
  String get sceneCityPlannerDataHeatmapWaternet =>
      'Carte thermique : réseau d’eau';

  @override
  String get sceneCityPlannerDataEgaliserenGras =>
      'Aplanir le terrain (→ herbe)';

  @override
  String get sceneCityPlannerDataMaaktBosHeuvelZandBouwrijp =>
      'Prépare les forêts, collines et zones sablonneuses à la construction.';

  @override
  String get sceneCityPlannerDataWaterGraven => 'Creuser un plan d’eau';

  @override
  String get sceneCityPlannerDataGraaftEenMeerOfKanaal =>
      'Creuse un lac ou un canal.';

  @override
  String get sceneCityPlannerDataBosPlanten => 'Planter une forêt';

  @override
  String get sceneCityPlannerDataPlantBosMinderVervuilingMooierWonen =>
      'Plante des forêts : moins de pollution, cadre de vie plus agréable.';

  @override
  String get sceneCityPlannerDataVruchtbareGrondVoorAkkers =>
      'Terres fertiles pour les cultures.';

  @override
  String get sceneSpaceColonyDataLandingModule => 'Landingmodule';

  @override
  String
  get sceneSpaceColonyDataYourStartingHomeGeneratesATrickleOfPowerAndSheltersColonists =>
      'Je startwoning. Levert een beetje stroom en biedt onderdak aan kolonisten.';

  @override
  String get sceneSpaceColonyDataSolarPanel => 'Zonnepaneel';

  @override
  String get sceneSpaceColonyData6PowerDuringTheDay => '+6 stroom overdag.';

  @override
  String get sceneSpaceColonyDataWindTurbine => 'Windturbine';

  @override
  String get sceneSpaceColonyData4PowerDayAndNightBoostedDuringDustStorms =>
      '+4 stroom, dag en nacht. Extra opbrengst tijdens stofstormen.';

  @override
  String get sceneSpaceColonyDataBattery => 'Accu';

  @override
  String get sceneSpaceColonyDataStores120PowerForTheNight =>
      'Slaat 120 stroom op voor de nacht.';

  @override
  String get sceneSpaceColonyDataGeothermalPlant => 'Geothermische centrale';

  @override
  String get sceneSpaceColonyData18PowerMustBeBuiltOnALavaZone =>
      '+18 stroom. Moet op een lavaveld worden gebouwd.';

  @override
  String get sceneSpaceColonyDataNuclearReactor => 'Kernreactor';

  @override
  String get sceneSpaceColonyData45PowerDayAndNight =>
      '+45 stroom, dag en nacht.';

  @override
  String get sceneSpaceColonyDataOxygenGenerator => 'Zuurstofgenerator';

  @override
  String get sceneSpaceColonyDataElectrolysesWater6OHUsesPowerAndALittleWater =>
      'Splitst water: +6 O₂/u, verbruikt stroom en een beetje water.';

  @override
  String get sceneSpaceColonyDataWaterExtractor => 'Waterpomp';

  @override
  String get sceneSpaceColonyData5WaterHMustBeBuiltOnAnIceField =>
      '+5 water/u. Moet op een ijsveld worden gebouwd.';

  @override
  String get sceneSpaceColonyDataWaterRecycler => 'Waterrecycler';

  @override
  String get sceneSpaceColonyData25WaterHAnywhereReclaimedFromWaste =>
      '+2,5 water/u, overal teruggewonnen uit afval.';

  @override
  String get sceneSpaceColonyDataGreenhouse => 'Kas';

  @override
  String
  get sceneSpaceColonyData3FoodAnd1OPerHourUsesWaterFarmingSkillBoostsYield =>
      '+3 voedsel en +1 O₂ per uur. Verbruikt water. Landbouwvaardigheid verhoogt de opbrengst.';

  @override
  String get sceneSpaceColonyDataHydroponicFarm => 'Hydrocultuurboerderij';

  @override
  String get sceneSpaceColonyData7FoodHHighDensityFarming =>
      '+7 voedsel/u door intensieve teelt.';

  @override
  String get sceneSpaceColonyDataMiningRig => 'Mijnbouwinstallatie';

  @override
  String
  get sceneSpaceColonyData25MetalHMustBeOnAMetalDepositMiningSkillBoostsYield =>
      '+2,5 metaal/u. Moet op een metaalafzetting staan. Mijnbouwvaardigheid verhoogt de opbrengst.';

  @override
  String get sceneSpaceColonyDataCrystalExtractor => 'Kristalextractor';

  @override
  String get sceneSpaceColonyData08AlienCrystalHMustBeOnACrystalDeposit =>
      '+0,8 buitenaards kristal/u. Moet op een kristalafzetting staan.';

  @override
  String get sceneSpaceColonyDataGlassworks => 'Glasfabriek';

  @override
  String get sceneSpaceColonyDataSmeltsSand2GlassH => 'Smelt zand: +2 glas/u.';

  @override
  String get sceneSpaceColonyDataElectronicsFab => 'Elektronicafabriek';

  @override
  String get sceneSpaceColonyData15ElectronicsHConsumes1MetalH =>
      '+1,5 elektronica/u, verbruikt 1 metaal/u.';

  @override
  String get sceneSpaceColonyDataLivingQuarters => 'Woonverblijven';

  @override
  String get sceneSpaceColonyDataHouses3ColonistsAndLetsThemSleepComfortably =>
      'Biedt plaats aan 3 kolonisten en een comfortabele slaapplaats.';

  @override
  String get sceneSpaceColonyDataPark => 'Park';

  @override
  String
  get sceneSpaceColonyDataAGreenOasisAmongTheDustSlowlyBoostsColonistHappinessNoResearchRequired =>
      'Een groene oase in het stof. Verhoogt langzaam het geluk van kolonisten. Geen onderzoek nodig.';

  @override
  String get sceneSpaceColonyDataLaboratory => 'Laboratorium';

  @override
  String get sceneSpaceColonyData15ScienceHScienceSkillBoostsOutput =>
      '+1,5 wetenschap/u. Wetenschapsvaardigheid verhoogt de opbrengst.';

  @override
  String get sceneSpaceColonyDataMedicalBay => 'Medische post';

  @override
  String get sceneSpaceColonyDataSlowlyHealsSickAndInjuredColonists =>
      'Geneest zieke en gewonde kolonisten langzaam.';

  @override
  String get sceneSpaceColonyDataStorageDepot => 'Opslagdepot';

  @override
  String get sceneSpaceColonyData150CapacityForAllMaterials =>
      '+150 opslagcapaciteit voor alle materialen.';

  @override
  String get sceneSpaceColonyDataDroneBay => 'Dronehangar';

  @override
  String get sceneSpaceColonyDataAutomation25OutputFromAllProducersStacks =>
      'Automatisering: +25% productie voor alle producenten (stapelt).';

  @override
  String get sceneSpaceColonyDataTradeBeacon => 'Handelsbaken';

  @override
  String
  get sceneSpaceColonyDataEvery24hSells5CrystalToEarthFor20Metal10GlassAnd6Electronics =>
      'Verkoopt elke 24 uur 5 kristal aan de aarde voor 20 metaal, 10 glas en 6 elektronica.';

  @override
  String get sceneSpaceColonyDataVehicleGarage => 'Voertuiggarage';

  @override
  String
  get sceneSpaceColonyDataUnlocksRoverDispatchSendARoverToExploreAnAncientRuinsTileForAOneTimeReward =>
      'Ontgrendelt rovermissies: stuur een rover naar een tegel met Oude Ruïnes voor een eenmalige beloning.';

  @override
  String get sceneSpaceColonyDataObservatory => 'Sterrenwacht';

  @override
  String
  get sceneSpaceColonyData1ScienceHAndGivesEarlyWarningOfIncomingMeteorsHalvingTheDamageTheyDeal =>
      '+1 wetenschap/u en waarschuwt vroeg voor naderende meteoren, waardoor hun schade halveert.';

  @override
  String get sceneSpaceColonyDataDefenseTurret => 'Verdedigingstoren';

  @override
  String
  get sceneSpaceColonyDataAutomaticallyShootsDownIncomingMeteorsBeforeTheyHit75InterceptChance =>
      'Schiet naderende meteoren automatisch neer voordat ze inslaan — 75% onderscheppingskans.';

  @override
  String get sceneSpaceColonyDataWindTurbines => 'Windturbines';

  @override
  String get sceneSpaceColonyDataEnergy => 'Energie';

  @override
  String get sceneSpaceColonyDataUnlocksWindPowerWorksAtNight =>
      'Ontgrendelt windenergie, werkt ook ’s nachts.';

  @override
  String get sceneSpaceColonyDataGeothermalPower => 'Geothermische energie';

  @override
  String get sceneSpaceColonyDataUnlocksGeothermalPlantsOnLavaZones =>
      'Ontgrendelt geothermische centrales op lavavelden.';

  @override
  String get sceneSpaceColonyDataNuclearPower => 'Kernenergie';

  @override
  String get sceneSpaceColonyDataUnlocksTheNuclearReactor =>
      'Ontgrendelt de kernreactor.';

  @override
  String get sceneSpaceColonyDataHydroponics => 'Hydrocultuur';

  @override
  String get sceneSpaceColonyDataBiology => 'Biologie';

  @override
  String get sceneSpaceColonyDataUnlocksHighYieldHydroponicFarms =>
      'Ontgrendelt hydrocultuurboerderijen met hoge opbrengst.';

  @override
  String get sceneSpaceColonyDataWaterRecycling => 'Waterrecycling';

  @override
  String get sceneSpaceColonyDataUnlocksWaterRecyclersNoIceNeeded =>
      'Ontgrendelt waterrecyclers (geen ijs nodig).';

  @override
  String get sceneSpaceColonyDataMedicine => 'Geneeskunde';

  @override
  String get sceneSpaceColonyDataUnlocksTheMedicalBay =>
      'Ontgrendelt de medische post.';

  @override
  String get sceneSpaceColonyDataCrystalExtraction => 'Kristalwinning';

  @override
  String get sceneSpaceColonyDataEngineering => 'Techniek';

  @override
  String get sceneSpaceColonyDataUnlocksCrystalExtractors =>
      'Ontgrendelt kristalextractors.';

  @override
  String get sceneSpaceColonyDataImprovedBatteries => 'Verbeterde accu’s';

  @override
  String get sceneSpaceColonyDataBatteriesStore60Power =>
      'Accu’s slaan +60 stroom op.';

  @override
  String get sceneSpaceColonyDataRobotics => 'Robotica';

  @override
  String get sceneSpaceColonyDataUnlocksDroneBays25Production =>
      'Ontgrendelt dronehangars (+25% productie).';

  @override
  String get sceneSpaceColonyDataOrbitalTrade => 'Orbitale handel';

  @override
  String get sceneSpaceColonyDataSpace => 'Ruimte';

  @override
  String get sceneSpaceColonyDataUnlocksTheTradeBeacon =>
      'Ontgrendelt het handelsbaken.';

  @override
  String get sceneSpaceColonyDataExplorationRovers => 'Verkenningsrovers';

  @override
  String
  get sceneSpaceColonyDataUnlocksTheVehicleGarageAndObservatoryLettingYouExploreAncientRuins =>
      'Ontgrendelt de voertuiggarage en sterrenwacht, zodat je Oude Ruïnes kunt verkennen.';

  @override
  String get sceneSpaceColonyDataAdvancedMining => 'Geavanceerde mijnbouw';

  @override
  String get sceneSpaceColonyData50OutputFromMiningRigsAndCrystalExtractors =>
      '+50% opbrengst van mijnbouwinstallaties en kristalextractors.';

  @override
  String get sceneSpaceColonyDataDefenseSystems => 'Verdedigingssystemen';

  @override
  String
  get sceneSpaceColonyDataUnlocksTheDefenseTurretWhichShootsDownIncomingMeteors =>
      'Ontgrendelt de verdedigingstoren, die naderende meteoren neerschiet.';

  @override
  String get sceneSpaceColonyDataTerraforming => 'Terraforming';

  @override
  String
  get sceneSpaceColonyDataCapstoneTechYourColonyIsNowAdvancedEnoughToBeginTerraformingThePlanet =>
      'Eindtechnologie: je kolonie is nu ver genoeg ontwikkeld om de planeet te terraformen.';

  @override
  String sceneCityPlannerDrawBuildingShape(Object building, Object cost) {
    return 'Faites glisser les cellules pour dessiner la forme de votre $building. Coût : $cost par cellule et par étage.';
  }

  @override
  String sceneCityPlannerAvailableFromPhase(Object name, Object phase) {
    return 'Disponible à partir de la phase $phase ($name).';
  }

  @override
  String sceneSubwayVehicleBuyTitle(Object cost, Object vehicle) {
    return 'Acheter un $vehicle ($cost)';
  }

  @override
  String sceneSubwayVehicleSellTitle(Object vehicle) {
    return 'Vendre un $vehicle';
  }

  @override
  String get sceneCityPlannerMonthJanuary => 'janv.';

  @override
  String get sceneCityPlannerMonthFebruary => 'févr.';

  @override
  String get sceneCityPlannerMonthMarch => 'mars';

  @override
  String get sceneCityPlannerMonthApril => 'avr.';

  @override
  String get sceneCityPlannerMonthMay => 'mai';

  @override
  String get sceneCityPlannerMonthJune => 'juin';

  @override
  String get sceneCityPlannerMonthJuly => 'juil.';

  @override
  String get sceneCityPlannerMonthAugust => 'août';

  @override
  String get sceneCityPlannerMonthSeptember => 'sept.';

  @override
  String get sceneCityPlannerMonthOctober => 'oct.';

  @override
  String get sceneCityPlannerMonthNovember => 'nov.';

  @override
  String get sceneCityPlannerMonthDecember => 'déc.';

  @override
  String sceneCityPlannerSaveFailed(Object error) {
    return 'Échec de l’enregistrement : $error';
  }

  @override
  String get schoolFormulaDefaultCategory => 'Personnalisé';

  @override
  String get marketplaceLoadFailedDetail =>
      'Vérifiez votre connexion, puis réessayez.';

  @override
  String fileTreeErrorDetail(Object detail) {
    return 'Échec de l’analyse : $detail';
  }

  @override
  String get sceneSpaceColonyStatusBroken =>
      'EN PANNE — cliquez pour réparer (2🔩)';

  @override
  String get sceneSpaceColonyStatusDepleted =>
      'ÉPUISÉ — gisement à sec, démolissez pour récupérer la case';

  @override
  String get sceneSpaceColonyStatusOnline => 'en ligne';

  @override
  String get sceneSpaceColonyStatusNoPowerInput => 'pas d’énergie/d’entrée';

  @override
  String get sceneSpaceColonyColonistNeedsTitle =>
      'faim / O₂ / sommeil / bonheur / santé';

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
    return 'Coût : $resources';
  }

  @override
  String sceneSpaceColonyRequiresResearch(Object technology) {
    return '(recherche requise : $technology)';
  }

  @override
  String get sceneSpaceColonyMeterHunger => 'Faim';

  @override
  String get sceneSpaceColonyMeterOxygen => 'Oxygène';

  @override
  String get sceneSpaceColonyMeterSleep => 'Sommeil';

  @override
  String get sceneSpaceColonyMeterHappiness => 'Bonheur';

  @override
  String get sceneSpaceColonyMeterHealth => 'Santé';

  @override
  String sceneSpaceColonyPowerLabel(Object power) {
    return 'Énergie $power';
  }

  @override
  String sceneCityPlannerNewsResearchCompleted(Object technology) {
    return '🔬 Recherche terminée : $technology';
  }

  @override
  String sceneCityPlannerNewsPhaseGrowth(Object name, Object phase) {
    return '🏙 Votre ville passe à la phase $phase : $name ! Nouveaux bâtiments débloqués.';
  }

  @override
  String get sceneCityPlannerNewsBankruptcy =>
      '💸 La ville est au bord de la faillite ! Réduisez les dépenses ou augmentez les impôts.';

  @override
  String get sceneCityPlannerNewsPowerOutage =>
      '⚡ Panne de courant ! Le réseau est surchargé : une partie de la ville est privée d’électricité.';

  @override
  String get sceneCityPlannerNewsDrought =>
      '🌵 Sécheresse ! La demande en eau approche l’offre. Construisez des pompes ou des stations de traitement.';

  @override
  String get sceneCityPlannerNewsCloudyWeek =>
      '🌥 Une semaine nuageuse : l’éolien et le solaire produisent moins.';

  @override
  String get sceneCityPlannerNewsFoodShortage =>
      '🌾 Une pénurie alimentaire se profile : les importations coûteront plus cher ce mois-ci.';

  @override
  String sceneCityPlannerNewsRegionalGrant(Object amount) {
    return '🎉 Subvention régionale reçue : € $amount.';
  }

  @override
  String get sceneCityPlannerNewsEconomicDownturn =>
      '📉 Ralentissement économique : les recettes de la taxe professionnelle baissent de 20 % ce mois-ci.';

  @override
  String sceneCityPlannerNewsBuildingFire(Object building) {
    return '🔥 Incendie dans $building ! Sans pompiers à proximité, le bâtiment est détruit.';
  }

  @override
  String get sceneSpaceColonyEventMeteorWarningNote =>
      '(l’observatoire a atténué l’impact)';

  @override
  String get sceneSpaceColonyEventLandingSuccess =>
      'Atterrissage réussi. Le sol 1 commence sur un monde inexploré.';

  @override
  String get sceneSpaceColonyEventSurvivalTip =>
      'Gardez l’oxygène, la nourriture et l’énergie à un niveau positif pour survivre.';

  @override
  String get sceneSpaceColonyEventMoraleLow =>
      '😠 Le moral est dangereusement bas — la production en souffre.';

  @override
  String sceneSpaceColonyEventDepositDepleted(
    Object building,
    Object resource,
  ) {
    return 'Le gisement de $resource sous votre $building est épuisé — le bâtiment est à l’arrêt. Déplacez-le ou démolissez-le.';
  }

  @override
  String sceneSpaceColonyEventDepositExhausted(Object resource) {
    return '⛏️ Un gisement de $resource est épuisé !';
  }

  @override
  String sceneSpaceColonyEventRecoveredMedical(Object colonist) {
    return '$colonist s’est rétabli à l’infirmerie.';
  }

  @override
  String sceneSpaceColonyEventRecovered(Object colonist) {
    return '$colonist s’est rétabli.';
  }

  @override
  String sceneSpaceColonyEventSkillImproved(
    Object colonist,
    Object level,
    Object skill,
  ) {
    return '$colonist a amélioré $skill au niveau $level.';
  }

  @override
  String sceneSpaceColonyEventColonistDied(Object colonist) {
    return '$colonist est décédé.';
  }

  @override
  String sceneSpaceColonyEventNewColonist(Object name) {
    return 'Une nouvelle colonie, $name, est arrivée de la Terre !';
  }

  @override
  String get sceneSpaceColonyEventTradeBeacon =>
      'Balise commerciale : 5 cristaux vendus → +20 métal, +10 verre, +6 composants électroniques.';

  @override
  String get sceneSpaceColonyEventDustStormPassed =>
      'La tempête de poussière est passée.';

  @override
  String get sceneSpaceColonyEventSolarFlareOver =>
      'Éruption solaire terminée — production d’énergie rétablie.';

  @override
  String get sceneSpaceColonyAlertMoraleLow =>
      '😠 Le moral est dangereusement bas — la production en souffre.';

  @override
  String get sceneSpaceColonyAlertDustStorm =>
      '🌪️ Tempête de poussière ! Production solaire divisée par deux.';

  @override
  String get sceneSpaceColonyEventDustStorm =>
      'Une tempête de poussière approche. Les panneaux solaires faiblissent, les éoliennes sont renforcées.';

  @override
  String get sceneSpaceColonyAlertSolarFlare =>
      '☀️ Éruption solaire ! Production −80 %.';

  @override
  String get sceneSpaceColonyEventSolarFlare =>
      'Éruption solaire détectée ! Toute la production d’énergie est temporairement paralysée.';

  @override
  String sceneSpaceColonyAlertBuildingBreakdown(Object building) {
    return '🔧 $building est en panne !';
  }

  @override
  String sceneSpaceColonyEventBuildingFailure(Object building) {
    return '$building a subi une panne. Cliquez dessus pour réparer (2 métaux).';
  }

  @override
  String sceneSpaceColonyAlertColonistIll(Object colonist) {
    return '🤒 $colonist est tombé malade.';
  }

  @override
  String sceneSpaceColonyEventColonistIll(Object colonist) {
    return '$colonist a contracté un microbe extraterrestre. Une infirmerie aiderait.';
  }

  @override
  String sceneSpaceColonyEventMeteorIntercepted(Object building) {
    return 'La tourelle a détruit une météorite avant qu’elle ne frappe $building.';
  }

  @override
  String get sceneSpaceColonyAlertMeteorIntercepted =>
      '🛡️ Météorite interceptée !';

  @override
  String sceneSpaceColonyEventMeteorDestroyed(Object building) {
    return 'Une météorite a détruit $building !';
  }

  @override
  String sceneSpaceColonyAlertMeteorDestroyed(Object building) {
    return '☄️ L’impact d’une météorite a détruit $building !';
  }

  @override
  String sceneSpaceColonyEventMeteorDamage(
    Object building,
    Object observatoryNote,
  ) {
    return 'Une pluie de météorites a endommagé $building$observatoryNote';
  }

  @override
  String get sceneSpaceColonyAlertMeteorShower => '☄️ Pluie de météorites !';

  @override
  String sceneSpaceColonyEventScavengedMetal(Object amount) {
    return 'Des récupérateurs ont trouvé $amount métal dans d’anciens débris météoritiques.';
  }

  @override
  String get sceneSpaceColonyAlertCannotBuild =>
      'Impossible de construire ici.';

  @override
  String get sceneSpaceColonyAlertNotEnoughMaterials =>
      'Matériaux insuffisants.';

  @override
  String sceneSpaceColonyEventBuildingBuilt(Object building) {
    return '$building construit.';
  }

  @override
  String sceneSpaceColonyEventRoverData(Object science) {
    return 'Le rover a récupéré des données anciennes : +$science science.';
  }

  @override
  String sceneSpaceColonyAlertRoverData(Object science) {
    return '🛰️ Le rover est revenu avec +$science science !';
  }

  @override
  String sceneSpaceColonyEventRoverCrystal(Object amount) {
    return 'Le rover a récupéré $amount cristal extraterrestre dans les ruines.';
  }

  @override
  String sceneSpaceColonyAlertRoverCrystal(Object amount) {
    return '🛰️ Le rover a récupéré $amount cristal extraterrestre !';
  }

  @override
  String sceneSpaceColonyEventRoverMaterials(Object glass, Object metal) {
    return 'Le rover a récupéré $metal métal et $glass verre.';
  }

  @override
  String get sceneSpaceColonyAlertRoverMaterials =>
      '🛰️ Le rover a récupéré des matériaux !';

  @override
  String sceneSpaceColonyEventRoverTech(Object technology) {
    return 'Le rover a découvert un savoir ancien — $technology débloquée gratuitement !';
  }

  @override
  String sceneSpaceColonyAlertRoverTech(Object technology) {
    return '🛰️ Savoir technologique ancien : $technology débloquée !';
  }

  @override
  String get sceneSpaceColonyEventRoverScience =>
      'Le rover a récupéré +30 science dans les ruines.';

  @override
  String get sceneSpaceColonyAlertRoverScience =>
      '🛰️ Le rover est revenu avec +30 science !';

  @override
  String get sceneSpaceColonyAlertRoverNeedsPower =>
      'Énergie insuffisante (15 requise) pour envoyer le rover.';

  @override
  String get sceneSpaceColonyAlertRoverChooseRuins =>
      'Choisissez une case de ruines anciennes (violet poussiéreux) pour le rover.';

  @override
  String sceneSpaceColonyEventBuildingDemolished(Object building) {
    return '$building démoli.';
  }

  @override
  String sceneSpaceColonyEventBuildingRepaired(Object building) {
    return '$building réparé.';
  }

  @override
  String get sceneSpaceColonyAlertRepairNeedsMetal =>
      '2 métaux nécessaires pour réparer.';

  @override
  String get sceneSpaceColonyAlertSendRover =>
      'Cliquez sur une case de ruines anciennes (violet poussiéreux) pour envoyer le rover.';

  @override
  String sceneSpaceColonyEventResearchComplete(Object technology) {
    return 'Recherche terminée : $technology !';
  }

  @override
  String get sceneSpaceColonyAlertTerraformUnlocked =>
      '🌍 Terraformage débloqué — l’avenir de votre colonie est assuré !';

  @override
  String get sceneSpaceColonyEventTerraformAchievement =>
      'Succès : recherche sur le terraforming terminée. La survie à long terme est assurée.';

  @override
  String get sceneSpaceColonyEventGameSaved => 'Partie enregistrée.';

  @override
  String get sceneSpaceColonyEventGameLoaded => 'Partie chargée.';

  @override
  String get sceneSpaceColonyAlertNoSave => 'Aucune sauvegarde trouvée.';

  @override
  String get sceneSubwayCouldNotReachCoopServer =>
      'Serveur coopératif injoignable';

  @override
  String get sceneSubwayLostConnectionReconnecting =>
      'Connexion à la salle perdue — reconnexion…';

  @override
  String get sceneSubwayClockAuthorityRunning =>
      'Exécution de l’horloge de cette salle';

  @override
  String sceneSubwayTravellingToPlace(Object place) {
    return 'En route vers $place…';
  }

  @override
  String sceneSubwayJoinedRoom(Object code) {
    return 'Salle $code rejointe';
  }

  @override
  String sceneSubwayRoomCreatedStartBuilding(Object code) {
    return 'Salle $code créée — commencez à construire';
  }

  @override
  String get sceneSubwayLoadCityFirst => 'Chargez d’abord une ville';

  @override
  String sceneSubwayRoomCreatedShareCode(Object code) {
    return 'Salle $code créée — partagez le code ou invitez un contact';
  }

  @override
  String sceneSubwayInviteChatMessage(Object code) {
    return 'Rejoins ma salle coop de Subway Builder : ouvre Subway Builder, appuie sur Co-op → Rejoindre et saisis le code $code.';
  }

  @override
  String sceneSubwayFailedToSendInvite(Object error) {
    return 'Échec de l’envoi du message d’invitation : $error';
  }

  @override
  String get sceneSubwayStillSyncing => 'Synchronisation avec l’hôte en cours…';

  @override
  String sceneSubwaySurveyingPlace(Object place) {
    return 'Exploration de $place… lecture de l’occupation des sols, de l’eau et des quartiers via OpenStreetMap';
  }

  @override
  String get sceneSubwayTracingStreets =>
      'Tracé des rues et voies ferrées… récupération de données ferroviaires réelles';

  @override
  String get sceneSubwaySurveyingRailCorridor =>
      'Exploration du corridor ferroviaire…';

  @override
  String get sceneSubwayAlreadyOnDraft => 'Déjà dans ce brouillon';

  @override
  String get sceneSubwayNativeBridgeTimedOut => 'Le pont natif a expiré';

  @override
  String get sceneSubwayNativeBridgeUnavailable =>
      'Le pont natif est indisponible';

  @override
  String get schoolQuizSubjectRekenen => 'Mathématiques';

  @override
  String get schoolQuizSubjectTaalverzorging => 'Maîtrise de la langue';

  @override
  String get schoolQuizSubjectLezen => 'Compréhension écrite';

  @override
  String get schoolQuizSubjectEngels => 'Anglais';

  @override
  String get schoolQuizSubjectAardrijkskunde => 'Géographie';

  @override
  String get schoolQuizSubjectGeschiedenis => 'Histoire';

  @override
  String get schoolQuizSubjectBiologie => 'Nature et technologie';

  @override
  String sceneSubwayUiClockDay(String day, String weekday) {
    return 'Jour $day · $weekday';
  }

  @override
  String get sceneSubwayUiRushHour => 'heure de pointe';

  @override
  String get sceneSubwayUiNight => 'nuit';

  @override
  String sceneSubwayUiSurfaceSlowdown(String factor) {
    return '— transports de surface ralentis ×$factor';
  }

  @override
  String sceneSubwayUiAchievementSummary(String done, String total) {
    return '$done / $total débloqués — faits réels sur le réseau que vous avez construit.';
  }

  @override
  String sceneSubwayUiLoanOwed(String amount) {
    return '$amount dus';
  }

  @override
  String get sceneSubwayUiNoDebt => 'Aucune dette';

  @override
  String sceneSubwayUiFundingSubsidy(String amount) {
    return 'Subvention d’exploitation de $amount/jour';
  }

  @override
  String sceneSubwayUiLoanQuestion(String amount) {
    return 'Contracter un emprunt de $amount ?';
  }

  @override
  String get sceneSubwayUiLoanInterest =>
      'Les intérêts quotidiens sont de 0,06% du montant restant.';

  @override
  String sceneSubwayUiBoardings(String count) {
    return 'Montées $count/jour';
  }

  @override
  String get sceneSubwayUiSelectHint =>
      'Cliquez sur un arrêt ou une ligne pour afficher les détails. Faites glisser pour déplacer, défilez pour zoomer et faites glisser avec le bouton droit pour tourner.';

  @override
  String sceneSubwayUiRailStationHint(String mode) {
    return 'Seuls les services $mode desservent les vraies stations, mises en évidence sur la carte. Cliquez sur l’une d’elles pour la louer.';
  }

  @override
  String get sceneSubwayUiMetroStationHint =>
      'Cliquez sur la carte pour creuser une station de métro. Les zones plus denses coûtent davantage.';

  @override
  String sceneSubwayUiStreetStationHint(String mode) {
    return 'Cliquez près d’une rue pour placer un arrêt $mode — il s’aligne sur la route.';
  }

  @override
  String get sceneSubwayUiRailLineHint =>
      'Cliquez sur les vraies stations dans l’ordre — l’itinéraire suit les voies existantes. Entrée pour terminer, ou cliquez de nouveau sur la première station pour fermer la boucle.';

  @override
  String get sceneSubwayUiMetroLineHint =>
      'Cliquez sur les stations dans l’ordre pour creuser les tunnels entre elles. Entrée pour terminer, ou cliquez de nouveau sur la première station pour fermer la boucle.';

  @override
  String get sceneSubwayUiStreetLineHint =>
      'Cliquez sur les arrêts dans l’ordre — l’itinéraire suit les vraies rues. Entrée pour terminer, ou cliquez de nouveau sur le premier arrêt pour fermer la boucle.';

  @override
  String get sceneSubwayUiBulldozeHint =>
      'Cliquez sur un arrêt pour le démolir (remboursement de 25 %). Cliquez sur une ligne pour la supprimer entièrement.';

  @override
  String sceneSubwayUiExtendNextStop(String line) {
    return 'Prolongement de $line — cliquez sur le prochain arrêt. Échap pour arrêter.';
  }

  @override
  String sceneSubwayUiExtendNewStop(String line) {
    return 'Prolongement de $line : cliquez sur un arrêt à l’une des extrémités, puis sur le nouvel arrêt.';
  }

  @override
  String sceneSubwayUiDraftCost(String count, String distance, String cost) {
    return '$count arrêts · $distance · $cost — Entrée pour construire, Échap pour annuler.';
  }

  @override
  String sceneSubwayUiDraftCostWater(
    String count,
    String distance,
    String cost,
  ) {
    return '$count arrêts · $distance · $cost (tunnels sous-marins inclus) — Entrée pour construire, Échap pour annuler.';
  }

  @override
  String get sceneSubwaySeasonSpring => 'Printemps';

  @override
  String get sceneSubwaySeasonSummer => 'Été';

  @override
  String get sceneSubwaySeasonAutumn => 'Automne';

  @override
  String get sceneSubwaySeasonWinter => 'Hiver';

  @override
  String get sceneSubwayWeatherClear => 'Clair';

  @override
  String get sceneSubwayWeatherCloudy => 'Nuageux';

  @override
  String get sceneSubwayWeatherRain => 'Pluie';

  @override
  String get sceneSubwayWeatherStorm => 'Tempête';

  @override
  String get sceneSubwayWeatherSnow => 'Neige';

  @override
  String get sceneSubwayWeatherHeatwave => 'Canicule';

  @override
  String get sceneSubwayWeatherFog => 'Brouillard';

  @override
  String get sceneSubwayDisruptionSignalFailure => 'Panne de signalisation';

  @override
  String get sceneSubwayDisruptionTrackFault => 'Défaut de voie';

  @override
  String get sceneSubwayDisruptionPowerOutage => 'Panne de courant';

  @override
  String get sceneSubwayDisruptionStaffShortage => 'Manque de personnel';

  @override
  String get sceneSubwayDisruptionStalledVehicle => 'Véhicule immobilisé';

  @override
  String get sceneSubwayEventStadiumMatch => 'Match au stade';

  @override
  String get sceneSubwayEventArenaConcert => 'Concert à l’arène';

  @override
  String get sceneSubwayEventStreetFestival => 'Festival de rue';

  @override
  String get sceneSubwayEventTradeConvention => 'Convention commerciale';

  @override
  String get sceneSubwayEventNightMarket => 'Marché nocturne';

  @override
  String get sceneSubwayEventMarathonFinish => 'Arrivée du marathon';

  @override
  String get sceneSubwayEventFireworksShow => 'Feu d’artifice';

  @override
  String get sceneSubwayEventFootballDerby => 'Derby de football';

  @override
  String sceneSubwayWeatherNews(Object weather) {
    return 'Météo : $weather';
  }

  @override
  String sceneSubwayWeatherSlowedNews(Object weather) {
    return 'Météo : $weather — les transports de surface sont ralentis';
  }

  @override
  String sceneSubwayDisruptionNews(
    Object disruption,
    Object line,
    Object hours,
  ) {
    return '⚠️ $disruption sur $line — prévoyez environ $hours h de retard';
  }

  @override
  String sceneSubwayEventNews(Object event, Object station) {
    return '🎪 $event près de $station ce soir — affluence attendue !';
  }

  @override
  String sceneSubwayEventDayReport(Object event, Object station) {
    return '$event à $station';
  }

  @override
  String get sceneSubwayUiRealStation => 'vraie station';

  @override
  String get sceneSubwayUiNoLinesYet => 'aucune ligne pour le moment';

  @override
  String get sceneSubwayUiPlayTogether => 'Jouer ensemble';

  @override
  String get sceneSubwayUiLeaveRoom => 'Quitter la salle';

  @override
  String get sceneSubwayUiYourRooms => 'Vos salles';

  @override
  String get sceneSubwayUiYourCities => 'Vos villes';

  @override
  String get sceneSubwayUiDeleteSave => 'supprimer la sauvegarde';

  @override
  String get sceneSubwayUiPlacePickerDescription =>
      'Choisissez un lieu réel sur Terre et construisez le réseau de transport qu’il mérite';

  @override
  String get sceneSubwayUiFeaturedCities => 'Villes à découvrir';

  @override
  String get sceneSubwayUiBackToMap => 'Retour à la carte';

  @override
  String get sceneSubwayUiNoPlacesFound => 'Aucun lieu trouvé.';

  @override
  String sceneAirlineTycoonClockDay(Object day) {
    return 'JOUR $day';
  }

  @override
  String sceneAirlineTycoonMoveFacilityTitle(Object facility, Object rotation) {
    return 'Déplacer $facility · $rotation°';
  }

  @override
  String sceneAirlineTycoonPlaceFacilityTitle(
    Object facility,
    Object rotation,
  ) {
    return 'Placer $facility · $rotation°';
  }

  @override
  String sceneAirlineTycoonPlaceFacilityCostTitle(
    Object facility,
    Object cost,
    Object rotation,
  ) {
    return 'Placer $facility · $cost · $rotation°';
  }

  @override
  String sceneAirlineTycoonConsecutiveDays(Object count) {
    return '$count jours d’affilée';
  }

  @override
  String get sceneAirlineTycoonPlacementInstruction =>
      'Cliquez pour placer · Faites glisser pour déplacer · Faites glisser avec le bouton droit pour tourner';

  @override
  String sceneAirlineTycoonCashStatus(Object cash) {
    return 'Trésorerie $cash';
  }

  @override
  String get sceneAirlineTycoonClickToConfirm => 'Cliquez pour confirmer';

  @override
  String sceneAirlineTycoonSceneStartFailure(Object details) {
    return 'L’aéroport 3D n’a pas pu démarrer. $details Mettez à jour le pilote graphique ou Android System WebView, puis rouvrez l’aéroport.';
  }

  @override
  String get sceneAirlineTycoonAirportMissingAsset =>
      'Un élément de scène fourni est manquant.';

  @override
  String get sceneAirlineTycoonAirportLabel => 'Aéroport';

  @override
  String get sceneAirlineTycoonZoneRubOut =>
      'Faites glisser sur une zone pour l’effacer';

  @override
  String sceneAirlineTycoonZoneMarkType(Object zone) {
    return 'Faites glisser sur le sol du terminal pour le définir comme $zone';
  }

  @override
  String get sceneAirlineTycoonAirfieldLabel => 'Aérodrome';

  @override
  String get sceneAirlineTycoonDaytimeTitle => 'En journée';

  @override
  String get sceneAirlineTycoonNightTitle =>
      'Nuit : les lumières de l’aéroport sont allumées';

  @override
  String get sceneAirlineTycoonResumeTitle => 'Reprendre l’aéroport (Espace)';

  @override
  String get sceneAirlineTycoonPauseTitle =>
      'Mettre l’aéroport en pause (Espace)';

  @override
  String get sceneAirlineTycoonResumeLabel => 'Reprendre l’aéroport';

  @override
  String get sceneAirlineTycoonPauseLabel => 'Mettre l’aéroport en pause';

  @override
  String get sceneAirlineTycoonQualityHighTitle =>
      'Qualité : élevée (cliquer pour privilégier les performances)';

  @override
  String get sceneAirlineTycoonQualityPerformanceTitle =>
      'Qualité : performances (cliquer pour passer en qualité élevée)';

  @override
  String get sceneAirlineTycoonReleaseToPlace => 'Relâchez pour placer';

  @override
  String get sceneAirlineTycoonOpenPlanningLabel => 'Ouvrir le planning';

  @override
  String get sceneAirlineTycoonPanelBuild => 'Construction';

  @override
  String get sceneAirlineTycoonPanelContracts => 'Contrats';

  @override
  String get sceneAirlineTycoonPanelPlanning => 'Planning';

  @override
  String get sceneAirlineTycoonPanelFleet => 'Flotte';

  @override
  String get sceneAirlineTycoonPanelRoutes => 'Itinéraires';

  @override
  String get sceneAirlineTycoonPanelSchedule => 'Horaires';

  @override
  String get sceneAirlineTycoonPanelFinances => 'Finances';

  @override
  String sceneCityPlannerRidersPerDay(Object count) {
    return '$count/jour';
  }

  @override
  String get sceneCityPlannerRidersLabel => 'Voyageurs';

  @override
  String get sceneCityPlannerActiveLabel => 'Actif';

  @override
  String get sceneCityPlannerPausedLabel => 'En pause';

  @override
  String get sceneCityPlannerLowFrequency => 'Fréquence faible';

  @override
  String get sceneCityPlannerNormalFrequency => 'Fréquence normale';

  @override
  String get sceneCityPlannerHighFrequency => 'Fréquence élevée';

  @override
  String get sceneCityPlannerNoLines => 'Aucune ligne pour le moment.';

  @override
  String sceneCityPlannerPhaseLabel(Object phase, Object name) {
    return 'Phase $phase · $name';
  }

  @override
  String get sceneAssetStudioSessionWorkspace =>
      'Espace de travail de la session';

  @override
  String get sceneAssetStudioDragToPan => 'Glisser pour déplacer';

  @override
  String get sceneAssetStudioPauseTurntable =>
      'Mettre le plateau tournant en pause';

  @override
  String get sceneAssetStudioFootprintTight => 'Dans l’emprise au sol';

  @override
  String get sceneAssetStudioBoundsAllRotations =>
      'Dans les limites aux 4 rotations';

  @override
  String get sceneAssetStudioGroundedAtZero => 'Posé au sol à y = 0';

  @override
  String get sceneAssetStudioNoGeometryBelowGround =>
      'Aucune géométrie sous le sol';

  @override
  String get sceneAssetStudioWithinHeightLimit => 'Dans la limite de hauteur';

  @override
  String get sceneAssetStudioVertexColorsOnly =>
      'Couleurs des sommets uniquement';

  @override
  String get sceneAssetStudioNoModelTexturesOrFonts =>
      'Aucune texture de modèle ni ressource de police';

  @override
  String get sceneAssetStudioLocalGeometryMergePassed =>
      'Fusion locale de géométrie réussie';

  @override
  String get sceneAssetStudioStaticMeshesBakedTransforms =>
      'Maillages statiques avec transformations intégrées';

  @override
  String get sceneAssetStudioGeometryChecksPassed =>
      'Contrôles de géométrie réussis';

  @override
  String get sceneAssetStudioReviewGeometryChecks =>
      'Vérifier les contrôles de géométrie';

  @override
  String sceneAssetStudioHeightCheckDetail(String height, String maximum) {
    return '$height m sur un maximum de $maximum m';
  }

  @override
  String sceneAssetStudioHelperCallBudget(String calls) {
    return 'Dans la limite de $calls appels de géométrie';
  }

  @override
  String get sceneAssetStudioInteractiveModelAria =>
      'Modèle 3D interactif. Glissez pour tourner et faites défiler pour zoomer.';

  @override
  String get sceneAssetStudioClipboardUnavailable =>
      'Presse-papiers indisponible. Utilisez Télécharger .js.';

  @override
  String get sceneAssetStudioModelFunctionCopied => 'Fonction du modèle copiée';

  @override
  String get sceneAssetStudioWebglPreviewRequired =>
      'Un aperçu WebGL est nécessaire pour enregistrer une image.';

  @override
  String get sceneAssetStudioModelRestored =>
      'Modèle restauré selon la spécification d’origine';

  @override
  String get sceneAssetStudioLiveValidationWebglRequired =>
      'La validation en direct nécessite un navigateur compatible WebGL.';

  @override
  String get sceneAssetStudioAllGeometryChecksPassed =>
      'Les 6 contrôles de géométrie ont réussi';

  @override
  String get sceneAssetStudioGeometryCheckNeedsAttention =>
      'Un contrôle de géométrie nécessite votre attention';

  @override
  String sceneAssetStudioFileDownloaded(String filename) {
    return '$filename téléchargé';
  }

  @override
  String sceneAssetStudioLoadedAsset(String name) {
    return '$name chargé';
  }

  @override
  String sceneAssetStudioPreviewSaved(String filename) {
    return 'Aperçu enregistré sous $filename';
  }

  @override
  String get sceneAssetStudioCatalogJewelryStoreName => 'Bijouterie';

  @override
  String get sceneAssetStudioCatalogJewelryStoreDescription =>
      'Boutique haut de gamme de l’aéroport proposant bijoux, montres et accessoires de luxe.';

  @override
  String get sceneAssetStudioCatalogJewelryStoreKeywords =>
      'Vitrines dorées, bustes à colliers royaux, galerie horlogère et comptoir conseil';

  @override
  String get sceneAssetStudioCategoryRetail => 'commerce';

  @override
  String get sceneAssetStudioCatalogOneWayCustomsName => 'Douane à sens unique';

  @override
  String get sceneAssetStudioCatalogOneWayCustomsDescription =>
      'Contrôle douanier à sens unique où les passagers à l’arrivée sont contrôlés avant de poursuivre.';

  @override
  String get sceneAssetStudioCatalogOneWayCustomsKeywords =>
      'Flèches directionnelles au sol, couloir vitré, agent et portique de contrôle';

  @override
  String get sceneAssetStudioCategorySecurity => 'sécurité';

  @override
  String get sceneAssetStudioCatalogCoffeeToGoName => 'Café à emporter';

  @override
  String get sceneAssetStudioCatalogCoffeeToGoDescription =>
      'Café à emporter, boissons chaudes et encas pour les passagers pressés.';

  @override
  String get sceneAssetStudioCatalogCoffeeToGoKeywords =>
      'Kiosque à trois parois, machine à espresso, barista et enseigne drapeau';

  @override
  String get sceneAssetStudioCategoryFood => 'restauration';

  @override
  String get sceneAssetStudioCatalogAirportArcadeName => 'Salle d’arcade';

  @override
  String get sceneAssetStudioCatalogAirportArcadeDescription =>
      'Salle de jeux où les passagers peuvent jouer en attendant leur vol.';

  @override
  String get sceneAssetStudioCatalogAirportArcadeKeywords =>
      'Enseigne néon, 5 bornes rétro, deux simulateurs de course, air hockey et piste de danse';

  @override
  String get sceneAssetStudioCategoryEntertainment => 'loisirs';

  @override
  String get sceneAssetStudioCatalogAirportCasinoName => 'Salon casino';

  @override
  String get sceneAssetStudioCatalogAirportCasinoDescription =>
      'Casino élégant côté piste avec machines à sous, tables de jeu et bar à cocktails pour les longues escales.';

  @override
  String get sceneAssetStudioCatalogAirportCasinoKeywords =>
      'Colonnes dorées, rangées de machines à sous, tables de cartes et bar à cocktails';

  @override
  String get sceneAssetStudioCatalogFlowerShopName => 'Fleuriste';

  @override
  String get sceneAssetStudioCatalogFlowerShopDescription =>
      'Fleuriste de l’aéroport proposant fleurs fraîches, bouquets, plantes et petits cadeaux.';

  @override
  String get sceneAssetStudioCatalogFlowerShopKeywords =>
      'Entrée sous pergola, mur floral, table à bouquets et vitrine réfrigérée';

  @override
  String get sceneAssetStudioCatalogCustomsCheckerName => 'Contrôle douanier';

  @override
  String get sceneAssetStudioCatalogCustomsCheckerDescription =>
      'Poste douanier pour inspecter les passagers à l’arrivée et leurs bagages.';

  @override
  String get sceneAssetStudioCatalogCustomsCheckerKeywords =>
      'Contrôle par agent, table d’inspection des bagages, couloir douanier sécurisé';

  @override
  String get sceneAssetStudioCatalogFoodCartName => 'Chariot de restauration';

  @override
  String get sceneAssetStudioCatalogFoodCartDescription =>
      'Petit chariot avec vendeur proposant repas rapides, encas et boissons.';

  @override
  String get sceneAssetStudioCatalogFoodCartKeywords =>
      'Chariot à roulettes, vitrine à pâtisseries, auvent et station café';

  @override
  String get sceneAssetStudioCatalogFlightInfoPanelName =>
      'Écran d’information vols';

  @override
  String get sceneAssetStudioCatalogFlightInfoPanelDescription =>
      'Écran compact du terminal affichant les prochains vols et leurs portes.';

  @override
  String get sceneAssetStudioCatalogFlightInfoPanelKeywords =>
      'Écran vertical unique, pied fin, cinq lignes de vol';

  @override
  String get sceneAssetStudioCategoryPassenger => 'passagers';

  @override
  String get sceneAssetStudioCatalogFlightInformationBoardName =>
      'Tableau des vols';

  @override
  String get sceneAssetStudioCatalogFlightInformationBoardDescription =>
      'Affiche les prochains vols, heures de départ, portes et statuts actuels.';

  @override
  String get sceneAssetStudioCatalogFlightInformationBoardKeywords =>
      'FIDS double face, lignes de vol, couleurs de statut, horloge double';

  @override
  String get sceneAssetStudioCatalogTrashBinsName => 'Poubelles';

  @override
  String get sceneAssetStudioCatalogTrashBinsDescription =>
      'Poubelles et bacs de recyclage pour garder le terminal propre.';

  @override
  String get sceneAssetStudioCatalogTrashBinsKeywords =>
      'Station à trois flux, ouvertures distinctes, bandes colorées';

  @override
  String get sceneAssetStudioCategoryInterior => 'intérieur';

  @override
  String get sceneAssetStudioCatalogInformationDeskName =>
      'Bureau d’information';

  @override
  String get sceneAssetStudioCatalogInformationDeskDescription =>
      'Centre d’information de l’aéroport avec assistance par le personnel et en libre-service.';

  @override
  String get sceneAssetStudioCatalogInformationDeskKeywords =>
      'Deux postes avec personnel, deux employés, écran libre-service séparé';

  @override
  String get sceneAssetStudioCatalogAirportRestaurantName => 'Restaurant';

  @override
  String get sceneAssetStudioCatalogAirportRestaurantDescription =>
      'Restaurant d’aéroport avec service à table et plats fraîchement préparés.';

  @override
  String get sceneAssetStudioCatalogAirportRestaurantKeywords =>
      'Entrée avec accueil, salle variée, bar et cuisine ouverte';

  @override
  String get sceneAssetStudioCatalogPerfumeCornerShopName => 'Parfumerie';

  @override
  String get sceneAssetStudioCatalogPerfumeCornerShopDescription =>
      'Parfums de luxe hors taxes dans une boutique d’angle haut de gamme.';

  @override
  String get sceneAssetStudioCatalogPerfumeCornerShopKeywords =>
      'Façade d’angle en L, mises en scène en vitrine, plateaux testeurs';

  @override
  String get sceneAssetStudioCatalogDutyFreeFoodDrinksName =>
      'Boutique hors taxes — alimentation et boissons';

  @override
  String get sceneAssetStudioCatalogDutyFreeFoodDrinksDescription =>
      'Boutique hors taxes de l’aéroport proposant nourriture, encas et boissons.';

  @override
  String get sceneAssetStudioCatalogDutyFreeFoodDrinksKeywords =>
      'Boutique ouverte, rayons garnis, mur de boissons réfrigérées';

  @override
  String get sceneAssetStudioCatalogCheckoutCounterName => 'Caisse';

  @override
  String get sceneAssetStudioCatalogCheckoutCounterDescription =>
      'Caisse avec personnel où les passagers règlent leurs achats.';

  @override
  String get sceneAssetStudioCatalogCheckoutCounterKeywords =>
      'Caisse avec employé, terminal de paiement, espace d’emballage et petite file';

  @override
  String get sceneAssetStudioCatalogCheckInCounterName =>
      'Comptoir d’enregistrement';

  @override
  String get sceneAssetStudioCatalogCheckInCounterDescription =>
      'Comptoir d’enregistrement avec personnel pour passagers et bagages en soute.';

  @override
  String get sceneAssetStudioCatalogCheckInCounterKeywords =>
      'Comptoir avec personnel, tapis et balance à bagages, file guidée';

  @override
  String get sceneAssetStudioCatalogVipLoungeName => 'Salon VIP';

  @override
  String get sceneAssetStudioCatalogVipLoungeDescription =>
      'Salon d’aéroport exclusif de première classe avec sièges luxueux et rafraîchissements.';

  @override
  String get sceneAssetStudioCatalogVipLoungeKeywords =>
      'Noyer fumé, Chesterfields en velours, bar à cocktails et écran des départs';

  @override
  String get sceneAssetStudioCatalogCozyClothingName => 'Noir & Co. Atelier';

  @override
  String get sceneAssetStudioCatalogCozyClothingDescription =>
      'Boutique de mode de luxe sombre et élégante pour les passagers au départ.';

  @override
  String get sceneAssetStudioCatalogCozyClothingKeywords =>
      'Bois espresso, laiton patiné, salon en velours';

  @override
  String get sceneAssetStudioCatalogDutyFreeClothingName =>
      'Vêtements hors taxes';

  @override
  String get sceneAssetStudioCatalogDutyFreeClothingDescription =>
      'Boutique de mode et de vêtements à l’aéroport pour les passagers au départ.';

  @override
  String get sceneAssetStudioCatalogDutyFreeClothingKeywords =>
      'Boutique ouverte, portants et mannequins, caisse';

  @override
  String get sceneAssetStudioCatalogBaggageCarouselName =>
      'Carrousel à bagages';

  @override
  String get sceneAssetStudioCatalogBaggageCarouselDescription =>
      'Récupérez les bagages des passagers à l’arrivée sur le carrousel.';

  @override
  String get sceneAssetStudioCatalogBaggageCarouselKeywords =>
      'Tapis circulaire, bord métallique, borne de réclamation';

  @override
  String get sceneAssetStudioCatalogWaitingSeatsName => 'Sièges d’attente';

  @override
  String get sceneAssetStudioCatalogWaitingSeatsDescription =>
      'Sièges pour les salles d’attente et portes d’embarquement de l’aéroport.';

  @override
  String get sceneAssetStudioCatalogWaitingSeatsKeywords =>
      'Quatre sièges, poutre commune, cinq accoudoirs';

  @override
  String get sceneAssetStudioCatalogVendingMachineName =>
      'Distributeur automatique';

  @override
  String get sceneAssetStudioCatalogVendingMachineDescription =>
      'Encas et boissons pour les passagers.';

  @override
  String get sceneAssetStudioCatalogVendingMachineKeywords =>
      'Vitrine en verre, trois étagères garnies, colonne de commande';

  @override
  String get sceneAssetStudioCatalogTicketMachineName => 'Borne de billets';

  @override
  String get sceneAssetStudioCatalogTicketMachineDescription =>
      'Billetterie en libre-service pour le terminal.';

  @override
  String get sceneAssetStudioCatalogTicketMachineKeywords =>
      'Écran incliné, lecteur de carte, fente de reçu';

  @override
  String get sceneAssetStudioColorWarmIvory => 'Ivoire chaud';

  @override
  String get sceneAssetStudioColorDarkLuxury => 'Luxe sombre';

  @override
  String get sceneAssetStudioColorChampagneGold => 'Or champagne';

  @override
  String get sceneAssetStudioColorVelvetEmerald => 'Velours émeraude';

  @override
  String get sceneAssetStudioColorVelvetBurgundy => 'Velours bordeaux';

  @override
  String get sceneAssetStudioColorJewelryCoolLight =>
      'Lumière froide pour bijoux';

  @override
  String get sceneAssetStudioColorBody => 'Corps';

  @override
  String get sceneAssetStudioColorTealAccent => 'Accent sarcelle';

  @override
  String get sceneAssetStudioColorScreen => 'Écran';

  @override
  String get sceneAssetStudioColorEmission => 'Émission';

  @override
  String get sceneAssetStudioColorBase => 'Base';

  @override
  String get sceneAssetStudioColorSafetyStrip => 'Bande de sécurité';

  @override
  String get sceneAssetStudioColorSmokedWalnut => 'Noyer fumé';

  @override
  String get sceneAssetStudioColorAcousticCharcoal => 'Charbon acoustique';

  @override
  String get sceneAssetStudioColorBurnishedBrass => 'Laiton patiné';

  @override
  String get sceneAssetStudioColorBordeauxVelvet => 'Velours bordeaux';

  @override
  String get sceneAssetStudioColorCognacLeather => 'Cuir cognac';

  @override
  String get sceneAssetStudioColorAmberDownlight =>
      'Éclairage descendant ambré';

  @override
  String get sceneAssetStudioColorKioskIvory => 'Ivoire de kiosque';

  @override
  String get sceneAssetStudioColorRoastWood => 'Bois torréfié';

  @override
  String get sceneAssetStudioColorEspresso => 'Espresso';

  @override
  String get sceneAssetStudioColorBeanBrown => 'Brun grain de café';

  @override
  String get sceneAssetStudioColorApronGreen => 'Vert tablier';

  @override
  String get sceneAssetStudioColorWarmLight => 'Lumière chaude';

  @override
  String get sceneAssetStudioColorArcadeDark => 'Arcade sombre';

  @override
  String get sceneAssetStudioColorNeonPurple => 'Violet néon';

  @override
  String get sceneAssetStudioColorLaserPink => 'Rose laser';

  @override
  String get sceneAssetStudioColorCyberBlue => 'Bleu cyber';

  @override
  String get sceneAssetStudioColorNeonGlow => 'Lueur néon';

  @override
  String get sceneAssetStudioColorSpeedYellow => 'Jaune vitesse';

  @override
  String get sceneAssetStudioColorCasinoCharcoal => 'Charbon casino';

  @override
  String get sceneAssetStudioColorDeepRed => 'Rouge profond';

  @override
  String get sceneAssetStudioColorCasinoGold => 'Or casino';

  @override
  String get sceneAssetStudioColorTableGreen => 'Vert table de jeu';

  @override
  String get sceneAssetStudioColorMidnightBlue => 'Bleu nuit';

  @override
  String get sceneAssetStudioColorWarmGlow => 'Lueur chaude';

  @override
  String sceneAssetStudioColorCopied(String color) {
    return 'Couleur $color copiée';
  }

  @override
  String sceneAssetStudioSourceCodeAria(String filename) {
    return 'Code source de $filename';
  }

  @override
  String sceneAssetStudioCatalogFootprint(String width, String depth) {
    return 'Emprise du catalogue : $width x $depth m. Le modèle accepte les paramètres w et d du modèle existant.';
  }
}
