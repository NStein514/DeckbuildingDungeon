import 'dart:math' as math;
import '../combos/combo.dart';
import '../../core/random/seeded_random.dart';
import '../cards/card_piles.dart';
import '../cards/upgrades.dart';
import '../relics/relic.dart';
import '../models/models.dart';

class CombatSnapshot {
  CombatSnapshot(CombatEngine engine)
    : player = engine._player.copy(),
      enemies = List.unmodifiable(engine._enemies.map((e) => e.copy())),
      hand = List.unmodifiable(engine._piles.hand),
      draw = engine._piles.drawPile.length,
      discard = engine._piles.discard.length,
      exhaust = engine._piles.exhaust.length,
      energy = engine._energy,
      turn = engine._turn,
      pendingDiscard = engine._pendingDiscard,
      outcome = engine._outcome,
      events = List.unmodifiable(engine._events),
      plays = List.unmodifiable(engine._plays);
  final List<CardPlay> plays;
  final Fighter player;
  final List<Fighter> enemies;
  final List<CardInstance> hand;
  final int draw, discard, exhaust, energy, turn, pendingDiscard;
  final Outcome outcome;
  final List<CombatEvent> events;
}

/// Synchronous command processor. Invalid commands never spend resources.
/// No Flutter imports, wall-clock randomness, timers, or animation dependencies.
class CombatEngine {
  CombatEngine({
    required this.cards,
    required List<CardInstance> deck,
    required List<EnemyDefinition> enemies,
    int seed = 1,
    this.rules = const CombatRules(),
    int? initialHealth,
    Set<Relic> relics = const {},
  }) : _relics = Set.unmodifiable(relics),
       _piles = CardPiles(deck, SeededRandom(seed)),
       _definitions = List.unmodifiable(enemies),
       _player = Fighter(
         id: 'player',
         name: 'Wayfarer',
         maxHealth: rules.maxHealth,
         health: initialHealth ?? rules.maxHealth,
       ),
       _enemies = [
         for (var i = 0; i < enemies.length; i++)
           Fighter(
             id: 'enemy-$i',
             name: enemies[i].name,
             maxHealth: enemies[i].health,
           ),
       ] {
    if (enemies.isEmpty ||
        enemies.any((e) => e.health <= 0 || e.pattern.isEmpty)) {
      throw ArgumentError('A battle needs living enemies with action patterns');
    }
    if (rules.maxHealth <= 0 ||
        rules.energy < 0 ||
        rules.draw < 0 ||
        rules.handLimit <= 0 ||
        _player.health <= 0 ||
        _player.health > rules.maxHealth) {
      throw ArgumentError('Invalid combat resources');
    }
    if (deck.any((c) => !cards.containsKey(c.definitionId))) {
      throw ArgumentError('Unknown card definition in deck');
    }
    _beginPlayerTurn();
  }
  final Map<String, CardDefinition> cards;
  final CombatRules rules;
  final Set<Relic> _relics;
  bool _emberUsed = false;
  final CardPiles _piles;
  final List<EnemyDefinition> _definitions;
  final Fighter _player;
  final List<Fighter> _enemies;
  final List<CombatEvent> _events = [];
  final List<CardPlay> _plays = [];
  int _energy = 0, _turn = 0, _pendingDiscard = 0, _sequence = 0;
  Outcome _outcome = Outcome.active;
  CombatSnapshot get state => CombatSnapshot(this);

  EnemyAction intent(String enemyId) {
    final index = _enemies.indexWhere((e) => e.id == enemyId);
    if (index < 0) throw ArgumentError.value(enemyId, 'enemyId');
    final pattern = _definitions[index].pattern;
    return pattern[(_turn - 1) % pattern.length];
  }

  int predictedDamage(String enemyId, int base) {
    final enemy = _enemies.firstWhere((e) => e.id == enemyId);
    return _attackAmount(enemy, _player, base);
  }

