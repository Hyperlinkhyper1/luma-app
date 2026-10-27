import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import '../team_clipboard_models.dart';

IconData teamKindIcon(TeamEntryKind kind) => switch (kind) {
  TeamEntryKind.bug => Icons.bug_report_rounded,
  TeamEntryKind.suggestion => Icons.lightbulb_rounded,
  TeamEntryKind.model => Icons.view_in_ar_rounded,
};

Color teamKindColor(TeamEntryKind kind, LumaPalette luma) => switch (kind) {
  TeamEntryKind.bug => luma.danger,
  TeamEntryKind.suggestion => luma.warning,
  TeamEntryKind.model => luma.accent,
};

String teamKindLabel(L t, TeamEntryKind kind) => switch (kind) {
  TeamEntryKind.bug => t.teamClipboardKindBug,
  TeamEntryKind.suggestion => t.teamClipboardKindSuggestion,
  TeamEntryKind.model => t.teamClipboardKindModel,
};

/// A stage's name for [kind]: a bug is open and fixed rather than an idea
/// and added.
String teamStageLabel(L t, TeamEntryStage stage, TeamEntryKind kind) {
  final bug = kind == TeamEntryKind.bug;
  return switch (stage) {
    TeamEntryStage.idea =>
      bug ? t.teamClipboardStageOpen : t.teamClipboardStageIdea,
    TeamEntryStage.claimed => t.teamClipboardStageClaimed,
    TeamEntryStage.done => t.teamClipboardStageDone,
    TeamEntryStage.added =>
      bug ? t.teamClipboardStageFixed : t.teamClipboardStageAdded,
  };
}

IconData teamStageIcon(TeamEntryStage stage) => switch (stage) {
  TeamEntryStage.idea => Icons.radio_button_unchecked_rounded,
  TeamEntryStage.claimed => Icons.pan_tool_alt_rounded,
  TeamEntryStage.done => Icons.check_circle_outline_rounded,
  TeamEntryStage.added => Icons.verified_rounded,
};

Color teamStageColor(TeamEntryStage stage, LumaPalette luma) => switch (stage) {
  TeamEntryStage.idea => luma.textSecondary,
  TeamEntryStage.claimed => luma.accent,
  TeamEntryStage.done => luma.success,
  TeamEntryStage.added => luma.success,
};

/// The colours a team tag can pick from, by index; the server keeps only
/// the index (fewer than its `kTeamBoardTagColors`).
List<Color> teamTagPalette(LumaPalette luma) => [
  luma.accent,
  luma.success,
  luma.warning,
  luma.danger,
  const Color(0xFF4F9DF0),
  const Color(0xFFE477B0),
  const Color(0xFF2BB5A8),
  luma.textSecondary,
];

Color teamTagColor(int index, LumaPalette luma) {
  final palette = teamTagPalette(luma);
  return palette[index.clamp(0, palette.length - 1)];
}

/// The darker surface finished entries sit on, so the work still to do
/// stands out above them in either theme.
Color teamFinishedSurface(BuildContext context) {
  final luma = context.luma;
  final dark = Theme.of(context).brightness == Brightness.dark;
  return Color.lerp(luma.surface, Colors.black, dark ? 0.38 : 0.07)!;
}

/// "by name", or the stand-in for a deleted account.
/// The warning shown when a Discord post lacks the file its forum asks for.
String? teamDiscordMissingLabel(L t, TeamDiscordMissing missing) =>
    switch (missing) {
      TeamDiscordMissing.none => null,
      TeamDiscordMissing.image => t.teamClipboardMissingImage,
      TeamDiscordMissing.log => t.teamClipboardMissingLog,
      TeamDiscordMissing.both => t.teamClipboardMissingBoth,
      TeamDiscordMissing.either => t.teamClipboardMissingEither,
    };

String teamPerson(L t, String name) =>
    name.isEmpty ? t.teamClipboardFormerMember : name;

String teamRelativeTime(BuildContext context, DateTime when) {
  final t = L.of(context);
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) return t.commonJustNow;
  if (diff.inHours < 1) return t.commonMinutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return t.commonHoursAgo(diff.inHours);
  if (diff.inDays < 7) return t.commonDaysAgo(diff.inDays);
  return MaterialLocalizations.of(context).formatShortDate(when);
}

String teamFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// A small rounded label with an icon, for kinds and stages.
class TeamPill extends StatelessWidget {
  const TeamPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.filled = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: filled ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// The checkerboard behind a texture, so transparent pixels read as
/// transparent.
class TeamCheckerboard extends CustomPainter {
  const TeamCheckerboard(this.a, this.b, {this.cell = 6});

  final Color a;
  final Color b;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = a);
    final paint = Paint()..color = b;
    for (var y = 0.0; y < size.height; y += cell) {
      for (
        var x = ((y / cell).floor().isOdd ? cell : 0.0);
        x < size.width;
        x += cell * 2
      ) {
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), paint);
      }
    }
  }

  @override
  bool shouldRepaint(TeamCheckerboard old) =>
      old.a != a || old.b != b || old.cell != cell;
}

/// A team tag as a small coloured label.
class TeamTagChip extends StatelessWidget {
  const TeamTagChip({super.key, required this.name, required this.color});

  final String name;
  final int color;

  @override
  Widget build(BuildContext context) {
    final c = teamTagColor(color, context.luma);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
