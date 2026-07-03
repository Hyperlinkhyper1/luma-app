import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'chart_viewer.dart';
import 'csv_import_export.dart';
import 'data_management_repository.dart';
import 'data_management_scope.dart';

/// The Data Management plugin: create datasets, edit tables, and visualize
/// with bar / line / area / pie charts. Supports CSV import/export.
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
    final id = await repo.createDataset(name);
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
                          'Create tables, edit data, and build charts from your own datasets.',
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                        subtitle: 'Create a dataset above, or import one from CSV.',
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

  void _confirmDelete(BuildContext context, DataManagementRepository repo, DatasetRecord ds) {
    final luma = context.luma;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: luma.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete "${ds.name}"?', style: TextStyle(color: luma.textPrimary)),
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
                      child: Icon(Icons.delete_outline, color: luma.danger, size: 18),
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
                '${widget.dataset.columns.length} columns',
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
  const _DatasetEditorView({super.key, required this.datasetId, required this.onClose});
  final int datasetId;
  final VoidCallback onClose;

  @override
  State<_DatasetEditorView> createState() => _DatasetEditorViewState();
}

class _DatasetEditorViewState extends State<_DatasetEditorView> {
  int _tab = 0; // 0 = table, 1 = charts
  final _nameController = TextEditingController();
  DatasetRecord? _dataset;

