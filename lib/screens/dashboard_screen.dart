import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;

import '../providers/auth_provider.dart';
import '../services/notification_service.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/med_helpers.dart';
import '../widgets/animated_fade_slide.dart';
import '../widgets/app_card.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/dose_tile.dart';
import '../widgets/icon_box.dart';
import '../widgets/loading_view.dart';
import '../widgets/main_shell.dart';
import '../widgets/medication_image.dart';
import '../widgets/page_header.dart';
import '../widgets/page_transitions.dart';
import '../widgets/primary_button.dart';
import '../widgets/skeleton.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_badge.dart';
import 'create_prescription_screen.dart';
import 'news_screen.dart';
import 'notifications_screen.dart';

/// Tableau de bord : prochaine prise, prises du jour par heure, observance, quotas, nouveautés.
class DashboardScreen extends StatefulWidget {
  final bool embedded;
  const DashboardScreen({super.key, this.embedded = false});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  Map<String, dynamic>? _data;
  List<dynamic> _news = [];
  bool _isLoading = true;
  String? _loadError;
  final Set<int> _busyDoses = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadData(silent: true);
  }

  Future<void> _loadData({bool silent = false}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final api = Provider.of<ApiService>(context, listen: false);
    if (auth.user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (!silent && _data == null && mounted) setState(() => _isLoading = true);
    try {
      final results = await Future.wait<dynamic>([api.getDashboard(auth.user!.id), api.getNews(limit: 8).catchError((_) => <Map<String, dynamic>>[])]);
      if (mounted) {
        setState(() {
          _data = results[0] as Map<String, dynamic>;
          _news = results[1] as List<dynamic>;
          _isLoading = false;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = 'Impossible de charger votre tableau de bord.';
        });
      }
    }
  }

  // ─────────────────────────── Données dérivées ───────────────────────────

  Map<String, dynamic>? get _stats => _data?['stats'] as Map<String, dynamic>?;

  List<Map<String, dynamic>> get _todayDoses {
    final doses = (_data?['doses'] as List<dynamic>?) ?? [];
    final now = tz.TZDateTime.now(NotificationService.localLocation);
    final result = <Map<String, dynamic>>[];
    for (final raw in doses) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final dt = DateTime.tryParse(map['scheduledAt']?.toString() ?? '');
      if (dt == null) continue;
      final local = tz.TZDateTime.from(dt.toUtc(), NotificationService.localLocation);
      if (local.year == now.year && local.month == now.month && local.day == now.day) {
        result.add(map);
      }
    }
    result.sort((a, b) => (a['scheduledAt']?.toString() ?? '').compareTo(b['scheduledAt']?.toString() ?? ''));
    return result;
  }

  /// Regroupe les prises du jour par heure "HH:MM" (ordre chronologique).
  List<MapEntry<String, List<Map<String, dynamic>>>> _groupByHour(List<Map<String, dynamic>> doses) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final d in doses) {
      final key = d['time']?.toString() ?? '--:--';
      groups.putIfAbsent(key, () => []).add(d);
    }
    final entries = groups.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  // ─────────────────────────────── Actions ───────────────────────────────

  Future<void> _toggleDose(Map<String, dynamic> dose, bool taken) async {
    final id = MedHelpers.parseId(dose['id']);
    if (id == null) return;
    final api = Provider.of<ApiService>(context, listen: false);
    setState(() => _busyDoses.add(id));
    try {
      await api.toggleDoseStatus(id, taken);
      if (!mounted) return;
      AppSnackbar.success(context, taken ? 'Prise confirmée' : 'Prise annulée');
      await _loadData(silent: true);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppSnackbar.clean(e));
    } finally {
      if (mounted) setState(() => _busyDoses.remove(id));
    }
  }

  Future<void> _delayDose(Map<String, dynamic> dose) async {
    final id = MedHelpers.parseId(dose['id']);
    if (id == null) return;
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      await api.delayDose(id);
      if (!mounted) return;
      AppSnackbar.info(context, 'Prise reportée');
      await _loadData(silent: true);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppSnackbar.clean(e));
    }
  }

  Future<void> _changeDoseTime(Map<String, dynamic> dose) async {
    final id = MedHelpers.parseId(dose['id']);
    if (id == null) return;
    final current = DateTime.tryParse(dose['scheduledAt']?.toString() ?? '') ?? DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current.toLocal()),
      helpText: 'Nouvelle heure de prise',
    );
    if (picked == null || !mounted) return;
    final local = current.toLocal();
    final newDt = DateTime(local.year, local.month, local.day, picked.hour, picked.minute);
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      await api.updateDoseTime(id, newDt.toIso8601String());
      if (!mounted) return;
      AppSnackbar.success(context, 'Heure mise à jour');
      await _loadData(silent: true);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppSnackbar.clean(e));
    }
  }

  void _goToPrescriptions() {
    final shell = MainShell.of(context);
    if (shell != null) {
      shell.selectTab(ShellTab.prescriptions);
    } else {
      Navigator.pushNamed(context, '/prescriptions');
    }
  }

  // ─────────────────────────────── Build ───────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final firstName = (user?.name ?? 'Utilisateur').trim().split(RegExp(r'\s+')).first;
    final now = DateTime.now();
    final dateStr = toBeginningOfSentenceCase(DateFormat('EEEE d MMMM', 'fr_FR').format(now));

    final header = PageHeader(
      overline: dateStr,
      title: 'Bonjour, $firstName 👋',
      leading: InitialsAvatar(name: user?.name ?? 'U', size: 46),
      actions: [
        HeaderIconButton(icon: Icons.newspaper_outlined, tooltip: 'Nouveautés', onTap: () => pushSlide(context, const NewsScreen())),
        HeaderIconButton(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Notifications',
          onTap: () => pushSlide(context, const NotificationsScreen()),
        ),
      ],
    );

    Widget body;
    if (_isLoading) {
      body = Column(
        children: [
          header,
          const Expanded(child: SkeletonDashboard()),
        ],
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () => _loadData(silent: true),
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: header),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, AppSpacing.bottomSafe),
              sliver: SliverList(delegate: SliverChildListDelegate(_buildSections(user?.type ?? 'standard'))),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(bottom: false, child: body),
    );
  }

  List<Widget> _buildSections(String userType) {
    final stats = _stats;
    final today = _todayDoses;
    final takenToday = today.where((d) => d['statusTaken'] == true || d['statusTaken'] == 1).length;
    final isExtended = userType == 'professional' || userType == 'pharmacist' || userType == 'admin';

    return [
      if (_loadError != null) ...[
        InfoBanner.error(
          message: _loadError!,
          action: GhostButton(label: 'Réessayer', icon: Icons.refresh_rounded, onPressed: _loadData),
        ),
        const SizedBox(height: 16),
      ],

      // ── Héros : prochaine prise ──
      AnimatedFadeSlide(
        index: 0,
        child: stats?['nextDose'] != null
            ? _NextDoseHero(
                dose: Map<String, dynamic>.from(stats!['nextDose'] as Map),
                busy: _busyDoses.contains(MedHelpers.parseId(stats['nextDose']['id'])),
                onTake: () => _toggleDose(Map<String, dynamic>.from(stats['nextDose'] as Map), true),
                onDelay: () => _delayDose(Map<String, dynamic>.from(stats['nextDose'] as Map)),
              )
            : _AllGoodHero(onCreate: () => pushSlide(context, const CreatePrescriptionScreen())),
      ),
      const SizedBox(height: 20),

      // ── Observance / statistiques ──
      if (stats != null) ...[
        AnimatedFadeSlide(
          index: 1,
          child: Column(
            children: [
              Row(
                children: [
                  StatCard(
                    label: 'Observance',
                    value: '${stats['observanceRate'] ?? 0}%',
                    icon: Icons.favorite_rounded,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 12),
                  StatCard(
                    label: 'Rappels actifs',
                    value: '${stats['activeReminders'] ?? 0}',
                    icon: Icons.notifications_active_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  StatCard(
                    label: 'En retard',
                    value: '${stats['overdueReminders'] ?? 0}',
                    icon: Icons.history_toggle_off_rounded,
                    color: AppColors.warning,
                  ),
                ],
              ),
              if (isExtended) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    StatCard(
                      label: 'Planifiés',
                      value: '${stats['plannedReminders'] ?? 0}',
                      icon: Icons.event_note_rounded,
                      color: AppColors.ai,
                    ),
                    const SizedBox(width: 12),
                    StatCard(
                      label: 'Pharmacies',
                      value: '${stats['nearbyPharmacies'] ?? 0}',
                      icon: Icons.local_pharmacy_rounded,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 12),
                    StatCard(
                      label: 'De garde',
                      value: '${stats['pharmaciesOnDuty'] ?? 0}',
                      icon: Icons.nightlight_round,
                      color: const Color(0xFF6366F1),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 28),
      ],

      // ── Prises du jour ──
      AnimatedFadeSlide(
        index: 2,
        child: SectionTitle(
          title: 'Aujourd\'hui',
          subtitle: today.isEmpty
              ? 'Aucune prise planifiée'
              : '${today.length} prise${today.length > 1 ? 's' : ''} planifiée${today.length > 1 ? 's' : ''}',
          trailing: today.isEmpty
              ? null
              : StatusBadge(
                  label: '$takenToday / ${today.length}',
                  type: takenToday == today.length ? StatusType.completed : StatusType.active,
                  icon: Icons.check_rounded,
                ),
        ),
      ),
      if (today.isEmpty)
        AnimatedFadeSlide(
          index: 3,
          child: AppCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: EmptyState(
              image: AppImages.emptyDoses,
              imageHeight: 150,
              compact: true,
              title: 'Rien à prendre aujourd\'hui',
              subtitle: 'Vos prochaines prises apparaîtront ici, groupées par heure.',
              action: SecondaryButton(
                label: 'Voir mes ordonnances',
                icon: Icons.description_outlined,
                expanded: false,
                height: 46,
                onPressed: _goToPrescriptions,
              ),
            ),
          ),
        )
      else
        ..._buildTimeline(today),
      const SizedBox(height: 28),

      // ── Quotas ──
      if (stats?['quota'] != null) ...[
        AnimatedFadeSlide(
          index: 4,
          child: QuotaSection(
            ordonnances: QuotaInfo.fromMap((stats!['quota'] as Map<String, dynamic>?)?['ordonnances'] as Map<String, dynamic>?),
            rappels: QuotaInfo.fromMap((stats['quota'] as Map<String, dynamic>?)?['rappels'] as Map<String, dynamic>?),
          ),
        ),
        const SizedBox(height: 28),
      ],

      // ── Nouveautés ──
      if (_news.isNotEmpty) ...[
        AnimatedFadeSlide(
          index: 5,
          child: SectionTitle(
            title: 'Actu',
            subtitle: 'Nouveautés et pharmacies partenaires',
            actionLabel: 'Tout voir',
            onAction: () => pushSlide(context, const NewsScreen()),
          ),
        ),
        AnimatedFadeSlide(
          index: 6,
          child: SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: _news.length.clamp(0, 8),
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) =>
                  _NewsMiniCard(item: Map<String, dynamic>.from(_news[i] as Map), onTap: () => pushSlide(context, const NewsScreen())),
            ),
          ),
        ),
      ],
    ];
  }

  List<Widget> _buildTimeline(List<Map<String, dynamic>> today) {
    final groups = _groupByHour(today);
    final widgets = <Widget>[];
    for (var g = 0; g < groups.length; g++) {
      final entry = groups[g];
      final allTaken = entry.value.every((d) => d['statusTaken'] == true || d['statusTaken'] == 1);
      final isLast = g == groups.length - 1;
      widgets.add(
        AnimatedFadeSlide(
          index: 3 + g,
          child: _HourGroup(
            hour: entry.key,
            allTaken: allTaken,
            isLast: isLast,
            children: [
              for (final d in entry.value)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DoseTile(
                    dose: d,
                    showTime: false,
                    busy: _busyDoses.contains(MedHelpers.parseId(d['id'])),
                    onToggle: (taken) => _toggleDose(d, taken),
                    onDelay: () => _delayDose(d),
                    onChangeTime: () => _changeDoseTime(d),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }
}

// ═══════════════════════════════ Widgets locaux ═══════════════════════════════

class _NextDoseHero extends StatelessWidget {
  final Map<String, dynamic> dose;
  final bool busy;
  final VoidCallback onTake;
  final VoidCallback onDelay;

  const _NextDoseHero({required this.dose, required this.busy, required this.onTake, required this.onDelay});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverdue = dose['isOverdue'] == true;
    final unit = dose['unit']?.toString() ?? '';
    final d = dose['dose'];
    final doseLabel = d == null ? unit : '$d $unit'.trim();
    final client = dose['clientName']?.toString() ?? '';
    final dt = DateTime.tryParse(dose['scheduledAt']?.toString() ?? '');
    String dayLabel = '';
    if (dt != null) {
      final local = tz.TZDateTime.from(dt.toUtc(), NotificationService.localLocation);
      final now = tz.TZDateTime.now(NotificationService.localLocation);
      final sameDay = local.year == now.year && local.month == now.month && local.day == now.day;
      dayLabel = sameDay ? 'Aujourd\'hui' : (toBeginningOfSentenceCase(DateFormat('EEE d MMM', 'fr_FR').format(local)) ?? '');
    }

    return HeroCard(
      gradient: isOverdue
          ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFB45309), Color(0xFFF59E0B)])
          : AppColors.brandGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(999)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isOverdue ? Icons.priority_high_rounded : Icons.alarm_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      isOverdue ? 'PRISE EN RETARD' : 'PROCHAINE PRISE',
                      style: theme.textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (dayLabel.isNotEmpty)
                Text(dayLabel, style: theme.textTheme.labelMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dose['medicationName']?.toString() ?? 'Médicament',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [if (doseLabel.isNotEmpty) doseLabel, if (client.isNotEmpty) client].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                dose['time']?.toString() ?? '--:--',
                style: theme.textTheme.displaySmall?.copyWith(color: Colors.white, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: busy ? null : onTake,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: isOverdue ? const Color(0xFFB45309) : AppColors.primary,
                      disabledBackgroundColor: Colors.white.withValues(alpha: 0.7),
                      minimumSize: const Size(0, 46),
                    ),
                    icon: busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check_rounded, size: 20),
                    label: const Text('Marquer comme prise'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 46,
                width: 46,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: AppRadius.rMd,
                  child: InkWell(
                    onTap: busy ? null : onDelay,
                    borderRadius: AppRadius.rMd,
                    child: const Tooltip(
                      message: 'Reporter',
                      child: Icon(Icons.snooze_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.98, 0.98));
  }
}

class _AllGoodHero extends StatelessWidget {
  final VoidCallback onCreate;
  const _AllGoodHero({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HeroCard(
      padding: const EdgeInsets.fromLTRB(22, 20, 12, 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    'TOUT EST À JOUR',
                    style: theme.textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Aucune prise\nen attente', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white)),
                const SizedBox(height: 6),
                Text(
                  'Ajoutez une ordonnance pour recevoir vos rappels.',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                ),
                const SizedBox(height: 14),
                PillButton(
                  label: 'Nouvelle ordonnance',
                  icon: Icons.add_rounded,
                  filled: true,
                  color: Colors.white.withValues(alpha: 0.22),
                  onPressed: onCreate,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 110,
            height: 110,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
            child: Image.asset(AppImages.emptyDoses, fit: BoxFit.contain),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.98, 0.98));
  }
}

class _HourGroup extends StatelessWidget {
  final String hour;
  final bool allTaken;
  final bool isLast;
  final List<Widget> children;

  const _HourGroup({required this.hour, required this.allTaken, required this.isLast, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = allTaken ? AppColors.success : AppColors.primary;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 58,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(color: allTaken ? AppColors.successLight : AppColors.primaryLight, borderRadius: AppRadius.rSm),
                  child: Text(
                    hour,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(children: children)),
        ],
      ),
    );
  }
}

class _NewsMiniCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _NewsMiniCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = item['type']?.toString();
    final med = item['medication'] is Map ? Map<String, dynamic>.from(item['medication'] as Map) : null;
    final pharmacy = item['pharmacy'] is Map ? Map<String, dynamic>.from(item['pharmacy'] as Map) : null;
    final rawImage = item['imageUrl']?.toString();
    final image = MedHelpers.photoForList(
      (rawImage != null && rawImage.isNotEmpty && rawImage != 'null') ? rawImage : med?['photoUrl']?.toString(),
    );
    final subtitle = med?['name']?.toString() ?? pharmacy?['name']?.toString() ?? item['summary']?.toString() ?? '';
    final (badge, badgeType, icon) = switch (type) {
      'pharmacie' => ('Pharmacie', StatusType.completed, Icons.local_pharmacy_rounded),
      'info' => ('Info', StatusType.warning, Icons.campaign_rounded),
      _ => ('Médicament', StatusType.active, Icons.medication_rounded),
    };
    return SizedBox(
      width: 160,
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                if (image != null)
                  MedicationImage(photoUrl: image, width: double.infinity, height: 104, borderRadius: 0, fit: BoxFit.cover)
                else
                  Container(
                    height: 104,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: type == 'pharmacie'
                            ? const [AppColors.secondary, AppColors.secondaryDark]
                            : const [AppColors.gradientStart, AppColors.gradientEnd],
                      ),
                    ),
                    child: Icon(icon, size: 36, color: Colors.white.withValues(alpha: 0.9)),
                  ),
                Positioned(top: 8, left: 8, child: StatusBadge(label: badge, type: badgeType, small: true)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title']?.toString() ?? 'Actualité',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icône décorative (réutilisée par d'autres écrans pour les liens rapides).
class DashboardQuickIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const DashboardQuickIcon({super.key, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => IconBox(icon: icon, color: color, size: 40);
}
