import 'dart:async';
import 'dart:convert';
import 'package:drunk_front/core/location/ip_location_datasource.dart';
import 'package:drunk_front/core/location/user_location_service.dart';
import 'package:drunk_front/core/network/api_client.dart';
import 'package:drunk_front/features/route_finder/data/datasources/city_bars_datasource.dart';
import 'package:drunk_front/features/route_finder/data/datasources/place_search_datasource.dart';
import 'package:drunk_front/features/route_finder/data/models/osrm_route_model.dart';
import 'package:drunk_front/features/route_finder/domain/entities/bar.dart';
import 'package:drunk_front/features/route_finder/domain/entities/place_suggestion.dart';
import 'package:drunk_front/features/route_finder/domain/repositories/route_finder_repository.dart';
import 'package:drunk_front/features/route_finder/presentation/controllers/route_finder_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeUserLocationService extends UserLocationService {
  UserLocationResult currentResult;
  final StreamController<UserLocationResult> streamController =
      StreamController<UserLocationResult>.broadcast();

  _FakeUserLocationService(this.currentResult);

  @override
  Future<UserLocationResult> obtainCurrentLocation() async => currentResult;

  @override
  Stream<UserLocationResult> watchLivePosition() => streamController.stream;
}

class _FakeRouteFinderRepository implements RouteFinderRepository {
  final List<Bar> _bars = [];

  @override
  Future<List<Bar>> getAllCityBars() async => List.unmodifiable(_bars);

  @override
  Future<List<Bar>> getNearbyBars({
    required LatLng center,
    required double radiusMeters,
  }) async {
    return List.unmodifiable(_bars);
  }

  @override
  Future<List<Bar>> saveCityBar(Bar bar) async {
    _bars.removeWhere((b) => b.id == bar.id);
    _bars.add(bar);
    return List.unmodifiable(_bars);
  }

  @override
  Future<List<Bar>> deleteCityBar(String barId) async {
    _bars.removeWhere((b) => b.id == barId);
    return List.unmodifiable(_bars);
  }

  @override
  Future<String> exportCityBarsJson() async {
    return jsonEncode(_bars.map((b) => b.toCatalogJson()).toList());
  }

  @override
  Future<List<Bar>> importCityBarsJson(String rawJson) async {
    final list = jsonDecode(rawJson) as List<dynamic>;
    for (final item in list) {
      _bars.add(Bar.fromJson(item as Map<String, dynamic>));
    }
    return List.unmodifiable(_bars);
  }

  @override
  Future<String> resolveAddress(LatLng point) async {
    return 'Rua São Leonardo • Uruguai';
  }

  @override
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    LatLng? proximity,
  }) async {
    return [
      PlaceSuggestion(
        id: '1',
        title: 'Resenha Bar',
        subtitle: 'Uruguai',
        coordinates: const LatLng(-5.0890, -42.7530),
        category: 'bar',
        distanceMeters: 420,
      ),
    ];
  }

  @override
  Future<OsrmRouteModel> calculateFootRoute(List<LatLng> waypoints) {
    throw UnimplementedError();
  }
}

