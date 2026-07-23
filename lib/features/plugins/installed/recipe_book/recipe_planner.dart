import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'recipe_book_controller.dart';
import 'recipe_models.dart';
import 'recipe_widgets.dart';

const _kWeekdayNames = [
  '', // 1-based
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _kMonthsShort = [
  '', // 1-based
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _weekdayShort(int weekday) => _kWeekdayNames[weekday].substring(0, 3);

String _formatDate(DateTime d) => '${d.day} ${_kMonthsShort[d.month]}';

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Opens the meal planner as its own full screen (more room than a popup).
Future<void> showRecipePlanner(
    BuildContext context, RecipeBookController controller) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => _RecipePlannerScreen(controller: controller),
    ),
  );
}

class _RecipePlannerScreen extends StatelessWidget {
  const _RecipePlannerScreen({required this.controller});
  final RecipeBookController controller;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        elevation: 0,
        titleSpacing: 0,
        iconTheme: IconThemeData(color: luma.textSecondary),
        title: Text('Meal planner',
            style: TextStyle(
                color: luma.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: RecipePlannerView(controller: controller),
            ),
          ),
        ),
      ),
    );
  }
}

/// The meal planner body: a navigable week (prev/next) whose days each hold
/// their own plan, a week-start selector, and the day cards. Kept separate so
/// it can be embedded anywhere; [showRecipePlanner] wraps it in a full screen.
class RecipePlannerView extends StatefulWidget {
  const RecipePlannerView({super.key, required this.controller});
  final RecipeBookController controller;

  @override
  State<RecipePlannerView> createState() => _RecipePlannerViewState();
}

class _RecipePlannerViewState extends State<RecipePlannerView> {
  late DateTime _weekStart;

