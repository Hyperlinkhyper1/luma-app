import 'package:flutter/material.dart';

import '../../../theme/luma_theme.dart';
import 'ffmpeg_installer.dart';
import 'ffmpeg_service.dart';

/// Shown wherever ffmpeg is required but missing: explains the situation and
/// offers a one-click download, a progress bar, and a manual re-check. Calls
/// [onReady] once ffmpeg becomes available.
class FfmpegSetup extends StatefulWidget {
  const FfmpegSetup({super.key, required this.onReady});

  final VoidCallback onReady;

  @override
  State<FfmpegSetup> createState() => _FfmpegSetupState();
}

class _FfmpegSetupState extends State<FfmpegSetup> {
  bool _installing = false;
  double? _progress;
  String? _error;
  bool _checking = false;

  Future<void> _install() async {
    setState(() {
      _installing = true;
      _progress = null;
      _error = null;
    });
    try {
      await FfmpegInstaller.install(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      final ok = await Ffmpeg.available();
      if (!mounted) return;
      if (ok) {
        widget.onReady();
      } else {
        setState(() {
          _installing = false;
          _error = 'Installed, but ffmpeg still could not be started.';
        });
      }
    } on FfmpegInstallException catch (e) {
      if (!mounted) return;
      setState(() {
        _installing = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _installing = false;
        _error = 'Install failed: $e';
      });
    }
  }

  Future<void> _recheck() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    Ffmpeg.invalidate();
    final ok = await Ffmpeg.available();
    if (!mounted) return;
    setState(() => _checking = false);
    if (ok) {
      widget.onReady();
    } else {
      setState(() => _error = 'Still not found.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: luma.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: luma.danger.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.extension_off_outlined, color: luma.danger, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ffmpeg is required',
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      FfmpegInstaller.supported
                          ? 'Audio & video tools need ffmpeg. Install it once '
                              'and luma will keep using it.'
                          : 'Audio & video tools need ffmpeg on your PATH. '
                              'Automatic install is Windows-only.',
                      style:
                          TextStyle(color: luma.textSecondary, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_installing) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 8,
                backgroundColor: luma.surfaceHover,
                valueColor: AlwaysStoppedAnimation(luma.accent),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _progress == null
                  ? 'Preparing…'
                  : 'Downloading ffmpeg… ${(_progress! * 100).toStringAsFixed(0)}%',
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            ),
          ] else ...[
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: luma.danger, fontSize: 12.5),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                if (FfmpegInstaller.supported)
                  _SetupButton(
                    label: 'Install ffmpeg',
                    icon: Icons.download_rounded,
                    primary: true,
                    onTap: _install,
                  ),
                if (FfmpegInstaller.supported) const SizedBox(width: 10),
                _SetupButton(
                  label: _checking ? 'Checking…' : 'Re-check',
                  icon: Icons.refresh_rounded,
                  primary: false,
                  onTap: _checking ? null : _recheck,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SetupButton extends StatefulWidget {
  const _SetupButton({
    required this.label,
    required this.icon,
    required this.primary,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback? onTap;

  @override
  State<_SetupButton> createState() => _SetupButtonState();
}

class _SetupButtonState extends State<_SetupButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final enabled = widget.onTap != null;
    final Color bg;
    final Color fg;
    if (widget.primary) {
      bg = !enabled
          ? luma.accent.withValues(alpha: 0.4)
          : (_hovering ? luma.accentHover : luma.accent);
      fg = luma.onAccent;
    } else {
      bg = _hovering ? luma.surfaceHover : Colors.transparent;
      fg = luma.textPrimary;
    }
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: widget.primary
                ? null
                : Border.all(color: luma.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: fg, size: 17),
              const SizedBox(width: 7),
              Text(
                widget.label,
                style: TextStyle(
                  color: fg,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
