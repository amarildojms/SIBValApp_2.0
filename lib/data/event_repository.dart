import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/event.dart';

/// Espelha app/src/main/java/com/sibval/app/data/repository/EventRepository.kt.
class EventRepository {
  EventRepository(this._firestore, this._storage);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _events => _firestore.collection('events');

  /// Filtra por `endDateTimeMillis` (não `dateTimeMillis`) em memória, e não na query —
  /// um evento de vários dias que já começou mas ainda não terminou tem `dateTimeMillis`
  /// (o início) no passado, mas ainda deve aparecer na lista. `Event.fromFirestore` já
  /// resolve `endDateTimeMillis` ausente (docs de antes de eventos multi-dia existirem)
  /// caindo pro início, então o filtro funciona igual pros dois casos.
  Future<List<Event>> getPublishedUpcoming() async {
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    final snapshot = await _events
        .where('status', isEqualTo: EventStatus.published)
        .orderBy('dateTimeMillis')
        .get();
    return snapshot.docs
        .map(Event.fromFirestore)
        .where((event) => event.endDateTimeMillis >= nowMillis)
        .toList();
  }

  Future<List<Event>> getPending() async {
    final snapshot = await _events
        .where('status', isEqualTo: EventStatus.pending)
        .orderBy('dateTimeMillis')
        .get();
    return snapshot.docs.map(Event.fromFirestore).toList();
  }

  Future<Event?> getById(String id) async {
    final doc = await _events.doc(id).get();
    return doc.exists ? Event.fromFirestore(doc) : null;
  }

  Future<void> create(Event event, File? flyerFile, String createdBy) async {
    final doc = _events.doc();
    String flyerUrl = '';
    String flyerStoragePath = '';
    if (flyerFile != null) {
      flyerStoragePath = 'events/${doc.id}.jpg';
      final ref = _storage.ref(flyerStoragePath);
      await ref.putFile(flyerFile);
      flyerUrl = await ref.getDownloadURL();
    }
    await doc.set({
      'title': event.title,
      'description': event.description,
      'location': event.location,
      'dateTimeMillis': event.dateTimeMillis,
      'endDateTimeMillis': event.endDateTimeMillis,
      'category': event.category,
      'requiresRegistration': event.requiresRegistration,
      'registrationLink': event.registrationLink,
      'flyerUrl': flyerUrl,
      'flyerStoragePath': flyerStoragePath,
      'likedBy': const <String>[],
      'status': EventStatus.published,
      'source': EventSource.manual,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      // Rastreamento de post no feed dia-a-dia (ver postEventDaysToFeed em functions/index.js).
      // postedToFeed só vira true quando o último dia do evento já foi postado.
      'postedFeedDays': const <String>[],
      'postedToFeed': false,
    });
  }

  Future<void> update(Event event, File? newFlyerFile) {
    return _updateFields(event, newFlyerFile, const {});
  }

  /// Salva as edições feitas na revisão e publica o evento num só passo.
  Future<void> updateAndApprove(Event event, File? newFlyerFile) {
    return _updateFields(event, newFlyerFile, {'status': EventStatus.published});
  }

  Future<void> _updateFields(Event event, File? newFlyerFile, Map<String, Object?> extraFields) async {
    var flyerUrl = event.flyerUrl;
    var flyerStoragePath = event.flyerStoragePath;
    if (newFlyerFile != null) {
      flyerStoragePath = 'events/${event.id}.jpg';
      final ref = _storage.ref(flyerStoragePath);
      await ref.putFile(newFlyerFile);
      flyerUrl = await ref.getDownloadURL();
    }
    await _events.doc(event.id).update({
      'title': event.title,
      'description': event.description,
      'location': event.location,
      'dateTimeMillis': event.dateTimeMillis,
      'endDateTimeMillis': event.endDateTimeMillis,
      'category': event.category,
      'requiresRegistration': event.requiresRegistration,
      'registrationLink': event.registrationLink,
      'flyerUrl': flyerUrl,
      'flyerStoragePath': flyerStoragePath,
      ...extraFields,
    });
  }

  Future<void> delete(Event event) async {
    if (event.flyerStoragePath.isNotEmpty) {
      try {
        await _storage.ref(event.flyerStoragePath).delete();
      } catch (_) {}
    }
    await _events.doc(event.id).delete();
  }

  Future<void> toggleLike(String eventId, String uid, bool liked) {
    return _events.doc(eventId).update({
      'likedBy': liked ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
    });
  }
}

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(FirebaseFirestore.instance, FirebaseStorage.instance);
});

final eventsProvider = FutureProvider.autoDispose<List<Event>>((ref) {
  return ref.watch(eventRepositoryProvider).getPublishedUpcoming();
});

final eventPendingProvider = FutureProvider.autoDispose<List<Event>>((ref) {
  return ref.watch(eventRepositoryProvider).getPending();
});

enum EventsTab { pontual, recorrente }

final eventsTabProvider = StateProvider.autoDispose<EventsTab>((ref) => EventsTab.pontual);
