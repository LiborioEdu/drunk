import 'package:drunk_front/core/location/gps_telemetry_service.dart';
import 'package:drunk_front/core/storage/local_storage_service.dart';
import 'package:drunk_front/core/theme/app_theme.dart';
import 'package:drunk_front/core/widgets/drunk_bottom_nav_bar.dart';
import 'package:drunk_front/features/race_hud/presentation/controllers/race_session_controller.dart';
import 'package:drunk_front/features/race_hud/presentation/screens/race_hud_screen.dart';
import 'package:drunk_front/features/route_finder/domain/entities/bar.dart';
import 'package:drunk_front/features/route_finder/domain/entities/drunk_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoopGpsService extends GpsTelemetryService {
  @override
  Stream<GpsTelemetrySample> watchPosition() => const Stream.empty();
}

DrunkRoute _sampleThreeBarRoute() {
  const origin = LatLng(-5.0645, -42.7788);
  final bars = [
    const Bar(
      id: 'b1',
      name: 'The Champions Restobar',
      latitude: -5.0691,
      longitude: -42.7812,
      order: 1,
      distanceFromPrevious: 650,
    ),
    const Bar(
      id: 'b2',
      name: 'Up Resto Pub',
      latitude: -5.0621,
      longitude: -42.7765,
      order: 2,
      distanceFromPrevious: 890,
    ),
    const Bar(
      id: 'b3',
      name: 'Varanda Boteco',
      latitude: -5.0723,
      longitude: -42.7934,
      order: 3,
      distanceFromPrevious: 1120,
    ),
  ];

  return DrunkRoute(
    origin: origin,
    bars: bars,
    totalDistanceMeters: 2660,
    totalDurationSeconds: 1900,
    polyline: [origin, ...bars.map((b) => b.coordinates)],
  );
}

void main() {
  testWidgets(
      'Barra de navegação inferior exibe o nome DRUNK no lugar de RADAR',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          bottomNavigationBar: DrunkBottomNavBar(
            currentTab: DrunkNavTab.radar,
            onSelectTab: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('DRUNK'), findsOneWidget);
    expect(find.text('RADAR'), findsNothing);
  });

  testWidgets(
      'Tela DRUNK estilo Pokémon GO: reconhece rota, ativa START no ponto de start, vira PAUSE na parada e exige START para voltar a contar',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorageService();
    final sessionNotifier = RaceSessionNotifier(
      storage: storage,
      gpsService: _NoopGpsService(),
      autoRestore: false,
    );

    final route = _sampleThreeBarRoute();

    // 1. Inicia longe do Ponto de Start (> 20m): botão START fica desativado
    await sessionNotifier.syncRouteFromFinder(
      route,
      userPosition: const LatLng(-5.0600, -42.7700),
      originLabel: 'Teresina',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          raceSessionProvider.overrideWith((_) => sessionNotifier),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const RaceHudScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('DRUNK'), findsOneWidget);
    expect(find.textContaining('VÁ ATÉ O PONTO DE START'), findsOneWidget);
    expect(sessionNotifier.state!.hasStarted, isFalse);

    // Garante que o topo ("DRUNK") e o HUD inferior estão separados na tela cheia (sem sobreposição)
    final topBadgeRect = tester.getRect(find.text('DRUNK'));
    final bottomOrbRect =
        tester.getRect(find.byKey(const Key('drunk_central_action_button')));
    expect(bottomOrbRect.top, greaterThan(topBadgeRect.bottom + 400));

    // Tentar clicar em START longe da largada não inicia a corrida
    await tester.tap(find.byKey(const Key('drunk_central_action_button')));
    await tester.pump();
    expect(sessionNotifier.state!.hasStarted, isFalse);

    // 2. Usuário chega no Ponto de Start -> botão START ativa!
    await sessionNotifier.moveUserPosition(route.origin);
    await tester.pump();

    expect(
      find.text('NO PONTO DE START • APERTE START PARA COMEÇAR'),
      findsOneWidget,
    );
    expect(sessionNotifier.state!.canStartAtOrigin, isTrue);

    // Clica em START -> grupo começa a corrida
    await tester.tap(find.byKey(const Key('drunk_central_action_button')));
    await tester.pump();
    expect(sessionNotifier.state!.hasStarted, isTrue);
    expect(sessionNotifier.state!.isPaused, isFalse);
    expect(find.textContaining('PERCURSO ATIVO • PARADA #1'), findsOneWidget);

    // 3. Usuário chega no Ponto de Parada #1 -> botão vira PAUSE!
    await tester.tap(find.byKey(const Key('drunk_simulate_step_button')));
    await tester.pump();

    expect(sessionNotifier.state!.isAtStopPoint, isTrue);
    expect(sessionNotifier.state!.canPauseAtStop, isTrue);
    expect(find.text('PAUSE'), findsOneWidget);
    expect(find.text('CHEGOU NA PARADA #1 • APERTE PAUSE'), findsOneWidget);

    // 4. Usuário aperta PAUSE na Parada #1 -> corrida pausa e botão vira START
    await tester.tap(find.byKey(const Key('drunk_central_action_button')));
    await tester.pump();

    expect(sessionNotifier.state!.isPaused, isTrue);
    expect(sessionNotifier.state!.canResumeFromStop, isTrue);
    expect(
      find.text('PAUSADO NA PARADA #1 • APERTE START PARA CONTINUAR'),
      findsOneWidget,
    );
    expect(find.text('START'), findsOneWidget);

    // 5. Usuário aperta START novamente -> volta a contar o percurso rumo à Parada #2!
    await tester.tap(find.byKey(const Key('drunk_central_action_button')));
    await tester.pump();

    expect(sessionNotifier.state!.isPaused, isFalse);
    expect(sessionNotifier.state!.completedBarsCount, 1);
    expect(find.text('PARADAS 1/3'), findsOneWidget);
    expect(find.textContaining('PERCURSO ATIVO • PARADA #2'), findsOneWidget);
  });
}
