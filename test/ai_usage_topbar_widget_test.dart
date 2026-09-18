import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/ai_usage/ai_usage_page.dart';
import 'package:luma/features/plugins/installed/ai_usage/ai_usage_repository.dart';
import 'package:luma/features/plugins/installed/ai_usage/ai_usage_scope.dart';
import 'package:luma/features/plugins/installed/ai_usage/ai_usage_source.dart';
import 'package:luma/features/plugins/installed/ai_usage/antigravity_scanner.dart';
import 'package:luma/features/plugins/installed/ai_usage/claude_code_scanner.dart';
import 'package:luma/features/plugins/installed/ai_usage/codex_cli_scanner.dart';
import 'package:luma/features/plugins/installed/ai_usage/data/ai_usage_database.dart';
import 'package:luma/features/plugins/installed/ai_usage/freebuff_scanner.dart';
import 'package:luma/features/plugins/installed/ai_usage/opencode_scanner.dart';
import 'package:luma/storage/storage_guard.dart';
import 'package:luma/theme/luma_theme.dart';
import 'package:luma/theme/theme_style.dart';

/// `scheduleRefresh` starts a real `Timer` that eventually calls
/// `path_provider`, unmocked here. Under flutter_test's FakeAsync clock that
/// platform-channel wait doesn't resolve and the test hangs (see the same
/// workaround in the Steam tools tests).
class _NoScheduleStorageGuard extends StorageGuardService {
  @override
  void scheduleRefresh() {}
}

/// Stub scanners: none of them may touch the real home directory from a
/// widget test — this machine has real `~/.codex/sessions` and friends, and
/// a real scan under FakeAsync never settles. Only the Claude stub reports
/// found, with one turn so the dashboard renders its body.
class _FoundClaudeScanner extends ClaudeCodeScanner {
  const _FoundClaudeScanner(this.db);
  final AiUsageDatabase db;

  @override
  Future<ClaudeCodeScanResult> scan(AiUsageDatabase db) async {
    await db.into(db.aiUsageTurns).insert(
          AiUsageTurnsCompanion.insert(
            sessionId: 'sess-1',
            timestamp: DateTime.now().toUtc(),
            model: 'claude-sonnet-4-6',
            source: AiUsageSource.claudeCode,
          ),
        );
    return const ClaudeCodeScanResult(
      projectsDirFound: true,
      filesScanned: 1,
      filesNew: 1,
      turnsAdded: 1,
    );
  }
}

class _UnavailableCodexScanner extends CodexCliScanner {
  const _UnavailableCodexScanner();
  @override
  Future<CodexCliScanResult> scan(AiUsageDatabase db) async =>
      CodexCliScanResult.unavailable;
}

class _UnavailableAntigravityScanner extends AntigravityScanner {
  const _UnavailableAntigravityScanner();
  @override
  Future<AntigravityScanResult> scan(AiUsageDatabase db) async =>
      AntigravityScanResult.unavailable;
}

class _UnavailableOpencodeScanner extends OpencodeScanner {
  const _UnavailableOpencodeScanner();
  @override
  Future<OpencodeScanResult> scan(AiUsageDatabase db) async =>
      OpencodeScanResult.unavailable;
}

class _UnavailableFreebuffScanner extends FreebuffScanner {
  const _UnavailableFreebuffScanner();
  @override
  Future<FreebuffScanResult> scan(AiUsageDatabase db) async =>
      FreebuffScanResult.unavailable;
}

/// Regression test: the rescan + settings buttons in the AI Usage top bar
/// must sit flush against the right content edge.
///
/// The top bar's Row has two flex children (the range tabs and the Spacer
/// between the status text and the buttons). While the tabs were only
/// `Flexible`, the Row split the free width in half; the tabs' Wrap used
/// less than its share and the unused remainder surfaced as dead space
/// *after* the gear button, leaving both buttons visibly short of the
/// window's right edge. The tabs must be Expanded (tight) instead.
///
/// The assertion targets the [IconButton] render boxes (not the Tooltips,
/// which are inset by the buttons' internal padding): with the buttons'
/// symmetric padding, their layout slots ending at the content edge is what
/// "flush right" means for a trailing icon pair.
void main() {
  // The scan consults the app-wide storage cap, which only main.dart sets.
  setUpAll(() => StorageGuardService.instance = _NoScheduleStorageGuard());

  testWidgets('rescan and settings buttons are flush right in the top bar',
      (tester) async {
    tester.view.physicalSize = const Size(1652, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AiUsageDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: LumaTheme.from(Brightness.dark, null, LumaThemeStyle.standard),
        home: Scaffold(
          body: AiUsageScope(
            repository: AiUsageRepository(
              db,
              claudeScanner: _FoundClaudeScanner(db),
              codexScanner: const _UnavailableCodexScanner(),
              antigravityScanner: const _UnavailableAntigravityScanner(),
              opencodeScanner: const _UnavailableOpencodeScanner(),
              freebuffScanner: const _UnavailableFreebuffScanner(),
            ),
            child: const AiUsageDashboardTab(),
          ),
        ),
      ),
    );
    // First frame: loading spinner. The post-frame callback then kicks off
    // the (stubbed) scan; a couple of microtask-friendly pumps later the
    // dashboard body is up.
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final gearFinder = find.byTooltip('Usage display settings');
    expect(gearFinder, findsOneWidget, reason: 'dashboard body should be up');

    // The page adds its own 24px trailing padding; the buttons must stop at
    // the content edge inside it.
    final pageRight = tester.getRect(find.byType(AiUsageDashboardTab)).right;
    const trailingPadding = 24.0;
    final contentRight = pageRight - trailingPadding;

    final gearRect =
        tester.getRect(find.ancestor(of: gearFinder, matching: find.byType(IconButton)));
    expect(
      gearRect.right,
      moreOrLessEquals(contentRight, epsilon: 0.5),
      reason:
          'the settings button must end at the right content edge ($contentRight), '
          'not ${gearRect.right.toStringAsFixed(1)} — dead space after it means the '
          'top bar Row is splitting flex width with the range tabs again',
    );

    final refreshRect = tester.getRect(find
        .ancestor(of: find.byTooltip('Rescan local AI usage logs'),
            matching: find.byType(IconButton)));
    expect(
      refreshRect.right,
      moreOrLessEquals(gearRect.left, epsilon: 0.5),
      reason: 'the rescan button sits immediately left of the settings button',
    );
  });
}
