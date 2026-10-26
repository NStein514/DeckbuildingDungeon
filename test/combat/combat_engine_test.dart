import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/game/combat/combat_engine.dart';
import 'package:deckbound/game/models/models.dart';
import '../test_catalog.dart';

void main() {
  final catalog = loadCatalog();
  const dummy = EnemyDefinition('dummy', 'Dummy', 100, [
    EnemyAction('Wait', []),
  ]);
  CombatEngine battle(
    List<String> ids, {
    List<EnemyDefinition> enemies = const [dummy],
    int energy = 10,
    int draw = 10,
    int? health,
    Map<String, CardDefinition>? cards,
  }) => CombatEngine(
    cards: cards ?? catalog.cards,
    deck: [for (var i = 0; i < ids.length; i++) CardInstance('$i', ids[i])],
    enemies: enemies,
    initialHealth: health,
    rules: CombatRules(energy: energy, draw: draw),
    seed: 9,
  );
  String? play(CombatEngine e, String definition, {String target = 'enemy-0'}) {
    final card = e.state.hand.firstWhere((c) => c.definitionId == definition);
    return e.play(card.id, targetId: target);
  }

  test(
    'catalog contains 47 distinct cards and a 12-instance starting deck',
    () {
      expect(catalog.cards.length, 47);
      expect(catalog.createDeck(), hasLength(12));
      expect(catalog.createDeck().map((c) => c.id).toSet(), hasLength(12));
      expect(catalog.enemies.length, 7);
    },
  );
  test('default battle draws five, starts with three energy and fifty HP', () {
    final e = CombatEngine(
      cards: catalog.cards,
      deck: catalog.createDeck(),
      enemies: [dummy],
    );
    expect(e.state.hand, hasLength(5));
    expect(e.state.energy, 3);
    expect(e.state.player.health, 50);
  });
  test('attacks spend energy and discard the played instance', () {
    final e = battle(['strike'], energy: 3);
    expect(play(e, 'strike'), isNull);
    expect(e.state.enemies.single.health, 94);
    expect(e.state.energy, 2);
    expect(e.state.discard, 1);
    expect(e.state.hand, isEmpty);
  });
  test('insufficient energy and invalid targets do not mutate state', () {
    final e = battle(['heavy_blow'], energy: 1);
    expect(play(e, 'heavy_blow'), isNotNull);
    expect(e.state.energy, 1);
    expect(e.state.hand, hasLength(1));
    final validEnergy = battle(['strike']);
    expect(play(validEnergy, 'strike', target: 'missing'), isNotNull);
    expect(validEnergy.state.energy, 10);
    expect(validEnergy.state.enemies.single.health, 100);
  });
  test('zero-cost attacks work at zero energy', () {
    final e = battle(['quick_slash'], energy: 0);
    expect(play(e, 'quick_slash'), isNull);
    expect(e.state.enemies.single.health, 97);
  });
  test('block absorbs damage and clears at next player turn', () {
    const enemy = EnemyDefinition('rat', 'Rat', 100, [
      EnemyAction('Bite', [Effect(EffectKind.damage, 7)]),
    ]);
    final e = battle(['guard'], enemies: [enemy]);
    play(e, 'guard');
    expect(e.state.player.block, 5);
    e.endTurn();
    expect(e.state.player.health, 48);
    expect(e.state.player.block, 0);
  });
  test(
    'healing is capped and exhaust removes a played card from circulation',
    () {
      final e = battle(['mend'], health: 48);
      play(e, 'mend');
      expect(e.state.player.health, 50);
      expect(e.state.exhaust, 1);
      e.endTurn();
      expect(e.state.hand, isEmpty);
    },
  );
  test('unplayed exhaust card stays in hand without exhausting', () {
    final e = battle(['mend']);
    e.endTurn();
    expect(e.state.exhaust, 0);
    expect(e.state.hand.single.definitionId, 'mend');
  });
  test('retain keeps the same instance and drawing respects hand cap', () {
    final e = battle(['brace', 'strike']);
    final retained = e.state.hand
        .firstWhere((c) => c.definitionId == 'brace')
        .id;
    e.endTurn();
    expect(e.state.hand.where((c) => c.id == retained), hasLength(1));
    expect(e.state.hand, hasLength(2));
  });
  test('burn and poison tick before enemy action and decay one stack', () {
    final e = battle(['firebolt', 'poison_edge']);
    play(e, 'firebolt');
    play(e, 'poison_edge');
    expect(e.state.enemies.single.health, 91);
    e.endTurn();
    expect(e.state.enemies.single.health, 86);
    expect(e.state.enemies.single.stacks(Status.burn), 1);
    expect(e.state.enemies.single.stacks(Status.poison), 2);
  });
  test('strength, weak and vulnerable use floor rounding in defined order', () {
    const enemy = EnemyDefinition('hex', 'Hex', 100, [
      EnemyAction('Hex', [Effect(EffectKind.status, 2, status: Status.weak)]),
    ]);
    final e = battle(['battle_cry', 'expose', 'strike'], enemies: [enemy]);
    play(e, 'battle_cry');
    e.endTurn();
    play(e, 'expose');
    play(e, 'strike');
    // (6 + 1) * .75 floor = 5; 5 * 1.5 floor = 7.
    expect(e.state.enemies.single.health, 93);
  });
  test('weak expires after affected actor turns', () {
    final e = battle(['enfeeble']);
    play(e, 'enfeeble');
    e.endTurn();
    expect(e.state.enemies.single.stacks(Status.weak), 1);
    e.endTurn();
    expect(e.state.enemies.single.stacks(Status.weak), 0);
  });
  test('chill impairs next action and then expires', () {
    const enemy = EnemyDefinition('rat', 'Rat', 100, [
      EnemyAction('Bite', [Effect(EffectKind.damage, 7)]),
    ]);
    final e = battle(['frost_ward'], enemies: [enemy]);
    play(e, 'frost_ward');
    expect(e.predictedDamage('enemy-0', 7), 5);
    e.endTurn();
    expect(e.state.player.health, 49);
    expect(e.state.enemies.single.stacks(Status.chill), 0);
  });
  test('lightning consumes shock for bonus damage', () {
    final e = battle(['spark', 'static_lance']);
    play(e, 'spark');
    play(e, 'static_lance');
    expect(e.state.enemies.single.health, 90);
    expect(e.state.enemies.single.stacks(Status.shock), 0);
  });
  test('regeneration heals at owner start and decays', () {
    final e = battle(['renewal'], health: 40);
    play(e, 'renewal');
    e.endTurn();
    expect(e.state.player.health, 43);
    expect(e.state.player.stacks(Status.regeneration), 2);
  });
  test(
    'preparation requires a discard and blocks other commands until chosen',
    () {
      final e = battle(['preparation', 'strike', 'guard']);
      play(e, 'preparation');
      expect(e.state.pendingDiscard, 1);
      expect(e.endTurn(), isNotNull);
      expect(play(e, 'strike'), isNotNull);
      final id = e.state.hand.first.id;
      expect(e.discardCard('absent'), isNotNull);
      expect(e.discardCard(id), isNull);
      expect(e.state.pendingDiscard, 0);
      expect(e.state.hand, hasLength(1));
      expect(e.state.exhaust, 1);
    },
  );
  test('drawing card cannot redraw itself while resolving', () {
    final e = battle(['focus']);
    play(e, 'focus');
    expect(e.state.hand, isEmpty);
    expect(e.state.exhaust, 1);
  });
  test('temporary cards vanish when played or discarded', () {
    const fleeting = CardDefinition(
      id: 'fleeting',
      name: 'Fleeting',
      description: '',
      type: CardType.skill,
      cost: 0,
      effects: [],
      keywords: [Keyword.temporary],
    );
    final e = battle(['fleeting'], cards: {'fleeting': fleeting});
    play(e, 'fleeting');
    expect(
      e.state.discard + e.state.exhaust + e.state.draw + e.state.hand.length,
      0,
    );
    final discard = battle(['fleeting'], cards: {'fleeting': fleeting});
    discard.endTurn();
    expect(discard.state.hand, isEmpty);
  });
  test(
    'multi-hit does not hit corpses and victory requires all enemies dead',
    () {
      const tiny = EnemyDefinition('tiny', 'Tiny', 3, [
        EnemyAction('Wait', []),
      ]);
      final e = battle(['double_cut', 'strike'], enemies: [tiny, tiny]);
      play(e, 'double_cut');
      expect(e.state.outcome, Outcome.active);
      expect(
        e.state.events.where((e) => e.kind == EventKind.defeat),
        hasLength(1),
      );
      expect(play(e, 'strike'), isNotNull);
      expect(play(e, 'strike', target: 'enemy-1'), isNull);
      expect(e.state.outcome, Outcome.victory);
      expect(e.endTurn(), isNotNull);
    },
  );
  test('lethal damage over time prevents enemy action', () {
    const tiny = EnemyDefinition('tiny', 'Tiny', 7, [
      EnemyAction('Kill', [Effect(EffectKind.damage, 999)]),
    ]);
    final e = battle(['firebolt'], enemies: [tiny]);
    play(e, 'firebolt');
    e.endTurn();
    expect(e.state.outcome, Outcome.victory);
    expect(e.state.player.health, 50);
  });
  test('defeat halts later enemies and prevents a new player turn', () {
    const killer = EnemyDefinition('killer', 'Killer', 100, [
      EnemyAction('Kill', [Effect(EffectKind.damage, 60)]),
    ]);
    final e = battle([], enemies: [killer, killer]);
    e.endTurn();
    expect(e.state.player.health, 0);
    expect(e.state.outcome, Outcome.defeat);
    expect(e.state.turn, 1);
    expect(
      e.state.events.where((e) => e.kind == EventKind.damage),
      hasLength(1),
    );
  });
  test('enemy intents advance deterministically and energy replenishes', () {
    final e = battle(['strike'], enemies: [catalog.enemies['skeleton']!]);
    expect(e.intent('enemy-0').name, 'Rusty blade');
    play(e, 'strike');
    e.endTurn();
    expect(e.intent('enemy-0').name, 'Bone shield');
    expect(e.state.energy, 10);
    e.endTurn();
    expect(e.state.enemies.single.block, 8);
  });
  test('snapshots cannot mutate engine fighters and event IDs increase', () {
    final e = battle(['strike']);
    e.state.player.health = 1;
    expect(e.state.player.health, 50);
    play(e, 'strike');
    final ids = e.state.events.map((e) => e.sequence).toList();
    expect(ids.toSet().length, ids.length);
    expect(ids, orderedEquals([...ids]..sort()));
  });
  test('complete seeded battle can reach victory using real card commands', () {
    final e = CombatEngine(
      cards: catalog.cards,
      deck: catalog.createDeck(),
      enemies: [catalog.enemies['rat']!],
      seed: 514,
    );
    for (var turn = 0; turn < 30 && e.state.outcome == Outcome.active; turn++) {
      for (
        var action = 0;
        action < 30 && e.state.outcome == Outcome.active;
        action++
      ) {
        if (e.state.pendingDiscard > 0) {
          e.discardCard(e.state.hand.first.id);
          continue;
        }
        final playable = e.state.hand
            .where((c) => catalog.cards[c.definitionId]!.cost <= e.state.energy)
            .toList();
        if (playable.isEmpty) break;
        e.play(playable.first.id, targetId: 'enemy-0');
      }
      if (e.state.outcome == Outcome.active) e.endTurn();
    }
    expect(e.state.outcome, Outcome.victory);
  });
}
