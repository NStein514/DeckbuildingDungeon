import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/assets/asset_registry.dart';
import 'package:deckbound/presentation/widgets/room_card.dart';

void main() {
  const arts = [
    'rooms/merchant',
    'rooms/treasure',
    'rooms/shrine',
    'events/sanctuary',
    'events/emberForge',
    'events/memoryWell',
    'events/bloodAltar',
    'events/wanderingHealer',
  ];
  for (final scale in [1.0, 1.6, 2.0]) {
    testWidgets(
      'all room artworks stay inside portrait cards at text scale $scale',
      (t) async {
        t.view.physicalSize = const Size(320, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        for (final art in arts) {
          expect(AssetRegistry.illustrations.containsKey(art), isTrue);
          await t.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: RoomCardPanel(
                      title: 'The wandering healer',
                      art: art,
                      description:
                          'Pay 20 gold to restore up to 12 HP. You can leave safely.',
                    ),
                  ),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          final card = find.byType(RoomCard),
              picture = find.byType(GameIllustration);
          expect(t.getSize(card).aspectRatio, closeTo(150 / 217, .001));
          expect(t.getSize(picture).aspectRatio, closeTo(1.5, .001));
          expect(t.getCenter(picture).dx, closeTo(t.getCenter(card).dx, 1));
          final rendered = t.widget<Image>(
            find.descendant(of: picture, matching: find.byType(Image)),
          );
          expect(rendered.fit, BoxFit.contain);
          expect(find.byType(Icon), findsNothing);
          expect(t.takeException(), isNull);
        }
      },
    );
  }
}
