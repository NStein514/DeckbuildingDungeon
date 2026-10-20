import '../data/game_catalog.dart';
import '../fusion/fusion.dart';
import '../models/models.dart';
import '../profile/player_profile.dart';

/// Sidegrade decks; unlocks are derived from durable journal records.
enum StartingBuild {
  wanderer,
  stormweaver,
  venomblade;

  String get title => switch (this) {
    wanderer => 'Wanderer',
    stormweaver => 'Stormweaver',
    venomblade => 'Venomblade',
  };

  String get description => switch (this) {
    wanderer => 'The original balanced deck. Always available.',
    stormweaver =>
      'Trade Heavy Blow and one Strike for Static Lance and Spark. Discover any fusion to unlock.',
    venomblade =>
      'Trade Heavy Blow and Firebolt for Poison Edge and Quick Slash. Defeat a guardian to unlock.',
  };

  bool unlocked(PlayerProfile? profile) => switch (this) {
    wanderer => true,
    stormweaver =>
      profile != null &&
          fusionRecipes.any((recipe) => profile.cards.contains(recipe.result)),
    venomblade => profile != null && profile.bestBosses >= 1,
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
    }
    return [
      for (var i = 0; i < ids.length; i++) CardInstance('starter-$i', ids[i]),
    ];
  }
}
