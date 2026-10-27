import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/app/settings.dart';
import 'package:deckbound/core/persistence/run_repository.dart';
import 'package:deckbound/core/persistence/save_store.dart';
import 'package:deckbound/core/random/seeded_random.dart';
import 'package:deckbound/game/combat/combat_engine.dart';
import 'package:deckbound/game/dungeon/difficulty.dart';
import 'package:deckbound/game/dungeon/dungeon.dart';
import 'package:deckbound/game/models/models.dart';
import 'package:deckbound/game/progression/run_rules.dart';
import 'package:deckbound/presentation/screens/battle_screen.dart';
import '../test_catalog.dart';

void main() {
  final catalog = loadCatalog(), rules = RunRules(loadCatalog());
  CombatEngine battle(
    EncounterModifier modifier, {
    String enemy = 'rat',
    int descent = 1,
  }) => CombatEngine(
    cards: catalog.cards,
    deck: const [CardInstance('hit', 'strike')],
    enemies: [scaleEnemy(catalog.enemies[enemy]!, descent, modifier: modifier)],
    rules: const CombatRules(maxHealth: 500),
  );
  test(
    'Rallying gains strength after an action, affecting subsequent hits',
    () {
      final e = battle(EncounterModifier.rallying);
      expect(e.predictedDamage('enemy-0', 5), 5);
      e.endTurn();
      expect(e.state.player.health, 495);
      expect(e.state.enemies.single.stacks(Status.strength), 1);
      expect(e.predictedDamage('enemy-0', 5), 6);
      e.endTurn();
      expect(e.state.player.health, 489);
      expect(e.state.enemies.single.stacks(Status.strength), 2);
      expect(
        battle(EncounterModifier.rallying).state.enemies.single.statuses,
        isEmpty,
      );
    },
  );
  test('Rallying applies once per action, including defense and multi-hit', () {
    final e = battle(EncounterModifier.rallying, enemy: 'duelist');
    e.endTurn();
    expect(e.state.enemies.single.block, 7);
    expect(e.state.enemies.single.stacks(Status.strength), 1);
    final scaled = scaleEnemy(
      catalog.enemies['broodmother']!,
      4,
      modifier: EncounterModifier.rallying,
    );
    for (final action in scaled.pattern) {
      expect(
        action.effects.where((e) => e.status == Status.strength),
        hasLength(1),
      );
      expect(action.effects.last.amount, 1);
    }
  });
  test(
    'Mending heals after actions, caps at max, and cannot revive a kill',
    () {
      final e = battle(EncounterModifier.mending);
      e.endTurn();
      expect(e.state.enemies.single.health, 22);
      e.play('hit', targetId: 'enemy-0');
      expect(e.state.enemies.single.health, 16);
      e.endTurn();
      expect(e.state.enemies.single.health, 19);
      final lethal = CombatEngine(
        cards: catalog.cards,
        deck: const [CardInstance('hit', 'cinder_maul', upgrade: 1)],
        enemies: [
          scaleEnemy(
            const EnemyDefinition('weak', 'Weak', 10, [
              EnemyAction('Wait', []),
            ]),
            1,
            modifier: EncounterModifier.mending,
          ),
        ],
      );
      lethal.play('hit', targetId: 'enemy-0');
      expect(lethal.state.outcome, Outcome.victory);
      expect(lethal.endTurn(), isNotNull);
      expect(lethal.state.enemies.single.health, 0);
    },
  );
  test(
    'descent scaling affects base values but keeps modifier bonuses fixed',
    () {
      final base = catalog.enemies['rat']!;
      final scaled = scaleEnemy(base, 3, modifier: EncounterModifier.mending);
      expect(scaled.health, 31);
      expect(scaled.pattern.first.effects.first.amount, 6);
      expect(scaled.pattern.first.effects.last.amount, 3);
      expect(base.pattern.first.effects, hasLength(1));
    },
  );
  test(
    'new maps vary risk modifiers without moving room contents or risk slots',
    () async {
      final seen = <EncounterModifier>{};
      final repo = RunRepository(MemorySaveStore(), catalog);
      for (var seed = 0; seed < 100; seed++) {
        final old = startVersion(rules, seed, 9), fresh = rules.start(seed);
        expect(fresh.mapVersion, 10);
        expect(fresh.toJson(), rules.start(seed).toJson());
        for (var i = 0; i < old.rooms.length; i++) {
          final a = old.rooms[i], b = fresh.rooms[i];
          expect(
            {...b.toJson()}..remove('modifier'),
            {...a.toJson()}..remove('modifier'),
          );
          expect(
            b.modifier == EncounterModifier.none,
            a.modifier == EncounterModifier.none,
          );
          seen.add(b.modifier);
        }
        await repo.save(fresh);
        expect((await repo.load())!.toJson(), fresh.toJson());
      }
      expect(seen, EncounterModifier.values.toSet());
    },
  );
  test(
    'version 9 golden layout and RNG stay compatible through load and descent',
    () async {
      final golden = jsonDecode(
        File('test/fixtures/map_v9_seed514.json').readAsStringSync(),
      );
      final rng = SeededRandom(514);
      expect(
        DungeonGenerator.generate(
          rng,
          version: 9,
        ).map((r) => r.toJson()).toList(),
        golden['rooms'],
      );
      expect(rng.state, golden['rngState']);
      final old = startVersion(rules, 514, 9);
      final store = MemorySaveStore()
        ..contents = jsonEncode({
          'version': 1,
          'contentVersion': 11,
          'run': old.toJson(),
        });
      final repo = RunRepository(store, catalog);
      var r = (await repo.load())!;
      expect(r.toJson(), old.toJson());
      r = advanceToDepth(rules, r, 5);
      r = enterRoom(rules, r, 'room-5-0');
      r = rules.descend(rules.finishCombat(r, Outcome.victory, 30));
      expect(r.mapVersion, 10);
      await repo.save(r);
      expect(jsonDecode(store.contents!)['contentVersion'], 18);
      expect((await repo.load())!.toJson(), r.toJson());
    },
  );
  test('new modifiers award the existing risk bonus exactly once', () {
    for (final modifier in [
      EncounterModifier.rallying,
      EncounterModifier.mending,
    ]) {
      var r = rules.start(0);
      for (
        var seed = 0;
        !r.rooms.any((room) => room.modifier == modifier);
        seed++
      ) {
        r = rules.start(seed);
      }
      final room = r.rooms.firstWhere((room) => room.modifier == modifier);
      r = enterRoom(rules, advanceToDepth(rules, r, room.depth), room.id);
      final after = rules.finishCombat(r, Outcome.victory, 30);
      expect(after.gold - r.gold, 25 + SeededRandom(r.rngState).nextInt(11));
      expect(
        () => rules.finishCombat(after, Outcome.victory, 30),
        throwsStateError,
      );
    }
  });
  for (final modifier in [
    EncounterModifier.rallying,
    EncounterModifier.mending,
  ]) {
    testWidgets(
      'phone intent identifies modifier self effect: ${modifier.name}',
      (t) async {
        await t.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => t.binding.setSurfaceSize(null));
        await t.pumpWidget(
          MaterialApp(
            home: BattleScreen(
              catalog: catalog,
              enemyIds: const ['rat'],
              settings: GameSettings(),
              seed: 1,
              modifier: modifier,
              deck: const [CardInstance('hit', 'strike')],
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(
          find.text('${modifier.title}: ${modifier.description}'),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            modifier == EncounterModifier.rallying
                ? '1 strength on itself'
                : 'heal itself by 3',
          ),
          findsWidgets,
        );
        await t.ensureVisible(find.text('End turn'));
        await t.tap(find.text('End turn'));
        await t.pumpAndSettle();
        expect(find.text('TURN 2'), findsOneWidget);
        if (modifier == EncounterModifier.rallying) {
          expect(find.textContaining('Gnaw  ·  6 damage'), findsOneWidget);
        }
        expect(t.takeException(), isNull);
      },
    );
  }
}
