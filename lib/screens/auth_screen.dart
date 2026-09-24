import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/auth_exception.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/auth_phone.dart';
import '../widgets/app_card.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/app_text_field.dart';
import '../widgets/country_picker.dart';
import '../widgets/loading_view.dart';
import '../widgets/page_header.dart';
import '../widgets/page_transitions.dart';
import '../widgets/pin_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/takymed_logo.dart';
import 'settings_screen.dart';

enum AuthMode { login, register }
enum AuthStep { phone, pin }

/// Connexion / inscription : téléphone (+ pays) puis code PIN à 6 chiffres.
class AuthScreen extends StatefulWidget {
  final AuthMode mode;
  const AuthScreen({super.key, required this.mode});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();

  AuthStep _step = AuthStep.phone;
  bool _isLoading = false;
  bool _resending = false;
  bool _acceptedTerms = false;
  bool _pinError = false;
  String? _inlineError;
  String _selectedCountry = 'CM';
  List<CountryOption> _countries = [CountryOption.fallback];
  final String _selectedType = 'standard';

  bool get _isLogin => widget.mode == AuthMode.login;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final list = await api.getCountries();
      if (mounted && list.isNotEmpty) setState(() => _countries = list);
    } catch (_) {}
  }

  CountryOption get _currentCountry => findCountry(_selectedCountry, _countries);

  String get _fullPhone => buildFullPhone(_phoneController.text, _selectedCountry, _countries);

  bool get _isSpecialAccount {
    final p = _phoneController.text.trim().toLowerCase();
    return p == 'admin' || p == 'commercial';
  }

  String get _displayPhone => _isSpecialAccount ? _phoneController.text.trim() : _fullPhone;

  // ─────────────────────────────── Actions ───────────────────────────────

  Future<void> _pickCountry() async {
    final selected = await showCountryPickerSheet(
      context,
      countries: _countries,
      selectedCode: _selectedCountry,
    );
    if (selected != null && mounted) setState(() => _selectedCountry = selected.code);
  }

  Future<void> _onContinue() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!_isLogin && !_acceptedTerms) {
      AppSnackbar.warning(context, 'Veuillez accepter les conditions d\'utilisation');
      return;
    }
    setState(() {
      _isLoading = true;
      _inlineError = null;
    });
    try {
      if (_isLogin) {
        setState(() => _step = AuthStep.pin);
      } else {
        final api = Provider.of<ApiService>(context, listen: false);
        final message = await api.register(
          _fullPhone,
          _selectedType,
          email: _emailController.text.trim(),
          countryCode: _selectedCountry,
        );
        if (mounted) {
          AppSnackbar.success(context, message);
          setState(() => _step = AuthStep.pin);
        }
      }
    } catch (e) {
      if (mounted) {
        final msg = AppSnackbar.clean(e);
        setState(() => _inlineError = msg);
        AppSnackbar.error(context, msg);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onSubmitPin() async {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      AppSnackbar.warning(context, 'Veuillez entrer votre code PIN');
      return;
    }
    setState(() {
      _isLoading = true;
      _pinError = false;
      _inlineError = null;
    });
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final api = Provider.of<ApiService>(context, listen: false);
      await auth.login(_fullPhone, _selectedType, pin, api);
      if (mounted) {
        AppSnackbar.success(context, _isLogin ? 'Connecté !' : 'Compte créé, bienvenue !');
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _pinError = true;
        _inlineError = e.message;
      });
      _pinController.clear();
      if (e.pinRegenerated) {
        AppSnackbar.warning(context, e.message);
      } else {
        AppSnackbar.error(context, e.message);
      }
    } catch (e) {
      if (mounted) {
        final msg = AppSnackbar.clean(e);
        setState(() {
          _pinError = true;
          _inlineError = msg;
        });
        AppSnackbar.error(context, msg);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onForgotPin() async {
    if (_resending) return;
    if (_phoneController.text.trim().isEmpty) {
      AppSnackbar.warning(context, 'Saisissez d\'abord votre numéro de téléphone');
      return;
    }
    setState(() => _resending = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final msg = await api.forgotPin(_fullPhone);
      if (mounted) {
        AppSnackbar.success(context, msg);
        _pinController.clear();
        setState(() {
          _pinError = false;
          _inlineError = null;
          if (_step == AuthStep.phone) _step = AuthStep.pin;
        });
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppSnackbar.clean(e));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _backToPhone() {
    setState(() {
      _step = AuthStep.phone;
      _pinError = false;
      _inlineError = null;
      _pinController.clear();
    });
  }

  // ─────────────────────────────── Build ───────────────────────────────

  @override
  Widget build(BuildContext context) {
    final showBack = _step == AuthStep.pin || !_isLogin;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            top: -140,
            left: -90,
            child: IgnorePointer(
              child: Container(
                width: 320,
                height: 320,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primaryLight),
              ),
            ),
          ),
          Positioned(
            top: 120,
            right: -120,
            child: IgnorePointer(
              child: Container(
                width: 260,
                height: 260,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.secondaryLight),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 0),
                  child: Row(
                    children: [
                      if (showBack)
                        HeaderIconButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: 'Retour',
                          onTap: _step == AuthStep.pin ? _backToPhone : () => Navigator.maybePop(context),
                        )
                      else
                        const TakymedLogo(size: TakymedLogoSize.small, variant: TakymedLogoVariant.horizontal),
                      const Spacer(),
                      if (_isLogin && _step == AuthStep.phone)
                        HeaderIconButton(
                          icon: Icons.tune_rounded,
                          tooltip: 'Paramètres',
                          onTap: () => pushSlide(context, const SettingsScreen()),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page, 16, AppSpacing.page, 32),
                    child: Form(
                      key: _formKey,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(anim),
                            child: child,
                          ),
                        ),
                        child: _step == AuthStep.phone
                            ? KeyedSubtree(key: const ValueKey('phone'), child: _buildPhoneStep())
                            : KeyedSubtree(key: const ValueKey('pin'), child: _buildPinStep()),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── Étape téléphone ───────────────────────────

  Widget _buildPhoneStep() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isLogin) ...[
          Center(
            child: Container(
              width: 96,
              height: 96,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: AppShadows.card,
              ),
              child: Image.asset(AppImages.logo, fit: BoxFit.contain),
            ).animate().scale(begin: const Offset(0.85, 0.85), duration: 500.ms, curve: Curves.easeOutBack),
          ),
          const SizedBox(height: 24),
        ],
        Text(
          _isLogin ? 'Bon retour !' : 'Créer un compte',
          style: theme.textTheme.displaySmall,
        ).animate().fadeIn().slideY(begin: 0.1),
        const SizedBox(height: 8),
        Text(
          _isLogin
              ? 'Connectez-vous avec votre numéro de téléphone pour retrouver vos rappels.'
              : 'Votre compte Standard est gratuit. Un code PIN vous sera envoyé par SMS.',
          style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.mutedForeground, height: 1.5),
        ).animate().fadeIn(delay: 80.ms),
        const SizedBox(height: 28),

        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Numéro de téléphone',
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              PhoneInputRow(
                controller: _phoneController,
                country: _currentCountry,
                onPickCountry: _pickCountry,
                textInputAction: _isLogin ? TextInputAction.done : TextInputAction.next,
                onSubmitted: _isLogin ? (_) => _onContinue() : null,
                onChanged: (_) {
                  if (_inlineError != null) setState(() => _inlineError = null);
                },
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return 'Numéro requis';
                  if (value.toLowerCase() == 'admin' || value.toLowerCase() == 'commercial') return null;
                  final digits = value.replaceAll(RegExp(r'\D'), '');
                  if (digits.length < 6) return 'Numéro trop court';
                  return null;
                },
              ),
              const SizedBox(height: 6),
              Text(
                'Indicatif ${_currentCountry.dialCode} · ${_currentCountry.name}',
                style: theme.textTheme.bodySmall,
              ),
              if (!_isLogin) ...[
                const SizedBox(height: 18),
                AppTextField(
                  controller: _emailController,
                  label: 'Adresse e-mail (optionnel)',
                  hint: 'vous@exemple.com',
                  prefixIcon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return null;
                    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
                    return ok ? null : 'Adresse e-mail invalide';
                  },
                ),
              ],
            ],
          ),
        ).animate().fadeIn(delay: 140.ms).slideY(begin: 0.08),

        if (_inlineError != null) ...[
          const SizedBox(height: 14),
          InfoBanner.error(message: _inlineError!),
        ],

        if (!_isLogin) ...[
          const SizedBox(height: 16),
          _TermsCheckbox(
            value: _acceptedTerms,
            onChanged: (v) => setState(() => _acceptedTerms = v),
          ).animate().fadeIn(delay: 200.ms),
        ],

        const SizedBox(height: 24),
        PrimaryButton(
          label: _isLogin ? 'Continuer' : 'Créer mon compte',
          icon: _isLogin ? Icons.arrow_forward_rounded : Icons.person_add_alt_1_rounded,
          iconTrailing: _isLogin,
          isLoading: _isLoading,
          onPressed: _onContinue,
        ).animate().fadeIn(delay: 240.ms),

        if (_isLogin) ...[
          const SizedBox(height: 12),
          SecondaryButton(
            label: 'Créer un compte',
            onPressed: () => pushSlide(context, const AuthScreen(mode: AuthMode.register)),
          ).animate().fadeIn(delay: 280.ms),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: _resending ? null : _onForgotPin,
              icon: _resending
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.key_rounded, size: 18),
              label: const Text('PIN oublié ?'),
            ),
          ),
        ] else ...[
          const SizedBox(height: 20),
          Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Vous avez déjà un compte ? ', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedForeground)),
                GestureDetector(
                  onTap: () => Navigator.maybePop(context),
                  child: Text(
                    'Se connecter',
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),
        Center(
          child: Text(
            'En continuant, vous acceptez nos conditions d\'utilisation\net notre politique de confidentialité.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.subtleForeground),
          ),
        ),
      ],
    );
  }

  // ───────────────────────────── Étape PIN ─────────────────────────────

  Widget _buildPinStep() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(26),
              boxShadow: AppShadows.elevated,
            ),
            child: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 38),
          ).animate().scale(begin: const Offset(0.85, 0.85), duration: 450.ms, curve: Curves.easeOutBack),
        ),
        const SizedBox(height: 24),
        Text('Votre code PIN', style: theme.textTheme.displaySmall, textAlign: TextAlign.center)
            .animate()
            .fadeIn()
            .slideY(begin: 0.1),
        const SizedBox(height: 8),
        Text(
          _isLogin
              ? 'Saisissez le code PIN à 6 chiffres associé à votre compte.'
              : 'Un code PIN à 6 chiffres vient de vous être envoyé par SMS.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.mutedForeground, height: 1.5),
        ).animate().fadeIn(delay: 80.ms),
        const SizedBox(height: 12),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isSpecialAccount) ...[
                  Text(_currentCountry.flag, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                ],
                Text(_displayPhone, style: theme.textTheme.labelLarge?.copyWith(color: AppColors.primary)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _backToPhone,
                  child: const Icon(Icons.edit_rounded, size: 16, color: AppColors.mutedForeground),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        AppCard(
          padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
          child: PinField(
            controller: _pinController,
            length: 6,
            hasError: _pinError,
            enabled: !_isLoading,
            onChanged: (_) {
              if (_pinError) setState(() => _pinError = false);
            },
            onCompleted: _onSubmitPin,
          ),
        ).animate().fadeIn(delay: 140.ms).slideY(begin: 0.08),
        if (_inlineError != null) ...[
          const SizedBox(height: 14),
          InfoBanner.error(message: _inlineError!),
        ],
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Vérifier',
          icon: Icons.verified_user_outlined,
          isLoading: _isLoading,
          onPressed: _onSubmitPin,
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 20),
        Center(
          child: Column(
            children: [
              Text(
                _isLogin ? 'Vous avez oublié votre code ?' : 'Vous n\'avez pas reçu le code ?',
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedForeground),
              ),
              TextButton.icon(
                onPressed: _resending ? null : _onForgotPin,
                icon: _resending
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.sms_outlined, size: 18),
                label: Text(_isLogin ? 'Recevoir un nouveau PIN par SMS' : 'Renvoyer le code'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _TermsCheckbox({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.rMd,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: AppRadius.rMd,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: AppRadius.rMd,
            border: Border.all(color: value ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: AppDurations.fast,
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: value ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: value ? AppColors.primary : AppColors.borderStrong, width: 1.8),
                ),
                child: value ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.foreground, height: 1.45),
                    children: const [
                      TextSpan(text: 'J\'accepte les '),
                      TextSpan(
                        text: 'conditions d\'utilisation',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: ' et la '),
                      TextSpan(
                        text: 'politique de confidentialité',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: ' de TAKYMED.'),
                    ],
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
