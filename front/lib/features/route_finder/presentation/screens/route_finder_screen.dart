import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/drunk_bottom_nav_bar.dart';
import '../../../crew_lobby/presentation/screens/crew_lobby_view.dart';
import '../../../race_log/presentation/screens/race_log_view.dart';
import '../../../race_hud/presentation/controllers/race_session_controller.dart';
import '../../../race_hud/presentation/screens/race_hud_screen.dart';
import '../../domain/entities/bar.dart';
import '../controllers/route_finder_controller.dart';
import '../widgets/city_bars_manager_modal.dart';
import '../widgets/dark_map_view.dart';
import '../widgets/floating_gps_header.dart';
import '../widgets/location_search_modal.dart';
import '../widgets/register_city_bar_modal.dart';
import '../widgets/route_bottom_sheet.dart';
import '../widgets/runner_profile_sheet.dart';

/// Shell Principal DRUNK com Barra Inferior Stitch IA (`ROTA • RADAR • CREW • PERFIL`)
class RouteFinderScreen extends ConsumerStatefulWidget {
  const RouteFinderScreen({super.key});

  @override
  ConsumerState<RouteFinderScreen> createState() => _RouteFinderScreenState();
}

class _RouteFinderScreenState extends ConsumerState<RouteFinderScreen> {
  DrunkNavTab _currentTab = DrunkNavTab.rota;
  bool _isTopMenuOpen = false;

  Future<void> _openLocationSearch(
    RouteFinderState state,
    RouteFinderNotifier notifier,
  ) {
    return LocationSearchModal.show(
      context,
      currentAddress: state.locationAddress,
      onSearch: (query) => notifier.searchPlaces(query),
      onUseMyLocation: () => notifier.centerOnMyLocation(),
      onSelectPlace: (place) => notifier.setCustomOrigin(
        place.coordinates,
        customLabel: place.formattedLabel,
      ),
    );
  }

