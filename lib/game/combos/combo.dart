import '../models/models.dart';

/// Successful plays only. Discard choices and rejected commands are not plays.
class CardPlay {
  const CardPlay(this.instanceId, this.definitionId, this.turn, this.targetId);
  final String instanceId, definitionId;
  final int turn;
  final String? targetId;
}

enum ComboBonus { fixedDamage, blockDamage, poison }

class ComboDefinition {
  const ComboDefinition(
    this.id,
    this.name,
    this.first,
    this.second,
    this.description,
    this.bonus,
    this.amount, {
    this.sameTarget = false,
    this.consumeBurn = 0,
  });
  final String id, name, first, second, description;
  final ComboBonus bonus;
  final int amount, consumeBurn;
  final bool sameTarget;

  bool matches(CardPlay? previous, CardPlay current, Fighter target) =>
      previous != null &&
      previous.turn == current.turn &&
      previous.definitionId == first &&
      current.definitionId == second &&
      (!sameTarget || previous.targetId == current.targetId) &&
      target.alive &&
      target.stacks(Status.burn) >= consumeBurn;
}

const comboLibrary = [
  ComboDefinition(
    'overload',
    'Overload',
    'firebolt',
    'spark',
    'Firebolt → Spark on the same enemy: consume 2 Burn to deal 6 bonus damage.',
    ComboBonus.fixedDamage,
    6,
    sameTarget: true,
    consumeBurn: 2,
  ),
  ComboDefinition(
    'shield_bash',
    'Shield Bash',
    'guard',
    'heavy_blow',
    'Guard → Heavy Blow: deal bonus damage equal to your current block. Keep the block.',
    ComboBonus.blockDamage,
    0,
  ),
  ComboDefinition(
    'toxic_flurry',
    'Toxic Flurry',
    'poison_edge',
    'quick_slash',
    'Poison Edge → Quick Slash on the same enemy: apply 3 extra Poison.',
    ComboBonus.poison,
    3,
    sameTarget: true,
  ),
];
