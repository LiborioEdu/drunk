import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../controllers/route_finder_state.dart';

/// Cabeçalho HUD flutuante com Menu Hambúrguer unificado:
/// - Modo recolhido: barra esbelta de 1 linha com menu hambúrguer, meta do percurso, endereço atual e GPS.
/// - Modo expandido: painel elegante com todas as opções e ferramentas do circuito.
class FloatingGpsHeader extends StatefulWidget {
  final GpsStatus gpsStatus;
  final double? gpsAccuracyMeters;
  final bool isFollowingUser;
  final String locationAddress;
  final bool isLoading;
  final int cityBarsCount;
  final double targetDistanceKm;
  final int targetBarsCount;
  final bool isRegisteringBarMode;
  final bool isManualRouteMode;
  final int manualStopsCount;
  final bool? isMenuOpen;
  final VoidCallback? onToggleMenu;
  final VoidCallback? onCloseMenu;
  final VoidCallback? onRefresh;
  final VoidCallback? onEditLocation;
  final VoidCallback? onToggleRegisterBarMode;
  final VoidCallback? onToggleManualRouteMode;
  final VoidCallback? onUndoManualStop;
  final VoidCallback? onOpenCityBarsManager;

  const FloatingGpsHeader({
    super.key,
    required this.gpsStatus,
    required this.locationAddress,
    this.gpsAccuracyMeters,
    this.isFollowingUser = true,
    this.isLoading = false,
    this.cityBarsCount = 0,
    this.targetDistanceKm = 10.0,
    this.targetBarsCount = 10,
    this.isRegisteringBarMode = false,
    this.isManualRouteMode = false,
    this.manualStopsCount = 0,
    this.isMenuOpen,
    this.onToggleMenu,
    this.onCloseMenu,
    this.onRefresh,
    this.onEditLocation,
    this.onToggleRegisterBarMode,
    this.onToggleManualRouteMode,
    this.onUndoManualStop,
    this.onOpenCityBarsManager,
  });

  @override
  State<FloatingGpsHeader> createState() => _FloatingGpsHeaderState();
}

class _FloatingGpsHeaderState extends State<FloatingGpsHeader> {
  bool _internalMenuOpen = false;

  bool get _isOpen => widget.isMenuOpen ?? _internalMenuOpen;

  void _toggleMenu() {
    if (widget.onToggleMenu != null) {
      widget.onToggleMenu!();
    } else {
      setState(() => _internalMenuOpen = !_internalMenuOpen);
    }
  }

  void _closeMenu() {
    if (widget.onCloseMenu != null) {
      widget.onCloseMenu!();
    } else {
      setState(() => _internalMenuOpen = false);
    }
  }

  Color _getStatusColor() {
    switch (widget.gpsStatus) {
      case GpsStatus.active:
        return AppColors.neonCyan;
      case GpsStatus.ipApproximate:
        return AppColors.cyberGreen;
      case GpsStatus.locating:
        return AppColors.neonCyan;
      case GpsStatus.permissionDenied:
        return AppColors.neonOrange;
      case GpsStatus.error:
        return AppColors.alertRed;
    }
  }

