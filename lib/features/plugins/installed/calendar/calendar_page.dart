import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/widgets.dart';
import '../../../../family/family_scope.dart';
import '../../../../theme/luma_theme.dart';
import 'calendar_repository.dart';
import 'calendar_scope.dart';
import 'dinner_editor.dart';
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

enum _View { day, week, month, agenda }

extension on _View {
  String get label => switch (this) {
        _View.day => 'Day',
        _View.week => 'Week',
        _View.month => 'Month',
        _View.agenda => 'Agenda',
      };

  IconData get icon => switch (this) {
        _View.day => Icons.calendar_view_day_rounded,
        _View.week => Icons.calendar_view_week_rounded,
        _View.month => Icons.calendar_view_month_rounded,
        _View.agenda => Icons.view_agenda_rounded,
      };
}

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

  /// Prev/next steps by day, week or month depending on the active view.
  void _shift(int by) {
    setState(() {
      switch (_view) {
        case _View.day:
          _selectedDay = _selectedDay.add(Duration(days: by));
          _monthCursor = DateTime(_selectedDay.year, _selectedDay.month);
        case _View.week:
          _selectedDay = _selectedDay.add(Duration(days: 7 * by));
          _monthCursor = DateTime(_selectedDay.year, _selectedDay.month);
        case _View.month:
        case _View.agenda:
          _monthCursor =
              DateTime(_monthCursor.year, _monthCursor.month + by);
      }
    });
  }

  void _selectDay(DateTime day) => setState(() => _selectedDay = _dateOnly(day));

  void _showDay(DateTime day) => setState(() {
        _selectedDay = _dateOnly(day);
        _monthCursor = DateTime(day.year, day.month);
        _view = _View.day;
      });

  DateTime get _weekStart =>
      _selectedDay.subtract(Duration(days: _selectedDay.weekday - 1));

  String get _toolbarLabel {
    switch (_view) {
      case _View.day:
        return DateFormat('d MMMM yyyy').format(_selectedDay);
      case _View.week:
        final start = _weekStart;
        final end = start.add(const Duration(days: 6));
        if (start.month == end.month) {
          return '${start.day} – ${DateFormat('d MMM yyyy').format(end)}';
        }
        return '${DateFormat('d MMM').format(start)} – '
            '${DateFormat('d MMM yyyy').format(end)}';
      case _View.month:
      case _View.agenda:
        return DateFormat('MMMM yyyy').format(_monthCursor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = CalendarScope.of(context);
    final familyRepo = FamilyScope.of(context);
    return StreamData<List<EventRecord>>(
      stream: repo.watchAll(),
      builder: (context, personalEvents) {
        return ListenableBuilder(
          listenable: familyRepo,
          builder: (context, _) {
            final events = [
              ...personalEvents,
              ...familyRepo.sharedEvents.map(familyShareEventToRecord),
            ]..sort((a, b) => a.start.compareTo(b.start));
            return StreamData<List<DinnerPlanRecord>>(
              stream: repo.watchDinners(),
              builder: (context, dinners) {
                return Column(
                  children: [
                    _Toolbar(
                      monthLabel: _toolbarLabel,
                      view: _view,
                      search: _search,
                      onSearch: (v) => setState(() => _query = v.trim()),
                      onView: (v) => setState(() => _view = v),
                      onPrev: () => _shift(-1),
                      onNext: () => _shift(1),
                      onToday: _goToday,
                      onNew: () => showEventEditor(context, repo,
                          initialDate: _selectedDay),
                    ),
                    Expanded(child: _body(context, repo, events, dinners)),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _body(BuildContext context, CalendarRepository repo,
      List<EventRecord> events, List<DinnerPlanRecord> dinners) {
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
    if (_view == _View.day || _view == _View.week) {
      final start = _view == _View.day ? _selectedDay : _weekStart;
      final days = [
        for (var i = 0; i < (_view == _View.day ? 1 : 7); i++)
          start.add(Duration(days: i)),
      ];
      return _TimeGridView(
        days: days,
        events: events,
        repo: repo,
        onShowDay: _view == _View.week ? _showDay : null,
      );
    }
    return _MonthView(
      monthCursor: _monthCursor,
      selectedDay: _selectedDay,
      events: events,
      dinners: dinners,
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
  final ValueChanged<String> onSearch;
  final ValueChanged<_View> onView;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return LayoutBuilder(
      builder: (context, constraints) {
        // The full desktop toolbar packs a 200px-wide title, a 220px search
        // box and three labelled buttons into one row; on a phone that runs
        // straight off the right edge (the buttons end up out of bounds).
        // Below this width it becomes a two-row layout where the search box
        // flexes to the available space instead.
        final narrow = constraints.maxWidth < 620;
        final decoration = BoxDecoration(
          border: Border(bottom: BorderSide(color: luma.border)),
        );
        if (narrow) {
          return Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            decoration: decoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _RoundIconButton(
                        icon: Icons.chevron_left_rounded, onTap: onPrev),
                    const SizedBox(width: 4),
                    _RoundIconButton(
                        icon: Icons.chevron_right_rounded, onTap: onNext),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        monthLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _ViewMenuButton(view: view, onView: onView),
                    const SizedBox(width: 4),
                    _RoundIconButton(icon: Icons.today_rounded, onTap: onToday),
                    const SizedBox(width: 4),
                    _RoundIconButton(icon: Icons.add_rounded, onTap: onNew),
                  ],
                ),
                const SizedBox(height: 10),
                _SearchField(search, onSearch),
              ],
            ),
          );
        }
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
          decoration: decoration,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RoundIconButton(
                      icon: Icons.chevron_left_rounded, onTap: onPrev),
                  const SizedBox(width: 4),
                  _RoundIconButton(
                      icon: Icons.chevron_right_rounded, onTap: onNext),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 204,
                    child: Text(
                      monthLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                  _ViewMenuButton(view: view, onView: onView),
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
      },
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

/// Google-Calendar-style view switcher: a bordered "Month ▾" button that
/// opens a dropdown listing Day / Week / Month / Agenda.
class _ViewMenuButton extends StatefulWidget {
  const _ViewMenuButton({required this.view, required this.onView});
  final _View view;
  final ValueChanged<_View> onView;

  @override
  State<_ViewMenuButton> createState() => _ViewMenuButtonState();
}

class _ViewMenuButtonState extends State<_ViewMenuButton> {
  final _menu = MenuController();
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MenuAnchor(
      controller: _menu,
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(luma.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(10),
        padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 6, horizontal: 6)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: luma.border),
          ),
        ),
      ),
      alignmentOffset: const Offset(0, 6),
      menuChildren: [
        for (final v in _View.values)
          _ViewMenuItem(
            view: v,
            selected: v == widget.view,
            onTap: () {
              _menu.close();
              widget.onView(v);
            },
          ),
      ],
      builder: (context, controller, _) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: GestureDetector(
            onTap: () => controller.isOpen ? controller.close() : controller.open(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 34,
              padding: const EdgeInsets.only(left: 12, right: 6),
              decoration: BoxDecoration(
                color: _hovering || controller.isOpen
                    ? luma.surfaceHover
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: luma.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.view.icon, size: 16, color: luma.textSecondary),
                  const SizedBox(width: 7),
                  Text(
                    widget.view.label,
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down_rounded,
                      size: 22, color: luma.textMuted),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ViewMenuItem extends StatefulWidget {
  const _ViewMenuItem(
      {required this.view, required this.selected, required this.onTap});
  final _View view;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ViewMenuItem> createState() => _ViewMenuItemState();
}

class _ViewMenuItemState extends State<_ViewMenuItem> {
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
          duration: const Duration(milliseconds: 120),
          width: 176,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: widget.selected
                ? luma.accentSubtle
                : _hovering
                    ? luma.surfaceHover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                widget.view.icon,
                size: 17,
                color: widget.selected ? luma.accent : luma.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.view.label,
                  style: TextStyle(
                    color:
                        widget.selected ? luma.accent : luma.textPrimary,
                    fontSize: 13,
                    fontWeight:
                        widget.selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
              if (widget.selected)
                Icon(Icons.check_rounded, size: 16, color: luma.accent),
            ],
          ),
        ),
      ),
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
    required this.dinners,
    required this.repo,
    required this.onSelectDay,
  });

  final DateTime monthCursor;
  final DateTime selectedDay;
  final List<EventRecord> events;
  final List<DinnerPlanRecord> dinners;
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

    final dinner = _dinnerFor(dinners, selectedDay);

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
                  dinner: dinner,
                  repo: repo,
                ),
              ),
            ],
          );
        }
        // Phone: the month grid and the selected day's panel don't both fit
        // in one fixed viewport without the panel (dinner card, event list)
        // getting clipped at the bottom. Make the whole thing scroll instead,
        // with the day panel shrink-wrapped below the grid.
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 340,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: grid,
                ),
              ),
              Container(height: 1, color: context.luma.border),
              _DayPanel(
                day: selectedDay,
                events: events,
                dinner: dinner,
                repo: repo,
                embedded: true,
              ),
            ],
          ),
        );
      },
    );
  }
}

