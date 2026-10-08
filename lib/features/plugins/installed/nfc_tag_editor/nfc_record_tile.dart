import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/luma_theme.dart';
import 'nfc_record.dart';

/// Icon and accent color for a record kind — shared by the record tile, the
/// type picker in the editor sheet, and the compact preview line shown on
/// template/history cards. The displayed label comes from [nfcRecordKindLabel].
class NfcRecordKindMeta {
  const NfcRecordKindMeta(this.icon, this.color);
  final IconData icon;
  final Color color;
}

const Map<NfcRecordKind, NfcRecordKindMeta> nfcRecordKindMetas = {
  NfcRecordKind.text: NfcRecordKindMeta(Icons.notes_rounded, Color(0xFF7C5AD9)),
  NfcRecordKind.uri: NfcRecordKindMeta(Icons.link_rounded, Color(0xFF2F80ED)),
  NfcRecordKind.phone: NfcRecordKindMeta(Icons.call_rounded, Color(0xFF12A372)),
  NfcRecordKind.email: NfcRecordKindMeta(Icons.email_rounded, Color(0xFFF5A623)),
  NfcRecordKind.wifi: NfcRecordKindMeta(Icons.wifi_rounded, Color(0xFF00B8A9)),
  NfcRecordKind.contact:
      NfcRecordKindMeta(Icons.contact_page_rounded, Color(0xFFF25F9C)),
  NfcRecordKind.appLaunch:
      NfcRecordKindMeta(Icons.open_in_new_rounded, Color(0xFF9B51E0)),
  NfcRecordKind.mime: NfcRecordKindMeta(Icons.data_object_rounded, Color(0xFF5D6470)),
  NfcRecordKind.raw:
      NfcRecordKindMeta(Icons.help_outline_rounded, Color(0xFF6F6981)),
};

NfcRecordKindMeta nfcRecordKindMeta(NfcRecordKind kind) =>
    nfcRecordKindMetas[kind]!;

String nfcRecordKindLabel(L t, NfcRecordKind kind) => switch (kind) {
      NfcRecordKind.text => t.nfcRecordEditorTypeText,
      NfcRecordKind.uri => t.nfcRecordEditorTypeLink,
      NfcRecordKind.phone => t.nfcKindPhone,
      NfcRecordKind.email => t.commonEmail,
      NfcRecordKind.wifi => t.nfcKindWifi,
      NfcRecordKind.contact => t.nfcKindContact,
      NfcRecordKind.appLaunch => t.nfcKindAppLaunch,
      NfcRecordKind.mime => t.nfcKindMime,
      NfcRecordKind.raw => t.nfcKindRaw,
    };

/// A one-line, human-readable summary of a record's content for list rows.
String nfcRecordSummary(L t, EditableNdefRecord record) {
  final f = record.fields;
  switch (record.kind) {
    case NfcRecordKind.text:
      return (f['text'] ?? '').isEmpty ? t.nfcSummaryEmpty : f['text']!;
    case NfcRecordKind.uri:
      return (f['uri'] ?? '').isEmpty ? t.nfcSummaryNoLink : f['uri']!;
    case NfcRecordKind.phone:
      return (f['number'] ?? '').isEmpty ? t.nfcSummaryNoNumber : f['number']!;
    case NfcRecordKind.email:
      return (f['address'] ?? '').isEmpty
          ? t.nfcSummaryNoAddress
          : f['address']!;
    case NfcRecordKind.wifi:
      final ssid = f['ssid'] ?? '';
      return ssid.isEmpty
          ? t.nfcSummaryNoNetwork
          : '$ssid · ${f['security'] ?? 'WPA'}';
    case NfcRecordKind.contact:
      return (f['name'] ?? '').isEmpty ? t.nfcSummaryNoName : f['name']!;
    case NfcRecordKind.appLaunch:
      return (f['package'] ?? '').isEmpty
          ? t.nfcSummaryNoPackage
          : f['package']!;
    case NfcRecordKind.mime:
      final mime = f['mimeType'] ?? '';
      return mime.isEmpty ? 'text/plain' : mime;
    case NfcRecordKind.raw:
      final bytes = ((record.rawPayloadHex?.length ?? 0) / 2).round();
      return t.nfcSummaryRawBytes(bytes);
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
    final t = L.of(context);
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
                  nfcRecordKindLabel(t, record.kind),
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  nfcRecordSummary(t, record),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: luma.textMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: t.commonMore,
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
                  child: Text(t.commonEdit,
                      style: TextStyle(color: luma.textPrimary, fontSize: 13.5)),
                ),
              PopupMenuItem(
                value: 'duplicate',
                child: Text(t.nfcDuplicate,
                    style: TextStyle(color: luma.textPrimary, fontSize: 13.5)),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(t.commonDelete,
                    style: TextStyle(color: luma.danger, fontSize: 13.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
