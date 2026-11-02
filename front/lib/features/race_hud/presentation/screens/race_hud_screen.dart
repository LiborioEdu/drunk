import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../comanda_checkin/presentation/modals/checkin_comanda_sheet.dart';
import '../../../comanda_checkin/presentation/modals/hydration_lock_modal.dart';
import '../../../race_summary/presentation/screens/drunk_wrapped_screen.dart';
import '../controllers/race_session_controller.dart';
import '../widgets/anti_cheat_banner.dart';
import '../widgets/race_live_map_card.dart';
import '../widgets/target_bar_proximity_card.dart';
import '../widgets/telemetry_hud_card.dart';

/// Tela 2 (Stitch `02_race_active_hud`): HUD Ativo de Corrida, Anti-Cheat, Geofence 20m e Hidratação
class RaceHudScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;

  const RaceHudScreen({super.key, this.onBack});

  @override
  ConsumerState<RaceHudScreen> createState() => _RaceHudScreenState();
}

class _RaceHudScreenState extends ConsumerState<RaceHudScreen> {
  bool _showDevSimulator = true;

  Future<void> _openCheckInModal() async {
    final session = ref.read(raceSessionProvider);
    if (session == null || !session.isWithinGeofence) return;
    final targetBar = session.targetBar;
    if (targetBar == null) return;

    HapticFeedback.mediumImpact();
    final result = await CheckInComandaSheet.show(
      context,
      session: session,
      bar: targetBar,
    );

    if (result == null || !mounted) return;
    await ref.read(raceSessionProvider.notifier).submitBarCheckin(
          spentBrl: result.spentBrl,
          category: result.category,
        );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(raceSessionProvider);
    final notifier = ref.read(raceSessionProvider.notifier);

    if (session == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Nenhuma corrida ativa — Voltar ao Mapa'),
          ),
        ),
      );
    }

    // Se todos os 10 bares foram concluídos, exibe automaticamente a Tela 5 (Drunk Wrapped)
    if (session.isCompleted) {
      return DrunkWrappedScreen(
        session: session,
        onReturnToMap: () async {
          await notifier.clearCurrentSession();
          if (widget.onBack != null) {
            widget.onBack!();
          } else if (context.mounted) {
            Navigator.of(context).maybePop();
          }
        },
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Superior DRUNK // 10K Nocturnal Run HUD
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () {
                            if (widget.onBack != null) {
                              widget.onBack!();
                            } else {
                              Navigator.of(context).maybePop();
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceCard,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: AppColors.neonOrange,
                              size: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DRUNK // 10K',
                                style: TextStyle(
                                  color: AppColors.neonOrange,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.3,
                                ),
                              ),
                              Text(
                                'NOCTURNAL RUN HUD',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Botão para exibir/ocultar o Simulador GPS (ideal para Web/Linux)
                        InkWell(
                          onTap: () => setState(
                            () => _showDevSimulator = !_showDevSimulator,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: _showDevSimulator
                                  ? AppColors.neonCyan.withValues(alpha: 0.16)
                                  : AppColors.surfaceCard,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _showDevSimulator
                                    ? AppColors.neonCyan
                                    : AppColors.glassBorder,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.developer_mode_rounded,
                                  color: _showDevSimulator
                                      ? AppColors.neonCyan
                                      : AppColors.textSecondary,
                                  size: 15,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'SIM GPS',
                                  style: TextStyle(
                                    color: _showDevSimulator
                                        ? AppColors.neonCyan
                                        : AppColors.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Linha Sala + Cronômetro Ativo
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'SESSÃO ${session.roomCode} • ${session.originLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '⏱ TEMPO: ${session.elapsedFormatted}',
                          style: const TextStyle(
                            color: AppColors.neonOrange,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Painel Simulador GPS (Para testar Caminhada, Geofence <= 20m e Anti-Cheat > 15 km/h no navegador/PC)
                  if (_showDevSimulator) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.neonCyan.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '⚡ SIMULADOR GPS DE TESTE (WEB / DESKTOP)',
                            style: TextStyle(
                              color: AppColors.neonCyan,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _SimChipButton(
                                icon: Icons.directions_run_rounded,
                                label: '+Corrida (~300m)',
                                color: AppColors.neonCyan,
                                onTap: () =>
                                    notifier.simulateRunStepTowardsBar(),
                              ),
                              _SimChipButton(
                                icon: Icons.my_location_rounded,
                                label: 'Chegar <=20m do Bar',
                                color: AppColors.cyberGreen,
                                onTap: () =>
                                    notifier.simulateArriveAtBarGeofence(),
                              ),
                              _SimChipButton(
                                icon: Icons.directions_car_filled_rounded,
                                label: session.antiCheatTriggered
                                    ? 'Sair do Veículo (9km/h)'
                                    : 'Testar Carro (25km/h)',
                                color: AppColors.alertRed,
                                onTap: () =>
                                    notifier.toggleSimulatedVehicleSpeed(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Banner Anti-Cheat (> 15 km/h)
                  AntiCheatBanner(session: session),
                  const SizedBox(height: 12),

                  // Painel de Telemetria Principal
                  TelemetryHudCard(session: session),
                  const SizedBox(height: 12),

                  // Mapa de Navegação Vivo Bicolor + Geofence 20m
                  RaceLiveMapCard(session: session),
                  const SizedBox(height: 12),

                  // Card de Proximidade do Bar Alvo + Botão Check-in
                  TargetBarProximityCard(
                    session: session,
                    onCheckInPressed: _openCheckInModal,
                    onTogglePause: () => notifier.togglePause(),
                  ),
                ],
              ),
            ),
          ),

          // Tela 4: Trava Obrigatória de Hidratação a cada 2 bares (2, 4, 6, 8)
          if (session.isLockedByHydration)
            HydrationLockOverlay(
              session: session,
              onConfirmWaterTaken: () {
                HapticFeedback.heavyImpact();
                notifier.confirmHydrationTaken();
              },
            ),
        ],
      ),
    );
  }
}

class _SimChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SimChipButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
