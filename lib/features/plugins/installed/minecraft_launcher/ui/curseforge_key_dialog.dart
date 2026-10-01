import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../logic/curseforge_api_client.dart';

/// Asks for the CurseForge API key the launcher needs to browse and
/// download from CurseForge. Returns true when a key was saved.
Future<bool> showCurseForgeKeyDialog(BuildContext context) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => const _CurseForgeKeyDialog(),
  );
  return saved ?? false;
}

class _CurseForgeKeyDialog extends StatefulWidget {
  const _CurseForgeKeyDialog();

  @override
  State<_CurseForgeKeyDialog> createState() => _CurseForgeKeyDialogState();
}

class _CurseForgeKeyDialogState extends State<_CurseForgeKeyDialog> {
  static const _consoleUrl = 'https://console.curseforge.com/';

  final _controller = TextEditingController();
  bool _obscure = true;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final key = _controller.text.trim();
    if (key.isEmpty) return;
    setState(() => _saving = true);
    await CurseForgeApiClient.instance.saveKey(key);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return AlertDialog(
      title: const Text('CurseForge API key'),
      content: SizedBox(
        width: lumaDialogWidth(context, 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CurseForge only answers apps that send an API key. Create a '
              'free one in the CurseForge for Studios console and paste it '
              'here. It is stored encrypted on this device, shared with '
              'Account Overview, and only ever sent to CurseForge.',
              style: TextStyle(color: luma.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(_consoleUrl),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Open the CurseForge console'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              obscureText: _obscure,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Paste your API key',
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(
          onPressed: _saving || _controller.text.trim().isEmpty ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
