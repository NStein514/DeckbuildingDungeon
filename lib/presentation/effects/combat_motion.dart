import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'combat_cue.dart';

// One shared texture decode. Generated art supplies moving particle detail;
// silhouettes, trajectories, trails and emission timing are drawn each frame.
final Future<ui.Image> _texture = () async {
  final data = await rootBundle.load('assets/images/effects/combat_atlas.png');
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}();

class CombatMotion extends StatelessWidget {
  const CombatMotion({super.key, required this.visual, required this.progress});
  final CombatVisual visual;
  final double progress;
  @override
  Widget build(BuildContext context) => FutureBuilder<ui.Image>(
    future: _texture,
    builder: (_, snapshot) => CustomPaint(
      painter: CombatMotionPainter(visual, progress, texture: snapshot.data),
      child: const SizedBox.expand(),
    ),
  );
}

class CombatMotionPainter extends CustomPainter {
  CombatMotionPainter(this.visual, this.progress, {this.texture});
  final CombatVisual visual;
  final double progress;
  final ui.Image? texture;
  double unit(double x) => x.clamp(0.0, 1.0);
  Offset polar(double angle, double radius) =>
      Offset(math.cos(angle) * radius, math.sin(angle) * radius);

  @override
  void paint(Canvas canvas, Size size) {
    final t = unit(progress);
    if (t <= 0 || t >= 1) return;
    canvas.save();
    canvas.translate(size.width / 2, size.height * .43);
    final scale = math.min(size.width / 220, size.height / 170);
    canvas.scale(scale);
    final fade = unit((1 - t) / .22);
    final color = switch (visual) {
      CombatVisual.slash => const Color(0xffffd897),
      CombatVisual.shield => const Color(0xff8ee7ff),
      CombatVisual.fire => const Color(0xffff993c),
      CombatVisual.lightning => const Color(0xffd0b4ff),
      CombatVisual.poison => const Color(0xffb4df67),
      CombatVisual.healing => const Color(0xff9bf2cb),
      CombatVisual.arcane => const Color(0xffc9abfa),
    };
    Paint ink(double opacity, {double width = 2, bool fill = false}) => Paint()
      ..color = color.withValues(alpha: unit(opacity) * fade)
      ..style = fill ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void line(Offset a, Offset b, {double alpha = 1, double width = 2}) =>
        canvas.drawLine(a, b, ink(alpha, width: width));
    void glow(Offset p, double radius, double opacity) {
      canvas.drawCircle(
        p,
        radius * 2,
        Paint()
          ..shader = ui.Gradient.radial(p, radius * 2, [
            color.withValues(alpha: unit(opacity) * fade * .5),
            color.withValues(alpha: 0),
          ]),
      );
      canvas.drawCircle(p, radius, ink(opacity, fill: true));
    }

    void detail(Offset p, int cell, double radius, double alpha) {
      if (texture == null) return;
      final w = texture!.width / 3, h = texture!.height / 2;
      canvas.drawImageRect(
        texture!,
        Rect.fromLTWH((cell % 3) * w, (cell ~/ 3) * h, w, h),
        Rect.fromCircle(center: p, radius: radius),
        Paint()..color = Colors.white.withValues(alpha: unit(alpha) * fade),
      );
    }

    void trace(Path path, double start, double end, double width) {
      final metric = path.computeMetrics().first;
      final segment = metric.extractPath(
        metric.length * unit(start),
        metric.length * unit(end),
      );
      canvas.drawPath(segment, ink(.18, width: width + 8));
      canvas.drawPath(segment, ink(1, width: width));
    }

    switch (visual) {
      case CombatVisual.slash:
        final path = Path()
          ..moveTo(-85, 48)
          ..quadraticBezierTo(-8, -68, 84, -30);
        final head = unit(t / .62), tail = unit((t - .27) / .65);
        trace(path, tail, head, 4.5);
        final metric = path.computeMetrics().first;
        final tip = metric.getTangentForOffset(metric.length * head)!.position;
        glow(tip, 3, 1);
        if (t > .44) {
          final burst = unit((t - .44) / .56);
          for (var i = 0; i < 9; i++) {
            final a = polar(i * 2.399, burst * 47);
            line(
              const Offset(42, -20) + a * .65,
              const Offset(42, -20) + a,
              alpha: 1 - burst,
              width: 1.6,
            );
          }
        }
      case CombatVisual.shield:
        final outline = Path()
          ..moveTo(0, -62)
          ..lineTo(47, -41)
          ..lineTo(40, 14)
          ..quadraticBezierTo(32, 44, 0, 61)
          ..quadraticBezierTo(-32, 44, -40, 14)
          ..lineTo(-47, -41)
          ..close();
        trace(outline, 0, unit(t / .48), 2.8);
        if (t > .35) {
          canvas.drawPath(outline, ink(.12, fill: true));
          final wave = unit((t - .35) / .65);
          for (var i = 0; i < 3; i++) {
            canvas.drawArc(
              Rect.fromCircle(
                center: Offset.zero,
                radius: 42 + wave * 33 + i * 5,
              ),
              -math.pi / 2 + i * 2.1 + wave,
              .8,
              false,
              ink((1 - wave) * .8, width: 2),
            );
          }
          line(const Offset(-32, -26), const Offset(0, -42), alpha: wave);
          line(const Offset(0, -42), const Offset(32, -26), alpha: wave);
          line(const Offset(0, -42), const Offset(0, 36), alpha: wave);
        }
      case CombatVisual.fire:
        final flight = unit(t / .43);
        final head = Offset(
          -83 * (1 - flight),
          37 * (1 - flight) - math.sin(flight * math.pi) * 25,
        );
        if (t < .58) {
          for (var i = 10; i >= 0; i--) {
            final p = unit(flight - i * .045);
            glow(
              Offset(-83 * (1 - p), 37 * (1 - p) - math.sin(p * math.pi) * 25),
              2 + i * .15,
              (1 - i / 12) * unit((.58 - t) / .15),
            );
          }
          detail(head, 2, 24, unit((.58 - t) / .15));
        }
        for (var i = 0; i < 18; i++) {
          final age = (t - .32 - (i % 4) * .035) / .62;
          if (age <= 0 || age >= 1) continue;
          final angle = i * 2.399;
          final p =
              polar(angle, age * (35 + i % 5 * 7)) +
              Offset(math.sin(age * 8 + i) * 8, -age * age * 44);
          final path = Path()
            ..moveTo(p.dx, p.dy + 12 * (1 - age))
            ..quadraticBezierTo(
              p.dx - 9,
              p.dy - 4,
              p.dx + math.sin(age * 9 + i) * 9,
              p.dy - 20 * (1 - age),
            );
          canvas.drawPath(path, ink(1 - age, width: 3));
          glow(p, 2.5 * (1 - age), 1 - age);
          if (i % 5 == 0) detail(p, 2, 13, 1 - age);
        }
      case CombatVisual.lightning:
        final frame = (t * 12).floor();
        final points = [
          for (var i = 0; i < 9; i++)
            Offset(
              -34 +
                  i * 8 +
                  math.sin(i * 19 + frame * 5) * ((i == 0 || i == 8) ? 0 : 14),
              -74 + i * 17.0,
            ),
        ];
        final head = unit(t / .34) * 8;
        for (var i = 0; i < 8; i++) {
          if (head <= i) break;
          final end = Offset.lerp(points[i], points[i + 1], unit(head - i))!;
          line(points[i], end, alpha: .22, width: 9);
          line(points[i], end, alpha: 1, width: 2.3);
          if (i > 1 && i % 2 == 0 && head > i + 1) {
            final branch = points[i] + Offset(i % 4 == 0 ? 34 : -34, 16);
            line(points[i], branch, alpha: .8, width: 1.4);
            line(branch, branch + const Offset(7, 19), alpha: .55, width: 1);
          }
        }
        if (t > .3) {
          final age = unit((t - .3) / .7);
          canvas.drawArc(
            Rect.fromCircle(
              center: const Offset(30, 40),
              radius: 10 + age * 34,
            ),
            age * 5,
            4,
            false,
            ink(1 - age, width: 1.5),
          );
        }
      case CombatVisual.poison:
        for (var i = 0; i < 14; i++) {
          final age = (t - (i % 5) * .055) / .74;
          if (age <= 0 || age >= 1) continue;
          final p = Offset(
            math.sin(i * 2.4) * 49 + math.sin(age * 5 + i) * 13,
            43 - age * (69 + i % 4 * 8),
          );
          final radius = 4 + i % 4 * 2.0;
          if (age < .68) {
            canvas.drawCircle(p, radius, ink(.14, fill: true));
            canvas.drawCircle(p, radius, ink(.85, width: 1.5));
            glow(p + Offset(-radius * .3, -radius * .3), 1, .8);
          } else {
            final pop = (age - .68) / .32;
            for (var j = 0; j < 4; j++) {
              final q = p + polar(j * math.pi / 2, pop * 13 + radius);
              glow(q, 1.8 * (1 - pop), 1 - pop);
            }
          }
        }
      case CombatVisual.healing:
        for (var i = 0; i < 12; i++) {
          final age = unit((t - (i % 3) * .04) / .82);
          final a = i * math.pi / 6 + age * 1.6;
          final p = polar(a, 63 * (1 - age)) + Offset(0, 18 - age * 36);
          glow(p, 2.5, math.sin(age * math.pi));
          line(
            p,
            p + polar(a + .3, 9),
            alpha: math.sin(age * math.pi) * .55,
            width: 1,
          );
        }
        final rise = unit((t - .28) / .6);
        final center = Offset(0, 12 - rise * 35);
        if (t > .28) {
          line(
            center + const Offset(-10, 0),
            center + const Offset(10, 0),
            alpha: math.sin(rise * math.pi),
            width: 3,
          );
          line(
            center + const Offset(0, -10),
            center + const Offset(0, 10),
            alpha: math.sin(rise * math.pi),
            width: 3,
          );
          detail(center, 5, 23, math.sin(rise * math.pi) * .5);
        }
      case CombatVisual.arcane:
        for (var i = 0; i < 3; i++) {
          final age = unit(t / .85);
          final p = polar(i * math.pi * 2 / 3 + age * 3.4, 48 * (1 - age));
          canvas.save();
          canvas.translate(p.dx, p.dy);
          canvas.rotate(age * 2 + i * .6);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(-9, -14, 18, 28),
              const Radius.circular(3),
            ),
            ink(.85, width: 1.8),
          );
          line(const Offset(-4, -4), const Offset(4, -4), alpha: .7, width: 1);
          line(const Offset(-4, 3), const Offset(3, 3), alpha: .7, width: 1);
          canvas.restore();
        }
        for (var i = 0; i < 6; i++) {
          final p = polar(i * math.pi / 3 - t * 2, 22 + t * 30);
          glow(p, 1.7, math.sin(t * math.pi));
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(CombatMotionPainter oldDelegate) =>
      visual != oldDelegate.visual ||
      progress != oldDelegate.progress ||
      texture != oldDelegate.texture;
}
