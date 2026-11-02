import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/location/gps_telemetry_service.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/utils/haversine_calculator.dart';
import '../../../comanda_checkin/domain/entities/bar_checkin_record.dart';
import '../../../route_finder/domain/entities/drunk_route.dart';
import '../../domain/entities/race_session.dart';

/// Providers globais de persistência, carteira DrunkCoins e histórico
final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService();
});

final drunkCoinsBalanceProvider = FutureProvider<int>((ref) async {
  final storage = ref.watch(localStorageServiceProvider);
  return storage.getDrunkCoinsBalance();
});

final completedSessionsProvider =
    FutureProvider<List<RaceSession>>((ref) async {
  final storage = ref.watch(localStorageServiceProvider);
  return storage.loadCompletedSessions();
});

/// Controlador principal do Modo Corrida (HUD Ativo, Anti-Cheat, Geofence 20m, Comanda e Hidratação)
class RaceSessionNotifier extends StateNotifier<RaceSession?> {
  final LocalStorageService _storage;
  final GpsTelemetryService _gpsService;
  final Ref? _ref;

  Timer? _stopwatchTimer;
  StreamSubscription<GpsTelemetrySample>? _gpsSubscription;
  DateTime? _lastSampleTime;

  RaceSessionNotifier({
    required LocalStorageService storage,
    GpsTelemetryService? gpsService,
    Ref? ref,
    bool autoRestore = true,
  })  : _storage = storage,
        _gpsService = gpsService ?? GpsTelemetryService(),
        _ref = ref,
        super(null) {
    if (autoRestore) {
      restoreSavedSession();
    }
  }

  /// Restaura sessão em andamento do armazenamento local caso o app tenha sido reaberto
  Future<void> restoreSavedSession() async {
    final saved = await _storage.loadActiveSession();
    if (!mounted || saved == null || saved.isCompleted) return;
    state = saved;
    if (!saved.isPaused) {
      _startTimersAndGps();
    }
  }

  /// Inicia uma nova sessão travando a rota dos 10 bares
  Future<RaceSession> startSession({
    required DrunkRoute route,
    String? roomCode,
    String? originLabel,
  }) async {
    _stopTimersAndGps();

    final randomSuffix = (100 + math.Random().nextInt(899)).toString();
    final session = RaceSession(
      sessionId: 'drk_${DateTime.now().millisecondsSinceEpoch}',
      roomCode: roomCode ?? 'DRK-$randomSuffix',
      originLabel: originLabel ?? 'Circuito Noturno 10K',
      route: route,
      currentPosition: route.origin,
      currentSpeedKmh: 0.0,
      validatedDistanceMeters: 0.0,
      elapsedSeconds: 0,
      startedAt: DateTime.now(),
    );

    state = session;
    await _storage.saveActiveSession(session);
    _startTimersAndGps();
    return session;
  }

