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
import '../widgets/page_header.dart';
import '../widgets/page_transitions.dart';
import '../widgets/primary_button.dart';
import '../widgets/skeleton.dart';
import '../widgets/status_badge.dart';
import 'commercial_register_screen.dart';
import 'create_prescription_screen.dart';
import 'notifications_screen.dart';

enum _ClientFilter { all, valid, pending }

/// Espace commercial : indicateurs, liste des clients et actions (message, ordonnance, renommer, supprimer).
class CommercialDashboardScreen extends StatefulWidget {
  final bool embedded;

  const CommercialDashboardScreen({super.key, this.embedded = false});

  @override
  State<CommercialDashboardScreen> createState() => _CommercialDashboardScreenState();
}

class _CommercialDashboardScreenState extends State<CommercialDashboardScreen> {
  List<dynamic> _clients = [];
  Map<String, dynamic>? _summary;
  bool _isLoading = true;
  String? _error;
  _ClientFilter _filter = _ClientFilter.all;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    fetchClients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  AuthProvider get _auth => Provider.of<AuthProvider>(context, listen: false);
  ApiService get _api => Provider.of<ApiService>(context, listen: false);

  Future<void> fetchClients() async {
    final user = _auth.user;
    if (user == null) return;
    setState(() {
      _isLoading = _clients.isEmpty;
      _error = null;
    });

    List<dynamic> loadedClients = _clients;
    Map<String, dynamic>? loadedSummary = _summary;
    String? errorMessage;

    try {
      loadedClients = await _api.getCommercialClients(user.id);
    } catch (e) {
      errorMessage = 'Impossible de charger la liste des clients';
      debugPrint('Commercial clients error: $e');
    }
    try {
      loadedSummary = await _api.getCommercialStats(user.id);
    } catch (e) {
      debugPrint('Commercial stats error: $e');
    }

    if (!mounted) return;
    setState(() {
      _clients = loadedClients;
      _summary = loadedSummary;
      _isLoading = false;
      _error = errorMessage != null && loadedClients.isEmpty ? errorMessage : null;
    });
    if (errorMessage != null && loadedClients.isNotEmpty) AppSnackbar.warning(context, errorMessage);
  }

  static bool _isValid(dynamic c) => c['isValid'] == 1 || c['isValid'] == true;

  List<dynamic> get _filteredClients {
    var list = _clients;
    switch (_filter) {
      case _ClientFilter.valid:
        list = list.where(_isValid).toList();
      case _ClientFilter.pending:
        list = list.where((c) => !_isValid(c)).toList();
      case _ClientFilter.all:
        break;
    }
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((c) => (c['name']?.toString().toLowerCase().contains(q) ?? false) || (c['phone']?.toString().contains(q) ?? false)).toList();
  }

  // ─────────────────────────────── Actions ───────────────────────────────

  Future<void> _renameClient(int id, String currentName) async {
    final controller = TextEditingController(text: currentName);
    String? newName;
    try {
      newName = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Renommer le client'),
          content: AppTextField(controller: controller, label: 'Nouveau nom', autofocus: true, textCapitalization: TextCapitalization.words),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Enregistrer')),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
    if (newName == null || newName.isEmpty || newName == currentName) return;
    try {
      await _api.updateClientName(_auth.user!.id, id, newName);
      if (mounted) AppSnackbar.success(context, 'Client renommé');
      await fetchClients();
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'Échec de la modification');
    }
  }

