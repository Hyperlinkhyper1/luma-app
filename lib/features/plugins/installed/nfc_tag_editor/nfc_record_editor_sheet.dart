import 'package:flutter/material.dart';

import '../../../../theme/luma_theme.dart';
import 'nfc_record.dart';

/// Opens the add/edit dialog for one record. Returns the built record, or
/// null if the user cancelled.
Future<EditableNdefRecord?> showNfcRecordEditor(
  BuildContext context, {
  EditableNdefRecord? existing,
}) {
  return showDialog<EditableNdefRecord>(
    context: context,
    builder: (_) => _NfcRecordEditorDialog(existing: existing),
  );
}

/// Kinds the dialog can build — [NfcRecordKind.raw] is view/delete-only
/// (see [NfcRecordTile]) since re-encoding an unrecognised record risks
/// corrupting bytes the editor doesn't understand.
const _editableKinds = [
  NfcRecordKind.text,
  NfcRecordKind.uri,
  NfcRecordKind.phone,
  NfcRecordKind.email,
  NfcRecordKind.wifi,
  NfcRecordKind.contact,
  NfcRecordKind.appLaunch,
  NfcRecordKind.mime,
];

const _kindLabels = {
  NfcRecordKind.text: 'Text',
  NfcRecordKind.uri: 'Link',
  NfcRecordKind.phone: 'Phone',
  NfcRecordKind.email: 'Email',
  NfcRecordKind.wifi: 'Wi-Fi',
  NfcRecordKind.contact: 'Contact',
  NfcRecordKind.appLaunch: 'App',
  NfcRecordKind.mime: 'Custom',
};

const _allFieldKeys = [
  'text', 'lang', 'uri', 'number', 'address', 'subject', 'body',
  'ssid', 'password', 'name', 'phone', 'email', 'org', 'package',
  'mimeType',
];

class _NfcRecordEditorDialog extends StatefulWidget {
  const _NfcRecordEditorDialog({this.existing});
  final EditableNdefRecord? existing;

  @override
  State<_NfcRecordEditorDialog> createState() => _NfcRecordEditorDialogState();
}

class _NfcRecordEditorDialogState extends State<_NfcRecordEditorDialog> {
  late NfcRecordKind _kind = widget.existing?.kind ?? NfcRecordKind.text;
  late final Map<String, TextEditingController> _controllers = {
    for (final key in _allFieldKeys)
      key: TextEditingController(text: widget.existing?.fields[key] ?? ''),
  };
  late String _security = widget.existing?.fields['security'] ?? 'WPA';
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _text(String key) => _controllers[key]!.text.trim();

  void _fail(String message) => setState(() => _error = message);

