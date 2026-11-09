import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/haversine_calculator.dart';
import '../../../../core/widgets/drunk_map_tiles.dart';
import '../../../route_finder/domain/entities/bar.dart';
import '../../../route_finder/domain/entities/drunk_route.dart';
import '../../../route_finder/presentation/controllers/route_finder_controller.dart';
import '../../domain/entities/race_session.dart';
import '../controllers/race_session_controller.dart';

/// Tela Principal DRUNK (antiga aba Radar):
/// Interface inspirada em Pokémon GO com mapa em alto zoom acompanhando a setinha do usuário,
/// reconhecendo a rota gerada e controlando o percurso via botão central (START -> PAUSE na parada -> START).
class RaceHudScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;

  const RaceHudScreen({super.key, this.onBack});

  @override
  ConsumerState<RaceHudScreen> createState() => _RaceHudScreenState();
}

class _RaceHudScreenState extends ConsumerState<RaceHudScreen> {
  final MapController _mapController = MapController();
  bool _isMapReady = false;
  bool _isFollowingUser = true;
  double _currentZoom = 17.6;
  DrunkMapStyle _mapStyle = DrunkMapStyle.pokemonGo;
  String? _lastSyncedRouteSignature;
  LatLng? _lastMovedPosition;

  static String _routeSignature(DrunkRoute route) {
    final ids = route.bars.map((b) => b.id).join(',');
    return '${route.origin.latitude.toStringAsFixed(5)}_'
        '${route.origin.longitude.toStringAsFixed(5)}_$ids';
  }

  void _syncRouteIfNeeded(RouteFinderState routeState, RaceSession? session) {
    final finderRoute = routeState.route;
    if (finderRoute == null || finderRoute.bars.isEmpty) return;

    final sig = _routeSignature(finderRoute);
    final sessionSig =
        session != null ? _routeSignature(session.route) : null;

    if (session == null ||
        (_lastSyncedRouteSignature != sig && sessionSig != sig)) {
      _lastSyncedRouteSignature = sig;
      Future.microtask(() {
        if (!mounted) return;
        ref.read(raceSessionProvider.notifier).syncRouteFromFinder(
              finderRoute,
              userPosition: routeState.userLocation ?? finderRoute.origin,
              headingDegrees: routeState.userHeading,
              originLabel: routeState.locationAddress,
            );
      });
    }
  }

  void _moveCameraToUser(LatLng target, {double? zoom}) {
    if (!_isMapReady) return;
    final z = zoom ?? _currentZoom;
    _currentZoom = z;
    _mapController.move(target, z);
  }

