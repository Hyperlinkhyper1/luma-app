import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/luma_theme.dart';
import 'auto_clicker_repository.dart';
import 'auto_clicker_scope.dart';
import 'clicker_engine.dart';

/// The Auto Clicker plugin: automates mouse clicks at a configurable
/// interval, with a global hotkey (default F6) to start and stop clicking
/// from any window — not just while luma is focused.
class AutoClickerPage extends StatefulWidget {
  const AutoClickerPage({super.key});

  @override
  State<AutoClickerPage> createState() => _AutoClickerPageState();
}

class _AutoClickerPageState extends State<AutoClickerPage> {
  late final TextEditingController _hoursCtrl;
  late final TextEditingController _minutesCtrl;
  late final TextEditingController _secondsCtrl;
  late final TextEditingController _millisCtrl;
  late final TextEditingController _randomOffsetCtrl;
  late final TextEditingController _repeatCountCtrl;
  bool _controllersReady = false;

  int _pickCountdown = 0;
  Timer? _pickTimer;

  @override
  void dispose() {
    _pickTimer?.cancel();
    if (_controllersReady) {
      _hoursCtrl.dispose();
      _minutesCtrl.dispose();
      _secondsCtrl.dispose();
      _millisCtrl.dispose();
      _randomOffsetCtrl.dispose();
      _repeatCountCtrl.dispose();
    }
    super.dispose();
  }

  void _initControllers(AutoClickerRepository repo) {
    final ms = repo.intervalMs;
    final hours = ms ~/ 3600000;
    final minutes = (ms % 3600000) ~/ 60000;
    final seconds = (ms % 60000) ~/ 1000;
    final millis = ms % 1000;
    _hoursCtrl = TextEditingController(text: hours == 0 ? '' : '$hours');
    _minutesCtrl = TextEditingController(text: minutes == 0 ? '' : '$minutes');
    _secondsCtrl = TextEditingController(text: seconds == 0 ? '' : '$seconds');
    _millisCtrl = TextEditingController(text: '$millis');
    _randomOffsetCtrl = TextEditingController(
        text: repo.randomOffsetMs == 0 ? '' : '${repo.randomOffsetMs}');
    _repeatCountCtrl = TextEditingController(text: '${repo.repeatCount}');
    _controllersReady = true;
  }

  void _onIntervalChanged(AutoClickerRepository repo) {
    final h = int.tryParse(_hoursCtrl.text) ?? 0;
    final m = int.tryParse(_minutesCtrl.text) ?? 0;
    final s = int.tryParse(_secondsCtrl.text) ?? 0;
    final ms = int.tryParse(_millisCtrl.text) ?? 0;
    final total = h * 3600000 + m * 60000 + s * 1000 + ms;
    repo.setIntervalMs(total <= 0 ? 1 : total);
  }

  void _onRandomOffsetChanged(AutoClickerRepository repo) {
    final ms = int.tryParse(_randomOffsetCtrl.text) ?? 0;
    repo.setRandomOffsetMs(ms < 0 ? 0 : ms);
  }

