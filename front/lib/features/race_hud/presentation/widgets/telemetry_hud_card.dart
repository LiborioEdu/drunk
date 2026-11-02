import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/race_session.dart';

/// Painel HUD de Telemetria (Distância 10K, Barra de 10 Checkpoints, Velocidade, Pace e Comanda)
class TelemetryHudCard extends StatelessWidget {
  final RaceSession session;

  const TelemetryHudCard({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final currentStep =
        (session.completedBarsCount + 1).clamp(1, session.totalBarsCount);
    final pct = session.totalBarsCount == 0
        ? 0
        : ((session.completedBarsCount / session.totalBarsCount) * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho Distância Total vs Etapa
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.straighten_rounded,
                          color: AppColors.neonOrange,
                          size: 14,
                        ),
                        SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'DISTÂNCIA TOTAL PERCORRIDA',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: 6,
                      children: [
                        Text(
                          session.validatedDistanceKm.toStringAsFixed(2),
                          style: AppTextStyles.displayHero,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '/ ${session.plannedDistanceKm.toStringAsFixed(1)} KM',
                            style: const TextStyle(
                              color: AppColors.neonOrange,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'STATUS ETAPA',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.neonOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.neonOrange.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Text(
                      '● ETAPA $currentStep / ${session.totalBarsCount}',
                      style: const TextStyle(
                        color: AppColors.neonOrange,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Régua de Progresso dos 10 Bares
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'ROTA DOS ${session.totalBarsCount} BARES '
                  '(${session.completedBarsCount} CONCLUÍDOS)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Text(
                '$pct% CONCLUÍDO',
                style: const TextStyle(
                  color: AppColors.cyberGreen,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (int i = 0; i < session.totalBarsCount; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: _BarStepChip(
                    order: i + 1,
                    isCompleted: i < session.completedBarsCount,
                    isActive: i == session.completedBarsCount,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // 3 Pods de Telemetria: Velocidade, Pace e Comanda
          Row(
            children: [
              Expanded(
                child: _TelemetryPod(
                  icon: Icons.bolt_rounded,
                  iconColor: session.antiCheatTriggered
                      ? AppColors.alertRed
                      : AppColors.neonCyan,
                  label: 'VELOCIDADE',
                  value: session.currentSpeedKmh.toStringAsFixed(1),
                  unit: 'KM/H',
                  footer: session.antiCheatTriggered
                      ? 'ACIMA 15 KM/H'
                      : 'RITMO SEGURO',
                  footerColor: session.antiCheatTriggered
                      ? AppColors.alertRed
                      : AppColors.cyberGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TelemetryPod(
                  icon: Icons.directions_run_rounded,
                  iconColor: AppColors.neonOrange,
                  label: 'PACE MÉDIO',
                  value: session.averagePaceFormatted,
                  unit: '/KM',
                  footer: 'TEMPO ${session.elapsedFormatted}',
                  footerColor: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TelemetryPod(
                  icon: Icons.sports_bar_rounded,
                  iconColor: AppColors.cyberGreen,
                  label: 'COMANDA',
                  value: RaceSession.formatBrl(session.totalSpentBrl),
                  valueColor: AppColors.cyberGreen,
                  unit: '',
                  footer: '${session.completedBarsCount} PARADAS REG.',
                  footerColor: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarStepChip extends StatelessWidget {
  final int order;
  final bool isCompleted;
  final bool isActive;

  const _BarStepChip({
    required this.order,
    required this.isCompleted,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isCompleted
        ? AppColors.cyberGreen.withValues(alpha: 0.16)
        : (isActive
            ? AppColors.neonOrange.withValues(alpha: 0.22)
            : AppColors.surfaceCard);
    final border = isCompleted
        ? AppColors.cyberGreen
        : (isActive ? AppColors.neonOrange : AppColors.glassBorder);

    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: border,
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: Center(
        child: isCompleted
            ? const Icon(
                Icons.check_rounded,
                color: AppColors.cyberGreen,
                size: 14,
              )
            : Text(
                order.toString().padLeft(2, '0'),
                style: TextStyle(
                  color: isActive ? AppColors.neonOrange : AppColors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );
  }
}

class _TelemetryPod extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;
  final String unit;
  final String footer;
  final Color footerColor;

  const _TelemetryPod({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
    required this.unit,
    required this.footer,
    required this.footerColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 13),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: AppTextStyles.telemetryLarge.copyWith(
                    color: valueColor,
                    fontSize: 19,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 2),
                  Text(
                    unit,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            footer,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: footerColor,
              fontSize: 8,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
