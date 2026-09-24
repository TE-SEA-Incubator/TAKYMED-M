import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Indicateur d'étapes (pastilles numérotées reliées + libellés).
class StepIndicator extends StatelessWidget {
  final List<String> steps;
  final int current;
  final ValueChanged<int>? onTap;

  const StepIndicator({super.key, required this.steps, required this.current, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(
            child: GestureDetector(
              onTap: onTap != null && i < current ? () => onTap!(i) : null,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AnimatedContainer(
                          duration: AppDurations.normal,
                          height: 3,
                          decoration: BoxDecoration(
                            color: i == 0 ? Colors.transparent : (i <= current ? AppColors.primary : AppColors.border),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      _StepDot(index: i, current: current),
                      Expanded(
                        child: AnimatedContainer(
                          duration: AppDurations.normal,
                          height: 3,
                          decoration: BoxDecoration(
                            color: i == steps.length - 1 ? Colors.transparent : (i < current ? AppColors.primary : AppColors.border),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    steps[i],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: i == current ? AppColors.primary : (i < current ? AppColors.foreground : AppColors.mutedForeground),
                      fontWeight: i == current ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  final int index;
  final int current;
  const _StepDot({required this.index, required this.current});

  @override
  Widget build(BuildContext context) {
    final done = index < current;
    final active = index == current;
    return AnimatedContainer(
      duration: AppDurations.normal,
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done || active ? AppColors.primary : AppColors.surface,
        border: Border.all(color: done || active ? AppColors.primary : AppColors.border, width: 2),
        boxShadow: active ? AppShadows.colored(AppColors.primary, alpha: 0.3) : null,
      ),
      alignment: Alignment.center,
      child: done
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : Text(
              '${index + 1}',
              style: TextStyle(
                color: active ? Colors.white : AppColors.mutedForeground,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
    );
  }
}

/// Barre d'actions fixe en bas d'un stepper (retour + suivant/valider).
class StepActions extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final String nextLabel;
  final IconData nextIcon;
  final bool loading;
  final bool brand;

  const StepActions({
    super.key,
    this.onBack,
    required this.onNext,
    required this.nextLabel,
    this.nextIcon = Icons.arrow_forward_rounded,
    this.loading = false,
    this.brand = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(AppSpacing.page, 12, AppSpacing.page, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(color: AppColors.foreground.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, -6)),
        ],
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            SizedBox(
              width: 54,
              height: 54,
              child: OutlinedButton(
                onPressed: loading ? null : onBack,
                style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(54, 54)),
                child: const Icon(Icons.arrow_back_rounded, size: 22),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: SizedBox(
              height: 54,
              child: brand
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: onNext == null || loading ? null : AppColors.brandGradient,
                        color: onNext == null || loading ? AppColors.primary.withValues(alpha: 0.4) : null,
                        borderRadius: AppRadius.rMd,
                      ),
                      child: ElevatedButton.icon(
                        onPressed: loading ? null : onNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                        ),
                        icon: loading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Icon(nextIcon, size: 20),
                        label: Text(nextLabel),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: loading ? null : onNext,
                      icon: loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(nextIcon, size: 20),
                      label: Text(nextLabel),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