  void _save() {
    final fields = <String, String>{};
    switch (_kind) {
      case NfcRecordKind.text:
        if (_text('text').isEmpty) return _fail('Enter some text.');
        fields['text'] = _text('text');
        fields['lang'] = _text('lang').isEmpty ? 'en' : _text('lang');
        break;
      case NfcRecordKind.uri:
        final uri = _text('uri');
        if (uri.isEmpty || Uri.tryParse(uri) == null) {
          return _fail('Enter a valid link.');
        }
        fields['uri'] = uri;
        break;
      case NfcRecordKind.phone:
        if (_text('number').isEmpty) return _fail('Enter a phone number.');
        fields['number'] = _text('number');
        break;
      case NfcRecordKind.email:
        if (_text('address').isEmpty) return _fail('Enter an email address.');
        fields['address'] = _text('address');
        fields['subject'] = _text('subject');
        fields['body'] = _text('body');
        break;
      case NfcRecordKind.wifi:
        if (_text('ssid').isEmpty) return _fail('Enter the network name.');
        fields['ssid'] = _text('ssid');
        fields['password'] = _text('password');
        fields['security'] = _security;
        break;
      case NfcRecordKind.contact:
        if (_text('name').isEmpty) return _fail('Enter a name.');
        fields['name'] = _text('name');
        fields['phone'] = _text('phone');
        fields['email'] = _text('email');
        fields['org'] = _text('org');
        break;
      case NfcRecordKind.appLaunch:
        if (_text('package').isEmpty) {
          return _fail('Enter a package name, e.g. com.example.app.');
        }
        fields['package'] = _text('package');
        break;
      case NfcRecordKind.mime:
        if (_text('mimeType').isEmpty) {
          return _fail('Enter a MIME type, e.g. text/plain.');
        }
        fields['mimeType'] = _text('mimeType');
        fields['text'] = _text('text');
        break;
      case NfcRecordKind.raw:
        return;
    }
    Navigator.of(context).pop(
      EditableNdefRecord(
        id: widget.existing?.id ?? newNfcRecordId(),
        kind: _kind,
        fields: fields,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return AlertDialog(
      backgroundColor: luma.surface,
      title: Text(
        widget.existing == null ? 'Add record' : 'Edit record',
        style: TextStyle(color: luma.textPrimary, fontSize: 16),
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.existing == null) ...[
                _label(luma, 'Type'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final kind in _editableKinds)
                      _KindChip(
                        label: _kindLabels[kind]!,
                        selected: _kind == kind,
                        onTap: () => setState(() => _kind = kind),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              ..._fieldsFor(luma, _kind),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: luma.danger, fontSize: 12.5)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
        ),
        TextButton(
          onPressed: _save,
          child: Text(
            widget.existing == null ? 'Add' : 'Save',
            style: TextStyle(color: luma.accent),
          ),
        ),
      ],
    );
  }

  List<Widget> _fieldsFor(LumaPalette luma, NfcRecordKind kind) {
    switch (kind) {
      case NfcRecordKind.text:
        return [
          _field(luma, 'Text', 'text',
              hint: 'Whatever this tag should say', maxLines: 3),
          const SizedBox(height: 12),
          _field(luma, 'Language code', 'lang', hint: 'en'),
        ];
      case NfcRecordKind.uri:
        return [_field(luma, 'Link', 'uri', hint: 'https://example.com')];
      case NfcRecordKind.phone:
        return [
          _field(luma, 'Phone number', 'number',
              hint: '+1 555 0100', keyboardType: TextInputType.phone),
        ];
      case NfcRecordKind.email:
        return [
          _field(luma, 'Address', 'address',
              hint: 'name@example.com', keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _field(luma, 'Subject (optional)', 'subject'),
          const SizedBox(height: 12),
          _field(luma, 'Body (optional)', 'body', maxLines: 3),
        ];
      case NfcRecordKind.wifi:
        return [
          _field(luma, 'Network name (SSID)', 'ssid'),
          const SizedBox(height: 12),
          _field(luma, 'Password', 'password', obscure: _security != 'nopass'),
          const SizedBox(height: 12),
          _label(luma, 'Security'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              for (final s in const ['WPA', 'WEP', 'nopass'])
                _KindChip(
                  label: s == 'nopass' ? 'Open' : s,
                  selected: _security == s,
                  onTap: () => setState(() => _security = s),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Written as a text record most phones can read when they tap the '
            "tag — it won't auto-join every device the way a router's own "
            'Wi-Fi QR code sometimes does.',
            style: TextStyle(color: luma.textMuted, fontSize: 11.5, height: 1.3),
          ),
        ];
      case NfcRecordKind.contact:
        return [
          _field(luma, 'Name', 'name'),
          const SizedBox(height: 12),
          _field(luma, 'Phone (optional)', 'phone', keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          _field(luma, 'Email (optional)', 'email', keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _field(luma, 'Organization (optional)', 'org'),
        ];
      case NfcRecordKind.appLaunch:
        return [
          _field(luma, 'Package name', 'package', hint: 'com.example.app'),
          const SizedBox(height: 8),
          Text(
            'Find this under Settings → Apps → (the app) → Advanced → App '
            'details, on the phone that has it installed. Android offers to '
            'open or install this app when it reads the tag.',
            style: TextStyle(color: luma.textMuted, fontSize: 11.5, height: 1.3),
          ),
        ];
      case NfcRecordKind.mime:
        return [
          _field(luma, 'MIME type', 'mimeType', hint: 'text/plain'),
          const SizedBox(height: 12),
          _field(luma, 'Content', 'text', maxLines: 3),
        ];
      case NfcRecordKind.raw:
        return const [];
    }
  }

  Widget _field(
    LumaPalette luma,
    String label,
    String key, {
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool obscure = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(luma, label),
        const SizedBox(height: 6),
        TextField(
          controller: _controllers[key],
          maxLines: maxLines,
          obscureText: obscure && maxLines == 1,
          keyboardType: keyboardType,
          style: TextStyle(color: luma.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: TextStyle(color: luma.textMuted, fontSize: 13),
            filled: true,
            fillColor: luma.background,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: luma.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: luma.accent),
            ),
          ),
        ),
      ],
    );
  }
}

Widget _label(LumaPalette luma, String text) => Text(
      text,
      style: TextStyle(
        color: luma.textSecondary,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
    );

class _KindChip extends StatelessWidget {
  const _KindChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? luma.accentSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? luma.accent : luma.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? luma.accent : luma.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
