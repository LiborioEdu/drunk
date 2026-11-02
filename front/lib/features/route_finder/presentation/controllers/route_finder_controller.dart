import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/location/user_location_service.dart';
import '../../../../core/utils/haversine_calculator.dart';
import '../../data/datasources/city_bars_datasource.dart';
import '../../data/datasources/nominatim_datasource.dart';
import '../../data/datasources/osrm_datasource.dart';
import '../../data/datasources/place_search_datasource.dart';
import '../../data/repositories/route_finder_repository_impl.dart';
import '../../domain/entities/bar.dart';
import '../../domain/entities/place_suggestion.dart';
import '../../domain/repositories/route_finder_repository.dart';
import '../../domain/services/bar_swap_service.dart';
import '../../domain/services/route_generator_service.dart';
import 'route_finder_state.dart';

export 'route_finder_state.dart';

class RouteFinderNotifier extends StateNotifier<RouteFinderState> {
  static int _barIdSequence = 0;

  final RouteFinderRepository _repository;
  final RouteGeneratorService _routeGeneratorService;
  final BarSwapService _barSwapService;
  final UserLocationService _userLocationService;
  StreamSubscription<UserLocationResult>? _liveLocationSubscription;

  RouteFinderNotifier({
    RouteFinderRepository? repository,
    RouteGeneratorService? routeGeneratorService,
    BarSwapService? barSwapService,
    UserLocationService? userLocationService,
  })  : _repository = repository ?? RouteFinderRepositoryImpl(),
        _routeGeneratorService =
            routeGeneratorService ?? RouteGeneratorService(),
        _barSwapService = barSwapService ?? BarSwapService(),
        _userLocationService = userLocationService ?? UserLocationService(),
        super(const RouteFinderState()) {
    _loadCityBars();
    initLocation();
  }

  /// Ponto padrão apenas em caso extremo 100% offline sem GPS nem rede IP
  static const LatLng defaultOrigin = UserLocationService.defaultCoordinates;

  /// Carrega os bares oficiais cadastrados na cidade para exibi-los no mapa
  Future<void> _loadCityBars() async {
    final bars = await _repository.getAllCityBars();
    if (!mounted) return;
    state = state.copyWith(cityBars: bars);
  }

  /// Ativa ou desativa o Modo Cadastrar Bar clicando direto no mapa
  void toggleRegisterBarMode([bool? enabled]) {
    final next = enabled ?? !state.isRegisteringBarMode;
    state = state.copyWith(
      isRegisteringBarMode: next,
      clearError: true,
    );
  }

  /// Destaca um bar cadastrado no mapa ao tocar no pino dele
  void selectCityBarOnMap(String? barId) {
    if (barId == null || state.highlightedCityBarId == barId) {
      state = state.copyWith(clearHighlightedCityBar: true);
    } else {
      state = state.copyWith(highlightedCityBarId: barId);
    }
  }

  /// Centraliza a câmera exatamente sobre um bar cadastrado da cidade
  void focusCityBar(Bar bar) {
    state = state.copyWith(
      highlightedCityBarId: bar.id,
      cameraTarget: bar.coordinates,
      cameraZoom: 17.0,
      cameraMoveId: state.cameraMoveId + 1,
    );
  }

  /// Resolve o endereço de uma coordenada (usado ao tocar no mapa para cadastrar um bar)
  Future<String> resolveAddressForPoint(LatLng point) {
    return _repository.resolveAddress(point);
  }

  /// Cadastra ou edita um bar oficial no banco de dados próprio da cidade
  Future<Bar> saveCityBar({
    String? existingId,
    required String name,
    required LatLng coordinates,
    String? address,
    String amenity = 'bar',
    String? description,
  }) async {
    String? finalAddress = address?.trim();
    if (finalAddress == null || finalAddress.isEmpty) {
      finalAddress = await _repository.resolveAddress(coordinates);
    }

    final bar = Bar(
      id: existingId ??
          'city_bar_${DateTime.now().microsecondsSinceEpoch}_${++_barIdSequence}',
      name: name.trim(),
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
      address: finalAddress,
      amenity: amenity,
      description:
          (description != null && description.trim().isNotEmpty)
              ? description.trim()
              : null,
    );

    final updatedList = await _repository.saveCityBar(bar);
    if (mounted) {
      state = state.copyWith(
        cityBars: updatedList,
        highlightedCityBarId: bar.id,
        clearError: true,
      );
    }
    return bar;
  }

