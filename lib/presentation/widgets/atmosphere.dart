import 'package:flutter/material.dart';

/// Visual themes follow floor position only; they never reveal room contents.
class FloorAtmosphere {
  static const names = [
    'The threshold',
    'The sunken cistern',
    'The sealed archive',
    'The ember forge',
    'The rooted vault',
    'The guardian hall',
  ];
  static const files = [
    'threshold',
    'cistern',
    'archive',
    'forge',
    'roots',
    'guardian',
  ];
  static String asset(int depth) =>
      'assets/images/backgrounds/${files[depth % files.length]}.png';
}

/// Artwork stays at the edges; the center is a quiet surface for game content.
class Atmosphere extends StatelessWidget {
  const Atmosphere({
    super.key,
    required this.child,
    this.depth = 0,
    this.floorPanel = false,
  });
  final Widget child;
  final int depth;
  final bool floorPanel;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xff10151c),
                image: DecorationImage(
                  image: ResizeImage(
                    AssetImage(FloorAtmosphere.asset(depth)),
                    width: 1024,
                  ),
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.topCenter,
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, .3, .65, 1],
                    colors: floorPanel
                        ? const [
                            Color(0x3010151c),
                            Color(0xd910151c),
                            Color(0xf510151c),
                            Color(0xff10151c),
                          ]
                        : const [
                            Color(0x7010151c),
                            Color(0xe610151c),
                            Color(0xf010151c),
                            Color(0xf510151c),
                          ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      child,
    ],
  );
}

class AtmosphericScaffold extends StatelessWidget {
  const AtmosphericScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.depth = 2,
  });
  final PreferredSizeWidget? appBar;
  final Widget body;
  final int depth;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: appBar,
    body: Atmosphere(
      depth: depth,
      child: SizedBox.expand(child: body),
    ),
  );
}

class FloorSurface extends StatelessWidget {
  const FloorSurface({super.key, required this.depth, required this.child});
  final int depth;
  final Widget child;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: Atmosphere(
      depth: depth,
      floorPanel: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 64,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    FloorAtmosphere.names[depth % 6],
                    style: const TextStyle(
                      fontFamily: 'serif',
                      fontSize: 19,
                      color: Color(0xffebdfc5),
                      shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                    ),
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    ),
  );
}
