import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../storage/storage_guard.dart';
import '../../../../theme/luma_theme.dart';
import 'chart_viewer.dart';
import 'csv_import_export.dart';
import 'data_management_repository.dart';
import 'data_management_scope.dart';

/// Preset swatches offered when creating or editing a tag.
const kTagColorChoices = [
  Color(0xFFB49DF5), // lavender
  Color(0xFF57D9A3), // mint
  Color(0xFFFF6B81), // coral
  Color(0xFFFFD166), // gold
  Color(0xFF6ECBF5), // sky
  Color(0xFFBC96E6), // purple
  Color(0xFF85E0C3), // seafoam
  Color(0xFFFF9E6D), // peach
  Color(0xFFE58FB1), // rose
  Color(0xFF9BD770), // leaf
];

/// The Data Management plugin: create datasets, edit tables, tag rows, and
/// visualize with bar / line / area / pie / donut charts — grouped by any
/// column or by tag, with aggregation and time-range filters. CSV in/out.
class DataManagementPage extends StatefulWidget {
  const DataManagementPage({super.key});

  @override
  State<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends State<DataManagementPage> {
  int? _activeDatasetId;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _activeDatasetId == null
          ? _DatasetListView(
              key: const ValueKey('list'),
              onOpen: (id) => setState(() => _activeDatasetId = id),
            )
          : _DatasetEditorView(
              key: ValueKey('editor-$_activeDatasetId'),
              datasetId: _activeDatasetId!,
              onClose: () => setState(() => _activeDatasetId = null),
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  DATASET LIST
// ═══════════════════════════════════════════════════════════════════════════

class _DatasetListView extends StatefulWidget {
  const _DatasetListView({super.key, required this.onOpen});
  final ValueChanged<int> onOpen;

  @override
  State<_DatasetListView> createState() => _DatasetListViewState();
}

class _DatasetListViewState extends State<_DatasetListView> {
  final _nameController = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create(DataManagementRepository repo) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _creating = true);
    final int id;
    try {
      id = await repo.createDataset(name);
    } on StorageLimitExceededException catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
      return;
    }
    _nameController.clear();
    if (mounted) {
      setState(() => _creating = false);
      widget.onOpen(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repo = DataManagementScope.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header + create
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Data Management',
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Create tables, tag entries, and build charts from your own datasets.',
                          style: TextStyle(color: luma.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Create new card
              LumaCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        style: TextStyle(color: luma.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'New dataset name...',
                          hintStyle: TextStyle(color: luma.textMuted),
                          filled: true,
                          fillColor: luma.background,
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
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _create(repo),
                      ),
                    ),
                    const SizedBox(width: 12),
                    LumaPrimaryButton(
                      label: 'Create',
                      icon: Icons.add,
                      loading: _creating,
                      onTap: () => _create(repo),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Dataset grid
              StreamData<List<DatasetRecord>>(
                stream: repo.watchDatasets(),
                builder: (context, datasets) {
                  if (datasets.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: LumaEmptyState(
                        icon: Icons.table_chart_outlined,
                        title: 'No datasets yet',
                        subtitle:
                            'Create a dataset above, or import one from CSV.',
                      ),
                    );
                  }
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final ds in datasets)
                        _DatasetCard(
                          dataset: ds,
                          onOpen: () => widget.onOpen(ds.id),
                          onDelete: () => _confirmDelete(context, repo, ds),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    DataManagementRepository repo,
    DatasetRecord ds,
  ) {
    final luma = context.luma;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: luma.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete "${ds.name}"?',
          style: TextStyle(color: luma.textPrimary),
        ),
        content: Text(
          'This will permanently delete the dataset and all its rows.',
          style: TextStyle(color: luma.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: luma.textMuted)),
          ),
          TextButton(
            onPressed: () {
              repo.deleteDataset(ds.id);
              Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: luma.danger)),
          ),
        ],
      ),
    );
  }
}

// ─── Dataset Card ────────────────────────────────────────────────────────────

class _DatasetCard extends StatefulWidget {
  const _DatasetCard({
    required this.dataset,
    required this.onOpen,
    required this.onDelete,
  });

