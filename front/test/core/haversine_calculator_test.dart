import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:drunk_front/core/utils/haversine_calculator.dart';

void main() {
  group('HaversineCalculator', () {
    test('Calcula distância aproximada com precisão', () {
      // Ponto A: MASP (Av. Paulista) (-23.5614, -46.6560)
      // Ponto B: Parque Ibirapuera (-23.5874, -46.6576)
      // Distância ~ 2.9 km
      const masp = LatLng(-23.5614, -46.6560);
      const ibira = LatLng(-23.5874, -46.6576);

      final distance = HaversineCalculator.distanceMeters(masp, ibira);

      expect(distance, greaterThan(2800));
      expect(distance, lessThan(3100));
    });

    test('Azimute e diferença angular funcionam corretamente', () {
      const p1 = LatLng(0, 0);
      const pNorth = LatLng(1, 0);
      const pSouth = LatLng(-1, 0);

      final bearingNorth = HaversineCalculator.bearingDegrees(p1, pNorth);
      final bearingSouth = HaversineCalculator.bearingDegrees(p1, pSouth);

      expect(bearingNorth, closeTo(0, 0.1));
      expect(bearingSouth, closeTo(180, 0.1));

      final angleDiff = HaversineCalculator.angleDifference(bearingNorth, bearingSouth);
      expect(angleDiff, closeTo(180, 0.1));
    });

    test('Formata distâncias legíveis para o usuário', () {
      expect(HaversineCalculator.formatDistance(350), '350 m');
      expect(HaversineCalculator.formatDistance(999), '999 m');
      expect(HaversineCalculator.formatDistance(1000), '1.0 km');
      expect(HaversineCalculator.formatDistance(10240), '10.2 km');
    });
  });
}
