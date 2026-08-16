import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import '../_shared/windows_webview.dart';
import 'ais_key_store.dart';
import 'ais_stream_client.dart';
import 'gtfs_realtime.dart';
import 'gtfs_stops.dart';
import 'transit_client.dart';
import 'transit_vehicle.dart';
import 'transport_prefs.dart';
import 'vessel.dart';

/// Live ship tracking on a real-world map — MarineTraffic/VesselFinder,
/// inside luma. The map itself (MapLibre GL, bundled as
/// `assets/transport_tracker/index.html`) runs in an embedded WebView, same
/// as Subway Builder; everything else (vessel list, detail card, settings)
/// is native Flutter layered on top. AIS data comes straight from
/// aisstream.io over a plain WebSocket, using the user's own free API key —
/// this never touches a luma server.
class TransportTrackerPage extends StatefulWidget {
  const TransportTrackerPage({super.key});

  @override
  State<TransportTrackerPage> createState() => _TransportTrackerPageState();
}

typedef _Bounds = ({double south, double west, double north, double east});

/// Width of the docked side panel on desktop-sized viewports.
const double _panelWidth = 300;

class _TransportTrackerPageState extends State<TransportTrackerPage> {
  WebviewController? _windowsController;
  InAppWebViewController? _inAppController;
  StreamSubscription? _windowsMsgSub;
  bool _loading = true;

  final _client = AisStreamClient();
  StreamSubscription<AisConnectionState>? _stateSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<VesselPatch>? _patchSub;
  Timer? _tickTimer;
  Timer? _boundsDebounce;
  Timer? _loadingFallback;

  final _vessels = <int, Vessel>{};
  bool _dirty = false;
  int? _selectedMmsi;
  _Bounds? _bounds;
  bool _tracking = false;
  AisConnectionState _connState = AisConnectionState.idle;

  /// First failure reported by the map itself (missing style, blocked tiles,
  /// no connection). Kept so a blank map can explain itself; only the first
  /// is retained because MapLibre fires 'error' once per failed tile.
  String? _mapError;

  // ---- Public transport ------------------------------------------------
  final _transit = TransitClient();
  StreamSubscription<List<TransitVehicle>>? _transitSub;
  StreamSubscription<String>? _transitErrorSub;
  List<TransitVehicle> _transitVehicles = const [];

  /// Which layers the options menu has switched on.
  bool _showVessels = true;
  bool _showTransit = false;
  Set<TransitMode> _transitModes = TransitMode.values.toSet();
  String? _selectedTransitId;

  /// Stop names/coordinates. Needed to label the next-stops list and to
  /// place trains at all, so it is fetched the first time transit is
  /// switched on rather than at startup.
  GtfsStopsCache? _stops;
  bool _stopsLoading = false;
  String? _stopsError;

  /// Restores the layer choices from the previous session and applies them
  /// once the map is up.
  Future<void> _restorePrefs() async {
    final prefs = await TransportPrefs.load();
    if (!mounted) return;
    setState(() {
      _showVessels = prefs.showVessels;
      _showTransit = prefs.showTransit;
      _transitModes = {...prefs.transitModes};
    });
    _applyLayers();
  }

  Future<void> _savePrefs() => TransportPrefs(
        showVessels: _showVessels,
        showTransit: _showTransit,
        transitModes: _transitModes,
      ).save();

  /// Pushes the current layer choices to the map and the feed clients.
  void _applyLayers() {
    _setLayerVisible('vessels', _showVessels);
    _setLayerVisible('transit', _showTransit);
    _transit.wantsTrains = _transitModes.contains(TransitMode.train);
    if (_showTransit) {
      unawaited(_ensureStops());
      _transit.start();
    } else {
      _transit.stop();
    }
    _pushTransit();
  }

  Future<void> _ensureStops() async {
    if (_stopsLoading) return;
    var cache = _stops ?? await GtfsStopsCache.load();
    if (cache.isEmpty || cache.isStale) {
      setState(() => _stopsLoading = true);
      try {
        cache = await GtfsStopsCache.download();
        if (mounted) setState(() => _stopsError = null);
      } catch (e) {
        if (mounted) setState(() => _stopsError = e.toString());
      } finally {
        if (mounted) setState(() => _stopsLoading = false);
      }
    }
    if (!mounted) return;
    setState(() => _stops = cache);
    _transit.stops = cache;
    // Trains only exist once stop coordinates are available.
    if (_showTransit) unawaited(_transit.refresh());
  }

  String? _apiKey;
  late final Future<void> _keyLoad = _loadKey();

