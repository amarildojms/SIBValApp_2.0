import 'package:cloud_firestore/cloud_firestore.dart';

import '../util/agenda_area.dart';

/// Espelha app/src/main/java/com/sibval/app/data/model/Event.kt — mesma
/// coleção `events` no Firestore.
class Event {
  final String id;
  final String title;
  final String description;
  final String location;
  final int dateTimeMillis;
  final String flyerUrl;
  final String flyerStoragePath;
  final String category;
  final bool requiresRegistration;
  final String registrationLink;
  final List<String> likedBy;
  final String status;
  final String source;
  final String createdBy;
  final DateTime? createdAt;

  /// A quem o evento é destinado — `EventAudience.wholeChurch` (padrão, mesmo
  /// comportamento público de sempre) ou `.specificMinistries` (com
  /// [targetMinistryIds] preenchido). 03/09/2026, pedido do usuário —
  /// controla a exibição destacada dentro da Agenda
  /// (`lib/agenda/agenda_page.dart`), não a aba pública "Eventos". ALTERADO
  /// (mesma data, 4ª rodada): "Igreja e comunidade" foi retirado — só restam
  /// as duas opções — e o flag `isOpen` avulso foi removido: Aberto/Restrito
  /// deixou de ser uma escolha própria e passou a ser derivado direto daqui
  /// (`.specificMinistries` = Restrito, `.wholeChurch` = Aberto), ver
  /// `AgendaCalendarItem.hasMinistryAudience`.
  final String audienceType;
  final List<String> targetMinistryIds;
  final List<String> targetMinistryNames;

  /// Área da igreja usada pelo evento (catálogo `agendaLocations` + os dois
  /// valores reservados de `lib/util/agenda_area.dart`) — vazio quando ainda
  /// não informado (eventos anteriores a esta mudança). 03/09/2026, pedido do
  /// usuário: "enviados automaticamente para o calendário".
  final String churchArea;

  /// Duração em minutos (03/09/2026, 2ª rodada, pedido do usuário: "Eventos
  /// deve ganhar também o campo Duração, assim ele irá para o calendário
  /// respeitando a duração") — `null` num evento salvo antes desta mudança,
  /// cai pro palpite de 5h já usado (ver [defaultDurationMinutes]), só pra
  /// não quebrar dado existente.
  final int? durationMinutes;

  static const defaultDurationMinutes = 300;

  int get effectiveDurationMinutes => durationMinutes ?? defaultDurationMinutes;

  const Event({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.dateTimeMillis,
    required this.flyerUrl,
    required this.flyerStoragePath,
    required this.category,
    required this.requiresRegistration,
    required this.registrationLink,
    required this.likedBy,
    required this.status,
    required this.source,
    required this.createdBy,
    required this.createdAt,
    this.audienceType = EventAudience.wholeChurch,
    this.targetMinistryIds = const [],
    this.targetMinistryNames = const [],
    this.churchArea = '',
    this.durationMinutes,
  });

  /// `true` se este evento ocupa/bloqueia a Agenda — precisa de uma área
  /// informada e diferente de "Fora da Igreja" (evento fora da igreja não
  /// disputa espaço físico). Vazio (evento anterior a esta mudança, sem o
  /// campo preenchido) é tratado como não-bloqueante, não como "toda a
  /// igreja".
  bool get blocksCalendar =>
      churchArea.isNotEmpty && churchArea != kOutsideChurchArea;

  DateTime get dateTimeUtc =>
      DateTime.fromMillisecondsSinceEpoch(dateTimeMillis, isUtc: true);

  DateTime get dateTimeSaoPaulo => toSaoPauloTime(dateTimeUtc);

  DateTime get endDateTimeSaoPaulo =>
      dateTimeSaoPaulo.add(Duration(minutes: effectiveDurationMinutes));

