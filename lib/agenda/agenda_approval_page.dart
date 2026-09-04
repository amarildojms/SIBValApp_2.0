import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/agenda_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../data/recurring_agenda_entry_repository.dart';
import '../data/user_repository.dart';
import '../events/recurring_event_utils.dart' show weekdayLabel;
import '../models/agenda_entry.dart';
import '../models/notification.dart';
import '../models/recurring_agenda_entry.dart';
import '../models/recurring_event.dart' show eventDurationLabel;
import '../notifications/notification_read_sync.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'agenda_entry_form_page.dart';

/// Sem equivalente no app nativo — feature nova (03/09/2026, pedido do
/// usuário: "todo compromisso antes de ser efetivado no calendário deverá ir
/// para aprovação"). Três abas: quem está em `isAgendaApproverProvider` vê
/// "Para aprovar" (compromissos avulsos + séries recorrentes pendentes, de
/// qualquer ministério) e "Séries recorrentes" (séries já aprovadas, com
/// opção de desativar); qualquer um vê "Minhas solicitações" (o que criou e
/// ainda não foi efetivado, foi rejeitado, cancelado ou precisa de nova
/// data). Aberta por um ícone na app bar de `AgendaPage`.
class AgendaApprovalPage extends ConsumerStatefulWidget {
  const AgendaApprovalPage({super.key});

  @override
  ConsumerState<AgendaApprovalPage> createState() => _AgendaApprovalPageState();
}

class _AgendaApprovalPageState extends ConsumerState<AgendaApprovalPage> {
  @override
  void initState() {
    super.initState();
    for (final type in const [
      NotificationType.agendaEntryPending,
      NotificationType.agendaEntryApproved,
      NotificationType.agendaEntryRejected,
      NotificationType.agendaEntryCancelled,
      NotificationType.agendaEntryRescheduled,
      NotificationType.agendaEntryRescheduleRequested,
      NotificationType.recurringAgendaEntryPending,
      NotificationType.recurringAgendaEntryApproved,
      NotificationType.recurringAgendaEntryRejected,
    ]) {
      syncNotificationsForScreen(ref, type: type);
    }
  }

  Future<void> _approve(AgendaEntry entry) async {
    final profile = ref.read(currentUserProfileProvider).asData?.value;
    final uid = ref.read(currentUidProvider) ?? '';
    try {
      await ref.read(agendaRepositoryProvider).approve(
            entry.id,
            approverUid: uid,
            approverName: profile?.shortName ?? '',
          );
    } catch (e) {
      _showError('Falha ao aprovar: $e');
    }
  }

  Future<void> _reject(AgendaEntry entry) async {
    final reason = await _askReason('Rejeitar compromisso');
    if (reason == null) return;
    final profile = ref.read(currentUserProfileProvider).asData?.value;
    final uid = ref.read(currentUidProvider) ?? '';
    try {
      await ref.read(agendaRepositoryProvider).reject(
            entry.id,
            reason: reason,
            approverUid: uid,
            approverName: profile?.shortName ?? '',
          );
    } catch (e) {
      _showError('Falha ao rejeitar: $e');
    }
  }

  Future<void> _delete(AgendaEntry entry) async {
    final confirmed = await _confirm('Excluir solicitação', 'Excluir "${entry.title}"?', 'Excluir');
    if (confirmed != true) return;
    try {
      await ref.read(agendaRepositoryProvider).delete(entry.id);
    } catch (e) {
      _showError('Falha ao excluir: $e');
    }
  }

  Future<void> _approveRecurring(RecurringAgendaEntry entry) async {
    final profile = ref.read(currentUserProfileProvider).asData?.value;
    final uid = ref.read(currentUidProvider) ?? '';
    try {
      await ref.read(recurringAgendaEntryRepositoryProvider).approve(
            entry.id,
            approverUid: uid,
            approverName: profile?.shortName ?? '',
          );
    } catch (e) {
      _showError('Falha ao aprovar: $e');
    }
  }

  Future<void> _rejectRecurring(RecurringAgendaEntry entry) async {
    final reason = await _askReason('Rejeitar série recorrente');
    if (reason == null) return;
    final profile = ref.read(currentUserProfileProvider).asData?.value;
    final uid = ref.read(currentUidProvider) ?? '';
    try {
      await ref.read(recurringAgendaEntryRepositoryProvider).reject(
            entry.id,
            reason: reason,
            approverUid: uid,
            approverName: profile?.shortName ?? '',
          );
    } catch (e) {
      _showError('Falha ao rejeitar: $e');
    }
  }

