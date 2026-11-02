import 'package:flutter/material.dart';

/// Categorias de consumo registradas na comanda financeira de cada parada
enum DrinkCategory {
  chopp(
    code: 'CHOPP',
    label: 'Chopp / Cerveja',
    subtitle: 'PILSEN • IPA • LAGER',
    icon: Icons.sports_bar_rounded,
  ),
  drink(
    code: 'DRINK',
    label: 'Drink / Dose',
    subtitle: 'GIN • VODKA • DOSE',
    icon: Icons.local_bar_rounded,
  ),
  water(
    code: 'WATER',
    label: 'Água / Isotônico',
    subtitle: 'GATE HIDRATAÇÃO',
    icon: Icons.water_drop_rounded,
  ),
  snack(
    code: 'SNACK',
    label: 'Petisco / Comida',
    subtitle: 'PORÇÃO RÁPIDA',
    icon: Icons.fastfood_rounded,
  );

  final String code;
  final String label;
  final String subtitle;
  final IconData icon;

  const DrinkCategory({
    required this.code,
    required this.label,
    required this.subtitle,
    required this.icon,
  });

  static DrinkCategory fromCode(String? code) {
    for (final cat in DrinkCategory.values) {
      if (cat.code == code) return cat;
    }
    return DrinkCategory.chopp;
  }
}

/// Registro individual de check-in validado (<= 20m) e gasto na comanda de um bar
class BarCheckinRecord {
  final int barOrder;
  final String barId;
  final String barName;
  final double spentBrl;
  final DrinkCategory category;
  final double distanceAtCheckinMeters;
  final DateTime checkedInAt;
  final String? notes;

  const BarCheckinRecord({
    required this.barOrder,
    required this.barId,
    required this.barName,
    required this.spentBrl,
    required this.category,
    required this.distanceAtCheckinMeters,
    required this.checkedInAt,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'barOrder': barOrder,
      'barId': barId,
      'barName': barName,
      'spentBrl': spentBrl,
      'category': category.code,
      'distanceAtCheckinMeters': distanceAtCheckinMeters,
      'checkedInAt': checkedInAt.toIso8601String(),
      'notes': notes,
    };
  }

  factory BarCheckinRecord.fromJson(Map<String, dynamic> map) {
    return BarCheckinRecord(
      barOrder: (map['barOrder'] as num).toInt(),
      barId: map['barId']?.toString() ?? '',
      barName: map['barName']?.toString() ?? 'Bar',
      spentBrl: (map['spentBrl'] as num?)?.toDouble() ?? 0.0,
      category: DrinkCategory.fromCode(map['category'] as String?),
      distanceAtCheckinMeters:
          (map['distanceAtCheckinMeters'] as num?)?.toDouble() ?? 0.0,
      checkedInAt: DateTime.tryParse(map['checkedInAt']?.toString() ?? '') ??
          DateTime.now(),
      notes: map['notes'] as String?,
    );
  }
}
