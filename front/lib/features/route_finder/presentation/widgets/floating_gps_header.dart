import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../controllers/route_finder_state.dart';

/// Cabeçalho HUD flutuante com GPS Real + Atalhos de Cadastro/Gerenciamento do Banco de Bares da Cidade
class FloatingGpsHeader extends StatelessWidget {
  final GpsStatus gpsStatus;
  final double? gpsAccuracyMeters;
  final bool isFollowingUser;
  final String locationAddress;
  final bool isLoading;
  final int cityBarsCount;
  final bool isRegisteringBarMode;
  final VoidCallback? onRefresh;
  final VoidCallback? onEditLocation;
  final VoidCallback? onToggleRegisterBarMode;
  final VoidCallback? onOpenCityBarsManager;

  const FloatingGpsHeader({
    super.key,
    required this.gpsStatus,
    required this.locationAddress,
    this.gpsAccuracyMeters,
    this.isFollowingUser = true,
    this.isLoading = false,
    this.cityBarsCount = 0,
    this.isRegisteringBarMode = false,
    this.onRefresh,
    this.onEditLocation,
    this.onToggleRegisterBarMode,
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

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassCard(
              borderRadius: 24,
              backgroundColor: const Color(0xEB141419),
              borderColor: const Color(0x22FFFFFF),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Linha 1: DRUNK // 10K + Status GPS + Minha Localização
                  Row(
                    children: [
                      const Icon(
                        Icons.near_me_outlined,
                        color: AppColors.neonOrange,
                        size: 21,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'DRUNK // 10K',
                        style: TextStyle(
                          color: AppColors.neonOrange,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
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
                              width: 7,
                              height: 7,
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
                            const SizedBox(width: 6),
                            Text(
                              _getStatusText(),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
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
                              width: 36,
                              height: 36,
                              child: Center(
                                child: isLoading
                                    ? const SizedBox(
                                        width: 15,
                                        height: 15,
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
                                        size: 18,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Linha 2: Box clicável SUA LOCALIZAÇÃO / PONTO DE PARTIDA + EDITAR
                  Material(
                    color: const Color(0xFF0B0B0E),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: onEditLocation ?? onRefresh,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0x1CFFFFFF)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: (isFollowingUser
                                        ? AppColors.neonCyan
                                        : AppColors.cyberGreen)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isFollowingUser
                                    ? Icons.my_location_rounded
                                    : Icons.location_on_outlined,
                                color: isFollowingUser
                                    ? AppColors.neonCyan
                                    : AppColors.cyberGreen,
                                size: 19,
                              ),
                            ),
                            const SizedBox(width: 10),
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
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    locationAddress,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.neonOrange.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
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
                                    size: 13,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'EDITAR',
                                    style: TextStyle(
                                      color: AppColors.neonOrange,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
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

                  // Linha 3: Ações Rápidas da Cidade (+ Cadastrar Bar, Banco de Bares, Minha Localização, Buscar)
                  const SizedBox(height: 11),
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        // 1. Modo Cadastrar Bar Clicando no Mapa
                        if (onToggleRegisterBarMode != null) ...[
                          GestureDetector(
                            onTap: onToggleRegisterBarMode,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: isRegisteringBarMode
                                    ? AppColors.neonOrange
                                    : AppColors.neonOrange
                                        .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.neonOrange,
                                  width: 1.4,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isRegisteringBarMode
                                        ? Icons.touch_app_rounded
                                        : Icons.add_location_alt_rounded,
                                    size: 14,
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
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],

                        // 2. Painel do Banco de Bares da Cidade
                        if (onOpenCityBarsManager != null) ...[
                          GestureDetector(
                            onTap: onOpenCityBarsManager,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.cyberGreen.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(20),
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
                                    size: 14,
                                    color: AppColors.cyberGreen,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Banco de Bares ($cityBarsCount)',
                                    style: const TextStyle(
                                      color: AppColors.cyberGreen,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],

                        // 3. Minha Localização Real
                        GestureDetector(
                          onTap: onRefresh,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: isFollowingUser
                                  ? AppColors.neonCyan.withValues(alpha: 0.18)
                                  : const Color(0xFF0E0E13),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isFollowingUser
                                    ? AppColors.neonCyan
                                    : const Color(0x28FFFFFF),
                                width: isFollowingUser ? 1.4 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.my_location_rounded,
                                  size: 13,
                                  color: isFollowingUser
                                      ? AppColors.neonCyan
                                      : const Color(0xFFD2D2DC),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Minha Localização',
                                  style: TextStyle(
                                    color: isFollowingUser
                                        ? AppColors.neonCyan
                                        : const Color(0xFFD2D2DC),
                                    fontSize: 12,
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
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: onEditLocation,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0E0E13),
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: const Color(0x28FFFFFF)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search_rounded,
                                    size: 13,
                                    color: AppColors.neonCyan,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'Buscar Rua / Bairro',
                                    style: TextStyle(
                                      color: Color(0xFFD2D2DC),
                                      fontSize: 12,
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