  RecipeBookController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _weekStart = _weekStartContaining(DateTime.now(), _controller.weekStartsOn);
  }

  /// The start date of the week that contains [day], for a given start weekday.
  static DateTime _weekStartContaining(DateTime day, int startsOn) {
    final d = DateTime(day.year, day.month, day.day);
    final offset = (d.weekday - startsOn + 7) % 7;
    return DateTime(d.year, d.month, d.day - offset);
  }

  void _shiftWeek(int weeks) {
    setState(() => _weekStart = DateTime(
        _weekStart.year, _weekStart.month, _weekStart.day + weeks * 7));
  }

  void _goToThisWeek() {
    setState(() =>
        _weekStart = _weekStartContaining(DateTime.now(), _controller.weekStartsOn));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final luma = context.luma;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final weekEnd =
            DateTime(_weekStart.year, _weekStart.month, _weekStart.day + 6);
        final showsToday =
            !today.isBefore(_weekStart) && !today.isAfter(weekEnd);
        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _weekNav(luma, weekEnd, showsToday),
            const SizedBox(height: 10),
            _weekStartRow(luma),
            const SizedBox(height: 14),
            for (var i = 0; i < 7; i++)
              _DayCard(
                controller: _controller,
                date: DateTime(
                    _weekStart.year, _weekStart.month, _weekStart.day + i),
                isToday: _isSameDay(
                    DateTime(_weekStart.year, _weekStart.month,
                        _weekStart.day + i),
                    today),
              ),
          ],
        );
      },
    );
  }

  Widget _weekNav(LumaPalette luma, DateTime weekEnd, bool showsToday) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        children: [
          _navArrow(luma, Icons.chevron_left_rounded, () => _shiftWeek(-1)),
          Expanded(
            child: Column(
              children: [
                Text(_rangeLabel(_weekStart, weekEnd),
                    style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                showsToday
                    ? Text('This week',
                        style:
                            TextStyle(color: luma.textMuted, fontSize: 12))
                    : GestureDetector(
                        onTap: _goToThisWeek,
                        child: Text('Jump to this week',
                            style: TextStyle(
                                color: luma.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
              ],
            ),
          ),
          _navArrow(luma, Icons.chevron_right_rounded, () => _shiftWeek(1)),
        ],
      ),
    );
  }

  Widget _navArrow(LumaPalette luma, IconData icon, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: luma.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: luma.border),
          ),
          child: Icon(icon, size: 22, color: luma.textSecondary),
        ),
      ),
    );
  }

  Widget _weekStartRow(LumaPalette luma) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        children: [
          Icon(Icons.first_page_rounded, size: 18, color: luma.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Week starts on',
                style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: luma.surface,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: luma.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _controller.weekStartsOn,
                dropdownColor: luma.surface,
                iconEnabledColor: luma.textMuted,
                style: TextStyle(color: luma.textPrimary, fontSize: 13),
                items: [
                  for (var d = 1; d <= 7; d++)
                    DropdownMenuItem(
                      value: d,
                      child: Text(_kWeekdayNames[d],
                          style: TextStyle(
                              color: luma.textPrimary, fontSize: 13)),
                    ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  _controller.setWeekStartsOn(v);
                  setState(() =>
                      _weekStart = _weekStartContaining(_weekStart, v));
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _rangeLabel(DateTime start, DateTime end) {
  if (start.month == end.month) {
    return '${start.day} – ${end.day} ${_kMonthsShort[end.month]}';
  }
  return '${_formatDate(start)} – ${_formatDate(end)}';
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.controller,
    required this.date,
    required this.isToday,
  });
  final RecipeBookController controller;
  final DateTime date;
  final bool isToday;

  int get weekday => date.weekday;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final meals = controller.plannedForDate(date);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isToday ? luma.accent : luma.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: luma.accentSubtle,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: Text(_weekdayShort(weekday),
                      style: TextStyle(
                          color: luma.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(_kWeekdayNames[weekday],
                            style: TextStyle(
                                color: luma.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                        if (isToday) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: luma.accentSubtle,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text('Today',
                                style: TextStyle(
                                    color: luma.accent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(_formatDate(date),
                        style:
                            TextStyle(color: luma.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              _addButton(context),
            ],
          ),
          if (meals.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...meals.map((m) => _MealRow(
                  controller: controller,
                  meal: m,
                  onRemove: () => controller.removeFromPlan(date, m.id),
                )),
          ] else ...[
            const SizedBox(height: 10),
            Text('Nothing planned yet.',
                style: TextStyle(color: luma.textMuted, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _addButton(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          final pick = await _showRecipePicker(context, controller);
          if (pick == null) return;
          if (pick.local != null) {
            await controller.addLocalToPlan(date, pick.local!);
          } else if (pick.public != null) {
            await controller.addPublicToPlan(date, pick.public!);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: luma.accentSubtle,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 16, color: luma.accent),
              const SizedBox(width: 4),
              Text('Add',
                  style: TextStyle(
                      color: luma.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MealRow extends StatelessWidget {
  const _MealRow({
    required this.controller,
    required this.meal,
    required this.onRemove,
  });
  final RecipeBookController controller;
  final PlannedMeal meal;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 40,
              height: 40,
              child: meal.isLocal
                  ? LocalRecipeImage(
                      path: meal.localPhotoPath,
                      category: meal.category,
                      iconSize: 18)
                  : RemoteRecipeImage(
                      controller: controller,
                      photoId: meal.photoId,
                      category: meal.category,
                      iconSize: 18),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meal.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(meal.isLocal ? meal.category : '${meal.category} · public',
                    style: TextStyle(color: luma.textMuted, fontSize: 11)),
              ],
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.close_rounded,
                    size: 16, color: luma.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Recipe picker ---------------------------------------------------------

class _PickResult {
  const _PickResult({this.local, this.public});
  final LocalRecipe? local;
  final PublicRecipe? public;
}

Future<_PickResult?> _showRecipePicker(
    BuildContext context, RecipeBookController controller) {
  return showDialog<_PickResult>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => _RecipePickerDialog(controller: controller),
  );
}

class _RecipePickerDialog extends StatefulWidget {
  const _RecipePickerDialog({required this.controller});
  final RecipeBookController controller;

  @override
  State<_RecipePickerDialog> createState() => _RecipePickerDialogState();
}

class _RecipePickerDialogState extends State<_RecipePickerDialog> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  int _tab = 0; // 0 = mine, 1 = public

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matches(String title) =>
      _query.isEmpty || title.toLowerCase().contains(_query);

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final controller = widget.controller;
    final locals =
        controller.privateRecipes.where((r) => _matches(r.title)).toList();
    final publics =
        controller.publicRecipes.where((r) => _matches(r.title)).toList();

    return Dialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: luma.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
              child: Row(
                children: [
                  Text('Add a recipe',
                      style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: luma.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: Column(
                children: [
                  _searchBar(luma),
                  const SizedBox(height: 10),
                  LumaSegmentedTabs(
                    tabs: const ['My recipes', 'Public'],
                    selectedIndex: _tab,
                    onSelect: (i) => setState(() => _tab = i),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _tab == 0
                  ? _list(
                      luma,
                      locals.length,
                      (i) => _row(
                        title: locals[i].title,
                        category: locals[i].category,
                        thumb: LocalRecipeImage(
                            path: locals[i].photoPath,
                            category: locals[i].category,
                            iconSize: 18),
                        onTap: () => Navigator.pop(
                            context, _PickResult(local: locals[i])),
                      ),
                      emptyText: controller.privateRecipes.isEmpty
                          ? 'You have no recipes yet.'
                          : 'No matches.',
                    )
                  : _list(
                      luma,
                      publics.length,
                      (i) => _row(
                        title: publics[i].title,
                        category: publics[i].category,
                        thumb: RemoteRecipeImage(
                            controller: controller,
                            photoId: publics[i].photoId,
                            category: publics[i].category,
                            iconSize: 18),
                        onTap: () => Navigator.pop(
                            context, _PickResult(public: publics[i])),
                      ),
                      emptyText: !controller.signedIn
                          ? 'Sign in to browse public recipes.'
                          : (controller.publicRecipes.isEmpty
                              ? 'No public recipes yet.'
                              : 'No matches.'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar(LumaPalette luma) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.search_rounded, size: 18, color: luma.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              style: TextStyle(color: luma.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search recipes…',
                hintStyle: TextStyle(color: luma.textMuted, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _list(LumaPalette luma, int count, Widget Function(int) builder,
      {required String emptyText}) {
    if (count == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(emptyText,
              textAlign: TextAlign.center,
              style: TextStyle(color: luma.textMuted, fontSize: 13)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: count,
      itemBuilder: (context, i) => builder(i),
    );
  }

  Widget _row({
    required String title,
    required String category,
    required Widget thumb,
    required VoidCallback onTap,
  }) {
    final luma = context.luma;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: luma.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: luma.border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(width: 44, height: 44, child: thumb),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(category,
                        style:
                            TextStyle(color: luma.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              Icon(Icons.add_circle_outline_rounded,
                  size: 20, color: luma.accent),
            ],
          ),
        ),
      ),
    );
  }
}
