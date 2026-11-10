import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../account/plan.dart';
import '../../../../../account/plan_selection_page.dart';
import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../settings/settings_scope.dart';
import '../../../../../sync/sync_scope.dart';
import '../../../../../theme/luma_theme.dart';
import '../../../plugin_scope.dart';
import '../../groceries/groceries_api.dart';
import '../../groceries/groceries_repository.dart';
import '../../groceries/groceries_scope.dart';
import '../recipe_book_controller.dart';
import '../recipe_models.dart';
import 'meal_chef_api.dart';
import 'meal_chef_groceries.dart';
import 'meal_chef_models.dart';

/// Opens the meal chef: a chat where Nebula plans a meal from a few
/// questions. [day] is the planner day the meal is offered for first.
Future<void> showMealChef(BuildContext context, RecipeBookController controller,
    {DateTime? day}) {
  return Navigator.of(context).push<void>(MaterialPageRoute(
    builder: (_) => MealChefPage(controller: controller, initialDay: day),
  ));
}

enum _Stage { allergies, people, deals, stores, notes, cooking, failed, meal }

class _Msg {
  const _Msg.bot(this.text, {this.error = false})
      : user = false,
        meal = null;
  const _Msg.user(this.text)
      : user = true,
        error = false,
        meal = null;
  const _Msg.meal(ChefMeal this.meal)
      : text = '',
        user = false,
        error = false;

  final String text;
  final bool user;
  final bool error;
  final ChefMeal? meal;
}

class MealChefPage extends StatefulWidget {
  const MealChefPage({super.key, required this.controller, this.initialDay});

  final RecipeBookController controller;
  final DateTime? initialDay;

  @override
  State<MealChefPage> createState() => _MealChefPageState();
}

class _MealChefPageState extends State<MealChefPage> {
  final _messages = <_Msg>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();

  _Stage _stage = _Stage.allergies;
  String? _busyLabel;
  bool? _inNetherlands;

  String _allergies = '';
  int _people = 2;
  bool? _useDeals;
  final Set<String> _stores = {};
  String _notes = '';
  final List<String> _feedback = [];
  List<RemoteProduct>? _deals;

