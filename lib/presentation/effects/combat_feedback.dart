import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'combat_cue.dart';

Duration combatFeedbackDuration({required bool reduced, required bool fast}) =>
    Duration(
      milliseconds: reduced
          ? 180
          : fast
          ? 180
          : 420,
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
                      final fade = widget.reducedMotion
                          ? 1.0
                          : (1 - t).clamp(0.0, 1.0);
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          if (!widget.reducedMotion)
                            for (var i = 0; i < cues.length; i++)
                              Opacity(
                                opacity: fade,
                                child: Transform.translate(
                                  offset: Offset(
                                    (i - (cues.length - 1) / 2) * 36,
                                    cues[i].visual == CombatVisual.healing
                                        ? -20 * t
                                        : 0,
                                  ),
                                  child: Transform.rotate(
                                    angle: cues[i].visual == CombatVisual.slash
                                        ? -.25 + t * .5
                                        : 0,
                                    child: Transform.scale(
                                      scale:
                                          .65 +
                                          Curves.easeOut.transform(t) * .65,
                                      child: _EffectSprite(
                                        visual: cues[i].visual,
                                      ),
                                    ),
                                  ),
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

/// Six generated atlas cells. Arcane reuses the healing rune tinted lavender.
class _EffectSprite extends StatelessWidget {
  const _EffectSprite({required this.visual});
  final CombatVisual visual;
  @override
  Widget build(BuildContext context) {
    final cell = visual == CombatVisual.arcane ? 5 : visual.index;
    return SizedBox.square(
      dimension: 136,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment((cell % 3) - 1.0, cell < 3 ? -1 : 1),
          maxWidth: 408,
          minWidth: 408,
          maxHeight: 272,
          minHeight: 272,
          child: Image.asset(
            'assets/images/effects/combat_atlas.png',
            width: 408,
            height: 272,
            fit: BoxFit.fill,
            color: visual == CombatVisual.arcane
                ? const Color(0xffbba3de)
                : null,
            colorBlendMode: BlendMode.modulate,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
