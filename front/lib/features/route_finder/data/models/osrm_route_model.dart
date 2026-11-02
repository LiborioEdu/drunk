import 'package:latlong2/latlong.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/polyline_decoder.dart';

/// Modelo de resposta estruturado para cálculos de rota a pé via OSRM
class OsrmRouteModel {
  final double distanceMeters;
  final double durationSeconds;
  final List<LatLng> polyline;
  final List<double> legDistances;

  const OsrmRouteModel({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.polyline,
    required this.legDistances,
  });

  factory OsrmRouteModel.fromJson(Map<String, dynamic> data) {
    final code = data['code'] as String?;
    if (code != 'Ok') {
      throw NetworkException('OSRM retornou status inválido: $code');
    }

    final routes = data['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) {
      throw const NetworkException('Nenhuma rota a pé encontrada pelo OSRM.');
    }

    final primaryRoute = routes.first as Map<String, dynamic>;
    final totalDistance =
        (primaryRoute['distance'] as num?)?.toDouble() ?? 0.0;
    final totalDuration =
        (primaryRoute['duration'] as num?)?.toDouble() ?? 0.0;

    final geometry = primaryRoute['geometry'] as Map<String, dynamic>?;
    final rawCoords = geometry?['coordinates'] as List<dynamic>? ?? [];
    final polyline = PolylineDecoder.decodeGeoJson(rawCoords);

    final legs = primaryRoute['legs'] as List<dynamic>? ?? [];
    final legDistances = legs.map((leg) {
      if (leg is Map<String, dynamic>) {
        return (leg['distance'] as num?)?.toDouble() ?? 0.0;
      }
      return 0.0;
    }).toList();

    return OsrmRouteModel(
      distanceMeters: totalDistance,
      durationSeconds: totalDuration,
      polyline: polyline,
      legDistances: legDistances,
    );
  }
}
