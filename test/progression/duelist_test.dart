import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/core/persistence/run_repository.dart';
import 'package:deckbound/core/persistence/save_store.dart';
import 'package:deckbound/core/random/seeded_random.dart';
import 'package:deckbound/game/combat/combat_engine.dart';
import 'package:deckbound/game/dungeon/dungeon.dart';
import 'package:deckbound/game/dungeon/difficulty.dart';
import 'package:deckbound/game/models/models.dart';
import 'package:deckbound/game/progression/run_rules.dart';
import '../test_catalog.dart';

void main() {
  final catalog = loadCatalog(), rules = RunRules(loadCatalog());
  test(
    'new maps include solo and ambush duelists without changing safe route structure',
    () async {
      var solo = false, ambush = false;
      final repo = RunRepository(MemorySaveStore(), catalog);
      for (var seed = 0; seed < 200; seed++) {
        final r = rules.start(seed);
        expect(r.mapVersion, 8);
        expect(r.rooms, hasLength(13));
        expect(r.rooms.first.enemies, ['rat']);
        expect(r.rooms.last.type, RoomType.boss);
        expect(rules.start(seed).toJson(), r.toJson());
        for (final room in r.rooms.where(
          (r) => r.enemies.contains('duelist'),
        )) {
          expect(room.depth, greaterThan(0));
          expect(room.type, RoomType.combat);
          solo |= room.enemies.length == 1;
          ambush |= room.enemies.length == 2;
        }
        await repo.save(r);
        expect((await repo.load())!.toJson(), r.toJson());
      }
      expect(solo && ambush, true);
    },
  );
  test(
    'version 7 golden map and RNG survive load and migrate only at descent',
    () async {
      final golden =
          jsonDecode(
                File('test/fixtures/map_v7_seed514.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final rng = SeededRandom(514);
      final old = DungeonGenerator.generate(rng, version: 7);
      expect(old.map((r) => r.toJson()).toList(), golden['rooms']);
      expect(rng.state, golden['rngState']);
      final json = rules.start(514).toJson()
        ..['mapVersion'] = 7
        ..['rooms'] = golden['rooms']
        ..['rngState'] = golden['rngState'];
      final store = MemorySaveStore()
        ..contents = jsonEncode({
          'version': 1,
          'contentVersion': 8,
          'run': json,
        });
      final repo = RunRepository(store, catalog);
      var r = (await repo.load())!;
      expect(r.toJson(), json);
      r = advanceToDepth(rules, r, 5);
      r = enterRoom(rules, r, 'room-5-0');
      r = rules.finishCombat(r, Outcome.victory, 30);
      r = rules.descend(r);
      expect(r.mapVersion, 8);
      await repo.save(r);
      expect((await repo.load())!.toJson(), r.toJson());
    },
  );
  test(
    'duelist guards, weakens, lunges and exposes a one-turn vulnerability',
    () {
      final e = CombatEngine(
        cards: catalog.cards,
        deck: [const CardInstance('hit', 'strike')],
        enemies: [catalog.enemies['duelist']!],
      );
      expect(e.intent('enemy-0').name, 'Measured guard');
      e.endTurn();
      expect(e.state.player.health, 50);
      expect(e.state.enemies.single.block, 7);
      expect(e.intent('enemy-0').name, 'Ash feint');
      e.endTurn();
      expect(e.state.player.health, 46);
      expect(e.state.player.stacks(Status.weak), 1);
      expect(e.state.enemies.single.block, 0);
      expect(e.intent('enemy-0').name, 'Reckless lunge');
      e.endTurn();
      expect(e.state.player.health, 35);
      expect(e.state.enemies.single.stacks(Status.vulnerable), 1);
      expect(e.play('hit', targetId: 'enemy-0'), isNull);
      expect(e.state.enemies.single.health, 25);
      e.endTurn();
      expect(e.state.enemies.single.stacks(Status.vulnerable), 0);
      expect(e.state.enemies.single.block, 7);
    },
  );
  test(
    'duelist scaling preserves self-targeted vulnerability and attack pattern',
    () {
      final enemy = scaleEnemy(
        catalog.enemies['duelist']!,
        3,
        modifier: EncounterModifier.fierce,
      );
      expect(enemy.health, greaterThan(34));
      expect(enemy.pattern.last.effects.first.amount, greaterThan(11));
      expect(enemy.pattern.last.effects.last.target, Target.self);
      expect(enemy.pattern.last.effects.last.status, Status.vulnerable);
      expect(enemy.pattern.last.effects.last.amount, 2);
    },
  );
}
