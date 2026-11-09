import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import '../../../../core/utils/haversine_calculator.dart';
import '../../../comanda_checkin/domain/entities/bar_checkin_record.dart';
import '../../../route_finder/domain/entities/bar.dart';
import '../../../route_finder/domain/entities/drunk_route.dart';

/// Estado completo de uma sessão ativa ou concluída da Maratona DRUNK 10KM
class RaceSession {
  /// Limite máximo permitido para corrida/caminhada antes de ativar o Anti-Cheat
  static const double maxValidSpeedKmh = 15.0;

  /// Raio máximo (Haversine) em metros para destravar o botão de Check-in no bar
  static const double geofenceRadiusMeters = 20.0;

  /// Intervalo de paradas que dispara a trava obrigatória de hidratação
  static const int hydrationIntervalBars = 2;

  final String sessionId;
  final String roomCode;
  final String originLabel;
  final DrunkRoute route;
  final LatLng currentPosition;
  final double headingDegrees;
  final double currentSpeedKmh;
  final bool hasStarted;
  final bool isPaused;
  final double validatedDistanceMeters;
  final int elapsedSeconds;
  final bool antiCheatTriggered;
  final int antiCheatWarningsCount;
  final List<BarCheckinRecord> checkins;
  final Set<int> completedHydrationGates;
  final int? pendingHydrationBarOrder;
  final bool isCompleted;
  final DateTime startedAt;
  final DateTime? finishedAt;

  const RaceSession({
    required this.sessionId,
    required this.roomCode,
    required this.originLabel,
    required this.route,
    required this.currentPosition,
    this.headingDegrees = 0.0,
    this.currentSpeedKmh = 0.0,
    this.hasStarted = true,
    this.isPaused = false,
    this.validatedDistanceMeters = 0.0,
    this.elapsedSeconds = 0,
    this.antiCheatTriggered = false,
    this.antiCheatWarningsCount = 0,
    this.checkins = const [],
    this.completedHydrationGates = const {},
    this.pendingHydrationBarOrder,
    this.isCompleted = false,
    required this.startedAt,
    this.finishedAt,
  });

  /// Quantidade de bares já validados na corrida
  int get completedBarsCount => checkins.length;

  /// Total de bares da rota planejada
  int get totalBarsCount => route.bars.length;

  /// Índice (0-based) do próximo bar alvo
  int get currentBarIndex => completedBarsCount;

  /// Próximo bar alvo (nulo se todos os bares foram concluídos)
  Bar? get targetBar {
    if (completedBarsCount >= route.bars.length) return null;
    return route.bars[completedBarsCount];
  }

  /// Indica se um bar específico (ordem 1..10) já teve check-in realizado
  bool isBarCompleted(int barOrder) {
    return checkins.any((c) => c.barOrder == barOrder);
  }

  /// Distância Haversine real (em metros) do corredor até o Ponto de Start (Largada)
  double get distanceToStartMeters {
    return HaversineCalculator.distanceMeters(
      currentPosition,
      route.origin,
    );
  }

  /// Verdadeiro quando o usuário está dentro do Ponto de Start (<= 20m)
  bool get isAtStartPoint => distanceToStartMeters <= geofenceRadiusMeters;

  /// Distância Haversine real (em metros) do corredor até o bar alvo atual
  double get distanceToTargetMeters {
    final target = targetBar;
    if (target == null) return 0.0;
    return HaversineCalculator.distanceMeters(
      currentPosition,
      target.coordinates,
    );
  }

  /// Verdadeiro quando o usuário chegou ao Ponto de Parada atual (<= 20m)
  bool get isAtStopPoint {
    if (targetBar == null || isCompleted) return false;
    return distanceToTargetMeters <= geofenceRadiusMeters;
  }

  /// Botão START ativa quando o usuário está no Ponto de Start antes de iniciar a corrida
  bool get canStartAtOrigin => !hasStarted && !isCompleted && isAtStartPoint;

  /// Botão vira PAUSE quando o usuário chega no Ponto de Parada durante o percurso
  bool get canPauseAtStop =>
      hasStarted && !isPaused && !isCompleted && isAtStopPoint;

  /// Botão volta a ser START quando a corrida está pausada na parada
  bool get canResumeFromStop => hasStarted && isPaused && !isCompleted;

