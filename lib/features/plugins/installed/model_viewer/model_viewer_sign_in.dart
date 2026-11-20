import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../l10n/app_localizations.dart';
import 'model_viewer_repository.dart';

class ModelViewerSignIn extends StatefulWidget {
  const ModelViewerSignIn({super.key, required this.repository});

  final ModelViewerRepository repository;

  @override
  State<ModelViewerSignIn> createState() => _ModelViewerSignInState();
}

class _ModelViewerSignInState extends State<ModelViewerSignIn> {
  final _token = TextEditingController();
  String? _code;
  String? _error;
  bool _authorizing = false;
  bool _saving = false;

  static final _deviceUrl = Uri.https('github.com', '/login/device');
  static final _tokenUrl = Uri.https(
    'github.com',
    '/settings/personal-access-tokens/new',
  );

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _open(Uri url) async {
    final t = L.of(context);
    try {
      if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (mounted) setState(() => _error = t.modelViewerOpenBrowserFailed);
  }

  Future<void> _signIn() async {
    final t = L.of(context);
    final repository = widget.repository;
    setState(() {
      _error = null;
      _code = null;
      _authorizing = true;
    });
    try {
      final authorization = await repository.beginDeviceSignIn();
      if (!mounted) return;
      setState(() => _code = authorization.userCode);
      final token = await repository.pollDeviceSignIn(
        authorization,
        cancelled: () => !mounted,
      );
      if (token != null && mounted) await _save(token);
    } on ModelViewerException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = t.modelViewerSignInFailed);
    } finally {
      if (mounted) {
        setState(() {
          _authorizing = false;
          _code = null;
        });
      }
    }
  }

  Future<void> _save(String token) async {
    final t = L.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.connect(token);
      if (mounted) Navigator.of(context).pop(true);
    } on ModelViewerException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = t.modelViewerSignInFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final busy = _saving || _authorizing;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        title: Text(t.modelViewerConnectGithub),
        content: SizedBox(
          width: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (ModelViewerRepository.deviceSignInAvailable) ...[
                if (_code case final String code) ...[
                  Text(t.modelViewerEnterCode),
                  const SizedBox(height: 8),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      SelectableText(
                        code,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      IconButton(
                        tooltip: t.commonCopy,
                        onPressed: () =>
                            Clipboard.setData(ClipboardData(text: code)),
                        icon: const Icon(Icons.copy_rounded),
                      ),
                      TextButton(
                        onPressed: () => _open(_deviceUrl),
                        child: Text(t.modelViewerOpenGithub),
                      ),
                    ],
                  ),
                ] else
                  OutlinedButton(
                    onPressed: busy ? null : _signIn,
                    child: Text(t.modelViewerSignInBrowser),
                  ),
                const SizedBox(height: 16),
              ],
              Text(t.modelViewerTokenInstructions),
              const SizedBox(height: 8),
              TextButton(
                onPressed: busy ? null : () => _open(_tokenUrl),
                child: Text(t.modelViewerCreateToken),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _token,
                enabled: !busy,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                onSubmitted: busy ? null : _save,
                decoration: InputDecoration(
                  labelText: t.githubConnectTokenLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (busy) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
              if (_error case final String error) ...[
                const SizedBox(height: 12),
                Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: Text(t.commonCancel),
          ),
          FilledButton(
            onPressed: busy ? null : () => _save(_token.text),
            child: Text(t.modelViewerUseToken),
          ),
        ],
      ),
    );
  }
}
