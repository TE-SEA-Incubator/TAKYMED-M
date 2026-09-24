import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/reminder_schedule_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_card.dart';
import 'app_snackbar.dart';
import 'app_text_field.dart';
import 'icon_box.dart';
import 'page_header.dart';
import 'primary_button.dart';
import 'status_badge.dart';

typedef OrdonnanceRefresh = Future<void> Function();

/// Contenu détaillé d'une ordonnance : médicaments + rappels, avec actions d'édition.
class OrdonnanceDetailPanel extends StatefulWidget {
  final dynamic ord;
  final dynamic details;
  final int userId;
  final ApiService api;
  final OrdonnanceRefresh onRefresh;

  const OrdonnanceDetailPanel({
    super.key,
    required this.ord,
    required this.details,
    required this.userId,
    required this.api,
    required this.onRefresh,
  });

  @override
  State<OrdonnanceDetailPanel> createState() => OrdonnanceDetailPanelState();
}

class OrdonnanceDetailPanelState extends State<OrdonnanceDetailPanel> {
  bool _showAllReminders = false;
  bool _showTaken = true;
  final Set<int> _busy = {};

  bool get _active => widget.ord['est_active'] == 1 || widget.ord['est_active'] == true;

  Future<void> _reloadDetails() async {
    await widget.onRefresh();
    await ReminderScheduleService.syncFromServer(widget.api, widget.userId);
  }

  /// Une prise ne peut être validée que si son heure prévue est passée (règle aussi appliquée par le serveur).
  static bool _isDue(String scheduledAt) {
    final sched = DateTime.tryParse(scheduledAt);
    if (sched == null) return true;
    return !sched.isAfter(DateTime.now());
  }

