import '../../game/models/models.dart';

/// Presentation only. No timers, randomness or game-state mutation.
enum CombatVisual { slash, shield, fire, lightning, poison, healing, arcane }

class CombatCue {
  const CombatCue(this.sequence, this.actorId, this.visual, this.label);
  final int sequence;
  final String actorId, label;
  final CombatVisual visual;
}

CombatVisual _statusVisual(Status? status) => switch (status) {
  Status.burn => CombatVisual.fire,
  Status.poison => CombatVisual.poison,
  Status.shock => CombatVisual.lightning,
  Status.chill => CombatVisual.shield,
  Status.regeneration => CombatVisual.healing,
  _ => CombatVisual.arcane,
};

CombatVisual _cardVisual(CardDefinition? card) {
  if (card == null) return CombatVisual.slash;
  if (card.tags.contains('fire')) return CombatVisual.fire;
  if (card.tags.contains('lightning')) return CombatVisual.lightning;
  if (card.effects.any((e) => e.status == Status.poison)) {
    return CombatVisual.poison;
  }
  return card.type == CardType.spell ? CombatVisual.arcane : CombatVisual.slash;
}

List<CombatCue> combatCues(
  List<CombatEvent> events,
  Map<String, CardDefinition> cards,
) {
  final result = <CombatCue>[];
  CardDefinition? played;
  final draws = events.where((e) => e.kind == EventKind.draw).length;
  for (final e in events) {
    final actor = e.actorId ?? 'player';
    void add(CombatVisual visual, String label) =>
        result.add(CombatCue(e.sequence, actor, visual, label));
    switch (e.kind) {
      case EventKind.play:
        played = cards[e.cardId];
        add(CombatVisual.arcane, played?.name ?? 'Played');
      case EventKind.damage:
        add(
          e.amount == 0 && e.blocked > 0
              ? CombatVisual.shield
              : e.status != null
              ? _statusVisual(e.status)
              : _cardVisual(played),
          e.amount == 0 && e.blocked > 0
              ? '${e.blocked} blocked'
              : '−${e.amount} HP${e.blocked > 0 ? ' · ${e.blocked} blocked' : ''}',
        );
      case EventKind.block:
        if (e.amount > 0) add(CombatVisual.shield, '+${e.amount} block');
      case EventKind.heal:
        add(CombatVisual.healing, '+${e.amount} HP');
      case EventKind.status:
        if (e.status != null) {
          add(_statusVisual(e.status), '+${e.amount} ${e.status!.name}');
        }
      case EventKind.combo:
        add(CombatVisual.lightning, 'COMBO!');
      case EventKind.draw:
        if (e == events.lastWhere((x) => x.kind == EventKind.draw)) {
          add(CombatVisual.arcane, 'Draw $draws');
        }
      case EventKind.discard:
        add(CombatVisual.arcane, 'Discard');
      case EventKind.turn:
        played = null;
      case EventKind.defeat:
      case EventKind.result:
        break;
    }
  }
  // Bound feedback per command; rapid actions replace rather than backlog.
  return result.length <= 24 ? result : result.sublist(result.length - 24);
}
