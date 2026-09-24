import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum StatusType { active, completed, cancelled, pending, validated, info, warning, danger, neutral, ai }

/// Badge de statut coloré (pill).
class StatusBadge extends StatelessWidget {
  final String label;
  final StatusType type;
  final IconData? icon;
  final bool small;
  final Color? customColor;

  const StatusBadge({
    super.key,
    required this.label,
    required this.type,
    this.icon,
    this.small = false,
    this.customColor,
  });

  factory StatusBadge.fromOrdonnance(dynamic ord, {bool small = false}) {
    final active = ord['est_active'];
    final isActive = active == 1 || active == true;
    final done = (ord['prises_effectuees'] as num?)?.toInt() ?? 0;
    final total = (ord['prises_totales'] as num?)?.toInt() ?? 0;
    if (!isActive) {
      return StatusBadge(label: 'Annulée', type: StatusType.cancelled, small: small);
    }
    if (total > 0 && done >= total) {
      return StatusBadge(label: 'Terminée', type: StatusType.completed, small: small);
    }
    return StatusBadge(label: 'En cours', type: StatusType.active, small: small);
  }

  (Color bg, Color fg) get _colors {
    if (customColor != null) {
      return (customColor!.withValues(alpha: 0.12), customColor!);
    }
    switch (type) {
      case StatusType.active:
      case StatusType.info:
        return (AppColors.primaryLight, AppColors.primary);
      case StatusType.completed:
      case StatusType.validated:
        return (AppColors.successLight, AppColors.secondaryDark);
      case StatusType.cancelled:
      case StatusType.neutral:
        return (AppColors.surfaceMuted, AppColors.mutedForeground);
      case StatusType.pending:
      case StatusType.warning:
        return (AppColors.warningLight, const Color(0xFFB45309));
      case StatusType.danger:
        return (AppColors.destructiveLight, const Color(0xFFB91C1C));
      case StatusType.ai:
        return (AppColors.aiLight, AppColors.ai);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    final fontSize = small ? 10.0 : 11.5;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: small ? 3 : 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: fontSize,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pastille compteur (ex. notifications non lues).
class CountBadge extends StatelessWidget {
  final int count;
  final Color color;

  const CountBadge({super.key, required this.count, this.color = AppColors.destructive});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      constraints: const BoxConstraints(minWidth: 18),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }
}
