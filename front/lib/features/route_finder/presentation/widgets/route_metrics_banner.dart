import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/drunk_route.dart';

/// Painel HUD de 3 colunas exibindo Distância Real vs Meta, Bares e Estimativa de Tempo
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
    final targetKmFormatted = route.targetDistanceKm.toStringAsFixed(
      route.targetDistanceKm.truncateToDouble() == route.targetDistanceKm
          ? 0
          : 1,
    );
    final durationUpper = route.estimatedDurationFormatted.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Coluna 1: Distância Real (ex: 9.8 KM) + Meta escolhida
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
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Text(
                        'KM',
                        style: TextStyle(
                          color: AppColors.neonOrange,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'META ${targetKmFormatted}K NAS RUAS',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(color: Color(0x24FFFFFF), width: 12),

            // Coluna 2: Quantidade de Bares
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
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        route.totalBars == 1 ? 'BAR' : 'BARES',
                        style: const TextStyle(
                          color: AppColors.cyberGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${route.availableSwapsCount} EXTRAS P/ SWAP',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(color: Color(0x24FFFFFF), width: 12),

            // Coluna 3: Estimativa de Tempo
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
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'TEMPO ESTIMADO',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
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
