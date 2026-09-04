import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import '../data/agenda_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../data/user_repository.dart';
import '../events/event_detail_page.dart';
import '../models/agenda_entry.dart';
import '../models/event.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'agenda_approval_page.dart';
import 'agenda_approvers_management_page.dart';
import 'agenda_entry_form_page.dart';
import 'agenda_location_management_page.dart';
import 'agenda_reschedule_sheet.dart';
import 'agenda_view_preference.dart';
import 'recurring_agenda_entry_form_page.dart';

/// Agenda dos ministérios (03/09/2026, pedido do usuário, sem equivalente no
/// nativo) — líderes de **qualquer** ministério (`myLedMinistryIdsProvider`,
/// ver `MemberRepository.isLeaderCargo`) marcam compromissos (avulsos ou
/// recorrentes) para um ou mais ministérios, ou para toda a igreja; todo
/// compromisso passa por aprovação (`AgendaApprovalPage`) antes de aparecer
/// aqui de verdade — só `status == approved` bloqueia o calendário e é
/// exibido. Eventos publicados (`lib/models/event.dart`,
/// `calendarEventsProvider`) entram automaticamente na mesma visualização,
/// sem uma segunda aprovação — inclusive já vencidos (03/09/2026, 2ª
/// rodada, pedido do usuário: evento passado só some da aba "Eventos", não
/// do calendário).
///
/// Layout inspirado no Outlook mobile — seletor de visualização em menu
/// (Agenda/Dia/Semana/Mês, `AgendaViewMode`, lembrado entre sessões via
/// `agendaViewModeProvider`) mais uma faixa de semana navegável por toque
/// ([_WeekStrip], só na visualização Agenda) acima do `SfCalendar`. O
/// cabeçalho nativo do `SfCalendar` (`headerHeight: 0`) fica oculto — o
/// título "Agenda" (com o mês/ano em exibição logo abaixo, atualizado via
/// `onViewChanged`) e o seletor de visualização já cobrem esse papel; troca
/// de mês/dia continua possível por gesto de arrastar.
class AgendaPage extends ConsumerStatefulWidget {
  const AgendaPage({super.key});

