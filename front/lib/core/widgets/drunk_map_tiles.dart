import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../constants/api_endpoints.dart';

/// Estilos visuais disponíveis para o mapa sem exigir chave de API
enum DrunkMapStyle {
  /// OpenStreetMap Oficial (Zoom 19, todos os nomes de ruas e comércios) com matriz Cyberpunk Dark
  osmCyberDark,

  /// Esri ArcGIS World Dark Gray Canvas + camada de nomes de ruas (nativo escuro, sem chave)
  arcgisDark,

  /// OpenStreetMap Oficial claro original (útil em ambientes externos diurnos)
  osmLight,
}

extension DrunkMapStyleLabel on DrunkMapStyle {
  String get shortLabel {
    switch (this) {
      case DrunkMapStyle.osmCyberDark:
        return 'OSM Dark Neon';
      case DrunkMapStyle.arcgisDark:
        return 'ArcGIS Dark';
      case DrunkMapStyle.osmLight:
        return 'OSM Claro';
    }
  }

  DrunkMapStyle get nextStyle {
    switch (this) {
      case DrunkMapStyle.osmCyberDark:
        return DrunkMapStyle.arcgisDark;
      case DrunkMapStyle.arcgisDark:
        return DrunkMapStyle.osmLight;
      case DrunkMapStyle.osmLight:
        return DrunkMapStyle.osmCyberDark;
    }
  }
}

/// Camada de tiles reutilizável 100% gratuita e livre de marca d'água "API KEY REQUIRED"
class DrunkMapTileLayer extends StatelessWidget {
  final DrunkMapStyle style;

  const DrunkMapTileLayer({
    super.key,
    this.style = DrunkMapStyle.osmCyberDark,
  });

  /// Matriz linear calibrada (78% inversão de luminância + 28% preservação de matiz + lift #0E0F15):
  /// - Ruas e quadras em tons grafite/obsidiana (#0E0F15 / #1B1B20)
  /// - Nomes de ruas nítidos em prata claro (#AEAFB5)
  /// - Rios/mar permanecem azul-noturno (#2D3A43) e parques verde-escuro
  static const ColorFilter _cyberpunkDarkFilter = ColorFilter.matrix(<double>[
    0.0546, -0.7581, -0.0765, 0, 212.9,
    -0.2254, -0.4781, -0.0765, 0, 213.9,
    -0.2254, -0.7581, 0.2035, 0, 219.9,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    // Se o usuário forneceu voluntariamente uma CARTO_API_KEY via --dart-define e está no modo Dark padrão
    if (style == DrunkMapStyle.osmCyberDark &&
        ApiEndpoints.cartoApiKey.isNotEmpty) {
      return TileLayer(
        urlTemplate: ApiEndpoints.cartoDbDarkMatter,
        subdomains: ApiEndpoints.cartoDbSubdomains,
        userAgentPackageName: ApiEndpoints.userAgentPackage,
        tileProvider: NetworkTileProvider(),
        maxZoom: 19,
      );
    }

    switch (style) {
      case DrunkMapStyle.osmCyberDark:
        return ColorFiltered(
          colorFilter: _cyberpunkDarkFilter,
          child: TileLayer(
            urlTemplate: ApiEndpoints.osmStandardTile,
            userAgentPackageName: ApiEndpoints.userAgentPackage,
            tileProvider: NetworkTileProvider(),
            maxZoom: 19,
          ),
        );

      case DrunkMapStyle.arcgisDark:
        return Stack(
          children: [
            TileLayer(
              urlTemplate: ApiEndpoints.arcgisDarkGrayBase,
              userAgentPackageName: ApiEndpoints.userAgentPackage,
              tileProvider: NetworkTileProvider(),
              maxNativeZoom: 16,
              maxZoom: 19,
            ),
            TileLayer(
              urlTemplate: ApiEndpoints.arcgisDarkGrayReference,
              userAgentPackageName: ApiEndpoints.userAgentPackage,
              tileProvider: NetworkTileProvider(),
              maxNativeZoom: 16,
              maxZoom: 19,
            ),
          ],
        );

      case DrunkMapStyle.osmLight:
        return TileLayer(
          urlTemplate: ApiEndpoints.osmStandardTile,
          userAgentPackageName: ApiEndpoints.userAgentPackage,
          tileProvider: NetworkTileProvider(),
          maxZoom: 19,
        );
    }
  }
}
