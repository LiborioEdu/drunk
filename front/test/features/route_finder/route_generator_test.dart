import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:drunk_front/features/route_finder/domain/entities/bar.dart';
import 'package:drunk_front/features/route_finder/domain/services/route_generator_service.dart';
import 'package:drunk_front/features/route_finder/domain/services/bar_swap_service.dart';
import 'package:drunk_front/features/route_finder/presentation/widgets/route_bottom_sheet.dart';

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
        targetDistanceKm: 10.0,
      );

      expect(route.bars.length, 10);
      expect(route.bars.first.order, 1);
      expect(route.bars.last.order, 10);
      expect(route.targetDistanceKm, 10.0);
      expect(route.totalDistanceMeters, greaterThan(5000));
      expect(route.polyline.length, greaterThanOrEqualTo(10));
    });

    test('Respeita quantidade customizada de bares e meta de KM escolhida pelo usuário', () async {
      const origin = LatLng(-5.0689, -42.7830);

      final pool = List.generate(20, (index) {
        final step = (index + 1) * 0.0035;
        return Bar(
          id: 'the_bar_$index',
          name: 'Bar Teresina $index',
          latitude: origin.latitude - step,
          longitude: origin.longitude + (index.isEven ? 0.0015 : -0.0015),
        );
      });

      final shortRoute = await routeService.generateRoute(
        origin: origin,
        candidatePool: pool,
        targetBars: 4,
        targetDistanceKm: 3.0,
      );

      expect(shortRoute.bars.length, 4);
      expect(shortRoute.targetBarsCount, 4);
      expect(shortRoute.targetDistanceKm, 3.0);
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

    testWidgets('RouteBottomSheet permite escolher KM, número de bares e minimizar arrastando para baixo', (tester) async {
      double selectedKm = 10.0;
      int selectedBars = 10;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                StatefulBuilder(
                  builder: (context, setState) {
                    return RouteBottomSheet(
                      targetDistanceKm: selectedKm,
                      onTargetDistanceChanged: (km) =>
                          setState(() => selectedKm = km),
                      targetBarsCount: selectedBars,
                      onTargetBarsChanged: (bars) =>
                          setState(() => selectedBars = bars),
                      searchRadiusKm: 3.5,
                      onRadiusChanged: (_) {},
                      isGenerating: false,
                      onGeneratePressed: () {},
                      cityBarsCount: 20,
                      onSwapBar: (_) {},
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );

      // Verifica exibição dos seletores de Distância e Bares
      expect(find.text('DISTÂNCIA DO PERCURSO'), findsOneWidget);
      expect(find.text('QUANTIDADE DE BARES'), findsOneWidget);

      // Seleciona chip rápido de 5 KM e 5 BARES
      await tester.tap(find.text('5 KM'));
      await tester.pumpAndSettle();
      expect(selectedKm, 5.0);

      await tester.tap(find.text('5 BARES'));
      await tester.pumpAndSettle();
      expect(selectedBars, 5);

      // Minimiza arrastando o cabeçalho para baixo ou tocando em MINIMIZAR
      await tester.drag(find.text('MINIMIZAR'), const Offset(0, 320));
      await tester.pumpAndSettle();

      // Verifica que entrou no modo dock minimizado exibindo o resumo compacto
      expect(find.text('META: 5 KM • 5 BARES'), findsOneWidget);
    });
  });
}