  Future<void> _deleteClient(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer $name ?'),
        content: const Text('Le client et ses ordonnances seront retirés de votre portefeuille. Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.deleteClient(_auth.user!.id, id);
      if (mounted) AppSnackbar.success(context, 'Client supprimé');
      await fetchClients();
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'Échec de la suppression');
    }
  }

  Future<void> _sendMessage(int clientId, String clientName) async {
    final controller = TextEditingController();
    bool sent = false;
    try {
      final result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (ctx) {
          bool sending = false;
          return StatefulBuilder(
            builder: (_, setSheet) => Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 24 + MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Message à $clientName', style: Theme.of(ctx).textTheme.titleLarge)),
                      IconButton(onPressed: sending ? null : () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppTextField(controller: controller, label: 'Votre message', hint: 'Bonjour, …', maxLines: 4, minLines: 3, autofocus: true),
                  const SizedBox(height: 10),
                  const InfoBanner(icon: Icons.timer_outlined, message: 'Ce message sera visible dans son application pendant 3 jours.'),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Envoyer',
                    icon: Icons.send_rounded,
                    isLoading: sending,
                    onPressed: () async {
                      if (controller.text.trim().isEmpty) return;
                      setSheet(() => sending = true);
                      try {
                        await _api.sendMessageToClient(_auth.user!.id, clientId, controller.text.trim());
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        if (ctx.mounted) {
                          AppSnackbar.error(ctx, AppSnackbar.clean(e));
                          setSheet(() => sending = false);
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
      sent = result == true;
    } finally {
      controller.dispose();
    }
    if (sent && mounted) AppSnackbar.success(context, 'Message envoyé');
  }

  Future<void> _registerClient() async {
    await pushSlide(context, const CommercialRegisterScreen());
    await fetchClients();
  }

  void _createPrescriptionFor(dynamic client) {
    final clientId = (client['id'] as num?)?.toInt();
    if (clientId == null || clientId <= 0) return;
    pushSlide(context, CreatePrescriptionScreen(targetUserId: clientId, targetUserName: client['name'] as String?));
  }

  // ─────────────────────────────── Build ───────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    if (auth.user == null || auth.user!.type != 'commercial') {
      return const Scaffold(
        body: EmptyState(icon: Icons.lock_rounded, title: 'Accès refusé', subtitle: 'Cet espace est réservé aux comptes commerciaux.'),
      );
    }

    final theme = Theme.of(context);
    final firstName = auth.user!.name.trim().split(RegExp(r'\s+')).first;
    final totalClients = (_summary?['totalClients'] as num?)?.toInt() ?? _clients.length;
    final validClients = (_summary?['validClients'] as num?)?.toInt() ?? _clients.where(_isValid).length;
    final pendingClients = (_summary?['pendingClients'] as num?)?.toInt() ?? (totalClients - validClients);
    final totalPrescriptions = (_summary?['totalPrescriptions'] as num?)?.toInt() ??
        _clients.fold<int>(0, (acc, c) => acc + ((c['prescriptionCount'] as num?)?.toInt() ?? 0));
    final totalReminders = (_summary?['totalReminders'] as num?)?.toInt() ??
        _clients.fold<int>(0, (acc, c) => acc + ((c['reminderCount'] as num?)?.toInt() ?? 0));
    final activeReminders = (_summary?['activeReminders'] as num?)?.toInt() ?? totalReminders;
    final overdueReminders = (_summary?['overdueReminders'] as num?)?.toInt() ?? 0;

    final filtered = _filteredClients;

    final list = RefreshIndicator(
      onRefresh: fetchClients,
      child: _isLoading
          ? const SkeletonDashboard()
          : _error != null
              ? ErrorState(message: _error!, onRetry: fetchClients)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 110),
                  children: [
                    AnimatedFadeSlide(
                      index: 0,
                      child: HeroCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Portefeuille clients', style: theme.textTheme.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.85), letterSpacing: 0.6)),
                                      const SizedBox(height: 4),
                                      Text('$totalClients client${totalClients > 1 ? 's' : ''}', style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white)),
                                      const SizedBox(height: 4),
                                      Text('$validClients validé${validClients > 1 ? 's' : ''} · $pendingClients en attente', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
                                    ],
                                  ),
                                ),
                                Image.asset(AppImages.hero, height: 84, fit: BoxFit.contain),
                              ],
                            ),
                            const SizedBox(height: 16),
                            PrimaryButton(
                              label: 'Inscrire un client',
                              icon: Icons.person_add_rounded,
                              height: 48,
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primary,
                              onPressed: _registerClient,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    AnimatedFadeSlide(
                      index: 1,
                      child: Row(
                        children: [
                          Expanded(child: _StatTile(icon: Icons.description_outlined, label: 'Ordonnances', value: totalPrescriptions, color: AppColors.primary)),
                          const SizedBox(width: 10),
                          Expanded(child: _StatTile(icon: Icons.alarm_on_rounded, label: 'Rappels actifs', value: activeReminders, color: AppColors.secondary)),
                          const SizedBox(width: 10),
                          Expanded(child: _StatTile(icon: Icons.alarm_off_rounded, label: 'En retard', value: overdueReminders, color: overdueReminders > 0 ? AppColors.destructive : AppColors.mutedForeground)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    SectionTitle(
                      title: 'Vos clients',
                      subtitle: '${filtered.length} affiché${filtered.length > 1 ? 's' : ''}',
                      trailing: PillButton(
                        label: 'Rappel pour moi',
                        icon: Icons.add_alarm_rounded,
                        onPressed: () => pushSlide(context, const CreatePrescriptionScreen()),
                      ),
                    ),
                    if (_clients.isNotEmpty) ...[
                      AppSearchField(controller: _searchController, hint: 'Rechercher un client…', onClear: () => _searchController.clear()),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _filterChip('Tous', _ClientFilter.all, _clients.length),
                          const SizedBox(width: 8),
                          _filterChip('Validés', _ClientFilter.valid, validClients),
                          const SizedBox(width: 8),
                          _filterChip('En attente', _ClientFilter.pending, pendingClients),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (_clients.isEmpty)
                      EmptyState(
                        image: AppImages.hero,
                        imageHeight: 150,
                        compact: true,
                        title: 'Aucun client pour le moment',
                        subtitle: 'Inscrivez votre premier client : il recevra son PIN par SMS et vous pourrez suivre ses rappels.',
                        action: PrimaryButton(label: 'Inscrire un client', icon: Icons.person_add_rounded, expanded: false, height: 46, onPressed: _registerClient),
                      )
                    else if (filtered.isEmpty)
                      EmptyState(
                        icon: Icons.filter_alt_off_rounded,
                        compact: true,
                        title: 'Aucun résultat',
                        subtitle: 'Aucun client ne correspond à votre recherche.',
                      )
                    else
                      for (var i = 0; i < filtered.length; i++)
                        AnimatedFadeSlide(
                          index: i,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ClientCard(
                              client: filtered[i],
                              onRename: () => _renameClient(filtered[i]['id'] as int, filtered[i]['name'] as String),
                              onDelete: () => _deleteClient(filtered[i]['id'] as int, filtered[i]['name'] as String),
                              onMessage: () => _sendMessage(filtered[i]['id'] as int, filtered[i]['name'] as String),
                              onPrescription: _isValid(filtered[i]) ? () => _createPrescriptionFor(filtered[i]) : null,
                            ),
                          ),
                        ),
                  ],
                ),
    );

    final body = Column(
      children: [
        if (widget.embedded)
          PageHeader(
            overline: 'Espace commercial',
            title: 'Bonjour, $firstName 👋',
            leading: InitialsAvatar(name: auth.user!.name, size: 46),
            actions: [
              HeaderIconButton(icon: Icons.notifications_outlined, tooltip: 'Notifications', onTap: () => pushSlide(context, const NotificationsScreen())),
            ],
          ),
        Expanded(child: list),
      ],
    );

    if (widget.embedded) {
      return Scaffold(backgroundColor: AppColors.background, body: SafeArea(bottom: false, child: body));
    }
    return Scaffold(backgroundColor: AppColors.background, appBar: const AppTopBar(title: 'Espace commercial'), body: body);
  }

  Widget _filterChip(String label, _ClientFilter value, int count) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text('$label · $count'),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      labelStyle: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? AppColors.primary : AppColors.foreground),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  const _StatTile({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBox(icon: icon, color: color, size: 36, iconSize: 18),
          const SizedBox(height: 10),
          Text('$value', style: theme.textTheme.headlineSmall?.copyWith(color: color)),
          Text(label, style: theme.textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  final dynamic client;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onMessage;
  final VoidCallback? onPrescription;

  const _ClientCard({
    required this.client,
    required this.onRename,
    required this.onDelete,
    required this.onMessage,
    this.onPrescription,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isValid = client['isValid'] == 1 || client['isValid'] == true;
    final name = client['name']?.toString() ?? 'Client';
    final phone = client['phone']?.toString() ?? '';
    final ordos = (client['prescriptionCount'] as num?)?.toInt() ?? 0;
    final reminders = (client['reminderCount'] as num?)?.toInt() ?? 0;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
      child: Column(
        children: [
          Row(
            children: [
              InitialsAvatar(name: name, size: 46, color: isValid ? AppColors.secondary : AppColors.warning),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(phone, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              StatusBadge(
                label: isValid ? 'Validé' : 'En attente',
                type: isValid ? StatusType.validated : StatusType.pending,
                small: true,
              ),
              PopupMenuButton<String>(
                tooltip: 'Plus d\'actions',
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.mutedForeground),
                onSelected: (v) => v == 'rename' ? onRename() : onDelete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: ListTile(dense: true, leading: Icon(Icons.edit_rounded, size: 20), title: Text('Renommer'))),
                  PopupMenuItem(value: 'delete', child: ListTile(dense: true, leading: Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.destructive), title: Text('Supprimer', style: TextStyle(color: AppColors.destructive)))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MiniStat(icon: Icons.description_outlined, text: '$ordos ordo.'),
              const SizedBox(width: 14),
              _MiniStat(icon: Icons.notifications_outlined, text: '$reminders rappel${reminders > 1 ? 's' : ''}'),
              const Spacer(),
              PillButton(label: 'Message', icon: Icons.chat_bubble_outline_rounded, color: AppColors.warning, onPressed: onMessage),
              if (onPrescription != null) ...[
                const SizedBox(width: 6),
                PillButton(label: 'Ordonnance', icon: Icons.add_alarm_rounded, filled: true, onPressed: onPrescription),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MiniStat({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.mutedForeground),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
