import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'map_maker_geometry.dart';
import 'map_maker_models.dart';
import 'map_maker_store.dart';
import 'transit_map_painter.dart';

class TransitMapEditorView extends StatefulWidget {
  const TransitMapEditorView({
    super.key,
    required this.save,
    required this.onBack,
  });

  final MapMakerSave save;
  final VoidCallback onBack;

  @override
  State<TransitMapEditorView> createState() => _TransitMapEditorViewState();
}

class _TransitMapEditorViewState extends State<TransitMapEditorView> {
  final TransformationController _controller = TransformationController();
  final FocusNode _focusNode = FocusNode();

  late final TransitMap _map;
  late final TextEditingController _titleController;

  int _revision = 0;
  MapMakerTool _tool = MapMakerTool.select;

  String? _selectedLineId;
  String? _selectedStationId;
  String? _selectedRiverId;
  String? _connectingFromStationId;

  final List<Offset> _draftRiver = [];
  Offset? _hover;

  bool _showGrid = true;
  bool _isSpacePressed = false;
  TransitStation? _draggingStation;
  bool _centeredOnce = false;

  @override
  void initState() {
    super.initState();
    _map = widget.save.transit;
    _titleController = TextEditingController(text: widget.save.title);
    if (_map.lines.isNotEmpty) {
      _selectedLineId = _map.lines.first.id;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _markDirty({bool persist = true}) {
    setState(() => _revision++);
    if (persist) {
      MapMakerStore.instance.put(widget.save);
    }
  }

  void _centerView(Size viewportSize) {
    Offset targetCenter;
    if (_map.stations.isNotEmpty) {
      var minX = double.infinity, maxX = -double.infinity;
      var minY = double.infinity, maxY = -double.infinity;
      for (final s in _map.stations) {
        if (s.x < minX) minX = s.x;
        if (s.x > maxX) maxX = s.x;
        if (s.y < minY) minY = s.y;
        if (s.y > maxY) maxY = s.y;
      }
      targetCenter = Offset((minX + maxX) / 2, (minY + maxY) / 2);
    } else {
      targetCenter = Offset(
        kTransitSheetSize.width / 2,
        kTransitSheetSize.height / 2,
      );
    }

    const scale = 1.0;
    _controller.value = Matrix4.identity()
      ..translateByDouble(viewportSize.width / 2, viewportSize.height / 2, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-targetCenter.dx, -targetCenter.dy, 0, 1);
  }

  // --- Map Editing Actions ---

  void _onPointerDown(PointerDownEvent event) {
    _focusNode.requestFocus();
    if (_isSpacePressed || _tool == MapMakerTool.pan) return;

    final pos = event.localPosition;

    switch (_tool) {
      case MapMakerTool.select:
        final hitSt = _map.hitStation(pos);
        if (hitSt != null) {
          setState(() {
            _selectedStationId = hitSt.id;
            _selectedRiverId = null;
            _draggingStation = hitSt;
          });
          return;
        }

        final hitRiv = _map.hitRiver(pos);
        if (hitRiv != null) {
          setState(() {
            _selectedRiverId = hitRiv.id;
            _selectedStationId = null;
          });
          return;
        }

        final hitLn = _map.hitLine(pos);
        if (hitLn != null) {
          setState(() {
            _selectedLineId = hitLn.id;
            _selectedStationId = null;
            _selectedRiverId = null;
          });
          return;
        }

        // Click on empty space deselects
        setState(() {
          _selectedStationId = null;
          _selectedRiverId = null;
        });

      case MapMakerTool.station:
        final snapped = snapToTransitGrid(pos);
        final existing = _map.hitStation(snapped, radius: 12);
        if (existing == null) {
          final newStation = TransitStation(
            id: 'st_${DateTime.now().microsecondsSinceEpoch}',
            name: 'Station ${_map.stations.length + 1}',
            x: snapped.dx,
            y: snapped.dy,
          );
          _map.addStation(newStation);

          if (_selectedLineId != null) {
            _map.appendStop(_selectedLineId!, newStation.id);
          }

          setState(() {
            _selectedStationId = newStation.id;
          });
          _markDirty();
        } else {
          setState(() => _selectedStationId = existing.id);
        }

      case MapMakerTool.connection:
        final hit = _map.hitStation(pos);
        if (hit != null) {
          if (_connectingFromStationId == null) {
            setState(() {
              _connectingFromStationId = hit.id;
              _selectedStationId = hit.id;
            });
          } else {
            final fromId = _connectingFromStationId!;
            final toId = hit.id;
            if (fromId != toId && _selectedLineId != null) {
              final line = _map.lineById(_selectedLineId!);
              if (line != null) {
                _connectStationsOnLine(line, fromId, toId);
                _markDirty();
              }
            }
            setState(() {
              _connectingFromStationId = toId;
              _selectedStationId = toId;
            });
          }
        } else {
          setState(() {
            _connectingFromStationId = null;
          });
        }

      case MapMakerTool.river:
        final snapped = snapToTransitGrid(pos, kTransitGrid / 2);
        if (_draftRiver.length >= 3 &&
            (_draftRiver.first - snapped).distance < 24) {
          _finishDraftRiver(closed: true);
        } else {
          setState(() {
            _draftRiver.add(snapped);
          });
          _markDirty(persist: false);
        }

      case MapMakerTool.delete:
        final hitSt = _map.hitStation(pos);
        if (hitSt != null) {
          _map.removeStation(hitSt.id);
          if (_selectedStationId == hitSt.id) _selectedStationId = null;
          _markDirty();
          return;
        }

        final hitRiv = _map.hitRiver(pos);
        if (hitRiv != null) {
          _map.removeRiver(hitRiv.id);
          if (_selectedRiverId == hitRiv.id) _selectedRiverId = null;
          _markDirty();
          return;
        }

      default:
        break;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final pos = event.localPosition;
    setState(() {
      _hover = pos;
    });

    if (_draggingStation != null && _tool == MapMakerTool.select) {
      final snapped = snapToTransitGrid(pos);
      if (_draggingStation!.position != snapped) {
        _draggingStation!.position = snapped;
        _markDirty(persist: false);
      }
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_draggingStation != null) {
      _draggingStation = null;
      _markDirty(persist: true);
    }
  }

  void _connectStationsOnLine(TransitLine line, String fromId, String toId) {
    if (line.stationIds.isEmpty) {
      line.stationIds.addAll([fromId, toId]);
    } else if (line.stationIds.last == fromId) {
      line.stationIds.add(toId);
    } else if (line.stationIds.first == toId) {
      line.stationIds.insert(0, fromId);
    } else if (line.stationIds.last == toId) {
      line.stationIds.add(fromId);
    } else if (line.stationIds.first == fromId) {
      line.stationIds.insert(0, toId);
    } else {
      line.stationIds.addAll([fromId, toId]);
    }
  }

  void _finishDraftRiver({bool closed = false}) {
    if (_draftRiver.length >= 2) {
      final river = TransitRiver(
        id: 'riv_${DateTime.now().microsecondsSinceEpoch}',
        points: List<Offset>.from(_draftRiver),
        closed: closed,
      );
      _map.addRiver(river);
      _selectedRiverId = river.id;
    }
    setState(() {
      _draftRiver.clear();
    });
    _markDirty();
  }

  Future<void> _addNewLineDialog() async {
    final luma = context.luma;
    final nameCtrl = TextEditingController(
      text: 'Line ${_map.lines.length + 1}',
    );

    int pickedColor = kTransitLinePalette[
        _map.lines.length % kTransitLinePalette.length];

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: luma.surface,
          title: Text('New Transit Line', style: TextStyle(color: luma.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: TextStyle(color: luma.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Line Name',
                  labelStyle: TextStyle(color: luma.textSecondary),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Line Color',
                style: TextStyle(
                  color: luma.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final colorVal in kTransitLinePalette)
                    GestureDetector(
                      onTap: () => setDlgState(() => pickedColor = colorVal),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(colorVal),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: pickedColor == colorVal
                                ? Colors.white
                                : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: pickedColor == colorVal
                              ? [
                                  BoxShadow(
                                    color: Color(colorVal).withValues(alpha: 0.6),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: luma.accent),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Create', style: TextStyle(color: luma.onAccent)),
            ),
          ],
        ),
      ),
    );

    if (created == true && nameCtrl.text.trim().isNotEmpty) {
      final newLine = TransitLine(
        id: 'line_${DateTime.now().microsecondsSinceEpoch}',
        name: nameCtrl.text.trim(),
        color: pickedColor,
      );
      _map.addLine(newLine);
      setState(() {
        _selectedLineId = newLine.id;
      });
      _markDirty();
    }
  }

  Future<void> _editLineDialog(TransitLine line) async {
    final luma = context.luma;
    final nameCtrl = TextEditingController(text: line.name);
    int pickedColor = line.color;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: luma.surface,
          title: Text('Edit Line', style: TextStyle(color: luma.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: luma.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Line Name',
                  labelStyle: TextStyle(color: luma.textSecondary),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Line Color',
                style: TextStyle(
                  color: luma.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final colorVal in kTransitLinePalette)
                    GestureDetector(
                      onTap: () => setDlgState(() => pickedColor = colorVal),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(colorVal),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: pickedColor == colorVal
                                ? Colors.white
                                : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: pickedColor == colorVal
                              ? [
                                  BoxShadow(
                                    color: Color(colorVal).withValues(alpha: 0.6),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            if (_map.lines.length > 1)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('delete'),
                child: Text('Delete Line', style: TextStyle(color: luma.danger)),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: luma.accent),
              onPressed: () => Navigator.of(ctx).pop('save'),
              child: Text('Save', style: TextStyle(color: luma.onAccent)),
            ),
          ],
        ),
      ),
    );

    if (result == 'save' && nameCtrl.text.trim().isNotEmpty) {
      line.name = nameCtrl.text.trim();
      line.color = pickedColor;
      _markDirty();
    } else if (result == 'delete') {
      _map.removeLine(line.id);
      if (_selectedLineId == line.id) {
        _selectedLineId = _map.lines.firstOrNull?.id;
      }
      _markDirty();
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final isPhone = context.isPhoneWidth;
    final selectedStation = _selectedStationId != null
        ? _map.stationById(_selectedStationId!)
        : null;
    final selectedRiver = _selectedRiverId != null
        ? _map.rivers.firstWhere(
            (r) => r.id == _selectedRiverId,
            orElse: () => _map.rivers.first,
          )
        : null;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.space) {
            setState(() => _isSpacePressed = true);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            setState(() {
              _selectedStationId = null;
              _selectedRiverId = null;
              _connectingFromStationId = null;
              _draftRiver.clear();
            });
            _markDirty(persist: false);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.delete ||
              event.logicalKey == LogicalKeyboardKey.backspace) {
            if (_selectedStationId != null) {
              _map.removeStation(_selectedStationId!);
              _selectedStationId = null;
              _markDirty();
              return KeyEventResult.handled;
            }
            if (_selectedRiverId != null) {
              _map.removeRiver(_selectedRiverId!);
              _selectedRiverId = null;
              _markDirty();
              return KeyEventResult.handled;
            }
          }
        } else if (event is KeyUpEvent) {
          if (event.logicalKey == LogicalKeyboardKey.space) {
            setState(() => _isSpacePressed = false);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: luma.background,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: luma.surface,
              border: Border(bottom: BorderSide(color: luma.border)),
            ),
            child: Row(
              children: [
                LumaGhostButton(
                  icon: Icons.arrow_back_rounded,
                  label: 'Saves',
                  onTap: () {
                    MapMakerStore.instance.put(widget.save);
                    widget.onBack();
                  },
                ),
                const SizedBox(width: 14),
                // Editable Map Title
                Expanded(
                  child: Row(
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: TextField(
                          controller: _titleController,
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (val) {
                            widget.save.title =
                                val.trim().isEmpty ? 'Untitled Map' : val.trim();
                            _markDirty();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.check_circle_rounded,
                        color: luma.success.withValues(alpha: 0.7),
                        size: 15,
                      ),
                    ],
                  ),
                ),
                // Controls
                IconButton(
                  tooltip: _showGrid ? 'Hide Grid' : 'Show Grid',
                  icon: Icon(
                    _showGrid ? Icons.grid_on_rounded : Icons.grid_off_rounded,
                    color: _showGrid ? luma.accent : luma.textMuted,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _showGrid = !_showGrid),
                ),
                LayoutBuilder(
                  builder: (ctx, constraints) => IconButton(
                    tooltip: 'Center View',
                    icon: Icon(
                      Icons.filter_center_focus_rounded,
                      color: luma.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => _centerView(MediaQuery.sizeOf(context)),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: Stack(
          children: [
            // Interactive Map Canvas
            LayoutBuilder(
              builder: (context, constraints) {
                if (!_centeredOnce) {
                  _centeredOnce = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _centerView(Size(constraints.maxWidth, constraints.maxHeight));
                  });
                }

                return MouseRegion(
                  cursor: _tool == MapMakerTool.pan || _isSpacePressed
                      ? SystemMouseCursors.grab
                      : (_tool == MapMakerTool.delete
                          ? SystemMouseCursors.forbidden
                          : SystemMouseCursors.precise),
                  child: InteractiveViewer(
                    transformationController: _controller,
                    panEnabled: _tool == MapMakerTool.pan || _isSpacePressed,
                    scaleEnabled: true,
                    minScale: 0.2,
                    maxScale: 3.5,
                    constrained: false,
                    boundaryMargin: const EdgeInsets.all(600),
                    child: SizedBox(
                      width: kTransitSheetSize.width,
                      height: kTransitSheetSize.height,
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: _onPointerDown,
                        onPointerMove: _onPointerMove,
                        onPointerUp: _onPointerUp,
                        child: CustomPaint(
                          painter: TransitMapPainter(
                            map: _map,
                            revision: _revision,
                            showGrid: _showGrid,
                            selectedStationId: _selectedStationId,
                            selectedLineId: _selectedLineId,
                            selectedRiverId: _selectedRiverId,
                            connectingFromStationId: _connectingFromStationId,
                            draftRiver: _draftRiver,
                            hover: _hover,
                            scale: _controller.value.getMaxScaleOnAxis(),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Top Toolbar: Tool Selection
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: luma.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: luma.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ToolPill(
                          icon: Icons.near_me_rounded,
                          label: 'Select / Move',
                          selected: _tool == MapMakerTool.select,
                          onTap: () => setState(() {
                            _tool = MapMakerTool.select;
                            _connectingFromStationId = null;
                            _draftRiver.clear();
                          }),
                        ),
                        const SizedBox(width: 4),
                        _ToolPill(
                          icon: Icons.pan_tool_rounded,
                          label: 'Pan',
                          selected: _tool == MapMakerTool.pan,
                          onTap: () => setState(() {
                            _tool = MapMakerTool.pan;
                            _connectingFromStationId = null;
                            _draftRiver.clear();
                          }),
                        ),
                        const SizedBox(width: 4),
                        _ToolPill(
                          icon: Icons.add_circle_outline_rounded,
                          label: 'Add Station',
                          selected: _tool == MapMakerTool.station,
                          onTap: () => setState(() {
                            _tool = MapMakerTool.station;
                            _connectingFromStationId = null;
                            _draftRiver.clear();
                          }),
                        ),
                        const SizedBox(width: 4),
                        _ToolPill(
                          icon: Icons.timeline_rounded,
                          label: 'Connect Line',
                          selected: _tool == MapMakerTool.connection,
                          onTap: () => setState(() {
                            _tool = MapMakerTool.connection;
                            _connectingFromStationId = null;
                            _draftRiver.clear();
                          }),
                        ),
                        const SizedBox(width: 4),
                        _ToolPill(
                          icon: Icons.water_rounded,
                          label: 'Draw River',
                          selected: _tool == MapMakerTool.river,
                          onTap: () => setState(() {
                            _tool = MapMakerTool.river;
                            _connectingFromStationId = null;
                          }),
                        ),
                        const SizedBox(width: 4),
                        _ToolPill(
                          icon: Icons.delete_outline_rounded,
                          label: 'Delete',
                          selected: _tool == MapMakerTool.delete,
                          onTap: () => setState(() {
                            _tool = MapMakerTool.delete;
                            _connectingFromStationId = null;
                            _draftRiver.clear();
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // River Drawing In-Progress Banner
            if (_tool == MapMakerTool.river && _draftRiver.isNotEmpty)
              Positioned(
                top: 76,
                left: 16,
                right: 16,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0077C0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_draftRiver.length} points • Click next point or close loop',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => _finishDraftRiver(closed: false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Finish River',
                              style: TextStyle(
                                color: Color(0xFF0077C0),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => setState(() => _draftRiver.clear()),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Connection Mode Banner
            if (_tool == MapMakerTool.connection &&
                _connectingFromStationId != null)
              Positioned(
                top: 76,
                left: 16,
                right: 16,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: luma.accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Connecting from ${_map.stationById(_connectingFromStationId!)?.name ?? 'Station'} • Click next stop',
                          style: TextStyle(
                            color: luma.onAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => setState(
                            () => _connectingFromStationId = null,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: luma.onAccent,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Bottom Line Selector Strip
            Positioned(
              bottom: 16,
              left: 16,
              right: isPhone ? 16 : 320,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: luma.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: luma.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Lines:',
                        style: TextStyle(
                          color: luma.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      for (final line in _map.lines) ...[
                        _LineChip(
                          line: line,
                          isSelected: line.id == _selectedLineId,
                          onSelect: () => setState(() => _selectedLineId = line.id),
                          onEdit: () => _editLineDialog(line),
                        ),
                        const SizedBox(width: 6),
                      ],
                      InkWell(
                        onTap: _addNewLineDialog,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: luma.accentSubtle,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: luma.accent.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded, size: 14, color: luma.accent),
                              const SizedBox(width: 4),
                              Text(
                                'New Line',
                                style: TextStyle(
                                  color: luma.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Station Inspector Card (when station is selected)
            if (selectedStation != null)
              Positioned(
                right: 16,
                bottom: 16,
                width: 280,
                child: _StationInspectorCard(
                  station: selectedStation,
                  map: _map,
                  activeLineId: _selectedLineId,
                  onChanged: () => _markDirty(),
                  onDelete: () {
                    _map.removeStation(selectedStation.id);
                    setState(() => _selectedStationId = null);
                    _markDirty();
                  },
                  onClose: () => setState(() => _selectedStationId = null),
                ),
              ),

            // River Inspector Card (when river is selected)
            if (selectedRiver != null && selectedStation == null)
              Positioned(
                right: 16,
                bottom: 16,
                width: 260,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: luma.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: luma.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Waterway',
                            style: TextStyle(
                              color: luma.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => setState(() => _selectedRiverId = null),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Checkbox(
                            value: selectedRiver.closed,
                            onChanged: (val) {
                              selectedRiver.closed = val ?? false;
                              _markDirty();
                            },
                          ),
                          Text(
                            'Closed shape (Lake / Sea)',
                            style: TextStyle(
                              color: luma.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: luma.danger,
                          minimumSize: const Size.fromHeight(32),
                        ),
                        icon: const Icon(Icons.delete_rounded, size: 14),
                        label: const Text('Delete Waterway', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          _map.removeRiver(selectedRiver.id);
                          setState(() => _selectedRiverId = null);
                          _markDirty();
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToolPill extends StatelessWidget {
  const _ToolPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? luma.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? luma.onAccent : luma.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? luma.onAccent : luma.textPrimary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineChip extends StatelessWidget {
  const _LineChip({
    required this.line,
    required this.isSelected,
    required this.onSelect,
    required this.onEdit,
  });

  final TransitLine line;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final color = Color(line.color);

    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.18) : luma.surfaceHover,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : luma.border,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              line.name,
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  Icons.settings_rounded,
                  size: 12,
                  color: luma.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StationInspectorCard extends StatelessWidget {
  const _StationInspectorCard({
    required this.station,
    required this.map,
    required this.activeLineId,
    required this.onChanged,
    required this.onDelete,
    required this.onClose,
  });

  final TransitStation station;
  final TransitMap map;
  final String? activeLineId;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: luma.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Station Details',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: station.name,
            style: TextStyle(color: luma.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Station Name',
              isDense: true,
              labelStyle: TextStyle(color: luma.textSecondary, fontSize: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (val) {
              station.name = val;
              onChanged();
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Station Type',
            style: TextStyle(color: luma.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _TypeChip(
                  label: 'Stop',
                  selected: station.kind == TransitStationKind.stop,
                  onTap: () {
                    station.kind = TransitStationKind.stop;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _TypeChip(
                  label: 'Transfer',
                  selected: station.kind == TransitStationKind.transfer,
                  onTap: () {
                    station.kind = TransitStationKind.transfer;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _TypeChip(
                  label: 'Airport',
                  selected: station.kind == TransitStationKind.airport,
                  onTap: () {
                    station.kind = TransitStationKind.airport;
                    onChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: luma.danger,
                    side: BorderSide(color: luma.danger.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: onDelete,
                  child: const Text('Delete Stop', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? luma.accent : luma.surfaceHover,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? luma.onAccent : luma.textPrimary,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
