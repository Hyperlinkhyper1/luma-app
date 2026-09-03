import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../theme/luma_theme.dart';
import '../github_models.dart';

/// Formatting and small widgets shared by every GitHub tab.
///
/// The look borrows GitHub's information design — a dense header strip, a
/// bordered list where each row is one repository or run, counts sitting
/// inline with their icon — while every colour comes from [LumaPalette], so
/// the section still reads as part of luma in all four themes.

// ---- formatting -------------------------------------------------------------

/// `1234` -> `1,234`. Grouping is what makes a five-digit star count
/// readable at a glance.
String formatCount(num value) {
  final negative = value < 0;
  final digits = value.abs().round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return negative ? '-$buffer' : buffer.toString();
}

/// Compact form for tiles where space is tight: `12.4k`, `3.1M`.
String formatCompact(num value) {
  final v = value.abs();
  if (v >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (v >= 10000) return '${(value / 1000).toStringAsFixed(0)}k';
  if (v >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
  return formatCount(value);
}

/// Trims a double to the fewest digits that still say something: `2` not
/// `2.00`, but `0.42` not `0`.
String formatDecimal(double value, {int decimals = 1}) {
  if (value == value.roundToDouble() && value.abs() < 100000) {
    return formatCount(value);
  }
  if (value.abs() < 1 && value != 0) return value.toStringAsFixed(2);
  return value.toStringAsFixed(decimals);
}

String formatMinutes(double minutes) {
  if (minutes < 60) return '${formatDecimal(minutes)} min';
  final hours = minutes / 60;
  return '${formatDecimal(hours)} h';
}

String formatBytesFromKb(int kilobytes) {
  if (kilobytes < 1024) return '$kilobytes KB';
  final mb = kilobytes / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  return '${(mb / 1024).toStringAsFixed(2)} GB';
}

String formatDuration(Duration d) {
  if (d.inSeconds < 60) return '${d.inSeconds}s';
  if (d.inMinutes < 60) return '${d.inMinutes}m ${d.inSeconds % 60}s';
  return '${d.inHours}h ${d.inMinutes % 60}m';
}

/// GitHub's "updated 3 days ago" phrasing.
String formatRelative(DateTime? when) {
  if (when == null) return 'unknown';
  final diff = DateTime.now().difference(when);
  if (diff.isNegative) return 'just now';
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) {
    return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
  }
  if (diff.inDays < 30) {
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }
  if (diff.inDays < 365) {
    final months = (diff.inDays / 30).floor();
    return '$months month${months == 1 ? '' : 's'} ago';
  }
  final years = (diff.inDays / 365).floor();
  return '$years year${years == 1 ? '' : 's'} ago';
}

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatDate(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

String monthLabel(int month) => _monthNames[month - 1];

/// A stable colour per language, so Dart is the same shade on every screen
/// and between sessions.
///
/// The hue is hashed from the name rather than copied from GitHub's linguist
/// palette: those colours are a data file with its own licence, and a
/// consistent hue is all this needs to do. Saturation and lightness are
/// fixed so every dot stays legible on both the light and dark surface.
Color languageColor(String language) {
  var hash = 0;
  for (final unit in language.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  final hue = (hash % 360).toDouble();
  return HSLColor.fromAHSL(1, hue, 0.62, 0.55).toColor();
}

/// Opens an external URL. Failures are swallowed on purpose — a browser that
/// will not open is not worth an error dialog over a link.
Future<void> openExternal(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

// ---- widgets ----------------------------------------------------------------

/// A headline number with its label, the way GitHub stacks counts across the
/// top of a profile.
class AccountStatTile extends StatelessWidget {
  const AccountStatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
    this.tint,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  final Color? tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;
    final color = tint ?? luma.accent;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: luma.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 24,
              height: 1.1,
              fontWeight: FontWeight.w700,
              // Tabular figures stop a refreshing counter from nudging the
              // tile's width around.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 4),
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: luma.textMuted, fontSize: 11),
            ),
          ],
        ],
      ),
    );

    return Semantics(
      label: '$label: $value${caption == null ? '' : '. $caption'}',
      button: onTap != null,
      child: Material(
        color: luma.surface,
        borderRadius: decor.cardBorderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: luma.surfaceHover,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: decor.cardBorderRadius,
              border: Border.all(color: luma.border, width: decor.borderWidth),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// An allowance meter: used against included, with the exact figures spelled
/// out above the bar.
///
/// [total] being null is a real state, not a bug — GitHub does not always
/// report an included allowance, and inventing a denominator would be worse
/// than showing the raw number. In that case this renders the usage figure
/// and an "add your allowance" hint instead of a bar.
class AccountMeter extends StatelessWidget {
  const AccountMeter({
    super.key,
    required this.label,
    required this.used,
    required this.total,
    required this.unit,
    this.icon,
    this.caption,
    this.onSetAllowance,
    this.formatter,
  });

  final String label;
  final double used;
  final double? total;
  final String unit;
  final IconData? icon;
  final String? caption;
  final VoidCallback? onSetAllowance;

  /// How to render a figure in this meter's unit. Defaults to [formatDecimal].
  final String Function(double)? formatter;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final format = formatter ?? formatDecimal;
    final ratio = (total == null || total! <= 0) ? null : (used / total!);

    // Approaching the cap is a warning, over it is a problem — and each
    // carries an icon so the state is never colour-only.
    final (Color barColor, IconData? statusIcon, String? statusText) =
        switch (ratio) {
      null => (luma.accent, null, null),
      >= 1.0 => (luma.danger, Icons.error_outline_rounded, 'Allowance used up'),
      >= 0.85 => (
          luma.warning,
          Icons.warning_amber_rounded,
          'Nearly at your allowance'
        ),
      _ => (luma.accent, null, null),
    };

    final percentLabel =
        ratio == null ? null : '${(ratio * 100).clamp(0, 999).round()}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: luma.textSecondary),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (percentLabel != null)
              Text(
                percentLabel,
                style: TextStyle(
                  color: barColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              format(used),
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                total == null
                    ? unit
                    : '$unit of ${format(total!)} included',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: luma.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (ratio != null)
          Semantics(
            label: '$label: ${format(used)} of ${format(total!)} $unit used, '
                '$percentLabel',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Stack(
                children: [
                  Container(height: 8, color: luma.surfaceHover),
                  LayoutBuilder(
                    builder: (context, constraints) => AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      height: 8,
                      width: constraints.maxWidth * ratio.clamp(0.0, 1.0),
                      color: barColor,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          _NoAllowanceHint(onTap: onSetAllowance),
        if (statusText != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(statusIcon, size: 14, color: barColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: barColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (caption != null) ...[
          const SizedBox(height: 8),
          Text(
            caption!,
            style: TextStyle(color: luma.textMuted, fontSize: 11, height: 1.4),
          ),
        ],
      ],
    );
  }
}

class _NoAllowanceHint extends StatelessWidget {
  const _NoAllowanceHint({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: luma.surfaceHover,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 14, color: luma.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'GitHub did not report an included allowance.',
              style: TextStyle(color: luma.textSecondary, fontSize: 11),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            AccountLinkButton(label: 'Set it', onTap: onTap!),
          ],
        ],
      ),
    );
  }
}

/// A text action styled like a GitHub link, with a real 44px tap target
/// around its much smaller label.
class AccountLinkButton extends StatelessWidget {
  const AccountLinkButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: luma.surfaceHover,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 14, color: luma.accent),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: luma.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

/// A small pill, GitHub's "Public"/"Archived"/"Fork" repository labels.
class AccountBadge extends StatelessWidget {
  const AccountBadge({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.filled = false,
  });

  final String label;
  final Color? color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final tint = color ?? luma.textSecondary;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: icon == null ? 8 : 7, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? tint.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: filled ? 0.3 : 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: tint),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: tint,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// The "12 stars" pairing GitHub repeats under every repository.
class AccountMetaCount extends StatelessWidget {
  const AccountMetaCount({
    super.key,
    required this.icon,
    required this.value,
    required this.semanticLabel,
    this.color,
  });

  final IconData icon;
  final String value;
  final String semanticLabel;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Semantics(
      label: semanticLabel,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color ?? luma.textMuted),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: luma.textSecondary,
              fontSize: 12,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled panel with the section's own header row — GitHub's boxed lists.
class AccountPanel extends StatelessWidget {
  const AccountPanel({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.subtitle,
    this.trailing,
    this.padding,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;
    return Container(
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: decor.cardBorderRadius,
        border: Border.all(color: luma.border, width: decor.borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
            decoration: BoxDecoration(
              color: luma.surfaceHover.withValues(alpha: 0.55),
              border: Border(bottom: BorderSide(color: luma.border)),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: luma.textSecondary),
                  const SizedBox(width: 9),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style:
                              TextStyle(color: luma.textMuted, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// The contribution calendar: 53 weeks of squares, one column per week.
///
/// Rebuilt rather than borrowed — the widget takes plain day counts and
/// derives its own five intensity levels from [LumaPalette.accent], so it
/// themes with the app instead of pinning GitHub's greens.
class GithubContributionGraph extends StatelessWidget {
  const GithubContributionGraph({super.key, required this.contributions});

  final GithubContributions contributions;

  static const _cell = 11.0;
  static const _gap = 3.0;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final days = contributions.days;
    if (days.isEmpty) {
      return Text(
        'No contribution data yet.',
        style: TextStyle(color: luma.textMuted, fontSize: 12),
      );
    }

    // GitHub's calendar starts on a Sunday; pad the first column so every
    // row is genuinely one weekday.
    final leading = days.first.date.weekday % 7;
    final padded = <GithubContributionDay?>[
      ...List<GithubContributionDay?>.filled(leading, null),
      ...days,
    ];
    final weeks = <List<GithubContributionDay?>>[];
    for (var i = 0; i < padded.length; i += 7) {
      weeks.add(padded.sublist(i, (i + 7).clamp(0, padded.length)));
    }

    final busiest = contributions.busiestDay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wide content scrolls inside its own box rather than pushing the
        // page sideways.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MonthLabels(weeks: weeks, cell: _cell, gap: _gap),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _WeekdayLabels(cell: _cell, gap: _gap),
                  const SizedBox(width: 6),
                  for (final week in weeks)
                    Padding(
                      padding: const EdgeInsets.only(right: _gap),
                      child: Column(
                        children: [
                          for (var weekday = 0; weekday < 7; weekday++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: _gap),
                              child: _DayCell(
                                day: weekday < week.length
                                    ? week[weekday]
                                    : null,
                                busiest: busiest,
                                size: _cell,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _Legend(busiest: busiest),
      ],
    );
  }
}

class _MonthLabels extends StatelessWidget {
  const _MonthLabels({required this.weeks, required this.cell, required this.gap});

  final List<List<GithubContributionDay?>> weeks;
  final double cell;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    // A label goes above the first week that opens a new month, which is how
    // GitHub places them.
    var lastMonth = -1;
    final labels = <Widget>[const SizedBox(width: 24 + 6)];
    for (final week in weeks) {
      final first = week.firstWhere((d) => d != null, orElse: () => null);
      final month = first?.date.month ?? -1;
      final isNew = month != -1 && month != lastMonth;
      if (isNew) lastMonth = month;
      labels.add(SizedBox(
        width: cell + gap,
        child: isNew
            ? Text(
                monthLabel(month),
                style: TextStyle(color: luma.textMuted, fontSize: 9.5),
              )
            : null,
      ));
    }
    return SizedBox(height: 13, child: Row(children: labels));
  }
}

class _WeekdayLabels extends StatelessWidget {
  const _WeekdayLabels({required this.cell, required this.gap});

  final double cell;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    const labels = ['', 'Mon', '', 'Wed', '', 'Fri', ''];
    return SizedBox(
      width: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final label in labels)
            SizedBox(
              height: cell + gap,
              child: Text(
                label,
                style: TextStyle(color: luma.textMuted, fontSize: 9.5),
              ),
            ),
        ],
      ),
    );
  }
}

/// One square. Its colour is an intensity, and its tooltip is the exact
/// count — the graph is never the only way to read a day.
class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.busiest, required this.size});

  final GithubContributionDay? day;
  final int busiest;
  final double size;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    if (day == null) {
      return SizedBox(width: size, height: size);
    }

    final count = day!.count;
    final level = _level(count, busiest);
    final color = level == 0
        ? Color.lerp(luma.surfaceHover, luma.border, 0.5)!
        : Color.lerp(
            luma.accent.withValues(alpha: 0.22),
            luma.accent,
            (level - 1) / 3,
          )!;

    final label = count == 0
        ? 'No contributions on ${formatDate(day!.date)}'
        : '$count contribution${count == 1 ? '' : 's'} on '
            '${formatDate(day!.date)}';

    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 250),
      child: Semantics(
        label: label,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
      ),
    );
  }

  /// Buckets relative to the busiest day, so a quiet year still shows shape
  /// instead of flattening into one shade.
  static int _level(int count, int busiest) {
    if (count <= 0) return 0;
    if (busiest <= 0) return 1;
    final ratio = count / busiest;
    if (ratio > 0.66) return 4;
    if (ratio > 0.33) return 3;
    if (ratio > 0.12) return 2;
    return 1;
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.busiest});

  final int busiest;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('Less', style: TextStyle(color: luma.textMuted, fontSize: 10)),
        const SizedBox(width: 6),
        for (var level = 0; level < 5; level++) ...[
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: level == 0
                  ? Color.lerp(luma.surfaceHover, luma.border, 0.5)!
                  : Color.lerp(
                      luma.accent.withValues(alpha: 0.22),
                      luma.accent,
                      (level - 1) / 3,
                    )!,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
        ],
        const SizedBox(width: 6),
        Text('More', style: TextStyle(color: luma.textMuted, fontSize: 10)),
      ],
    );
  }
}

/// The inline warning strip used when one section of a refresh failed but
/// the rest of the page is fine.
class AccountNotice extends StatelessWidget {
  const AccountNotice({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.tone,
    this.onDismiss,
    this.action,
  });

  final String message;
  final IconData icon;
  final Color? tone;
  final VoidCallback? onDismiss;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final color = tone ?? luma.warning;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: luma.textSecondary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
          ?action,
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, size: 16),
              color: luma.textMuted,
              tooltip: 'Dismiss',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
        ],
      ),
    );
  }
}
