import '../../core/random/seeded_random.dart';
import '../data/game_catalog.dart';
import '../models/models.dart';

class Merchant {
  static const healingPrice = 30, healingAmount = 15, removalPrice = 40;
  static const minimumDeck = 5;
  static int price(CardDefinition card) => switch (card.rarity) {
    Rarity.common => 40,
    Rarity.uncommon => 60,
    Rarity.rare => 90,
    Rarity.legendary => 120,
  };
  static List<String> stock(GameCatalog catalog, int seed) {
    final pool =
        catalog.cards.values
            .where(
              (c) => c.type != CardType.curse && !c.tags.contains('fusion'),
            )
            .map((c) => c.id)
            .toList()
          ..sort();
    SeededRandom(seed).shuffle(pool);
    return List.unmodifiable(pool.take(3));
  }
}

enum JourneyEvent {
  bloodAltar(
    'The hungry altar',
    'Offer 8 HP to receive 35 gold. You must survive the offering.',
    -8,
    35,
  ),
  wanderingHealer(
    'The wandering healer',
    'Pay 20 gold to restore up to 12 HP.',
    12,
    -20,
  ),
  emberForge(
    'The ember forge',
    'Offer 6 HP to upgrade one unupgraded card. You must survive the forging.',
    -6,
    0,
  ),
  memoryWell(
    'The memory well',
    'Pay 25 gold to remove one card permanently. Keep at least five cards.',
    0,
    -25,
  );

  const JourneyEvent(this.title, this.description, this.health, this.gold);
  final String title, description;
  final int health, gold;
  bool get choosesCard => this == emberForge || this == memoryWell;
  String get actionLabel => switch (this) {
    bloodAltar => 'Offer 8 HP · gain 35 gold',
    wanderingHealer => 'Pay 20 gold · heal up to 12 HP',
    emberForge => 'Offer 6 HP · choose an upgrade',
    memoryWell => 'Pay 25 gold · choose a card to remove',
  };
  bool canAccept(
    int currentHealth,
    int currentGold,
    int maxHealth,
    List<CardInstance> deck,
  ) =>
      currentHealth + health > 0 &&
      currentGold + gold >= 0 &&
      (health <= 0 || currentHealth < maxHealth) &&
      (this != emberForge || deck.any((c) => c.upgrade == 0)) &&
      (this != memoryWell || deck.length > Merchant.minimumDeck);
  static JourneyEvent fromSeed(int seed, {required int mapVersion}) {
    final roll = SeededRandom(seed).nextInt(1000000);
    return mapVersion < 6
        ? values[roll < 500000 ? 0 : 1]
        : values[roll ~/ 250000];
  }
}
