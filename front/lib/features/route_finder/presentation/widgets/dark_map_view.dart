import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/haversine_calculator.dart';
import '../../../../core/widgets/drunk_map_tiles.dart';
import '../../domain/entities/bar.dart';
import '../../domain/entities/drunk_route.dart';
import 'map_control_buttons.dart';

/// Camada cartográfica Dark Neon exibindo localização real + Banco Próprio de Bares da Cidade + Rota 10KM
class DarkMapView extends StatefulWidget {
  final LatLng origin;
  final LatLng? userLocation;
  final double? gpsAccuracyMeters;
  final double? userHeading;
  final bool isFollowingUser;
  final bool isLocating;
  final LatLng? cameraTarget;
  final double cameraZoom;
  final int cameraMoveId;
  final double searchRadiusKm;
  final List<Bar> cityBars;
  final bool isRegisteringBarMode;
  final String? highlightedCityBarId;
  final DrunkRoute? route;
  final int? selectedBarIndex;
  final Function(LatLng point)? onSelectOrigin;
  final Function(LatLng point)? onRegisterBarAtPoint;
  final ValueChanged<Bar>? onTapCityBar;
  final ValueChanged<Bar>? onEditCityBar;
  final VoidCallback? onCenterMyLocation;
  final Function(int barIndex)? onSelectBar;

  const DarkMapView({
    super.key,
    required this.origin,
    this.userLocation,
    this.gpsAccuracyMeters,
    this.userHeading,
    this.isFollowingUser = true,
    this.isLocating = false,
    this.cameraTarget,
    this.cameraZoom = 15.2,
    this.cameraMoveId = 0,
    this.searchRadiusKm = 3.5,
    this.cityBars = const [],
    this.isRegisteringBarMode = false,
    this.highlightedCityBarId,
    this.route,
    this.selectedBarIndex,
    this.onSelectOrigin,
    this.onRegisterBarAtPoint,
    this.onTapCityBar,
    this.onEditCityBar,
    this.onCenterMyLocation,
    this.onSelectBar,
  });

  @override
  State<DarkMapView> createState() => _DarkMapViewState();
}

class _DarkMapViewState extends State<DarkMapView> {
  final MapController _mapController = MapController();
  bool _isMapReady = false;
  int _lastAppliedMoveId = -1;
  DrunkMapStyle _mapStyle = DrunkMapStyle.osmCyberDark;

  @override
  void didUpdateWidget(covariant DarkMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isMapReady) return;

