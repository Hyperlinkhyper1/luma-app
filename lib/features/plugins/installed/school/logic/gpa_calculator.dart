// Pure GPA / grade-weighting math, kept free of Drift row types so it's
// easy to reason about and reuse from the repository and the UI alike.

/// One term's finished result for a subject: how many credit hours it was
/// worth and the grade points it earned. Interpreted on the Dutch 1-10
/// scale by default, or the US 0.0-4.0 scale when that setting is enabled.
class GpaWeighting {
  const GpaWeighting({required this.creditHours, required this.gradePoints});
  final double creditHours;
  final double gradePoints;
}

/// Standard US 4.0-scale conversion from a percentage grade.
double percentTo4Point(double percent) {
  if (percent >= 93) return 4.0;
  if (percent >= 90) return 3.7;
  if (percent >= 87) return 3.3;
  if (percent >= 83) return 3.0;
  if (percent >= 80) return 2.7;
  if (percent >= 77) return 2.3;
  if (percent >= 73) return 2.0;
  if (percent >= 70) return 1.7;
  if (percent >= 67) return 1.3;
  if (percent >= 63) return 1.0;
  if (percent >= 60) return 0.7;
  return 0.0;
}

/// Weighted-average GPA across every recorded term/subject result. Returns
/// null when there are no credit hours to weight against.
double? computeGpa(Iterable<GpaWeighting> records) {
  var totalPoints = 0.0;
  var totalCredits = 0.0;
  for (final r in records) {
    totalPoints += r.gradePoints * r.creditHours;
    totalCredits += r.creditHours;
  }
  if (totalCredits <= 0) return null;
  return totalPoints / totalCredits;
}

/// One weighted grade component within a subject (e.g. "Midterm", 30%,
/// 88/100). [scoreEarned] is null until the component has been graded.
class GradeComponentInput {
  const GradeComponentInput({
    required this.weightPercent,
    required this.scoreTotal,
    this.scoreEarned,
  });
  final double weightPercent;
  final double scoreTotal;
  final double? scoreEarned;
}

/// The subject's grade so far: what fraction of the total weight has been
/// graded, and the resulting percentage over just that graded portion.
class CurrentGradeResult {
  const CurrentGradeResult({
    required this.gradedWeightPercent,
    required this.currentPercent,
  });

  /// Sum of weightPercent across components that have a score.
  final double gradedWeightPercent;

  /// Weighted percentage over the graded portion, or null if nothing is
  /// graded yet.
  final double? currentPercent;
}

CurrentGradeResult currentGrade(List<GradeComponentInput> components) {
  var gradedWeight = 0.0;
  var earnedWeightedPoints = 0.0;
  for (final c in components) {
    if (c.scoreEarned == null || c.scoreTotal <= 0) continue;
    gradedWeight += c.weightPercent;
    earnedWeightedPoints += c.weightPercent * (c.scoreEarned! / c.scoreTotal);
  }
  if (gradedWeight <= 0) {
    return const CurrentGradeResult(
        gradedWeightPercent: 0, currentPercent: null);
  }
  return CurrentGradeResult(
    gradedWeightPercent: gradedWeight,
    currentPercent: earnedWeightedPoints / gradedWeight * 100,
  );
}

/// The average percentage the student needs on the remaining (ungraded)
/// components to land on [targetPercent] overall. Returns null when
/// everything is already graded (no remaining weight) or there's no
/// weighted work at all.
double? neededAverageOnRemaining(
  List<GradeComponentInput> components,
  double targetPercent,
) {
  final totalWeight =
      components.fold<double>(0, (sum, c) => sum + c.weightPercent);
  if (totalWeight <= 0) return null;

  var earnedWeightedPoints = 0.0;
  var remainingWeight = 0.0;
  for (final c in components) {
    if (c.scoreEarned == null || c.scoreTotal <= 0) {
      remainingWeight += c.weightPercent;
    } else {
      earnedWeightedPoints += c.weightPercent * (c.scoreEarned! / c.scoreTotal);
    }
  }
  if (remainingWeight <= 0) return null;

  final neededWeightedPoints =
      targetPercent / 100 * totalWeight - earnedWeightedPoints;
  return neededWeightedPoints / remainingWeight * 100;
}
