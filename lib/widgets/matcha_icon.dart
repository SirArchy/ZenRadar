import 'package:flutter/material.dart';

class MatchaIcon extends StatelessWidget {
  final double size;
  final Color? color;
  final bool
  withSteam; // Keeping for backward compatibility, but not used with PNG

  const MatchaIcon({
    super.key,
    this.size = 24.0,
    this.color,
    this.withSteam = true,
  });

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
