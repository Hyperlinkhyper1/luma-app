import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';
import '../youtube_models.dart';
import '../youtube_scope.dart';
import 'account_shared.dart';

/// The YouTube landing view: who the channel is, the headline counts, and
/// the shortlist of recent uploads.
class YoutubeOverviewTab extends StatelessWidget {
  const YoutubeOverviewTab({super.key, required this.onOpenSection});

  /// Lets the "view all" link hand the user to the Videos section rather
  /// than opening a dead end.
  final void Function(String sectionId) onOpenSection;

  @override
  Widget build(BuildContext context) {
    final repository = YoutubeScope.of(context);
    final snapshot = repository.snapshot;
    final channel = snapshot.channel;
    final luma = context.luma;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        if (channel != null) _ChannelHeader(channel: channel),
        const SizedBox(height: 18),
        if (channel != null)
          _StatGrid(
            channel: channel,
            snapshot: snapshot,
            onOpenSection: onOpenSection,
          ),
        const SizedBox(height: 18),
        _RecentVideosPanel(
          videos: snapshot.videos,
          onViewAll: () => onOpenSection('youtube-videos'),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            snapshot.fetchedAt.millisecondsSinceEpoch == 0
                ? 'Not refreshed yet'
                : 'Updated ${formatRelative(snapshot.fetchedAt)}',
            style: TextStyle(color: luma.textMuted, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _ChannelHeader extends StatelessWidget {
  const _ChannelHeader({required this.channel});

  final YoutubeChannelSnapshot channel;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: decor.cardBorderRadius,
        border: Border.all(color: luma.border, width: decor.borderWidth),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 520;
          final avatar = _Avatar(url: channel.thumbnailUrl, title: channel.title);
          final identity = Column(
            crossAxisAlignment:
                narrow ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                channel.title,
                textAlign: narrow ? TextAlign.center : TextAlign.start,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 14,
                runSpacing: 8,
                alignment: narrow ? WrapAlignment.center : WrapAlignment.start,
                children: [
                  AccountMetaCount(
                    icon: Icons.people_outline_rounded,
                    value: channel.hiddenSubscriberCount
                        ? 'Subscribers hidden'
                        : '${formatCompact(channel.subscriberCount)} subscribers',
                    semanticLabel: channel.hiddenSubscriberCount
                        ? 'Subscriber count hidden'
                        : '${channel.subscriberCount} subscribers',
                  ),
                  if (channel.publishedAt != null)
                    AccountMetaCount(
                      icon: Icons.cake_outlined,
                      value: 'Since ${formatDate(channel.publishedAt!)}',
                      semanticLabel:
                          'Channel created ${formatDate(channel.publishedAt!)}',
                    ),
                ],
              ),
            ],
          );

          final actions = AccountLinkButton(
            label: 'Channel',
            icon: Icons.open_in_new_rounded,
            onTap: () => openExternal(channel.htmlUrl),
          );

          if (narrow) {
            return Column(
              children: [
                avatar,
                const SizedBox(height: 14),
                identity,
                const SizedBox(height: 6),
                actions,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              avatar,
              const SizedBox(width: 18),
              Expanded(child: identity),
              const SizedBox(width: 12),
              actions,
            ],
          );
        },
      ),
    );
  }
}

/// The channel thumbnail, with its initial standing in while the image loads
/// or if it never does.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.title});

  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final fallback = Container(
      width: 74,
      height: 74,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: luma.accentSubtle, shape: BoxShape.circle),
      child: Text(
        title.isEmpty ? '?' : title[0].toUpperCase(),
        style: TextStyle(color: luma.accent, fontSize: 28, fontWeight: FontWeight.w700),
      ),
    );

    if (url.isEmpty) return fallback;

    return Semantics(
      label: '$title avatar',
      image: true,
      child: ClipOval(
        child: Image.network(
          url,
          width: 74,
          height: 74,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : fallback,
        ),
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({
    required this.channel,
    required this.snapshot,
    required this.onOpenSection,
  });

  final YoutubeChannelSnapshot channel;
  final YoutubeSnapshot snapshot;
  final void Function(String sectionId) onOpenSection;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final analytics = snapshot.analytics;

    final tiles = <Widget>[
      AccountStatTile(
        icon: Icons.play_circle_outline_rounded,
        label: 'Total views',
        value: formatCompact(channel.viewCount),
        caption: 'all time',
      ),
      AccountStatTile(
        icon: Icons.people_outline_rounded,
        label: 'Subscribers',
        value: channel.hiddenSubscriberCount
            ? 'Hidden'
            : formatCompact(channel.subscriberCount),
        tint: luma.warning,
      ),
      AccountStatTile(
        icon: Icons.video_library_outlined,
        label: 'Videos',
        value: formatCount(channel.videoCount),
        onTap: () => onOpenSection('youtube-videos'),
      ),
      AccountStatTile(
        icon: Icons.timer_outlined,
        label: 'Watch time',
        value: formatMinutes(analytics.totalMinutesWatched.toDouble()),
        caption: 'last 90 days',
        tint: luma.success,
        onTap: () => onOpenSection('youtube-analytics'),
      ),
      AccountStatTile(
        icon: analytics.netSubscribers >= 0
            ? Icons.trending_up_rounded
            : Icons.trending_down_rounded,
        label: 'Net subscribers',
        value: '${analytics.netSubscribers >= 0 ? '+' : ''}'
            '${formatCount(analytics.netSubscribers)}',
        caption: 'last 90 days',
        tint: luma.accent,
        onTap: () => onOpenSection('youtube-analytics'),
      ),
      AccountStatTile(
        icon: Icons.visibility_outlined,
        label: 'Views',
        value: formatCompact(analytics.totalViews),
        caption: 'last 90 days',
        onTap: () => onOpenSection('youtube-analytics'),
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

class _RecentVideosPanel extends StatelessWidget {
  const _RecentVideosPanel({required this.videos, required this.onViewAll});

  final List<YoutubeVideoStat> videos;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final visible = videos.take(6).toList();

    return AccountPanel(
      title: 'Recent uploads',
      icon: Icons.video_library_outlined,
      trailing: videos.length > 6
          ? AccountLinkButton(label: 'View all', onTap: onViewAll)
          : null,
      padding: EdgeInsets.zero,
      child: visible.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No videos yet.',
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < visible.length; i++)
                  YoutubeVideoRow(video: visible[i], isLast: i == visible.length - 1),
              ],
            ),
    );
  }
}

/// One video row — shared with the Videos tab so the two never drift apart.
class YoutubeVideoRow extends StatelessWidget {
  const YoutubeVideoRow({super.key, required this.video, required this.isLast});

  final YoutubeVideoStat video;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => openExternal(video.htmlUrl),
        hoverColor: luma.surfaceHover,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: isLast ? null : Border(bottom: BorderSide(color: luma.border)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: video.thumbnailUrl.isEmpty
                    ? Container(width: 64, height: 36, color: luma.surfaceHover)
                    : Image.network(
                        video.thumbnailUrl,
                        width: 64,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            Container(width: 64, height: 36, color: luma.surfaceHover),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      video.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      video.publishedAt == null
                          ? ''
                          : formatRelative(video.publishedAt),
                      style: TextStyle(color: luma.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AccountMetaCount(
                icon: Icons.visibility_outlined,
                value: formatCompact(video.viewCount),
                semanticLabel: '${video.viewCount} views',
              ),
              const SizedBox(width: 12),
              AccountMetaCount(
                icon: Icons.thumb_up_outlined,
                value: formatCompact(video.likeCount),
                semanticLabel: '${video.likeCount} likes',
                color: luma.warning,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
