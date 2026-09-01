import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';
import '../youtube_scope.dart';
import 'account_shared.dart';
import 'youtube_overview_tab.dart' show YoutubeVideoRow;

enum _VideoSort { newest, mostViewed, mostLiked }

/// Every recent upload, sortable — the full list the Overview tab's
/// shortlist links out to.
class YoutubeVideosTab extends StatefulWidget {
  const YoutubeVideosTab({super.key});

  @override
  State<YoutubeVideosTab> createState() => _YoutubeVideosTabState();
}

class _YoutubeVideosTabState extends State<YoutubeVideosTab> {
  _VideoSort _sort = _VideoSort.newest;

  @override
  Widget build(BuildContext context) {
    final repository = YoutubeScope.of(context);
    final luma = context.luma;
    final videos = [...repository.snapshot.videos];

    switch (_sort) {
      case _VideoSort.newest:
        videos.sort((a, b) {
          final at = a.publishedAt, bt = b.publishedAt;
          if (at == null && bt == null) return 0;
          if (at == null) return 1;
          if (bt == null) return -1;
          return bt.compareTo(at);
        });
      case _VideoSort.mostViewed:
        videos.sort((a, b) => b.viewCount.compareTo(a.viewCount));
      case _VideoSort.mostLiked:
        videos.sort((a, b) => b.likeCount.compareTo(a.likeCount));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Text(
                '${videos.length} video${videos.length == 1 ? '' : 's'}',
                style: TextStyle(color: luma.textSecondary, fontSize: 12.5),
              ),
              const Spacer(),
              DropdownButton<_VideoSort>(
                value: _sort,
                underline: const SizedBox.shrink(),
                dropdownColor: luma.surface,
                style: TextStyle(color: luma.textPrimary, fontSize: 12.5),
                items: const [
                  DropdownMenuItem(value: _VideoSort.newest, child: Text('Newest')),
                  DropdownMenuItem(
                      value: _VideoSort.mostViewed, child: Text('Most viewed')),
                  DropdownMenuItem(
                      value: _VideoSort.mostLiked, child: Text('Most liked')),
                ],
                onChanged: (value) => setState(() => _sort = value ?? _sort),
              ),
            ],
          ),
        ),
        Expanded(
          child: videos.isEmpty
              ? Center(
                  child: Text(
                    'No videos yet.',
                    style: TextStyle(color: luma.textMuted, fontSize: 12),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    AccountPanel(
                      title: 'Uploads',
                      icon: Icons.video_library_outlined,
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < videos.length; i++)
                            YoutubeVideoRow(
                                video: videos[i], isLast: i == videos.length - 1),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
