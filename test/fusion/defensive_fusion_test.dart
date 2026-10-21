import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/app/run_controller.dart';
import 'package:deckbound/core/persistence/profile_repository.dart';
import 'package:deckbound/core/persistence/run_repository.dart';
import 'package:deckbound/core/persistence/save_store.dart';
import 'package:deckbound/game/cards/upgrades.dart';
import 'package:deckbound/game/combat/combat_engine.dart';
import 'package:deckbound/game/models/models.dart';
import 'package:deckbound/game/profile/player_profile.dart';
import 'package:deckbound/game/progression/run_rules.dart';
import 'package:deckbound/game/relics/relic.dart';
import '../test_catalog.dart';
import '../persistence/save_test.dart' show FailingStore;
import 'fusion_test.dart' show shrine;

void main() {
  final catalog = loadCatalog(), rules = RunRules(loadCatalog());
  CombatEngine battle(
    String id, {
    int upgrade = 0,
    int hp = 30,
    Set<Relic> relics = const {},
  }) => CombatEngine(
    cards: catalog.cards,
    deck: [CardInstance('fusion', id, upgrade: upgrade)],
    enemies: const [
      EnemyDefinition('dummy', 'Dummy', 100, [
        EnemyAction('Hit', [Effect(EffectKind.damage, 5)]),
      ]),
    ],
    initialHealth: hp,
    relics: relics,
  );
  test(
    'Venom Ward validates targeting before granting block or spending energy',
    () {
      final e = battle('venom_ward', relics: {Relic.venomFang});
      expect(e.play('fusion'), isNotNull);
      expect(e.play('fusion', targetId: 'missing'), isNotNull);
      expect(e.state.energy, 3);
      expect(e.state.player.block, 0);
      expect(e.play('fusion', targetId: 'enemy-0'), isNull);
      expect(e.state.energy, 2);
      expect(e.state.player.block, 7);
      expect(e.state.enemies.single.health, 100);
      expect(e.state.enemies.single.stacks(Status.poison), 4);
      e.endTurn();
      expect(e.state.enemies.single.health, 96);
      expect(e.state.player.health, 30);
      expect(e.state.hand.single.definitionId, 'venom_ward');
    },
  );
  test(
    'Bloomguard heals once per encounter and remains in the persistent deck',
    () {
      final e = battle('bloomguard');
      expect(e.play('fusion'), isNull);
      expect(e.state.player.block, 7);
      expect(e.state.player.health, 34);
      expect(e.state.exhaust, 1);
      e.endTurn();
      expect(e.state.player.health, 34);
      expect(e.state.hand, isEmpty);
      expect(e.play('fusion'), isNotNull);
      final next = battle('bloomguard', hp: e.state.player.health);
      expect(next.state.hand.single.definitionId, 'bloomguard');
      next.play('fusion');
      expect(next.state.player.health, 38);
    },
  );
  test(
    'Bloomguard stays playable at full health, caps healing and upgrades match previews',
    () {
      for (final hp in [48, 50]) {
        final e = battle('bloomguard', hp: hp);
        expect(e.play('fusion'), isNull);
        expect(e.state.player.health, 50);
        expect(e.state.player.block, 7);
      }
      final bloom = battle('bloomguard', upgrade: 1)..play('fusion');
      expect(bloom.state.player.block, 9);
      expect(bloom.state.player.health, 36);
      expect(bloom.state.exhaust, 1);
      final venom = battle('venom_ward', upgrade: 1)
        ..play('fusion', targetId: 'enemy-0');
      expect(venom.state.player.block, 9);
      expect(venom.state.enemies.single.stacks(Status.poison), 4);
      expect(
        resolveCard(
          catalog.cards['bloomguard']!,
          const CardInstance('x', 'bloomguard', upgrade: 1),
        ).description,
        contains('Restore 6 health'),
      );
    },
  );
  for (final id in ['venom_ward', 'bloomguard']) {
    test(
      '$id saves atomically, retries failure and preserves discovery across journeys',
      () async {
        final run = shrine(rules);
        run.deck[0] = CardInstance(
          'starter-0',
          id == 'venom_ward' ? 'poison_edge' : 'mend',
        );
        final store = FailingStore()
          ..contents = jsonEncode({
            'version': 1,
            'contentVersion': 12,
            'run': run.toJson(),
          });
        final journal = MemorySaveStore()
          ..contents = jsonEncode({
            'version': 1,
            'contentVersion': 2,
            'profile': PlayerProfile().toJson(),
          });
        final c = RunController(
          RunRepository(store, catalog),
          profileRepository: ProfileRepository(journal, catalog),
        );
        await c.load();
        final before = store.contents;
        store.fail = true;
        expect(await c.fuse('starter-3', 'starter-0'), false);
        expect(store.contents, before);
        expect(c.state!.deck, hasLength(12));
        store.fail = false;
        expect(await c.fuse('starter-3', 'starter-0'), true);
        expect(await c.fuse('starter-3', 'starter-0'), false);
        await c.load();
        expect(c.state!.deck.last.definitionId, id);
        expect(c.state!.deck, hasLength(11));
        expect(c.state!.mapVersion, 10);
        expect(jsonDecode(store.contents!)['contentVersion'], 13);
        expect(jsonDecode(journal.contents!)['contentVersion'], 3);
        await c.start(514);
        expect(c.profile!.cards, contains(id));
        c.dispose();
      },
    );
  }
}
