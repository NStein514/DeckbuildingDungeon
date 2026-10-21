import 'package:flutter/material.dart';

/// Logical identifiers remain stable when approved illustrations are imported.
class AssetRegistry {
  static const Map<String, String> illustrations = {
    'relics/lastEmber': 'assets/images/relics/last_ember.png',
    'enemies/duelist': 'assets/images/enemies/duelist.png',
    'effects/slashSequence': 'assets/images/effects/slash_sequence.png',
    'effects/shieldSequence': 'assets/images/effects/shield_sequence.png',
    'effects/fireSequence': 'assets/images/effects/fire_sequence.png',
    'effects/poisonSequence': 'assets/images/effects/poison_sequence.png',
    'effects/lightningSequence': 'assets/images/effects/lightning_sequence.png',
    'effects/healingSequence': 'assets/images/effects/healing_sequence.png',
    'effects/arcaneSequence': 'assets/images/effects/arcane_sequence.png',
    'effects/combatAtlas': 'assets/images/effects/combat_atlas.png',
    'cards/brace': 'assets/images/cards/brace.png',
    'cards/enfeeble': 'assets/images/cards/enfeeble.png',
    'cards/cinder_storm': 'assets/images/cards/cinder_storm.png',
    'cards/venom_ward': 'assets/images/cards/venom_ward.png',
    'cards/bloomguard': 'assets/images/cards/bloomguard.png',
    'cards/stormguard': 'assets/images/cards/stormguard.png',
    'cards/cinder_maul': 'assets/images/cards/cinder_maul.png',
    'cards/strike': 'assets/images/cards/strike.png',
    'events/emberForge': 'assets/images/events/ember_forge.png',
    'events/memoryWell': 'assets/images/events/memory_well.png',
    'enemies/broodmother': 'assets/images/enemies/broodmother.png',
    'enemies/sentinel': 'assets/images/enemies/sentinel.png',
  };
}

class GameIllustration extends StatelessWidget {
  const GameIllustration({
    super.key,
    required this.id,
    this.icon = Icons.auto_awesome,
    this.color = const Color(0xffc8a96b),
    this.height = 80,
  });
  final String id;
  final IconData icon;
  final Color color;
  final double height;
  @override
  Widget build(BuildContext context) {
    final path = AssetRegistry.illustrations[id];
    if (path != null) {
      return Image.asset(
        path,
        height: height,
        fit: id.startsWith('enemies/') ? BoxFit.contain : BoxFit.cover,
        excludeFromSemantics: true,
        errorBuilder: (_, error, stack) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
    height: height,
    width: double.infinity,
    decoration: BoxDecoration(
      gradient: RadialGradient(
        colors: [color.withValues(alpha: .16), const Color(0xff131b25)],
      ),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: height * .42),
        const SizedBox(height: 5),
        Text(
          'TEMP ART',
          style: TextStyle(
            fontSize: 8,
            letterSpacing: 2,
            color: color.withValues(alpha: .7),
          ),
        ),
      ],
    ),
  );
}