  @override
  void initState() {
    super.initState();
    _stateSub = _client.state.listen((s) {
      if (!mounted) return;
      setState(() {
        _connState = s;
        if (s == AisConnectionState.closed || s == AisConnectionState.error) {
          _tracking = false;
        }
      });
    });
    _errorSub = _client.errors.listen((msg) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    });
    _patchSub = _client.patches.listen((patch) {
      final existing = _vessels[patch.mmsi];
      _vessels[patch.mmsi] =
          existing == null ? Vessel.fromPatch(patch) : existing.mergedWith(patch);
      _dirty = true;
    });
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());

    unawaited(_restorePrefs());

    _transitSub = _transit.vehicles.listen((list) {
      if (!mounted) return;
      setState(() => _transitVehicles = list);
      _pushTransit();
    });
    _transitErrorSub = _transit.errors.listen((msg) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    });
  }

  void _pushTransit() {
    final features = _transitVehicles
        .where((v) => _transitModes.contains(v.mode))
        .map((v) => v.toGeoJsonFeature())
        .toList();
    final fc = jsonEncode({'type': 'FeatureCollection', 'features': features});
    _evalJs('window.TT && TT.updateTransit($fc)');
  }

  Offset? _lastPointer;

  /// Forwards the cursor to the map page, rate-limited to whole pixels so a
  /// drag doesn't fire an `executeScript` per hover event.
  void _reportPointer(Offset position) {
    final rounded = Offset(position.dx.roundToDouble(), position.dy.roundToDouble());
    if (rounded == _lastPointer) return;
    _lastPointer = rounded;
    _evalJs('window.TT && TT.setPointer(${rounded.dx}, ${rounded.dy})');
  }

  void _setLayerVisible(String group, bool visible) {
    _evalJs('window.TT && TT.setLayerVisible(${jsonEncode(group)}, $visible)');
  }

  Future<void> _openLayers() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _LayersDialog(
        showVessels: _showVessels,
        showTransit: _showTransit,
        transitModes: _transitModes,
        onChanged: (vessels, transit, modes) {
          setState(() {
            _showVessels = vessels;
            _showTransit = transit;
            _transitModes = modes;
          });
          _applyLayers();
          if (!vessels && _tracking) {
            unawaited(_client.disconnect());
            setState(() => _tracking = false);
          }
          unawaited(_savePrefs());
        },
      ),
    );
  }

  /// The HTML document loading (`onLoaded`/`onLoadStop`) just means the page
  /// executed — the map itself only reports ready once MapLibre's 'load'
  /// event fires (`_onBridgeEvent('mapReady', ...)`), which needs the style
  /// JSON to be fetched over the network. If that never happens (e.g. no
  /// internet), fall back after a while instead of spinning forever.
  void _armLoadingFallback() {
    _loadingFallback?.cancel();
    _loadingFallback = Timer(const Duration(seconds: 15), () {
      if (mounted && _loading) setState(() => _loading = false);
    });
  }

  Future<void> _loadKey() async {
    final store = await AisKeyStore.load();
    final key = await store.readKey();
    if (!mounted) return;
    setState(() => _apiKey = key);
  }

  void _onTick() {
    final now = DateTime.now();
    final before = _vessels.length;
    _vessels.removeWhere(
        (_, v) => now.difference(v.lastUpdate) > const Duration(minutes: 8));
    if (_vessels.length != before && _selectedMmsi != null &&
        !_vessels.containsKey(_selectedMmsi)) {
      _selectedMmsi = null;
    }
    if (_dirty || _vessels.length != before) {
      _pushVessels();
      _dirty = false;
    }
    if (mounted) setState(() {});
  }

  void _pushVessels() {
    final features = _vessels.values
        .map((v) => v.toGeoJsonFeature(selected: v.mmsi == _selectedMmsi))
        .toList();
    final fc = jsonEncode({'type': 'FeatureCollection', 'features': features});
    _evalJs('window.TT && TT.updateVessels($fc)');
  }

  Future<void> _evalJs(String script) async {
    try {
      if (Platform.isWindows) {
        await _windowsController?.executeScript(script);
      } else {
        await _inAppController?.evaluateJavascript(source: script);
      }
    } catch (_) {
      // Webview not attached yet, or navigated away — safe to drop.
    }
  }

  // ---- Bridge: JS -> Dart -------------------------------------------

  void _onBridgeEvent(String name, List args) {
    switch (name) {
      case 'mapReady':
        if (mounted) setState(() => _loading = false);
        break;
      case 'boundsChanged':
        if (args.length < 4) return;
        _bounds = (
          south: (args[0] as num).toDouble(),
          west: (args[1] as num).toDouble(),
          north: (args[2] as num).toDouble(),
          east: (args[3] as num).toDouble(),
        );
        if (mounted) setState(() {});
        if (_tracking) _scheduleBoundsUpdate();
        break;
      case 'vesselClicked':
        if (args.isEmpty) return;
        final mmsi = (args[0] as num).toInt();
        if (!mounted || !_vessels.containsKey(mmsi)) return;
        setState(() => _selectedMmsi = mmsi);
        _pushVessels();
        break;
      case 'transitClicked':
        if (args.isEmpty) return;
        final id = args[0].toString();
        if (!mounted) return;
        final hit = _transitVehicles.where((v) => v.id == id);
        if (hit.isEmpty) return;
        setState(() {
          _selectedTransitId = id;
          _selectedMmsi = null;
        });
        _pushVessels();
        break;
      case 'mapError':
        if (!mounted || _mapError != null || args.isEmpty) return;
        setState(() => _mapError = args[0].toString());
        break;
    }
  }

  void _onWindowsController(WebviewController controller) {
    _windowsController = controller;
    _windowsMsgSub = controller.webMessage.listen((raw) {
      Map<String, dynamic> msg;
      try {
        msg = raw is String
            ? jsonDecode(raw) as Map<String, dynamic>
            : Map<String, dynamic>.from(raw as Map);
      } catch (_) {
        return;
      }
      final name = msg['name'] as String? ?? '';
      final args = (msg['args'] as List?) ?? const [];
      _onBridgeEvent(name, args);
    });
  }

  // ---- Live tracking --------------------------------------------------

  /// AISStream allows updating a live connection's bounding box on the fly
  /// (throttled to roughly once a second), so panning the map while tracking
  /// just re-subscribes instead of tearing down the socket.
  void _scheduleBoundsUpdate() {
    _boundsDebounce?.cancel();
    _boundsDebounce = Timer(const Duration(milliseconds: 1300), () {
      final bounds = _bounds;
      final key = _apiKey;
      if (bounds == null || key == null || !_tracking) return;
      _client.updateBoundingBox(
        apiKey: key,
        box: AisBoundingBox(
          south: bounds.south,
          west: bounds.west,
          north: bounds.north,
          east: bounds.east,
        ),
      );
    });
  }

  Future<void> _toggleTracking() async {
    if (_tracking) {
      await _client.disconnect();
      if (mounted) setState(() => _tracking = false);
      return;
    }
    final key = _apiKey;
    if (key == null || key.isEmpty) {
      await _openSettings();
      return;
    }
    final bounds = _bounds;
    if (bounds == null) return;
    setState(() => _tracking = true);
    await _client.connect(
      apiKey: key,
      box: AisBoundingBox(
        south: bounds.south,
        west: bounds.west,
        north: bounds.north,
        east: bounds.east,
      ),
    );
  }

  void _selectVessel(int mmsi) {
    final v = _vessels[mmsi];
    if (v == null) return;
    setState(() => _selectedMmsi = mmsi);
    _pushVessels();
    _evalJs('TT.flyTo(${v.latitude}, ${v.longitude}, 12)');
  }

  Future<void> _openSettings() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const _ApiKeyDialog(),
    );
    if (saved == true) await _loadKey();
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isLinux) {
      return const Center(
        child: LumaEmptyState(
          icon: Icons.directions_boat_outlined,
          title: 'Not available on Linux',
          subtitle: 'Transport Tracker requires an embedded WebView that is '
              'not yet supported on this platform.',
        ),
      );
    }
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 700;
      return Stack(
        children: [
          // The embedded WebView receives the wheel but never a mousemove,
          // so the page cannot know where the cursor is and would zoom from
          // the top-left corner. Forwarding hover keeps scroll zoom anchored
          // under the pointer. See the hostPointer note in map.js.
          Positioned.fill(
            child: MouseRegion(
              opaque: false,
              onHover: (event) => _reportPointer(event.localPosition),
              child: Platform.isWindows
                ? WindowsWebview(
                    fileUrl: Uri.file(
                      windowsAssetPath('assets/transport_tracker/index.html'),
                    ).toString(),
                    onController: _onWindowsController,
                    onLoaded: _armLoadingFallback,
                  )
                : InAppWebView(
                    initialFile: 'assets/transport_tracker/index.html',
                    initialSettings: InAppWebViewSettings(
                      transparentBackground: true,
                      supportZoom: false,
                    ),
                    onWebViewCreated: (controller) {
                      _inAppController = controller;
                      controller.addJavaScriptHandler(
                        handlerName: 'tt_bridge',
                        callback: (args) async {
                          final name = args[0] as String;
                          final callArgs =
                              (args.length > 1 ? args[1] : const []) as List;
                          _onBridgeEvent(name, callArgs);
                          return null;
                        },
                      );
                    },
                    onLoadStop: (controller, url) => _armLoadingFallback(),
                  ),
            ),
          ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (!_loading) _TopBar(
            // On phone the app overlays its own floating back button in the
            // top-left corner (this plugin is full-screen/"immersive" there
            // — see AppShell._phoneImmersivePlugins), so the status pill
            // needs extra clearance to not sit under it.
            leftInset: wide ? 12 : 56,
            // Keep the controls clear of the docked side panel so a wrapped
            // second row can never slide underneath it.
            rightInset: wide ? _panelWidth + 24 : 12,
            connState: _connState,
            tracking: _tracking,
            canTrack: _bounds != null,
            showVessels: _showVessels,
            onToggleTracking: _toggleTracking,
            onOpenLayers: _openLayers,
            onOpenSettings: _openSettings,
          ),
          if (!_loading)
            Positioned(
              // Docked to the right on desktop; a bottom sheet on a phone,
              // where a full-height panel would cover the whole map.
              top: wide ? 66 : null,
              right: 12,
              bottom: 12,
              width: wide ? _panelWidth : null,
              left: wide ? null : 12,
              height: wide ? null : constraints.maxHeight * 0.42,
              child: FutureBuilder<void>(
                future: _keyLoad,
                builder: (context, _) => _SidePanel(
                  vessels: _vessels,
                  selectedMmsi: _selectedMmsi,
                  selectedTransit: _selectedTransitId == null
                      ? null
                      : _transitVehicles
                          .where((v) => v.id == _selectedTransitId)
                          .firstOrNull,
                  onTransitBack: () =>
                      setState(() => _selectedTransitId = null),
                  stops: _stops,
                  stopsLoading: _stopsLoading,
                  stopsError: _stopsError,
                  tripUpdates: _transit.tripUpdates,
                  hasApiKey: _apiKey != null && _apiKey!.isNotEmpty,
                  tracking: _tracking,
                  mapError: _mapError,
                  rawMessages: _client.rawMessageCount,
                  transitVehicles: _showTransit
                      ? _transitVehicles
                          .where((v) => _transitModes.contains(v.mode))
                          .toList()
                      : null,
                  onSelect: _selectVessel,
                  onDeselect: () {
                    setState(() => _selectedMmsi = null);
                    _pushVessels();
                  },
                  onOpenSettings: _openSettings,
                ),
              ),
            ),
        ],
      );
    });
  }

  @override
  void dispose() {
    _boundsDebounce?.cancel();
    _loadingFallback?.cancel();
    _tickTimer?.cancel();
    _stateSub?.cancel();
    _errorSub?.cancel();
    _patchSub?.cancel();
    _transitSub?.cancel();
    _transitErrorSub?.cancel();
    _transit.dispose();
    _client.dispose();
    _windowsMsgSub?.cancel();
    _windowsController?.dispose();
    _inAppController?.dispose();
    super.dispose();
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.leftInset,
    required this.rightInset,
    required this.connState,
    required this.tracking,
    required this.canTrack,
    required this.showVessels,
    required this.onToggleTracking,
    required this.onOpenLayers,
    required this.onOpenSettings,
  });

  final double leftInset;
  final double rightInset;
  final AisConnectionState connState;
  final bool tracking;
  final bool canTrack;
  final bool showVessels;
  final VoidCallback onToggleTracking;
  final VoidCallback onOpenLayers;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    // The status/track pills sit in a Wrap so a long status label on a
    // narrow phone drops to a second line instead of overflowing (there's
    // no scroll region to bail out into up here); settings stays pinned to
    // the trailing edge via the outer Row regardless of how that wraps.
    return Positioned(
      top: 12,
      left: leftInset,
      right: rightInset,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Glass(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: switch (connState) {
                            AisConnectionState.live => luma.success,
                            AisConnectionState.connecting => luma.accent,
                            AisConnectionState.error => luma.danger,
                            _ => luma.textMuted,
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        switch (connState) {
                          AisConnectionState.live => 'Live',
                          AisConnectionState.connecting => 'Connecting…',
                          AisConnectionState.error => 'Connection error',
                          AisConnectionState.closed => 'Stopped',
                          AisConnectionState.idle => 'Idle',
                        },
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showVessels) _Glass(
                  onTap: canTrack ? onToggleTracking : null,
                  accent: tracking,
                  tooltip: canTrack
                      ? (tracking
                          ? 'Stop the live AIS feed'
                          : 'Start a live AIS feed for the area on screen')
                      : 'Waiting for the map to finish loading',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tracking
                            ? Icons.stop_circle_outlined
                            : Icons.play_circle_outline_rounded,
                        size: 16,
                        color: tracking ? luma.onAccent : luma.textPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tracking ? 'Stop tracking' : 'Track this view',
                        style: TextStyle(
                          color: tracking ? luma.onAccent : luma.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _Glass(
            onTap: onOpenLayers,
            tooltip: 'Choose what to track',
            padding: const EdgeInsets.all(12),
            child: Icon(Icons.layers_outlined, size: 16, color: luma.textPrimary),
          ),
          const SizedBox(width: 8),
          _Glass(
            onTap: onOpenSettings,
            tooltip: 'AISStream.io API key settings',
            padding: const EdgeInsets.all(12),
            child: Icon(Icons.settings_outlined, size: 16, color: luma.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// A translucent "glass" chip, matching the floating-control look used
/// elsewhere for map overlays (see Subway Builder's `#mapctl`). Always at
/// least 44×44 so it meets the platform touch-target minimum even where the
/// visible pill is smaller (e.g. the icon-only settings button).
class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    this.onTap,
    this.accent = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.tooltip,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool accent;
  final EdgeInsetsGeometry padding;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final pill = Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: padding,
      decoration: BoxDecoration(
        color: accent ? luma.accent : luma.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent ? luma.accent : luma.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // widthFactor pins Align to its child's width. Without it, Align
      // expands to the maximum width its parent offers — inside a Wrap that
      // is the full row, which stretched each pill across the screen and
      // pushed the rest onto extra lines.
      child: Center(widthFactor: 1.0, child: child),
    );
    if (onTap == null) return pill;
    final button = Material(
      type: MaterialType.transparency,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        child: pill,
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.vessels,
    required this.selectedMmsi,
    required this.hasApiKey,
    required this.tracking,
    required this.mapError,
    required this.rawMessages,
    required this.transitVehicles,
    required this.selectedTransit,
    required this.onTransitBack,
    required this.stops,
    required this.stopsLoading,
    required this.stopsError,
    required this.tripUpdates,
    required this.onSelect,
    required this.onDeselect,
    required this.onOpenSettings,
  });

  final TransitVehicle? selectedTransit;
  final VoidCallback onTransitBack;
  final GtfsStopsCache? stops;
  final bool stopsLoading;
  final String? stopsError;
  final Map<String, TripUpdate> tripUpdates;
  final Map<int, Vessel> vessels;
  final int? selectedMmsi;
  final bool hasApiKey;
  final bool tracking;
  final String? mapError;
  final int rawMessages;
  final List<TransitVehicle>? transitVehicles;
  final ValueChanged<int> onSelect;
  final VoidCallback onDeselect;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final selected =
        selectedMmsi != null ? vessels[selectedMmsi] : null;
    return Container(
      decoration: BoxDecoration(
        color: luma.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: luma.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      // Crossfade rather than snap between the list and detail views —
      // this is a real navigation state change, not a static redraw.
      child: AnimatedSwitcher(
        duration: WidgetsBinding
                .instance.platformDispatcher.accessibilityFeatures.disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        // The default layout builder centres its child, which left a short
        // detail card floating in the middle of a tall panel with a large
        // empty band above it. Pin everything to the top instead.
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, ?current],
        ),
        child: selectedTransit != null
            ? _TransitDetail(
                key: ValueKey('transit-${selectedTransit!.id}'),
                vehicle: selectedTransit!,
                stops: stops,
                stopsLoading: stopsLoading,
                stopsError: stopsError,
                update: tripUpdates[selectedTransit!.tripId],
                onBack: onTransitBack,
              )
            : selected != null
            ? _VesselDetail(
                key: ValueKey('detail-${selected.mmsi}'),
                vessel: selected,
                onBack: onDeselect,
              )
            : _VesselList(
                key: const ValueKey('list'),
                vessels: vessels,
                hasApiKey: hasApiKey,
                tracking: tracking,
                mapError: mapError,
                rawMessages: rawMessages,
                transitVehicles: transitVehicles,
                onSelect: onSelect,
                onOpenSettings: onOpenSettings,
              ),
      ),
    );
  }
}

class _VesselList extends StatelessWidget {
  const _VesselList({
    super.key,
    required this.vessels,
    required this.hasApiKey,
    required this.tracking,
    required this.mapError,
    required this.rawMessages,
    required this.transitVehicles,
    required this.onSelect,
    required this.onOpenSettings,
  });

  final Map<int, Vessel> vessels;
  final bool hasApiKey;
  final bool tracking;
  final String? mapError;
  final int rawMessages;
  final List<TransitVehicle>? transitVehicles;
  final ValueChanged<int> onSelect;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final sorted = vessels.values.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Row(
            children: [
              Icon(Icons.directions_boat_rounded, size: 16, color: luma.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  transitVehicles != null
                      ? 'Vessels (${vessels.length}) · Transit (${transitVehicles!.length})'
                      : 'Vessels (${vessels.length})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!hasApiKey)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: _KeyPrompt(onOpenSettings: onOpenSettings),
          ),
        Expanded(
          child: sorted.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        !hasApiKey
                            ? 'Add a free AISStream.io API key to see live '
                                'ships.'
                            : tracking
                                ? 'Connected — waiting for position reports. '
                                    'Busy shipping lanes fill in within '
                                    'seconds; open ocean can take longer.'
                                : 'No vessels yet. Press "Track this view" to '
                                    'start the live feed for the area on '
                                    'screen.',
                        style: TextStyle(
                            color: luma.textMuted, fontSize: 12.5, height: 1.4),
                      ),
                      // Tells a silent feed apart from one that is arriving
                      // but not producing positions.
                      if (tracking) ...[
                        const SizedBox(height: 10),
                        Text(
                          rawMessages == 0
                              ? 'No AIS messages received yet. If this stays '
                                  'at zero, the key may be rejected or this '
                                  'area may have no reporting traffic.'
                              : '$rawMessages AIS messages received.',
                          style: TextStyle(
                              color: luma.textMuted,
                              fontSize: 11,
                              height: 1.4),
                        ),
                      ],
                      if (mapError != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                size: 14, color: luma.danger),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'The map could not load fully — check this '
                                'device\'s internet connection. ($mapError)',
                                style: TextStyle(
                                    color: luma.danger,
                                    fontSize: 11,
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                )
              // Only vessels are listed. Transit routinely runs to a few
              // thousand vehicles nationwide, and an undifferentiated wall
              // of "Bus 1079" rows is noise — those are found by tapping
              // them on the map, which is where they have context.
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                  itemCount: sorted.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 2),
                  itemBuilder: (context, i) {
                    final v = sorted[i];
                    return _VesselRow(vessel: v, onTap: () => onSelect(v.mmsi));
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: _CategoryLegend(),
        ),
      ],
    );
  }
}

