import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
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

  List<String> _tabs(L t) => [
        t.schoolTabDashboard,
        t.schoolTabTimetable,
        t.schoolTabAssignments,
        t.schoolTabFlashcards,
        t.schoolTabPracticeTests,
        t.schoolTabFormulas,
        t.schoolTabStudyTimer,
        t.schoolTabGpa,
        t.schoolTabCitations,
      ];

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: LumaSegmentedTabs(
            tabs: _tabs(t),
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
