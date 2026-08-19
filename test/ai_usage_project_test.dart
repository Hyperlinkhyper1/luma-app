import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/ai_usage/ai_usage_project.dart';

void main() {
  group('projectNameFromCwd', () {
    test('null input returns null', () {
      expect(projectNameFromCwd(null), isNull);
    });

    test('empty/whitespace input returns null', () {
      expect(projectNameFromCwd(''), isNull);
      expect(projectNameFromCwd('   '), isNull);
    });

    test('joins the last two path segments', () {
      expect(
        projectNameFromCwd(r'C:\Users\ayden\Files\Intellij-Programs\luma-app'),
        'Intellij-Programs/luma-app',
      );
    });

    test('handles forward-slash paths the same way', () {
      expect(projectNameFromCwd('/home/ayden/projects/luma-app'), 'projects/luma-app');
    });

    test('a single-segment path returns just that segment', () {
      expect(projectNameFromCwd('luma-app'), 'luma-app');
    });

    test('a trailing separator does not produce an empty last segment', () {
      expect(
        projectNameFromCwd(r'C:\Users\ayden\Files\Intellij-Programs\luma-app\'),
        'Intellij-Programs/luma-app',
      );
    });
  });
}
