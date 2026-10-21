import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'combat_cue.dart';

/// Eight painted poses per effect, with a fixed registration point. Keep the
/// decoded sheets bounded: 7 × 768 × 512 RGBA is about 10.5 MiB.
class CombatMotionAssets {
  static const columns = 4, rows = 2, frames = columns * rows;
  static final _sheets = <CombatVisual, Future<ui.Image?>>{};
  static String path(CombatVisual visual) =>
      'assets/images/effects/${visual.name}_sequence.png';

  static Future<ui.Image?> load(CombatVisual visual) =>
      _sheets.putIfAbsent(visual, () async {
        try {
          final data = await rootBundle.load(path(visual));
          final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
            targetWidth: 768,
          );
          try {
            return (await codec.getNextFrame()).image;
          } finally {
            codec.dispose();
          }
        } catch (error) {
          // Feedback labels remain available when an asset cannot be loaded.
          debugPrint('Combat artwork unavailable: ${visual.name}: $error');
          return null;
        }
      });

  static Future<void> warm() async {
    await Future.wait(CombatVisual.values.map(load));
  }
}

class CombatMotion extends StatelessWidget {
  const CombatMotion({super.key, required this.visual, required this.progress});
  final CombatVisual visual;
  final double progress;
  @override
  Widget build(BuildContext context) => FutureBuilder<ui.Image?>(
    future: CombatMotionAssets.load(visual),
    builder: (_, snapshot) => CustomPaint(
      painter: CombatMotionPainter(visual, progress, texture: snapshot.data),
      child: const SizedBox.expand(),
    ),
  );
}

/// The motion comes from changing painted frames, not transforms of one pose.
/// Premultiplied cross-dissolves soften the short intervals between poses;
/// neither the registration point nor the drawing scale moves during playback.
class CombatMotionPainter extends CustomPainter {
  CombatMotionPainter(this.visual, this.progress, {this.texture});
  final CombatVisual visual;
  final double progress;
  final ui.Image? texture;

  @override
  void paint(Canvas canvas, Size size) {
    final sheet = texture;
    if (sheet == null || progress <= 0 || progress >= 1 || size.isEmpty) return;
    final t = progress.clamp(0.0, 1.0);
    final position = t * (CombatMotionAssets.frames - 1);
    final first = position.floor();
    final next = math.min(first + 1, CombatMotionAssets.frames - 1);
    final mix = position - first;
    final width = sheet.width / CombatMotionAssets.columns;
    final height = sheet.height / CombatMotionAssets.rows;
    final extent = math.min(
      size.width * .85 * height / width,
      size.height * .82,
    );
    final destination = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * .43),
      width: extent * width / height,
      height: extent,
    );
    final opacity = math.min(1.0, math.min(t / .08, (1 - t) / .15));
    final bounds = Offset.zero & size;
    canvas.saveLayer(
      bounds,
      Paint()..color = Colors.white.withValues(alpha: opacity),
    );
    void frame(int index, double alpha, BlendMode blend) {
      if (alpha <= 0) return;
      canvas.drawImageRect(
        sheet,
        Rect.fromLTWH(
          (index % CombatMotionAssets.columns) * width,
          (index ~/ CombatMotionAssets.columns) * height,
          width,
          height,
        ).deflate(1),
        destination,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..color = Colors.white.withValues(alpha: alpha)
          ..blendMode = blend,
      );
    }

    frame(first, 1 - mix, BlendMode.srcOver);
    frame(next, mix, BlendMode.plus);
    // Feather sheet-cell boundaries so painted smoke never ends in a hard
    // rectangular edge. This mask stays fixed for the entire sequence.
    final colors = [
      Colors.transparent,
      Colors.white,
      Colors.white,
      Colors.transparent,
    ];
    const stops = [0.0, .08, .92, 1.0];
    for (final end in [destination.topRight, destination.bottomLeft]) {
      canvas.drawRect(
        destination,
        Paint()
          ..shader = ui.Gradient.linear(destination.topLeft, end, colors, stops)
          ..blendMode = BlendMode.dstIn,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(CombatMotionPainter oldDelegate) =>
      visual != oldDelegate.visual ||
      progress != oldDelegate.progress ||
      texture != oldDelegate.texture;
}
