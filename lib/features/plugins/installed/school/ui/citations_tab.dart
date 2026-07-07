import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../data/school_database.dart';
import '../logic/citation_formatter.dart';
import '../school_scope.dart';

/// Generates APA / MLA / Chicago citations from a handful of source fields,
/// and keeps a list of every citation the student has generated so far.
class CitationsTab extends StatefulWidget {
  const CitationsTab({super.key});

  @override
  State<CitationsTab> createState() => _CitationsTabState();
}

class _CitationsTabState extends State<CitationsTab> {
  CitationStyle _style = CitationStyle.apa;
  SourceType _sourceType = SourceType.website;

  final _author = TextEditingController();
  final _title = TextEditingController();
  final _year = TextEditingController();
  final _container = TextEditingController();
  final _url = TextEditingController();
  final _accessDate = TextEditingController();
  final _volume = TextEditingController();
  final _issue = TextEditingController();
  final _pages = TextEditingController();
  final _city = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _author,
      _title,
      _year,
      _container,
      _url,
      _accessDate,
      _volume,
      _issue,
      _pages,
      _city,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  CitationFields get _fields => CitationFields(
        author: _author.text.trim(),
        title: _title.text.trim(),
        year: _year.text.trim(),
        container: _container.text.trim(),
        url: _url.text.trim(),
        accessDate: _accessDate.text.trim(),
        volume: _volume.text.trim(),
        issue: _issue.text.trim(),
        pages: _pages.text.trim(),
        city: _city.text.trim(),
      );

  Future<void> _generate() async {
    final repo = SchoolScope.of(context);
    await repo.createCitation(_style, _sourceType, _fields);
  }

  @override
  Widget build(BuildContext context) {
    final repo = SchoolScope.of(context);
    final luma = context.luma;
    final preview = formatCitation(_style, _sourceType, _fields);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              child: LumaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('New citation',
                        style: TextStyle(
                            color: luma.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<CitationStyle>(
                            initialValue: _style,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Style'),
                            items: [
                              for (final s in CitationStyle.values)
                                DropdownMenuItem(value: s, child: Text(s.label)),
                            ],
                            onChanged: (v) => setState(() => _style = v!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<SourceType>(
                            initialValue: _sourceType,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Source type'),
                            items: [
                              for (final t in SourceType.values)
                                DropdownMenuItem(value: t, child: Text(t.label)),
                            ],
                            onChanged: (v) => setState(() => _sourceType = v!),
                          ),
                        ),
                      ],
                    ),
                    _field(_author, 'Author (Last, First)'),
                    _field(_title, 'Title'),
                    Row(
                      children: [
                        Expanded(child: _field(_year, 'Year')),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(_container,
                              _sourceType == SourceType.book ? 'Publisher' : 'Website / journal name'),
                        ),
                      ],
                    ),
                    if (_sourceType == SourceType.journalArticle)
                      Row(
                        children: [
                          Expanded(child: _field(_volume, 'Volume')),
                          const SizedBox(width: 12),
                          Expanded(child: _field(_issue, 'Issue')),
                          const SizedBox(width: 12),
                          Expanded(child: _field(_pages, 'Pages')),
                        ],
                      ),
                    if (_sourceType == SourceType.book) _field(_city, 'City'),
                    if (_sourceType == SourceType.website) ...[
                      _field(_url, 'URL'),
                      _field(_accessDate, 'Access date'),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: luma.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: luma.border),
                      ),
                      child: SelectableText(
                        preview.isEmpty ? 'Preview will appear here.' : preview,
                        style: TextStyle(color: luma.textPrimary, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        LumaGhostButton(
                          label: 'Copy',
                          icon: Icons.copy_rounded,
                          onTap: preview.isEmpty
                              ? null
                              : () => Clipboard.setData(ClipboardData(text: preview)),
                        ),
                        LumaPrimaryButton(
                          label: 'Save citation',
                          icon: Icons.check_rounded,
                          onTap: preview.isEmpty ? null : _generate,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 4,
            child: StreamData<List<Citation>>(
              stream: repo.watchCitations(),
              builder: (context, citations) {
                if (citations.isEmpty) {
                  return const LumaEmptyState(
                    icon: Icons.format_quote_rounded,
                    title: 'No saved citations yet',
                  );
                }
                return ListView.separated(
                  itemCount: citations.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final c = citations[i];
                    return LumaCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(c.formattedText,
                                style: TextStyle(color: luma.textPrimary, fontSize: 13)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            onPressed: () =>
                                Clipboard.setData(ClipboardData(text: c.formattedText)),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline_rounded,
                                color: luma.textMuted, size: 18),
                            onPressed: () => repo.deleteCitation(c.id),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextField(
        controller: controller,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
