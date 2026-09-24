import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/auth_phone.dart';
import '../utils/phone_utils.dart';
import '../widgets/animated_fade_slide.dart';
import '../widgets/app_card.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/app_text_field.dart';
import '../widgets/country_picker.dart';
import '../widgets/icon_box.dart';
import '../widgets/loading_view.dart';
import '../widgets/page_header.dart';
import '../widgets/pin_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/status_badge.dart';
import '../widgets/step_indicator.dart';
import 'create_prescription_screen.dart' show AddMedicationForm;

/// Inscription d'un client par un commercial : coordonnées → ordonnance initiale → validation PIN.
class CommercialRegisterScreen extends StatefulWidget {
  const CommercialRegisterScreen({super.key});

  @override
  State<CommercialRegisterScreen> createState() => _CommercialRegisterScreenState();
}

class _CommercialRegisterScreenState extends State<CommercialRegisterScreen> {
  static const _steps = ['Client', 'Ordonnance', 'Validation'];

  int _step = 0;
  bool _isLoading = false;

  // Étape 1
  final _infoFormKey = GlobalKey<FormState>();
  final _clientNameController = TextEditingController();
  final _clientPhoneController = TextEditingController();
  List<CountryOption> _countries = [CountryOption.fallback];
  CountryOption _country = CountryOption.fallback;

  // Étape 2
  final _titleController = TextEditingController(text: 'Ordonnance initiale');
  final List<Map<String, dynamic>> _medications = [];
  Map<String, dynamic> _limits = const {};

  // Étape 3
  final _pinController = TextEditingController();
  int? _registeredClientId;
  bool _pinSent = true;

