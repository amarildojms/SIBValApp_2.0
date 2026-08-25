import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/user_repository.dart';
import '../data/visitor_repository.dart';
import '../models/event.dart' show toSaoPauloTime;
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'visitor_tiles.dart';

final _headerFormat = DateFormat('EEEE, dd/MM/yyyy', 'pt_BR');

String _dayHeader(DateTime day) {
  final label = _headerFormat.format(day);
  return label.isEmpty ? label : label[0].toUpperCase() + label.substring(1);
}

Map<DateTime, List<T>> _groupByDay<T>(List<T> items, DateTime? Function(T) createdAtOf) {
  final map = <DateTime, List<T>>{};
  for (final item in items) {
    final createdAt = createdAtOf(item);
    if (createdAt == null) continue;
    final day = toSaoPauloTime(createdAt.toUtc());
    final key = DateTime(day.year, day.month, day.day);
    map.putIfAbsent(key, () => []).add(item);
  }
  return map;
}

/// Sem equivalente no app nativo — feature nova (25/08/2026): visitantes de
/// dias anteriores a hoje (ver `Visitor.isFromToday`/`IntroductionPage`, que
/// só mostra os do dia), agrupados por data (pedido do usuário). Mesmas
/// regras de visibilidade/exclusão de `IntroductionPage` — Introdução/Pastor
/// veem dados completos (Introdução também apaga), Dirigentes só o resumo
/// sem telefone.
class ArchivedVisitorsPage extends ConsumerWidget {
  const ArchivedVisitorsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final canRegister = profile?.canRegisterVisitors ?? false;
    final canViewDetails = profile?.canViewVisitorDetails ?? false;
    final canReadFull = canRegister || canViewDetails;

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Visitantes arquivados'),
            Expanded(child: canReadFull ? _FullArchive(canDelete: canRegister) : const _SummaryArchive()),
          ],
        ),
      ),
    );
  }
}

class _FullArchive extends ConsumerWidget {
  const _FullArchive({required this.canDelete});

  final bool canDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitorsAsync = ref.watch(archivedVisitorsProvider);

    return visitorsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary))),
      data: (visitors) {
        if (visitors.isEmpty) {
          return Center(child: Text('Nenhum visitante arquivado ainda.', style: TextStyle(color: context.textSecondary)));
        }
        final byDay = _groupByDay(visitors, (v) => v.createdAt);
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            for (final entry in byDay.entries)
              _DayGroup(
                header: _dayHeader(entry.key),
                count: entry.value.length,
                children: [
                  for (final visitor in entry.value)
                    VisitorFullTile(
                      visitor: visitor,
                      onDelete: canDelete ? (id) => ref.read(visitorRepositoryProvider).deleteVisitor(id) : null,
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _SummaryArchive extends ConsumerWidget {
  const _SummaryArchive();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summariesAsync = ref.watch(archivedVisitorSummariesProvider);

    return summariesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary))),
      data: (summaries) {
        if (summaries.isEmpty) {
          return Center(child: Text('Nenhum visitante arquivado ainda.', style: TextStyle(color: context.textSecondary)));
        }
        final byDay = _groupByDay(summaries, (s) => s.createdAt);
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            for (final entry in byDay.entries)
              _DayGroup(
                header: _dayHeader(entry.key),
                count: entry.value.length,
                children: [for (final summary in entry.value) VisitorSummaryTile(summary: summary)],
              ),
          ],
        );
      },
    );
  }
}

/// Cada dia arquivado vira uma linha compacta (data + contagem), expandindo
/// só ao tocar — antes a lista mostrava todo mundo de todos os dias já de
/// cara, o que ficava longo demais pra navegar (pedido do usuário,
/// 25/08/2026). Fechado por padrão.
class _DayGroup extends StatelessWidget {
  const _DayGroup({required this.header, required this.count, required this.children});

  final String header;
  final int count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(header, style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
          subtitle: Text(
            count == 1 ? '1 visitante' : '$count visitantes',
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          children: children,
        ),
      ),
    );
  }
}
