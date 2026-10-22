import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dungeon_card.dart';

/// Flips the chosen map card in place, then carries its face to the reveal panel.
/// Saved reveals render immediately; the animation never chooses room contents.
class PathReveal extends StatefulWidget {
  const PathReveal({
    super.key,
    required this.child,
    this.origin,
    this.prepare,
    this.reducedMotion = false,
    this.fast = false,
  });
  final Widget child;
  final Rect? origin;
  final Future<void> Function()? prepare;
  final bool reducedMotion, fast;
  @override
  State<PathReveal> createState() => _PathRevealState();
}

class _PathRevealState extends State<PathReveal>
    with SingleTickerProviderStateMixin {
  final _target = GlobalKey();
  late final AnimationController _controller;
  OverlayEntry? _entry;
  bool _flying = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.fast ? 420 : 850),
    );
    _flying = widget.origin != null && !widget.reducedMotion;
    if (_flying) WidgetsBinding.instance.addPostFrameCallback((_) => _launch());
  }

  Future<void> _launch() async {
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _flying = false);
      return;
    }
    final box = _target.currentContext!.findRenderObject()! as RenderBox;
    final target = box.localToGlobal(Offset.zero) & box.size;
    _entry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: AbsorbPointer(
          child: ExcludeSemantics(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                final flip = (t / .48).clamp(0.0, 1.0);
                final grow = Curves.easeInOutCubic.transform(
                  ((t - .48) / .52).clamp(0.0, 1.0),
                );
                final rect = Rect.lerp(widget.origin!, target, grow)!;
                final back = flip < .5;
                return Stack(
                  children: [
                    Positioned.fromRect(
                      rect: rect,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, .001)
                          ..rotateY((back ? flip : flip - 1) * math.pi),
                        child: Material(
                          color: Colors.transparent,
                          child: FittedBox(
                            fit: BoxFit.fill,
                            child: SizedBox(
                              width: back ? 150 : target.width,
                              height: back ? 217 : target.height,
                              child: back
                                  ? const DungeonCard(label: 'Chosen path')
                                  : widget.child,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_entry!);
    await widget.prepare?.call();
    if (!mounted || _entry == null) return;
    _controller.forward().then((_) {
      _entry?.remove();
      _entry?.dispose();
      _entry = null;
      if (mounted) setState(() => _flying = false);
    });
  }

  @override
  void dispose() {
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: _flying,
    child: ExcludeSemantics(
      excluding: _flying,
      child: Opacity(
        key: _target,
        opacity: _flying ? 0 : 1,
        child: widget.child,
      ),
    ),
  );
}
