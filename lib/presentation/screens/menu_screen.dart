import '../widgets/atmosphere.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../../app/settings.dart';
import '../../game/data/game_catalog.dart';
import '../widgets/game_card.dart';
import 'battle_screen.dart';
import 'deck_screen.dart';
import '../../game/progression/starting_build.dart';
import 'run_screen.dart';
import 'journal_screen.dart';
import '../widgets/journal_notice.dart';
import '../../app/run_controller.dart';
import '../../game/progression/run_state.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({
    super.key,
    required this.catalog,
    required this.settings,
    required this.runs,
  });
  final GameCatalog catalog;
  final GameSettings settings;
  final RunController runs;
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  String encounter = 'rat';
  StartingBuild startingBuild = StartingBuild.wanderer;
  final seed = TextEditingController();
  String? seedError;
  @override
  void dispose() {
    seed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.runs,
    builder: (context, child) => AtmosphericScaffold(
      depth: 0,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -.5),
            radius: 1.1,
            colors: [Color(0x30283239), Color(0x6010151c)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 42,
                      color: Color(0xffc8a96b),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'DECKBOUND',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 44,
                        letterSpacing: 4,
                        color: Color(0xffebdfc5),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'YOUR DECK. YOUR DESTINY.',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 3,
                        color: Color(0xffc8a96b),
                      ),
                    ),
                    const SizedBox(height: 36),
                    const Text(
                      'The Ashen Crypt',
                      style: TextStyle(fontFamily: 'serif', fontSize: 27),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Beyond the dying torches, something stirs.\nShape your hand. Choose your moment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xffaeb8c2), height: 1.6),
                    ),
                    const SizedBox(height: 26),
                    if (widget.runs.error != null)
                      Text(
                        widget.runs.error!,
                        style: const TextStyle(color: Colors.orangeAccent),
                      ),
                    JournalNotice(runs: widget.runs),
                    if (!widget.runs.loaded)
                      TextButton(
                        onPressed: widget.runs.busy ? null : widget.runs.load,
                        child: Text(
                          widget.runs.busy
                              ? 'Loading save…'
                              : 'Retry loading save',
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed:
                            widget.runs.busy ||
                                !widget.runs.loaded ||
                                widget.runs.profileError != null
                            ? null
                            : _newRun,
                        child: const Text('New run'),
                      ),
                    ),
                    ExpansionTile(
                      title: Text('Starting build · ${startingBuild.title}'),
                      children: [
                        const Text(
                          '12 cards · 50 HP · Iron Sigil. No permanent stat bonuses.',
                        ),
                        for (final build in StartingBuild.values)
                          ListTile(
                            title: Text(
                              '${build.title}${build == startingBuild ? " · selected" : ""}',
                            ),
                            subtitle: Text(
                              '${build.unlocked(widget.runs.profile) ? "" : "Locked · "}${build.description}',
                            ),
                            leading: Icon(
                              build == startingBuild
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                            ),
                            onTap:
                                widget.runs.busy ||
                                    !widget.runs.loaded ||
                                    widget.runs.profileError != null ||
                                    !build.unlocked(widget.runs.profile)
                                ? null
                                : () => setState(() => startingBuild = build),
                            trailing: IconButton(
                              tooltip: 'Inspect ${build.title} deck',
                              icon: const Icon(Icons.style),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => DeckScreen(
                                    catalog: widget.catalog,
                                    deck: build.deck(widget.catalog),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (widget.runs.state != null)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: widget.runs.busy ? null : _openRun,
                          child: Text(
                            [RunPhase.defeat].contains(widget.runs.state!.phase)
                                ? 'Last journey'
                                : 'Continue run',
                          ),
                        ),
                      ),
                    const SizedBox(height: 26),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'PRACTICE ENCOUNTER · NOT SAVED',
                        style: TextStyle(fontSize: 10, letterSpacing: 2),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final enemy in widget.catalog.enemies.values)
                          ChoiceChip(
                            label: Text(enemy.name),
                            selected: encounter == enemy.id,
                            onSelected: (_) =>
                                setState(() => encounter = enemy.id),
                          ),
                        ChoiceChip(
                          label: const Text('Crypt ambush · 2 enemies'),
                          selected: encounter == 'ambush',
                          onSelected: (_) =>
                              setState(() => encounter = 'ambush'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: seed,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Run / battle seed',
                        helperText:
                            'Blank: a fresh run. Enter a seed to replay; practice defaults to 514.',
                        errorText: seedError,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _start,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('Enter the crypt'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => JournalScreen(
                                runs: widget.runs,
                                catalog: widget.catalog,
                              ),
                            ),
                          ),
                          child: const Text('Journey journal'),
                        ),
                        TextButton(
                          onPressed: _collection,
                          child: const Text('Collection'),
                        ),
                        TextButton(
                          onPressed: _settings,
                          child: const Text('Settings'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'FUSE YOUR DECK · DESCEND DEEPER\nTemporary art • Runs save at room boundaries',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xff83919f),
                        height: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  void _openRun() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => RunScreen(
        runs: widget.runs,
        catalog: widget.catalog,
        settings: widget.settings,
      ),
    ),
  );
  Future<void> _newRun() async {
    final value = seed.text.trim().isEmpty
        ? Random().nextInt(0x100000000)
        : int.tryParse(seed.text.trim());
    if (value == null || value < 0 || value > 0xffffffff) {
      setState(() => seedError = 'Use an integer from 0 to 4294967295.');
      return;
    }
    setState(() => seedError = null);
    if (widget.runs.state != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Begin a new journey?'),
          content: const Text(
            'This replaces your saved run. Your current journey will be lost. Your journal and personal records are kept.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep current run'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('New journey'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    if (await widget.runs.start(value, build: startingBuild) && mounted) {
      _openRun();
    }
  }

  void _start() {
    final value = seed.text.trim().isEmpty
        ? 514
        : int.tryParse(seed.text.trim());
    if (value == null || value < 0 || value > 0xffffffff) {
      setState(() => seedError = 'Use an integer from 0 to 4294967295.');
      return;
    }
    setState(() => seedError = null);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BattleScreen(
          catalog: widget.catalog,
          settings: widget.settings,
          seed: value,
          startingBuild: startingBuild,
          deck: startingBuild.deck(widget.catalog),
          enemyIds: encounter == 'ambush' ? ['rat', 'skeleton'] : [encounter],
        ),
      ),
    );
  }

  void _collection() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => AtmosphericScaffold(
        appBar: AppBar(title: const Text('The card archive')),
        body: GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 210,
            mainAxisExtent: 250,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: widget.catalog.cards.length,
          itemBuilder: (_, index) => GameCard(
            card: widget.catalog.cards.values.elementAt(index),
            reducedMotion: widget.settings.reducedMotion,
          ),
        ),
      ),
    ),
  );

  void _settings() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => ListenableBuilder(
      listenable: widget.settings,
      builder: (context, child) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Settings',
                style: TextStyle(fontFamily: 'serif', fontSize: 28),
              ),
              SwitchListTile(
                title: const Text('Reduced motion'),
                value: widget.settings.reducedMotion,
                onChanged: (value) => widget.settings.update(reduced: value),
              ),
              SwitchListTile(
                title: const Text('Fast animations'),
                value: widget.settings.fastAnimations,
                onChanged: (value) => widget.settings.update(fast: value),
              ),
              const Text('Music volume'),
              Slider(
                value: widget.settings.musicVolume,
                onChanged: (value) => widget.settings.update(music: value),
              ),
              const Text('Effects volume'),
              Slider(
                value: widget.settings.effectsVolume,
                onChanged: (value) => widget.settings.update(effects: value),
              ),
              Text(
                widget.settings.persistenceError ??
                    (widget.settings.store == null
                        ? 'Audio is silent. Settings last for this session.'
                        : 'Audio is silent. Settings are saved locally.'),
                style: TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