  /// Mesma escolha "toda a série" vs "só a próxima data" já usada em
  /// eventos recorrentes (`recurring_event_list_page.dart`,
  /// `_onActiveChanged`) — 03/09/2026, 4ª rodada, pedido do usuário: "em
  /// agendamentos recorrentes, vamos manter a mesma ideia dos eventos, o
  /// admin tem a opção de desativar toda a série ou somente para a próxima
  /// data". Antes só existia o caminho "toda a série" aqui, mesmo o
  /// repositório já tendo `cancelNextOccurrenceOnly` pronto (usado só pelo
  /// remanejamento/cancelamento de uma instância avulsa já publicada).
  Future<void> _deactivateRecurring(RecurringAgendaEntry entry) async {
    final choice = await showDialog<_DeactivateChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Desativar série recorrente'),
        content: Text(
          'Desativar "${entry.title}": toda a série (para de gerar novas ocorrências e '
          'cancela a próxima já gerada) ou só a próxima data (a série continua ativa nas '
          'semanas seguintes)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(_DeactivateChoice.nextOnly),
            child: const Text('Só a próxima data'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(_DeactivateChoice.fullSeries),
            child: const Text('Toda a série'),
          ),
        ],
      ),
    );
    if (choice == null) return;
    try {
      final repo = ref.read(recurringAgendaEntryRepositoryProvider);
      switch (choice) {
        case _DeactivateChoice.fullSeries:
          await repo.deactivateSeries(entry.id);
        case _DeactivateChoice.nextOnly:
          await repo.cancelNextOccurrenceOnly(entry.id);
      }
    } catch (e) {
      _showError('Falha ao desativar: $e');
    }
  }

  Future<String?> _askReason(String title) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Justificativa'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.of(dialogContext).pop(text);
            },
            child: const Text('Rejeitar'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirm(String title, String message, String confirmLabel) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isApprover = ref.watch(isAgendaApproverProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: const SibValAppBar(isHome: false),
        body: SafeArea(
          bottom: true,
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ScreenTitle('Solicitações'),
              const TabBar(
                isScrollable: true,
                labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                tabs: [
                  Tab(text: 'Para aprovar'),
                  Tab(text: 'Séries recorrentes'),
                  Tab(text: 'Minhas solicitações'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    isApprover
                        ? _ApprovalTab(
                            onApprove: _approve,
                            onReject: _reject,
                            onApproveRecurring: _approveRecurring,
                            onRejectRecurring: _rejectRecurring,
                          )
                        : _NotApproverMessage(),
                    isApprover
                        ? _RecurringSeriesTab(onDeactivate: _deactivateRecurring)
                        : _NotApproverMessage(),
                    _MyRequestsTab(onDelete: _delete),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotApproverMessage extends StatelessWidget {
  const _NotApproverMessage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Você não é aprovador de compromissos da Agenda.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.textSecondary),
        ),
      ),
    );
  }
}

class _ApprovalTab extends ConsumerWidget {
  const _ApprovalTab({
    required this.onApprove,
    required this.onReject,
    required this.onApproveRecurring,
    required this.onRejectRecurring,
  });

  final ValueChanged<AgendaEntry> onApprove;
  final ValueChanged<AgendaEntry> onReject;
  final ValueChanged<RecurringAgendaEntry> onApproveRecurring;
  final ValueChanged<RecurringAgendaEntry> onRejectRecurring;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingAgendaApprovalProvider);
    final pendingRecurring = ref.watch(pendingRecurringAgendaEntriesProvider);
    if (pending.isEmpty && pendingRecurring.isEmpty) {
      return Center(
        child: Text('Nenhum compromisso aguardando aprovação.', style: TextStyle(color: context.textSecondary)),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final entry in pendingRecurring)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.repeat, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(entry.title, style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(_recurringSummary(entry), style: TextStyle(color: context.textSecondary, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Solicitado por ${entry.createdByName}', style: TextStyle(color: context.textSecondary, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(onPressed: () => onRejectRecurring(entry), child: const Text('Rejeitar')),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(onPressed: () => onApproveRecurring(entry), child: const Text('Aprovar')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        for (final entry in pending)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.title, style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(_summary(entry), style: TextStyle(color: context.textSecondary, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Solicitado por ${entry.createdByName}', style: TextStyle(color: context.textSecondary, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(onPressed: () => onReject(entry), child: const Text('Rejeitar')),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(onPressed: () => onApprove(entry), child: const Text('Aprovar')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _RecurringSeriesTab extends ConsumerWidget {
  const _RecurringSeriesTab({required this.onDeactivate});

  final ValueChanged<RecurringAgendaEntry> onDeactivate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeRecurringAgendaEntriesProvider);
    if (active.isEmpty) {
      return Center(
        child: Text('Nenhuma série recorrente ativa.', style: TextStyle(color: context.textSecondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: active.length,
      itemBuilder: (context, index) {
        final entry = active[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title, style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(_recurringSummary(entry), style: TextStyle(color: context.textSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    onPressed: () => onDeactivate(entry),
                    child: const Text('Desativar série'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MyRequestsTab extends ConsumerWidget {
  const _MyRequestsTab({required this.onDelete});

  final ValueChanged<AgendaEntry> onDelete;

  static const _statusLabels = {
    AgendaEntryStatus.pending: 'Aguardando',
    AgendaEntryStatus.rejected: 'Rejeitado',
    AgendaEntryStatus.cancelled: 'Cancelado',
    AgendaEntryStatus.needsReschedule: 'Precisa remarcar',
  };

  Color _statusColor(String status) => switch (status) {
    AgendaEntryStatus.rejected || AgendaEntryStatus.cancelled => Colors.red.withValues(alpha: 0.15),
    AgendaEntryStatus.needsReschedule => Colors.orange.withValues(alpha: 0.2),
    _ => SibValColors.goldAccent.withValues(alpha: 0.15),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myAgendaRequestsProvider);
    if (mine.isEmpty) {
      return Center(
        child: Text('Nenhuma solicitação pendente, rejeitada ou cancelada.', style: TextStyle(color: context.textSecondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: mine.length,
      itemBuilder: (context, index) {
        final entry = mine[index];
        final canEdit = entry.status == AgendaEntryStatus.rejected ||
            entry.status == AgendaEntryStatus.needsReschedule;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(entry.title, style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
                    ),
                    Chip(
                      label: Text(_statusLabels[entry.status] ?? entry.status),
                      backgroundColor: _statusColor(entry.status),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(_summary(entry), style: TextStyle(color: context.textSecondary, fontSize: 13)),
                if (entry.status == AgendaEntryStatus.rejected && entry.rejectionReason.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Justificativa: ${entry.rejectionReason}', style: TextStyle(color: context.textPrimary, fontSize: 13)),
                ],
                if (entry.status == AgendaEntryStatus.needsReschedule && entry.rescheduleMessage.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Justificativa: ${entry.rescheduleMessage}', style: TextStyle(color: context.textPrimary, fontSize: 13)),
                ],
                if (entry.status == AgendaEntryStatus.cancelled && entry.cancelReason.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Justificativa: ${entry.cancelReason}', style: TextStyle(color: context.textPrimary, fontSize: 13)),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (canEdit)
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => AgendaEntryFormPage(editing: entry)),
                        ),
                        child: const Text('Editar'),
                      ),
                    TextButton(onPressed: () => onDelete(entry), child: const Text('Excluir')),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _summary(AgendaEntry entry) {
  final dateFormat = DateFormat('EEE, dd/MM', 'pt_BR');
  final timeFormat = DateFormat('HH:mm', 'pt_BR');
  return '${entry.displayAudience} · ${dateFormat.format(entry.startDateTime)} · '
      '${timeFormat.format(entry.startDateTime)} às ${timeFormat.format(entry.endDateTime)} · ${entry.location}';
}

String _recurringSummary(RecurringAgendaEntry entry) {
  final timeLabel =
      '${entry.hour.toString().padLeft(2, '0')}:${entry.minute.toString().padLeft(2, '0')}';
  return '${entry.displayAudience} · Toda ${weekdayLabel(entry.weekday)} às $timeLabel '
      '(${eventDurationLabel(entry.durationMinutes)}) · ${entry.location}';
}

enum _DeactivateChoice { fullSeries, nextOnly }