  String? play(String cardId, {String? targetId}) {
    if (_outcome != Outcome.active) return 'This battle has ended.';
    if (_pendingDiscard > 0) return 'Choose a card to discard first.';
    final found = _piles.hand.where((c) => c.id == cardId);
    if (found.isEmpty) return 'That card is not in your hand.';
    final instance = found.first;
    final card = resolveCard(cards[instance.definitionId]!, instance);
    if (card.type == CardType.curse) return 'Curses cannot be played.';
    if (_energy < card.cost) return 'Not enough energy.';
    Fighter? target;
    if (card.needsTarget) {
      final targets = _enemies.where((e) => e.id == targetId && e.alive);
      if (targets.isEmpty) return 'Choose a living enemy.';
      target = targets.first;
    }
    _energy -= card.cost;
    // In flight cards cannot be drawn again by their own draw effects.
    _piles.hand.remove(instance);
    _emit(
      EventKind.play,
      'Played ${card.name}.',
      actor: _player.id,
      cardId: card.id,
    );
    for (final effect in card.effects) {
      if (_outcome != Outcome.active) break;
      _resolve(
        effect,
        _player,
        target ?? _player,
        attack: card.type == CardType.attack,
        lightning: card.tags.contains('lightning'),
      );
      _checkOutcome();
    }
    if (!_emberUsed &&
        card.tags.contains('fire') &&
        _relics.contains(Relic.emberHeart)) {
      _emberUsed = true;
      if (_outcome == Outcome.active && target != null && target.alive) {
        _emit(EventKind.status, 'Ember Heart awakens.', actor: _player.id);
        _resolve(
          const Effect(EffectKind.status, 2, status: Status.burn),
          _player,
          target,
        );
      }
    }
    final play = CardPlay(instance.id, card.id, _turn, target?.id);
    if (_outcome == Outcome.active && target != null && target.alive) {
      for (final combo in comboLibrary) {
        if (!combo.matches(_plays.lastOrNull, play, target)) continue;
        if (combo.consumeBurn > 0) {
          final remaining = target.stacks(Status.burn) - combo.consumeBurn;
          if (remaining == 0) {
            target.statuses.remove(Status.burn);
          } else {
            target.statuses[Status.burn] = remaining;
          }
        }
        final amount = combo.bonus == ComboBonus.blockDamage
            ? _player.block
            : combo.amount;
        _resolve(
          Effect(
            combo.bonus == ComboBonus.poison
                ? EffectKind.status
                : EffectKind.damage,
            amount,
            status: combo.bonus == ComboBonus.poison ? Status.poison : null,
          ),
          _player,
          target,
        );
        _emit(
          EventKind.combo,
          '${combo.name}! ${combo.description}',
          actor: _player.id,
        );
        _checkOutcome();
      }
    }
    _plays.add(play);
    if (!card.keywords.contains(Keyword.temporary)) {
      (card.keywords.contains(Keyword.exhaust)
              ? _piles.exhaust
              : _piles.discard)
          .add(instance);
    }
    _pendingDiscard = math.min(_pendingDiscard, _piles.hand.length);
    return null;
  }

  String? discardCard(String cardId) {
    if (_outcome != Outcome.active || _pendingDiscard == 0) {
      return 'No discard is required.';
    }
    final found = _piles.hand.where((c) => c.id == cardId);
    if (found.isEmpty) return 'Choose a card in your hand.';
    final card = found.first;
    _discard(card);
    _pendingDiscard--;
    return null;
  }

  String? endTurn() {
    if (_outcome != Outcome.active) return 'This battle has ended.';
    if (_pendingDiscard > 0) return 'Choose a card to discard first.';
    for (final card in List<CardInstance>.of(_piles.hand)) {
      if (cards[card.definitionId]!.keywords.contains(Keyword.temporary)) {
        _discard(card);
      }
    }
    _expire(_player);
    for (final enemy in _enemies) {
      if (!enemy.alive || _outcome != Outcome.active) continue;
      _startPhase(enemy);
      _checkOutcome();
      if (!enemy.alive || _outcome != Outcome.active) continue;
      final action = intent(enemy.id);
      _emit(EventKind.turn, '${enemy.name}: ${action.name}.', actor: enemy.id);
      for (final effect in action.effects) {
        if (_outcome != Outcome.active) break;
        _resolve(effect, enemy, _player, attack: true);
        _checkOutcome();
      }
      _expire(enemy);
    }
    if (_outcome == Outcome.active) _beginPlayerTurn();
    return null;
  }

  void _discard(CardInstance card) {
    _piles.hand.remove(card);
    // Exhaust applies on play, not on discard. Temporary cards vanish on either.
    if (!cards[card.definitionId]!.keywords.contains(Keyword.temporary)) {
      _piles.discard.add(card);
    }
    _emit(
      EventKind.discard,
      'Discarded ${cards[card.definitionId]!.name}.',
      actor: _player.id,
    );
  }

  void _beginPlayerTurn() {
    _turn++;
    _plays.clear();
    _startPhase(_player);
    _checkOutcome();
    if (_outcome != Outcome.active) return;
    _energy = rules.energy;
    _emit(EventKind.turn, 'Turn $_turn • your move.');
    _draw(
      rules.draw +
          (_turn == 1 && _relics.contains(Relic.quickdrawCharm) ? 1 : 0),
    );
    if (_turn == 1 && _relics.contains(Relic.ironSigil)) {
      _emit(EventKind.block, 'Iron Sigil awakens.', actor: _player.id);
      _resolve(
        const Effect(EffectKind.block, 4, target: Target.self),
        _player,
        _player,
      );
    }
  }

