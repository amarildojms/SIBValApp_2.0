import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/agenda_entry.dart';
import '../models/event.dart';
import '../models/recurring_agenda_entry.dart';
import '../models/recurring_event.dart';
import '../util/agenda_area.dart';
import 'event_repository.dart';
import 'member_repository.dart' show isLeaderCargo, myMemberProvider;
import 'post_repository.dart' show currentUidProvider;
import 'recurring_agenda_entry_repository.dart';
import 'recurring_event_repository.dart';

class AgendaRepository {
  AgendaRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _entries =>
      _firestore.collection('agendaEntries');

  /// Tempo real — a agenda de um ministério é editada por mais de um líder em
  /// potencial e lida pelos liderados, mesmo padrão de `membersProvider`.
  Stream<List<AgendaEntry>> watchAll() {
    return _entries
        .orderBy('startDateTime')
        .snapshots()
        .map((s) => s.docs.map(AgendaEntry.fromFirestore).toList());
  }

  Future<void> create(AgendaEntry entry) => _entries.add({
    ...entry.toContentMap(),
    'createdAt': FieldValue.serverTimestamp(),
    'status': AgendaEntryStatus.pending,
    'rejectionReason': '',
    'approvedByUid': '',
    'approvedByName': '',
    'decidedAt': null,
    'rescheduleMessage': '',
  });

  /// Qualquer edição de conteúdo (pelo dono, só enquanto `pending`/
  /// `rejected`/`needsReschedule` — ver `firestore.rules`) devolve o
  /// compromisso pra fila de aprovação.
  Future<void> update(String id, AgendaEntry entry) => _entries.doc(id).update({
    ...entry.toContentMap(),
    'status': AgendaEntryStatus.pending,
    'rejectionReason': '',
    'approvedByUid': '',
    'approvedByName': '',
    'decidedAt': null,
    'rescheduleMessage': '',
  });

  Future<void> delete(String id) => _entries.doc(id).delete();

