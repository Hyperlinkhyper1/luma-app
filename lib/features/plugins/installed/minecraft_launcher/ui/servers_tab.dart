import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import 'hover_sync_scroll.dart';

const _kineticUrl = 'https://billing.kinetichosting.com/aff.php?aff=1433';

/// Servers tab: a partner card for Minecraft server hosting. Tapping it opens
/// the Kinetic Hosting affiliate link in the browser.
class ServersTab extends StatelessWidget {
  const ServersTab({super.key});

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final opened = await launchUrl(
      Uri.parse(_kineticUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Could not open the browser.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;

    return HoverSyncScroll(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          Text(
            'Servers',
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Rent a Minecraft server to play your instances with friends.',
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          _KineticBanner(onTap: () => _open(context)),
          const SizedBox(height: 16),
          LumaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kinetic Hosting',
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Modpack and plugin support, 24/7 support and one-click '
                  'installs. Signing up through this link supports luma at no '
                  'extra cost to you.',
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: LumaPrimaryButton(
                    label: 'Browse plans',
                    icon: Icons.open_in_new_rounded,
                    onTap: () => _open(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KineticBanner extends StatefulWidget {
  const _KineticBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_KineticBanner> createState() => _KineticBannerState();
}

class _KineticBannerState extends State<_KineticBanner> {
  bool _hovering = false;

  static const _ink = Color(0xFF17122B);
  static const _violet = Color(0xFF7C4DFF);
  static const _lilac = Color(0xFFB59BFF);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF241A45), _ink],
            ),
            border: Border.all(
              color: _violet.withValues(alpha: _hovering ? 0.75 : 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: _violet.withValues(alpha: _hovering ? 0.35 : 0.18),
                blurRadius: _hovering ? 26 : 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 16,
            spacing: 24,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'MINECRAFT SERVER HOSTING',
                    style: TextStyle(
                      color: _lilac.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'QUALITY HOSTING,\nFOR LOW PRICES!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
              const Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Pill(
                    icon: Icons.support_agent_rounded,
                    label: '24/7 support',
                  ),
                  _Pill(icon: Icons.extension_rounded, label: 'Mod support'),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, color: _lilac, size: 22),
                      SizedBox(width: 6),
                      Text(
                        'KINETIC HOSTING',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: _hovering ? const Color(0xFF8F63FF) : _violet,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'START TODAY!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
