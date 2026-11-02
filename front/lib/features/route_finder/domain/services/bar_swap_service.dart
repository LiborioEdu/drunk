import 'package:latlong2/latlong.dart';
import '../../../../core/utils/haversine_calculator.dart';
import '../../data/datasources/osrm_datasource.dart';
import '../entities/bar.dart';
import '../entities/drunk_route.dart';

/// Serviço responsável pelo mecanismo de Swap (substituição individual de um bar)
class BarSwapService {
  final OsrmDatasource _osrmDatasource;

  BarSwapService({OsrmDatasource? osrmDatasource})
      : _osrmDatasource = osrmDatasource ?? OsrmDatasource();

  /// Substitui o bar no [barIndex] da [currentRoute] por um candidato alternativo do pool
  Future<DrunkRoute> swapBar({
    required DrunkRoute currentRoute,
    required int barIndex,
  }) async {
    if (barIndex < 0 || barIndex >= currentRoute.bars.length) {
      throw RangeError('Índice de bar inválido para swap.');
    }

    final barToReplace = currentRoute.bars[barIndex];
    final updatedRejectedIds = Set<String>.from(currentRoute.rejectedBarIds)
      ..add(barToReplace.id);

    final currentSelectedIds = currentRoute.bars.map((b) => b.id).toSet();

    // Ponto anterior e próximo para calcular o ponto médio ideal
    final prevCoord = barIndex == 0
        ? currentRoute.origin
        : currentRoute.bars[barIndex - 1].coordinates;

    final nextCoord = barIndex < currentRoute.bars.length - 1
        ? currentRoute.bars[barIndex + 1].coordinates
        : prevCoord;

    final targetMidpoint = LatLng(
      (prevCoord.latitude + nextCoord.latitude) / 2.0,
      (prevCoord.longitude + nextCoord.longitude) / 2.0,
    );

    // Filtra candidatos viáveis no pool original
    final candidates = currentRoute.candidatePool.where((candidate) {
      return !currentSelectedIds.contains(candidate.id) &&
          !updatedRejectedIds.contains(candidate.id);
    }).toList();

    if (candidates.isEmpty) {
      throw Exception('Não há outros bares disponíveis para substituição nesta região.');
    }

    // Ordena pelo mais próximo ao ponto médio do trecho
    candidates.sort((a, b) {
      final distA = HaversineCalculator.distanceMeters(targetMidpoint, a.coordinates);
      final distB = HaversineCalculator.distanceMeters(targetMidpoint, b.coordinates);
      return distA.compareTo(distB);
    });

    final replacementBar = candidates.first;

    // Constrói nova lista com a substituição
    final newBars = List<Bar>.from(currentRoute.bars);
    newBars[barIndex] = replacementBar;

    // Recalcula o traçado com OSRM
    final allCoords = [
      currentRoute.origin,
      ...newBars.map((b) => b.coordinates),
    ];

    try {
      final osrmResult = await _osrmDatasource.calculateFootRoute(allCoords);

      final finalizedBars = <Bar>[];
      for (int i = 0; i < newBars.length; i++) {
        final legDist = (i < osrmResult.legDistances.length)
            ? osrmResult.legDistances[i]
            : HaversineCalculator.distanceMeters(
                i == 0 ? currentRoute.origin : newBars[i - 1].coordinates,
                newBars[i].coordinates,
              );

        finalizedBars.add(
          newBars[i].copyWith(
            order: i + 1,
            distanceFromPrevious: legDist,
          ),
        );
      }

      return currentRoute.copyWith(
        bars: finalizedBars,
        totalDistanceMeters: osrmResult.distanceMeters,
        totalDurationSeconds: osrmResult.durationSeconds,
        polyline: osrmResult.polyline,
        rejectedBarIds: updatedRejectedIds,
      );
    } catch (_) {
      // Fallback
      double totalDist = 0.0;
      final finalizedBars = <Bar>[];
      final polyline = <LatLng>[currentRoute.origin];
      LatLng prev = currentRoute.origin;

      for (int i = 0; i < newBars.length; i++) {
        final dist = HaversineCalculator.distanceMeters(prev, newBars[i].coordinates) * 1.28;
        totalDist += dist;
        finalizedBars.add(
          newBars[i].copyWith(
            order: i + 1,
            distanceFromPrevious: dist,
          ),
        );
        polyline.add(newBars[i].coordinates);
        prev = newBars[i].coordinates;
      }

      return currentRoute.copyWith(
        bars: finalizedBars,
        totalDistanceMeters: totalDist,
        totalDurationSeconds: totalDist / 1.25,
        polyline: polyline,
        rejectedBarIds: updatedRejectedIds,
      );
    }
  }
}