  Future<void> _handleCentralButtonTap(
    RaceSession session,
    RaceSessionNotifier notifier,
  ) async {
    if (session.isCompleted) {
      HapticFeedback.mediumImpact();
      await notifier.syncRouteFromFinder(
        session.route,
        userPosition: session.route.origin,
        originLabel: session.originLabel,
      );
      return;
    }

    if (session.canStartAtOrigin) {
      HapticFeedback.heavyImpact();
      await notifier.startAtOrigin();
      return;
    }

    if (session.canPauseAtStop) {
      HapticFeedback.heavyImpact();
      await notifier.pauseAtStop();
      return;
    }

    if (session.canResumeFromStop) {
      HapticFeedback.heavyImpact();
      await notifier.resumeFromStop();
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeState = ref.watch(routeFinderProvider);
    final session = ref.watch(raceSessionProvider);
    final notifier = ref.read(raceSessionProvider.notifier);

    // Escuta atualizações de GPS da aba de rotas para manter a setinha sempre sincronizada
    ref.listen<RouteFinderState>(routeFinderProvider, (prev, next) {
      if (next.userLocation != null &&
          next.userLocation != prev?.userLocation) {
        ref.read(raceSessionProvider.notifier).moveUserPosition(
              next.userLocation!,
              headingDegrees: next.userHeading,
            );
      }
    });

    _syncRouteIfNeeded(routeState, session);

    final activeRoute = session?.route ?? routeState.route;
    final userPos = session?.currentPosition ??
        routeState.userLocation ??
        activeRoute?.origin ??
        RouteFinderNotifier.defaultOrigin;
    final heading = session?.headingDegrees ?? routeState.userHeading ?? 0.0;

    if (_isMapReady &&
        _isFollowingUser &&
        (_lastMovedPosition == null ||
            HaversineCalculator.distanceMeters(_lastMovedPosition!, userPos) >
                0.5)) {
      _lastMovedPosition = userPos;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isMapReady && _isFollowingUser) {
          _mapController.move(userPos, _currentZoom);
        }
      });
    }

    final isDaylightStyle = _mapStyle == DrunkMapStyle.pokemonGo ||
        _mapStyle == DrunkMapStyle.osmLight;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. MAPA EM TELA CHEIA COM ZOOM ACOMPANHANDO O CELULAR DO USUÁRIO
            Positioned.fill(
              child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: userPos,
                initialZoom: _currentZoom,
                minZoom: 13.0,
                maxZoom: 19.0,
                onMapReady: () {
                  _isMapReady = true;
                  _lastMovedPosition = userPos;
                  _mapController.move(userPos, _currentZoom);
                },
                onPositionChanged: (camera, hasGesture) {
                  _currentZoom = camera.zoom;
                  if (hasGesture) {
                    setState(() => _isFollowingUser = false);
                  }
                },
                onTap: (_, tappedPoint) {
                  // Permite mover a setinha tocando no mapa para facilitar testes do percurso
                  setState(() => _isFollowingUser = true);
                  notifier.moveUserPosition(tappedPoint);
                },
              ),
              children: [
                DrunkMapTileLayer(style: _mapStyle),

                // Círculos de Geofence no chão (Ponto de Start, Paradas e Radar da Setinha)
                CircleLayer(
                  circles: [
                    // Círculo do Ponto de Start (Largada)
                    if (activeRoute != null)
                      CircleMarker(
                        point: activeRoute.origin,
                        radius: RaceSession.geofenceRadiusMeters,
                        useRadiusInMeter: true,
                        color: AppColors.cyberGreen.withValues(alpha: 0.18),
                        borderColor: AppColors.cyberGreen,
                        borderStrokeWidth: 2.2,
                      ),

                    // Círculos de cada Ponto de Parada (estilo base de PokéStop)
                    if (activeRoute != null)
                      for (int i = 0; i < activeRoute.bars.length; i++)
                        CircleMarker(
                          point: activeRoute.bars[i].coordinates,
                          radius: RaceSession.geofenceRadiusMeters,
                          useRadiusInMeter: true,
                          color: (session != null &&
                                  i < session.completedBarsCount)
                              ? AppColors.cyberGreen.withValues(alpha: 0.16)
                              : (session != null &&
                                      i == session.completedBarsCount &&
                                      session.isAtStopPoint)
                                  ? AppColors.cyberGreen.withValues(alpha: 0.25)
                                  : const Color(0xFF00E5FF)
                                      .withValues(alpha: 0.15),
                          borderColor: (session != null &&
                                  i < session.completedBarsCount)
                              ? AppColors.cyberGreen
                              : (session != null &&
                                      i == session.completedBarsCount &&
                                      session.isAtStopPoint)
                                  ? AppColors.cyberGreen
                                  : Colors.white.withValues(alpha: 0.85),
                          borderStrokeWidth: 2.0,
                        ),

                    // Anel externo de alcance do jogador (idêntico ao círculo ao redor do personagem no Pokémon GO)
                    CircleMarker(
                      point: userPos,
                      radius: RaceSession.geofenceRadiusMeters,
                      useRadiusInMeter: true,
                      color: Colors.white.withValues(alpha: 0.06),
                      borderColor: Colors.white.withValues(alpha: 0.85),
                      borderStrokeWidth: 2.0,
                    ),
                    CircleMarker(
                      point: userPos,
                      radius: RaceSession.geofenceRadiusMeters * 0.72,
                      useRadiusInMeter: true,
                      color: Colors.transparent,
                      borderColor: const Color(0xFFE040FB).withValues(alpha: 0.45),
                      borderStrokeWidth: 1.2,
                    ),
                  ],
                ),

                // Traçado da Rota Gerada (estilo estrada destacada do Pokémon GO)
                if (activeRoute != null && activeRoute.polyline.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      // Contorno amarelo/dourado da pista (estilo Pokémon GO)
                      Polyline(
                        points: activeRoute.polyline,
                        strokeWidth: 14.0,
                        color: const Color(0xFFFFEA61).withValues(alpha: 0.88),
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                      // Faixa interna da pista (azul-petróleo escuro)
                      Polyline(
                        points: activeRoute.polyline,
                        strokeWidth: 9.0,
                        color: const Color(0xFF28666E),
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                      // Linha central guia
                      Polyline(
                        points: activeRoute.polyline,
                        strokeWidth: 2.4,
                        color: const Color(0xFFFFEA61).withValues(alpha: 0.75),
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                    ],
                  ),

                // Marcadores: Ponto de Start + Pontos de Parada + Setinha do Usuário
                MarkerLayer(
                  markers: [
                    // Marcador do Ponto de Start
                    if (activeRoute != null)
                      Marker(
                        point: activeRoute.origin,
                        width: 110,
                        height: 64,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _isFollowingUser = true);
                            notifier.moveUserPosition(activeRoute.origin);
                          },
                          child: _StartPointMarker(
                            isReached: session?.isAtStartPoint ?? true,
                            hasStarted: session?.hasStarted ?? false,
                          ),
                        ),
                      ),

                    // Marcadores dos Pontos de Parada (estilo PokéStop)
                    if (activeRoute != null)
                      for (int i = 0; i < activeRoute.bars.length; i++)
                        Marker(
                          point: activeRoute.bars[i].coordinates,
                          width: 136,
                          height: 76,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _isFollowingUser = true);
                              notifier.moveUserPosition(
                                activeRoute.bars[i].coordinates,
                              );
                            },
                            child: _PokeStopBarMarker(
                              bar: activeRoute.bars[i],
                              order: i + 1,
                              isCompleted: session != null &&
                                  i < session.completedBarsCount,
                              isCurrentTarget: session != null &&
                                  session.hasStarted &&
                                  i == session.completedBarsCount,
                              isWithinRadius: session != null &&
                                  i == session.completedBarsCount &&
                                  session.isAtStopPoint,
                            ),
                          ),
                        ),

                    // Setinha Direcional do Usuário (no centro do movimento)
                    Marker(
                      point: userPos,
                      width: 68,
                      height: 68,
                      child: _PokemonGoUserArrow(
                        headingDegrees: heading,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. HORIZONTE ATMOSFÉRICO NO TOPO (igual ao céu do Pokémon GO)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDaylightStyle
                        ? [
                            const Color(0xFF4FC3F7).withValues(alpha: 0.85),
                            const Color(0xFF81D4FA).withValues(alpha: 0.45),
                            Colors.transparent,
                          ]
                        : [
                            const Color(0xFF0B0B0E).withValues(alpha: 0.88),
                            const Color(0xFF0B0B0E).withValues(alpha: 0.35),
                            Colors.transparent,
                          ],
                  ),
                ),
              ),
            ),
          ),

          // 3. CONTROLES SUPERIORES (Título DRUNK + Sol/Tema + Bússola Pokémon GO)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge superior esquerdo "DRUNK"
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xD90B0B0E),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.navigation_rounded,
                            color: AppColors.neonCyan,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'DRUNK',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          if (activeRoute != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.neonOrange.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                activeRoute.totalDistanceKmFormatted,
                                style: const TextStyle(
                                  color: AppColors.neonOrange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                          if (session != null &&
                              (session.hasStarted ||
                                  session.elapsedSeconds > 0)) ...[
                            const SizedBox(width: 8),
                            Tooltip(
                              message: 'Reiniciar percurso do Ponto de Start',
                              child: InkWell(
                                onTap: () async {
                                  await notifier.clearCurrentSession();
                                  if (activeRoute != null) {
                                    await notifier.syncRouteFromFinder(
                                      activeRoute,
                                      userPosition: activeRoute.origin,
                                      originLabel: routeState.locationAddress,
                                    );
                                  }
                                },
                                child: const Icon(
                                  Icons.restart_alt_rounded,
                                  color: AppColors.textSecondary,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Ícones no canto superior direito (Sol/Clima + Bússola idênticos ao Pokémon GO)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Botão de estilo do mapa (Sol / Lua)
                        _TopRightCircleIcon(
                          tooltip: 'Alternar tema do mapa',
                          onTap: () {
                            setState(() {
                              _mapStyle = _mapStyle == DrunkMapStyle.pokemonGo
                                  ? DrunkMapStyle.osmCyberDark
                                  : DrunkMapStyle.pokemonGo;
                            });
                          },
                          child: Icon(
                            isDaylightStyle
                                ? Icons.wb_sunny_rounded
                                : Icons.nightlight_round,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Bússola Pokémon GO (recentraliza e trava câmera na setinha)
                        _TopRightCircleIcon(
                          tooltip: 'Centralizar na minha setinha',
                          onTap: () {
                            setState(() => _isFollowingUser = true);
                            _moveCameraToUser(userPos, zoom: 17.6);
                          },
                          child: Transform.rotate(
                            angle: -heading * (math.pi / 180.0),
                            child: const _CompassNeedleIcon(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. HUD INFERIOR ESTILO POKÉMON GO (Status à esquerda + Botão START/PAUSE central + Próxima parada à direita)
          Positioned(
            left: 14,
            right: 14,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: activeRoute == null || session == null
                  ? _NoRouteBanner(onGoToRoute: widget.onBack)
                  : _PokemonGoBottomHud(
                      session: session,
                      onMainButtonTap: () =>
                          _handleCentralButtonTap(session, notifier),
                      onSimulateStepTap: () {
                        setState(() => _isFollowingUser = true);
                        notifier.simulateStepToTarget();
                      },
                    ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Setinha direcional do usuário no centro do mapa ("apenas a setinha por enquanto")
class _PokemonGoUserArrow extends StatelessWidget {
  final double headingDegrees;

  const _PokemonGoUserArrow({
    required this.headingDegrees,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Sombra/halo de base no chão sob a setinha
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF00E5FF).withValues(alpha: 0.22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.8),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.55),
                blurRadius: 14,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        // Setinha direcional rotacionando conforme o movimento do celular
        Transform.rotate(
          angle: headingDegrees * (math.pi / 180.0),
          child: CustomPaint(
            size: const Size(34, 34),
            painter: _NavigationArrowPainter(),
          ),
        ),
      ],
    );
  }
}

class _NavigationArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final arrowPath = Path()
      ..moveTo(w * 0.5, h * 0.06) // Ponta norte da setinha
      ..lineTo(w * 0.86, h * 0.86) // Asa direita
      ..lineTo(w * 0.5, h * 0.68) // Recorte central traseiro
      ..lineTo(w * 0.14, h * 0.86) // Asa esquerda
      ..close();

    // Sombra projetada
    canvas.drawShadow(arrowPath, Colors.black, 6.0, true);

    // Preenchimento gradiente ciano/azul vibrante
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF00F0FF),
          Color(0xFF0088FF),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    canvas.drawPath(arrowPath, fillPaint);

    // Borda branca nítida
    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.4
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(arrowPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Marcador do Ponto de Start (Largada)
class _StartPointMarker extends StatelessWidget {
  final bool isReached;
  final bool hasStarted;

  const _StartPointMarker({
    required this.isReached,
    required this.hasStarted,
  });

  @override
  Widget build(BuildContext context) {
    final color = hasStarted
        ? AppColors.cyberGreen
        : (isReached ? AppColors.cyberGreen : AppColors.neonOrange);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xE60B0B0E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Text(
            hasStarted ? 'LARGADA ✓' : 'PONTO DE START',
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.6),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(
            Icons.flag_rounded,
            color: Colors.black,
            size: 16,
          ),
        ),
      ],
    );
  }
}

/// Marcador de Ponto de Parada (Bar) estilizado como PokéStop (cubo/diamante flutuante + base)
class _PokeStopBarMarker extends StatelessWidget {
  final Bar bar;
  final int order;
  final bool isCompleted;
  final bool isCurrentTarget;
  final bool isWithinRadius;

  const _PokeStopBarMarker({
    required this.bar,
    required this.order,
    required this.isCompleted,
    required this.isCurrentTarget,
    required this.isWithinRadius,
  });

  @override
  Widget build(BuildContext context) {
    final Color mainColor;
    if (isCompleted) {
      mainColor = AppColors.cyberGreen;
    } else if (isWithinRadius) {
      mainColor = AppColors.cyberGreen;
    } else if (isCurrentTarget) {
      mainColor = const Color(0xFF00E5FF);
    } else {
      mainColor = const Color(0xFF29B6F6);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Etiqueta com o nome da parada
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
          decoration: BoxDecoration(
            color: const Color(0xE60B0B0E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: mainColor,
              width: isCurrentTarget ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            '#${order.toString().padLeft(2, '0')} ${bar.name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isCompleted || isWithinRadius ? mainColor : Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 5),
        // Cubo/Diamante estilo PokéStop
        Transform.rotate(
          angle: math.pi / 4,
          child: Container(
            width: isCurrentTarget ? 26 : 22,
            height: isCurrentTarget ? 26 : 22,
            decoration: BoxDecoration(
              color: mainColor,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.white, width: 2.0),
              boxShadow: [
                BoxShadow(
                  color: mainColor.withValues(alpha: 0.7),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Transform.rotate(
              angle: -math.pi / 4,
              child: Center(
                child: isCompleted
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.black,
                        size: 14,
                      )
                    : Text(
                        '$order',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
          ),
        ),
        // Haste vertical do PokéStop
        Container(
          width: 3,
          height: 8,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      ],
    );
  }
}

/// HUD Inferior inspirado na tela principal do Pokémon GO:
/// - Esquerda: Cronômetro do Percurso + Progresso de Paradas
/// - Centro: Botão Orbe Principal (START no início -> PAUSE ao chegar na parada -> START para retomar)
/// - Direita: Pílula de proximidade + Botão de avanço no mapa para testes
class _PokemonGoBottomHud extends StatelessWidget {
  final RaceSession session;
  final VoidCallback onMainButtonTap;
  final VoidCallback onSimulateStepTap;

  const _PokemonGoBottomHud({
    required this.session,
    required this.onMainButtonTap,
    required this.onSimulateStepTap,
  });

  String _statusMessage() {
    if (session.isCompleted) {
      return 'PERCURSO CONCLUÍDO! (${session.elapsedFormatted})';
    }
    if (!session.hasStarted) {
      if (session.isAtStartPoint) {
        return 'NO PONTO DE START • APERTE START PARA COMEÇAR';
      }
      return 'VÁ ATÉ O PONTO DE START (${session.distanceToStartMeters.round()}m)';
    }
    if (session.isPaused) {
      final stopNum =
          (session.completedBarsCount + 1).clamp(1, session.totalBarsCount);
      return 'PAUSADO NA PARADA #$stopNum • APERTE START PARA CONTINUAR';
    }
    if (session.isAtStopPoint) {
      final stopNum =
          (session.completedBarsCount + 1).clamp(1, session.totalBarsCount);
      return 'CHEGOU NA PARADA #$stopNum • APERTE PAUSE';
    }
    final target = session.targetBar;
    final stopNum =
        (session.completedBarsCount + 1).clamp(1, session.totalBarsCount);
    return 'PERCURSO ATIVO • PARADA #$stopNum (${target != null ? "${session.distanceToTargetMeters.round()}m" : ""})';
  }

  @override
  Widget build(BuildContext context) {
    final targetBar = session.targetBar;
    final nextDistanceMeters = !session.hasStarted
        ? session.distanceToStartMeters.round()
        : session.distanceToTargetMeters.round();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pílula de status contextual logo acima do botão central
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xE60B0B0E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (session.canStartAtOrigin || session.canResumeFromStop)
                  ? AppColors.cyberGreen
                  : session.canPauseAtStop
                      ? AppColors.neonOrange
                      : Colors.white.withValues(alpha: 0.22),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
              ),
            ],
          ),
          child: Text(
            _statusMessage(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
        ),

        // Linha inferior Pokémon GO: [Status/Timer] --- [ORBE START/PAUSE] --- [Parada Alvo + Simular]
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Canto Inferior Esquerdo: Tempo de Percurso + Contador de Paradas
            Expanded(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xE60B0B0E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: session.hasStarted && !session.isPaused
                                  ? AppColors.cyberGreen
                                  : (session.isPaused && session.hasStarted
                                      ? AppColors.neonOrange
                                      : AppColors.textMuted),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            session.elapsedFormatted,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'PARADAS ${session.completedBarsCount}/${session.totalBarsCount}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Centro Inferior: Botão Orbe Principal (START / PAUSE)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: _CentralStartPauseOrb(
                session: session,
                onTap: onMainButtonTap,
              ),
            ),

            // Canto Inferior Direito: Botão Laranja (Simular Passo) + Pílula da Próxima Parada
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Botão circular laranja (igual ao binóculo do Pokémon GO) para avançar até o próximo ponto em testes
                  if (!session.isCompleted &&
                      (!session.hasStarted && !session.isAtStartPoint ||
                          (session.hasStarted &&
                              !session.isPaused &&
                              !session.isAtStopPoint)))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Tooltip(
                        message: !session.hasStarted
                            ? 'Ir para o Ponto de Start'
                            : 'Simular chegada na Parada',
                        child: Material(
                          color: AppColors.neonOrange,
                          shape: const CircleBorder(
                            side: BorderSide(color: Colors.white, width: 2),
                          ),
                          elevation: 6,
                          child: InkWell(
                            key: const Key('drunk_simulate_step_button'),
                            customBorder: const CircleBorder(),
                            onTap: onSimulateStepTap,
                            child: const SizedBox(
                              width: 44,
                              height: 44,
                              child: Icon(
                                Icons.near_me_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Pílula branca/translúcida estilo radar de proximidade do Pokémon GO
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          !session.hasStarted
                              ? Icons.flag_rounded
                              : Icons.sports_bar_rounded,
                          color: const Color(0xFF1E293B),
                          size: 16,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            session.isCompleted
                                ? 'FIM'
                                : !session.hasStarted
                                    ? 'START • ${nextDistanceMeters}m'
                                    : '#${(session.completedBarsCount + 1).toString().padLeft(2, '0')} • ${targetBar != null ? "${nextDistanceMeters}m" : ""}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Botão Central Estilo Pokébola:
/// - No Ponto de Start (`canStartAtOrigin`) -> Botão `START` ativo
/// - Longe do Ponto de Start (`!hasStarted && !isAtStartPoint`) -> Botão `START` desativado
/// - Em movimento até a parada -> `EM ROTA` (aguardando chegada na parada)
/// - Ao chegar no Ponto de Parada (`canPauseAtStop`) -> Vira `PAUSE` ativo
/// - Em Pause na parada (`canResumeFromStop`) -> Vira `START` ativo para voltar a contar o percurso
class _CentralStartPauseOrb extends StatelessWidget {
  final RaceSession session;
  final VoidCallback onTap;

  const _CentralStartPauseOrb({
    required this.session,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled;
    final String label;
    final IconData icon;
    final Color topColor;
    final Color glowColor;

    if (session.isCompleted) {
      isEnabled = true;
      label = 'START';
      icon = Icons.replay_rounded;
      topColor = AppColors.neonCyan;
      glowColor = AppColors.neonCyanGlow;
    } else if (!session.hasStarted) {
      isEnabled = session.canStartAtOrigin;
      label = 'START';
      icon = Icons.play_arrow_rounded;
      topColor = isEnabled ? AppColors.cyberGreen : const Color(0xFF475569);
      glowColor =
          isEnabled ? AppColors.cyberGreenGlow : Colors.transparent;
    } else if (session.canPauseAtStop) {
      isEnabled = true;
      label = 'PAUSE';
      icon = Icons.pause_rounded;
      topColor = AppColors.neonOrange;
      glowColor = AppColors.neonOrangeGlow;
    } else if (session.canResumeFromStop) {
      isEnabled = true;
      label = 'START';
      icon = Icons.play_arrow_rounded;
      topColor = AppColors.cyberGreen;
      glowColor = AppColors.cyberGreenGlow;
    } else {
      // Correndo entre paradas (ainda não chegou no ponto de parada)
      isEnabled = false;
      label = 'ROTA';
      icon = Icons.directions_run_rounded;
      topColor = const Color(0xFF00B4D8);
      glowColor = Colors.transparent;
    }

    return GestureDetector(
      key: const Key('drunk_central_action_button'),
      onTap: isEnabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: isEnabled ? 0.95 : 0.45),
            width: 3.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
            if (isEnabled)
              BoxShadow(
                color: glowColor,
                blurRadius: 22,
                spreadRadius: 4,
              ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.48, 0.52, 1.0],
            colors: [
              topColor,
              topColor,
              const Color(0xFF1E293B),
              Colors.white.withValues(alpha: isEnabled ? 0.96 : 0.55),
            ],
          ),
        ),
        child: Center(
          child: Container(
            width: 58,
            height: 58,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0F172A),
              border: Border.all(
                color: isEnabled ? topColor : Colors.white24,
                width: 2.5,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: isEnabled ? Colors.white : Colors.white54,
                    size: 20,
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      color: isEnabled ? Colors.white : Colors.white54,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopRightCircleIcon extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final String tooltip;

  const _TopRightCircleIcon({
    required this.child,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.38),
        shape: CircleBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.55), width: 1.5),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

/// Agulha de bússola vermelha e branca idêntica à do Pokémon GO
class _CompassNeedleIcon extends StatelessWidget {
  const _CompassNeedleIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(24, 24),
      painter: _CompassPainter(),
    );
  }
}

class _CompassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final northPath = Path()
      ..moveTo(w * 0.5, h * 0.08)
      ..lineTo(w * 0.72, h * 0.5)
      ..lineTo(w * 0.28, h * 0.5)
      ..close();

    final southPath = Path()
      ..moveTo(w * 0.5, h * 0.92)
      ..lineTo(w * 0.72, h * 0.5)
      ..lineTo(w * 0.28, h * 0.5)
      ..close();

    canvas.drawPath(
      northPath,
      Paint()
        ..color = const Color(0xFFFF3B30)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      southPath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NoRouteBanner extends StatelessWidget {
  final VoidCallback? onGoToRoute;

  const _NoRouteBanner({this.onGoToRoute});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xEB0B0B0E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.neonOrange.withValues(alpha: 0.6)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'NENHUMA ROTA GERADA NO MAPA',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Gere ou monte uma rota na aba ROTA para liberar o Ponto de Start e as paradas.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          if (onGoToRoute != null) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onGoToRoute,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonOrange,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              icon: const Icon(Icons.route_rounded, size: 18),
              label: const Text(
                'IR PARA ABA ROTA',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
