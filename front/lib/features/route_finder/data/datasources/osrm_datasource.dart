import 'package:latlong2/latlong.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/osrm_route_model.dart';

/// Alias de compatibilidade
typedef OsrmRouteResult = OsrmRouteModel;

/// Datasource multi-mirror para traçado e cálculo real pelas ruas via OSRM
class OsrmDatasource {
  final ApiClient _apiClient;

  OsrmDatasource({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Traça a rota a pé passando ordenadamente por todas as [coordinates]
  Future<OsrmRouteModel> calculateFootRoute(List<LatLng> coordinates) async {
    if (coordinates.length < 2) {
      throw ArgumentError(
        'São necessárias pelo menos 2 coordenadas para calcular a rota.',
      );
    }

    final coordsParam = coordinates
        .map((c) =>
            '${c.longitude.toStringAsFixed(6)},${c.latitude.toStringAsFixed(6)}')
        .join(';');

    AppException? lastError;

    for (final base in ApiEndpoints.osrmFootMirrors) {
      try {
        final uri = Uri.parse(
          '$base/$coordsParam?overview=full&geometries=geojson&steps=false',
        );
        final json = await _apiClient.getJson(
          uri,
          timeout: const Duration(seconds: 12),
        );
        return OsrmRouteModel.fromJson(json);
      } on AppException catch (e) {
        lastError = e;
      } catch (e) {
        lastError = NetworkException(
          'Erro ao traçar rota OSRM ($base)',
          originalError: e,
        );
      }
    }

    throw lastError ??
        const NetworkException('Serviço de roteamento OSRM indisponível.');
  }
}
