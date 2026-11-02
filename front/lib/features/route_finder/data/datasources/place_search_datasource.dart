import 'package:latlong2/latlong.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/haversine_calculator.dart';
import '../../domain/entities/place_suggestion.dart';

/// Datasource de Autocomplete e Busca de Locais via Photon (Komoot/OSM) + fallback Nominatim
class PlaceSearchDatasource {
  final ApiClient _apiClient;

  PlaceSearchDatasource({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Busca endereços, bairros, cidades e bares com viés de proximidade para [proximity]
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    LatLng? proximity,
    int limit = 8,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    // 1. Primário: Photon by Komoot (autocomplete instantâneo enviesado por lat/lon)
    final photonResults = await _searchViaPhoton(
      trimmed,
      proximity: proximity,
      limit: limit,
    );
    if (photonResults.isNotEmpty) {
      return photonResults;
    }

    // 2. Fallback: Nominatim Search (JSONv2 com accept-language na query string)
    return _searchViaNominatim(
      trimmed,
      proximity: proximity,
      limit: limit,
    );
  }

  Future<List<PlaceSuggestion>> _searchViaPhoton(
    String query, {
    LatLng? proximity,
    required int limit,
  }) async {
    try {
      final params = <String, String>{
        'q': query,
        'limit': limit.toString(),
        if (proximity != null) ...{
          'lat': proximity.latitude.toStringAsFixed(5),
          'lon': proximity.longitude.toStringAsFixed(5),
        },
      };

      final uri =
          Uri.parse(ApiEndpoints.photonSearch).replace(queryParameters: params);
      final data = await _apiClient.getJson(
        uri,
        timeout: const Duration(seconds: 7),
      );

      final features = data['features'] as List<dynamic>? ?? const [];
      final results = <PlaceSuggestion>[];
      final seenKeys = <String>{};

      for (final raw in features) {
        if (raw is! Map<String, dynamic>) continue;
        final geometry = raw['geometry'] as Map<String, dynamic>?;
        final coords = geometry?['coordinates'] as List<dynamic>?;
        if (coords == null || coords.length < 2) continue;

        final lon = (coords[0] as num?)?.toDouble();
        final lat = (coords[1] as num?)?.toDouble();
        if (lat == null || lon == null) continue;

        final props = (raw['properties'] as Map<String, dynamic>?) ?? const {};
        final name = (props['name'] as String?)?.trim();
        final street = (props['street'] as String?)?.trim();
        final houseNumber = (props['housenumber'] as String?)?.trim();
        final district = ((props['district'] ?? props['suburb'] ?? props['locality'])
                as String?)
            ?.trim();
        final city =
            ((props['city'] ?? props['town'] ?? props['county']) as String?)
                ?.trim();
        final state = (props['state'] as String?)?.trim();
        final osmValue = (props['osm_value'] as String?)?.trim() ?? 'place';

        String title;
        if (name != null && name.isNotEmpty) {
          title = (street != null && street.isNotEmpty && street != name)
              ? name
              : (houseNumber != null ? '$name, $houseNumber' : name);
        } else if (street != null && street.isNotEmpty) {
          title = houseNumber != null ? '$street, $houseNumber' : street;
        } else if (district != null && district.isNotEmpty) {
          title = district;
        } else if (city != null && city.isNotEmpty) {
          title = city;
        } else {
          continue;
        }

        final subParts = <String>[
          if (street != null &&
              street.isNotEmpty &&
              street != title &&
              !title.startsWith(street))
            houseNumber != null ? '$street, $houseNumber' : street,
          if (district != null && district.isNotEmpty && district != title)
            district,
          if (city != null && city.isNotEmpty && city != title) city,
          if (state != null && state.isNotEmpty && state != city) state,
        ];
        final subtitle = subParts.take(3).join(' • ');

        final dedupeKey =
            '${title.toLowerCase()}|${lat.toStringAsFixed(3)}|${lon.toStringAsFixed(3)}';
        if (!seenKeys.add(dedupeKey)) continue;

        final point = LatLng(lat, lon);
        final dist = proximity != null
            ? HaversineCalculator.distanceMeters(proximity, point)
            : null;

        results.add(
          PlaceSuggestion(
            id: 'photon_${props['osm_id'] ?? results.length}',
            title: title,
            subtitle: subtitle,
            coordinates: point,
            category: osmValue,
            distanceMeters: dist,
          ),
        );
      }

      return results;
    } catch (_) {
      return const [];
    }
  }

  Future<List<PlaceSuggestion>> _searchViaNominatim(
    String query, {
    LatLng? proximity,
    required int limit,
  }) async {
    try {
      final params = <String, String>{
        'format': 'jsonv2',
        'q': query,
        'addressdetails': '1',
        'limit': limit.toString(),
        'accept-language': 'pt-BR,pt',
      };
      final uri = Uri.parse(ApiEndpoints.nominatimSearch)
          .replace(queryParameters: params);

      final rawList = await _apiClient.getJsonDynamic(
        uri,
        timeout: const Duration(seconds: 8),
      );
      if (rawList is! List) return const [];

      final results = <PlaceSuggestion>[];
      for (final item in rawList) {
        if (item is! Map<String, dynamic>) continue;
        final lat = double.tryParse(item['lat']?.toString() ?? '');
        final lon = double.tryParse(item['lon']?.toString() ?? '');
        if (lat == null || lon == null) continue;

        final address =
            (item['address'] as Map<String, dynamic>?) ?? const {};
        final name = (item['name'] as String?)?.trim();
        final road = (address['road'] as String?)?.trim();
        final suburb = ((address['suburb'] ??
                address['neighbourhood'] ??
                address['city_district']) as String?)
            ?.trim();
        final city = ((address['city'] ??
                address['town'] ??
                address['municipality']) as String?)
            ?.trim();

        final title = (name != null && name.isNotEmpty)
            ? name
            : (road ?? suburb ?? city ?? 'Localização');

        final subParts = <String>[
          if (road != null && road != title) road,
          if (suburb != null && suburb != title) suburb,
          if (city != null && city != title) city,
        ];

        final point = LatLng(lat, lon);
        final dist = proximity != null
            ? HaversineCalculator.distanceMeters(proximity, point)
            : null;

        results.add(
          PlaceSuggestion(
            id: 'nom_${item['place_id'] ?? results.length}',
            title: title,
            subtitle: subParts.join(' • '),
            coordinates: point,
            category: (item['type'] as String?) ?? 'place',
            distanceMeters: dist,
          ),
        );
      }
      return results;
    } catch (_) {
      return const [];
    }
  }
}
