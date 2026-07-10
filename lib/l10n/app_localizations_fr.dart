// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class LFr extends L {
  LFr([String locale = 'fr']) : super(locale);

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
}
