import 'package:flutter/material.dart';
import '../../assets/asset_registry.dart';
import '../../game/models/models.dart';

Color cardColor(CardType type) => switch (type) {
  CardType.attack => const Color(0xffdf8e78),
  CardType.defense => const Color(0xff8ebfc8),
  CardType.spell => const Color(0xffbba3de),
  _ => const Color(0xffc8b77b),
};
IconData cardIcon(CardType type) => switch (type) {
  CardType.attack => Icons.bolt,
  CardType.defense => Icons.shield_outlined,
  CardType.spell => Icons.local_fire_department_outlined,
  _ => Icons.auto_awesome,
};

class GameCard extends StatelessWidget {
  const GameCard({
    super.key,
    required this.card,
    this.selected = false,
    this.affordable = true,
    this.onTap,
    this.reducedMotion = false,
  });
  final CardDefinition card;
  final bool selected, affordable, reducedMotion;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final color = cardColor(card.type);
    return Semantics(
      button: onTap != null,
      excludeSemantics: true,
      onTap: onTap,
      selected: selected,
      label:
          '${card.name}. Cost ${card.cost}. ${card.description}${affordable ? '' : ' Not enough energy.'}',
      child: AnimatedContainer(
        duration: Duration(milliseconds: reducedMotion ? 0 : 140),
        width: 150,
        margin: EdgeInsets.only(
          top: selected ? 0 : 7,
          bottom: selected ? 7 : 0,
        ),
        decoration: BoxDecoration(
          color: const Color(0xff181c21),
          image: const DecorationImage(
            image: ResizeImage(
              AssetImage('assets/images/ui/card_frame.png'),
              width: 384,
            ),
            fit: BoxFit.fill,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xfff4d699)
                : color.withValues(alpha: .5),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stack(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: GameIllustration(
                            id: card.art,
                            icon: cardIcon(card.type),
                            color: color,
                            height: null,
                          ),
                        ),
                        Positioned(
                          top: 3,
                          left: 3,
                          right: 3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xe610151c),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: color.withValues(alpha: .45),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: affordable
                                        ? color
                                        : const Color(0xff746168),
                                  ),
                                  child: Text(
                                    '${card.cost}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xff10151c),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    card.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(9, 7, 9, 0),
                      child: Text(
                        '${card.type.name.toUpperCase()} · ${card.rarity.name}',
                        style: TextStyle(color: color, fontSize: 9),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(9),
                        child: Text(
                          card.description,
                          style: const TextStyle(fontSize: 11, height: 1.35),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