  /// Remove um bar do banco de dados da cidade
  Future<void> deleteCityBar(String barId) async {
    final updatedList = await _repository.deleteCityBar(barId);
    if (!mounted) return;
    final wasInRoute =
        state.route?.bars.any((b) => b.id == barId) ?? false;
    state = state.copyWith(
      cityBars: updatedList,
      clearHighlightedCityBar: state.highlightedCityBarId == barId,
      clearRoute: wasInRoute,
    );
  }

  /// Exporta o banco da cidade em JSON formatado para `assets/data/city_bars_seed.json`
  Future<String> exportCityBarsJson() {
    return _repository.exportCityBarsJson();
  }

  /// Importa uma lista JSON de bares para o banco da cidade
  Future<int> importCityBarsJson(String rawJson) async {
    final updated = await _repository.importCityBarsJson(rawJson);
    if (mounted) {
      state = state.copyWith(cityBars: updated, clearError: true);
    }
    return updated.length;
  }

  /// Inicializa ou atualiza a localização real do usuário (GPS -> Rede IP -> Fallback)
  Future<void> initLocation({bool snapOriginToUser = true}) async {
    state = state.copyWith(
      isLoadingLocation: true,
      gpsStatus:
          state.userLocation == null ? GpsStatus.locating : state.gpsStatus,
      clearError: true,
    );

    final result = await _userLocationService.obtainCurrentLocation();
    if (!mounted) return;

    final status = switch (result.source) {
      LocationSource.gpsHardware => GpsStatus.active,
      LocationSource.ipNetwork => GpsStatus.ipApproximate,
      LocationSource.fallbackDefault =>
        result.permissionDenied ? GpsStatus.permissionDenied : GpsStatus.error,
    };

    final targetZoom =
        result.source == LocationSource.gpsHardware ? 15.6 : 14.3;
    final shouldMoveOrigin = snapOriginToUser || state.origin == null;
    final provisionalLabel = result.suggestedLabel ?? 'Identificando rua...';

    state = state.copyWith(
      isLoadingLocation: false,
      gpsStatus: status,
      userLocation: result.coordinates,
      gpsAccuracyMeters: result.accuracyMeters,
      userHeading: result.headingDegrees,
      origin: shouldMoveOrigin ? result.coordinates : state.origin,
      isFollowingUser: shouldMoveOrigin ? true : state.isFollowingUser,
      cameraTarget: shouldMoveOrigin ? result.coordinates : state.cameraTarget,
      cameraZoom: shouldMoveOrigin ? targetZoom : state.cameraZoom,
      cameraMoveId:
          shouldMoveOrigin ? state.cameraMoveId + 1 : state.cameraMoveId,
      locationAddress:
          shouldMoveOrigin ? provisionalLabel : state.locationAddress,
    );

    if (shouldMoveOrigin && result.source != LocationSource.fallbackDefault) {
      final resolvedAddress =
          await _repository.resolveAddress(result.coordinates);
      if (mounted && state.origin == result.coordinates) {
        final looksLikeRawCoords = resolvedAddress.contains(',') &&
            double.tryParse(resolvedAddress.split(',').first.trim()) != null;
        state = state.copyWith(
          locationAddress: (looksLikeRawCoords && result.suggestedLabel != null)
              ? result.suggestedLabel!
              : resolvedAddress,
        );
      }
    }

    if (result.source == LocationSource.gpsHardware) {
      _startLiveLocationStream();
    }
  }

