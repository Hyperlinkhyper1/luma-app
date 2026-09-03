import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'device_health_models.dart';
import 'device_health_repository.dart';
import 'device_health_scope.dart';
import 'widgets/app_updates_card.dart';
import 'widgets/battery_card.dart';
import 'widgets/cpu_ram_card.dart';
import 'widgets/defender_card.dart';
import 'widgets/gpu_and_driver_card.dart';
import 'widgets/health_score_dial.dart';
import 'widgets/processes_card.dart';

class DeviceHealthPage extends StatefulWidget {
  const DeviceHealthPage({super.key});

  @override
  State<DeviceHealthPage> createState() => _DeviceHealthPageState();
}

class _DeviceHealthPageState extends State<DeviceHealthPage> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || !DeviceHealthRepository.isSupported) return;
    _started = true;
    DeviceHealthScope.of(context).refreshAmbient();
  }

  @override
  Widget build(BuildContext context) {
    if (!DeviceHealthRepository.isSupported) {
      return const LumaEmptyState(
        icon: Icons.desktop_windows_rounded,
        title: 'Device Health is Windows only',
        subtitle: 'CPU, driver and Defender data come from Windows-only '
            'APIs, so this plugin only runs there for now.',
      );
    }

    final repo = DeviceHealthScope.of(context);
    final score = repo.computeScore();

    const cards = [
      CpuRamCard(),
      GpuAndDriverCard(),
      BatteryCard(),
      DefenderCard(),
      ProcessesCard(),
      AppUpdatesCard(),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(score: score, repo: repo),
          if (score.issues.isNotEmpty) ...[
            const SizedBox(height: 16),
            _IssuesBanner(issues: score.issues),
          ],
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 720) {
                return Column(
                  children: [for (final c in cards) ...[c, const SizedBox(height: 16)]],
                );
              }
              final left = <Widget>[];
              final right = <Widget>[];
              for (var i = 0; i < cards.length; i++) {
                (i.isEven ? left : right).addAll([cards[i], const SizedBox(height: 16)]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Column(children: left)),
                  const SizedBox(width: 16),
                  Expanded(child: Column(children: right)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.score, required this.repo});
  final HealthScore score;
  final DeviceHealthRepository repo;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return LumaCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 560;
          final dial = HealthScoreDial(score: score);
          final info = Column(
            crossAxisAlignment:
                narrow ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Device Health',
                style: TextStyle(color: luma.textPrimary, fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                score.checkedCategories == 0
                    ? 'Reading system status…'
                    : '${score.checkedCategories} of ${score.totalCategories} checks run',
                style: TextStyle(color: luma.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 14),
              LumaPrimaryButton(
                label: repo.checkingEverything ? 'Checking…' : 'Check everything',
                icon: Icons.health_and_safety_rounded,
                loading: repo.checkingEverything,
                onTap: repo.checkingEverything ? null : () => repo.checkEverything(),
              ),
            ],
          );
          if (narrow) {
            return Column(children: [dial, const SizedBox(height: 16), info]);
          }
          return Row(
            children: [
              dial,
              const SizedBox(width: 24),
              Expanded(child: info),
            ],
          );
        },
      ),
    );
  }
}

class _IssuesBanner extends StatelessWidget {
  const _IssuesBanner({required this.issues});
  final List<String> issues;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: luma.warning, size: 18),
              const SizedBox(width: 8),
              Text(
                'What needs attention',
                style: TextStyle(color: luma.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final issue in issues)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('•  $issue', style: TextStyle(color: luma.textSecondary, fontSize: 13)),
            ),
        ],
      ),
    );
  }
}
