import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/drunk_bottom_nav_bar.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../../crew_lobby/presentation/screens/crew_lobby_view.dart';
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
import '../widgets/route_locked_modal.dart';
import '../widgets/runner_profile_sheet.dart';

/// Shell Principal DRUNK com Barra Inferior Stitch IA (`ROTA • RADAR • CREW • PERFIL`)
class RouteFinderScreen extends ConsumerStatefulWidget {
  const RouteFinderScreen({super.key});

  @override
  ConsumerState<RouteFinderScreen> createState() => _RouteFinderScreenState();
}

class _RouteFinderScreenState extends ConsumerState<RouteFinderScreen> {
  DrunkNavTab _currentTab = DrunkNavTab.rota;

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

  Future<void> _lockAndLaunchHud() async {
    final state = ref.read(routeFinderProvider);
    final route = state.route;
    if (route == null) return;

    final decision = await RouteLockedModal.show(context, route);
    if (decision == null || !mounted) return;

    final roomCode = decision == 'SOLO-START' ? null : decision;
    await ref.read(raceSessionProvider.notifier).startSession(
          route: route,
          roomCode: roomCode,
          originLabel: state.locationAddress,
        );

    if (!mounted) return;
    setState(() => _currentTab = DrunkNavTab.radar);
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
              highlightedCityBarId: state.highlightedCityBarId,
              route: state.route,
              selectedBarIndex: state.selectedBarIndex,
              onSelectOrigin: (point) => notifier.setCustomOrigin(
                point,
                centerCamera: false,
              ),
              onRegisterBarAtPoint: (point) =>
                  _openRegisterBarModal(notifier, point: point),
              onTapCityBar: (bar) => notifier.selectCityBarOnMap(bar.id),
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
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingGpsHeader(
                    gpsStatus: state.gpsStatus,
                    gpsAccuracyMeters: state.gpsAccuracyMeters,
                    isFollowingUser: state.isFollowingUser,
                    locationAddress: state.locationAddress,
                    isLoading: state.isLoadingLocation,
                    cityBarsCount: state.cityBars.length,
                    isRegisteringBarMode: state.isRegisteringBarMode,
                    onRefresh: () => notifier.centerOnMyLocation(),
                    onEditLocation: () => _openLocationSearch(state, notifier),
                    onToggleRegisterBarMode: () =>
                        notifier.toggleRegisterBarMode(),
                    onOpenCityBarsManager: () =>
                        _openCityBarsManager(state, notifier, origin),
                  ),
                  if (activeSession != null && !activeSession.isCompleted)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                      child: Material(
                        color: const Color(0xF0141419),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () =>
                              setState(() => _currentTab = DrunkNavTab.radar),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.cyberGreen,
                                width: 1.4,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.directions_run_rounded,
                                  color: AppColors.cyberGreen,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'CORRIDA ATIVA (${activeSession.completedBarsCount}/${activeSession.totalBarsCount} BARES • '
                                    '${activeSession.validatedDistanceKm.toStringAsFixed(2)} KM)',
                                    style: const TextStyle(
                                      color: AppColors.cyberGreen,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const Text(
                                  'ABRIR RADAR →',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            RouteBottomSheet(
              searchRadiusKm: state.searchRadiusKm,
              onRadiusChanged: (value) => notifier.setSearchRadius(value),
              isGenerating: state.isGenerating,
              onGeneratePressed: () => notifier.generateDrunkRoute(),
              cityBarsCount: state.cityBars.length,
              route: state.route,
              swappingBarIndex: state.swappingBarIndex,
              selectedBarIndex: state.selectedBarIndex,
              onSelectBar: (index) => notifier.selectBar(index),
              onSwapBar: (index) => notifier.swapBar(index),
              errorMessage: state.errorMessage,
              onResetRoute: () => notifier.resetRoute(),
              onLockAndStart: _lockAndLaunchHud,
            ),
          ],
        );

      case DrunkNavTab.radar:
        if (activeSession != null) {
          return RaceHudScreen(
            onBack: () => setState(() => _currentTab = DrunkNavTab.rota),
          );
        }
        return _buildEmptyRadarLauncher(context, state, notifier);

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

  Widget _buildEmptyRadarLauncher(
    BuildContext context,
    RouteFinderState state,
    RouteFinderNotifier notifier,
  ) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: AppColors.neonCyan.withValues(alpha: 0.45),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppColors.neonCyan.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.neonCyan, width: 1.8),
                  ),
                  child: const Icon(
                    Icons.radar_rounded,
                    color: AppColors.neonCyan,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'NOCTURNAL RUN HUD',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Telemetria em tempo real com trava Anti-Cheat (>15 km/h), Geofence de 20m, Comanda em R\$ e Gates de Hidratação.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                NeonButton(
                  label: state.hasRoute
                      ? 'INICIAR HUD COM ROTA ATUAL'
                      : 'GERAR ROTA 10KM E INICIAR HUD',
                  icon: Icons.play_arrow_rounded,
                  borderRadius: 28,
                  color: AppColors.cyberGreen,
                  glowColor: AppColors.cyberGreenGlow,
                  gradient: AppColors.cyberGreenGradient,
                  textColor: Colors.black,
                  isLoading: state.isGenerating,
                  onPressed: () async {
                    if (!state.hasRoute) {
                      await notifier.generateDrunkRoute();
                    }
                    final updatedRoute = ref.read(routeFinderProvider).route;
                    if (updatedRoute != null) {
                      await ref.read(raceSessionProvider.notifier).startSession(
                            route: updatedRoute,
                            originLabel:
                                ref.read(routeFinderProvider).locationAddress,
                          );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
