import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/animated_fade_slide.dart';
import '../widgets/app_card.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/app_text_field.dart';
import '../widgets/icon_box.dart';
import '../widgets/loading_view.dart';
import '../widgets/primary_button.dart';
import '../widgets/page_header.dart';
import '../widgets/skeleton.dart';
import '../widgets/status_badge.dart';

/// Formules d'abonnement (types de compte) et demande de changement.
class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  List<dynamic> _plans = [];
  bool _isLoading = true;
  String? _error;
  String? _submittingPlan;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final settings = await api.getAccountSettings(auth.user!.id);
      if (!mounted) return;
      setState(() {
        _plans = (settings['types'] as List<dynamic>? ?? [])
            .where((p) => !(p['name']?.toString() ?? '').toLowerCase().contains('admin'))
            .toList();
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Impossible de charger les offres.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isCurrent(String planName, String currentType) {
    final n = planName.toLowerCase();
    if (currentType == 'standard' && n.contains('standard')) return true;
    if (currentType == 'professional' && n.contains('pro')) return true;
    if (currentType == 'commercial' && n.contains('commercial')) return true;
    return false;
  }

  Future<void> _handlePlanSelection(Map<String, dynamic> plan) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final planName = plan['name'] as String;
    if (_isCurrent(planName, auth.user?.type ?? 'standard')) return;

    final motiveController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Passer à la formule $planName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              controller: motiveController,
              label: 'Pourquoi souhaitez-vous changer de formule ?',
              hint: 'Ex. besoin de plus d\'ordonnances…',
              maxLines: 3,
              minLines: 2,
              autofocus: true,
            ),
            const SizedBox(height: 10),
            Text(
              'Votre demande sera examinée par un administrateur.',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Envoyer la demande')),
        ],
      ),
    );

    if (confirmed != true) return;
    final motive = motiveController.text.trim();
    if (motive.isEmpty) {
      if (mounted) AppSnackbar.warning(context, 'Veuillez indiquer un motif');
      return;
    }
    await _submitRequest(planName, motive);
  }

  Future<void> _submitRequest(String planName, String motive) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final api = Provider.of<ApiService>(context, listen: false);
    setState(() => _submittingPlan = planName);
    try {
      await api.submitUpgradeRequest(auth.user!.id, planName, motive: motive);
      if (mounted) {
        Navigator.pop(context);
        AppSnackbar.success(context, 'Demande envoyée ! Un administrateur vous répondra.');
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppSnackbar.clean(e));
    } finally {
      if (mounted) setState(() => _submittingPlan = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final currentType = auth.user?.type ?? 'standard';
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppTopBar(title: 'Mon abonnement', subtitle: 'Choisissez la formule adaptée'),
      body: _isLoading
          ? const SkeletonList(count: 3, itemHeight: 200, withLeading: false)
          : _error != null
              ? ErrorState(message: _error!, onRetry: _loadPlans)
              : RefreshIndicator(
                  onRefresh: _loadPlans,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 40),
                    children: [
                      AnimatedFadeSlide(
                        index: 0,
                        child: HeroCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Boostez votre expérience', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Plus d\'ordonnances, un suivi pour vos patients ou vos clients : passez à la formule qui vous ressemble.',
                                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.9), height: 1.45),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Image.asset(AppImages.hero, height: 90, fit: BoxFit.contain),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      for (var i = 0; i < _plans.length; i++)
                        AnimatedFadeSlide(
                          index: i + 1,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _PlanCard(
                              plan: Map<String, dynamic>.from(_plans[i] as Map),
                              isCurrent: _isCurrent(_plans[i]['name']?.toString() ?? '', currentType),
                              loading: _submittingPlan == _plans[i]['name'],
                              onSelect: () => _handlePlanSelection(Map<String, dynamic>.from(_plans[i] as Map)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final bool isCurrent;
  final bool loading;
  final VoidCallback onSelect;

  const _PlanCard({required this.plan, required this.isCurrent, required this.loading, required this.onSelect});

  (IconData, Color) _style(String name) {
    final n = name.toLowerCase();
    if (n.contains('commercial')) return (Icons.storefront_rounded, AppColors.warning);
    if (n.contains('pro')) return (Icons.medical_services_rounded, AppColors.secondary);
    return (Icons.person_rounded, AppColors.primary);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = plan['name']?.toString() ?? '';
    final price = (plan['price'] as num?) ?? 0;
    final currency = plan['currency']?.toString() ?? 'FCFA';
    final description = plan['description']?.toString() ?? '';
    final (icon, color) = _style(name);

    return AppCard(
      borderColor: isCurrent ? color : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBox(icon: icon, color: color, size: 48, iconSize: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleMedium),
                    Text(
                      price == 0 ? 'Gratuit' : '${price.toInt()} $currency / mois',
                      style: theme.textTheme.titleSmall?.copyWith(color: color),
                    ),
                  ],
                ),
              ),
              if (isCurrent) const StatusBadge(label: 'Actuelle', type: StatusType.validated, small: true, icon: Icons.check_rounded),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(description, style: theme.textTheme.bodySmall?.copyWith(height: 1.5)),
          ],
          const SizedBox(height: 16),
          if (isCurrent)
            SecondaryButton(label: 'Votre formule actuelle', icon: Icons.check_circle_outline_rounded, height: 48, onPressed: null)
          else
            PrimaryButton(
              label: 'Choisir cette formule',
              icon: Icons.arrow_forward_rounded,
              iconTrailing: true,
              height: 48,
              backgroundColor: color,
              isLoading: loading,
              onPressed: onSelect,
            ),
        ],
      ),
    );
  }
}
