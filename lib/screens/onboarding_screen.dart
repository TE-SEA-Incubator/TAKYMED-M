import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/loading_view.dart';
import '../widgets/primary_button.dart';
import '../widgets/takymed_logo.dart';

/// Onboarding en 3 écrans illustrés (affiché une seule fois).
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPageData(
      image: AppImages.hero,
      tint: AppColors.primaryLight,
      accent: AppColors.primary,
      eyebrow: 'Rappels intelligents',
      title: 'Ne manquez plus\naucune prise',
      subtitle:
          'TAKYMED vous rappelle chaque médicament au bon moment — par SMS, WhatsApp, appel ou notification.',
    ),
    _OnboardingPageData(
      image: AppImages.reminders,
      tint: AppColors.secondaryLight,
      accent: AppColors.secondary,
      eyebrow: 'Ordonnances',
      title: 'Vos traitements,\nbien organisés',
      subtitle:
          'Créez une ordonnance en quelques étapes, confirmez vos prises et suivez votre observance jour après jour.',
    ),
    _OnboardingPageData(
      image: AppImages.pharmacy,
      tint: AppColors.primaryLight,
      accent: AppColors.primary,
      eyebrow: 'Pharmacies',
      title: 'Une pharmacie\ntoujours à portée',
      subtitle:
          'Trouvez les officines proches et celles de garde, appelez-les ou lancez l\'itinéraire en un geste.',
    ),
  ];

  bool get _isLast => _currentPage == _pages.length - 1;

  void _next() {
    if (_isLast) {
      widget.onComplete();
      return;
    }
    _pageController.nextPage(duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final page = _pages[_currentPage];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [page.tint, AppColors.background],
                stops: const [0.0, 0.55],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.page, 12, 12, 0),
                  child: Row(
                    children: [
                      const TakymedLogo(size: TakymedLogoSize.small, variant: TakymedLogoVariant.horizontal),
                      const Spacer(),
                      AnimatedOpacity(
                        duration: AppDurations.normal,
                        opacity: _isLast ? 0 : 1,
                        child: TextButton(
                          onPressed: _isLast ? null : widget.onComplete,
                          style: TextButton.styleFrom(foregroundColor: AppColors.mutedForeground),
                          child: const Text('Passer'),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (context, index) => _OnboardingPage(data: _pages[index], index: index),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 24),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pages.length, (i) {
                          final active = i == _currentPage;
                          return AnimatedContainer(
                            duration: AppDurations.normal,
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: active ? 28 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: active ? page.accent : page.accent.withValues(alpha: 0.22),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),
                      _isLast
                          ? PrimaryButton.brand(
                              label: 'Commencer',
                              icon: Icons.arrow_forward_rounded,
                              iconTrailing: true,
                              onPressed: _next,
                            )
                          : PrimaryButton(
                              label: 'Suivant',
                              icon: Icons.arrow_forward_rounded,
                              iconTrailing: true,
                              onPressed: _next,
                            ),
                      const SizedBox(height: 10),
                      Text(
                        '${_currentPage + 1} / ${_pages.length}',
                        style: theme.textTheme.labelSmall?.copyWith(color: AppColors.subtleForeground),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingPageData data;
  final int index;

  const _OnboardingPage({required this.data, required this.index});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageHeight = (constraints.maxHeight * 0.46).clamp(200.0, 340.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  height: imageHeight,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.xxl),
                    boxShadow: AppShadows.card,
                  ),
                  clipBehavior: Clip.antiAlias,
                  padding: const EdgeInsets.all(16),
                  child: Image.asset(
                    data.image,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                )
                    .animate(key: ValueKey('img-$index'))
                    .fadeIn(duration: 400.ms)
                    .scale(begin: const Offset(0.94, 0.94), curve: Curves.easeOutCubic),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: data.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  data.eyebrow.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: data.accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ).animate(key: ValueKey('eyebrow-$index')).fadeIn(delay: 80.ms).slideY(begin: 0.2),
              const SizedBox(height: 12),
              Text(
                data.title,
                style: theme.textTheme.displaySmall,
              ).animate(key: ValueKey('title-$index')).fadeIn(delay: 140.ms).slideY(begin: 0.15),
              const SizedBox(height: 12),
              Text(
                data.subtitle,
                style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.mutedForeground, height: 1.55),
              ).animate(key: ValueKey('sub-$index')).fadeIn(delay: 220.ms),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _OnboardingPageData {
  final String image;
  final Color tint;
  final Color accent;
  final String eyebrow;
  final String title;
  final String subtitle;

  const _OnboardingPageData({
    required this.image,
    required this.tint,
    required this.accent,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });
}
