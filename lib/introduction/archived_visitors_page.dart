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
            for (final entry in byDay.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(_dayHeader(entry.key), style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
              ),
              for (final visitor in entry.value)
                VisitorFullTile(
                  visitor: visitor,
                  onDelete: canDelete ? (id) => ref.read(visitorRepositoryProvider).deleteVisitor(id) : null,
                ),
            ],
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
            for (final entry in byDay.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(_dayHeader(entry.key), style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
              ),
              for (final summary in entry.value) VisitorSummaryTile(summary: summary),
            ],
          ],
        );
      },
    );
  }
}
