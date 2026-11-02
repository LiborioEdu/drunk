/// Endpoints públicos e configurações de rede (Stack Open Custo Zero + CORS-Safe)
class ApiEndpoints {
  ApiEndpoints._();

  /// URL base do Backend FastAPI local opcional (/home/eduardo/dev/drunk/api)
  static const String backendBaseUrl = 'http://localhost:8000/api/v1';

  /// Mirrors da Overpass API atualizados (2026) com suporte CORS para busca de bares/pubs
  static const String overpassPrivateCoffee =
      'https://overpass.private.coffee/api/interpreter';
  static const String overpassInterpreter =
      'https://overpass-api.de/api/interpreter';
  static const String overpassMailRu =
      'https://maps.mail.ru/osm/tools/overpass/api/interpreter';

  static const List<String> overpassMirrors = [
    overpassPrivateCoffee,
    overpassInterpreter,
    overpassMailRu,
  ];

  /// Mirrors OSRM públicos para cálculo de rotas a pé pelas ruas
  static const String osrmFootRouteBase =
      'https://router.project-osrm.org/route/v1/foot';
  static const String osrmFootDe =
      'https://routing.openstreetmap.de/routed-foot/route/v1/foot';

  static const List<String> osrmFootMirrors = [
    osrmFootRouteBase,
    osrmFootDe,
  ];

  /// Photon API (Komoot / OpenStreetMap) — Autocomplete e Reverse Geocoding rápidos com CORS
  static const String photonSearch = 'https://photon.komoot.io/api/';
  static const String photonReverse = 'https://photon.komoot.io/reverse';

  /// Nominatim OpenStreetMap — Geocodificação direta e reversa
  static const String nominatimReverse =
      'https://nominatim.openstreetmap.org/reverse';
  static const String nominatimSearch =
      'https://nominatim.openstreetmap.org/search';

  /// BigDataCloud Client API — Geolocalização por IP + Reverse Geocoding (HTTPS, sem chave, CORS liberado)
  static const String bigDataCloudReverseClient =
      'https://api-bdc.net/data/reverse-geocode-client';

  /// Fallbacks adicionais de Geolocalização por IP via HTTPS com CORS liberado
  static const String geoJsIpGeo = 'https://get.geojs.io/v1/ip/geo.json';
  static const String ipWhoIs = 'https://ipwho.is/';

  /// Provedor 1 (Padrão — 100% Gratuito, Sem API Key, Zoom 19 detalhado): OpenStreetMap Oficial
  static const String osmStandardTile =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Provedor 2 (Alternativo — 100% Gratuito, Sem API Key): Esri ArcGIS World Dark Gray Canvas + Rótulos
  static const String arcgisDarkGrayBase =
      'https://services.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}';
  static const String arcgisDarkGrayReference =
      'https://services.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Reference/MapServer/tile/{z}/{y}/{x}';

  /// Chave opcional da CARTO (`--dart-define=CARTO_API_KEY=...`), caso o usuário deseje usar CartoDB no futuro
  static const String cartoApiKey = String.fromEnvironment('CARTO_API_KEY');
  static String get cartoDbDarkMatter => cartoApiKey.isNotEmpty
      ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png?key=$cartoApiKey'
      : osmStandardTile;
  static const List<String> cartoDbSubdomains = ['a', 'b', 'c', 'd'];

  /// User-Agent exigido em sockets nativos (Android / iOS / Linux Desktop)
  static const String userAgentPackage = 'com.drunk.drunk_front/1.0.0';
}
