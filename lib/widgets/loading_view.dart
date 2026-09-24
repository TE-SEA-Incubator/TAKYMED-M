import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'primary_button.dart';
import 'takymed_logo.dart';

/// Chargement plein écran (logo + spinner).
class LoadingView extends StatelessWidget {
  final String? message;
  final bool showLogo;

  const LoadingView({super.key, this.message, this.showLogo = true});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLogo) ...[
            const TakymedLogo(size: TakymedLogoSize.large, circularBackground: true),
            const SizedBox(height: 24),
          ],
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.mutedForeground),
            ),
          ],
        ],
      ),
    );
  }
}

/// Illustrations de marque disponibles pour les états vides / en-têtes.
class AppImages {
  AppImages._();
  static const hero = 'assets/images/hero.webp';
  static const reminders = 'assets/images/feature-reminders.webp';
  static const pharmacy = 'assets/images/feature-pharmacy.webp';
  static const safety = 'assets/images/feature-safety.webp';
  static const emptyDoses = 'assets/images/empty-doses.webp';
  static const emptyPrescriptions = 'assets/images/empty-prescriptions.webp';
  static const emptyPharmacies = 'assets/images/empty-pharmacies.webp';
  static const medicationPlaceholder = 'assets/images/medication-placeholder.webp';
  static const pharmacyCard = 'assets/images/pharmacy-card.webp';
  static const logo = 'assets/images/logo.png';
  static const logoHorizontal = 'assets/images/logo_horizontal.png';
}

/// État vide illustré (image de marque ou icône), titre, sous-titre, action.
class EmptyState extends StatelessWidget {
  final IconData? icon;
  final String? image;
  final double imageHeight;
  final String title;
  final String? subtitle;
  final Widget? action;
  final bool compact;

  const EmptyState({
    super.key,
    this.icon,
    this.image,
    this.imageHeight = 180,
    required this.title,
    this.subtitle,
    this.action,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (image != null)
          Image.asset(
            image!,
            height: compact ? imageHeight * 0.7 : imageHeight,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          )
        else
          Container(
            width: compact ? 64 : 84,
            height: compact ? 64 : 84,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(compact ? 20 : 26),
            ),
            child: Icon(icon ?? Icons.inbox_rounded, size: compact ? 30 : 38, color: AppColors.primary),
          ),
        SizedBox(height: compact ? 16 : 24),
        Text(
          title,
          style: compact ? theme.textTheme.titleMedium : theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedForeground, height: 1.5),
          ),
        ],
        if (action != null) ...[
          SizedBox(height: compact ? 16 : 24),
          action!,
        ],
      ],
    );

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxxl, vertical: compact ? 16 : 32),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 360), child: content),
      ),
    );
  }
}

/// État d'erreur avec bouton réessayer.
class ErrorState extends StatelessWidget {
  final String message;
  final String? title;
  final VoidCallback? onRetry;

  const ErrorState({super.key, required this.message, this.title, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.destructiveLight,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.cloud_off_rounded, size: 34, color: AppColors.destructive),
              ),
              const SizedBox(height: 20),
              Text(title ?? 'Une erreur est survenue', style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedForeground),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                SecondaryButton(label: 'Réessayer', icon: Icons.refresh_rounded, onPressed: onRetry, expanded: false),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
