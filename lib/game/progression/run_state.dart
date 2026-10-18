import '../models/models.dart';
import '../dungeon/dungeon.dart';
import '../relics/relic.dart';

enum RunPhase {
  map,
  combat,
  reward,
  rest,
  treasure,
  shrine,
  merchant,
  event,
  victory,
  defeat,
}

/// Rules mutate detached copies; the controller only publishes saved states.
class RunState {
  RunState({
    required this.seed,
    required this.rngState,
    required this.rooms,
    required this.deck,
    required this.health,
    this.gold = 0,
    this.mapVersion = 3,
    this.descent = 1,
    int? mapSeed,
    this.phase = RunPhase.map,
    this.currentRoom,
    this.battleSeed = 0,
    this.nextCardId = 12,
    List<String>? completed,
    List<String>? rewards,
    List<Relic>? relics,
    List<String>? discovered,
    List<String>? purchases,
  }) : mapSeed = mapSeed ?? seed,
       completed = completed ?? [],
       rewards = rewards ?? [],
       purchases = purchases ?? [],
       relics = relics ?? [],
       discovered =
           discovered ?? deck.map((c) => c.definitionId).toSet().toList();
  final int seed, mapVersion, descent, mapSeed;
  int get clearedRooms => (descent - 1) * 6 + completed.length;
  int rngState, health, gold, battleSeed, nextCardId;
  RunPhase phase;
  String? currentRoom;
  final List<DungeonRoom> rooms;
  final List<CardInstance> deck;
  final List<String> completed, rewards, discovered, purchases;
  final List<Relic> relics;
  DungeonRoom? get room =>
      currentRoom == null ? null : rooms.firstWhere((r) => r.id == currentRoom);
  List<String> get availableRooms =>
      phase != RunPhase.map ? [] : room?.next ?? [rooms.first.id];
  RunState copy() => RunState.fromJson(toJson());
  Map<String, dynamic> toJson() => {
    'seed': seed,
    'mapVersion': mapVersion,
    'mapSeed': mapSeed,
    'descent': descent,
    'rngState': rngState,
    'health': health,
    'gold': gold,
    'phase': phase.name,
    'currentRoom': currentRoom,
    'battleSeed': battleSeed,
    'nextCardId': nextCardId,
    'rooms': rooms.map((r) => r.toJson()).toList(),
    'deck': deck
        .map(
          (c) => {
            'id': c.id,
            'definitionId': c.definitionId,
            'upgrade': c.upgrade,
          },
        )
        .toList(),
    'completed': completed,
    'rewards': rewards,
    'relics': relics.map((r) => r.name).toList(),
    'discovered': discovered,
    'purchases': purchases,
  };
  factory RunState.fromJson(Map<String, dynamic> j) => RunState(
    seed: j['seed'] as int,
    mapVersion: j['mapVersion'] as int? ?? 1,
    mapSeed: j['mapSeed'] as int? ?? j['seed'] as int,
    descent: j['descent'] as int? ?? 1,
    rngState: j['rngState'] as int,
    health: j['health'] as int,
    gold: j['gold'] as int,
    phase: RunPhase.values.byName(j['phase'] as String),
    currentRoom: j['currentRoom'] as String?,
    battleSeed: j['battleSeed'] as int,
    nextCardId: j['nextCardId'] as int,
    rooms: (j['rooms'] as List)
        .map((r) => DungeonRoom.fromJson(r as Map<String, dynamic>))
        .toList(),
    deck: (j['deck'] as List)
        .map(
          (c) => CardInstance(
            c['id'] as String,
            c['definitionId'] as String,
            upgrade: c['upgrade'] as int,
          ),
        )
        .toList(),
    completed: List<String>.from(j['completed'] as List),
    rewards: List<String>.from(j['rewards'] as List),
    relics: (j['relics'] as List)
        .map((r) => Relic.values.byName(r as String))
        .toList(),
    discovered: List<String>.from(j['discovered'] as List),
    purchases: List<String>.from(j['purchases'] as List? ?? []),
  );
}
