import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/presentation/widgets/path_reveal.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets('chosen card flies once and settles; reduced motion=$reduced', (
      t,
    ) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                height: 400,
                child: PathReveal(
                  origin: const Rect.fromLTWH(24, 500, 150, 217),
                  reducedMotion: reduced,
                  child: const ColoredBox(
                    color: Colors.red,
                    child: Text('Revealed room'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await t.pump();
      if (!reduced) {
        expect(find.text('Chosen path'), findsOneWidget);
        await t.pump(const Duration(milliseconds: 220));
        expect(find.byType(Transform), findsWidgets);
      }
      await t.pumpAndSettle();
      expect(find.text('Chosen path'), findsNothing);
      expect(find.text('Revealed room'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('flight waits for portrait readiness before starting', (t) async {
    final ready = Completer<void>();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 400,
            child: PathReveal(
              origin: const Rect.fromLTWH(0, 400, 150, 217),
              prepare: () => ready.future,
              child: const Text('Room'),
            ),
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 900));
    expect(find.text('Chosen path'), findsOneWidget);
    ready.complete();
    await t.pump();
    await t.pump();
    expect(find.text('Chosen path'), findsOneWidget);
    await t.pumpAndSettle();
    expect(find.text('Chosen path'), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('disposing during flight removes the overlay safely', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 400,
            child: PathReveal(
              origin: Rect.fromLTWH(0, 400, 150, 217),
              child: Text('Room'),
            ),
          ),
        ),
      ),
    );
    await t.pump();
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
