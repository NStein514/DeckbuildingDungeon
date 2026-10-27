import 'package:flutter/material.dart';
import '../../assets/asset_registry.dart';
import 'card_rim.dart';

/// A room's complete illustration stays inside the same gold rim as deck cards.
class RoomCard extends StatelessWidget {
  const RoomCard({
    super.key,
    required this.title,
    required this.art,
    required this.description,
  });
  final String title, art, description;
  static const titleStyle = TextStyle(
    fontFamily: 'serif',
    fontSize: 20,
    color: Color(0xffffe4aa),
  );
  static const bodyStyle = TextStyle(fontSize: 14, height: 1.35);

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xff181c21),
      image: const DecorationImage(
        image: AssetImage('assets/images/ui/card_frame.png'),
        fit: BoxFit.fill,
      ),
      borderRadius: BorderRadius.circular(12),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: const EdgeInsets.all(5),
            child: LayoutBuilder(
              builder: (context, bounds) {
                double textHeight(String text, TextStyle style, double inset) {
                  final painter =
                      TextPainter(
                        text: TextSpan(
                          text: text,
                          style: DefaultTextStyle.of(
                            context,
                          ).style.merge(style),
                        ),
                        textDirection: Directionality.of(context),
                        textScaler: MediaQuery.textScalerOf(context),
                      )..layout(
                        maxWidth: (bounds.maxWidth - inset).clamp(
                          1,
                          double.infinity,
                        ),
                      );
                  final height = painter.height;
                  painter.dispose();
                  return height;
                }

                final header = Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xdd5c4225), Color(0xee201810)],
                    ),
                    border: Border(
                      bottom: BorderSide(color: Color(0xffb59454)),
                    ),
                  ),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: titleStyle,
                  ),
                );
                final picture = AspectRatio(
                  aspectRatio: 3 / 2,
                  child: GameIllustration(id: art, height: null),
                );
                final body = Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Text(
                    description,
                    textAlign: TextAlign.center,
                    style: bodyStyle,
                  ),
                );
                final needed =
                    textHeight(title, titleStyle, 28) +
                    24 +
                    bounds.maxWidth / 1.5 +
                    textHeight(description, bodyStyle, 36) +
                    28;
                if (needed > bounds.maxHeight) {
                  return SingleChildScrollView(
                    child: Column(children: [header, picture, body]),
                  );
                }
                return Column(
                  children: [
                    header,
                    picture,
                    Expanded(child: Center(child: body)),
                  ],
                );
              },
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: ClipPath(
                clipper: const CardRimClipper(),
                child: Image.asset(
                  'assets/images/ui/card_frame.png',
                  cacheWidth: 768,
                  fit: BoxFit.fill,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Room action screens use the same portrait proportions as their reveal.
class RoomCardPanel extends StatelessWidget {
  const RoomCardPanel({
    super.key,
    required this.title,
    required this.art,
    required this.description,
  });
  final String title, art, description;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: AspectRatio(
        aspectRatio: 150 / 217,
        child: RoomCard(title: title, art: art, description: description),
      ),
    ),
  );
}