  @override
  ConsumerState<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends ConsumerState<AgendaPage> {
  DateTime _selectedDate = DateTime.now();
  late String _visibleMonthLabel;
  late final CalendarController _calendarController;

  @override
  void initState() {
    super.initState();
    _calendarController = CalendarController()..displayDate = _selectedDate;
    _visibleMonthLabel = _formatMonthLabel(_selectedDate);
  }

  @override
  void dispose() {
    _calendarController.dispose();
    super.dispose();
  }

  static String _formatMonthLabel(DateTime date) {
    final label = DateFormat('MMMM yyyy', 'pt_BR').format(date);
    return label.isEmpty ? label : label[0].toUpperCase() + label.substring(1);
  }

  static CalendarView _syncfusionViewFor(AgendaViewMode mode) {
    switch (mode) {
      case AgendaViewMode.agenda:
        return CalendarView.schedule;
      case AgendaViewMode.day:
        return CalendarView.day;
      case AgendaViewMode.week:
        return CalendarView.week;
      case AgendaViewMode.month:
        return CalendarView.month;
    }
  }

  void _goToDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _visibleMonthLabel = _formatMonthLabel(date);
    });
    _calendarController.displayDate = date;
    _calendarController.selectedDate = date;
  }

  // Cabeçalho mostra o mês/ano em exibição no calendário — atualizado sempre
  // que o usuário navega por gesto (arrastar entre meses/dias, ou rolar a
  // lista da Agenda), não só ao tocar num dia na faixa de semana.
  //
  // `addPostFrameCallback` adia a atualização pro fim do frame atual — o
  // Syncfusion chama `onViewChanged` de dentro do próprio `initState()` de um
  // widget interno, em plena fase de build; um `setState` síncrono aqui já
  // causou um crash real nesta base.
  void _onCalendarViewChanged(ViewChangedDetails details) {
    if (details.visibleDates.isEmpty) return;
    final middle = details.visibleDates[details.visibleDates.length ~/ 2];
    final label = _formatMonthLabel(middle);
    if (label == _visibleMonthLabel) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _visibleMonthLabel = label);
    });
  }

  // O CalendarController guarda seu próprio `view` internamente e só usa
  // `SfCalendar.view` pra inicializar na primeira montagem — sem isto, trocar
  // de modo atualiza o ícone/rádio do menu mas o calendário exibido continua
  // preso na primeira visualização. Também é o único jeito de refletir a
  // visualização lembrada (`agendaViewModeProvider`), que carrega de forma
  // assíncrona (`SharedPreferences`) depois do primeiro frame — ver
  // `ref.listen` em `build()`. NÃO adicionar `key: ValueKey(mode)` no
  // `SfCalendar` — já tentado e revertido, colide com os `GlobalKey`s
  // internos do Syncfusion e derruba o app.
  void _setMode(AgendaViewMode mode) {
    ref.read(agendaViewModeProvider.notifier).set(mode);
  }

  Future<void> _showNewEntryChooser(DateTime initialDate) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('Compromisso único'),
              onTap: () => Navigator.of(sheetContext).pop('single'),
            ),
            ListTile(
              leading: const Icon(Icons.repeat),
              title: const Text('Compromisso recorrente'),
              onTap: () => Navigator.of(sheetContext).pop('recurring'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'single') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AgendaEntryFormPage(initialDate: initialDate)),
      );
    } else if (choice == 'recurring') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const RecurringAgendaEntryFormPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(agendaViewModeProvider);
    ref.listen<AgendaViewMode>(agendaViewModeProvider, (previous, next) {
      _calendarController.view = _syncfusionViewFor(next);
    });

    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final isAdmin = profile?.isAdmin ?? false;
    final ledIds = ref.watch(myLedMinistryIdsProvider);
    final memberIds = ref.watch(myMemberMinistryIdsProvider);
    final visibleIds = {...memberIds, ...ledIds};
    final items = ref.watch(agendaCalendarItemsProvider);
    final isApprover = ref.watch(isAgendaApproverProvider);
    // Só é lido quando `isApprover` (o ícone de "Solicitações" nem aparece
    // pra quem não aprova, ver mais abaixo) — a fila de aprovação.
    final requestsBadge =
        isApprover ? ref.watch(pendingAgendaApprovalProvider).length : 0;

    // Criar compromisso: quem lidera pelo menos um ministério, ou admin —
    // não precisa mais liderar o ministério-alvo, só passa a exigir
    // aprovação depois.
    final canCreate = isAdmin || ledIds.isNotEmpty;

    // Todo item aparece no calendário — o que muda é só o quanto dele fica
    // visível: "Restrito" (sem título/descrição/local reais) pra quem não é
    // admin/aprovador/participante dos ministérios envolvidos num item
    // fechado (03/09/2026, 3ª rodada, pedido do usuário — antes um item de
    // ministério específico sumia por completo pra quem estava de fora,
    // agora ele continua ocupando o horário visivelmente, só sem revelar do
    // que se trata). Ver `AgendaCalendarItem.isMaskedFor`.
    bool isMasked(AgendaCalendarItem item) => item.isMaskedFor(
      isAdmin: isAdmin,
      isApprover: isApprover,
      visibleIds: visibleIds,
    );

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      floatingActionButton: !canCreate
          ? null
          : FloatingActionButton(
              heroTag: 'agenda_fab',
              onPressed: () => _showNewEntryChooser(
                // Dia/hora que estiver selecionado no calendário no
                // momento — `_calendarController.selectedDate` é a fonte
                // única de verdade (ver `_goToDate`).
                _calendarController.selectedDate ?? _selectedDate,
              ),
              child: const _NewAgendaEntryIcon(),
            ),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        top: 4,
                        bottom: 4,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Agenda',
                            style: TextStyle(
                              color: SibValColors.goldAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 19,
                            ),
                          ),
                          Text(
                            _visibleMonthLabel,
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Legenda',
                    icon: const Icon(Icons.info_outline),
                    onPressed: () => _showLegend(context),
                  ),
                  // Ícone (e a tela de aprovação por trás dele) só aparece
                  // pra quem de fato aprova (03/09/2026, 3ª rodada, pedido
                  // do usuário: "Para quem não for aprovador, não mostre
                  // nem o ícone de aprovação"). Quem não é aprovador
                  // continua sabendo do desfecho da própria solicitação
                  // pela notificação (que já abre `AgendaApprovalPage`
                  // direto, sem depender deste ícone).
                  if (isApprover)
                    IconButton(
                      tooltip: 'Solicitações',
                      icon: Badge(
                        isLabelVisible: requestsBadge > 0,
                        label: Text('$requestsBadge'),
                        child: const Icon(Icons.fact_check_outlined),
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AgendaApprovalPage()),
                      ),
                    ),
                  if (isAdmin) ...[
                    IconButton(
                      tooltip: 'Configurar aprovadores',
                      icon: const Icon(Icons.verified_user_outlined),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AgendaApproversManagementPage(),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Configurar locais',
                      icon: const Icon(Icons.place_outlined),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AgendaLocationManagementPage(),
                        ),
                      ),
                    ),
                  ],
                  _ViewModeMenuButton(mode: mode, onChanged: _setMode),
                ],
              ),
            ),
            if (mode == AgendaViewMode.agenda)
              _WeekStrip(selectedDate: _selectedDate, onSelect: _goToDate),
            Expanded(
              child: SfCalendar(
                view: _syncfusionViewFor(mode),
                controller: _calendarController,
                firstDayOfWeek: 7,
                headerHeight: 0,
                dataSource: _AgendaDataSource(items, isMasked),
                // Padrão 24h no texto do compromisso na visão Agenda
                // (schedule) — sem isso o Syncfusion usa o formato padrão
                // dele ('hh:mm a', 12h com AM/PM) pra essa visão específica,
                // diferente da régua de horário Dia/Semana (`timeFormat`
                // acima), que já tinha sido corrigida antes (03/09/2026,
                // pedido do usuário: "os compromissos ainda aparecem com
                // padrão 12 horas").
                appointmentTimeTextFormat: 'HH:mm',
                todayHighlightColor: SibValColors.goldAccent,
                onViewChanged: _onCalendarViewChanged,
                // Widget de verdade pro cabeçalho de mês da visualização
                // Agenda, no lugar do texto desenhado no canvas por
                // `MonthHeaderSettings.textAlign` — esse `textAlign: center`
                // sozinho só centralizava verticalmente na prática (relatado
                // pelo usuário, 03/09/2026, 3ª rodada); um `Center` de
                // verdade garante os dois eixos.
                scheduleViewMonthHeaderBuilder: (context, details) {
                  return Container(
                    width: details.bounds.width,
                    height: details.bounds.height,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Text(
                      _formatMonthLabel(details.date),
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  );
                },
                viewHeaderStyle: ViewHeaderStyle(
                  dayTextStyle: TextStyle(
                    color: context.textSecondary,
                  ),
                  dateTextStyle: TextStyle(
                    color: context.textPrimary,
                  ),
                ),
                timeSlotViewSettings: TimeSlotViewSettings(
                  nonWorkingDays: const [],
                  timeFormat: 'HH:mm',
                  timeTextStyle: TextStyle(
                    color: context.textSecondary,
                  ),
                ),
                monthViewSettings: MonthViewSettings(
                  showAgenda: false,
                  appointmentDisplayMode: MonthAppointmentDisplayMode.appointment,
                  monthCellStyle: MonthCellStyle(
                    textStyle: TextStyle(color: context.textPrimary),
                    trailingDatesTextStyle: TextStyle(
                      color: context.textSecondary.withValues(alpha: 0.5),
                    ),
                    leadingDatesTextStyle: TextStyle(
                      color: context.textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                scheduleViewSettings: ScheduleViewSettings(
                  hideEmptyScheduleWeek: true,
                  // Só a altura importa aqui — o conteúdo visual vem de
                  // `scheduleViewMonthHeaderBuilder` acima.
                  monthHeaderSettings: const MonthHeaderSettings(height: 44),
                  weekHeaderSettings: WeekHeaderSettings(
                    weekTextStyle: TextStyle(
                      color: context.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  placeholderTextStyle: TextStyle(
                    color: context.textSecondary,
                    fontSize: 14,
                  ),
                ),
                onTap: (details) {
                  final appointment = details.appointments?.isNotEmpty == true
                      ? details.appointments!.first
                      : null;
                  if (appointment is! Appointment) return;
                  final id = appointment.id as String;
                  final item = items.firstWhere((i) => '${i.isEvent}_${i.id}' == id);
                  if (isMasked(item)) {
                    _showRestrictedDetail(context, item);
                    return;
                  }
                  // Ocorrência futura de uma série virtual (03/09/2026,
                  // pedido do usuário) — ainda não existe documento em
                  // Firestore pra ela (só nasce perto da data, ver
                  // `generateInstanceForTemplate`/`generateAgendaInstanceForTemplate`),
                  // então nada de Remanejar/Cancelar aqui — só uma prévia.
                  // `appointment.startTime`/`.endTime` já são a data real
                  // desta ocorrência específica (o Syncfusion recalcula por
                  // ocorrência a partir do `recurrenceRule`), diferente de
                  // `item.start`/`.end`, que só valem pra 1ª ocorrência da
                  // série virtual.
                  if (item.isVirtual) {
                    _showVirtualOccurrenceDetail(
                      context,
                      item,
                      start: appointment.startTime,
                      end: appointment.endTime,
                    );
                    return;
                  }
                  if (item.isEvent) {
                    _showEventDetail(context, item.event!);
                  } else {
                    final entry = item.entry!;
                    _showEntryDetail(context, ref, entry, isApprover: isApprover);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showLegend(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Legenda'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _legendRow(dialogContext, kPointEventColor, 'Evento pontual'),
            _legendRow(dialogContext, kRecurringEventColor, 'Evento recorrente'),
            _legendRow(dialogContext, kRecurringAgendaColor, 'Compromisso recorrente'),
            _legendRow(dialogContext, kPointAgendaColor, 'Compromisso único'),
            _legendRow(dialogContext, kNonBlockingColor, 'Não bloqueia a data/horário'),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('🔒', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bloqueia a data/horário para outros compromissos/eventos',
                    style: TextStyle(color: dialogContext.textPrimary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Fechar')),
      ],
    ),
  );
}

Widget _legendRow(BuildContext context, Color color, String label) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Container(width: 16, height: 16, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: TextStyle(color: context.textPrimary, fontSize: 13))),
      ],
    ),
  );
}

/// Ícone do FAB "novo compromisso" — calendário com um sinal "+" no canto,
/// mesmo padrão de ícone composto já usado em `main_shell.dart`.
class _NewAgendaEntryIcon extends StatelessWidget {
  const _NewAgendaEntryIcon();

  static const _iconColor = SibValColors.navyBlueDark;

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.calendar_today, color: _iconColor, size: 24),
          Positioned(
            bottom: -3,
            right: -4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: SibValColors.goldAccent,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: EdgeInsets.all(1),
                child: Icon(Icons.add, color: _iconColor, size: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewModeMenuButton extends StatelessWidget {
  const _ViewModeMenuButton({required this.mode, required this.onChanged});

  final AgendaViewMode mode;
  final ValueChanged<AgendaViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AgendaViewMode>(
      tooltip: 'Alterar visualização',
      icon: Icon(mode.icon, color: context.textPrimary),
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final option in AgendaViewMode.values)
          PopupMenuItem(
            value: option,
            child: Row(
              children: [
                Icon(option.icon, size: 20, color: context.textSecondary),
                const SizedBox(width: 12),
                Expanded(child: Text(option.label)),
                Icon(
                  option == mode
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: option == mode
                      ? SibValColors.goldAccent
                      : context.textSecondary,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Faixa de semana navegável por toque, inspirada na tira de dias do
/// Outlook mobile (só aparece na visualização Agenda).
class _WeekStrip extends StatefulWidget {
  const _WeekStrip({required this.selectedDate, required this.onSelect});

  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelect;

  @override
  State<_WeekStrip> createState() => _WeekStripState();
}

class _WeekStripState extends State<_WeekStrip> {
  static const _initialPage = 6000;
  static const _weekdayLetters = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

  late final DateTime _baseSunday;
  late final PageController _pageController;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _startOfWeek(DateTime d) =>
      d.subtract(Duration(days: d.weekday % 7));

  @override
  void initState() {
    super.initState();
    _baseSunday = _startOfWeek(_dateOnly(DateTime.now()));
    final selectedSunday = _startOfWeek(_dateOnly(widget.selectedDate));
    final weeksDiff = selectedSunday.difference(_baseSunday).inDays ~/ 7;
    _pageController = PageController(initialPage: _initialPage + weeksDiff);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    final selected = _dateOnly(widget.selectedDate);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              for (final letter in _weekdayLetters)
                Expanded(
                  child: Center(
                    child: Text(
                      letter,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 52,
          child: PageView.builder(
            controller: _pageController,
            itemBuilder: (context, page) {
              final weekStart = _baseSunday.add(
                Duration(days: (page - _initialPage) * 7),
              );
              return Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final date = weekStart.add(Duration(days: i));
                          return _DayCell(
                            date: date,
                            isToday: _dateOnly(date) == today,
                            isSelected: _dateOnly(date) == selected,
                            onTap: () => widget.onSelect(date),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime date;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ring = isToday && !isSelected;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? SibValColors.goldAccent : null,
            shape: BoxShape.circle,
            border: ring
                ? Border.all(color: SibValColors.goldAccent, width: 1.5)
                : null,
          ),
          child: Text(
            '${date.day}',
            style: TextStyle(
              color: isSelected
                  ? SibValColors.navyBlueDark
                  : context.textPrimary,
              fontWeight: isSelected || isToday
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

void _showEntryDetail(
  BuildContext context,
  WidgetRef ref,
  AgendaEntry entry, {
  required bool isApprover,
}) {
  final dateFormat = DateFormat('EEE, dd/MM', 'pt_BR');
  final timeFormat = DateFormat('HH:mm', 'pt_BR');
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
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
              '${entry.displayAudience} · ${dateFormat.format(entry.startDateTime)} · '
              '${timeFormat.format(entry.startDateTime)} às ${dateFormat.format(entry.endDateTime)} '
              '${timeFormat.format(entry.endDateTime)}',
              style: TextStyle(
                color: sheetContext.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.place_outlined,
                  size: 14,
                  color: sheetContext.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  entry.location,
                  style: TextStyle(
                    color: sheetContext.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            if (entry.recurringAgendaEntryId.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Ocorrência de série recorrente',
                style: TextStyle(color: sheetContext.textSecondary, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
            if (entry.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                entry.description,
                style: TextStyle(color: sheetContext.textPrimary),
              ),
            ],
            if (isApprover) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        showAgendaRescheduleSheet(context, ref, entry);
                      },
                      icon: const Icon(Icons.edit_calendar_outlined),
                      label: const Text('Remanejar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        // Justificativa obrigatória (03/09/2026, 3ª rodada,
                        // pedido do usuário: "Ao remanejar ou cancelar um
                        // agendamento, deve informar a justificativa").
                        final controller = TextEditingController();
                        final reason = await showDialog<String>(
                          context: sheetContext,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Cancelar compromisso'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Cancelar "${entry.title}"? O solicitante será notificado.'),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: controller,
                                  autofocus: true,
                                  maxLines: 3,
                                  textCapitalization: TextCapitalization.sentences,
                                  decoration: const InputDecoration(labelText: 'Justificativa'),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(dialogContext).pop(),
                                child: const Text('Voltar'),
                              ),
                              TextButton(
                                onPressed: () {
                                  final text = controller.text.trim();
                                  if (text.isEmpty) return;
                                  Navigator.of(dialogContext).pop(text);
                                },
                                child: const Text('Cancelar compromisso'),
                              ),
                            ],
                          ),
                        );
                        if (reason != null && reason.isNotEmpty) {
                          final profile = ref.read(currentUserProfileProvider).asData?.value;
                          final uid = ref.read(currentUidProvider) ?? '';
                          await ref.read(agendaRepositoryProvider).cancel(
                                entry.id,
                                reason: reason,
                                approverUid: uid,
                                approverName: profile?.shortName ?? '',
                              );
                          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                        }
                      },
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancelar'),
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

/// Detalhe de uma ocorrência futura de uma série virtual (03/09/2026,
/// pedido do usuário: "os agendamentos recorrentes... já devem ficar
/// marcados no calendário todas as datas a frente") — só uma prévia
/// somente-leitura; a ocorrência de verdade (com aprovação/cancelamento
/// possível) só nasce em Firestore perto da data real.
void _showVirtualOccurrenceDetail(
  BuildContext context,
  AgendaCalendarItem item, {
  required DateTime start,
  required DateTime end,
}) {
  final dateFormat = DateFormat('EEE, dd/MM', 'pt_BR');
  final timeFormat = DateFormat('HH:mm', 'pt_BR');
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style: TextStyle(color: sheetContext.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              '${dateFormat.format(start)} · ${timeFormat.format(start)} às ${timeFormat.format(end)}',
              style: TextStyle(color: sheetContext.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.place_outlined, size: 14, color: sheetContext.textSecondary),
                const SizedBox(width: 4),
                Text(item.location, style: TextStyle(color: sheetContext.textSecondary, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Próxima ocorrência da série recorrente "${item.title}" — ainda não gerada de '
              'verdade; entra na Agenda automaticamente mais perto da data.',
              style: TextStyle(color: sheetContext.textSecondary, fontSize: 13, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Detalhe de um item "Restrito" (03/09/2026, 3ª rodada) — quem não é
/// admin/aprovador/participante dos ministérios envolvidos só vê que o
/// horário está ocupado, sem título/descrição/local reais.
void _showRestrictedDetail(BuildContext context, AgendaCalendarItem item) {
  final dateFormat = DateFormat('EEE, dd/MM', 'pt_BR');
  final timeFormat = DateFormat('HH:mm', 'pt_BR');
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_outline, color: sheetContext.textPrimary),
                const SizedBox(width: 8),
                Text(
                  'Restrito',
                  style: TextStyle(
                    color: sheetContext.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${dateFormat.format(item.start)} · ${timeFormat.format(item.start)} '
              'às ${timeFormat.format(item.end)}',
              style: TextStyle(color: sheetContext.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text(
              'Visível só pra quem participa dos ministérios envolvidos.',
              style: TextStyle(color: sheetContext.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Detalhe simplificado de um Evento dentro da Agenda — somente leitura;
/// editar/excluir é sempre pela tela de Eventos, não daqui.
void _showEventDetail(BuildContext context, Event event) {
  final dateFormat = DateFormat('EEE, dd/MM', 'pt_BR');
  final timeFormat = DateFormat('HH:mm', 'pt_BR');
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title,
              style: TextStyle(
                color: sheetContext.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Evento · ${dateFormat.format(event.dateTimeSaoPaulo)} · '
              '${timeFormat.format(event.dateTimeSaoPaulo)}',
              style: TextStyle(color: sheetContext.textSecondary, fontSize: 13),
            ),
            if (event.churchArea.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.place_outlined, size: 14, color: sheetContext.textSecondary),
                  const SizedBox(width: 4),
                  Text(event.churchArea, style: TextStyle(color: sheetContext.textSecondary, fontSize: 13)),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Text(
              event.blocksCalendar
                  ? 'Bloqueia esse horário no calendário.'
                  : 'Não bloqueia esse horário no calendário.',
              style: TextStyle(color: sheetContext.textSecondary, fontSize: 12, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => EventDetailPage(eventId: event.id)),
                  );
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Ver evento'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Cores por categoria (03/09/2026, 2ª rodada, pedido do usuário: "Vamos
/// classificar os agendamentos por cores" — sem usar dourado, que já é a
/// cor do FAB). Item que não bloqueia a data/horário (evento com área "Fora
/// da Igreja" ou sem área informada) usa [kNonBlockingColor] em vez da cor
/// da categoria — o que importa ali é "não compete por espaço".
const kPointEventColor = Color(0xFFB0413E);
const kRecurringEventColor = Color(0xFF3E8E8E);
const kRecurringAgendaColor = Color(0xFF7D5BA6);
const kPointAgendaColor = Color(0xFF3F6FBF);
const kNonBlockingColor = Color(0xFF6B7A85);

Color _colorForItem(AgendaCalendarItem item) {
  if (!item.blocksCalendar) return kNonBlockingColor;
  switch (item.category) {
    case AgendaItemCategory.pointEvent:
      return kPointEventColor;
    case AgendaItemCategory.recurringEvent:
      return kRecurringEventColor;
    case AgendaItemCategory.recurringAgenda:
      return kRecurringAgendaColor;
    case AgendaItemCategory.pointAgenda:
      return kPointAgendaColor;
  }
}

String _subjectFor(AgendaCalendarItem item, {required bool masked}) {
  final lock = item.blocksCalendar ? '🔒 ' : '';
  if (masked) return '${lock}Restrito';
  final tag = item.isEvent ? '📅 ' : '';
  return '$lock$tag${item.title}';
}

class _AgendaDataSource extends CalendarDataSource {
  _AgendaDataSource(List<AgendaCalendarItem> items, bool Function(AgendaCalendarItem) isMasked) {
    appointments = [
      for (final item in items)
        Appointment(
          id: '${item.isEvent}_${item.id}',
          startTime: item.start,
          endTime: item.end,
          subject: _subjectFor(item, masked: isMasked(item)),
          location: isMasked(item) ? '' : item.location,
          color: _colorForItem(item),
          // Item virtual de uma série recorrente ativa (03/09/2026, pedido
          // do usuário) — o Syncfusion expande sozinho todas as ocorrências
          // futuras a partir de `startTime`/`endTime` (a 1ª ocorrência
          // ainda não materializada), sem precisar de um item por semana.
          recurrenceRule: item.recurrenceRule,
          recurrenceExceptionDates: item.recurrenceExceptionDates,
        ),
    ];
  }
}
