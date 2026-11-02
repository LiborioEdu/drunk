import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

/// Utilitário para cálculos geodésicos locais (Haversine & Azimute)
class HaversineCalculator {
  HaversineCalculator._();

  static const double earthRadiusMeters = 6371000.0;

  /// Retorna a distância em metros entre duas coordenadas esféricas
  static double distanceMeters(LatLng start, LatLng end) {
    final lat1Rad = start.latitude * (math.pi / 180.0);
    final lat2Rad = end.latitude * (math.pi / 180.0);
    final deltaLatRad = (end.latitude - start.latitude) * (math.pi / 180.0);
    final deltaLonRad = (end.longitude - start.longitude) * (math.pi / 180.0);

    final a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLonRad / 2) *
            math.sin(deltaLonRad / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  /// Retorna o azimute/rumo em graus (0º a 360º) de [from] para [to]
  static double bearingDegrees(LatLng from, LatLng to) {
    final lat1 = from.latitude * (math.pi / 180.0);
    final lon1 = from.longitude * (math.pi / 180.0);
    final lat2 = to.latitude * (math.pi / 180.0);
    final lon2 = to.longitude * (math.pi / 180.0);

    final dLon = lon2 - lon1;

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final initialBearingRad = math.atan2(y, x);
    final initialBearingDeg = initialBearingRad * (180.0 / math.pi);

    return (initialBearingDeg + 360.0) % 360.0;
  }

  /// Calcula a menor diferença angular (0º a 180º) entre dois azimutes
  static double angleDifference(double angle1, double angle2) {
    final diff = (angle1 - angle2).abs() % 360.0;
    return diff > 180.0 ? 360.0 - diff : diff;
  }

  /// Formata metros em string amigável (ex: "850 m" ou "1.2 km")
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      final km = meters / 1000.0;
      return '${km.toStringAsFixed(1)} km';
    }
  }
}
