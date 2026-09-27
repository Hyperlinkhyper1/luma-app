import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../spotify_models.dart';
import '../spotify_scope.dart';
import 'account_shared.dart';
import 'spotify_connect_dialog.dart';

class SpotifyTab extends StatelessWidget {
  const SpotifyTab({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = SpotifyScope.of(context);
    final snapshot = repository.snapshot;
    final luma = context.luma;
    if (!repository.loaded) {
      return Center(child: CircularProgressIndicator(color: luma.accent));
    }
    if (!repository.connected) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (repository.error case final error?) ...[
                  AccountNotice(message: error, tone: luma.danger),
                  const SizedBox(height: 16),
                ],
                LumaEmptyState(
                  icon: Icons.music_note_rounded,
                  title: 'Connect your Spotify account',
                  subtitle:
                      'See your top artists and tracks, recent plays, saved tracks, playlists, and profile stats.',
                  action: LumaPrimaryButton(
                    label: 'Connect Spotify',
                    icon: Icons.link_rounded,
                    onTap: () => showSpotifyConnectDialog(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        if (repository.error case final error?) ...[
          AccountNotice(
            message: error,
            icon: Icons.error_outline_rounded,
            tone: luma.danger,
            onDismiss: repository.clearError,
          ),
          const SizedBox(height: 14),
        ],
        if (repository.warnings.isNotEmpty && !repository.loading) ...[
          AccountNotice(message: repository.warnings.join('\n')),
          const SizedBox(height: 14),
        ],
        if (repository.loading) ...[
          LinearProgressIndicator(color: luma.accent),
          const SizedBox(height: 14),
        ],
        Row(
          children: [
            Icon(Icons.music_note_rounded, color: luma.accent, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                snapshot?.displayName ?? repository.credentials!.displayName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (snapshot?.profileUrl case final url?)
              AccountLinkButton(
                label: 'Profile',
                icon: Icons.open_in_new_rounded,
                onTap: () => openExternal(url),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (snapshot != null) ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 520 ? 2 : 4;
              final width =
                  (constraints.maxWidth - (columns - 1) * 10) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: width,
                    child: AccountStatTile(
                      icon: Icons.people_outline_rounded,
                      label: 'Followers',
                      value: snapshot.followers?.toString() ?? '—',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: AccountStatTile(
                      icon: Icons.favorite_outline_rounded,
                      label: 'Saved tracks',
                      value: snapshot.savedTracks?.toString() ?? '—',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: AccountStatTile(
                      icon: Icons.queue_music_rounded,
                      label: 'Playlists',
                      value: snapshot.playlists?.toString() ?? '—',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: AccountStatTile(
                      icon: Icons.timer_outlined,
                      label: 'Tracked minutes',
                      value: '${repository.listeningTotal.minutes} min',
                      caption: repository.listeningTotal.firstPlayedAt == null
                          ? 'Waiting for recent plays'
                          : 'From ${formatDate(repository.listeningTotal.firstPlayedAt!.toLocal())}',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Estimated from full track lengths in Spotify’s available recent plays. Refresh regularly to keep the total current.',
            style: TextStyle(color: luma.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 22),
          Text(
            'Your favorites',
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Spotify rankings for the selected period',
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (range, label) in const [
                ('short_term', 'Last 4 weeks'),
                ('medium_term', 'Last 6 months'),
                ('long_term', 'Long term'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: repository.timeRange == range,
                  onSelected: (_) => repository.setTimeRange(range),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (snapshot.timeRange != repository.timeRange)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            _ItemPanel(
              title: 'Top artists',
              icon: Icons.person_outline_rounded,
              items: snapshot.topArtists,
              empty: 'No top artists available for this period.',
            ),
            const SizedBox(height: 14),
            _ItemPanel(
              title: 'Top tracks',
              icon: Icons.multitrack_audio_rounded,
              items: snapshot.topTracks,
              empty: 'No top tracks available for this period.',
            ),
          ],
          const SizedBox(height: 14),
          _ItemPanel(
            title: 'Recently played',
            icon: Icons.history_rounded,
            items: snapshot.recentTracks,
            empty: 'No recent tracks available.',
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              'Updated ${formatRelative(snapshot.fetchedAt)}',
              style: TextStyle(color: luma.textMuted, fontSize: 11),
            ),
          ),
        ] else if (!repository.loading)
          Text(
            'Refresh to load your Spotify stats.',
            style: TextStyle(color: luma.textSecondary),
          ),
      ],
    );
  }
}

class _ItemPanel extends StatelessWidget {
  const _ItemPanel({
    required this.title,
    required this.icon,
    required this.items,
    required this.empty,
  });
  final String title;
  final IconData icon;
  final List<SpotifyItem> items;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return AccountPanel(
      title: title,
      icon: icon,
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                empty,
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
            )
          : Column(
              children: [
                for (var index = 0; index < items.length; index++)
                  ListTile(
                    dense: true,
                    leading: SizedBox(
                      width: 42,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 18,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: luma.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (items[index].imageUrl case final imageUrl?)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                imageUrl,
                                width: 24,
                                height: 24,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.music_note, size: 20),
                              ),
                            ),
                        ],
                      ),
                    ),
                    title: Text(
                      items[index].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: luma.textPrimary, fontSize: 13),
                    ),
                    subtitle: items[index].subtitle.isEmpty
                        ? null
                        : Text(
                            items[index].subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: luma.textMuted,
                              fontSize: 11,
                            ),
                          ),
                    trailing: items[index].url == null
                        ? null
                        : Icon(
                            Icons.open_in_new_rounded,
                            size: 16,
                            color: luma.textMuted,
                          ),
                    onTap: items[index].url == null
                        ? null
                        : () => openExternal(items[index].url!),
                  ),
              ],
            ),
    );
  }
}
