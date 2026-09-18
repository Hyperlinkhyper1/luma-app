import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import 'ui/assignments_tab.dart';
import 'ui/citations_tab.dart';
import 'ui/dashboard_tab.dart';
import 'ui/flashcards_tab.dart';
import 'ui/formulas_tab.dart';
import 'ui/gpa_tab.dart';
import 'ui/study_timer_tab.dart';
import 'ui/tests_tab.dart';
import 'ui/timetable_tab.dart';

/// Root of the School plugin: a segmented sub-navigation over the dashboard,
/// timetable, assignments, flashcards, practice tests, formulas, study timer,
/// GPA and citations sections.
class SchoolPage extends StatefulWidget {
  const SchoolPage({super.key});

  @override
  State<SchoolPage> createState() => _SchoolPageState();
}

class _SchoolPageState extends State<SchoolPage> {
  int _tab = 0;

  static const _tabs = [
    'Dashboard',
    'Timetable',
    'Assignments',
    'Flashcards',
    'Toetsen',
    'Formulas',
    'Study timer',
    'GPA',
    'Citations',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: LumaSegmentedTabs(
            tabs: _tabs,
            selectedIndex: _tab,
            onSelect: (i) => setState(() => _tab = i),
            scrollable: true,
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: const [
              DashboardTab(),
              TimetableTab(),
              AssignmentsTab(),
              FlashcardsTab(),
              TestsTab(),
              FormulasTab(),
              StudyTimerTab(),
              GpaTab(),
              CitationsTab(),
            ],
          ),
        ),
      ],
    );
  }
}
