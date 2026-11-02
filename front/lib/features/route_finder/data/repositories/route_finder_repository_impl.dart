import 'package:latlong2/latlong.dart';
import '../../domain/entities/bar.dart';
import '../../domain/entities/place_suggestion.dart';
import '../../domain/repositories/route_finder_repository.dart';
import '../datasources/city_bars_datasource.dart';
import '../datasources/nominatim_datasource.dart';
import '../datasources/osrm_datasource.dart';
import '../datasources/place_search_datasource.dart';
import '../models/osrm_route_model.dart';

/// Implementação concreta usando 100% o Banco de Dados Próprio da Cidade para os bares,
/// mantendo OSRM para traçado nas ruas e Photon/Nominatim para endereços.
class RouteFinderRepositoryImpl implements RouteFinderRepository {
  final CityBarsDatasource _cityBarsDatasource;
  final OsrmDatasource _osrmDatasource;
  final NominatimDatasource _nominatimDatasource;
  final PlaceSearchDatasource _placeSearchDatasource;

  RouteFinderRepositoryImpl({
    CityBarsDatasource? cityBarsDatasource,
    OsrmDatasource? osrmDatasource,
    NominatimDatasource? nominatimDatasource,
    PlaceSearchDatasource? placeSearchDatasource,
  })  : _cityBarsDatasource = cityBarsDatasource ?? CityBarsDatasource(),
        _osrmDatasource = osrmDatasource ?? OsrmDatasource(),
        _nominatimDatasource = nominatimDatasource ?? NominatimDatasource(),
        _placeSearchDatasource =
            placeSearchDatasource ?? PlaceSearchDatasource();

  @override
  Future<List<Bar>> getAllCityBars() {
    return _cityBarsDatasource.getAllCityBars();
  }

  @override
  Future<List<Bar>> getNearbyBars({
    required LatLng center,
    required double radiusMeters,
  }) {
    return _cityBarsDatasource.getBarsAround(
      center: center,
      radiusMeters: radiusMeters,
    );
  }

  @override
  Future<List<Bar>> saveCityBar(Bar bar) {
    return _cityBarsDatasource.saveBar(bar);
  }

  @override
  Future<List<Bar>> deleteCityBar(String barId) {
    return _cityBarsDatasource.deleteBar(barId);
  }

  @override
  Future<String> exportCityBarsJson() {
    return _cityBarsDatasource.exportCatalogJson();
  }

  @override
  Future<List<Bar>> importCityBarsJson(String rawJson) {
    return _cityBarsDatasource.importCatalogJson(rawJson);
  }

  @override
  Future<OsrmRouteModel> calculateFootRoute(List<LatLng> waypoints) {
    return _osrmDatasource.calculateFootRoute(waypoints);
  }

  @override
  Future<String> resolveAddress(LatLng point) {
    return _nominatimDatasource.reverseGeocode(point);
  }

  @override
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    LatLng? proximity,
  }) {
    return _placeSearchDatasource.searchPlaces(
      query,
      proximity: proximity,
    );
  }
}
