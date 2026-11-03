import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../data/datasources/drunk_api_datasource.dart';
import '../../domain/entities/drunk_route.dart';

/// Modal de confirmação ao travar a rota com integração ao Backend FastAPI (Criação de Sala DRK-XXX)
class RouteLockedModal extends StatefulWidget {
  final DrunkRoute route;

  const RouteLockedModal({
    super.key,
    required this.route,
  });

  static Future<String?> show(BuildContext context, DrunkRoute route) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => RouteLockedModal(route: route),
    );
  }

  @override
  State<RouteLockedModal> createState() => _RouteLockedModalState();
}

class _RouteLockedModalState extends State<RouteLockedModal> {
  final DrunkApiDatasource _apiDatasource = DrunkApiDatasource();
  bool _isSyncing = false;
  String? _roomCode;
  String? _sessionId;
  String? _syncError;

  Future<void> _createLobbyOnBackend() async {
    setState(() {
      _isSyncing = true;
      _syncError = null;
    });

    try {
      final result = await _apiDatasource.syncRouteAndCreateLobby(
        route: widget.route,
        hostNickname: 'Host Runner',
      );
      if (!mounted) return;
      setState(() {
        _isSyncing = false;
        _roomCode = result['room_code'] as String?;
        _sessionId = result['session_id'] as String?;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSyncing = false;
        _syncError =
            'API FastAPI offline em localhost:8000 (Modo Local Ativo)';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.cyberGreen.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.cyberGreen,
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.cyberGreenGlow,
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.lock_rounded,
              color: AppColors.cyberGreen,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'SESSÃO DRUNK TRAVADA!',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Percurso de ${route.totalDistanceKmFormatted} passando por ${route.totalBars} bares validado (~${route.estimatedDurationFormatted} de caminhada).',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          // Se a sala foi criada na API FastAPI, exibe o código DRK-XXX em destaque
          if (_roomCode != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cyberGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cyberGreen, width: 1.5),
              ),
              child: Column(
                children: [
                  const Text(
                    'SALA DE GRUPO CRIADA NA API',
                    style: TextStyle(
                      color: AppColors.cyberGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _roomCode!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sessão ID: $_sessionId',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RESUMO DO PAYLOAD DA SESSÃO',
                    style: TextStyle(
                      color: AppColors.neonCyan,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Partida: ${route.origin.latitude.toStringAsFixed(4)}, ${route.origin.longitude.toStringAsFixed(4)}\n'
                    '• Primeiro Bar: #01 ${route.bars.first.name}\n'
                    '• Último Bar: #${route.bars.length.toString().padLeft(2, '0')} ${route.bars.last.name}\n'
                    '• Pontos na Polyline: ${route.polyline.length} coordenadas',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  if (_syncError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _syncError!,
                      style: const TextStyle(
                        color: AppColors.neonOrange,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 18),
          if (_roomCode == null) ...[
            NeonButton(
              label: 'CRIAR SALA DE GRUPO (API)',
              subtitle: 'Gera código DRK-XXX no Backend FastAPI',
              icon: Icons.group_add_rounded,
              color: AppColors.neonOrange,
              glowColor: AppColors.neonOrangeGlow,
              gradient: AppColors.neonOrangeGradient,
              isLoading: _isSyncing,
              onPressed: _createLobbyOnBackend,
            ),
            const SizedBox(height: 10),
          ],
          NeonButton(
            label:
                'INICIAR CORRIDA (${route.totalDistanceKmFormatted.toUpperCase()} • ${route.totalBars} BARES)',
            subtitle: 'Ativar HUD de telemetria, Geofence 20m e Comanda',
            icon: Icons.directions_run_rounded,
            color: AppColors.cyberGreen,
            glowColor: AppColors.cyberGreenGlow,
            gradient: AppColors.cyberGreenGradient,
            textColor: Colors.black,
            onPressed: () =>
                Navigator.of(context).pop(_roomCode ?? 'SOLO-START'),
          ),
        ],
      ),
    );
  }
}
