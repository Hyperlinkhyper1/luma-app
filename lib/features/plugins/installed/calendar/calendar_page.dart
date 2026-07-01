import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'calendar_repository.dart';
import 'calendar_scope.dart';
import 'event_editor.dart';
import 'recurrence.dart';

/// The Calendar plugin: a month grid with a day agenda side-panel, an
/// upcoming-events list, search, colors, recurrence and reminders. Not secret
/// data, so no PIN gate.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

enum _View { month, agenda }

class _CalendarPageState extends State<CalendarPage> {
  final _search = TextEditingController();

  late DateTime _monthCursor; // first day of the visible month
  late DateTime _selectedDay; // day shown in the side panel
  _View _view = _View.month;
  String _query = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _monthCursor = DateTime(now.year, now.month);
    _selectedDay = _dateOnly(now);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _monthCursor = DateTime(now.year, now.month);
      _selectedDay = _dateOnly(now);
    });
  }

  void _shiftMonth(int by) => setState(
      () => _monthCursor = DateTime(_monthCursor.year, _monthCursor.month + by));

  void _selectDay(DateTime day) => setState(() => _selectedDay = _dateOnly(day));

  @override
  Widget build(BuildContext context) {
    final repo = CalendarScope.of(context);
    return StreamData<List<EventRecord>>(
      stream: repo.watchAll(),
      builder: (context, events) {
        return Column(
          children: [
            _Toolbar(
              monthLabel: DateFormat('MMMM yyyy').format(_monthCursor),
              view: _view,
              search: _search,
              searching: _query.isNotEmpty,
              onSearch: (v) => setState(() => _query = v.trim()),
              onView: (v) => setState(() => _view = v),
              onPrev: () => _shiftMonth(-1),
              onNext: () => _shiftMonth(1),
              onToday: _goToday,
              onNew: () => showEventEditor(context, repo,
                  initialDate: _selectedDay),
            ),
            Expanded(child: _body(context, repo, events)),
          ],
        );
      },
    );
  }

  Widget _body(
      BuildContext context, CalendarRepository repo, List<EventRecord> events) {
    if (_query.isNotEmpty) {
      return _SearchResults(
        repo: repo,
        events: events,
        query: _query,
      );
    }
    if (_view == _View.agenda) {
      return _AgendaView(repo: repo, events: events);
    }
    return _MonthView(
      monthCursor: _monthCursor,
      selectedDay: _selectedDay,
      events: events,
      repo: repo,
      onSelectDay: _selectDay,
    );
  }
}

// ── Toolbar ──────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.monthLabel,
    required this.view,
    required this.search,
    required this.searching,
    required this.onSearch,
    required this.onView,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onNew,
  });

  final String monthLabel;
  final _View view;
  final TextEditingController search;
  final bool searching;
  final ValueChanged<String> onSearch;
  final ValueChanged<_View> onView;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: luma.border)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RoundIconButton(icon: Icons.chevron_left_rounded, onTap: onPrev),
              const SizedBox(width: 4),
              _RoundIconButton(
                  icon: Icons.chevron_right_rounded, onTap: onNext),
              const SizedBox(width: 12),
              SizedBox(
                width: 168,
                child: Text(
                  monthLabel,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              LumaGhostButton(
                  label: 'Today', icon: Icons.today_rounded, onTap: onToday),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 220, child: _SearchField(search, onSearch)),
              const SizedBox(width: 12),
              _ViewToggle(view: view, searching: searching, onView: onView),
              const SizedBox(width: 12),
              LumaPrimaryButton(
                label: 'New event',
                icon: Icons.add_rounded,
                onTap: onNew,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField(this.controller, this.onChanged);
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c),
        );
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(color: luma.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Search events',
        hintStyle: TextStyle(color: luma.textMuted),
        prefixIcon: Icon(Icons.search_rounded, size: 18, color: luma.textMuted),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.clear_rounded, size: 16, color: luma.textMuted),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        filled: true,
        fillColor: luma.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        enabledBorder: border(luma.border),
        focusedBorder: border(luma.accent),
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle(
      {required this.view, required this.searching, required this.onView});
  final _View view;
  final bool searching;
  final ValueChanged<_View> onView;

  @override
  Widget build(BuildContext context) {
    return LumaSegmentedTabs(
      tabs: const ['Month', 'Agenda'],
      selectedIndex: searching ? -1 : view.index,
      onSelect: (i) => onView(_View.values[i]),
    );
  }
}

