import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// En-tête des écrans d'onglet : grand titre, sous-titre, actions à droite.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? overline;
  final Widget? leading;
  final List<Widget> actions;
  final Widget? bottom;
  final EdgeInsetsGeometry padding;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.overline,
    this.leading,
    this.actions = const [],
    this.bottom,
    this.padding = const EdgeInsets.fromLTRB(AppSpacing.page, 12, AppSpacing.page, 8),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 14)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (overline != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          overline!,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.mutedForeground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    Text(title, style: theme.textTheme.headlineMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedForeground),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              for (final a in actions) Padding(padding: const EdgeInsets.only(left: 8), child: a),
            ],
          ),
          if (bottom != null) ...[const SizedBox(height: 16), bottom!],
        ],
      ),
    );
  }
}

/// Bouton d'action rond/carré pour les en-têtes (ex. cloche, réglages).
class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final Widget? badge;
  final Color? color;
  final Color? background;

  const HeaderIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.badge,
    this.color,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: background ?? AppColors.surface,
      borderRadius: AppRadius.rSm,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.rSm,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: AppRadius.rSm,
            border: Border.all(color: background != null ? Colors.transparent : AppColors.border),
          ),
          child: Icon(icon, size: 20, color: color ?? AppColors.foreground),
        ),
      ),
    );

    final withBadge = badge == null
        ? btn
        : Stack(
            clipBehavior: Clip.none,
            children: [
              btn,
              Positioned(top: -4, right: -4, child: badge!),
            ],
          );

    if (tooltip == null) return withBadge;
    return Tooltip(message: tooltip!, child: withBadge);
  }
}

/// AppBar des écrans poussés : bouton retour encadré, titre, actions.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool showBack;
  final VoidCallback? onBack;
  final Color? backgroundColor;
  final PreferredSizeWidget? bottom;
  final bool centerTitle;

  const AppTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.showBack = true,
    this.onBack,
    this.backgroundColor,
    this.bottom,
    this.centerTitle = false,
  });

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + 8 + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPop = showBack && (onBack != null || Navigator.of(context).canPop());
    return AppBar(
      backgroundColor: backgroundColor ?? AppColors.background,
      toolbarHeight: kToolbarHeight + 8,
      automaticallyImplyLeading: false,
      centerTitle: centerTitle,
      titleSpacing: canPop ? 0 : AppSpacing.page,
      leadingWidth: canPop ? 62 : 0,
      leading: canPop
          ? Padding(
              padding: const EdgeInsets.only(left: AppSpacing.page - 4),
              child: Center(
                child: HeaderIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Retour',
                  onTap: onBack ?? () => Navigator.of(context).maybePop(),
                ),
              ),
            )
          : null,
      title: Column(
        crossAxisAlignment: centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: theme.textTheme.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (subtitle != null)
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      actions: actions == null
          ? null
          : [
              ...actions!.map((a) => Padding(padding: const EdgeInsets.only(left: 8), child: a)),
              const SizedBox(width: AppSpacing.page - 4),
            ],
      bottom: bottom,
    );
  }
}

/// Titre de section dans une liste (avec action optionnelle à droite).
class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;

  const SectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: theme.textTheme.bodySmall),
                  ),
              ],
            ),
          ),
          ?trailing,
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(actionLabel!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
