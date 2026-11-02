import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/race_session.dart';

/// Banner dinâmico da Trava Anti-Cheat (> 15 km/h pausa a contagem de KM)
class AntiCheatBanner extends StatelessWidget {
  final RaceSession session;

  const AntiCheatBanner({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final isAlert = session.antiCheatTriggered;
    final accent = isAlert ? AppColors.alertRed : AppColors.cyberGreen;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isAlert
            ? AppColors.alertRed.withValues(alpha: 0.18)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isAlert
              ? AppColors.alertRed
              : AppColors.alertRed.withValues(alpha: 0.45),
          width: isAlert ? 1.6 : 1.1,
        ),
        boxShadow: isAlert
            ? [
                BoxShadow(
                  color: AppColors.alertRed.withValues(alpha: 0.28),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.alertRed.withValues(alpha: isAlert ? 0.28 : 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAlert ? Icons.warning_amber_rounded : Icons.speed_rounded,
              color: AppColors.alertRed,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      isAlert
                          ? 'ALERTA DE VEÍCULO DETECTADO!'
                          : 'TRAVA ANTI-CHEAT ATIVA',
                      style: const TextStyle(
                        color: AppColors.alertRed,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.alertRed,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'MAX 15 KM/H',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  isAlert
                      ? 'Velocidade: ${session.currentSpeedKmh.toStringAsFixed(1)} km/h • Contagem de KM PAUSADA!'
                      : 'Telemetria pedonal: ${session.currentSpeedKmh.toStringAsFixed(1)} km/h (Fair Play On)',
                  style: TextStyle(
                    color: isAlert ? Colors.white : AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: isAlert ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isAlert ? 'PAUSADO' : 'VERIFICADO',
                    style: TextStyle(
                      color: accent,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'SHIELD GPS',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
