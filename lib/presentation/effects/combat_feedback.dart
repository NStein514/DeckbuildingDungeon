import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'combat_cue.dart';
import 'combat_motion.dart';

Duration combatFeedbackDuration({required bool reduced, required bool fast}) =>
    Duration(
      milliseconds: reduced
          ? 180
          : fast
          ? 240
          : 480,
    );

/// Local, non-interactive bursts remain anchored while the battle scrolls.
class CombatFeedback extends StatefulWidget {
  const CombatFeedback({
    super.key,
    required this.cues,
    required this.child,
    required this.reducedMotion,
    required this.fastAnimations,
  });
  final List<CombatCue> cues;
  final Widget child;
  final bool reducedMotion, fastAnimations;
  @override
  State<CombatFeedback> createState() => _CombatFeedbackState();
}

class _CombatFeedbackState extends State<CombatFeedback>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: duration,
  );
  Duration get duration => combatFeedbackDuration(
    reduced: widget.reducedMotion,
    fast: widget.fastAnimations,
  );
  @override
  void initState() {
    super.initState();
    if (widget.cues.isNotEmpty) controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(CombatFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    controller.duration = duration;
    if (widget.cues.isNotEmpty &&
        (oldWidget.cues.isEmpty ||
            oldWidget.cues.last.sequence != widget.cues.last.sequence)) {
      controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    controller.duration = duration;
    final cues = widget.cues.length > 3
        ? widget.cues.sublist(widget.cues.length - 3)
        : widget.cues;
    final visuals = cues.map((c) => c.visual).toSet();
    if (visuals.length > 1) visuals.remove(CombatVisual.arcane);
    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          widget.child,
          if (cues.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: AnimatedBuilder(
                    animation: controller,
                    builder: (_, _) {
                      if (controller.isCompleted) {
                        return const SizedBox.shrink();
                      }
                      final t = controller.value;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          if (!widget.reducedMotion)
                            for (final visual in visuals)
                              Positioned.fill(
                                child: CombatMotion(
                                  visual: visual,
                                  progress: t,
                                ),
                              ),
                          Align(
                            alignment: const Alignment(0, .55),
                            child: Opacity(
                              opacity: widget.reducedMotion
                                  ? 1
                                  : math.min(1, (1 - t) * 3),
                              child: Container(
                                key: const ValueKey('combat-feedback-label'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xee10151c),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xffc8a96b),
                                  ),
                                ),
                                child: Text(
                                  cues.map((c) => c.label).join(' · '),
                                  maxLines: 3,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xffebdfc5),
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
        ],
      ),
    );
  }
}
