import 'package:flutter/material.dart';

/// Palette officielle TAKYMED (identité web) déclinée pour le mobile.
class AppColors {
  AppColors._();

  // --- Bleu marque (primaire) ---
  static const primary = Color(0xFF006093);
  static const primaryDark = Color(0xFF004B73);
  static const primaryLight = Color(0xFFE8F1F7);
  static const primarySoft = Color(0xFFCFE3EE);
  static const primaryForeground = Color(0xFFFFFFFF);

  // --- Vert marque (secondaire / succès) ---
  static const secondary = Color(0xFF00A859);
  static const secondaryDark = Color(0xFF008A48);
  static const secondaryLight = Color(0xFFE6F7EF);
  static const secondarySoft = Color(0xFFC3EBD6);

  // --- Fond et surfaces ---
  static const background = Color(0xFFF7FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF1F5F9);
  static const foreground = Color(0xFF0F172A);
  static const muted = Color(0xFFF1F5F9);
  static const mutedForeground = Color(0xFF64748B);
  static const subtleForeground = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);
  static const borderStrong = Color(0xFFCBD5E1);

  // --- Statuts ---
  static const success = secondary;
  static const successLight = secondaryLight;

  static const warning = Color(0xFFF59E0B);
  static const warningLight = Color(0xFFFEF3C7);

  static const destructive = Color(0xFFEF4444);
  static const destructiveLight = Color(0xFFFEE2E2);

  static const info = primary;
  static const infoLight = primaryLight;

  // --- Accent IA (fiches enrichies) ---
  static const ai = Color(0xFF7C3AED);
  static const aiLight = Color(0xFFEDE9FE);

  // --- Dégradés ---
  static const gradientStart = primary;
  static const gradientEnd = secondary;

  /// Dégradé héros bleu → vert (cartes mises en avant, en-têtes, onboarding).
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientStart, gradientEnd],
  );

  /// Variante plus sombre pour les fonds où du texte blanc doit rester lisible.
  static const LinearGradient brandGradientDeep = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primary, secondaryDark],
    stops: [0.0, 0.55, 1.0],
  );

  /// Dégradé très léger pour les arrière-plans de section.
  static const LinearGradient softGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryLight, background],
  );

  static const LinearGradient aiGradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
  );

  /// Compatibilité avec l'ancien nom.
  static LinearGradient get primaryGradient => brandGradient;

  /// Couleur d'accent d'un canal de notification.
  static Color channelColor(String id) {
    switch (id) {
      case 'sms':
        return const Color(0xFF0EA5E9);
      case 'whatsapp':
        return const Color(0xFF25D366);
      case 'call':
        return primary;
      case 'push':
      default:
        return const Color(0xFF8B5CF6);
    }
  }
}
