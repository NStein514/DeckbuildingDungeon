import 'package:flutter/material.dart';
import '../../game/cards/upgrades.dart';
import '../../game/data/game_catalog.dart';
import '../../game/models/models.dart';
import '../widgets/game_card.dart';

class DeckScreen extends StatefulWidget {
  const DeckScreen({
    super.key,
    required this.catalog,
    required this.deck,
    this.chooseUpgrade = false,
    this.chooseRemoval = false,
    this.confirmationTitle,
    this.selectionHint,
  });
  final GameCatalog catalog;
  final List<CardInstance> deck;
  final bool chooseUpgrade, chooseRemoval;
  final String? confirmationTitle, selectionHint;
  @override
  State<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends State<DeckScreen> {
  CardType? filter;
  String sort = 'Name';
  @override
  Widget build(BuildContext context) {
    final cards = widget.deck
        .where(
          (c) =>
              (!widget.chooseUpgrade || c.upgrade == 0) &&
              (filter == null ||
                  widget.catalog.cards[c.definitionId]!.type == filter),
        )
        .toList();
    cards.sort((a, b) {
      final x = widget.catalog.cards[a.definitionId]!,
          y = widget.catalog.cards[b.definitionId]!;
      return switch (sort) {
        'Cost' => x.cost.compareTo(y.cost),
        'Rarity' => y.rarity.index.compareTo(x.rarity.index),
        _ => x.name.compareTo(y.name),
      };
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.chooseUpgrade
              ? 'Choose a card to upgrade'
              : widget.chooseRemoval
              ? 'Choose a card to remove'
              : 'Your deck · ${widget.deck.length}',
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              children: [
                DropdownButton<CardType>(
                  value: filter,
                  hint: const Text('All types'),
                  items: [
                    const DropdownMenuItem<CardType>(
                      value: null,
                      child: Text('All types'),
                    ),
                    ...CardType.values.map(
                      (t) => DropdownMenuItem(value: t, child: Text(t.name)),
                    ),
                  ],
                  onChanged: (v) => setState(() => filter = v),
                ),
                DropdownButton<String>(
                  value: sort,
                  items: ['Name', 'Cost', 'Rarity']
                      .map(
                        (v) =>
                            DropdownMenuItem(value: v, child: Text('Sort: $v')),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => sort = v!),
                ),
              ],
            ),
          ),
          if (widget.chooseUpgrade || widget.chooseRemoval)
            Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                widget.selectionHint ??
                    (widget.chooseRemoval
                        ? 'Tap to preview removal. Cost: 40 gold.'
                        : 'Tap to preview. Each card can be upgraded once.'),
              ),
            ),
          Expanded(
            child: cards.isEmpty
                ? const Center(child: Text('No matching cards.'))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 210,
                          mainAxisExtent: 280,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: cards.length,
                    itemBuilder: (_, i) => GameCard(
                      card: resolveCard(
                        widget.catalog.cards[cards[i].definitionId]!,
                        cards[i],
                      ),
                      onTap: widget.chooseUpgrade || widget.chooseRemoval
                          ? () => _preview(cards[i])
                          : null,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _preview(CardInstance card) async {
    final upgraded = resolveCard(
      widget.catalog.cards[card.definitionId]!,
      CardInstance(
        card.id,
        card.definitionId,
        upgrade: widget.chooseRemoval ? card.upgrade : 1,
      ),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.confirmationTitle ??
              (widget.chooseRemoval
                  ? 'Remove this card for 40 gold?'
                  : 'Upgrade preview'),
        ),
        content: SizedBox(
          height: 280,
          width: 170,
          child: GameCard(card: upgraded),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(widget.chooseRemoval ? 'Remove card' : 'Upgrade'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.pop(context, card.id);
  }
}
