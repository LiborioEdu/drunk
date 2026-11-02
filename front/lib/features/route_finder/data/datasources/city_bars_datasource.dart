import 'dart:convert';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/utils/haversine_calculator.dart';
import '../../domain/entities/bar.dart';

/// Banco de Dados Próprio de Bares da Cidade:
/// Combina o catálogo embutido + `assets/data/city_bars_seed.json` (distribuído junto no Beta)
/// com os bares cadastrados/editados em tempo real pelo mapa (`SharedPreferences`).
class CityBarsDatasource {
  static const String seedAssetPath = 'assets/data/city_bars_seed.json';
  static const String _localBarsStorageKey = 'drunk_city_bars_catalog_v1';
  static const String _deletedIdsStorageKey = 'drunk_city_bars_deleted_ids_v1';

  /// Catálogo inicial oficial de 20 bares da região para funcionamento imediato mesmo com cache do navegador
  static const List<Bar> builtInSeedBars = [
    Bar(
      id: 'the_01_champions_restobar',
      name: 'The Champions Restobar',
      latitude: -5.0645,
      longitude: -42.7788,
      address: 'Zona Leste • Teresina, PI',
      amenity: 'bar',
    ),
    Bar(
      id: 'the_02_esquina_leste',
      name: 'Esquina Leste Bar e Espetaria',
      latitude: -5.0691,
      longitude: -42.7812,
      address: 'Zona Leste • Teresina, PI',
      amenity: 'espetinho',
    ),
    Bar(
      id: 'the_03_up_resto_pub',
      name: 'Up Resto Pub',
      latitude: -5.0621,
      longitude: -42.7765,
      address: 'Zona Leste • Teresina, PI',
      amenity: 'pub',
    ),
    Bar(
      id: 'the_04_varanda_boteco',
      name: 'Varanda Boteco',
      latitude: -5.0723,
      longitude: -42.7934,
      address: 'Fátima / Jóquei • Teresina, PI',
      amenity: 'bar',
    ),
    Bar(
      id: 'the_05_roots_rock_pub',
      name: 'Roots Rock Pub',
      latitude: -5.0711,
      longitude: -42.7915,
      address: 'Jóquei • Teresina, PI',
      amenity: 'pub',
    ),
    Bar(
      id: 'the_06_meduzza_bar',
      name: 'MEDUZZA - Bar and Cocktail',
      latitude: -5.0689,
      longitude: -42.7830,
      address: 'Zona Leste • Teresina, PI',
      amenity: 'bar',
    ),
    Bar(
      id: 'the_07_al_capone_pub',
      name: 'Al Capone Pub Rock and Blues',
      latitude: -5.0667,
      longitude: -42.7801,
      address: 'Zona Leste • Teresina, PI',
      amenity: 'pub',
    ),
    Bar(
      id: 'the_08_boteco_do_ze_original',
      name: 'Boteco do Zé Original',
      latitude: -5.0754,
      longitude: -42.7956,
      address: 'Fátima • Teresina, PI',
      amenity: 'bar',
    ),
    Bar(
      id: 'the_09_bruhaus_cervejaria',
      name: 'Bruhaus Cervejaria',
      latitude: -5.0678,
      longitude: -42.7822,
      address: 'Zona Leste • Teresina, PI',
      amenity: 'brewery',
    ),
    Bar(
      id: 'the_10_fabrica_manhana',
      name: 'Fábrica Manhana',
      latitude: -5.0650,
      longitude: -42.7790,
      address: 'Zona Leste • Teresina, PI',
      amenity: 'brewery',
    ),
    Bar(
      id: 'the_11_bierbrau_cervejas',
      name: 'Bierbrau Cervejas Especiais',
      latitude: -5.0700,
      longitude: -42.7850,
      address: 'Jóquei • Teresina, PI',
      amenity: 'brewery',
    ),
    Bar(
      id: 'the_12_espeto_beer',
      name: 'Espeto Beer',
      latitude: -5.0801,
      longitude: -42.7602,
      address: 'Uruguai / São Cristóvão • Teresina, PI',
      amenity: 'espetinho',
    ),
    Bar(
      id: 'the_13_clovis_rockbar',
      name: 'Clóvis RockBar',
      latitude: -5.0820,
      longitude: -42.7550,
      address: 'Uruguai • Teresina, PI',
      amenity: 'pub',
    ),
    Bar(
      id: 'the_14_chama',
      name: 'Chama',
      latitude: -5.0715,
      longitude: -42.7860,
      address: 'Jóquei • Teresina, PI',
      amenity: 'bar',
    ),
    Bar(
      id: 'the_15_sombra_do_cajueiro',
      name: 'Bar e Restaurante Sombra do Cajueiro',
      latitude: -5.0740,
      longitude: -42.7940,
      address: 'Fátima • Teresina, PI',
      amenity: 'bar',
    ),
    Bar(
      id: 'the_16_quintal_aroeira',
      name: 'Quintal Aroeira',
      latitude: -5.0730,
      longitude: -42.7920,
      address: 'Jóquei / Fátima • Teresina, PI',
      amenity: 'bar',
    ),
    Bar(
      id: 'the_17_seu_ze_restobar',
      name: 'Seu Zé Restobar',
      latitude: -5.0745,
      longitude: -42.7900,
      address: 'Jóquei • Teresina, PI',
      amenity: 'bar',
    ),
    Bar(
      id: 'the_18_flyer_bar',
      name: 'Flyer Bar',
      latitude: -5.0720,
      longitude: -42.7910,
      address: 'Jóquei • Teresina, PI',
      amenity: 'bar',
    ),
    Bar(
      id: 'the_19_iver_bar',
      name: 'Iver Bar',
      latitude: -5.0780,
      longitude: -42.7850,
      address: 'São Cristóvão • Teresina, PI',
      amenity: 'bar',
    ),
    Bar(
      id: 'the_20_resenha_bar_churrascaria',
      name: 'Resenha Bar e Churrascaria',
      latitude: -5.0725,
      longitude: -42.7915,
      address: 'Jóquei • Teresina, PI',
      amenity: 'espetinho',
    ),
  ];

