import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';
import '../youtube_models.dart';
import '../youtube_scope.dart';
import 'account_shared.dart';
import 'youtube_charts.dart';

/// The OAuth-gated deep insights: watch time, average view duration,
/// subscriber churn and where the views came from — none of which the
/// public Data API can answer on its own.
class YoutubeAnalyticsTab extends StatelessWidget {
  const YoutubeAnalyticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = YoutubeScope.of(context);
    final analytics = repository.snapshot.analytics;
    final luma = context.luma;

    if (analytics.points.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            repository.refreshing
                ? 'Loading analytics…'
                : 'No analytics yet. Refresh to fetch the last 90 days.',
            textAlign: TextAlign.center,
            style: TextStyle(color: luma.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        _SummaryGrid(analytics: analytics),
        const SizedBox(height: 18),
        AccountPanel(
          title: 'Views',
          icon: Icons.visibility_outlined,
          subtitle: 'Last 90 days',
          child: SizedBox(
            height: 200,
            child: YoutubeTrendChart(
              points: [for (final p in analytics.points) (day: p.day, value: p.views)],
              color: luma.accent,
              valueLabel: 'views',
            ),
          ),
        ),
        const SizedBox(height: 18),
        AccountPanel(
          title: 'Watch time',
          icon: Icons.timer_outlined,
          subtitle: 'Minutes watched, last 90 days',
          child: SizedBox(
            height: 200,
            child: YoutubeTrendChart(
              points: [
                for (final p in analytics.points)
                  (day: p.day, value: p.estimatedMinutesWatched),
              ],
              color: luma.success,
              valueLabel: 'minutes',
            ),
          ),
        ),
        const SizedBox(height: 18),
        _TrafficSourcesPanel(sources: analytics.trafficSources),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.analytics});

  final YoutubeAnalyticsSnapshot analytics;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final tiles = <Widget>[
      AccountStatTile(
        icon: Icons.visibility_outlined,
        label: 'Views',
        value: formatCompact(analytics.totalViews),
        caption: 'last 90 days',
      ),
      AccountStatTile(
        icon: Icons.timer_outlined,
        label: 'Watch time',
        value: formatMinutes(analytics.totalMinutesWatched.toDouble()),
        tint: luma.success,
      ),
      AccountStatTile(
        icon: Icons.schedule_rounded,
        label: 'Avg. view duration',
        value: formatDuration(
            Duration(seconds: analytics.averageViewDurationSeconds.round())),
      ),
      AccountStatTile(
        icon: analytics.netSubscribers >= 0
            ? Icons.trending_up_rounded
            : Icons.trending_down_rounded,
        label: 'Net subscribers',
        value: '${analytics.netSubscribers >= 0 ? '+' : ''}'
            '${formatCount(analytics.netSubscribers)}',
        tint: luma.accent,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 190).floor().clamp(2, 4);
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

class _TrafficSourcesPanel extends StatelessWidget {
  const _TrafficSourcesPanel({required this.sources});

  final List<YoutubeTrafficSource> sources;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final total = sources.fold(0, (sum, s) => sum + s.views);
    final visible = sources.take(8).toList();

    return AccountPanel(
      title: 'Traffic sources',
      icon: Icons.route_outlined,
      subtitle: 'Where views came from, last 90 days',
      child: total == 0
          ? Text(
              'No traffic data yet.',
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final source in visible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                source.label,
                                style: TextStyle(
                                    color: luma.textSecondary, fontSize: 12.5),
                              ),
                            ),
                            Text(
                              '${formatCompact(source.views)} · '
                              '${(source.views / total * 100).round()}%',
                              style: TextStyle(
                                color: luma.textMuted,
                                fontSize: 11,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: SizedBox(
                            height: 6,
                            child: Stack(
                              children: [
                                Container(color: luma.surfaceHover),
                                FractionallySizedBox(
                                  widthFactor:
                                      (source.views / total).clamp(0.0, 1.0),
                                  child: Container(color: luma.accent),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
