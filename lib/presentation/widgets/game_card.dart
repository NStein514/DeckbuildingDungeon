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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x995c4225), Color(0xbb201810)],
                            ),
                            border: Border(
                              bottom: BorderSide(color: Color(0xffb59454)),
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
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: affordable
                                        ? const [
                                            Color(0xffefd59a),
                                            Color(0xff98703b),
                                          ]
                                        : const [
                                            Color(0xffa18c77),
                                            Color(0xff594a40),
                                          ],
                                  ),
                                  border: Border.all(
                                    color: const Color(0xffe3c583),
                                  ),
                                ),
                                child: Text(
                                  '${card.cost}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xff201810),
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
                                    color: Color(0xfff3e1b9),
                                    fontWeight: FontWeight.w700,
                                    shadows: [
                                      Shadow(
                                        blurRadius: 2,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        GameIllustration(
                          id: card.art,
                          icon: cardIcon(card.type),
                          color: color,
                          height: null,
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
                              style: const TextStyle(
                                fontSize: 11,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ClipPath(
                        clipper: const _CardRimClipper(),
                        child: Image.asset(
                          'assets/images/ui/card_frame.png',
                          cacheWidth: 384,
                          fit: BoxFit.fill,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Only the ornamental rim paints over the illustration; the center stays clear.
class _CardRimClipper extends CustomClipper<Path> {
  const _CardRimClipper();

  @override
  Path getClip(Size size) => Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Offset.zero & size)
    ..addRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(7),
        const Radius.circular(5),
      ),
    );

  @override
  bool shouldReclip(_CardRimClipper oldClipper) => false;
}
