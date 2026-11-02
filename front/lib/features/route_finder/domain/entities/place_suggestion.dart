import 'package:latlong2/latlong.dart';

/// Sugestão de endereço, bairro, cidade ou estabelecimento (Autocomplete estilo Google Maps)
class PlaceSuggestion {
  final String id;
  final String title;
  final String subtitle;
  final LatLng coordinates;
  final String category;
  final double? distanceMeters;

  const PlaceSuggestion({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.coordinates,
    this.category = 'place',
    this.distanceMeters,
  });

  String get formattedLabel =>
      subtitle.isNotEmpty ? '$title • $subtitle' : title;

  String? get formattedDistance {
    final d = distanceMeters;
    if (d == null || !d.isFinite) return null;
    if (d < 1000) return '${d.round()} m';
    return '${(d / 1000.0).toStringAsFixed(1)} km';
  }
}