  void _startLiveLocationStream() {
    _liveLocationSubscription?.cancel();
    _liveLocationSubscription =
        _userLocationService.watchLivePosition().listen((live) {
      if (!mounted) return;

      final shouldFollow = state.isFollowingUser && state.route == null;
      final previousOrigin = state.origin;
      final movedSignificantly = previousOrigin == null ||
          HaversineCalculator.distanceMeters(previousOrigin, live.coordinates) >
              25.0;

      state = state.copyWith(
        gpsStatus: GpsStatus.active,
        userLocation: live.coordinates,
        gpsAccuracyMeters: live.accuracyMeters,
        userHeading: live.headingDegrees,
        origin: shouldFollow ? live.coordinates : state.origin,
      );

      if (shouldFollow && movedSignificantly) {
        _refreshFollowingAddress(live.coordinates);
      }
    });
  }

  Future<void> _refreshFollowingAddress(LatLng coords) async {
    final address = await _repository.resolveAddress(coords);
    if (mounted && state.isFollowingUser && state.route == null) {
      state = state.copyWith(locationAddress: address);
    }
  }

  /// Botão "Minha Localização" estilo Google Maps: centraliza imediatamente na posição real do usuário
  Future<void> centerOnMyLocation() async {
    final knownUserPos = state.userLocation;
    final canMoveOrigin = state.route == null;

    if (knownUserPos != null) {
      state = state.copyWith(
        origin: canMoveOrigin ? knownUserPos : state.origin,
        isFollowingUser: canMoveOrigin ? true : state.isFollowingUser,
        cameraTarget: knownUserPos,
        cameraZoom: 15.8,
        cameraMoveId: state.cameraMoveId + 1,
        clearSelectedBar: true,
        clearError: true,
      );
      if (canMoveOrigin) {
        final resolved = await _repository.resolveAddress(knownUserPos);
        if (mounted && state.origin == knownUserPos) {
          state = state.copyWith(locationAddress: resolved);
        }
      }
    }

    await initLocation(snapOriginToUser: canMoveOrigin);
  }

  /// Altera o ponto de partida tocando no mapa ou buscando um endereço
  Future<void> setCustomOrigin(
    LatLng newOrigin, {
    String? customLabel,
    bool centerCamera = true,
  }) async {
    final isSameAsUser = state.userLocation != null &&
        HaversineCalculator.distanceMeters(state.userLocation!, newOrigin) <
            20.0;

    state = state.copyWith(
      origin: newOrigin,
      isFollowingUser: isSameAsUser,
      cameraTarget: centerCamera ? newOrigin : state.cameraTarget,
      cameraZoom: centerCamera ? 15.4 : state.cameraZoom,
      cameraMoveId: centerCamera ? state.cameraMoveId + 1 : state.cameraMoveId,
      locationAddress: customLabel ?? 'Identificando endereço...',
      clearRoute: true,
      clearSelectedBar: true,
      clearError: true,
    );

    if (customLabel == null) {
      final address = await _repository.resolveAddress(newOrigin);
      if (mounted && state.origin == newOrigin) {
        state = state.copyWith(locationAddress: address);
      }
    }
  }

  /// Autocomplete estilo Google Maps enviesado para a localização real do usuário
  Future<List<PlaceSuggestion>> searchPlaces(String query) {
    return _repository.searchPlaces(
      query,
      proximity: state.userLocation ?? state.origin,
    );
  }

  /// Limpa a rota atual para configurar uma nova busca mantendo o ponto de partida
  void resetRoute() {
    state = state.copyWith(
      clearRoute: true,
      clearSelectedBar: true,
      clearError: true,
    );
  }

  /// Seleciona/destaca um bar na lista e no mapa
  void selectBar(int? index) {
    if (state.selectedBarIndex == index) {
      state = state.copyWith(clearSelectedBar: true);
    } else {
      state = state.copyWith(selectedBarIndex: index);
    }
  }