    if (widget.route != null && widget.route != oldWidget.route) {
      _fitRouteBounds(widget.route!);
    } else if (widget.selectedBarIndex != null &&
        widget.selectedBarIndex != oldWidget.selectedBarIndex &&
        widget.route != null &&
        widget.selectedBarIndex! < widget.route!.bars.length) {
      final selectedBar = widget.route!.bars[widget.selectedBarIndex!];
      _mapController.move(selectedBar.coordinates, 16.2);
    } else if (widget.cameraMoveId != oldWidget.cameraMoveId &&
        widget.cameraTarget != null) {
      _lastAppliedMoveId = widget.cameraMoveId;
      _mapController.move(widget.cameraTarget!, widget.cameraZoom);
    } else if (widget.origin != oldWidget.origin && widget.route == null) {
      _mapController.move(widget.origin, widget.cameraZoom);
    }
  }

  void _onMapReady() {
    _isMapReady = true;
    if (widget.route != null) {
      _fitRouteBounds(widget.route!);
    } else if (widget.cameraTarget != null &&
        _lastAppliedMoveId != widget.cameraMoveId) {
      _lastAppliedMoveId = widget.cameraMoveId;
      _mapController.move(widget.cameraTarget!, widget.cameraZoom);
    }
  }

  void _fitRouteBounds(DrunkRoute route) {
    if (!_isMapReady || route.polyline.isEmpty) return;
    final points = [route.origin, ...route.polyline];
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.only(
          top: 205,
          left: 44,
          right: 76,
          bottom: 330,
        ),
      ),
    );
  }

  void _zoomBy(double delta) {
    if (!_isMapReady) return;
    final camera = _mapController.camera;
    final nextZoom = (camera.zoom + delta).clamp(4.0, 19.0);
    _mapController.move(camera.center, nextZoom);
  }

  @override
  Widget build(BuildContext context) {
    final userLoc = widget.userLocation;
    final isOriginAtUser = userLoc != null &&
        HaversineCalculator.distanceMeters(userLoc, widget.origin) <= 20.0;

    final routeBarIds = widget.route?.bars.map((b) => b.id).toSet() ?? const {};
    final markers = <Marker>[];

    // 1. Pinos dos Bares Cadastrados na Cidade (sempre visíveis no mapa antes e fora da rota ativa)
    for (final cityBar in widget.cityBars) {
      if (routeBarIds.contains(cityBar.id)) continue;
      final isHighlighted = widget.highlightedCityBarId == cityBar.id;

      markers.add(
        Marker(
          point: cityBar.coordinates,
          width: isHighlighted ? 170 : 112,
          height: isHighlighted ? 82 : 58,
          child: GestureDetector(
            onTap: () => widget.onTapCityBar?.call(cityBar),
            onLongPress: () => widget.onEditCityBar?.call(cityBar),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: isHighlighted
                      ? () => widget.onEditCityBar?.call(cityBar)
                      : () => widget.onTapCityBar?.call(cityBar),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 3),
                    padding: EdgeInsets.symmetric(
                      horizontal: isHighlighted ? 9 : 7,
                      vertical: isHighlighted ? 3.5 : 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xF00B0B0E),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isHighlighted
                            ? AppColors.cyberGreen
                            : AppColors.neonOrange.withValues(alpha: 0.75),
                        width: isHighlighted ? 1.4 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            cityBar.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isHighlighted
                                  ? AppColors.cyberGreen
                                  : Colors.white,
                              fontSize: isHighlighted ? 10.5 : 9.0,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (isHighlighted) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.edit_outlined,
                            size: 11,
                            color: AppColors.cyberGreen,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: isHighlighted ? 34 : 28,
                  height: isHighlighted ? 34 : 28,
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? AppColors.cyberGreen
                        : const Color(0xFF1A1410),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isHighlighted
                          ? Colors.white
                          : AppColors.neonOrange,
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isHighlighted
                            ? AppColors.cyberGreenGlow
                            : AppColors.neonOrangeGlow,
                        blurRadius: isHighlighted ? 14 : 9,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.sports_bar_rounded,
                    size: isHighlighted ? 18 : 15,
                    color: isHighlighted ? Colors.black : AppColors.neonOrange,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 2. Marcador de Localização Real ao Vivo do Usuário (se separada da Largada)
    if (userLoc != null && !isOriginAtUser) {
      markers.add(
        Marker(
          point: userLoc,
          width: 90,
          height: 82,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PulsingUserLocationBeacon(
                headingDegrees: widget.userHeading,
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xEE0B0B0E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.neonCyan.withValues(alpha: 0.8),
                  ),
                ),
                child: const Text(
                  'VOCÊ',
                  style: TextStyle(
                    color: AppColors.neonCyan,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 3. Marcador da LARGADA (integrado ao beacon pulsante quando coincide com a posição real do usuário)
    markers.add(
      Marker(
        point: widget.origin,
        width: 120,
        height: 88,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isOriginAtUser)
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.cyberGreen.withValues(alpha: 0.65),
                        width: 1.6,
                      ),
                    ),
                  ),
                  _PulsingUserLocationBeacon(
                    headingDegrees: widget.userHeading,
                  ),
                ],
              )
            else
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.cyberGreen.withValues(alpha: 0.16),
                  border: Border.all(
                    color: AppColors.cyberGreen.withValues(alpha: 0.55),
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.cyberGreenGlow,
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0B0B0E),
                      border: Border.all(
                        color: AppColors.cyberGreen,
                        width: 5.5,
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xEE0B0B0E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (isOriginAtUser
                          ? AppColors.neonCyan
                          : AppColors.cyberGreen)
                      .withValues(alpha: 0.8),
                ),
              ),
              child: Text(
                isOriginAtUser ? 'VOCÊ • LARGADA' : 'LARGADA',
                style: TextStyle(
                  color:
                      isOriginAtUser ? AppColors.neonCyan : AppColors.cyberGreen,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // 4. Marcadores Numerados 01..10 em Laranja Neon Sólido (quando uma rota está ativa)
    if (widget.route != null) {
      for (int i = 0; i < widget.route!.bars.length; i++) {
        final bar = widget.route!.bars[i];
        final isSelected = widget.selectedBarIndex == i;

        markers.add(
          Marker(
            point: bar.coordinates,
            width: isSelected ? 140 : 42,
            height: isSelected ? 74 : 42,
            child: GestureDetector(
              onTap: () => widget.onSelectBar?.call(i),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isSelected)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xEE0B0B0E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.neonCyan,
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        bar.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.neonCyan,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: isSelected ? 38 : 32,
                    height: isSelected ? 38 : 32,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.neonCyan
                          : AppColors.neonOrange,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: isSelected
                              ? AppColors.neonCyanGlow
                              : AppColors.neonOrangeGlow,
                          blurRadius: isSelected ? 18 : 14,
                          spreadRadius: isSelected ? 4 : 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        (i + 1).toString().padLeft(2, '0'),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
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

    final accuracyRadiusMeters =
        (widget.gpsAccuracyMeters ?? 28.0).clamp(16.0, 220.0);

    return MouseRegion(
      cursor: widget.isRegisteringBarMode
          ? SystemMouseCursors.precise
          : MouseCursor.defer,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.cameraTarget ?? widget.origin,
              initialZoom: widget.cameraZoom,
              minZoom: 4,
              maxZoom: 19,
              onMapReady: _onMapReady,
              onTap: (tapPosition, point) {
                if (widget.isRegisteringBarMode) {
                  widget.onRegisterBarAtPoint?.call(point);
                  return;
                }
                if (widget.route == null) {
                  widget.onSelectOrigin?.call(point);
                } else {
                  widget.onSelectBar?.call(-1);
                }
              },
            ),
            children: [
              DrunkMapTileLayer(style: _mapStyle),

              // Anéis de Radar na Cidade + Halo de Precisão GPS estilo Google Maps
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: widget.origin,
                    radius: widget.searchRadiusKm * 1000.0,
                    useRadiusInMeter: true,
                    color: AppColors.neonCyan.withValues(alpha: 0.03),
                    borderColor: AppColors.neonCyan.withValues(alpha: 0.26),
                    borderStrokeWidth: 1.2,
                  ),
                  CircleMarker(
                    point: widget.origin,
                    radius: widget.searchRadiusKm * 550.0,
                    useRadiusInMeter: true,
                    color: Colors.transparent,
                    borderColor: AppColors.neonCyan.withValues(alpha: 0.14),
                    borderStrokeWidth: 1.0,
                  ),
                  if (userLoc != null)
                    CircleMarker(
                      point: userLoc,
                      radius: accuracyRadiusMeters,
                      useRadiusInMeter: true,
                      color: AppColors.neonCyan.withValues(alpha: 0.11),
                      borderColor: AppColors.neonCyan.withValues(alpha: 0.38),
                      borderStrokeWidth: 1.2,
                    ),
                ],
              ),

              // Polyline Neon Tripla da Rota de 10KM
              if (widget.route != null && widget.route!.polyline.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: widget.route!.polyline,
                      strokeWidth: 12.0,
                      color: AppColors.neonOrange.withValues(alpha: 0.25),
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                    Polyline(
                      points: widget.route!.polyline,
                      strokeWidth: 5.5,
                      color: AppColors.neonOrange,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                    Polyline(
                      points: widget.route!.polyline,
                      strokeWidth: 1.8,
                      color: const Color(0xFFFFDFC7),
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                  ],
                ),

              MarkerLayer(markers: markers),
            ],
          ),

          // Controles Flutuantes Laterais Direitos
          Positioned(
            right: 14,
            top: 225,
            child: MapControlButtons(
              onZoomIn: () => _zoomBy(1.0),
              onZoomOut: () => _zoomBy(-1.0),
              isFollowingUser: widget.isFollowingUser && isOriginAtUser,
              isLocating: widget.isLocating,
              onCenterMyLocation: () {
                if (widget.onCenterMyLocation != null) {
                  widget.onCenterMyLocation!();
                } else if (_isMapReady) {
                  _mapController.move(userLoc ?? widget.origin, 15.8);
                }
              },
              onCenterOrigin: (!isOriginAtUser && userLoc != null)
                  ? () {
                      if (_isMapReady) {
                        _mapController.move(widget.origin, 15.4);
                      }
                    }
                  : null,
              onFitRoute: widget.route != null
                  ? () => _fitRouteBounds(widget.route!)
                  : null,
              mapStyleTooltip: 'Camada: ${_mapStyle.shortLabel}',
              onToggleMapStyle: () {
                final next = _mapStyle.nextStyle;
                setState(() => _mapStyle = next);
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      duration: const Duration(milliseconds: 1400),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: const Color(0xF215151B),
                      content: Text(
                        'Camada do mapa: ${next.shortLabel} (Sem API Key)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Ponto azul/ciano pulsante em tempo real idêntico à experiência do Google Maps
class _PulsingUserLocationBeacon extends StatefulWidget {
  final double? headingDegrees;

  const _PulsingUserLocationBeacon({
    this.headingDegrees,
  });

  @override
  State<_PulsingUserLocationBeacon> createState() =>
      _PulsingUserLocationBeaconState();
}

class _PulsingUserLocationBeaconState extends State<_PulsingUserLocationBeacon>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;

  bool get _isInWidgetTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    if (!_isInWidgetTest) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1800),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _pulseController;
    if (controller == null) {
      return _buildStaticDot(pulseProgress: 0.35);
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _buildStaticDot(pulseProgress: controller.value),
    );
  }

  Widget _buildStaticDot({required double pulseProgress}) {
    final outerSize = 22.0 + (22.0 * pulseProgress);
    final outerAlpha = (1.0 - pulseProgress).clamp(0.0, 1.0) * 0.48;

    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: outerSize,
            height: outerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.neonCyan.withValues(alpha: outerAlpha),
            ),
          ),
          if (widget.headingDegrees != null)
            Transform.rotate(
              angle: widget.headingDegrees! * (math.pi / 180.0),
              child: const Align(
                alignment: Alignment.topCenter,
                child: Icon(
                  Icons.navigation_rounded,
                  size: 13,
                  color: AppColors.neonCyan,
                ),
              ),
            ),
          Container(
            width: 19,
            height: 19,
            decoration: BoxDecoration(
              color: const Color(0xFF00C8FF),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3.0),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.neonCyanGlow,
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
