import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Carte de base : surface blanche, bord fin, ombre douce, coins généreux.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius borderRadius;
  final Color? borderColor;
  final bool shadow;
  final List<BoxShadow>? boxShadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.color,
    this.gradient,
    this.onTap,
    this.onLongPress,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.borderColor,
    this.shadow = true,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final hasGradient = gradient != null;
    final decoration = BoxDecoration(
      color: hasGradient ? null : (color ?? AppColors.surface),
      gradient: gradient,
      borderRadius: borderRadius,
      border: hasGradient
          ? null
          : Border.all(color: borderColor ?? AppColors.border),
      boxShadow: boxShadow ?? (shadow ? (hasGradient ? AppShadows.elevated : AppShadows.soft) : null),
    );

    Widget content = Padding(padding: padding, child: child);

    if (onTap != null || onLongPress != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: borderRadius,
          splashColor: (hasGradient ? Colors.white : AppColors.primary).withValues(alpha: 0.08),
          highlightColor: (hasGradient ? Colors.white : AppColors.primary).withValues(alpha: 0.04),
          child: content,
        ),
      );
    }

    return Container(
      margin: margin,
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}

/// Carte de section : titre (+ sous-titre / action) puis contenu.
class SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
                    borderRadius: AppRadius.rSm,
                  ),
                  child: Icon(icon, size: 18, color: iconColor ?? AppColors.primary),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Carte héros dégradée (bleu → vert) avec cercles décoratifs.
class HeroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Gradient gradient;
  final BorderRadius borderRadius;

  const HeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.onTap,
    this.gradient = AppColors.brandGradient,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: borderRadius,
        boxShadow: AppShadows.elevated,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          splashColor: Colors.white.withValues(alpha: 0.12),
          highlightColor: Colors.white.withValues(alpha: 0.05),
          child: Stack(
            children: [
              Positioned(
                right: -40,
                top: -50,
                child: _DecorCircle(size: 160, alpha: 0.12),
              ),
              Positioned(
                right: 40,
                bottom: -70,
                child: _DecorCircle(size: 140, alpha: 0.08),
              ),
              Positioned(
                left: -30,
                bottom: -40,
                child: _DecorCircle(size: 100, alpha: 0.06),
              ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _DecorCircle extends StatelessWidget {
  final double size;
  final double alpha;
  const _DecorCircle({required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: alpha),
        ),
      ),
    );
  }
}

/// Bandeau d'information coloré (info / succès / alerte / erreur).
class InfoBanner extends StatelessWidget {
  final String message;
  final String? title;
  final IconData icon;
  final Color color;
  final Widget? action;

  const InfoBanner({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.info_outline_rounded,
    this.color = AppColors.primary,
    this.action,
  });

  const InfoBanner.success({super.key, required this.message, this.title, this.action})
      : icon = Icons.check_circle_outline_rounded,
        color = AppColors.success;

  const InfoBanner.warning({super.key, required this.message, this.title, this.action})
      : icon = Icons.warning_amber_rounded,
        color = AppColors.warning;

  const InfoBanner.error({super.key, required this.message, this.title, this.action})
      : icon = Icons.error_outline_rounded,
        color = AppColors.destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.rMd,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(title!, style: theme.textTheme.titleSmall?.copyWith(color: color)),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.foreground, height: 1.45),
                ),
                if (action != null) ...[
                  const SizedBox(height: 8),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
