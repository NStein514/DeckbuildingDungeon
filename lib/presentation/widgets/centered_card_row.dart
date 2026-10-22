import 'package:flutter/material.dart';

/// Keeps card sizes intact, centering short rows and scrolling longer ones.
class CenteredCardRow extends StatelessWidget {
  const CenteredCardRow({super.key, required this.children, this.gap = 8});
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: constraints.maxWidth),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                children[i],
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
