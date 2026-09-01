import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../account_overview_scope.dart';
import 'account_shared.dart';

/// Asks for a personal access token and connects the account.
Future<void> showGithubConnectDialog(BuildContext context) => showDialog<void>(
      context: context,
      builder: (_) => AccountOverviewScope(
        repository: AccountOverviewScope.of(context),
        child: const _GithubConnectDialog(),
      ),
    );

class _GithubConnectDialog extends StatefulWidget {
  const _GithubConnectDialog();

  @override
  State<_GithubConnectDialog> createState() => _GithubConnectDialogState();
}

class _GithubConnectDialogState extends State<_GithubConnectDialog> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _obscured = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final repository = AccountOverviewScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await repository.connect(_controller.text);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      // Validation failures belong next to the field that caused them, not
      // in a toast that vanishes before it is read.
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repository = AccountOverviewScope.of(context);
    final existing = repository.credentials;

    return AlertDialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: context.lumaDecor.cardBorderRadius,
        side: BorderSide(color: luma.border),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
      title: Row(
        children: [
          Icon(Icons.hub_rounded, size: 20, color: luma.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              existing == null ? 'Connect GitHub' : 'Reconnect GitHub',
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (existing != null) ...[
                AccountNotice(
                  icon: Icons.check_circle_outline_rounded,
                  tone: luma.success,
                  message: 'Connected as ${existing.login} with a token ending '
                      '${existing.maskedToken.substring(existing.maskedToken.length - 4)}. '
                      'Pasting a new token replaces it.',
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'Personal access token',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                focusNode: _focus,
                autofocus: true,
                obscureText: _obscured,
                enabled: !_busy,
                onSubmitted: (_) => _submit(),
                style: TextStyle(color: luma.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'ghp_… or github_pat_…',
                  hintStyle: TextStyle(color: luma.textMuted, fontSize: 13),
                  errorText: _error,
                  errorMaxLines: 4,
                  filled: true,
                  fillColor: luma.background,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: luma.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: luma.accent, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: luma.danger),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: luma.danger, width: 2),
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: _obscured ? 'Show token' : 'Hide token',
                        onPressed: () => setState(() => _obscured = !_obscured),
                        icon: Icon(
                          _obscured
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 18,
                        ),
                        color: luma.textMuted,
                      ),
                      IconButton(
                        tooltip: 'Paste',
                        onPressed: _busy
                            ? null
                            : () async {
                                final data = await Clipboard.getData(
                                    Clipboard.kTextPlain);
                                final text = data?.text?.trim();
                                if (text != null && text.isNotEmpty) {
                                  _controller.text = text;
                                }
                              },
                        icon: const Icon(Icons.content_paste_rounded, size: 17),
                        color: luma.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'The token is encrypted on this device and sent only to '
                'api.github.com. It never reaches a luma server.',
                style:
                    TextStyle(color: luma.textMuted, fontSize: 11, height: 1.45),
              ),
              const SizedBox(height: 18),
              _ScopeGuide(),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      actions: [
        if (existing != null)
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    final confirmed = await _confirmDisconnect(context);
                    if (!confirmed || !context.mounted) return;
                    await AccountOverviewScope.of(context).disconnect();
                    if (context.mounted) Navigator.of(context).pop();
                  },
            style: TextButton.styleFrom(foregroundColor: luma.danger),
            child: const Text('Disconnect'),
          ),
        // AlertDialog lays its actions out in an OverflowBar, not a Flex, so
        // the destructive action is separated by sitting at the opposite end
        // of the row from the primary one rather than by a Spacer.
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: luma.textSecondary),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 6),
        LumaPrimaryButton(
          label: 'Connect',
          icon: Icons.link_rounded,
          loading: _busy,
          onTap: _busy ? null : _submit,
        ),
      ],
    );
  }

  Future<bool> _confirmDisconnect(BuildContext context) async {
    final luma = context.luma;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: luma.surface,
        title: Text(
          'Disconnect GitHub?',
          style: TextStyle(color: luma.textPrimary, fontSize: 16),
        ),
        content: Text(
          'The stored token and every cached number are deleted from this '
          'device. Your GitHub account itself is untouched.',
          style: TextStyle(color: luma.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: luma.textSecondary),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: luma.danger),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

/// What to tick when creating the token. Getting this wrong is the single
/// most likely reason a section comes back empty, so it is spelled out here
/// rather than left to a failed request to explain later.
class _ScopeGuide extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: luma.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.key_rounded, size: 14, color: luma.textSecondary),
              const SizedBox(width: 8),
              Text(
                'Scopes to tick',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _scopeRow(context, 'repo', 'Private repositories, their issues and '
              'their workflow runs'),
          _scopeRow(context, 'read:user', 'Profile, followers, contributions'),
          _scopeRow(context, 'user', 'Usage, storage and Copilot allowances'),
          const SizedBox(height: 4),
          Text(
            'A fine-grained token wants the equivalent read-only permissions '
            'plus "Plan".',
            style: TextStyle(color: luma.textMuted, fontSize: 11, height: 1.45),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: AccountLinkButton(
              label: 'Open GitHub token settings',
              icon: Icons.open_in_new_rounded,
              onTap: () =>
                  openExternal('https://github.com/settings/tokens/new'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scopeRow(BuildContext context, String scope, String purpose) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: luma.accentSubtle,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              scope,
              style: TextStyle(
                color: luma.accent,
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              purpose,
              style: TextStyle(
                color: luma.textSecondary,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lets the user record the allowances GitHub does not report, so the usage
/// meters have a denominator to draw against.
Future<void> showGithubAllowanceDialog(BuildContext context) => showDialog<void>(
      context: context,
      builder: (_) => AccountOverviewScope(
        repository: AccountOverviewScope.of(context),
        child: const _AllowanceDialog(),
      ),
    );

class _AllowanceDialog extends StatefulWidget {
  const _AllowanceDialog();

  @override
  State<_AllowanceDialog> createState() => _AllowanceDialogState();
}

/// GitHub's own published per-plan numbers, so the allowance fields can be
/// one tap instead of a trip to the billing page and a calculator.
///
/// Storage and Actions minutes come from the repo-hosting plan
/// (Free/Pro/Team/Enterprise Cloud); Copilot is a separate subscription with
/// its own tiers, so it gets its own set of chips.
const _kStorageGbByPlan = {
  'Free': 0.5,
  'Pro': 2.0,
  'Team': 2.0,
  'Enterprise': 50.0,
};

const _kActionsMinutesByPlan = {
  'Free': 2000.0,
  'Pro': 3000.0,
  'Team': 3000.0,
  'Enterprise': 50000.0,
};

const _kCopilotRequestsByPlan = {
  'Free': 50.0,
  'Pro': 300.0,
  'Pro+': 1500.0,
  'Business': 300.0,
  'Enterprise': 1000.0,
};

class _AllowanceDialogState extends State<_AllowanceDialog> {
  final _copilot = TextEditingController();
  final _storage = TextEditingController();
  final _minutes = TextEditingController();
  bool _busy = false;
  bool _prefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The scope is not readable from initState, and re-prefilling on every
    // dependency change would wipe out whatever the user has typed — so the
    // stored values are copied in exactly once.
    if (_prefilled) return;
    _prefilled = true;
    final credentials = AccountOverviewScope.of(context).credentials;
    _copilot.text = _asText(credentials?.copilotAllowance);
    _storage.text = _asText(credentials?.storageAllowanceGb);
    _minutes.text = _asText(credentials?.minutesAllowance);
  }

  /// `2000.0` should come back into the field as `2000`, not as a decimal
  /// the user then has to tidy up.
  static String _asText(double? value) {
    if (value == null) return '';
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toString();
  }

  @override
  void dispose() {
    _copilot.dispose();
    _storage.dispose();
    _minutes.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    final value = double.tryParse(text.replaceAll(',', '.'));
    return (value == null || value <= 0) ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return AlertDialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: context.lumaDecor.cardBorderRadius,
        side: BorderSide(color: luma.border),
      ),
      title: Text(
        'Your monthly allowances',
        style: TextStyle(
          color: luma.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'GitHub reports what you have used but not always what your '
                'plan includes. Fill in the figures from your billing page '
                'and the meters get a bar; leave one blank and it shows the '
                'raw usage instead.',
                style: TextStyle(
                  color: luma.textSecondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: AccountLinkButton(
                  label: 'Open GitHub billing',
                  icon: Icons.open_in_new_rounded,
                  onTap: () => openExternal(
                      'https://github.com/settings/billing/summary'),
                ),
              ),
              const SizedBox(height: 8),
              _field(
                controller: _copilot,
                label: 'Copilot allowance',
                helper: 'Included AI credits or premium requests per month',
                quickFills: _kCopilotRequestsByPlan,
              ),
              _field(
                controller: _storage,
                label: 'Storage allowance',
                helper: 'Included Packages and Actions storage, in GB',
                quickFills: _kStorageGbByPlan,
              ),
              _field(
                controller: _minutes,
                label: 'Actions compute allowance',
                helper: 'Included workflow minutes per month',
                quickFills: _kActionsMinutesByPlan,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: luma.textSecondary),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 6),
        LumaPrimaryButton(
          label: 'Save',
          loading: _busy,
          onTap: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  await AccountOverviewScope.of(context).saveAllowances(
                    copilot: _parse(_copilot),
                    storageGb: _parse(_storage),
                    minutes: _parse(_minutes),
                  );
                  if (context.mounted) Navigator.of(context).pop();
                },
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String helper,
    Map<String, double> quickFills = const {},
  }) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            enabled: !_busy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: luma.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Leave blank if you do not know',
              hintStyle: TextStyle(color: luma.textMuted, fontSize: 12),
              helperText: helper,
              helperMaxLines: 2,
              helperStyle: TextStyle(color: luma.textMuted, fontSize: 11),
              filled: true,
              fillColor: luma.background,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: luma.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: luma.accent, width: 2),
              ),
            ),
          ),
          if (quickFills.isNotEmpty) ...[
            const SizedBox(height: 7),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in quickFills.entries)
                  _PlanChip(
                    label: entry.key,
                    onTap: _busy
                        ? null
                        : () => setState(
                            () => controller.text = _asText(entry.value)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A small tappable plan-name chip that fills its field with GitHub's
/// published allowance for that plan.
class _PlanChip extends StatelessWidget {
  const _PlanChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Material(
      color: luma.surfaceHover,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: TextStyle(
              color: luma.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
