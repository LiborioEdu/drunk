import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../../race_hud/domain/entities/race_session.dart';

/// Tela 5 (Stitch `05_drunk_wrapped`): Resumo Final da Maratona 10KM, Comanda e DrunkCoins
class DrunkWrappedScreen extends StatelessWidget {
  final RaceSession session;
  final VoidCallback onReturnToMap;

  const DrunkWrappedScreen({
    super.key,
    required this.session,
    required this.onReturnToMap,
  });

  String _buildShareText() {
    return '🏆 DRUNK // 10K WRAPPED FINISHER (${session.roomCode})\n'
        '🏃 Distância Validada: ${session.validatedDistanceKm.toStringAsFixed(2)} km\n'
        '🍺 Bares Concluídos: ${session.completedBarsCount}/${session.totalBarsCount}\n'
        '⚡ Pace Médio: ${session.averagePaceFormatted}/km (${session.elapsedFormatted})\n'
        '🧾 Comanda Total: ${RaceSession.formatBrl(session.totalSpentBrl)}\n'
        '💧 Hidratações: ${session.completedHydrationGates.length}/${session.totalHydrationGatesCount}\n'
        '🪙 Recompensa: +${session.earnedDrunkCoins} DrunkCoins!';
  }

  @override
  Widget build(BuildContext context) {
    final firstBarName =
        session.route.bars.isNotEmpty ? session.route.bars.first.name : 'Início';
    final lastBarName =
        session.route.bars.isNotEmpty ? session.route.bars.last.name : 'Chegada';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: onReturnToMap,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Expanded(
                      child: Column(
                        children: [
                          Text(
                            'DRUNK // 10K',
                            style: TextStyle(
                              color: AppColors.neonOrange,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                            ),
                          ),
                          Text(
                            'WRAPPED FINISHER',
                            style: TextStyle(
                              color: AppColors.cyberGreen,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Badge Maratona Concluída
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cyberGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.cyberGreen.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.emoji_events_rounded,
                        color: AppColors.cyberGreen,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'MARATONA DRUNK CONCLUÍDA • #${session.roomCode}',
                        style: const TextStyle(
                          color: AppColors.cyberGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                session.originLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),

              // Trophy Card Compartilhável
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.neonOrange.withValues(alpha: 0.55),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cyberGreen.withValues(alpha: 0.08),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(
                                color: AppColors.cyberGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'DRUNK // OFFICIAL FINISHER',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.cyberGreen.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.cyberGreen.withValues(alpha: 0.5),
                            ),
                          ),
                          child: const Text(
                            '✓ OFICIAL',
                            style: TextStyle(
                              color: AppColors.cyberGreen,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      '🏃 CIRCUITO TOTAL HOMOLOGADO',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.neonOrange,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          session.validatedDistanceKm.toStringAsFixed(2),
                          style: AppTextStyles.displayHero.copyWith(
                            fontSize: 54,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'KM',
                          style: TextStyle(
                            color: AppColors.neonOrange,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cyberGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.cyberGreen.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          '✓ DISTÂNCIA REAL VALIDADA '
                          '(${session.antiCheatWarningsCount} ALERTAS ANTI-CHEAT)',
                          style: const TextStyle(
                            color: AppColors.cyberGreen,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Preview Gráfico Neon dos 10 Checkpoints
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${session.completedBarsCount} BARES VALIDADOS',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const Text(
                                '100% CONCLUÍDO',
                                style: TextStyle(
                                  color: AppColors.cyberGreen,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 76,
                            child: CustomPaint(
                              painter: _NeonCircuitPainter(
                                stopsCount: math.max(2, session.totalBarsCount),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'START: $firstBarName',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'FINISH: $lastBarName 🏆',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    color: AppColors.cyberGreen,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Grid 2x2 de Estatísticas
                    Row(
                      children: [
                        Expanded(
                          child: _WrappedStatBox(
                            label: 'BARES VISITADOS',
                            value:
                                '${session.completedBarsCount}/${session.totalBarsCount}',
                            valueColor: Colors.white,
                            subtitle: '100% dos checkpoints',
                            icon: Icons.local_bar_rounded,
                            iconColor: AppColors.cyberGreen,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _WrappedStatBox(
                            label: 'PACE MÉDIO',
                            value: '${session.averagePaceFormatted}/KM',
                            valueColor: Colors.white,
                            subtitle: 'Tempo: ${session.elapsedFormatted}',
                            icon: Icons.speed_rounded,
                            iconColor: AppColors.neonOrange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _WrappedStatBox(
                            label: 'COMANDA TOTAL',
                            value: RaceSession.formatBrl(session.totalSpentBrl),
                            valueColor: AppColors.cyberGreen,
                            subtitle:
                                'Média ${RaceSession.formatBrl(session.averageSpentPerBarBrl)}/bar',
                            icon: Icons.receipt_long_rounded,
                            iconColor: AppColors.cyberGreen,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _WrappedStatBox(
                            label: 'HIDRATAÇÃO SAFE',
                            value:
                                '${session.completedHydrationGates.length}/${session.totalHydrationGatesCount} 💧',
                            valueColor: Colors.white,
                            subtitle: 'Protocolo cumprido!',
                            icon: Icons.water_drop_rounded,
                            iconColor: AppColors.neonCyan,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Card DrunkCoins Ganhos
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.neonOrange.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        gradient: AppColors.neonOrangeGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.monetization_on_rounded,
                        color: Colors.black,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '+${session.earnedDrunkCoins} DRUNKCOINS CREDITADOS',
                            style: const TextStyle(
                              color: AppColors.neonOrange,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'XP ÉPICO + BADGE "TITÃ DA MADRUGADA"',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Extrato Detalhado por Bar (Comanda)
              if (session.checkins.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EXTRATO DA COMANDA POR BAR',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final item in session.checkins)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Text(
                                '#${item.barOrder.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  color: AppColors.cyberGreen,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${item.barName} (${item.category.label})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                RaceSession.formatBrl(item.spentBrl),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),

              // Botão Compartilhar
              NeonButton(
                label: 'COMPARTILHAR CARD NO STORIES',
                icon: Icons.share_rounded,
                gradient: AppColors.neonOrangeGradient,
                color: AppColors.neonOrange,
                glowColor: AppColors.neonOrangeGlow,
                textColor: Colors.black,
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: _buildShareText()),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppColors.surfaceCard,
                      content: Text(
                        'Resumo Drunk Wrapped copiado para compartilhar!',
                        style: TextStyle(color: AppColors.cyberGreen),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),

              // Botão Voltar ao Mapa
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(
                    color: AppColors.cyberGreen,
                    width: 1.4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: onReturnToMap,
                icon: const Icon(
                  Icons.map_rounded,
                  color: AppColors.cyberGreen,
                  size: 19,
                ),
                label: const Text(
                  'SALVAR NO HISTÓRICO E VOLTAR AO MAPA',
                  style: TextStyle(
                    color: AppColors.cyberGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WrappedStatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final String subtitle;
  final IconData icon;
  final Color iconColor;

  const _WrappedStatBox({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              Icon(icon, color: iconColor, size: 15),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.telemetryLarge.copyWith(
              color: valueColor,
              fontSize: 21,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NeonCircuitPainter extends CustomPainter {
  final int stopsCount;

  const _NeonCircuitPainter({required this.stopsCount});

  @override
  void paint(Canvas canvas, Size size) {
    final pts = <Offset>[];
    for (int i = 0; i < stopsCount; i++) {
      final t = i / (stopsCount - 1);
      final x = 14 + t * (size.width - 28);
      final wave = math.sin(t * math.pi * 2.5) * (size.height * 0.28);
      final y = (size.height * 0.52) - wave;
      pts.add(Offset(x, y));
    }

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final midX = (pts[i].dx + pts[i + 1].dx) / 2;
      path.cubicTo(
        midX,
        pts[i].dy,
        midX,
        pts[i + 1].dy,
        pts[i + 1].dx,
        pts[i + 1].dy,
      );
    }

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = AppColors.cyberGreen.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path, glowPaint);

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [AppColors.neonOrange, AppColors.cyberGreen],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, linePaint);

    for (int i = 0; i < pts.length; i++) {
      final isLast = i == pts.length - 1;
      canvas.drawCircle(
        pts[i],
        isLast ? 7.0 : 4.5,
        Paint()..color = AppColors.cyberGreen,
      );
      canvas.drawCircle(
        pts[i],
        isLast ? 3.2 : 2.0,
        Paint()..color = AppColors.background,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NeonCircuitPainter oldDelegate) =>
      oldDelegate.stopsCount != stopsCount;
}