  Future<void> _openRegisterBarModal(
    RouteFinderNotifier notifier, {
    required LatLng point,
    Bar? existingBar,
  }) {
    return RegisterCityBarModal.show(
      context,
      initialCoordinates: point,
      existingBar: existingBar,
      onResolveAddress: (coords) => notifier.resolveAddressForPoint(coords),
      onSave: ({
        existingId,
        required name,
        required coordinates,
        address,
        required amenity,
        description,
      }) async {
        final saved = await notifier.saveCityBar(
          existingId: existingId,
          name: name,
          coordinates: coordinates,
          address: address,
          amenity: amenity,
          description: description,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              duration: const Duration(milliseconds: 1800),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xF215261D),
              content: Text(
                '🍺 "${saved.name}" salvo no Banco da Cidade!',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
      },
      onDelete: existingBar != null
          ? (barId) => notifier.deleteCityBar(barId)
          : null,
    );
  }

  Future<void> _openCityBarsManager(
    RouteFinderState state,
    RouteFinderNotifier notifier,
    LatLng origin,
  ) {
    return CityBarsManagerModal.show(
      context,
      cityBars: state.cityBars,
      referencePoint: state.userLocation ?? origin,
      onAddAtMapTapMode: () => notifier.toggleRegisterBarMode(true),
      onAddViaCoordinates: () => _openRegisterBarModal(
        notifier,
        point: origin,
      ),
      onFocusBar: (bar) => notifier.focusCityBar(bar),
      onEditBar: (bar) => _openRegisterBarModal(
        notifier,
        point: bar.coordinates,
        existingBar: bar,
      ),
      onDeleteBar: (barId) => notifier.deleteCityBar(barId),
      onExportJson: () => notifier.exportCityBarsJson(),
      onImportJson: (raw) => notifier.importCityBarsJson(raw),
    );
  }

  Future<void> _registerRoute() async {
    final notifier = ref.read(routeFinderProvider.notifier);
    final saved = await notifier.registerCurrentRoute();
    if (!saved || !mounted) return;

    final route = ref.read(routeFinderProvider).route;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 2200),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xF215261D),
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.cyberGreen,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Rota de ${route?.totalDistanceKmFormatted ?? ""} (${route?.totalBars ?? 0} paradas) registrada e salva!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(routeFinderProvider);
    final notifier = ref.read(routeFinderProvider.notifier);
    final activeSession = ref.watch(raceSessionProvider);
    final hasActiveRace = activeSession != null && !activeSession.isCompleted;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _buildCurrentTabBody(
        context,
        state: state,
        notifier: notifier,
        activeSession: activeSession,
      ),
      bottomNavigationBar: DrunkBottomNavBar(
        currentTab: _currentTab,
        hasActiveRace: hasActiveRace,
        onSelectTab: (tab) {
          setState(() => _currentTab = tab);
        },
      ),
    );
  }

  Widget _buildCurrentTabBody(
    BuildContext context, {
    required RouteFinderState state,
    required RouteFinderNotifier notifier,
    required dynamic activeSession,
  }) {
    switch (_currentTab) {
      case DrunkNavTab.rota:
        final origin = state.origin ??
            state.userLocation ??
            RouteFinderNotifier.defaultOrigin;
        return Stack(
          children: [
            DarkMapView(
              origin: origin,
              userLocation: state.userLocation,
              gpsAccuracyMeters: state.gpsAccuracyMeters,
              userHeading: state.userHeading,
              isFollowingUser: state.isFollowingUser,
              isLocating: state.isLoadingLocation,
              cameraTarget: state.cameraTarget,
              cameraZoom: state.cameraZoom,
              cameraMoveId: state.cameraMoveId,
              searchRadiusKm: state.searchRadiusKm,
              cityBars: state.cityBars,
              isRegisteringBarMode: state.isRegisteringBarMode,
              isManualRouteMode: state.isManualRouteMode,
              highlightedCityBarId: state.highlightedCityBarId,
              route: state.route,
              selectedBarIndex: state.selectedBarIndex,
              onSelectOrigin: (point) => notifier.setCustomOrigin(
                point,
                centerCamera: false,
              ),
              onRegisterBarAtPoint: (point) =>
                  _openRegisterBarModal(notifier, point: point),
              onAddManualStopAtPoint: (point) =>
                  notifier.addManualStopAtPoint(point),
              onTapCityBar: (bar) => notifier.selectCityBarOnMap(bar.id),
              onAddCityBarToRoute: (bar) =>
                  notifier.toggleBarInManualRoute(bar),
              onEditCityBar: (bar) => _openRegisterBarModal(
                notifier,
                point: bar.coordinates,
                existingBar: bar,
              ),
              onCenterMyLocation: () => notifier.centerOnMyLocation(),
              onSelectBar: (barIndex) {
                if (barIndex < 0) {
                  notifier.selectBar(null);
                } else {
                  notifier.selectBar(barIndex);
                }
              },
              onRemoveBar: (barIndex) =>
                  notifier.removeStopFromRoute(barIndex),
            ),
            if (_isTopMenuOpen)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _isTopMenuOpen = false),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                ),
              ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: FloatingGpsHeader(
                gpsStatus: state.gpsStatus,
                gpsAccuracyMeters: state.gpsAccuracyMeters,
                isFollowingUser: state.isFollowingUser,
                locationAddress: state.locationAddress,
                isLoading: state.isLoadingLocation,
                cityBarsCount: state.cityBars.length,
                targetDistanceKm: state.targetDistanceKm,
                targetBarsCount: state.targetBarsCount,
                isRegisteringBarMode: state.isRegisteringBarMode,
                isManualRouteMode: state.isManualRouteMode,
                manualStopsCount: state.route?.bars.length ?? 0,
                isMenuOpen: _isTopMenuOpen,
                onToggleMenu: () =>
                    setState(() => _isTopMenuOpen = !_isTopMenuOpen),
                onCloseMenu: () => setState(() => _isTopMenuOpen = false),
                onRefresh: () => notifier.centerOnMyLocation(),
                onEditLocation: () => _openLocationSearch(state, notifier),
                onToggleRegisterBarMode: () =>
                    notifier.toggleRegisterBarMode(),
                onToggleManualRouteMode: () =>
                    notifier.toggleManualRouteMode(),
                onUndoManualStop: () => notifier.undoLastManualStop(),
                onOpenCityBarsManager: () =>
                    _openCityBarsManager(state, notifier, origin),
              ),
            ),
            RouteBottomSheet(
              targetDistanceKm: state.targetDistanceKm,
              onTargetDistanceChanged: (km) => notifier.setTargetDistanceKm(km),
              targetBarsCount: state.targetBarsCount,
              onTargetBarsChanged: (bars) => notifier.setTargetBarsCount(bars),
              searchRadiusKm: state.searchRadiusKm,
              onRadiusChanged: (value) => notifier.setSearchRadius(value),
              isGenerating: state.isGenerating,
              isManualRouteMode: state.isManualRouteMode,
              isRouteRegistered: state.isRouteRegistered,
              onGeneratePressed: () => notifier.generateDrunkRoute(),
              onToggleManualRouteMode: () => notifier.toggleManualRouteMode(),
              onUndoManualStop: () => notifier.undoLastManualStop(),
              cityBarsCount: state.cityBars.length,
              route: state.route,
              swappingBarIndex: state.swappingBarIndex,
              selectedBarIndex: state.selectedBarIndex,
              onSelectBar: (index) => notifier.selectBar(index),
              onSwapBar: (index) => notifier.swapBar(index),
              onRemoveBar: (index) => notifier.removeStopFromRoute(index),
              errorMessage: state.errorMessage,
              onResetRoute: () => notifier.resetRoute(),
              onRegisterRoute: _registerRoute,
            ),
          ],
        );

      case DrunkNavTab.anotar:
        return RaceLogView(
          onGoToRoute: () => setState(() => _currentTab = DrunkNavTab.rota),
        );

      case DrunkNavTab.radar:
        return RaceHudScreen(
          onBack: () => setState(() => _currentTab = DrunkNavTab.rota),
        );

      case DrunkNavTab.crew:
        return CrewLobbyView(
          onGoToRoute: () => setState(() => _currentTab = DrunkNavTab.rota),
          onGoToRadar: () => setState(() => _currentTab = DrunkNavTab.radar),
        );

      case DrunkNavTab.perfil:
        return const SafeArea(
          child: Center(
            child: RunnerProfileSheet(),
          ),
        );
    }
  }
}