  /// Verdadeiro assim que chega o horário de início do evento (fuso
  /// America/Sao_Paulo) — não diz sozinho até quando a tag "Iniciado" fica
  /// visível, ver [eventStartedTagVisible] pra isso.
  bool get hasStarted => !toSaoPauloTimeNow().isBefore(dateTimeSaoPaulo);

  Event copyWith({
    String? title,
    String? description,
    String? location,
    int? dateTimeMillis,
    String? flyerUrl,
    String? flyerStoragePath,
    String? category,
    bool? requiresRegistration,
    String? registrationLink,
    String? status,
    String? audienceType,
    List<String>? targetMinistryIds,
    List<String>? targetMinistryNames,
    String? churchArea,
    int? durationMinutes,
  }) {
    return Event(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      dateTimeMillis: dateTimeMillis ?? this.dateTimeMillis,
      flyerUrl: flyerUrl ?? this.flyerUrl,
      flyerStoragePath: flyerStoragePath ?? this.flyerStoragePath,
      category: category ?? this.category,
      requiresRegistration: requiresRegistration ?? this.requiresRegistration,
      registrationLink: registrationLink ?? this.registrationLink,
      likedBy: likedBy,
      status: status ?? this.status,
      source: source,
      createdBy: createdBy,
      createdAt: createdAt,
      audienceType: audienceType ?? this.audienceType,
      targetMinistryIds: targetMinistryIds ?? this.targetMinistryIds,
      targetMinistryNames: targetMinistryNames ?? this.targetMinistryNames,
      churchArea: churchArea ?? this.churchArea,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }

  factory Event.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final dateTimeMillis = (data['dateTimeMillis'] as num?)?.toInt() ?? 0;
    return Event(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      location: data['location'] as String? ?? '',
      dateTimeMillis: dateTimeMillis,
      flyerUrl: data['flyerUrl'] as String? ?? '',
      flyerStoragePath: data['flyerStoragePath'] as String? ?? '',
      category: data['category'] as String? ?? '',
      requiresRegistration: data['requiresRegistration'] as bool? ?? false,
      registrationLink: data['registrationLink'] as String? ?? '',
      likedBy: List<String>.from(data['likedBy'] as List? ?? const []),
      status: data['status'] as String? ?? EventStatus.published,
      source: data['source'] as String? ?? EventSource.manual,
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      audienceType: data['audienceType'] as String? ?? EventAudience.wholeChurch,
      targetMinistryIds: List<String>.from(
        data['targetMinistryIds'] as List? ?? const [],
      ),
      targetMinistryNames: List<String>.from(
        data['targetMinistryNames'] as List? ?? const [],
      ),
      churchArea: data['churchArea'] as String? ?? '',
      durationMinutes: (data['durationMinutes'] as num?)?.toInt(),
    );
  }
}

/// A quem um Evento é destinado (03/09/2026, pedido do usuário) — controla só
/// a exibição destacada dentro da Agenda, a aba pública "Eventos" continua
/// mostrando todo evento publicado independente disso. "Igreja e comunidade"
/// (`churchAndCommunity`) existiu entre a 3ª e a 4ª rodada da mesma data e foi
/// retirado a pedido do usuário — um evento antigo salvo com esse valor cai
/// no comportamento de "Aberto" (mesma regra de qualquer valor que não seja
/// [specificMinistries], ver `AgendaCalendarItem.hasMinistryAudience`), sem
/// precisar de migração.
abstract final class EventAudience {
  static const specificMinistries = 'specificMinistries';
  static const wholeChurch = 'wholeChurch';
}

abstract final class EventStatus {
  static const published = 'published';
  static const pending = 'pending';
  static const cancelled = 'cancelled';
}

abstract final class EventSource {
  static const manual = 'manual';
  static const email = 'email';
  static const recurring = 'recurring';
}

/// Espelha app/src/main/java/com/sibval/app/data/model/Event.kt (EventCategory).
abstract final class EventCategory {
  static const cultos = 'cultos';
  static const acampamento = 'acampamento';
  static const pgm = 'pgm';
  static const congresso = 'congresso';
  static const cursoWorkshop = 'curso_workshop';

