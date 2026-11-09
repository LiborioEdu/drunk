import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Amostra de telemetria GPS contendo coordenada atual, velocidade em km/h e direção (heading)
class GpsTelemetrySample {
  final LatLng coordinates;
  final double speedKmh;
  final double? headingDegrees;
  final DateTime timestamp;

  const GpsTelemetrySample({
    required this.coordinates,
    required this.speedKmh,
    this.headingDegrees,
    required this.timestamp,
  });
}

/// Serviço que encapsula o stream de GPS em tempo real (`geolocator`)
class GpsTelemetryService {
  /// Inicia o monitoramento contínuo de posição caso o GPS e as permissões estejam ativos
  Stream<GpsTelemetrySample> watchPosition() async* {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      const settings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
      );

      await for (final pos
          in Geolocator.getPositionStream(locationSettings: settings)) {
        final rawSpeedMs = pos.speed.isFinite && pos.speed > 0 ? pos.speed : 0.0;
        final validHeading =
            pos.heading.isFinite && pos.heading >= 0 ? pos.heading : null;
        yield GpsTelemetrySample(
          coordinates: LatLng(pos.latitude, pos.longitude),
          speedKmh: rawSpeedMs * 3.6,
          headingDegrees: validHeading,
          timestamp: pos.timestamp,
        );
      }
    } catch (_) {
      // Em ambientes sem hardware GPS (Linux Desktop / Web sem HTTPS), opera via modo simulação/manual
      return;
    }
  }
}