DinnerPlanRecord? _dinnerFor(List<DinnerPlanRecord> dinners, DateTime day) {
  for (final d in dinners) {
    if (_sameDay(d.date, day)) return d;
  }
  return null;
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

    // Every day is a real surface tile so the grid reads as blocks rather than
    // blending into the background. In-month days sit on the full surface;
    // adjacent-month days recede on a dimmer surface but stay tiles.
    final Color cellColor;
    if (isSelected) {
      cellColor = luma.accentSubtle;
    } else if (_hovering) {
      cellColor = luma.surfaceHover;
    } else if (inMonth) {
      cellColor = luma.surface;
    } else {
      cellColor = Color.lerp(luma.surface, luma.background, 0.6)!;
    }

    final Color borderColor;
    final double borderWidth;
    if (isSelected) {
      borderColor = luma.accent;
      borderWidth = 1.5;
    } else if (isToday) {
      borderColor = luma.accent.withValues(alpha: 0.55);
      borderWidth = 1.5;
    } else {
      borderColor = luma.border;
      borderWidth = 1;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onSelectDay(day),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: cellColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          padding: const EdgeInsets.all(7),
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
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Expanded(
                child:
                    _CellEvents(events: dayEvents, day: day, repo: widget.repo),
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
        const chipExtent = 27.0; // chip height + spacing
        final capacity =
            (constraints.maxHeight / chipExtent).floor().clamp(0, 8);
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
              const SizedBox(height: 4),
            ],
            if (hidden > 0)
              Padding(
                padding: const EdgeInsets.only(left: 2, top: 1),
                child: Text(
                  '+$hidden more',
                  style: TextStyle(
                    color: context.luma.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
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
    final color = Color(occurrence.color);
    // Solid colored block; text flips to dark on light event colors so it
    // always meets contrast.
    final onColor = color.computeLuminance() > 0.6
        ? const Color(0xFF1A1526)
        : Colors.white;
    final time = occurrence.allDay
        ? null
        : DateFormat('HH:mm').format(occurrence.start);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () =>
            showEventEditor(context, repo, existing: occurrence.event),
        child: Container(
          height: 23,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            time == null ? occurrence.title : '$time · ${occurrence.title}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: onColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.05,
            ),
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
  const _DayPanel({
    required this.day,
    required this.events,
    required this.dinner,
    required this.repo,
    this.embedded = false,
  });
  final DateTime day;
  final List<EventRecord> events;
  final DinnerPlanRecord? dinner;
  final CalendarRepository repo;

  /// True when the panel is stacked inside an outer scroll view (phone month
  /// view) rather than filling a fixed side pane. It then shrink-wraps its
  /// event list instead of expanding, so it contributes its natural height to
  /// the scroll rather than needing a bounded box.
  final bool embedded;

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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: _DinnerSection(day: day, dinner: dinner, repo: repo),
        ),
        Container(height: 1, color: luma.border),
        if (dayEvents.isEmpty)
          _wrapEvents(
            SizedBox(
              height: embedded ? 220 : null,
              child: LumaEmptyState(
                icon: Icons.event_available_rounded,
                title: 'Nothing planned',
                subtitle: 'Add an event to fill this day.',
                action: LumaGhostButton(
                  label: 'Add event',
                  icon: Icons.add_rounded,
                  onTap: () =>
                      showEventEditor(context, repo, initialDate: day),
                ),
              ),
            ),
          )
        else
          _wrapEvents(
            ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              shrinkWrap: embedded,
              physics:
                  embedded ? const NeverScrollableScrollPhysics() : null,
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

  /// In the fixed side-pane layout the events area fills the remaining height
  /// (Expanded); when embedded in an outer scroll view it must instead take
  /// only its natural height.
  Widget _wrapEvents(Widget child) =>
      embedded ? child : Expanded(child: child);
}

/// The "what's for dinner" card shown at the top of the day panel: an empty
/// prompt to set one, or the planned dish that opens the recipe on tap.
class _DinnerSection extends StatelessWidget {
  const _DinnerSection(
      {required this.day, required this.dinner, required this.repo});
  final DateTime day;
  final DinnerPlanRecord? dinner;
  final CalendarRepository repo;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    if (dinner == null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => showDinnerEditor(context, repo, day: day),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: luma.border),
            ),
            child: Row(
              children: [
                Icon(Icons.dinner_dining_outlined,
                    size: 17, color: luma.textMuted),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Set dinner for this day',
                    style: TextStyle(
                        color: luma.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.add_rounded, size: 17, color: luma.textMuted),
              ],
            ),
          ),
        ),
      );
    }

    final d = dinner!;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => showDinnerDetail(context, repo, d),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: luma.accentSubtle,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: luma.accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(Icons.dinner_dining_rounded, size: 18, color: luma.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dinner',
                      style: TextStyle(
                        color: luma.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      d.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: luma.accent),
            ],
          ),
        ),
      ),
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

