import 'package:flutter/material.dart';
import 'dungeon_card.dart';

/// Additional opponents remain concealed until their own card is turned.
class PathCardStack extends StatefulWidget {
  const PathCardStack({
    super.key,
    required this.count,
    required this.cardBuilder,
    required this.onRevealed,
    required this.reducedMotion,
  });
  final int count;
  final Widget Function(int) cardBuilder;
  final ValueChanged<int> onRevealed;
  final bool reducedMotion;
  @override
  State<PathCardStack> createState() => _PathCardStackState();
}

class _PathCardStackState extends State<PathCardStack> {
  int revealed = 1;
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void reveal() {
    setState(() => revealed++);
    widget.onRevealed(revealed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (widget.reducedMotion) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      } else {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final width = bounds.maxWidth.clamp(0.0, 320.0);
      final height = width * 217 / 150;
      Widget face(int index) => SizedBox(
        width: width,
        height: height,
        child: index == 0
            ? widget.cardBuilder(index)
            : DungeonCard(
                label: 'Opponent ${index + 1}',
                flip: true,
                reducedMotion: widget.reducedMotion,
                front: widget.cardBuilder(index),
              ),
      );
      final hidden = revealed < widget.count;
      return SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: bounds.maxWidth),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var index = 0; index < revealed; index++) ...[
                if (index > 0) const SizedBox(width: 12),
                if (hidden && index == revealed - 1)
                  SizedBox(
                    width: width + 24,
                    height: height + 48,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 24,
                          top: 32,
                          width: width,
                          height: height,
                          child: DungeonCard(
                            label: 'Unrevealed opponent',
                            onTap: reveal,
                          ),
                        ),
                        Positioned(left: 0, top: 0, child: face(index)),
                        Positioned(
                          left: 24,
                          right: 0,
                          bottom: 0,
                          child: FilledButton.tonal(
                            onPressed: reveal,
                            child: const Text('Reveal next opponent'),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  face(index),
              ],
            ],
          ),
        ),
      );
    },
  );
}
