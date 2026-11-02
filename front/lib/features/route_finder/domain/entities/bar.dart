import 'package:latlong2/latlong.dart';

/// Entidade que representa um bar/pub oficial cadastrado na cidade ou integrante da rota DRUNK
class Bar {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? address;
  final String amenity;
  final String? description;
  final int order; // 1 a 10 quando na rota
  final double distanceFromPrevious; // em metros

  const Bar({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    this.amenity = 'bar',
    this.description,
    this.order = 0,
    this.distanceFromPrevious = 0.0,
  });

  LatLng get coordinates => LatLng(latitude, longitude);

  Bar copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    String? address,
    String? amenity,
    String? description,
    int? order,
    double? distanceFromPrevious,
  }) {
    return Bar(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      amenity: amenity ?? this.amenity,
      description: description ?? this.description,
      order: order ?? this.order,
      distanceFromPrevious: distanceFromPrevious ?? this.distanceFromPrevious,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'amenity': amenity,
      if (description != null && description!.isNotEmpty)
        'description': description,
      'order': order,
      'distanceFromPrevious': distanceFromPrevious,
    };
  }

  /// JSON limpo apenas com dados cadastrais permanentes para exportar ao `city_bars_seed.json`
  Map<String, dynamic> toCatalogJson() {
    return {
      'id': id,
      'name': name,
      'latitude': double.parse(latitude.toStringAsFixed(6)),
      'longitude': double.parse(longitude.toStringAsFixed(6)),
      if (address != null && address!.isNotEmpty) 'address': address,
      'amenity': amenity,
      if (description != null && description!.isNotEmpty)
        'description': description,
    };
  }

  factory Bar.fromJson(Map<String, dynamic> map) {
    return Bar(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Bar sem nome',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      address: map['address']?.toString(),
      amenity: map['amenity']?.toString() ?? 'bar',
      description: map['description']?.toString(),
      order: (map['order'] as num?)?.toInt() ?? 0,
      distanceFromPrevious:
          (map['distanceFromPrevious'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
