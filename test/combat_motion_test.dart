import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/presentation/effects/combat_cue.dart';
import 'package:deckbound/presentation/effects/combat_motion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'each effect changes its rendered shape over time and clears fully',
    () async {
      final signatures = <String>{};
      final gallery = ui.PictureRecorder();
      final canvas = Canvas(gallery);
      canvas.drawColor(const Color(0xff10151c), BlendMode.src);
      for (final visual in CombatVisual.values) {
        final frames = <String>{};
        for (final t in [.18, .48, .78, 1.0]) {
          final recorder = ui.PictureRecorder();
          CombatMotionPainter(
            visual,
            t,
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
