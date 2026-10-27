import '../widgets/room_card.dart';
import '../widgets/path_card_stack.dart';
import '../widgets/path_reveal.dart';
import '../widgets/centered_card_row.dart';
import '../widgets/atmosphere.dart';
import '../../assets/asset_registry.dart';
import '../../game/economy/economy.dart';
import '../widgets/guardian_plan.dart';
import 'package:flutter/material.dart';
import '../../app/run_controller.dart';
import '../../app/settings.dart';
import '../../game/data/game_catalog.dart';
import '../../game/dungeon/dungeon.dart';
import '../../game/progression/run_state.dart';
import '../widgets/game_card.dart';
import '../widgets/dungeon_card.dart';
import '../../game/dungeon/difficulty.dart';
import 'battle_screen.dart';
import 'deck_screen.dart';
import 'fusion_panel.dart';
import 'economy_panel.dart';
import 'journal_screen.dart';
import '../widgets/journal_notice.dart';
import 'collection_screen.dart';

class RunScreen extends StatefulWidget {
  const RunScreen({
    super.key,
    required this.runs,
    required this.catalog,
    required this.settings,
  });
  final RunController runs;
  final GameCatalog catalog;
  final GameSettings settings;
  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  RunController get runs => widget.runs;
  GameCatalog get catalog => widget.catalog;
  GameSettings get settings => widget.settings;
  final _mapScroll = ScrollController(keepScrollOffset: false);
  final _floors = List.generate(6, (_) => GlobalKey());
  String? _focus;
  final _roomKeys = <String, GlobalKey>{};
  Rect? _revealOrigin;
  int _revealedOpponents = 1;
  int? _descent;
  double? _mapOffset;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The reveal overlay must have both faces ready before its first paint.
    precacheImage(
      const ResizeImage(
        AssetImage('assets/images/ui/enemy_frame.png'),
        width: 768,
      ),
      context,
    );
    precacheImage(
      const ResizeImage(
        AssetImage('assets/images/ui/card_back.png'),
        width: 384,
      ),
      context,
    );
  }

  @override
  void dispose() {
    _mapScroll.dispose();
    super.dispose();
  }

  void _focusPath(RunState r) {
    if (r.phase != RunPhase.map) {
      if (_mapScroll.hasClients) _mapOffset = _mapScroll.offset;
      _focus = null;
      return;
    }
    final signature = '${r.seed}-${r.descent}-${r.completed.length}';
    if (_focus == signature) return;
    _focus = signature;
    final freshDescent = _descent != r.descent;
    _descent = r.descent;
    final depth = r.rooms
        .firstWhere((room) => r.availableRooms.contains(room.id))
        .depth;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _focus != signature || !_mapScroll.hasClients) return;
      final max = _mapScroll.position.maxScrollExtent;
      _mapScroll.jumpTo(
        freshDescent ? max : (_mapOffset ?? max).clamp(0.0, max),
      );
      // The first floor starts at the very bottom. Resumed runs and completed
      // rooms focus the entire reachable floor, including its lane choices.
      if (depth > 0) {
        final target = _floors[depth].currentContext;
        if (target != null) {
          Scrollable.ensureVisible(
            target,
            alignment: .5,
            duration: freshDescent ? Duration.zero : settings.duration,
          );
        }
      }
    });
  }

  String _roomArt(RunState r) => switch (r.room!.type) {
    RoomType.rest => 'events/sanctuary',
    RoomType.event =>
      'events/${JourneyEvent.fromSeed(r.battleSeed, mapVersion: r.mapVersion).name}',
    _ => 'rooms/${r.room!.type.name}',
  };

  Widget _revealedCard(RunState r, String? enemyId) {
    if (enemyId == null) {
      final event = r.room!.type == RoomType.event
          ? JourneyEvent.fromSeed(r.battleSeed, mapVersion: r.mapVersion)
          : null;
      return RoomCard(
        title: event?.title ?? r.room!.type.name.toUpperCase(),
        art: _roomArt(r),
        description: event?.description ?? _roomDescription(r.room!.type),
      );
    }
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: ResizeImage(
            AssetImage('assets/images/ui/enemy_frame.png'),
            width: 768,
          ),
          fit: BoxFit.fill,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffd5b87a)),
      ),
      child: LayoutBuilder(
        builder: (context, bounds) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: bounds.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 48,
                  color: Color(0xffd5b87a),
                ),
                const SizedBox(height: 12),
                Text(
                  r.room!.type.name.toUpperCase(),
                  style: const TextStyle(fontSize: 24),
                ),
                for (final id in [enemyId]) ...[
                  if (AssetRegistry.illustrations.containsKey('enemies/$id'))
                    GameIllustration(id: 'enemies/$id', height: 150),
                  const SizedBox(height: 8),
                  Text(
                    '${catalog.enemies[id]!.name} · ${scaleEnemy(catalog.enemies[id]!, r.descent, modifier: r.room!.modifier).health} HP',
                    textAlign: TextAlign.center,
                  ),
                ],
                if (r.room!.modifier != EncounterModifier.none)
                  Text(
                    r.room!.modifier.description,
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 16),
                Text(
                  _roomDescription(r.room!.type),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: runs,
    builder: (context, child) {
      final r = runs.state!;
      _focusPath(r);
      return AtmosphericScaffold(
        depth: r.room?.depth ?? 0,
        appBar: AppBar(
          title: const Text('The Ashen Crypt'),
          actions: [
            IconButton(
              tooltip: 'Journey journal',
              icon: const Icon(Icons.emoji_events_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => JournalScreen(runs: runs, catalog: catalog),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Combos and fusions',
              icon: const Icon(Icons.auto_stories_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => CollectionScreen(
                    catalog: catalog,
                    discovered: r.discovered,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Inspect deck',
              icon: const Icon(Icons.style_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => DeckScreen(catalog: catalog, deck: r.deck),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: _RunContent(
                controller: r.phase == RunPhase.map ? _mapScroll : null,
                key: ValueKey('${r.descent}-${r.phase.name}'),
                children: [
                  Wrap(
                    spacing: 18,
                    runSpacing: 8,
                    children: [
                      Text('${r.health} / ${catalog.rules.maxHealth} HP'),
                      Text('${r.gold} gold'),
                      Text('${r.deck.length} cards'),
                      Text('Seed ${r.seed}'),
                      Text(
                        'Descent ${r.descent} · ${r.clearedRooms} rooms cleared',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: r.relics
                        .map(
                          (x) => Tooltip(
                            message: x.description,
                            child: Chip(
                              avatar: x.name == 'lastEmber'
                                  ? const SizedBox(
                                      width: 24,
                                      child: GameIllustration(
                                        id: 'relics/lastEmber',
                                        height: 24,
                                      ),
                                    )
                                  : null,
                              label: Text(x.title),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  JournalNotice(runs: runs),
                  if (runs.busy) const LinearProgressIndicator(),
                  if (runs.error != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        runs.error!,
                        style: const TextStyle(color: Colors.orangeAccent),
                      ),
                    ),
                  const SizedBox(height: 20),
                  ...switch (r.phase) {
                    RunPhase.map => _map(context, r),
                    RunPhase.reveal => [
                      const Text(
                        'The path is revealed',
                        style: TextStyle(fontSize: 28, fontFamily: 'serif'),
                      ),
                      const SizedBox(height: 16),
                      PathCardStack(
                        key: ValueKey('cards-${r.descent}-${r.currentRoom}'),
                        count: r.room!.enemies.isEmpty
                            ? 1
                            : r.room!.enemies.length,
                        reducedMotion:
                            settings.reducedMotion ||
                            MediaQuery.disableAnimationsOf(context),
                        onRevealed: (count) => setState(() {
                          _revealedOpponents = count;
                          _revealOrigin = null;
                        }),
                        cardBuilder: (index) => PathReveal(
                          origin: index == 0 ? _revealOrigin : null,
                          reducedMotion: settings.reducedMotion,
                          fast: settings.fastAnimations,
                          prepare: () async {
                            if (r.room!.enemies.isEmpty) {
                              final asset =
                                  AssetRegistry.illustrations[_roomArt(r)];
                              if (asset != null && context.mounted) {
                                await precacheImage(
                                  ResizeImage(AssetImage(asset), width: 768),
                                  context,
                                );
                              }
                            }
                            for (final id in r.room!.enemies) {
                              final asset =
                                  AssetRegistry.illustrations['enemies/$id'];
                              if (asset != null && context.mounted) {
                                await precacheImage(
                                  ResizeImage(AssetImage(asset), width: 768),
                                  context,
                                );
                              }
                            }
                          },
                          child: _revealedCard(
                            r,
                            r.room!.enemies.isEmpty
                                ? null
                                : r.room!.enemies[index],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (r.room!.enemies.isNotEmpty)
                        for (final id in r.room!.enemies.take(
                          _revealedOpponents,
                        ))
                          GuardianPlan(
                            enemy: scaleEnemy(
                              catalog.enemies[id]!,
                              r.descent,
                              modifier: r.room!.modifier,
                            ),
                          ),
                      const Text(
                        'This path is yours. The reveal is saved; returning to camp keeps the same card.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: runs.busy
                            ? null
                            : () => _continueRoom(context),
                        child: Text(
                          r.room!.enemies.isNotEmpty
                              ? 'Enter encounter'
                              : 'Continue to room',
                        ),
                      ),
                    ],
                    RunPhase.combat => [
                      const Text(
                        'An encounter awaits',
                        style: TextStyle(fontSize: 26, fontFamily: 'serif'),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Resume from the entry checkpoint with the same health, deck, and seed.',
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: runs.busy ? null : () => _battle(context, r),
                        child: const Text('Resume encounter'),
                      ),
                    ],
                    RunPhase.reward => [
                      const Text(
                        'Spoils of battle',
                        style: TextStyle(fontSize: 28, fontFamily: 'serif'),
                      ),
                      const Text(
                        'Gold secured. Choose one card or skip; your choice is saved once.',
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 280,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: r.rewards.length,
                          separatorBuilder: (_, i) => const SizedBox(width: 12),
                          itemBuilder: (_, i) => GameCard(
                            card: catalog.cards[r.rewards[i]]!,
                            onTap: runs.busy
                                ? null
                                : () => runs.reward(r.rewards[i]),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: runs.busy ? null : () => runs.reward(null),
                        child: const Text('Skip card reward'),
                      ),
                    ],
                    RunPhase.rest => [
                      const RoomCardPanel(
                        title: 'A moment by the embers',
                        art: 'events/sanctuary',
                        description:
                            'Choose one: recover 30% of maximum health, upgrade one card, or remove one card. Your choice ends this visit.',
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: runs.busy ? null : () => runs.rest(),
                        child: Text(
                          'Rest · heal up to ${(catalog.rules.maxHealth * .3).ceil()} HP',
                        ),
                      ),
                      OutlinedButton(
                        onPressed:
                            runs.busy || r.deck.every((c) => c.upgrade > 0)
                            ? null
                            : () => _upgrade(context, r),
                        child: const Text('Upgrade a card'),
                      ),
                      OutlinedButton(
                        onPressed:
                            runs.busy || r.deck.length <= Merchant.minimumDeck
                            ? null
                            : () => _removeAtSanctuary(context, r),
                        child: const Text('Let go · remove a card'),
                      ),
                      const Text(
                        'Removal costs no gold, but gives up healing and upgrading. Keep at least five cards.',
                      ),
                    ],
                    RunPhase.merchant || RunPhase.event => [
                      EconomyPanel(
                        key: ValueKey('${r.descent}-${r.currentRoom}'),
                        runs: runs,
                        catalog: catalog,
                        run: r,
                      ),
                    ],
                    RunPhase.shrine => [
                      FusionPanel(
                        key: ValueKey('shrine-${r.descent}-${r.currentRoom}'),
                        runs: runs,
                        catalog: catalog,
                        run: r,
                        reducedMotion: settings.reducedMotion,
                      ),
                    ],
                    RunPhase.treasure => [
                      const RoomCardPanel(
                        title: 'A forgotten reliquary',
                        art: 'rooms/treasure',
                        description:
                            'Take 25 gold and a relic you do not own. Relics apply automatically in future battles.',
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: runs.busy ? null : () => runs.treasure(),
                        child: const Text('Claim treasure'),
                      ),
                    ],
                    RunPhase.victory || RunPhase.defeat => [
                      Text(
                        r.phase == RunPhase.victory
                            ? 'The Warden falls. The depths await.'
                            : 'The journey ends.',
                        style: const TextStyle(
                          fontSize: 30,
                          fontFamily: 'serif',
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '${r.clearedRooms} rooms completed · ${r.discovered.length} cards discovered',
                      ),
                      const SizedBox(height: 20),
                      if (r.phase == RunPhase.victory) ...[
                        Text(
                          'Descend with your current health, deck, gold and relics. '
                          'Descent ${r.descent + 1}: enemies have +${20 * r.descent}% base health and +${10 * r.descent}% base damage/block.',
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: runs.busy ? null : runs.descend,
                          child: const Text('Descend deeper'),
                        ),
                        const SizedBox(height: 12),
                      ],
                      FilledButton(
                        onPressed: runs.busy
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('Return to camp'),
                      ),
                    ],
                  },
                  const SizedBox(height: 24),
                  const Text(
                    'Progress saves after room choices and rewards. Leaving a battle restarts that encounter.',
                    style: TextStyle(fontSize: 11, color: Color(0xffaeb8c2)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  List<Widget> _map(BuildContext context, RunState r) => [
    const Text(
      'Choose your path',
      style: TextStyle(fontFamily: 'serif', fontSize: 30),
    ),
    const SizedBox(height: 8),
    Text(
      r.mapVersion >= 4
          ? 'Choose one face-down card on the next floor. Flipping commits your path; other cards stay unknown.'
          : 'Each floor connects to every room on the next. Highlighted paths are reachable.',
    ),
    const SizedBox(height: 20),
    for (var depth = 5; depth >= 0; depth--)
      FloorSurface(
        key: _floors[depth],
        depth: depth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              depth == 5
                  ? 'FLOOR ${r.descent * 6} · BOSS'
                  : 'FLOOR ${(r.descent - 1) * 6 + depth + 1}',
              style: const TextStyle(letterSpacing: 2, fontSize: 10),
            ),
            const SizedBox(height: 8),
            CenteredCardRow(
              children: [
                for (final room in r.rooms.where((x) => x.depth == depth))
                  Transform.rotate(
                    angle: dungeonCardTilt(r.mapSeed, room.id),
                    child: SizedBox(
                      key: _roomKeys.putIfAbsent(room.id, () => GlobalKey()),
                      width: 150,
                      height: MediaQuery.textScalerOf(context).scale(1) > 1.3
                          ? 283
                          : 217,
                      child: r.mapVersion >= 4 && !r.completed.contains(room.id)
                          ? DungeonCard(
                              label:
                                  'Unexplored path ${room.lane + 1} · floor ${(r.descent - 1) * 6 + room.depth + 1}',
                              onTap:
                                  !runs.busy &&
                                      r.availableRooms.contains(room.id)
                                  ? () => _enter(context, room.id)
                                  : null,
                            )
                          : OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 8,
                                ),
                              ),
                              onPressed:
                                  !runs.busy &&
                                      r.availableRooms.contains(room.id)
                                  ? () => _enter(context, room.id)
                                  : null,
                              child: Column(
                                children: [
                                  Icon(
                                    r.completed.contains(room.id)
                                        ? Icons.check_circle_outline
                                        : switch (room.type) {
                                            RoomType.combat => Icons.bolt,
                                            RoomType.rest =>
                                              Icons
                                                  .local_fire_department_outlined,
                                            RoomType.treasure =>
                                              Icons.auto_awesome,
                                            RoomType.shrine =>
                                              Icons.auto_fix_high,
                                            RoomType.merchant =>
                                              Icons.storefront_outlined,
                                            RoomType.event =>
                                              Icons.explore_outlined,
                                            RoomType.boss =>
                                              Icons.shield_outlined,
                                          },
                                  ),
                                  const SizedBox(height: 8),
                                  Text(room.type.name.toUpperCase()),
                                  if (room.modifier != EncounterModifier.none)
                                    Text(
                                      room.modifier.description,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.orangeAccent,
                                      ),
                                    ),
                                  if (room.enemies.isNotEmpty)
                                    Text(
                                      room.enemies
                                          .map(
                                            (id) => catalog.enemies[id]!.name,
                                          )
                                          .join(' + '),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                ],
                              ),
                            ),
                    ),
                  ),
              ],
            ),
            if (depth > 0)
              const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.call_split,
                  size: 22,
                  color: Color(0xff7c8b98),
                ),
              ),
          ],
        ),
      ),
  ];
  String _roomDescription(RoomType type) => switch (type) {
    RoomType.combat => 'Defeat the encounter to earn gold and a card choice.',
    RoomType.boss => 'Defeat the guardian to open the next descent.',
    RoomType.rest => 'Choose healing, an upgrade or card removal.',
    RoomType.treasure => 'Claim gold and an unowned relic.',
    RoomType.shrine => 'Combine two compatible cards, or leave safely.',
    RoomType.merchant =>
      'Spend gold on cards, healing or removal, or leave safely.',
    RoomType.event =>
      'Discover a bargain for resources or your deck. You can decline it.',
  };

  Future<void> _continueRoom(BuildContext context) async {
    if (await runs.continueRoom() &&
        context.mounted &&
        runs.state!.phase == RunPhase.combat) {
      await _battle(context, runs.state!);
    }
  }

  Future<void> _enter(BuildContext context, String id) async {
    _revealedOpponents = 1;
    if (runs.busy) return;
    final box = _roomKeys[id]?.currentContext?.findRenderObject() as RenderBox?;
    _revealOrigin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    if (await runs.enter(id) &&
        context.mounted &&
        runs.state!.phase == RunPhase.combat) {
      await _battle(context, runs.state!);
    }
  }

  Future<void> _battle(BuildContext context, RunState r) =>
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => BattleScreen(
            catalog: catalog,
            enemyIds: r.room!.enemies,
            settings: settings,
            seed: r.battleSeed,
            descent: r.descent,
            floorDepth: r.room!.depth,
            modifier: r.room!.modifier,
            discovered: r.discovered,
            deck: r.deck,
            startingBuild: r.startingBuild,
            initialHealth: r.health,
            relics: r.relics.toSet(),
            onComplete: (result) =>
                runs.finish(result.outcome, result.player.health),
          ),
        ),
      );
  Future<void> _upgrade(BuildContext context, RunState r) async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        builder: (_) =>
            DeckScreen(catalog: catalog, deck: r.deck, chooseUpgrade: true),
      ),
    );
    if (id != null) await runs.rest(upgradeId: id);
  }

  Future<void> _removeAtSanctuary(BuildContext context, RunState r) async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        builder: (_) => DeckScreen(
          catalog: catalog,
          deck: r.deck,
          chooseRemoval: true,
          selectionHint:
              'Remove one card for no gold. Forgo healing and upgrading this visit.',
          confirmationTitle: 'Remove this card and end the sanctuary visit?',
        ),
      ),
    );
    if (id != null) await runs.rest(removeId: id);
  }
}

/// Only the bounded map needs every floor laid out for anchor-based scrolling.
/// Other room screens retain their existing lazy list and accessibility tree.
class _RunContent extends StatelessWidget {
  const _RunContent({super.key, this.controller, required this.children});
  final ScrollController? controller;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => controller == null
      ? ListView(padding: const EdgeInsets.all(20), children: children)
      : SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        );
}
