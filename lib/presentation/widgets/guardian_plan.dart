import 'package:flutter/material.dart';
import '../../game/models/models.dart';

/// Uses the same scaled definition as combat, before temporary battle statuses.
class GuardianPlan extends StatelessWidget {
  const GuardianPlan({super.key, required this.enemy});
  final EnemyDefinition enemy;

  String _effect(Effect effect) {
    final target = effect.target == Target.self ? 'itself' : 'you';
    return switch (effect.kind) {
      EffectKind.damage => '${effect.amount} damage to $target',
      EffectKind.block => '${effect.amount} block for $target',
      EffectKind.status => '${effect.amount} ${effect.status!.name} on $target',
      EffectKind.heal => 'heal $target by ${effect.amount}',
      EffectKind.draw => 'draw ${effect.amount}',
      EffectKind.discard => 'discard ${effect.amount}',
    };
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: Text('${enemy.name} · battle plan'),
    childrenPadding: const EdgeInsets.all(12),
    children: [
      const Text(
        'Repeats in this order. Values include descent scaling; battle statuses can change them. Check the current intent each turn.',
      ),
      for (var i = 0; i < enemy.pattern.length; i++)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${i + 1}. ${enemy.pattern[i].name}'),
          subtitle: Text(enemy.pattern[i].effects.map(_effect).join('; ')),
        ),
    ],
  );
}
