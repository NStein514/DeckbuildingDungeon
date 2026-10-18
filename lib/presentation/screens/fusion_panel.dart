import 'package:flutter/material.dart';
import '../../app/run_controller.dart';
import '../../game/cards/upgrades.dart';
import '../../game/data/game_catalog.dart';
import '../../game/fusion/fusion.dart';
import '../../game/models/models.dart';
import '../../game/progression/run_state.dart';
import '../widgets/game_card.dart';

class FusionPanel extends StatefulWidget {
  const FusionPanel({
    super.key,
    required this.runs,
    required this.catalog,
    required this.run,
    required this.reducedMotion,
  });
  final RunController runs;
  final GameCatalog catalog;
  final RunState run;
  final bool reducedMotion;
  @override
  State<FusionPanel> createState() => _FusionPanelState();
}

class _FusionPanelState extends State<FusionPanel> {
  String? first, second;
  bool confirming = false;
  String label(CardInstance c) {
    final copies = widget.run.deck
        .where((x) => x.definitionId == c.definitionId)
        .toList();
    final name = resolveCard(widget.catalog.cards[c.definitionId]!, c).name;
    return copies.length == 1
        ? name
        : '$name · copy ${copies.indexWhere((x) => x.id == c.id) + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.run.deck.where((c) => c.id == first).firstOrNull;
    final b = widget.run.deck.where((c) => c.id == second).firstOrNull;
    final recipe = a == null || b == null
        ? null
        : fusionRecipes.where((r) => r.matches(a, b)).firstOrNull;
    final disabled = widget.runs.busy || confirming;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.auto_fix_high, size: 64, color: Color(0xffc8a96b)),
        const Text(
          'The fusion shrine',
          style: TextStyle(fontSize: 28, fontFamily: 'serif'),
        ),
        const SizedBox(height: 12),
        const Text(
          'Combine two cards permanently. One fusion per shrine. Source upgrades are consumed; the result starts unupgraded.',
        ),
        const SizedBox(height: 16),
        for (final isFirst in [true, false])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              initialValue: isFirst ? first : second,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: isFirst ? 'First card' : 'Second card',
              ),
              items: widget.run.deck
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(label(c), overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: disabled
                  ? null
                  : (value) => setState(() {
                      if (isFirst) {
                        first = value;
                      } else {
                        second = value;
                      }
                    }),
            ),
          ),
        AnimatedSwitcher(
          duration: widget.reducedMotion
              ? Duration.zero
              : const Duration(milliseconds: 250),
          child: recipe == null
              ? Text(
                  first == null || second == null
                      ? 'Choose two cards to preview a fusion.'
                      : 'No recipe matches these two distinct cards.',
                  key: const ValueKey('empty'),
                )
              : Column(
                  key: ValueKey(recipe.result),
                  children: [
                    const Text('RESULT'),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 190,
                      height: 280,
                      child: GameCard(
                        card: widget.catalog.cards[recipe.result]!,
                        reducedMotion: widget.reducedMotion,
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: disabled || recipe == null
              ? null
              : () async {
                  setState(() => confirming = true);
                  final accepted = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Fuse these cards?'),
                      content: Text(
                        'Remove ${label(a!)} and ${label(b!)}. Add ${widget.catalog.cards[recipe.result]!.name}. This choice is permanent for this journey.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Confirm fusion'),
                        ),
                      ],
                    ),
                  );
                  if (!mounted) return;
                  if (accepted == true) await widget.runs.fuse(a!.id, b!.id);
                  if (mounted) setState(() => confirming = false);
                },
          child: const Text('Fuse cards'),
        ),
        TextButton(
          onPressed: disabled ? null : widget.runs.skipShrine,
          child: const Text('Leave shrine'),
        ),
      ],
    );
  }
}
