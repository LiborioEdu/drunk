import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drunk_front/features/race_log/domain/entities/bar_log_entry.dart';
import 'package:drunk_front/features/race_log/presentation/controllers/race_log_controller.dart';

void main() {
  group('Aba ANOTAR — gasto e tempo por bar', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('Formata moeda, tempo e interpreta valores digitados', () {
      expect(RaceLogFormat.brl(25), 'R\$ 25,00');
      expect(RaceLogFormat.brl(1234.5), 'R\$ 1.234,50');
      expect(RaceLogFormat.runTime(754), '12:34');
      expect(RaceLogFormat.runTime(4510), '1:15:10');
      expect(RaceLogFormat.parseBrl('25,5'), 25.5);
      expect(RaceLogFormat.parseBrl('1.234,50'), 1234.5);
      expect(RaceLogFormat.parseBrl('18.90'), 18.9);
      expect(RaceLogFormat.parseBrl(''), isNull);
    });

    test('Salva, soma e persiste anotações por rota', () async {
      final routeKey = RaceLogNotifier.routeKeyFor(['a', 'b', 'c']);
      final notifier = RaceLogNotifier();
      await notifier.syncRoute(routeKey);

      await notifier.saveEntry(barId: 'a', spentBrl: 30, runSeconds: 600);
      await notifier.saveEntry(barId: 'b', spentBrl: 22.5, runSeconds: 480);
      expect(notifier.state.totalSpentBrl, 52.5);
      expect(notifier.state.totalRunSeconds, 1080);

      // Recarrega em um novo controlador -> anotações persistidas
      final reloaded = RaceLogNotifier();
      await reloaded.syncRoute(routeKey);
      expect(reloaded.state.entries.keys, containsAll(['a', 'b']));

      await reloaded.removeEntry('a');
      expect(reloaded.state.entries.containsKey('a'), isFalse);

      // Rota diferente começa com anotações vazias
      final other = RaceLogNotifier();
      await other.syncRoute(RaceLogNotifier.routeKeyFor(['x', 'y']));
      expect(other.state.entries, isEmpty);
    });
  });
}
