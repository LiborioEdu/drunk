import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/haversine_calculator.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../domain/entities/race_session.dart';

/// Card inferior de destino, distância Geofence (<= 20m) e botão de Check-in
class TargetBarProximityCard extends StatelessWidget {
  final RaceSession session;
  final VoidCallback onCheckInPressed;
  final VoidCallback onTogglePause;

  const TargetBarProximityCard({
    super.key,
    required this.session,
    required this.onCheckInPressed,
    required this.onTogglePause,
  });

  @override
  Widget build(BuildContext context) {
    final target = session.targetBar;
    if (target == null) return const SizedBox.shrink();

    final barOrder =
        target.order > 0 ? target.order : (session.completedBarsCount + 1);
    final orderLabel = barOrder.toString().padLeft(2, '0');
    final distMeters = session.distanceToTargetMeters;
    final canCheckIn = session.isWithinGeofence;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: canCheckIn
              ? AppColors.cyberGreen.withValues(alpha: 0.7)
              : AppColors.glassBorder,
          width: canCheckIn ? 1.6 : 1.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.neonOrange.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.neonOrange.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  '🚩 PRÓXIMA PARADA • BAR #$orderLabel DE ${session.totalBarsCount}',
                  style: const TextStyle(
                    color: AppColors.neonOrange,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              if (session.currentTargetTriggersHydration)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.neonCyan.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.neonCyan.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Text(
                    '💧 HIDRATAÇÃO OBRIGATÓRIA (300ML)',
                    style: TextStyle(
                      color: AppColors.neonCyan,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            target.name.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        if (canCheckIn) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            color: AppColors.cyberGreen,
                            size: 18,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      target.address != null && target.address!.isNotEmpty
                          ? '${target.address!} • Checkpoint $barOrder/${session.totalBarsCount}'
                          : 'Trecho previsto: +${HaversineCalculator.formatDistance(target.distanceFromPrevious)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Status do Radar Geofence (<= 20 metros)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: canCheckIn
                  ? AppColors.cyberGreen.withValues(alpha: 0.10)
                  : AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: canCheckIn
                    ? AppColors.cyberGreen.withValues(alpha: 0.5)
                    : AppColors.glassBorder,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (canCheckIn
                            ? AppColors.cyberGreen
                            : AppColors.neonCyan)
                        .withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    canCheckIn
                        ? Icons.sensors_rounded
                        : Icons.location_searching_rounded,
                    color:
                        canCheckIn ? AppColors.cyberGreen : AppColors.neonCyan,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        canCheckIn
                            ? 'DENTRO DO RAIO DE 20 METROS!'
                            : 'APROXIME-SE ATÉ 20M DO BAR PARA DESTRAVAR',
                        style: TextStyle(
                          color: canCheckIn
                              ? AppColors.cyberGreen
                              : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Distância Haversine atual: ${HaversineCalculator.formatDistance(distMeters)}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Linha de Ação: Check-in (destravado em <= 20m) + Pausar
          Row(
            children: [
              Expanded(
                child: NeonButton(
                  label: canCheckIn
                      ? 'FAZER CHECK-IN NO BAR #$orderLabel (${distMeters.round()}M)'
                      : 'CHECK-IN TRAVADO (${HaversineCalculator.formatDistance(distMeters)})',
                  subtitle: canCheckIn
                      ? 'Abrir comanda financeira da parada'
                      : 'Requer distância <= 20m e velocidade <= 15 km/h',
                  icon: canCheckIn
                      ? Icons.check_circle_outline_rounded
                      : Icons.lock_clock_rounded,
                  color: AppColors.cyberGreen,
                  glowColor: AppColors.cyberGreenGlow,
                  gradient: AppColors.cyberGreenGradient,
                  textColor: canCheckIn ? Colors.black : AppColors.textSecondary,
                  onPressed: canCheckIn ? onCheckInPressed : null,
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: onTogglePause,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: session.isPaused
                          ? AppColors.cyberGreen
                          : AppColors.alertRed.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        session.isPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        color: session.isPaused
                            ? AppColors.cyberGreen
                            : AppColors.alertRed,
                        size: 22,
                      ),
                      Text(
                        session.isPaused ? 'VOLTAR' : 'PAUSAR',
                        style: TextStyle(
                          color: session.isPaused
                              ? AppColors.cyberGreen
                              : AppColors.alertRed,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
