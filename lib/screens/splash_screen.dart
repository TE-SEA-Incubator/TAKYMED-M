import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Écran de démarrage : fond doux, logo dans une tuile blanche, progression.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: _Blob(size: 320, color: AppColors.primaryLight),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: _Blob(size: 340, color: AppColors.secondaryLight),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 128,
                  height: 128,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(36),
                    boxShadow: AppShadows.elevated,
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                )
                    .animate()
                    .scale(begin: const Offset(0.8, 0.8), duration: 650.ms, curve: Curves.easeOutBack)
                    .fadeIn(duration: 350.ms),
                const SizedBox(height: 28),
                Text(
                  'TAKYMED',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: AppColors.primary,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w900,
                  ),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, curve: Curves.easeOutCubic),
                const SizedBox(height: 6),
                Text(
                  'Take your medicine, on time.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedForeground),
                ).animate().fadeIn(delay: 320.ms),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 56,
            child: Column(
              children: [
                SizedBox(
                  width: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: const LinearProgressIndicator(minHeight: 4),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 450.ms),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
