import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Bouton principal plein (bleu marque) ou dégradé, pleine largeur par défaut.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool iconTrailing;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Gradient? gradient;
  final bool expanded;
  final double height;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.iconTrailing = false,
    this.backgroundColor,
    this.foregroundColor,
    this.gradient,
    this.expanded = true,
    this.height = 54,
  });

  /// Variante dégradé marque (bleu → vert) pour les actions mises en avant.
  const PrimaryButton.brand({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.iconTrailing = false,
    this.expanded = true,
    this.height = 54,
  }) : gradient = AppColors.brandGradient,
       backgroundColor = null,
       foregroundColor = null;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final fg = foregroundColor ?? Colors.white;

    Widget button;
    if (gradient != null) {
      button = DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled ? gradient : null,
          color: enabled ? null : AppColors.primary.withValues(alpha: 0.35),
          borderRadius: AppRadius.rMd,
          boxShadow: enabled ? AppShadows.colored(AppColors.primary, alpha: 0.22) : null,
        ),
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: fg,
            minimumSize: Size(expanded ? double.infinity : 0, height),
          ),
          child: _ButtonContent(label: label, icon: icon, iconTrailing: iconTrailing, isLoading: isLoading, color: fg),
        ),
      );
    } else {
      button = ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.primary,
          foregroundColor: fg,
          disabledBackgroundColor: (backgroundColor ?? AppColors.primary).withValues(alpha: 0.35),
          minimumSize: Size(expanded ? double.infinity : 0, height),
        ),
        child: _ButtonContent(label: label, icon: icon, iconTrailing: iconTrailing, isLoading: isLoading, color: fg),
      );
    }

    return SizedBox(width: expanded ? double.infinity : null, height: height, child: button);
  }
}

/// Bouton secondaire (contour), pleine largeur par défaut.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final Color? color;
  final bool expanded;
  final double height;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.color,
    this.expanded = true,
    this.height = 54,
  });

  @override
  Widget build(BuildContext context) {
    final fg = color ?? AppColors.primary;
    return SizedBox(
      width: expanded ? double.infinity : null,
      height: height,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          side: BorderSide(color: color != null ? fg.withValues(alpha: 0.4) : AppColors.border, width: 1.4),
          minimumSize: Size(expanded ? double.infinity : 0, height),
        ),
        child: _ButtonContent(label: label, icon: icon, isLoading: isLoading, color: fg),
      ),
    );
  }
}

/// Bouton texte discret (liens d'action).
class GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;

  const GhostButton({super.key, required this.label, this.onPressed, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final fg = color ?? AppColors.primary;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(foregroundColor: fg),
      child: _ButtonContent(label: label, icon: icon, color: fg, compact: true),
    );
  }
}

/// Petit bouton "pill" (actions inline dans les cartes).
class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final bool filled;

  const PillButton({super.key, required this.label, this.onPressed, this.icon, this.color = AppColors.primary, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : color;
    return Material(
      color: filled ? color : color.withValues(alpha: 0.1),
      borderRadius: AppRadius.rPill,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.rPill,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ButtonContent extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool iconTrailing;
  final bool isLoading;
  final Color color;
  final bool compact;

  const _ButtonContent({
    required this.label,
    this.icon,
    this.iconTrailing = false,
    this.isLoading = false,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: color));
    }
    if (icon == null) return Text(label);
    final iconWidget = Icon(icon, size: compact ? 18 : 20, color: color);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!iconTrailing) ...[iconWidget, const SizedBox(width: 8)],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        if (iconTrailing) ...[const SizedBox(width: 8), iconWidget],
      ],
    );
  }
}
