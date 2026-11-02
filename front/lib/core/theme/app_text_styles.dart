import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Estilos tipográficos padronizados para o HUD Dark Neon
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle displayHero = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 44,
    height: 0.98,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle telemetryLarge = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 24,
    height: 1.05,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.6,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle currencyGiant = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 38,
    height: 1.05,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.8,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle hudBadge = TextStyle(
    color: AppColors.neonOrange,
    fontSize: 10,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.4,
  );

  static const TextStyle sectionTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.1,
  );

  static const TextStyle metricValue = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.4,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle metricLabel = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
  );

  static const TextStyle cardTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle cardSubtitle = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );
}
