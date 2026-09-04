import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/agenda_entry.dart';
import '../models/recurring_agenda_entry.dart';

/// Espelha `RecurringEventRepository` (`lib/data/recurring_event_repository.dart`)
/// — molde em `recurringAgendaEntries`; as instâncias geradas semanalmente
/// ficam em `agendaEntries` (mesma coleção dos compromissos avulsos,
/// `AgendaEntry.recurringAgendaEntryId` aponta pro molde). Diferente de
/// Eventos: a geração da instância só acontece depois que a série é
/// aprovada (`RecurringAgendaEntryStatus.approved`) — enquanto `pending`,
/// nenhuma ocorrência é gerada.
class RecurringAgendaEntryRepository {
  RecurringAgendaEntryRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _templates =>
      _firestore.collection('recurringAgendaEntries');
  CollectionReference<Map<String, dynamic>> get _entries =>
      _firestore.collection('agendaEntries');

  Stream<List<RecurringAgendaEntry>> watchAll() {
    return _templates
        .orderBy('weekday')
        .snapshots()
        .map((s) => s.docs.map(RecurringAgendaEntry.fromFirestore).toList());
  }

  Future<void> create(RecurringAgendaEntry entry) => _templates.add({
    ...entry.toContentMap(),
    'active': true,
    'status': RecurringAgendaEntryStatus.pending,
    'rejectionReason': '',
    'approvedByUid': '',
    'approvedByName': '',
    'decidedAt': null,
    'createdAt': FieldValue.serverTimestamp(),
  });

  Future<void> approve(String id, {required String approverUid, required String approverName}) {
    return _templates.doc(id).update({
      'status': RecurringAgendaEntryStatus.approved,
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
    return _templates.doc(id).update({
      'status': RecurringAgendaEntryStatus.rejected,
      'rejectionReason': reason,
      'approvedByUid': approverUid,
      'approvedByName': approverName,
      'decidedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Desativa a série inteira (para de gerar novas ocorrências) e cancela a
  /// instância futura, se houver — ação do aprovador.
  Future<void> deactivateSeries(String id) async {
    await _templates.doc(id).update({'active': false});
    await _cancelUpcomingInstance(id);
  }

  /// Cancela só a próxima ocorrência já gerada; a série continua ativa para
  /// as semanas seguintes (03/09/2026, pedido do usuário: "Um evento
  /// recorrente que é interrompido em um dia ou mais, deve ser removido do
  /// calendário para estes determinados dias também").
  Future<void> cancelNextOccurrenceOnly(String id) => _cancelUpcomingInstance(id);

  /// Instância mais próxima da série, qualquer status — usada pra mostrar se
  /// a ocorrência desta semana está cancelada e oferecer "remarcar".
  Future<AgendaEntry?> getUpcomingInstance(String recurringAgendaEntryId) async {
    final doc = await _findUpcomingInstance(recurringAgendaEntryId);
    return doc == null ? null : AgendaEntry.fromFirestore(doc);
  }

  Future<void> reactivateUpcomingInstance(String recurringAgendaEntryId) async {
    final doc = await _findUpcomingInstance(recurringAgendaEntryId);
    if (doc == null) return;
    await doc.reference.update({'status': AgendaEntryStatus.approved});
  }

  Future<void> _cancelUpcomingInstance(String recurringAgendaEntryId) async {
    final doc = await _findUpcomingInstance(recurringAgendaEntryId);
    if (doc == null) return;
    await doc.reference.update({'status': AgendaEntryStatus.cancelled});
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _findUpcomingInstance(
    String recurringAgendaEntryId,
  ) async {
    final snapshot = await _entries
        .where('recurringAgendaEntryId', isEqualTo: recurringAgendaEntryId)
        .where('startDateTime', isGreaterThanOrEqualTo: Timestamp.now())
        .orderBy('startDateTime')
        .limit(1)
        .get();
    return snapshot.docs.firstOrNull;
  }
}

final recurringAgendaEntryRepositoryProvider = Provider<RecurringAgendaEntryRepository>((ref) {
  return RecurringAgendaEntryRepository(FirebaseFirestore.instance);
});

final recurringAgendaEntriesProvider = StreamProvider.autoDispose<List<RecurringAgendaEntry>>((
  ref,
) {
  return ref.watch(recurringAgendaEntryRepositoryProvider).watchAll();
});

final pendingRecurringAgendaEntriesProvider =
    Provider.autoDispose<List<RecurringAgendaEntry>>((ref) {
  final all = ref.watch(recurringAgendaEntriesProvider).asData?.value ?? const [];
  return all.where((e) => e.status == RecurringAgendaEntryStatus.pending).toList();
});

final activeRecurringAgendaEntriesProvider =
    Provider.autoDispose<List<RecurringAgendaEntry>>((ref) {
  final all = ref.watch(recurringAgendaEntriesProvider).asData?.value ?? const [];
  return all
      .where((e) => e.status == RecurringAgendaEntryStatus.approved && e.active)
      .toList();
});

final upcomingRecurringAgendaInstanceProvider =
    FutureProvider.autoDispose.family<AgendaEntry?, String>((ref, recurringAgendaEntryId) {
  return ref
      .watch(recurringAgendaEntryRepositoryProvider)
      .getUpcomingInstance(recurringAgendaEntryId);
});
