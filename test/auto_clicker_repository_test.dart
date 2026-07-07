import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/auto_clicker/auto_clicker_repository.dart';

void main() {
  group('AutoClickerRepository nextDelayMs', () {
    test('no offset returns the exact interval', () {
      final repo = AutoClickerRepository();
      repo.setIntervalMs(50);
      repo.setRandomOffsetMs(0);
      for (var i = 0; i < 20; i++) {
        expect(repo.nextDelayMs(), 50);
      }
    });

    test('±30 around a 50 ms base stays inside [20, 80]', () {
      final repo = AutoClickerRepository();
      repo.setIntervalMs(50);
      repo.setRandomOffsetMs(30);
      for (var i = 0; i < 500; i++) {
        final ms = repo.nextDelayMs();
        expect(ms, greaterThanOrEqualTo(20));
        expect(ms, lessThanOrEqualTo(80));
      }
    });

    test('offset larger than interval clamps to 1 ms on the low end', () {
      final repo = AutoClickerRepository();
      repo.setIntervalMs(20);
      repo.setRandomOffsetMs(1000);
      for (var i = 0; i < 500; i++) {
        final ms = repo.nextDelayMs();
        expect(ms, greaterThanOrEqualTo(1));
        expect(ms, lessThanOrEqualTo(1020));
      }
    });

    test('produces variation across calls when offset > 0', () {
      final repo = AutoClickerRepository();
      repo.setIntervalMs(50);
      repo.setRandomOffsetMs(30);
      final samples = List<int>.generate(50, (_) => repo.nextDelayMs()).toSet();
      expect(samples.length, greaterThan(1),
          reason: 'random offset should produce more than one distinct value');
    });

    test('randomOffsetMs setter clamps negatives to 0', () {
      final repo = AutoClickerRepository();
      repo.setRandomOffsetMs(-10);
      expect(repo.randomOffsetMs, 0);
    });

    test('interval setter rejects zero by clamping to 1 ms', () {
      final repo = AutoClickerRepository();
      repo.setIntervalMs(0);
      expect(repo.intervalMs, 1);
    });
  });
}