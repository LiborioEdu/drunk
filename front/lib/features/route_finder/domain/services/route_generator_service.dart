import 'package:latlong2/latlong.dart';
import '../../../../core/utils/haversine_calculator.dart';
import '../../data/datasources/osrm_datasource.dart';
import '../entities/bar.dart';
import '../entities/drunk_route.dart';

/// Serviço que executa a heurística local para selecionar 10 bares rumo a ~10km
class RouteGeneratorService {
  final OsrmDatasource _osrmDatasource;

  RouteGeneratorService({OsrmDatasource? osrmDatasource})
      : _osrmDatasource = osrmDatasource ?? OsrmDatasource();

  /// Executa o algoritmo de seleção e traçado de rota
  Future<DrunkRoute> generateRoute({
    required LatLng origin,
    required List<Bar> candidatePool,
    int targetBars = 10,
    double minLegDistanceMeters = 600.0,
    double maxLegDistanceMeters = 1400.0,
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

    // Heurística de seleção sequencial
    final selectedBars = _select10Bars(
      origin: origin,
      pool: availablePool,
      targetCount: targetBars,
      minLeg: minLegDistanceMeters,
      maxLeg: maxLegDistanceMeters,
    );

    // Lista de coordenadas completas (Origem + Bares)
    final allCoords = [
      origin,
      ...selectedBars.map((b) => b.coordinates),
    ];

    try {
      // 3. Traçado de Ruas Reais via OSRM
      final osrmResult = await _osrmDatasource.calculateFootRoute(allCoords);

      // Atualiza cada bar com sua ordem e distância real do trecho
      final finalizedBars = <Bar>[];
      for (int i = 0; i < selectedBars.length; i++) {
        final legDist = (i < osrmResult.legDistances.length)
            ? osrmResult.legDistances[i]
            : HaversineCalculator.distanceMeters(
                i == 0 ? origin : selectedBars[i - 1].coordinates,
                selectedBars[i].coordinates,
              );

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
        polyline: osrmResult.polyline,
        candidatePool: candidatePool,
        rejectedBarIds: initialRejectedIds,
      );
    } catch (_) {
      // Fallback gracioso caso OSRM público esteja temporariamente indisponível
      return _generateFallbackRoute(
        origin: origin,
        selectedBars: selectedBars,
        candidatePool: candidatePool,
        rejectedIds: initialRejectedIds,
      );
    }
  }

  /// Seleciona bares encadeados com heurística direcional
  List<Bar> _select10Bars({
    required LatLng origin,
    required List<Bar> pool,
    required int targetCount,
    required double minLeg,
    required double maxLeg,
  }) {
    final selected = <Bar>[];
    final usedIds = <String>{};
    LatLng currentPoint = origin;
    double? lastBearing;

    // Tenta em passadas com relaxamento progressivo de raio caso necessário
    double curMinLeg = minLeg;
    double curMaxLeg = maxLeg;

    while (selected.length < targetCount && usedIds.length < pool.length) {
      Bar? bestCandidate;
      double bestScore = double.infinity;

      for (final candidate in pool) {
        if (usedIds.contains(candidate.id)) continue;

        final dist = HaversineCalculator.distanceMeters(
          currentPoint,
          candidate.coordinates,
        );

        // Verifica se está dentro da faixa de distância do trecho
        if (dist < (curMinLeg * 0.6) || dist > (curMaxLeg * 1.5)) continue;

        final bearing = HaversineCalculator.bearingDegrees(
          currentPoint,
          candidate.coordinates,
        );

        // Penalidade para evitar voltar para trás
        double anglePenalty = 0.0;
        if (lastBearing != null) {
          final angleDiff = HaversineCalculator.angleDifference(lastBearing, bearing);
          if (angleDiff > 120.0) {
            anglePenalty = (angleDiff - 120.0) * 8.0; // penaliza retornos
          }
        }

        // Score: busca proximidade da distância ideal (~900m) + baixa penalidade angular
        final targetLeg = (curMinLeg + curMaxLeg) / 2.0;
        final distDeviation = (dist - targetLeg).abs();
        final score = distDeviation + anglePenalty;

        if (score < bestScore) {
          bestScore = score;
          bestCandidate = candidate;
        }
      }

      if (bestCandidate != null) {
        selected.add(bestCandidate);
        usedIds.add(bestCandidate.id);
        lastBearing = HaversineCalculator.bearingDegrees(
          currentPoint,
          bestCandidate.coordinates,
        );
        currentPoint = bestCandidate.coordinates;
      } else {
        // Se não encontrou no raio ideal, relaxa as restrições
        if (curMinLeg > 300) {
          curMinLeg -= 150;
          curMaxLeg += 300;
        } else {
          // Pega o bar não visitado mais próximo
          Bar? closest;
          double closestDist = double.infinity;
          for (final c in pool) {
            if (usedIds.contains(c.id)) continue;
            final d = HaversineCalculator.distanceMeters(currentPoint, c.coordinates);
            if (d < closestDist) {
              closestDist = d;
              closest = c;
            }
          }
          if (closest != null) {
            selected.add(closest);
            usedIds.add(closest.id);
            currentPoint = closest.coordinates;
          } else {
            break; // Sem mais candidatos
          }
        }
      }
    }

    return selected;
  }

  /// Gera a rota calculando distâncias em linha reta com compensação caso a API OSRM oscile
  DrunkRoute _generateFallbackRoute({
    required LatLng origin,
    required List<Bar> selectedBars,
    required List<Bar> candidatePool,
    required Set<String> rejectedIds,
  }) {
    double totalDist = 0.0;
    final finalizedBars = <Bar>[];
    final polyline = <LatLng>[origin];

    LatLng prev = origin;
    for (int i = 0; i < selectedBars.length; i++) {
      final bar = selectedBars[i];
      // Haversine compensado em ~1.28x para estimar curvas de ruas
      final dist = HaversineCalculator.distanceMeters(prev, bar.coordinates) * 1.28;
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

    // Estimativa de caminhada a ~4.5 km/h (1.25 m/s)
    final durationSeconds = totalDist / 1.25;

    return DrunkRoute(
      origin: origin,
      bars: finalizedBars,
      totalDistanceMeters: totalDist,
      totalDurationSeconds: durationSeconds,
      polyline: polyline,
      candidatePool: candidatePool,
      rejectedBarIds: rejectedIds,
    );
  }
}
