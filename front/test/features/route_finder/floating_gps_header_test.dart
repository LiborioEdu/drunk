import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drunk_front/features/route_finder/presentation/controllers/route_finder_state.dart';
import 'package:drunk_front/features/route_finder/presentation/widgets/floating_gps_header.dart';

void main() {
  group('FloatingGpsHeader com Menu Hambúrguer', () {
    testWidgets('Exibe cabeçalho compacto inicialmente e abre opções no menu hambúrguer',
        (WidgetTester tester) async {
      bool manualModeToggled = false;
      bool registerModeToggled = false;
      bool cityBarsOpened = false;
      bool locationEdited = false;
      bool refreshed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                FloatingGpsHeader(
                  gpsStatus: GpsStatus.active,
                  gpsAccuracyMeters: 8.0,
                  locationAddress: 'Rua São Leonardo • Uruguai',
                  targetDistanceKm: 10.0,
                  targetBarsCount: 10,
                  cityBarsCount: 20,
                  onEditLocation: () => locationEdited = true,
                  onToggleManualRouteMode: () => manualModeToggled = true,
                  onToggleRegisterBarMode: () => registerModeToggled = true,
                  onOpenCityBarsManager: () => cityBarsOpened = true,
                  onRefresh: () => refreshed = true,
                ),
              ],
            ),
          ),
        ),
      );

      // No estado fechado, exibe DRUNK // 10K e o botão hambúrguer
      expect(find.text('DRUNK // 10K'), findsOneWidget);
      expect(find.text('10 BARES'), findsOneWidget);
      expect(find.text('Rua São Leonardo • Uruguai'), findsOneWidget);
      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);

      // As opções do menu não devem estar visíveis ainda
      expect(find.text('OPÇÕES & FERRAMENTAS DO MAPA'), findsNothing);

      // Toca no botão hambúrguer
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();

      // Agora o menu deve estar aberto com o cabeçalho e todas as ferramentas
      expect(find.text('OPÇÕES & FERRAMENTAS DO MAPA'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.text('PONTO DE PARTIDA'), findsOneWidget);
      expect(find.text('TRAÇADO DE ROTA'), findsOneWidget);
      expect(find.text('BANCO DE DADOS'), findsOneWidget);
      expect(find.text('ESTABELECIMENTOS'), findsOneWidget);
      expect(find.text('GEOLOCALIZAÇÃO'), findsOneWidget);

      // Toca em "Banco de Bares da Cidade"
      await tester.tap(find.text('Banco de Bares da Cidade'));
      await tester.pumpAndSettle();
      expect(cityBarsOpened, isTrue);

      // Reabre o menu
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();
      expect(find.text('OPÇÕES & FERRAMENTAS DO MAPA'), findsOneWidget);

      // Toca em "Montar Rota Manualmente no Mapa"
      await tester.tap(find.text('Montar Rota Manualmente no Mapa'));
      await tester.pumpAndSettle();
      expect(manualModeToggled, isTrue);

      // Reabre o menu e testa Cadastrar Bar
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+ Cadastrar Bar Clicando no Mapa'));
      await tester.pumpAndSettle();
      expect(registerModeToggled, isTrue);

      // Reabre o menu e testa Alterar Ponto de Partida
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ALTERAR'));
      await tester.pumpAndSettle();
      expect(locationEdited, isTrue);

      // Reabre o menu e testa Centralizar GPS
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CENTRALIZAR'));
      await tester.pumpAndSettle();
      expect(refreshed, isTrue);
    });

    testWidgets('Exibe banner ativo do Modo Manual quando isManualRouteMode é true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                FloatingGpsHeader(
                  gpsStatus: GpsStatus.active,
                  locationAddress: 'Rua São Leonardo',
                  isManualRouteMode: true,
                  manualStopsCount: 3,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.textContaining('MODO MANUAL (3 paradas)'), findsOneWidget);
      expect(find.text('DESFAZER ↶'), findsNothing); // sem callback onUndoManualStop
      expect(find.text('PRONTO'), findsOneWidget);
    });
  });
}
