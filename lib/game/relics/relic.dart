enum Relic {
  emberHeart(
    'Ember Heart',
    'The first Fire card each combat applies 2 additional Burn.',
  ),
  ironSigil('Iron Sigil', 'Begin each combat with 4 block.'),
  quickdrawCharm('Quickdraw Charm', 'Draw one extra card on the first turn.'),
  venomFang('Venom Fang', 'Your Poison applications gain 1 extra stack.'),
  lastEmber(
    'Last Ember',
    'Enter combat at half health or less to gain 1 extra energy on the first turn.',
  );

  const Relic(this.title, this.description);
  final String title, description;

  bool grantsOpeningEnergy(int health, int maxHealth) =>
      this == lastEmber && health * 2 <= maxHealth;

  static Iterable<Relic> treasurePool(int mapVersion) =>
      values.where((r) => mapVersion >= 9 || r != lastEmber);
}
