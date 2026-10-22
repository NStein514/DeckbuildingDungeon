import 'package:flutter/material.dart';

/// Opposing corners keep the hero near the hand and opponents in the distance.
class Battlefield extends StatelessWidget {
  const Battlefield({
    super.key,
    required this.player,
    required this.enemies,
    required this.enemyHeight,
  });

  final Widget player;
  final List<Widget> enemies;
  final double enemyHeight;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
        final opponentWidth = wide
            ? constraints.maxWidth * .58
            : constraints.maxWidth;
        final cardWidth = enemies.length == 1
            ? (opponentWidth * (wide ? 1 : .82)).clamp(220.0, 320.0)
            : ((opponentWidth - 12) / 2).clamp(
                largeText ? 245.0 : 200.0,
                265.0,
              );
        final opponents = SizedBox(
          width: opponentWidth,
          height: enemyHeight,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: opponentWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < enemies.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    SizedBox(width: cardWidth, child: enemies[i]),
                  ],
                ],
              ),
            ),
          ),
        );
        final hero = SizedBox(
          width: cardWidth,
          height: enemyHeight,
          child: player,
        );
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              hero,
              Padding(
                padding: const EdgeInsets.only(bottom: 88),
                child: opponents,
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [opponents, const SizedBox(height: 16), hero],
        );
      },
    ),
  );
}
