import '../../core/random/seeded_random.dart';

enum RoomType { combat, rest, treasure, shrine, boss }

class DungeonRoom {
  DungeonRoom(
    this.id,
    this.depth,
    this.lane,
    this.type,
    List<String> next,
    List<String> enemies,
  ) : next = List.unmodifiable(next),
      enemies = List.unmodifiable(enemies);
  final String id;
  final int depth, lane;
  final RoomType type;
  final List<String> next, enemies;
  Map<String, dynamic> toJson() => {
    'id': id,
    'depth': depth,
    'lane': lane,
    'type': type.name,
    'next': next,
    'enemies': enemies,
  };
  factory DungeonRoom.fromJson(Map<String, dynamic> j) => DungeonRoom(
    j['id'] as String,
    j['depth'] as int,
    j['lane'] as int,
    RoomType.values.byName(j['type'] as String),
    List<String>.from(j['next'] as List),
    List<String>.from(j['enemies'] as List),
  );
}

class DungeonGenerator {
  static List<DungeonRoom> generate(SeededRandom rng, {int version = 2}) {
    if (version != 1 && version != 2) {
      throw ArgumentError("Unknown map version");
    }
    final widths = [1, 2, 2, 2, version == 1 ? 2 : 3, 1];
    final rooms = <DungeonRoom>[];
    for (var depth = 0; depth < widths.length; depth++) {
      final restLane = rng.nextInt(1000000) < 500000 ? 0 : 1;
      for (var lane = 0; lane < widths[depth]; lane++) {
        final type = depth == 4 && lane == 2
            ? RoomType.shrine
            : depth == 5
            ? RoomType.boss
            : depth == 2 || depth == 4
            ? (lane == restLane ? RoomType.rest : RoomType.treasure)
            : RoomType.combat;
        final enemies = type == RoomType.boss
            ? ['warden']
            : type != RoomType.combat
            ? <String>[]
            : depth == 0
            ? ['rat']
            : depth == 3 && lane == 1
            ? ['rat', 'mage']
            : [rng.nextInt(1000000) < 500000 ? 'skeleton' : 'mage'];
        rooms.add(
          DungeonRoom(
            'room-$depth-$lane',
            depth,
            lane,
            type,
            depth == 5
                ? []
                : [
                    for (var i = 0; i < widths[depth + 1]; i++)
                      'room-${depth + 1}-$i',
                  ],
            enemies,
          ),
        );
      }
    }
    return rooms;
  }
}
