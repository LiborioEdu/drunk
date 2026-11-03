import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../route_finder/domain/entities/bar.dart';
import '../../../route_finder/presentation/controllers/route_finder_controller.dart';
import '../../domain/entities/bar_log_entry.dart';
import '../controllers/race_log_controller.dart';
import '../widgets/bar_log_sheet.dart';

/// Aba ANOTAR (ícone de lápis): lista os bares da rota registrada em ordem
/// e permite anotar o gasto e o tempo de corrida em cada parada.
class RaceLogView extends ConsumerStatefulWidget {
  final VoidCallback onGoToRoute;

  const RaceLogView({super.key, required this.onGoToRoute});

  @override
  ConsumerState<RaceLogView> createState() => _RaceLogViewState();
}

class _RaceLogViewState extends ConsumerState<RaceLogView> {
  String? _syncedRouteKey;

  void _openBar(Bar bar, int order, BarLogEntry? existing) {
    final notifier = ref.read(raceLogProvider.notifier);
    BarLogSheet.show(
      context,
      bar: bar,
      order: order,
      existing: existing,
      onSave: (spent, seconds) => notifier.saveEntry(
        barId: bar.id,
        spentBrl: spent,
        runSeconds: seconds,
      ),
      onRemove: () => notifier.removeEntry(bar.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final routeState = ref.watch(routeFinderProvider);
    final route = routeState.isRouteRegistered ? routeState.route : null;

    if (route == null || route.bars.isEmpty) {
      return _EmptyState(onGoToRoute: widget.onGoToRoute);
    }

    final routeKey =
        RaceLogNotifier.routeKeyFor(route.bars.map((b) => b.id));
    if (_syncedRouteKey != routeKey) {
      _syncedRouteKey = routeKey;
      Future.microtask(
        () => ref.read(raceLogProvider.notifier).syncRoute(routeKey),
      );
    }

    final log = ref.watch(raceLogProvider);
    final entries =
        log.routeKey == routeKey ? log.entries : const <String, BarLogEntry>{};
    final doneCount = route.bars.where((b) => entries.containsKey(b.id)).length;
    final totalSpent = entries.values.fold(0.0, (s, e) => s + e.spentBrl);
    final totalSeconds = entries.values.fold(0, (s, e) => s + e.runSeconds);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          // Cabeçalho enxuto
          const Text(
            'ANOTAÇÕES',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${route.totalDistanceKmFormatted} • ${route.totalBars} paradas',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),

          // Resumo em 3 números
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0x14FFFFFF)),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  _SummaryStat(
                    value: RaceLogFormat.brl(totalSpent),
                    label: 'GASTO',
                    color: AppColors.neonOrange,
                  ),
                  const VerticalDivider(color: Color(0x1AFFFFFF), width: 1),
                  _SummaryStat(
                    value: RaceLogFormat.runTime(totalSeconds),
                    label: 'TEMPO',
                    color: Colors.white,
                  ),
                  const VerticalDivider(color: Color(0x1AFFFFFF), width: 1),
                  _SummaryStat(
                    value: '$doneCount/${route.totalBars}',
                    label: 'BARES',
                    color: AppColors.cyberGreen,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Lista de paradas em ordem
          for (int i = 0; i < route.bars.length; i++)
            _BarLogTile(
              order: i + 1,
              bar: route.bars[i],
              entry: entries[route.bars[i].id],
              isLast: i == route.bars.length - 1,
              onTap: () => _openBar(
                route.bars[i],
                i + 1,
                entries[route.bars[i].id],
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _SummaryStat({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Item da linha do tempo: número da parada + nome do bar + anotação (se houver)
class _BarLogTile extends StatelessWidget {
  final int order;
  final Bar bar;
  final BarLogEntry? entry;
  final bool isLast;
  final VoidCallback onTap;

  const _BarLogTile({
    required this.order,
    required this.bar,
    required this.entry,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = entry != null;
    final accent = isDone ? AppColors.cyberGreen : AppColors.neonOrange;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Trilho vertical com o marcador da parada
          SizedBox(
            width: 38,
            child: Column(
              children: [
                const SizedBox(height: 18),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isDone ? AppColors.cyberGreen : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: accent, width: 1.8),
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(
                            Icons.check_rounded,
                            size: 17,
                            color: Colors.black,
                          )
                        : Text(
                            order.toString().padLeft(2, '0'),
                            style: TextStyle(
                              color: accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.6,
                      margin: const EdgeInsets.only(top: 4),
                      color: isDone
                          ? AppColors.cyberGreen.withValues(alpha: 0.45)
                          : const Color(0x1FFFFFFF),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Card clicável do bar
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDone
                            ? AppColors.cyberGreen.withValues(alpha: 0.28)
                            : const Color(0x12FFFFFF),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                bar.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              isDone
                                  ? Text(
                                      '${RaceLogFormat.brl(entry!.spentBrl)}   ·   ${RaceLogFormat.runTime(entry!.runSeconds)}',
                                      style: const TextStyle(
                                        color: AppColors.cyberGreen,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    )
                                  : const Text(
                                      'Toque para anotar',
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ],
                          ),
                        ),
                        Icon(
                          isDone ? Icons.edit_rounded : Icons.add_rounded,
                          size: 18,
                          color: isDone
                              ? AppColors.textSecondary
                              : AppColors.neonOrange,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onGoToRoute;
  const _EmptyState({required this.onGoToRoute});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.neonOrange.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: AppColors.neonOrange,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Nenhuma rota registrada',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Registre uma rota na aba ROTA para anotar\nos gastos e tempos em cada bar.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              OutlinedButton.icon(
                onPressed: onGoToRoute,
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  side: const BorderSide(color: AppColors.neonOrange),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                icon: const Icon(
                  Icons.route_rounded,
                  color: AppColors.neonOrange,
                  size: 18,
                ),
                label: const Text(
                  'IR PARA ROTA',
                  style: TextStyle(
                    color: AppColors.neonOrange,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
