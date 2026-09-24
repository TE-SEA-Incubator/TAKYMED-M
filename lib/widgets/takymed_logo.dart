import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum TakymedLogoSize { small, medium, large, hero }

/// Variante d'affichage du logo.
enum TakymedLogoVariant {
  /// Icône seule (horloge + feuille).
  icon,

  /// Logo horizontal : icône + texte "TAKYMED" côte à côte.
  horizontal,
}

class TakymedLogo extends StatelessWidget {
  final TakymedLogoSize size;
  final bool showLabel;
  final Color? labelColor;
  final bool circularBackground;
  final TakymedLogoVariant variant;

  const TakymedLogo({
    super.key,
    this.size = TakymedLogoSize.medium,
    this.showLabel = false,
    this.labelColor,
    this.circularBackground = false,
    this.variant = TakymedLogoVariant.icon,
  });

  double get _iconSize {
    switch (size) {
      case TakymedLogoSize.small:
        return 40;
      case TakymedLogoSize.medium:
        return 60;
      case TakymedLogoSize.large:
        return 90;
      case TakymedLogoSize.hero:
        return 120;
    }
  }

  double get _horizontalHeight {
    switch (size) {
      case TakymedLogoSize.small:
        return 32;
      case TakymedLogoSize.medium:
        return 44;
      case TakymedLogoSize.large:
        return 60;
      case TakymedLogoSize.hero:
        return 80;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (variant == TakymedLogoVariant.horizontal) {
      // Logo horizontal (icône + texte TAKYMED intégrés dans l'image)
      final Widget horizontalImg = Image.asset(
        'assets/images/logo_horizontal.png',
        height: _horizontalHeight,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
      return horizontalImg;
    }

    // Icône seule
    final Widget iconImg = Image.asset(
      'assets/images/logo.png',
      width: _iconSize,
      height: _iconSize,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    if (circularBackground) {
      return Container(
        padding: EdgeInsets.all(_iconSize * 0.15),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.12),
            width: 1.5,
          ),
        ),
        child: iconImg,
      );
    }

    return iconImg;
  }
}
