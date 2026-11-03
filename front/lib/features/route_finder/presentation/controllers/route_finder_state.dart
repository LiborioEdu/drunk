import 'package:latlong2/latlong.dart';
import '../../domain/entities/bar.dart';
import '../../domain/entities/drunk_route.dart';

enum GpsStatus {
  locating,
  active,
  ipApproximate,
  permissionDenied,
  error,
}

/// Estado imutável da Tela 1 (Mapa centralizado + Banco Próprio de Bares da Cidade + Gerador Automático e Manual de Rotas)
class RouteFinderState {
  final bool isLoadingLocation;
  final bool isGenerating;
  final int? swappingBarIndex;
  final int? selectedBarIndex;
  final LatLng? origin;
  final LatLng? userLocation;
  final double? gpsAccuracyMeters;
  final double? userHeading;
  final bool isFollowingUser;
  final LatLng? cameraTarget;
  final double cameraZoom;
  final int cameraMoveId;
  final String locationAddress;
  final GpsStatus gpsStatus;
  final double targetDistanceKm;
  final int targetBarsCount;
  final double searchRadiusKm;
  final List<Bar> cityBars;
  final bool isRegisteringBarMode;
  final bool isManualRouteMode;
  final bool isRouteRegistered;
  final String? highlightedCityBarId;
  final DrunkRoute? route;
  final String? errorMessage;

  const RouteFinderState({
    this.isLoadingLocation = false,
    this.isGenerating = false,
    this.swappingBarIndex,
    this.selectedBarIndex,
    this.origin,
    this.userLocation,
    this.gpsAccuracyMeters,
    this.userHeading,
    this.isFollowingUser = true,
    this.cameraTarget,
    this.cameraZoom = 15.2,
    this.cameraMoveId = 0,
    this.locationAddress = 'Localizando você...',
    this.gpsStatus = GpsStatus.locating,
    this.targetDistanceKm = 10.0,
    this.targetBarsCount = 10,
    this.searchRadiusKm = 3.5,
    this.cityBars = const [],
    this.isRegisteringBarMode = false,
    this.isManualRouteMode = false,
    this.isRouteRegistered = false,
    this.highlightedCityBarId,
    this.route,
    this.errorMessage,
  });

  bool get hasRoute => route != null && route!.bars.isNotEmpty;

  /// Distância média planejada por bar (em km)
  double get averageKmPerBar =>
      targetBarsCount > 0 ? targetDistanceKm / targetBarsCount : targetDistanceKm;

  RouteFinderState copyWith({
    bool? isLoadingLocation,
    bool? isGenerating,
    int? swappingBarIndex,
    bool clearSwappingIndex = false,
    int? selectedBarIndex,
    bool clearSelectedBar = false,
    LatLng? origin,
    LatLng? userLocation,
    double? gpsAccuracyMeters,
    double? userHeading,
    bool? isFollowingUser,
    LatLng? cameraTarget,
    double? cameraZoom,
    int? cameraMoveId,
    String? locationAddress,
    GpsStatus? gpsStatus,
    double? targetDistanceKm,
    int? targetBarsCount,
    double? searchRadiusKm,
    List<Bar>? cityBars,
    bool? isRegisteringBarMode,
    bool? isManualRouteMode,
    bool? isRouteRegistered,
    String? highlightedCityBarId,
    bool clearHighlightedCityBar = false,
    DrunkRoute? route,
    bool clearRoute = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RouteFinderState(
      isLoadingLocation: isLoadingLocation ?? this.isLoadingLocation,
      isGenerating: isGenerating ?? this.isGenerating,
      swappingBarIndex: clearSwappingIndex
          ? null
          : (swappingBarIndex ?? this.swappingBarIndex),
      selectedBarIndex: clearSelectedBar
          ? null
          : (selectedBarIndex ?? this.selectedBarIndex),
      origin: origin ?? this.origin,
      userLocation: userLocation ?? this.userLocation,
      gpsAccuracyMeters: gpsAccuracyMeters ?? this.gpsAccuracyMeters,
      userHeading: userHeading ?? this.userHeading,
      isFollowingUser: isFollowingUser ?? this.isFollowingUser,
      cameraTarget: cameraTarget ?? this.cameraTarget,
      cameraZoom: cameraZoom ?? this.cameraZoom,
      cameraMoveId: cameraMoveId ?? this.cameraMoveId,
      locationAddress: locationAddress ?? this.locationAddress,
      gpsStatus: gpsStatus ?? this.gpsStatus,
      targetDistanceKm: targetDistanceKm ?? this.targetDistanceKm,
      targetBarsCount: targetBarsCount ?? this.targetBarsCount,
      searchRadiusKm: searchRadiusKm ?? this.searchRadiusKm,
      cityBars: cityBars ?? this.cityBars,
      isRegisteringBarMode: isRegisteringBarMode ?? this.isRegisteringBarMode,
      isManualRouteMode: isManualRouteMode ?? this.isManualRouteMode,
      isRouteRegistered:
          clearRoute ? false : (isRouteRegistered ?? this.isRouteRegistered),
      highlightedCityBarId: clearHighlightedCityBar
          ? null
          : (highlightedCityBarId ?? this.highlightedCityBarId),
      route: clearRoute ? null : (route ?? this.route),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