  void _pickLocation(AutoClickerRepository repo) {
    _pickTimer?.cancel();
    setState(() => _pickCountdown = 3);
    _pickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final next = _pickCountdown - 1;
      if (next <= 0) {
        timer.cancel();
        final point = ClickerEngine.cursorPosition;
        setState(() => _pickCountdown = 0);
        if (point != null) repo.setFixedPoint(point);
      } else {
        setState(() => _pickCountdown = next);
      }
    });
  }

  Future<void> _rebindHotKey(AutoClickerRepository repo) async {
    HotKey? recorded;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final luma = dialogContext.luma;
        final t = L.of(dialogContext);
        return AlertDialog(
          backgroundColor: luma.surface,
          title: Text(t.autoClickerPressNewHotkey,
              style: TextStyle(color: luma.textPrimary, fontSize: 16)),
          content: SizedBox(
            width: lumaDialogWidth(dialogContext, 260),
            child: HotKeyRecorder(
              initalHotKey: repo.hotKey,
              onHotKeyRecorded: (hotKey) => recorded = hotKey,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(t.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(t.commonSave),
            ),
          ],
        );
      },
    );
    if (confirmed == true && recorded != null) {
      await repo.setHotKey(recorded!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repo = AutoClickerScope.of(context);
    final t = L.of(context);

    if (!repo.supported) {
      return LumaEmptyState(
        icon: Icons.desktop_windows_outlined,
        title: t.audioToolsWindowsOnly,
        subtitle: t.autoClickerWindowsOnlyBody,
      );
    }

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        if (!repo.loaded) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          );
        }
        if (!_controllersReady) _initControllers(repo);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _statusCard(luma, repo),
                  const SizedBox(height: 16),
                  _intervalCard(luma, repo),
                  const SizedBox(height: 16),
                  _clickCard(luma, repo),
                  const SizedBox(height: 16),
                  _locationCard(luma, repo),
                  const SizedBox(height: 16),
                  _repeatCard(luma, repo),
                  const SizedBox(height: 16),
                  _hotKeyCard(luma, repo),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _statusCard(LumaPalette luma, AutoClickerRepository repo) {
    final t = L.of(context);
    final running = repo.isRunning;
    final blocked = !repo.clickAtCursor && repo.fixedPoint == null;
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LumaIconBadge(
                icon: running ? Icons.pause_rounded : Icons.ads_click_rounded,
                color: running ? luma.danger : luma.accent,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      running ? t.autoClickerClicking : t.autoClickerStopped,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      running
                          ? t.autoClickerClicksSoFar(repo.clicksDone)
                          : t.autoClickerStartHint(repo.hotKey.debugName),
                      style: TextStyle(color: luma.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          running
              ? LumaGhostButton(
                  label: t.autoClickerStopClicking,
                  icon: Icons.stop_rounded,
                  onTap: repo.stop,
                )
              : LumaPrimaryButton(
                  label: t.autoClickerStartClicking,
                  icon: Icons.play_arrow_rounded,
                  onTap: blocked ? null : repo.start,
                ),
          if (!running && blocked) ...[
            const SizedBox(height: 10),
            Text(
              t.autoClickerPickFixedFirst,
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            ),
          ],
          if (repo.hotKeyError != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: luma.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    repo.hotKeyError!,
                    style: TextStyle(color: luma.danger, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _intervalCard(LumaPalette luma, AutoClickerRepository repo) {
    final t = L.of(context);
    final offset = repo.randomOffsetMs;
    final lowerBound = repo.intervalMs > offset ? repo.intervalMs - offset : 1;
    final help = offset == 0
        ? t.autoClickerRandomHelpExact
        : t.autoClickerRandomHelpRange(
            '$lowerBound',
            '${repo.intervalMs + offset}',
          );
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionLabel(luma, t.autoClickerClickEvery),
          Row(
            children: [
              Expanded(
                child: _intervalField(luma,
                    controller: _hoursCtrl,
                    label: t.autoClickerHours,
                    repo: repo),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _intervalField(luma,
                    controller: _minutesCtrl,
                    label: t.autoClickerMinutes,
                    repo: repo),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _intervalField(luma,
                    controller: _secondsCtrl,
                    label: t.autoClickerSeconds,
                    repo: repo),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _intervalField(luma,
                    controller: _millisCtrl,
                    label: t.autoClickerMillis,
                    repo: repo),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _sectionLabel(luma, t.autoClickerRandomOffset),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _randomOffsetCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: TextStyle(color: luma.textPrimary),
                  decoration: _inputDecoration(luma)
                      .copyWith(prefixText: '± ', prefixStyle: TextStyle(color: luma.textMuted)),
                  onChanged: (_) => _onRandomOffsetChanged(repo),
                ),
              ),
              const SizedBox(width: 10),
              Text(t.autoClickerMilliseconds,
                  style: TextStyle(color: luma.textSecondary, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            help,
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _intervalField(
    LumaPalette luma, {
    required TextEditingController controller,
    required String label,
    required AutoClickerRepository repo,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: TextStyle(color: luma.textPrimary),
          decoration: _inputDecoration(luma),
          onChanged: (_) => _onIntervalChanged(repo),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: luma.textMuted, fontSize: 11)),
      ],
    );
  }

  Widget _clickCard(LumaPalette luma, AutoClickerRepository repo) {
    final t = L.of(context);
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionLabel(luma, t.autoClickerMouseButton),
          LumaSegmentedTabs(
            tabs: [t.autoClickerLeft, t.autoClickerMiddle, t.autoClickerRight],
            selectedIndex: ClickButton.values.indexOf(repo.button),
            onSelect: (i) => repo.setButton(ClickButton.values[i]),
          ),
          const SizedBox(height: 18),
          _sectionLabel(luma, t.autoClickerClickType),
          LumaSegmentedTabs(
            tabs: [t.autoClickerSingle, t.autoClickerDouble],
            selectedIndex: repo.doubleClick ? 1 : 0,
            onSelect: (i) => repo.setDoubleClick(i == 1),
          ),
        ],
      ),
    );
  }

  Widget _locationCard(LumaPalette luma, AutoClickerRepository repo) {
    final t = L.of(context);
    final fixed = repo.fixedPoint;
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionLabel(luma, t.autoClickerClickLocation),
          LumaSegmentedTabs(
            tabs: [t.autoClickerCurrentCursor, t.autoClickerFixedPosition],
            selectedIndex: repo.clickAtCursor ? 0 : 1,
            onSelect: (i) => repo.setClickAtCursor(i == 0),
          ),
          if (!repo.clickAtCursor) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _pickCountdown > 0
                        ? t.autoClickerHoldCursor(_pickCountdown)
                        : (fixed != null
                            ? t.autoClickerTarget(
                                '${fixed.x}',
                                '${fixed.y}',
                              )
                            : t.autoClickerNoPositionYet),
                    style: TextStyle(color: luma.textSecondary, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 12),
                LumaGhostButton(
                  label: _pickCountdown > 0
                      ? t.autoClickerPicking
                      : t.autoClickerPickLocation,
                  icon: Icons.center_focus_strong_rounded,
                  onTap: _pickCountdown > 0 ? null : () => _pickLocation(repo),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _repeatCard(LumaPalette luma, AutoClickerRepository repo) {
    final t = L.of(context);
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionLabel(luma, t.autoClickerRepeat),
          LumaSegmentedTabs(
            tabs: [t.autoClickerUntilStopped, t.autoClickerSetAmount],
            selectedIndex: repo.repeatMode == ClickRepeatMode.count ? 1 : 0,
            onSelect: (i) => repo.setRepeatMode(
              i == 1 ? ClickRepeatMode.count : ClickRepeatMode.untilStopped,
            ),
          ),
          if (repo.repeatMode == ClickRepeatMode.count) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _repeatCountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: TextStyle(color: luma.textPrimary),
                    decoration: _inputDecoration(luma),
                    onChanged: (v) =>
                        repo.setRepeatCount(int.tryParse(v) ?? 1),
                  ),
                ),
                const SizedBox(width: 12),
                Text(t.autoClickerClicksTotal,
                    style: TextStyle(color: luma.textSecondary, fontSize: 13)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _hotKeyCard(LumaPalette luma, AutoClickerRepository repo) {
    final t = L.of(context);
    return LumaCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel(luma, t.autoClickerHotkeyLabel),
                HotKeyVirtualView(hotKey: repo.hotKey),
              ],
            ),
          ),
          LumaGhostButton(
            label: t.autoClickerChange,
            icon: Icons.keyboard_rounded,
            onTap: () => _rebindHotKey(repo),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(LumaPalette luma, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: luma.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      );

  InputDecoration _inputDecoration(LumaPalette luma) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c),
        );
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: luma.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      enabledBorder: border(luma.border),
      focusedBorder: border(luma.accent),
    );
  }
}
