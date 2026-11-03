import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../domain/entities/drunk_route.dart';
import 'bar_card_item.dart';
import 'route_metrics_banner.dart';

/// Gaveta inferior deslizante e minimizável com o dedo:
/// Permite configurar quantos KM terá o percurso, quantos bares percorrer,
/// minimizar para ver o mapa livremente e fazer Swap individual de paradas.
class RouteBottomSheet extends StatefulWidget {
  final double targetDistanceKm;
  final ValueChanged<double>? onTargetDistanceChanged;
  final int targetBarsCount;
  final ValueChanged<int>? onTargetBarsChanged;
  final double searchRadiusKm;
  final ValueChanged<double> onRadiusChanged;
  final bool isGenerating;
  final bool isManualRouteMode;
  final bool isRouteRegistered;
  final VoidCallback onGeneratePressed;
  final VoidCallback? onToggleManualRouteMode;
  final VoidCallback? onUndoManualStop;
  final int cityBarsCount;
  final DrunkRoute? route;
  final int? swappingBarIndex;
  final int? selectedBarIndex;
  final Function(int index) onSwapBar;
  final Function(int index)? onRemoveBar;
  final Function(int index)? onSelectBar;
  final VoidCallback? onRegisterRoute;
  final VoidCallback? onResetRoute;
  final String? errorMessage;

  const RouteBottomSheet({
    super.key,
    this.targetDistanceKm = 10.0,
    this.onTargetDistanceChanged,
    this.targetBarsCount = 10,
    this.onTargetBarsChanged,
    required this.searchRadiusKm,
    required this.onRadiusChanged,
    required this.isGenerating,
    this.isManualRouteMode = false,
    this.isRouteRegistered = false,
    required this.onGeneratePressed,
    this.onToggleManualRouteMode,
    this.onUndoManualStop,
    this.cityBarsCount = 0,
    this.route,
    this.swappingBarIndex,
    this.selectedBarIndex,
    required this.onSwapBar,
    this.onRemoveBar,
    this.onSelectBar,
    this.onRegisterRoute,
    this.onResetRoute,
    this.errorMessage,
  });

  @override
  State<RouteBottomSheet> createState() => _RouteBottomSheetState();
}

class _RouteBottomSheetState extends State<RouteBottomSheet> {
  static const double _minSize = 0.115;
  static const double _midConfigSize = 0.52;
  static const double _midRouteSize = 0.54;
  static const double _maxSize = 0.88;