  String get _clientPhoneE164 => PhoneUtils.normalizeCameroon(_clientPhoneController.text.trim(), dialCode: _country.dialCode);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCountries();
      _loadLimits();
    });
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _clientPhoneController.dispose();
    _titleController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final list = await api.getCountries();
      if (!mounted || list.isEmpty) return;
      setState(() {
        _countries = list;
        _country = findCountry(auth.user?.country, list);
      });
    } catch (_) {}
  }

  Future<void> _loadLimits() async {
    try {
      final cfg = await Provider.of<ApiService>(context, listen: false).getAppConfig();
      if (mounted && cfg.isNotEmpty) setState(() => _limits = cfg);
    } catch (_) {}
  }

  Future<void> _pickCountry() async {
    final picked = await showCountryPickerSheet(context, countries: _countries, selectedCode: _country.code);
    if (picked != null && mounted) setState(() => _country = picked);
  }

  String? _validatePhone(String? v) {
    if ((v ?? '').trim().isEmpty) return 'Numéro de téléphone requis';
    final e164 = _clientPhoneE164;
    if (_country.code == 'CM') {
      if (!RegExp(r'^\+2376\d{8}$').hasMatch(e164)) return 'Numéro invalide. Format attendu : 6XXXXXXXX';
    } else if (!RegExp(r'^\+\d{8,15}$').hasMatch(e164)) {
      return 'Numéro international invalide';
    }
    return null;
  }

  // ─────────────────────────────── Navigation ───────────────────────────────

  Future<void> _next() async {
    switch (_step) {
      case 0:
        if (!(_infoFormKey.currentState?.validate() ?? false)) return;
        await _checkAvailability();
      case 1:
        if (_medications.isEmpty) {
          AppSnackbar.warning(context, 'Ajoutez au moins un médicament à l\'ordonnance initiale');
          return;
        }
        await _registerClient();
      default:
        await _validateClient();
    }
  }

  void _back() {
    if (_step == 0 || _step == 2) {
      Navigator.maybePop(context);
    } else {
      setState(() => _step -= 1);
    }
  }

  Future<void> _checkAvailability() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final api = Provider.of<ApiService>(context, listen: false);
    setState(() => _isLoading = true);
    try {
      final availability = await api.checkCommercialClientAvailability(
        auth.user!.id,
        _clientNameController.text.trim(),
        _clientPhoneE164,
      );
      if (availability['available'] != true) {
        final errors = availability['errors'];
        throw Exception(errors is List && errors.isNotEmpty ? errors.first.toString() : 'Ce client ne peut pas être inscrit.');
      }
      if (mounted) setState(() => _step = 1);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppSnackbar.clean(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registerClient() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final api = Provider.of<ApiService>(context, listen: false);
    setState(() => _isLoading = true);
    try {
      final title = _titleController.text.trim();
      final result = await api.registerCommercialClient(
        auth.user!.id,
        _clientNameController.text.trim(),
        _clientPhoneE164,
        {
          'title': title.isEmpty ? 'Ordonnance initiale' : title,
          'medications': _medications,
        },
        DateTime.now().toIso8601String().split('T').first,
      );
      final clientId = result['clientId'];
      if (!mounted) return;
      setState(() {
        _registeredClientId = clientId is int ? clientId : int.tryParse(clientId?.toString() ?? '');
        _pinSent = result['pinSent'] != false;
        _step = 2;
      });
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppSnackbar.clean(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _validateClient() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final api = Provider.of<ApiService>(context, listen: false);
    if (_pinController.text.trim().length < 4) {
      AppSnackbar.warning(context, 'Saisissez le code PIN reçu par le client');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await api.validateCommercialClient(auth.user!.id, _clientPhoneE164, _pinController.text.trim(), clientId: _registeredClientId);
      if (mounted) {
        Navigator.pop(context, true);
        AppSnackbar.success(context, 'Client validé avec succès !');
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppSnackbar.clean(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddMedicationModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: AddMedicationForm(
          limits: _limits,
          onAdd: (med) {
            setState(() => _medications.add(med));
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  // ─────────────────────────────── Build ───────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    if (auth.user == null || auth.user?.type != 'commercial') {
      return Scaffold(
        appBar: const AppTopBar(title: 'Inscrire un client'),
        body: const EmptyState(icon: Icons.lock_rounded, title: 'Accès réservé', subtitle: 'Cette fonctionnalité est réservée aux comptes commerciaux.'),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppTopBar(
        title: 'Inscrire un client',
        subtitle: 'Étape ${_step + 1} sur 3 — ${_steps[_step]}',
        onBack: _back,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 12),
            child: StepIndicator(steps: _steps, current: _step, onTap: _step == 2 ? null : (i) => setState(() => _step = i)),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: AppDurations.slow,
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(anim), child: child),
              ),
              child: KeyedSubtree(
                key: ValueKey(_step),
                child: switch (_step) {
                  0 => _buildClientStep(),
                  1 => _buildPrescriptionStep(),
                  _ => _buildValidationStep(),
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: StepActions(
        onBack: _step == 1 ? _back : null,
        onNext: _next,
        loading: _isLoading,
        brand: _step == 2,
        nextLabel: switch (_step) {
          0 => 'Vérifier et continuer',
          1 => 'Inscrire le client',
          _ => 'Valider le compte',
        },
        nextIcon: switch (_step) {
          0 => Icons.arrow_forward_rounded,
          1 => Icons.person_add_rounded,
          _ => Icons.verified_rounded,
        },
      ),
    );
  }

  Widget _buildClientStep() {
    final theme = Theme.of(context);
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
                    decoration: BoxDecoration(color: AppColors.secondaryLight, borderRadius: AppRadius.rLg),
                    child: Image.asset(AppImages.hero, fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Coordonnées du client', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text('Le client recevra son code PIN par SMS sur ce numéro.', style: theme.textTheme.bodySmall),
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
                      controller: _clientNameController,
                      label: 'Nom complet du client',
                      hint: 'Ex. Marie Ngo',
                      prefixIcon: Icons.person_outline_rounded,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v ?? '').trim().length < 2 ? 'Nom du client requis' : null,
                    ),
                    const SizedBox(height: 16),
                    Text('Téléphone', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    PhoneInputRow(
                      controller: _clientPhoneController,
                      country: _country,
                      onPickCountry: _pickCountry,
                      validator: _validatePhone,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _next(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            const AnimatedFadeSlide(
              index: 2,
              child: InfoBanner(
                icon: Icons.shield_outlined,
                message: 'La disponibilité du nom et du numéro est vérifiée avant de créer le compte.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionStep() {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 32),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        AnimatedFadeSlide(
          index: 0,
          child: AppCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const IconBox(icon: Icons.person_rounded, color: AppColors.secondary, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_clientNameController.text.trim(), style: theme.textTheme.titleSmall),
                      Text(_clientPhoneE164, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const StatusBadge(label: 'Disponible', type: StatusType.validated, small: true, icon: Icons.check_rounded),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedFadeSlide(
          index: 1,
          child: AppTextField(
            controller: _titleController,
            label: 'Titre de l\'ordonnance initiale',
            prefixIcon: Icons.title_rounded,
            textCapitalization: TextCapitalization.sentences,
          ),
        ),
        const SizedBox(height: 20),
        SectionTitle(
          title: 'Médicaments',
          subtitle: _medications.isEmpty ? 'Une ordonnance initiale est obligatoire' : '${_medications.length} ajouté${_medications.length > 1 ? 's' : ''}',
          trailing: PillButton(label: 'Ajouter', icon: Icons.add_rounded, filled: true, onPressed: _showAddMedicationModal),
        ),
        if (_medications.isEmpty)
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: EmptyState(
              image: AppImages.emptyPrescriptions,
              imageHeight: 130,
              compact: true,
              title: 'Aucun médicament',
              subtitle: 'Ajoutez le premier traitement du client : dose, fréquence et durée.',
              action: PrimaryButton(label: 'Ajouter un médicament', icon: Icons.add_rounded, expanded: false, height: 46, onPressed: _showAddMedicationModal),
            ),
          )
        else
          for (var i = 0; i < _medications.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                child: Row(
                  children: [
                    const IconBox(icon: Icons.medication_rounded, size: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_medications[i]['name'].toString(), style: theme.textTheme.titleSmall),
                          const SizedBox(height: 2),
                          Text(
                            '${_medications[i]['doseValue']} ${_medications[i]['unit']} · ${_medications[i]['frequencyType']} · ${_medications[i]['durationDays']} j',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _medications.removeAt(i)),
                      icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.mutedForeground),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildValidationStep() {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 32),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        AnimatedFadeSlide(
          index: 0,
          child: HeroCard(
            gradient: const LinearGradient(colors: [AppColors.secondary, Color(0xFF059669)]),
            child: Row(
              children: [
                const IconBox(icon: Icons.check_circle_rounded, color: Colors.white, background: Color(0x33FFFFFF), size: 50, iconSize: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Client inscrit !', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(
                        _pinSent
                            ? 'Un code PIN a été envoyé par SMS à $_clientPhoneE164. Demandez-le au client pour activer son compte.'
                            : 'Le SMS n\'a pas pu être envoyé. Le client pourra utiliser « PIN oublié » à la connexion.',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.9), height: 1.45),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        AnimatedFadeSlide(
          index: 1,
          child: SectionCard(
            title: 'Code PIN du client',
            subtitle: 'Saisissez le code reçu par le client',
            icon: Icons.password_rounded,
            iconColor: AppColors.warning,
            child: PinField(controller: _pinController, length: 6, onCompleted: _validateClient),
          ),
        ),
        const SizedBox(height: 14),
        const AnimatedFadeSlide(
          index: 2,
          child: InfoBanner(
            icon: Icons.info_outline_rounded,
            message: 'Vous pourrez aussi valider ce client plus tard depuis votre espace commercial.',
          ),
        ),
      ],
    );
  }
}
