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

  /// Piso da consulta: início do dia atual em America/Sao_Paulo, não o
  /// instante exato de agora (29/08/2026, pedido do usuário) — um evento só
  /// deve sumir da lista no dia seguinte ao seu horário, não assim que o
  /// relógio passa da hora marcada. A limpeza de verdade (exclusão do
  /// documento) continua por conta da Cloud Function `deleteExpiredEvents`
  /// (roda 1x por dia, 3h da manhã em America/Sao_Paulo, apaga tudo com
  /// `dateTimeMillis` anterior àquele instante) — já tinha esse mesmo
  /// comportamento de "só no dia seguinte", o filtro client-side é que
  /// escondia o evento cedo demais.
  Future<List<Event>> getPublishedUpcoming() async {
    final spNow = toSaoPauloTimeNow();
    final spMidnight = DateTime.utc(spNow.year, spNow.month, spNow.day);
    final thresholdMillis = spMidnight.add(const Duration(hours: 3)).millisecondsSinceEpoch;
    final snapshot = await _events
        .where('status', isEqualTo: EventStatus.published)
        .where('dateTimeMillis', isGreaterThanOrEqualTo: thresholdMillis)
        .orderBy('dateTimeMillis')
        .get();
    return snapshot.docs.map(Event.fromFirestore).toList();
  }

  Future<List<Event>> getPending() async {
    final snapshot = await _events
        .where('status', isEqualTo: EventStatus.pending)
        .orderBy('dateTimeMillis')
        .get();
    return snapshot.docs.map(Event.fromFirestore).toList();
  }

  /// Tempo real — evita depender de sair/voltar da tela pra ver um evento
  /// importado por e-mail assim que ele é criado como pendente.
  Stream<List<Event>> watchPending() {
    return _events
        .where('status', isEqualTo: EventStatus.pending)
        .orderBy('dateTimeMillis')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Event.fromFirestore).toList());
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

final eventPendingProvider = StreamProvider.autoDispose<List<Event>>((ref) {
  return ref.watch(eventRepositoryProvider).watchPending();
});

enum EventsTab { pontual, recorrente }

final eventsTabProvider = StateProvider.autoDispose<EventsTab>((ref) => EventsTab.pontual);
