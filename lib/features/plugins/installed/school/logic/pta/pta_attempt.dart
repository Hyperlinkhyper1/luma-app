import 'dart:math' as math;

import 'pta_chemistry.dart';
import 'pta_lab.dart';
import 'pta_scenarios.dart';

class PtaJarAttempt {
  PtaJarAttempt(this.label, this.set, math.Random rng)
    : lab = PtaLab(substanceById(set.ids[rng.nextInt(set.ids.length)]));

  final String label;
  final PtaSet set;
  final PtaLab lab;
  final formulas = <String, String>{};
  final steps = [PtaWorksheetStep()];
  Substance? choice;
  String conclusion = '';
  String confirmation = '';

  bool get correct => choice?.id == lab.unknown.id;
}

class PtaWorksheetStep {
  String action = '';
  final predictions = <String, String>{};
  String observation = '';
  String deduction = '';
  String equation = '';
}
