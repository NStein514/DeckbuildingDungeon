import 'package:flutter/material.dart';

/// Logical identifiers remain stable when approved illustrations are imported.
class AssetRegistry {
  static const Map<String, String> illustrations = {
    'cards/trail_rations': 'assets/images/cards/trail_rations.png',
    'cards/winter_circuit': 'assets/images/cards/winter_circuit.png',
    'cards/nightshade_mantle': 'assets/images/cards/nightshade_mantle.png',
    'cards/graven_resolve': 'assets/images/cards/graven_resolve.png',
    'cards/cinder_insight': 'assets/images/cards/cinder_insight.png',

    'cards/measured_strike': 'assets/images/cards/measured_strike.png',
    'cards/stormglass_focus': 'assets/images/cards/stormglass_focus.png',
    'cards/patient_fang': 'assets/images/cards/patient_fang.png',
    'cards/crypt_reprisal': 'assets/images/cards/crypt_reprisal.png',
    'cards/phoenix_brand': 'assets/images/cards/phoenix_brand.png',

    'cards/ash_surge': 'assets/images/cards/ash_surge.png',
    'cards/ember_veil': 'assets/images/cards/ember_veil.png',
    'cards/tomb_seal': 'assets/images/cards/tomb_seal.png',
    'cards/grave_oath': 'assets/images/cards/grave_oath.png',
    'cards/serpent_step': 'assets/images/cards/serpent_step.png',
    'cards/wasting_venom': 'assets/images/cards/wasting_venom.png',
    'cards/forked_current': 'assets/images/cards/forked_current.png',
    'cards/charged_aegis': 'assets/images/cards/charged_aegis.png',
    'cards/lantern_watch': 'assets/images/cards/lantern_watch.png',
    'cards/trailblazer_cut': 'assets/images/cards/trailblazer_cut.png',
    'cards/venom_flurry': 'assets/images/cards/venom_flurry.png',
    'cards/glacial_barrier': 'assets/images/cards/glacial_barrier.png',
    'cards/flaming_strike': 'assets/images/cards/flaming_strike.png',
    'cards/bulwark': 'assets/images/cards/bulwark.png',
    'cards/static_lance': 'assets/images/cards/static_lance.png',
    'cards/double_cut': 'assets/images/cards/double_cut.png',
    'cards/renewal': 'assets/images/cards/renewal.png',
    'cards/expose': 'assets/images/cards/expose.png',
    'cards/poison_edge': 'assets/images/cards/poison_edge.png',
    'cards/battle_cry': 'assets/images/cards/battle_cry.png',
    'cards/focus': 'assets/images/cards/focus.png',
    'cards/guard': 'assets/images/cards/guard.png',
    'cards/quick_slash': 'assets/images/cards/quick_slash.png',
    'cards/heavy_blow': 'assets/images/cards/heavy_blow.png',
    'cards/mend': 'assets/images/cards/mend.png',
    'cards/firebolt': 'assets/images/cards/firebolt.png',
    'cards/frost_ward': 'assets/images/cards/frost_ward.png',
    'cards/spark': 'assets/images/cards/spark.png',
    'cards/preparation': 'assets/images/cards/preparation.png',
    'enemies/rat': 'assets/images/enemies/rat.png',
    'enemies/skeleton': 'assets/images/enemies/skeleton.png',
    'enemies/mage': 'assets/images/enemies/mage.png',
    'enemies/warden': 'assets/images/enemies/warden.png',
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
    'events/sanctuary': 'assets/images/events/sanctuary.png',
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

  /// Null lets the artwork use its natural aspect ratio at the available width.
  final double? height;
  @override
  Widget build(BuildContext context) {
    final path = AssetRegistry.illustrations[id];
    if (path != null) {
      return Image.asset(
        path,
        height: height,
        cacheWidth: id.startsWith('cards/') ? 512 : 768,
        // Preserve the complete composition inside each card's artwork window.
        fit: id.startsWith('cards/') || id.startsWith('enemies/')
            ? BoxFit.contain
            : BoxFit.cover,
        excludeFromSemantics: true,
        errorBuilder: (_, error, stack) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
    height: height ?? 80,
    width: double.infinity,
    decoration: BoxDecoration(
      gradient: RadialGradient(
        colors: [color.withValues(alpha: .16), const Color(0xff131b25)],
      ),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: (height ?? 80) * .42),
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
