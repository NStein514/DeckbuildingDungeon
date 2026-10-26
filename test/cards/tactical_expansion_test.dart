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
  CombatEngine battle(List<String> ids) => CombatEngine(
    cards: catalog.cards,
    deck: [for (var i = 0; i < ids.length; i++) CardInstance('$i', ids[i])],
    enemies: const [
      EnemyDefinition('dummy', 'Dummy', 100, [EnemyAction('Wait', [])]),
    ],
    rules: const CombatRules(energy: 10, draw: 10),
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

  test('guarded attacks damage their target and protect the player', () {
    final e = battle(['measured_strike', 'crypt_reprisal']);
    play(e, 'measured_strike');
    expect(e.state.enemies.single.health, 95);
    expect(e.state.player.block, 3);
    play(e, 'crypt_reprisal');
    expect(e.state.enemies.single.health, 87);
    expect(e.state.player.block, 9);
    expect(e.state.energy, 7);
  });
  test('Stormglass sets up lightning for no energy and exhausts', () {
    final e = battle(['stormglass_focus', 'forked_current']);
    play(e, 'stormglass_focus');
    expect(e.state.energy, 10);
    expect(e.state.exhaust, 1);
    expect(e.state.enemies.single.stacks(Status.shock), 3);
    play(e, 'forked_current');
    expect(e.state.enemies.single.health, 91);
    expect(e.state.enemies.single.stacks(Status.shock), 0);
  });
  test('Stormglass draws from remaining pile without drawing itself', () {
    for (var seed = 0; seed < 100; seed++) {
      final e = CombatEngine(
        cards: catalog.cards,
        deck: const [
          CardInstance('s', 'stormglass_focus'),
          CardInstance('a', 'strike'),
          CardInstance('b', 'guard'),
        ],
        enemies: const [
          EnemyDefinition('dummy', 'Dummy', 100, [EnemyAction('Wait', [])]),
        ],
        rules: const CombatRules(draw: 2),
        seed: seed,
      );
      if (!e.state.hand.any((c) => c.id == 's')) continue;
      play(e, 'stormglass_focus');
      expect(e.state.hand, hasLength(2));
      expect(e.state.hand.any((c) => c.id == 's'), isFalse);
      expect(e.state.draw, 0);
      return;
    }
    fail('No opening hand found');
  });
  test('Patient Fang remains in hand, then deals damage and poison', () {
    final e = battle(['patient_fang']);
    e.endTurn();
    expect(e.state.hand.single.definitionId, 'patient_fang');
    play(e, 'patient_fang');
    expect(e.state.enemies.single.health, 96);
    expect(e.state.enemies.single.stacks(Status.poison), 2);
    e.endTurn();
    expect(e.state.enemies.single.health, 94);
  });
  test('Phoenix Brand deals immediate damage, burns and exhausts', () {
    final e = battle(['phoenix_brand']);
    play(e, 'phoenix_brand');
    expect(e.state.energy, 8);
    expect(e.state.enemies.single.health, 93);
    expect(e.state.enemies.single.stacks(Status.burn), 4);
    expect(e.state.exhaust, 1);
    e.endTurn();
    expect(e.state.enemies.single.health, 89);
  });
  test('pool 2 preserves previous expansion shops and reward rolls', () async {
    final prior = GameCatalog.decode(
      jsonEncode(
        (jsonDecode(File('assets/data/cards.json').readAsStringSync()) as List)
            .where(
              (c) => !(c['tags'] as List? ?? []).contains('tactical_expansion'),
            )
            .toList(),
      ),
      File('assets/data/enemies.json').readAsStringSync(),
      File('assets/data/balance.json').readAsStringSync(),
    );
    for (var seed = 0; seed < 150; seed++) {
      expect(
        Merchant.stock(catalog, seed, poolVersion: 2),
        Merchant.stock(prior, seed),
      );
      final old = RunState.fromJson(
        rules.start(seed).toJson()..['cardPoolVersion'] = 2,
      );
      final fight = enterRoom(rules, old, old.rooms.first.id);
      final actual = rules.finishCombat(fight, Outcome.victory, 40);
      final expected = RunRules(prior).finishCombat(fight, Outcome.victory, 40);
      expect(actual.rewards, expected.rewards);
      expect(actual.rngState, expected.rngState);
    }
    final oldShop = RunState.fromJson(
      reachRoom(rules, RoomType.merchant).toJson()..['cardPoolVersion'] = 2,
    )..gold = 200;
    final bought = rules.buyCard(
      oldShop,
      Merchant.stock(prior, oldShop.battleSeed).first,
    );
    final store = MemorySaveStore()
      ..contents = jsonEncode({
        'version': 1,
        'contentVersion': 14,
        'run': bought.toJson(),
      });
    final loaded = (await RunRepository(store, catalog).load())!;
    expect(loaded.purchases, bought.purchases);
    expect(loaded.cardPoolVersion, 2);
    final victory = RunState.fromJson(
      won(rules).toJson()..['cardPoolVersion'] = 2,
    );
    expect(rules.descend(victory).cardPoolVersion, 2);
  });
}
