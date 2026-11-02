import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/haversine_calculator.dart';
import '../../domain/entities/bar.dart';

/// Card individual de parada fiel ao Stitch IA (`01_route_finder`) com badge laranja sólido e botão Swap
class BarCardItem extends StatelessWidget {
  final Bar bar;
  final bool isSwapping;
  final bool isSelected;
  final bool isLast;
  final VoidCallback onSwap;
  final VoidCallback? onTap;

  const BarCardItem({
    super.key,
    required this.bar,
    required this.isSwapping,
    this.isSelected = false,
    this.isLast = false,
    required this.onSwap,
    this.onTap,
  });

  String _formatAmenitySubtitle(String amenity) {
    switch (amenity.toLowerCase()) {
      case 'pub':
        return 'Pub Noturno';
      case 'biergarten':
        return 'Cervejaria Artesanal';
      default:
        return 'Chopp & Drinks';
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitleText = (bar.address != null && bar.address!.isNotEmpty)
        ? '${_formatAmenitySubtitle(bar.amenity)} • ${bar.address!}'
        : '${_formatAmenitySubtitle(bar.amenity)} • Parada #${bar.order.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.neonCyan.withValues(alpha: 0.08)
              : const Color(0xFF191920),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSwapping || isSelected
                ? AppColors.neonCyan
                : const Color(0x22FFFFFF),
            width: isSwapping || isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Círculo Laranja Neon Sólido com Número Preto (01..10)
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.neonCyan : AppColors.neonOrange,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isSelected
                            ? AppColors.neonCyan
                            : AppColors.neonOrange)
                        .withValues(alpha: 0.35),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  bar.order.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Nome + Pílula +980m na primeira linha; Subtítulo/Endereço na segunda
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          bar.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.neonOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.neonOrange.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Text(
                          '+${HaversineCalculator.formatDistance(bar.distanceFromPrevious).replaceAll(' ', '')}',
                          style: const TextStyle(
                            color: AppColors.neonOrange,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Botão Circular SWAP com Borda Laranja Neon
            Tooltip(
              message: 'Trocar este bar por outro próximo',
              child: InkWell(
                onTap: isSwapping ? null : onSwap,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF14141A),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSwapping
                          ? AppColors.neonCyan
                          : AppColors.neonOrange.withValues(alpha: 0.55),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: isSwapping
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.neonCyan,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.swap_horiz_rounded,
                            color: AppColors.neonOrange,
                            size: 20,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
