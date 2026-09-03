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
/// `myMemberMinistryIdsProvider`) só visualizam. Admin vê tudo e também pode
/// **criar** um compromisso em qualquer ministério — revisão do mesmo dia:
/// a 1ª versão restringia a criação só a quem lidera (mesmo admin), mas o
/// usuário pediu a exceção de volta ao notar que, testando como admin sem
/// liderar nenhum ministério, o botão de inserir sumia; editar/excluir já
/// era liberado pro admin desde a 1ª versão.
///
/// Layout revisado em 03/09/2026 (mesmo dia, pedido do usuário: "algo
/// parecido com" a agenda do app Outlook) — troca de Dia/Semana/Mês por
/// `SegmentedButton` deu lugar a um seletor de visualização em menu (Agenda/
/// Dia/Semana/Mês, [_AgendaViewMode]) mais uma faixa de semana navegável por
/// toque ([_WeekStrip], só na visualização Agenda) acima do `SfCalendar` —
/// mesmo motor de calendário de antes, só reconfigurado por modo
/// (`CalendarView.schedule` para Agenda, `CalendarView.day` para Dia,
/// `CalendarView.week` para Semana, `CalendarView.month` para Mês). O
/// cabeçalho nativo do `SfCalendar` (`headerHeight: 0`) fica oculto — o
/// título "Agenda" (com o mês/ano em exibição logo abaixo, atualizado via
/// `onViewChanged`) e o seletor de visualização já cobrem esse papel; troca
/// de mês/dia continua possível por gesto de arrastar, como no Outlook.
/// "3 Dias" (opção inicial) virou "Semana" no mesmo dia, a pedido do
/// usuário.
class AgendaPage extends ConsumerStatefulWidget {
  const AgendaPage({super.key});

  @override
  ConsumerState<AgendaPage> createState() => _AgendaPageState();
}

enum _AgendaViewMode {
  agenda('Agenda', Icons.view_agenda_outlined),
  day('Dia', Icons.view_day_outlined),
  week('Semana', Icons.view_week_outlined),
  month('Mês', Icons.calendar_view_month_outlined);