  /// Ajusta o raio de busca
  void setSearchRadius(double radiusKm) {
    state = state.copyWith(searchRadiusKm: radiusKm);
  }

  /// Executa o fluxo completo usando 100% o Banco de Dados Próprio da Cidade:
  /// 1. Busca os bares oficiais cadastrados na cidade
  /// 2. Seleciona até 10 bares na sequência ideal (~10km)
  /// 3. Traça as ruas reais a pé via OSRM
  Future<void> generateDrunkRoute() async {
    final origin = state.origin ?? state.userLocation ?? defaultOrigin;

    state = state.copyWith(
      isGenerating: true,
      isRegisteringBarMode: false,
      clearError: true,
      clearSelectedBar: true,
    );

    try {
      if (state.cityBars.isEmpty) {
        state = state.copyWith(
          isGenerating: false,
          errorMessage:
              'Nenhum bar cadastrado no Banco da Cidade ainda! Toque em "+ Cadastrar Bar" no topo e clique nos bares da sua cidade no mapa para registrá-los.',
        );
        return;
      }

      final radiusMeters = state.searchRadiusKm * 1000.0;
      final candidates = await _repository.getNearbyBars(
        center: origin,
        radiusMeters: radiusMeters,
      );

      if (candidates.isEmpty) {
        state = state.copyWith(
          isGenerating: false,
          errorMessage:
              'Você possui ${state.cityBars.length} bar(es) cadastrado(s), mas estão a mais de 15 km deste ponto de partida. Abra "Banco de Bares" para focar na sua região.',
        );
        return;
      }

      final drunkRoute = await _routeGeneratorService.generateRoute(
        origin: origin,
        candidatePool: candidates,
        targetBars: 10,
      );

      state = state.copyWith(
        isGenerating: false,
        route: drunkRoute,
      );
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        errorMessage:
            'Erro ao gerar rota: ${e.toString().replaceAll("Exception: ", "")}',
      );
    }
  }

  /// Executa o mecanismo de Swap no bar selecionado usando o restante do Banco da Cidade
  Future<void> swapBar(int index) async {
    final currentRoute = state.route;
    if (currentRoute == null ||
        index < 0 ||
        index >= currentRoute.bars.length) {
      return;
    }

    state = state.copyWith(swappingBarIndex: index, clearError: true);

    try {
      final updatedRoute = await _barSwapService.swapBar(
        currentRoute: currentRoute,
        barIndex: index,
      );

      state = state.copyWith(
        clearSwappingIndex: true,
        selectedBarIndex: index,
        route: updatedRoute,
      );
    } catch (e) {
      state = state.copyWith(
        clearSwappingIndex: true,
        errorMessage:
            'Não há outro bar livre cadastrado no banco para substituir esta parada. Cadastre mais bares na região!',
      );
    }
  }

  @override
  void dispose() {
    _liveLocationSubscription?.cancel();
    super.dispose();
  }
}

/// Providers Riverpod para localização, banco próprio de bares e geração de rotas
final userLocationServiceProvider = Provider<UserLocationService>((ref) {
  return UserLocationService();
});

final routeFinderRepositoryProvider = Provider<RouteFinderRepository>((ref) {
  return RouteFinderRepositoryImpl(
    cityBarsDatasource: CityBarsDatasource(),
    osrmDatasource: OsrmDatasource(),
    nominatimDatasource: NominatimDatasource(),
    placeSearchDatasource: PlaceSearchDatasource(),
  );
});

final routeFinderProvider =
    StateNotifierProvider<RouteFinderNotifier, RouteFinderState>((ref) {
  final osrm = OsrmDatasource();
  final repository = ref.watch(routeFinderRepositoryProvider);
  final locationService = ref.watch(userLocationServiceProvider);
  return RouteFinderNotifier(
    repository: repository,
    routeGeneratorService: RouteGeneratorService(osrmDatasource: osrm),
    barSwapService: BarSwapService(osrmDatasource: osrm),
    userLocationService: locationService,
  );
});