  /// Regra de Geofencing: Check-in só destrava a <= 20m, sem Anti-Cheat e sem bloqueio de água
  bool get isWithinGeofence {
    if (targetBar == null || isCompleted || isPaused) return false;
    if (antiCheatTriggered || isLockedByHydration) return false;
    return distanceToTargetMeters <= geofenceRadiusMeters;
  }

  /// Verdadeiro quando o corredor concluiu um múltiplo de 2 bares e ainda não bebeu água
  bool get isLockedByHydration => pendingHydrationBarOrder != null;

  /// Verdadeiro se a parada atual disparará gate de hidratação ao ser concluída
  bool get currentTargetTriggersHydration {
    final target = targetBar;
    if (target == null) return false;
    final order = target.order > 0 ? target.order : (completedBarsCount + 1);
    return order % hydrationIntervalBars == 0 && order < totalBarsCount;
  }

  /// Total esperado de paradas de hidratação na rota (ex: 4 gates para 10 bares: 2, 4, 6, 8)
  int get totalHydrationGatesCount {
    if (totalBarsCount <= 2) return 0;
    return (totalBarsCount - 1) ~/ hydrationIntervalBars;
  }

  /// Distância validada em quilômetros (ex: 4.28)
  double get validatedDistanceKm => validatedDistanceMeters / 1000.0;

  /// Distância planejada total em quilômetros (ex: 10.2)
  double get plannedDistanceKm => route.totalDistanceMeters / 1000.0;

  /// Soma acumulada da comanda financeira em Reais
  double get totalSpentBrl =>
      checkins.fold(0.0, (sum, item) => sum + item.spentBrl);

  /// Média gasta por bar concluído
  double get averageSpentPerBarBrl =>
      checkins.isEmpty ? 0.0 : totalSpentBrl / checkins.length;

