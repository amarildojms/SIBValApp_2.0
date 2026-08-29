import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/leader_schedule_repository.dart';
import '../data/user_repository.dart';
import '../models/leader_schedule.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'leader_schedule_form_page.dart';

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário). Aberta pelo menu ☰ dentro de "Ordem de Culto"
/// (`ServiceOrderListPage`) — Escala de Dirigentes: lista as datas já
/// planejadas (`leaderSchedulesProvider`, mais próxima primeiro). Pastor/
/// admin (`canManageLeaderSchedule`) tem FAB "Nova Escala".
///
/// **Revisão de 28/08/2026, mesma sessão** — editar/excluir viraram um menu
/// de toque longo (`_showActions`), disponível só pra quem tem
/// `canManageLeaderSchedule`. A lixeira que ficava dentro do formulário de
/// edição saiu — excluir agora só a partir desta lista.
///
/// **Revisão de 29/08/2026** — lista virou uma linha do tempo
/// (`_ScheduleTimelineTile`, pedido do usuário: "formato de cards/linha de
/// tempo") — um trilho vertical com uma bolha de data por entrada, ligado
/// por uma linha contínua entre elas, e um card ao lado com dia da semana,
/// dirigente e tema. **Mesma revisão**: o toque simples (que abria
/// `LeaderScheduleFormPage(readOnly: true)`) foi removido — pedido do
/// usuário: "não faz sentido já que na linha de tempo já se vê todas as
/// informações". Só sobrou o toque longo (editar/excluir), exclusivo de quem
/// gerencia; quem só visualiza (Dirigentes) não tem mais nenhuma interação
/// no card, só lê o que já está na linha do tempo.
class LeaderScheduleListPage extends ConsumerWidget {
  const LeaderScheduleListPage({super.key});

  static final _dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(leaderSchedulesProvider);
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final canManage = profile?.canManageLeaderSchedule ?? false;

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              heroTag: 'leader_schedule_new_fab',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const LeaderScheduleFormPage(),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Nova Escala'),
            )
          : null,
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Escala de Dirigentes'),
            Expanded(
              child: entriesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text(
                    'Falha ao carregar: $error',
                    style: TextStyle(color: context.textPrimary),
                  ),
                ),
                data: (entries) {
                  if (entries.isEmpty) {
                    return Center(
                      child: Text(
                        'Nenhuma escala cadastrada ainda.',
                        style: TextStyle(color: context.textSecondary),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _ScheduleTimelineTile(
                        entry: entry,
                        isFirst: index == 0,
                        isLast: index == entries.length - 1,
                        onLongPress: canManage
                            ? () => _showActions(context, ref, entry)
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showActions(BuildContext context, WidgetRef ref, LeaderScheduleEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LeaderScheduleFormPage(editing: entry),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Excluir'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmDelete(context, ref, entry);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, LeaderScheduleEntry entry) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir escala'),
        content: Text(
          'Tem certeza que deseja excluir a escala de ${_dateFormat.format(entry.dateTime)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref.read(leaderScheduleRepositoryProvider).delete(entry.id);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}

String _capitalizeFirst(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Uma entrada da escala em formato de linha do tempo (29/08/2026, pedido do
/// usuário) — trilho vertical à esquerda (linha contínua entre bolhas de
/// data, cortada nas pontas via [isFirst]/[isLast]) e um card à direita com
/// dia da semana, dirigente e tema. Sem toque simples (removido na mesma
/// revisão — o card já mostra tudo) — só toque longo, exclusivo de quem
/// gerencia ([onLongPress] nulo pra quem só visualiza).
class _ScheduleTimelineTile extends StatelessWidget {
  const _ScheduleTimelineTile({
    required this.entry,
    required this.isFirst,
    required this.isLast,
    required this.onLongPress,
  });

  final LeaderScheduleEntry entry;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onLongPress;

  static final _weekdayFormat = DateFormat('EEEE', 'pt_BR');
  static final _monthAbbrevFormat = DateFormat('MMM', 'pt_BR');

  @override
  Widget build(BuildContext context) {
    final lineColor = Theme.of(context).colorScheme.outlineVariant;
    final weekday = _capitalizeFirst(_weekdayFormat.format(entry.dateTime));
    final monthAbbrev = _monthAbbrevFormat.format(entry.dateTime).replaceAll('.', '').toUpperCase();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 52,
            child: Column(
              children: [
                Expanded(
                  child: Container(width: 2, color: isFirst ? Colors.transparent : lineColor),
                ),
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: SibValColors.goldAccent.withValues(alpha: 0.12),
                    border: Border.all(color: SibValColors.goldAccent, width: 1.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${entry.dateTime.day}',
                        style: const TextStyle(
                          color: SibValColors.goldAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        monthAbbrev,
                        style: const TextStyle(
                          color: SibValColors.goldAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(width: 2, color: isLast ? Colors.transparent : lineColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 16),
              child: Card(
                margin: EdgeInsets.zero,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onLongPress: onLongPress,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          weekday,
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 16, color: SibValColors.goldAccent),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                entry.leaderName,
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (entry.theme.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            entry.theme,
                            style: TextStyle(color: context.textSecondary, fontSize: 13),
                          ),
                        ],
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
