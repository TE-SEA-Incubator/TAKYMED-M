import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Applique un effet "shimmer" balayant ses enfants (placeholders gris).
class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [Color(0xFFE6EDF3), Color(0xFFF6F9FB), Color(0xFFE6EDF3)],
              stops: const [0.35, 0.5, 0.65],
              begin: const Alignment(-1, -0.3),
              end: const Alignment(1, 0.3),
              transform: _SlidingGradientTransform(_controller.value * 2 - 1),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform(this.slidePercent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0, 0);
  }
}

/// Bloc placeholder (à utiliser dans un [Shimmer]).
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  final bool circle;

  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 8, this.circle = false});

  const SkeletonBox.circle({super.key, required double size}) : width = size, height = size, radius = 999, circle = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE6EDF3),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}

/// Ligne de texte placeholder (largeur relative).
class SkeletonLine extends StatelessWidget {
  final double widthFactor;
  final double height;

  const SkeletonLine({super.key, this.widthFactor = 1, this.height = 12});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: SkeletonBox(height: height, radius: height / 2),
    );
  }
}

/// Carte placeholder générique (icône + 2 lignes).
class SkeletonCard extends StatelessWidget {
  final double height;
  final bool withLeading;

  const SkeletonCard({super.key, this.height = 84, this.withLeading = true});

  @override
  Widget build(BuildContext context) {
    // Cartes basses (< 72 px) : lignes et espacements réduits, et on tronque
    // au lieu de déborder si la hauteur demandée est vraiment petite.
    final compact = height < 72;
    final pad = compact ? 12.0 : 16.0;
    final leadingSize = compact ? (height - pad * 2).clamp(20.0, 40.0) : 48.0;
    return Container(
      height: height,
      padding: EdgeInsets.all(pad),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.rLg,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          if (withLeading) ...[SkeletonBox(width: leadingSize, height: leadingSize, radius: 14), const SizedBox(width: 14)],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: compact
                  ? const [SkeletonLine(widthFactor: 0.6, height: 11), SizedBox(height: 6), SkeletonLine(widthFactor: 0.9, height: 9)]
                  : const [SkeletonLine(widthFactor: 0.6, height: 14), SizedBox(height: 10), SkeletonLine(widthFactor: 0.9, height: 11)],
            ),
          ),
        ],
      ),
    );
  }
}

/// Liste de cartes placeholders (dans un Shimmer).
class SkeletonList extends StatelessWidget {
  final int count;
  final double itemHeight;
  final EdgeInsetsGeometry padding;
  final bool withLeading;

  const SkeletonList({super.key, this.count = 4, this.itemHeight = 84, this.padding = AppSpacing.listPadding, this.withLeading = true});

  @override
  Widget build(BuildContext context) {
    // Pas de ListView : ce squelette est souvent inséré dans un scroll parent,
    // où un viewport imbriqué sans hauteur bornée plante le layout
    // (« Vertical viewport was given unbounded height »). Le SingleChildScrollView
    // se contente de la hauteur de son contenu en contexte non borné et coupe
    // proprement (sans débordement) lorsqu'il sert de body plein écran.
    return Shimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              SkeletonCard(height: itemHeight, withLeading: withLeading),
            ],
          ],
        ),
      ),
    );
  }
}

/// Placeholder d'un tableau de bord (héro + tuiles + lignes).
class SkeletonDashboard extends StatelessWidget {
  const SkeletonDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        padding: AppSpacing.listPadding,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          SkeletonBox(height: 160, radius: 24),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 96, radius: 20)),
              SizedBox(width: 12),
              Expanded(child: SkeletonBox(height: 96, radius: 20)),
              SizedBox(width: 12),
              Expanded(child: SkeletonBox(height: 96, radius: 20)),
            ],
          ),
          SizedBox(height: 24),
          SkeletonLine(widthFactor: 0.4, height: 16),
          SizedBox(height: 14),
          SkeletonCard(),
          SizedBox(height: 12),
          SkeletonCard(),
          SizedBox(height: 12),
          SkeletonCard(),
        ],
      ),
    );
  }
}