  final AssetBundle _assetBundle;
  final bool includeSeedBars;

  CityBarsDatasource({
    AssetBundle? assetBundle,
    this.includeSeedBars = true,
  }) : _assetBundle = assetBundle ?? rootBundle;

  /// Carrega todos os bares oficiais cadastrados na cidade
  Future<List<Bar>> getAllCityBars() async {
    final deletedIds = await _loadDeletedIds();
    final mergedById = <String, Bar>{};

    if (includeSeedBars) {
      for (final bar in builtInSeedBars) {
        if (!deletedIds.contains(bar.id)) {
          mergedById[bar.id] = bar;
        }
      }

      final seedBars = await _loadSeedBars();
      for (final bar in seedBars) {
        if (!deletedIds.contains(bar.id)) {
          mergedById[bar.id] = bar;
        }
      }
    }

    // Bares salvos/editados localmente têm precedência sobre o seed inicial
    final localBars = await _loadLocalBars();
    for (final bar in localBars) {
      if (!deletedIds.contains(bar.id)) {
        mergedById[bar.id] = bar;
      }
    }

    return mergedById.values.toList();
  }

  /// Filtra os bares cadastrados dentro do raio [radiusMeters] ao redor de [center].
  /// Caso no raio curto selecionado haja menos de 10 bares, expande até 15 km na mesma cidade.
  Future<List<Bar>> getBarsAround({
    required LatLng center,
    required double radiusMeters,
  }) async {
    final allBars = await getAllCityBars();
    if (allBars.isEmpty) return const [];

    final withinRadius = allBars.where((bar) {
      final d = HaversineCalculator.distanceMeters(center, bar.coordinates);
      return d <= radiusMeters;
    }).toList();

    if (withinRadius.length >= 10) {
      return withinRadius;
    }

    // Garante pool completo da cidade (até 15 km) quando o raio curto tem menos de 10 paradas
    final maxCityRadius = radiusMeters < 15000 ? 15000.0 : radiusMeters;
    final withinCity = allBars.where((bar) {
      final d = HaversineCalculator.distanceMeters(center, bar.coordinates);
      return d <= maxCityRadius;
    }).toList();

    return withinCity.isNotEmpty ? withinCity : withinRadius;
  }

