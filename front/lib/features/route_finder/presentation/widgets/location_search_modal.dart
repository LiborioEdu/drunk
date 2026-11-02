import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/place_suggestion.dart';

/// Modal de Busca com Autocomplete em Tempo Real (estilo Google Maps, via Photon + Nominatim)
class LocationSearchModal extends StatefulWidget {
  final String currentAddress;
  final Future<List<PlaceSuggestion>> Function(String query) onSearch;
  final VoidCallback onUseMyLocation;
  final ValueChanged<PlaceSuggestion> onSelectPlace;

  const LocationSearchModal({
    super.key,
    required this.currentAddress,
    required this.onSearch,
    required this.onUseMyLocation,
    required this.onSelectPlace,
  });

  static Future<void> show(
    BuildContext context, {
    required String currentAddress,
    required Future<List<PlaceSuggestion>> Function(String query) onSearch,
    required VoidCallback onUseMyLocation,
    required ValueChanged<PlaceSuggestion> onSelectPlace,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationSearchModal(
        currentAddress: currentAddress,
        onSearch: onSearch,
        onUseMyLocation: onUseMyLocation,
        onSelectPlace: onSelectPlace,
      ),
    );
  }

  @override
  State<LocationSearchModal> createState() => _LocationSearchModalState();
}

class _LocationSearchModalState extends State<LocationSearchModal> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;
  List<PlaceSuggestion> _results = const [];
  String _lastQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      setState(() {
        _isSearching = false;
        _results = const [];
        _lastQuery = trimmed;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _lastQuery = trimmed;
    });

    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final items = await widget.onSearch(trimmed);
      if (!mounted || _controller.text.trim() != trimmed) return;
      setState(() {
        _isSearching = false;
        _results = items;
      });
    });
  }

  IconData _iconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'bar':
      case 'pub':
      case 'biergarten':
      case 'nightclub':
        return Icons.sports_bar_rounded;
      case 'city':
      case 'town':
      case 'suburb':
      case 'district':
      case 'administrative':
        return Icons.location_city_rounded;
      default:
        return Icons.place_outlined;
    }
  }

  Color _colorForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'bar':
      case 'pub':
      case 'biergarten':
      case 'nightclub':
        return AppColors.neonOrange;
      default:
        return AppColors.neonCyan;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        decoration: BoxDecoration(
          color: const Color(0xF8141419),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(
              color: AppColors.neonCyan.withValues(alpha: 0.5),
              width: 1.4,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grabber
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 10),
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFF343442),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              // Cabeçalho
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    const Icon(
                      Icons.travel_explore_rounded,
                      color: AppColors.neonCyan,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'DEFINIR PONTO DE PARTIDA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Campo de Busca Estilo Google Maps
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  onChanged: _onQueryChanged,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Buscar rua, bairro, cidade ou bar...',
                    hintStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13.5,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF0B0B0E),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.neonCyan,
                    ),
                    suffixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(13),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.neonCyan,
                                ),
                              ),
                            ),
                          )
                        : (_controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear_rounded,
                                  color: AppColors.textSecondary,
                                  size: 18,
                                ),
                                onPressed: () {
                                  _controller.clear();
                                  _onQueryChanged('');
                                },
                              )
                            : null),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0x28FFFFFF)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: AppColors.neonCyan,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),

              // Ação Rápida #1: Usar Minha Localização Atual (GPS)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Material(
                  color: AppColors.cyberGreen.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onUseMyLocation();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.cyberGreen.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color:
                                  AppColors.cyberGreen.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.my_location_rounded,
                              color: AppColors.cyberGreen,
                              size: 19,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Usar Minha Localização Atual',
                                  style: TextStyle(
                                    color: AppColors.cyberGreen,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'GPS / Rede • Atual: ${widget.currentAddress}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.cyberGreen,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Lista de Sugestões Autocomplete
              Flexible(
                child: _buildResultsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    if (_lastQuery.length < 2) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(24, 14, 24, 26),
        child: Text(
          'Digite pelo menos 2 letras para buscar qualquer endereço, bairro, cidade ou bar próximo à sua localização.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.5,
            height: 1.4,
          ),
        ),
      );
    }

    if (!_isSearching && _results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(24, 18, 24, 28),
        child: Text(
          'Nenhum local encontrado para essa busca. Tente adicionar o nome da cidade ou bairro.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.5,
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 20),
      itemCount: _results.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: Color(0x16FFFFFF)),
      itemBuilder: (context, index) {
        final item = _results[index];
        final accent = _colorForCategory(item.category);
        final distLabel = item.formattedDistance;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 4,
          ),
          onTap: () {
            Navigator.of(context).pop();
            widget.onSelectPlace(item);
          },
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              _iconForCategory(item.category),
              color: accent,
              size: 20,
            ),
          ),
          title: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: item.subtitle.isNotEmpty
              ? Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                )
              : null,
          trailing: distLabel != null
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B0B0E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x22FFFFFF)),
                  ),
                  child: Text(
                    distLabel,
                    style: const TextStyle(
                      color: AppColors.neonCyan,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}
