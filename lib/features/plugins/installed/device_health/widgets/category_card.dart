import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../device_health_models.dart';
import 'status_pill.dart';

/// Shared shell for every Device Health category: icon, title, a status pill
/// (or a spinner while loading), an optional per-card "Check" action, and a
/// body below.
class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.status,
    this.loading = false,
    this.error,
    this.onCheck,
    this.checkLabel = 'Check',
  });

  final IconData icon;
  final String title;
  final Widget child;
  final HealthStatus? status;
  final bool loading;
  final String? error;
  final VoidCallback? onCheck;
  final String checkLabel;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LumaIconBadge(icon: icon, color: luma.accent, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (status != null)
                StatusPill(status: status!),
              if (onCheck != null && !loading) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onCheck,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  tooltip: checkLabel,
                  visualDensity: VisualDensity.compact,
                  color: luma.textSecondary,
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          if (error != null)
            Text(error!, style: TextStyle(color: luma.danger, fontSize: 13))
          else
            child,
        ],
      ),
    );
  }
}
