import '../../core/random/seeded_random.dart';

enum RoomType { combat, rest, treasure, shrine, merchant, event, boss }

enum EncounterModifier {
  none('Standard', 'Authored enemy stats.'),
  hardy('Hardy', 'Enemies have 25% more health. Victory grants 10 extra gold.'),
  fierce(
    'Fierce',
    'Each enemy damage effect deals 2 extra damage. Victory grants 10 extra gold.',
  );

  const EncounterModifier(this.title, this.description);
  final String title, description;
}

class DungeonRoom {
  DungeonRoom(
    this.id,
    this.depth,
    this.lane,
    this.type,
    List<String> next,
    List<String> enemies, {
    this.modifier = EncounterModifier.none,
  }) : next = List.unmodifiable(next),
       enemies = List.unmodifiable(enemies);
  final String id;
  final int depth, lane;
  final RoomType type;
  final EncounterModifier modifier;
  final List<String> next, enemies;
  Map<String, dynamic> toJson() => {
    'id': id,
    'depth': depth,
    'lane': lane,
    'type': type.name,
    'next': next,
    'enemies': enemies,
    if (modifier != EncounterModifier.none) 'modifier': modifier.name,
  };
  factory DungeonRoom.fromJson(Map<String, dynamic> j) => DungeonRoom(
    j['id'] as String,
    j['depth'] as int,
    j['lane'] as int,
    RoomType.values.byName(j['type'] as String),
    List<String>.from(j['next'] as List),
    List<String>.from(j['enemies'] as List),
    modifier: EncounterModifier.values.byName(
      j['modifier'] as String? ?? 'none',
    ),
  );
}

class DungeonGenerator {
  static List<DungeonRoom> generate(SeededRandom rng, {int version = 5}) {
    if (version < 1 || version > 5) {
      throw ArgumentError("Unknown map version");
    }
    final widths = [
      1,
      2,
      version >= 3 ? 3 : 2,
      2,
      version == 1
          ? 2
          : version == 2
          ? 3
          : 4,
      1,
    ];
    final rooms = <DungeonRoom>[];
    for (var depth = 0; depth < widths.length; depth++) {
      final restLane = rng.nextInt(1000000) < 500000 ? 0 : 1;
      for (var lane = 0; lane < widths[depth]; lane++) {
        final type = version >= 3 && depth == 2 && lane == 2
            ? RoomType.event
            : version >= 3 && depth == 4 && lane == 3
            ? RoomType.merchant
            : depth == 4 && lane == 2
            ? RoomType.shrine
            : depth == 5
            ? RoomType.boss
            : depth == 2 || depth == 4
            ? (lane == restLane ? RoomType.rest : RoomType.treasure)
            : RoomType.combat;
        var enemies = type == RoomType.boss
            ? ['warden']
            : type != RoomType.combat
            ? <String>[]
            : depth == 0
            ? ['rat']
            : depth == 3 && lane == 1
            ? ['rat', 'mage']
            : [rng.nextInt(1000000) < 500000 ? 'skeleton' : 'mage'];
        var modifier = EncounterModifier.none;
        if (version >= 3 && type == RoomType.combat && depth > 0) {
          if (depth == 3 && lane == 1) {
            enemies = rng.nextInt(1000000) < 500000
                ? ['rat', 'mage']
                : ['rat', 'skeleton'];
          } else {
            enemies = [
              const ['rat', 'skeleton', 'mage'][rng.nextInt(1000000) % 3],
            ];
            if (lane == 1 || depth == 3) {
              modifier = rng.nextInt(1000000) < 500000
                  ? EncounterModifier.hardy
                  : EncounterModifier.fierce;
            }
          }
        }
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
            modifier: modifier,
          ),
        );
      }
    }
    if (version >= 4) {
      // Shuffle contents, not identities or edges. Lane positions reveal no
      // room type, while old generator versions retain their exact RNG order.
      for (var depth = 1; depth < 5; depth++) {
        final indices = [
          for (var i = 0; i < rooms.length; i++)
            if (rooms[i].depth == depth) i,
        ];
        final contents = indices.map((i) => rooms[i]).toList();
        rng.shuffle(contents);
        for (var i = 0; i < indices.length; i++) {
          final slot = rooms[indices[i]], content = contents[i];
          rooms[indices[i]] = DungeonRoom(
            slot.id,
            slot.depth,
            slot.lane,
            content.type,
            slot.next,
            content.enemies,
            modifier: content.modifier,
          );
        }
      }
    }
    if (version >= 5) {
      final slot = rooms.last;
      final guardian = const [
        'warden',
        'broodmother',
        'sentinel',
      ][rng.nextInt(1000000) % 3];
      rooms[rooms.length - 1] = DungeonRoom(
        slot.id,
        slot.depth,
        slot.lane,
        slot.type,
        slot.next,
        [guardian],
      );
    }
    return rooms;
  }
}
