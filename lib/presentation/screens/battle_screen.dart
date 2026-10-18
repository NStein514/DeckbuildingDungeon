import 'dart:async';
import 'package:flutter/material.dart';
import 'collection_screen.dart';
import '../../game/dungeon/difficulty.dart';
import '../../app/settings.dart';
import '../../assets/asset_registry.dart';
import '../../core/services/audio_service.dart';
import '../../game/combat/combat_engine.dart';
import '../../game/data/game_catalog.dart';
import '../../game/models/models.dart';
import '../../game/cards/upgrades.dart';
import '../../game/relics/relic.dart';
import '../widgets/game_card.dart';

class BattleScreen extends StatefulWidget {
  const BattleScreen({
    super.key,
    required this.catalog,
    required this.enemyIds,
    required this.settings,
    required this.seed,
    this.deck,
    this.descent = 1,
    this.discovered = const [],
    this.initialHealth,
    this.relics = const {},
    this.onComplete,
  });
  final GameCatalog catalog;
  final List<String> enemyIds;
  final GameSettings settings;
  final int seed, descent;
  final List<String> discovered;
  final List<CardInstance>? deck;
  final int? initialHealth;
  final Set<Relic> relics;
  final Future<bool> Function(CombatSnapshot)? onComplete;
  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  late final CombatEngine engine;
  final AudioService audio = SilentAudioService();
  String? selected;
  String message = 'Select a card. Enemy-targeted cards need a target.';
  int lastEvent = -1;
  bool savingResult = false, resultSaved = false;
  String? saveError;
  CardDefinition definitionFor(CardInstance card) =>
      resolveCard(widget.catalog.cards[card.definitionId]!, card);
  @override
  void initState() {
    super.initState();
    engine = CombatEngine(
      cards: widget.catalog.cards,
      deck: widget.deck ?? widget.catalog.createDeck(),
      enemies: widget.enemyIds
          .map((id) => scaleEnemy(widget.catalog.enemies[id]!, widget.descent))
          .toList(),
      rules: widget.catalog.rules,
      seed: widget.seed,
      initialHealth: widget.initialHealth,
      relics: widget.relics,
    );
    lastEvent = engine.state.events.last.sequence;
  }

  @override
  void dispose() {
    audio.dispose();
    super.dispose();
  }

  void command(String? Function() action) {
    final error = action();
    final state = engine.state;
    final events = state.events.where((e) => e.sequence > lastEvent).toList();
    for (final event in events) {
      audio.handle(event);
    }
    if (events.isNotEmpty) lastEvent = events.last.sequence;
    setState(() {
      if (error != null) {
        message = error;
        return;
      }
      selected = null;
      final feedback = events
          .where((e) => e.kind != EventKind.draw && e.kind != EventKind.discard)
          .toList();
      message = state.pendingDiscard > 0
          ? 'Preparation: select ${state.pendingDiscard} card to discard.'
          : events.any((e) => e.kind == EventKind.combo)
          ? events.lastWhere((e) => e.kind == EventKind.combo).message
          : feedback.isNotEmpty
          ? feedback.last.message
          : 'Choose your next action.';
    });
    if (state.outcome != Outcome.active && widget.onComplete != null) {
      unawaited(_saveResult());
    }
  }

  Future<void> _saveResult() async {
    if (savingResult || resultSaved) return;
    setState(() {
      savingResult = true;
      saveError = null;
    });
    var saved = false;
    try {
      saved = await widget.onComplete!(engine.state);
    } catch (_) {
      saved = false;
    }
    if (!mounted) return;
    setState(() {
      savingResult = false;
      resultSaved = saved;
      if (!saved) {
        saveError = 'Your result could not be saved. Retry to continue.';
      }
    });
  }

