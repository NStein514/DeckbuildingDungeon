import 'package:deckbound/core/persistence/profile_repository.dart';
import 'package:deckbound/game/profile/player_profile.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/game/combat/combat_engine.dart';
import 'package:deckbound/game/data/game_catalog.dart';
import 'package:deckbound/game/economy/economy.dart';
import 'package:deckbound/game/models/models.dart';
import 'package:deckbound/game/progression/run_rules.dart';
import 'package:deckbound/game/progression/run_state.dart';
import 'package:deckbound/game/progression/starting_build.dart';
import 'package:deckbound/game/cards/upgrades.dart';
import 'package:deckbound/core/persistence/run_repository.dart';
import 'package:deckbound/core/persistence/save_store.dart';
import '../test_catalog.dart';
import '../economy/economy_test.dart' show reachRoom;
import 'package:deckbound/game/dungeon/dungeon.dart';
import '../progression/descent_test.dart' show won;

void main() {
  final catalog = loadCatalog(), rules = RunRules(loadCatalog());
  final expanded = StartingBuild.values.expand((b) => b.supportCards).toSet();
  CombatEngine battle(List<String> ids, {int damage = 0, int health = 50}) =>
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
    final card = e.state.hand.firstWhere((c) => c.definitionId == id);
    expect(e.play(card.id, targetId: 'enemy-0'), isNull);
  }

  test('five builds recommend distinct collectible support sets', () {
    expect(expanded, hasLength(25));
    for (final build in StartingBuild.values) {
      expect(build.deck(catalog), hasLength(12));
      for (final id in build.supportCards) {
        expect(catalog.cards[id]!.tags, contains(build.name));
        expect(catalog.cards[id]!.tags, isNot(contains('fusion')));
      }
    }
  });
  test(
    'Charged Aegis sets up both Forked Current hits, consuming Shock once',
    () {
      final e = battle(['charged_aegis', 'forked_current']);
      play(e, 'charged_aegis');
      expect(e.state.player.block, 5);
      expect(e.state.enemies.single.stacks(Status.shock), 2);
      play(e, 'forked_current');
      expect(e.state.enemies.single.health, 92);
      expect(e.state.enemies.single.stacks(Status.shock), 0);
      expect(
        e.state.events
            .where((e) => e.kind == EventKind.damage)
            .map((e) => e.amount),
        [5, 3],
      );
    },
  );
  test('Venomblade weakens incoming damage, poisons, and exhausts evasion', () {
    final e = battle(['wasting_venom', 'serpent_step'], damage: 8);
    play(e, 'wasting_venom');
    play(e, 'serpent_step');
    expect(e.state.exhaust, 1);
    e.endTurn();
    expect(e.state.player.health, 47);
    expect(e.state.enemies.single.health, 97);
    expect(e.state.enemies.single.stacks(Status.poison), 2);
  });
  test('Grave Oath sustains once and Tomb Seal blocks a weakened hit', () {
    final e = battle(['grave_oath', 'tomb_seal'], damage: 8, health: 30);
    play(e, 'grave_oath');
    play(e, 'tomb_seal');
    expect(e.state.player.block, 13);
    expect(e.state.exhaust, 1);
    e.endTurn();
    expect(e.state.player.health, 31);
    expect(e.state.player.stacks(Status.regeneration), 0);
    expect(e.state.enemies.single.stacks(Status.weak), 1);
  });
  test(
    'Ember Veil and Ash Surge stack Burn and enable a vulnerable attack',
    () {
      final e = battle(['ember_veil', 'ash_surge', 'strike']);
      play(e, 'ember_veil');
      play(e, 'ash_surge');
      play(e, 'strike');
      expect(e.state.player.block, 5);
      expect(e.state.exhaust, 1);
      expect(e.state.enemies.single.stacks(Status.burn), 6);
      expect(e.state.enemies.single.health, 91);
    },
  );
  for (final id in ['trailblazer_cut', 'lantern_watch']) {
    test('$id replaces itself by drawing from the remaining pile', () {
      CombatEngine? e;
      for (var seed = 0; seed < 100; seed++) {
        final candidate = CombatEngine(
          cards: catalog.cards,
          deck: [
            CardInstance('new', id),
            const CardInstance('a', 'guard'),
            const CardInstance('b', 'strike'),
          ],
          enemies: const [
            EnemyDefinition('dummy', 'Dummy', 100, [EnemyAction('Wait', [])]),
          ],
          rules: const CombatRules(draw: 2),
          seed: seed,
        );
        if (candidate.state.hand.any((c) => c.id == 'new')) {
          e = candidate;
          break;
        }
      }
      expect(e, isNotNull);
      play(e!, id);
      expect(e.state.hand, hasLength(2));
      expect(e.state.draw, 0);
      expect(e.state.exhaust, id == 'lantern_watch' ? 1 : 0);
    });
  }
  test('support upgrades keep their cost, targeting and one-use limits', () {
    for (final id in expanded) {
      final base = catalog.cards[id]!;
      final upgraded = resolveCard(base, CardInstance('u', id, upgrade: 1));
      expect(upgraded.cost, base.cost);
      expect(upgraded.keywords, base.keywords);
      expect(upgraded.needsTarget, base.needsTarget);
    }
    expect(
      resolveCard(
        catalog.cards['grave_oath']!,
        const CardInstance('u', 'grave_oath', upgrade: 1),
      ).effects.last.amount,
      2,
    );
  });
  test(
    'legacy rewards and shop inventories retain the original seeded pool',
    () async {
      final originalCards =
          (jsonDecode(File('assets/data/cards.json').readAsStringSync())
                  as List)
              .where((c) => !expanded.contains(c['id']))
              .toList();
      final legacy = GameCatalog.decode(
        jsonEncode(originalCards),
        File('assets/data/enemies.json').readAsStringSync(),
        File('assets/data/balance.json').readAsStringSync(),
      );
      final seenRewards = <String>{}, seenStock = <String>{};
      for (var seed = 0; seed < 150; seed++) {
        expect(
          Merchant.stock(catalog, seed, poolVersion: 1),
          Merchant.stock(legacy, seed),
        );
        seenStock.addAll(Merchant.stock(catalog, seed));
        final fresh = rules.start(seed);
        final old = RunState.fromJson(
          fresh.toJson()..remove('cardPoolVersion'),
        );
        final oldBattle = enterRoom(rules, old, old.rooms.first.id);
        final oldReward = rules.finishCombat(oldBattle, Outcome.victory, 40);
        final expected = RunRules(
          legacy,
        ).finishCombat(oldBattle, Outcome.victory, 40);
        expect(oldReward.rewards, expected.rewards);
        expect(oldReward.rngState, expected.rngState);
        final freshReward = rules.finishCombat(
          enterRoom(rules, fresh, fresh.rooms.first.id),
          Outcome.victory,
          40,
        );
        seenRewards.addAll(freshReward.rewards);
      }
      expect(seenStock, containsAll(expanded));
      expect(seenRewards, containsAll(expanded));
      final shop = RunState.fromJson(
        reachRoom(rules, RoomType.merchant).toJson()..remove('cardPoolVersion'),
      )..gold = 200;
      final stock = Merchant.stock(catalog, shop.battleSeed, poolVersion: 1);
      final bought = rules.buyCard(shop, stock.first);
      final store = MemorySaveStore()
        ..contents = jsonEncode({
          'version': 1,
          'contentVersion': 13,
          'run': bought.toJson()..remove('cardPoolVersion'),
        });
      final repo = RunRepository(store, catalog),
          loaded = (await RunRepository(store, catalog).load())!;
      expect(loaded.cardPoolVersion, 1);
      expect(loaded.purchases, bought.purchases);
      expect(
        Merchant.stock(
          catalog,
          loaded.battleSeed,
          poolVersion: loaded.cardPoolVersion,
        ),
        stock,
      );
      await repo.save(loaded);
      expect(jsonDecode(store.contents!)['contentVersion'], 17);
      expect((await repo.load())!.toJson(), loaded.toJson());
      final invalid = loaded.toJson()..['cardPoolVersion'] = 99;
      expect(
        () => repo.validate(RunState.fromJson(invalid)),
        throwsFormatException,
      );
    },
  );
  test(
    'card pools survive deeper descents and new card saves round-trip',
    () async {
      final victory = won(rules);
      expect(rules.descend(victory).cardPoolVersion, 5);
      final legacy = RunState.fromJson(
        victory.toJson()..remove('cardPoolVersion'),
      );
      expect(rules.descend(legacy).cardPoolVersion, 1);
      final run = rules.start(514);
      run.deck.addAll([
        for (final id in expanded)
          CardInstance('card-${run.nextCardId++}', id, upgrade: 1),
      ]);
      final repo = RunRepository(MemorySaveStore(), catalog);
      await repo.save(run);
      expect((await repo.load())!.toJson(), run.toJson());
      final journal = ProfileRepository(MemorySaveStore(), catalog);
      await journal.save(PlayerProfile(cards: expanded.toList()));
      expect((await journal.load()).cards, containsAll(expanded));
    },
  );
}