  Future<void> _toggleDose(int doseId, bool currentlyTaken, String scheduledAt) async {
    if (!currentlyTaken && !_isDue(scheduledAt)) {
      final sched = DateTime.tryParse(scheduledAt)?.toLocal();
      final when = sched == null ? '' : ' (prévue à ${DateFormat.Hm('fr_FR').format(sched)})';
      AppSnackbar.warning(context, 'Cette prise ne peut pas encore être validée$when.');
      return;
    }
    setState(() => _busy.add(doseId));
    try {
      await widget.api.toggleDoseStatus(doseId, !currentlyTaken);
      await _reloadDetails();
      if (mounted) AppSnackbar.success(context, currentlyTaken ? 'Prise annulée' : 'Prise confirmée');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppSnackbar.clean(e));
    } finally {
      if (mounted) setState(() => _busy.remove(doseId));
    }
  }

  Future<void> _delayDose(int doseId) async {
    try {
      await widget.api.delayDose(doseId);
      await _reloadDetails();
      if (mounted) AppSnackbar.info(context, 'Prise reportée de 1 heure');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppSnackbar.clean(e));
    }
  }

  Future<void> _editDoseTime(int doseId, DateTime current) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      helpText: 'Nouvelle heure de prise',
    );
    if (time == null) return;
    final updated = DateTime(current.year, current.month, current.day, time.hour, time.minute);
    try {
      await widget.api.updateDoseTime(doseId, updated.toIso8601String());
      await _reloadDetails();
      if (mounted) AppSnackbar.success(context, 'Heure mise à jour');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppSnackbar.clean(e));
    }
  }

  Future<void> _markAllTaken() async {
    try {
      await widget.api.markAllPrisesTaken(widget.ord['id'] as int);
      await _reloadDetails();
      if (mounted) AppSnackbar.success(context, 'Prises échues validées');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppSnackbar.clean(e));
    }
  }

  /// Le champ « patient » est réservé aux comptes professionnels et plus.
  bool get _isProPlus {
    final auth = context.read<AuthProvider?>();
    final type = auth?.user?.type.toLowerCase() ?? 'standard';
    return type != 'standard';
  }

  /// Ouvre la feuille d'édition de l'ordonnance (titre, patient pour les pros, catégorie).
  Future<void> editOrdonnance() async {
    final titreCtrl = TextEditingController(text: widget.ord['titre']?.toString() ?? '');
    final patientCtrl = TextEditingController(text: widget.ord['nom_patient']?.toString() ?? '');
    final showPatient = _isProPlus;
    String categorie = (widget.ord['categorie_age']?.toString() ?? 'adulte').toLowerCase();
    if (!const ['enfant', 'adulte', 'senior'].contains(categorie)) categorie = 'adulte';

    try {
      final saved = await _showFormSheet(
        title: 'Modifier l\'ordonnance',
        submitLabel: 'Enregistrer',
        builder: (setModal) => [
          AppTextField(controller: titreCtrl, label: 'Titre', hint: 'Ex : Traitement antibiotique', autofocus: true),
          if (showPatient) ...[
            const SizedBox(height: 14),
            AppTextField(controller: patientCtrl, label: 'Patient', hint: 'Nom du patient', prefixIcon: Icons.person_outline_rounded),
          ],
          const SizedBox(height: 14),
          Text('Catégorie d\'âge', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _SegmentRow(
            options: const {'enfant': 'Enfant', 'adulte': 'Adulte', 'senior': 'Senior'},
            value: categorie,
            onChanged: (v) => setModal(() => categorie = v),
          ),
        ],
      );
      if (saved != true) return;

      await widget.api.updateOrdonnance(
        widget.ord['id'] as int,
        titreCtrl.text.trim(),
        patientCtrl.text.trim(),
        categorie,
        userId: widget.userId,
      );
      await _reloadDetails();
      if (mounted) AppSnackbar.success(context, 'Ordonnance mise à jour');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppSnackbar.clean(e));
    } finally {
      titreCtrl.dispose();
      patientCtrl.dispose();
    }
  }

  Future<void> _addMedicament() async {
    final nameCtrl = TextEditingController();
    final doseCtrl = TextEditingController(text: '1');
    final daysCtrl = TextEditingController(text: '1');
    String freq = '1x';
    DateTime startDate = DateTime.now();

    bool ok = false;
    String savedName = '';
    int savedDose = 1;
    int savedDays = 1;
    String savedFreq = '1x';

    try {
      ok = await _showFormSheet(
            title: 'Ajouter un médicament',
            submitLabel: 'Ajouter',
            builder: (setModal) => [
              AppTextField(
                controller: nameCtrl,
                label: 'Nom du médicament',
                hint: 'Ex : Paracétamol 500 mg',
                prefixIcon: Icons.medication_outlined,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(controller: doseCtrl, label: 'Dose', hint: '1', keyboardType: TextInputType.number),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(controller: daysCtrl, label: 'Durée (jours)', hint: '1', keyboardType: TextInputType.number),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text('Début de prise', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _DateField(
                value: startDate,
                onPick: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: startDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    helpText: 'Début de prise de ce médicament',
                    locale: const Locale('fr', 'FR'),
                  );
                  if (picked != null) setModal(() => startDate = picked);
                },
              ),
              const SizedBox(height: 14),
              Text('Fréquence', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _FrequencyChips(value: freq, onChanged: (v) => setModal(() => freq = v)),
            ],
          ) ==
          true;

      savedName = nameCtrl.text.trim();
      savedDose = int.tryParse(doseCtrl.text) ?? 1;
      savedDays = int.tryParse(daysCtrl.text) ?? 1;
      savedFreq = freq;
    } finally {
      nameCtrl.dispose();
      doseCtrl.dispose();
      daysCtrl.dispose();
    }

    if (!ok) return;
    if (savedName.isEmpty) {
      if (mounted) AppSnackbar.warning(context, 'Le nom du médicament est requis');
      return;
    }

    try {
      await widget.api.addMedicament(widget.ord['id'] as int, {
        'medicamentName': savedName,
        'dose': savedDose,
        'type_frequence': savedFreq,
        'intervalle_heures': savedFreq == 'interval' ? 8 : null,
        'duree_jours': savedDays,
        'times': ['08:00'],
        'date_debut': DateFormat('yyyy-MM-dd').format(startDate),
      });
      await _reloadDetails();
      if (mounted) AppSnackbar.success(context, 'Médicament ajouté');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppSnackbar.clean(e));
    }
  }

  Future<void> _editMedicament(dynamic med) async {
    final doseCtrl = TextEditingController(text: '${med['dose']}');
    final daysCtrl = TextEditingController(text: '${med['duree_jours']}');
    String freq = med['type_frequence']?.toString() ?? '1x';

    try {
      final ok = await _showFormSheet(
        title: med['medicament']?.toString() ?? 'Médicament',
        submitLabel: 'Enregistrer',
        builder: (setModal) => [
          Row(
            children: [
              Expanded(child: AppTextField(controller: doseCtrl, label: 'Dose', keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: AppTextField(controller: daysCtrl, label: 'Durée (jours)', keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 14),
          Text('Fréquence', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _FrequencyChips(value: freq, onChanged: (v) => setModal(() => freq = v)),
        ],
      );
      if (ok != true) return;

      await widget.api.updateMedicament(widget.ord['id'] as int, med['id'] as int, {
        'dose': int.tryParse(doseCtrl.text) ?? 1,
        'type_frequence': freq,
        'intervalle_heures': freq == 'interval' ? 8 : null,
        'duree_jours': int.tryParse(daysCtrl.text) ?? 1,
      });
      await _reloadDetails();
      if (mounted) AppSnackbar.success(context, 'Médicament mis à jour');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppSnackbar.clean(e));
    } finally {
      doseCtrl.dispose();
      daysCtrl.dispose();
    }
  }

  Future<void> _deleteMedicament(dynamic med) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le médicament ?'),
        content: Text('« ${med['medicament']} » et ses rappels seront retirés de l\'ordonnance.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await widget.api.deleteMedicament(widget.ord['id'] as int, med['id'] as int);
      await _reloadDetails();
      if (mounted) AppSnackbar.success(context, 'Médicament supprimé');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppSnackbar.clean(e));
    }
  }

  Future<bool?> _showFormSheet({
    required String title,
    required String submitLabel,
    required List<Widget> Function(void Function(VoidCallback) setModal) builder,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 18),
                ...builder(setModal),
                const SizedBox(height: 22),
                PrimaryButton(label: submitLabel, onPressed: () => Navigator.pop(ctx, true)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String frequencyLabel(String? f) {
    switch (f) {
      case '1x':
        return '1 fois / jour';
      case '2x':
        return '2 fois / jour';
      case '3x':
        return '3 fois / jour';
      case 'interval':
        return 'À intervalles';
      case 'prn':
        return 'Si besoin';
      default:
        return f ?? '';
    }
  }

  // ─────────────────────────────── Build ───────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.details == null) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final medicaments = widget.details['medicaments'] as List<dynamic>? ?? [];
    final rappels = widget.details['rappels'] as List<dynamic>? ?? [];
    final hasDuePending = rappels.any((r) => r['statut_prise'] != 1 && _isDue(r['heure_prevue'].toString()));

    final visible = rappels.where((r) => _showTaken || r['statut_prise'] != 1).toList();
    final limited = _showAllReminders ? visible : visible.take(20).toList();
    final grouped = _groupByDay(limited);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Médicaments ──
        SectionTitle(
          title: 'Médicaments',
          subtitle: '${medicaments.length} dans cette ordonnance',
          trailing: _active
              ? PillButton(label: 'Ajouter', icon: Icons.add_rounded, onPressed: _addMedicament)
              : null,
        ),
        if (medicaments.isEmpty)
          AppCard(
            child: Row(
              children: [
                const IconBox(icon: Icons.medication_outlined, color: AppColors.mutedForeground),
                const SizedBox(width: 12),
                Expanded(child: Text('Aucun médicament pour le moment.', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedForeground))),
              ],
            ),
          )
        else
          ...medicaments.map((med) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  child: Row(
                    children: [
                      const IconBox(icon: Icons.medication_rounded, color: AppColors.primary, size: 42),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(med['medicament']?.toString() ?? '', style: theme.textTheme.titleSmall),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                StatusBadge(label: 'Dose ${med['dose']}', type: StatusType.info, small: true),
                                StatusBadge(label: frequencyLabel(med['type_frequence']?.toString()), type: StatusType.neutral, small: true),
                                StatusBadge(label: '${med['duree_jours']} j', type: StatusType.neutral, small: true),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (_active)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded, color: AppColors.mutedForeground, size: 20),
                          onSelected: (v) {
                            if (v == 'edit') _editMedicament(med);
                            if (v == 'delete') _deleteMedicament(med);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 10), Text('Modifier')]),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [
                                Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.destructive),
                                SizedBox(width: 10),
                                Text('Supprimer', style: TextStyle(color: AppColors.destructive)),
                              ]),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              )),

        const SizedBox(height: 20),

        // ── Rappels ──
        SectionTitle(
          title: 'Rappels',
          subtitle: rappels.isEmpty ? 'Aucun rappel planifié' : '${rappels.where((r) => r['statut_prise'] == 1).length} / ${rappels.length} prises effectuées',
          trailing: _active && hasDuePending
              ? PillButton(label: 'Valider les échues', icon: Icons.done_all_rounded, color: AppColors.success, onPressed: _markAllTaken)
              : null,
        ),
        if (rappels.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Afficher les prises effectuées'),
                  selected: _showTaken,
                  onSelected: (v) => setState(() => _showTaken = v),
                  showCheckmark: true,
                  checkmarkColor: AppColors.primary,
                ),
              ],
            ),
          ),
        if (rappels.isEmpty)
          AppCard(
            child: Row(
              children: [
                const IconBox(icon: Icons.notifications_off_outlined, color: AppColors.mutedForeground),
                const SizedBox(width: 12),
                Expanded(child: Text('Aucun rappel planifié pour cette ordonnance.', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedForeground))),
              ],
            ),
          )
        else ...[
          for (final day in grouped.entries) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Text(
                day.key,
                style: theme.textTheme.labelMedium?.copyWith(color: AppColors.mutedForeground, fontWeight: FontWeight.w700, letterSpacing: 0.4),
              ),
            ),
            for (final rappel in day.value) _ReminderRow(
              rappel: rappel,
              active: _active,
              busy: _busy.contains(rappel['id']),
              isDue: _isDue(rappel['heure_prevue'].toString()),
              onToggle: (taken, raw) => _toggleDose(rappel['id'] as int, taken, raw),
              onDelay: () => _delayDose(rappel['id'] as int),
              onEditTime: (dt) => _editDoseTime(rappel['id'] as int, dt),
            ),
          ],
          if (visible.length > 20)
            Center(
              child: GhostButton(
                label: _showAllReminders ? 'Réduire' : 'Afficher les ${visible.length - 20} autres rappels',
                icon: _showAllReminders ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                onPressed: () => setState(() => _showAllReminders = !_showAllReminders),
              ),
            ),
        ],
      ],
    );
  }

  Map<String, List<dynamic>> _groupByDay(List<dynamic> rappels) {
    final result = <String, List<dynamic>>{};
    final now = DateTime.now();
    for (final r in rappels) {
      final dt = DateTime.tryParse(r['heure_prevue'].toString())?.toLocal();
      String key;
      if (dt == null) {
        key = 'Date inconnue';
      } else if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        key = 'AUJOURD\'HUI';
      } else if (dt.year == now.year && dt.month == now.month && dt.day == now.day + 1) {
        key = 'DEMAIN';
      } else {
        key = DateFormat('EEEE d MMMM', 'fr_FR').format(dt).toUpperCase();
      }
      result.putIfAbsent(key, () => []).add(r);
    }
    return result;
  }
}