  Future<void> approve(String id, {required String approverUid, required String approverName}) {
    return _entries.doc(id).update({
      'status': AgendaEntryStatus.approved,
      'rejectionReason': '',
      'approvedByUid': approverUid,
      'approvedByName': approverName,
      'decidedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reject(
    String id, {
    required String reason,
    required String approverUid,
    required String approverName,
  }) {
    return _entries.doc(id).update({
      'status': AgendaEntryStatus.rejected,
      'rejectionReason': reason,
      'approvedByUid': approverUid,
      'approvedByName': approverName,
      'decidedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cancela um compromisso já aprovado — exclusivo do aprovador
  /// (03/09/2026, 2ª rodada, pedido do usuário: "Somente o aprovador pode
  /// cancelar/remanejar um agendamento"). Some do calendário e da checagem
  /// de conflito, mas fica registrado (não é apagado). [reason] é
  /// obrigatório (3ª rodada, mesma sessão: "Ao remanejar ou cancelar um
  /// agendamento, deve informar a justificativa").
  Future<void> cancel(
    String id, {
    required String reason,
    required String approverUid,
    required String approverName,
  }) {
    return _entries.doc(id).update({
      'status': AgendaEntryStatus.cancelled,
      'cancelReason': reason,
      'approvedByUid': approverUid,
      'approvedByName': approverName,
      'decidedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remanejamento direto: o aprovador escolhe a nova data/horário — o
  /// compromisso continua `approved`, só a data muda. [reason] (obrigatório,
  /// ver [cancel]) reaproveita o campo `rescheduleMessage`, mesmo texto que
  /// [requestReschedule] usa pro outro caminho de remanejar.
  Future<void> rescheduleDirect(
    String id, {
    required DateTime start,
    required DateTime end,
    required String reason,
    required String approverUid,
    required String approverName,
  }) {
    return _entries.doc(id).update({
      'status': AgendaEntryStatus.approved,
      'startDateTime': Timestamp.fromDate(start),
      'endDateTime': Timestamp.fromDate(end),
      'rescheduleMessage': reason,
      'approvedByUid': approverUid,
      'approvedByName': approverName,
      'decidedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remanejamento pedido: o aprovador devolve pro solicitante com uma
  /// mensagem explicando que ele deve escolher outra data — o solicitante
  /// edita e reenvia (`update`, que já volta pra `pending`).
  Future<void> requestReschedule(
    String id, {
    required String message,
    required String approverUid,
    required String approverName,
  }) {
    return _entries.doc(id).update({
      'status': AgendaEntryStatus.needsReschedule,
      'rescheduleMessage': message,
      'approvedByUid': approverUid,
      'approvedByName': approverName,
      'decidedAt': FieldValue.serverTimestamp(),
    });
  }
}

final agendaRepositoryProvider = Provider<AgendaRepository>((ref) {
  return AgendaRepository(FirebaseFirestore.instance);
});

final agendaEntriesProvider = StreamProvider.autoDispose<List<AgendaEntry>>((
  ref,
) {
  return ref.watch(agendaRepositoryProvider).watchAll();
});

/// Só os compromissos efetivados — o que de fato ocupa o calendário e é
/// visível na visualização normal da Agenda.
final approvedAgendaEntriesProvider = Provider.autoDispose<List<AgendaEntry>>((ref) {
  final all = ref.watch(agendaEntriesProvider).asData?.value ?? const [];
  return all.where((e) => e.status == AgendaEntryStatus.approved).toList();
});

/// Fila de aprovação — todo compromisso pendente, de qualquer ministério
/// (quem vê de verdade é filtrado por `isAgendaApproverProvider` na UI).
final pendingAgendaApprovalProvider = Provider.autoDispose<List<AgendaEntry>>((ref) {
  final all = ref.watch(agendaEntriesProvider).asData?.value ?? const [];
  return all.where((e) => e.status == AgendaEntryStatus.pending).toList();
});

/// "Minhas solicitações" — o que o usuário logado criou e ainda não foi
/// efetivado (pendente/rejeitado/cancelado/precisa remarcar).
final myAgendaRequestsProvider = Provider.autoDispose<List<AgendaEntry>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const [];
  final all = ref.watch(agendaEntriesProvider).asData?.value ?? const [];
  return all
      .where((e) => e.createdByUid == uid && e.status != AgendaEntryStatus.approved)
      .toList();
});

/// Ministérios em que o usuário logado tem o cargo "Líder" — usado só como
/// pré-seleção de conveniência no formulário (03/09/2026: qualquer líder pode
/// escolher qualquer ministério/toda a igreja, não mais restrito ao próprio).
final myLedMinistryIdsProvider = Provider.autoDispose<Set<String>>((ref) {
  final member = ref.watch(myMemberProvider).asData?.value;
  if (member == null) return const {};
  return {
    for (final m in member.ministries)
      if (m.cargos.any(isLeaderCargo)) m.ministryId,
  };
});

/// Todo ministério de que o usuário logado participa (líder ou não) — define
/// o que os "liderados" enxergam na Agenda.
final myMemberMinistryIdsProvider = Provider.autoDispose<Set<String>>((ref) {
  final member = ref.watch(myMemberProvider).asData?.value;
  return member == null ? const {} : member.ministryIds.toSet();
});

/// `settings/agendaApprovers.uids` — quem o admin escolheu como aprovador dos
/// compromissos da Agenda (03/09/2026, pedido do usuário), mesmo padrão de
/// `CifraEditorsRepository`.
class AgendaApproversRepository {
  AgendaApproversRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection('settings').doc('agendaApprovers');

  Stream<List<String>> watchUids() {
    return _doc.snapshots().map(
      (doc) => List<String>.from(doc.data()?['uids'] as List? ?? const []),
    );
  }

  Future<void> setUids(List<String> uids) => _doc.set({'uids': uids});
}

final agendaApproversRepositoryProvider = Provider<AgendaApproversRepository>((ref) {
  return AgendaApproversRepository(FirebaseFirestore.instance);
});

final agendaApproverUidsProvider = StreamProvider.autoDispose<List<String>>((ref) {
  return ref.watch(agendaApproversRepositoryProvider).watchUids();
});

/// `true` se o usuário logado pode aprovar/rejeitar/cancelar/remanejar
/// compromissos — exclusivamente quem o admin atribuiu (03/09/2026, 2ª
/// rodada, pedido do usuário: "Admin não pode aprovar agendamento, somente
/// quem o admin atribuir" — mesmo o admin precisa se auto-atribuir na lista
/// pra ganhar esse poder).
final isAgendaApproverProvider = Provider.autoDispose<bool>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return false;
  final uids = ref.watch(agendaApproverUidsProvider).asData?.value ?? const [];
  return uids.contains(uid);
});

/// As 4 categorias visuais do calendário (03/09/2026, 2ª rodada, pedido do
/// usuário: cores diferentes pra cada uma, sem usar dourado) — ver cores em
/// `lib/agenda/agenda_page.dart`.
enum AgendaItemCategory { pointEvent, recurringEvent, recurringAgenda, pointAgenda }

/// Um item exibido no calendário da Agenda e no card "Esta Semana" da
/// Início — um compromisso aprovado ou um Evento publicado (03/09/2026,
/// pedido do usuário: eventos publicados também entram automaticamente).
/// [blocksCalendar] decide se ele entra na checagem de conflito
/// (`findAgendaConflicts`) — compromisso aprovado sempre bloqueia; evento só
/// quando tem área que bloqueia (`Event.blocksCalendar`).
class AgendaCalendarItem {
  const AgendaCalendarItem({
    required this.id,
    required this.title,
    required this.location,
    required this.start,
    required this.end,
    required this.isEvent,
    required this.blocksCalendar,
    required this.category,
    this.entry,
    this.event,
    this.recurrenceRule,
    this.recurrenceExceptionDates,
  });

  final String id;
  final String title;
  final String location;
  final DateTime start;
  final DateTime end;
  final bool isEvent;
  final bool blocksCalendar;
  final AgendaItemCategory category;
  final AgendaEntry? entry;
  final Event? event;

  /// Preenchido só nos itens "virtuais" gerados a partir de um molde
  /// recorrente ativo (`AgendaCalendarItem.virtualFromRecurringEvent`/
  /// `.virtualFromRecurringAgendaEntry`) — regra RRule (`FREQ=WEEKLY...`)
  /// consumida nativamente pelo Syncfusion (`Appointment.recurrenceRule`)
  /// pra marcar todas as datas futuras da série no calendário de uma vez,
  /// não só a próxima ocorrência já gerada em Firestore (03/09/2026, pedido
  /// do usuário: "assim como os eventos recorrentes, já devem ficar
  /// marcados no calendário todas as datas a frente"). `null` pra qualquer
  /// item concreto (compromisso aprovado/evento publicado de verdade).
  final String? recurrenceRule;

  /// Datas a pular dentro da série virtual (`Appointment.recurrenceExceptionDates`)
  /// — hoje só a data da ocorrência mais próxima já materializada em
  /// Firestore (publicada ou cancelada), pra não desenhar duas vezes a
  /// mesma semana (uma vez como item concreto — se publicada —, outra como
  /// ocorrência da série virtual) e pra respeitar um cancelamento avulso
  /// daquela semana (`cancelNextOccurrenceOnly`), que também não deve
  /// ressurgir via a série virtual.
  final List<DateTime>? recurrenceExceptionDates;

  bool get isVirtual => recurrenceRule != null;

  /// `true` quando o destino é um ou mais ministérios específicos — nesse
  /// caso o item é Restrito; qualquer outro destino ("toda a igreja") é
  /// Aberto. ALTERADO (03/09/2026, 4ª rodada, pedido do usuário: "vamos
  /// retirar os flags restrito e aberto, e atrelar a regra pelo destinado
  /// a") — Aberto/Restrito deixou de ser um flag próprio (`isOpen`,
  /// removido dos modelos) e passou a ser só isto, derivado do destino.
  bool get hasMinistryAudience => entry != null
      ? entry!.audienceType == AgendaAudience.ministries
      : event!.audienceType == EventAudience.specificMinistries;

  List<String> get involvedMinistryIds => entry?.ministryIds ?? event?.targetMinistryIds ?? const [];

  /// `true` se [item] deve aparecer como "Restrito" (sem título/descrição/
  /// local reais) pra quem está vendo — admin e aprovador sempre veem tudo;
  /// os demais só veem os detalhes se o item for destinado a toda a igreja,
  /// ou eles participarem de algum dos ministérios envolvidos (03/09/2026,
  /// pedido do usuário: "Um evento fechado deve aparecer para os demais
  /// como Restrito").
  bool isMaskedFor({required bool isAdmin, required bool isApprover, required Set<String> visibleIds}) {
    if (isAdmin || isApprover) return false;
    if (!hasMinistryAudience) return false;
    return !involvedMinistryIds.any(visibleIds.contains);
  }

  factory AgendaCalendarItem.fromEntry(AgendaEntry entry) => AgendaCalendarItem(
    id: entry.id,
    title: entry.title,
    location: entry.location,
    start: entry.startDateTime,
    end: entry.endDateTime,
    isEvent: false,
    blocksCalendar: true,
    category: entry.recurringAgendaEntryId.isEmpty
        ? AgendaItemCategory.pointAgenda
        : AgendaItemCategory.recurringAgenda,
    entry: entry,
  );

  factory AgendaCalendarItem.fromEvent(Event event) => AgendaCalendarItem(
    id: event.id,
    title: event.title,
    location: event.churchArea,
    start: event.dateTimeSaoPaulo,
    end: event.endDateTimeSaoPaulo,
    isEvent: true,
    blocksCalendar: event.blocksCalendar,
    category: event.source == EventSource.recurring
        ? AgendaItemCategory.recurringEvent
        : AgendaItemCategory.pointEvent,
    event: event,
  );

  /// Série virtual (não gera documento em Firestore) representando **todas**
  /// as datas futuras de um molde de evento recorrente ativo — ver doc
  /// comment de [recurrenceRule]. [excludeDate] é a data da ocorrência mais
  /// próxima já materializada em `events` (publicada ou cancelada, ver
  /// `RecurringEventRepository.getUpcomingInstance`) — o ponto de partida
  /// ([start]/[end], usado por quem só olha esses dois campos direto, sem
  /// entender `recurrenceRule`: `agendaConflictItemsProvider`, "Esta
  /// Semana") pula pra semana seguinte quando cai nessa data, pra não
  /// duplicar (se publicada, aquela semana já aparece via
  /// [AgendaCalendarItem.fromEvent]) nem ressuscitar (se cancelada
  /// avulsamente) a semana já materializada — o Syncfusion, que entende
  /// `recurrenceRule` de verdade, não gera nenhuma ocorrência antes de
  /// [start] de qualquer forma, então a lacuna daquela semana na visão de
  /// calendário é preenchida só pelo item concreto (ou por nenhum, se
  /// cancelado), nunca pelos dois ao mesmo tempo.
  factory AgendaCalendarItem.virtualFromRecurringEvent(
    RecurringEvent template, {
    DateTime? excludeDate,
  }) {
    var start = nextWeekdayOccurrence(template.weekday, template.hour, template.minute);
    if (excludeDate != null && _isSameDay(start, excludeDate)) {
      start = start.add(const Duration(days: 7));
    }
    final end = start.add(Duration(minutes: template.durationMinutes ?? Event.defaultDurationMinutes));
    final syntheticEvent = Event(
      id: 'virtual_${template.id}',
      title: template.title,
      description: template.description,
      location: template.location,
      dateTimeMillis: 0,
      flyerUrl: template.flyerUrl,
      flyerStoragePath: template.flyerStoragePath,
      category: template.category,
      requiresRegistration: false,
      registrationLink: '',
      likedBy: const [],
      status: EventStatus.published,
      source: EventSource.recurring,
      createdBy: template.createdBy,
      createdAt: null,
      audienceType: template.audienceType,
      targetMinistryIds: template.targetMinistryIds,
      targetMinistryNames: template.targetMinistryNames,
      churchArea: template.churchArea,
      durationMinutes: template.durationMinutes,
    );
    return AgendaCalendarItem(
      id: 'virtual_event_${template.id}',
      title: template.title,
      location: template.churchArea,
      start: start,
      end: end,
      isEvent: true,
      blocksCalendar: syntheticEvent.blocksCalendar,
      category: AgendaItemCategory.recurringEvent,
      event: syntheticEvent,
      recurrenceRule: 'FREQ=WEEKLY;INTERVAL=1;BYDAY=${_rruleWeekday(template.weekday)}',
      recurrenceExceptionDates: excludeDate == null ? null : [excludeDate],
    );
  }

  /// Mesma ideia de [virtualFromRecurringEvent], só que pra um molde de
  /// compromisso recorrente já aprovado e ativo.
  factory AgendaCalendarItem.virtualFromRecurringAgendaEntry(
    RecurringAgendaEntry template, {
    DateTime? excludeDate,
  }) {
    var start = nextWeekdayOccurrence(template.weekday, template.hour, template.minute);
    if (excludeDate != null && _isSameDay(start, excludeDate)) {
      start = start.add(const Duration(days: 7));
    }
    final end = start.add(Duration(minutes: template.durationMinutes));
    final syntheticEntry = AgendaEntry(
      id: 'virtual_${template.id}',
      audienceType: template.audienceType,
      ministryIds: template.ministryIds,
      ministryNames: template.ministryNames,
      title: template.title,
      description: template.description,
      location: template.location,
      startDateTime: start,
      endDateTime: end,
      createdByUid: template.createdByUid,
      createdByName: template.createdByName,
      recurringAgendaEntryId: template.id,
    );
    return AgendaCalendarItem(
      id: 'virtual_agenda_${template.id}',
      title: template.title,
      location: template.location,
      start: start,
      end: end,
      isEvent: false,
      blocksCalendar: true,
      category: AgendaItemCategory.recurringAgenda,
      entry: syntheticEntry,
      recurrenceRule: 'FREQ=WEEKLY;INTERVAL=1;BYDAY=${_rruleWeekday(template.weekday)}',
      recurrenceExceptionDates: excludeDate == null ? null : [excludeDate],
    );
  }
}

/// Mesma convenção de `weekday` usada em todo o app (Domingo=1..Sábado=7,
/// espelhando `Calendar.SUNDAY` do Java, ver `occurrenceInCurrentWeekMillis`
/// em `SIBValApp2/functions/index.js`) — próxima ocorrência (hoje inclusa,
/// se o horário ainda não passou) em America/Sao_Paulo.
DateTime nextWeekdayOccurrence(int weekday, int hour, int minute, {DateTime? from}) {
  final now = from ?? toSaoPauloTimeNow();
  final dartWeekday = weekday == 1 ? DateTime.sunday : weekday - 1;
  var daysUntil = (dartWeekday - now.weekday) % 7;
  if (daysUntil < 0) daysUntil += 7;
  var candidate = DateTime(now.year, now.month, now.day, hour, minute).add(Duration(days: daysUntil));
  if (!candidate.isAfter(now)) {
    candidate = candidate.add(const Duration(days: 7));
  }
  return candidate;
}

const _rruleWeekdays = {1: 'SU', 2: 'MO', 3: 'TU', 4: 'WE', 5: 'TH', 6: 'FR', 7: 'SA'};

String _rruleWeekday(int weekday) => _rruleWeekdays[weekday] ?? 'SU';

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Todo item visível no calendário/"Esta Semana": compromissos aprovados +
/// TODO evento publicado (bloqueando ou não — a distinção vira só cor/
/// cadeado, ver `agenda_page.dart`). Confirmado com o usuário: "Esta Semana"
/// mostra tudo que está aprovado, sem filtrar por ministério — a filtragem
/// por audiência/ministério (quando necessária) é feita à parte, só dentro
/// de `AgendaPage`. ALTERADO (03/09/2026, 4ª rodada, pedido do usuário: "os
/// agendamentos recorrentes, assim como os eventos recorrentes, já devem
/// ficar marcados no calendário todas as datas a frente") — além dos itens
/// concretos (compromisso aprovado/evento publicado), soma um item "virtual"
/// por molde recorrente ativo, representando a série inteira via
/// `Appointment.recurrenceRule` nativo do Syncfusion (ver
/// `AgendaCalendarItem.virtualFromRecurringEvent`/
/// `.virtualFromRecurringAgendaEntry`) — sem depender de uma instância nova
/// ser gerada em Firestore semana a semana pra aparecer no calendário.
final agendaCalendarItemsProvider = Provider.autoDispose<List<AgendaCalendarItem>>((ref) {
  final entries = ref.watch(approvedAgendaEntriesProvider);
  final events = ref.watch(calendarEventsProvider).asData?.value ?? const [];

  final activeRecurringEvents = ref
      .watch(recurringEventsProvider)
      .asData
      ?.value
      .where((e) => e.active)
      .toList() ??
      const [];
  final activeRecurringAgenda = ref.watch(activeRecurringAgendaEntriesProvider);

  final virtualItems = [
    for (final template in activeRecurringEvents)
      AgendaCalendarItem.virtualFromRecurringEvent(
        template,
        excludeDate: ref.watch(upcomingRecurringInstanceProvider(template.id)).asData?.value?.dateTimeSaoPaulo,
      ),
    for (final template in activeRecurringAgenda)
      AgendaCalendarItem.virtualFromRecurringAgendaEntry(
        template,
        excludeDate:
            ref.watch(upcomingRecurringAgendaInstanceProvider(template.id)).asData?.value?.startDateTime,
      ),
  ];

  return [
    for (final e in entries) AgendaCalendarItem.fromEntry(e),
    for (final e in events) AgendaCalendarItem.fromEvent(e),
    ...virtualItems,
  ];
});

/// Só os itens que de fato ocupam o calendário — usado na checagem de
/// conflito ao criar/remanejar um compromisso.
final agendaConflictItemsProvider = Provider.autoDispose<List<AgendaCalendarItem>>((ref) {
  return ref.watch(agendaCalendarItemsProvider).where((i) => i.blocksCalendar).toList();
});

/// Itens que colidem com [location]/[start]/[end] (`areasConflict`,
/// `lib/util/agenda_area.dart`), vindos de qualquer ministério/evento.
/// [excludeId] ignora o próprio compromisso sendo editado/remanejado.
/// [wholeVenue] é o conjunto de locais do catálogo marcados como "bloqueia
/// todo o espaço" (`wholeVenueLocationNames`).
List<AgendaCalendarItem> findAgendaConflicts(
  List<AgendaCalendarItem> occupants, {
  required String location,
  required DateTime start,
  required DateTime end,
  required Set<String> wholeVenue,
  String? excludeId,
}) {
  if (location.isEmpty) return const [];
  return occupants.where((o) {
    if (!o.isEvent && o.id == excludeId) return false;
    if (!areasConflict(location, o.location, wholeVenue)) return false;
    return start.isBefore(o.end) && end.isAfter(o.start);
  }).toList();
}
