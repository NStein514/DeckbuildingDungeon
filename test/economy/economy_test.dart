import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/app/run_controller.dart';
import 'package:deckbound/core/persistence/run_repository.dart';
import 'package:deckbound/core/persistence/save_store.dart';
import 'package:deckbound/core/random/seeded_random.dart';
import 'package:deckbound/game/dungeon/difficulty.dart';
import 'package:deckbound/game/dungeon/dungeon.dart';
import 'package:deckbound/game/economy/economy.dart';
import 'package:deckbound/game/models/models.dart';
import 'package:deckbound/game/progression/run_rules.dart';
import 'package:deckbound/game/progression/run_state.dart';
import '../test_catalog.dart';
import '../persistence/save_test.dart' show FailingStore;

RunState reachRoom(RunRules rules, RoomType type, {int seed = 514}) {
  var r = rules.start(seed);
  final target = r.rooms.firstWhere(
    (room) =>
        room.type == type &&
        (type != RoomType.combat ||
            (room.depth == 1 && room.modifier != EncounterModifier.none)),
  );
  for (var depth = 0; depth < target.depth; depth++) {
    final room = r.rooms.firstWhere(
      (x) => x.depth == depth && (depth != 2 || x.type == RoomType.rest),
    );
    r = enterRoom(rules, r, room.id);
    r = r.phase == RunPhase.rest
        ? rules.rest(r)
        : rules.reward(rules.finishCombat(r, Outcome.victory, 30), null);
  }
  return enterRoom(rules, r, target.id);
}

