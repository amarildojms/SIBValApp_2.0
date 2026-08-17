import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/event.dart';

/// Espelha app/src/main/java/com/sibval/app/data/repository/EventRepository.kt.
class EventRepository {
  EventRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _events => _firestore.collection('events');

  Future<List<Event>> getPublishedUpcoming() async {
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    final snapshot = await _events
        .where('status', isEqualTo: EventStatus.published)
        .where('dateTimeMillis', isGreaterThanOrEqualTo: nowMillis)
        .orderBy('dateTimeMillis')
        .get();
    return snapshot.docs.map(Event.fromFirestore).toList();
  }

  Future<void> toggleLike(String eventId, String uid, bool liked) {
    return _events.doc(eventId).update({
      'likedBy': liked ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
    });
  }
}

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(FirebaseFirestore.instance);
});

final eventsProvider = FutureProvider.autoDispose<List<Event>>((ref) {
  return ref.watch(eventRepositoryProvider).getPublishedUpcoming();
});

enum EventsTab { pontual, recorrente }

final eventsTabProvider = StateProvider.autoDispose<EventsTab>((ref) => EventsTab.pontual);
