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
  final String category;
  final bool requiresRegistration;
  final String registrationLink;
  final List<String> likedBy;
  final String status;
  final String source;

  const Event({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.dateTimeMillis,
    required this.flyerUrl,
    required this.category,
    required this.requiresRegistration,
    required this.registrationLink,
    required this.likedBy,
    required this.status,
    required this.source,
  });

  DateTime get dateTimeUtc => DateTime.fromMillisecondsSinceEpoch(dateTimeMillis, isUtc: true);

  factory Event.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Event(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      location: data['location'] as String? ?? '',
      dateTimeMillis: (data['dateTimeMillis'] as num?)?.toInt() ?? 0,
      flyerUrl: data['flyerUrl'] as String? ?? '',
      category: data['category'] as String? ?? '',
      requiresRegistration: data['requiresRegistration'] as bool? ?? false,
      registrationLink: data['registrationLink'] as String? ?? '',
      likedBy: List<String>.from(data['likedBy'] as List? ?? const []),
      status: data['status'] as String? ?? EventStatus.published,
      source: data['source'] as String? ?? EventSource.manual,
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

/// Sempre exibe o horário em America/Sao_Paulo, independente do fuso do
/// aparelho — mesma correção aplicada em EventDetailFragment.kt/EventAdapter.kt
/// (o Brasil não tem horário de verão desde 2019, então UTC-3 fixo é seguro).
DateTime toSaoPauloTime(DateTime utc) => utc.toUtc().add(const Duration(hours: -3));
