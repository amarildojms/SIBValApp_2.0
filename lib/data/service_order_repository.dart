import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/service_order.dart';

/// Sem equivalente no app nativo — feature nova (27/08/2026), ver doc
/// comment de `ServiceOrder` (`lib/models/service_order.dart`).
class ServiceOrderRepository {
  ServiceOrderRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _serviceOrders =>
      _firestore.collection('serviceOrders');

  /// Data/hora da última ordem cadastrada — usada só pra pré-preencher o
  /// formulário de criação com o próximo domingo, 19h (ver
  /// `ServiceOrderFormPage._prefillDateTime`).
  Future<DateTime?> getLatestDateTime() async {
    final snapshot = await _serviceOrders
        .orderBy('dateTimeMillis', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final millis = (snapshot.docs.first.data()['dateTimeMillis'] as num?)
        ?.toInt();
    return millis != null ? DateTime.fromMillisecondsSinceEpoch(millis) : null;
  }

  Stream<List<ServiceOrder>> watchAll({int limit = 100}) {
    return _serviceOrders
        .orderBy('dateTimeMillis', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(ServiceOrder.fromFirestore).toList());
  }

  /// Uma ordem específica, em tempo real (28/08/2026, pedido do usuário —
  /// a visão do Louvor precisa refletir o progresso que o dirigente marca
  /// em `ServiceOrderLivePage` sem nenhuma ação própria, só observando).
  Stream<ServiceOrder?> watchOne(String id) {
    return _serviceOrders
        .doc(id)
        .snapshots()
        .map((doc) => doc.exists ? ServiceOrder.fromFirestore(doc) : null);
  }

  Future<void> create(ServiceOrder order) {
    return _serviceOrders.add({
      ...order.toFieldsMap(),
      'createdByUid': order.ownerUid,
      'createdByName': order.ownerName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Edição de uma ordem já cadastrada (28/08/2026, pedido do usuário —
  /// toque e segure numa ordem da lista) — `createdAt`/`createdByUid`/
  /// `createdByName` não são reescritos, só os campos editáveis.
  Future<void> update(String id, ServiceOrder order) {
    return _serviceOrders.doc(id).update(order.toFieldsMap());
  }

  Future<void> delete(String id) => _serviceOrders.doc(id).delete();

  /// Transferência de propriedade (28/08/2026, pedido do usuário) — só o
  /// admin consegue de fato gravar isso em produção. Quem passa a ser dono
  /// ganha o direito de iniciar o culto/marcar momentos dessa ordem; o dono
  /// anterior perde esse acesso. **Revisão de 29/08/2026**: admin já edita
  /// diretamente qualquer ordem (`update()` acima) sem precisar transferir
  /// primeiro — esta transferência agora serve só pra passar quem pode
  /// efetivamente *conduzir* o culto (iniciar/marcar momento), não mais como
  /// via indireta de edição.
  Future<void> transferOwner(String id, String ownerUid, String ownerName) {
    return _serviceOrders.doc(id).update({
      'ownerUid': ownerUid,
      'ownerName': ownerName,
    });
  }

  /// Progresso do modo apresentação (`ServiceOrderLivePage`, 28/08/2026,
  /// pedido do usuário) — grava só `completedMomentKeys`, nunca os outros
  /// campos, pra uma edição normal (`update`) nunca resetar isso e vice-versa.
  Future<void> updateProgress(String id, List<String> completedMomentKeys) {
    return _serviceOrders.doc(id).update({
      'completedMomentKeys': completedMomentKeys,
    });
  }

  /// Marca a ordem como finalizada (28/08/2026, pedido do usuário — botão
  /// "Finalizar Culto" ao concluir todos os momentos).
  Future<void> finalize(String id) {
    return _serviceOrders.doc(id).update({
      'isFinalized': true,
      'finalizedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Marca o momento em que o dirigente de fato tocou em "Iniciar Culto"
  /// (28/08/2026, pedido do usuário) — separado de `completedMomentKeys`/
  /// `isFinalized`, grava só `startedAt`, pra uma edição normal nunca
  /// resetar. É o que libera `ServiceOrderMemberViewPage` (demais membros/
  /// visitantes) de ficar travada no timer.
  Future<void> markStarted(String id) {
    return _serviceOrders.doc(id).update({
      'startedAt': FieldValue.serverTimestamp(),
    });
  }
}

final serviceOrderRepositoryProvider = Provider<ServiceOrderRepository>((ref) {
  return ServiceOrderRepository(FirebaseFirestore.instance);
});

final serviceOrdersProvider = StreamProvider.autoDispose<List<ServiceOrder>>((
  ref,
) {
  return ref.watch(serviceOrderRepositoryProvider).watchAll();
});

final serviceOrderStreamProvider =
    StreamProvider.autoDispose.family<ServiceOrder?, String>((ref, id) {
      return ref.watch(serviceOrderRepositoryProvider).watchOne(id);
    });
