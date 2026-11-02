import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../domain/entities/bar.dart';
import '../../domain/entities/drunk_route.dart';

/// Datasource de integração com o Backend Python FastAPI (DRUNK API)
class DrunkApiDatasource {
  final http.Client _client;
  final String baseUrl;

  DrunkApiDatasource({
    http.Client? client,
    this.baseUrl = ApiEndpoints.backendBaseUrl,
  }) : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      };

  /// Registra/Sincroniza a rota no Backend FastAPI e opcionalmente cria uma sala de Lobby (ex: DRK-492)
  Future<Map<String, dynamic>> syncRouteAndCreateLobby({
    required DrunkRoute route,
    required String hostNickname,
  }) async {
    // 1. Cria/Autentica o usuário Host
    final authResp = await _client
        .post(
          Uri.parse('$baseUrl/users/auth'),
          headers: _headers,
          body: jsonEncode({'nickname': hostNickname}),
        )
        .timeout(const Duration(seconds: 6));

    if (authResp.statusCode != 200) {
      throw Exception('Falha ao autenticar usuário na API.');
    }
    final userData =
        jsonDecode(utf8.decode(authResp.bodyBytes)) as Map<String, dynamic>;
    final userId = userData['id'] as String;

    // 2. Registra a sessão de rota na API enviando os bares já validados
    final genResp = await _client
        .post(
          Uri.parse('$baseUrl/routes/generate'),
          headers: _headers,
          body: jsonEncode({
            'origin': {
              'latitude': route.origin.latitude,
              'longitude': route.origin.longitude,
            },
            'radius_km': 3.5,
            'target_bars': route.bars.length,
            'host_user_id': userId,
            'candidate_pool_override':
                route.bars.map((b) => b.toJson()).toList(),
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (genResp.statusCode != 200) {
      throw Exception('Falha ao salvar rota no Backend FastAPI.');
    }
    final sessionData =
        jsonDecode(utf8.decode(genResp.bodyBytes)) as Map<String, dynamic>;
    final sessionId = sessionData['session_id'] as String;

    // 3. Cria a sala de Lobby (DRK-XXX)
    final lobbyResp = await _client
        .post(
          Uri.parse('$baseUrl/lobbies'),
          headers: _headers,
          body: jsonEncode({
            'session_id': sessionId,
            'host_user_id': userId,
            'host_nickname': hostNickname,
          }),
        )
        .timeout(const Duration(seconds: 6));

    if (lobbyResp.statusCode != 200) {
      throw Exception('Falha ao criar Lobby na API.');
    }

    return jsonDecode(utf8.decode(lobbyResp.bodyBytes))
        as Map<String, dynamic>;
  }

  /// Converte a resposta do endpoint `/api/v1/routes/generate` em `DrunkRoute`
  DrunkRoute parseBackendRoute(Map<String, dynamic> data) {
    final originMap = data['origin'] as Map<String, dynamic>;
    final origin = LatLng(
      (originMap['latitude'] as num).toDouble(),
      (originMap['longitude'] as num).toDouble(),
    );

    final barsList = (data['bars'] as List<dynamic>)
        .map((b) => Bar.fromJson(b as Map<String, dynamic>))
        .toList();

    final polyList = (data['polyline'] as List<dynamic>).map((p) {
      final map = p as Map<String, dynamic>;
      return LatLng(
        (map['latitude'] as num).toDouble(),
        (map['longitude'] as num).toDouble(),
      );
    }).toList();

    return DrunkRoute(
      origin: origin,
      bars: barsList,
      totalDistanceMeters: (data['totalDistanceMeters'] as num).toDouble(),
      totalDurationSeconds: (data['totalDurationSeconds'] as num).toDouble(),
      polyline: polyList,
    );
  }
}
