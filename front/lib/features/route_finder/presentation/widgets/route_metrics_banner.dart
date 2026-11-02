import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/drunk_route.dart';

/// Painel HUD de 3 colunas fiel ao Stitch IA (`01_route_finder`): 10.2 KM | 10 BARES | 1H 58M
class RouteMetricsBanner extends StatelessWidget {
  final DrunkRoute route;
  final VoidCallback? onResetRoute;

  const RouteMetricsBanner({
    super.key,
    required this.route,
    this.onResetRoute,
  });

  @override
  Widget build(BuildContext context) {
    final kmNum = (route.totalDistanceMeters / 1000.0).toStringAsFixed(1);
    final durationUpper = route.estimatedDurationFormatted.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Coluna 1: 10.2 KM
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        kmNum,
                        style: const TextStyle(
                          color: AppColors.neonOrange,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Text(
                        'KM',
                        style: TextStyle(
                          color: AppColors.neonOrange,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'DISTÂNCIA REAL',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(color: Color(0x24FFFFFF), width: 12),

            // Coluna 2: 10 BARES
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${route.totalBars}',
                        style: const TextStyle(
                          color: AppColors.cyberGreen,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'BARES',
                        style: TextStyle(
                          color: AppColors.cyberGreen,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'CHECKPOINTS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(color: Color(0x24FFFFFF), width: 12),

            // Coluna 3: 1H 58M
            Expanded(
              child: GestureDetector(
                onTap: onResetRoute,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        durationUpper,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'ESTIMATIVA TOTAL',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
