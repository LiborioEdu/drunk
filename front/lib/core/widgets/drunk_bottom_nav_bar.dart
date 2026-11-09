import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Abas principais da barra inferior (DRUNK centralizado entre os 5 ícones)
enum DrunkNavTab { rota, anotar, radar, crew, perfil }

/// Barra de navegação inferior Cyberpunk Dark Neon (`ROTA • ANOTAR • DRUNK • CREW • PERFIL`)
class DrunkBottomNavBar extends StatelessWidget {
  final DrunkNavTab currentTab;
  final ValueChanged<DrunkNavTab> onSelectTab;
  final bool hasActiveRace;

  const DrunkBottomNavBar({
    super.key,
    required this.currentTab,
    required this.onSelectTab,
    this.hasActiveRace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0B0B0E),
        border: Border(
          top: BorderSide(color: Color(0x1FFFFFFF), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  icon: Icons.route_rounded,
                  label: 'ROTA',
                  isSelected: currentTab == DrunkNavTab.rota,
                  onTap: () => onSelectTab(DrunkNavTab.rota),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.edit_rounded,
                  label: 'ANOTAR',
                  isSelected: currentTab == DrunkNavTab.anotar,
                  onTap: () => onSelectTab(DrunkNavTab.anotar),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.navigation_rounded,
                  label: 'DRUNK',
                  isSelected: currentTab == DrunkNavTab.radar,
                  showLiveDot: hasActiveRace,
                  onTap: () => onSelectTab(DrunkNavTab.radar),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.groups_rounded,
                  label: 'CREW',
                  isSelected: currentTab == DrunkNavTab.crew,
                  onTap: () => onSelectTab(DrunkNavTab.crew),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.person_outline_rounded,
                  label: 'PERFIL',
                  isSelected: currentTab == DrunkNavTab.perfil,
                  onTap: () => onSelectTab(DrunkNavTab.perfil),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool showLiveDot;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.showLiveDot = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.neonOrange : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: color, size: 23),
              if (showLiveDot)
                Positioned(
                  right: -4,
                  top: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.cyberGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.cyberGreenGlow,
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