class _KeyPrompt extends StatelessWidget {
  const _KeyPrompt({required this.onOpenSettings});
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Material(
      color: luma.accentSubtle,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenSettings,
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: luma.accent.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(Icons.key_rounded, size: 16, color: luma.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Add your free API key',
                  style: TextStyle(
                    color: luma.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 16, color: luma.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _VesselRow extends StatelessWidget {
  const _VesselRow({required this.vessel, required this.onTap});
  final Vessel vessel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: vessel.category.color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vessel.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      vessel.category.label,
                      style: TextStyle(color: luma.textMuted, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              if (vessel.sog != null)
                Text(
                  '${vessel.sog!.toStringAsFixed(1)} kn',
                  style: TextStyle(color: luma.textSecondary, fontSize: 11),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryLegend extends StatelessWidget {
  const _CategoryLegend();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    const shown = [
      VesselCategory.cargo,
      VesselCategory.tanker,
      VesselCategory.passenger,
      VesselCategory.fishing,
      VesselCategory.pleasureCraft,
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        for (final c in shown)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(shape: BoxShape.circle, color: c.color),
              ),
              const SizedBox(width: 4),
              Text(c.label, style: TextStyle(color: luma.textMuted, fontSize: 10)),
            ],
          ),
      ],
    );
  }
}

class _VesselDetail extends StatelessWidget {
  const _VesselDetail({super.key, required this.vessel, required this.onBack});
  final Vessel vessel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, size: 18, color: luma.textSecondary),
                onPressed: onBack,
                tooltip: 'Back to vessel list',
              ),
              Expanded(
                child: Text(
                  vessel.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: vessel.category.color),
                ),
                const SizedBox(width: 6),
                Text(vessel.category.label,
                    style: TextStyle(color: luma.textMuted, fontSize: 11.5)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Divider(color: luma.border, height: 1),
          const SizedBox(height: 10),
          _DetailRow(label: 'MMSI', value: '${vessel.mmsi}'),
          if (vessel.imo != null) _DetailRow(label: 'IMO', value: '${vessel.imo}'),
          if (vessel.callSign != null)
            _DetailRow(label: 'Call sign', value: vessel.callSign!),
          _DetailRow(
            label: 'Speed',
            value: vessel.sog != null
                ? '${vessel.sog!.toStringAsFixed(1)} kn'
                : '—',
          ),
          _DetailRow(
            label: 'Course',
            value: vessel.cog != null ? '${vessel.cog!.toStringAsFixed(0)}°' : '—',
          ),
          if (vessel.trueHeading != null)
            _DetailRow(label: 'Heading', value: '${vessel.trueHeading}°'),
          _DetailRow(label: 'Status', value: navStatusLabel(vessel.navStatus)),
          if (vessel.destination != null)
            _DetailRow(label: 'Destination', value: vessel.destination!),
          if (vessel.draught != null)
            _DetailRow(
                label: 'Draught', value: '${vessel.draught!.toStringAsFixed(1)} m'),
          _DetailRow(
            label: 'Position',
            value:
                '${vessel.latitude.toStringAsFixed(4)}, ${vessel.longitude.toStringAsFixed(4)}',
          ),
          _DetailRow(label: 'Last report', value: _relativeTime(vessel.lastUpdate)),
        ],
      ),
    );
  }
}

