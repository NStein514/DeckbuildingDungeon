// Generates valid deterministic checkpoints for an isolated browser smoke profile.
import 'dart:convert';
import 'dart:io';
import 'package:deckbound/game/economy/economy.dart';
import 'package:deckbound/core/persistence/run_repository.dart';
import 'package:deckbound/core/persistence/save_store.dart';
import 'package:deckbound/game/data/game_catalog.dart';
import 'package:deckbound/game/dungeon/dungeon.dart';
import 'package:deckbound/game/models/models.dart';
import 'package:deckbound/game/progression/run_rules.dart';
import 'package:deckbound/game/progression/run_state.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) throw ArgumentError('Supply an output JSON path.');
  final catalog = GameCatalog.decode(
    File('assets/data/cards.json').readAsStringSync(),
    File('assets/data/enemies.json').readAsStringSync(),
    File('assets/data/balance.json').readAsStringSync(),
  );
  final rules = RunRules(catalog), store = MemorySaveStore();
  final repo = RunRepository(store, catalog);
  final checkpoints = <String, dynamic>{};
  var r = rules.start(514);
  for (var depth = 0; depth < 4; depth++) {
    final room = r.rooms.firstWhere(
      (x) => x.depth == depth && (depth != 2 || x.type == RoomType.rest),
    );
    if (depth == 2) {
      await repo.save(
        enterRoom(
          rules,
          r,
          r.rooms.firstWhere((room) => room.type == RoomType.event).id,
        )..gold = 100,
      );
      checkpoints['event'] = jsonDecode(store.contents!);
    }
    r = enterRoom(rules, r, room.id);
    r = r.phase == RunPhase.rest
        ? rules.rest(r)
        : rules.reward(rules.finishCombat(r, Outcome.victory, 40), null);
  }
  await repo.save(
    enterRoom(
      rules,
      r,
      r.rooms.firstWhere((room) => room.type == RoomType.merchant).id,
    )..gold = 200,
  );
  checkpoints['merchant'] = jsonDecode(store.contents!);
  r = enterRoom(
    rules,
    r,
    r.rooms.firstWhere((room) => room.type == RoomType.shrine).id,
  );
  await repo.save(r);
  checkpoints['shrine'] = jsonDecode(store.contents!);
  r = rules.fuse(r, 'starter-0', 'starter-8');
  final reveal = rules.enter(r, 'room-5-0');
  await repo.save(reveal);
  checkpoints['guardian'] = jsonDecode(store.contents!);
  r = rules.finishCombat(rules.continueRoom(reveal), Outcome.victory, 23);
  await repo.save(r);
  checkpoints['victory'] = jsonDecode(store.contents!);
  for (final entry in {
    'event': JourneyEvent.bloodAltar,
    'forge': JourneyEvent.emberForge,
    'well': JourneyEvent.memoryWell,
  }.entries) {
    for (var seed = 0; seed < 1000; seed++) {
      var candidate = rules.start(seed);
      for (var depth = 0; depth < 2; depth++) {
        candidate = rules.reward(
          rules.finishCombat(
            enterRoom(rules, candidate, candidate.availableRooms.first),
            Outcome.victory,
            40,
          ),
          null,
        );
      }
      candidate = enterRoom(
        rules,
        candidate,
        candidate.rooms.firstWhere((room) => room.type == RoomType.event).id,
      )..gold = 100;
      if (JourneyEvent.fromSeed(
            candidate.battleSeed,
            mapVersion: candidate.mapVersion,
          ) ==
          entry.value) {
        await repo.save(candidate);
        checkpoints[entry.key] = jsonDecode(store.contents!);
        break;
      }
    }
    if (!checkpoints.containsKey(entry.key)) {
      throw StateError('Missing event checkpoint');
    }
  }
  File(args.single).writeAsStringSync(jsonEncode(checkpoints));
}

RunState enterRoom(RunRules rules, RunState run, String id) =>
    rules.continueRoom(rules.enter(run, id));
