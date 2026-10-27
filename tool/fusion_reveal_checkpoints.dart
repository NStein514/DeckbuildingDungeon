// Valid saved rooms for isolated browser verification; never touches user saves.
import 'dart:convert';
import 'dart:io';
import 'package:deckbound/game/economy/economy.dart';
import 'package:deckbound/game/dungeon/dungeon.dart';
import 'package:deckbound/game/fusion/fusion.dart';
import 'package:deckbound/game/models/models.dart';
import 'package:deckbound/game/progression/run_rules.dart';
import 'package:deckbound/core/persistence/run_repository.dart';
import 'package:deckbound/core/persistence/save_store.dart';
import '../test/test_catalog.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) throw ArgumentError('Supply output JSON path');
  final catalog = loadCatalog(),
      rules = RunRules(loadCatalog()),
      store = MemorySaveStore();
  final repo = RunRepository(store, catalog), out = <String, dynamic>{};
  for (final type in [
    RoomType.merchant,
    RoomType.treasure,
    RoomType.shrine,
    RoomType.rest,
    RoomType.event,
  ]) {
    for (var seed = 0; seed < 1000; seed++) {
      var run = beforeType(rules, type, seed: seed);
      run = rules.enter(run, run.rooms.firstWhere((r) => r.type == type).id)
        ..gold = 200;
      final key = type == RoomType.event
          ? JourneyEvent.fromSeed(
              run.battleSeed,
              mapVersion: run.mapVersion,
            ).name
          : type.name;
      if (out.containsKey(key)) continue;
      await repo.save(run);
      out[key] = jsonDecode(store.contents!);
      if (type != RoomType.event ||
          JourneyEvent.values.every((e) => out.containsKey(e.name))) {
        break;
      }
    }
  }
  for (final recipe in fusionRecipes.where(
    (r) => catalog.cards[r.result]!.tags.contains('fusion'),
  )) {
    store.contents = jsonEncode(out['shrine']);
    final run = rules.continueRoom((await repo.load())!);
    run.deck[0] = CardInstance('starter-0', recipe.first);
    run.deck[1] = CardInstance('starter-1', recipe.second);
    await repo.save(run);
    out['fusion_${recipe.result}'] = jsonDecode(store.contents!);
  }
  final combat = enterRoom(rules, rules.start(514), 'room-0-0');
  await repo.save(combat);
  out['combat'] = jsonDecode(store.contents!);
  File(args.single).writeAsStringSync(jsonEncode(out));
}
