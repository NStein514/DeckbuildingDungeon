import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/presentation/widgets/centered_card_row.dart';

void main() {
  testWidgets(
    'centers short rows and scrolls four full-size cards without wrapping',
    (t) async {
      Future<void> show(int count) async {
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 390,
                  height: 225,
                  child: CenteredCardRow(
                    children: List.generate(
                      count,
                      (i) =>
                          SizedBox(key: ValueKey(i), width: 150, height: 217),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
      }

      await show(1);
      final row = t.getRect(find.byType(CenteredCardRow));
      expect(t.getRect(find.byKey(const ValueKey(0))).center.dx, row.center.dx);
      await show(4);
      final first = t.getRect(find.byKey(const ValueKey(0)));
      final last = t.getRect(find.byKey(const ValueKey(3)));
      expect(first.size, const Size(150, 217));
      expect(last.size, first.size);
      expect(last.top, first.top);
      expect(last.right, greaterThan(row.right));
      await t.drag(find.byType(CenteredCardRow), const Offset(-450, 0));
      await t.pumpAndSettle();
      expect(
        t.getRect(find.byKey(const ValueKey(3))).right,
        lessThanOrEqualTo(row.right),
      );
      expect(t.takeException(), isNull);
    },
  );
}
