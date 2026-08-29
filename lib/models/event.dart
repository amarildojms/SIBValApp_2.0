import 'package:cloud_firestore/cloud_firestore.dart';

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
  });

  DateTime get dateTimeUtc =>
      DateTime.fromMillisecondsSinceEpoch(dateTimeMillis, isUtc: true);

  DateTime get dateTimeSaoPaulo => toSaoPauloTime(dateTimeUtc);

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
    );
  }
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
