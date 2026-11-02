import 'package:drunk_front/core/location/gps_telemetry_service.dart';
import 'package:drunk_front/core/storage/local_storage_service.dart';
import 'package:drunk_front/core/theme/app_theme.dart';
import 'package:drunk_front/features/comanda_checkin/presentation/modals/hydration_lock_modal.dart';
import 'package:drunk_front/features/race_hud/presentation/controllers/race_session_controller.dart';
import 'package:drunk_front/features/race_hud/presentation/screens/race_hud_screen.dart';
import 'package:drunk_front/features/race_summary/presentation/screens/drunk_wrapped_screen.dart';
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
  const origin = LatLng(-23.5535, -46.6575);
  final bars = [
    const Bar(
      id: 'b1',
      name: 'Boteco Neon Augusta',
      latitude: -23.5505,
      longitude: -46.6555,
      order: 1,
      distanceFromPrevious: 980,
    ),
    const Bar(
      id: 'b2',
      name: 'Cervejaria Subsolo',
      latitude: -23.5475,
      longitude: -46.6535,
      order: 2,
      distanceFromPrevious: 1020,
    ),
    const Bar(
      id: 'b3',
      name: 'Pub Velha Guarda',
      latitude: -23.5445,
      longitude: -46.6515,
      order: 3,
      distanceFromPrevious: 990,
    ),
  ];

  return DrunkRoute(
    origin: origin,
    bars: bars,
    totalDistanceMeters: 2990,
    totalDurationSeconds: 2100,
    polyline: [origin, ...bars.map((b) => b.coordinates)],
  );
}

void main() {
  testWidgets(
      'Fluxo completo UI: RaceHudScreen -> Geofence 20m -> Comanda -> Hydration Lock -> Drunk Wrapped',
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

    await sessionNotifier.startSession(
      route: _sampleThreeBarRoute(),
      roomCode: 'DRK-492',
      originLabel: 'Rua Augusta, 1420',
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

    // 1. Verifica que o HUD montou e a trava Anti-Cheat está ativa
    expect(find.text('TRAVA ANTI-CHEAT ATIVA'), findsOneWidget);
    expect(find.textContaining('BOTECO NEON AUGUSTA'), findsOneWidget);

    // 2. Simula veículo > 15 km/h e verifica alerta vermelho
    await tester.tap(find.text('Testar Carro (25km/h)'));
    await tester.pump();
    expect(find.text('ALERTA DE VEÍCULO DETECTADO!'), findsOneWidget);

    // Sai do veículo de volta para ritmo seguro
    await tester.tap(find.text('Sair do Veículo (9km/h)'));
    await tester.pump();

    // 3. Chega a <= 20m do Bar #01 e abre modal de Check-in e Comanda
    await tester.tap(find.text('Chegar <=20m do Bar'));
    await tester.pump();
    expect(find.text('DENTRO DO RAIO DE 20 METROS!'), findsOneWidget);

    final checkinBtn1 = find.textContaining('FAZER CHECK-IN NO BAR #01');
    await tester.ensureVisible(checkinBtn1);
    await tester.tap(checkinBtn1);
    await tester.pumpAndSettle();

    // Tela 3: Modal de Comanda Financeira aberto
    expect(find.text('QUANTO VOCÊ GASTOU NESTE BAR?'), findsOneWidget);
    await tester.tap(find.text('+ R\$ 50'));
    await tester.pump();
    await tester.tap(find.text('SALVAR COMANDA E LIBERAR BAR #02'));
    await tester.pumpAndSettle();

    // 4. Chega no Bar #02 (par -> dispara Trava Obrigatória de Hidratação!)
    await tester.tap(find.text('Chegar <=20m do Bar'));
    await tester.pump();
    final checkinBtn2 = find.textContaining('FAZER CHECK-IN NO BAR #02');
    await tester.ensureVisible(checkinBtn2);
    await tester.tap(checkinBtn2);
    await tester.pumpAndSettle();

    await tester.tap(find.text('SALVAR COMANDA E LIBERAR BAR #03'));
    await tester.pump();

    // Tela 4: HydrationLockOverlay visível!
    expect(find.byType(HydrationLockOverlay), findsOneWidget);
    expect(find.textContaining('HORA DA ÁGUA!'), findsOneWidget);

    final waterBtn = find.text("JÁ BEBI MEU COPO D'ÁGUA");
    await tester.ensureVisible(waterBtn);
    await tester.tap(waterBtn);
    await tester.pump();
    expect(find.byType(HydrationLockOverlay), findsNothing);

    // 5. Chega no Bar #03 (último bar -> transiciona direto para DrunkWrappedScreen!)
    await tester.tap(find.text('Chegar <=20m do Bar'));
    await tester.pump();
    final checkinBtn3 = find.textContaining('FAZER CHECK-IN NO BAR #03');
    await tester.ensureVisible(checkinBtn3);
    await tester.tap(checkinBtn3);
    await tester.pumpAndSettle();

    await tester.tap(find.text('SALVAR E FINALIZAR 10KM (WRAPPED)'));
    await tester.pump();

    // Tela 5: DrunkWrappedScreen exibida com soma R$ 100,00 (50 + 25 + 25)!
    expect(find.byType(DrunkWrappedScreen), findsOneWidget);
    expect(find.text('R\$ 100,00'), findsOneWidget);
    expect(find.textContaining('DRUNKCOINS CREDITADOS'), findsOneWidget);
  });
}
