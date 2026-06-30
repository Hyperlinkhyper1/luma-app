import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../theme/luma_theme.dart';
import '../converter_widgets.dart';
import '../downscaler_service.dart';
import '../file_saver.dart';
import '../media/ffmpeg_service.dart';

/// The individual optimizations, in display order.
enum DsOption {
  resize,
  reduceColors,
  reduceBitDepth,
  stripMetadata,
  removeAlpha,
  trim,
  pngRecompress,
  toWebp,
}

/// Picture downscaler: stack size-reducing optimizations with live, computed
/// savings estimates per option.
class DownscalerView extends StatefulWidget {
  const DownscalerView({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  State<DownscalerView> createState() => _DownscalerViewState();
}

class _DownscalerViewState extends State<DownscalerView> {
  Uint8List? _bytes;
  String? _name;
  int _originalSize = 0;

  ImageProbe? _probe;
  bool _probing = false;
  bool _ffmpegReady = false;

  DownscaleParams _params = const DownscaleParams();

  /// Standalone byte size of each option applied on its own (null = computing).
  final Map<DsOption, int?> _optionSize = {};

  int? _estimatedSize;
  bool _estimating = false;
  Timer? _debounce;

  /// Bumped whenever a new image loads, to discard stale async results.
  int _gen = 0;

  bool _applying = false;
  String? _error;
  SaveResult? _result;

  @override
  void initState() {
    super.initState();
    _checkFfmpeg();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _checkFfmpeg() async {
    if (kIsWeb) return;
    final ready = await Ffmpeg.available();
    if (!mounted) return;
    setState(() => _ffmpegReady = ready);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _error = 'Could not read the selected file.');
      return;
    }

    setState(() {
      _bytes = bytes;
      _name = file.name;
      _originalSize = file.size;
      _params = const DownscaleParams();
      _probe = null;
      _probing = true;
      _optionSize.clear();
      _estimatedSize = null;
      _result = null;
      _error = null;
      _gen++;
    });

    final gen = _gen;
    final probe = await DownscalerService.probe(bytes);
    if (!mounted || gen != _gen) return;
    setState(() {
      _probing = false;
      _probe = probe;
      _error = probe.decodable
          ? null
          : 'Could not read this image — it may be corrupt or unsupported.';
    });
    if (probe.decodable) _computeAllOptionEstimates();
  }

  bool _enabledFor(DsOption o) {
    final probe = _probe;
    if (probe == null) return false;
    switch (o) {
      case DsOption.removeAlpha:
        return probe.hasAlpha && probe.fullyOpaque;
      case DsOption.trim:
        return probe.transparentBorder;
      case DsOption.toWebp:
        return !kIsWeb && _ffmpegReady;
      default:
        return true;
    }
  }

  /// Params with only [o] applied, at its current slider value.
  DownscaleParams _soloParams(DsOption o) {
    const base = DownscaleParams();
    switch (o) {
      case DsOption.resize:
        return base.copyWith(resize: true, scalePercent: _params.scalePercent);
      case DsOption.reduceColors:
        return base.copyWith(
            reduceColors: true, colors: _params.colors, dither: _params.dither);
      case DsOption.reduceBitDepth:
        return base.copyWith(
            reduceBitDepth: true, bitsPerChannel: _params.bitsPerChannel);
      case DsOption.stripMetadata:
        return base.copyWith(stripMetadata: true);
      case DsOption.removeAlpha:
        return base.copyWith(removeAlpha: true);
      case DsOption.trim:
        return base.copyWith(trim: true);
      case DsOption.pngRecompress:
        return base.copyWith(pngRecompress: true);
      case DsOption.toWebp:
        return base.copyWith(toWebp: true);
    }
  }

  Future<void> _computeAllOptionEstimates() async {
    for (final o in DsOption.values) {
      if (!_enabledFor(o)) continue;
      await _computeOptionEstimate(o);
    }
  }

  Future<void> _computeOptionEstimate(DsOption o) async {
    final bytes = _bytes;
    if (bytes == null) return;
    final gen = _gen;
    setState(() => _optionSize[o] = null);
    try {
      final size = await _renderSize(bytes, _soloParams(o));
      if (!mounted || gen != _gen) return;
      setState(() => _optionSize[o] = size);
    } catch (_) {
      if (!mounted || gen != _gen) return;
      setState(() => _optionSize.remove(o));
    }
  }

  /// Renders [params] and returns the resulting byte length, routing through
  /// ffmpeg when WebP output is selected.
  Future<int> _renderSize(Uint8List bytes, DownscaleParams params) async {
    final out = await _renderBytes(bytes, params);
    return out.length;
  }

  Future<Uint8List> _renderBytes(
      Uint8List bytes, DownscaleParams params) async {
    final png = await DownscalerService.renderPng(bytes, params);
    if (!params.toWebp) return png;
    return Ffmpeg.transcode(
      input: png,
      inputExtension: 'png',
      outputExtension: 'webp',
      args: const ['-c:v', 'libwebp', '-lossless', '1'],
    );
  }

  void _onParamsChanged(DownscaleParams next, {DsOption? recompute}) {
    setState(() => _params = next);
    if (recompute != null) _computeOptionEstimate(recompute);
    _scheduleCombined();
  }

  void _scheduleCombined() {
    _debounce?.cancel();
    if (!_anySelected) {
      setState(() {
        _estimatedSize = null;
        _estimating = false;
      });
      return;
    }
    setState(() => _estimating = true);
    _debounce = Timer(const Duration(milliseconds: 300), _computeCombined);
  }

  Future<void> _computeCombined() async {
    final bytes = _bytes;
    if (bytes == null) return;
    final gen = _gen;
    try {
      final size = await _renderSize(bytes, _params);
      if (!mounted || gen != _gen) return;
      setState(() {
        _estimatedSize = size;
        _estimating = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _estimating = false;
        _error = 'Could not estimate size: $e';
      });
    }
  }

  bool get _anySelected =>
      _params.resize ||
      _params.reduceColors ||
      _params.reduceBitDepth ||
      _params.stripMetadata ||
      _params.removeAlpha ||
      _params.trim ||
      _params.pngRecompress ||
      _params.toWebp;

  bool _isChecked(DsOption o) => switch (o) {
        DsOption.resize => _params.resize,
        DsOption.reduceColors => _params.reduceColors,
        DsOption.reduceBitDepth => _params.reduceBitDepth,
        DsOption.stripMetadata => _params.stripMetadata,
        DsOption.removeAlpha => _params.removeAlpha,
        DsOption.trim => _params.trim,
        DsOption.pngRecompress => _params.pngRecompress,
        DsOption.toWebp => _params.toWebp,
      };

  void _toggle(DsOption o, bool value) {
    switch (o) {
      case DsOption.resize:
        _onParamsChanged(_params.copyWith(
          resize: value,
          scalePercent: value && _params.scalePercent == 100
              ? 50
              : _params.scalePercent,
        ));
      case DsOption.reduceColors:
        _onParamsChanged(_params.copyWith(
          reduceColors: value,
          colors: value && _params.colors == 256 ? 64 : _params.colors,
        ));
      case DsOption.reduceBitDepth:
        _onParamsChanged(_params.copyWith(reduceBitDepth: value));
      case DsOption.stripMetadata:
        _onParamsChanged(_params.copyWith(stripMetadata: value));
      case DsOption.removeAlpha:
        _onParamsChanged(_params.copyWith(removeAlpha: value));
      case DsOption.trim:
        _onParamsChanged(_params.copyWith(trim: value));
      case DsOption.pngRecompress:
        _onParamsChanged(_params.copyWith(pngRecompress: value));
      case DsOption.toWebp:
        _onParamsChanged(_params.copyWith(toWebp: value));
    }
  }

  Future<void> _apply() async {
    final bytes = _bytes;
    final name = _name;
    if (bytes == null || name == null) return;
    setState(() {
      _applying = true;
      _error = null;
      _result = null;
    });
    try {
      final out = await _renderBytes(bytes, _params);
      final ext = _params.toWebp ? 'webp' : 'png';
      final mime = _params.toWebp ? 'image/webp' : 'image/png';
      final save = await saveConvertedFile(
        bytes: out,
        suggestedName: '${_stripExtension(name)}-optimized.$ext',
        mimeType: mime,
        extensions: [ext],
      );
      if (!mounted) return;
      setState(() {
        _applying = false;
        _result = save;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _applying = false;
        _error = 'Something went wrong: $e';
      });
    }
  }

  void _reset() {
    setState(() {
      _bytes = null;
      _name = null;
      _originalSize = 0;
      _probe = null;
      _params = const DownscaleParams();
      _optionSize.clear();
      _estimatedSize = null;
      _result = null;
      _error = null;
      _gen++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return ToolScaffold(
      icon: Icons.compress_rounded,
      title: 'Image downscaler',
      subtitle: 'Shrink image file size with stackable optimizations',
      onBack: widget.onBack,
      children: [
        if (_bytes == null)
          ConverterDropZone(
            onTap: _pickFile,
            icon: Icons.tune_rounded,
            title: 'Click to choose an image',
            subtitle: 'PNG or JPEG',
          )
        else
          ConverterFileCard(
            name: _name!,
            thumbnail: _bytes,
            meta: _probe == null
                ? formatBytes(_originalSize)
                : '${_probe!.width}×${_probe!.height} · ${formatBytes(_originalSize)}',
            onChange: _pickFile,
          ),
        if (_probing) ...[
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.4, color: luma.accent),
            ),
          ),
        ],
        if (_probe?.decodable == true) ...[
          const SizedBox(height: 16),
          _OptionsCard(
            view: this,
          ),
          const SizedBox(height: 16),
          _EstimateCard(
            originalSize: _originalSize,
            estimatedSize: _estimatedSize,
            estimating: _estimating,
            anySelected: _anySelected,
            applying: _applying,
            outputLabel: _params.toWebp ? 'WEBP' : 'PNG',
            onApply: _anySelected ? _apply : null,
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          ConverterBanner(
            icon: Icons.error_outline_rounded,
            color: luma.danger,
            message: _error!,
          ),
        ],
        if (_result != null && _result!.saved) ...[
          const SizedBox(height: 16),
          ConverterBanner(
            icon: Icons.check_circle_outline_rounded,
            color: luma.success,
            message: _result!.summary,
            trailing:
                ConverterTextButton(label: 'Optimize another', onTap: _reset),
          ),
        ],
      ],
    );
  }
}

/// Card listing every optimization with its checkbox, tooltip and savings chip.
class _OptionsCard extends StatelessWidget {
  const _OptionsCard({required this.view});
  final _DownscalerViewState view;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return ConverterCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Optimizations',
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Stack any of these. Hover for details; chips show what each saves '
            'on its own.',
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          for (final o in DsOption.values) ...[
            Divider(color: luma.border, height: 20),
            _OptionRow(view: view, option: o),
          ],
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.view, required this.option});
  final _DownscalerViewState view;
  final DsOption option;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final meta = _optionMeta[option]!;
    final enabled = view._enabledFor(option);
    final checked = view._isChecked(option) && enabled;
    final savings = enabled ? view._optionSize[option] : null;
    final computing = enabled && view._optionSize[option] == null;

    final subtitle = enabled ? meta.explanation : (meta.disabledNote ?? meta.explanation);

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Tooltip(
            message: subtitle,
            waitDuration: const Duration(milliseconds: 250),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _Check(
                  value: checked,
                  onChanged:
                      enabled ? (v) => view._toggle(option, v) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              meta.title,
                              style: TextStyle(
                                color: luma.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.help_outline_rounded,
                              size: 13, color: luma.textMuted),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(color: luma.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _SavingsChip(
                  computing: computing && enabled,
                  optionSize: savings,
                  originalSize: view._originalSize,
                  enabled: enabled,
                ),
              ],
            ),
          ),
          if (checked) _slider(context),
        ],
      ),
    );
  }

  Widget _slider(BuildContext context) {
    switch (option) {
      case DsOption.resize:
        return _LabeledSlider(
          label: 'Scale',
          valueLabel: '${view._params.scalePercent}%',
          value: view._params.scalePercent.toDouble(),
          min: 10,
          max: 100,
          divisions: 18,
          onChanged: (v) => view._onParamsChanged(
            view._params.copyWith(scalePercent: v.round()),
            recompute: DsOption.resize,
          ),
        );
      case DsOption.reduceColors:
        final idx = DownscalerService.colorStops.indexOf(view._params.colors);
        return Column(
          children: [
            _LabeledSlider(
              label: 'Colors',
              valueLabel: '${view._params.colors}',
              value: (idx < 0 ? DownscalerService.colorStops.length - 1 : idx)
                  .toDouble(),
              min: 0,
              max: (DownscalerService.colorStops.length - 1).toDouble(),
              divisions: DownscalerService.colorStops.length - 1,
              onChanged: (v) => view._onParamsChanged(
                view._params
                    .copyWith(colors: DownscalerService.colorStops[v.round()]),
                recompute: DsOption.reduceColors,
              ),
            ),
            _MiniToggle(
              label: 'Dithering',
              value: view._params.dither,
              onChanged: (v) => view._onParamsChanged(
                view._params.copyWith(dither: v),
                recompute: DsOption.reduceColors,
              ),
            ),
          ],
        );
      case DsOption.reduceBitDepth:
        final idx =
            DownscalerService.bitStops.indexOf(view._params.bitsPerChannel);
        const labels = {8: '32-bit', 4: '16-bit', 2: '8-bit'};
        return _LabeledSlider(
          label: 'Depth',
          valueLabel: labels[view._params.bitsPerChannel] ?? '',
          value: (idx < 0 ? 1 : idx).toDouble(),
          min: 0,
          max: (DownscalerService.bitStops.length - 1).toDouble(),
          divisions: DownscalerService.bitStops.length - 1,
          onChanged: (v) => view._onParamsChanged(
            view._params
                .copyWith(bitsPerChannel: DownscalerService.bitStops[v.round()]),
            recompute: DsOption.reduceBitDepth,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _SavingsChip extends StatelessWidget {
  const _SavingsChip({
    required this.computing,
    required this.optionSize,
    required this.originalSize,
    required this.enabled,
  });
  final bool computing;
  final int? optionSize;
  final int originalSize;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    if (!enabled) {
      return Text('—', style: TextStyle(color: luma.textMuted, fontSize: 12));
    }
    if (computing || optionSize == null) {
      return SizedBox(
        width: 14,
        height: 14,
        child:
            CircularProgressIndicator(strokeWidth: 2, color: luma.textMuted),
      );
    }
    final saved = originalSize - optionSize!;
    final pct = originalSize == 0 ? 0.0 : saved / originalSize * 100;
    final positive = saved > 0;
    final color = positive ? luma.success : luma.textMuted;
    final label = positive
        ? '−${pct.toStringAsFixed(0)}%'
        : (saved == 0 ? '0%' : '+${(-pct).toStringAsFixed(0)}%');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EstimateCard extends StatelessWidget {
  const _EstimateCard({
    required this.originalSize,
    required this.estimatedSize,
    required this.estimating,
    required this.anySelected,
    required this.applying,
    required this.outputLabel,
    required this.onApply,
  });

  final int originalSize;
  final int? estimatedSize;
  final bool estimating;
  final bool anySelected;
  final bool applying;
  final String outputLabel;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final saved =
        estimatedSize == null ? null : originalSize - estimatedSize!;
    final pct = (saved == null || originalSize == 0)
        ? null
        : saved / originalSize * 100;

    return ConverterCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _SizeColumn(
                  label: 'Original',
                  value: formatBytes(originalSize),
                  color: luma.textPrimary,
                ),
              ),
              Icon(Icons.arrow_forward_rounded,
                  color: luma.textSecondary, size: 20),
              Expanded(
                child: _SizeColumn(
                  label: 'Estimated ($outputLabel)',
                  value: !anySelected
                      ? '—'
                      : (estimating || estimatedSize == null
                          ? '…'
                          : formatBytes(estimatedSize!)),
                  color: luma.accent,
                  alignEnd: true,
                ),
              ),
            ],
          ),
          if (pct != null && !estimating) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (pct > 0 ? luma.success : luma.danger)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    pct > 0
                        ? Icons.trending_down_rounded
                        : Icons.trending_up_rounded,
                    size: 16,
                    color: pct > 0 ? luma.success : luma.danger,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    pct > 0
                        ? 'Saves ${pct.toStringAsFixed(0)}% (${formatBytes(saved!)})'
                        : '${(-pct).toStringAsFixed(0)}% larger than the original',
                    style: TextStyle(
                      color: pct > 0 ? luma.success : luma.danger,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          ConverterPrimaryButton(
            label: kIsWeb ? 'Optimize & download' : 'Optimize & save',
            icon: Icons.compress_rounded,
            loading: applying,
            onTap: onApply,
          ),
          if (!anySelected) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Select at least one optimization',
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SizeColumn extends StatelessWidget {
  const _SizeColumn({
    required this.label,
    required this.value,
    required this.color,
    this.alignEnd = false,
  });
  final String label;
  final String value;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: luma.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: onChanged == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: value ? luma.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: value ? luma.accent : luma.border,
              width: 1.5,
            ),
          ),
          child: value
              ? Icon(Icons.check_rounded, size: 16, color: luma.onAccent)
              : null,
        ),
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.only(left: 34, top: 6),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(label,
                style: TextStyle(color: luma.textSecondary, fontSize: 12)),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              valueLabel,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniToggle extends StatelessWidget {
  const _MiniToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.only(left: 34, top: 2, bottom: 4),
      child: Row(
        children: [
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: luma.onAccent,
              activeTrackColor: luma.accent,
            ),
          ),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(color: luma.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

/// Static copy for each option.
class _OptionMeta {
  const _OptionMeta(this.title, this.explanation, [this.disabledNote]);
  final String title;
  final String explanation;
  final String? disabledNote;
}

const _optionMeta = <DsOption, _OptionMeta>{
  DsOption.resize: _OptionMeta(
    'Resize resolution',
    'Scale the pixel dimensions down. Fewer pixels is usually the single '
        'biggest size saver.',
  ),
  DsOption.reduceColors: _OptionMeta(
    'Reduce color depth',
    'Map the image onto a small color palette (e.g. 64 or 16 colors). Great '
        'for flat graphics and screenshots.',
  ),
  DsOption.reduceBitDepth: _OptionMeta(
    'Reduce bit depth',
    'Keep fewer bits per color channel (32 → 16 → 8-bit). Slightly banded but '
        'compresses much better.',
  ),
  DsOption.stripMetadata: _OptionMeta(
    'Strip metadata',
    'Remove the embedded ICC profile, EXIF and text chunks. No visible change.',
  ),
  DsOption.removeAlpha: _OptionMeta(
    'Remove alpha channel',
    'Drop the transparency channel. Only offered when the image is fully '
        'opaque, so it is lossless.',
    'Unavailable — this image either has no alpha channel or uses real '
        'transparency.',
  ),
  DsOption.trim: _OptionMeta(
    'Trim transparent borders',
    'Crop away fully transparent edges around the image.',
    'Unavailable — no transparent border to trim.',
  ),
  DsOption.pngRecompress: _OptionMeta(
    'PNG lossless re-compress',
    'Re-encode the PNG at maximum compression. Safe, no visible change.',
  ),
  DsOption.toWebp: _OptionMeta(
    'Convert to WebP',
    'Encode the result as WebP, which is often much smaller than PNG.',
    'Unavailable — WebP needs ffmpeg (desktop app only).',
  ),
};

String _stripExtension(String name) {
  final dot = name.lastIndexOf('.');
  return dot <= 0 ? name : name.substring(0, dot);
}
