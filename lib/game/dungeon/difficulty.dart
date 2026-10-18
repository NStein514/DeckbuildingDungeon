import '../models/models.dart';

/// Descent 1 preserves authored balance. Subsequent descents add 20% base HP
/// and 10% base damage/block each, rounded up. Status stacks stay authored.
EnemyDefinition scaleEnemy(EnemyDefinition enemy, int descent) {
  if (descent < 1) throw ArgumentError.value(descent, 'descent');
  int scale(int value, int percent) =>
      (value * (100 + percent * (descent - 1)) + 99) ~/ 100;
  return EnemyDefinition(enemy.id, enemy.name, scale(enemy.health, 20), [
    for (final action in enemy.pattern)
      EnemyAction(action.name, [
        for (final effect in action.effects)
          Effect(
            effect.kind,
            effect.kind == EffectKind.damage || effect.kind == EffectKind.block
                ? scale(effect.amount, 10)
                : effect.amount,
            target: effect.target,
            status: effect.status,
          ),
      ]),
  ], boss: enemy.boss);
}
