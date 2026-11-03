/// Anotação simples de uma parada: quanto foi gasto no bar e o tempo de corrida do trecho
class BarLogEntry {
  final String barId;
  final double spentBrl;
  final int runSeconds;
  final DateTime updatedAt;

  const BarLogEntry({
    required this.barId,
    required this.spentBrl,
    required this.runSeconds,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'barId': barId,
        'spentBrl': spentBrl,
        'runSeconds': runSeconds,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory BarLogEntry.fromJson(Map<String, dynamic> map) {
    return BarLogEntry(
      barId: map['barId'] as String,
      spentBrl: (map['spentBrl'] as num?)?.toDouble() ?? 0.0,
      runSeconds: (map['runSeconds'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// Formatadores enxutos usados na aba ANOTAR
class RaceLogFormat {
  RaceLogFormat._();

  /// 1234.5 -> "R$ 1.234,50"
  static String brl(double value) {
    final fixed = value.abs().toStringAsFixed(2);
    final parts = fixed.split('.');
    final intDigits = parts[0];
    final buffer = StringBuffer();
    for (int i = 0; i < intDigits.length; i++) {
      final remaining = intDigits.length - i;
      buffer.write(intDigits[i]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write('.');
    }
    return 'R\$ ${buffer.toString()},${parts[1]}';
  }

  /// 754 -> "12:34" | 4510 -> "1:15:10"
  static String runTime(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
    return '${m.toString().padLeft(2, '0')}:$ss';
  }

  /// Aceita "25", "25,5", "25.50", "1.234,50"
  static double? parseBrl(String raw) {
    var text = raw.trim().replaceAll('R\$', '').replaceAll(' ', '');
    if (text.isEmpty) return null;
    if (text.contains(',')) {
      text = text.replaceAll('.', '').replaceAll(',', '.');
    }
    return double.tryParse(text);
  }
}