  /// Cadastra um novo bar ou atualiza um bar existente no banco local da cidade
  Future<List<Bar>> saveBar(Bar bar) async {
    final prefs = await SharedPreferences.getInstance();
    final localBars = await _loadLocalBars();
    final deletedIds = await _loadDeletedIds();

    deletedIds.remove(bar.id);
    final updatedLocal = [
      for (final existing in localBars)
        if (existing.id != bar.id) existing,
      bar,
    ];

    await prefs.setString(
      _localBarsStorageKey,
      jsonEncode(updatedLocal.map((b) => b.toCatalogJson()).toList()),
    );
    await prefs.setStringList(_deletedIdsStorageKey, deletedIds.toList());

    return getAllCityBars();
  }

  /// Remove um bar do banco da cidade
  Future<List<Bar>> deleteBar(String barId) async {
    final prefs = await SharedPreferences.getInstance();
    final localBars = await _loadLocalBars();
    final deletedIds = await _loadDeletedIds();

    deletedIds.add(barId);
    final updatedLocal = localBars.where((b) => b.id != barId).toList();

    await prefs.setString(
      _localBarsStorageKey,
      jsonEncode(updatedLocal.map((b) => b.toCatalogJson()).toList()),
    );
    await prefs.setStringList(_deletedIdsStorageKey, deletedIds.toList());

    return getAllCityBars();
  }

  /// Exporta todos os bares cadastrados como JSON formatado pronto para `assets/data/city_bars_seed.json`
  Future<String> exportCatalogJson() async {
    final bars = await getAllCityBars();
    final list = bars.map((b) => b.toCatalogJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }

  /// Importa uma lista JSON de bares mesclando ao banco local
  Future<List<Bar>> importCatalogJson(String rawJson) async {
    final decoded = jsonDecode(rawJson);
    if (decoded is! List) {
      throw const FormatException(
        'O JSON deve ser uma lista de bares ([ { "name": "...", "latitude": ..., "longitude": ... } ]).',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final existingLocal = await _loadLocalBars();
    final deletedIds = await _loadDeletedIds();
    final byId = <String, Bar>{
      for (final b in existingLocal) b.id: b,
    };

    int seq = 0;
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;
      final id = (item['id']?.toString().trim().isNotEmpty ?? false)
          ? item['id'].toString().trim()
          : 'city_bar_${DateTime.now().millisecondsSinceEpoch}_${++seq}';
      final bar = Bar.fromJson({...item, 'id': id});
      deletedIds.remove(bar.id);
      byId[bar.id] = bar;
    }

    await prefs.setString(
      _localBarsStorageKey,
      jsonEncode(byId.values.map((b) => b.toCatalogJson()).toList()),
    );
    await prefs.setStringList(_deletedIdsStorageKey, deletedIds.toList());

    return getAllCityBars();
  }

  Future<List<Bar>> _loadSeedBars() async {
    try {
      final raw = await _assetBundle.loadString(seedAssetPath);
      if (raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Bar.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<Bar>> _loadLocalBars() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localBarsStorageKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Bar.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<Set<String>> _loadDeletedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_deletedIdsStorageKey) ?? const [];
      return list.toSet();
    } catch (_) {
      return <String>{};
    }
  }
}