void main() {
  final catalog = loadCatalog(), rules = RunRules(loadCatalog());
  RunState shop() => reachRoom(rules, RoomType.merchant)..gold = 300;
  test(
    'three stable distinct non-fusion offers across reload; purchase once',
    () async {
      final r = shop(), stock = Merchant.stock(catalog, shop().battleSeed);
      expect(stock.toSet(), hasLength(3));
      expect(
        stock.every((id) => !catalog.cards[id]!.tags.contains('fusion')),
        true,
      );
      final id = stock.first, bought = rules.buyCard(r, stock.first);
      expect(bought.gold, 300 - Merchant.price(catalog.cards[id]!));
      expect(bought.deck, hasLength(13));
      expect(bought.deck.last.definitionId, id);
      expect(bought.nextCardId, 13);
      expect(bought.discovered, contains(id));
      expect(r.deck, hasLength(12));
      expect(r.gold, 300);
      final repo = RunRepository(MemorySaveStore(), catalog);
      await repo.save(bought);
      final loaded = (await repo.load())!;
      expect(Merchant.stock(catalog, loaded.battleSeed), stock);
      expect(() => rules.buyCard(loaded, id), throwsStateError);
      expect(loaded.purchases, ['card:$id']);
      final left = rules.leaveMerchant(loaded);
      expect(left.purchases, isEmpty);
      expect(left.phase, RunPhase.map);
      expect(() => rules.buyCard(left, stock.last), throwsStateError);
    },
  );
  test('gold gates purchases; unavailable cards cannot spend money', () {
    final r = shop()..gold = 0;
    final before = r.toJson();
    for (final id in [
      Merchant.stock(catalog, r.battleSeed).first,
      'missing',
      'flaming_strike',
    ]) {
      expect(() => rules.buyCard(r, id), throwsStateError);
    }
    expect(() => rules.merchantHeal(r), throwsStateError);
    expect(() => rules.removeCard(r, r.deck.first.id), throwsStateError);
    expect(r.toJson(), before);
  });
  test('healing is capped, one-use, and unavailable at full health', () {
    final r = shop()..health = 45;
    final healed = rules.merchantHeal(r);
    expect(healed.health, 50);
    expect(healed.gold, 270);
    expect(() => rules.merchantHeal(healed), throwsStateError);
    expect(r.health, 45);
    r.health = 50;
    expect(() => rules.merchantHeal(r), throwsStateError);
  });
  test(
    'removal spends once and removes only the selected duplicate instance',
    () {
      final r = shop();
      final removed = rules.removeCard(r, 'starter-1');
      expect(removed.gold, 260);
      expect(removed.deck, hasLength(11));
      expect(removed.deck.any((c) => c.id == 'starter-0'), true);
      expect(removed.deck.any((c) => c.id == 'starter-1'), false);
      expect(() => rules.removeCard(removed, 'starter-0'), throwsStateError);
      expect(() => rules.removeCard(r, 'missing'), throwsStateError);
      r.deck.removeRange(5, r.deck.length);
      expect(() => rules.removeCard(r, 'starter-0'), throwsStateError);
    },
  );
  test('events preview deterministic costs, are optional and resolve once', () {
    final types = <JourneyEvent>{};
    for (var seed = 0; seed < 50; seed++) {
      final r = reachRoom(rules, RoomType.event, seed: seed)..gold = 100;
      final event = JourneyEvent.fromSeed(r.battleSeed);
      types.add(event);
      final accepted = rules.resolveEvent(r, accept: true);
      expect(accepted.gold, r.gold + event.gold);
      expect(accepted.health, r.health + event.health);
      expect(accepted.phase, RunPhase.map);
      expect(
        () => rules.resolveEvent(accepted, accept: true),
        throwsStateError,
      );
      final skipped = rules.resolveEvent(r, accept: false);
      expect(skipped.gold, r.gold);
      expect(skipped.health, r.health);
      if (event == JourneyEvent.bloodAltar) {
        r.health = 8;
      } else {
        r.gold = 19;
      }
      expect(() => rules.resolveEvent(r, accept: true), throwsStateError);
      expect(rules.resolveEvent(r, accept: false).phase, RunPhase.map);
    }
    expect(types, JourneyEvent.values.toSet());
  });
  test(
    'failed purchases preserve wallet and deck; concurrent clicks charge once',
    () async {
      final store = FailingStore(),
          repo = RunRepository(FailingStore(), catalog);
      await repo.save(shop());
      store.contents = (repo.store as FailingStore).contents;
      final runs = RunController(RunRepository(store, catalog));
      await runs.load();
      final id = Merchant.stock(catalog, runs.state!.battleSeed).first;
      final original = store.contents;
      store.fail = true;
      expect(await runs.buyCard(id), false);
      expect(store.contents, original);
      expect(runs.state!.gold, 300);
      store.fail = false;
      store.gate = Completer<void>();
      final pending = runs.buyCard(id);
      expect(await runs.buyCard(id), false);
      store.gate!.complete();
      expect(await pending, true);
      expect(runs.state!.gold, 300 - Merchant.price(catalog.cards[id]!));
      expect((await runs.repository.load())!.deck, hasLength(13));
      runs.dispose();
    },
  );
  test(
    'failed event save leaves health and gold intact and retries once',
    () async {
      final store = FailingStore(),
          repo = RunRepository(FailingStore(), catalog);
      await repo.save(reachRoom(rules, RoomType.event)..gold = 100);
      store.contents = (repo.store as FailingStore).contents;
      final runs = RunController(RunRepository(store, catalog));
      await runs.load();
      final before = runs.state!.toJson();
      store.fail = true;
      expect(await runs.resolveEvent(true), false);
      expect(runs.state!.toJson(), before);
      store.fail = false;
      expect(await runs.resolveEvent(true), true);
      expect(await runs.resolveEvent(true), false);
      runs.dispose();
    },
  );
  test(
    'legacy map versions load without rerolling; invalid merchant flags reject',
    () async {
      for (final version in [1, 2]) {
        final r = rules.start(514).toJson()..['mapVersion'] = version;
        final rng = SeededRandom(514);
        r['rooms'] = DungeonGenerator.generate(
          rng,
          version: version,
        ).map((x) => x.toJson()).toList();
        r['rngState'] = rng.state;
        r.remove('purchases');
        final store = MemorySaveStore()
          ..contents = jsonEncode({
            'version': 1,
            'contentVersion': version,
            'run': r,
          });
        final repo = RunRepository(store, catalog),
            loaded = (await RunRepository(store, catalog).load())!;
        expect(loaded.rooms.length, version == 1 ? 10 : 11);
        expect(loaded.rooms.any((r) => r.type == RoomType.merchant), false);
        await repo.save(loaded);
        expect((await repo.load())!.toJson(), loaded.toJson());
      }
      final repo = RunRepository(MemorySaveStore(), catalog);
      final bad = shop()..purchases.add('card:flaming_strike');
      await expectLater(repo.save(bad), throwsFormatException);
      await expectLater(
        repo.save(rules.start(1)..purchases.add('heal')),
        throwsFormatException,
      );
      await expectLater(
        repo.save(shop()..purchases.addAll(['heal', 'heal'])),
        throwsFormatException,
      );
    },
  );
  test(
    'new maps have safe alternatives and both modifier types over 200 seeds',
    () {
      final modifiers = <EncounterModifier>{}, encounters = <String>{};
      for (var seed = 0; seed < 200; seed++) {
        final r = rules.start(seed);
        expect(r.rooms, hasLength(13));
        expect(r.rooms.where((r) => r.type == RoomType.merchant), hasLength(1));
        expect(r.rooms.where((r) => r.type == RoomType.event), hasLength(1));
        expect(r.rooms.first.modifier, EncounterModifier.none);
        expect(r.rooms.last.modifier, EncounterModifier.none);
        expect(
          r.rooms.where(
            (r) => r.depth == 1 && r.modifier == EncounterModifier.none,
          ),
          hasLength(1),
        );
        for (final room in r.rooms) {
          modifiers.add(room.modifier);
          encounters.add(room.enemies.join('+'));
          expect(
            room.next.every(
              (id) =>
                  r.rooms.any((r) => r.id == id && r.depth == room.depth + 1),
            ),
            true,
          );
        }
      }
      expect(modifiers, EncounterModifier.values.toSet());
      expect(
        encounters,
        containsAll(['rat+mage', 'rat+skeleton', 'rat', 'mage', 'skeleton']),
      );
    },
  );
  test('modifiers apply after descent scaling and bonuses reward the risk', () {
    final rat = catalog.enemies['rat']!;
    expect(scaleEnemy(rat, 2, modifier: EncounterModifier.hardy).health, 34);
    expect(
      scaleEnemy(
        rat,
        2,
        modifier: EncounterModifier.fierce,
      ).pattern.first.effects.first.amount,
      8,
    );
    expect(rat.health, 22);
    final r = rules.reward(
      rules.finishCombat(
        enterRoom(rules, rules.start(514), 'room-0-0'),
        Outcome.victory,
        30,
      ),
      null,
    );
    final encounter = enterRoom(
      rules,
      r,
      r.rooms
          .firstWhere(
            (room) =>
                room.depth == 1 && room.modifier != EncounterModifier.none,
          )
          .id,
    );
    final result = rules.finishCombat(encounter, Outcome.victory, 30);
    expect(result.gold - encounter.gold, inInclusiveRange(25, 35));
  });
}