  final DatasetRecord dataset;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  State<_DatasetCard> createState() => _DatasetCardState();
}

class _DatasetCardState extends State<_DatasetCard> {
  bool _hover = false;

  static const _cardColors = [
    Color(0xFF7C5AD9),
    Color(0xFF12A372),
    Color(0xFFE5484D),
    Color(0xFF2563EB),
    Color(0xFFD97706),
    Color(0xFF9333EA),
  ];

  Color get _color => _cardColors[widget.dataset.id % _cardColors.length];

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final tagCount = widget.dataset.tags.length;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 220,
          height: 140,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: luma.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hover ? _color.withValues(alpha: 0.5) : luma.border,
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: _color.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.table_chart, color: _color, size: 20),
                  ),
                  const Spacer(),
                  if (_hover)
                    GestureDetector(
                      onTap: widget.onDelete,
                      child: Icon(
                        Icons.delete_outline,
                        color: luma.danger,
                        size: 18,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                widget.dataset.name,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.dataset.columns.length} columns'
                '${tagCount > 0 ? '  ·  $tagCount tags' : ''}',
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  DATASET EDITOR
// ═══════════════════════════════════════════════════════════════════════════

class _DatasetEditorView extends StatefulWidget {
  const _DatasetEditorView({
    super.key,
    required this.datasetId,
    required this.onClose,
  });
  final int datasetId;
  final VoidCallback onClose;

  @override
  State<_DatasetEditorView> createState() => _DatasetEditorViewState();
}

class _DatasetEditorViewState extends State<_DatasetEditorView> {
  int _tab = 0; // 0 = table, 1 = charts
  final _nameController = TextEditingController();
  DatasetRecord? _dataset;
  bool _loadStarted = false;

  // Reading the scope needs an inherited-widget lookup, which isn't allowed
  // from initState — kicking the first load off here is what previously left
  // the editor stuck on a spinner.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadStarted) {
      _loadStarted = true;
      _loadDataset();
    }
  }

  @override
  void didUpdateWidget(_DatasetEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.datasetId != widget.datasetId) _loadDataset();
  }

  Future<void> _loadDataset() async {
    final repo = DataManagementScope.of(context);
    final ds = await repo.getDataset(widget.datasetId);
    if (mounted && ds != null) {
      setState(() {
        _dataset = ds;
        if (_nameController.text != ds.name) _nameController.text = ds.name;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _rename(DataManagementRepository repo) async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _dataset == null) return;
    await repo.renameDataset(_dataset!.id, name);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repo = DataManagementScope.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  GestureDetector(
                    onTap: widget.onClose,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_back_rounded,
                            color: luma.textMuted,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Back',
                            style: TextStyle(
                              color: luma.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => _rename(repo),
                      onEditingComplete: () => _rename(repo),
                    ),
                  ),
                  LumaGhostButton(
                    label: 'Tags',
                    icon: Icons.sell_outlined,
                    onTap: _dataset == null
                        ? null
                        : () => showTagManager(
                            context,
                            repo,
                            _dataset!,
                            _loadDataset,
                          ),
                  ),
                  const SizedBox(width: 8),
                  LumaGhostButton(
                    label: 'Import CSV',
                    icon: Icons.upload_file_rounded,
                    onTap: () => _importCsv(context, repo),
                  ),
                  const SizedBox(width: 8),
                  StreamData<List<DataRowRecord>>(
                    stream: repo.watchRows(widget.datasetId),
                    builder: (context, rows) {
                      return LumaGhostButton(
                        label: 'Export CSV',
                        icon: Icons.download_rounded,
                        onTap: _dataset == null
                            ? null
                            : () => CsvHelper.exportCsv(_dataset!, rows),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Tabs
              LumaSegmentedTabs(
                tabs: const ['Table', 'Charts'],
                selectedIndex: _tab,
                onSelect: (i) => setState(() => _tab = i),
              ),
              const SizedBox(height: 16),
              // Content
              if (_dataset == null)
                const Center(child: CircularProgressIndicator(strokeWidth: 2))
              else
                StreamData<List<DataRowRecord>>(
                  stream: repo.watchRows(widget.datasetId),
                  builder: (context, rows) {
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _tab == 0
                          ? _TableEditor(
                              key: const ValueKey('table'),
                              dataset: _dataset!,
                              rows: rows,
                              onDatasetChanged: _loadDataset,
                            )
                          : _ChartTab(
                              key: const ValueKey('charts'),
                              dataset: _dataset!,
                              rows: rows,
                            ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _importCsv(
    BuildContext context,
    DataManagementRepository repo,
  ) async {
    final result = await CsvHelper.importCsv();
    if (result == null) return;
    final (columns, rows) = result;
    await repo.clearRows(widget.datasetId);
    await repo.updateColumns(widget.datasetId, columns);
    await repo.importRows(widget.datasetId, rows);
    if (mounted) _loadDataset();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAG MANAGER
// ═══════════════════════════════════════════════════════════════════════════

Future<void> showTagManager(
  BuildContext context,
  DataManagementRepository repo,
  DatasetRecord dataset,
  VoidCallback onChanged,
) async {
  final luma = context.luma;
  var tags = List<DataTagDef>.from(dataset.tags);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        backgroundColor: luma.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Manage Tags', style: TextStyle(color: luma.textPrimary)),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tags can be attached to any row and used to group charts — '
                'e.g. tag income rows by source and see what earns the most.',
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              if (tags.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No tags yet.',
                    style: TextStyle(color: luma.textMuted, fontSize: 13),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final tag in tags)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Color(tag.colorValue),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    tag.name,
                                    style: TextStyle(
                                      color: luma.textPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: luma.textMuted,
                                  ),
                                  onPressed: () async {
                                    final edited = await _editTagDialog(
                                      context,
                                      luma,
                                      tag,
                                    );
                                    if (edited == null) return;
                                    await repo.renameTag(
                                      dataset.id,
                                      tag.name,
                                      edited,
                                    );
                                    final refreshed = await repo.getDataset(
                                      dataset.id,
                                    );
                                    setDialogState(
                                      () => tags = List.from(
                                        refreshed?.tags ?? tags,
                                      ),
                                    );
                                    onChanged();
                                  },
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    size: 16,
                                    color: luma.danger,
                                  ),
                                  onPressed: () async {
                                    await repo.deleteTag(dataset.id, tag.name);
                                    final refreshed = await repo.getDataset(
                                      dataset.id,
                                    );
                                    setDialogState(
                                      () => tags = List.from(
                                        refreshed?.tags ?? tags,
                                      ),
                                    );
                                    onChanged();
                                  },
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              LumaGhostButton(
                label: 'New tag',
                icon: Icons.add,
                onTap: () async {
                  final created = await _editTagDialog(context, luma, null);
                  if (created == null) return;
                  if (tags.any((t) => t.name == created.name)) return;
                  final next = [...tags, created];
                  await repo.updateTags(dataset.id, next);
                  setDialogState(() => tags = next);
                  onChanged();
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Done', style: TextStyle(color: luma.accent)),
          ),
        ],
      ),
    ),
  );
}

/// Shared create/edit dialog for a single tag. Returns null when cancelled.
Future<DataTagDef?> _editTagDialog(
  BuildContext context,
  LumaPalette luma,
  DataTagDef? existing,
) async {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  var color = existing?.colorValue ?? kTagColorChoices.first.toARGB32();

  final result = await showDialog<DataTagDef>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        backgroundColor: luma.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          existing == null ? 'New Tag' : 'Edit Tag',
          style: TextStyle(color: luma.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: TextStyle(color: luma.textPrimary),
              decoration: InputDecoration(
                hintText: 'Tag name (e.g. Salary, Side gig)',
                hintStyle: TextStyle(color: luma.textMuted),
                filled: true,
                fillColor: luma.background,
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Color',
              style: TextStyle(color: luma.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in kTagColorChoices)
                  GestureDetector(
                    onTap: () => setDialogState(() => color = c.toARGB32()),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: color == c.toARGB32()
                              ? luma.textPrimary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: luma.textMuted)),
          ),
          TextButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(
                dialogContext,
                DataTagDef(name: name, colorValue: color),
              );
            },
            child: Text('Save', style: TextStyle(color: luma.accent)),
          ),
        ],
      ),
    ),
  );
  nameCtrl.dispose();
  return result;
}

