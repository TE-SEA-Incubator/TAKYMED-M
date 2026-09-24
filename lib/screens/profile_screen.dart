import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/push_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/auth_phone.dart';
import '../utils/timezone_utils.dart';
import '../widgets/animated_fade_slide.dart';
import '../widgets/app_card.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/app_text_field.dart';
import '../widgets/country_picker.dart';
import '../widgets/icon_box.dart';
import '../widgets/page_header.dart';
import '../widgets/page_transitions.dart';
import '../widgets/primary_button.dart';
import '../widgets/reminder_notification_config.dart';
import '../widgets/status_badge.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'upgrade_screen.dart';

/// Profil : identité, pays & fuseau horaire, canaux de rappel, sécurité (PIN), menu.
class ProfileScreen extends StatefulWidget {
  final bool embedded;

  const ProfileScreen({super.key, this.embedded = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ── Pays & fuseau ──
  List<CountryOption> _countries = [];
  bool _loadingCountries = true;
  CountryOption? _pickedCountry;
  bool _savingCountry = false;
  Timer? _clock;

  // ── Canaux ──
  final Set<String> _channels = {'push', 'whatsapp'};
  final _notifPhoneController = TextEditingController();
  bool _loadingPrefs = true;
  bool _savingPrefs = false;

  // ── Sécurité ──
  bool _resettingPin = false;

  @override
  void initState() {
    super.initState();
    _loadCountries();
    _loadNotificationPreferences();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _notifPhoneController.dispose();
    super.dispose();
  }

  AuthProvider get _auth => Provider.of<AuthProvider>(context, listen: false);
  ApiService get _api => Provider.of<ApiService>(context, listen: false);

  CountryOption get _accountCountry => findCountry(_auth.user?.country, _countries);
  CountryOption get _effectiveCountry => _pickedCountry ?? _accountCountry;
  String get _dialCode => _accountCountry.dialCode;

  String _stripDial(String raw) {
    var v = raw.trim().replaceAll(' ', '');
    if (v.startsWith(_dialCode)) return v.substring(_dialCode.length);
    return v.replaceAll(RegExp(r'^\+\d{1,3}'), '');
  }

  // ─────────────────────────────── Données ───────────────────────────────

  Future<void> _loadCountries() async {
    try {
      final list = await _api.getCountries();
      if (mounted) setState(() => _countries = list);
    } catch (_) {
      if (mounted) setState(() => _countries = [CountryOption.fallback]);
    } finally {
      if (mounted) {
        setState(() => _loadingCountries = false);
        final phone = _auth.user?.phone ?? '';
        if (_notifPhoneController.text.isEmpty && phone.isNotEmpty) {
          _notifPhoneController.text = _stripDial(phone);
        }
      }
    }
  }

  Future<void> _loadNotificationPreferences() async {
    final user = _auth.user;
    if (user == null) return;
    try {
      final prefs = await _api.getNotificationPreferences(user.id);
      if (!mounted) return;
      setState(() {
        final saved = (prefs['channels'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .where((c) => ['sms', 'whatsapp', 'call', 'push'].contains(c));
        if (saved.isNotEmpty) {
          _channels
            ..clear()
            ..addAll(saved);
        }
        final recipients = prefs['recipients'] as List<dynamic>? ?? const [];
        if (recipients.isNotEmpty) _notifPhoneController.text = _stripDial(recipients.first.toString());
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingPrefs = false);
    }
  }

  Future<void> _saveNotificationPreferences() async {
    final user = _auth.user;
    if (user == null) return;
    if (!ReminderNotificationConfig.isValid(_channels, _notifPhoneController)) {
      AppSnackbar.warning(context, 'Indiquez un téléphone pour SMS, WhatsApp ou Appel');
      return;
    }
    setState(() => _savingPrefs = true);
    try {
      final recipients = _channels.any((c) => c != 'push')
          ? ['$_dialCode${_notifPhoneController.text.trim().replaceAll(' ', '')}']
          : <String>[];
      await _api.saveNotificationPreferences(user.id, channels: _channels.toList(), recipients: recipients);
      if (_channels.contains('push')) await PushService.registerDevice(_api, user.id);
      if (mounted) AppSnackbar.success(context, 'Canaux de rappel enregistrés');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppSnackbar.clean(e));
    } finally {
      if (mounted) setState(() => _savingPrefs = false);
    }
  }

  Future<void> _pickCountry() async {
    final picked = await showCountryPickerSheet(
      context,
      countries: _countries,
      selectedCode: _effectiveCountry.code,
      title: 'Pays du compte',
    );
    if (picked != null && mounted) setState(() => _pickedCountry = picked);
  }

  Future<void> _saveCountry() async {
    final user = _auth.user;
    final picked = _pickedCountry;
    if (user == null || picked == null) return;
    setState(() => _savingCountry = true);
    try {
      final res = await _api.updateProfile(user.id, user.name, user.phone ?? '', email: user.email, countryCode: picked.code);
      final country = res['country']?.toString() ?? picked.code;
      final timezone = res['timezone']?.toString() ?? picked.timezone ?? NotificationService.defaultTimezone;
      await _auth.updateCountry(country: country, timezone: timezone);
      if (mounted) {
        setState(() => _pickedCountry = null);
        AppSnackbar.success(context, 'Pays enregistré · rappels alignés sur ${TimezoneUtils.cityLabel(timezone)}');
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppSnackbar.clean(e));
    } finally {
      if (mounted) setState(() => _savingCountry = false);
    }
  }

  Future<void> _editIdentity() async {
    final user = _auth.user;
    if (user == null) return;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EditIdentitySheet(
        name: user.name,
        phone: user.phone ?? '',
        email: user.email ?? '',
        onSave: (name, phone, email) async {
          await _api.updateProfile(user.id, name, phone, email: email, countryCode: user.country);
          await _auth.updateUser(name, phone, email: email);
        },
      ),
    );
    if (changed == true && mounted) AppSnackbar.success(context, 'Profil mis à jour');
  }

  Future<void> _resetPin() async {
    final user = _auth.user;
    final phone = user?.phone;
    if (phone == null || phone.isEmpty) {
      AppSnackbar.warning(context, 'Aucun numéro associé à ce compte');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Réinitialiser le PIN ?'),
        content: Text('Un nouveau code PIN sera envoyé par SMS au $phone. L\'ancien code ne fonctionnera plus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Envoyer un nouveau PIN')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _resettingPin = true);
    try {
      final msg = await _api.forgotPin(phone);
      if (mounted) AppSnackbar.success(context, msg);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppSnackbar.clean(e));
    } finally {
      if (mounted) setState(() => _resettingPin = false);
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text('Vous devrez saisir votre téléphone et votre PIN pour vous reconnecter.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
    if (ok == true) await _auth.logout();
  }

  static String typeLabel(String? type) => switch (type) {
    'commercial' => 'Commercial',
    'professional' => 'Professionnel',
    'admin' => 'Administrateur',
    _ => 'Patient',
  };

  // ─────────────────────────────── Build ───────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final theme = Theme.of(context);
    final effectiveTz = _pickedCountry?.timezone ?? user?.timezone ?? _accountCountry.timezone ?? NotificationService.defaultTimezone;
    final countryDirty = _pickedCountry != null && _pickedCountry!.code != _accountCountry.code;

    final list = ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 110),
      children: [
        // ── Identité ──
        AnimatedFadeSlide(
          index: 0,
          child: HeroCard(
            onTap: _editIdentity,
            child: Row(
              children: [
                InitialsAvatar(name: user?.name ?? 'U', size: 62, color: Colors.white),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? 'Utilisateur', style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
                      const SizedBox(height: 3),
                      Text(user?.phone ?? '—', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
                      if ((user?.email ?? '').isNotEmpty)
                        Text(user!.email!, style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.8))),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusBadge(
                            label: typeLabel(user?.type),
                            type: StatusType.info,
                            small: true,
                            customColor: Colors.white,
                            icon: Icons.verified_user_rounded,
                          ),
                          Text(
                            'Modifier',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Pays & fuseau ──
        AnimatedFadeSlide(
          index: 1,
          child: SectionCard(
            title: 'Pays & fuseau horaire',
            subtitle: 'Vos rappels suivent l\'heure de ce pays',
            icon: Icons.public_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CountryPickerField(country: _effectiveCountry, loading: _loadingCountries, onTap: _pickCountry),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.primaryLight.withValues(alpha: 0.6), borderRadius: AppRadius.rMd),
                  child: Row(
                    children: [
                      const IconBox(icon: Icons.schedule_rounded, size: 40, iconSize: 20, background: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(effectiveTz, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                            Text(
                              '${TimezoneUtils.utcOffset(effectiveTz)} · ${countryDirty ? 'après enregistrement' : 'fuseau actif des rappels'}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // L'heure ne doit jamais provoquer de débordement : elle se
                      // réduit légèrement sur les petits écrans / grandes polices.
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                TimezoneUtils.localTime(effectiveTz),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: AppColors.primary,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                              Text('heure locale', style: theme.textTheme.labelSmall),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (countryDirty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: 'Annuler',
                          height: 48,
                          onPressed: _savingCountry ? null : () => setState(() => _pickedCountry = null),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: PrimaryButton(
                          label: 'Enregistrer le pays',
                          icon: Icons.check_rounded,
                          height: 48,
                          isLoading: _savingCountry,
                          onPressed: _saveCountry,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Canaux de rappel ──
        AnimatedFadeSlide(
          index: 2,
          child: SectionCard(
            title: 'Canaux de rappel par défaut',
            subtitle: 'Pré-remplis à chaque nouvelle ordonnance',
            icon: Icons.notifications_active_rounded,
            iconColor: AppColors.secondary,
            child: _loadingPrefs
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ChannelSelector(
                        channels: _channels,
                        onToggle: (id) => setState(() {
                          if (_channels.contains(id)) {
                            if (_channels.length > 1) _channels.remove(id);
                          } else {
                            _channels.add(id);
                          }
                        }),
                      ),
                      if (_channels.any((c) => c != 'push')) ...[
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _notifPhoneController,
                          label: 'Téléphone pour SMS / WhatsApp / Appel',
                          prefixIcon: Icons.phone_rounded,
                          prefixText: '$_dialCode ',
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                      const SizedBox(height: 14),
                      PrimaryButton(
                        label: 'Enregistrer les canaux',
                        icon: Icons.save_outlined,
                        height: 48,
                        isLoading: _savingPrefs,
                        onPressed: _saveNotificationPreferences,
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Sécurité ──
        AnimatedFadeSlide(
          index: 3,
          child: SectionCard(
            title: 'Sécurité',
            subtitle: 'Code PIN de connexion',
            icon: Icons.lock_outline_rounded,
            iconColor: AppColors.warning,
            child: _MenuTile(
              icon: Icons.password_rounded,
              color: AppColors.warning,
              title: 'Réinitialiser mon PIN',
              subtitle: 'Un nouveau code vous sera envoyé par SMS',
              loading: _resettingPin,
              onTap: _resettingPin ? null : _resetPin,
              flat: true,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Menu ──
        AnimatedFadeSlide(
          index: 4,
          child: AppCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                _MenuTile(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  subtitle: 'Historique des alertes reçues',
                  onTap: () => pushSlide(context, const NotificationsScreen()),
                ),
                const Divider(height: 1, indent: 68),
                _MenuTile(
                  icon: Icons.workspace_premium_outlined,
                  color: AppColors.secondary,
                  title: 'Mon abonnement',
                  subtitle: 'Formule ${typeLabel(user?.type)} · changer d\'offre',
                  onTap: () => pushSlide(context, const UpgradeScreen()),
                ),
                const Divider(height: 1, indent: 68),
                _MenuTile(
                  icon: Icons.settings_outlined,
                  color: AppColors.mutedForeground,
                  title: 'Paramètres & à propos',
                  subtitle: 'Connexion serveur, version',
                  onTap: () => pushSlide(context, const SettingsScreen()),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        AnimatedFadeSlide(
          index: 5,
          child: SecondaryButton(label: 'Se déconnecter', icon: Icons.logout_rounded, color: AppColors.destructive, onPressed: _logout),
        ),
      ],
    );

    final body = Column(
      children: [
        if (widget.embedded)
          PageHeader(
            title: 'Profil',
            subtitle: 'Compte, pays et préférences',
            actions: [
              HeaderIconButton(
                icon: Icons.notifications_outlined,
                tooltip: 'Notifications',
                onTap: () => pushSlide(context, const NotificationsScreen()),
              ),
            ],
          ),
        Expanded(child: list),
      ],
    );

    if (widget.embedded) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(bottom: false, child: body),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppTopBar(title: 'Profil'),
      body: body,
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool loading;
  final bool flat;

  const _MenuTile({
    required this.icon,
    this.color = AppColors.primary,
    required this.title,
    this.subtitle,
    this.onTap,
    this.loading = false,
    this.flat = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.rMd,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: flat ? 0 : 14, vertical: 12),
        child: Row(
          children: [
            IconBox(icon: icon, color: color, size: 42, iconSize: 21),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  if (subtitle != null) Text(subtitle!, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (loading)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else
              const Icon(Icons.chevron_right_rounded, color: AppColors.mutedForeground),
          ],
        ),
      ),
    );
  }
}

/// Feuille d'édition nom / téléphone / e-mail.
class _EditIdentitySheet extends StatefulWidget {
  final String name;
  final String phone;
  final String email;
  final Future<void> Function(String name, String phone, String email) onSave;

  const _EditIdentitySheet({required this.name, required this.phone, required this.email, required this.onSave});

  @override
  State<_EditIdentitySheet> createState() => _EditIdentitySheetState();
}

class _EditIdentitySheetState extends State<_EditIdentitySheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.name);
  late final _phone = TextEditingController(text: widget.phone);
  late final _email = TextEditingController(text: widget.email);
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(_name.text.trim(), _phone.text.trim(), _email.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppSnackbar.clean(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 24),
          children: [
            Row(
              children: [
                Expanded(child: Text('Modifier mes informations', style: theme.textTheme.titleLarge)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ],
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _name,
              label: 'Nom complet',
              prefixIcon: Icons.person_outline_rounded,
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v ?? '').trim().isEmpty ? 'Nom requis' : null,
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _phone,
              label: 'Numéro de téléphone',
              prefixIcon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
              helper: 'Format international, ex. +237 6 XX XX XX XX',
              validator: (v) => (v ?? '').trim().isEmpty ? 'Téléphone requis' : null,
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _email,
              label: 'Adresse e-mail (optionnel)',
              prefixIcon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null;
                return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t) ? null : 'E-mail invalide';
              },
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Enregistrer', icon: Icons.check_rounded, isLoading: _saving, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
