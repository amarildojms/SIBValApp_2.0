import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/leader_schedule.dart';

/// Sem equivalente no app nativo — feature nova (28/08/2026), ver doc
/// comment de `LeaderScheduleEntry`.
class LeaderScheduleRepository {
  LeaderScheduleRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _entries =>
      _firestore.collection('leaderSchedules');

  /// Ascendente (mais próxima primeiro) — diferente de
  /// `ServiceOrderRepository.watchAll` (mais recente primeiro): aqui é uma
  /// agenda de planejamento futuro, não um histórico.
  Stream<List<LeaderScheduleEntry>> watchAll({int limit = 100}) {
    return _entries
        .orderBy('dateTimeMillis')
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(LeaderScheduleEntry.fromFirestore).toList());
  }

  Future<void> create(LeaderScheduleEntry entry) {
    return _entries.add({
      ...entry.toFieldsMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> update(String id, LeaderScheduleEntry entry) {
    return _entries.doc(id).update(entry.toFieldsMap());
  }

  Future<void> delete(String id) => _entries.doc(id).delete();
}

final leaderScheduleRepositoryProvider = Provider<LeaderScheduleRepository>((
  ref,
) {
  return LeaderScheduleRepository(FirebaseFirestore.instance);
});

final leaderSchedulesProvider =
    StreamProvider.autoDispose<List<LeaderScheduleEntry>>((ref) {
      return ref.watch(leaderScheduleRepositoryProvider).watchAll();
    });
