import 'package:drunk_front/core/location/gps_telemetry_service.dart';
import 'package:drunk_front/core/storage/local_storage_service.dart';
import 'package:drunk_front/features/comanda_checkin/domain/entities/bar_checkin_record.dart';
import 'package:drunk_front/features/race_hud/presentation/controllers/race_session_controller.dart';
import 'package:drunk_front/features/route_finder/domain/entities/bar.dart';
import 'package:drunk_front/features/route_finder/domain/entities/drunk_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _IdleGpsTelemetryService extends GpsTelemetryService {
  @override
  Stream<GpsTelemetrySample> watchPosition() => const Stream.empty();
}

DrunkRoute _buildTestRoute({int count = 4}) {
  const origin = LatLng(-23.5535, -46.6575);
  final bars = List.generate(count, (index) {
    final order = index + 1;
    return Bar(
      id: 'bar_$order',
      name: 'Bar Neon #$order',
      latitude: origin.latitude + (order * 0.004),
      longitude: origin.longitude + (order * 0.002),
      order: order,
      distanceFromPrevious: 1000.0,
    );
  });

  return DrunkRoute(
    origin: origin,
    bars: bars,
    totalDistanceMeters: count * 1000.0,
    totalDurationSeconds: count * 600.0,
    polyline: [origin, ...bars.map((b) => b.coordinates)],
  );
}

void main() {
  group('RaceSessionNotifier — Anti-Cheat, Geofence 20m, Comanda e Hidratação',
      () {
    late LocalStorageService storage;
    late RaceSessionNotifier notifier;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      storage = LocalStorageService();
      notifier = RaceSessionNotifier(
        storage: storage,
        gpsService: _IdleGpsTelemetryService(),
        autoRestore: false,
      );
    });

    tearDown(() {
      notifier.dispose();
    });

    test(
        'Anti-Cheat pausa soma de quilometragem quando velocidade ultrapassa 15 km/h',
        () async {
      final route = _buildTestRoute();
      await notifier.startSession(route: route, roomCode: 'DRK-777');

      // Corrida válida a 9.5 km/h soma distância normalmente
      await notifier.applyTelemetryUpdate(
        const LatLng(-23.5525, -46.6570),
        reportedSpeedKmh: 9.5,
        explicitWalkedMeters: 250.0,
      );
      expect(notifier.state!.antiCheatTriggered, isFalse);
      expect(notifier.state!.validatedDistanceMeters, closeTo(250.0, 0.01));

      // Trapaça em veículo a 24.8 km/h (> 15 km/h) congela a quilometragem
      await notifier.applyTelemetryUpdate(
        const LatLng(-23.5500, -46.6550),
        reportedSpeedKmh: 24.8,
        explicitWalkedMeters: 400.0,
      );
      expect(notifier.state!.antiCheatTriggered, isTrue);
      expect(notifier.state!.antiCheatWarningsCount, 1);
      expect(notifier.state!.validatedDistanceMeters, closeTo(250.0, 0.01));
    });

    test(
        'Geofence bloqueia check-in acima de 20m e destrava em <= 20m somando Comanda e exigindo Água no Bar #02',
        () async {
      final route = _buildTestRoute(count: 4);
      await notifier.startSession(route: route, roomCode: 'DRK-492');

      // Longe do Bar #01 (> 20m) -> Check-in recusado
      expect(notifier.state!.isWithinGeofence, isFalse);
      final denied = await notifier.submitBarCheckin(
        spentBrl: 20.0,
        category: DrinkCategory.chopp,
      );
      expect(denied, isFalse);

      // Chega a <= 20m do Bar #01 -> Check-in liberado, sem trava de hidratação (ímpar)
      await notifier.simulateArriveAtBarGeofence();
      expect(notifier.state!.isWithinGeofence, isTrue);
      final okBar1 = await notifier.submitBarCheckin(
        spentBrl: 28.50,
        category: DrinkCategory.chopp,
      );
      expect(okBar1, isTrue);
      expect(notifier.state!.completedBarsCount, 1);
      expect(notifier.state!.totalSpentBrl, closeTo(28.50, 0.01));
      expect(notifier.state!.isLockedByHydration, isFalse);

      // Chega a <= 20m do Bar #02 (par) -> Check-in aciona Trava Obrigatória de Hidratação!
      await notifier.simulateArriveAtBarGeofence();
      final okBar2 = await notifier.submitBarCheckin(
        spentBrl: 19.00,
        category: DrinkCategory.drink,
      );
      expect(okBar2, isTrue);
      expect(notifier.state!.completedBarsCount, 2);
      expect(notifier.state!.totalSpentBrl, closeTo(47.50, 0.01));
      expect(notifier.state!.isLockedByHydration, isTrue);
      expect(notifier.state!.pendingHydrationBarOrder, 2);

      // Confirma ingestão do copo d'água -> destrava rota e registra gate
      await notifier.confirmHydrationTaken();
      expect(notifier.state!.isLockedByHydration, isFalse);
      expect(notifier.state!.completedHydrationGates.contains(2), isTrue);

      // Verifica persistência local da sessão ativa
      final persisted = await storage.loadActiveSession();
      expect(persisted, isNotNull);
      expect(persisted!.totalSpentBrl, closeTo(47.50, 0.01));
      expect(persisted.completedBarsCount, 2);
    });

    test(
        'Concluir o último bar encerra a maratona, arquiva Drunk Wrapped e credita DrunkCoins',
        () async {
      final route = _buildTestRoute(count: 2);
      await notifier.startSession(route: route, roomCode: 'DRK-999');

      // Bar 1
      await notifier.simulateArriveAtBarGeofence();
      await notifier.submitBarCheckin(
        spentBrl: 25.0,
        category: DrinkCategory.chopp,
      );

      // Bar 2 (último bar -> vai direto para Drunk Wrapped concluído!)
      await notifier.simulateArriveAtBarGeofence();
      await notifier.submitBarCheckin(
        spentBrl: 30.0,
        category: DrinkCategory.snack,
      );

      expect(notifier.state!.isCompleted, isTrue);
      expect(notifier.state!.totalSpentBrl, closeTo(55.0, 0.01));

      final coins = await storage.getDrunkCoinsBalance();
      expect(coins, greaterThan(0));

      final history = await storage.loadCompletedSessions();
      expect(history.length, 1);
      expect(history.first.roomCode, 'DRK-999');
    });
  });
}
