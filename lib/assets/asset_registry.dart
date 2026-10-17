import 'package:flutter/material.dart';

/// Logical identifiers remain stable when approved illustrations are imported.
class AssetRegistry {
  static const Map<String, String> illustrations = {};
}

class GameIllustration extends StatelessWidget {
  const GameIllustration({
    super.key,
    required this.id,
    this.icon = Icons.auto_awesome,
    this.color = const Color(0xffc8a96b),
    this.height = 80,
  });
  final String id;
  final IconData icon;
  final Color color;
  final double height;
  @override
  Widget build(BuildContext context) {
    final path = AssetRegistry.illustrations[id];
    if (path != null) {
      return Image.asset(
        path,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stack) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
    height: height,
    width: double.infinity,
    decoration: BoxDecoration(
      gradient: RadialGradient(
        colors: [color.withValues(alpha: .16), const Color(0xff131b25)],
      ),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: height * .42),
        const SizedBox(height: 5),
        Text(
          'TEMP ART',
          style: TextStyle(
            fontSize: 8,
            letterSpacing: 2,
            color: color.withValues(alpha: .7),
          ),
        ),
      ],
    ),
  );
}
