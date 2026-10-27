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
      .where((r) => catalog.cards[r.result]!.tags.contains('advanced_fusion'))
      .toList();
  CombatEngine battle(String id, {int health = 30}) => CombatEngine(
    cards: catalog.cards,
    deck: [
      CardInstance('f', id),
      const CardInstance('s', 'strike'),
      const CardInstance('spark', 'spark'),
    ],
    initialHealth: health,
    enemies: const [
      EnemyDefinition('dummy', 'Dummy', 100, [
        EnemyAction('Hit', [Effect(EffectKind.damage, 8)]),
      ]),
    ],
  );
  test(
    'advanced recipes persist result and journal and never enter ordinary pools',
    () async {
      expect(recipes, hasLength(5));
      expect(
        fusionRecipes
            .map((r) => [r.first, r.second]..sort())
            .map((r) => r.join('|'))
            .toSet(),
        hasLength(17),
      );
      for (final recipe in recipes) {
        final run = shrine(rules);
        run.deck[0] = CardInstance('starter-0', recipe.first, upgrade: 1);
        run.deck[1] = CardInstance('starter-1', recipe.second);
        final fused = rules.fuse(run, 'starter-0', 'starter-1');
        final repo = RunRepository(MemorySaveStore(), catalog);
        await repo.save(fused);
        expect((await repo.load())!.deck.last.definitionId, recipe.result);
        expect((await repo.load())!.deck.last.upgrade, 0);
        final journal = ProfileRepository(MemorySaveStore(), catalog);
        await journal.save(PlayerProfile().include(fused));
        expect((await journal.load()).cards, contains(recipe.result));
      }
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
    },
  );
  test(
    'Trailkeeper heals, blocks and replaces itself from the draw pile once',
    () {
      final deck = [
        const CardInstance('f', 'trailkeeper'),
        for (var i = 0; i < 7; i++) CardInstance('s$i', 'strike'),
      ];
      final e = CombatEngine(
        cards: catalog.cards,
        deck: deck,
        initialHealth: 30,
        rules: const CombatRules(draw: 8),
        enemies: const [
          EnemyDefinition('dummy', 'Dummy', 100, [EnemyAction('Wait', [])]),
        ],
      );
      // Discard an attack, then drawing from the empty pile reshuffles that card.
      expect(e.play('s0', targetId: 'enemy-0'), isNull);
      final before = e.state.hand.length;
      expect(e.play('f'), isNull);
      expect(e.state.player.health, 34);
      expect(e.state.player.block, 6);
      expect(e.state.hand.length, before);
      expect(e.state.hand.any((c) => c.id == 's0'), isTrue);
      expect(e.state.exhaust, 1);
      final capped = battle('trailkeeper', health: 49);
      capped.play('f');
      expect(capped.state.player.health, 50);
    },
  );
  test(
    'Tempest Fork consumes old Shock on its first hit then applies new Shock',
    () {
      final e = battle('tempest_fork');
      e.play('spark', targetId: 'enemy-0');
      expect(e.play('f', targetId: 'enemy-0'), isNull);
      expect(e.state.enemies.single.health, 87); // 2 + (5 + 1 Shock) + 5.
      expect(e.state.enemies.single.stacks(Status.shock), 3);
      expect(e.state.exhaust, 0);
    },
  );
  test('Noxious Covenant is retained, poisons and weakens the next attack', () {
    final e = battle('noxious_covenant');
    e.endTurn();
    expect(e.state.hand.any((c) => c.id == 'f'), isTrue);
    final hp = e.state.player.health;
    expect(e.play('f', targetId: 'enemy-0'), isNull);
    expect(e.state.exhaust, 1);
    e.endTurn();
    expect(e.state.player.health, hp - 6);
    expect(e.state.enemies.single.health, 95);
  });
  test(
    'Gravebloom blocks one hit and regeneration heals with declining stacks',
    () {
      final e = battle('gravebloom');
      expect(e.play('f'), isNull);
      expect(e.state.player.block, 8);
      expect(e.state.exhaust, 1);
      e.endTurn();
      expect(e.state.player.health, 34);
      expect(e.state.player.stacks(Status.regeneration), 3);
      e.endTurn();
      expect(e.state.player.health, 29); // +3 regeneration then an unblocked 8.
    },
  );
  test('Cinderwake costs no energy and prepares the following attack', () {
    final e = battle('cinderwake');
    expect(e.play('f', targetId: 'enemy-0'), isNull);
    expect(e.state.energy, 3);
    expect(e.state.enemies.single.health, 96);
    expect(e.state.exhaust, 1);
    expect(e.play('s', targetId: 'enemy-0'), isNull);
    expect(e.state.enemies.single.health, 87);
    e.endTurn();
    expect(e.state.enemies.single.health, 84);
  });
  test(
    'advanced fusion upgrades improve effects without changing costs or keywords',
    () {
      final expected = {
        'trailkeeper': [6, 8, 2],
        'tempest_fork': [7, 7, 4],
        'noxious_covenant': [6, 3],
        'gravebloom': [10, 5],
        'cinderwake': [6, 4, 2],
      };
      for (final entry in expected.entries) {
        final base = catalog.cards[entry.key]!,
            upgraded = resolveCard(
              catalog.cards[entry.key]!,
              CardInstance('u', entry.key, upgrade: 1),
            );
        expect(upgraded.effects.map((e) => e.amount), entry.value);
        expect(upgraded.cost, base.cost);
        expect(upgraded.keywords, base.keywords);
      }
    },
  );
}