  void select(CardInstance card) {
    if (engine.state.pendingDiscard > 0) {
      command(() => engine.discardCard(card.id));
      return;
    }
    final definition = definitionFor(card);
    setState(() {
      selected = selected == card.id ? null : card.id;
      message = selected == null
          ? 'Select a card.'
          : definition.cost > engine.state.energy
          ? 'Not enough energy for ${definition.name}.'
          : '${definition.name}: ${definition.description} ${definition.needsTarget ? 'Tap an enemy to play.' : 'Tap Play card below.'}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = engine.state;
    if (state.outcome != Outcome.active) return _result(state);
    final selection = state.hand.where((c) => c.id == selected).firstOrNull;
    final definition = selection == null ? null : definitionFor(selection);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'THE ASHEN CRYPT',
          style: TextStyle(fontSize: 14, letterSpacing: 2),
        ),
        actions: [
          IconButton(
            tooltip: 'Combo guide',
            icon: const Icon(Icons.auto_stories_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => CollectionScreen(
                  catalog: widget.catalog,
                  discovered: widget.discovered,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Combat log',
            onPressed: _showLog,
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final largeText =
                    MediaQuery.textScalerOf(context).scale(1) > 1.3;
                final content = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Wrap(
                        spacing: 20,
                        runSpacing: 6,
                        children: [
                          Text(
                            'ENCOUNTER  /  ${widget.enemyIds.length == 1 ? 'DUEL' : 'AMBUSH'}',
                            style: const TextStyle(
                              color: Color(0xffb6a581),
                              fontSize: 11,
                              letterSpacing: 1.8,
                            ),
                          ),
                          Text(
                            'TURN ${state.turn}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: largeText ? 340 : 244,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: state.enemies.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, i) => SizedBox(
                          width: state.enemies.length == 1
                              ? (constraints.maxWidth - 40).clamp(220.0, 480.0)
                              : 245,
                          child: _enemy(state.enemies[i], definition),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: _player(state),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: AnimatedSwitcher(
                        duration: widget.settings.duration,
                        child: Text(
                          message,
                          key: ValueKey(message),
                          style: const TextStyle(
                            color: Color(0xffd7c59d),
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 6,
                        children: [
                          Text(
                            'YOUR HAND · ${state.hand.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.4,
                            ),
                          ),
                          Text(
                            'Draw ${state.draw}  /  Discard ${state.discard}  /  Exhaust ${state.exhaust}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xffaab3bd),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: largeText ? 290 : 224,
                      child: state.hand.isEmpty
                          ? const Center(
                              child: Text(
                                'Your hand is empty. End your turn to draw.',
                              ),
                            )
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              itemCount: state.hand.length,
                              separatorBuilder: (_, index) =>
                                  const SizedBox(width: 9),
                              itemBuilder: (_, i) {
                                final card = state.hand[i];
                                return GameCard(
                                  key: ValueKey(card.id),
                                  card: definitionFor(card),
                                  selected: selected == card.id,
                                  affordable:
                                      definitionFor(card).cost <= state.energy,
                                  reducedMotion: widget.settings.reducedMotion,
                                  onTap: () => select(card),
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      child: Row(
                        children: [
                          if (definition != null && !definition.needsTarget)
                            Expanded(
                              child: FilledButton(
                                onPressed: state.energy >= definition.cost
                                    ? () =>
                                          command(() => engine.play(selected!))
                                    : null,
                                child: const Text('Play card'),
                              ),
                            )
                          else
                            Expanded(
                              child: Text(
                                state.pendingDiscard > 0
                                    ? 'Choose a discard'
                                    : definition != null
                                    ? 'Tap an enemy'
                                    : 'Plan your next move',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: state.pendingDiscard == 0
                                ? () => command(engine.endTurn)
                                : null,
                            child: const Text('End turn'),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                return SingleChildScrollView(child: content);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _enemy(Fighter enemy, CardDefinition? selectedCard) {
    final action = engine.intent(enemy.id);
    final intent = action.effects
        .map(
          (effect) => switch (effect.kind) {
            EffectKind.damage =>
              '${engine.predictedDamage(enemy.id, effect.amount)} damage',
            EffectKind.block => '${effect.amount} block',
            EffectKind.status => '${effect.amount} ${effect.status!.name}',
            _ => '${effect.amount} ${effect.kind.name}',
          },
        )
        .join(' · ');
    final targetable =
        enemy.alive &&
        selectedCard != null &&
        selectedCard.needsTarget &&
        selectedCard.cost <= engine.state.energy;
    return Semantics(
      button: targetable,
      excludeSemantics: true,
      onTap: targetable
          ? () => command(() => engine.play(selected!, targetId: enemy.id))
          : null,
      label:
          '${enemy.name}. ${enemy.health} health. ${enemy.block} block. ${enemy.alive ? 'Intent $intent' : 'Defeated'}. ${enemy.statuses.entries.map((s) => '${s.key.name} ${s.value}').join(', ')}',
      child: Material(
        color: const Color(0xff1a222b),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: targetable
              ? () => command(() => engine.play(selected!, targetId: enemy.id))
              : null,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: targetable
                    ? const Color(0xffe9be70)
                    : const Color(0xff35404b),
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    enemy.alive ? '${action.name}  ·  $intent' : 'DEFEATED',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xffe7aa93),
                      fontSize: 11,
                    ),
                  ),
                ),
                Expanded(
                  child: GameIllustration(
                    id: 'enemies/${widget.enemyIds[int.parse(enemy.id.split('-').last)]}',
                    icon: enemy.alive
                        ? Icons.local_fire_department_outlined
                        : Icons.blur_on,
                    height: 100,
                    color: enemy.alive
                        ? const Color(0xffbda07d)
                        : Colors.blueGrey,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      Text(
                        enemy.name,
                        style: const TextStyle(
                          fontFamily: 'serif',
                          fontSize: 19,
                        ),
                      ),
                      const SizedBox(height: 7),
                      _health(enemy),
                      const SizedBox(height: 4),
                      _statuses(enemy),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _health(Fighter fighter) => Column(
    children: [
      TweenAnimationBuilder<double>(
        tween: Tween(end: fighter.health / fighter.maxHealth),
        duration: widget.settings.duration,
        builder: (_, value, child) => LinearProgressIndicator(
          value: value,
          minHeight: 5,
          backgroundColor: const Color(0xff323945),
          color: const Color(0xffb66e65),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        '${fighter.health} / ${fighter.maxHealth} HP  ·  ${fighter.block} block',
        style: const TextStyle(fontSize: 11),
      ),
    ],
  );
  Widget _statuses(Fighter fighter) => Text(
    fighter.statuses.isEmpty
        ? 'No afflictions'
        : fighter.statuses.entries
              .map((s) => '${s.key.name} ${s.value}')
              .join(' · '),
    style: const TextStyle(fontSize: 10, color: Color(0xffaebbc5)),
    textAlign: TextAlign.center,
  );
  Widget _player(CombatSnapshot state) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xff1b2630),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xff36434e)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'THE WAYFARER',
                style: TextStyle(fontSize: 11, letterSpacing: 2),
              ),
              const SizedBox(height: 8),
              _health(state.player),
              _statuses(state.player),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Column(
          children: [
            Text(
              '${state.energy}',
              style: const TextStyle(
                fontFamily: 'serif',
                fontSize: 30,
                color: Color(0xfff0cb81),
              ),
            ),
            const Text(
              'ENERGY',
              style: TextStyle(fontSize: 9, letterSpacing: 1.4),
            ),
          ],
        ),
      ],
    ),
  );

  void _showLog() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Combat chronicle', style: TextStyle(fontSize: 22)),
        const SizedBox(height: 12),
        ...engine.state.events.reversed.map(
          (e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(e.message),
          ),
        ),
      ],
    ),
  );

  Widget _result(CombatSnapshot state) => PopScope(
    canPop: widget.onComplete == null || resultSaved,
    child: Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  state.outcome == Outcome.victory
                      ? Icons.wb_sunny_outlined
                      : Icons.nights_stay_outlined,
                  size: 72,
                  color: const Color(0xffc8a96b),
                ),
                const SizedBox(height: 24),
                Text(
                  state.outcome == Outcome.victory
                      ? 'The crypt falls silent.'
                      : 'The embers fade.',
                  style: const TextStyle(fontFamily: 'serif', fontSize: 32),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Text(
                  state.outcome == Outcome.victory ? 'VICTORY' : 'DEFEAT',
                  style: const TextStyle(
                    letterSpacing: 4,
                    color: Color(0xffc8a96b),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '${state.turn} turns  ·  ${state.player.health} health remaining\nBattle seed ${widget.seed}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  widget.onComplete == null
                      ? 'Practice battle complete.'
                      : savingResult
                      ? 'Saving your journey…'
                      : resultSaved
                      ? 'Your journey has been saved.'
                      : saveError ?? 'Preparing your checkpoint…',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: savingResult
                      ? null
                      : widget.onComplete != null && !resultSaved
                      ? _saveResult
                      : () => Navigator.of(context).pop(),
                  child: Text(
                    widget.onComplete != null && !resultSaved
                        ? 'Retry save'
                        : widget.onComplete != null
                        ? 'Continue journey'
                        : 'Return to camp',
                  ),
                ),
                TextButton(
                  onPressed: _showLog,
                  child: const Text('Read combat chronicle'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