// ── Day / Week time grid ────────────────────────────────────────────────

/// Google-Calendar-style time grid: one column per day, hour lines, timed
/// events as positioned blocks, all-day events in a top strip and a "now"
/// line on today. Used for both the Day (1 column) and Week (7 columns)
/// views.
class _TimeGridView extends StatefulWidget {
  const _TimeGridView({
    required this.days,
    required this.events,
    required this.repo,
    this.onShowDay,
  });

  final List<DateTime> days;
  final List<EventRecord> events;
  final CalendarRepository repo;

  /// Week view passes this so tapping a day header zooms into that day.
  final ValueChanged<DateTime>? onShowDay;

  @override
  State<_TimeGridView> createState() => _TimeGridViewState();
}

class _TimeGridViewState extends State<_TimeGridView> {
  static const _hourHeight = 56.0;
  static const _gutterWidth = 58.0;

  // Open on 07:00 so the working day is in view.
  final _scroll = ScrollController(initialScrollOffset: 7 * _hourHeight);
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Keeps the "now" line moving while the grid stays open.
    _ticker = Timer.periodic(
        const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final rangeStart = widget.days.first;
    final rangeEnd = widget.days.last.add(const Duration(days: 1));
    final occurrences =
        expandOccurrences(widget.events, rangeStart, rangeEnd);
    final allDay = occurrences.where((o) => o.allDay).toList();
    final timed = occurrences.where((o) => !o.allDay).toList();
    final hasAllDay = allDay.isNotEmpty;

    return Column(
      children: [
        _TimeGridHeader(days: widget.days, onShowDay: widget.onShowDay),
        if (hasAllDay) ...[
          Container(height: 1, color: luma.border),
          _AllDayStrip(
            days: widget.days,
            occurrences: allDay,
            repo: widget.repo,
          ),
        ],
        Container(height: 1, color: luma.border),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            child: SizedBox(
              height: 24 * _hourHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HourGutter(hourHeight: _hourHeight, width: _gutterWidth),
                  for (final day in widget.days)
                    Expanded(
                      child: _DayColumn(
                        day: day,
                        occurrences: timed,
                        hourHeight: _hourHeight,
                        repo: widget.repo,
                      ),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimeGridHeader extends StatelessWidget {
  const _TimeGridHeader({required this.days, required this.onShowDay});
  final List<DateTime> days;
  final ValueChanged<DateTime>? onShowDay;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final today = _dateOnly(DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(
          left: _TimeGridViewState._gutterWidth, right: 8),
      child: Row(
        children: [
          for (final day in days)
            Expanded(
              child: _DayHeaderCell(
                day: day,
                isToday: _sameDay(day, today),
                onTap: onShowDay == null ? null : () => onShowDay!(day),
                luma: luma,
              ),
            ),
        ],
      ),
    );
  }
}

class _DayHeaderCell extends StatefulWidget {
  const _DayHeaderCell({
    required this.day,
    required this.isToday,
    required this.onTap,
    required this.luma,
  });
  final DateTime day;
  final bool isToday;
  final VoidCallback? onTap;
  final LumaPalette luma;

  @override
  State<_DayHeaderCell> createState() => _DayHeaderCellState();
}

class _DayHeaderCellState extends State<_DayHeaderCell> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = widget.luma;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          DateFormat('EEE').format(widget.day).toUpperCase(),
          style: TextStyle(
            color: widget.isToday ? luma.accent : luma.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.isToday
                ? luma.accent
                : _hovering
                    ? luma.surfaceHover
                    : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Text(
            '${widget.day.day}',
            style: TextStyle(
              color: widget.isToday ? luma.onAccent : luma.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: widget.onTap == null
          ? Center(child: content)
          : MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hovering = true),
              onExit: (_) => setState(() => _hovering = false),
              child: GestureDetector(
                onTap: widget.onTap,
                behavior: HitTestBehavior.opaque,
                child: Center(child: content),
              ),
            ),
    );
  }
}

class _AllDayStrip extends StatelessWidget {
  const _AllDayStrip({
    required this.days,
    required this.occurrences,
    required this.repo,
  });
  final List<DateTime> days;
  final List<EventOccurrence> occurrences;
  final CalendarRepository repo;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _TimeGridViewState._gutterWidth,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, right: 8),
              child: Text(
                'all-day',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: luma.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          for (final day in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 5, 2, 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final o in occurrences.where((o) => o.coversDay(day))) ...[
                      _MiniChip(occurrence: o, repo: repo),
                      const SizedBox(height: 3),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HourGutter extends StatelessWidget {
  const _HourGutter({required this.hourHeight, required this.width});
  final double hourHeight;
  final double width;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return SizedBox(
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var h = 1; h < 24; h++)
            Positioned(
              top: h * hourHeight - 7,
              right: 8,
              child: Text(
                '${h.toString().padLeft(2, '0')}:00',
                style: TextStyle(
                  color: luma.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One day column of the time grid: hour lines, laid-out event blocks and,
/// on today, the current-time line.
class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.occurrences,
    required this.hourHeight,
    required this.repo,
  });

  final DateTime day;
  final List<EventOccurrence> occurrences;
  final double hourHeight;
  final CalendarRepository repo;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final now = DateTime.now();
    final isToday = _sameDay(day, now);
    final slots = _layoutDay(
      occurrences.where((o) => o.coversDay(day)).toList(),
      day,
      hourHeight,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => showEventEditor(context, repo, initialDate: day),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Left edge of the column + hour lines.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: luma.border)),
                  ),
                ),
              ),
              for (var h = 1; h < 24; h++)
                Positioned(
                  top: h * hourHeight,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 1,
                    color: luma.border.withValues(alpha: 0.55),
                  ),
                ),
              for (final s in slots)
                Positioned(
                  top: s.top,
                  left: 3 + (width - 6) * s.lane / s.lanes,
                  width: (width - 6) / s.lanes - 2,
                  height: s.height,
                  child: _TimeBlock(occurrence: s.occurrence, repo: repo),
                ),
              if (isToday)
                Positioned(
                  top: (now.hour * 60 + now.minute) / 60 * hourHeight - 4,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: luma.danger,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                            child: Container(height: 2, color: luma.danger)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A timed event rendered as a colored block in the grid.
class _TimeBlock extends StatelessWidget {
  const _TimeBlock({required this.occurrence, required this.repo});
  final EventOccurrence occurrence;
  final CalendarRepository repo;

  @override
  Widget build(BuildContext context) {
    final color = Color(occurrence.color);
    final onColor = color.computeLuminance() > 0.6
        ? const Color(0xFF1A1526)
        : Colors.white;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () =>
            showEventEditor(context, repo, existing: occurrence.event),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.25), width: 0.5),
          ),
          clipBehavior: Clip.hardEdge,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showTime = constraints.maxHeight >= 34;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    occurrence.title,
                    maxLines: showTime ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: onColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  if (showTime)
                    Text(
                      '${DateFormat('HH:mm').format(occurrence.start)} – '
                      '${DateFormat('HH:mm').format(occurrence.end)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: onColor.withValues(alpha: 0.85),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TimeSlot {
  _TimeSlot(this.occurrence, this.top, this.height);
  final EventOccurrence occurrence;
  final double top;
  final double height;
  int lane = 0;
  int lanes = 1;
}

/// Positions one day's timed events: clamp to the day, convert to pixels,
/// then split overlapping events into side-by-side lanes (like Google
/// Calendar does).
List<_TimeSlot> _layoutDay(
    List<EventOccurrence> items, DateTime day, double hourHeight) {
  final dayStart = _dateOnly(day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  final slots = <_TimeSlot>[];
  for (final o in items) {
    final s = o.start.isBefore(dayStart) ? dayStart : o.start;
    final e = o.end.isAfter(dayEnd) ? dayEnd : o.end;
    if (!e.isAfter(s)) continue;
    final top = s.difference(dayStart).inMinutes / 60 * hourHeight;
    final height =
        (e.difference(s).inMinutes / 60 * hourHeight).clamp(22.0, 24 * hourHeight);
    slots.add(_TimeSlot(o, top, height));
  }
  slots.sort((a, b) => a.top.compareTo(b.top));

  // Greedy lane assignment within clusters of transitively-overlapping events.
  var clusterStart = 0;
  var clusterEnd = double.negativeInfinity;
  final laneEnds = <double>[];
  void finalizeCluster(int endIndex) {
    for (var i = clusterStart; i < endIndex; i++) {
      slots[i].lanes = laneEnds.length;
    }
  }

  for (var i = 0; i < slots.length; i++) {
    final s = slots[i];
    if (laneEnds.isNotEmpty && s.top >= clusterEnd) {
      finalizeCluster(i);
      laneEnds.clear();
      clusterStart = i;
      clusterEnd = double.negativeInfinity;
    }
    var lane = laneEnds.indexWhere((end) => end <= s.top);
    if (lane == -1) {
      lane = laneEnds.length;
      laneEnds.add(0);
    }
    s.lane = lane;
    laneEnds[lane] = s.top + s.height;
    if (s.top + s.height > clusterEnd) clusterEnd = s.top + s.height;
  }
  finalizeCluster(slots.length);
  return slots;
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
