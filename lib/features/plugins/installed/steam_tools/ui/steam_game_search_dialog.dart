import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../data/steam_database.dart';
import '../steam_api.dart';
import '../steam_models.dart';
import '../steam_scope.dart';

/// Opens the search dialog that is this plugin's main way of adding a game
/// to track — no Steam account needed.
Future<void> showSteamGameSearchDialog(BuildContext context) => showDialog<void>(
      context: context,
      builder: (_) => const SteamGameSearchDialog(),
    );

/// Search the public Steam store and start tracking whatever turns up.
///
/// This, not connecting a Steam account, is the plugin's primary way in:
/// the store search behind it takes no key and needs no library, so a game
/// can be tracked by anyone in a few seconds. Connecting Steam (see
/// SteamAccountDialog) is an optional way to bulk-add an existing library
/// afterward — nice to have, never required.
class SteamGameSearchDialog extends StatefulWidget {
  const SteamGameSearchDialog({super.key});

  @override
  State<SteamGameSearchDialog> createState() => _SteamGameSearchDialogState();
}

class _SteamGameSearchDialogState extends State<SteamGameSearchDialog> {
  final _controller = TextEditingController();
  Timer? _debounce;

  String _query = '';
  List<SteamSearchResult>? _results;
  bool _loading = false;
  String? _error;

  /// Tracks are fire-and-forget from the row's point of view, but the row
  /// still needs to know one is in flight so a second tap can't double it.
  final Set<int> _tracking = {};

  /// Created once and reused, rather than calling `watchTrackedGames()`
  /// fresh inside `build()` — a new `Stream` object every rebuild would
  /// read as "a different stream" to `StreamBuilder`, which cancels and
  /// resubscribes on every keystroke instead of just listening once.
  late final Stream<List<SteamGame>> _trackedGamesStream =
      SteamScope.of(context).watchTrackedGames();

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    setState(() => _query = query);
    if (query.isEmpty) {
      setState(() {
        _results = null;
        _error = null;
        _loading = false;
      });
      return;
    }
    // Steam's search is a real network call per keystroke otherwise — this
    // waits for a pause in typing before spending one.
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await SteamScope.of(context).search(query);
      // The field may have moved on to a newer query while this one was in
      // flight — a stale response landing now must not overwrite it.
      if (!mounted || query != _query) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } on SteamApiException catch (e) {
      if (!mounted || query != _query) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || query != _query) return;
      setState(() {
        _error = 'Could not search Steam: $e';
        _loading = false;
      });
    }
  }

  Future<void> _track(SteamSearchResult result) async {
    setState(() => _tracking.add(result.appId));
    await SteamScope.of(context)
        .trackGame(appId: result.appId, name: result.name);
    if (!mounted) return;
    setState(() => _tracking.remove(result.appId));
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Dialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: luma.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.search_rounded, color: luma.accent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Track a game',
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Search the Steam store — no account needed.',
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onChanged,
                style: TextStyle(color: luma.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search for a game',
                  hintStyle: TextStyle(color: luma.textMuted, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 18, color: luma.textMuted),
                  filled: true,
                  fillColor: luma.background,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: luma.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: luma.accent),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: luma.border),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildResults(context)),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: LumaGhostButton(
                  label: 'Done',
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    final luma = context.luma;

    if (_query.isEmpty) {
      return _Hint(
        icon: Icons.videogame_asset_outlined,
        message: "Search by a game's name to start tracking its price.",
      );
    }
    if (_loading) {
      return Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: luma.accent),
        ),
      );
    }
    if (_error case final message?) {
      return _Hint(icon: Icons.error_outline_rounded, message: message);
    }
    final results = _results ?? const [];
    if (results.isEmpty) {
      return _Hint(
        icon: Icons.search_off_rounded,
        message: 'No games matched "$_query".',
      );
    }

    return StreamBuilder<List<SteamGame>>(
      stream: _trackedGamesStream,
      builder: (context, snapshot) {
        final trackedIds = {
          for (final g in snapshot.data ?? const <SteamGame>[]) g.appId,
        };
        return ListView.separated(
          itemCount: results.length,
          separatorBuilder: (_, _) => const SizedBox(height: 4),
          itemBuilder: (context, i) {
            final result = results[i];
            final tracked = trackedIds.contains(result.appId);
            final busy = _tracking.contains(result.appId);
            return _SearchResultRow(
              result: result,
              tracked: tracked,
              busy: busy,
              onTap: tracked || busy ? null : () => _track(result),
            );
          },
        );
      },
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: luma.textMuted),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: luma.textMuted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({
    required this.result,
    required this.tracked,
    required this.busy,
    required this.onTap,
  });

  final SteamSearchResult result;
  final bool tracked;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: luma.surfaceHover,
        child: Semantics(
          label: tracked
              ? '${result.name}, already tracked'
              : '${result.name}, tap to track',
          button: !tracked,
          excludeSemantics: true,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 64,
                    height: 24,
                    child: result.tinyImage != null
                        ? Image.network(
                            result.tinyImage!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, _, _) =>
                                ColoredBox(color: luma.background),
                          )
                        : ColoredBox(color: luma.background),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tracked ? luma.textMuted : luma.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (busy)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: luma.accent,
                    ),
                  )
                else if (tracked)
                  Icon(Icons.check_circle_rounded,
                      size: 18, color: luma.success)
                else
                  Icon(Icons.add_circle_outline_rounded,
                      size: 18, color: luma.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
