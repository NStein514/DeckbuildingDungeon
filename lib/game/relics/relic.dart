enum Relic {
  emberHeart(
    'Ember Heart',
    'The first Fire card each combat applies 2 additional Burn.',
  ),
  ironSigil('Iron Sigil', 'Begin each combat with 4 block.'),
  quickdrawCharm('Quickdraw Charm', 'Draw one extra card on the first turn.'),
  venomFang('Venom Fang', 'Your Poison applications gain 1 extra stack.');

  const Relic(this.title, this.description);
  final String title, description;
}
