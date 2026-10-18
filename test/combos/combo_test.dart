import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/game/combat/combat_engine.dart';
import 'package:deckbound/game/models/models.dart';
import 'package:deckbound/game/relics/relic.dart';
import '../test_catalog.dart';

void main() {
  final catalog = loadCatalog();
  CombatEngine battle(
    List<String> ids, {
    int hp = 100,
    int energy = 10,
    Set<Relic> relics = const {},
  }) => CombatEngine(
    cards: catalog.cards,
    deck: [for (var i = 0; i < ids.length; i++) CardInstance('$i', ids[i])],
    enemies: [
      for (var i = 0; i < 2; i++)
        EnemyDefinition('dummy', 'Dummy', hp, const [EnemyAction('Wait', [])]),
    ],
    rules: CombatRules(draw: 10, energy: energy),
    relics: relics,
  );
  void play(CombatEngine e, String id, {String target = 'enemy-0'}) {
    final card = e.state.hand.firstWhere((c) => c.definitionId == id);
    expect(e.play(card.id, targetId: target), isNull);
  }

  test('Overload consumes two Burn after Spark and deals six bonus damage', () {
    final e = battle(['firebolt', 'spark']);
    play(e, 'firebolt');
    play(e, 'spark');
    expect(e.state.enemies.first.health, 87);
    expect(e.state.enemies.first.stacks(Status.burn), 0);
    expect(e.state.enemies.first.stacks(Status.shock), 1);
    expect(
      e.state.events.where((x) => x.kind == EventKind.combo),
      hasLength(1),
    );
    expect(e.state.plays.map((p) => p.definitionId), ['firebolt', 'spark']);
  });
  test(
    'Shield Bash scales with retained accumulated block including relic',
    () {
      final e = battle(['guard', 'heavy_blow'], relics: {Relic.ironSigil});
      play(e, 'guard');
      play(e, 'heavy_blow');
      expect(e.state.player.block, 9);
      expect(e.state.enemies.first.health, 78);
    },
  );
  test('Toxic Flurry applies ordinary Poison including Venom Fang', () {
    final e = battle(['poison_edge', 'quick_slash'], relics: {Relic.venomFang});
    play(e, 'poison_edge');
    play(e, 'quick_slash');
    expect(e.state.enemies.first.health, 93);
    expect(e.state.enemies.first.stacks(Status.poison), 8);
  });
  test(
    'different enemies and reverse order cannot trigger elemental combo',
    () {
      final e = battle(['firebolt', 'spark']);
      play(e, 'firebolt');
      play(e, 'spark', target: 'enemy-1');
      expect(e.state.events.where((x) => x.kind == EventKind.combo), isEmpty);
      final reversed = battle(['spark', 'firebolt']);
      play(reversed, 'spark');
      play(reversed, 'firebolt');
      expect(
        reversed.state.events.where((x) => x.kind == EventKind.combo),
        isEmpty,
      );
    },
  );
  test('intervening successful play breaks combo; invalid play does not', () {
    final e = battle(['firebolt', 'spark', 'guard']);
    play(e, 'firebolt');
    play(e, 'guard');
    play(e, 'spark');
    expect(e.state.events.where((x) => x.kind == EventKind.combo), isEmpty);
    final valid = battle(['firebolt', 'spark']);
    play(valid, 'firebolt');
    expect(valid.play('missing'), isNotNull);
    expect(
      valid.play(valid.state.hand.single.id, targetId: 'missing'),
      isNotNull,
    );
    expect(valid.state.plays, hasLength(1));
    play(valid, 'spark');
    expect(
      valid.state.events.where((x) => x.kind == EventKind.combo),
      hasLength(1),
    );
  });
  test('new turn clears history even when the pair remains in the deck', () {
    final e = battle(['firebolt', 'spark']);
    play(e, 'firebolt');
    e.endTurn();
    expect(e.state.plays, isEmpty);
    play(e, 'spark');
    expect(e.state.events.where((x) => x.kind == EventKind.combo), isEmpty);
  });
  test('dead target does not receive bonus or redirect to another enemy', () {
    final e = battle(['firebolt', 'spark'], hp: 7);
    play(e, 'firebolt');
    play(e, 'spark');
    expect(e.state.enemies.last.health, 7);
    expect(e.state.events.where((x) => x.kind == EventKind.combo), isEmpty);
  });
  test('combo can finish combat and no commands run after victory', () {
    final e = CombatEngine(
      cards: catalog.cards,
      deck: const [
        CardInstance('fire', 'firebolt'),
        CardInstance('spark', 'spark'),
      ],
      enemies: const [
        EnemyDefinition('d', 'Dummy', 13, [EnemyAction('Wait', [])]),
      ],
    );
    play(e, 'firebolt');
    play(e, 'spark');
    expect(e.state.outcome, Outcome.victory);
    expect(e.endTurn(), isNotNull);
  });
  test('fusion results resolve damage, block and statuses in combat', () {
    final e = battle(['flaming_strike', 'glacial_barrier', 'venom_flurry']);
    play(e, 'flaming_strike');
    play(e, 'glacial_barrier');
    play(e, 'venom_flurry');
    expect(e.state.enemies.first.health, 86);
    expect(e.state.enemies.first.stacks(Status.burn), 3);
    expect(e.state.enemies.first.stacks(Status.chill), 1);
    expect(e.state.enemies.first.stacks(Status.poison), 3);
    expect(e.state.player.block, 9);
  });
}
