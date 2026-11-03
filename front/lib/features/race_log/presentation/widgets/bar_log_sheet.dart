import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../../route_finder/domain/entities/bar.dart';
import '../../domain/entities/bar_log_entry.dart';

/// Folha inferior minimalista para anotar o gasto e o tempo de corrida de uma parada
class BarLogSheet extends StatefulWidget {
  final Bar bar;
  final int order;
  final BarLogEntry? existing;
  final void Function(double spentBrl, int runSeconds) onSave;
  final VoidCallback? onRemove;

  const BarLogSheet({
    super.key,
    required this.bar,
    required this.order,
    required this.onSave,
    this.existing,
    this.onRemove,
  });

  static Future<void> show(
    BuildContext context, {
    required Bar bar,
    required int order,
    BarLogEntry? existing,
    required void Function(double spentBrl, int runSeconds) onSave,
    VoidCallback? onRemove,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141419),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => BarLogSheet(
        bar: bar,
        order: order,
        existing: existing,
        onSave: onSave,
        onRemove: onRemove,
      ),
    );
  }

  @override
  State<BarLogSheet> createState() => _BarLogSheetState();
}

class _BarLogSheetState extends State<BarLogSheet> {
  late final TextEditingController _spentCtrl;
  late final TextEditingController _minCtrl;
  late final TextEditingController _secCtrl;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _spentCtrl = TextEditingController(
      text: e == null
          ? ''
          : e.spentBrl.toStringAsFixed(2).replaceAll('.', ','),
    );
    _minCtrl = TextEditingController(
      text: e == null ? '' : (e.runSeconds ~/ 60).toString(),
    );
    _secCtrl = TextEditingController(
      text: e == null ? '' : (e.runSeconds % 60).toString().padLeft(2, '0'),
    );
  }

  @override
  void dispose() {
    _spentCtrl.dispose();
    _minCtrl.dispose();
    _secCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final spent = RaceLogFormat.parseBrl(_spentCtrl.text) ?? 0.0;
    final minutes = int.tryParse(_minCtrl.text.trim()) ?? 0;
    final seconds = (int.tryParse(_secCtrl.text.trim()) ?? 0).clamp(0, 59);
    widget.onSave(spent, minutes * 60 + seconds);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(22, 12, 22, 22 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A48),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'PARADA ${widget.order.toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: AppColors.neonOrange,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.bar.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 24),

          const _FieldLabel('GASTO NO BAR'),
          const SizedBox(height: 8),
          _InputBox(
            child: Row(
              children: [
                const Text(
                  'R\$',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _spentCtrl,
                    autofocus: widget.existing == null,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                    cursorColor: AppColors.neonOrange,
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: '0,00',
                      hintStyle: TextStyle(color: Color(0xFF3A3A48)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          const _FieldLabel('TEMPO DE CORRIDA ATÉ AQUI'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _TimeField(controller: _minCtrl, caption: 'min'),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  ':',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Expanded(
                child: _TimeField(
                  controller: _secCtrl,
                  caption: 'seg',
                  maxLength: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),

          NeonButton(
            label: 'SALVAR',
            icon: Icons.check_rounded,
            borderRadius: 28,
            height: 54,
            color: AppColors.cyberGreen,
            glowColor: AppColors.cyberGreenGlow,
            gradient: AppColors.cyberGreenGradient,
            textColor: Colors.black,
            onPressed: _save,
          ),
          if (widget.existing != null && widget.onRemove != null) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: () {
                widget.onRemove!();
                Navigator.of(context).pop();
              },
              child: const Text(
                'Remover anotação',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
      ),
    );
  }
}

class _InputBox extends StatelessWidget {
  final Widget child;
  const _InputBox({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: child,
    );
  }
}

class _TimeField extends StatelessWidget {
  final TextEditingController controller;
  final String caption;
  final int maxLength;

  const _TimeField({
    required this.controller,
    required this.caption,
    this.maxLength = 3,
  });

  @override
  Widget build(BuildContext context) {
    return _InputBox(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(maxLength),
              ],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
              cursorColor: AppColors.neonOrange,
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: '00',
                hintStyle: TextStyle(color: Color(0xFF3A3A48)),
              ),
            ),
          ),
          Text(
            caption,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
