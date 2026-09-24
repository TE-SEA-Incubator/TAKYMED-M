import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Carré arrondi teinté contenant une icône (motif récurrent des cartes).
class IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double? iconSize;
  final double? radius;
  final Color? background;
  final bool filled;
  final Gradient? gradient;

  const IconBox({
    super.key,
    required this.icon,
    this.color = AppColors.primary,
    this.size = 44,
    this.iconSize,
    this.radius,
    this.background,
    this.filled = false,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final fg = (filled || gradient != null) ? Colors.white : color;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: gradient != null ? null : (background ?? (filled ? color : color.withValues(alpha: 0.11))),
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius ?? size * 0.32),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize ?? size * 0.5, color: fg),
    );
  }
}

/// Avatar à initiales (cercle dégradé ou teinté).
class InitialsAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Gradient? gradient;
  final Color? color;

  const InitialsAvatar({
    super.key,
    required this.name,
    this.size = 48,
    this.gradient,
    this.color,
  });

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final useGradient = gradient ?? (color == null ? AppColors.brandGradient : null);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: useGradient,
        color: useGradient == null ? color!.withValues(alpha: 0.14) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: useGradient != null ? Colors.white : color,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.38,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