  ChefMeal? _meal;
  LocalRecipe? _savedRecipe;
  bool _groceryPending = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inNetherlands == null) {
      final t = L.of(context);
      var platformLocale = '';
      try {
        platformLocale = Platform.localeName;
      } catch (_) {}
      _inNetherlands = mealChefShopsInNetherlands(platformLocale, t.localeName);
      _messages.add(_Msg.bot(t.mealChefGreeting));
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _busy => _busyLabel != null;

  MealChefAnswers get _answers => MealChefAnswers(
        allergies: _allergies,
        people: _people,
        useDeals: _useDeals,
        stores: _stores.toList(),
        notes: _notes,
      );

  void _say(_Msg msg) {
    setState(() => _messages.add(msg));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  void _startOver() {
    final t = L.of(context);
    setState(() {
      _messages
        ..clear()
        ..add(_Msg.bot(t.mealChefGreeting));
      _stage = _Stage.allergies;
      _allergies = '';
      _people = 2;
      _useDeals = null;
      _stores.clear();
      _notes = '';
      _feedback.clear();
      _deals = null;
      _meal = null;
      _savedRecipe = null;
      _groceryPending = false;
      _input.clear();
    });
  }

  // ---- The questions ------------------------------------------------------

  void _submitText() {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    final t = L.of(context);
    switch (_stage) {
      case _Stage.allergies:
        _input.clear();
        _answerAllergies(text, text);
      case _Stage.people:
        final n = int.tryParse(text);
        _input.clear();
        if (n == null || n < 1 || n > 20) {
          _say(_Msg.user(text));
          _say(_Msg.bot(t.mealChefPeopleInvalid, error: true));
        } else {
          _answerPeople(n);
        }
      case _Stage.notes:
        _input.clear();
        _answerNotes(text, text);
      case _Stage.meal:
        _input.clear();
        _requestChange(text, text);
      default:
        break;
    }
  }

  void _answerAllergies(String shown, String value) {
    _say(_Msg.user(shown));
    _allergies = value;
    _stage = _Stage.people;
    _say(_Msg.bot(L.of(context).mealChefAskPeople));
  }

  void _answerPeople(int people) {
    final t = L.of(context);
    _say(_Msg.user('$people'));
    _people = people;
    if (_inNetherlands == true) {
      _stage = _Stage.deals;
      _say(_Msg.bot(t.mealChefAskDeals));
    } else {
      _stage = _Stage.notes;
      _say(_Msg.bot(t.mealChefAskNotes));
    }
  }

  void _answerDeals(bool yes) {
    final t = L.of(context);
    _say(_Msg.user(yes ? t.mealChefYesDeals : t.mealChefNoDeals));
    _useDeals = yes;
    _stage = _Stage.stores;
    _say(_Msg.bot(t.mealChefAskStores));
  }

  void _confirmStores() {
    if (_stores.isEmpty) return;
    _say(_Msg.user(
        [for (final s in kMealChefStores.keys) if (_stores.contains(s)) kMealChefStores[s]!].join(', ')));
    _stage = _Stage.notes;
    _say(_Msg.bot(L.of(context).mealChefAskNotes));
  }

  void _answerNotes(String shown, String value) {
    _say(_Msg.user(shown));
    _notes = value;
    _cook();
  }

  void _requestChange(String shown, String feedback) {
    _say(_Msg.user(shown));
    _feedback.add(feedback);
    if (_feedback.length > 5) _feedback.removeAt(0);
    _cook(changing: true);
  }

  // ---- Cooking ------------------------------------------------------------

  Future<void> _cook({bool changing = false}) async {
    final t = L.of(context);
    final sync = SyncScope.of(context);
    final groceries = _groceriesApi();
    setState(() => _stage = _Stage.cooking);
    if (_useDeals == true && _deals == null && groceries != null) {
      setState(() => _busyLabel = t.mealChefFindingDeals);
      _deals = await fetchMealChefDeals(groceries, _stores.toList());
      if (!mounted) return;
    }
    setState(() => _busyLabel = t.mealChefCooking);
    final serverUrl = sync.serverUrl;
    if (!sync.serverReady || serverUrl == null) {
      setState(() {
        _busyLabel = null;
        _stage = _meal != null ? _Stage.meal : _Stage.failed;
      });
      _say(_Msg.bot(t.mealChefSignInError, error: true));
      return;
    }
    final api = MealChefApi(serverUrl, token: sync.authToken);
    try {
      final meal = await api.plan(
        MealChefApi.requestBody(
          answers: _answers,
          language: t.localeName,
          deals: _deals ?? const [],
          previous: changing ? _meal : null,
          feedback: changing ? _feedback : const [],
        ),
        signIn: t.mealChefSignInError,
        unreachable: t.mealChefUnreachable,
      );
      if (!mounted) return;
      setState(() {
        _busyLabel = null;
        _meal = meal;
        _savedRecipe = null;
        _groceryPending = true;
        _stage = _Stage.meal;
      });
      if (meal.message.isNotEmpty) _say(_Msg.bot(meal.message));
      _say(_Msg.meal(meal));
      _say(_Msg.bot(t.mealChefAskGroceries));
    } on MealChefException catch (e) {
      if (!mounted) return;
      if (changing && _feedback.isNotEmpty) _feedback.removeLast();
      setState(() {
        _busyLabel = null;
        _stage = _meal != null ? _Stage.meal : _Stage.failed;
      });
      _say(_Msg.bot(e.message, error: true));
    } finally {
      api.close();
    }
  }

  GroceriesApi? _groceriesApi() =>
      context.getInheritedWidgetOfExactType<GroceriesApiScope>()?.notifier;

  GroceriesRepository? _groceriesRepository() =>
      context.getInheritedWidgetOfExactType<GroceriesScope>()?.repository;

  // ---- After the meal -----------------------------------------------------

  Future<LocalRecipe?> _ensureSaved() async {
    final meal = _meal;
    if (meal == null) return null;
    if (_savedRecipe case final saved?) return saved;
    final now = DateTime.now();
    final recipe =
        meal.toLocalRecipe('chef_${now.microsecondsSinceEpoch}', now);
    await widget.controller.addLocalRecipe(recipe);
    _savedRecipe = recipe;
    return recipe;
  }

  Future<void> _saveRecipe() async {
    final t = L.of(context);
    final already = _savedRecipe != null;
    await _ensureSaved();
    if (!mounted || already) return;
    _say(_Msg.bot(t.mealChefSaved));
  }

  Future<void> _addToPlanner() async {
    final t = L.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = widget.initialDay ?? today;
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(today) ? today : initial,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final recipe = await _ensureSaved();
    if (recipe == null) return;
    await widget.controller.addLocalToPlan(date, recipe);
    if (!mounted) return;
    _say(_Msg.bot(t.mealChefPlanned(
        DateFormat('EEEE d MMMM', t.localeName).format(date))));
  }

  void _skipGroceries() {
    final t = L.of(context);
    setState(() => _groceryPending = false);
    _say(_Msg.user(t.mealChefNoList));
    _say(_Msg.bot(t.mealChefAfterMeal));
  }

  Future<void> _makeGroceryList() async {
    final t = L.of(context);
    final meal = _meal;
    final api = _groceriesApi();
    final repository = _groceriesRepository();
    final plugins = PluginScope.of(context);
    if (meal == null || api == null || repository == null) return;
    setState(() {
      _groceryPending = false;
      _busyLabel = t.mealChefBuildingList;
    });
    _say(_Msg.user(t.mealChefMakeList));
    final result = await buildMealChefGroceryList(
      repository: repository,
      api: api,
      meal: meal,
      stores: _stores.toList(),
      deals: _deals ?? const [],
      preferDeals: _useDeals == true,
    );
    final installed = await plugins.isInstalled('groceries-list');
    if (!mounted) return;
    setState(() => _busyLabel = null);
    if (result.listId == null) {
      _say(_Msg.bot(t.mealChefListFailed, error: true));
      return;
    }
    _say(_Msg.bot(t.mealChefListCreated(result.added, meal.title)));
    if (result.missing.isNotEmpty) {
      _say(_Msg.bot(t.mealChefListMissing(result.missing.join(', '))));
    }
    if (!installed) _say(_Msg.bot(t.mealChefListInstallHint));
    _say(_Msg.bot(t.mealChefAfterMeal));
  }

  // ---- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final settings = SettingsScope.of(context);
    final sync = SyncScope.of(context);
    final paid = planAtLeast(settings.selectedPlanId, 'orbit');

    Widget body;
    if (!paid) {
      body = LumaEmptyState(
        icon: Icons.auto_awesome_rounded,
        title: t.mealChefGateTitle,
        subtitle: t.mealChefGateSubtitle,
        action: LumaPrimaryButton(
          label: t.mealChefUpgradeTo(planById('orbit').name),
          icon: Icons.auto_awesome_rounded,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PlanSelectionPage()),
          ),
        ),
      );
    } else if (!sync.serverReady) {
      body = LumaEmptyState(
        icon: Icons.cloud_off_rounded,
        title: t.mealChefSignInTitle,
        subtitle: t.mealChefSignInSubtitle,
      );
    } else {
      body = Column(
        children: [
          Expanded(child: _chat(luma, t)),
          _quickReplies(luma, t),
          _inputBar(luma, t),
        ],
      );
    }

    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        elevation: 0,
        titleSpacing: 0,
        iconTheme: IconThemeData(color: luma.textSecondary),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.mealChefTitle,
                style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            Text(t.mealChefUsageNote,
                style: TextStyle(color: luma.textMuted, fontSize: 11)),
          ],
        ),
        actions: [
          if (paid && sync.serverReady)
            IconButton(
              tooltip: t.mealChefStartOver,
              icon: Icon(Icons.restart_alt_rounded, color: luma.textSecondary),
              onPressed: _busy ? null : _startOver,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: body,
          ),
        ),
      ),
    );
  }

  Widget _chat(LumaPalette luma, L t) {
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      children: [
        for (final m in _messages)
          if (m.meal != null)
            _MealCard(meal: m.meal!)
          else
            _Bubble(msg: m),
        if (_busyLabel != null) _TypingBubble(label: _busyLabel!),
      ],
    );
  }

  Widget _quickReplies(LumaPalette luma, L t) {
    if (_busy) return const SizedBox.shrink();
    final chips = <Widget>[];
    switch (_stage) {
      case _Stage.allergies:
        chips.add(_Chip(
            label: t.mealChefNoAllergies,
            onTap: () => _answerAllergies(t.mealChefNoAllergies, '')));
      case _Stage.people:
        for (var n = 1; n <= 6; n++) {
          chips.add(_Chip(label: '$n', onTap: () => _answerPeople(n)));
        }
      case _Stage.deals:
        chips
          ..add(_Chip(
              label: t.mealChefYesDeals, onTap: () => _answerDeals(true)))
          ..add(_Chip(
              label: t.mealChefNoDeals, onTap: () => _answerDeals(false)));
      case _Stage.stores:
        for (final entry in kMealChefStores.entries) {
          chips.add(_Chip(
            label: entry.value,
            selected: _stores.contains(entry.key),
            onTap: () => setState(() {
              if (!_stores.remove(entry.key)) _stores.add(entry.key);
            }),
          ));
        }
        chips.add(_Chip(
          label: t.mealChefContinue,
          primary: true,
          onTap: _stores.isEmpty ? null : _confirmStores,
        ));
      case _Stage.notes:
        chips.add(_Chip(
            label: t.mealChefNoNotes,
            onTap: () => _answerNotes(t.mealChefNoNotes, '')));
      case _Stage.failed:
        chips.add(_Chip(
            label: t.mealChefRetry, primary: true, onTap: () => _cook()));
      case _Stage.meal:
        if (_groceryPending) {
          chips
            ..add(_Chip(
                label: t.mealChefMakeList,
                primary: true,
                icon: Icons.local_grocery_store_rounded,
                onTap: _makeGroceryList))
            ..add(_Chip(label: t.mealChefNoList, onTap: _skipGroceries));
        }
        chips
          ..add(_Chip(
              label: t.mealChefAddToPlanner,
              icon: Icons.calendar_month_rounded,
              onTap: _addToPlanner))
          ..add(_Chip(
              label: t.mealChefSaveRecipe,
              icon: _savedRecipe != null
                  ? Icons.check_rounded
                  : Icons.bookmark_add_outlined,
              onTap: _saveRecipe))
          ..add(_Chip(
              label: t.mealChefAnother,
              icon: Icons.casino_outlined,
              onTap: () =>
                  _requestChange(t.mealChefAnother, t.mealChefAnotherFeedback)));
      case _Stage.cooking:
        break;
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(spacing: 8, runSpacing: 8, children: chips),
      ),
    );
  }

  Widget _inputBar(LumaPalette luma, L t) {
    final enabled = !_busy &&
        (_stage == _Stage.allergies ||
            _stage == _Stage.people ||
            _stage == _Stage.notes ||
            _stage == _Stage.meal);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: luma.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: luma.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: luma.border),
              ),
              child: TextField(
                controller: _input,
                enabled: enabled,
                maxLength: 600,
                minLines: 1,
                maxLines: 4,
                keyboardType: _stage == _Stage.people
                    ? TextInputType.number
                    : TextInputType.text,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submitText(),
                style: TextStyle(color: luma.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: _stage == _Stage.meal
                      ? t.mealChefFeedbackHint
                      : t.mealChefInputHint,
                  hintStyle: TextStyle(color: luma.textMuted, fontSize: 14),
                  border: InputBorder.none,
                  counterText: '',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: t.mealChefSend,
            onPressed: enabled ? _submitText : null,
            style: IconButton.styleFrom(
              backgroundColor: luma.accent,
              foregroundColor: luma.onAccent,
              disabledBackgroundColor: luma.surface,
            ),
            icon: const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg});
  final _Msg msg;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final user = msg.user;
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: user
            ? luma.accent
            : (msg.error
                ? luma.danger.withValues(alpha: 0.1)
                : luma.surface),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: Radius.circular(user ? 14 : 4),
          bottomRight: Radius.circular(user ? 4 : 14),
        ),
        border: user
            ? null
            : Border.all(
                color: msg.error
                    ? luma.danger.withValues(alpha: 0.4)
                    : luma.border),
      ),
      child: SelectableText(msg.text,
          style: TextStyle(
              color: user
                  ? luma.onAccent
                  : (msg.error ? luma.danger : luma.textPrimary),
              fontSize: 14,
              height: 1.35)),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            user ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!user) ...[const _ChefAvatar(), const SizedBox(width: 8)],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

