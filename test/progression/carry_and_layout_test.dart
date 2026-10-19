import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/core/persistence/run_repository.dart';
import 'package:deckbound/core/persistence/save_store.dart';
import 'package:deckbound/game/combat/combat_engine.dart';
import 'package:deckbound/game/dungeon/dungeon.dart';
import 'package:deckbound/game/models/models.dart';
import 'package:deckbound/game/progression/run_rules.dart';
import 'package:deckbound/presentation/widgets/dungeon_card.dart';
import '../test_catalog.dart';

void main() {
  final catalog = loadCatalog(), rules = RunRules(loadCatalog());
  const waiting = EnemyDefinition('dummy', 'Dummy', 1000, [
    EnemyAction('Wait', []),
  ]);
  test(
    'unplayed instances remain across turns, draw to cap, and never duplicate',
    () {
      final e = CombatEngine(
        cards: catalog.cards,
        deck: [for (var i = 0; i < 14; i++) CardInstance('$i', 'strike')],
        enemies: [waiting],
      );
      final first = e.state.hand.map((c) => c.id).toSet();
      e.endTurn();
      expect(e.state.hand.map((c) => c.id), containsAll(first));
      expect(e.state.hand, hasLength(10));
      expect(e.state.discard, 0);
      final full = e.state.hand.map((c) => c.id).toList();
      e.endTurn();
      expect(e.state.hand.map((c) => c.id), full);
      expect(e.state.draw, 4);
      final played = full.first;
      e.play(played, targetId: 'enemy-0');
      expect(e.state.discard, 1);
      e.endTurn();
      expect(e.state.hand.map((c) => c.id), isNot(contains(played)));
      expect(e.state.hand.map((c) => c.id).toSet(), hasLength(10));
      expect(
        e.state.hand.length + e.state.draw + e.state.discard + e.state.exhaust,
        14,
      );
    },
  );
  test(
    'played cards recycle but carried unplayed cards never enter discard',
    () {
      final e = CombatEngine(
        cards: catalog.cards,
        deck: [
          const CardInstance('a', 'strike'),
          const CardInstance('b', 'guard'),
        ],
        enemies: [waiting],
      );
      e.play('a', targetId: 'enemy-0');
      expect(e.state.discard, 1);
      e.endTurn();
      expect(e.state.hand.map((c) => c.id).toSet(), {'a', 'b'});
      expect(e.state.discard, 0);
    },
  );
  test(
    'earned cards and upgrades survive combat exhaustion, save, and a fresh encounter hand',
    () async {
      var r = rules.finishCombat(
        enterRoom(rules, rules.start(514), 'room-0-0'),
        Outcome.victory,
        40,
      );
      r = rules.reward(r, r.rewards.first);
      r.deck[0] = CardInstance(
        r.deck[0].id,
        r.deck[0].definitionId,
        upgrade: 1,
      );
      final before = r.toJson()['deck'];
      final e = CombatEngine(
        cards: catalog.cards,
        deck: r.deck,
        enemies: [waiting],
        initialHealth: 30,
        rules: const CombatRules(draw: 20, handLimit: 20),
      );
      final mend = r.deck.firstWhere((c) => c.definitionId == 'mend');
      e.play(mend.id);
      expect(e.state.exhaust, 1);
      e.endTurn();
      expect(e.state.hand.any((c) => c.id == mend.id), false);
      expect(r.toJson()['deck'], before);
      final repo = RunRepository(MemorySaveStore(), catalog);
      await repo.save(r);
      final restored = (await repo.load())!;
      final next = CombatEngine(
        cards: catalog.cards,
        deck: restored.deck,
        enemies: [waiting],
      );
      expect(next.state.turn, 1);
      expect(next.state.hand, hasLength(5));
      expect(next.state.exhaust, 0);
      expect(next.state.discard, 0);
      expect(next.state.draw + next.state.hand.length, 13);
      final all = CombatEngine(
        cards: catalog.cards,
        deck: restored.deck,
        enemies: [waiting],
        rules: const CombatRules(draw: 20, handLimit: 20),
      );
      expect(all.state.hand.any((c) => c.id == mend.id), true);
      expect(
        all.state.hand.firstWhere((c) => c.id == r.deck.first.id).upgrade,
        1,
      );
      expect(restored.toJson()['deck'], before);
    },
  );
  test(
    'interior bands reach all orders while preserving encounters and safe choices',
    () {
      final orders = <String>{},
          eventDepths = <int>{},
          merchantDepths = <int>{};
      for (var seed = 0; seed < 1000; seed++) {
        final r = rules.start(seed);
        expect(r.toJson(), rules.start(seed).toJson());
        eventDepths.add(
          r.rooms.singleWhere((r) => r.type == RoomType.event).depth,
        );
        merchantDepths.add(
          r.rooms.singleWhere((r) => r.type == RoomType.merchant).depth,
        );
        final order = <String>[];
        for (var depth = 1; depth < 5; depth++) {
          final band = r.rooms.where((r) => r.depth == depth).toList();
          order.add(
            band.any((r) => r.enemies.length > 1)
                ? 'ambush'
                : band.any((r) => r.type == RoomType.event)
                ? 'event'
                : band.any((r) => r.type == RoomType.merchant)
                ? 'merchant'
                : 'combat',
          );
          if (band.any((r) => r.type == RoomType.combat)) {
            expect(band.every((r) => r.type == RoomType.combat), true);
          } else {
            expect(band.any((r) => r.type == RoomType.rest), true);
          }
        }
        orders.add(order.join(','));
        expect(r.rooms.first.enemies, ['rat']);
        expect(r.rooms.last.type, RoomType.boss);
        expect(r.rooms, hasLength(13));
      }
      expect(orders, hasLength(24));
      expect(eventDepths, {1, 2, 3, 4});
      expect(merchantDepths, {1, 2, 3, 4});
    },
  );
  test('legacy version 6 maps keep their layout and saved RNG', () async {
    final old = startVersion(rules, 514, 6),
        repo = RunRepository(MemorySaveStore(), catalog);
    await repo.save(old);
    expect((await repo.load())!.toJson(), old.toJson());
    expect(old.rooms.singleWhere((r) => r.type == RoomType.event).depth, 2);
    expect(old.rooms.singleWhere((r) => r.type == RoomType.merchant).depth, 4);
  });
  test(
    'cosmetic tilt is bounded, varied, and stable without consuming game RNG',
    () {
      final r = rules.start(514), before = r.toJson();
      final angles = [
        for (final room in r.rooms) dungeonCardTilt(r.mapSeed, room.id),
      ];
      expect(angles.toSet().length, greaterThan(5));
      for (var i = 0; i < angles.length; i++) {
        expect(angles[i].abs(), lessThanOrEqualTo(math.pi / 120));
        expect(dungeonCardTilt(r.mapSeed, r.rooms[i].id), angles[i]);
      }
      expect(r.toJson(), before);
    },
  );
}
