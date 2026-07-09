import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// SHIMMER LOADING
// Enveloppe n'importe quel widget avec un effet shimmer animé.
// Utilise un GradientTransform coulissant pour l'efficacité GPU.
// ─────────────────────────────────────────────────────────────

class ShimmerLoading extends StatefulWidget {
  final Widget child;
  const ShimmerLoading({super.key, required this.child});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      child: widget.child,
      builder: (_, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (Rect bounds) => LinearGradient(
          begin: const Alignment(-1.5, 0),
          end: const Alignment(1.5, 0),
          colors: const [
            Color(0xFFE2E8F0),
            Color(0xFFEEF4FF),
            Color(0xFFF8FAFF),
            Color(0xFFEEF4FF),
            Color(0xFFE2E8F0),
          ],
          stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
          transform: _SlidingGradientTransform(slidePercent: _ctrl.value),
        ).createShader(bounds),
        child: child!,
      ),
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.slidePercent});
  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(
        bounds.width * (slidePercent * 2.5 - 0.75),
        0,
        0,
      );
}

// ─────────────────────────────────────────────────────────────
// PRIMITIVE : boîte grise réutilisable
// ─────────────────────────────────────────────────────────────

Widget skeletonBox(double? w, double h, {double radius = 8}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(radius),
      ),
    );

// ─────────────────────────────────────────────────────────────
// SKELETON — Carte médicament (expansion card)
// Miroir de _MedExpansionCard dans search_screen.dart
// ─────────────────────────────────────────────────────────────

class MedCardSkeleton extends StatelessWidget {
  const MedCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          skeletonBox(5, 48, radius: 3),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                skeletonBox(double.infinity, 15),
                const SizedBox(height: 8),
                skeletonBox(120, 12),
              ],
            ),
          ),
          const SizedBox(width: 12),
          skeletonBox(72, 26, radius: 12),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SKELETON — Carte pharmacie (dans les résultats)
// Miroir de _buildAvailabilityTiles dans search_screen.dart
// ─────────────────────────────────────────────────────────────

class PharmacyCardSkeleton extends StatelessWidget {
  const PharmacyCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Accent strip
          Container(
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFFE2E8F0),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  skeletonBox(44, 44, radius: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        skeletonBox(double.infinity, 15),
                        const SizedBox(height: 6),
                        skeletonBox(140, 12),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  skeletonBox(56, 22, radius: 20),
                ]),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFE2E8F0), height: 1),
                const SizedBox(height: 16),
                Row(children: [
                  skeletonBox(90, 28, radius: 20),
                  const Spacer(),
                  skeletonBox(80, 28, radius: 20),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: skeletonBox(double.infinity, 40, radius: 12)),
                  const SizedBox(width: 10),
                  Expanded(child: skeletonBox(double.infinity, 40, radius: 12)),
                  const SizedBox(width: 10),
                  skeletonBox(46, 46, radius: 12),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SKELETON — Vue complète chargement recherche
// Remplace le spinner dans search_screen.dart
// ─────────────────────────────────────────────────────────────

class SearchLoadingSkeleton extends StatelessWidget {
  const SearchLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            skeletonBox(double.infinity, 64, radius: 12),
            const SizedBox(height: 16),
            skeletonBox(double.infinity, 48, radius: 14),
            const SizedBox(height: 16),
            skeletonBox(double.infinity, 52, radius: 16),
            const SizedBox(height: 16),
            skeletonBox(double.infinity, 68, radius: 16),
            const SizedBox(height: 32),
            skeletonBox(160, 20, radius: 10),
            const SizedBox(height: 16),
            const MedCardSkeleton(),
            const MedCardSkeleton(),
            const MedCardSkeleton(),
            const MedCardSkeleton(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SKELETON — Carte pharmacie proche (nearby_pharmacies_screen)
// ─────────────────────────────────────────────────────────────

class NearbyPharmacyCardSkeleton extends StatelessWidget {
  const NearbyPharmacyCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(children: [
        skeletonBox(48, 48, radius: 12),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              skeletonBox(double.infinity, 15),
              const SizedBox(height: 6),
              skeletonBox(120, 12),
              const SizedBox(height: 6),
              skeletonBox(80, 12),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          skeletonBox(56, 22, radius: 20),
          const SizedBox(height: 8),
          skeletonBox(40, 22, radius: 20),
        ]),
      ]),
    );
  }
}

class NearbyLoadingSkeleton extends StatelessWidget {
  const NearbyLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 5,
        itemBuilder: (_, __) => const NearbyPharmacyCardSkeleton(),
      ),
    );
  }
}
