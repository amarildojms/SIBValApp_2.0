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

  DateTime get dateTimeUtc => DateTime.fromMillisecondsSinceEpoch(dateTimeMillis, isUtc: true);

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
    return Event(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      location: data['location'] as String? ?? '',
      dateTimeMillis: (data['dateTimeMillis'] as num?)?.toInt() ?? 0,
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
DateTime toSaoPauloTime(DateTime utc) => utc.toUtc().add(const Duration(hours: -3));

/// "Agora", em America/Sao_Paulo — usado para comparar com `toSaoPauloTime`
/// ao decidir se um evento é hoje/amanhã/já passou.
DateTime toSaoPauloTimeNow() => toSaoPauloTime(DateTime.now().toUtc());
