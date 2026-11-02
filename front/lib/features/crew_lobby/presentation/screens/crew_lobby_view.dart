import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../../race_hud/presentation/controllers/race_session_controller.dart';
import '../../../route_finder/data/datasources/drunk_api_datasource.dart';
import '../../../route_finder/presentation/controllers/route_finder_controller.dart';

/// Aba CREW: Criação e entrada em salas de grupo (`DRK-XXX`)
class CrewLobbyView extends ConsumerStatefulWidget {
  final VoidCallback onGoToRoute;
  final VoidCallback onGoToRadar;

  const CrewLobbyView({
    super.key,
    required this.onGoToRoute,
    required this.onGoToRadar,
  });

  @override
  ConsumerState<CrewLobbyView> createState() => _CrewLobbyViewState();
}

class _CrewLobbyViewState extends ConsumerState<CrewLobbyView> {
  final TextEditingController _codeController =
      TextEditingController(text: 'DRK-492');
  final TextEditingController _nicknameController =
      TextEditingController(text: 'Runner SP');
  bool _isSyncing = false;
  String? _statusMessage;

  @override
  void dispose() {
    _codeController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _hostCrewRoom() async {
    final routeState = ref.read(routeFinderProvider);
    if (routeState.route == null) {
      setState(() {
        _statusMessage =
            'Gere primeiro uma rota de 10KM na aba ROTA para abrir a sala da Crew.';
      });
      return;
    }

    setState(() {
      _isSyncing = true;
      _statusMessage = null;
    });

    String roomCode = 'DRK-492';
    try {
      final api = DrunkApiDatasource();
      final res = await api.syncRouteAndCreateLobby(
        route: routeState.route!,
        hostNickname: _nicknameController.text.trim().isEmpty
            ? 'Host Runner'
            : _nicknameController.text.trim(),
      );
      roomCode = (res['room_code'] as String?) ?? roomCode;
    } catch (_) {
      // Caso a API local FastAPI esteja desligada, cria sala local imediatamente
    }

    await ref.read(raceSessionProvider.notifier).startSession(
          route: routeState.route!,
          roomCode: roomCode,
          originLabel: routeState.locationAddress,
        );

    if (!mounted) return;
    setState(() => _isSyncing = false);
    widget.onGoToRadar();
  }

  @override
  Widget build(BuildContext context) {
    final activeSession = ref.watch(raceSessionProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.groups_rounded,
                    color: AppColors.neonOrange,
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DRUNK // CREW LOBBY',
                          style: TextStyle(
                            color: AppColors.neonOrange,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          'Sincronize os 10 bares com seu grupo de corrida',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (activeSession != null && !activeSession.isCompleted) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.cyberGreen.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppColors.cyberGreen.withValues(alpha: 0.6),
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      'SALA ATIVA EM CORRIDA',
                      style: TextStyle(
                        color: AppColors.cyberGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      activeSession.roomCode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${activeSession.completedBarsCount}/${activeSession.totalBarsCount} bares • '
                      '${activeSession.validatedDistanceKm.toStringAsFixed(2)} km validados',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 14),
                    NeonButton(
                      label: 'ABRIR RADAR DA CORRIDA',
                      icon: Icons.radar_rounded,
                      color: AppColors.cyberGreen,
                      glowColor: AppColors.cyberGreenGlow,
                      gradient: AppColors.cyberGreenGradient,
                      textColor: Colors.black,
                      onPressed: widget.onGoToRadar,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'SEU CODINOME NA CREW',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nicknameController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: AppColors.glassBorder),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  NeonButton(
                    label: 'CRIAR SALA COM ROTA ATUAL',
                    subtitle: 'Gera código DRK-XXX e inicia HUD da Crew',
                    icon: Icons.group_add_rounded,
                    gradient: AppColors.neonOrangeGradient,
                    textColor: Colors.black,
                    isLoading: _isSyncing,
                    onPressed: _hostCrewRoom,
                  ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _statusMessage!,
                      style: const TextStyle(
                        color: AppColors.neonCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: widget.onGoToRoute,
                      icon: const Icon(
                        Icons.route_rounded,
                        color: AppColors.neonOrange,
                      ),
                      label: const Text(
                        'IR PARA ABA ROTA E GERAR 10KM',
                        style: TextStyle(color: AppColors.neonOrange),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
