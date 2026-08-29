import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/leader_schedule_repository.dart';
import '../data/user_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'leader_schedule_form_page.dart';

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário). Aberta pelo menu ☰ dentro de "Ordem de Culto"
/// (`ServiceOrderListPage`) — Escala de Dirigentes: lista as datas já
/// planejadas (`leaderSchedulesProvider`, mais próxima primeiro). Pastor/
/// admin (`canManageLeaderSchedule`) tem FAB "Nova Escala" e edita ao tocar;
/// Dirigentes só visualiza (`LeaderScheduleFormPage(readOnly: true)`).
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
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.event_note_outlined),
                          title: Text(
                            _dateFormat.format(entry.dateTime),
                            style: TextStyle(color: context.textPrimary),
                          ),
                          subtitle: Text(
                            entry.theme.isEmpty
                                ? 'Dirigente: ${entry.leaderName}'
                                : 'Dirigente: ${entry.leaderName} · Tema: ${entry.theme}',
                            style: TextStyle(color: context.textSecondary),
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LeaderScheduleFormPage(
                                editing: entry,
                                readOnly: !canManage,
                              ),
                            ),
                          ),
                        ),
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
}
