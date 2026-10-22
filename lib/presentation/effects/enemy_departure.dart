import 'package:flutter/material.dart';

/// Defeat is immediate in the rules; only the departing card remains briefly.
class EnemyDeparture extends StatefulWidget {
  const EnemyDeparture({
    super.key,
    required this.defeated,
    required this.child,
    required this.onDeparted,
    required this.reducedMotion,
    required this.fast,
  });
  final bool defeated, reducedMotion, fast;
  final Widget child;
  final VoidCallback onDeparted;
  @override
  State<EnemyDeparture> createState() => _EnemyDepartureState();
}

class _EnemyDepartureState extends State<EnemyDeparture>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(
        vsync: this,
        duration: Duration(
          milliseconds: widget.reducedMotion
              ? 180
              : widget.fast
              ? 210
              : 420,
        ),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDeparted();
      });
  @override
  void initState() {
    super.initState();
    if (widget.defeated) _controller.forward();
  }

  @override
  void didUpdateWidget(EnemyDeparture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.defeated && !oldWidget.defeated) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: widget.defeated,
    child: ExcludeSemantics(
      excluding: widget.defeated,
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (_, child) {
          final t = _controller.value;
          final gray = (t * 4).clamp(0.0, 1.0);
          final keep = 1 - gray;
          return Opacity(
            opacity: 1 - Curves.easeIn.transform(t),
            child: Transform.translate(
              offset: Offset(
                0,
                widget.reducedMotion ? 0 : 24 * Curves.easeIn.transform(t),
              ),
              child: ColorFiltered(
                colorFilter: ColorFilter.matrix([
                  keep + .2126 * gray,
                  .7152 * gray,
                  .0722 * gray,
                  0,
                  0,
                  .2126 * gray,
                  keep + .7152 * gray,
                  .0722 * gray,
                  0,
                  0,
                  .2126 * gray,
                  .7152 * gray,
                  keep + .0722 * gray,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                ]),
                child: child,
              ),
            ),
          );
        },
      ),
    ),
  );
}
