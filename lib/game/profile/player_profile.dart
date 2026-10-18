import 'dart:math' as math;
import '../progression/run_state.dart';

/// Monotonic records and discovery sets. Replaying a checkpoint is idempotent.
class PlayerProfile {
  PlayerProfile({
    this.deepestFloor = 0,
    this.bestRooms = 0,
    this.bestBosses = 0,
    Iterable<String> cards = const [],
    Iterable<String> relics = const [],
  }) : cards = Set.unmodifiable(cards),
       relics = Set.unmodifiable(relics);
  final int deepestFloor, bestRooms, bestBosses;
  final Set<String> cards, relics;

  PlayerProfile include(RunState run) => PlayerProfile(
    deepestFloor: math.max(
      deepestFloor,
      (run.descent - 1) * 6 + (run.room == null ? 0 : run.room!.depth + 1),
    ),
    bestRooms: math.max(bestRooms, run.clearedRooms),
    bestBosses: math.max(
      bestBosses,
      run.descent - 1 + (run.phase == RunPhase.victory ? 1 : 0),
    ),
    cards: {...cards, ...run.discovered},
    relics: {...relics, ...run.relics.map((r) => r.name)},
  );

  Map<String, dynamic> toJson() => {
    'deepestFloor': deepestFloor,
    'bestRooms': bestRooms,
    'bestBosses': bestBosses,
    'cards': cards.toList()..sort(),
    'relics': relics.toList()..sort(),
  };
}
