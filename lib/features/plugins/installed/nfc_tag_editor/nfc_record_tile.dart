import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'nfc_record.dart';

/// Icon, label and accent color for a record kind — shared by the record
/// tile, the type picker in the editor sheet, and the compact preview line
/// shown on template/history cards.
class NfcRecordKindMeta {
  const NfcRecordKindMeta(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;
}

const Map<NfcRecordKind, NfcRecordKindMeta> nfcRecordKindMetas = {
  NfcRecordKind.text: NfcRecordKindMeta(
      Icons.notes_rounded, 'Text', Color(0xFF7C5AD9)),
  NfcRecordKind.uri: NfcRecordKindMeta(
      Icons.link_rounded, 'Link', Color(0xFF2F80ED)),
  NfcRecordKind.phone: NfcRecordKindMeta(
      Icons.call_rounded, 'Phone number', Color(0xFF12A372)),
  NfcRecordKind.email: NfcRecordKindMeta(
      Icons.email_rounded, 'Email', Color(0xFFF5A623)),
  NfcRecordKind.wifi: NfcRecordKindMeta(
      Icons.wifi_rounded, 'Wi-Fi details', Color(0xFF00B8A9)),
  NfcRecordKind.contact: NfcRecordKindMeta(
      Icons.contact_page_rounded, 'Contact card', Color(0xFFF25F9C)),
  NfcRecordKind.appLaunch: NfcRecordKindMeta(
      Icons.open_in_new_rounded, 'App shortcut', Color(0xFF9B51E0)),
  NfcRecordKind.mime: NfcRecordKindMeta(
      Icons.data_object_rounded, 'Custom data', Color(0xFF5D6470)),
  NfcRecordKind.raw: NfcRecordKindMeta(
      Icons.help_outline_rounded, 'Unrecognized record', Color(0xFF6F6981)),
};

NfcRecordKindMeta nfcRecordKindMeta(NfcRecordKind kind) =>
    nfcRecordKindMetas[kind]!;

/// A one-line, human-readable summary of a record's content for list rows.
String nfcRecordSummary(EditableNdefRecord record) {
  final f = record.fields;
  switch (record.kind) {
    case NfcRecordKind.text:
      return (f['text'] ?? '').isEmpty ? 'Empty' : f['text']!;
    case NfcRecordKind.uri:
      return (f['uri'] ?? '').isEmpty ? 'No link set' : f['uri']!;
    case NfcRecordKind.phone:
      return (f['number'] ?? '').isEmpty ? 'No number set' : f['number']!;
    case NfcRecordKind.email:
      return (f['address'] ?? '').isEmpty ? 'No address set' : f['address']!;
    case NfcRecordKind.wifi:
      final ssid = f['ssid'] ?? '';
      return ssid.isEmpty ? 'No network set' : '$ssid · ${f['security'] ?? 'WPA'}';
    case NfcRecordKind.contact:
      return (f['name'] ?? '').isEmpty ? 'No name set' : f['name']!;
    case NfcRecordKind.appLaunch:
      return (f['package'] ?? '').isEmpty ? 'No package set' : f['package']!;
    case NfcRecordKind.mime:
      final mime = f['mimeType'] ?? '';
      return mime.isEmpty ? 'text/plain' : mime;
    case NfcRecordKind.raw:
      final bytes = ((record.rawPayloadHex?.length ?? 0) / 2).round();
      return 'Kept as-is ($bytes bytes) — not editable';
  }
}

/// One record row in the editor's list: icon, kind label, content summary,
/// and a menu for edit/duplicate/delete. [onEdit] is null for records the
/// editor can't safely re-encode (see [NfcRecordKind.raw]).
class NfcRecordTile extends StatelessWidget {
  const NfcRecordTile({
    super.key,
    required this.record,
    required this.onDuplicate,
    required this.onDelete,
    this.onEdit,
    this.dragHandle,
  });

  final EditableNdefRecord record;
  final VoidCallback? onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final Widget? dragHandle;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final meta = nfcRecordKindMeta(record.kind);
    return LumaCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Row(
        children: [
          if (dragHandle != null) ...[dragHandle!, const SizedBox(width: 4)],
          LumaIconBadge(icon: meta.icon, color: meta.color, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  meta.label,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  nfcRecordSummary(record),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: luma.textMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            color: luma.surface,
            icon: Icon(Icons.more_vert_rounded, color: luma.textMuted, size: 20),
            onSelected: (value) {
              if (value == 'edit') {
                onEdit?.call();
              } else if (value == 'duplicate') {
                onDuplicate();
              } else {
                onDelete();
              }
            },
            itemBuilder: (context) => [
              if (onEdit != null)
                PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit',
                      style: TextStyle(color: luma.textPrimary, fontSize: 13.5)),
                ),
              PopupMenuItem(
                value: 'duplicate',
                child: Text('Duplicate',
                    style: TextStyle(color: luma.textPrimary, fontSize: 13.5)),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete',
                    style: TextStyle(color: luma.danger, fontSize: 13.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
