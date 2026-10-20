import '../models/models.dart';
import 'dungeon.dart';

/// Descent 1 preserves authored balance. Subsequent descents add 20% base HP
/// and 10% base damage/block each, rounded up. Status stacks stay authored.
EnemyDefinition scaleEnemy(
  EnemyDefinition enemy,
  int descent, {
  EncounterModifier modifier = EncounterModifier.none,
}) {
  if (descent < 1) throw ArgumentError.value(descent, 'descent');
  int scale(int value, int percent) =>
      (value * (100 + percent * (descent - 1)) + 99) ~/ 100;
  final hp = scale(enemy.health, 20);
  return EnemyDefinition(
    enemy.id,
    enemy.name,
    modifier == EncounterModifier.hardy ? (hp * 125 + 99) ~/ 100 : hp,
    [
      for (final action in enemy.pattern)
        EnemyAction(action.name, [
          for (final effect in action.effects)
            Effect(
              effect.kind,
              effect.kind == EffectKind.damage ||
                      effect.kind == EffectKind.block
                  ? scale(effect.amount, 10) +
                        (effect.kind == EffectKind.damage &&
                                modifier == EncounterModifier.fierce
                            ? 2
                            : 0)
                  : effect.amount,
              target: effect.target,
              status: effect.status,
            ),
          if (modifier == EncounterModifier.rallying)
            const Effect(
              EffectKind.status,
              1,
              target: Target.self,
              status: Status.strength,
            ),
          if (modifier == EncounterModifier.mending)
            const Effect(EffectKind.heal, 3, target: Target.self),
        ]),
    ],
    boss: enemy.boss,
  );
}
