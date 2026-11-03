import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../controllers/route_finder_state.dart';

/// Cabeçalho HUD flutuante com GPS Real + Meta Dinâmica (KM/Bares) + Banco de Bares da Cidade
class FloatingGpsHeader extends StatelessWidget {
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
    this.onRefresh,
    this.onEditLocation,
    this.onToggleRegisterBarMode,
    this.onToggleManualRouteMode,
    this.onUndoManualStop,
    this.onOpenCityBarsManager,
  });

  Color _getStatusColor() {
    switch (gpsStatus) {
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
    switch (gpsStatus) {
      case GpsStatus.active:
        final acc = gpsAccuracyMeters;
        if (acc != null && acc.isFinite && acc > 0) {
          final formattedAcc = acc >= 1000
              ? '${(acc / 1000.0).toStringAsFixed(1)}KM'
              : '${acc.round()}M';
          return 'GPS ATIVO • $formattedAcc';
        }
        return 'GPS ATIVO';
      case GpsStatus.ipApproximate:
        return 'REDE IP • ATIVA';
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
    final kmFormatted = targetDistanceKm.truncateToDouble() == targetDistanceKm
        ? targetDistanceKm.toStringAsFixed(0)
        : targetDistanceKm.toStringAsFixed(1);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassCard(
              borderRadius: 22,
              backgroundColor: const Color(0xEB141419),
              borderColor: const Color(0x22FFFFFF),
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Linha 1: DRUNK // XK • N BARES + Status GPS + Minha Localização
                  Row(
                    children: [
                      const Icon(
                        Icons.near_me_outlined,
                        color: AppColors.neonOrange,
                        size: 19,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'DRUNK // ${kmFormatted}K',
                        style: const TextStyle(
                          color: AppColors.neonOrange,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cyberGreen.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.cyberGreen.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          '$targetBarsCount BARES',
                          style: const TextStyle(
                            color: AppColors.cyberGreen,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4.5,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6.5,
                              height: 6.5,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: statusColor.withValues(alpha: 0.7),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _getStatusText(),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 7),
                      Tooltip(
                        message: 'Centralizar na Minha Localização',
                        child: Material(
                          color: const Color(0xFF1F1F27),
                          shape: const CircleBorder(
                            side: BorderSide(color: Color(0x28FFFFFF)),
                          ),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: isLoading ? null : onRefresh,
                            child: SizedBox(
                              width: 34,
                              height: 34,
                              child: Center(
                                child: isLoading
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
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
                                        size: 17,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),

                  // Linha 2: Box clicável SUA LOCALIZAÇÃO / PONTO DE PARTIDA + EDITAR
                  Material(
                    color: const Color(0xFF0B0B0E),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: onEditLocation ?? onRefresh,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0x1CFFFFFF)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: (isFollowingUser
                                        ? AppColors.neonCyan
                                        : AppColors.cyberGreen)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Icon(
                                isFollowingUser
                                    ? Icons.my_location_rounded
                                    : Icons.location_on_outlined,
                                color: isFollowingUser
                                    ? AppColors.neonCyan
                                    : AppColors.cyberGreen,
                                size: 17,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isFollowingUser
                                        ? 'SUA LOCALIZAÇÃO ATUAL'
                                        : 'PONTO DE PARTIDA',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 1.5),
                                  Text(
                                    locationAddress,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.neonOrange.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: AppColors.neonOrange
                                      .withValues(alpha: 0.55),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search_rounded,
                                    color: AppColors.neonOrange,
                                    size: 12,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'EDITAR',
                                    style: TextStyle(
                                      color: AppColors.neonOrange,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.7,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Linha 3: Ações Rápidas da Cidade (Montar no Mapa, + Cadastrar Bar, Banco de Bares, Minha Localização)
                  const SizedBox(height: 9),
                  SizedBox(
                    height: 31,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        // 0. Modo Montar Rota Manualmente Clicando no Mapa
                        if (onToggleManualRouteMode != null) ...[
                          GestureDetector(
                            onTap: onToggleManualRouteMode,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isManualRouteMode
                                    ? AppColors.neonCyan
                                    : AppColors.neonCyan
                                        .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: AppColors.neonCyan,
                                  width: 1.3,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isManualRouteMode
                                        ? Icons.ads_click_rounded
                                        : Icons.touch_app_rounded,
                                    size: 13,
                                    color: isManualRouteMode
                                        ? Colors.black
                                        : AppColors.neonCyan,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    isManualRouteMode
                                        ? 'Montando no Mapa ($manualStopsCount)'
                                        : 'Montar no Mapa',
                                    style: TextStyle(
                                      color: isManualRouteMode
                                          ? Colors.black
                                          : AppColors.neonCyan,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                        ],

                        // 1. Modo Cadastrar Bar Clicando no Mapa
                        if (onToggleRegisterBarMode != null) ...[
                          GestureDetector(
                            onTap: onToggleRegisterBarMode,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isRegisteringBarMode
                                    ? AppColors.neonOrange
                                    : AppColors.neonOrange
                                        .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: AppColors.neonOrange,
                                  width: 1.3,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isRegisteringBarMode
                                        ? Icons.touch_app_rounded
                                        : Icons.add_location_alt_rounded,
                                    size: 13,
                                    color: isRegisteringBarMode
                                        ? Colors.black
                                        : AppColors.neonOrange,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    isRegisteringBarMode
                                        ? 'Toque no Mapa p/ Salvar'
                                        : '+ Cadastrar Bar',
                                    style: TextStyle(
                                      color: isRegisteringBarMode
                                          ? Colors.black
                                          : AppColors.neonOrange,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                        ],

                        // 2. Painel do Banco de Bares da Cidade
                        if (onOpenCityBarsManager != null) ...[
                          GestureDetector(
                            onTap: onOpenCityBarsManager,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.cyberGreen.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: AppColors.cyberGreen
                                      .withValues(alpha: 0.65),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.sports_bar_rounded,
                                    size: 13,
                                    color: AppColors.cyberGreen,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Banco de Bares ($cityBarsCount)',
                                    style: const TextStyle(
                                      color: AppColors.cyberGreen,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                        ],

                        // 3. Minha Localização Real
                        GestureDetector(
                          onTap: onRefresh,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isFollowingUser
                                  ? AppColors.neonCyan.withValues(alpha: 0.18)
                                  : const Color(0xFF0E0E13),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isFollowingUser
                                    ? AppColors.neonCyan
                                    : const Color(0x28FFFFFF),
                                width: isFollowingUser ? 1.3 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.my_location_rounded,
                                  size: 12,
                                  color: isFollowingUser
                                      ? AppColors.neonCyan
                                      : const Color(0xFFD2D2DC),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Minha Localização',
                                  style: TextStyle(
                                    color: isFollowingUser
                                        ? AppColors.neonCyan
                                        : const Color(0xFFD2D2DC),
                                    fontSize: 11,
                                    fontWeight: isFollowingUser
                                        ? FontWeight.w900
                                        : FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 4. Buscar Rua / Bairro
                        if (onEditLocation != null) ...[
                          const SizedBox(width: 7),
                          GestureDetector(
                            onTap: onEditLocation,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0E0E13),
                                borderRadius: BorderRadius.circular(18),
                                border:
                                    Border.all(color: const Color(0x28FFFFFF)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search_rounded,
                                    size: 12,
                                    color: AppColors.neonCyan,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'Buscar Rua / Bairro',
                                    style: TextStyle(
                                      color: Color(0xFFD2D2DC),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Banner flutuante quando o Modo Montar Rota Manualmente está ativo
            if (isManualRouteMode && !isRegisteringBarMode)
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
                          manualStopsCount == 0
                              ? 'MODO MANUAL: Toque nos bares 🍺 ou em qualquer ponto do mapa para marcar a Parada #01!'
                              : 'MODO MANUAL ($manualStopsCount paradas): Continue clicando no mapa para adicionar mais paradas!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (manualStopsCount > 0 && onUndoManualStop != null) ...[
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: onUndoManualStop,
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
                        onTap: onToggleManualRouteMode,
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
            if (isRegisteringBarMode)
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
                        onTap: onToggleRegisterBarMode,
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
}
