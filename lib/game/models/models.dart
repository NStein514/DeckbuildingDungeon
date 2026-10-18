enum CardType { attack, defense, skill, spell, utility, curse }

enum Rarity { common, uncommon, rare, legendary }

enum Target { self, enemy }

enum EffectKind { damage, block, heal, draw, discard, status }

enum Status {
  strength,
  weak,
  vulnerable,
  burn,
  poison,
  chill,
  shock,
  regeneration,
}

enum Keyword { retain, exhaust, temporary }

enum Outcome { active, victory, defeat }

enum EventKind {
  draw,
  play,
  discard,
  damage,
  block,
  heal,
  status,
  defeat,
  turn,
  result,
  combo,
}

class Effect {
  const Effect(
    this.kind,
    this.amount, {
    this.target = Target.enemy,
    this.status,
  });
  final EffectKind kind;
  final int amount;
  final Target target;
  final Status? status;
  factory Effect.fromJson(Map<String, dynamic> j) => Effect(
    EffectKind.values.byName(j['kind'] as String),
    j['amount'] as int,
    target: Target.values.byName(j['target'] as String? ?? 'enemy'),
    status: j['status'] == null
        ? null
        : Status.values.byName(j['status'] as String),
  );
}

class CardDefinition {
  const CardDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.cost,
    required this.effects,
    this.rarity = Rarity.common,
    this.keywords = const [],
    this.tags = const [],
    this.art = '',
    this.animation = 'card_play',
    this.audio = 'card_play',
  });
  final String id, name, description, art, animation, audio;
  final CardType type;
  final int cost;
  final Rarity rarity;
  final List<Effect> effects;
  final List<Keyword> keywords;
  final List<String> tags;
  bool get needsTarget => effects.any((e) => e.target == Target.enemy);
  factory CardDefinition.fromJson(Map<String, dynamic> j) => CardDefinition(
    id: j['id'] as String,
    name: j['name'] as String,
    description: j['description'] as String,
    type: CardType.values.byName(j['type'] as String),
    cost: j['cost'] as int,
    rarity: Rarity.values.byName(j['rarity'] as String? ?? 'common'),
    effects: List.unmodifiable(
      (j['effects'] as List).map(
        (e) => Effect.fromJson(e as Map<String, dynamic>),
      ),
    ),
    keywords: List.unmodifiable(
      (j['keywords'] as List? ?? []).map(
        (k) => Keyword.values.byName(k as String),
      ),
    ),
    tags: List<String>.unmodifiable(j['tags'] as List? ?? []),
    art: j['art'] as String? ?? '',
  );
}

class CardInstance {
  const CardInstance(this.id, this.definitionId, {this.upgrade = 0});
  final String id, definitionId;
  final int upgrade;
}

class EnemyDefinition {
  const EnemyDefinition(
    this.id,
    this.name,
    this.health,
    this.pattern, {
    this.boss = false,
  });
  final String id, name;
  final int health;
  final List<EnemyAction> pattern;
  final bool boss;
  factory EnemyDefinition.fromJson(Map<String, dynamic> j) => EnemyDefinition(
    j['id'] as String,
    j['name'] as String,
    j['health'] as int,
    List.unmodifiable(
      (j['pattern'] as List).map(
        (a) => EnemyAction(
          a['name'] as String,
          List<Effect>.unmodifiable(
            (a['effects'] as List).map(
              (e) => Effect.fromJson(e as Map<String, dynamic>),
            ),
          ),
        ),
      ),
    ),
    boss: j['boss'] as bool? ?? false,
  );
}

class EnemyAction {
  const EnemyAction(this.name, this.effects);
  final String name;
  final List<Effect> effects;
}

/// Mutable only inside the combat engine. Presentation receives snapshots.
class Fighter {
  Fighter({
    required this.id,
    required this.name,
    required this.maxHealth,
    int? health,
    this.block = 0,
    Map<Status, int>? statuses,
  }) : health = health ?? maxHealth,
       statuses = Map.of(statuses ?? {});
  final String id, name;
  final int maxHealth;
  int health, block;
  final Map<Status, int> statuses;
  bool get alive => health > 0;
  int stacks(Status status) => statuses[status] ?? 0;
  Fighter copy() => Fighter(
    id: id,
    name: name,
    maxHealth: maxHealth,
    health: health,
    block: block,
    statuses: statuses,
  );
}

class CombatEvent {
  const CombatEvent(
    this.sequence,
    this.kind,
    this.message, {
    this.actorId,
    this.amount = 0,
  });
  final int sequence;
  final EventKind kind;
  final String message;
  final String? actorId;
  final int amount;
}

class CombatRules {
  const CombatRules({
    this.maxHealth = 50,
    this.energy = 3,
    this.draw = 5,
    this.handLimit = 10,
  });
  final int maxHealth, energy, draw, handLimit;
}
