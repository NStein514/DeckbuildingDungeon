import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/app/run_controller.dart';
import 'package:deckbound/core/persistence/run_repository.dart';
import 'package:deckbound/core/persistence/save_store.dart';
import 'package:deckbound/core/random/seeded_random.dart';
import 'package:deckbound/game/dungeon/dungeon.dart';
import 'package:deckbound/game/fusion/fusion.dart';
import 'package:deckbound/game/models/models.dart';
import 'package:deckbound/game/progression/run_rules.dart';
import 'package:deckbound/game/progression/run_state.dart';
import '../test_catalog.dart';
import '../persistence/save_test.dart' show FailingStore;

RunState shrine(RunRules rules) {
  var r = rules.start(514);
  for (var depth = 0; depth < 4; depth++) {
    final room = r.rooms.firstWhere(
      (x) => x.depth == depth && (depth != 2 || x.type == RoomType.rest),
    );
    r = rules.enter(r, room.id);
    r = r.phase == RunPhase.rest
        ? rules.rest(r)
        : rules.reward(rules.finishCombat(r, Outcome.victory, 40), null);
  }
  return rules.enter(r, 'room-4-2');
}

void main() {
  final catalog = loadCatalog(), rules = RunRules(loadCatalog());
  test(
    'each recipe works in both orders, consumes exact instances and upgrades',
    () {
      for (final recipe in fusionRecipes) {
        for (final reverse in [false, true]) {
          final r = shrine(rules);
          r.deck[0] = CardInstance('starter-0', recipe.first, upgrade: 1);
          r.deck[1] = CardInstance('starter-1', recipe.second, upgrade: 1);
          final before = jsonEncode(r.toJson());
          final fused = rules.fuse(
            r,
            reverse ? 'starter-1' : 'starter-0',
            reverse ? 'starter-0' : 'starter-1',
          );
          expect(fused.deck, hasLength(11));
          expect(
            fused.deck.where((c) => c.id == 'starter-0' || c.id == 'starter-1'),
            isEmpty,
          );
          expect(fused.deck.last.definitionId, recipe.result);
          expect(fused.deck.last.upgrade, 0);
          expect(fused.deck.last.id, 'card-12');
          expect(fused.nextCardId, 13);
          expect(fused.discovered, contains(recipe.result));
          expect(fused.phase, RunPhase.map);
          expect(fused.availableRooms, ['room-5-0']);
          expect(jsonEncode(r.toJson()), before);
          expect(
            () => rules.fuse(fused, 'starter-0', 'starter-1'),
            throwsStateError,
          );
        }
      }
    },
  );
  test(
    'same instance, absent source, incompatible pair and wrong phase reject',
    () {
      final r = shrine(rules), before = shrine(rules).toJson();
      for (final pair in [
        ['starter-0', 'starter-0'],
        ['starter-0', 'missing'],
        ['starter-0', 'starter-1'],
      ]) {
        expect(() => rules.fuse(r, pair[0], pair[1]), throwsStateError);
      }
      expect(
        () => rules.fuse(rules.start(1), 'starter-0', 'starter-8'),
        throwsStateError,
      );
      expect(r.toJson(), before);
      final skipped = rules.skipShrine(r);
      expect(skipped.deck.length, r.deck.length);
      expect(() => rules.skipShrine(skipped), throwsStateError);
    },
  );
  test('shrine, fused deck and discovery survive save reload', () async {
    final repo = RunRepository(MemorySaveStore(), catalog);
    await repo.save(shrine(rules));
    expect((await repo.load())!.phase, RunPhase.shrine);
    final fused = rules.fuse((await repo.load())!, 'starter-0', 'starter-8');
    await repo.save(fused);
    expect((await repo.load())!.toJson(), fused.toJson());
  });
  test(
    'failed and concurrent fusion saves never consume or duplicate cards',
    () async {
      final store = FailingStore(),
          repo = RunRepository(FailingStore(), catalog);
      await repo.save(shrine(rules));
      store.contents = (repo.store as FailingStore).contents;
      final c = RunController(RunRepository(store, catalog));
      await c.load();
      final original = store.contents;
      store.fail = true;
      expect(await c.fuse('starter-0', 'starter-8'), false);
      expect(store.contents, original);
      expect(c.state!.deck, hasLength(12));
      store.fail = false;
      store.gate = Completer<void>();
      final pending = c.fuse('starter-0', 'starter-8');
      expect(await c.fuse('starter-0', 'starter-8'), false);
      store.gate!.complete();
      expect(await pending, true);
      expect(c.state!.deck, hasLength(11));
      expect(await c.fuse('starter-0', 'starter-8'), false);
      expect(
        (await c.repository.load())!.discovered,
        contains('flaming_strike'),
      );
      c.dispose();
    },
  );
  test(
    'legacy content version 1 loads without altering its map or RNG',
    () async {
      final r = rules.start(514).toJson()
        ..remove('mapVersion')
        ..remove('mapSeed')
        ..remove('descent');
      final rng = SeededRandom(514);
      r['rooms'] = DungeonGenerator.generate(
        rng,
        version: 1,
      ).map((r) => r.toJson()).toList();
      r['rngState'] = rng.state;
      final store = MemorySaveStore()
        ..contents = jsonEncode({'version': 1, 'contentVersion': 1, 'run': r});
      final repo = RunRepository(store, catalog),
          loaded = (await RunRepository(store, catalog).load())!;
      expect(loaded.mapVersion, 1);
      expect(loaded.rooms, hasLength(10));
      expect(loaded.rooms.any((r) => r.type == RoomType.shrine), false);
      await repo.save(loaded);
      expect((await repo.load())!.toJson(), loaded.toJson());
      final bad = loaded.toJson()..['mapVersion'] = 2;
      await expectLater(
        repo.save(RunState.fromJson(bad)),
        throwsFormatException,
      );
    },
  );
  test(
    'new maps contain a reachable shrine and fusion cards are not rewards',
    () {
      for (var seed = 0; seed < 200; seed++) {
        final r = rules.start(seed);
        expect(r.rooms.where((r) => r.type == RoomType.shrine), hasLength(1));
        expect(
          r.rooms
              .where((r) => r.depth == 3)
              .every((r) => r.next.contains('room-4-2')),
          true,
        );
        final reward = rules.finishCombat(
          rules.enter(r, 'room-0-0'),
          Outcome.victory,
          40,
        );
        expect(
          reward.rewards.any(
            (id) => catalog.cards[id]!.tags.contains('fusion'),
          ),
          false,
        );
      }
    },
  );
}
