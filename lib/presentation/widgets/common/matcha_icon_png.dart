import 'package:flutter/material.dart';

class MatchaIconPng extends StatelessWidget {
  final double size;
  final Color? color;

  const MatchaIconPng({super.key, this.size = 24.0, this.color});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'lib/assets/Icon.png',
      width: size,
      height: size,
      color: color,
      colorBlendMode: color != null ? BlendMode.srcIn : null,
      fit: BoxFit.contain,
    );
  }
}
