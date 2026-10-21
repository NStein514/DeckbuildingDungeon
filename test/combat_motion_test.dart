import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/presentation/effects/combat_cue.dart';
import 'package:deckbound/presentation/effects/combat_motion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'painted sheets contain eight distinct transparent frames and are cached',
    () async {
      for (final visual in CombatVisual.values) {
        final sheet = (await CombatMotionAssets.load(visual))!;
        expect(identical(await CombatMotionAssets.load(visual), sheet), isTrue);
        final signatures = <int>{};
        final w = sheet.width ~/ 4, h = sheet.height ~/ 2;
        for (var frame = 0; frame < 8; frame++) {
          final recorder = ui.PictureRecorder();
          Canvas(recorder).drawImageRect(
            sheet,
            Rect.fromLTWH(
              (frame % 4) * w.toDouble(),
              (frame ~/ 4) * h.toDouble(),
              w.toDouble(),
              h.toDouble(),
            ),
            Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
            Paint(),
          );
          final picture = recorder.endRecording();
          final image = await picture.toImage(w, h);
          final bytes = (await image.toByteData())!.buffer.asUint8List();
          var transparent = 0, visible = 0;
          for (var i = 3; i < bytes.length; i += 4) {
            if (bytes[i] < 8) transparent++;
            if (bytes[i] > 100) visible++;
          }
          expect(
            transparent,
            greaterThan(w * h * .05),
            reason: '${visual.name} frame $frame',
          );
          expect(
            visible,
            greaterThan(100),
            reason: '${visual.name} frame $frame',
          );
          signatures.add(Object.hashAll(bytes));
          image.dispose();
          picture.dispose();
        }
        expect(signatures, hasLength(8), reason: visual.name);
      }
    },
  );
  test(
    'each effect changes its rendered shape over time and clears fully',
    () async {
      final signatures = <String>{};
      final gallery = ui.PictureRecorder();
      final canvas = Canvas(gallery);
      canvas.drawColor(const Color(0xff10151c), BlendMode.src);
      for (final visual in CombatVisual.values) {
        final sheet = await CombatMotionAssets.load(visual);
        expect(sheet, isNotNull, reason: visual.name);
        expect(sheet!.width, 768);
        expect(sheet.height, lessThanOrEqualTo(512));
        final frames = <String>{};
        for (final t in [.18, .48, .78, 1.0]) {
          final recorder = ui.PictureRecorder();
          CombatMotionPainter(
            visual,
            t,
            texture: sheet,
          ).paint(Canvas(recorder), const Size(220, 170));
          final picture = recorder.endRecording();
          final image = await picture.toImage(220, 170);
          final bytes = (await image.toByteData())!.buffer.asUint8List();
          final occupied = <int>[];
          for (var i = 3; i < bytes.length; i += 4) {
            if (bytes[i] > 20) occupied.add(i);
          }
          if (t == 1) {
            expect(occupied, isEmpty, reason: visual.name);
          } else {
            expect(occupied, isNotEmpty, reason: visual.name);
            frames.add(occupied.join(','));
            canvas.drawImage(
              image,
              Offset(
                ([.18, .48, .78].indexOf(t)) * 220.0,
                visual.index * 170.0,
              ),
              Paint(),
            );
          }
          image.dispose();
          picture.dispose();
        }
        expect(
          frames,
          hasLength(3),
          reason: '${visual.name} must change spatial shape',
        );
        signatures.add(frames.join('|'));
      }
      expect(signatures, hasLength(CombatVisual.values.length));
      final picture = gallery.endRecording();
      final image = await picture.toImage(660, 1190);
      final output = Platform.environment['COMBAT_FRAME_GALLERY'];
      if (output != null) {
        File(output).writeAsBytesSync(
          (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List(),
        );
      }
      image.dispose();
      picture.dispose();
    },
  );
}
