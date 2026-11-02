import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:drunk_front/features/route_finder/domain/entities/bar.dart';
import 'package:drunk_front/features/route_finder/domain/services/route_generator_service.dart';
import 'package:drunk_front/features/route_finder/domain/services/bar_swap_service.dart';

void main() {
  group('RouteGeneratorService & BarSwapService', () {
    late RouteGeneratorService routeService;
    late BarSwapService swapService;

    setUp(() {
      routeService = RouteGeneratorService();
      swapService = BarSwapService();
    });

    test('Gera rota encadeada de até 10 paradas com fallback gracioso', () async {
      const origin = LatLng(-23.5505, -46.6333);

      // Gera 25 bares candidatos espalhados em direção Sul/Leste
      final pool = List.generate(25, (index) {
        final step = (index + 1) * 0.007; // ~800m a cada passo
        return Bar(
          id: 'bar_$index',
          name: 'Bar Teste $index',
          latitude: origin.latitude - step,
          longitude: origin.longitude + (index % 2 == 0 ? 0.002 : -0.002),
        );
      });

      final route = await routeService.generateRoute(
        origin: origin,
        candidatePool: pool,
        targetBars: 10,
      );

      expect(route.bars.length, 10);
      expect(route.bars.first.order, 1);
      expect(route.bars.last.order, 10);
      expect(route.totalDistanceMeters, greaterThan(5000));
      expect(route.polyline.length, greaterThanOrEqualTo(10));
    });

    test('Substitui um bar com sucesso ao acionar o Swap', () async {
      const origin = LatLng(-23.5505, -46.6333);

      final pool = List.generate(15, (index) {
        final step = (index + 1) * 0.007;
        return Bar(
          id: 'bar_$index',
          name: 'Bar Teste $index',
          latitude: origin.latitude - step,
          longitude: origin.longitude,
        );
      });

      final initialRoute = await routeService.generateRoute(
        origin: origin,
        candidatePool: pool,
        targetBars: 5,
      );

      final bar4Original = initialRoute.bars[3];

      final swappedRoute = await swapService.swapBar(
        currentRoute: initialRoute,
        barIndex: 3,
      );

      // O bar no índice 3 foi substituído
      expect(swappedRoute.bars[3].id, isNot(bar4Original.id));
      expect(swappedRoute.rejectedBarIds.contains(bar4Original.id), isTrue);
      expect(swappedRoute.bars[3].order, 4);
    });
  });
}
