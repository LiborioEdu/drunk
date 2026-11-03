import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import '../../../../core/utils/haversine_calculator.dart';
import '../../data/datasources/osrm_datasource.dart';
import '../entities/bar.dart';
import '../entities/drunk_route.dart';

/// Serviço que executa a heurística local para selecionar [targetBars] bares
/// atingindo aproximadamente [targetDistanceKm] km de percurso pelas ruas.
class RouteGeneratorService {
  /// Fator médio de tortuosidade urbana (distância de rua vs. linha reta Haversine)
  static const double urbanTortuosityFactor = 1.28;

  final OsrmDatasource _osrmDatasource;

  RouteGeneratorService({OsrmDatasource? osrmDatasource})
      : _osrmDatasource = osrmDatasource ?? OsrmDatasource();

  /// Executa o algoritmo de seleção e traçado de rota parametrizado por KM e nº de bares
  Future<DrunkRoute> generateRoute({
    required LatLng origin,
    required List<Bar> candidatePool,
    int targetBars = 10,
    double targetDistanceKm = 10.0,
    double? minLegDistanceMeters,
    double? maxLegDistanceMeters,
    Set<String> initialRejectedIds = const {},
  }) async {
    if (candidatePool.isEmpty) {
      throw Exception('Nenhum bar encontrado na região selecionada.');
    }

    final availablePool = candidatePool
        .where((b) => !initialRejectedIds.contains(b.id))
        .toList();

    if (availablePool.isEmpty) {
      throw Exception('Todos os bares encontrados já foram rejeitados.');
    }

    final effectiveTargetBars =
        targetBars.clamp(1, availablePool.length);
    final targetDistanceMeters =
        (targetDistanceKm.clamp(0.5, 50.0)) * 1000.0;

    // Distância em linha reta esperada por trecho para atingir a meta de rua
    final idealStraightLeg =
        (targetDistanceMeters / urbanTortuosityFactor) / effectiveTargetBars;
    final effectiveMinLeg =
        minLegDistanceMeters ?? (idealStraightLeg * 0.45).clamp(80.0, 2500.0);
    final effectiveMaxLeg =
        maxLegDistanceMeters ?? (idealStraightLeg * 1.65).clamp(250.0, 6000.0);

    // Heurística multi-start que escolhe a sequência de bares mais fiel à meta de KM
    final selectedBars = _selectOptimalBarChain(
      origin: origin,
      pool: availablePool,
      targetCount: effectiveTargetBars,
      targetStreetDistanceMeters: targetDistanceMeters,
      minLeg: effectiveMinLeg,
      maxLeg: effectiveMaxLeg,
    );

    final allCoords = [
      origin,
      ...selectedBars.map((b) => b.coordinates),
    ];

    try {
      final osrmResult = await _osrmDatasource.calculateFootRoute(allCoords);

      final finalizedBars = <Bar>[];
      for (int i = 0; i < selectedBars.length; i++) {
        final legDist = (i < osrmResult.legDistances.length)
            ? osrmResult.legDistances[i]
            : HaversineCalculator.distanceMeters(
                  i == 0 ? origin : selectedBars[i - 1].coordinates,
                  selectedBars[i].coordinates,
                ) *
                urbanTortuosityFactor;

        finalizedBars.add(
          selectedBars[i].copyWith(
            order: i + 1,
            distanceFromPrevious: legDist,
          ),
        );
      }

      return DrunkRoute(
        origin: origin,
        bars: finalizedBars,
        totalDistanceMeters: osrmResult.distanceMeters,
        totalDurationSeconds: osrmResult.durationSeconds,
        targetDistanceMeters: targetDistanceMeters,
        targetBarsCount: effectiveTargetBars,
        polyline: osrmResult.polyline,
        candidatePool: candidatePool,
        rejectedBarIds: initialRejectedIds,
      );
    } catch (_) {
      return _generateFallbackRoute(
        origin: origin,
        selectedBars: selectedBars,
        candidatePool: candidatePool,
        rejectedIds: initialRejectedIds,
        targetDistanceMeters: targetDistanceMeters,
        targetBarsCount: effectiveTargetBars,
      );
    }
  }

