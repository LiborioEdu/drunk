import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/haversine_calculator.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../../race_hud/domain/entities/race_session.dart';
import '../../../route_finder/domain/entities/bar.dart';
import '../../domain/entities/bar_checkin_record.dart';

/// Resultado retornado pelo Modal de Check-in e Comanda Financeira (Tela 3)
class CheckInComandaInput {
  final double spentBrl;
  final DrinkCategory category;

  const CheckInComandaInput({
    required this.spentBrl,
    required this.category,
  });
}

/// Tela 3 (Stitch `03_checkin_comanda`): Gaveta Cyberpunk acionada quando Haversine <= 20m
class CheckInComandaSheet extends StatefulWidget {
  final RaceSession session;
  final Bar bar;

  const CheckInComandaSheet({
    super.key,
    required this.session,
    required this.bar,
  });

  static Future<CheckInComandaInput?> show(
    BuildContext context, {
    required RaceSession session,
    required Bar bar,
  }) {
    return showModalBottomSheet<CheckInComandaInput>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CheckInComandaSheet(session: session, bar: bar),
    );
  }

  @override
  State<CheckInComandaSheet> createState() => _CheckInComandaSheetState();
}

class _CheckInComandaSheetState extends State<CheckInComandaSheet> {
  late final TextEditingController _amountController;
  DrinkCategory _selectedCategory = DrinkCategory.chopp;
  double _currentAmount = 25.0;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: '25,00');
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _setAmount(double newAmount) {
    final clamped = newAmount.clamp(0.0, 9999.0);
    setState(() {
      _currentAmount = clamped;
      _amountController.text = clamped.toStringAsFixed(2).replaceAll('.', ',');
      _amountController.selection = TextSelection.fromPosition(
        TextPosition(offset: _amountController.text.length),
      );
    });
  }

  void _addQuickAmount(double delta) {
    _setAmount(_currentAmount + delta);
  }

  void _onManualChanged(String raw) {
    final normalized = raw
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .replaceAll(',', '.');
    final parsed = double.tryParse(normalized);
    setState(() {
      _currentAmount = (parsed ?? 0.0).clamp(0.0, 9999.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final bar = widget.bar;
    final barOrder =
        bar.order > 0 ? bar.order : (session.completedBarsCount + 1);
    final orderLabel = barOrder.toString().padLeft(2, '0');
    final nextOrderLabel = (barOrder + 1).toString().padLeft(2, '0');
    final isFinalBar = barOrder >= session.totalBarsCount;
    final distMeters = session.distanceToTargetMeters.round();
    final previousTotal = session.totalSpentBrl;
    final nextTotal = previousTotal + _currentAmount;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(
              color: AppColors.cyberGreen.withValues(alpha: 0.65),
              width: 1.8,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.85),
              blurRadius: 32,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Pill
              Center(
                child: Container(
                  width: 46,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Banner Geofence Validado
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cyberGreen.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.cyberGreen.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: AppColors.cyberGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.black,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'GEOFENCE VALIDADO (${distMeters}M) • CHECK-IN #$orderLabel CONCLUÍDO',
                        style: const TextStyle(
                          color: AppColors.cyberGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Text(
                        'STOP\n#$orderLabel',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Nome do Bar e Metadados do Trecho
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      bar.name.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cyberGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.cyberGreen.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          color: AppColors.cyberGreen,
                          size: 13,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'CONFIRMADO',
                          style: TextStyle(
                            color: AppColors.cyberGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'PARADA $orderLabel/${session.totalBarsCount.toString().padLeft(2, '0')} • '
                    'TRECHO: +${HaversineCalculator.formatDistance(bar.distanceFromPrevious)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    '• TEMPO: ${session.elapsedFormatted}',
                    style: const TextStyle(
                      color: AppColors.neonCyan,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Container Principal de Valor da Comanda
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.neonOrange.withValues(alpha: 0.55),
                    width: 1.3,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.receipt_long_rounded,
                              color: AppColors.neonOrange,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'QUANTO VOCÊ GASTOU NESTE BAR?',
                              style: TextStyle(
                                color: AppColors.neonOrange,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'PARADA $orderLabel',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'R\$ ',
                          style: AppTextStyles.currencyGiant.copyWith(
                            color: AppColors.neonOrange,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]'),
                              ),
                            ],
                            cursorColor: AppColors.neonOrange,
                            cursorWidth: 3,
                            style: AppTextStyles.currencyGiant,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: '0,00',
                              hintStyle: TextStyle(color: AppColors.textMuted),
                            ),
                            onChanged: _onManualChanged,
                          ),
                        ),
                        const Text(
                          'VALOR GASTO',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: AppColors.glassBorder, height: 18),
                    // Chips rápidos (+ R$ 15, + R$ 25, + R$ 50, R$ 0 Água)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _QuickAmountChip(
                          label: '+ R\$ 15',
                          isSelected: (_currentAmount - 15.0).abs() < 0.01,
                          onTap: () => _setAmount(15.0),
                          onLongPress: () => _addQuickAmount(15.0),
                        ),
                        _QuickAmountChip(
                          label: '+ R\$ 25',
                          isSelected: (_currentAmount - 25.0).abs() < 0.01,
                          onTap: () => _setAmount(25.0),
                          onLongPress: () => _addQuickAmount(25.0),
                        ),
                        _QuickAmountChip(
                          label: '+ R\$ 50',
                          isSelected: (_currentAmount - 50.0).abs() < 0.01,
                          onTap: () => _setAmount(50.0),
                          onLongPress: () => _addQuickAmount(50.0),
                        ),
                        _QuickAmountChip(
                          label: 'R\$ 0 (Água)',
                          isSelected: _currentAmount == 0.0,
                          onTap: () {
                            _setAmount(0.0);
                            setState(() {
                              _selectedCategory = DrinkCategory.water;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Categoria de Consumo (Grid 2x2)
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CATEGORIA DE CONSUMO',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.9,
                    ),
                  ),
                  Text(
                    '1 SELECIONADO',
                    style: TextStyle(
                      color: AppColors.neonCyan,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.55,
                children: [
                  for (final cat in DrinkCategory.values)
                    _CategoryTile(
                      category: cat,
                      isSelected: _selectedCategory == cat,
                      onTap: () => setState(() => _selectedCategory = cat),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Resumo Acumulado da Corrida
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'ANTERIOR: ${RaceSession.formatBrl(previousTotal)}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.cyberGreen,
                      size: 16,
                    ),
                    Flexible(
                      child: Text(
                        'NOVO TOTAL: ${RaceSession.formatBrl(nextTotal)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: AppColors.cyberGreen,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Botão Principal Laranja Neon
              NeonButton(
                label: isFinalBar
                    ? 'SALVAR E FINALIZAR 10KM (WRAPPED)'
                    : 'SALVAR COMANDA E LIBERAR BAR #$nextOrderLabel',
                icon: isFinalBar
                    ? Icons.emoji_events_rounded
                    : Icons.lock_open_rounded,
                gradient: AppColors.neonOrangeGradient,
                color: AppColors.neonOrange,
                glowColor: AppColors.neonOrangeGlow,
                textColor: Colors.black,
                onPressed: () {
                  Navigator.of(context).pop(
                    CheckInComandaInput(
                      spentBrl: _currentAmount,
                      category: _selectedCategory,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAmountChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _QuickAmountChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.neonOrange.withValues(alpha: 0.20)
              : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.neonOrange : AppColors.glassBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.neonOrange : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final DrinkCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = category == DrinkCategory.water
        ? AppColors.neonCyan
        : AppColors.neonOrange;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.16)
              : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? accent : AppColors.glassBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              category.icon,
              color: isSelected ? accent : AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? accent : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    category.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: category == DrinkCategory.water
                          ? AppColors.neonCyan
                          : AppColors.textMuted,
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
    );
  }
}