void main() {
  group('Stack Open de Geolocalização, Busca Photon e Banco Próprio da Cidade',
      () {
    test('IpLocationDatasource faz fallback para GeoJS parseando lat/lon em String',
        () async {
      final mockHttp = MockClient((request) async {
        if (request.url.host.contains('api-bdc.net')) {
          return http.Response('Erro', 503);
        }
        if (request.url.host.contains('geojs.io')) {
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'latitude': '-5.0892',
              'longitude': '-42.8016',
              'city': 'Teresina',
              'region': 'Piauí',
            })),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final datasource =
          IpLocationDatasource(apiClient: ApiClient(client: mockHttp));
      final result = await datasource.fetchIpLocation();

      expect(result, isNotNull);
      expect(result!.coordinates.latitude, closeTo(-5.0892, 0.0001));
      expect(result.coordinates.longitude, closeTo(-42.8016, 0.0001));
      expect(result.label, 'Teresina • Piauí');
    });

    test('PlaceSearchDatasource interpreta GeoJSON da Photon API com distância',
        () async {
      final mockHttp = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'type': 'FeatureCollection',
            'features': [
              {
                'type': 'Feature',
                'geometry': {
                  'type': 'Point',
                  'coordinates': [-42.7535, -5.0895],
                },
                'properties': {
                  'osm_id': 98765,
                  'name': 'Espetinho do Grau',
                  'street': 'Rua São Leonardo',
                  'district': 'Uruguai',
                  'city': 'Teresina',
                  'state': 'Piauí',
                  'osm_value': 'bar',
                },
              },
            ],
          })),
          200,
        );
      });

      final searchDs =
          PlaceSearchDatasource(apiClient: ApiClient(client: mockHttp));
      final suggestions = await searchDs.searchPlaces(
        'Espetinho',
        proximity: const LatLng(-5.0890, -42.7530),
      );

      expect(suggestions, hasLength(1));
      expect(suggestions.first.title, 'Espetinho do Grau');
      expect(suggestions.first.category, 'bar');
      expect(suggestions.first.distanceMeters, isNotNull);
      expect(suggestions.first.formattedDistance, endsWith('m'));
    });

    test('CityBarsDatasource carrega os 20 bares oficiais da cidade e permite CRUD local',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});

      // Verifica que o catálogo padrão já traz os 20 bares oficiais da região
      final seededDs = CityBarsDatasource(includeSeedBars: true);
      final seededBars = await seededDs.getAllCityBars();
      expect(seededBars.length, greaterThanOrEqualTo(20));
      expect(
        seededBars.any((b) => b.name == 'The Champions Restobar'),
        isTrue,
      );

      // Testa CRUD isolado sem o seed inicial
      final ds = CityBarsDatasource(includeSeedBars: false);

      final afterFirst = await ds.saveBar(
        const Bar(
          id: 'b_1',
          name: 'Bar da Esquina',
          latitude: -5.0891,
          longitude: -42.7532,
          address: 'Rua São Leonardo, 120 • Uruguai',
          amenity: 'bar',
          description: 'Chopp gelado',
        ),
      );
      expect(afterFirst, hasLength(1));
      expect(afterFirst.first.name, 'Bar da Esquina');

      final exported = await ds.exportCatalogJson();
      expect(exported, contains('Bar da Esquina'));
      expect(exported, contains('Chopp gelado'));

      final afterImport = await ds.importCatalogJson(
        jsonEncode([
          {
            'id': 'b_2',
            'name': 'Resenha Pub',
            'latitude': -5.0850,
            'longitude': -42.7500,
            'amenity': 'pub',
          },
        ]),
      );
      expect(afterImport, hasLength(2));

      final afterDelete = await ds.deleteBar('b_1');
      expect(afterDelete, hasLength(1));
      expect(afterDelete.first.id, 'b_2');
    });

    test(
        'RouteFinderNotifier cadastra bares na cidade, centraliza no GPS real e gera rota 100% pelo banco próprio',
        () async {
      const realUserCoords = LatLng(-5.0890, -42.7530);
      final fakeLocService = _FakeUserLocationService(
        const UserLocationResult(
          coordinates: realUserCoords,
          accuracyMeters: 8.0,
          source: LocationSource.gpsHardware,
        ),
      );
      final fakeRepo = _FakeRouteFinderRepository();

      final notifier = RouteFinderNotifier(
        repository: fakeRepo,
        userLocationService: fakeLocService,
      );
      addTearDown(notifier.dispose);
      addTearDown(fakeLocService.streamController.close);

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(notifier.state.gpsStatus, GpsStatus.active);
      expect(notifier.state.origin, realUserCoords);
      expect(notifier.state.cityBars, isEmpty);

      // Tenta gerar rota com banco vazio -> exibe orientação amigável de cadastro
      await notifier.generateDrunkRoute();
      expect(notifier.state.route, isNull);
      expect(notifier.state.errorMessage, contains('+ Cadastrar Bar'));

      // Cadastra 3 bares oficiais na cidade pelo controlador
      await notifier.saveCityBar(
        name: 'Boteco São Leonardo',
        coordinates: const LatLng(-5.0820, -42.7510),
        amenity: 'bar',
      );
      await notifier.saveCityBar(
        name: 'Choperia Uruguai',
        coordinates: const LatLng(-5.0750, -42.7490),
        amenity: 'pub',
      );
      await notifier.saveCityBar(
        name: 'Espetinho Noturno',
        coordinates: const LatLng(-5.0680, -42.7470),
        amenity: 'espetinho',
      );

      expect(notifier.state.cityBars, hasLength(3));

      // Gera rota usando exclusivamente os bares cadastrados no banco da cidade
      await notifier.generateDrunkRoute();
      expect(notifier.state.errorMessage, isNull);
      expect(notifier.state.route, isNotNull);
      expect(notifier.state.route!.bars, hasLength(3));
      expect(notifier.state.route!.bars.first.name, 'Boteco São Leonardo');

      // Testa montagem manual de rota clicando nas paradas no mapa
      notifier.resetRoute();
      notifier.toggleManualRouteMode(enabled: true, clearExistingRoute: true);
      expect(notifier.state.isManualRouteMode, isTrue);
      expect(notifier.state.route, isNull);

      // 1º clique próximo (<= 40m) ao "Boteco São Leonardo" -> faz snap para o bar cadastrado
      await notifier.addManualStopAtPoint(const LatLng(-5.0820, -42.7510));
      expect(notifier.state.route, isNotNull);
      expect(notifier.state.route!.bars, hasLength(1));
      expect(notifier.state.route!.bars.first.name, 'Boteco São Leonardo');

      // 2º clique em uma rua qualquer livre no mapa -> cria parada manual customizada
      await notifier.addManualStopAtPoint(const LatLng(-5.0780, -42.7600));
      expect(notifier.state.route!.bars, hasLength(2));
      expect(notifier.state.route!.bars[1].order, 2);

      // Desfaz a última parada manual
      await notifier.undoLastManualStop();
      expect(notifier.state.route!.bars, hasLength(1));

      // Registra e salva a rota no armazenamento local
      expect(notifier.state.isRouteRegistered, isFalse);
      final savedOk = await notifier.registerCurrentRoute();
      expect(savedOk, isTrue);
      expect(notifier.state.isRouteRegistered, isTrue);
    });
  });
}
