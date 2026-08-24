import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/visitor.dart';

/// Sem equivalente no app nativo — feature nova (24/08/2026), ver doc comment
/// de `Visitor`/`VisitorSummary` (`lib/models/visitor.dart`) para o desenho
/// completo de coleções/papéis.
class VisitorRepository {
  VisitorRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _visitors => _firestore.collection('visitors');

  CollectionReference<Map<String, dynamic>> get _summaries => _firestore.collection('visitorSummaries');

  /// Cria só o doc completo (`visitors/{id}`) — a Cloud Function
  /// `onVisitorCreated` espelha o resumo em `visitorSummaries` e notifica
  /// Dirigentes/admin, então não é feito aqui no cliente.
  Future<void> registerVisitor({
    required String name,
    required String phone,
    required String church,
    required bool firstVisit,
    required String createdByUid,
  }) {
    return _visitors.add({
      'name': name,
      'phone': phone,
      'church': church,
      'firstVisit': firstVisit,
      'createdByUid': createdByUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Lista completa (Recepção corrigindo o que ela mesma cadastrou, e
  /// Pastor com acesso de leitura aos dados completos) — só os visitantes de
  /// hoje (25/08/2026, pedido do usuário: "arquivar" no dia seguinte, ver
  /// `Visitor.isFromToday`). Os cadastros de dias anteriores continuam no
  /// Firestore, só somem da lista.
  Stream<List<Visitor>> watchAll({int limit = 200}) {
    return _visitors
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(Visitor.fromFirestore).where((v) => v.isFromToday).toList());
  }

  /// Recorte sem telefone (papel Dirigentes) — `visitorSummaries`, mantido
  /// pela Cloud Function. Mesmo filtro "só hoje" de `watchAll`.
  Stream<List<VisitorSummary>> watchSummaries({int limit = 200}) {
    return _summaries
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(VisitorSummary.fromFirestore).where((v) => v.isFromToday).toList());
  }

  /// Visitantes "arquivados" — dias anteriores a hoje (25/08/2026, ver
  /// `ArchivedVisitorsPage`, que agrupa por data). Limite maior que
  /// `watchAll` porque acumula com o tempo, sem o corte diário.
  Stream<List<Visitor>> watchArchived({int limit = 500}) {
    return _visitors
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(Visitor.fromFirestore).where((v) => !v.isFromToday).toList());
  }

  /// Recorte sem telefone dos arquivados (papel Dirigentes).
  Stream<List<VisitorSummary>> watchArchivedSummaries({int limit = 500}) {
    return _summaries
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(VisitorSummary.fromFirestore).where((v) => !v.isFromToday).toList());
  }

  /// Apaga os dois docs (completo + resumo) — só a Recepção corrige/remove
  /// um cadastro feito por engano; ver `firestore.rules` (`isRecepcao()`
  /// também libera `delete` em `visitorSummaries`, exclusivamente pra isso).
  Future<void> deleteVisitor(String id) async {
    final batch = _firestore.batch();
    batch.delete(_visitors.doc(id));
    batch.delete(_summaries.doc(id));
    await batch.commit();
  }
}

final visitorRepositoryProvider = Provider<VisitorRepository>((ref) {
  return VisitorRepository(FirebaseFirestore.instance);
});

final visitorsProvider = StreamProvider.autoDispose<List<Visitor>>((ref) {
  return ref.watch(visitorRepositoryProvider).watchAll();
});

final visitorSummariesProvider = StreamProvider.autoDispose<List<VisitorSummary>>((ref) {
  return ref.watch(visitorRepositoryProvider).watchSummaries();
});

final archivedVisitorsProvider = StreamProvider.autoDispose<List<Visitor>>((ref) {
  return ref.watch(visitorRepositoryProvider).watchArchived();
});

final archivedVisitorSummariesProvider = StreamProvider.autoDispose<List<VisitorSummary>>((ref) {
  return ref.watch(visitorRepositoryProvider).watchArchivedSummaries();
});
