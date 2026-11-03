import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/race_hud/domain/entities/race_session.dart';
import '../../features/route_finder/domain/entities/drunk_route.dart';

/// Serviço de persistência offline no dispositivo (Custo Zero, compatível com Android, Linux e Web)
class LocalStorageService {
  static const String _registeredRouteKey = 'drunk_registered_route_v1';
  static const String _registeredRouteOriginLabelKey =
      'drunk_registered_route_origin_label_v1';
  static const String _activeSessionKey = 'drunk_active_session_v1';
  static const String _completedSessionsKey = 'drunk_completed_sessions_v1';
  static const String _drunkCoinsKey = 'drunk_coins_balance_v1';

  /// Salva a rota registrada pelo organizador/corredor para ser seguida posteriormente
  Future<void> saveRegisteredRoute(
    DrunkRoute route, {
    String? originLabel,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_registeredRouteKey, jsonEncode(route.toJson()));
      if (originLabel != null && originLabel.trim().isNotEmpty) {
        await prefs.setString(
          _registeredRouteOriginLabelKey,
          originLabel.trim(),
        );
      }
    } catch (_) {}
  }

  /// Carrega a rota registrada salva anteriormente no dispositivo
  Future<DrunkRoute?> loadRegisteredRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_registeredRouteKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return DrunkRoute.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Carrega o rótulo de endereço de partida da rota registrada
  Future<String?> loadRegisteredRouteOriginLabel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_registeredRouteOriginLabelKey);
    } catch (_) {
      return null;
    }
  }

  /// Remove a rota registrada salva
  Future<void> clearRegisteredRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_registeredRouteKey);
      await prefs.remove(_registeredRouteOriginLabelKey);
    } catch (_) {}
  }

  /// Salva o estado atual da corrida para resiliência contra bloqueio de tela ou fechamento
  Future<void> saveActiveSession(RaceSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeSessionKey, jsonEncode(session.toJson()));
    } catch (_) {}
  }

  /// Recupera uma sessão em andamento caso exista
  Future<RaceSession?> loadActiveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_activeSessionKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return RaceSession.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Remove a sessão ativa (após finalizar ou abandonar a corrida)
  Future<void> clearActiveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeSessionKey);
    } catch (_) {}
  }

  /// Arquiva uma sessão concluída no histórico local e credita DrunkCoins
  Future<void> archiveCompletedSession(RaceSession completedSession) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = await loadCompletedSessions();

      // Evita duplicidade caso a mesma sessão já tenha sido arquivada
      final filtered = history
          .where((s) => s.sessionId != completedSession.sessionId)
          .toList();
      filtered.insert(0, completedSession);

      // Mantém até 30 corridas recentes no histórico local
      final trimmed = filtered.take(30).map((s) => s.toJson()).toList();
      await prefs.setString(_completedSessionsKey, jsonEncode(trimmed));

      final currentCoins = prefs.getInt(_drunkCoinsKey) ?? 0;
      await prefs.setInt(
        _drunkCoinsKey,
        currentCoins + completedSession.earnedDrunkCoins,
      );
      await prefs.remove(_activeSessionKey);
    } catch (_) {}
  }

  /// Retorna a lista de maratonas concluídas salvas no aparelho
  Future<List<RaceSession>> loadCompletedSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_completedSessionsKey);
      if (raw == null || raw.isEmpty) return const [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => RaceSession.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Saldo acumulado de DrunkCoins do corredor
  Future<int> getDrunkCoinsBalance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_drunkCoinsKey) ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
