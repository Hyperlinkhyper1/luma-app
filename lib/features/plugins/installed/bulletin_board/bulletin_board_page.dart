import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'bulletin_board_repository.dart';
import 'bulletin_board_scope.dart';

class BulletinBoardPage extends StatefulWidget {
  const BulletinBoardPage({super.key});

  @override
  State<BulletinBoardPage> createState() => _BulletinBoardPageState();
}

class _BulletinBoardPageState extends State<BulletinBoardPage> {
  final TransformationController _transformController = TransformationController();

  void _addCard(BulletinBoardRepository repo, String type) async {
    String content = '';
    if (type == 'image') {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
      );
      if (result != null && result.files.single.path != null) {
        content = result.files.single.path!;
      } else {
        return;
      }
    } else if (type == 'checklist') {
      content = jsonEncode([
        {'text': 'Item 1', 'done': false},
        {'text': 'Item 2', 'done': false}
      ]);
    }

    // Default position near center of viewport, could be improved by using Matrix4 inversion
    await repo.add(
      type: type,
      title: type == 'note' ? 'New Note' : type == 'checklist' ? 'New Checklist' : null,
      content: content,
      posX: 500,
      posY: 500,
      width: type == 'idea' ? 250 : 300,
      height: type == 'idea' ? 120 : type == 'image' ? 300 : 250,
      color: 0xFFF1ECFB, // Light pastel default
    );
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = BulletinBoardScope.of(context);
    final luma = context.luma;