  /// Avalia múltiplas sementes iniciais e retorna a sequência de [targetCount] bares
  /// cuja distância total estimada pelas ruas mais se aproxima de [targetStreetDistanceMeters]
  /// sem realizar retornos artificiais (ziguezague de 180°).
  List<Bar> _selectOptimalBarChain({
    required LatLng origin,
    required List<Bar> pool,
    required int targetCount,
    required double targetStreetDistanceMeters,
    required double minLeg,
    required double maxLeg,
  }) {
    final targetStraightTotal =
        targetStreetDistanceMeters / urbanTortuosityFactor;
    final idealFirstLeg = targetStraightTotal / targetCount;

    // Se o pool possui exatamente (ou menos que) a quantidade de bares pedida,
    // inicia pelo bar mais próximo da largada para manter progressão geográfica natural
    if (pool.length <= targetCount) {
      final closestToOrigin = List<Bar>.from(pool)
        ..sort((a, b) {
          final da = HaversineCalculator.distanceMeters(origin, a.coordinates);
          final db = HaversineCalculator.distanceMeters(origin, b.coordinates);
          return da.compareTo(db);
        });
      return _buildChainFromSeed(
        origin: origin,
        pool: pool,
        firstBar: closestToOrigin.first,
        targetCount: targetCount,
        targetStraightTotal: targetStraightTotal,
        minLeg: minLeg,
        maxLeg: maxLeg,
      );
    }

    // Ordena possíveis primeiros bares pela proximidade ao salto ideal a partir da largada
    final sortedStarts = List<Bar>.from(pool)
      ..sort((a, b) {
        final da =
            (HaversineCalculator.distanceMeters(origin, a.coordinates) -
                    idealFirstLeg)
                .abs();
        final db =
            (HaversineCalculator.distanceMeters(origin, b.coordinates) -
                    idealFirstLeg)
                .abs();
        return da.compareTo(db);
      });

    final maxSeeds = math.min(sortedStarts.length, 6);
    List<Bar>? bestChain;
    double bestTotalScore = double.infinity;

    for (int s = 0; s < maxSeeds; s++) {
      final candidateChain = _buildChainFromSeed(
        origin: origin,
        pool: pool,
        firstBar: sortedStarts[s],
        targetCount: targetCount,
        targetStraightTotal: targetStraightTotal,
        minLeg: minLeg,
        maxLeg: maxLeg,
      );

      if (candidateChain.isEmpty) continue;

      double chainStraightDist = 0.0;
      double totalBacktrackPenalty = 0.0;
      LatLng prev = origin;
      double? prevBearing;

      for (final b in candidateChain) {
        chainStraightDist +=
            HaversineCalculator.distanceMeters(prev, b.coordinates);
        final bearing = HaversineCalculator.bearingDegrees(prev, b.coordinates);
        if (prevBearing != null) {
          final angleDiff =
              HaversineCalculator.angleDifference(prevBearing, bearing);
          if (angleDiff > 125.0) {
            totalBacktrackPenalty += (angleDiff - 125.0) * 18.0;
          }
        }
        prevBearing = bearing;
        prev = b.coordinates;
      }

      // Prioriza cadeias completas, sem retornos bruscos e próximas à meta de KM
      final missingPenalty =
          (targetCount - candidateChain.length) * 10000.0;
      final distError = (chainStraightDist - targetStraightTotal).abs();
      final totalScore = missingPenalty + distError + totalBacktrackPenalty;

      if (totalScore < bestTotalScore) {
        bestTotalScore = totalScore;
        bestChain = candidateChain;
      }
    }

    return bestChain ?? pool.take(targetCount).toList();
  }