/// Detail card for a public-transport vehicle, opened by tapping its dot on
/// the map or its row in the list.
///
/// Deliberately does not promise a next-stops timeline: the realtime feed
/// identifies stops only by id, and resolving those to names needs the
/// national static GTFS dataset, which is a ~225 MB download. Everything
/// shown here comes from the live feed itself.
class _TransitDetail extends StatelessWidget {
  const _TransitDetail({
    super.key,
    required this.vehicle,
    required this.stops,
    required this.stopsLoading,
    required this.stopsError,
    required this.update,
    required this.onBack,
  });

  final TransitVehicle vehicle;
  final GtfsStopsCache? stops;
  final bool stopsLoading;
  final String? stopsError;
  final TripUpdate? update;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final kmh = vehicle.speed == null ? null : vehicle.speed! * 3.6;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded,
                    size: 18, color: luma.textSecondary),
                onPressed: onBack,
                tooltip: 'Back to list',
              ),
              // Line badge, in the vehicle's mode colour.
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: vehicle.mode.color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  (vehicle.line?.isNotEmpty ?? false) ? vehicle.line! : '—',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${vehicle.operator ?? 'Unknown'} · ${vehicle.mode.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                    ),
                    Text(
                      vehicle.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: luma.border, height: 1),
          const SizedBox(height: 10),
          _DetailRow(label: 'Operator', value: vehicle.operator ?? '—'),
          _DetailRow(label: 'Line', value: vehicle.line ?? '—'),
          _DetailRow(label: 'Mode', value: vehicle.mode.label),
          _DetailRow(label: 'Vehicle #', value: vehicle.label ?? '—'),
          _DetailRow(
            label: 'Speed',
            value: kmh == null ? '—' : '${kmh.toStringAsFixed(0)} km/h',
          ),
          _DetailRow(
            label: 'Position',
            value: '${vehicle.latitude.toStringAsFixed(4)}, '
                '${vehicle.longitude.toStringAsFixed(4)}',
          ),
          _DetailRow(
            label: 'Last update',
            value: vehicle.timestamp == null
                ? '—'
                : _relativeTime(vehicle.timestamp!),
          ),
          if (vehicle.interpolated) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 13, color: luma.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Estimated from the timetable — trains do not broadcast '
                    'their position in the open data, so this is interpolated '
                    'between stations.',
                    style: TextStyle(
                        color: luma.textMuted, fontSize: 10.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _NextStops(
            update: update,
            stops: stops,
            stopsLoading: stopsLoading,
            stopsError: stopsError,
            accent: vehicle.mode.color,
          ),
        ],
      ),
    );
  }
}

