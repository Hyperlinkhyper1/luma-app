import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'qr_code_repository.dart';
import 'qr_code_scope.dart';

/// The QR Code Generator plugin: turn a URL into a QR code and keep a local
/// history of everything generated, so codes can be reopened later. This is
/// not secret data like the password vault, so there's no PIN gate.
class QrCodeGeneratorPage extends StatefulWidget {
  const QrCodeGeneratorPage({super.key});

  @override
  State<QrCodeGeneratorPage> createState() => _QrCodeGeneratorPageState();
}

class _QrCodeGeneratorPageState extends State<QrCodeGeneratorPage> {
  final _controller = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generate(QrCodeRepository repo) async {
    final url = _controller.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Enter a URL.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    await repo.add(url);
    _controller.clear();
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repo = QrCodeScope.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LumaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Generate a QR code',
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Paste a URL and turn it into a scannable QR code.',
                      style: TextStyle(color: luma.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            autofocus: true,
                            style: TextStyle(color: luma.textPrimary),
                            decoration: _qrInputDecoration(luma,
                                hint: 'https://example.com'),
                            onSubmitted: (_) => _generate(repo),
                          ),
                        ),
                        const SizedBox(width: 12),
                        LumaPrimaryButton(
                          label: 'Generate',
                          icon: Icons.qr_code_2_rounded,
                          loading: _saving,
                          onTap: () => _generate(repo),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!,
                          style: TextStyle(color: luma.danger, fontSize: 13)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'History',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              StreamData<List<QrCodeRecord>>(
                stream: repo.watchAll(),
                builder: (context, records) {
                  if (records.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: LumaEmptyState(
                        icon: Icons.qr_code_2_rounded,
                        title: 'No QR codes yet',
                        subtitle:
                            'Codes you generate are saved here so you can reopen them anytime.',
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final r in records) ...[
                        _QrHistoryTile(
                            record: r, onDelete: () => repo.delete(r.id)),
                        const SizedBox(height: 10),
                      ],
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
}

class _QrHistoryTile extends StatelessWidget {
  const _QrHistoryTile({required this.record, required this.onDelete});
  final QrCodeRecord record;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showQrDetail(context, record),
        child: LumaCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: QrImageView(
                  data: record.url,
                  version: QrVersions.auto,
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(record.createdAt),
                      style: TextStyle(color: luma.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded,
                    color: luma.textMuted, size: 20),
                tooltip: 'Delete',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showQrDetail(BuildContext context, QrCodeRecord record) {
  showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: context.luma.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: record.url,
                  version: QrVersions.auto,
                  size: 220,
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(
                record.url,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.luma.textPrimary, fontSize: 13),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LumaGhostButton(
                    label: 'Copy URL',
                    icon: Icons.copy_rounded,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: record.url));
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(width: 10),
                  LumaPrimaryButton(
                    label: 'Close',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _formatDate(DateTime d) {
  final local = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

InputDecoration _qrInputDecoration(LumaPalette luma, {String? hint}) {
  OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c),
      );
  return InputDecoration(
    isDense: true,
    hintText: hint,
    hintStyle: TextStyle(color: luma.textMuted),
    filled: true,
    fillColor: luma.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    enabledBorder: border(luma.border),
    focusedBorder: border(luma.accent),
  );
}
