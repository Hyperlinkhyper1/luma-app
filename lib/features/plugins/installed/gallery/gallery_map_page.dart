import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../account/travel/world_map_data.dart';
import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'gallery_media.dart';
import 'gallery_repository.dart';
import 'gallery_scope.dart';
import 'gallery_tile.dart';
import 'gallery_viewer_page.dart';

/// Where the photos were taken, on the same bundled world outline the travel
/// map uses. No tiles, no network — the coordinates come out of the files
/// themselves and the map is an asset.
class GalleryMapPage extends StatefulWidget {
  const GalleryMapPage({super.key});

  @override
  State<GalleryMapPage> createState() => _GalleryMapPageState();
}

class _GalleryMapPageState extends State<GalleryMapPage> {
  final TransformationController _controller = TransformationController();
  double _scale = 1;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTransform);
  }

  void _onTransform() {
    final scale = _controller.value.getMaxScaleOnAxis();
    // Clusters split as you zoom in, so the pins have to be rebuilt — but
    // only when the scale has actually moved, not on every pan frame.
    if ((scale - _scale).abs() > 0.01) setState(() => _scale = scale);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTransform)
      ..dispose();
    super.dispose();
  }

  void _openCluster(BuildContext context, GalleryMapCluster cluster) {
    final luma = context.luma;
    final repo = GalleryScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: luma.surface,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ClusterSheet(cluster: cluster, repository: repo),
    );
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repo = GalleryScope.of(context);
    final located = repo.locatedItems;

    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Photo map'),
        titleTextStyle: TextStyle(
          color: luma.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: luma.textSecondary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(22),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                repo.isLocating
                    ? '${located.length} placed so far — still reading '
                        'locations'
                    : '${located.length} of ${repo.items.length} carry a '
                        'location',
                style: TextStyle(color: luma.textSecondary, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
      body: located.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: LumaEmptyState(
                icon: Icons.location_off_rounded,
                title: 'No photos with a location',
                subtitle: 'Photos only carry coordinates when the camera had '
                    'location tagging switched on when they were taken.',
              ),
            )
          : FutureBuilder<WorldMap>(
              future: WorldMap.load(),
              builder: (context, snapshot) {
                final map = snapshot.data;
                if (map == null) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: luma.accent,
                      strokeWidth: 2.5,
                    ),
                  );
                }
                return _MapCanvas(
                  map: map,
                  items: located,
                  controller: _controller,
                  scale: _scale,
                  onOpenCluster: (cluster) => _openCluster(context, cluster),
                );
              },
            ),
    );
  }
}

class _MapCanvas extends StatelessWidget {
  const _MapCanvas({
    required this.map,
    required this.items,
    required this.controller,
    required this.scale,
    required this.onOpenCluster,
  });

  final WorldMap map;
  final List<GalleryItem> items;
  final TransformationController controller;
  final double scale;
  final ValueChanged<GalleryMapCluster> onOpenCluster;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final clusters = clusterItems(items, scale);

