import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/bar_log_entry.dart';

/// Estado das anotações vinculadas à rota registrada atual
class RaceLogState {
  final String? routeKey;
  final Map<String, BarLogEntry> entries;
  final bool isLoaded;

  const RaceLogState({
    this.routeKey,
    this.entries = const {},
    this.isLoaded = false,
  });

  double get totalSpentBrl =>
      entries.values.fold(0.0, (sum, e) => sum + e.spentBrl);

  int get totalRunSeconds =>
      entries.values.fold(0, (sum, e) => sum + e.runSeconds);
}

/// Controla as anotações (gasto + tempo) por bar e persiste no aparelho
class RaceLogNotifier extends StateNotifier<RaceLogState> {
  static const String _storageKey = 'drunk_race_log_v1';

  RaceLogNotifier() : super(const RaceLogState());

  /// Gera uma chave única para a rota a partir da sequência de bares
  static String routeKeyFor(Iterable<String> barIds) => barIds.join('|');

  /// Carrega as anotações salvas da rota [routeKey]; se a rota mudou, começa do zero
  Future<void> syncRoute(String routeKey) async {
    if (state.routeKey == routeKey && state.isLoaded) return;
    state = RaceLogState(routeKey: routeKey);

    final entries = <String, BarLogEntry>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        if (decoded['routeKey'] == routeKey) {
          final list = decoded['entries'] as List<dynamic>? ?? const [];
          for (final item in list) {
            final entry = BarLogEntry.fromJson(item as Map<String, dynamic>);
            entries[entry.barId] = entry;
          }
        }
      }
    } catch (_) {}

    if (!mounted || state.routeKey != routeKey) return;
    state = RaceLogState(routeKey: routeKey, entries: entries, isLoaded: true);
  }

  /// Salva (ou atualiza) a anotação de um bar
  Future<void> saveEntry({
    required String barId,
    required double spentBrl,
    required int runSeconds,
  }) async {
    final updated = Map<String, BarLogEntry>.from(state.entries)
      ..[barId] = BarLogEntry(
        barId: barId,
        spentBrl: spentBrl,
        runSeconds: runSeconds,
        updatedAt: DateTime.now(),
      );
    state = RaceLogState(
      routeKey: state.routeKey,
      entries: updated,
      isLoaded: true,
    );
    await _persist();
  }

  /// Remove a anotação de um bar
  Future<void> removeEntry(String barId) async {
    final updated = Map<String, BarLogEntry>.from(state.entries)
      ..remove(barId);
    state = RaceLogState(
      routeKey: state.routeKey,
      entries: updated,
      isLoaded: true,
    );
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode({
          'routeKey': state.routeKey,
          'entries': state.entries.values.map((e) => e.toJson()).toList(),
        }),
      );
    } catch (_) {}
  }
}

final raceLogProvider =
    StateNotifierProvider<RaceLogNotifier, RaceLogState>((ref) {
  return RaceLogNotifier();
});
