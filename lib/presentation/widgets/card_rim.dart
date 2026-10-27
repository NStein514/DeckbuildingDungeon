import 'package:flutter/material.dart';

/// Only the ornamental rim paints over the illustration; the center stays clear.
class CardRimClipper extends CustomClipper<Path> {
  const CardRimClipper();

  @override
  Path getClip(Size size) => Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Offset.zero & size)
    ..addRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(7),
        const Radius.circular(5),
      ),
    );

  @override
  bool shouldReclip(CardRimClipper oldClipper) => false;
}