  List<Bar> _buildChainFromSeed({
    required LatLng origin,
    required List<Bar> pool,
    required Bar firstBar,
    required int targetCount,
    required double targetStraightTotal,
    required double minLeg,
    required double maxLeg,
  }) {
    final selected = <Bar>[firstBar];
    final usedIds = <String>{firstBar.id};

    double accumulatedStraight = HaversineCalculator.distanceMeters(
      origin,
      firstBar.coordinates,
    );
    LatLng currentPoint = firstBar.coordinates;
    double? lastBearing = HaversineCalculator.bearingDegrees(
      origin,
      firstBar.coordinates,
    );

    while (selected.length < targetCount && usedIds.length < pool.length) {
      final remainingSteps = targetCount - selected.length;
      final remainingBudget = math.max(
        80.0 * remainingSteps,
        targetStraightTotal - accumulatedStraight,
      );
      final dynamicTargetLeg = remainingBudget / remainingSteps;

      Bar? bestCandidate;
      double bestScore = double.infinity;

      for (final candidate in pool) {
        if (usedIds.contains(candidate.id)) continue;

        final dist = HaversineCalculator.distanceMeters(
          currentPoint,
          candidate.coordinates,
        );

        final bearing = HaversineCalculator.bearingDegrees(
          currentPoint,
          candidate.coordinates,
        );

        // Penalidade suave para evitar ziguezague brusco de 180 graus
        double anglePenalty = 0.0;
        if (lastBearing != null) {
          final angleDiff =
              HaversineCalculator.angleDifference(lastBearing, bearing);
          if (angleDiff > 130.0) {
            anglePenalty = (angleDiff - 130.0) * 5.5;
          }
        }

        // Penalidade extra se fugir demais da janela flexível do trecho
        double boundsPenalty = 0.0;
        final lowerBound = math.min(minLeg * 0.5, dynamicTargetLeg * 0.45);
        final upperBound = math.max(maxLeg * 1.5, dynamicTargetLeg * 1.85);
        if (dist < lowerBound) {
          boundsPenalty = (lowerBound - dist) * 1.5;
        } else if (dist > upperBound) {
          boundsPenalty = (dist - upperBound) * 1.5;
        }

        final distDeviation = (dist - dynamicTargetLeg).abs();
        final score = distDeviation + anglePenalty + boundsPenalty;

        if (score < bestScore) {
          bestScore = score;
          bestCandidate = candidate;
        }
      }

      if (bestCandidate == null) break;

      final stepDist = HaversineCalculator.distanceMeters(
        currentPoint,
        bestCandidate.coordinates,
      );
      accumulatedStraight += stepDist;
      lastBearing = HaversineCalculator.bearingDegrees(
        currentPoint,
        bestCandidate.coordinates,
      );
      currentPoint = bestCandidate.coordinates;
      selected.add(bestCandidate);
      usedIds.add(bestCandidate.id);
    }

    return selected;
  }

  /// Gera a rota calculando distâncias em linha reta com compensação caso a API OSRM oscile
  DrunkRoute _generateFallbackRoute({
    required LatLng origin,
    required List<Bar> selectedBars,
    required List<Bar> candidatePool,
    required Set<String> rejectedIds,
    required double targetDistanceMeters,
    required int targetBarsCount,
  }) {
    double totalDist = 0.0;
    final finalizedBars = <Bar>[];
    final polyline = <LatLng>[origin];

    LatLng prev = origin;
    for (int i = 0; i < selectedBars.length; i++) {
      final bar = selectedBars[i];
      final dist = HaversineCalculator.distanceMeters(prev, bar.coordinates) *
          urbanTortuosityFactor;
      totalDist += dist;

      finalizedBars.add(
        bar.copyWith(
          order: i + 1,
          distanceFromPrevious: dist,
        ),
      );
      polyline.add(bar.coordinates);
      prev = bar.coordinates;
    }

    // Estimativa de caminhada/trote a ~5.0 km/h (1.39 m/s)
    final durationSeconds = totalDist / 1.39;

    return DrunkRoute(
      origin: origin,
      bars: finalizedBars,
      totalDistanceMeters: totalDist,
      totalDurationSeconds: durationSeconds,
      targetDistanceMeters: targetDistanceMeters,
      targetBarsCount: targetBarsCount,
      polyline: polyline,
      candidatePool: candidatePool,
      rejectedBarIds: rejectedIds,
    );
  }
}