class _RoundIconButton extends StatefulWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_RoundIconButton> createState() => _RoundIconButtonState();
}

class _RoundIconButtonState extends State<_RoundIconButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _hovering ? luma.surfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: luma.border),
          ),
          child: Icon(widget.icon, color: luma.textPrimary, size: 20),
        ),
      ),
    );
  }
}

// ── Month view ───────────────────────────────────────────────────────────

class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.monthCursor,
    required this.selectedDay,
    required this.events,
    required this.repo,
    required this.onSelectDay,
  });

  final DateTime monthCursor;
  final DateTime selectedDay;
  final List<EventRecord> events;
  final CalendarRepository repo;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    // Grid runs from the Monday on/before the 1st, six weeks (42 days).
    final firstOfMonth = DateTime(monthCursor.year, monthCursor.month);
    final gridStart =
        firstOfMonth.subtract(Duration(days: firstOfMonth.weekday - 1));
    final gridEnd = gridStart.add(const Duration(days: 42));
    final occurrences = expandOccurrences(events, gridStart, gridEnd);

    final grid = _MonthGrid(
      gridStart: gridStart,
      monthCursor: monthCursor,
      selectedDay: selectedDay,
      occurrences: occurrences,
      repo: repo,
      onSelectDay: onSelectDay,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 20),
                child: grid,
              )),
              Container(width: 1, color: context.luma.border),
              SizedBox(
                width: 340,
                child: _DayPanel(
                  day: selectedDay,
                  events: events,
                  repo: repo,
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            SizedBox(
              height: 360,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: grid,
              ),
            ),
            Container(height: 1, color: context.luma.border),
            Expanded(
              child: _DayPanel(
                day: selectedDay,
                events: events,
                repo: repo,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.gridStart,
    required this.monthCursor,
    required this.selectedDay,
    required this.occurrences,
    required this.repo,
    required this.onSelectDay,
  });

  final DateTime gridStart;
  final DateTime monthCursor;
  final DateTime selectedDay;
  final List<EventOccurrence> occurrences;
  final CalendarRepository repo;
  final ValueChanged<DateTime> onSelectDay;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final today = _dateOnly(DateTime.now());

    return Column(
      children: [
        Row(
          children: [
            for (final d in _weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      color: luma.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Column(
            children: [
              for (var week = 0; week < 6; week++)
                Expanded(
                  child: Row(
                    children: [
                      for (var d = 0; d < 7; d++)
                        Expanded(
                          child: _DayCell(
                            day: gridStart
                                .add(Duration(days: week * 7 + d)),
                            monthCursor: monthCursor,
                            today: today,
                            selectedDay: selectedDay,
                            occurrences: occurrences,
                            repo: repo,
                            onSelectDay: onSelectDay,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatefulWidget {
  const _DayCell({
    required this.day,
    required this.monthCursor,
    required this.today,
    required this.selectedDay,
    required this.occurrences,
    required this.repo,
    required this.onSelectDay,
  });

  final DateTime day;
  final DateTime monthCursor;
  final DateTime today;
  final DateTime selectedDay;
  final List<EventOccurrence> occurrences;
  final CalendarRepository repo;
  final ValueChanged<DateTime> onSelectDay;

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final day = widget.day;
    final inMonth = day.month == widget.monthCursor.month;
    final isToday = _sameDay(day, widget.today);
    final isSelected = _sameDay(day, widget.selectedDay);
    final dayEvents =
        widget.occurrences.where((o) => o.coversDay(day)).toList();

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onSelectDay(day),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSelected
                ? luma.accentSubtle
                : (_hovering ? luma.surfaceHover : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? luma.accent : Colors.transparent,
            ),
          ),
          padding: const EdgeInsets.all(5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _DayNumber(
                    day: day,
                    isToday: isToday,
                    inMonth: inMonth,
                    luma: luma,
                  ),
                  const Spacer(),
                  if (_hovering)
                    _AddDot(
                      onTap: () => showEventEditor(context, widget.repo,
                          initialDate: day),
                    )
                  else if (dayEvents.isNotEmpty && !inMonth)
                    const SizedBox.shrink(),
                ],
              ),
              const SizedBox(height: 2),
              Expanded(
                child: _CellEvents(events: dayEvents, day: day, repo: widget.repo),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayNumber extends StatelessWidget {
  const _DayNumber({
    required this.day,
    required this.isToday,
    required this.inMonth,
    required this.luma,
  });
  final DateTime day;
  final bool isToday;
  final bool inMonth;
  final LumaPalette luma;

  @override
  Widget build(BuildContext context) {
    if (isToday) {
      return Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: luma.accent, shape: BoxShape.circle),
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: luma.onAccent,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: inMonth ? luma.textPrimary : luma.textMuted.withValues(alpha: 0.6),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Renders as many event chips as fit the available height, then a "+N more".
class _CellEvents extends StatelessWidget {
  const _CellEvents(
      {required this.events, required this.day, required this.repo});
  final List<EventOccurrence> events;
  final DateTime day;
  final CalendarRepository repo;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        const chipExtent = 19.0; // chip height + spacing
        final capacity = (constraints.maxHeight / chipExtent).floor().clamp(0, 6);
        if (capacity <= 0) {
          return _MoreDots(count: events.length);
        }
        final showChips =
            events.length <= capacity ? events.length : capacity - 1;
        final hidden = events.length - showChips;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < showChips; i++) ...[
              _MiniChip(occurrence: events[i], repo: repo),
              const SizedBox(height: 3),
            ],
            if (hidden > 0)
              Text(
                '+$hidden more',
                style: TextStyle(
                  color: context.luma.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MoreDots extends StatelessWidget {
  const _MoreDots({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    return Text('$count',
        style: TextStyle(
            color: context.luma.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700));
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.occurrence, required this.repo});
  final EventOccurrence occurrence;
  final CalendarRepository repo;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final color = Color(occurrence.color);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final time = occurrence.allDay
        ? null
        : DateFormat('HH:mm').format(occurrence.start);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () =>
            showEventEditor(context, repo, existing: occurrence.event),
        child: Container(
          height: 16,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.30 : 0.16),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  time == null
                      ? occurrence.title
                      : '$time ${occurrence.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddDot extends StatelessWidget {
  const _AddDot({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: luma.surface,
            shape: BoxShape.circle,
            border: Border.all(color: luma.border),
          ),
          child: Icon(Icons.add_rounded, size: 13, color: luma.textSecondary),
        ),
      ),
    );
  }
}

// ── Day panel (side / stacked) ─────────────────────────────────────────────

class _DayPanel extends StatelessWidget {
  const _DayPanel(
      {required this.day, required this.events, required this.repo});
  final DateTime day;
  final List<EventRecord> events;
  final CalendarRepository repo;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final dayStart = _dateOnly(day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final dayEvents = expandOccurrences(events, dayStart, dayEnd)
        .where((o) => o.coversDay(day))
        .toList();
    final isToday = _sameDay(day, DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isToday ? 'Today' : DateFormat('EEEE').format(day),
                      style: TextStyle(
                        color: luma.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('d MMMM yyyy').format(day),
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dayEvents.isEmpty
                          ? 'No events'
                          : '${dayEvents.length} event${dayEvents.length == 1 ? '' : 's'}',
                      style: TextStyle(color: luma.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _RoundIconButton(
                icon: Icons.add_rounded,
                onTap: () =>
                    showEventEditor(context, repo, initialDate: day),
              ),
            ],
          ),
        ),
        Container(height: 1, color: luma.border),
        Expanded(
          child: dayEvents.isEmpty
              ? LumaEmptyState(
                  icon: Icons.event_available_rounded,
                  title: 'Nothing planned',
                  subtitle: 'Add an event to fill this day.',
                  action: LumaGhostButton(
                    label: 'Add event',
                    icon: Icons.add_rounded,
                    onTap: () =>
                        showEventEditor(context, repo, initialDate: day),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: dayEvents.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _EventTile(
                    occurrence: dayEvents[i],
                    repo: repo,
                  ),
                ),
        ),
      ],
    );
  }
}

/// A rich event row used in the day panel, agenda and search results.
class _EventTile extends StatelessWidget {
  const _EventTile({required this.occurrence, required this.repo});
  final EventOccurrence occurrence;
  final CalendarRepository repo;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final e = occurrence.event;
    final color = Color(occurrence.color);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => showEventEditor(context, repo, existing: e),
        child: Container(
          decoration: BoxDecoration(
            color: luma.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: luma.border),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(12)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded,
                                size: 13, color: luma.textMuted),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                _timeText(occurrence),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: luma.textSecondary,
                                  fontSize: 12,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (e.location != null && e.location!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.place_outlined,
                                  size: 13, color: luma.textMuted),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  e.location!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: luma.textSecondary, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_hasMeta(e)) ...[
                          const SizedBox(height: 7),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (e.recurrence != Recurrence.none)
                                _MetaChip(
                                  icon: Icons.repeat_rounded,
                                  label: e.recurrence.label,
                                  luma: luma,
                                ),
                              if (e.reminderMinutes != null)
                                _MetaChip(
                                  icon: Icons.notifications_none_rounded,
                                  label: _reminderText(e.reminderMinutes!),
                                  luma: luma,
                                ),
                              if (e.allDay)
                                _MetaChip(
                                  icon: Icons.wb_sunny_outlined,
                                  label: 'All-day',
                                  luma: luma,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static bool _hasMeta(EventRecord e) =>
      e.recurrence != Recurrence.none ||
      e.reminderMinutes != null ||
      e.allDay;
}

class _MetaChip extends StatelessWidget {
  const _MetaChip(
      {required this.icon, required this.label, required this.luma});
  final IconData icon;
  final String label;
  final LumaPalette luma;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: luma.textMuted),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: luma.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Agenda view ─────────────────────────────────────────────────────────

class _AgendaView extends StatelessWidget {
  const _AgendaView({required this.repo, required this.events});
  final CalendarRepository repo;
  final List<EventRecord> events;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = _dateOnly(now);
    final end = start.add(const Duration(days: 365));
    final occurrences = expandOccurrences(events, start, end);

    if (occurrences.isEmpty) {
      return LumaEmptyState(
        icon: Icons.event_note_rounded,
        title: 'No upcoming events',
        subtitle: 'Events you add will show up here, soonest first.',
        action: LumaPrimaryButton(
          label: 'New event',
          icon: Icons.add_rounded,
          onTap: () => showEventEditor(context, repo, initialDate: now),
        ),
      );
    }

    final groups = _groupByDay(occurrences);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
          itemCount: groups.length,
          itemBuilder: (context, i) {
            final g = groups[i];
            return _AgendaGroup(day: g.day, occurrences: g.items, repo: repo);
          },
        ),
      ),
    );
  }
}

class _AgendaGroup extends StatelessWidget {
  const _AgendaGroup(
      {required this.day, required this.occurrences, required this.repo});
  final DateTime day;
  final List<EventOccurrence> occurrences;
  final CalendarRepository repo;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final now = DateTime.now();
    final isToday = _sameDay(day, now);
    final isTomorrow = _sameDay(day, now.add(const Duration(days: 1)));
    final label = isToday
        ? 'Today'
        : isTomorrow
            ? 'Tomorrow'
            : DateFormat('EEEE').format(day);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isToday ? luma.accent : luma.surface,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                      color: isToday ? luma.accent : luma.border),
                ),
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    color: isToday ? luma.onAccent : luma.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  Text(DateFormat('MMMM yyyy').format(day),
                      style: TextStyle(color: luma.textMuted, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final o in occurrences) ...[
            _EventTile(occurrence: o, repo: repo),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

// ── Search results ─────────────────────────────────────────────────────

class _SearchResults extends StatelessWidget {
  const _SearchResults(
      {required this.repo, required this.events, required this.query});
  final CalendarRepository repo;
  final List<EventRecord> events;
  final String query;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final q = query.toLowerCase();
    final matches = events.where((e) {
      return e.title.toLowerCase().contains(q) ||
          (e.location?.toLowerCase().contains(q) ?? false) ||
          (e.description?.toLowerCase().contains(q) ?? false);
    }).toList();

    if (matches.isEmpty) {
      return LumaEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No events match "$query"',
        subtitle: 'Try a different title, place or note.',
      );
    }

    // Show each matching event's next upcoming occurrence (or its start).
    final now = DateTime.now();
    final occ = <EventOccurrence>[];
    for (final e in matches) {
      final future = expandOccurrences(
          [e], _dateOnly(now), _dateOnly(now).add(const Duration(days: 730)));
      if (future.isNotEmpty) {
        occ.add(future.first);
      } else {
        occ.add(EventOccurrence(event: e, start: e.start, end: e.end));
      }
    }
    occ.sort((a, b) => a.start.compareTo(b.start));

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
          itemCount: occ.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${occ.length} result${occ.length == 1 ? '' : 's'} for "$query"',
                  style: TextStyle(
                      color: luma.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              );
            }
            final o = occ[i - 1];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 5),
                  child: Text(
                    DateFormat('EEE, d MMM yyyy').format(o.start),
                    style: TextStyle(color: luma.textMuted, fontSize: 11),
                  ),
                ),
                _EventTile(occurrence: o, repo: repo),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────

class _DayGroup {
  _DayGroup(this.day) : items = [];
  final DateTime day;
  final List<EventOccurrence> items;
}

List<_DayGroup> _groupByDay(List<EventOccurrence> occurrences) {
  final groups = <_DayGroup>[];
  final byKey = <String, _DayGroup>{};
  for (final o in occurrences) {
    final day = _dateOnly(o.start);
    final key = '${day.year}-${day.month}-${day.day}';
    final group = byKey.putIfAbsent(key, () {
      final g = _DayGroup(day);
      groups.add(g);
      return g;
    });
    group.items.add(o);
  }
  return groups;
}

String _timeText(EventOccurrence o) {
  if (o.allDay) {
    final days = _dateOnly(o.end).difference(_dateOnly(o.start)).inDays;
    return days >= 1 ? 'All-day · ${days + 1} days' : 'All-day';
  }
  final sameDay = _sameDay(o.start, o.end);
  final startStr = DateFormat('HH:mm').format(o.start);
  final endStr = DateFormat('HH:mm').format(o.end);
  if (sameDay) return '$startStr – $endStr';
  return '${DateFormat('d MMM HH:mm').format(o.start)} – '
      '${DateFormat('d MMM HH:mm').format(o.end)}';
}

String _reminderText(int minutes) {
  if (minutes == 0) return 'At start';
  if (minutes % 1440 == 0) return '${minutes ~/ 1440}d before';
  if (minutes % 60 == 0) return '${minutes ~/ 60}h before';
  return '${minutes}m before';
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
