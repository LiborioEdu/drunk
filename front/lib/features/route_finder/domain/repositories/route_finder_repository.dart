import 'package:latlong2/latlong.dart';
import '../../data/models/osrm_route_model.dart';
import '../entities/bar.dart';
import '../entities/place_suggestion.dart';

/// Contrato de repositório para operações de mapa, banco próprio de bares da cidade, busca e rotas
abstract class RouteFinderRepository {
  /// Carrega todos os bares oficiais cadastrados no banco de dados da cidade
  Future<List<Bar>> getAllCityBars();

  /// Busca bares do banco próprio da cidade próximos ao [center] dentro de [radiusMeters]
  Future<List<Bar>> getNearbyBars({
    required LatLng center,
    required double radiusMeters,
  });

  /// Salva (cria ou edita) um bar oficial no banco da cidade
  Future<List<Bar>> saveCityBar(Bar bar);

  /// Remove um bar do banco da cidade
  Future<List<Bar>> deleteCityBar(String barId);

  /// Exporta o banco da cidade em JSON formatado para `assets/data/city_bars_seed.json`
  Future<String> exportCityBarsJson();

  /// Importa bares em lote a partir de um JSON
  Future<List<Bar>> importCityBarsJson(String rawJson);

  /// Calcula a rota a pé pelas ruas passando pelos [waypoints]
  Future<OsrmRouteModel> calculateFootRoute(List<LatLng> waypoints);

  /// Converte coordenadas em um endereço legível
  Future<String> resolveAddress(LatLng point);

  /// Busca endereços, bairros, cidades ou estabelecimentos com autocomplete
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    LatLng? proximity,
  });
}