  String _getStatusText() {
    switch (widget.gpsStatus) {
      case GpsStatus.active:
        final acc = widget.gpsAccuracyMeters;
        if (acc != null && acc.isFinite && acc > 0) {
          final formattedAcc = acc >= 1000
              ? '${(acc / 1000.0).toStringAsFixed(1)}KM'
              : '${acc.round()}M';
          return 'GPS • $formattedAcc';
        }
        return 'GPS ATIVO';
      case GpsStatus.ipApproximate:
        return 'REDE IP';
      case GpsStatus.locating:
        return 'LOCALIZANDO...';
      case GpsStatus.permissionDenied:
        return 'PERMISSÃO GPS';
      case GpsStatus.error:
        return 'MODO MANUAL';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final kmFormatted = widget.targetDistanceKm.truncateToDouble() ==
            widget.targetDistanceKm
        ? widget.targetDistanceKm.toStringAsFixed(0)
        : widget.targetDistanceKm.toStringAsFixed(1);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barra Principal Esbelta (Hambúrguer + Meta + Endereço + GPS)
            GlassCard(
              borderRadius: 22,
              backgroundColor: const Color(0xEB141419),
              borderColor: _isOpen
                  ? AppColors.neonOrange.withValues(alpha: 0.6)
                  : const Color(0x22FFFFFF),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  // 1. Botão Hambúrguer com feedback neon
                  Tooltip(
                    message: _isOpen ? 'Fechar Menu' : 'Menu de Opções',
                    child: Material(
                      color: _isOpen
                          ? AppColors.neonOrange.withValues(alpha: 0.2)
                          : const Color(0xFF1B1B24),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _toggleMenu,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isOpen
                                  ? AppColors.neonOrange
                                  : const Color(0x33FFFFFF),
                              width: 1.3,
                            ),
                          ),
                          child: Icon(
                            _isOpen
                                ? Icons.close_rounded
                                : Icons.menu_rounded,
                            color: _isOpen
                                ? AppColors.neonOrange
                                : Colors.white,
                            size: 21,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // 2. Título & Endereço do Ponto de Partida
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _toggleMenu,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                'DRUNK // ${kmFormatted}K',
                                style: const TextStyle(
                                  color: AppColors.neonOrange,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.cyberGreen
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.cyberGreen
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  '${widget.targetBarsCount} BARES',
                                  style: const TextStyle(
                                    color: AppColors.cyberGreen,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                widget.isFollowingUser
                                    ? Icons.my_location_rounded
                                    : Icons.location_on_rounded,
                                size: 11,
                                color: widget.isFollowingUser
                                    ? AppColors.neonCyan
                                    : AppColors.cyberGreen,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widget.locationAddress,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFD2D2DC),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Status GPS compacto
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withValues(alpha: 0.7),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _getStatusText(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // 4. Botão Rápido Minha Localização
                  Tooltip(
                    message: 'Minha Localização',
                    child: Material(
                      color: const Color(0xFF1B1B24),
                      shape: const CircleBorder(
                        side: BorderSide(color: Color(0x28FFFFFF)),
                      ),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: widget.isLoading ? null : widget.onRefresh,
                        child: SizedBox(
                          width: 34,
                          height: 34,
                          child: Center(
                            child: widget.isLoading
                                ? const SizedBox(
                                    width: 13,
                                    height: 13,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        AppColors.neonCyan,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.my_location_rounded,
                                    color: AppColors.neonCyan,
                                    size: 16,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Painel do Menu Hambúrguer Aberto
            if (_isOpen)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xF7131319),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: AppColors.neonOrange.withValues(alpha: 0.45),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.85),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Cabeçalho do Menu
                      Row(
                        children: [
                          const Icon(
                            Icons.tune_rounded,
                            color: AppColors.neonOrange,
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'OPÇÕES & FERRAMENTAS DO MAPA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: _closeMenu,
                            borderRadius: BorderRadius.circular(8),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              child: Text(
                                'FECHAR ✕',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(color: Color(0x1AFFFFFF), height: 1),
                      const SizedBox(height: 8),

                      // Opção 1: Ponto de Partida / Buscar Endereço
                      _buildMenuItem(
                        icon: Icons.search_rounded,
                        accentColor: AppColors.neonCyan,
                        category: 'PONTO DE PARTIDA',
                        title: widget.locationAddress,
                        trailingText: 'ALTERAR',
                        trailingColor: AppColors.neonOrange,
                        onTap: () {
                          _closeMenu();
                          widget.onEditLocation?.call();
                        },
                      ),

                      // Opção 2: Montar Rota Manualmente no Mapa
                      _buildMenuItem(
                        icon: Icons.touch_app_rounded,
                        accentColor: AppColors.neonCyan,
                        category: 'TRAÇADO DE ROTA',
                        title: widget.isManualRouteMode
                            ? 'Montando no Mapa (${widget.manualStopsCount} paradas)'
                            : 'Montar Rota Manualmente no Mapa',
                        isActive: widget.isManualRouteMode,
                        activeBadgeColor: AppColors.neonCyan,
                        onTap: () {
                          _closeMenu();
                          widget.onToggleManualRouteMode?.call();
                        },
                      ),

                      // Opção 3: Cadastrar Bar Clicando no Mapa
                      _buildMenuItem(
                        icon: Icons.add_location_alt_rounded,
                        accentColor: AppColors.neonOrange,
                        category: 'BANCO DE DADOS',
                        title: widget.isRegisteringBarMode
                            ? 'Modo Cadastrar Bar Ativo'
                            : '+ Cadastrar Bar Clicando no Mapa',
                        isActive: widget.isRegisteringBarMode,
                        activeBadgeColor: AppColors.neonOrange,
                        onTap: () {
                          _closeMenu();
                          widget.onToggleRegisterBarMode?.call();
                        },
                      ),

                      // Opção 4: Banco de Bares da Cidade
                      _buildMenuItem(
                        icon: Icons.sports_bar_rounded,
                        accentColor: AppColors.cyberGreen,
                        category: 'ESTABELECIMENTOS',
                        title: 'Banco de Bares da Cidade',
                        subtitle:
                            '${widget.cityBarsCount} bares cadastrados na região',
                        trailingText: 'GERENCIAR',
                        trailingColor: AppColors.cyberGreen,
                        onTap: () {
                          _closeMenu();
                          widget.onOpenCityBarsManager?.call();
                        },
                      ),

                      // Opção 5: Centralizar no GPS
                      _buildMenuItem(
                        icon: Icons.my_location_rounded,
                        accentColor: AppColors.neonCyan,
                        category: 'GEOLOCALIZAÇÃO',
                        title: 'Centralizar na Minha Localização',
                        subtitle: _getStatusText(),
                        trailingText: 'CENTRALIZAR',
                        trailingColor: AppColors.neonCyan,
                        isLast: true,
                        onTap: () {
                          _closeMenu();
                          widget.onRefresh?.call();
                        },
                      ),
                    ],
                  ),
                ),
              ),

            // Banner flutuante quando o Modo Montar Rota Manualmente está ativo
            if (widget.isManualRouteMode && !widget.isRegisteringBarMode)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xF50B161B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.neonCyan,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.touch_app_rounded,
                        color: AppColors.neonCyan,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.manualStopsCount == 0
                              ? 'MODO MANUAL: Toque nos bares 🍺 ou em qualquer ponto do mapa para marcar a Parada #01!'
                              : 'MODO MANUAL (${widget.manualStopsCount} paradas): Continue clicando no mapa para adicionar paradas!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (widget.manualStopsCount > 0 &&
                          widget.onUndoManualStop != null) ...[
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: widget.onUndoManualStop,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A252B),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.neonCyan.withValues(alpha: 0.5),
                              ),
                            ),
                            child: const Text(
                              'DESFAZER ↶',
                              style: TextStyle(
                                color: AppColors.neonCyan,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: widget.onToggleManualRouteMode,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Text(
                            'PRONTO',
                            style: TextStyle(
                              color: AppColors.cyberGreen,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Banner flutuante quando o Modo Cadastrar Bar clicando no mapa está ativo
            if (widget.isRegisteringBarMode)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xF51A120B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.neonOrange,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.touch_app_rounded,
                        color: AppColors.neonOrange,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'MODO CADASTRO: Toque na rua/esquina do bar no mapa para cadastrá-lo!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: widget.onToggleRegisterBarMode,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text(
                            'CONCLUIR',
                            style: TextStyle(
                              color: AppColors.neonOrange,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color accentColor,
    required String category,
    required String title,
    String? subtitle,
    String? trailingText,
    Color? trailingColor,
    bool? isActive,
    Color? activeBadgeColor,
    bool isLast = false,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 6),
      child: Material(
        color: const Color(0xFF191922),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (isActive == true
                        ? (activeBadgeColor ?? accentColor)
                        : const Color(0x1FFFFFFF))
                    .withValues(alpha: isActive == true ? 0.6 : 0.2),
              ),
            ),
            child: Row(
              children: [
                // Ícone na caixa
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accentColor, size: 16),
                ),
                const SizedBox(width: 10),

                // Conteúdo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        category,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Trailing: Toggle ativo/inativo ou Ação
                if (isActive != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? (activeBadgeColor ?? accentColor)
                          : const Color(0xFF121218),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isActive
                            ? (activeBadgeColor ?? accentColor)
                            : const Color(0x28FFFFFF),
                      ),
                    ),
                    child: Text(
                      isActive ? 'ATIVO ✓' : 'INATIVO',
                      style: TextStyle(
                        color: isActive ? Colors.black : AppColors.textSecondary,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                else if (trailingText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: (trailingColor ?? accentColor)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (trailingColor ?? accentColor)
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      trailingText,
                      style: TextStyle(
                        color: trailingColor ?? accentColor,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