// ─── Table Editor ────────────────────────────────────────────────────────────

class _TableEditor extends StatefulWidget {
  const _TableEditor({
    super.key,
    required this.dataset,
    required this.rows,
    required this.onDatasetChanged,
  });

  final DatasetRecord dataset;
  final List<DataRowRecord> rows;
  final VoidCallback onDatasetChanged;

  @override
  State<_TableEditor> createState() => _TableEditorState();
}

class _TableEditorState extends State<_TableEditor> {
  String _search = '';
  final Set<String> _tagFilter = {};
  int? _sortColumn; // null = manual order
  bool _sortAsc = true;

  List<DataRowRecord> get _visibleRows {
    var rows = widget.rows;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      rows = [
        for (final r in rows)
          if (r.values.values.any((v) => v.toLowerCase().contains(q)) ||
              r.tags.any((t) => t.toLowerCase().contains(q)))
            r,
      ];
    }
    if (_tagFilter.isNotEmpty) {
      rows = [
        for (final r in rows)
          if (r.tags.any(_tagFilter.contains)) r,
      ];
    }
    final sortCol = _sortColumn;
    if (sortCol != null && sortCol < widget.dataset.columns.length) {
      final type = widget.dataset.columns[sortCol].type;
      final sorted = List<DataRowRecord>.from(rows);
      sorted.sort((a, b) {
        final av = a.valueAt(sortCol);
        final bv = b.valueAt(sortCol);
        int cmp;
        if (type == 'number') {
          cmp =
              (double.tryParse(av.replaceAll(',', '.')) ??
                      double.negativeInfinity)
                  .compareTo(
                    double.tryParse(bv.replaceAll(',', '.')) ??
                        double.negativeInfinity,
                  );
        } else if (type == 'date') {
          cmp = (parseFlexibleDate(av) ?? DateTime(1900)).compareTo(
            parseFlexibleDate(bv) ?? DateTime(1900),
          );
        } else {
          cmp = av.toLowerCase().compareTo(bv.toLowerCase());
        }
        return _sortAsc ? cmp : -cmp;
      });
      rows = sorted;
    }
    return rows;
  }

  void _tapHeader(int index) {
    setState(() {
      if (_sortColumn != index) {
        _sortColumn = index;
        _sortAsc = true;
      } else if (_sortAsc) {
        _sortAsc = false;
      } else {
        _sortColumn = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repo = DataManagementScope.of(context);
    final rows = _visibleRows;

    // Stats for numeric columns, computed over the filtered view so they
    // respond to search / tag filters.
    final numericCols = [
      for (var i = 0; i < widget.dataset.columns.length; i++)
        if (widget.dataset.columns[i].type == 'number') i,
    ];

    final stats = <Widget>[];
    for (final colIdx in numericCols.take(4)) {
      final values = rows
          .map(
            (r) => double.tryParse(r.valueAt(colIdx).replaceAll(',', '.')) ?? 0,
          )
          .toList();
      if (values.isEmpty) continue;
      final sum = values.fold<double>(0, (a, b) => a + b);
      final avg = sum / values.length;
      final maxVal = values.reduce((a, b) => a > b ? a : b);
      stats.add(
        _StatCard(
          label: widget.dataset.columns[colIdx].name,
          value: sum.toStringAsFixed(1),
          sub:
              'avg ${avg.toStringAsFixed(1)}  ·  max ${maxVal.toStringAsFixed(1)}',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stats.isNotEmpty) ...[
          Wrap(spacing: 12, runSpacing: 12, children: stats),
          const SizedBox(height: 20),
        ],
        // Toolbar
        Row(
          children: [
            LumaGhostButton(
              label: 'Add Column',
              icon: Icons.view_column_outlined,
              onTap: () => _addColumn(context, repo),
            ),
            const SizedBox(width: 8),
            LumaPrimaryButton(
              label: 'Add Row',
              icon: Icons.add,
              onTap: () => _addRow(repo),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                style: TextStyle(color: luma.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search rows...',
                  hintStyle: TextStyle(color: luma.textMuted, fontSize: 13),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: luma.textMuted,
                  ),
                  filled: true,
                  fillColor: luma.background,
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
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _search = v.trim()),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _search.isEmpty && _tagFilter.isEmpty
                  ? '${widget.rows.length} rows'
                  : '${rows.length} of ${widget.rows.length} rows',
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            ),
          ],
        ),
        // Tag filter chips
        if (widget.dataset.tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in widget.dataset.tags)
                _TagChip(
                  tag: tag,
                  selected: _tagFilter.contains(tag.name),
                  onTap: () => setState(() {
                    _tagFilter.contains(tag.name)
                        ? _tagFilter.remove(tag.name)
                        : _tagFilter.add(tag.name);
                  }),
                ),
              if (_tagFilter.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _tagFilter.clear()),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'Clear filter',
                      style: TextStyle(color: luma.accent, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        // Data table
        if (widget.dataset.columns.isEmpty)
          LumaEmptyState(
            icon: Icons.view_column_outlined,
            title: 'No columns yet',
            subtitle: 'Add a column to start building your table.',
            action: LumaGhostButton(
              label: 'Add Column',
              icon: Icons.view_column_outlined,
              onTap: () => _addColumn(context, repo),
            ),
          )
        else
          LumaCard(
            padding: const EdgeInsets.all(0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      headingRowColor: WidgetStatePropertyAll(luma.surfaceHover),
                      dataRowMinHeight: 44,
                      dataRowMaxHeight: 44,
                      horizontalMargin: 16,
                      columnSpacing: 24,
                      columns: [
                        for (var i = 0; i < widget.dataset.columns.length; i++)
                          DataColumn(
                            columnWidth: const FlexColumnWidth(),
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () => _tapHeader(i),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        widget.dataset.columns[i].name,
                                        style: TextStyle(
                                          color: luma.textPrimary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (_sortColumn == i) ...[
                                        const SizedBox(width: 2),
                                        Icon(
                                          _sortAsc
                                              ? Icons.arrow_upward_rounded
                                              : Icons.arrow_downward_rounded,
                                          size: 12,
                                          color: luma.accent,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => _editColumn(context, repo, i),
                                  child: Icon(
                                    Icons.edit,
                                    size: 14,
                                    color: luma.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        DataColumn(
                          columnWidth: const FlexColumnWidth(),
                          label: Text(
                            'Tags',
                            style: TextStyle(
                              color: luma.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        DataColumn(label: SizedBox(), columnWidth: FixedColumnWidth(60)),
                      ],
                      rows: [
                        for (final row in rows)
                          DataRow(
                            cells: [
                              for (
                                var i = 0;
                                i < widget.dataset.columns.length;
                                i++
                              )
                                DataCell(
                                  _EditableCell(
                                    value: row.valueAt(i),
                                    type: widget.dataset.columns[i].type,
                                    onChanged: (val) {
                                      final newValues = Map<String, String>.from(
                                        row.values,
                                      );
                                      newValues[i.toString()] = val;
                                      repo.updateRow(row.id, newValues);
                                    },
                                  ),
                                ),
                              DataCell(
                                _RowTagsCell(
                                  dataset: widget.dataset,
                                  row: row,
                                  repo: repo,
                                  onManageTags: () => showTagManager(
                                    context,
                                    repo,
                                    widget.dataset,
                                    widget.onDatasetChanged,
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Tooltip(
                                      message: 'Duplicate row',
                                      child: GestureDetector(
                                        onTap: () => repo.duplicateRow(row),
                                        child: Icon(
                                          Icons.copy_rounded,
                                          size: 16,
                                          color: luma.textMuted,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    GestureDetector(
                                      onTap: () => repo.deleteRow(row.id),
                                      child: Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: luma.danger.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _addColumn(
    BuildContext context,
    DataManagementRepository repo,
  ) async {
    final result = await _columnDialog(context, null);
    if (result == null) return;
    final newCols = List<DataColumnDef>.from(widget.dataset.columns)
      ..add(result);
    await repo.updateColumns(widget.dataset.id, newCols);
    widget.onDatasetChanged();
  }

  Future<void> _editColumn(
    BuildContext context,
    DataManagementRepository repo,
    int index,
  ) async {
    final col = widget.dataset.columns[index];
    final result = await _columnDialog(context, col);
    if (result == null) return;

    if (result == _kDeleteColumn) {
      final newCols = List<DataColumnDef>.from(widget.dataset.columns)
        ..removeAt(index);
      // Also remove values for that column from all rows
      final rows = await repo.getRows(widget.dataset.id);
      for (final row in rows) {
        final newValues = Map<String, String>.from(row.values);
        newValues.remove(index.toString());
        // Renumber higher indices
        final remapped = <String, String>{};
        for (final entry in newValues.entries) {
          final oldIdx = int.tryParse(entry.key) ?? 0;
          remapped[(oldIdx > index ? oldIdx - 1 : oldIdx).toString()] =
              entry.value;
        }
        await repo.updateRow(row.id, remapped);
      }
      await repo.updateColumns(widget.dataset.id, newCols);
    } else {
      final newCols = List<DataColumnDef>.from(widget.dataset.columns);
      newCols[index] = result;
      await repo.updateColumns(widget.dataset.id, newCols);
    }
    widget.onDatasetChanged();
  }

  /// Sentinel returned by [_columnDialog] when the user chose Delete.
  static const _kDeleteColumn = DataColumnDef(name: ' delete', type: 'text');

  Future<DataColumnDef?> _columnDialog(
    BuildContext context,
    DataColumnDef? existing,
  ) async {
    final luma = context.luma;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    String type = existing?.type ?? 'text';

    final action = await showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: luma.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            existing == null ? 'Add Column' : 'Edit Column',
            style: TextStyle(color: luma.textPrimary),
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  style: TextStyle(color: luma.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Column name',
                    hintStyle: TextStyle(color: luma.textMuted),
                    filled: true,
                    fillColor: luma.background,
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Type:',
                  style: TextStyle(color: luma.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (t, label) in const [
                      ('text', 'Text'),
                      ('number', 'Number'),
                      ('date', 'Date'),
                    ])
                      ChoiceChip(
                        label: Text(
                          label,
                          style: TextStyle(color: luma.textPrimary),
                        ),
                        selected: type == t,
                        onSelected: (_) => setDialogState(() => type = t),
                        selectedColor: luma.accentSubtle,
                        backgroundColor: luma.background,
                        side: BorderSide(
                          color: type == t ? luma.accent : luma.border,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () => Navigator.pop(context, 'delete'),
                child: Text('Delete', style: TextStyle(color: luma.danger)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: Text('Cancel', style: TextStyle(color: luma.textMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'save'),
              child: Text(
                existing == null ? 'Add' : 'Save',
                style: TextStyle(color: luma.accent),
              ),
            ),
          ],
        ),
      ),
    );

    DataColumnDef? result;
    if (action == 'save' && nameCtrl.text.trim().isNotEmpty) {
      result = DataColumnDef(name: nameCtrl.text.trim(), type: type);
    } else if (action == 'delete') {
      result = _kDeleteColumn;
    }
    nameCtrl.dispose();
    return result;
  }

  Future<void> _addRow(DataManagementRepository repo) async {
    // A new row inherits the active tag filter so it stays visible.
    try {
      await repo.addRow(widget.dataset.id, {}, tags: _tagFilter.toList());
    } on StorageLimitExceededException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

// ─── Tag Chip ────────────────────────────────────────────────────────────────

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.tag,
    required this.selected,
    required this.onTap,
  });
  final DataTagDef tag;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final color = Color(tag.colorValue);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : luma.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              tag.name,
              style: TextStyle(
                color: selected ? luma.textPrimary : luma.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Row Tags Cell ───────────────────────────────────────────────────────────

class _RowTagsCell extends StatelessWidget {
  const _RowTagsCell({
    required this.dataset,
    required this.row,
    required this.repo,
    required this.onManageTags,
  });

  final DatasetRecord dataset;
  final DataRowRecord row;
  final DataManagementRepository repo;
  final VoidCallback onManageTags;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final name in row.tags.take(3))
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Color(
                  dataset.tagByName(name)?.colorValue ?? 0xFF888888,
                ).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                name,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        if (row.tags.length > 3)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              '+${row.tags.length - 3}',
              style: TextStyle(color: luma.textMuted, fontSize: 11),
            ),
          ),
        _TagPickerButton(
          dataset: dataset,
          row: row,
          repo: repo,
          onManageTags: onManageTags,
        ),
      ],
    );
  }
}

class _TagPickerButton extends StatelessWidget {
  const _TagPickerButton({
    required this.dataset,
    required this.row,
    required this.repo,
    required this.onManageTags,
  });

  final DatasetRecord dataset;
  final DataRowRecord row;
  final DataManagementRepository repo;
  final VoidCallback onManageTags;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return PopupMenuButton<String>(
      tooltip: 'Edit tags',
      color: luma.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      icon: Icon(Icons.sell_outlined, size: 15, color: luma.textMuted),
      padding: EdgeInsets.zero,
      itemBuilder: (context) => [
        if (dataset.tags.isEmpty)
          PopupMenuItem<String>(
            value: ' manage',
            child: Text(
              'Create tags…',
              style: TextStyle(color: luma.accent, fontSize: 13),
            ),
          )
        else ...[
          for (final tag in dataset.tags)
            CheckedPopupMenuItem<String>(
              value: tag.name,
              checked: row.tags.contains(tag.name),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Color(tag.colorValue),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tag.name,
                    style: TextStyle(color: luma.textPrimary, fontSize: 13),
                  ),
                ],
              ),
            ),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: ' manage',
            child: Text(
              'Manage tags…',
              style: TextStyle(color: luma.accent, fontSize: 13),
            ),
          ),
        ],
      ],
      onSelected: (value) {
        if (value == ' manage') {
          onManageTags();
          return;
        }
        final next = List<String>.from(row.tags);
        next.contains(value) ? next.remove(value) : next.add(value);
        repo.setRowTags(row.id, next);
      },
    );
  }
}

// ─── Editable Cell ───────────────────────────────────────────────────────────

class _EditableCell extends StatefulWidget {
  const _EditableCell({
    required this.value,
    required this.type,
    required this.onChanged,
  });
  final String value;
  final String type;
  final ValueChanged<String> onChanged;

  @override
  State<_EditableCell> createState() => _EditableCellState();
}

class _EditableCellState extends State<_EditableCell> {
  late final _ctrl = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  @override
  void didUpdateWidget(_EditableCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Don't fight the user while they're typing in this cell.
    if (!_focus.hasFocus &&
        oldWidget.value != widget.value &&
        _ctrl.text != widget.value) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final initial = parseFlexibleDate(_ctrl.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final formatted =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      _ctrl.text = formatted;
      widget.onChanged(formatted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            focusNode: _focus,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 13,
              fontFeatures: widget.type == 'number'
                  ? const [FontFeature.tabularFigures()]
                  : null,
            ),
            keyboardType: widget.type == 'number'
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: widget.onChanged,
          ),
        ),
        if (widget.type == 'date')
          GestureDetector(
            onTap: () => _pickDate(context),
            child: Icon(
              Icons.calendar_today_outlined,
              size: 14,
              color: luma.textMuted,
            ),
          ),
      ],
    );
  }
}

// ─── Stat Card ───────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
  });
  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: luma.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: luma.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(color: luma.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

// ─── Chart Tab ─────────────────────────────────────────────────────────────────

class _ChartTab extends StatelessWidget {
  const _ChartTab({super.key, required this.dataset, required this.rows});
  final DatasetRecord dataset;
  final List<DataRowRecord> rows;

  @override
  Widget build(BuildContext context) {
    return LumaCard(
      child: ChartViewer(dataset: dataset, rows: rows),
    );
  }
}
