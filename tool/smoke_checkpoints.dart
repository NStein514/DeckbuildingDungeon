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
  var r = beforeType(rules, RoomType.shrine);
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
  r = advanceToDepth(rules, rules.fuse(r, 'starter-0', 'starter-8'), 5);
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
      var candidate = beforeType(rules, RoomType.event, seed: seed);
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

RunState completeRoom(RunRules rules, RunState r, {int health = 40}) =>
    switch (r.phase) {
      RunPhase.combat =>
        r.room!.type == RoomType.boss
            ? rules.finishCombat(r, Outcome.victory, health)
            : rules.reward(
                rules.finishCombat(r, Outcome.victory, health),
                null,
              ),
      RunPhase.rest => rules.rest(r),
      RunPhase.treasure => rules.treasure(r),
      RunPhase.shrine => rules.skipShrine(r),
      RunPhase.merchant => rules.leaveMerchant(r),
      RunPhase.event => rules.resolveEvent(r, accept: false),
      _ => throw StateError('Expected an entered room'),
    };

RunState advanceToDepth(
  RunRules rules,
  RunState r,
  int depth, {
  int health = 40,
}) {
  while (r.completed.length < depth) {
    final choices = r.rooms.where((room) => r.availableRooms.contains(room.id));
    final room =
        choices.where((room) => room.type == RoomType.rest).firstOrNull ??
        choices.first;
    r = completeRoom(rules, enterRoom(rules, r, room.id), health: health);
  }
  return r;
}

RunState beforeType(RunRules rules, RoomType type, {int seed = 514}) {
  final r = rules.start(seed);
  return advanceToDepth(
    rules,
    r,
    r.rooms.firstWhere((room) => room.type == type).depth,
  );
}
