import 'dart:math' as math;
import '../fusion/fusion.dart';
import '../../core/random/seeded_random.dart';
import '../data/game_catalog.dart';
import '../dungeon/dungeon.dart';
import '../models/models.dart';
import '../relics/relic.dart';
import 'run_state.dart';

class RunRules {
  RunRules(this.catalog);
  final GameCatalog catalog;
  RunState start(int seed) {
    if (seed < 0 || seed > 0xffffffff) throw ArgumentError('Invalid seed');
    final rng = SeededRandom(seed);
    final rooms = DungeonGenerator.generate(rng);
    return RunState(
      seed: seed,
      rngState: rng.state,
      rooms: rooms,
      deck: catalog.createDeck(),
      health: catalog.rules.maxHealth,
      relics: [Relic.ironSigil],
    );
  }

  RunState descend(RunState old) {
    if (old.phase != RunPhase.victory) {
      throw StateError('Defeat the boss first.');
    }
    final rng = SeededRandom(old.rngState);
    final mapSeed = rng.nextInt(0x100000000);
    final mapRng = SeededRandom(mapSeed);
    final r = old.copy();
    return RunState(
      seed: r.seed,
      mapSeed: mapSeed,
      descent: r.descent + 1,
      rooms: DungeonGenerator.generate(mapRng),
      rngState: mapRng.state,
      deck: r.deck,
      health: r.health,
      gold: r.gold,
      relics: r.relics,
      discovered: r.discovered,
      nextCardId: r.nextCardId,
    );
  }

  RunState enter(RunState old, String id) {
    if (!old.availableRooms.contains(id)) {
      throw StateError('Choose a connected room.');
    }
    final r = old.copy()..currentRoom = id;
    final rng = SeededRandom(r.rngState);
    r.battleSeed = rng.nextInt(0x100000000);
    r.rngState = rng.state;
    r.phase = switch (r.room!.type) {
      RoomType.combat || RoomType.boss => RunPhase.combat,
      RoomType.rest => RunPhase.rest,
      RoomType.shrine => RunPhase.shrine,
      RoomType.treasure => RunPhase.treasure,
    };
    return r;
  }

  RunState finishCombat(RunState old, Outcome outcome, int health) {
    if (old.phase != RunPhase.combat ||
        outcome == Outcome.active ||
        health < 0 ||
        health > catalog.rules.maxHealth ||
        (outcome == Outcome.victory && health == 0) ||
        (outcome == Outcome.defeat && health != 0)) {
      throw StateError('Invalid battle result.');
    }
    final r = old.copy()..health = health;
    if (outcome == Outcome.defeat) {
      r.phase = RunPhase.defeat;
      return r;
    }
    if (r.room!.type == RoomType.boss) {
      _complete(r);
      r.phase = RunPhase.victory;
      return r;
    }
    final rng = SeededRandom(r.rngState);
    r.gold += 15 + rng.nextInt(11);
    final pool =
        catalog.cards.values
            .where(
              (c) => c.type != CardType.curse && !c.tags.contains('fusion'),
            )
            .map((c) => c.id)
            .toList()
          ..sort();
    rng.shuffle(pool);
    r.rewards.addAll(pool.take(3));
    r.rngState = rng.state;
    r.phase = RunPhase.reward;
    return r;
  }

  RunState reward(RunState old, String? id) {
    if (old.phase != RunPhase.reward ||
        (id != null && !old.rewards.contains(id))) {
      throw StateError('Reward already resolved or unavailable.');
    }
    final r = old.copy();
    if (id != null) {
      r.deck.add(CardInstance('card-${r.nextCardId++}', id));
      if (!r.discovered.contains(id)) r.discovered.add(id);
    }
    r.rewards.clear();
    _complete(r);
    return r;
  }

  RunState rest(RunState old, {String? upgradeId}) {
    if (old.phase != RunPhase.rest) throw StateError('No active rest site.');
    final r = old.copy();
    if (upgradeId == null) {
      r.health = math.min(
        catalog.rules.maxHealth,
        r.health + (catalog.rules.maxHealth * .3).ceil(),
      );
    } else {
      final i = r.deck.indexWhere((c) => c.id == upgradeId && c.upgrade == 0);
      if (i < 0) throw StateError('Choose an unupgraded card.');
      final c = r.deck[i];
      r.deck[i] = CardInstance(c.id, c.definitionId, upgrade: 1);
    }
    _complete(r);
    return r;
  }

  RunState treasure(RunState old) {
    if (old.phase != RunPhase.treasure) {
      throw StateError('Treasure already claimed.');
    }
    final r = old.copy(), rng = SeededRandom(old.rngState);
    final pool = Relic.values.where((x) => !r.relics.contains(x)).toList();
    if (pool.isNotEmpty) r.relics.add(pool[rng.nextInt(pool.length)]);
    r.gold += 25;
    r.rngState = rng.state;
    _complete(r);
    return r;
  }

  RunState fuse(RunState old, String firstId, String secondId) {
    if (old.phase != RunPhase.shrine) throw StateError('No active shrine.');
    final a = old.deck.where((c) => c.id == firstId).firstOrNull;
    final b = old.deck.where((c) => c.id == secondId).firstOrNull;
    if (a == null || b == null) throw StateError('Choose two owned cards.');
    final recipe = fusionRecipes.where((r) => r.matches(a, b)).firstOrNull;
    if (recipe == null) throw StateError('These cards cannot be fused.');
    final r = old.copy();
    r.deck.removeWhere((c) => c.id == firstId || c.id == secondId);
    // Fusion creates a base card; source upgrades are consumed.
    r.deck.add(CardInstance('card-${r.nextCardId++}', recipe.result));
    if (!r.discovered.contains(recipe.result)) r.discovered.add(recipe.result);
    _complete(r);
    return r;
  }

  RunState skipShrine(RunState old) {
    if (old.phase != RunPhase.shrine) throw StateError('No active shrine.');
    final r = old.copy();
    _complete(r);
    return r;
  }

  void _complete(RunState r) {
    if (r.completed.contains(r.currentRoom)) {
      throw StateError('Room already completed.');
    }
    r.completed.add(r.currentRoom!);
    r.phase = RunPhase.map;
  }
}
