import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/game/combat/combat_engine.dart';
import 'package:deckbound/game/models/models.dart';
import 'package:deckbound/game/cards/upgrades.dart';
import 'package:deckbound/game/fusion/fusion.dart';
import 'package:deckbound/game/economy/economy.dart';
import 'package:deckbound/game/progression/run_rules.dart';
import 'package:deckbound/core/persistence/run_repository.dart';
import 'package:deckbound/core/persistence/profile_repository.dart';
import 'package:deckbound/core/persistence/save_store.dart';
import 'package:deckbound/game/profile/player_profile.dart';
import '../test_catalog.dart';
import 'fusion_test.dart' show shrine;

void main() {
  final catalog = loadCatalog(), rules = RunRules(loadCatalog());
  final recipes = fusionRecipes
      .where((r) => catalog.cards[r.result]!.tags.contains('archetype_fusion'))
      .toList();
  CombatEngine battle(String id) => CombatEngine(
    cards: catalog.cards,
    deck: [CardInstance('f', id), const CardInstance('s', 'strike')],
    enemies: const [
      EnemyDefinition('dummy', 'Dummy', 100, [
        EnemyAction('Hit', [Effect(EffectKind.damage, 8)]),
      ]),
    ],
  );
  test(
    'five unique new fusions persist their results and journal discoveries',
    () async {
      expect(recipes, hasLength(5));
      expect(fusionRecipes.map((r) => r.result).toSet(), hasLength(17));
      for (final recipe in recipes) {
        final run = shrine(rules);
        run.deck[0] = CardInstance('starter-0', recipe.first, upgrade: 1);
        run.deck[1] = CardInstance('starter-1', recipe.second);
        final fused = rules.fuse(run, 'starter-1', 'starter-0');
        final repo = RunRepository(MemorySaveStore(), catalog);
        await repo.save(fused);
        expect((await repo.load())!.deck.last.definitionId, recipe.result);
        expect((await repo.load())!.deck.last.upgrade, 0);
        final journal = ProfileRepository(MemorySaveStore(), catalog);
        await journal.save(PlayerProfile().include(fused));
        expect((await journal.load()).cards, contains(recipe.result));
      }
    },
  );
  test('fusion results are absent from all reward and merchant pools', () {
    final ids = recipes.map((r) => r.result).toSet();
    for (var seed = 0; seed < 150; seed++) {
      for (var pool = 1; pool <= 5; pool++) {
        expect(
          Merchant.stock(catalog, seed, poolVersion: pool).any(ids.contains),
          isFalse,
        );
      }
      final run = rules.start(seed);
      final reward = rules.finishCombat(
        enterRoom(rules, run, run.rooms.first.id),
        Outcome.victory,
        40,
      );
      expect(reward.rewards.any(ids.contains), isFalse);
    }
  });
  test('Dawnward attacks, blocks and draws without exhausting', () {
    final e = battle('dawnward');
    expect(e.play('f', targetId: 'enemy-0'), isNull);
    expect(e.state.enemies.single.health, 94);
    expect(e.state.player.block, 5);
    expect(e.state.exhaust, 0);
  });
  test('Storm Prism sets Shock and Chill once and protects the next turn', () {
    final e = battle('storm_prism');
    expect(e.play('f', targetId: 'enemy-0'), isNull);
    expect(e.state.enemies.single.stacks(Status.shock), 4);
    expect(e.state.exhaust, 1);
    e.endTurn();
    expect(e.state.player.health, 46);
    expect(e.state.enemies.single.stacks(Status.chill), 0);
  });
  test('Widow promise is retained, hits and poisons', () {
    final e = battle('widows_promise');
    e.endTurn();
    expect(e.state.hand.any((c) => c.id == 'f'), isTrue);
    expect(e.play('f', targetId: 'enemy-0'), isNull);
    expect(e.state.enemies.single.health, 94);
    e.endTurn();
    expect(e.state.enemies.single.health, 89);
  });
  test('Ancient Bastion protects and boosts later attacks but exhausts', () {
    final e = battle('ancient_bastion');
    expect(e.play('f'), isNull);
    expect(e.state.player.block, 12);
    expect(e.state.player.stacks(Status.strength), 2);
    expect(e.state.exhaust, 1);
    expect(e.play('s', targetId: 'enemy-0'), isNull);
    expect(e.state.enemies.single.health, 92);
  });
  test('Solar Script hits and burns once per encounter', () {
    final e = battle('solar_script');
    expect(e.play('f', targetId: 'enemy-0'), isNull);
    expect(e.state.enemies.single.health, 91);
    expect(e.state.exhaust, 1);
    e.endTurn();
    expect(e.state.enemies.single.health, 86);
  });
  test('new fusion upgrades preserve keywords and improve all effects', () {
    final expected = {
      'dawnward': [8, 7, 2],
      'storm_prism': [5, 3, 2],
      'widows_promise': [8, 6],
      'ancient_bastion': [14, 3],
      'solar_script': [11, 6, 2],
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
  });
}