    return Stack(
      children: [
        // Grid background
        Positioned.fill(
          child: CustomPaint(
            painter: _GridPainter(luma.border),
          ),
        ),
        // Interactive board
        InteractiveViewer(
          transformationController: _transformController,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(5000),
          minScale: 0.1,
          maxScale: 3.0,
          child: SizedBox(
            width: 10000,
            height: 10000,
            child: StreamData<List<BoardItemRecord>>(
              stream: repo.watchAll(),
              builder: (context, items) {
                return Stack(
                  children: items.map((item) {
                    return Positioned(
                      left: item.posX,
                      top: item.posY,
                      width: item.width,
                      height: item.height,
                      child: _BoardCard(record: item),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ),
        // Floating Action Menu
        Positioned(
          bottom: 24,
          right: 24,
          child: _FloatingAddMenu(
            onAddNote: () => _addCard(repo, 'note'),
            onAddIdea: () => _addCard(repo, 'idea'),
            onAddChecklist: () => _addCard(repo, 'checklist'),
            onAddImage: () => _addCard(repo, 'image'),
          ),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 1.0;
    const spacing = 40.0;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BoardCard extends StatefulWidget {
  const _BoardCard({required this.record});
  final BoardItemRecord record;

  @override
  State<_BoardCard> createState() => _BoardCardState();
}

class _BoardCardState extends State<_BoardCard> {
  bool _hovering = false;
  Offset? _dragStartOffset;
  late BoardItemRecord _record;

  @override
  void initState() {
    super.initState();
    _record = widget.record;
  }

  @override
  void didUpdateWidget(_BoardCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record != widget.record) {
      _record = widget.record;
    }
  }

  void _updateRecord(BoardItemRecord newRecord) {
    setState(() => _record = newRecord);
    BulletinBoardScope.of(context).updateItem(newRecord);
  }

  @override
  Widget build(BuildContext context) {
    final repo = BulletinBoardScope.of(context);

    Widget content;
    switch (_record.type) {
      case 'note':
        content = _NoteContent(record: _record, onUpdate: _updateRecord);
        break;
      case 'idea':
        content = _IdeaContent(record: _record, onUpdate: _updateRecord);
        break;
      case 'checklist':
        content = _ChecklistContent(record: _record, onUpdate: _updateRecord);
        break;
      case 'image':
        content = _ImageContent(record: _record);
        break;
      default:
        content = const SizedBox();
    }

    final card = Container(
      decoration: BoxDecoration(
        color: Color(_record.color),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: content,
          ),
          if (_hovering)
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  LumaIconButton(
                    icon: _record.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    onPressed: () => _updateRecord(_record.copyWith(pinned: !_record.pinned)),
                  ),
                  LumaIconButton(
                    icon: Icons.delete_outline,
                    onPressed: () => repo.delete(_record.id),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onPanStart: _record.pinned
            ? null
            : (details) {
                _dragStartOffset = details.globalPosition - Offset(_record.posX, _record.posY);
              },
        onPanUpdate: _record.pinned
            ? null
            : (details) {
                if (_dragStartOffset != null) {
                  setState(() {
                    _record = _record.copyWith(
                      posX: details.globalPosition.dx - _dragStartOffset!.dx,
                      posY: details.globalPosition.dy - _dragStartOffset!.dy,
                    );
                  });
                }
              },
        onPanEnd: _record.pinned
            ? null
            : (details) {
                _dragStartOffset = null;
                repo.updateItem(_record);
              },
        child: card,
      ),
    );
  }
}

// Minimal LumaIconButton implementation for use here, as it might not be exported perfectly or we want local control
class LumaIconButton extends StatelessWidget {
  const LumaIconButton({super.key, required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      onPressed: onPressed,
      splashRadius: 20,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}

class _NoteContent extends StatelessWidget {
  const _NoteContent({required this.record, required this.onUpdate});
  final BoardItemRecord record;
  final ValueChanged<BoardItemRecord> onUpdate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          initialValue: record.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
          decoration: const InputDecoration(border: InputBorder.none, hintText: 'Title'),
          onChanged: (val) => onUpdate(record.copyWith(title: val)),
        ),
        Expanded(
          child: TextFormField(
            initialValue: record.content,
            maxLines: null,
            expands: true,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
            decoration: const InputDecoration(border: InputBorder.none, hintText: 'Note content...'),
            onChanged: (val) => onUpdate(record.copyWith(content: val)),
          ),
        ),
      ],
    );
  }
}

class _IdeaContent extends StatelessWidget {
  const _IdeaContent({required this.record, required this.onUpdate});
  final BoardItemRecord record;
  final ValueChanged<BoardItemRecord> onUpdate;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            initialValue: record.content,
            maxLines: null,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
            decoration: const InputDecoration(border: InputBorder.none, hintText: 'Quick idea...'),
            onChanged: (val) => onUpdate(record.copyWith(content: val)),
          ),
        ),
      ],
    );
  }
}

class _ChecklistContent extends StatelessWidget {
  const _ChecklistContent({required this.record, required this.onUpdate});
  final BoardItemRecord record;
  final ValueChanged<BoardItemRecord> onUpdate;

  @override
  Widget build(BuildContext context) {
    List<dynamic> items = [];
    try {
      items = jsonDecode(record.content);
    } catch (_) {}

    return Column(
      children: [
        TextFormField(
          initialValue: record.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
          decoration: const InputDecoration(border: InputBorder.none, hintText: 'Checklist'),
          onChanged: (val) => onUpdate(record.copyWith(title: val)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: items.length + 1,
            itemBuilder: (context, index) {
              if (index == items.length) {
                return TextButton(
                  onPressed: () {
                    items.add({'text': '', 'done': false});
                    onUpdate(record.copyWith(content: jsonEncode(items)));
                  },
                  child: const Text('+ Add Item'),
                );
              }
              final item = items[index];
              return Row(
                children: [
                  Checkbox(
                    value: item['done'],
                    onChanged: (val) {
                      item['done'] = val;
                      onUpdate(record.copyWith(content: jsonEncode(items)));
                    },
                  ),
                  Expanded(
                    child: TextFormField(
                      initialValue: item['text'],
                      style: TextStyle(
                        decoration: item['done'] ? TextDecoration.lineThrough : null,
                        color: Colors.black87,
                      ),
                      decoration: const InputDecoration(border: InputBorder.none),
                      onChanged: (val) {
                        item['text'] = val;
                        onUpdate(record.copyWith(content: jsonEncode(items)));
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ImageContent extends StatelessWidget {
  const _ImageContent({required this.record});
  final BoardItemRecord record;

  @override
  Widget build(BuildContext context) {
    if (record.content.isEmpty) return const Center(child: Text('No image'));
    return Center(
      child: Image.file(
        File(record.content),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Text('Image not found'),
      ),
    );
  }
}

class _FloatingAddMenu extends StatefulWidget {
  const _FloatingAddMenu({
    required this.onAddNote,
    required this.onAddIdea,
    required this.onAddChecklist,
    required this.onAddImage,
  });
  final VoidCallback onAddNote;
  final VoidCallback onAddIdea;
  final VoidCallback onAddChecklist;
  final VoidCallback onAddImage;

  @override
  State<_FloatingAddMenu> createState() => _FloatingAddMenuState();
}

class _FloatingAddMenuState extends State<_FloatingAddMenu> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_open) ...[
          _MenuItem(icon: Icons.note_add, label: 'Note', onTap: () { setState(() => _open = false); widget.onAddNote(); }),
          const SizedBox(height: 8),
          _MenuItem(icon: Icons.lightbulb, label: 'Idea', onTap: () { setState(() => _open = false); widget.onAddIdea(); }),
          const SizedBox(height: 8),
          _MenuItem(icon: Icons.checklist, label: 'Checklist', onTap: () { setState(() => _open = false); widget.onAddChecklist(); }),
          const SizedBox(height: 8),
          _MenuItem(icon: Icons.image, label: 'Image', onTap: () { setState(() => _open = false); widget.onAddImage(); }),
          const SizedBox(height: 16),
        ],
        FloatingActionButton(
          backgroundColor: luma.accent,
          foregroundColor: luma.onAccent,
          onPressed: () => setState(() => _open = !_open),
          child: Icon(_open ? Icons.close : Icons.add),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return FloatingActionButton.extended(
      backgroundColor: luma.surface,
      foregroundColor: luma.textPrimary,
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      heroTag: label,
    );
  }
}
