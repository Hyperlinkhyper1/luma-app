import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../../_shared/windows_webview.dart'
    show WindowsWebview, windowsAssetPath;
import 'pagoda_test_page.dart' show ModelButton;

class _BundledRackTest {
  const _BundledRackTest({
    required this.model,
    required this.description,
    required this.asset,
  });

  final String model;
  final String description;
  final String asset;
}

const _bundledRackTests = <_BundledRackTest>[
  _BundledRackTest(
    model: 'Sonnet 5.5 (Low)',
    description: 'Full 42U rack plus single-slice server inspection by '
        'Sonnet 5.5 Low.',
    asset: 'assets/ai_usage/server_rack_tests/sonnet_5_5_low.html',
  ),
  _BundledRackTest(
    model: 'Sonnet 5.5 (Xhigh)',
    description: 'A 42U rack of nine inspectable servers; each one slides '
        'out on its rails into an open single-slice view with exploded, '
        'cutaway and airflow modes.',
    asset: 'assets/ai_usage/server_rack_tests/sonnet_5_5_xhigh.html',
  ),
];

/// The **Server Rack Test** page: a 42U rack that opens into a single,
/// per-archetype server slice. Entries are bundled scenes, so it works with
/// no server account.
class ServerRackTestPage extends StatefulWidget {
  const ServerRackTestPage({super.key});

  @override
  State<ServerRackTestPage> createState() => _ServerRackTestPageState();
}

class _ServerRackTestPageState extends State<ServerRackTestPage> {
  _BundledRackTest? _selected;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final selected = _selected;
    final back = IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => setState(() => _selected = null),
    );
    if (selected != null) {
      return Scaffold(
        backgroundColor: luma.background,
        appBar: AppBar(
          backgroundColor: luma.background,
          elevation: 0,
          title: Text(selected.model),
          leading: back,
        ),
        body: Platform.isWindows
            ? WindowsWebview(
                key: ValueKey(selected.asset),
                fileUrl: Uri.file(windowsAssetPath(selected.asset)).toString(),
              )
            : const Padding(
                padding: EdgeInsets.all(24),
                child: LumaEmptyState(
                  icon: Icons.computer_rounded,
                  title: 'Not available on this platform',
                  subtitle: 'The Server Rack Test requires Windows desktop.',
                ),
              ),
      );
    }
    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        elevation: 0,
        title: const Text('Server Rack Test'),
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
              'A full 42U rack and a single-server slice view: macro '
              'architecture of how machines fit a rack, and micro '
              'architecture of the hardware inside one chassis.',
              style: TextStyle(color: luma.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Text(
              'Select a Model',
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            for (final entry in _bundledRackTests) ...[
              ModelButton(
                model: entry.model,
                description: entry.description,
                onTap: () => setState(() => _selected = entry),
                isSelected: false,
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
