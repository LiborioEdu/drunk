import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drunk_front/main.dart';
import 'package:drunk_front/features/route_finder/presentation/screens/route_finder_screen.dart';

void main() {
  testWidgets('DrunkApp monta com ProviderScope e exibe RouteFinderScreen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: DrunkApp(),
      ),
    );

    expect(find.byType(RouteFinderScreen), findsOneWidget);
  });
}
