import 'dart:math' as math;
import '../fusion/fusion.dart';
import '../economy/economy.dart';
import '../../core/random/seeded_random.dart';
import '../data/game_catalog.dart';
import '../dungeon/dungeon.dart';
import '../models/models.dart';
import '../relics/relic.dart';
import 'run_state.dart';
import 'starting_build.dart';

class RunRules {
  RunRules(this.catalog);
  final GameCatalog catalog;
  RunState start(int seed, {StartingBuild build = StartingBuild.wanderer}) {
    if (seed < 0 || seed > 0xffffffff) throw ArgumentError('Invalid seed');
    final rng = SeededRandom(seed);
    final rooms = DungeonGenerator.generate(rng);
    return RunState(
      seed: seed,
      startingBuild: build,
      rngState: rng.state,
      rooms: rooms,
      deck: build.deck(catalog),
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
      startingBuild: r.startingBuild,
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
    r.phase = r.mapVersion >= 4 ? RunPhase.reveal : _roomPhase(r.room!.type);
    return r;
  }

  RunState continueRoom(RunState old) {
    if (old.phase != RunPhase.reveal) {
      throw StateError('No revealed path awaits entry.');
    }
    final r = old.copy()..phase = _roomPhase(old.room!.type);
    return r;
  }

  RunPhase _roomPhase(RoomType type) => switch (type) {
    RoomType.combat || RoomType.boss => RunPhase.combat,
    RoomType.rest => RunPhase.rest,
    RoomType.merchant => RunPhase.merchant,
    RoomType.event => RunPhase.event,
    RoomType.shrine => RunPhase.shrine,
    RoomType.treasure => RunPhase.treasure,
  };

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
    r.gold +=
        15 +
        rng.nextInt(11) +
        (r.room!.modifier == EncounterModifier.none ? 0 : 10);
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

  RunState rest(RunState old, {String? upgradeId, String? removeId}) {
    if (old.phase != RunPhase.rest) throw StateError('No active rest site.');
    if (upgradeId != null && removeId != null) {
      throw StateError('Choose one sanctuary action.');
    }
    final r = old.copy();
    if (removeId != null) {
      if (r.deck.length <= Merchant.minimumDeck ||
          !r.deck.any((c) => c.id == removeId)) {
        throw StateError(
          'Choose a card to remove and keep at least five cards.',
        );
      }
      r.deck.removeWhere((c) => c.id == removeId);
    } else if (upgradeId == null) {
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
    final pool = Relic.treasurePool(
      r.mapVersion,
    ).where((x) => !r.relics.contains(x)).toList();
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

  RunState buyCard(RunState old, String id) {
    if (old.phase != RunPhase.merchant ||
        !Merchant.stock(catalog, old.battleSeed).contains(id) ||
        old.deck.length >= 1000) {
      throw StateError('Card unavailable.');
    }
    final r = _purchase(old, 'card:$id', Merchant.price(catalog.cards[id]!));
    r.deck.add(CardInstance('card-${r.nextCardId++}', id));
    if (!r.discovered.contains(id)) r.discovered.add(id);
    return r;
  }

  RunState merchantHeal(RunState old) {
    if (old.health >= catalog.rules.maxHealth) {
      throw StateError('Already at full health.');
    }
    final r = _purchase(old, 'heal', Merchant.healingPrice);
    r.health = math.min(
      catalog.rules.maxHealth,
      r.health + Merchant.healingAmount,
    );
    return r;
  }

  RunState merchantUpgrade(RunState old, String instanceId) {
    final index = old.deck.indexWhere(
      (c) => c.id == instanceId && c.upgrade == 0,
    );
    if (index < 0) throw StateError('Choose an owned, unupgraded card.');
    final r = _purchase(old, 'upgrade', Merchant.upgradePrice);
    final card = r.deck[index];
    r.deck[index] = CardInstance(card.id, card.definitionId, upgrade: 1);
    return r;
  }

  RunState removeCard(RunState old, String instanceId) {
    if (old.deck.length <= Merchant.minimumDeck ||
        !old.deck.any((c) => c.id == instanceId)) {
      throw StateError('Choose an owned card; keep at least five cards.');
    }
    final r = _purchase(old, 'remove', Merchant.removalPrice);
    r.deck.removeWhere((c) => c.id == instanceId);
    return r;
  }

  RunState _purchase(RunState old, String token, int price) {
    if (old.phase != RunPhase.merchant ||
        old.purchases.contains(token) ||
        old.gold < price) {
      throw StateError('Purchase unavailable or not enough gold.');
    }
    final r = old.copy()..gold -= price;
    r.purchases.add(token);
    return r;
  }

  RunState leaveMerchant(RunState old) {
    if (old.phase != RunPhase.merchant) throw StateError('No active merchant.');
    final r = old.copy()..purchases.clear();
    _complete(r);
    return r;
  }

  RunState resolveEvent(RunState old, {required bool accept, String? cardId}) {
    if (old.phase != RunPhase.event) throw StateError('No active event.');
    final r = old.copy();
    if (accept) {
      final event = JourneyEvent.fromSeed(
        old.battleSeed,
        mapVersion: old.mapVersion,
      );
      if (!event.canAccept(r.health, r.gold, catalog.rules.maxHealth, r.deck)) {
        throw StateError('You cannot accept this bargain.');
      }
      if (event.choosesCard) {
        final index = r.deck.indexWhere((c) => c.id == cardId);
        if (index < 0) throw StateError('Choose a card from your deck.');
        final card = r.deck[index];
        if (event == JourneyEvent.emberForge) {
          if (card.upgrade != 0) throw StateError('Choose an unupgraded card.');
          r.deck[index] = CardInstance(card.id, card.definitionId, upgrade: 1);
        } else {
          r.deck.removeAt(index);
        }
      } else if (cardId != null) {
        throw StateError('This event does not accept a card.');
      }
      r.health = math.min(catalog.rules.maxHealth, r.health + event.health);
      r.gold += event.gold;
    }
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
