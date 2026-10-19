import '../../assets/asset_registry.dart';
import 'package:flutter/material.dart';
import '../../app/run_controller.dart';
import '../../game/data/game_catalog.dart';
import '../../game/economy/economy.dart';
import '../../game/progression/run_state.dart';
import '../widgets/game_card.dart';
import 'deck_screen.dart';

class EconomyPanel extends StatelessWidget {
  const EconomyPanel({
    super.key,
    required this.runs,
    required this.catalog,
    required this.run,
  });
  final RunController runs;
  final GameCatalog catalog;
  final RunState run;
  @override
  Widget build(BuildContext context) {
    if (run.phase == RunPhase.event) {
      final event = JourneyEvent.fromSeed(
        run.battleSeed,
        mapVersion: run.mapVersion,
      );
      final canAccept = event.canAccept(
        run.health,
        run.gold,
        catalog.rules.maxHealth,
        run.deck,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (event.choosesCard)
            GameIllustration(id: 'events/${event.name}', height: 160)
          else
            const Icon(Icons.explore_outlined, size: 64),
          Text(
            event.title,
            style: const TextStyle(fontSize: 28, fontFamily: 'serif'),
          ),
          const SizedBox(height: 16),
          Text(event.description),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: runs.busy || !canAccept
                ? null
                : () async {
                    if (!event.choosesCard) {
                      await runs.resolveEvent(true);
                      return;
                    }
                    final id = await Navigator.push<String>(
                      context,
                      MaterialPageRoute<String>(
                        builder: (_) => DeckScreen(
                          catalog: catalog,
                          deck: run.deck,
                          chooseUpgrade: event == JourneyEvent.emberForge,
                          chooseRemoval: event == JourneyEvent.memoryWell,
                          confirmationTitle: event == JourneyEvent.emberForge
                              ? 'Upgrade this card for 6 HP?'
                              : 'Remove this card for 25 gold?',
                        ),
                      ),
                    );
                    if (id != null) await runs.resolveEvent(true, cardId: id);
                  },
            child: Text(event.actionLabel),
          ),
          if (!canAccept)
            const Text(
              'This bargain needs sufficient health or gold, and an eligible card or missing health.',
            ),
          TextButton(
            onPressed: runs.busy ? null : () => runs.resolveEvent(false),
            child: const Text('Leave safely'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.storefront_outlined, size: 64),
        const Text(
          'The crypt merchant',
          style: TextStyle(fontSize: 28, fontFamily: 'serif'),
        ),
        const Text(
          'Each card and service is available once this visit. Spend now or save for later descents.',
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 330,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: Merchant.stock(catalog, run.battleSeed).length,
            separatorBuilder: (_, i) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final id = Merchant.stock(catalog, run.battleSeed)[i];
              final card = catalog.cards[id]!,
                  sold = run.purchases.contains('card:$id');
              return SizedBox(
                width: 170,
                child: Column(
                  children: [
                    Expanded(child: GameCard(card: card)),
                    FilledButton(
                      onPressed:
                          runs.busy ||
                              sold ||
                              run.gold < Merchant.price(card) ||
                              run.deck.length >= 1000
                          ? null
                          : () => runs.buyCard(id),
                      child: Text(
                        sold ? 'Sold' : 'Buy · ${Merchant.price(card)} gold',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed:
              runs.busy ||
                  run.purchases.contains('heal') ||
                  run.gold < Merchant.healingPrice ||
                  run.health == catalog.rules.maxHealth
              ? null
              : runs.merchantHeal,
          child: Text(
            run.purchases.contains('heal')
                ? 'Healing purchased'
                : 'Heal up to 15 HP · 30 gold',
          ),
        ),
        OutlinedButton(
          onPressed:
              runs.busy ||
                  run.purchases.contains('remove') ||
                  run.gold < Merchant.removalPrice ||
                  run.deck.length <= Merchant.minimumDeck
              ? null
              : () async {
                  final id = await Navigator.push<String>(
                    context,
                    MaterialPageRoute<String>(
                      builder: (_) => DeckScreen(
                        catalog: catalog,
                        deck: run.deck,
                        chooseRemoval: true,
                      ),
                    ),
                  );
                  if (id != null) await runs.removeCard(id);
                },
          child: Text(
            run.purchases.contains('remove')
                ? 'Card removal purchased'
                : 'Remove a card · 40 gold',
          ),
        ),
        const Text(
          'Keep at least five cards after merchant removal. Card removal is permanent for this journey.',
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: runs.busy ? null : runs.leaveMerchant,
          child: const Text('Leave merchant'),
        ),
      ],
    );
  }
}
