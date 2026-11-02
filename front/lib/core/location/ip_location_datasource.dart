import 'package:latlong2/latlong.dart';
import '../constants/api_endpoints.dart';
import '../network/api_client.dart';

/// Resultado da localização aproximada por IP (fallback quando GPS nativo/permissão não está disponível)
class IpLocationResult {
  final LatLng coordinates;
  final String? label;

  const IpLocationResult({
    required this.coordinates,
    this.label,
  });
}

/// Datasource multi-mirror HTTPS + CORS para Geolocalização por IP sem chave de API
class IpLocationDatasource {
  final ApiClient _apiClient;

  IpLocationDatasource({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Tenta obter a localização real aproximada (cidade/bairro) via IP em cascata:
  /// 1. BigDataCloud (`api-bdc.net/data/reverse-geocode-client`)
  /// 2. GeoJS (`get.geojs.io/v1/ip/geo.json`)
  /// 3. ipwho.is (`ipwho.is`)
  Future<IpLocationResult?> fetchIpLocation() async {
    final fromBdc = await _tryBigDataCloud();
    if (fromBdc != null) return fromBdc;

    final fromGeoJs = await _tryGeoJs();
    if (fromGeoJs != null) return fromGeoJs;

    final fromIpWho = await _tryIpWhoIs();
    if (fromIpWho != null) return fromIpWho;

    return null;
  }

  Future<IpLocationResult?> _tryBigDataCloud() async {
    try {
      final uri = Uri.parse(ApiEndpoints.bigDataCloudReverseClient).replace(
        queryParameters: {'localityLanguage': 'pt'},
      );
      final data = await _apiClient.getJson(
        uri,
        timeout: const Duration(seconds: 6),
      );
      final lat = _parseDouble(data['latitude']);
      final lon = _parseDouble(data['longitude']);
      if (!_isValidLatLng(lat, lon)) return null;

      final locality = (data['locality'] as String?)?.trim();
      final city = (data['city'] as String?)?.trim();
      final stateCode = (data['principalSubdivisionCode'] as String?)
          ?.split('-')
          .last
          .trim();

      final parts = <String>[
        if (locality != null && locality.isNotEmpty) locality,
        if (city != null && city.isNotEmpty && city != locality) city,
      ];
      String? label = parts.isNotEmpty ? parts.join(' • ') : null;
      if (label != null && stateCode != null && stateCode.length <= 3) {
        label = '$label, $stateCode';
      }

      return IpLocationResult(
        coordinates: LatLng(lat!, lon!),
        label: label,
      );
    } catch (_) {
      return null;
    }
  }

  Future<IpLocationResult?> _tryGeoJs() async {
    try {
      final uri = Uri.parse(ApiEndpoints.geoJsIpGeo);
      final data = await _apiClient.getJson(
        uri,
        timeout: const Duration(seconds: 6),
      );
      final lat = _parseDouble(data['latitude']);
      final lon = _parseDouble(data['longitude']);
      if (!_isValidLatLng(lat, lon)) return null;

      final city = (data['city'] as String?)?.trim();
      final region = (data['region'] as String?)?.trim();
      final parts = <String>[
        if (city != null && city.isNotEmpty) city,
        if (region != null && region.isNotEmpty && region != city) region,
      ];

      return IpLocationResult(
        coordinates: LatLng(lat!, lon!),
        label: parts.isNotEmpty ? parts.join(' • ') : null,
      );
    } catch (_) {
      return null;
    }
  }

  Future<IpLocationResult?> _tryIpWhoIs() async {
    try {
      final uri = Uri.parse(ApiEndpoints.ipWhoIs);
      final data = await _apiClient.getJson(
        uri,
        timeout: const Duration(seconds: 6),
      );
      if (data['success'] == false) return null;

      final lat = _parseDouble(data['latitude']);
      final lon = _parseDouble(data['longitude']);
      if (!_isValidLatLng(lat, lon)) return null;

      final city = (data['city'] as String?)?.trim();
      final regionCode = (data['region_code'] as String?)?.trim();
      String? label;
      if (city != null && city.isNotEmpty) {
        label = (regionCode != null && regionCode.isNotEmpty)
            ? '$city, $regionCode'
            : city;
      }

      return IpLocationResult(
        coordinates: LatLng(lat!, lon!),
        label: label,
      );
    } catch (_) {
      return null;
    }
  }

  double? _parseDouble(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw.trim());
    return null;
  }

  bool _isValidLatLng(double? lat, double? lon) {
    if (lat == null || lon == null) return false;
    if (!lat.isFinite || !lon.isFinite) return false;
    if (lat == 0.0 && lon == 0.0) return false;
    return lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180;
  }
}
