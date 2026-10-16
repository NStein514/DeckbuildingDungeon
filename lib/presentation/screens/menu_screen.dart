import 'package:flutter/material.dart';
import '../../app/settings.dart';
import '../../game/data/game_catalog.dart';
import '../widgets/game_card.dart';
import 'battle_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key, required this.catalog, required this.settings});
  final GameCatalog catalog;
  final GameSettings settings;
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  String encounter = 'rat';
  final seed = TextEditingController(text: '514');
  String? seedError;
  @override
  void dispose() { seed.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(body: DecoratedBox(
    decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(0, -.5), radius: 1.1,
      colors: [Color(0xff283239), Color(0xff10151c)])),
    child: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(28),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 500), child: Column(children: [
        const Icon(Icons.auto_awesome, size: 42, color: Color(0xffc8a96b)),
        const SizedBox(height: 18),
        const Text('DECKBOUND', style: TextStyle(fontFamily: 'serif', fontSize: 44, letterSpacing: 4, color: Color(0xffebdfc5))),
        const SizedBox(height: 10),
        const Text('YOUR DECK. YOUR DESTINY.', style: TextStyle(fontSize: 10, letterSpacing: 3, color: Color(0xffc8a96b))),
        const SizedBox(height: 36),
        const Text('The Ashen Crypt', style: TextStyle(fontFamily: 'serif', fontSize: 27)),
        const SizedBox(height: 10),
        const Text('Beyond the dying torches, something stirs.\nShape your hand. Choose your moment.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xffaeb8c2), height: 1.6)),
        const SizedBox(height: 26),
        const Align(alignment: Alignment.centerLeft, child: Text('CHOOSE AN ENCOUNTER', style: TextStyle(fontSize: 10, letterSpacing: 2))),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final enemy in widget.catalog.enemies.values)
            ChoiceChip(label: Text(enemy.name), selected: encounter == enemy.id, onSelected: (_) => setState(() => encounter = enemy.id)),
          ChoiceChip(label: const Text('Crypt ambush · 2 enemies'), selected: encounter == 'ambush', onSelected: (_) => setState(() => encounter = 'ambush')),
        ]),
        const SizedBox(height: 16),
        TextField(controller: seed, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Battle seed', helperText: 'Same seed, same opening hand.', errorText: seedError)),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: _start, child: const Padding(padding: EdgeInsets.all(8), child: Text('Enter the crypt')))),
        const SizedBox(height: 12),
        Wrap(alignment: WrapAlignment.center, spacing: 16, children: [
          TextButton(onPressed: _collection, child: const Text('Collection')),
          TextButton(onPressed: _settings, child: const Text('Settings')),
        ]),
        const SizedBox(height: 20),
        const Text('MILESTONE 1 · PLAYABLE COMBAT\nTemporary art • Progress is not saved', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Color(0xff83919f), height: 1.8)),
      ])),
    ))),
  ));

  void _start() {
    final value = int.tryParse(seed.text);
    if (value == null || value < 0 || value > 0xffffffff) {
      setState(() => seedError = 'Use an integer from 0 to 4294967295.');
      return;
    }
    setState(() => seedError = null);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => BattleScreen(
      catalog: widget.catalog, settings: widget.settings, seed: value,
      enemyIds: encounter == 'ambush' ? ['rat', 'skeleton'] : [encounter],
    )));
  }

  void _collection() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => Scaffold(
    appBar: AppBar(title: const Text('The card archive')),
    body: GridView.builder(padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 210, mainAxisExtent: 250, crossAxisSpacing: 12, mainAxisSpacing: 12),
      itemCount: widget.catalog.cards.length,
      itemBuilder: (_, index) => GameCard(card: widget.catalog.cards.values.elementAt(index), reducedMotion: widget.settings.reducedMotion)),
  )));

  void _settings() => showModalBottomSheet<void>(context: context, showDragHandle: true, isScrollControlled: true,
    builder: (context) => ListenableBuilder(listenable: widget.settings, builder: (context, child) => SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Settings', style: TextStyle(fontFamily: 'serif', fontSize: 28)),
        SwitchListTile(title: const Text('Reduced motion'), value: widget.settings.reducedMotion,
          onChanged: (value) => widget.settings.update(reduced: value)),
        SwitchListTile(title: const Text('Fast animations'), value: widget.settings.fastAnimations,
          onChanged: (value) => widget.settings.update(fast: value)),
        const Text('Music volume'), Slider(value: widget.settings.musicVolume, onChanged: (value) => widget.settings.update(music: value)),
        const Text('Effects volume'), Slider(value: widget.settings.effectsVolume, onChanged: (value) => widget.settings.update(effects: value)),
        const Text('Audio is silent in this build. Settings last for this session.', style: TextStyle(fontSize: 12), textAlign: TextAlign.center),
      ]),
    ))));
}
