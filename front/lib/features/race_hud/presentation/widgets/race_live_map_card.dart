import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/drunk_map_tiles.dart';
import '../../domain/entities/race_session.dart';

/// Mapa de navegação vivo no HUD com trilha bicolor (Verde visitado + Laranja restante) e Geofence de 20m
class RaceLiveMapCard extends StatefulWidget {
  final RaceSession session;

  const RaceLiveMapCard({
    super.key,
    required this.session,
  });

  @override
  State<RaceLiveMapCard> createState() => _RaceLiveMapCardState();
}

class _RaceLiveMapCardState extends State<RaceLiveMapCard> {
  final MapController _mapController = MapController();
  bool _isMapReady = false;

  @override
  void didUpdateWidget(covariant RaceLiveMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isMapReady &&
        widget.session.currentPosition != oldWidget.session.currentPosition) {
      _mapController.move(
        widget.session.currentPosition,
        _mapController.camera.zoom,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final completedCoords = <LatLng>[session.route.origin];
    for (int i = 0; i < session.completedBarsCount && i < session.route.bars.length; i++) {
      completedCoords.add(session.route.bars[i].coordinates);
    }
    completedCoords.add(session.currentPosition);

    final remainingCoords = <LatLng>[session.currentPosition];
    for (int i = session.completedBarsCount; i < session.route.bars.length; i++) {
      remainingCoords.add(session.route.bars[i].coordinates);
    }

    final targetBar = session.targetBar;
    final markers = <Marker>[];

    // Marcadores dos 10 Bares (Verde se concluído, Laranja se pendente)
    for (int i = 0; i < session.route.bars.length; i++) {
      final bar = session.route.bars[i];
      final isDone = i < session.completedBarsCount;
      final isCurrentTarget = i == session.completedBarsCount;

      markers.add(
        Marker(
          point: bar.coordinates,
          width: isCurrentTarget ? 140 : 34,
          height: isCurrentTarget ? 68 : 34,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isCurrentTarget)
                Container(
                  margin: const EdgeInsets.only(bottom: 3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: session.isWithinGeofence
                          ? AppColors.cyberGreen
                          : AppColors.neonOrange,
                    ),
                  ),
                  child: Text(
                    '${bar.name} (${session.distanceToTargetMeters.round()}m)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: session.isWithinGeofence
                          ? AppColors.cyberGreen
                          : Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              Container(
                width: isCurrentTarget ? 34 : 28,
                height: isCurrentTarget ? 34 : 28,
                decoration: BoxDecoration(
                  color: isDone ? AppColors.cyberGreen : AppColors.neonOrange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.8),
                  boxShadow: [
                    BoxShadow(
                      color: isDone
                          ? AppColors.cyberGreenGlow
                          : AppColors.neonOrangeGlow,
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: isDone
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.black,
                          size: 16,
                        )
                      : Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Beacon GPS ao Vivo do Corredor (Neon Cyan)
    markers.add(
      Marker(
        point: session.currentPosition,
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.neonCyan.withValues(alpha: 0.22),
                border: Border.all(
                  color: AppColors.neonCyan.withValues(alpha: 0.6),
                ),
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.neonCyan,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
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
      ),
    );

    return Container(
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: session.currentPosition,
                initialZoom: 15.8,
                minZoom: 5,
                maxZoom: 19,
                onMapReady: () {
                  _isMapReady = true;
                },
              ),
              children: [
                const DrunkMapTileLayer(),
                if (targetBar != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: targetBar.coordinates,
                        radius: RaceSession.geofenceRadiusMeters,
                        useRadiusInMeter: true,
                        color: (session.isWithinGeofence
                                ? AppColors.cyberGreen
                                : AppColors.neonOrange)
                            .withValues(alpha: 0.20),
                        borderColor: session.isWithinGeofence
                            ? AppColors.cyberGreen
                            : AppColors.neonOrange,
                        borderStrokeWidth: 2.0,
                      ),
                    ],
                  ),
                PolylineLayer(
                  polylines: [
                    if (session.route.polyline.isNotEmpty)
                      Polyline(
                        points: session.route.polyline,
                        strokeWidth: 4.0,
                        color: AppColors.neonOrange.withValues(alpha: 0.30),
                      ),
                    if (completedCoords.length >= 2)
                      Polyline(
                        points: completedCoords,
                        strokeWidth: 5.0,
                        color: AppColors.cyberGreen,
                      ),
                    if (remainingCoords.length >= 2)
                      Polyline(
                        points: remainingCoords,
                        strokeWidth: 4.5,
                        color: AppColors.neonOrange,
                      ),
                  ],
                ),
                MarkerLayer(markers: markers),
              ],
            ),

            // Badge Modo Navegação
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.radar_rounded,
                      color: AppColors.neonCyan,
                      size: 13,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'GEOFENCE RADAR 20M',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Botão Recentralizar no Corredor
            Positioned(
              right: 12,
              top: 12,
              child: Material(
                color: AppColors.background.withValues(alpha: 0.88),
                shape: const CircleBorder(
                  side: BorderSide(color: AppColors.neonCyan),
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _mapController.move(
                    session.currentPosition,
                    16.5,
                  ),
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(
                      Icons.my_location_rounded,
                      color: AppColors.neonCyan,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
