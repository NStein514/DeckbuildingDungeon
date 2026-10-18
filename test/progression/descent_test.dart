import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/app/run_controller.dart';
import 'package:deckbound/core/persistence/run_repository.dart';
import 'package:deckbound/core/persistence/save_store.dart';
import 'package:deckbound/game/dungeon/difficulty.dart';
import 'package:deckbound/game/models/models.dart';
import 'package:deckbound/game/progression/run_rules.dart';
import 'package:deckbound/game/progression/run_state.dart';
import '../test_catalog.dart';
import '../fusion/fusion_test.dart' show shrine;
import '../persistence/save_test.dart' show FailingStore;

RunState won(RunRules rules) => rules.finishCombat(
  rules.enter(rules.fuse(shrine(rules), 'starter-0', 'starter-8'), 'room-5-0'),
  Outcome.victory,
  23,
);

void main() {
  final catalog = loadCatalog(), rules = RunRules(loadCatalog());
  test(
    'descent preserves build and health, advances floor and generates deterministically',
    () async {
      final victory = won(rules), next = rules.descend(won(rules));
      expect(next.toJson(), rules.descend(victory).toJson());
      expect(victory.phase, RunPhase.victory);
      expect(next.descent, 2);
      expect(next.clearedRooms, 6);
      expect(next.seed, victory.seed);
      expect(next.mapSeed, isNot(victory.mapSeed));
      expect(next.health, 23);
      expect(next.gold, victory.gold);
      expect(next.toJson()['deck'], victory.toJson()['deck']);
      expect(next.discovered, victory.discovered);
      expect(next.relics, victory.relics);
      expect(next.nextCardId, victory.nextCardId);
      expect(next.availableRooms, ['room-0-0']);
      expect(next.completed, isEmpty);
      final repo = RunRepository(MemorySaveStore(), catalog);
      await repo.save(next);
      expect((await repo.load())!.toJson(), next.toJson());
      expect(() => rules.descend(next), throwsStateError);
    },
  );
  test(
    'difficulty scales actual definitions, preserving statuses and catalog',
    () {
      final rat = catalog.enemies['rat']!;
      final scaled = scaleEnemy(rat, 2);
      expect(scaled.health, 27); // ceil(22 * 1.2)
      expect(scaled.pattern.first.effects.first.amount, 6); // ceil(5 * 1.1)
      expect(rat.health, 22);
      final mage = catalog.enemies['mage']!,
          deep = scaleEnemy(catalog.enemies['mage']!, 100);
      for (var i = 0; i < mage.pattern.length; i++) {
        for (var j = 0; j < mage.pattern[i].effects.length; j++) {
          final e = mage.pattern[i].effects[j];
          if (e.kind == EffectKind.status) {
            expect(deep.pattern[i].effects[j].amount, e.amount);
            expect(deep.pattern[i].effects[j].status, e.status);
          }
        }
      }
      expect(() => scaleEnemy(rat, 0), throwsArgumentError);
    },
  );
  test(
    '100 simulated descents keep bounded map state and valid checkpoints',
    () async {
      var r = won(rules);
      final repo = RunRepository(MemorySaveStore(), catalog);
      final seeds = <int>{};
      for (var i = 0; i < 100; i++) {
        r = rules.descend(r);
        seeds.add(r.mapSeed);
        while (r.phase != RunPhase.victory) {
          r = switch (r.phase) {
            RunPhase.map => rules.enter(r, r.availableRooms.first),
            RunPhase.combat => rules.finishCombat(r, Outcome.victory, 23),
            RunPhase.reward => rules.reward(r, null),
            RunPhase.rest => rules.rest(r),
            RunPhase.treasure => rules.treasure(r),
            RunPhase.shrine => rules.skipShrine(r),
            _ => throw StateError('Unexpected phase'),
          };
          await repo.save(r);
          r = (await repo.load())!;
        }
        expect(r.rooms, hasLength(11));
        expect(r.completed, hasLength(6));
      }
      expect(r.descent, 101);
      expect(r.clearedRooms, 606);
      expect(seeds.length, 100);
    },
  );
  test(
    'failed descent save can retry; overlapping clicks cannot skip descents',
    () async {
      final store = FailingStore();
      final repo = RunRepository(store, catalog);
      await repo.save(won(rules));
      final runs = RunController(repo);
      await runs.load();
      final original = store.contents;
      store.fail = true;
      expect(await runs.descend(), false);
      expect(store.contents, original);
      expect(runs.state!.descent, 1);
      store.fail = false;
      store.gate = Completer<void>();
      final pending = runs.descend();
      expect(await runs.descend(), false);
      store.gate!.complete();
      expect(await pending, true);
      expect(runs.state!.descent, 2);
      runs.dispose();
    },
  );
}
