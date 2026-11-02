import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../../race_hud/domain/entities/race_session.dart';

/// Tela 4 (Stitch `04_hydration_lock`): Overlay obrigatório de hidratação a cada 2 bares concluídos
class HydrationLockOverlay extends StatelessWidget {
  final RaceSession session;
  final VoidCallback onConfirmWaterTaken;

  const HydrationLockOverlay({
    super.key,
    required this.session,
    required this.onConfirmWaterTaken,
  });

  @override
  Widget build(BuildContext context) {
    final completedBarOrder =
        session.pendingHydrationBarOrder ?? session.completedBarsCount;
    final gateIndex =
        (completedBarOrder ~/ RaceSession.hydrationIntervalBars).clamp(1, 99);
    final totalGates = session.totalHydrationGatesCount > 0
        ? session.totalHydrationGatesCount
        : 4;
    final nextBarOrder =
        (completedBarOrder + 1).toString().padLeft(2, '0');
    final gateOrders = List.generate(
      totalGates,
      (i) => (i + 1) * RaceSession.hydrationIntervalBars,
    );

    return Positioned.fill(
      child: PopScope(
        canPop: false,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.25),
                radius: 1.0,
                colors: [
                  AppColors.neonCyan.withValues(alpha: 0.22),
                  AppColors.background.withValues(alpha: 0.95),
                ],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Topo: Protocolo de Segurança Ativo
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.neonCyan.withValues(alpha: 0.55),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: AppColors.neonCyan,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.lock_outline_rounded,
                            color: AppColors.neonCyan,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'PROTOCOLO DE SEGURANÇA ATIVO • ROTA BLOQUEADA',
                              style: TextStyle(
                                color: AppColors.neonCyan,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.neonCyan.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.neonCyan.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              'GATE #$gateIndex',
                              style: const TextStyle(
                                color: AppColors.neonCyan,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Pílula de Checkpoint
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.water_drop_outlined,
                            color: AppColors.neonCyan,
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'CHECKPOINT DE HIDRATAÇÃO 0$gateIndex/0$totalGates '
                              '(BAR #${completedBarOrder.toString().padLeft(2, '0')} CONCLUÍDO)',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Emblema Central Holográfico 300 ML
                    Center(
                      child: SizedBox(
                        width: 170,
                        height: 170,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 164,
                              height: 164,
                              child: CircularProgressIndicator(
                                value: gateIndex / totalGates,
                                strokeWidth: 8,
                                backgroundColor: AppColors.surfaceLight,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.neonCyan,
                                ),
                              ),
                            ),
                            Container(
                              width: 128,
                              height: 128,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.surface,
                                border: Border.all(
                                  color: AppColors.neonCyan.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: AppColors.neonCyanGlow,
                                    blurRadius: 26,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.local_drink_rounded,
                                    color: AppColors.neonCyan,
                                    size: 40,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '300 ML',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  Text(
                                    'OBRIGATÓRIO',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Título de Impacto
                    const Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          height: 1.15,
                        ),
                        children: [
                          TextSpan(
                            text: 'PAUSA OBRIGATÓRIA:\n',
                            style: TextStyle(color: Colors.white),
                          ),
                          TextSpan(
                            text: 'HORA DA ÁGUA!',
                            style: TextStyle(color: AppColors.neonCyan),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Você já completou ${session.completedBarsCount} bares e '
                      '${session.validatedDistanceKm.toStringAsFixed(2)} km. '
                      'Para manter o ritmo nos 10km e destravar as coordenadas '
                      'do Bar #$nextBarOrder, beba um copo cheio d\'água (300ml) agora.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Card de Bônus DrunkCoins + Tracker dos 4 Gates
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.neonCyan.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.neonCyan.withValues(
                                    alpha: 0.15,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.token_rounded,
                                  color: AppColors.neonCyan,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '+50 DRUNKCOINS',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      'BÔNUS DE HIDRATAÇÃO SEGURA',
                                      style: TextStyle(
                                        color: AppColors.neonCyan,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.cyberGreen.withValues(
                                    alpha: 0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.cyberGreen.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  '⚡ RECOMPENSA',
                                  style: TextStyle(
                                    color: AppColors.cyberGreen,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              for (final gateOrder in gateOrders)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    child: _HydrationGatePill(
                                      barOrder: gateOrder,
                                      isDone: session.completedHydrationGates
                                          .contains(gateOrder),
                                      isCurrent:
                                          gateOrder == completedBarOrder,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline_rounded,
                                  color: AppColors.neonCyan,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Hidratar a cada 2 bares reduz a ressaca matinal e previne câimbras durante a corrida noturna.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Botão Ciano Neon para Destravar
                    NeonButton(
                      label: 'JÁ BEBI MEU COPO D\'ÁGUA',
                      subtitle: 'Destravar coordenadas do Bar #$nextBarOrder',
                      icon: Icons.water_drop_rounded,
                      color: AppColors.neonCyan,
                      glowColor: AppColors.neonCyanGlow,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00E5FF), Color(0xFF00B8D4)],
                      ),
                      textColor: Colors.black,
                      onPressed: onConfirmWaterTaken,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HydrationGatePill extends StatelessWidget {
  final int barOrder;
  final bool isDone;
  final bool isCurrent;

  const _HydrationGatePill({
    required this.barOrder,
    required this.isDone,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isCurrent
        ? AppColors.neonCyan
        : (isDone ? AppColors.cyberGreen : AppColors.glassBorder);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: isCurrent
            ? AppColors.neonCyan.withValues(alpha: 0.16)
            : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: isCurrent ? 1.6 : 1.0,
        ),
      ),
      child: Column(
        children: [
          Icon(
            isDone
                ? Icons.check_circle_rounded
                : (isCurrent ? Icons.water_drop_rounded : Icons.lock_rounded),
            size: 18,
            color: isDone
                ? AppColors.cyberGreen
                : (isCurrent ? AppColors.neonCyan : AppColors.textMuted),
          ),
          const SizedBox(height: 5),
          Text(
            'Bar #${barOrder.toString().padLeft(2, '0')}',
            style: TextStyle(
              color: isCurrent || isDone ? Colors.white : AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isDone ? 'FEITO' : (isCurrent ? 'AGORA' : 'TRAVADO'),
            style: TextStyle(
              color: isDone
                  ? AppColors.cyberGreen
                  : (isCurrent ? AppColors.neonCyan : AppColors.textMuted),
              fontSize: 8,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
