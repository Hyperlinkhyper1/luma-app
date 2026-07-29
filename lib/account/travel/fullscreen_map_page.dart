import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../settings/settings_scope.dart';
import '../../theme/luma_theme.dart';
import 'world_map_data.dart';
import 'world_map_view.dart';

/// The travel map on its own, edge to edge. On a phone it locks to landscape
/// and hides the system bars, so the world gets the whole screen instead of a
/// letterboxed strip; on desktop it's simply a full-window map.
class FullscreenMapPage extends StatefulWidget {
  const FullscreenMapPage({super.key, required this.map});

  final WorldMap map;

  @override
  State<FullscreenMapPage> createState() => _FullscreenMapPageState();
}

class _FullscreenMapPageState extends State<FullscreenMapPage> {
  final _view = TransformationController();
  bool _rotated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_rotated) return;
    final platform = Theme.of(context).platform;
    if (platform != TargetPlatform.android && platform != TargetPlatform.iOS) {
      return;
    }
    _rotated = true;
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    if (_rotated) {
      // Hand the phone back exactly as it was found.
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
    _view.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final settings = SettingsScope.of(context);

    return Scaffold(
      backgroundColor: luma.background,
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          final visited = settings.visitedCountries
              .where((code) => widget.map.byCode(code) != null)
              .toSet();
          return Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: WorldMapView(
                    map: widget.map,
                    visited: visited,
                    onToggle: (country) =>
                        settings.toggleVisitedCountry(country.code),
                    controller: _view,
                    borderRadius: 0,
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      _OverlayButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Close',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 10),
                      _CountPill(
                        visited: visited.length,
                        total: widget.map.countries.length,
                      ),
                      const Spacer(),
                      _OverlayButton(
                        icon: Icons.restart_alt_rounded,
                        tooltip: 'Reset zoom',
                        onTap: () => _view.value = Matrix4.identity(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  const _OverlayButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: luma.surface.withValues(alpha: 0.92),
        shape: CircleBorder(side: BorderSide(color: luma.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, size: 20, color: luma.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.visited, required this.total});

  final int visited;
  final int total;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: luma.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: luma.border),
      ),
      child: Text(
        '$visited of $total visited',
        style: TextStyle(
          color: luma.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