class _ChefAvatar extends StatelessWidget {
  const _ChefAvatar();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: luma.accentSubtle,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(Icons.auto_awesome_rounded, size: 16, color: luma.accent),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const _ChefAvatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: luma.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: luma.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: luma.accent),
                ),
                const SizedBox(width: 10),
                Text(label,
                    style:
                        TextStyle(color: luma.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.primary = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final bool primary;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final enabled = onTap != null;
    final filled = primary || selected;
    final fg = !enabled
        ? luma.textMuted
        : (primary ? luma.onAccent : (selected ? luma.accent : luma.textPrimary));
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: !enabled
                ? luma.surface
                : (primary
                    ? luma.accent
                    : (selected ? luma.accentSubtle : luma.surface)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: filled && enabled ? luma.accent : luma.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected && !primary) ...[
                Icon(Icons.check_rounded, size: 15, color: fg),
                const SizedBox(width: 5),
              ] else if (icon != null) ...[
                Icon(icon, size: 15, color: fg),
                const SizedBox(width: 5),
              ],
              Text(label,
                  style: TextStyle(
                      color: fg, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.meal});
  final ChefMeal meal;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final color = recipeCategoryColor(meal.category, luma);
    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 38),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: luma.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(meal.title,
              style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          if (meal.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(meal.description,
                style: TextStyle(
                    color: luma.textSecondary, fontSize: 13, height: 1.35)),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _pill(luma, localizedRecipeCategory(t, meal.category), color),
              if (meal.totalMinutes > 0)
                _pill(luma, formatRecipeTime(meal.totalMinutes, t),
                    luma.textSecondary,
                    icon: Icons.schedule_rounded),
              _pill(luma, t.recipeServingsCount(meal.servings),
                  luma.textSecondary,
                  icon: Icons.people_alt_outlined),
            ],
          ),
          if (meal.allergyNote.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: luma.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: luma.warning.withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.health_and_safety_outlined,
                      size: 16, color: luma.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(meal.allergyNote,
                        style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 12.5,
                            height: 1.35)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          _heading(luma, t.mealChefIngredients),
          const SizedBox(height: 6),
          for (final i in meal.ingredients) _ingredientRow(luma, t, i),
          const SizedBox(height: 12),
          _heading(luma, t.mealChefSteps),
          const SizedBox(height: 6),
          for (final (index, step) in meal.steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: luma.accentSubtle,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text('${index + 1}',
                        style: TextStyle(
                            color: luma.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(step,
                        style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 13.5,
                            height: 1.4)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _heading(LumaPalette luma, String text) => Text(text.toUpperCase(),
      style: TextStyle(
          color: luma.textMuted,
          fontSize: 11,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w800));

  Widget _pill(LumaPalette luma, String text, Color color, {IconData? icon}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
            ],
            Text(text,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _ingredientRow(LumaPalette luma, L t, ChefIngredient i) {
    final unit = i.unit.isEmpty ? '' : localizedRecipeUnit(t, i.unit);
    final quantity = [i.amount, unit].where((s) => s.isNotEmpty).join(' ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: i.pantry ? luma.textMuted : luma.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          if (quantity.isNotEmpty) ...[
            Text(quantity,
                style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(i.name,
                style: TextStyle(
                    color: i.pantry ? luma.textSecondary : luma.textPrimary,
                    fontSize: 13.5)),
          ),
          if (i.fromDeal)
            _tag(luma, t.mealChefOnSale, luma.success)
          else if (i.pantry)
            _tag(luma, t.mealChefPantry, luma.textMuted),
        ],
      ),
    );
  }

  Widget _tag(LumaPalette luma, String text, Color color) => Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 10.5, fontWeight: FontWeight.w800)),
      );
}