  @override
  void initState() {
    super.initState();
    _loadDataset();
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
        _nameController.text = ds.name;
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
          constraints: const BoxConstraints(maxWidth: 960),
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
                          Icon(Icons.arrow_back_rounded, color: luma.textMuted, size: 18),
                          const SizedBox(width: 6),
                          Text('Back', style: TextStyle(color: luma.textMuted, fontSize: 13)),
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
                      decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                      onSubmitted: (_) => _rename(repo),
                      onEditingComplete: () => _rename(repo),
                    ),
                  ),
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
                        onTap: _dataset == null ? null : () => CsvHelper.exportCsv(_dataset!, rows),
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

  Future<void> _importCsv(BuildContext context, DataManagementRepository repo) async {
    final result = await CsvHelper.importCsv();
    if (result == null) return;
    final (columns, rows) = result;
    await repo.clearRows(widget.datasetId);
    await repo.updateColumns(widget.datasetId, columns);
    await repo.importRows(widget.datasetId, rows);
    if (mounted) _loadDataset();
  }
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
  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repo = DataManagementScope.of(context);

    // Stats for numeric columns
    final numericCols = [
      for (var i = 0; i < widget.dataset.columns.length; i++)
        if (widget.dataset.columns[i].type == 'number') i,
    ];

    final stats = <Widget>[];
    for (final colIdx in numericCols.take(4)) {
      final values = widget.rows
          .map((r) => double.tryParse(r.valueAt(colIdx).replaceAll(',', '.')) ?? 0)
          .toList();
      if (values.isEmpty) continue;
      final sum = values.fold<double>(0, (a, b) => a + b);
      final avg = sum / values.length;
      final maxVal = values.reduce((a, b) => a > b ? a : b);
      stats.add(_StatCard(
        label: widget.dataset.columns[colIdx].name,
        value: sum.toStringAsFixed(1),
        sub: 'avg ${avg.toStringAsFixed(1)}  ·  max ${maxVal.toStringAsFixed(1)}',
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stats.isNotEmpty) ...[
          Wrap(spacing: 12, runSpacing: 12, children: stats),
          const SizedBox(height: 20),
        ],
        // Column toolbar
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
            const Spacer(),
            Text(
              '${widget.rows.length} rows',
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            ),
          ],
        ),
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
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStatePropertyAll(luma.surfaceHover),
                  dataRowMinHeight: 44,
                  dataRowMaxHeight: 44,
                  horizontalMargin: 16,
                  columnSpacing: 24,
                  columns: [
                    for (var i = 0; i < widget.dataset.columns.length; i++)
                      DataColumn(
                        label: Row(
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
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => _editColumn(context, repo, i),
                              child: Icon(Icons.edit, size: 14, color: luma.textMuted),
                            ),
                          ],
                        ),
                      ),
                    const DataColumn(label: SizedBox()),
                  ],
                  rows: [
                    for (final row in widget.rows)
                      DataRow(
                        cells: [
                          for (var i = 0; i < widget.dataset.columns.length; i++)
                            DataCell(
                              _EditableCell(
                                value: row.valueAt(i),
                                type: widget.dataset.columns[i].type,
                                onChanged: (val) {
                                  final newValues = Map<String, String>.from(row.values);
                                  newValues[i.toString()] = val;
                                  repo.updateRow(row.id, newValues);
                                },
                              ),
                            ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () => repo.deleteRow(row.id),
                                  child: Icon(Icons.delete_outline, size: 18, color: luma.danger.withValues(alpha: 0.7)),
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
      ],
    );
  }

  Future<void> _addColumn(BuildContext context, DataManagementRepository repo) async {
    final luma = context.luma;
    final nameCtrl = TextEditingController();
    String type = 'text';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: luma.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Add Column', style: TextStyle(color: luma.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: luma.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: luma.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: luma.accent)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('Type:', style: TextStyle(color: luma.textSecondary, fontSize: 13)),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: Text('Text', style: TextStyle(color: luma.textPrimary)),
                    selected: type == 'text',
                    onSelected: (_) => setDialogState(() => type = 'text'),
                    selectedColor: luma.accentSubtle,
                    backgroundColor: luma.background,
                    side: BorderSide(color: type == 'text' ? luma.accent : luma.border),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Number', style: TextStyle(color: luma.textPrimary)),
                    selected: type == 'number',
                    onSelected: (_) => setDialogState(() => type = 'number'),
                    selectedColor: luma.accentSubtle,
                    backgroundColor: luma.background,
                    side: BorderSide(color: type == 'number' ? luma.accent : luma.border),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Date', style: TextStyle(color: luma.textPrimary)),
                    selected: type == 'date',
                    onSelected: (_) => setDialogState(() => type = 'date'),
                    selectedColor: luma.accentSubtle,
                    backgroundColor: luma.background,
                    side: BorderSide(color: type == 'date' ? luma.accent : luma.border),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: TextStyle(color: luma.textMuted))),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Add', style: TextStyle(color: luma.accent)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && nameCtrl.text.trim().isNotEmpty) {
      final newCols = List<DataColumnDef>.from(widget.dataset.columns)
        ..add(DataColumnDef(name: nameCtrl.text.trim(), type: type));
      await repo.updateColumns(widget.dataset.id, newCols);
      widget.onDatasetChanged();
    }
    nameCtrl.dispose();
  }

  Future<void> _editColumn(BuildContext context, DataManagementRepository repo, int index) async {
    final luma = context.luma;
    final col = widget.dataset.columns[index];
    final nameCtrl = TextEditingController(text: col.name);
    String type = col.type;

    final action = await showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: luma.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Edit Column', style: TextStyle(color: luma.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: luma.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: luma.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: luma.accent)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('Type:', style: TextStyle(color: luma.textSecondary, fontSize: 13)),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: Text('Text', style: TextStyle(color: luma.textPrimary)),
                    selected: type == 'text',
                    onSelected: (_) => setDialogState(() => type = 'text'),
                    selectedColor: luma.accentSubtle,
                    backgroundColor: luma.background,
                    side: BorderSide(color: type == 'text' ? luma.accent : luma.border),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Number', style: TextStyle(color: luma.textPrimary)),
                    selected: type == 'number',
                    onSelected: (_) => setDialogState(() => type = 'number'),
                    selectedColor: luma.accentSubtle,
                    backgroundColor: luma.background,
                    side: BorderSide(color: type == 'number' ? luma.accent : luma.border),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Date', style: TextStyle(color: luma.textPrimary)),
                    selected: type == 'date',
                    onSelected: (_) => setDialogState(() => type = 'date'),
                    selectedColor: luma.accentSubtle,
                    backgroundColor: luma.background,
                    side: BorderSide(color: type == 'date' ? luma.accent : luma.border),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'delete'),
              child: Text('Delete', style: TextStyle(color: luma.danger)),
            ),
            TextButton(onPressed: () => Navigator.pop(context, 'cancel'), child: Text('Cancel', style: TextStyle(color: luma.textMuted))),
            TextButton(
              onPressed: () => Navigator.pop(context, 'save'),
              child: Text('Save', style: TextStyle(color: luma.accent)),
            ),
          ],
        ),
      ),
    );

    if (action == 'save' && nameCtrl.text.trim().isNotEmpty) {
      final newCols = List<DataColumnDef>.from(widget.dataset.columns);
      newCols[index] = DataColumnDef(name: nameCtrl.text.trim(), type: type);
      await repo.updateColumns(widget.dataset.id, newCols);
      widget.onDatasetChanged();
    } else if (action == 'delete') {
      final newCols = List<DataColumnDef>.from(widget.dataset.columns)..removeAt(index);
      // Also remove values for that column from all rows
      final rows = await repo.getRows(widget.dataset.id);
      for (final row in rows) {
        final newValues = Map<String, String>.from(row.values);
        newValues.remove(index.toString());
        // Renumber higher indices
        final remapped = <String, String>{};
        for (final entry in newValues.entries) {
          final oldIdx = int.tryParse(entry.key) ?? 0;
          remapped[(oldIdx > index ? oldIdx - 1 : oldIdx).toString()] = entry.value;
        }
        await repo.updateRow(row.id, remapped);
      }
      await repo.updateColumns(widget.dataset.id, newCols);
      widget.onDatasetChanged();
    }
    nameCtrl.dispose();
  }

  Future<void> _addRow(DataManagementRepository repo) async {
    await repo.addRow(widget.dataset.id, {});
  }
}

// ─── Editable Cell ───────────────────────────────────────────────────────────

class _EditableCell extends StatefulWidget {
  const _EditableCell({required this.value, required this.type, required this.onChanged});
  final String value;
  final String type;
  final ValueChanged<String> onChanged;

  @override
  State<_EditableCell> createState() => _EditableCellState();
}

class _EditableCellState extends State<_EditableCell> {
  late final _ctrl = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(_EditableCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _ctrl.text != widget.value) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return TextField(
      controller: _ctrl,
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
    );
  }
}

// ─── Stat Card ───────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.sub});
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
          Text(label, style: TextStyle(color: luma.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: luma.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
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
    return SizedBox(
      height: 520,
      child: LumaCard(
        child: ChartViewer(dataset: dataset, rows: rows),
      ),
    );
  }
}