class _ReminderRow extends StatelessWidget {
  final dynamic rappel;
  final bool active;
  final bool busy;
  final bool isDue;
  final void Function(bool currentlyTaken, String raw) onToggle;
  final VoidCallback onDelay;
  final ValueChanged<DateTime> onEditTime;

  const _ReminderRow({
    required this.rappel,
    required this.active,
    required this.busy,
    required this.isDue,
    required this.onToggle,
    required this.onDelay,
    required this.onEditTime,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taken = rappel['statut_prise'] == 1;
    final raw = rappel['heure_prevue'].toString();
    final dt = (DateTime.tryParse(raw) ?? DateTime.now()).toLocal();
    final upcoming = !taken && !isDue;
    final overdue = !taken && isDue;
    final accent = taken ? AppColors.success : (overdue ? AppColors.warning : AppColors.primary);
    final canToggle = active && !upcoming;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: taken ? AppColors.successLight.withValues(alpha: 0.5) : AppColors.surface,
        borderRadius: AppRadius.rMd,
        border: Border.all(color: taken ? AppColors.secondary.withValues(alpha: 0.25) : AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.rMd,
          onTap: canToggle && !busy ? () => onToggle(taken, raw) : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: canToggle && !busy ? () => onToggle(taken, raw) : null,
                  child: Tooltip(
                    message: upcoming ? 'Validation possible à partir de ${DateFormat.Hm('fr_FR').format(dt)}' : '',
                    child: AnimatedContainer(
                      duration: AppDurations.normal,
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: taken ? AppColors.success : Colors.transparent,
                        border: Border.all(
                          color: taken ? AppColors.success : (canToggle ? AppColors.borderStrong : AppColors.border),
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: busy
                          ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: taken ? Colors.white : accent))
                          : Icon(taken ? Icons.check_rounded : Icons.circle, size: taken ? 18 : 0, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rappel['medicament']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: taken ? AppColors.mutedForeground : AppColors.foreground,
                          decoration: taken ? TextDecoration.lineThrough : null,
                          decorationColor: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          'Dose ${rappel['dose']}',
                          if (upcoming) 'À venir',
                          if (overdue) 'À valider',
                        ].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: overdue ? AppColors.warning : AppColors.mutedForeground,
                          fontWeight: overdue ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: active && !taken ? () => onEditTime(dt) : null,
                  borderRadius: AppRadius.rSm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: AppRadius.rSm),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat.Hm('fr_FR').format(dt),
                          style: theme.textTheme.labelLarge?.copyWith(color: accent, fontWeight: FontWeight.w800),
                        ),
                        if (active && !taken) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.edit_rounded, size: 12, color: accent),
                        ],
                      ],
                    ),
                  ),
                ),
                if (active && !taken)
                  IconButton(
                    tooltip: 'Reporter de 1 h',
                    onPressed: onDelay,
                    icon: const Icon(Icons.snooze_rounded, size: 20, color: AppColors.mutedForeground),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FrequencyChips extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _FrequencyChips({required this.value, required this.onChanged});

  static const _options = {
    '1x': '1x / jour',
    '2x': '2x / jour',
    '3x': '3x / jour',
    'interval': 'Intervalle',
    'prn': 'Si besoin',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _options.entries.map((e) {
        final selected = e.key == value;
        return ChoiceChip(
          label: Text(e.value),
          selected: selected,
          onSelected: (_) => onChanged(e.key),
          labelStyle: TextStyle(
            color: selected ? AppColors.primary : AppColors.foreground,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 13,
          ),
        );
      }).toList(),
    );
  }
}

class _SegmentRow extends StatelessWidget {
  final Map<String, String> options;
  final String value;
  final ValueChanged<String> onChanged;
  const _SegmentRow({required this.options, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.entries.map((e) {
        final selected = e.key == value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: e.key == options.keys.last ? 0 : 8),
            child: Material(
              color: selected ? AppColors.primary : AppColors.surface,
              borderRadius: AppRadius.rSm,
              child: InkWell(
                onTap: () => onChanged(e.key),
                borderRadius: AppRadius.rSm,
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.rSm,
                    border: Border.all(color: selected ? AppColors.primary : AppColors.border),
                  ),
                  child: Text(
                    e.value,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.foreground,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Champ « date » cliquable, aligné sur le style des AppTextField.
class _DateField extends StatelessWidget {
  final DateTime value;
  final VoidCallback onPick;

  const _DateField({required this.value, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.rMd,
      child: InkWell(
        onTap: onPick,
        borderRadius: AppRadius.rMd,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(borderRadius: AppRadius.rMd, border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              const Icon(Icons.event_rounded, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  DateFormat('d MMMM yyyy', 'fr_FR').format(value),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.edit_calendar_outlined, size: 18, color: AppColors.mutedForeground),
            ],
          ),
        ),
      ),
    );
  }
}
