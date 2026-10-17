import '../models/models.dart';

/// Single upgrade, shared by presentation and combat to keep wording accurate.
CardDefinition resolveCard(CardDefinition base, CardInstance instance) {
  if (instance.upgrade == 0) return base;
  final effects = base.effects
      .map(
        (e) => Effect(
          e.kind,
          e.amount +
              switch (e.kind) {
                EffectKind.damage || EffectKind.block || EffectKind.heal => 2,
                EffectKind.status || EffectKind.draw => 1,
                EffectKind.discard => 0,
              },
          target: e.target,
          status: e.status,
        ),
      )
      .toList();
  final text = effects
      .map(
        (e) => switch (e.kind) {
          EffectKind.damage => 'Deal ${e.amount} damage.',
          EffectKind.block => 'Gain ${e.amount} block.',
          EffectKind.heal => 'Restore ${e.amount} health.',
          EffectKind.draw => 'Draw ${e.amount} cards.',
          EffectKind.discard => 'Discard ${e.amount} card.',
          EffectKind.status =>
            '${e.target == Target.self ? 'Gain' : 'Apply'} ${e.amount} ${e.status!.name}.',
        },
      )
      .join(' ');
  return CardDefinition(
    id: base.id,
    name: '${base.name} +',
    description: '$text ${base.keywords.map((k) => '${k.name}.').join(' ')}'
        .trim(),
    type: base.type,
    cost: base.cost,
    effects: List.unmodifiable(effects),
    rarity: base.rarity,
    keywords: base.keywords,
    tags: base.tags,
    art: base.art,
    animation: base.animation,
    audio: base.audio,
  );
}
