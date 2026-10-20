import '../../assets/asset_registry.dart';
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

class RunScreen extends StatelessWidget {
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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: runs,
    builder: (context, child) {
      final r = runs.state!;
      return Scaffold(
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
              child: ListView(
                key: ValueKey('${r.descent}-${r.phase.name}'),
                padding: const EdgeInsets.all(20),
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
                      DungeonCard(
                        key: ValueKey('reveal-${r.descent}-${r.currentRoom}'),
                        label: 'Chosen path',
                        flip: true,
                        reducedMotion: settings.reducedMotion,
                        fast: settings.fastAnimations,
                        front: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xff1b2630),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xffd5b87a)),
                          ),
                          child: Column(
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
                              for (final id in r.room!.enemies) ...[
                                if (AssetRegistry.illustrations.containsKey(
                                  'enemies/$id',
                                ))
                                  GameIllustration(
                                    id: 'enemies/$id',
                                    height: 150,
                                  ),
                                const SizedBox(height: 8),
                                Text(
                                  '${catalog.enemies[id]!.name} · ${scaleEnemy(catalog.enemies[id]!, r.descent, modifier: r.room!.modifier).health} HP',
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
                      const SizedBox(height: 16),
                      if (r.room!.enemies.isNotEmpty)
                        for (final id in r.room!.enemies)
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
                      const Icon(
                        Icons.local_fire_department_outlined,
                        size: 72,
                        color: Color(0xffc8a96b),
                      ),
                      const Text(
                        'A moment by the embers',
                        style: TextStyle(fontSize: 28, fontFamily: 'serif'),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Choose one: recover 30% of maximum health, or permanently upgrade one card.',
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
                      const Icon(
                        Icons.auto_awesome,
                        size: 72,
                        color: Color(0xffc8a96b),
                      ),
                      const Text(
                        'A forgotten reliquary',
                        style: TextStyle(fontSize: 28, fontFamily: 'serif'),
                      ),
                      const Text(
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
    for (var depth = 0; depth <= 5; depth++) ...[
      Text(
        depth == 5
            ? 'FLOOR ${r.descent * 6} · BOSS'
            : 'FLOOR ${(r.descent - 1) * 6 + depth + 1}',
        style: const TextStyle(letterSpacing: 2, fontSize: 10),
      ),
      const SizedBox(height: 8),
      for (
        var start = 0;
        start < r.rooms.where((x) => x.depth == depth).length;
        start += 2
      )
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final room
                in r.rooms.where((x) => x.depth == depth).skip(start).take(2))
              Expanded(
                child: Transform.rotate(
                  angle: dungeonCardTilt(r.mapSeed, room.id),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: r.mapVersion >= 4 && !r.completed.contains(room.id)
                        ? DungeonCard(
                            label:
                                'Unexplored path ${room.lane + 1} · floor ${(r.descent - 1) * 6 + room.depth + 1}',
                            onTap:
                                !runs.busy && r.availableRooms.contains(room.id)
                                ? () => _enter(context, room.id)
                                : null,
                          )
                        : OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 18,
                                horizontal: 8,
                              ),
                            ),
                            onPressed:
                                !runs.busy && r.availableRooms.contains(room.id)
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
                                        .map((id) => catalog.enemies[id]!.name)
                                        .join(' + '),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
          ],
        ),
      if (depth < 5)
        const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(Icons.call_split, size: 22, color: Color(0xff7c8b98)),
        ),
    ],
  ];
  String _roomDescription(RoomType type) => switch (type) {
    RoomType.combat => 'Defeat the encounter to earn gold and a card choice.',
    RoomType.boss => 'Defeat the guardian to open the next descent.',
    RoomType.rest => 'Recover health or upgrade one card.',
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
            modifier: r.room!.modifier,
            discovered: r.discovered,
            deck: r.deck,
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
}
