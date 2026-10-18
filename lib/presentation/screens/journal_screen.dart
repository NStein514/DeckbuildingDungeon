import 'package:flutter/material.dart';
import '../../app/run_controller.dart';
import '../../game/data/game_catalog.dart';
import '../../game/fusion/fusion.dart';
import '../../game/relics/relic.dart';
import '../widgets/game_card.dart';
import '../widgets/journal_notice.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key, required this.runs, required this.catalog});
  final RunController runs;
  final GameCatalog catalog;
  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  bool discoveredOnly = false;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.runs,
    builder: (context, _) {
      final profile = widget.runs.profile;
      final cards =
          widget.catalog.cards.values
              .where(
                (c) =>
                    !discoveredOnly || (profile?.cards.contains(c.id) ?? false),
              )
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      return Scaffold(
        appBar: AppBar(title: const Text('Journey journal')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                JournalNotice(runs: widget.runs),
                if (profile == null)
                  const Text(
                    'Journal unavailable. Retry loading it to view your records.',
                  )
                else ...[
                  const Text(
                    'Personal records',
                    style: TextStyle(fontSize: 26, fontFamily: 'serif'),
                  ),
                  const Text(
                    'Best results from saved journeys. Practice encounters do not count.',
                  ),
                  ListTile(
                    title: const Text('Deepest floor entered'),
                    trailing: Text('${profile.deepestFloor}'),
                  ),
                  ListTile(
                    title: const Text('Most rooms cleared in one journey'),
                    trailing: Text('${profile.bestRooms}'),
                  ),
                  ListTile(
                    title: const Text('Most bosses defeated in one journey'),
                    trailing: Text('${profile.bestBosses}'),
                  ),
                  const Divider(),
                  Text(
                    'Fusion discoveries · ${fusionRecipes.where((r) => profile.cards.contains(r.result)).length} / ${fusionRecipes.length}',
                    style: const TextStyle(fontSize: 22),
                  ),
                  for (final recipe in fusionRecipes)
                    ListTile(
                      leading: Icon(
                        profile.cards.contains(recipe.result)
                            ? Icons.auto_awesome
                            : Icons.search,
                      ),
                      title: Text(widget.catalog.cards[recipe.result]!.name),
                      subtitle: Text(
                        '${widget.catalog.cards[recipe.first]!.name} + ${widget.catalog.cards[recipe.second]!.name}\n${profile.cards.contains(recipe.result) ? 'Discovered across your journeys' : 'Not yet discovered'}',
                      ),
                    ),
                  const Divider(),
                  Text(
                    'Relics discovered · ${profile.relics.length} / ${Relic.values.length}',
                    style: const TextStyle(fontSize: 22),
                  ),
                  for (final relic in Relic.values)
                    ListTile(
                      leading: Icon(
                        profile.relics.contains(relic.name)
                            ? Icons.check_circle_outline
                            : Icons.search,
                      ),
                      title: Text(relic.title),
                      subtitle: Text(
                        '${profile.relics.contains(relic.name) ? 'Discovered' : 'Not yet discovered'} · ${relic.description}',
                      ),
                    ),
                  const Divider(),
                  Text(
                    'Cards discovered · ${profile.cards.length} / ${widget.catalog.cards.length}',
                    style: const TextStyle(fontSize: 22),
                  ),
                  SwitchListTile(
                    title: const Text('Show discovered cards only'),
                    value: discoveredOnly,
                    onChanged: (value) =>
                        setState(() => discoveredOnly = value),
                  ),
                  for (final card in cards)
                    ListTile(
                      leading: Icon(
                        profile.cards.contains(card.id)
                            ? Icons.check_circle_outline
                            : Icons.search,
                      ),
                      title: Text(card.name),
                      subtitle: Text(
                        profile.cards.contains(card.id)
                            ? 'Discovered'
                            : 'Not yet discovered',
                      ),
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(card.name),
                          content: SizedBox(
                            width: 190,
                            height: 280,
                            child: GameCard(card: card),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (cards.isEmpty)
                    const Text(
                      'No cards discovered yet. Start a journey to begin your journal.',
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your journal survives starting a new journey on this device. Discoveries record what you have found; they do not increase character stats.',
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
