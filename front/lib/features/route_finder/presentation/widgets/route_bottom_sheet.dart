import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../domain/entities/drunk_route.dart';
import 'bar_card_item.dart';
import 'route_metrics_banner.dart';

/// Gaveta inferior deslizante fiel ao Stitch IA (`01_route_finder`)
class RouteBottomSheet extends StatelessWidget {
  final double searchRadiusKm;
  final ValueChanged<double> onRadiusChanged;
  final bool isGenerating;
  final VoidCallback onGeneratePressed;
  final int cityBarsCount;
  final DrunkRoute? route;
  final int? swappingBarIndex;
  final int? selectedBarIndex;
  final Function(int index) onSwapBar;
  final Function(int index)? onSelectBar;
  final VoidCallback? onLockAndStart;
  final VoidCallback? onResetRoute;
  final String? errorMessage;

  const RouteBottomSheet({
    super.key,
    required this.searchRadiusKm,
    required this.onRadiusChanged,
    required this.isGenerating,
    required this.onGeneratePressed,
    this.cityBarsCount = 0,
    this.route,
    this.swappingBarIndex,
    this.selectedBarIndex,
    required this.onSwapBar,
    this.onSelectBar,
    this.onLockAndStart,
    this.onResetRoute,
    this.errorMessage,
  });

  static const List<double> _quickRadii = [2.0, 3.5, 5.0];

  @override
  Widget build(BuildContext context) {
    final hasRoute = route != null && route!.bars.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: hasRoute ? 0.49 : 0.37,
      minChildSize: 0.22,
      maxChildSize: 0.86,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xF5141419),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border(
              top: BorderSide(
                color: AppColors.neonOrange.withValues(alpha: 0.42),
                width: 1.4,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.75),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Grabber Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 10),
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFF343442),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.alertRed.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.alertRed.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.alertRed,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              Expanded(
                child: hasRoute
                    ? _buildRouteReadyView(context, scrollController)
                    : _buildInitialView(context, scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Estado Pré-Geração estilizado com o novo Design System Stitch IA
  Widget _buildInitialView(
    BuildContext context,
    ScrollController scrollController,
  ) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
      children: [
        // Preview cápsula 3 colunas estilo Stitch antes da geração
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFF0B0B0E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x22FFFFFF)),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  children: [
                    Text(
                      '~10.0 KM',
                      style: TextStyle(
                        color: AppColors.neonOrange,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'META DO CIRCUITO',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 30, color: const Color(0x24FFFFFF)),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$cityBarsCount BARES',
                      style: const TextStyle(
                        color: AppColors.cyberGreen,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'BANCO DA CIDADE',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 30, color: const Color(0x24FFFFFF)),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${searchRadiusKm.toStringAsFixed(1)} KM',
                      style: const TextStyle(
                        color: AppColors.neonCyan,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'RAIO RADAR',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Controle de Raio Compacto
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          decoration: BoxDecoration(
            color: const Color(0xFF191920),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x22FFFFFF)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.radar_rounded,
                        color: AppColors.neonCyan,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'ALCANCE DO RADAR NA CIDADE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      for (final r in _quickRadii)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: GestureDetector(
                            onTap:
                                isGenerating ? null : () => onRadiusChanged(r),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 3.5,
                              ),
                              decoration: BoxDecoration(
                                color: (searchRadiusKm - r).abs() < 0.1
                                    ? AppColors.neonOrange
                                    : const Color(0xFF0E0E13),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${r.toStringAsFixed(1)}k',
                                style: TextStyle(
                                  color: (searchRadiusKm - r).abs() < 0.1
                                      ? Colors.black
                                      : AppColors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              Slider(
                value: searchRadiusKm,
                min: 1.5,
                max: 6.0,
                divisions: 9,
                onChanged: isGenerating ? null : onRadiusChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        NeonButton(
          label: 'GERAR ROTA DRUNK (10KM)',
          icon: Icons.bolt_rounded,
          borderRadius: 28,
          height: 56,
          gradient: AppColors.neonOrangeGradient,
          textColor: Colors.black,
          isLoading: isGenerating,
          onPressed: isGenerating ? null : onGeneratePressed,
        ),
      ],
    );
  }

  /// Estado Rota Gerada: Cápsula 10.2 KM | 10 BARES | 1H 58M + Lista + Botão Pílula Cyber Green
  Widget _buildRouteReadyView(
    BuildContext context,
    ScrollController scrollController,
  ) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
            children: [
              RouteMetricsBanner(
                route: route!,
                onResetRoute: onResetRoute,
              ),
              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.only(left: 2, right: 2, bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.neonOrange,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ITINERÁRIO DOS ${route!.totalBars} BARES',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    if (onResetRoute != null)
                      InkWell(
                        onTap: onResetRoute,
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          child: Text(
                            'NOVA ROTA ↻',
                            style: TextStyle(
                              color: AppColors.neonOrange,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              for (int i = 0; i < route!.bars.length; i++)
                BarCardItem(
                  bar: route!.bars[i],
                  isSwapping: swappingBarIndex == i,
                  isSelected: selectedBarIndex == i,
                  isLast: i == route!.bars.length - 1,
                  onTap: () => onSelectBar?.call(i),
                  onSwap: () => onSwapBar(i),
                ),
            ],
          ),
        ),

        // CTA Pílula Fixo em Cyber Green exatamente como no Stitch IA (`01_route_finder`)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: NeonButton(
            label: 'TRAVAR ROTA E INICIAR CORRIDA (10KM)',
            icon: Icons.play_arrow_rounded,
            borderRadius: 28,
            height: 56,
            color: AppColors.cyberGreen,
            glowColor: AppColors.cyberGreenGlow,
            gradient: AppColors.cyberGreenGradient,
            textColor: Colors.black,
            onPressed: onLockAndStart,
          ),
        ),
      ],
    );
  }
}
