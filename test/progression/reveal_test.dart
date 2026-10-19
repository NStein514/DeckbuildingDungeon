import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/app/run_controller.dart';
import 'package:deckbound/core/persistence/run_repository.dart';
import 'package:deckbound/core/persistence/save_store.dart';
import 'package:deckbound/core/random/seeded_random.dart';
import 'package:deckbound/game/dungeon/dungeon.dart';
import 'package:deckbound/game/models/models.dart';
import 'package:deckbound/game/progression/run_rules.dart';
import 'package:deckbound/game/progression/run_state.dart';
import '../test_catalog.dart';
import '../persistence/save_test.dart' show FailingStore;

void main() {
  final catalog = loadCatalog(), rules = RunRules(loadCatalog());
  test('hidden contents shuffle across lanes deterministically', () {
    final eventLanes = <int>{}, merchantLanes = <int>{};
    for (var seed = 0; seed < 100; seed++) {
      final r = rules.start(seed);
      expect(r.toJson(), rules.start(seed).toJson());
      eventLanes.add(r.rooms.singleWhere((x) => x.type == RoomType.event).lane);
      merchantLanes.add(
        r.rooms.singleWhere((x) => x.type == RoomType.merchant).lane,
      );
    }
    expect(eventLanes, hasLength(3));
    expect(merchantLanes, hasLength(4));
  });
  test(
    'every room reveals before entry, reload preserves seed and blocks scouting',
    () async {
      final repo = RunRepository(MemorySaveStore(), catalog);
      var r = rules.start(514);
      final seen = <RoomType>{};
      for (var depth = 0; depth < 6; depth++) {
        for (final room in r.rooms.where((x) => x.depth == depth)) {
          final reveal = rules.enter(r, room.id);
          seen.add(room.type);
          expect(reveal.phase, RunPhase.reveal);
          expect(() => rules.enter(reveal, room.id), throwsStateError);
          expect(
            () => rules.finishCombat(reveal, Outcome.victory, 40),
            throwsStateError,
          );
          expect(() => rules.treasure(reveal), throwsStateError);
          await repo.save(reveal);
          final loaded = (await repo.load())!;
          expect(loaded.toJson(), reveal.toJson());
          final entered = rules.continueRoom(loaded);
          expect(entered.rngState, reveal.rngState);
          expect(entered.battleSeed, reveal.battleSeed);
          expect(
            entered.phase.name,
            room.type == RoomType.boss ? 'combat' : room.type.name,
          );
          expect(() => rules.continueRoom(entered), throwsStateError);
        }
        r = advanceToDepth(rules, r, depth + 1);
      }
      expect(seen, RoomType.values.toSet());
    },
  );
  test(
    'failed and overlapping reveals or entry writes cannot reroll or skip',
    () async {
      final store = FailingStore();
      final controller = RunController(RunRepository(store, catalog));
      await controller.load();
      await controller.start(514);
      final expected = rules.enter(controller.state!, 'room-0-0');
      store.fail = true;
      expect(await controller.enter('room-0-0'), false);
      expect(controller.state!.currentRoom, isNull);
      store.fail = false;
      store.gate = Completer<void>();
      final pending = controller.enter('room-0-0');
      expect(await controller.enter('room-0-0'), false);
      expect(await controller.continueRoom(), false);
      store.gate!.complete();
      expect(await pending, true);
      store.gate = null;
      expect(controller.state!.toJson(), expected.toJson());
      store.fail = true;
      expect(await controller.continueRoom(), false);
      expect(controller.state!.phase, RunPhase.reveal);
      store.fail = false;
      expect(await controller.continueRoom(), true);
      expect(controller.state!.battleSeed, expected.battleSeed);
      expect(await controller.continueRoom(), false);
      controller.dispose();
    },
  );
  test(
    'content 3 retains face-up direct entry; legacy reveal saves reject',
    () async {
      final json = rules.start(514).toJson()..['mapVersion'] = 3;
      final rng = SeededRandom(514);
      json['rooms'] = DungeonGenerator.generate(
        rng,
        version: 3,
      ).map((x) => x.toJson()).toList();
      json['rngState'] = rng.state;
      final store = MemorySaveStore()
        ..contents = jsonEncode({
          'version': 1,
          'contentVersion': 3,
          'run': json,
        });
      final repo = RunRepository(store, catalog);
      final legacy = (await repo.load())!;
      final entered = rules.enter(legacy, 'room-0-0');
      expect(entered.phase, RunPhase.combat);
      await repo.save(entered);
      entered.phase = RunPhase.reveal;
      await expectLater(repo.save(entered), throwsFormatException);
    },
  );
}