  static const all = [cultos, acampamento, pgm, congresso, cursoWorkshop];
}

/// Sempre exibe o horário em America/Sao_Paulo, independente do fuso do
/// aparelho — mesma correção aplicada em EventDetailFragment.kt/EventAdapter.kt
/// (o Brasil não tem horário de verão desde 2019, então UTC-3 fixo é seguro).
DateTime toSaoPauloTime(DateTime utc) =>
    utc.toUtc().add(const Duration(hours: -3));

/// "Agora", em America/Sao_Paulo — usado para comparar com `toSaoPauloTime`
/// ao decidir se um evento é hoje/amanhã/já passou.
DateTime toSaoPauloTimeNow() => toSaoPauloTime(DateTime.now().toUtc());

/// Evento imediatamente seguinte a [event] que cai no mesmo dia civil (fuso
/// America/Sao_Paulo) — `null` se não houver nenhum, ou se o próximo evento
/// da lista já for em outro dia. [sortedEvents] precisa estar ordenado por
/// `dateTimeMillis` ascendente, mesma ordem que
/// `EventRepository.getPublishedUpcoming` já devolve (a tela "Confira nossas
/// programações" reaproveita essa mesma lista, antes de dividir por aba) —
/// como a lista é globalmente ordenada, o item logo depois de [event] nela,
/// se cair no mesmo dia, já é por definição o próximo evento daquele dia
/// (29/08/2026, pedido do usuário).
Event? nextEventSameDay(List<Event> sortedEvents, Event event) {
  final idx = sortedEvents.indexWhere((e) => e.id == event.id);
  if (idx == -1 || idx + 1 >= sortedEvents.length) return null;
  final next = sortedEvents[idx + 1];
  final day = event.dateTimeSaoPaulo;
  final nextDay = next.dateTimeSaoPaulo;
  if (day.year == nextDay.year &&
      day.month == nextDay.month &&
      day.day == nextDay.day) {
    return next;
  }
  return null;
}

/// Até quando a tag "Iniciado às HH:mm" (`event_started_tag.dart`) continua
/// visível pra um evento que já começou (29/08/2026, pedido do usuário) —
/// meia-noite do dia seguinte ao início, ou 6h antes do próximo evento que
/// cair no mesmo dia, o que vier primeiro (se houver um assim). Exemplo
/// prático dado pelo usuário: EBD às 9h30 de domingo com Culto de Louvor e
/// Adoração às 19h do mesmo domingo — a tag da EBD precisa sumir às 13h (6h
/// antes do Culto), não só à meia-noite; já a tag do Culto, sem nenhum outro
/// evento depois dele no mesmo dia, fica visível até a meia-noite de
/// segunda-feira. Antes, `Event.hasStarted` sozinho não tinha nenhum
/// critério de expiração — ficava visível o dia inteiro, mesmo com outro
/// evento chegando antes da meia-noite.
DateTime eventStartedTagExpiry(Event event, List<Event> sortedEvents) {
  final start = event.dateTimeSaoPaulo;
  final next = nextEventSameDay(sortedEvents, event);
  if (next != null) {
    return next.dateTimeSaoPaulo.subtract(const Duration(hours: 6));
  }
  return DateTime(start.year, start.month, start.day + 1);
}

/// Verdadeiro entre o início do evento e [eventStartedTagExpiry] — usado por
/// `event_card.dart`/`events_page.dart`/`event_detail_page.dart` pra decidir
/// se mostram a tag "Iniciado".
bool eventStartedTagVisible(Event event, List<Event> sortedEvents) {
  final now = toSaoPauloTimeNow();
  final start = event.dateTimeSaoPaulo;
  if (now.isBefore(start)) return false;
  return now.isBefore(eventStartedTagExpiry(event, sortedEvents));
}
