import 'package:flutter/material.dart';

/// Paleta de cores oficial do Design System DRUNK (Dark Neon HUD)
class AppColors {
  AppColors._();

  // Background & Surfaces
  static const Color background = Color(0xFF0E0E11);
  static const Color surface = Color(0xFF17171C);
  static const Color surfaceCard = Color(0xFF1F1F27);
  static const Color surfaceLight = Color(0xFF2A2A35);

  // Neon Brand Accents
  static const Color neonOrange = Color(0xFFFF5E00);
  static const Color neonOrangeLight = Color(0xFFFF8533);
  static const Color neonOrangeGlow = Color(0x66FF5E00);

  static const Color cyberGreen = Color(0xFF00FF66);
  static const Color cyberGreenDark = Color(0xFF00CC52);
  static const Color cyberGreenGlow = Color(0x6600FF66);

  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color neonCyanGlow = Color(0x6600E5FF);

  static const Color neonPurple = Color(0xFFB829FF);
  static const Color alertRed = Color(0xFFFF3366);

  // Typography Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA8A8B3);
  static const Color textMuted = Color(0xFF686875);

  // Glassmorphism
  static const Color glassBackground = Color(0xD915151B);
  static const Color glassBorder = Color(0x29FFFFFF);
  static const Color glassHighlight = Color(0x14FFFFFF);

  // Gradients
  static const LinearGradient neonOrangeGradient = LinearGradient(
    colors: [Color(0xFFFF5E00), Color(0xFFFF2A00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyberGreenGradient = LinearGradient(
    colors: [Color(0xFF00FF66), Color(0xFF00C853)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
