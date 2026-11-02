import 'package:latlong2/latlong.dart';

/// Decodificador de geometrias de rotas (Polyline string e GeoJSON)
class PolylineDecoder {
  PolylineDecoder._();

  /// Decodifica lista de coordenadas GeoJSON `[[lng, lat], ...]` para `List<LatLng>`
  static List<LatLng> decodeGeoJson(List<dynamic> coordinates) {
    final points = <LatLng>[];
    for (final coord in coordinates) {
      if (coord is List && coord.length >= 2) {
        final lng = (coord[0] as num).toDouble();
        final lat = (coord[1] as num).toDouble();
        points.add(LatLng(lat, lng));
      }
    }
    return points;
  }

  /// Decodifica string codificada no formato padrão Google Polyline (fator 1e5)
  static List<LatLng> decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }
}
