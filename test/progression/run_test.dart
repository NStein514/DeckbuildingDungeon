import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/core/random/seeded_random.dart';
import 'package:deckbound/game/dungeon/dungeon.dart';
import 'package:deckbound/game/progression/run_rules.dart';
import 'package:deckbound/game/progression/run_state.dart';
import 'package:deckbound/game/combat/combat_engine.dart';
import 'package:deckbound/game/cards/upgrades.dart';
import 'package:deckbound/game/models/models.dart';
import 'package:deckbound/game/relics/relic.dart';
import 'package:deckbound/core/persistence/run_repository.dart';
import 'package:deckbound/core/persistence/save_store.dart';
import '../test_catalog.dart';

void main() {
  final catalog = loadCatalog(), rules = RunRules(loadCatalog());
  RunState reward() => rules.finishCombat(
    rules.enter(rules.start(514), 'room-0-0'),
    Outcome.victory,
    40,
  );
  RunState floorThree() {
    var r = rules.reward(reward(), null);
    r = rules.enter(r, r.availableRooms.first);
    return rules.reward(rules.finishCombat(r, Outcome.victory, 30), null);
  }

  CombatEngine battle(List<CardInstance> deck, Set<Relic> relics) =>
      CombatEngine(
        cards: catalog.cards,
        deck: deck,
        enemies: [
          const EnemyDefinition('dummy', 'Dummy', 100, [
            EnemyAction('Wait', []),
          ]),
        ],
        relics: relics,
        rules: const CombatRules(energy: 10, draw: 5),
      );
  test(
    '200 seeded maps have reachable rooms, forward edges and a boss route',
    () {
      final layouts = <String>{};
      for (var seed = 0; seed < 200; seed++) {
        final rooms = DungeonGenerator.generate(SeededRandom(seed)),
            seen = <String>{};
        void visit(String id) {
          if (!seen.add(id)) return;
          final r = rooms.firstWhere((x) => x.id == id);
          if (r.type != RoomType.boss) expect(r.next, isNotEmpty);
          for (final n in r.next) {
            expect(rooms.firstWhere((x) => x.id == n).depth, r.depth + 1);
            visit(n);
          }
        }

        visit(rooms.first.id);
        expect(seen.length, rooms.length);
        expect(rooms.where((r) => r.type == RoomType.boss), hasLength(1));
        layouts.add(jsonEncode(rooms.map((r) => r.toJson()).toList()));
      }
      expect(layouts.length, greaterThan(8));
    },
  );
  test('same seed produces identical map and RNG continuation', () {
    final a = rules.start(514), b = rules.start(514);
    expect(a.toJson(), b.toJson());
    expect(a.deck, hasLength(12));
    expect(a.relics, [Relic.ironSigil]);
  });
  test('room entry rejects unconnected rooms and repeated entry', () {
    final r = rules.start(1);
    expect(() => rules.enter(r, 'room-5-0'), throwsStateError);
    final entered = rules.enter(r, 'room-0-0');
    expect(() => rules.enter(entered, 'room-0-0'), throwsStateError);
    expect(r.currentRoom, isNull);
  });
  test('three unique rewards, once-only gold and reward confirmation', () {
    final r = reward();
    expect(r.rewards.toSet(), hasLength(3));
    expect(r.gold, inInclusiveRange(15, 25));
    expect(r.toJson(), reward().toJson());
    expect(() => rules.finishCombat(r, Outcome.victory, 40), throwsStateError);
    final confirmed = rules.reward(r, r.rewards.first);
    expect(confirmed.deck, hasLength(13));
    expect(r.deck, hasLength(12));
    expect(confirmed.gold, r.gold);
    expect(() => rules.reward(confirmed, r.rewards.first), throwsStateError);
  });
  test('skip and invalid reward selection do not add cards', () {
    final r = reward();
    expect(() => rules.reward(r, 'absent'), throwsStateError);
    expect(rules.reward(r, null).deck, hasLength(12));
  });
  test('rest healing is capped and cannot be claimed twice', () {
    final map = floorThree();
    final r = rules.enter(
      map,
      map.rooms.firstWhere((x) => x.depth == 2 && x.type == RoomType.rest).id,
    );
    final healed = rules.rest(r);
    expect(healed.health, 45);
    expect(() => rules.rest(healed), throwsStateError);
    r.health = 49;
    expect(rules.rest(r).health, 50);
  });
  test('upgrade affects one instance, validates and preserves source', () {
    final map = floorThree();
    final r = rules.enter(
      map,
      map.rooms.firstWhere((x) => x.depth == 2 && x.type == RoomType.rest).id,
    );
    final upgraded = rules.rest(r, upgradeId: r.deck.first.id);
    expect(upgraded.deck.where((c) => c.upgrade == 1), hasLength(1));
    expect(upgraded.health, r.health);
    expect(r.deck.first.upgrade, 0);
    expect(() => rules.rest(r, upgradeId: 'missing'), throwsStateError);
  });
  test('treasure grants a distinct relic and gold once', () {
    final map = floorThree();
    final r = rules.enter(
      map,
      map.rooms
          .firstWhere((x) => x.depth == 2 && x.type == RoomType.treasure)
          .id,
    );
    final taken = rules.treasure(r);
    expect(taken.relics.toSet(), hasLength(2));
    expect(taken.gold, r.gold + 25);
    expect(() => rules.treasure(taken), throwsStateError);
  });
  test(
    'defeat stops progression and inconsistent battle results are rejected',
    () {
      final r = rules.enter(rules.start(1), 'room-0-0');
      final dead = rules.finishCombat(r, Outcome.defeat, 0);
      expect(dead.phase, RunPhase.defeat);
      expect(dead.availableRooms, isEmpty);
      expect(() => rules.finishCombat(r, Outcome.victory, 0), throwsStateError);
      expect(() => rules.finishCombat(r, Outcome.active, 50), throwsStateError);
      expect(() => rules.start(-1), throwsArgumentError);
    },
  );
  test('upgraded wording and combat effects agree', () {
    const c = CardInstance('x', 'strike', upgrade: 1);
    expect(
      resolveCard(catalog.cards['strike']!, c).description,
      'Deal 8 damage.',
    );
    final e = battle([c], {});
    e.play('x', targetId: 'enemy-0');
    expect(e.state.enemies.single.health, 92);
    expect(catalog.cards['strike']!.effects.single.amount, 6);
  });
  test('Iron Sigil only grants first-turn block', () {
    final e = battle([], {Relic.ironSigil});
    expect(e.state.player.block, 4);
    e.endTurn();
    expect(e.state.player.block, 0);
  });
  test('Quickdraw only adds a first-turn draw', () {
    final e = battle(List.generate(12, (i) => CardInstance('$i', 'strike')), {
      Relic.quickdrawCharm,
    });
    expect(e.state.hand, hasLength(6));
    e.endTurn();
    expect(e.state.hand, hasLength(5));
  });
  test('Ember Heart triggers only on first fire play', () {
    final e = battle(
      [
        const CardInstance('a', 'firebolt'),
        const CardInstance('b', 'firebolt'),
      ],
      {Relic.emberHeart},
    );
    e.play('a', targetId: 'enemy-0');
    expect(e.state.enemies.single.stacks(Status.burn), 4);
    e.play('b', targetId: 'enemy-0');
    expect(e.state.enemies.single.stacks(Status.burn), 6);
  });
  test('Venom Fang boosts poison', () {
    final e = battle(
      [const CardInstance('a', 'poison_edge')],
      {Relic.venomFang},
    );
    e.play('a', targetId: 'enemy-0');
    expect(e.state.enemies.single.stacks(Status.poison), 4);
  });
  test(
    'complete seed 514 run wins real battles and restores each checkpoint',
    () async {
      final repo = RunRepository(MemorySaveStore(), catalog);
      var r = rules.start(514);
      var battles = 0;
      for (
        var step = 0;
        step < 30 && r.phase != RunPhase.victory && r.phase != RunPhase.defeat;
        step++
      ) {
        switch (r.phase) {
          case RunPhase.map:
            final options = r.rooms
                .where((x) => r.availableRooms.contains(x.id))
                .toList();
            r = rules.enter(
              r,
              (options.where((x) => x.type == RoomType.rest).firstOrNull ??
                      options.first)
                  .id,
            );
          case RunPhase.combat:
            battles++;
            final e = CombatEngine(
              cards: catalog.cards,
              deck: r.deck,
              enemies: r.room!.enemies
                  .map((id) => catalog.enemies[id]!)
                  .toList(),
              initialHealth: r.health,
              seed: r.battleSeed,
              rules: catalog.rules,
              relics: r.relics.toSet(),
            );
            for (
              var action = 0;
              action < 500 && e.state.outcome == Outcome.active;
              action++
            ) {
              final s = e.state;
              if (s.pendingDiscard > 0) {
                e.discardCard(s.hand.last.id);
                continue;
              }
              final target = s.enemies.where((x) => x.alive).first;
              final incoming = s.enemies
                  .where((x) => x.alive)
                  .fold<int>(
                    0,
                    (n, x) =>
                        n +
                        e
                            .intent(x.id)
                            .effects
                            .where((f) => f.kind == EffectKind.damage)
                            .fold<int>(
                              0,
                              (n, f) => n + e.predictedDamage(x.id, f.amount),
                            ),
                  );
              double score(CardInstance c) {
                final d = catalog.cards[c.definitionId]!;
                var value = 0.0;
                for (final f in d.effects) {
                  value += switch (f.kind) {
                    EffectKind.damage => f.amount.toDouble(),
                    EffectKind.block =>
                      (incoming - s.player.block).clamp(0, f.amount) * 1.2,
                    EffectKind.heal =>
                      (50 - s.player.health).clamp(0, f.amount) * 1.5,
                    EffectKind.draw => f.amount * 3.0,
                    EffectKind.discard => -1.0,
                    EffectKind.status => switch (f.status!) {
                      Status.burn || Status.poison => f.amount * 2.0,
                      Status.strength => 3.0,
                      _ => 1.0,
                    },
                  };
                }
                return value / (d.cost == 0 ? .5 : d.cost);
              }

              final choices =
                  s.hand
                      .where(
                        (c) =>
                            catalog.cards[c.definitionId]!.cost <= s.energy &&
                            score(c) > 0,
                      )
                      .toList()
                    ..sort((a, b) => score(b).compareTo(score(a)));
              if (choices.isEmpty) {
                e.endTurn();
              } else {
                expect(e.play(choices.first.id, targetId: target.id), isNull);
              }
            }
            expect(e.state.outcome, isNot(Outcome.active));
            r = rules.finishCombat(r, e.state.outcome, e.state.player.health);
          case RunPhase.reward:
            r = rules.reward(
              r,
              r.rewards
                  .where(
                    (id) => [
                      'poison_edge',
                      'heavy_blow',
                      'firebolt',
                      'mend',
                      'double_cut',
                    ].contains(id),
                  )
                  .firstOrNull,
            );
          case RunPhase.rest:
            r = rules.rest(r);
          case RunPhase.treasure:
            r = rules.treasure(r);
          case RunPhase.victory || RunPhase.defeat:
            break;
        }
        await repo.save(r);
        final restored = (await repo.load())!;
        expect(restored.toJson(), r.toJson());
        r = restored;
      }
      expect(battles, 4);
      expect(r.phase, RunPhase.victory);
      expect(r.completed, hasLength(6));
      expect(r.gold, greaterThanOrEqualTo(45));
    },
  );
}
