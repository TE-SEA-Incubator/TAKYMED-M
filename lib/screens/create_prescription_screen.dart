import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/push_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/auth_phone.dart';
import '../widgets/animated_fade_slide.dart';
import '../widgets/app_card.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/app_text_field.dart';
import '../widgets/icon_box.dart';
import '../widgets/loading_view.dart';
import '../widgets/page_header.dart';
import '../widgets/primary_button.dart';
import '../widgets/reminder_notification_config.dart';
import '../widgets/status_badge.dart';
import '../widgets/step_indicator.dart';

/// Création d'ordonnance en 3 étapes : informations → médicaments → rappels.
class CreatePrescriptionScreen extends StatefulWidget {
  final String? initialMedName;

  /// Compte patient cible (commercial : client). Null = compte connecté.
  final int? targetUserId;
  final String? targetUserName;

  const CreatePrescriptionScreen({
    super.key,
    this.initialMedName,
    this.targetUserId,
    this.targetUserName,
  });

  @override
  State<CreatePrescriptionScreen> createState() => _CreatePrescriptionScreenState();
}

class _CreatePrescriptionScreenState extends State<CreatePrescriptionScreen> {
  static const _stepLabels = ['Informations', 'Médicaments', 'Rappels'];

  final _infoFormKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _patientController = TextEditingController();
  final _phoneController = TextEditingController();

  final List<Map<String, dynamic>> _medications = [];
  String _categorieAge = 'adulte';

  bool _isLoading = false;
  int _step = 0;
  Set<String> _channels = {'push', 'whatsapp'};
  String _dialCode = '+237';
  Map<String, dynamic> _limits = {
    'limit_dose_comprime': '5',
    'limit_dose_mg': '4',
    'limit_dose_ml': '500',
    'limit_duration_days': '365',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDefaults();
      _loadLimits();
      if (widget.initialMedName != null) {
        setState(() => _step = 1);
        _showAddMedicationModal(initialMedName: widget.initialMedName);
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _patientController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadLimits() async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final cfg = await api.getAppConfig();
      if (mounted && cfg.isNotEmpty) setState(() => _limits = cfg);
    } catch (_) {}
  }

  String _stripDial(String raw) {
    var v = raw.trim().replaceAll(' ', '');
    if (v.startsWith(_dialCode)) return v.substring(_dialCode.length);
    return v.replaceAll(RegExp(r'^\+\d{1,3}'), '');
  }

  Future<void> _loadDefaults() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final api = Provider.of<ApiService>(context, listen: false);
    if (auth.user == null) return;

    // Compte standard : le patient est toujours l'utilisateur lui-même (champ masqué).
    _patientController.text = widget.targetUserName ?? (_isProPlus(auth) ? '' : auth.user!.name);

    // Indicatif du pays du compte (fallback +237).
    try {
      final countries = await api.getCountries();
      final country = findCountry(auth.user?.country, countries);
      if (mounted) setState(() => _dialCode = country.dialCode);
    } catch (_) {}

    if (auth.user?.phone != null && _phoneController.text.isEmpty) {
      _phoneController.text = _stripDial(auth.user!.phone!);
    }

