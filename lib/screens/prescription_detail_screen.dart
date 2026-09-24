import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_card.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/icon_box.dart';
import '../widgets/loading_view.dart';
import '../widgets/ordonnance_detail_panel.dart';
import '../widgets/page_header.dart';
import '../widgets/skeleton.dart';
import '../widgets/status_badge.dart';

/// Détail d'une ordonnance : en-tête, progression, médicaments, rappels, actions.
class PrescriptionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> ordonnance;

  const PrescriptionDetailScreen({super.key, required this.ordonnance});

  @override
  State<PrescriptionDetailScreen> createState() => _PrescriptionDetailScreenState();
}

class _PrescriptionDetailScreenState extends State<PrescriptionDetailScreen> {
  late Map<String, dynamic> _ord;
  Map<String, dynamic>? _details;
  bool _loading = true;
  bool _changed = false;
  String? _error;
  final _panelKey = GlobalKey<OrdonnanceDetailPanelState>();

  int get _id => (_ord['id'] as num).toInt();
  bool get _active => _ord['est_active'] == 1 || _ord['est_active'] == true;

  @override
  void initState() {
    super.initState();
    _ord = Map<String, dynamic>.from(widget.ordonnance);
    _load();
  }

  Future<void> _load() async {
    final api = Provider.of<ApiService>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final results = await Future.wait([api.getOrdonnanceDetails(_id), if (auth.user != null) api.getOrdonnances(auth.user!.id)]);
      if (!mounted) return;
      final details = results[0];
      Map<String, dynamic>? refreshed;
      if (results.length > 1) {
        final list = (results[1]['ordonnances'] as List<dynamic>?) ?? [];
        for (final o in list) {
          if (o is Map && o['id'] == _ord['id']) {
            refreshed = Map<String, dynamic>.from(o);
            break;
          }
        }
      }
      setState(() {
        _details = details;
        if (refreshed != null) _ord = refreshed;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = AppSnackbar.clean(e);
        });
      }
    }
  }

  Future<void> _refreshAll() async {
    _changed = true;
    await _load();
  }

  Future<bool?> _confirm(String title, String content, {bool destructive = false, String confirmLabel = 'Confirmer'}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: destructive ? AppColors.destructive : AppColors.primary),
            child: Text(destructive ? 'Supprimer' : confirmLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _cancel() async {
    if (await _confirm(
          'Annuler l\'ordonnance',
          'Les rappels seront suspendus. Vous pourrez la réactiver plus tard.',
          confirmLabel: 'Annuler l\'ordonnance',
        ) !=
        true) {
      return;
    }
    if (!mounted) return;
    try {
      await Provider.of<ApiService>(context, listen: false).cancelOrdonnance(_id);
      if (!mounted) return;
      AppSnackbar.success(context, 'Ordonnance annulée');
      await _refreshAll();
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppSnackbar.clean(e));
    }
  }

  Future<void> _reactivate() async {
    if (await _confirm('Réactiver l\'ordonnance', 'Réactiver cette ordonnance et reprendre les rappels ?', confirmLabel: 'Réactiver') !=
        true) {
      return;
    }
    if (!mounted) return;
    try {
      await Provider.of<ApiService>(context, listen: false).reactivateOrdonnance(_id);
      if (!mounted) return;
      AppSnackbar.success(context, 'Ordonnance réactivée');
      await _refreshAll();
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppSnackbar.clean(e));
    }
  }

  Future<void> _delete() async {
    if (await _confirm(
          'Supprimer définitivement',
          'Cette action est irréversible. Toutes les données de l\'ordonnance seront effacées.',
          destructive: true,
        ) !=
        true) {
      return;
    }
    if (!mounted) return;
    final userId = Provider.of<AuthProvider>(context, listen: false).user?.id;
    try {
      await Provider.of<ApiService>(context, listen: false).deleteOrdonnance(_id, userId: userId);
      if (!mounted) return;
      AppSnackbar.success(context, 'Ordonnance supprimée');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppSnackbar.clean(e));
    }
  }

  void _edit() => _panelKey.currentState?.editOrdonnance();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = Provider.of<AuthProvider>(context, listen: false).user?.id ?? 0;
    final api = Provider.of<ApiService>(context, listen: false);
    final total = (_ord['prises_totales'] as num?)?.toInt() ?? 0;
    final done = (_ord['prises_effectuees'] as num?)?.toInt() ?? 0;
    final progress = total > 0 ? (done / total).clamp(0.0, 1.0) : 0.0;
    final percent = (progress * 100).round();
    final date = DateTime.tryParse(_ord['date_ordonnance']?.toString() ?? '');
    final title = _ord['titre']?.toString().trim().isNotEmpty == true ? _ord['titre'].toString() : 'Ordonnance #$_id';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppTopBar(
          title: title,
          subtitle: _ord['nom_patient']?.toString(),
          onBack: () => Navigator.pop(context, _changed),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Actions',
              icon: const HeaderIconButton(icon: Icons.more_horiz_rounded),
              onSelected: (v) {
                switch (v) {
                  case 'edit':
                    _edit();
                  case 'cancel':
                    _cancel();
                  case 'reactivate':
                    _reactivate();
                  case 'delete':
                    _delete();
                }
              },
              itemBuilder: (_) => [
                if (_active)
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 10), Text('Modifier')]),
                  ),
                if (_active)
                  const PopupMenuItem(
                    value: 'cancel',
                    child: Row(
                      children: [Icon(Icons.pause_circle_outline_rounded, size: 18), SizedBox(width: 10), Text('Annuler l\'ordonnance')],
                    ),
                  ),
                if (!_active)
                  const PopupMenuItem(
                    value: 'reactivate',
                    child: Row(children: [Icon(Icons.play_circle_outline_rounded, size: 18), SizedBox(width: 10), Text('Réactiver')]),
                  ),
                if (!_active)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.destructive),
                        SizedBox(width: 10),
                        Text('Supprimer', style: TextStyle(color: AppColors.destructive)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 40),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // ── En-tête ──
              Hero(
                tag: 'ordonnance-${_ord['id']}',
                child: HeroCard(
                  gradient: _active ? AppColors.brandGradient : const LinearGradient(colors: [Color(0xFF475569), Color(0xFF64748B)]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const IconBox(icon: Icons.description_rounded, color: Colors.white, background: Color(0x33FFFFFF), size: 46),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  [
                                    if ((_ord['nom_patient']?.toString() ?? '').isNotEmpty) _ord['nom_patient'].toString(),
                                    if (date != null) DateFormat.yMMMd('fr_FR').format(date),
                                  ].join(' · '),
                                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge.fromOrdonnance(_ord),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Text('$percent%', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white)),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor: Colors.white.withValues(alpha: 0.25),
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            flex: 2,
                            child: Text(
                              '$done / $total prises',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: theme.textTheme.labelMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _HeroChip(icon: Icons.medication_outlined, label: '${_ord['nombre_medicaments'] ?? 0} médicament(s)'),
                          if (_ord['categorie_age'] != null) _HeroChip(icon: Icons.cake_outlined, label: _ord['categorie_age'].toString()),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              if (!_active)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: InfoBanner.warning(
                    title: 'Ordonnance annulée',
                    message: 'Les rappels sont suspendus. Réactivez-la pour reprendre le suivi.',
                  ),
                ),

              if (_loading)
                const Shimmer(
                  child: Column(
                    children: [
                      SkeletonCard(height: 76),
                      SizedBox(height: 10),
                      SkeletonCard(height: 76),
                      SizedBox(height: 20),
                      SkeletonCard(height: 64),
                      SizedBox(height: 8),
                      SkeletonCard(height: 64),
                    ],
                  ),
                )
              else if (_error != null)
                ErrorState(message: _error!, onRetry: _load)
              else
                OrdonnanceDetailPanel(key: _panelKey, ord: _ord, details: _details, userId: userId, api: api, onRefresh: _refreshAll),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeroChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