  const _AgendaViewMode(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _AgendaPageState extends ConsumerState<AgendaPage> {
  _AgendaViewMode _mode = _AgendaViewMode.agenda;
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

  CalendarView get _syncfusionView {
    switch (_mode) {
      case _AgendaViewMode.agenda:
        return CalendarView.schedule;
      case _AgendaViewMode.day:
        return CalendarView.day;
      case _AgendaViewMode.week:
        return CalendarView.week;
      case _AgendaViewMode.month:
        return CalendarView.month;
    }
  }

  void _goToDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _visibleMonthLabel = _formatMonthLabel(date);
    });
    _calendarController.displayDate = date;
  }

  // Cabeçalho mostra o mês/ano em exibição no calendário (pedido do
  // usuário) — atualizado sempre que o usuário navega por gesto (arrastar
  // entre meses/dias, ou rolar a lista da Agenda), não só ao tocar num dia
  // na faixa de semana.
  //
  // Causa raiz de um crash real encontrado nesta mesma sessão
  // ("Failed assertion: '_elements.contains(element)': is not true",
  // reproduzido ao alternar Agenda/Dia/Semana/Mês repetidamente): o
  // Syncfusion chama `onViewChanged` de dentro do próprio `initState()` de um
  // widget interno (`_CustomCalendarScrollViewState`), ou seja, em plena
  // fase de build da árvore — um `setState` síncrono aqui disparava "setState
  // ou markNeedsBuild chamado durante o build", que por sua vez deixava a
  // árvore de elementos num estado inconsistente e derrubava o app pouco
  // depois. `addPostFrameCallback` adia a atualização pro fim do frame atual,
  // depois que o build em andamento termina.
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

  // O CalendarController guarda seu próprio `view` internamente (só usa
  // `SfCalendar.view` pra inicializar na primeira montagem — depois disso, o
  // widget ignora silenciosamente qualquer mudança em `view:`) — sem isto,
  // trocar de modo atualiza o ícone/rádio do menu mas o calendário exibido
  // continua preso na primeira visualização.
  //
  // NÃO adicionar `key: ValueKey(_mode)` no `SfCalendar` pra "garantir" a
  // troca de configurações (timeSlotViewSettings etc.) — já tentado e
  // revertido (03/09/2026): forçar remontagem completa toda vez que
  // `_calendarController.view` já muda a view muda sozinho colide com os
  // `GlobalKey`s internos do Syncfusion e derruba o app com
  // `Failed assertion: '_elements.contains(element)': is not true` ao
  // alternar entre Agenda/Dia/Semana/Mês algumas vezes. Sem a key, o
  // `SfCalendarState.didUpdateWidget` já compara e aplica sozinho qualquer
  // mudança nas configurações (confirmado lendo o código-fonte do pacote).
  void _setMode(_AgendaViewMode mode) {
    setState(() => _mode = mode);
    _calendarController.view = _syncfusionView;
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final isAdmin = profile?.isAdmin ?? false;
    final ministries = ref.watch(ministriesProvider).asData?.value ?? const [];
    final ledIds = ref.watch(myLedMinistryIdsProvider);
    final memberIds = ref.watch(myMemberMinistryIdsProvider);
    final entriesAsync = ref.watch(agendaEntriesProvider);

    // Criação de compromisso novo: quem lidera aquele ministério, ou admin
    // (bypass restaurado em 03/09/2026 — sem ele, um admin que não lidera
    // nenhum ministério não via o botão de inserir).
    final creatableIds = isAdmin
        ? ministries.map((m) => m.id).toSet()
        : ledIds;
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
              child: const _NewAgendaEntryIcon(),
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
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
                _ViewModeMenuButton(mode: _mode, onChanged: _setMode),
              ],
            ),
          ),
          if (_mode == _AgendaViewMode.agenda)
            _WeekStrip(selectedDate: _selectedDate, onSelect: _goToDate),
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
                        view: _syncfusionView,
                        controller: _calendarController,
                        firstDayOfWeek: 7,
                        headerHeight: 0,
                        dataSource: _AgendaDataSource(entries),
                        todayHighlightColor: SibValColors.goldAccent,
                        onViewChanged: _onCalendarViewChanged,
                        viewHeaderStyle: ViewHeaderStyle(
                          dayTextStyle: TextStyle(color: context.textSecondary),
                          dateTextStyle: TextStyle(color: context.textPrimary),
                        ),
                        timeSlotViewSettings: TimeSlotViewSettings(
                          // Sem dias "não úteis" (padrão do pacote marca
                          // sáb./dom.) — pra uma igreja é o contrário, o fim
                          // de semana costuma ser quando mais acontece.
                          nonWorkingDays: const [],
                          // Formato 24h na régua de horários (Dia/Semana) —
                          // padrão do pacote é 'h a' (ex. "1 AM"), pedido do
                          // usuário foi trocar pra 24h.
                          timeFormat: 'HH:mm',
                          timeTextStyle: TextStyle(color: context.textSecondary),
                        ),
                        monthViewSettings: MonthViewSettings(
                          showAgenda: false,
                          appointmentDisplayMode:
                              MonthAppointmentDisplayMode.appointment,
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
                          monthHeaderSettings: MonthHeaderSettings(
                            height: 44,
                            backgroundColor:
                                Theme.of(context).colorScheme.surfaceContainerHighest,
                            monthTextStyle: TextStyle(
                              color: context.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
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

/// Ícone do FAB "novo compromisso" — calendário com um sinal "+" no canto
/// (pedido do usuário, 03/09/2026), mesmo padrão de ícone composto já usado
/// em `main_shell.dart` (`SettingsMailIcon` etc.): dois `Icons` do Material
/// empilhados via `Stack`, sem precisar de um asset novo. O círculo do "+"
/// usa a própria cor de fundo do FAB (`SibValColors.goldAccent`) — cria um
/// efeito de "recorte" em vez de um badge de cor diferente por cima.
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

  final _AgendaViewMode mode;
  final ValueChanged<_AgendaViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_AgendaViewMode>(
      tooltip: 'Alterar visualização',
      icon: Icon(mode.icon, color: context.textPrimary),
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final option in _AgendaViewMode.values)
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
/// Outlook mobile (só aparece na visualização Agenda) — cada semana é uma
/// página de um `PageView` "infinito" (offset em torno de hoje), com o dia
/// selecionado preenchido em dourado e o dia de hoje (quando não é o
/// selecionado) com um contorno dourado. Tocar num dia chama [onSelect], que
/// desloca o `CalendarController.displayDate` da agenda pra aquele dia.
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
              final weekStart =
                  _baseSunday.add(Duration(days: (page - _initialPage) * 7));
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
              color: isSelected ? SibValColors.navyBlueDark : context.textPrimary,
              fontWeight:
                  isSelected || isToday ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
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