  void _startTimersAndGps() {
    _stopwatchTimer?.cancel();
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final current = state;
      if (current == null || current.isPaused || current.isCompleted) return;
      final nextElapsed = current.elapsedSeconds + 1;
      state = current.copyWith(elapsedSeconds: nextElapsed);
      if (nextElapsed % 10 == 0) {
        _storage.saveActiveSession(state!);
      }
    });

    _gpsSubscription?.cancel();
    _gpsSubscription = _gpsService.watchPosition().listen((sample) {
      applyTelemetryUpdate(
        sample.coordinates,
        reportedSpeedKmh: sample.speedKmh,
        sampleTime: sample.timestamp,
      );
    });
  }

  void _stopTimersAndGps() {
    _stopwatchTimer?.cancel();
    _stopwatchTimer = null;
    _gpsSubscription?.cancel();
    _gpsSubscription = null;
  }

  /// Processa cada atualização de GPS aplicando a Trava Anti-Cheat (> 15 km/h)
  Future<void> applyTelemetryUpdate(
    LatLng newPosition, {
    double? reportedSpeedKmh,
    DateTime? sampleTime,
    double? explicitWalkedMeters,
  }) async {
    final current = state;
    if (current == null || current.isPaused || current.isCompleted) return;

    final now = sampleTime ?? DateTime.now();
    final deltaMeters = HaversineCalculator.distanceMeters(
      current.currentPosition,
      newPosition,
    );

    double computedSpeedKmh = reportedSpeedKmh ?? 0.0;
    if (reportedSpeedKmh == null && _lastSampleTime != null) {
      final dtSeconds =
          now.difference(_lastSampleTime!).inMilliseconds / 1000.0;
      if (dtSeconds > 0.3) {
        computedSpeedKmh = (deltaMeters / dtSeconds) * 3.6;
      }
    }
    _lastSampleTime = now;

    // REGRA ANTI-CHEAT (RF-04): Se passar de 15 km/h, congela a contagem de distância!
    final isOverspeed = computedSpeedKmh > RaceSession.maxValidSpeedKmh;
    final nextWarnings = (!current.antiCheatTriggered && isOverspeed)
        ? current.antiCheatWarningsCount + 1
        : current.antiCheatWarningsCount;

    double nextValidatedMeters = current.validatedDistanceMeters;
    if (!isOverspeed && !current.isLockedByHydration) {
      final increment = explicitWalkedMeters ??
          (deltaMeters <= 400.0 ? deltaMeters : 0.0);
      nextValidatedMeters += increment;
    }

    final updated = current.copyWith(
      currentPosition: newPosition,
      currentSpeedKmh: computedSpeedKmh,
      antiCheatTriggered: isOverspeed,
      antiCheatWarningsCount: nextWarnings,
      validatedDistanceMeters: nextValidatedMeters,
    );

    state = updated;
    await _storage.saveActiveSession(updated);
  }

  /// Registra o Check-in no bar atual (somente se Haversine <= 20m) e salva a Comanda Financeira
  Future<bool> submitBarCheckin({
    required double spentBrl,
    required DrinkCategory category,
    String? notes,
  }) async {
    final current = state;
    if (current == null || !current.isWithinGeofence) {
      return false;
    }

    final target = current.targetBar;
    if (target == null) return false;

    final barOrder =
        target.order > 0 ? target.order : (current.completedBarsCount + 1);
    final record = BarCheckinRecord(
      barOrder: barOrder,
      barId: target.id,
      barName: target.name,
      spentBrl: math.max(0.0, spentBrl),
      category: category,
      distanceAtCheckinMeters: current.distanceToTargetMeters,
      checkedInAt: DateTime.now(),
      notes: notes,
    );

    final updatedCheckins = [...current.checkins, record];
    final finishedAllBars = updatedCheckins.length >= current.totalBarsCount;

    if (finishedAllBars) {
      _stopTimersAndGps();
      final completed = current.copyWith(
        checkins: updatedCheckins,
        currentSpeedKmh: 0.0,
        antiCheatTriggered: false,
        clearPendingHydration: true,
        isCompleted: true,
        finishedAt: DateTime.now(),
      );
      state = completed;
      await _storage.archiveCompletedSession(completed);
      _ref?.invalidate(drunkCoinsBalanceProvider);
      _ref?.invalidate(completedSessionsProvider);
      return true;
    }

    // REGRA DE HIDRATAÇÃO (RF-07): A cada 2 bares concluídos (2, 4, 6, 8), trava obrigatória!
    final requiresWaterGate =
        barOrder % RaceSession.hydrationIntervalBars == 0;

    final updated = current.copyWith(
      checkins: updatedCheckins,
      pendingHydrationBarOrder: requiresWaterGate ? barOrder : null,
      clearPendingHydration: !requiresWaterGate,
    );

    state = updated;
    await _storage.saveActiveSession(updated);
    return true;
  }

  /// Desbloqueia o próximo bar após confirmação obrigatória de "Copo d'Água Tomado"
  Future<void> confirmHydrationTaken() async {
    final current = state;
    if (current == null || current.pendingHydrationBarOrder == null) return;

    final gateOrder = current.pendingHydrationBarOrder!;
    final updatedGates = {...current.completedHydrationGates, gateOrder};
    final updated = current.copyWith(
      completedHydrationGates: updatedGates,
      clearPendingHydration: true,
    );

    state = updated;
    await _storage.saveActiveSession(updated);
  }

  /// Alterna pausa manual do cronômetro/HUD
  Future<void> togglePause() async {
    final current = state;
    if (current == null || current.isCompleted) return;
    final nextPaused = !current.isPaused;
    state = current.copyWith(
      isPaused: nextPaused,
      currentSpeedKmh: nextPaused ? 0.0 : current.currentSpeedKmh,
    );
    await _storage.saveActiveSession(state!);
  }

  /// Encerra/limpa a sessão atual para retornar ao buscador de rotas
  Future<void> clearCurrentSession() async {
    _stopTimersAndGps();
    state = null;
    await _storage.clearActiveSession();
  }

  // ===========================================================================
  // FERRAMENTAS DE SIMULAÇÃO DEV (Para testes imediatos em Web-Server / Desktop)
  // ===========================================================================

  /// Simula avanço de ~300m correndo a 9.4 km/h na direção do próximo bar
  Future<void> simulateRunStepTowardsBar() async {
    final current = state;
    if (current == null ||
        current.targetBar == null ||
        current.isLockedByHydration ||
        current.isPaused) {
      return;
    }

    final target = current.targetBar!.coordinates;
    final dist = HaversineCalculator.distanceMeters(
      current.currentPosition,
      target,
    );

    if (dist <= 14.0) {
      await applyTelemetryUpdate(
        current.currentPosition,
        reportedSpeedKmh: 9.4,
        explicitWalkedMeters: 0.0,
      );
      return;
    }

    // Avança ~40% da distância restante (ou chega a 12m se já estiver perto)
    final fraction = dist <= 320.0 ? ((dist - 12.0) / dist) : 0.42;
    final nextLat = current.currentPosition.latitude +
        (target.latitude - current.currentPosition.latitude) * fraction;
    final nextLng = current.currentPosition.longitude +
        (target.longitude - current.currentPosition.longitude) * fraction;
    final nextPos = LatLng(nextLat, nextLng);

    final straightStep = HaversineCalculator.distanceMeters(
      current.currentPosition,
      nextPos,
    );
    final streetStepMeters = straightStep * 1.25;
    final simulatedRunSecs = (streetStepMeters / (9.4 / 3.6)).round();

    state = current.copyWith(
      elapsedSeconds: current.elapsedSeconds + math.max(15, simulatedRunSecs),
    );

    await applyTelemetryUpdate(
      nextPos,
      reportedSpeedKmh: 9.4,
      explicitWalkedMeters: streetStepMeters,
    );
  }

  /// Simula chegada imediata ao raio de Geofence (12m <= 20m) do próximo bar
  Future<void> simulateArriveAtBarGeofence() async {
    final current = state;
    if (current == null ||
        current.targetBar == null ||
        current.isLockedByHydration ||
        current.isPaused) {
      return;
    }

    final targetBar = current.targetBar!;
    final target = targetBar.coordinates;
    final remainingStraight = HaversineCalculator.distanceMeters(
      current.currentPosition,
      target,
    );

    // Posiciona a ~12 metros do bar (aprox. 0.000108 graus de latitude)
    final arrivalPos = LatLng(target.latitude - 0.000105, target.longitude);
    final walkedMeters = remainingStraight > 25.0
        ? math.max(remainingStraight * 1.24, targetBar.distanceFromPrevious * 0.5)
        : remainingStraight;
    final simulatedSecs = (walkedMeters / (9.6 / 3.6)).round();

    state = current.copyWith(
      elapsedSeconds: current.elapsedSeconds + math.max(10, simulatedSecs),
    );

    await applyTelemetryUpdate(
      arrivalPos,
      reportedSpeedKmh: 9.6,
      explicitWalkedMeters: walkedMeters,
    );
  }

  /// Simula entrada/saída de um veículo (> 15 km/h) para validar a trava Anti-Cheat
  Future<void> toggleSimulatedVehicleSpeed() async {
    final current = state;
    if (current == null || current.isCompleted) return;

    if (current.antiCheatTriggered) {
      // Volta ao ritmo seguro de corrida a pé (9.2 km/h)
      await applyTelemetryUpdate(
        current.currentPosition,
        reportedSpeedKmh: 9.2,
        explicitWalkedMeters: 0.0,
      );
    } else {
      // Simula carro/moto a 24.8 km/h deslocando 120m (que NÃO serão somados na meta!)
      final fakeCarPos = LatLng(
        current.currentPosition.latitude + 0.0004,
        current.currentPosition.longitude + 0.0004,
      );
      await applyTelemetryUpdate(
        fakeCarPos,
        reportedSpeedKmh: 24.8,
        explicitWalkedMeters: 120.0,
      );
    }
  }

  @override
  void dispose() {
    _stopTimersAndGps();
    super.dispose();
  }
}

final raceSessionProvider =
    StateNotifierProvider<RaceSessionNotifier, RaceSession?>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return RaceSessionNotifier(
    storage: storage,
    ref: ref,
  );
});
