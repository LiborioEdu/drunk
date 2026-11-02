import '../../domain/entities/bar.dart';

/// Modelo de dados para parsing dos nós da Overpass API
class BarModel {
  static Bar? fromOverpassElement(Map<String, dynamic> json) {
    double? lat;
    double? lon;

    if (json.containsKey('lat') && json.containsKey('lon')) {
      lat = (json['lat'] as num?)?.toDouble();
      lon = (json['lon'] as num?)?.toDouble();
    } else if (json.containsKey('center')) {
      final center = json['center'] as Map<String, dynamic>?;
      if (center != null) {
        lat = (center['lat'] as num?)?.toDouble();
        lon = (center['lon'] as num?)?.toDouble();
      }
    }

    if (lat == null || lon == null) {
      return null;
    }

    final tags = (json['tags'] as Map<String, dynamic>?) ?? {};
    final id = json['id']?.toString() ?? UniqueKey().toString();

    // Extrai nome preferencial
    String name = tags['name'] ??
        tags['name:pt'] ??
        tags['name:en'] ??
        tags['brand'] ??
        'Bar sem nome';

    // Extrai endereço aproximado
    final street = tags['addr:street'] as String?;
    final number = tags['addr:housenumber'] as String?;
    String? address;
    if (street != null) {
      address = number != null ? '$street, $number' : street;
    }

    final amenity = tags['amenity'] as String? ?? 'bar';

    return Bar(
      id: id,
      name: name,
      latitude: lat,
      longitude: lon,
      address: address,
      amenity: amenity,
    );
  }
}

class UniqueKey {
  static int _count = 0;
  @override
  String toString() => 'bar_${++_count}';
}
