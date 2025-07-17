import 'package:flutter/material.dart';
import '../widgets/matcha_icon.dart';

class AppIconWidget extends StatelessWidget {
  const AppIconWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 512,
      height: 512,
      color: const Color(0xFF4CAF50), // Green background
      child: const Center(
        child: MatchaIcon(size: 400, color: Colors.white, withSteam: true),
      ),
    );
  }
}

// Helper widget for app icon generation
class MatchaAppIcon extends StatelessWidget {
  final double size;
  final bool backgroundEnabled;

  const MatchaAppIcon({
    super.key,
    this.size = 512,
    this.backgroundEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final widget = MatchaIcon(
      size: size * 0.7,
      color: backgroundEnabled ? Colors.white : const Color(0xFF4CAF50),
      withSteam: true,
    );

    if (backgroundEnabled) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xFF4CAF50),
          shape: BoxShape.circle,
        ),
        child: Center(child: widget),
      );
    }

    return widget;
  }
}