/// The remaining calls of a journey, in the style of a departure board:
/// stop name, countdown, and scheduled vs expected time when delayed.
class _NextStops extends StatelessWidget {
  const _NextStops({
    required this.update,
    required this.stops,
    required this.stopsLoading,
    required this.stopsError,
    required this.accent,
  });

  final TripUpdate? update;
  final GtfsStopsCache? stops;
  final bool stopsLoading;
  final String? stopsError;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;

    Widget note(String text, {Color? color}) => Text(
          text,
          style: TextStyle(
              color: color ?? luma.textMuted, fontSize: 11.5, height: 1.4),
        );

    if (stopsLoading) {
      return Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: luma.accent),
          ),
          const SizedBox(width: 10),
          Expanded(child: note('Downloading stop names (about 1.4 MB, once)…')),
        ],
      );
    }
    if (stopsError != null) {
      return note('Stop names unavailable: $stopsError', color: luma.danger);
    }

    final calls = update?.calls ?? const <StopCall>[];
    if (calls.isEmpty) {
      return note('No stop predictions are published for this journey.');
    }

    final now = DateTime.now();
    final upcoming = calls
        .where((c) => c.time != null && c.time!.isAfter(now))
        .take(12)
        .toList();
    if (upcoming.isEmpty) {
      return note('This journey has no remaining stops.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NEXT STOPS',
          style: TextStyle(
            color: luma.textMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < upcoming.length; i++)
          _StopRow(
            call: upcoming[i],
            name: stops?.lookup(upcoming[i].stopId)?.name ??
                upcoming[i].stopId ??
                'Unknown stop',
            accent: accent,
            first: i == 0,
            last: i == upcoming.length - 1,
            now: now,
          ),
      ],
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.call,
    required this.name,
    required this.accent,
    required this.first,
    required this.last,
    required this.now,
  });

  final StopCall call;
  final String name;
  final Color accent;
  final bool first;
  final bool last;
  final DateTime now;

  static String _countdown(Duration d) {
    if (d.inMinutes < 1) return '${d.inSeconds} sec';
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    return '$hours u ${minutes.toString().padLeft(2, '0')} min';
  }

  static String _clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final time = call.time!;
    final delay = call.delaySeconds ?? 0;
    // Under a minute either way is not worth colouring as a delay.
    final late = delay >= 60;
    final scheduled = time.subtract(Duration(seconds: delay));

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline rail: a dot per stop with a connecting line.
          SizedBox(
            width: 18,
            child: Column(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: first ? accent : luma.surface,
                    border: Border.all(color: accent, width: 2),
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: accent.withValues(alpha: 0.35),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 12.5,
                        fontWeight: first ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _countdown(time.difference(now)),
                        style: TextStyle(
                          color: late ? luma.danger : luma.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (late) ...[
                            Text(
                              _clock(scheduled),
                              style: TextStyle(
                                color: luma.textMuted,
                                fontSize: 10.5,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            _clock(time),
                            style: TextStyle(
                              color: late ? luma.danger : luma.textMuted,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(label,
                style: TextStyle(color: luma.textMuted, fontSize: 11.5)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _relativeTime(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  return '${diff.inHours}h ago';
}

/// "What to track" — picks which live layers are on, and which transport
/// modes are shown within them.
class _LayersDialog extends StatefulWidget {
  const _LayersDialog({
    required this.showVessels,
    required this.showTransit,
    required this.transitModes,
    required this.onChanged,
  });

  final bool showVessels;
  final bool showTransit;
  final Set<TransitMode> transitModes;
  final void Function(bool vessels, bool transit, Set<TransitMode> modes)
      onChanged;

  @override
  State<_LayersDialog> createState() => _LayersDialogState();
}

class _LayersDialogState extends State<_LayersDialog> {
  late bool _vessels = widget.showVessels;
  late bool _transit = widget.showTransit;
  late final Set<TransitMode> _modes = {...widget.transitModes};

  void _emit() => widget.onChanged(_vessels, _transit, {..._modes});

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
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.layers_outlined, color: luma.accent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'What to track',
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _LayerToggle(
                icon: Icons.directions_boat_rounded,
                title: 'Ships',
                subtitle: 'Live AIS vessel positions worldwide. Needs your '
                    'own free AISStream.io key.',
                value: _vessels,
                onChanged: (v) {
                  setState(() => _vessels = v);
                  _emit();
                },
              ),
              const SizedBox(height: 10),
              _LayerToggle(
                icon: Icons.directions_bus_rounded,
                title: 'Public transport — Netherlands',
                subtitle: 'Live trains, metros, trams, buses and ferries '
                    'from the Dutch open-data feed. No key needed.',
                value: _transit,
                onChanged: (v) {
                  setState(() => _transit = v);
                  _emit();
                },
              ),
              if (_transit) ...[
                const SizedBox(height: 14),
                Text(
                  'Modes',
                  style: TextStyle(
                    color: luma.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final mode in TransitMode.values)
                      _ModeChip(
                        mode: mode,
                        selected: _modes.contains(mode),
                        onTap: () {
                          setState(() {
                            if (!_modes.remove(mode)) _modes.add(mode);
                          });
                          _emit();
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              LumaGhostButton(
                label: 'Done',
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LayerToggle extends StatelessWidget {
  const _LayerToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Material(
      color: value ? luma.accentSubtle : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onChanged(!value),
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: value ? luma.accent : luma.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: value ? luma.accent : luma.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                          color: luma.textMuted, fontSize: 11, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final TransitMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Material(
      color: selected ? mode.color.withValues(alpha: 0.16) : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border:
                Border.all(color: selected ? mode.color : luma.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(mode.icon,
                  size: 15, color: selected ? mode.color : luma.textMuted),
              const SizedBox(width: 7),
              Text(
                mode.label,
                style: TextStyle(
                  color: selected ? luma.textPrimary : luma.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The AISStream.io API key entry dialog — mirrors the AI Assistant's
/// per-provider key management UI (see `AiSettingsSection`).
class _ApiKeyDialog extends StatefulWidget {
  const _ApiKeyDialog();

  @override
  State<_ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<_ApiKeyDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  bool _testing = false;
  String? _savedMasked;
  late final Future<void> _load = _loadSavedKey();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadSavedKey() async {
    final store = await AisKeyStore.load();
    final key = await store.readKey();
    if (!mounted) return;
    setState(() => _savedMasked = key == null ? null : _mask(key));
  }

  static String _mask(String key) {
    if (key.length <= 8) return '••••••••';
    return '${key.substring(0, 4)}••••${key.substring(key.length - 4)}';
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    setState(() => _saving = true);
    final store = await AisKeyStore.load();
    await store.saveKey(value);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop(true);
  }

  Future<void> _testConnection() async {
    final typed = _controller.text.trim();
    String? key = typed.isNotEmpty ? typed : null;
    if (key == null) {
      final store = await AisKeyStore.load();
      key = await store.readKey();
    }
    if (key == null || key.isEmpty) {
      _showSnack('Enter an API key first.');
      return;
    }
    setState(() => _testing = true);
    final error = await AisStreamClient.testKey(key);
    if (!mounted) return;
    setState(() => _testing = false);
    _showSnack(error ?? 'Connection works.');
  }

  Future<void> _clear() async {
    final store = await AisKeyStore.load();
    await store.clearKey();
    if (!mounted) return;
    setState(() => _savedMasked = null);
    _showSnack('API key removed.');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: FutureBuilder<void>(
          future: _load,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.directions_boat_rounded, color: luma.accent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'AISStream.io API key',
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => launchUrl(
                    Uri.parse('https://aisstream.io'),
                    mode: LaunchMode.externalApplication,
                  ),
                  mouseCursor: SystemMouseCursors.click,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Get a free key at aisstream.io — sign in, then copy '
                      'your API key from the dashboard.',
                      style: TextStyle(
                        color: luma.accent,
                        fontSize: 12,
                        height: 1.4,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_savedMasked != null) ...[
                Row(
                  children: [
                    Icon(Icons.key_rounded, size: 16, color: luma.accent),
                    const SizedBox(width: 8),
                    Text(_savedMasked!,
                        style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _controller,
                obscureText: _obscure,
                style: TextStyle(color: luma.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: _savedMasked != null
                      ? 'Enter a new key to replace it'
                      : 'Paste your API key',
                  hintStyle: TextStyle(color: luma.textMuted),
                  filled: true,
                  fillColor: luma.background,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: luma.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: luma.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: luma.accent),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      color: luma.textMuted,
                    ),
                    tooltip: _obscure ? 'Show key' : 'Hide key',
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Stored locally on this device only, encrypted at rest. Sent '
                'directly to aisstream.io when tracking — never to any luma '
                'server.',
                style: TextStyle(color: luma.textMuted, fontSize: 11, height: 1.4),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  LumaPrimaryButton(
                    label: 'Save',
                    icon: Icons.save_rounded,
                    loading: _saving,
                    onTap: _save,
                  ),
                  LumaGhostButton(
                    label: 'Test connection',
                    icon: Icons.wifi_tethering_rounded,
                    onTap: _testing ? null : _testConnection,
                  ),
                  if (_savedMasked != null)
                    LumaGhostButton(
                      label: 'Remove key',
                      icon: Icons.delete_outline_rounded,
                      onTap: _clear,
                    ),
                  LumaGhostButton(
                    label: 'Close',
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