  void _draw(int amount) {
    for (final card in _piles.draw(amount, rules.handLimit)) {
      _emit(
        EventKind.draw,
        'Drew ${cards[card.definitionId]!.name}.',
        actor: _player.id,
      );
    }
  }

  void _resolve(
    Effect effect,
    Fighter source,
    Fighter other, {
    bool attack = false,
    bool lightning = false,
  }) {
    final target = effect.target == Target.self ? source : other;
    if (!target.alive) return;
    switch (effect.kind) {
      case EffectKind.damage:
        var amount = attack
            ? _attackAmount(source, target, effect.amount)
            : effect.amount;
        if (lightning && target.stacks(Status.shock) > 0) {
          amount += target.stacks(Status.shock);
          target.statuses.remove(Status.shock);
        }
        _damage(target, amount);
      case EffectKind.block:
        target.block += effect.amount;
        _emit(
          EventKind.block,
          '${target.name} gains ${effect.amount} block.',
          actor: target.id,
          amount: effect.amount,
        );
      case EffectKind.heal:
        _heal(target, effect.amount);
      case EffectKind.draw:
        _draw(effect.amount);
      case EffectKind.discard:
        _pendingDiscard += effect.amount;
      case EffectKind.status:
        final status = effect.status!;
        final amount =
            effect.amount +
            (source == _player &&
                    status == Status.poison &&
                    _relics.contains(Relic.venomFang)
                ? 1
                : 0);
        target.statuses[status] = target.stacks(status) + amount;
        _emit(
          EventKind.status,
          '${target.name}: +$amount ${status.name}.',
          actor: target.id,
          amount: amount,
          status: status,
        );
    }
  }

  int _attackAmount(Fighter source, Fighter target, int base) {
    var amount = math.max(
      0,
      base + source.stacks(Status.strength) - source.stacks(Status.chill) * 2,
    );
    if (source.stacks(Status.weak) > 0) amount = amount * 3 ~/ 4;
    if (target.stacks(Status.vulnerable) > 0) amount = amount * 3 ~/ 2;
    return amount;
  }

  void _damage(
    Fighter target,
    int amount, {
    bool bypassBlock = false,
    Status? status,
  }) {
    final absorbed = bypassBlock ? 0 : math.min(target.block, amount);
    target.block -= absorbed;
    final lost = math.min(target.health, amount - absorbed);
    target.health -= lost;
    _emit(
      EventKind.damage,
      '${target.name} takes $lost damage${absorbed > 0 ? ' ($absorbed blocked)' : ''}.',
      actor: target.id,
      amount: lost,
      blocked: absorbed,
      status: status,
    );
    if (!target.alive) {
      _emit(EventKind.defeat, '${target.name} falls.', actor: target.id);
    }
  }

  void _heal(Fighter target, int amount) {
    final restored = math.min(amount, target.maxHealth - target.health);
    target.health += restored;
    _emit(
      EventKind.heal,
      '${target.name} restores $restored health.',
      actor: target.id,
      amount: restored,
    );
  }

  void _startPhase(Fighter actor) {
    actor.block = 0;
    for (final status in [Status.burn, Status.poison]) {
      final stacks = actor.stacks(status);
      if (stacks > 0 && actor.alive) {
        _damage(actor, stacks, bypassBlock: true, status: status);
        _reduce(actor, status);
      }
    }
    if (actor.alive && actor.stacks(Status.regeneration) > 0) {
      _heal(actor, actor.stacks(Status.regeneration));
      _reduce(actor, Status.regeneration);
    }
  }

  void _expire(Fighter actor) {
    for (final status in [Status.weak, Status.vulnerable]) {
      _reduce(actor, status);
    }
    actor.statuses.remove(Status.chill);
  }

  void _reduce(Fighter actor, Status status) {
    final value = actor.stacks(status) - 1;
    if (value <= 0) {
      actor.statuses.remove(status);
    } else {
      actor.statuses[status] = value;
    }
  }

  void _checkOutcome() {
    if (_outcome != Outcome.active) return;
    if (!_player.alive) {
      _outcome = Outcome.defeat;
    } else if (_enemies.every((e) => !e.alive)) {
      _outcome = Outcome.victory;
    }
    if (_outcome != Outcome.active) {
      _pendingDiscard = 0;
      _emit(
        EventKind.result,
        _outcome == Outcome.victory
            ? 'The crypt falls silent. Victory.'
            : 'Your journey ends here.',
      );
    }
  }

  void _emit(
    EventKind kind,
    String message, {
    String? actor,
    int amount = 0,
    String? cardId,
    Status? status,
    int blocked = 0,
  }) {
    _events.add(
      CombatEvent(
        _sequence++,
        kind,
        message,
        actorId: actor,
        amount: amount,
        cardId: cardId,
        status: status,
        blocked: blocked,
      ),
    );
    if (_events.length > 200) _events.removeAt(0);
  }
}
