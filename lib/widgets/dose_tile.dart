import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Ligne de prise (médicament, dose, patient) avec bouton de confirmation.
class DoseTile extends StatelessWidget {
  final Map<String, dynamic> dose;
  final bool busy;
  final bool showTime;
  final bool showClient;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onDelay;
  final VoidCallback? onChangeTime;

  const DoseTile({
    super.key,
    required this.dose,
    this.busy = false,
    this.showTime = true,
    this.showClient = true,
    this.onToggle,
    this.onDelay,
    this.onChangeTime,
  });

  bool get _taken => dose['statusTaken'] == true || dose['statusTaken'] == 1;

  bool get _overdue {
    if (_taken) return false;
    final raw = dose['scheduledAt']?.toString();
    if (raw == null) return false;
    final dt = DateTime.tryParse(raw);
    return dt != null && dt.isBefore(DateTime.now());
  }

  String get _doseLabel {
    final d = dose['dose'];
    final unit = dose['unit']?.toString() ?? '';
    if (d == null) return unit;
    final num? n = d is num ? d : num.tryParse(d.toString());
    final doseStr = n == null ? d.toString() : (n == n.roundToDouble() ? n.toInt().toString() : n.toString());
    return '$doseStr $unit'.trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taken = _taken;
    final overdue = _overdue;
    final accent = taken ? AppColors.success : (overdue ? AppColors.warning : AppColors.primary);
    final time = dose['time']?.toString() ?? '--:--';
    final client = dose['clientName']?.toString() ?? '';
    final hasMenu = onDelay != null || onChangeTime != null;

    return AnimatedContainer(
      duration: AppDurations.normal,
      decoration: BoxDecoration(
        color: taken ? AppColors.successLight.withValues(alpha: 0.5) : AppColors.surface,
        borderRadius: AppRadius.rMd,
        border: Border.all(color: taken ? AppColors.secondary.withValues(alpha: 0.25) : AppColors.border),
        boxShadow: taken ? null : AppShadows.soft,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.rMd,
          onTap: onToggle == null || busy ? null : () => onToggle!(!taken),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                if (showTime) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: AppRadius.rSm,
                    ),
                    child: Text(
                      time,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dose['medicationName']?.toString() ?? 'Médicament',
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
                          if (_doseLabel.isNotEmpty) _doseLabel,
                          if (showClient && client.isNotEmpty) client,
                          if (overdue) 'En retard',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: overdue ? AppColors.warning : AppColors.mutedForeground,
                          fontWeight: overdue ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _CheckButton(taken: taken, busy: busy, accent: accent, onTap: onToggle == null ? null : () => onToggle!(!taken)),
                if (hasMenu && !taken)
                  PopupMenuButton<String>(
                    tooltip: 'Options',
                    icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.mutedForeground),
                    padding: EdgeInsets.zero,
                    onSelected: (v) {
                      if (v == 'delay') onDelay?.call();
                      if (v == 'time') onChangeTime?.call();
                    },
                    itemBuilder: (_) => [
                      if (onDelay != null)
                        const PopupMenuItem(
                          value: 'delay',
                          child: Row(children: [
                            Icon(Icons.snooze_rounded, size: 18, color: AppColors.mutedForeground),
                            SizedBox(width: 10),
                            Text('Reporter la prise'),
                          ]),
                        ),
                      if (onChangeTime != null)
                        const PopupMenuItem(
                          value: 'time',
                          child: Row(children: [
                            Icon(Icons.schedule_rounded, size: 18, color: AppColors.mutedForeground),
                            SizedBox(width: 10),
                            Text('Changer l\'heure'),
                          ]),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckButton extends StatelessWidget {
  final bool taken;
  final bool busy;
  final Color accent;
  final VoidCallback? onTap;

  const _CheckButton({required this.taken, required this.busy, required this.accent, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: AnimatedContainer(
        duration: AppDurations.normal,
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: taken ? AppColors.success : Colors.transparent,
          border: Border.all(color: taken ? AppColors.success : AppColors.borderStrong, width: 2),
        ),
        alignment: Alignment.center,
        child: busy
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: taken ? Colors.white : accent),
              )
            : Icon(
                Icons.check_rounded,
                size: 20,
                color: taken ? Colors.white : Colors.transparent,
              ),
      ),
    );
  }
}