    try {
      final prefs = await api.getNotificationPreferences(auth.user!.id);
      if (!mounted) return;
      final savedChannels = (prefs['channels'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .where((c) => ['sms', 'whatsapp', 'call', 'push'].contains(c))
          .toList();
      final recipients = (prefs['recipients'] as List<dynamic>?) ?? [];
      setState(() {
        if (savedChannels != null && savedChannels.isNotEmpty) _channels = savedChannels.toSet();
        if (recipients.isNotEmpty) _phoneController.text = _stripDial(recipients.first.toString());
      });
    } catch (_) {}
  }

  /// Le champ « patient » n'est proposé qu'aux comptes professionnels et plus.
  bool _isProPlus(AuthProvider auth) {
    final type = auth.user?.type.toLowerCase() ?? 'standard';
    return type != 'standard';
  }

  /// Date de début la plus proche parmi les médicaments (affichage récapitulatif).
  DateTime? get _earliestStart {
    DateTime? min;
    for (final m in _medications) {
      final raw = m['startDate']?.toString();
      if (raw == null || raw.isEmpty) continue;
      final d = DateTime.tryParse(raw);
      if (d != null && (min == null || d.isBefore(min))) min = d;
    }
    return min;
  }

  // ─────────────────────────────── Navigation ───────────────────────────────

  void _next() {
    if (_step == 0) {
      if (!(_infoFormKey.currentState?.validate() ?? false)) return;
      setState(() => _step = 1);
    } else if (_step == 1) {
      if (_medications.isEmpty) {
        AppSnackbar.warning(context, 'Ajoutez au moins un médicament');
        return;
      }
      setState(() => _step = 2);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step == 0) {
      Navigator.maybePop(context);
    } else {
      setState(() => _step -= 1);
    }
  }

  void _showAddMedicationModal({String? initialMedName}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: AddMedicationForm(
          initialMedName: initialMedName,
          limits: _limits,
          onAdd: (med) {
            setState(() => _medications.add(med));
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!ReminderNotificationConfig.isValid(_channels, _phoneController)) {
      AppSnackbar.warning(context, 'Sélectionnez au moins un canal, et un téléphone si SMS / WhatsApp / Appel sont activés');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);

      final actor = authProvider.user;
      if (actor == null || actor.id <= 0) {
        throw Exception('Session expirée. Reconnectez-vous.');
      }

      final targetUserId = widget.targetUserId ?? actor.id;
      final patientInput = _isProPlus(authProvider) ? _patientController.text.trim() : '';
      final targetUserName = patientInput.isNotEmpty ? patientInput : (widget.targetUserName ?? actor.name);

      final recipients = <String>[];
      if (_phoneController.text.trim().isNotEmpty) {
        recipients.add('$_dialCode${_phoneController.text.trim().replaceAll(' ', '')}');
      } else if (authProvider.user?.phone != null) {
        recipients.add(authProvider.user!.phone!);
      }

      final titleInput = _titleController.text.trim();
      final resolvedTitle = titleInput.isNotEmpty ? titleInput : 'Ordonnance';

      await apiService.createOrdonnance(
        {
          'userId': targetUserId,
          'title': resolvedTitle,
          'patientName': targetUserName,
          'categorieAge': _categorieAge,
          // Chaque médicament porte sa propre date de début (clé startDate).
          'medications': _medications,
          'notifConfig': {
            'recipients': recipients,
            'channels': _channels.toList(),
          },
        },
        actorUserId: actor.id,
      );

      if (_channels.contains('push')) {
        await PushService.registerDevice(apiService, actor.id);
      }
      await PushService.syncReminders(apiService, targetUserId);

      if (mounted) {
        final methods = _channels.map(NotificationChannel.labelFor).join(', ');
        Navigator.pop(context, true);
        AppSnackbar.success(context, 'Ordonnance créée. Rappels via : $methods');
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppSnackbar.clean(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────── Build ───────────────────────────────

  @override
  Widget build(BuildContext context) {
    final forTarget = widget.targetUserId != null && widget.targetUserName != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppTopBar(
        title: 'Nouvelle ordonnance',
        subtitle: forTarget ? 'Pour ${widget.targetUserName}' : 'Étape ${_step + 1} sur 3 — ${_stepLabels[_step]}',
        onBack: _back,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 12),
            child: StepIndicator(steps: _stepLabels, current: _step, onTap: (i) => setState(() => _step = i)),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: AppDurations.slow,
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(anim),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(_step),
                child: switch (_step) {
                  0 => _buildInfoStep(forTarget),
                  1 => _buildMedicationsStep(),
                  _ => _buildRemindersStep(),
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: StepActions(
        onBack: _step == 0 ? null : _back,
        onNext: _next,
        loading: _isLoading,
        brand: _step == 2,
        nextLabel: switch (_step) {
          0 => 'Continuer',
          1 => 'Choisir les rappels',
          _ => 'Enregistrer l\'ordonnance',
        },
        nextIcon: _step == 2 ? Icons.check_rounded : Icons.arrow_forward_rounded,
      ),
    );
  }

  Widget _buildInfoStep(bool forTarget) {
    final theme = Theme.of(context);
    final showPatient = forTarget || _isProPlus(Provider.of<AuthProvider>(context, listen: false));
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 32),
      child: Form(
        key: _infoFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedFadeSlide(
              index: 0,
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: AppRadius.rLg),
                    child: Image.asset(AppImages.reminders, fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('À propos du traitement', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          'La date de début se choisit sur chaque médicament, à l\'étape suivante.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AnimatedFadeSlide(
              index: 1,
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(
                      controller: _titleController,
                      label: 'Nom de l\'ordonnance (optionnel)',
                      hint: 'Ex. Traitement du matin',
                      prefixIcon: Icons.title_rounded,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    if (showPatient) ...[
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _patientController,
                        label: 'Patient',
                        hint: 'Nom du patient',
                        prefixIcon: Icons.person_outline_rounded,
                        readOnly: forTarget,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => (v ?? '').trim().isEmpty ? 'Nom du patient requis' : null,
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text('Catégorie d\'âge', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final entry in const {'enfant': ('Enfant', Icons.child_care_rounded), 'adulte': ('Adulte', Icons.person_rounded), 'senior': ('Senior', Icons.elderly_rounded)}.entries)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: entry.key == 'senior' ? 0 : 8),
                              child: _AgeOption(
                                label: entry.value.$1,
                                icon: entry.value.$2,
                                selected: _categorieAge == entry.key,
                                onTap: () => setState(() => _categorieAge = entry.key),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationsStep() {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 32),
      children: [
        SectionTitle(
          title: 'Médicaments',
          subtitle: _medications.isEmpty ? 'Ajoutez les médicaments de l\'ordonnance' : '${_medications.length} ajouté${_medications.length > 1 ? 's' : ''}',
          trailing: PillButton(label: 'Ajouter', icon: Icons.add_rounded, filled: true, onPressed: _showAddMedicationModal),
        ),
        if (_medications.isEmpty)
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: EmptyState(
              image: AppImages.emptyPrescriptions,
              imageHeight: 140,
              compact: true,
              title: 'Aucun médicament',
              subtitle: 'Recherchez un médicament dans le catalogue et précisez la dose, la fréquence et la durée.',
              action: PrimaryButton(
                label: 'Ajouter un médicament',
                icon: Icons.add_rounded,
                expanded: false,
                height: 46,
                onPressed: _showAddMedicationModal,
              ),
            ),
          )
        else
          for (var i = 0; i < _medications.length; i++)
            AnimatedFadeSlide(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MedicationSummaryCard(
                  med: _medications[i],
                  onRemove: () => setState(() => _medications.removeAt(i)),
                ),
              ),
            ),
        if (_medications.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Astuce : appuyez sur « Ajouter » pour inclure un autre médicament dans la même ordonnance.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _buildRemindersStep() {
    final theme = Theme.of(context);
    final title = _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : 'Ordonnance';
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 32),
      children: [
        AnimatedFadeSlide(
          index: 0,
          child: HeroCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const IconBox(icon: Icons.description_rounded, color: Colors.white, background: Color(0x33FFFFFF), size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (_patientController.text.trim().isNotEmpty) _patientController.text.trim(),
                          '${_medications.length} médicament${_medications.length > 1 ? 's' : ''}',
                          if (_earliestStart != null) 'dès le ${DateFormat('d MMM', 'fr_FR').format(_earliestStart!)}',
                        ].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedFadeSlide(
          index: 1,
          child: ReminderNotificationConfig(
            channels: _channels,
            onChannelsChanged: (next) => setState(() => _channels = next),
            phoneController: _phoneController,
            phonePrefix: '$_dialCode ',
          ),
        ),
      ],
    );
  }
}

class _AgeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _AgeOption({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryLight : AppColors.surface,
      borderRadius: AppRadius.rMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.rMd,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: AppRadius.rMd,
            border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.6 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: selected ? AppColors.primary : AppColors.mutedForeground),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.primary : AppColors.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MedicationSummaryCard extends StatelessWidget {
  final Map<String, dynamic> med;
  final VoidCallback onRemove;

  const _MedicationSummaryCard({required this.med, required this.onRemove});

  String _freqLabel(String f) {
    switch (f) {
      case '1x':
        return '1× / jour';
      case '2x':
        return '2× / jour';
      case '3x':
        return '3× / jour';
      case '4x':
        return '4× / jour';
      case 'prn':
        return 'Au besoin';
      default:
        return f;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final times = (med['times'] as List?)?.cast<String>() ?? const <String>[];
    final isPrn = med['frequencyType'] == 'prn';
    final start = DateTime.tryParse(med['startDate']?.toString() ?? '');
    final startLabel = start == null ? null : DateFormat('d MMM', 'fr_FR').format(start);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconBox(icon: Icons.medication_rounded, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(med['name'] as String, style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    StatusBadge(label: '${med['doseValue']} ${med['unit']}', type: StatusType.info, small: true),
                    StatusBadge(label: _freqLabel(med['frequencyType'] as String), type: StatusType.neutral, small: true),
                    StatusBadge(label: '${med['durationDays']} jour(s)', type: StatusType.neutral, small: true),
                    if (startLabel != null)
                      StatusBadge(label: 'Dès le $startLabel', type: StatusType.active, small: true, icon: Icons.event_rounded),
                  ],
                ),
                if (!isPrn && times.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 14, color: AppColors.mutedForeground),
                      const SizedBox(width: 6),
                      Expanded(child: Text(times.join(' · '), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600))),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Retirer',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.mutedForeground),
          ),
        ],
      ),
    );
  }
}

/// Formulaire d'ajout d'un médicament (feuille modale).
class AddMedicationForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onAdd;
  final String? initialMedName;
  final Map<String, dynamic> limits;

  const AddMedicationForm({
    super.key,
    required this.onAdd,
    this.initialMedName,
    this.limits = const {},
  });

  @override
  State<AddMedicationForm> createState() => _AddMedicationFormState();
}

class _AddMedicationFormState extends State<AddMedicationForm> {
  final _formKey = GlobalKey<FormState>();
  final _medicationNameController = TextEditingController();
  final _doseController = TextEditingController(text: '1');
  final _durationController = TextEditingController(text: '1');
  String _frequencyType = '1x';
  String _unit = 'comprimé';
  List<String> _times = ['08:00'];
  bool _applyCustomReminderHours = false;
  DateTime _startDate = DateTime.now();

  static const _units = ['comprimé', 'mg', 'ml', 'goutte'];
  static const _frequencies = {'1x': '1× / jour', '2x': '2× / jour', '3x': '3× / jour', '4x': '4× / jour', 'prn': 'Au besoin'};

  @override
  void initState() {
    super.initState();
    if (widget.initialMedName != null) _medicationNameController.text = widget.initialMedName!;
  }

  @override
  void dispose() {
    _medicationNameController.dispose();
    _doseController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  int get _count => switch (_frequencyType) {
        '1x' => 1,
        '2x' => 2,
        '3x' => 3,
        '4x' => 4,
        _ => 0,
      };

  void _calculateAutoTimes(String firstTime) {
    final parts = firstTime.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final count = _count;
    if (count <= 1) {
      setState(() => _times = [firstTime]);
      return;
    }
    final interval = 24 ~/ count;
    setState(() {
      _times = List.generate(count, (i) {
        final hour = (h + i * interval) % 24;
        return '${hour.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      });
    });
  }

  void _updateTimes() {
    setState(() {
      final count = _count;
      if (count == 0) {
        _times = [];
        return;
      }
      const startHour = 8;
      final interval = 24 ~/ count;
      _times = List.generate(count, (i) => '${((startHour + i * interval) % 24).toString().padLeft(2, '0')}:00');
    });
  }

  Future<void> _pickTime(int index) async {
    final parts = _times[index].split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
      helpText: 'Heure de prise ${index + 1}',
    );
    if (picked == null) return;
    final newTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    if (!_applyCustomReminderHours && index == 0) {
      _calculateAutoTimes(newTime);
    } else {
      setState(() => _times[index] = newTime);
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Début de prise de ce médicament',
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null && mounted) setState(() => _startDate = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final medName = _medicationNameController.text.trim();
    final durationDays = int.tryParse(_durationController.text) ?? 1;
    final doseValue = int.tryParse(_doseController.text) ?? 1;

    final limits = widget.limits;
    final maxDuration = int.tryParse(limits['limit_duration_days']?.toString() ?? '365') ?? 365;
    if (durationDays > maxDuration) {
      AppSnackbar.warning(context, 'La durée ne peut pas dépasser $maxDuration jours');
      return;
    }
    final (String? key, double fallback) = switch (_unit) {
      'comprimé' => ('limit_dose_comprime', 5),
      'mg' => ('limit_dose_mg', 4),
      'ml' => ('limit_dose_ml', 500),
      _ => (null, double.infinity),
    };
    if (key != null) {
      final maxDose = double.tryParse(limits[key]?.toString() ?? '$fallback') ?? fallback;
      if (doseValue > maxDose) {
        AppSnackbar.warning(context, 'La dose maximale pour « $_unit » est $maxDose');
        return;
      }
    }

    widget.onAdd({
      'name': medName,
      'frequencyType': _frequencyType,
      'times': _times,
      'durationDays': durationDays,
      'doseValue': doseValue,
      'unit': _unit,
      'startDate': DateFormat('yyyy-MM-dd').format(_startDate),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scroll) => Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(child: Text('Ajouter un médicament', style: theme.textTheme.titleLarge)),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 16),
                children: [
                  Autocomplete<Map<String, dynamic>>(
                    optionsBuilder: (TextEditingValue value) async {
                      if (value.text.length < 2) return const Iterable<Map<String, dynamic>>.empty();
                      final apiService = Provider.of<ApiService>(context, listen: false);
                      try {
                        final results = await apiService.searchMedications(value.text);
                        return (results['medications'] as List<dynamic>?)
                                ?.whereType<Map>()
                                .map((e) => Map<String, dynamic>.from(e))
                                .toList() ??
                            const <Map<String, dynamic>>[];
                      } catch (_) {
                        return const Iterable<Map<String, dynamic>>.empty();
                      }
                    },
                    displayStringForOption: (option) => option['name']?.toString() ?? '',
                    optionsViewBuilder: (context, onSelected, options) => Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 8,
                        shadowColor: AppColors.foreground.withValues(alpha: 0.12),
                        borderRadius: AppRadius.rMd,
                        clipBehavior: Clip.antiAlias,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: 240, maxWidth: MediaQuery.of(context).size.width - 2 * AppSpacing.page),
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final o = options.elementAt(i);
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.medication_outlined, size: 20, color: AppColors.primary),
                                title: Text(o['name']?.toString() ?? '', style: theme.textTheme.titleSmall),
                                subtitle: (o['description']?.toString().isNotEmpty ?? false)
                                    ? Text(o['description'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis)
                                    : null,
                                onTap: () => onSelected(o),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      if (controller.text.isEmpty && _medicationNameController.text.isNotEmpty) {
                        controller.text = _medicationNameController.text;
                      }
                      controller.addListener(() => _medicationNameController.text = controller.text);
                      return AppTextField(
                        controller: controller,
                        focusNode: focusNode,
                        label: 'Nom du médicament',
                        hint: 'Rechercher dans le catalogue…',
                        prefixIcon: Icons.medication_rounded,
                        autofocus: widget.initialMedName == null,
                        textCapitalization: TextCapitalization.sentences,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Médicament requis' : null,
                      );
                    },
                    onSelected: (selection) => _medicationNameController.text = selection['name']?.toString() ?? '',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _doseController,
                          label: 'Dose',
                          keyboardType: TextInputType.number,
                          validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Dose invalide' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Unité', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 54,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (final u in _units)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: ChoiceChip(
                                          label: Text(u),
                                          selected: _unit == u,
                                          onSelected: (_) => setState(() => _unit = u),
                                          labelStyle: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: _unit == u ? AppColors.primary : AppColors.foreground,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Fréquence', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _frequencies.entries.map((e) {
                      final selected = _frequencyType == e.key;
                      return ChoiceChip(
                        label: Text(e.value),
                        selected: selected,
                        onSelected: (_) {
                          setState(() => _frequencyType = e.key);
                          _updateTimes();
                        },
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: selected ? AppColors.primary : AppColors.foreground,
                        ),
                      );
                    }).toList(),
                  ),
                  if (_frequencyType != 'prn') ...[
                    const SizedBox(height: 16),
                    Text('Heures de prise', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < _times.length; i++)
                          _TimeChip(
                            time: _times[i],
                            index: i,
                            auto: !_applyCustomReminderHours && i > 0,
                            onTap: (!_applyCustomReminderHours && i > 0) ? null : () => _pickTime(i),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: AppColors.primaryLight.withValues(alpha: 0.6),
                      borderRadius: AppRadius.rMd,
                      child: InkWell(
                        onTap: () => setState(() => _applyCustomReminderHours = !_applyCustomReminderHours),
                        borderRadius: AppRadius.rMd,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _applyCustomReminderHours,
                                  onChanged: (v) => setState(() => _applyCustomReminderHours = v ?? false),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Je paramètre mes horaires moi-même',
                                        style: theme.textTheme.labelLarge?.copyWith(color: AppColors.primary, fontSize: 13)),
                                    Text('Sans respecter les intervalles réguliers entre les prises.', style: theme.textTheme.bodySmall),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _durationController,
                          label: 'Durée (jours)',
                          prefixIcon: Icons.date_range_rounded,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Durée requise';
                            if (int.tryParse(value) == null || int.parse(value) <= 0) return 'Nombre invalide';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Début de prise', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Material(
                              color: AppColors.surface,
                              borderRadius: AppRadius.rMd,
                              child: InkWell(
                                onTap: _pickStartDate,
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
                                          DateFormat('d MMM yyyy', 'fr_FR').format(_startDate),
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Chaque médicament de l\'ordonnance peut démarrer à une date différente.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 16 + MediaQuery.of(context).padding.bottom),
              child: PrimaryButton(label: 'Ajouter à l\'ordonnance', icon: Icons.check_rounded, onPressed: _submit),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String time;
  final int index;
  final bool auto;
  final VoidCallback? onTap;

  const _TimeChip({required this.time, required this.index, required this.auto, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: auto ? AppColors.surfaceMuted : AppColors.primaryLight,
      borderRadius: AppRadius.rSm,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.rSm,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: AppRadius.rSm,
            border: Border.all(color: auto ? AppColors.border : AppColors.primary.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(auto ? Icons.lock_clock_rounded : Icons.schedule_rounded, size: 16, color: auto ? AppColors.mutedForeground : AppColors.primary),
              const SizedBox(width: 6),
              Text(
                time,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: auto ? AppColors.mutedForeground : AppColors.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (auto) ...[
                const SizedBox(width: 6),
                const Text('auto', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
