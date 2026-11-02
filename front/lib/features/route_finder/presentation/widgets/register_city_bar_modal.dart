import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../domain/entities/bar.dart';

/// Modal Cyberpunk para Cadastrar ou Editar um Bar Oficial no Banco da Cidade
class RegisterCityBarModal extends StatefulWidget {
  final LatLng initialCoordinates;
  final Bar? existingBar;
  final Future<String> Function(LatLng point) onResolveAddress;
  final Future<void> Function({
    String? existingId,
    required String name,
    required LatLng coordinates,
    String? address,
    required String amenity,
    String? description,
  }) onSave;
  final Future<void> Function(String barId)? onDelete;

  const RegisterCityBarModal({
    super.key,
    required this.initialCoordinates,
    required this.onResolveAddress,
    required this.onSave,
    this.existingBar,
    this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    required LatLng initialCoordinates,
    Bar? existingBar,
    required Future<String> Function(LatLng point) onResolveAddress,
    required Future<void> Function({
      String? existingId,
      required String name,
      required LatLng coordinates,
      String? address,
      required String amenity,
      String? description,
    }) onSave,
    Future<void> Function(String barId)? onDelete,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RegisterCityBarModal(
        initialCoordinates: initialCoordinates,
        existingBar: existingBar,
        onResolveAddress: onResolveAddress,
        onSave: onSave,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<RegisterCityBarModal> createState() => _RegisterCityBarModalState();
}

class _RegisterCityBarModalState extends State<RegisterCityBarModal> {
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _coordsController;
  late final TextEditingController _descController;
  late String _selectedAmenity;
  late LatLng _coords;
  bool _isResolvingAddress = false;
  bool _isSaving = false;
  String? _validationError;

  static const List<(String, String, IconData)> _categories = [
    ('bar', 'Bar / Boteco', Icons.sports_bar_rounded),
    ('pub', 'Pub / Choperia', Icons.liquor_rounded),
    ('espetinho', 'Espetinho', Icons.outdoor_grill_rounded),
    ('brewery', 'Cervejaria', Icons.local_drink_rounded),
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existingBar;
    _coords = existing?.coordinates ?? widget.initialCoordinates;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _addressController = TextEditingController(text: existing?.address ?? '');
    _coordsController = TextEditingController(
      text:
          '${_coords.latitude.toStringAsFixed(6)}, ${_coords.longitude.toStringAsFixed(6)}',
    );
    _descController = TextEditingController(text: existing?.description ?? '');
    _selectedAmenity = existing?.amenity ?? 'bar';

    if (existing == null ||
        existing.address == null ||
        existing.address!.isEmpty) {
      _autoResolveAddress(_coords);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _coordsController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _autoResolveAddress(LatLng point) async {
    setState(() => _isResolvingAddress = true);
    final resolved = await widget.onResolveAddress(point);
    if (!mounted) return;
    setState(() {
      _isResolvingAddress = false;
      if (_addressController.text.trim().isEmpty) {
        _addressController.text = resolved;
      }
    });
  }

  LatLng? _tryParseCoords(String raw) {
    final parts = raw.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return LatLng(lat, lng);
  }

  void _onCoordsChanged(String value) {
    final parsed = _tryParseCoords(value);
    if (parsed != null) {
      _coords = parsed;
      _addressController.clear();
      _autoResolveAddress(parsed);
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _validationError = 'Informe o nome do bar.');
      return;
    }

    final parsedCoords = _tryParseCoords(_coordsController.text);
    if (parsedCoords == null) {
      setState(
        () => _validationError =
            'Coordenadas inválidas. Use o formato: -5.0892, -42.7534',
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _validationError = null;
    });

    await widget.onSave(
      existingId: widget.existingBar?.id,
      name: name,
      coordinates: parsedCoords,
      address: _addressController.text.trim(),
      amenity: _selectedAmenity,
      description: _descController.text.trim(),
    );

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.existingBar != null;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFA141419),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(
              color: AppColors.neonOrange.withValues(alpha: 0.65),
              width: 1.5,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF343442),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                // Cabeçalho
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.neonOrange.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.sports_bar_rounded,
                        color: AppColors.neonOrange,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isEditing
                            ? 'EDITAR BAR DA CIDADE'
                            : 'CADASTRAR BAR OFICIAL',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.9,
                        ),
                      ),
                    ),
                    if (isEditing && widget.onDelete != null)
                      IconButton(
                        tooltip: 'Excluir Bar',
                        onPressed: () async {
                          await widget.onDelete!(widget.existingBar!.id);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.alertRed,
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
                const SizedBox(height: 14),

                // Nome do Bar
                const Text(
                  'NOME DO BAR / ESTABELECIMENTO *',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameController,
                  autofocus: !isEditing,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: _inputDecoration(
                    hint: 'Ex: Resenha Bar, Espetinho do Grau...',
                    icon: Icons.storefront_rounded,
                  ),
                ),
                const SizedBox(height: 14),

                // Seletor de Categoria
                const Text(
                  'ESTILO DO LOCAL',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (value, label, icon) in _categories)
                      GestureDetector(
                        onTap: () => setState(() => _selectedAmenity = value),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _selectedAmenity == value
                                ? AppColors.neonOrange.withValues(alpha: 0.20)
                                : const Color(0xFF0B0B0E),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _selectedAmenity == value
                                  ? AppColors.neonOrange
                                  : const Color(0x26FFFFFF),
                              width: _selectedAmenity == value ? 1.4 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                size: 15,
                                color: _selectedAmenity == value
                                    ? AppColors.neonOrange
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                label,
                                style: TextStyle(
                                  color: _selectedAmenity == value
                                      ? AppColors.neonOrange
                                      : Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Endereço preenchido automaticamente
                Row(
                  children: [
                    const Text(
                      'RUA / BAIRRO',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    if (_isResolvingAddress) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 11,
                        height: 11,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.neonCyan),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _addressController,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  decoration: _inputDecoration(
                    hint: 'Rua e bairro do bar',
                    icon: Icons.place_outlined,
                  ),
                ),
                const SizedBox(height: 14),

                // Coordenadas (suporta colar direto do clique direito do Google Maps!)
                const Text(
                  'COORDENADAS (TOQUE NO MAPA OU COLE DO GOOGLE MAPS)',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _coordsController,
                  onChanged: _onCoordsChanged,
                  style: const TextStyle(
                    color: AppColors.neonCyan,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: _inputDecoration(
                    hint: '-5.089210, -42.753410',
                    icon: Icons.my_location_rounded,
                  ),
                ),
                const SizedBox(height: 14),

                // Destaque opcional
                const Text(
                  'OBSERVAÇÃO / DESTAQUE (OPCIONAL)',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _descController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _inputDecoration(
                    hint: 'Ex: Chopp gelado, música ao vivo, abre às 18h',
                    icon: Icons.star_outline_rounded,
                  ),
                ),

                if (_validationError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _validationError!,
                    style: const TextStyle(
                      color: AppColors.alertRed,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],

                const SizedBox(height: 18),
                NeonButton(
                  label: isEditing
                      ? 'SALVAR ALTERAÇÕES DO BAR'
                      : 'SALVAR NO BANCO DA CIDADE',
                  icon: Icons.check_circle_outline_rounded,
                  borderRadius: 26,
                  height: 52,
                  color: AppColors.cyberGreen,
                  glowColor: AppColors.cyberGreenGlow,
                  gradient: AppColors.cyberGreenGradient,
                  textColor: Colors.black,
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF0B0B0E),
      prefixIcon: Icon(icon, color: AppColors.neonOrange, size: 19),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0x26FFFFFF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.neonOrange, width: 1.4),
      ),
    );
  }
}
