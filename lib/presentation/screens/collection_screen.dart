import '../widgets/atmosphere.dart';
import 'package:flutter/material.dart';
import '../../game/combos/combo.dart';
import '../../game/data/game_catalog.dart';
import '../../game/fusion/fusion.dart';
import '../widgets/game_card.dart';

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({
    super.key,
    required this.catalog,
    required this.discovered,
  });
  final GameCatalog catalog;
  final List<String> discovered;
  @override
  Widget build(BuildContext context) => AtmosphericScaffold(
    appBar: AppBar(title: const Text('Combos & fusions')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Tactical combos', style: TextStyle(fontSize: 26)),
            const Text(
              'Play the pair consecutively in one turn. Bonuses resolve after the second card, only while its target survives. Bonus damage uses block but is not modified by Strength, Weak, Vulnerable or Shock.',
            ),
            for (final combo in comboLibrary)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(combo.name),
                subtitle: Text(combo.description),
              ),
            const Divider(),
            const Text('Fusion recipes', style: TextStyle(fontSize: 26)),
            const Text(
              'Discoveries belong to this journey. Fuse either order at a shrine. Upgrades on the two source cards are consumed.',
            ),
            for (final recipe in fusionRecipes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${catalog.cards[recipe.first]!.name} + ${catalog.cards[recipe.second]!.name}',
                    ),
                    Text(
                      discovered.contains(recipe.result)
                          ? 'Discovered this journey'
                          : 'Not yet fused this journey',
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 280,
                      width: 190,
                      child: GameCard(card: catalog.cards[recipe.result]!),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
