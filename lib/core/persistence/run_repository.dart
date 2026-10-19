import 'dart:convert';
import '../random/seeded_random.dart';
import '../../game/data/game_catalog.dart';
import '../../game/dungeon/dungeon.dart';
import '../../game/progression/run_state.dart';
import '../../game/economy/economy.dart';
import 'save_store.dart';

class RunRepository {
  RunRepository(this.store, this.catalog);
  final SaveStore store;
  final GameCatalog catalog;
  Future<RunState?> load() async {
    final text = await store.read();
    if (text == null) return null;
    try {
      final j = jsonDecode(text) as Map<String, dynamic>;
      if (j['version'] != 1 || ![1, 2, 3, 4, 5].contains(j['contentVersion'])) {
        throw const FormatException(
          'Unsupported save version; save preserved.',
        );
      }
      final run = RunState.fromJson(j['run'] as Map<String, dynamic>);
      validate(run);
      return run;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid save; original data preserved.');
    }
  }

  Future<void> save(RunState r) async {
    validate(r);
    await store.write(
      jsonEncode({'version': 1, 'contentVersion': 5, 'run': r.toJson()}),
    );
  }

  void validate(RunState r) {
    void check(bool condition) {
      if (!condition) throw const FormatException('Invalid run checkpoint.');
    }

    check(
      r.seed >= 0 &&
          r.seed <= 0xffffffff &&
          r.rngState >= 0 &&
          r.rngState <= 0xffffffff &&
          r.battleSeed >= 0 &&
          r.battleSeed <= 0xffffffff,
    );
    check(
      r.health >= 0 &&
          r.health <= catalog.rules.maxHealth &&
          r.gold >= 0 &&
          r.deck.isNotEmpty &&
          r.deck.length <= 1000 &&
          r.nextCardId >= 12,
    );
    check(
      r.deck.map((c) => c.id).toSet().length == r.deck.length &&
          r.relics.toSet().length == r.relics.length,
    );
    for (final c in r.deck) {
      check(
        catalog.cards.containsKey(c.definitionId) &&
            c.upgrade >= 0 &&
            c.upgrade <= 1,
      );
      final parts = c.id.split('-');
      final id = parts.length == 2 ? int.tryParse(parts[1]) : null;
      check(
        id != null &&
            id >= 0 &&
            (parts[0] == 'starter'
                ? id < 12
                : parts[0] == 'card' && id >= 12 && id < r.nextCardId),
      );
    }
    check([1, 2, 3, 4, 5].contains(r.mapVersion));
    check(r.descent >= 1 && r.mapSeed >= 0 && r.mapSeed <= 0xffffffff);
    check(r.descent != 1 || r.mapSeed == r.seed);
    check(r.mapVersion != 1 || r.descent == 1);
    final expected = DungeonGenerator.generate(
      SeededRandom(r.mapSeed),
      version: r.mapVersion,
    );
    check(
      jsonEncode(r.rooms.map((x) => x.toJson()).toList()) ==
          jsonEncode(expected.map((x) => x.toJson()).toList()),
    );
    check(
      r.completed.toSet().length == r.completed.length &&
          r.completed.every((id) => r.rooms.any((x) => x.id == id)),
    );
    for (var i = 0; i < r.completed.length; i++) {
      check(
        i == 0
            ? r.completed[i] == r.rooms.first.id
            : r.rooms
                  .firstWhere((x) => x.id == r.completed[i - 1])
                  .next
                  .contains(r.completed[i]),
      );
    }
    check(r.currentRoom == null || r.rooms.any((x) => x.id == r.currentRoom));
    if (r.currentRoom == null) {
      check(r.phase == RunPhase.map && r.completed.isEmpty);
    } else if (r.phase == RunPhase.map || r.phase == RunPhase.victory) {
      check(r.completed.isNotEmpty && r.completed.last == r.currentRoom);
    } else {
      final reachable = r.completed.isEmpty
          ? [r.rooms.first.id]
          : r.rooms.firstWhere((x) => x.id == r.completed.last).next;
      check(
        reachable.contains(r.currentRoom) &&
            !r.completed.contains(r.currentRoom),
      );
    }
    check(
      r.rewards.every(catalog.cards.containsKey) &&
          r.discovered.every(catalog.cards.containsKey),
    );
    check(
      r.phase == RunPhase.reward
          ? r.rewards.length == 3 && r.rewards.toSet().length == 3
          : r.rewards.isEmpty,
    );
    check((r.phase == RunPhase.defeat) == (r.health == 0));
    if (r.phase != RunPhase.map) check(r.currentRoom != null);
    if (r.phase == RunPhase.combat ||
        r.phase == RunPhase.reward ||
        r.phase == RunPhase.defeat) {
      check(r.room!.enemies.isNotEmpty);
    }
    if (r.phase == RunPhase.reveal) check(r.mapVersion >= 4);
    if (r.phase == RunPhase.merchant) {
      check(r.room!.type == RoomType.merchant);
      final tokens = {
        'heal',
        'remove',
        ...Merchant.stock(catalog, r.battleSeed).map((id) => 'card:$id'),
      };
      check(
        r.purchases.toSet().length == r.purchases.length &&
            r.purchases.every(tokens.contains),
      );
    } else {
      check(r.purchases.isEmpty);
    }
    if (r.phase == RunPhase.event) check(r.room!.type == RoomType.event);
    if (r.phase == RunPhase.shrine) check(r.room!.type == RoomType.shrine);
    if (r.phase == RunPhase.rest) check(r.room!.type == RoomType.rest);
    if (r.phase == RunPhase.treasure) check(r.room!.type == RoomType.treasure);
    if (r.phase == RunPhase.victory) check(r.room!.type == RoomType.boss);
    if (r.phase == RunPhase.map) check(r.room?.type != RoomType.boss);
  }
}
