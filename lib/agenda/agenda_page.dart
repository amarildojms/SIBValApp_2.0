import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import '../data/agenda_repository.dart';
import '../data/ministry_repository.dart';
import '../data/user_repository.dart';
import '../models/agenda_entry.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'agenda_entry_form_page.dart';
import 'agenda_location_management_page.dart';

/// Agenda dos ministérios (03/09/2026, pedido do usuário, sem equivalente no
/// nativo) — líderes de cada ministério (`myLedMinistryIdsProvider`, ver
/// `MemberRepository.isLeaderCargo`) marcam ensaios/reuniões/eventos pro
/// próprio ministério; os demais membros do ministério (liderados,
/// `myMemberMinistryIdsProvider`) só visualizam. Admin vê tudo, mas —
/// revisão de 03/09/2026, pedido do usuário: "cada líder só pode marcar
/// horário para seus próprios ministérios" — **criar** um compromisso novo é
/// restrito a quem de fato lidera aquele ministério, mesmo pra admin (ver
/// `_creatableMinistryIds`); admin mantém só o privilégio de editar/excluir
/// qualquer compromisso já existente, pra fins de gerenciamento.
///
/// Virou um calendário de verdade (`SfCalendar`, pacote `syncfusion_flutter_calendar`,
/// escolha confirmada com o usuário) com troca Dia/Semana/Mês — antes era uma
/// lista simples ordenada por data.
class AgendaPage extends ConsumerStatefulWidget {
  const AgendaPage({super.key});

  @override
  ConsumerState<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends ConsumerState<AgendaPage> {
  CalendarView _view = CalendarView.week;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final isAdmin = profile?.isAdmin ?? false;
    final ministries = ref.watch(ministriesProvider).asData?.value ?? const [];
    final ledIds = ref.watch(myLedMinistryIdsProvider);
    final memberIds = ref.watch(myMemberMinistryIdsProvider);
    final entriesAsync = ref.watch(agendaEntriesProvider);

    // Criação de compromisso novo: só ministérios que o usuário de fato
    // lidera — admin não ganha bypass aqui (pedido explícito do usuário).
    final creatableIds = ledIds;
    // Editar/excluir um compromisso já existente: líder daquele ministério
    // ou admin (oversight/gerenciamento, mantido).
    final manageableIds = isAdmin
        ? ministries.map((m) => m.id).toSet()
        : ledIds;
    final visibleIds = isAdmin
        ? ministries.map((m) => m.id).toSet()
        : {...memberIds, ...ledIds};

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      floatingActionButton: creatableIds.isEmpty
          ? null
          : FloatingActionButton(
              heroTag: 'agenda_fab',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      AgendaEntryFormPage(manageableMinistryIds: creatableIds),
                ),
              ),
              child: const Icon(Icons.add),
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                const Expanded(child: ScreenTitle('Agenda')),
                if (isAdmin)
                  IconButton(
                    tooltip: 'Configurar locais',
                    icon: const Icon(Icons.place_outlined),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AgendaLocationManagementPage(),
                      ),
                    ),
                  ),
                SegmentedButton<CalendarView>(
                  segments: const [
                    ButtonSegment(value: CalendarView.day, label: Text('Dia')),
                    ButtonSegment(value: CalendarView.week, label: Text('Semana')),
                    ButtonSegment(value: CalendarView.month, label: Text('Mês')),
                  ],
                  selected: {_view},
                  onSelectionChanged: (selection) =>
                      setState(() => _view = selection.first),
                ),
              ],
            ),
          ),
          Expanded(
            child: visibleIds.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Você não participa de nenhum ministério ainda.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.textSecondary),
                      ),
                    ),
                  )
                : entriesAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(
                      child: Text(
                        'Falha ao carregar: $error',
                        style: TextStyle(color: context.textPrimary),
                      ),
                    ),
                    data: (all) {
                      final entries = all
                          .where((e) => visibleIds.contains(e.ministryId))
                          .toList();
                      return SfCalendar(
                        view: _view,
                        firstDayOfWeek: 7,
                        dataSource: _AgendaDataSource(entries),
                        todayHighlightColor: SibValColors.goldAccent,
                        headerStyle: CalendarHeaderStyle(
                          textStyle: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        monthViewSettings: const MonthViewSettings(
                          showAgenda: true,
                          appointmentDisplayMode:
                              MonthAppointmentDisplayMode.appointment,
                        ),
                        onTap: (details) {
                          final appointment = details.appointments?.isNotEmpty == true
                              ? details.appointments!.first
                              : null;
                          if (appointment is! Appointment) return;
                          final entry = entries.firstWhere(
                            (e) => e.id == appointment.id,
                          );
                          _showEntryDetail(
                            context,
                            entry,
                            canManage: manageableIds.contains(entry.ministryId),
                            manageableMinistryIds: manageableIds,
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

void _showEntryDetail(
  BuildContext context,
  AgendaEntry entry, {
  required bool canManage,
  required Set<String> manageableMinistryIds,
}) {
  final dateFormat = DateFormat('EEE, dd/MM', 'pt_BR');
  final timeFormat = DateFormat('HH:mm', 'pt_BR');
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => Consumer(
      builder: (sheetContext, ref, _) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.title,
              style: TextStyle(
                color: sheetContext.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${entry.ministryName} · ${dateFormat.format(entry.startDateTime)} · '
              '${timeFormat.format(entry.startDateTime)} às ${timeFormat.format(entry.endDateTime)}',
              style: TextStyle(color: sheetContext.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.place_outlined, size: 14, color: sheetContext.textSecondary),
                const SizedBox(width: 4),
                Text(entry.location, style: TextStyle(color: sheetContext.textSecondary, fontSize: 13)),
              ],
            ),
            if (entry.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(entry.description, style: TextStyle(color: sheetContext.textPrimary)),
            ],
            if (canManage) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AgendaEntryFormPage(
                              manageableMinistryIds: {
                                ...manageableMinistryIds,
                                entry.ministryId,
                              },
                              editing: entry,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Editar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: sheetContext,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Excluir compromisso'),
                            content: Text(
                              'Excluir "${entry.title}"? Essa ação não pode ser desfeita.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(dialogContext).pop(false),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(dialogContext).pop(true),
                                child: const Text('Excluir'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await ref.read(agendaRepositoryProvider).delete(entry.id);
                          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Excluir'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

/// Cor determinística por ministério — só pra distinguir visualmente vários
/// ministérios no mesmo calendário (útil sobretudo pro admin, que vê todos).
const _kMinistryColors = [
  Color(0xFFB68B00),
  Color(0xFF3F6FBF),
  Color(0xFF6B8E23),
  Color(0xFFB0413E),
  Color(0xFF7D5BA6),
  Color(0xFF3E8E8E),
];

Color _colorForMinistry(String ministryId) =>
    _kMinistryColors[ministryId.hashCode.abs() % _kMinistryColors.length];

class _AgendaDataSource extends CalendarDataSource {
  _AgendaDataSource(List<AgendaEntry> entries) {
    appointments = [
      for (final e in entries)
        Appointment(
          id: e.id,
          startTime: e.startDateTime,
          endTime: e.endDateTime,
          subject: '${e.title} (${e.ministryName})',
          location: e.location,
          notes: e.description,
          color: _colorForMinistry(e.ministryId),
        ),
    ];
  }
}
