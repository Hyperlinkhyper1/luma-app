import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../../_shared/windows_webview.dart';

/// The **Pagoda Test** page loads an interactive Three.js voxel garden
/// benchmark — a procedurally generated Japanese garden with a 5-story pagoda.
///
/// The scene demonstrates voxel rendering, animation, interaction, and dynamic
/// day/night cycles. It runs in an embedded WebView on Windows and Android.
class PagodaTestPage extends StatefulWidget {
  const PagodaTestPage({super.key});

  @override
  State<PagodaTestPage> createState() => _PagodaTestPageState();
}

class _PagodaTestPageState extends State<PagodaTestPage> {
  bool _loading = true;
  String? _selectedModel;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;

    // Show model selection UI if no model is selected
    if (_selectedModel == null) {
      return Scaffold(
        backgroundColor: luma.background,
        appBar: AppBar(
          backgroundColor: luma.background,
          elevation: 0,
          title: const Text('Pagoda Test'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Benchmark Scene',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Spring Festival at the Five-Story Pagoda — an interactive voxel '
                'garden benchmark with procedural terrain, animated elements, and '
                'dynamic lighting.',
                style: TextStyle(
                  color: luma.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Select a Model',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ModelButton(
                model: 'Haiku 4.5',
                description: 'Fast vision model for the benchmark',
                onTap: () => setState(() => _selectedModel = 'Haiku 4.5'),
                isSelected: false,
              ),
            ],
          ),
        ),
      );
    }

    // Show benchmark scene
    if (Platform.isWindows) {
      return Scaffold(
        backgroundColor: luma.background,
        appBar: AppBar(
          backgroundColor: luma.background,
          elevation: 0,
          title: const Text('Pagoda Test'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => setState(() => _selectedModel = null),
          ),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: WindowsWebview(
                fileUrl: Uri.file(
                  windowsAssetPath('assets/tests/pagoda.html'),
                ).toString(),
                onLoaded: () {
                  if (mounted) setState(() => _loading = false);
                },
              ),
            ),
            if (_loading)
              Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(luma.accent),
                ),
              ),
          ],
        ),
      );
    }

    // Fallback for non-Windows platforms
    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        elevation: 0,
        title: const Text('Pagoda Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: LumaEmptyState(
          icon: Icons.computer_rounded,
          title: 'Not available on this platform',
          subtitle: 'The Pagoda Test requires a Windows desktop. '
              'Mobile and Linux support are coming soon.',
        ),
      ),
    );
  }
}

/// A button to select and start a model benchmark.
class ModelButton extends StatefulWidget {
  const ModelButton({
    super.key,
    required this.model,
    required this.description,
    required this.onTap,
    required this.isSelected,
  });

  final String model;
  final String description;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  State<ModelButton> createState() => _ModelButtonState();
}

class _ModelButtonState extends State<ModelButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: _hovered ? luma.surfaceHover : luma.surface,
          border: Border.all(
            color: _hovered ? luma.accent : luma.border,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.model,
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.description,
                          style: TextStyle(
                            color: luma.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedSlide(
                    duration: const Duration(milliseconds: 160),
                    offset: Offset(_hovered ? 0.2 : 0, 0),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: luma.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
