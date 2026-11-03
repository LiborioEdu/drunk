import 'package:latlong2/latlong.dart';
import 'bar.dart';

/// Entidade que encapsula a rota completa gerada com meta customizável de KM e bares
class DrunkRoute {
  final LatLng origin;
  final List<Bar> bars;
  final double totalDistanceMeters;
  final double totalDurationSeconds;
  final List<LatLng> polyline;
  final List<Bar> candidatePool;
  final Set<String> rejectedBarIds;
  final double targetDistanceMeters;
  final int targetBarsCount;

  const DrunkRoute({
    required this.origin,
    required this.bars,
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    required this.polyline,
    this.candidatePool = const [],
    this.rejectedBarIds = const {},
    this.targetDistanceMeters = 10000.0,
    int? targetBarsCount,
  }) : targetBarsCount = targetBarsCount ?? bars.length;

  /// Meta planejada em quilômetros (ex: 5.0 ou 10.0)
  double get targetDistanceKm => targetDistanceMeters / 1000.0;

  /// Total em quilômetros formatado (ex: "10.2 km")
  String get totalDistanceKmFormatted {
    final km = totalDistanceMeters / 1000.0;
    return '${km.toStringAsFixed(1)} km';
  }

  /// Tempo estimado de caminhada formatado (ex: "1h 55m" ou "48 min")
  String get estimatedDurationFormatted {
    final totalMinutes = (totalDurationSeconds / 60.0).round();
    if (totalMinutes < 60) {
      return '$totalMinutes min';
    }
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }

  /// Total de bares na rota
  int get totalBars => bars.length;

  /// Quantidade de bares extras disponíveis no pool para Swap
  int get availableSwapsCount {
    final selectedIds = bars.map((b) => b.id).toSet();
    return candidatePool
        .where((b) =>
            !selectedIds.contains(b.id) && !rejectedBarIds.contains(b.id))
        .length;
  }

  /// Retorna cópia com modificações
  DrunkRoute copyWith({
    LatLng? origin,
    List<Bar>? bars,
    double? totalDistanceMeters,
    double? totalDurationSeconds,
    List<LatLng>? polyline,
    List<Bar>? candidatePool,
    Set<String>? rejectedBarIds,
    double? targetDistanceMeters,
    int? targetBarsCount,
  }) {
    return DrunkRoute(
      origin: origin ?? this.origin,
      bars: bars ?? this.bars,
      totalDistanceMeters: totalDistanceMeters ?? this.totalDistanceMeters,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      polyline: polyline ?? this.polyline,
      candidatePool: candidatePool ?? this.candidatePool,
      rejectedBarIds: rejectedBarIds ?? this.rejectedBarIds,
      targetDistanceMeters: targetDistanceMeters ?? this.targetDistanceMeters,
      targetBarsCount: targetBarsCount ?? this.targetBarsCount,
    );
  }

  /// Serialização para persistência no SQLite ou sincronização com API/Firebase
  Map<String, dynamic> toJson() {
    return {
      'origin': {
        'latitude': origin.latitude,
        'longitude': origin.longitude,
      },
      'totalDistanceMeters': totalDistanceMeters,
      'totalDurationSeconds': totalDurationSeconds,
      'targetDistanceMeters': targetDistanceMeters,
      'targetBarsCount': targetBarsCount,
      'bars': bars.map((b) => b.toJson()).toList(),
      'polyline': polyline
          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList(),
    };
  }

  /// Desserialização a partir do armazenamento local ou API
  factory DrunkRoute.fromJson(Map<String, dynamic> map) {
    final originMap = map['origin'] as Map<String, dynamic>;
    final origin = LatLng(
      (originMap['latitude'] as num).toDouble(),
      (originMap['longitude'] as num).toDouble(),
    );

    final bars = (map['bars'] as List<dynamic>? ?? const [])
        .map((item) => Bar.fromJson(item as Map<String, dynamic>))
        .toList();

    final polyline = (map['polyline'] as List<dynamic>? ?? const []).map((p) {
      final pt = p as Map<String, dynamic>;
      final lat = (pt['lat'] ?? pt['latitude']) as num;
      final lng = (pt['lng'] ?? pt['longitude']) as num;
      return LatLng(lat.toDouble(), lng.toDouble());
    }).toList();

    return DrunkRoute(
      origin: origin,
      bars: bars,
      totalDistanceMeters:
          (map['totalDistanceMeters'] as num?)?.toDouble() ?? 0.0,
      totalDurationSeconds:
          (map['totalDurationSeconds'] as num?)?.toDouble() ?? 0.0,
      targetDistanceMeters:
          (map['targetDistanceMeters'] as num?)?.toDouble() ?? 10000.0,
      targetBarsCount: (map['targetBarsCount'] as num?)?.toInt() ?? bars.length,
      polyline: polyline,
    );
  }
}
