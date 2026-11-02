import 'package:latlong2/latlong.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';

/// Datasource de Geocodificação Reversa em cascata CORS-Safe:
/// 1. Nominatim (`accept-language` via query param — sem preflight no browser)
/// 2. Photon Reverse (`photon.komoot.io/reverse`)
/// 3. BigDataCloud Reverse Client (`api-bdc.net/data/reverse-geocode-client`)
class NominatimDatasource {
  final ApiClient _apiClient;

  NominatimDatasource({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Converte uma coordenada [point] em um endereço amigável (ex: "Rua Augusta • Consolação")
  Future<String> reverseGeocode(LatLng point) async {
    final fromNominatim = await _tryNominatim(point);
    if (fromNominatim != null) return fromNominatim;

    final fromPhoton = await _tryPhotonReverse(point);
    if (fromPhoton != null) return fromPhoton;

    final fromBdc = await _tryBigDataCloudReverse(point);
    if (fromBdc != null) return fromBdc;

    return '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
  }

  Future<String?> _tryNominatim(LatLng point) async {
    final uri = Uri.parse(ApiEndpoints.nominatimReverse).replace(
      queryParameters: {
        'format': 'jsonv2',
        'lat': point.latitude.toStringAsFixed(6),
        'lon': point.longitude.toStringAsFixed(6),
        'zoom': '18',
        'addressdetails': '1',
        'accept-language': 'pt-BR,pt',
      },
    );

    try {
      final data = await _apiClient.getJson(
        uri,
        timeout: const Duration(seconds: 6),
      );

      final address = data['address'] as Map<String, dynamic>?;
      if (address != null) {
        final road = address['road'] ??
            address['pedestrian'] ??
            address['footway'] ??
            address['suburb'];
        final number = address['house_number'];
        final suburb = address['suburb'] ??
            address['neighbourhood'] ??
            address['city_district'];
        final city =
            address['city'] ?? address['town'] ?? address['municipality'];

        final roadWithNumber = (road is String && road.isNotEmpty)
            ? (number is String && number.isNotEmpty ? '$road, $number' : road)
            : null;

        final parts = <String>[
          ?roadWithNumber,
          if (suburb is String && suburb.isNotEmpty && suburb != road) suburb,
          if (city is String && city.isNotEmpty && _partsIsShort(road, suburb))
            city,
        ];

        if (parts.isNotEmpty) {
          return parts.join(' • ');
        }
      }

      final displayName = data['display_name'] as String?;
      if (displayName != null && displayName.isNotEmpty) {
        final segments = displayName.split(',').map((s) => s.trim()).toList();
        return segments.take(2).join(', ');
      }
    } catch (_) {
      // Avança para o próximo provedor CORS-safe
    }
    return null;
  }

  Future<String?> _tryPhotonReverse(LatLng point) async {
    final uri = Uri.parse(ApiEndpoints.photonReverse).replace(
      queryParameters: {
        'lat': point.latitude.toStringAsFixed(6),
        'lon': point.longitude.toStringAsFixed(6),
      },
    );

    try {
      final data = await _apiClient.getJson(
        uri,
        timeout: const Duration(seconds: 6),
      );
      final features = data['features'] as List<dynamic>?;
      if (features == null || features.isEmpty) return null;

      final first = features.first;
      if (first is! Map<String, dynamic>) return null;
      final props = (first['properties'] as Map<String, dynamic>?) ?? const {};

      final street = (props['street'] ?? props['name']) as String?;
      final number = props['housenumber'] as String?;
      final district =
          (props['district'] ?? props['suburb'] ?? props['locality'])
              as String?;
      final city = (props['city'] ?? props['town']) as String?;

      final streetFormatted = (street != null && street.isNotEmpty)
          ? (number != null && number.isNotEmpty ? '$street, $number' : street)
          : null;

      final parts = <String>[
        ?streetFormatted,
        if (district != null && district.isNotEmpty && district != street)
          district,
        if (city != null &&
            city.isNotEmpty &&
            _partsIsShort(streetFormatted, district))
          city,
      ];
      if (parts.isNotEmpty) return parts.join(' • ');
    } catch (_) {
      // Avança para BigDataCloud
    }
    return null;
  }

  Future<String?> _tryBigDataCloudReverse(LatLng point) async {
    final uri = Uri.parse(ApiEndpoints.bigDataCloudReverseClient).replace(
      queryParameters: {
        'latitude': point.latitude.toStringAsFixed(6),
        'longitude': point.longitude.toStringAsFixed(6),
        'localityLanguage': 'pt',
      },
    );

    try {
      final data = await _apiClient.getJson(
        uri,
        timeout: const Duration(seconds: 6),
      );
      final locality = (data['locality'] as String?)?.trim();
      final city = (data['city'] as String?)?.trim();
      final state = (data['principalSubdivisionCode'] as String?)
          ?.split('-')
          .last
          .trim();

      final parts = <String>[
        if (locality != null && locality.isNotEmpty) locality,
        if (city != null && city.isNotEmpty && city != locality) city,
      ];
      if (parts.isEmpty) return null;
      final joined = parts.join(' • ');
      if (state != null && state.length <= 3) {
        return '$joined, $state';
      }
      return joined;
    } catch (_) {
      return null;
    }
  }

  bool _partsIsShort(Object? road, Object? suburb) {
    return road == null || suburb == null;
  }
}
