import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/game/combat/combat_engine.dart';
import 'package:deckbound/game/data/game_catalog.dart';
import 'package:deckbound/game/economy/economy.dart';
import 'package:deckbound/game/models/models.dart';
import 'package:deckbound/game/cards/upgrades.dart';
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
  CombatEngine battle(List<String> ids, {int damage = 0}) => CombatEngine(
    cards: catalog.cards,
    deck: [for (var i = 0; i < ids.length; i++) CardInstance('$i', ids[i])],
    enemies: [
      EnemyDefinition('dummy', 'Dummy', 100, [
        EnemyAction('Hit', [Effect(EffectKind.damage, damage)]),
      ]),
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

  test('Opening Gambit is free and makes only subsequent hits vulnerable', () {
    final e = battle(['opening_gambit', 'strike']);
    play(e, 'opening_gambit');
    expect(e.state.energy, 10);
    expect(e.state.enemies.single.health, 98);
    expect(e.state.exhaust, 1);
    play(e, 'strike');
    expect(e.state.enemies.single.health, 89);
  });
  test('Thunderhead consumes previous Shock and leaves fresh Shock', () {
    final e = battle(['stormglass_focus', 'thunderhead', 'forked_current']);
    play(e, 'stormglass_focus');
    play(e, 'thunderhead');
    expect(e.state.enemies.single.health, 88);
    expect(e.state.enemies.single.stacks(Status.shock), 2);
    play(e, 'forked_current');
    expect(e.state.enemies.single.health, 80);
    expect(e.state.enemies.single.stacks(Status.shock), 0);
  });
  test(
    'Bitter Bloom poisons through two weakened enemy turns and exhausts',
    () {
      final e = battle(['bitter_bloom'], damage: 8);
      play(e, 'bitter_bloom');
      expect(e.state.energy, 8);
      expect(e.state.exhaust, 1);
      e.endTurn();
      expect(e.state.player.health, 44);
      expect(e.state.enemies.single.health, 96);
      expect(e.state.enemies.single.stacks(Status.weak), 1);
      e.endTurn();
      expect(e.state.player.health, 38);
      expect(e.state.enemies.single.health, 93);
      expect(e.state.enemies.single.stacks(Status.weak), 0);
    },
  );
  test('Ossuary Ward can wait in hand and protects only once after play', () {
    final e = battle(['ossuary_ward'], damage: 8);
    e.endTurn();
    expect(e.state.hand.single.definitionId, 'ossuary_ward');
    play(e, 'ossuary_ward');
    expect(e.state.player.block, 7);
    expect(e.state.exhaust, 1);
    e.endTurn();
    expect(e.state.player.health, 41);
    expect(e.state.hand, isEmpty);
  });
  test('Flashfire is a free single-use hit followed by Burn', () {
    final e = battle(['flashfire']);
    play(e, 'flashfire');
    expect(e.state.energy, 10);
    expect(e.state.exhaust, 1);
    expect(e.state.enemies.single.health, 97);
    e.endTurn();
    expect(e.state.enemies.single.health, 96);
    expect(e.state.hand, isEmpty);
  });
  test(
    'initiative upgrades improve effects without changing energy or limits',
    () {
      final expected = {
        'opening_gambit': [4, 2],
        'thunderhead': [11, 3],
        'bitter_bloom': [5, 3],
        'ossuary_ward': [9],
        'flashfire': [5, 2],
      };
      for (final entry in expected.entries) {
        final base = catalog.cards[entry.key]!;
        final upgraded = resolveCard(
          base,
          CardInstance('u', entry.key, upgrade: 1),
        );
        expect(upgraded.effects.map((e) => e.amount), entry.value);
        expect(upgraded.cost, base.cost);
        expect(upgraded.keywords, base.keywords);
      }
    },
  );
  test('pool 4 preserves previous expansion shops and reward rolls', () async {
    final prior = GameCatalog.decode(
      jsonEncode(
        (jsonDecode(File('assets/data/cards.json').readAsStringSync()) as List)
            .where(
              (c) =>
                  !(c['tags'] as List? ?? []).contains('initiative_expansion'),
            )
            .toList(),
      ),
      File('assets/data/enemies.json').readAsStringSync(),
      File('assets/data/balance.json').readAsStringSync(),
    );
    for (var seed = 0; seed < 150; seed++) {
      expect(
        Merchant.stock(catalog, seed, poolVersion: 4),
        Merchant.stock(prior, seed),
      );
      final old = RunState.fromJson(
        rules.start(seed).toJson()..['cardPoolVersion'] = 4,
      );
      final fight = enterRoom(rules, old, old.rooms.first.id);
      final actual = rules.finishCombat(fight, Outcome.victory, 40);
      final expected = RunRules(prior).finishCombat(fight, Outcome.victory, 40);
      expect(actual.rewards, expected.rewards);
      expect(actual.rngState, expected.rngState);
    }
    final oldShop = RunState.fromJson(
      reachRoom(rules, RoomType.merchant).toJson()..['cardPoolVersion'] = 4,
    )..gold = 200;
    final bought = rules.buyCard(
      oldShop,
      Merchant.stock(prior, oldShop.battleSeed).first,
    );
    final store = MemorySaveStore()
      ..contents = jsonEncode({
        'version': 1,
        'contentVersion': 16,
        'run': bought.toJson(),
      });
    final loaded = (await RunRepository(store, catalog).load())!;
    expect(loaded.purchases, bought.purchases);
    expect(loaded.cardPoolVersion, 4);
    final victory = RunState.fromJson(
      won(rules).toJson()..['cardPoolVersion'] = 4,
    );
    expect(rules.descend(victory).cardPoolVersion, 4);
  });
}
