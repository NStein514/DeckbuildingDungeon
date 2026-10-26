import '../data/game_catalog.dart';
import '../fusion/fusion.dart';
import '../models/models.dart';
import '../profile/player_profile.dart';

/// Sidegrade decks; unlocks are derived from durable journal records.
enum StartingBuild {
  wanderer,
  stormweaver,
  venomblade,
  gravewarden,
  embercaller;

  String get title => switch (this) {
    wanderer => 'Wanderer',
    stormweaver => 'Stormweaver',
    venomblade => 'Venomblade',
    gravewarden => 'Gravewarden',
    embercaller => 'Embercaller',
  };

  String get description => switch (this) {
    wanderer => 'The original balanced deck. Always available.',
    stormweaver =>
      'Trade Heavy Blow and one Strike for Static Lance and Spark. Discover any fusion to unlock.',
    venomblade =>
      'Trade Heavy Blow and Firebolt for Poison Edge and Quick Slash. Defeat a guardian to unlock.',
    gravewarden =>
      'Trade Quick Slash and Firebolt for Brace and Enfeeble. Discover Glacial Barrier, Stormguard, Venom Ward or Bloomguard to unlock.',
    embercaller =>
      'Trade Heavy Blow and Frost Ward for Cinder Storm and a second Firebolt. Discover Flaming Strike or Cinder Maul to unlock.',
  };

  /// Collectible support cards; they do not replace the balanced starting deck.
  List<String> get supportCards => switch (this) {
    wanderer => ['trailblazer_cut', 'lantern_watch', 'measured_strike'],
    stormweaver => ['charged_aegis', 'forked_current', 'stormglass_focus'],
    venomblade => ['wasting_venom', 'serpent_step', 'patient_fang'],
    gravewarden => ['grave_oath', 'tomb_seal', 'crypt_reprisal'],
    embercaller => ['ember_veil', 'ash_surge', 'phoenix_brand'],
  };

  bool unlocked(PlayerProfile? profile) => switch (this) {
    wanderer => true,
    stormweaver =>
      profile != null &&
          fusionRecipes.any((recipe) => profile.cards.contains(recipe.result)),
    venomblade => profile != null && profile.bestBosses >= 1,
    gravewarden =>
      profile != null &&
          const [
            'glacial_barrier',
            'stormguard',
            'venom_ward',
            'bloomguard',
          ].any(profile.cards.contains),
    embercaller =>
      profile != null &&
          const ['flaming_strike', 'cinder_maul'].any(profile.cards.contains),
  };

  List<CardInstance> deck(GameCatalog catalog) {
    final ids = List<String>.of(catalog.startingDeck);
    void replace(String from, String to) => ids[ids.indexOf(from)] = to;
    switch (this) {
      case wanderer:
        break;
      case stormweaver:
        replace('heavy_blow', 'static_lance');
        replace('strike', 'spark');
      case venomblade:
        replace('heavy_blow', 'poison_edge');
        replace('firebolt', 'quick_slash');
      case gravewarden:
        replace('quick_slash', 'brace');
        replace('firebolt', 'enfeeble');
      case embercaller:
        replace('heavy_blow', 'cinder_storm');
        replace('frost_ward', 'firebolt');
    }
    return [
      for (var i = 0; i < ids.length; i++) CardInstance('starter-$i', ids[i]),
    ];
  }
}
