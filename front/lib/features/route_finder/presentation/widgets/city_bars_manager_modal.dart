import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/haversine_calculator.dart';
import '../../domain/entities/bar.dart';

/// Painel Gerenciador do Banco de Dados Oficial de Bares da Cidade
class CityBarsManagerModal extends StatelessWidget {
  final List<Bar> cityBars;
  final LatLng referencePoint;
  final VoidCallback onAddAtMapTapMode;
  final VoidCallback onAddViaCoordinates;
  final ValueChanged<Bar> onFocusBar;
  final ValueChanged<Bar> onEditBar;
  final ValueChanged<String> onDeleteBar;
  final Future<String> Function() onExportJson;
  final Future<int> Function(String rawJson) onImportJson;

  const CityBarsManagerModal({
    super.key,
    required this.cityBars,
    required this.referencePoint,
    required this.onAddAtMapTapMode,
    required this.onAddViaCoordinates,
    required this.onFocusBar,
    required this.onEditBar,
    required this.onDeleteBar,
    required this.onExportJson,
    required this.onImportJson,
  });

  static Future<void> show(
    BuildContext context, {
    required List<Bar> cityBars,
    required LatLng referencePoint,
    required VoidCallback onAddAtMapTapMode,
    required VoidCallback onAddViaCoordinates,
    required ValueChanged<Bar> onFocusBar,
    required ValueChanged<Bar> onEditBar,
    required ValueChanged<String> onDeleteBar,
    required Future<String> Function() onExportJson,
    required Future<int> Function(String rawJson) onImportJson,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CityBarsManagerModal(
        cityBars: cityBars,
        referencePoint: referencePoint,
        onAddAtMapTapMode: onAddAtMapTapMode,
        onAddViaCoordinates: onAddViaCoordinates,
        onFocusBar: onFocusBar,
        onEditBar: onEditBar,
        onDeleteBar: onDeleteBar,
        onExportJson: onExportJson,
        onImportJson: onImportJson,
      ),
    );
  }

  String _formatDist(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000.0).toStringAsFixed(1)} km';
  }

  Future<void> _showImportDialog(BuildContext context) async {
    final controller = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    final raw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16161D),
        title: const Text(
          'Importar JSON de Bares',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          maxLines: 7,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: InputDecoration(
            hintText:
                '[\n  {"name": "Bar Exemplo", "latitude": -5.089, "longitude": -42.753}\n]',
            hintStyle: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.5,
            ),
            filled: true,
            fillColor: const Color(0xFF0B0B0E),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.cyberGreen,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Importar'),
          ),
        ],
      ),
    );

    if (raw == null || raw.trim().isEmpty) return;
    try {
      final total = await onImportJson(raw);
      nav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Banco atualizado! Total de $total bares na cidade.'),
          backgroundColor: const Color(0xFF183A26),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('JSON inválido: $e'),
          backgroundColor: AppColors.alertRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...cityBars]..sort((a, b) {
        final da =
            HaversineCalculator.distanceMeters(referencePoint, a.coordinates);
        final db =
            HaversineCalculator.distanceMeters(referencePoint, b.coordinates);
        return da.compareTo(db);
      });

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.84,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFA141419),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: AppColors.cyberGreen.withValues(alpha: 0.55),
            width: 1.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                    Icons.storage_rounded,
                    color: AppColors.cyberGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'BANCO DE BARES DA CIDADE (${cityBars.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
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

            // Botões de Cadastro Rápido + Exportar/Importar JSON
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ActionTileButton(
                          icon: Icons.touch_app_rounded,
                          label: 'Clicar no Mapa',
                          accent: AppColors.neonOrange,
                          onTap: () {
                            Navigator.of(context).pop();
                            onAddAtMapTapMode();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionTileButton(
                          icon: Icons.add_location_alt_rounded,
                          label: 'Colar Coordenada',
                          accent: AppColors.cyberGreen,
                          onTap: () {
                            Navigator.of(context).pop();
                            onAddViaCoordinates();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionTileButton(
                          icon: Icons.copy_all_rounded,
                          label: 'Copiar JSON Oficial',
                          accent: AppColors.neonCyan,
                          compact: true,
                          onTap: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final jsonStr = await onExportJson();
                            await Clipboard.setData(
                              ClipboardData(text: jsonStr),
                            );
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'JSON copiado! Cole em assets/data/city_bars_seed.json para fixar no app Beta.',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionTileButton(
                          icon: Icons.file_upload_outlined,
                          label: 'Importar JSON',
                          accent: Colors.white70,
                          compact: true,
                          onTap: () => _showImportDialog(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0x1EFFFFFF)),

            // Lista dos Bares Cadastrados
            Flexible(
              child: sorted.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.fromLTRB(26, 26, 26, 34),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.sports_bar_outlined,
                            color: AppColors.neonOrange,
                            size: 40,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Nenhum bar cadastrado ainda!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Use "Clicar no Mapa" para tocar nas esquinas dos bares da sua cidade ou "Colar Coordenada" copiando do Google Maps. Recomendamos pelo menos 10 bares para fechar rotas completas de 10 km!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.5,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                      itemCount: sorted.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: Color(0x16FFFFFF)),
                      itemBuilder: (context, index) {
                        final bar = sorted[index];
                        final dist = HaversineCalculator.distanceMeters(
                          referencePoint,
                          bar.coordinates,
                        );

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            onFocusBar(bar);
                          },
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color:
                                  AppColors.neonOrange.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Icon(
                              Icons.sports_bar_rounded,
                              color: AppColors.neonOrange,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            bar.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            '${_formatDist(dist)} • ${bar.address ?? "${bar.latitude.toStringAsFixed(4)}, ${bar.longitude.toStringAsFixed(4)}"}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Editar',
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: AppColors.neonCyan,
                                  size: 19,
                                ),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  onEditBar(bar);
                                },
                              ),
                              IconButton(
                                tooltip: 'Remover',
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppColors.alertRed,
                                  size: 19,
                                ),
                                onPressed: () => onDeleteBar(bar.id),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTileButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;
  final bool compact;

  const _ActionTileButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: compact ? 9 : 11,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: accent, size: compact ? 15 : 17),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: compact ? 11.5 : 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
