import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/event.dart';
import '../models/recurring_event.dart';

/// Espelha app/src/main/java/com/sibval/app/data/repository/RecurringEventRepository.kt.
class RecurringEventRepository {
  RecurringEventRepository(this._firestore, this._storage);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _recurringEvents => _firestore.collection('recurringEvents');
  CollectionReference<Map<String, dynamic>> get _events => _firestore.collection('events');

  Future<List<RecurringEvent>> getAll() async {
    final snapshot = await _recurringEvents.orderBy('weekday').get();
    return snapshot.docs.map(RecurringEvent.fromFirestore).toList();
  }

  Future<RecurringEvent?> getById(String id) async {
    final doc = await _recurringEvents.doc(id).get();
    return doc.exists ? RecurringEvent.fromFirestore(doc) : null;
  }

  Future<void> create(RecurringEvent event, String createdBy) {
    final doc = _recurringEvents.doc();
    return doc.set({
      'title': event.title,
      'description': event.description,
      'location': event.location,
      'category': event.category,
      'weekday': event.weekday,
      'hour': event.hour,
      'minute': event.minute,
      'flyerUrl': event.flyerUrl,
      'flyerStoragePath': event.flyerStoragePath,
      'reminderLeadMinutes': event.reminderLeadMinutes,
      'active': event.active,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'audienceType': event.audienceType,
      'targetMinistryIds': event.targetMinistryIds,
      'targetMinistryNames': event.targetMinistryNames,
      'churchArea': event.churchArea,
      'durationMinutes': event.durationMinutes,
    });
  }

  /// Atualiza o molde da série. Não altera a instância já gerada (se houver) —
  /// a mudança passa a valer a partir da próxima geração. Para editar só a
  /// ocorrência atual, use [applyEditToUpcomingInstance].
  Future<void> update(RecurringEvent event) {
    return _recurringEvents.doc(event.id).update({
      'title': event.title,
      'description': event.description,
      'location': event.location,
      'category': event.category,
      'weekday': event.weekday,
      'hour': event.hour,
      'minute': event.minute,
      'reminderLeadMinutes': event.reminderLeadMinutes,
      'active': event.active,
      'audienceType': event.audienceType,
      'targetMinistryIds': event.targetMinistryIds,
      'targetMinistryNames': event.targetMinistryNames,
      'churchArea': event.churchArea,
      'durationMinutes': event.durationMinutes,
    });
  }

  /// Aplica as edições só na instância já publicada desta série (se existir
  /// uma futura). Retorna `false` quando ainda não há instância gerada — quem
  /// chamar decide o que fazer (ex.: cair para [update]).
  Future<bool> applyEditToUpcomingInstance(RecurringEvent event) async {
    final doc = await _findUpcomingInstance(event.id);
    if (doc == null) return false;
    await doc.reference.update({
      'title': event.title,
      'description': event.description,
      'location': event.location,
      'category': event.category,
      'audienceType': event.audienceType,
      'targetMinistryIds': event.targetMinistryIds,
      'targetMinistryNames': event.targetMinistryNames,
      'churchArea': event.churchArea,
      'durationMinutes': event.durationMinutes,
    });
    return true;
  }

  Future<void> setActive(String id, bool active) {
    return _recurringEvents.doc(id).update({'active': active});
  }

  /// Desativa a série inteira (para de gerar novas ocorrências) e cancela a
  /// instância futura, se houver.
  Future<void> deactivateSeries(String id) async {
    await _recurringEvents.doc(id).update({'active': false});
    await _cancelUpcomingInstance(id);
  }

  /// Cancela só a próxima ocorrência já gerada; a série continua ativa para
  /// as semanas seguintes.
  Future<void> cancelNextOccurrenceOnly(String id) {
    return _cancelUpcomingInstance(id);
  }

  /// Instância publicada mais próxima da série, qualquer status — usada pra
  /// mostrar na lista quando a ocorrência desta semana foi cancelada
  /// avulsamente (ver [cancelNextOccurrenceOnly]) e oferecer o botão de
  /// remarcar ([reactivateUpcomingInstance]).
  Future<Event?> getUpcomingInstance(String recurringEventId) async {
    final doc = await _findUpcomingInstance(recurringEventId);
    return doc == null ? null : Event.fromFirestore(doc);
  }

  /// Desfaz o cancelamento avulso da próxima ocorrência: volta o `status`
  /// para `published`. O post some/volta ao feed em tempo real sozinho —
  /// quem cuida disso é a Cloud Function `onEventUpdatedFeedSync`, que reage
  /// a qualquer mudança de status no documento do evento.
  Future<void> reactivateUpcomingInstance(String recurringEventId) async {
    final doc = await _findUpcomingInstance(recurringEventId);
    if (doc == null) return;
    await doc.reference.update({'status': EventStatus.published});
  }

  Future<void> _cancelUpcomingInstance(String recurringEventId) async {
    final doc = await _findUpcomingInstance(recurringEventId);
    if (doc == null) return;
    await doc.reference.update({'status': EventStatus.cancelled});
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _findUpcomingInstance(String recurringEventId) async {
    final snapshot = await _events
        .where('recurringEventId', isEqualTo: recurringEventId)
        .where('dateTimeMillis', isGreaterThanOrEqualTo: DateTime.now().millisecondsSinceEpoch)
        .orderBy('dateTimeMillis')
        .limit(1)
        .get();
    return snapshot.docs.firstOrNull;
  }

  /// Exclui a série e também qualquer instância já publicada em `events` para
  /// ela. O flyer da instância não é apagado do Storage: pode ser o mesmo
  /// arquivo compartilhado do padrão de categoria no Repositório de Flyers.
  Future<void> delete(RecurringEvent event) async {
    final instancesSnap = await _events.where('recurringEventId', isEqualTo: event.id).get();
    for (final instanceDoc in instancesSnap.docs) {
      await instanceDoc.reference.delete();
    }
    if (event.flyerStoragePath.isNotEmpty) {
      try {
        await _storage.ref(event.flyerStoragePath).delete();
      } catch (_) {}
    }
    await _recurringEvents.doc(event.id).delete();
  }
}

final recurringEventRepositoryProvider = Provider<RecurringEventRepository>((ref) {
  return RecurringEventRepository(FirebaseFirestore.instance, FirebaseStorage.instance);
});

final recurringEventsProvider = FutureProvider.autoDispose<List<RecurringEvent>>((ref) {
  return ref.watch(recurringEventRepositoryProvider).getAll();
});

/// Instância mais próxima de uma série (qualquer status) — usada na lista
/// pra saber se a ocorrência desta semana está cancelada e mostrar o botão
/// de remarcar.
final upcomingRecurringInstanceProvider = FutureProvider.autoDispose.family<Event?, String>((ref, recurringEventId) {
  return ref.watch(recurringEventRepositoryProvider).getUpcomingInstance(recurringEventId);
});
