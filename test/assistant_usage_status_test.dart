import 'package:flutter_test/flutter_test.dart';
import 'package:luma/sync/sync_service.dart';

void main() {
  test('per-mode token allowances and usage are parsed independently', () {
    final status = AiServerStatus.fromJson({
      'usage': {
        'fiveHourPct': 1,
        'weeklyPct': 2,
        'modes': {
          'normal': {
            'fiveHourUsed': 1125,
            'fiveHourLimit': 112500,
            'fiveHourPct': 1,
            'weeklyUsed': 15000,
            'weeklyLimit': 750000,
            'weeklyPct': 2,
          },
          'smarter': {
            'fiveHourUsed': 1500,
            'fiveHourLimit': 75000,
            'fiveHourPct': 2,
            'weeklyUsed': 15000,
            'weeklyLimit': 500000,
            'weeklyPct': 3,
          },
        },
      },
    });
    expect(status.usageFor('normal').weeklyLimit, 750000);
    expect(status.usageFor('smarter').weeklyLimit, 500000);
    expect(status.usageFor('smarter').weeklyPct, 3);
    expect(status.usageFor('normal').weeklyPct, 2);
  });
}
