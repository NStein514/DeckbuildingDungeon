import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/game/combat/combat_engine.dart';
import 'package:deckbound/game/data/game_catalog.dart';
import 'package:deckbound/game/economy/economy.dart';
import 'package:deckbound/game/models/models.dart';
import 'package:deckbound/game/progression/run_rules.dart';
import 'package:deckbound/game/progression/run_state.dart';
import 'package:deckbound/core/persistence/run_repository.dart';
import 'package:deckbound/core/persistence/save_store.dart';
import '../test_catalog.dart';
import '../economy/economy_test.dart' show reachRoom;
import 'package:deckbound/game/dungeon/dungeon.dart';
import '../progression/descent_test.dart' show won;

void main() {
  final catalog = loadCatalog(), rules = RunRules(loadCatalog());
  CombatEngine battle(List<String> ids, {int health = 50, int damage = 0}) =>
      CombatEngine(
        cards: catalog.cards,
        deck: [for (var i = 0; i < ids.length; i++) CardInstance('$i', ids[i])],
        enemies: [
          EnemyDefinition('dummy', 'Dummy', 100, [
            EnemyAction('Hit', [Effect(EffectKind.damage, damage)]),
          ]),
        ],
        rules: const CombatRules(energy: 10, draw: 10),
        initialHealth: health,
      );
  void play(CombatEngine e, String id) {
    expect(
      e.play(
        e.state.hand.firstWhere((c) => c.definitionId == id).id,
        targetId: 'enemy-0',
      ),
      isNull,
    );
  }

  test('Trail Rations heals once and respects maximum health', () {
    for (final health in [30, 49]) {
      final e = battle(['trail_rations'], health: health);
      play(e, 'trail_rations');
      expect(e.state.player.health, health == 30 ? 33 : 50);
      expect(e.state.exhaust, 1);
      e.endTurn();
      expect(e.state.hand, isEmpty);
    }
  });
  test(
    'Winter Circuit reduces an attack turn while preserving Shock for lightning',
    () {
      final e = battle(['winter_circuit', 'forked_current'], damage: 8);
      play(e, 'winter_circuit');
      e.endTurn();
      expect(e.state.player.health, 44);
      expect(e.state.enemies.single.stacks(Status.chill), 0);
      expect(e.state.enemies.single.stacks(Status.shock), 2);
      play(e, 'forked_current');
      expect(e.state.enemies.single.health, 92);
      expect(e.state.enemies.single.stacks(Status.shock), 0);
    },
  );
  test('Nightshade Mantle blocks damage as poison ticks', () {
    final e = battle(['nightshade_mantle'], damage: 8);
    play(e, 'nightshade_mantle');
    expect(e.state.player.block, 4);
    e.endTurn();
    expect(e.state.player.health, 46);
    expect(e.state.enemies.single.health, 98);
    expect(e.state.enemies.single.stacks(Status.poison), 1);
  });
  test(
    'Graven Resolve protects now and strengthens later turns without replay',
    () {
      final e = battle(['graven_resolve', 'strike'], damage: 8);
      play(e, 'graven_resolve');
      expect(e.state.player.block, 6);
      expect(e.state.energy, 8);
      expect(e.state.exhaust, 1);
      e.endTurn();
      expect(e.state.player.health, 48);
      expect(e.state.player.stacks(Status.strength), 1);
      play(e, 'strike');
      expect(e.state.enemies.single.health, 93);
    },
  );
  for (final id in ['trail_rations', 'cinder_insight']) {
    test('$id draws a replacement without drawing itself', () {
      for (var seed = 0; seed < 100; seed++) {
        final e = CombatEngine(
          cards: catalog.cards,
          deck: [
            CardInstance('new', id),
            const CardInstance('a', 'strike'),
            const CardInstance('b', 'guard'),
          ],
          enemies: const [
            EnemyDefinition('dummy', 'Dummy', 100, [EnemyAction('Wait', [])]),
          ],
          rules: const CombatRules(draw: 2),
          seed: seed,
        );
        if (!e.state.hand.any((c) => c.id == 'new')) continue;
        play(e, id);
        expect(e.state.hand, hasLength(2));
        expect(e.state.draw, 0);
        expect(e.state.hand.any((c) => c.id == 'new'), isFalse);
        if (id == 'cinder_insight') {
          expect(e.state.enemies.single.stacks(Status.burn), 2);
          e.endTurn();
          expect(e.state.enemies.single.health, 98);
        }
        return;
      }
      fail('No opening hand found');
    });
  }
  test('pool 3 preserves previous expansion shops and reward rolls', () async {
    final prior = GameCatalog.decode(
      jsonEncode(
        (jsonDecode(File('assets/data/cards.json').readAsStringSync()) as List)
            .where(
              (c) =>
                  !(c['tags'] as List? ?? []).contains('endurance_expansion'),
            )
            .toList(),
      ),
      File('assets/data/enemies.json').readAsStringSync(),
      File('assets/data/balance.json').readAsStringSync(),
    );
    for (var seed = 0; seed < 150; seed++) {
      expect(
        Merchant.stock(catalog, seed, poolVersion: 3),
        Merchant.stock(prior, seed),
      );
      final old = RunState.fromJson(
        rules.start(seed).toJson()..['cardPoolVersion'] = 3,
      );
      final fight = enterRoom(rules, old, old.rooms.first.id);
      final actual = rules.finishCombat(fight, Outcome.victory, 40);
      final expected = RunRules(prior).finishCombat(fight, Outcome.victory, 40);
      expect(actual.rewards, expected.rewards);
      expect(actual.rngState, expected.rngState);
    }
    final oldShop = RunState.fromJson(
      reachRoom(rules, RoomType.merchant).toJson()..['cardPoolVersion'] = 3,
    )..gold = 200;
    final bought = rules.buyCard(
      oldShop,
      Merchant.stock(prior, oldShop.battleSeed).first,
    );
    final store = MemorySaveStore()
      ..contents = jsonEncode({
        'version': 1,
        'contentVersion': 15,
        'run': bought.toJson(),
      });
    final loaded = (await RunRepository(store, catalog).load())!;
    expect(loaded.purchases, bought.purchases);
    expect(loaded.cardPoolVersion, 3);
    final victory = RunState.fromJson(
      won(rules).toJson()..['cardPoolVersion'] = 3,
    );
    expect(rules.descend(victory).cardPoolVersion, 3);
  });
}
