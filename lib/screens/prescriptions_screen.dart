import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/animated_fade_slide.dart';
import '../widgets/app_card.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/icon_box.dart';
import '../widgets/loading_view.dart';
import '../widgets/page_header.dart';
import '../widgets/page_transitions.dart';
import '../widgets/primary_button.dart';
import '../widgets/skeleton.dart';
import '../widgets/status_badge.dart';
import 'create_prescription_screen.dart';
import 'prescription_detail_screen.dart';

enum _Filter { all, active, done, cancelled }

/// Liste des ordonnances : filtres, progression, accès au détail.
class OrdonnancesScreen extends StatefulWidget {
  final bool embedded;

  const OrdonnancesScreen({super.key, this.embedded = false});

  @override
  State<OrdonnancesScreen> createState() => _OrdonnancesScreenState();
}

class _OrdonnancesScreenState extends State<OrdonnancesScreen> {
  List<dynamic> _ordonnances = [];
  bool _isLoading = true;
  String? _errorMessage;
  _Filter _filter = _Filter.all;

  bool _isActive(dynamic ord) => ord['est_active'] == 1 || ord['est_active'] == true;

  bool _isDone(dynamic o) {
    final total = (o['prises_totales'] as num?)?.toInt() ?? 0;
    final done = (o['prises_effectuees'] as num?)?.toInt() ?? 0;
    return _isActive(o) && total > 0 && done >= total;
  }

  bool _isRunning(dynamic o) => _isActive(o) && !_isDone(o);

  int get _total => _ordonnances.length;
  int get _terminees => _ordonnances.where(_isDone).length;
  int get _enCours => _ordonnances.where(_isRunning).length;
  int get _annulees => _ordonnances.where((o) => !_isActive(o)).length;

