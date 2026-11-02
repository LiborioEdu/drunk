/// Exceção base padronizada para toda a aplicação DRUNK
class AppException implements Exception {
  final String message;
  final String? code;
  final Object? originalError;

  const AppException(
    this.message, {
    this.code,
    this.originalError,
  });

  @override
  String toString() => message;
}

/// Exceção específica para falhas de comunicação com APIs externas
class NetworkException extends AppException {
  final int? statusCode;

  const NetworkException(
    super.message, {
    this.statusCode,
    super.code,
    super.originalError,
  });
}

/// Exceção de domínio durante a geração ou troca de bares na rota
class RouteGenerationException extends AppException {
  const RouteGenerationException(
    super.message, {
    super.code,
    super.originalError,
  });
}