  static const List<double> _quickDistancesKm = [2.0, 3.0, 5.0, 8.0, 10.0, 15.0];
  static const List<int> _quickBarCounts = [3, 5, 8, 10, 12, 15];

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  bool _isMinimized = false;
  bool _showConfigOverRoute = false;

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_onSheetExtentChanged);
  }

  @override
  void didUpdateWidget(covariant RouteBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hadRoute = oldWidget.route != null && oldWidget.route!.bars.isNotEmpty;
    final hasRoute = widget.route != null && widget.route!.bars.isNotEmpty;

    if (!oldWidget.isManualRouteMode && widget.isManualRouteMode) {
      // Ao entrar no Modo Manual clicando no mapa, minimiza automaticamente
      // para liberar a visão do mapa para o usuário clicar nas paradas
      _showConfigOverRoute = false;
      _animateSheetTo(_minSize);
    } else if (!hadRoute && hasRoute && !widget.isManualRouteMode) {
      _showConfigOverRoute = false;
      _animateSheetTo(_midRouteSize);
    }
  }

  void _onSheetExtentChanged() {
    if (!_sheetController.isAttached || !mounted) return;
    final nowMinimized = _sheetController.size <= (_minSize + 0.045);
    if (nowMinimized != _isMinimized) {
      setState(() => _isMinimized = nowMinimized);
    }
  }

  void _animateSheetTo(double targetExtent) {
    if (!_sheetController.isAttached) return;
    _sheetController.animateTo(
      targetExtent.clamp(_minSize, _maxSize),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _toggleMinimizeOrRestore() {
    if (!_sheetController.isAttached) return;
    final hasRoute = widget.route != null && widget.route!.bars.isNotEmpty;
    final defaultOpenSize = hasRoute ? _midRouteSize : _midConfigSize;
    if (_sheetController.size <= (_minSize + 0.05)) {
      _animateSheetTo(defaultOpenSize);
    } else {
      _animateSheetTo(_minSize);
    }
  }

  /// Permite arrastar a barra superior / cabeçalho do modal diretamente com o dedo ou mouse
  void _handleHeaderVerticalDragUpdate(
    DragUpdateDetails details,
    double screenHeight,
  ) {
    if (!_sheetController.isAttached || screenHeight <= 0) return;
    final deltaFraction = (details.primaryDelta ?? 0.0) / screenHeight;
    final nextSize =
        (_sheetController.size - deltaFraction).clamp(_minSize, _maxSize);
    _sheetController.jumpTo(nextSize);
  }

  void _handleHeaderVerticalDragEnd(DragEndDetails details) {
    if (!_sheetController.isAttached) return;
    final velocity = details.primaryVelocity ?? 0.0;
    final current = _sheetController.size;
    final hasRoute = widget.route != null && widget.route!.bars.isNotEmpty;
    final midSize = hasRoute ? _midRouteSize : _midConfigSize;

    // Arraste rápido para baixo -> minimiza imediatamente
    if (velocity > 240) {
      if (current > midSize + 0.12) {
        _animateSheetTo(midSize);
      } else {
        _animateSheetTo(_minSize);
      }
      return;
    }

    // Arraste rápido para cima -> restaura ou expande
    if (velocity < -240) {
      if (current < midSize - 0.06) {
        _animateSheetTo(midSize);
      } else {
        _animateSheetTo(_maxSize);
      }
      return;
    }

    // Sem flick forte -> faz snap para a posição mais próxima
    final snaps = [_minSize, midSize, _maxSize];
    double closest = snaps.first;
    double minDiff = (current - closest).abs();
    for (final s in snaps.skip(1)) {
      final diff = (current - s).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = s;
      }
    }
    _animateSheetTo(closest);
  }

  String _formatKmLabel(double km) {
    return km.truncateToDouble() == km
        ? km.toStringAsFixed(0)
        : km.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetExtentChanged);
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasRoute = widget.route != null && widget.route!.bars.isNotEmpty;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: hasRoute ? _midRouteSize : _midConfigSize,
      minChildSize: _minSize,
      maxChildSize: _maxSize,
      snap: true,
      snapSizes: [
        _minSize,
        hasRoute ? _midRouteSize : _midConfigSize,
        _maxSize,
      ],
      builder: (context, scrollController) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isCompactHeight =
                constraints.maxHeight <= 132 || _isMinimized;

            return Container(
              decoration: BoxDecoration(
                color: const Color(0xF6131318),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(
                    color: (hasRoute
                            ? AppColors.cyberGreen
                            : AppColors.neonOrange)
                        .withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.78),
                    blurRadius: 28,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: isCompactHeight
                  ? _buildMinimizedDock(
                      context,
                      scrollController: scrollController,
                      screenHeight: screenHeight,
                      hasRoute: hasRoute,
                    )
                  : Column(
                      children: [
                        // Barra Superior Arrastável com o Dedo + Botão Minimizar
                        _buildDraggableHeader(
                          screenHeight: screenHeight,
                          hasRoute: hasRoute,
                        ),

                        if (widget.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.alertRed.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      AppColors.alertRed.withValues(alpha: 0.5),
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
                                      widget.errorMessage!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        Expanded(
                          child: (hasRoute && !_showConfigOverRoute)
                              ? _buildRouteReadyView(context, scrollController)
                              : _buildConfiguratorView(
                                  context,
                                  scrollController,
                                  hasExistingRoute: hasRoute,
                                ),
                        ),
                      ],
                    ),
            );
          },
        );
      },
    );
  }

  /// Cabeçalho superior sensível ao toque/arraste do dedo para minimizar ou expandir o painel
  Widget _buildDraggableHeader({
    required double screenHeight,
    required bool hasRoute,
  }) {
    final kmText = _formatKmLabel(widget.targetDistanceKm);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleMinimizeOrRestore,
      onVerticalDragUpdate: (details) =>
          _handleHeaderVerticalDragUpdate(details, screenHeight),
      onVerticalDragEnd: _handleHeaderVerticalDragEnd,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 14, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pílula Grabber Central
            Container(
              width: 46,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFF454556),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  hasRoute && !_showConfigOverRoute
                      ? Icons.route_rounded
                      : Icons.tune_rounded,
                  color: hasRoute && !_showConfigOverRoute
                      ? AppColors.cyberGreen
                      : AppColors.neonOrange,
                  size: 16,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    hasRoute && !_showConfigOverRoute
                        ? (widget.isRouteRegistered
                            ? 'ROTA REGISTRADA ✓ • ${widget.route!.totalDistanceKmFormatted.toUpperCase()} (${widget.route!.totalBars} BARES)'
                            : 'ROTA PRONTA • ${widget.route!.totalDistanceKmFormatted.toUpperCase()} (${widget.route!.totalBars} BARES)')
                        : 'MONTE SEU PERCURSO • ${kmText}KM & ${widget.targetBarsCount} BARES',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Botão explícito para minimizar com 1 toque ou arrastar para baixo
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E28),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x26FFFFFF)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary,
                        size: 15,
                      ),
                      SizedBox(width: 2),
                      Text(
                        'MINIMIZAR',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Barra compacta exibida quando o usuário arrasta o modal para baixo (Minimizado)
  Widget _buildMinimizedDock(
    BuildContext context, {
    required ScrollController scrollController,
    required double screenHeight,
    required bool hasRoute,
  }) {
    final kmText = _formatKmLabel(widget.targetDistanceKm);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleMinimizeOrRestore,
      onVerticalDragUpdate: (details) =>
          _handleHeaderVerticalDragUpdate(details, screenHeight),
      onVerticalDragEnd: _handleHeaderVerticalDragEnd,
      child: SingleChildScrollView(
        controller: scrollController,
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFF454556),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: (hasRoute
                              ? AppColors.cyberGreen
                              : AppColors.neonOrange)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: (hasRoute
                                ? AppColors.cyberGreen
                                : AppColors.neonOrange)
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    child: Icon(
                      hasRoute ? Icons.flag_rounded : Icons.bolt_rounded,
                      color: hasRoute
                          ? AppColors.cyberGreen
                          : AppColors.neonOrange,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hasRoute
                              ? (widget.isRouteRegistered
                                  ? 'ROTA SALVA: ${widget.route!.totalDistanceKmFormatted.toUpperCase()} • ${widget.route!.totalBars} PARADAS'
                                  : 'ROTA: ${widget.route!.totalDistanceKmFormatted.toUpperCase()} • ${widget.route!.totalBars} PARADAS')
                              : (widget.isManualRouteMode
                                  ? 'MODO MANUAL ATIVO (0 PARADAS)'
                                  : 'META: $kmText KM • ${widget.targetBarsCount} BARES'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.isManualRouteMode
                              ? 'Clique nos bares ou ruas no mapa p/ adicionar paradas!'
                              : (hasRoute
                                  ? (widget.isRouteRegistered
                                      ? 'Rota salva! Arraste p/ cima p/ ver ou editar'
                                      : 'Toque em REGISTRAR p/ salvar a rota')
                                  : 'Arraste p/ cima p/ configurar percurso'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: widget.isManualRouteMode
                                ? AppColors.neonCyan
                                : (widget.isRouteRegistered
                                    ? AppColors.cyberGreen
                                    : AppColors.textSecondary),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // CTA rápido mesmo minimizado (apenas Gerar ou Registrar Rota)
                  GestureDetector(
                    onTap: () {
                      if (hasRoute) {
                        widget.onRegisterRoute?.call();
                      } else if (!widget.isGenerating) {
                        widget.onGeneratePressed();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: hasRoute
                            ? AppColors.cyberGreenGradient
                            : AppColors.neonOrangeGradient,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        hasRoute
                            ? (widget.isRouteRegistered
                                ? 'SALVA ✓'
                                : 'REGISTRAR')
                            : 'GERAR ⚡',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F1F29),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0x28FFFFFF)),
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Painel de Configuração de Percurso: Escolha de Quantos KM e Quantos Bares
  Widget _buildConfiguratorView(
    BuildContext context,
    ScrollController scrollController, {
    required bool hasExistingRoute,
  }) {
    final maxBarsAllowed = widget.cityBarsCount >= 2
        ? math.min(20, widget.cityBarsCount)
        : 20;
    final effectiveBars = widget.targetBarsCount.clamp(1, maxBarsAllowed);
    final avgMetersPerBar =
        ((widget.targetDistanceKm * 1000.0) / effectiveBars).round();
    final avgFormatted = avgMetersPerBar >= 1000
        ? '${(avgMetersPerBar / 1000.0).toStringAsFixed(1)} km/bar'
        : '$avgMetersPerBar m/bar';
    final reserveCount = math.max(0, widget.cityBarsCount - effectiveBars);
    final kmLabel = _formatKmLabel(widget.targetDistanceKm);

    return ListView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      children: [
        // 1. Seletor de DISTÂNCIA DO PERCURSO (KM)
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: const Color(0xFF181820),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.neonOrange.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.neonOrange.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.straighten_rounded,
                      color: AppColors.neonOrange,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DISTÂNCIA DO PERCURSO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                        Text(
                          'Quantos quilômetros terá a corrida',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStepperButton(
                    icon: Icons.remove_rounded,
                    color: AppColors.neonOrange,
                    onTap: widget.isGenerating || widget.targetDistanceKm <= 1.0
                        ? null
                        : () => widget.onTargetDistanceChanged?.call(
                              (widget.targetDistanceKm - 0.5).clamp(1.0, 20.0),
                            ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '$kmLabel KM',
                      style: const TextStyle(
                        color: AppColors.neonOrange,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _buildStepperButton(
                    icon: Icons.add_rounded,
                    color: AppColors.neonOrange,
                    onTap:
                        widget.isGenerating || widget.targetDistanceKm >= 20.0
                            ? null
                            : () => widget.onTargetDistanceChanged?.call(
                                  (widget.targetDistanceKm + 0.5)
                                      .clamp(1.0, 20.0),
                                ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.neonOrange,
                  inactiveTrackColor: const Color(0xFF282834),
                  thumbColor: AppColors.neonOrange,
                  overlayColor: AppColors.neonOrange.withValues(alpha: 0.16),
                  trackHeight: 4.0,
                ),
                child: Slider(
                  value: widget.targetDistanceKm.clamp(1.0, 20.0),
                  min: 1.0,
                  max: 20.0,
                  divisions: 38,
                  onChanged: widget.isGenerating
                      ? null
                      : (val) => widget.onTargetDistanceChanged?.call(val),
                ),
              ),
              // Atalhos rápidos de KM
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final presetKm in _quickDistancesKm)
                    _buildQuickChip(
                      label: '${presetKm.toStringAsFixed(0)} KM',
                      isSelected:
                          (widget.targetDistanceKm - presetKm).abs() < 0.2,
                      activeColor: AppColors.neonOrange,
                      onTap: widget.isGenerating
                          ? null
                          : () =>
                              widget.onTargetDistanceChanged?.call(presetKm),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 2. Seletor de QUANTIDADE DE BARES
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: const Color(0xFF181820),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.cyberGreen.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.cyberGreen.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.sports_bar_rounded,
                      color: AppColors.cyberGreen,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'QUANTIDADE DE BARES',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                        Text(
                          'Quantas paradas terá o circuito',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStepperButton(
                    icon: Icons.remove_rounded,
                    color: AppColors.cyberGreen,
                    onTap: widget.isGenerating || effectiveBars <= 2
                        ? null
                        : () => widget.onTargetBarsChanged?.call(
                              effectiveBars - 1,
                            ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '$effectiveBars BARES',
                      style: const TextStyle(
                        color: AppColors.cyberGreen,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _buildStepperButton(
                    icon: Icons.add_rounded,
                    color: AppColors.cyberGreen,
                    onTap:
                        widget.isGenerating || effectiveBars >= maxBarsAllowed
                            ? null
                            : () => widget.onTargetBarsChanged?.call(
                                  effectiveBars + 1,
                                ),
                  ),
                ],
              ),
              if (maxBarsAllowed > 2)
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.cyberGreen,
                    inactiveTrackColor: const Color(0xFF282834),
                    thumbColor: AppColors.cyberGreen,
                    overlayColor: AppColors.cyberGreen.withValues(alpha: 0.16),
                    trackHeight: 4.0,
                  ),
                  child: Slider(
                    value: effectiveBars.toDouble(),
                    min: 2,
                    max: maxBarsAllowed.toDouble(),
                    divisions: math.max(1, maxBarsAllowed - 2),
                    onChanged: widget.isGenerating
                        ? null
                        : (val) =>
                            widget.onTargetBarsChanged?.call(val.round()),
                  ),
                ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final presetBars in _quickBarCounts)
                    if (presetBars <= maxBarsAllowed)
                      _buildQuickChip(
                        label: '$presetBars BARES',
                        isSelected: effectiveBars == presetBars,
                        activeColor: AppColors.cyberGreen,
                        onTap: widget.isGenerating
                            ? null
                            : () =>
                                widget.onTargetBarsChanged?.call(presetBars),
                      ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 3. Faixa de Resumo Dinâmico (Média por trecho + Reservas p/ Swap)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFF0E0E13),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x1FFFFFFF)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.directions_run_rounded,
                    color: AppColors.neonCyan,
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Média ~$avgFormatted',
                    style: const TextStyle(
                      color: AppColors.neonCyan,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Text(
                '$reserveCount bar(es) reserva p/ Swap',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 4. Botão Principal de Geração Automática + Opção de Montar Manualmente no Mapa
        Row(
          children: [
            if (hasExistingRoute) ...[
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    side: const BorderSide(color: Color(0x38FFFFFF)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: () =>
                      setState(() => _showConfigOverRoute = false),
                  child: const Text(
                    'VER ATUAL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: 5,
              child: NeonButton(
                label:
                    'GERAR ROTA (${kmLabel}KM • $effectiveBars BARES)',
                icon: Icons.bolt_rounded,
                borderRadius: 28,
                height: 52,
                gradient: AppColors.neonOrangeGradient,
                textColor: Colors.black,
                isLoading: widget.isGenerating,
                onPressed: widget.isGenerating
                    ? null
                    : () {
                        setState(() => _showConfigOverRoute = false);
                        widget.onGeneratePressed();
                      },
              ),
            ),
          ],
        ),
        if (widget.onToggleManualRouteMode != null) ...[
          const SizedBox(height: 9),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              backgroundColor: widget.isManualRouteMode
                  ? AppColors.neonCyan.withValues(alpha: 0.16)
                  : const Color(0xFF10151A),
              side: BorderSide(
                color: AppColors.neonCyan.withValues(alpha: 0.7),
                width: 1.3,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            onPressed: () {
              setState(() => _showConfigOverRoute = false);
              widget.onToggleManualRouteMode?.call();
            },
            icon: const Icon(
              Icons.touch_app_rounded,
              color: AppColors.neonCyan,
              size: 18,
            ),
            label: Text(
              widget.isManualRouteMode
                  ? 'MODO MANUAL ATIVO • TOQUE NAS PARADAS NO MAPA'
                  : 'MONTAR ROTA MANUALMENTE CLICANDO NO MAPA',
              style: const TextStyle(
                color: AppColors.neonCyan,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStepperButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Material(
      color: const Color(0xFF0E0E14),
      shape: CircleBorder(
        side: BorderSide(
          color: enabled ? color.withValues(alpha: 0.6) : const Color(0x22FFFFFF),
        ),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(
            icon,
            size: 16,
            color: enabled ? color : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChip({
    required String label,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : const Color(0xFF0E0E14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? activeColor
                : const Color(0x24FFFFFF),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : AppColors.textSecondary,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  /// Estado Rota Gerada: Banner de Métricas + Botão Ajustar KM/Bares + Lista de Paradas + CTA Iniciar
  Widget _buildRouteReadyView(
    BuildContext context,
    ScrollController scrollController,
  ) {
    final route = widget.route!;

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
            children: [
              RouteMetricsBanner(
                route: route,
                onResetRoute: widget.onResetRoute,
              ),
              const SizedBox(height: 12),

              // Barra de ações rápidas sobre o itinerário: Ajustar KM/Bares ou Sortear Nova Rota
              Row(
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
                      const SizedBox(width: 7),
                      Text(
                        'ITINERÁRIO (${route.totalBars} PARADAS)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (widget.onToggleManualRouteMode != null) ...[
                        InkWell(
                          onTap: () {
                            if (!widget.isManualRouteMode) {
                              widget.onToggleManualRouteMode?.call();
                            } else {
                              _animateSheetTo(_minSize);
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: widget.isManualRouteMode
                                  ? AppColors.neonCyan
                                  : AppColors.neonCyan.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.neonCyan.withValues(alpha: 0.6),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_location_alt_rounded,
                                  size: 12,
                                  color: widget.isManualRouteMode
                                      ? Colors.black
                                      : AppColors.neonCyan,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '+ NO MAPA',
                                  style: TextStyle(
                                    color: widget.isManualRouteMode
                                        ? Colors.black
                                        : AppColors.neonCyan,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      // Botão para abrir o configurador de KM e Bares rapidamente
                      InkWell(
                        onTap: () =>
                            setState(() => _showConfigOverRoute = true),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.neonCyan.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.neonCyan.withValues(alpha: 0.5),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.tune_rounded,
                                size: 12,
                                color: AppColors.neonCyan,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'KM / BARES',
                                style: TextStyle(
                                  color: AppColors.neonCyan,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: widget.onResetRoute,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.alertRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.alertRed.withValues(alpha: 0.45),
                            ),
                          ),
                          child: const Text(
                            'LIMPAR',
                            style: TextStyle(
                              color: AppColors.alertRed,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              for (int i = 0; i < route.bars.length; i++)
                BarCardItem(
                  bar: route.bars[i],
                  isSwapping: widget.swappingBarIndex == i,
                  isSelected: widget.selectedBarIndex == i,
                  isLast: i == route.bars.length - 1,
                  onTap: () => widget.onSelectBar?.call(i),
                  onSwap: () => widget.onSwapBar(i),
                  onRemove: widget.onRemoveBar != null
                      ? () => widget.onRemoveBar!(i)
                      : null,
                ),
            ],
          ),
        ),

        // Botão único para Registrar e deixar a Rota Salva (sem iniciar corrida aqui)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: NeonButton(
            label: widget.isRouteRegistered
                ? 'ROTA REGISTRADA E SALVA ✓ (${route.totalDistanceKmFormatted.toUpperCase()})'
                : 'REGISTRAR ROTA (${route.totalDistanceKmFormatted.toUpperCase()} • ${route.totalBars} BARES)',
            icon: widget.isRouteRegistered
                ? Icons.check_circle_rounded
                : Icons.bookmark_added_rounded,
            borderRadius: 28,
            height: 54,
            color: AppColors.cyberGreen,
            glowColor: AppColors.cyberGreenGlow,
            gradient: AppColors.cyberGreenGradient,
            textColor: Colors.black,
            onPressed: widget.onRegisterRoute,
          ),
        ),
      ],
    );
  }
}