  /// Tempo ativo formatado (MM:SS ou HH:MM:SS)
  String get elapsedFormatted {
    final hours = elapsedSeconds ~/ 3600;
    final mins = (elapsedSeconds % 3600) ~/ 60;
    final secs = elapsedSeconds % 60;
    final mm = mins.toString().padLeft(2, '0');
    final ss = secs.toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$mm:$ss';
    }
    return '$mm:$ss';
  }

  /// Pace médio de corrida formatado (ex: 5'42")
  String get averagePaceFormatted {
    if (validatedDistanceMeters < 50 || elapsedSeconds < 5) {
      return "6'00\"";
    }
    final secondsPerKm = elapsedSeconds / (validatedDistanceMeters / 1000.0);
    final clamped = secondsPerKm.clamp(180.0, 1800.0);
    final mins = clamped ~/ 60;
    final secs = (clamped % 60).round().toString().padLeft(2, '0');
    return "$mins'$secs\"";
  }

  /// Cálculo oficial de DrunkCoins ganhos na sessão (SPECS RF-08)
  int get earnedDrunkCoins {
    final fromBars = completedBarsCount * 80;
    final fromKm = (validatedDistanceKm * 45).floor();
    final fromHydration = completedHydrationGates.length * 50;
    final penalty = antiCheatWarningsCount * 25;
    return math.max(0, fromBars + fromKm + fromHydration - penalty);
  }

  /// Formata valores em Real brasileiro (ex: "R$ 28,00")
  static String formatBrl(double value) {
    final fixed = value.toStringAsFixed(2).replaceAll('.', ',');
    return 'R\$ $fixed';
  }

  RaceSession copyWith({
    String? sessionId,
    String? roomCode,
    String? originLabel,
    DrunkRoute? route,
    LatLng? currentPosition,
    double? headingDegrees,
    double? currentSpeedKmh,
    bool? hasStarted,
    bool? isPaused,
    double? validatedDistanceMeters,
    int? elapsedSeconds,
    bool? antiCheatTriggered,
    int? antiCheatWarningsCount,
    List<BarCheckinRecord>? checkins,
    Set<int>? completedHydrationGates,
    int? pendingHydrationBarOrder,
    bool clearPendingHydration = false,
    bool? isCompleted,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) {
    return RaceSession(
      sessionId: sessionId ?? this.sessionId,
      roomCode: roomCode ?? this.roomCode,
      originLabel: originLabel ?? this.originLabel,
      route: route ?? this.route,
      currentPosition: currentPosition ?? this.currentPosition,
      headingDegrees: headingDegrees ?? this.headingDegrees,
      currentSpeedKmh: currentSpeedKmh ?? this.currentSpeedKmh,
      hasStarted: hasStarted ?? this.hasStarted,
      isPaused: isPaused ?? this.isPaused,
      validatedDistanceMeters:
          validatedDistanceMeters ?? this.validatedDistanceMeters,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      antiCheatTriggered: antiCheatTriggered ?? this.antiCheatTriggered,
      antiCheatWarningsCount:
          antiCheatWarningsCount ?? this.antiCheatWarningsCount,
      checkins: checkins ?? this.checkins,
      completedHydrationGates:
          completedHydrationGates ?? this.completedHydrationGates,
      pendingHydrationBarOrder: clearPendingHydration
          ? null
          : (pendingHydrationBarOrder ?? this.pendingHydrationBarOrder),
      isCompleted: isCompleted ?? this.isCompleted,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'roomCode': roomCode,
      'originLabel': originLabel,
      'route': route.toJson(),
      'currentPosition': {
        'lat': currentPosition.latitude,
        'lng': currentPosition.longitude,
      },
      'headingDegrees': headingDegrees,
      'currentSpeedKmh': currentSpeedKmh,
      'hasStarted': hasStarted,
      'isPaused': isPaused,
      'validatedDistanceMeters': validatedDistanceMeters,
      'elapsedSeconds': elapsedSeconds,
      'antiCheatTriggered': antiCheatTriggered,
      'antiCheatWarningsCount': antiCheatWarningsCount,
      'checkins': checkins.map((c) => c.toJson()).toList(),
      'completedHydrationGates': completedHydrationGates.toList(),
      'pendingHydrationBarOrder': pendingHydrationBarOrder,
      'isCompleted': isCompleted,
      'startedAt': startedAt.toIso8601String(),
      'finishedAt': finishedAt?.toIso8601String(),
    };
  }

  factory RaceSession.fromJson(Map<String, dynamic> map) {
    final posMap = map['currentPosition'] as Map<String, dynamic>;
    return RaceSession(
      sessionId: map['sessionId']?.toString() ?? 'drk_local',
      roomCode: map['roomCode']?.toString() ?? 'DRK-10K',
      originLabel: map['originLabel']?.toString() ?? 'Ponto de Partida',
      route: DrunkRoute.fromJson(map['route'] as Map<String, dynamic>),
      currentPosition: LatLng(
        (posMap['lat'] as num).toDouble(),
        (posMap['lng'] as num).toDouble(),
      ),
      headingDegrees: (map['headingDegrees'] as num?)?.toDouble() ?? 0.0,
      currentSpeedKmh: (map['currentSpeedKmh'] as num?)?.toDouble() ?? 0.0,
      hasStarted: map['hasStarted'] as bool? ?? false,
      isPaused: map['hasStarted'] == null
          ? true
          : (map['isPaused'] as bool? ?? false),
      validatedDistanceMeters:
          (map['validatedDistanceMeters'] as num?)?.toDouble() ?? 0.0,
      elapsedSeconds: map['hasStarted'] == null
          ? 0
          : ((map['elapsedSeconds'] as num?)?.toInt() ?? 0),
      antiCheatTriggered: map['antiCheatTriggered'] as bool? ?? false,
      antiCheatWarningsCount:
          (map['antiCheatWarningsCount'] as num?)?.toInt() ?? 0,
      checkins: (map['checkins'] as List<dynamic>? ?? const [])
          .map((item) =>
              BarCheckinRecord.fromJson(item as Map<String, dynamic>))
          .toList(),
      completedHydrationGates:
          (map['completedHydrationGates'] as List<dynamic>? ?? const [])
              .map((e) => (e as num).toInt())
              .toSet(),
      pendingHydrationBarOrder:
          (map['pendingHydrationBarOrder'] as num?)?.toInt(),
      isCompleted: map['isCompleted'] as bool? ?? false,
      startedAt: DateTime.tryParse(map['startedAt']?.toString() ?? '') ??
          DateTime.now(),
      finishedAt: map['finishedAt'] != null
          ? DateTime.tryParse(map['finishedAt'].toString())
          : null,
    );
  }
}
