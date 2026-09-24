import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/app_version.dart';
import '../widgets/animated_fade_slide.dart';
import '../widgets/app_card.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/icon_box.dart';
import '../widgets/loading_view.dart';
import '../widgets/page_header.dart';
import '../widgets/primary_button.dart';

/// Paramètres techniques & à propos (connexion serveur, fuseau des rappels, version).
class SettingsScreen extends StatefulWidget {
  final bool embedded;

  const SettingsScreen({super.key, this.embedded = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _pingResult;
  bool _pingOk = false;
  bool _isPinging = false;
  String _appVersionLabel = 'TAKYMED';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final label = await AppVersion.label();
    if (mounted) setState(() => _appVersionLabel = label);
  }

  Future<void> _pingServer() async {
    final api = Provider.of<ApiService>(context, listen: false);
    setState(() {
      _isPinging = true;
      _pingResult = null;
    });
    try {
      final result = await api.ping();
      if (!mounted) return;
      setState(() {
        _pingResult = result;
        _pingOk = true;
      });
      AppSnackbar.success(context, 'Connexion au serveur OK');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pingResult = AppSnackbar.clean(e);
        _pingOk = false;
      });
      AppSnackbar.error(context, 'Échec : ${AppSnackbar.clean(e)}');
    } finally {
      if (mounted) setState(() => _isPinging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final body = ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 100),
      children: [
        AnimatedFadeSlide(
          index: 0,
          child: SectionCard(
            title: 'Connexion serveur',
            subtitle: 'Vérifier la disponibilité de l\'API',
            icon: Icons.dns_rounded,
            iconColor: AppColors.secondary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: AppRadius.rSm),
                  child: Row(
                    children: [
                      const Icon(Icons.link_rounded, size: 16, color: AppColors.mutedForeground),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ApiService.baseUrl,
                          style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                PrimaryButton(
                  label: _isPinging ? 'Test en cours…' : 'Tester la connexion',
                  icon: Icons.network_check_rounded,
                  isLoading: _isPinging,
                  backgroundColor: AppColors.secondary,
                  height: 48,
                  onPressed: _pingServer,
                ),
                if (_pingResult != null) ...[
                  const SizedBox(height: 12),
                  InfoBanner(
                    color: _pingOk ? AppColors.success : AppColors.destructive,
                    icon: _pingOk ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                    message: _pingResult!,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedFadeSlide(
          index: 1,
          child: SectionCard(
            title: 'Rappels natifs',
            subtitle: 'Fuseau horaire utilisé par les notifications locales',
            icon: Icons.schedule_rounded,
            child: Row(
              children: [
                const IconBox(icon: Icons.public_rounded, size: 40, iconSize: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(NotificationService.currentTimezone, style: theme.textTheme.titleSmall),
                      Text('Modifiable depuis Profil → Pays & fuseau horaire', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedFadeSlide(
          index: 2,
          child: AppCard(
            child: Column(
              children: [
                Image.asset(AppImages.logoHorizontal, height: 40, fit: BoxFit.contain),
                const SizedBox(height: 12),
                Text(_appVersionLabel, style: theme.textTheme.labelLarge?.copyWith(color: AppColors.mutedForeground)),
                const SizedBox(height: 4),
                Text(
                  'Vos rappels de médicaments, simplement.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(children: [const PageHeader(title: 'Paramètres'), Expanded(child: body)]),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppTopBar(title: 'Paramètres', subtitle: 'Technique & à propos'),
      body: body,
    );
  }
}