    return LayoutBuilder(
      builder: (context, constraints) {
        var width = constraints.maxWidth;
        var height = width / MillerProjection.aspectRatio;
        if (constraints.hasBoundedHeight && height > constraints.maxHeight) {
          height = constraints.maxHeight;
          width = height * MillerProjection.aspectRatio;
        }
        final size = Size(width, height);

        return Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: InteractiveViewer(
                transformationController: controller,
                minScale: 1,
                maxScale: 24,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    final hit = _clusterAt(details.localPosition, size, clusters);
                    if (hit != null) onOpenCluster(hit);
                  },
                  child: CustomPaint(
                    size: size,
                    painter: _PhotoMapPainter(
                      map: map,
                      clusters: clusters,
                      scale: scale,
                      luma: luma,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// The pin under a tap. Pins are drawn at a fixed on-screen size, so the
  /// hit radius has to be divided back out of the zoom.
  GalleryMapCluster? _clusterAt(
    Offset local,
    Size size,
    List<GalleryMapCluster> clusters,
  ) {
    final zoom = scale <= 0 ? 1.0 : scale;
    GalleryMapCluster? best;
    var bestDistance = double.infinity;
    for (final cluster in clusters) {
      final center = Offset(
        cluster.position.dx * size.width,
        cluster.position.dy * size.height,
      );
      // A pin's own radius plus a finger's worth of forgiveness, both in the
      // canvas's coordinates rather than the screen's.
      final slop = (_pinRadius(cluster.count) + 8) / zoom;
      final distance = (center - local).distance;
      if (distance < slop && distance < bestDistance) {
        best = cluster;
        bestDistance = distance;
      }
    }
    return best;
  }
}

/// Pins grow a little with the number of photos behind them, but not without
/// limit — a holiday should not swallow the continent.
double _pinRadius(int count) {
  if (count <= 1) return 5;
  if (count < 10) return 7;
  if (count < 50) return 9;
  return 11;
}

/// A group of photos close enough together to share one pin.
class GalleryMapCluster {
  GalleryMapCluster(this.position, this.items);

  /// Unit-space position (see [MillerProjection]).
  final Offset position;
  final List<GalleryItem> items;

  int get count => items.length;
}

/// Buckets photos into a grid in unit space, one pin per occupied cell. The
/// cell shrinks as [scale] grows, so zooming in pulls a city apart into the
/// streets it was shot on.
List<GalleryMapCluster> clusterItems(List<GalleryItem> items, double scale) {
  final cell = 0.02 / (scale <= 0 ? 1 : scale);
  final buckets = <String, List<GalleryItem>>{};
  final positions = <String, Offset>{};

  for (final item in items) {
    if (!item.hasLocation) continue;
    final point = MillerProjection.project(item.longitude!, item.latitude!);
    final key = '${(point.dx / cell).floor()}:${(point.dy / cell).floor()}';
    buckets.putIfAbsent(key, () => []).add(item);
    // The pin sits on the running mean of its members, which keeps it over
    // the photos rather than in the corner of a grid cell.
    final previous = positions[key];
    final count = buckets[key]!.length;
    positions[key] = previous == null
        ? point
        : Offset(
            previous.dx + (point.dx - previous.dx) / count,
            previous.dy + (point.dy - previous.dy) / count,
          );
  }

  return [
    for (final entry in buckets.entries)
      GalleryMapCluster(positions[entry.key]!, entry.value),
  ]..sort((a, b) => a.count.compareTo(b.count));
}

class _PhotoMapPainter extends CustomPainter {
  _PhotoMapPainter({
    required this.map,
    required this.clusters,
    required this.scale,
    required this.luma,
  });

  final WorldMap map;
  final List<GalleryMapCluster> clusters;
  final double scale;
  final LumaPalette luma;

  @override
  void paint(Canvas canvas, Size size) {
    final land = Paint()..color = luma.surfaceHover;
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6 / scale
      ..color = luma.background.withValues(alpha: 0.9);

    final paths = map.pathsFor(size);
    for (final country in map.byDescendingSize) {
      final path = paths[country.code];
      if (path == null) continue;
      canvas.drawPath(path, land);
      canvas.drawPath(path, border);
    }

    final fill = Paint()..color = luma.accent;
    final halo = Paint()..color = luma.accent.withValues(alpha: 0.25);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 / scale
      ..color = luma.onAccent.withValues(alpha: 0.85);

    for (final cluster in clusters) {
      final center = Offset(
        cluster.position.dx * size.width,
        cluster.position.dy * size.height,
      );
      final radius = _pinRadius(cluster.count) / scale;
      canvas.drawCircle(center, radius * 1.9, halo);
      canvas.drawCircle(center, radius, fill);
      canvas.drawCircle(center, radius, ring);
      if (cluster.count > 1) {
        _paintCount(canvas, center, cluster.count, radius);
      }
    }
  }

  void _paintCount(Canvas canvas, Offset center, int count, double radius) {
    final label = count > 999 ? '999+' : '$count';
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontSize: radius * 1.1,
      fontWeight: FontWeight.w700,
      textAlign: TextAlign.center,
    ))
      ..pushStyle(ui.TextStyle(color: luma.onAccent))
      ..addText(label);
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: radius * 4));
    canvas.drawParagraph(
      paragraph,
      Offset(center.dx - radius * 2, center.dy - paragraph.height / 2),
    );
  }

  @override
  bool shouldRepaint(_PhotoMapPainter old) =>
      old.clusters != clusters || old.scale != scale || old.luma != luma;
}

/// The photos behind one pin.
class _ClusterSheet extends StatelessWidget {
  const _ClusterSheet({required this.cluster, required this.repository});

  final GalleryMapCluster cluster;
  final GalleryRepository repository;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final items = cluster.items;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              items.length == 1
                  ? '1 photo here'
                  : '${items.length} photos here',
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) => GalleryTile(
                  item: items[index],
                  repository: repository,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => GalleryViewerPage(
                        items: items,
                        initialIndex: index,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
