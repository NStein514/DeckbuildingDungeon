import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Hidden faces receive no room contents, including semantics and tooltips.
class DungeonCard extends StatelessWidget {
  const DungeonCard({
    super.key,
    required this.label,
    this.onTap,
    this.front,
    this.flip = false,
    this.reducedMotion = false,
    this.fast = false,
  });
  final String label;
  final VoidCallback? onTap;
  final Widget? front;
  final bool flip, reducedMotion, fast;
  @override
  Widget build(BuildContext context) {
    final back = Container(
      constraints: const BoxConstraints(minHeight: 150),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff16191e),
        image: const DecorationImage(
          image: ResizeImage(
            AssetImage('assets/images/ui/card_back.png'),
            width: 384,
          ),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
        border: Border.all(color: const Color(0xffb69b68), width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xe616191e),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            onTap == null
                ? 'Beyond the lantern light'
                : 'Flip to choose this path',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Color(0xffb8c5ce)),
          ),
        ],
      ),
    );
    if (front == null) {
      return Semantics(
        label: label,
        button: onTap != null,
        enabled: onTap != null,
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: back,
          ),
        ),
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: flip && !reducedMotion ? 0 : 1, end: 1),
      duration: Duration(
        milliseconds: reducedMotion
            ? 0
            : fast
            ? 180
            : 550,
      ),
      builder: (_, value, _) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .001)
          ..rotateY(value < .5 ? value * math.pi : (value - 1) * math.pi),
        child: value < .5 ? ExcludeSemantics(child: back) : front!,
      ),
    );
  }
}

/// Cosmetic only: no gameplay RNG consumption, stable across rebuilds/reloads.
double dungeonCardTilt(int mapSeed, String roomId) {
  var hash = mapSeed & 0x7fffffff;
  for (final unit in roomId.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  // Mix adjacent lane IDs before choosing an angle of at most 1.5 degrees.
  hash = ((hash ^ (hash >>> 13)) * 127) & 0x7fffffff;
  return ((hash % 2001) - 1000) / 1000 * (math.pi / 120);
}
