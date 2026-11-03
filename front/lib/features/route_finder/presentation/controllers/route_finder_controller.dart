import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/location/user_location_service.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/utils/haversine_calculator.dart';
import '../../data/datasources/city_bars_datasource.dart';
import '../../data/datasources/nominatim_datasource.dart';
import '../../data/datasources/osrm_datasource.dart';
import '../../data/datasources/place_search_datasource.dart';
import '../../data/repositories/route_finder_repository_impl.dart';
import '../../domain/entities/bar.dart';
import '../../domain/entities/drunk_route.dart';
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
  final LocalStorageService _localStorageService;
  StreamSubscription<UserLocationResult>? _liveLocationSubscription;
  int _manualRouteRebuildVersion = 0;

  RouteFinderNotifier({
    RouteFinderRepository? repository,
    RouteGeneratorService? routeGeneratorService,
    BarSwapService? barSwapService,
    UserLocationService? userLocationService,
    LocalStorageService? localStorageService,
  })  : _repository = repository ?? RouteFinderRepositoryImpl(),
        _routeGeneratorService =
            routeGeneratorService ?? RouteGeneratorService(),
        _barSwapService = barSwapService ?? BarSwapService(),
        _userLocationService = userLocationService ?? UserLocationService(),
        _localStorageService = localStorageService ?? LocalStorageService(),
        super(const RouteFinderState()) {
    _loadCityBars();
    _restoreSavedRoute();
    initLocation();
  }

  /// Ponto padrão apenas em caso extremo 100% offline sem GPS nem rede IP
  static const LatLng defaultOrigin = UserLocationService.defaultCoordinates;

  /// Restaura a última rota registrada e salva localmente no dispositivo
  Future<void> _restoreSavedRoute() async {
    final savedRoute = await _localStorageService.loadRegisteredRoute();
    if (!mounted || savedRoute == null || savedRoute.bars.isEmpty) return;
    final savedLabel =
        await _localStorageService.loadRegisteredRouteOriginLabel();
    if (!mounted) return;

    state = state.copyWith(
      route: savedRoute.copyWith(
        candidatePool: state.cityBars.isNotEmpty
            ? state.cityBars
            : savedRoute.candidatePool,
      ),
      origin: savedRoute.origin,
      locationAddress: savedLabel ?? state.locationAddress,
      targetDistanceKm: savedRoute.targetDistanceKm.clamp(1.0, 20.0),
      targetBarsCount: savedRoute.totalBars,
      isRouteRegistered: true,
    );
  }

  /// Registra e salva a rota atual no armazenamento local para os corredores seguirem
  Future<bool> registerCurrentRoute() async {
    final currentRoute = state.route;
    if (currentRoute == null || currentRoute.bars.isEmpty) {
      return false;
    }

    await _localStorageService.saveRegisteredRoute(
      currentRoute,
      originLabel: state.locationAddress,
    );
    if (!mounted) return false;

    state = state.copyWith(
      isRouteRegistered: true,
      isManualRouteMode: false,
      isRegisteringBarMode: false,
      clearSelectedBar: true,
      clearError: true,
    );
    return true;
  }

  /// Carrega os bares oficiais cadastrados na cidade para exibi-los no mapa
  Future<void> _loadCityBars() async {
    final bars = await _repository.getAllCityBars();
    if (!mounted) return;
    final maxAvailable = bars.isNotEmpty ? bars.length : 10;
    final adjustedBarsCount =
        state.targetBarsCount.clamp(1, math.max<int>(2, maxAvailable));
    state = state.copyWith(
      cityBars: bars,
      targetBarsCount: adjustedBarsCount,
    );
  }

  /// Ativa ou desativa o Modo Cadastrar Bar clicando direto no mapa
  void toggleRegisterBarMode([bool? enabled]) {
    final next = enabled ?? !state.isRegisteringBarMode;
    state = state.copyWith(
      isRegisteringBarMode: next,
      isManualRouteMode: next ? false : state.isManualRouteMode,
      clearError: true,
    );
  }

  /// Ativa ou desativa o Modo de Montar Rota Manualmente clicando nas paradas no mapa
  void toggleManualRouteMode({
    bool? enabled,
    bool clearExistingRoute = false,
  }) {
    final next = enabled ?? !state.isManualRouteMode;
    state = state.copyWith(
      isManualRouteMode: next,
      isRegisteringBarMode: next ? false : state.isRegisteringBarMode,
      clearRoute: clearExistingRoute,
      clearSelectedBar: clearExistingRoute,
      clearError: true,
    );
  }

  /// Destaca um bar cadastrado no mapa ao tocar no pino dele (ou adiciona à rota se em Modo Manual)
  Future<void> selectCityBarOnMap(String? barId) async {
    if (barId == null) {
      state = state.copyWith(clearHighlightedCityBar: true);
      return;
    }

    if (state.isManualRouteMode) {
      Bar? matched;
      for (final b in state.cityBars) {
        if (b.id == barId) {
          matched = b;
          break;
        }
      }
      if (matched != null) {
        await toggleBarInManualRoute(matched);
        return;
      }
    }

    if (state.highlightedCityBarId == barId) {
      state = state.copyWith(clearHighlightedCityBar: true);
    } else {
      state = state.copyWith(highlightedCityBarId: barId);
    }
  }

  /// Adiciona ou remove um bar oficial do banco da cidade na rota manual
  Future<void> toggleBarInManualRoute(Bar bar) async {
    final currentBars = List<Bar>.from(state.route?.bars ?? const []);
    final existingIdx = currentBars.indexWhere((b) => b.id == bar.id);

    if (existingIdx >= 0) {
      currentBars.removeAt(existingIdx);
    } else {
      currentBars.add(bar);
    }

    state = state.copyWith(
      isManualRouteMode: true,
      isRegisteringBarMode: false,
      clearHighlightedCityBar: true,
      clearError: true,
    );

    await _rebuildRouteFromOrderedBars(currentBars);
  }

  /// Chamado quando o usuário está no Modo Manual e clica em qualquer ponto do mapa:
  /// - Se clicar próximo (<= 40m) de um bar oficial cadastrado, seleciona esse bar.
  /// - Se clicar em qualquer outra rua/esquina, cria uma parada manual naquele ponto e traça a rota!
  Future<void> addManualStopAtPoint(LatLng point) async {
    // 1. Verifica se clicou em cima/perto de algum bar já presente na rota (para selecioná-lo)
    final currentBars = List<Bar>.from(state.route?.bars ?? const []);

    // 2. Verifica se clicou próximo (<= 40m) de um bar cadastrado no Banco da Cidade
    Bar? nearestCityBar;
    double nearestDist = double.infinity;
    for (final cityBar in state.cityBars) {
      final d = HaversineCalculator.distanceMeters(cityBar.coordinates, point);
      if (d <= 40.0 && d < nearestDist) {
        nearestDist = d;
        nearestCityBar = cityBar;
      }
    }

    if (nearestCityBar != null) {
      await toggleBarInManualRoute(nearestCityBar);
      return;
    }

    // 3. Cria uma parada personalizada exatamente na coordenada clicada
    final stopOrder = currentBars.length + 1;
    final customStopId =
        'manual_stop_${DateTime.now().microsecondsSinceEpoch}_${++_barIdSequence}';
    final provisionalBar = Bar(
      id: customStopId,
      name: 'Parada #${stopOrder.toString().padLeft(2, '0')}',
      latitude: point.latitude,
      longitude: point.longitude,
      address: 'Calculando rua...',
      amenity: 'bar',
      order: stopOrder,
    );

    currentBars.add(provisionalBar);
    await _rebuildRouteFromOrderedBars(currentBars);

    // Resolve o nome da rua em background para enriquecer o card da parada manual
    final resolvedStreet = await _repository.resolveAddress(point);
    if (!mounted) return;
    final activeBars = state.route?.bars;
    if (activeBars == null) return;
    final idx = activeBars.indexWhere((b) => b.id == customStopId);
    if (idx < 0) return;

    final shortStreet = resolvedStreet.split('•').first.trim();
    final updatedBar = activeBars[idx].copyWith(
      name: shortStreet.isNotEmpty && !shortStreet.contains(',')
          ? 'Parada #${(idx + 1).toString().padLeft(2, '0')} • $shortStreet'
          : activeBars[idx].name,
      address: resolvedStreet,
    );
    final updatedList = List<Bar>.from(activeBars)..[idx] = updatedBar;
    state = state.copyWith(
      route: state.route!.copyWith(bars: updatedList),
    );
  }

  /// Remove uma parada específica pelo índice (0-based) e recalcula a rota
  Future<void> removeStopFromRoute(int index) async {
    final currentBars = List<Bar>.from(state.route?.bars ?? const []);
    if (index < 0 || index >= currentBars.length) return;
    currentBars.removeAt(index);
    state = state.copyWith(clearSelectedBar: true, clearError: true);
    await _rebuildRouteFromOrderedBars(currentBars);
  }

  /// Desfaz a última parada adicionada na rota manual
  Future<void> undoLastManualStop() async {
    final currentBars = List<Bar>.from(state.route?.bars ?? const []);
    if (currentBars.isEmpty) return;
    currentBars.removeLast();
    state = state.copyWith(clearSelectedBar: true, clearError: true);
    await _rebuildRouteFromOrderedBars(currentBars);
  }

  /// Reconstrói o objeto [DrunkRoute] instantaneamente e atualiza a geometria real nas ruas via OSRM
  Future<void> _rebuildRouteFromOrderedBars(List<Bar> orderedBars) async {
    final rebuildId = ++_manualRouteRebuildVersion;
    if (orderedBars.isEmpty) {
      state = state.copyWith(
        clearRoute: true,
        clearSelectedBar: true,
      );
      return;
    }

    final origin = state.origin ?? state.userLocation ?? defaultOrigin;

    // 1. Atualização instantânea (< 16ms) com linha estimada para feedback visual imediato ao clicar no mapa
    double instantTotalMeters = 0.0;
    final instantBars = <Bar>[];
    final instantPolyline = <LatLng>[origin];
    LatLng prev = origin;

    for (int i = 0; i < orderedBars.length; i++) {
      final legMeters =
          HaversineCalculator.distanceMeters(prev, orderedBars[i].coordinates) *
              RouteGeneratorService.urbanTortuosityFactor;
      instantTotalMeters += legMeters;
      instantBars.add(
        orderedBars[i].copyWith(
          order: i + 1,
          distanceFromPrevious: legMeters,
        ),
      );
      instantPolyline.add(orderedBars[i].coordinates);
      prev = orderedBars[i].coordinates;
    }

    final instantRoute = DrunkRoute(
      origin: origin,
      bars: instantBars,
      totalDistanceMeters: instantTotalMeters,
      totalDurationSeconds: instantTotalMeters / 1.39,
      targetDistanceMeters: instantTotalMeters,
      targetBarsCount: instantBars.length,
      polyline: instantPolyline,
      candidatePool: state.cityBars,
    );

    state = state.copyWith(
      route: instantRoute,
      targetBarsCount: instantBars.length,
      selectedBarIndex: instantBars.length - 1,
      isRouteRegistered: false,
    );

    // 2. Cálculo assíncrono do traçado real pelas calçadas/ruas via OSRM
    try {
      final waypoints = [origin, ...instantBars.map((b) => b.coordinates)];
      final osrm = await _repository.calculateFootRoute(waypoints);
      if (!mounted || rebuildId != _manualRouteRebuildVersion) return;

      final currentRouteBars = state.route?.bars ?? instantBars;
      final refinedBars = <Bar>[];
      for (int i = 0; i < currentRouteBars.length; i++) {
        final legDist = (i < osrm.legDistances.length)
            ? osrm.legDistances[i]
            : currentRouteBars[i].distanceFromPrevious;
        refinedBars.add(
          currentRouteBars[i].copyWith(
            order: i + 1,
            distanceFromPrevious: legDist,
          ),
        );
      }

      state = state.copyWith(
        route: DrunkRoute(
          origin: origin,
          bars: refinedBars,
          totalDistanceMeters: osrm.distanceMeters,
          totalDurationSeconds: osrm.durationSeconds,
          targetDistanceMeters: osrm.distanceMeters,
          targetBarsCount: refinedBars.length,
          polyline: osrm.polyline,
          candidatePool: state.cityBars,
        ),
      );
    } catch (_) {
      // Mantém a rota instantânea caso o servidor OSRM esteja offline
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
    final maxBars = updatedList.isNotEmpty ? updatedList.length : 2;
    state = state.copyWith(
      cityBars: updatedList,
      targetBarsCount: state.targetBarsCount.clamp(1, maxBars),
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
    final shouldMoveOrigin =
        (snapOriginToUser && !state.hasRoute) || state.origin == null;
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
  Future<void> resetRoute() async {
    ++_manualRouteRebuildVersion;
    state = state.copyWith(
      clearRoute: true,
      isRouteRegistered: false,
      clearSelectedBar: true,
      clearError: true,
    );
    await _localStorageService.clearRegisteredRoute();
  }

  /// Seleciona/destaca um bar na lista e no mapa
  void selectBar(int? index) {
    if (state.selectedBarIndex == index) {
      state = state.copyWith(clearSelectedBar: true);
    } else {
      state = state.copyWith(selectedBarIndex: index);
    }
  }

  /// Define a distância total desejada para o percurso (em KM)
  void setTargetDistanceKm(double km) {
    final clamped = (km * 2).round() / 2.0; // passos de 0.5 km
    final finalKm = clamped.clamp(1.0, 20.0);
    final syncedRadarRadius = (finalKm * 0.45).clamp(1.5, 6.0);
    state = state.copyWith(
      targetDistanceKm: finalKm,
      searchRadiusKm: syncedRadarRadius,
    );
  }

  /// Define quantos bares o usuário deseja percorrer na rota
  void setTargetBarsCount(int count) {
    final maxBars = state.cityBars.isNotEmpty
        ? math.min<int>(20, state.cityBars.length)
        : 20;
    final clamped = count.clamp(1, math.max<int>(1, maxBars));
    state = state.copyWith(targetBarsCount: clamped);
  }

  /// Ajusta o raio do radar diretamente (compatibilidade)
  void setSearchRadius(double radiusKm) {
    state = state.copyWith(searchRadiusKm: radiusKm);
  }

  /// Executa o fluxo completo usando 100% o Banco de Dados Próprio da Cidade:
  /// 1. Busca os bares oficiais cadastrados na cidade
  /// 2. Seleciona [targetBarsCount] bares na sequência ideal (~[targetDistanceKm] km)
  /// 3. Traça as ruas reais a pé via OSRM
  Future<void> generateDrunkRoute() async {
    final origin = state.origin ?? state.userLocation ?? defaultOrigin;

    state = state.copyWith(
      isGenerating: true,
      isRegisteringBarMode: false,
      isManualRouteMode: false,
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

      final radiusMeters =
          math.max(state.searchRadiusKm, state.targetDistanceKm * 0.6) * 1000.0;
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

      final requestedBars =
          state.targetBarsCount.clamp(1, candidates.length);

      final drunkRoute = await _routeGeneratorService.generateRoute(
        origin: origin,
        candidatePool: candidates,
        targetBars: requestedBars,
        targetDistanceKm: state.targetDistanceKm,
      );

      state = state.copyWith(
        isGenerating: false,
        isRouteRegistered: false,
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
        isRouteRegistered: false,
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
