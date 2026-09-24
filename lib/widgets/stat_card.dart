import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'app_card.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.mutedForeground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuotaInfo {
  final int used;
  final int? max;
  final int? remaining;
  final bool unlimited;

  const QuotaInfo({
    required this.used,
    this.max,
    this.remaining,
    this.unlimited = false,
  });

  factory QuotaInfo.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const QuotaInfo(used: 0, max: 0, remaining: 0);
    }
    final unlimited = map['unlimited'] == true;
    final used = (map['used'] as num?)?.toInt() ?? 0;
    final max = unlimited ? null : (map['max'] as num?)?.toInt();
    final remaining = unlimited ? null : (map['remaining'] as num?)?.toInt();
    return QuotaInfo(
      used: used,
      max: max,
      remaining: remaining,
      unlimited: unlimited,
    );
  }

  String get limitLabel => unlimited ? 'Illimité' : '${max ?? 0}';

  String get remainingLabel {
    if (unlimited) return '∞';
    return '${(remaining ?? 0).clamp(0, 9999)}';
  }

  double get progress {
    if (unlimited || max == null || max! <= 0) return 0;
    return (used / max!).clamp(0.0, 1.0);
  }

  Color get accentColor {
    if (unlimited) return AppColors.success;
    final p = progress;
    if (p >= 1) return AppColors.destructive;
    if (p >= 0.8) return AppColors.warning;
    return AppColors.primary;
  }
}

/// Section quotas — alignée sur le dashboard web (used/max + restant).
class QuotaSection extends StatelessWidget {
  final QuotaInfo ordonnances;
  final QuotaInfo rappels;

  const QuotaSection({
    super.key,
    required this.ordonnances,
    required this.rappels,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quotas',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: QuotaCard(
                key: ValueKey('ord-${ordonnances.used}-${ordonnances.max}-${ordonnances.unlimited}'),
                title: 'Ordonnances actives',
                info: ordonnances,
                icon: Icons.description_rounded,
                animationDelay: 0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: QuotaCard(
                key: ValueKey('rap-${rappels.used}-${rappels.max}-${rappels.unlimited}'),
                title: 'Rappels actifs',
                info: rappels,
                icon: Icons.notifications_active_rounded,
                animationDelay: 120,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class QuotaCard extends StatefulWidget {
  final String title;
  final QuotaInfo info;
  final IconData icon;
  final int animationDelay;

  const QuotaCard({
    super.key,
    required this.title,
    required this.info,
    required this.icon,
    this.animationDelay = 0,
  });

  @override
  State<QuotaCard> createState() => _QuotaCardState();
}

class _QuotaCardState extends State<QuotaCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnim;
  late Animation<int> _usedAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _progressAnim = Tween<double>(begin: 0, end: widget.info.progress).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _usedAnim = IntTween(begin: 0, end: widget.info.used).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    Future<void>.delayed(Duration(milliseconds: widget.animationDelay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.info.accentColor;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.icon, size: 18, color: color),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: AppColors.mutedForeground,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_usedAnim.value}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: color,
                      height: 1,
                      letterSpacing: -1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(
                      '/ ${widget.info.limitLabel}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: widget.info.unlimited ? null : _progressAnim.value,
                  minHeight: 6,
                  backgroundColor: color.withValues(alpha: 0.12),
                  color: color,
                ),
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  text: 'Restant : ',
                  style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                  children: [
                    TextSpan(
                      text: widget.info.remainingLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Indicateur circulaire animé (utilisable ailleurs si besoin).
class CircularQuotaIndicator extends StatelessWidget {
  final String label;
  final int used;
  final int? max;
  final bool unlimited;

  const CircularQuotaIndicator({
    super.key,
    required this.label,
    required this.used,
    this.max,
    this.unlimited = false,
  });

  @override
  Widget build(BuildContext context) {
    final info = QuotaInfo(used: used, max: max, unlimited: unlimited);
    final color = info.accentColor;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: info.progress),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) {
        return Column(
          children: [
            SizedBox(
              width: 76,
              height: 76,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: unlimited ? null : progress.clamp(0.0, 1.0),
                    strokeWidth: 6,
                    backgroundColor: color.withValues(alpha: 0.15),
                    color: color,
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        used.toString(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                      if (!unlimited && max != null)
                        Text(
                          '/ $max',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      if (unlimited)
                        const Text(
                          '∞',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.mutedForeground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }
}
