import 'package:latlong2/latlong.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/bar.dart';
import '../models/bar_model.dart';

/// Datasource responsável por buscar bares, pubs, botecos e cervejarias reais na Overpass API
class OverpassDatasource {
  final ApiClient _apiClient;

  OverpassDatasource({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Busca bares num raio [radiusMeters] ao redor da localização [center] do usuário
  Future<List<Bar>> fetchBarsAround({
    required LatLng center,
    double radiusMeters = 3500.0,
  }) async {
    final radiusInt = radiusMeters.toInt();
    final lat = center.latitude.toStringAsFixed(6);
    final lon = center.longitude.toStringAsFixed(6);

    final query = '''
[out:json][timeout:22];
(
  nwr["amenity"~"^(bar|pub|biergarten|nightclub)\$"](around:$radiusInt,$lat,$lon);
  nwr["craft"="brewery"](around:$radiusInt,$lat,$lon);
  nwr["amenity"~"^(restaurant|cafe|fast_food)\$"]["name"~"(Bar\\\\b|Boteco|Botequim|Choperia|Cervejaria|Pub\\\\b|Taberna|Espetinho)",i](around:$radiusInt,$lat,$lon);
);
out center;
''';

    AppException? lastError;

    for (final endpoint in ApiEndpoints.overpassMirrors) {
      try {
        Map<String, dynamic> data;
        try {
          data = await _apiClient.postFormJson(
            Uri.parse(endpoint),
            body: {'data': query},
            timeout: const Duration(seconds: 18),
          );
        } catch (_) {
          // Fallback GET caso algum proxy/mirror restrinja POST
          final getUri = Uri.parse(endpoint).replace(
            queryParameters: {'data': query},
          );
          data = await _apiClient.getJson(
            getUri,
            timeout: const Duration(seconds: 18),
          );
        }

        final elements = data['elements'] as List<dynamic>? ?? [];
        final primaryBars = <Bar>[];
        final secondaryBars = <Bar>[];
        final seenIds = <String>{};

        for (final elem in elements) {
          if (elem is Map<String, dynamic>) {
            final bar = BarModel.fromOverpassElement(elem);
            if (bar != null && !seenIds.contains(bar.id)) {
              seenIds.add(bar.id);
              if (bar.amenity == 'bar' ||
                  bar.amenity == 'pub' ||
                  bar.amenity == 'biergarten') {
                primaryBars.add(bar);
              } else {
                secondaryBars.add(bar);
              }
            }
          }
        }

        // Prioriza bares/pubs nativos quando há oferta suficiente (>= 12), complementando em bairros menores
        if (primaryBars.length >= 14) {
          return primaryBars;
        }
        return [...primaryBars, ...secondaryBars];
      } on AppException catch (e) {
        lastError = e;
      } catch (e) {
        lastError = NetworkException(
          'Erro ao consultar Overpass ($endpoint)',
          originalError: e,
        );
      }
    }

    throw lastError ??
        const NetworkException(
          'Não foi possível obter dados da Overpass API.',
        );
  }
}
