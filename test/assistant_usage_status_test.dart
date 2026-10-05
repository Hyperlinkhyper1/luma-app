import 'package:flutter_test/flutter_test.dart';
import 'package:luma/sync/sync_service.dart';
import 'package:luma/features/chat/providers/ai_modes.dart';
import 'package:luma/features/chat/providers/ai_usage.dart';

void main() {
  test('server versions update branded model and usage names', () {
    final status = AiServerStatus.fromJson({
      'modeVersions': {'normal': '1.9', 'smarter': '2.0', 'smartest': '10.0'},
    });
    expect(
      AiMode.normal.displayNameFor(status.modeVersions['normal']),
      'Aurora 1.9',
    );
    expect(
      AiMode.smarter.displayNameFor(status.modeVersions['smarter']),
      'Nebula 2.0',
    );
    expect(
      AiMode.smartest.displayNameFor(status.modeVersions['smartest']),
      'Pulsar 10.0',
    );
    expect(
      kModelUsageEntries.first.labelFor(status.modeVersions),
      'Luma Aurora 1.9',
    );
    expect(kModelUsageEntries.last.labelFor(status.modeVersions), 'OpenAI');
  });

  test('old servers and malformed versions retain default names', () {
    final status = AiServerStatus.fromJson({
      'modeVersions': {'normal': 12, 'smarter': 'invalid'},
    });
    expect(
      AiMode.normal.displayNameFor(status.modeVersions['normal']),
      'Aurora 1.0',
    );
    expect(
      AiMode.smarter.displayNameFor(status.modeVersions['smarter']),
      'Nebula 1.0',
    );
    expect(AiServerStatus.fromJson({}).modeVersions, isEmpty);
  });

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

  test('the shared allowance and per-mode drain weights are parsed', () {
    final shared = {
      'fiveHourUsed': 100000,
      'fiveHourLimit': 2100000,
      'fiveHourPct': 5,
      'weeklyUsed': 700000,
      'weeklyLimit': 14000000,
      'weeklyPct': 5,
    };
    final status = AiServerStatus.fromJson({
      'usage': {
        'fiveHourPct': 5,
        'weeklyPct': 5,
        'modes': {'normal': shared, 'smarter': shared, 'smartest': shared},
        'modeWeights': {'normal': 1.0, 'smarter': 1.5, 'smartest': 2.5},
      },
    });
    expect(status.shared.weeklyLimit, 14000000);
    expect(status.usageFor('smartest').weeklyUsed, 700000);
    expect(status.modeWeights, {
      'normal': 1.0,
      'smarter': 1.5,
      'smartest': 2.5,
    });
    expect(AiServerStatus.fromJson({}).modeWeights, isEmpty);
  });
}
