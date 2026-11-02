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

/// Estado imutável da Tela 1 (Mapa centralizado + Banco Próprio de Bares da Cidade + Gerador de Rotas)
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
  final double searchRadiusKm;
  final List<Bar> cityBars;
  final bool isRegisteringBarMode;
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
    this.searchRadiusKm = 3.5,
    this.cityBars = const [],
    this.isRegisteringBarMode = false,
    this.highlightedCityBarId,
    this.route,
    this.errorMessage,
  });

  bool get hasRoute => route != null && route!.bars.isNotEmpty;

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
    double? searchRadiusKm,
    List<Bar>? cityBars,
    bool? isRegisteringBarMode,
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
      searchRadiusKm: searchRadiusKm ?? this.searchRadiusKm,
      cityBars: cityBars ?? this.cityBars,
      isRegisteringBarMode: isRegisteringBarMode ?? this.isRegisteringBarMode,
      highlightedCityBarId: clearHighlightedCityBar
          ? null
          : (highlightedCityBarId ?? this.highlightedCityBarId),
      route: clearRoute ? null : (route ?? this.route),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
