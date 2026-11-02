import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../constants/api_endpoints.dart';
import '../errors/app_exception.dart';

/// Cliente HTTP centralizado com proteção anti-CORS Preflight no Flutter Web, UTF-8 e tratamento de erros
class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  /// No Flutter Web (`kIsWeb`), enviar `'User-Agent'` customizado dispara um CORS Preflight (`OPTIONS`)
  /// que servidores públicos (Overpass, Nominatim, Photon, OSRM) bloqueiam. No navegador, o próprio
  /// browser envia `User-Agent` e `Referer` nativamente como Simple Request.
  Map<String, String> get _defaultGetHeaders => {
        if (!kIsWeb) 'User-Agent': ApiEndpoints.userAgentPackage,
        'Accept': 'application/json',
      };

  /// Executa um HTTP GET retornando o JSON decodificado (Map ou List) em UTF-8
  Future<dynamic> getJsonDynamic(
    Uri uri, {
    Duration timeout = const Duration(seconds: 12),
    Map<String, String>? headers,
  }) async {
    try {
      final mergedHeaders = <String, String>{
        ..._defaultGetHeaders,
        if (!kIsWeb && headers != null) ...headers,
      };

      final response = await _client
          .get(
            uri,
            headers: mergedHeaders,
          )
          .timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }

      throw NetworkException(
        'Servidor retornou HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw NetworkException(
        'Falha de conexão com ${uri.host}',
        originalError: e,
      );
    }
  }

  /// Executa um HTTP GET retornando um Map JSON decodificado em UTF-8
  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    Duration timeout = const Duration(seconds: 12),
    Map<String, String>? headers,
  }) async {
    final decoded = await getJsonDynamic(
      uri,
      timeout: timeout,
      headers: headers,
    );
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const NetworkException('Formato de resposta JSON inesperado.');
  }

  /// Executa um HTTP POST com formulário URL-encoded mantendo CORS Simple Request na Web
  Future<Map<String, dynamic>> postFormJson(
    Uri uri, {
    required Map<String, String> body,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    try {
      final postHeaders = <String, String>{
        if (!kIsWeb) 'User-Agent': ApiEndpoints.userAgentPackage,
        if (!kIsWeb) 'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      };

      final response = await _client
          .post(
            uri,
            headers: postHeaders,
            body: body,
          )
          .timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        throw const NetworkException('Formato de resposta JSON inesperado.');
      }

      throw NetworkException(
        'Servidor retornou HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw NetworkException(
        'Falha ao consultar ${uri.host}',
        originalError: e,
      );
    }
  }
}