  List<dynamic> get _filtered {
    switch (_filter) {
      case _Filter.active:
        return _ordonnances.where(_isRunning).toList();
      case _Filter.done:
        return _ordonnances.where(_isDone).toList();
      case _Filter.cancelled:
        return _ordonnances.where((o) => !_isActive(o)).toList();
      case _Filter.all:
        return _ordonnances;
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchOrdonnances();
  }

  Future<void> _fetchOrdonnances() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Utilisateur non connecté';
      });
      return;
    }

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final data = await api.getOrdonnances(authProvider.user!.id);
      if (mounted) {
        setState(() {
          _ordonnances = data['ordonnances'] ?? [];
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = AppSnackbar.clean(e);
          _isLoading = false;
        });
      }
    }
  }

  Future<bool?> _confirmDialog(String title, String content, {bool destructive = false, String confirmLabel = 'Confirmer'}) {
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

  Future<void> _cancelOrdonnance(int id) async {
    if (await _confirmDialog('Annuler l\'ordonnance', 'Les rappels seront suspendus. Vous pourrez réactiver plus tard.', confirmLabel: 'Annuler l\'ordonnance') != true) return;
    if (!mounted) return;
    try {
      await Provider.of<ApiService>(context, listen: false).cancelOrdonnance(id);
      await _fetchOrdonnances();
      if (mounted) AppSnackbar.success(context, 'Ordonnance annulée');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppSnackbar.clean(e));
    }
  }

  Future<void> _reactivateOrdonnance(int id) async {
    if (await _confirmDialog('Réactiver l\'ordonnance', 'Réactiver cette ordonnance et reprendre les rappels ?', confirmLabel: 'Réactiver') != true) return;
    if (!mounted) return;
    try {
      await Provider.of<ApiService>(context, listen: false).reactivateOrdonnance(id);
      await _fetchOrdonnances();
      if (mounted) AppSnackbar.success(context, 'Ordonnance réactivée');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppSnackbar.clean(e));
    }
  }

  Future<void> _deleteOrdonnance(int id) async {
    if (await _confirmDialog('Supprimer définitivement', 'Cette action est irréversible. Toutes les données seront effacées.', destructive: true) != true) return;
    if (!mounted) return;
    final userId = Provider.of<AuthProvider>(context, listen: false).user?.id;
    try {
      await Provider.of<ApiService>(context, listen: false).deleteOrdonnance(id, userId: userId);
      if (!mounted) return;
      setState(() => _ordonnances.removeWhere((o) => o['id'] == id));
      AppSnackbar.success(context, 'Ordonnance supprimée');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppSnackbar.clean(e));
    }
  }

  Future<void> _openDetail(dynamic ord) async {
    final changed = await pushSlide<bool>(
      context,
      PrescriptionDetailScreen(ordonnance: Map<String, dynamic>.from(ord as Map)),
    );
    if (changed == true) _fetchOrdonnances();
  }

  Future<void> _showActions(dynamic ord) async {
    final active = _isActive(ord);
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      ord['titre']?.toString() ?? 'Ordonnance #${ord['id']}',
                      style: Theme.of(ctx).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  StatusBadge.fromOrdonnance(ord),
                ],
              ),
            ),
            ListTile(
              leading: const IconBox(icon: Icons.open_in_new_rounded, size: 40),
              title: const Text('Voir le détail'),
              onTap: () => Navigator.pop(ctx, 'open'),
            ),
            if (active)
              ListTile(
                leading: const IconBox(icon: Icons.pause_circle_outline_rounded, color: AppColors.warning, size: 40),
                title: const Text('Annuler l\'ordonnance'),
                subtitle: const Text('Suspend les rappels'),
                onTap: () => Navigator.pop(ctx, 'cancel'),
              ),
            if (!active) ...[
              ListTile(
                leading: const IconBox(icon: Icons.play_circle_outline_rounded, color: AppColors.success, size: 40),
                title: const Text('Réactiver'),
                onTap: () => Navigator.pop(ctx, 'reactivate'),
              ),
              ListTile(
                leading: const IconBox(icon: Icons.delete_outline_rounded, color: AppColors.destructive, size: 40),
                title: const Text('Supprimer définitivement', style: TextStyle(color: AppColors.destructive)),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
            ],
          ],
        ),
      ),
    );

    final id = ord['id'] as int;
    switch (action) {
      case 'open':
        await _openDetail(ord);
      case 'cancel':
        await _cancelOrdonnance(id);
      case 'reactivate':
        await _reactivateOrdonnance(id);
      case 'delete':
        await _deleteOrdonnance(id);
    }
  }

  // ─────────────────────────────── Build ───────────────────────────────

  @override
  Widget build(BuildContext context) {
    final header = PageHeader(
      title: 'Mes ordonnances',
      subtitle: _isLoading
          ? 'Chargement…'
          : (_total == 0 ? 'Aucune ordonnance pour le moment' : '$_total ordonnance${_total > 1 ? 's' : ''} · $_enCours en cours'),
      actions: [
        if (!widget.embedded)
          HeaderIconButton(icon: Icons.add_rounded, tooltip: 'Nouvelle ordonnance', onTap: () => pushSlide(context, const CreatePrescriptionScreen())),
      ],
      bottom: _ordonnances.isEmpty
          ? null
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  _FilterChip(label: 'Toutes', count: _total, selected: _filter == _Filter.all, onTap: () => setState(() => _filter = _Filter.all)),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'En cours', count: _enCours, selected: _filter == _Filter.active, color: AppColors.primary, onTap: () => setState(() => _filter = _Filter.active)),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Terminées', count: _terminees, selected: _filter == _Filter.done, color: AppColors.success, onTap: () => setState(() => _filter = _Filter.done)),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Annulées', count: _annulees, selected: _filter == _Filter.cancelled, color: AppColors.mutedForeground, onTap: () => setState(() => _filter = _Filter.cancelled)),
                ],
              ),
            ),
    );

    Widget body;
    if (_isLoading) {
      body = const SkeletonList(count: 4, itemHeight: 150, withLeading: false);
    } else if (_errorMessage != null) {
      body = ErrorState(message: _errorMessage!, onRetry: _fetchOrdonnances);
    } else if (_ordonnances.isEmpty) {
      body = RefreshIndicator(
        onRefresh: _fetchOrdonnances,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppSpacing.listPadding,
          children: [
            const SizedBox(height: 12),
            EmptyState(
              image: AppImages.emptyPrescriptions,
              imageHeight: 200,
              title: 'Aucune ordonnance',
              subtitle: 'Créez votre première ordonnance : TAKYMED programmera vos rappels automatiquement.',
              action: PrimaryButton.brand(
                label: 'Créer une ordonnance',
                icon: Icons.add_rounded,
                expanded: false,
                onPressed: () async {
                  await pushSlide(context, const CreatePrescriptionScreen());
                  _fetchOrdonnances();
                },
              ),
            ),
          ],
        ),
      );
    } else {
      final items = _filtered;
      body = RefreshIndicator(
        onRefresh: _fetchOrdonnances,
        color: AppColors.primary,
        child: items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppSpacing.listPadding,
                children: const [
                  SizedBox(height: 24),
                  EmptyState(
                    icon: Icons.filter_alt_off_rounded,
                    compact: true,
                    title: 'Rien dans cette catégorie',
                    subtitle: 'Changez de filtre pour voir vos autres ordonnances.',
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppSpacing.listPadding,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final ord = items[index];
                  return AnimatedFadeSlide(
                    index: index,
                    child: _OrdonnanceCard(
                      ord: ord,
                      isActive: _isActive(ord),
                      onTap: () => _openDetail(ord),
                      onMore: () => _showActions(ord),
                    ),
                  );
                },
              ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (!widget.embedded)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, 0, 0),
                child: Row(
                  children: [HeaderIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.maybePop(context))],
                ),
              ),
            header,
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.color = AppColors.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? color : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.foreground,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: selected ? Colors.white.withValues(alpha: 0.22) : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.mutedForeground,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrdonnanceCard extends StatelessWidget {
  final dynamic ord;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onMore;

  const _OrdonnanceCard({required this.ord, required this.isActive, required this.onTap, required this.onMore});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = (ord['prises_totales'] as num?)?.toInt() ?? 0;
    final done = (ord['prises_effectuees'] as num?)?.toInt() ?? 0;
    final progress = total > 0 ? (done / total).clamp(0.0, 1.0) : 0.0;
    final percent = (progress * 100).round();
    final date = DateTime.tryParse(ord['date_ordonnance']?.toString() ?? '');
    final complete = total > 0 && done >= total;
    final accent = !isActive ? AppColors.mutedForeground : (complete ? AppColors.success : AppColors.primary);
    final title = (ord['titre']?.toString().trim().isNotEmpty ?? false) ? ord['titre'].toString() : 'Ordonnance #${ord['id']}';

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 10, 16),
      onTap: onTap,
      onLongPress: onMore,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'ordonnance-${ord['id']}',
                flightShuttleBuilder: (_, _, _, _, _) => IconBox(icon: Icons.description_rounded, color: accent, size: 46),
                child: IconBox(icon: Icons.description_rounded, color: accent, size: 46),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if ((ord['nom_patient']?.toString() ?? '').isNotEmpty) ord['nom_patient'].toString(),
                        if (date != null) DateFormat.yMMMd('fr_FR').format(date),
                      ].join(' · '),
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              StatusBadge.fromOrdonnance(ord, small: true),
              IconButton(
                onPressed: onMore,
                icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.mutedForeground),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: accent.withValues(alpha: 0.12),
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('$percent%', style: theme.textTheme.labelLarge?.copyWith(color: accent, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.medication_outlined, size: 15, color: AppColors.mutedForeground),
              const SizedBox(width: 5),
              Text('${ord['nombre_medicaments'] ?? 0} médicament(s)', style: theme.textTheme.bodySmall),
              const SizedBox(width: 14),
              Icon(Icons.check_circle_outline_rounded, size: 15, color: AppColors.mutedForeground),
              const SizedBox(width: 5),
              Text('$done / $total prises', style: theme.textTheme.bodySmall),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.subtleForeground),
            ],
          ),
        ],
      ),
    );
  }
}
