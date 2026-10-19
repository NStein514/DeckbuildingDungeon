import 'package:deckbound/core/random/seeded_random.dart';
import 'package:deckbound/game/dungeon/dungeon.dart';
import 'package:deckbound/game/models/models.dart';
import 'package:deckbound/game/progression/run_rules.dart';
import 'package:deckbound/game/progression/run_state.dart';
import 'dart:io';
import 'dart:convert';
import 'package:deckbound/game/data/game_catalog.dart';

GameCatalog loadCatalog({List<String>? deck}) => GameCatalog.decode(
  File('assets/data/cards.json').readAsStringSync(),
  File('assets/data/enemies.json').readAsStringSync(),
  deck == null
      ? File('assets/data/balance.json').readAsStringSync()
      : jsonEncode({
          ...jsonDecode(File('assets/data/balance.json').readAsStringSync())
              as Map<String, dynamic>,
          'startingDeck': deck,
        }),
);

RunState enterRoom(RunRules rules, RunState run, String id) {
  final next = rules.enter(run, id);
  return next.phase == RunPhase.reveal ? rules.continueRoom(next) : next;
}

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

RunState startVersion(RunRules rules, int seed, int version) {
  final rng = SeededRandom(seed);
  final rooms = DungeonGenerator.generate(rng, version: version);
  final json = rules.start(seed).toJson()
    ..['mapVersion'] = version
    ..['rooms'] = rooms.map((r) => r.toJson()).toList()
    ..['rngState'] = rng.state;
  return RunState.fromJson(json);
}
