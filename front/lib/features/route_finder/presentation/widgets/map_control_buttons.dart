import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Controles flutuantes laterais de câmera estilo Google Maps + Stitch IA (`01_route_finder`)
class MapControlButtons extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onCenterMyLocation;
  final bool isFollowingUser;
  final bool isLocating;
  final VoidCallback? onToggleMapStyle;
  final String? mapStyleTooltip;
  final VoidCallback? onCenterOrigin;
  final VoidCallback? onFitRoute;

  const MapControlButtons({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onCenterMyLocation,
    this.isFollowingUser = false,
    this.isLocating = false,
    this.onToggleMapStyle,
    this.mapStyleTooltip,
    this.onCenterOrigin,
    this.onFitRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Cápsula vertical de Zoom (+ / -)
        Container(
          width: 44,
          decoration: BoxDecoration(
            color: const Color(0xEB15151B),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0x26FFFFFF)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: onZoomIn,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
                child: const SizedBox(
                  height: 44,
                  width: 44,
                  child: Icon(Icons.add_rounded, color: Colors.white, size: 22),
                ),
              ),
              const Divider(height: 1, color: Color(0x22FFFFFF)),
              InkWell(
                onTap: onZoomOut,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(22),
                ),
                child: const SizedBox(
                  height: 44,
                  width: 44,
                  child: Icon(
                    Icons.remove_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Botão "Minha Localização" (estilo Google Maps — brilha intenso quando fixado no usuário)
        Tooltip(
          message: 'Minha Localização',
          child: _CircleMapButton(
            icon: isFollowingUser
                ? Icons.my_location_rounded
                : Icons.location_searching_rounded,
            borderColor: AppColors.neonCyan,
            iconColor: isFollowingUser ? Colors.black : AppColors.neonCyan,
            fillColor: isFollowingUser
                ? AppColors.neonCyan
                : AppColors.neonCyan.withValues(alpha: 0.14),
            glowColor: isFollowingUser ? AppColors.neonCyanGlow : null,
            isLoading: isLocating,
            onTap: onCenterMyLocation,
          ),
        ),

        // Caso a LARGADA tenha sido movida para outro bairro, permite focar também na LARGADA
        if (onCenterOrigin != null) ...[
          const SizedBox(height: 10),
          Tooltip(
            message: 'Ir para Largada',
            child: _CircleMapButton(
              icon: Icons.flag_rounded,
              borderColor: AppColors.cyberGreen,
              iconColor: AppColors.cyberGreen,
              fillColor: AppColors.cyberGreen.withValues(alpha: 0.14),
              onTap: onCenterOrigin!,
            ),
          ),
        ],

        if (onFitRoute != null) ...[
          const SizedBox(height: 10),
          // Botão circular Orange: Enquadrar Rota 10KM
          Tooltip(
            message: 'Enquadrar Rota 10KM',
            child: _CircleMapButton(
              icon: Icons.center_focus_strong_rounded,
              borderColor: AppColors.neonOrange,
              iconColor: AppColors.neonOrange,
              fillColor: AppColors.neonOrange.withValues(alpha: 0.14),
              onTap: onFitRoute!,
            ),
          ),
        ],

        if (onToggleMapStyle != null) ...[
          const SizedBox(height: 10),
          // Botão de Camadas (OSM Dark Neon / ArcGIS Dark / OSM Claro)
          Tooltip(
            message: mapStyleTooltip ?? 'Alternar Estilo do Mapa',
            child: _CircleMapButton(
              icon: Icons.layers_outlined,
              borderColor: const Color(0x55FFFFFF),
              iconColor: Colors.white,
              fillColor: const Color(0x22FFFFFF),
              onTap: onToggleMapStyle!,
            ),
          ),
        ],
      ],
    );
  }
}

class _CircleMapButton extends StatelessWidget {
  final IconData icon;
  final Color borderColor;
  final Color iconColor;
  final Color fillColor;
  final Color? glowColor;
  final bool isLoading;
  final VoidCallback onTap;

  const _CircleMapButton({
    required this.icon,
    required this.borderColor,
    required this.iconColor,
    required this.fillColor,
    required this.onTap,
    this.glowColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: glowColor != null
            ? [
                BoxShadow(
                  color: glowColor!,
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Material(
        color: const Color(0xEB15151B),
        shape: CircleBorder(
          side: BorderSide(
            color: borderColor.withValues(alpha: 0.8),
            width: 1.4,
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fillColor,
            ),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                      ),
                    )
                  : Icon(icon, color: iconColor, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
