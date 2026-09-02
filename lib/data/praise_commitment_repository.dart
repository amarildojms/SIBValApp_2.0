import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'post_repository.dart' show currentUidProvider;

/// Sem equivalente no app nativo — feature nova (02/09/2026, pedido do
/// usuário). "Termo de Compromisso com a Igreja" — todo integrante do
/// Ministério de Louvor precisa ler o termo inteiro e marcar cada item
/// (`PraiseCommitmentTermPage`) antes de acessar `PraiseMinistryPage` pela
/// primeira vez. Aceite guardado em `praiseCommitments/{uid}` (doc id = uid,
/// existência do doc = já aceitou) — coleção própria, separada de
/// `users/{uid}`, só pra não misturar esse aceite com o restante do perfil.
class PraiseCommitmentRepository {
  PraiseCommitmentRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('praiseCommitments');

  Future<bool> hasAccepted(String uid) async {
    final doc = await _collection.doc(uid).get();
    return doc.exists;
  }

  Future<void> accept(String uid) {
    return _collection.doc(uid).set({'acceptedAt': FieldValue.serverTimestamp()});
  }
}

final praiseCommitmentRepositoryProvider = Provider<PraiseCommitmentRepository>((
  ref,
) {
  return PraiseCommitmentRepository(FirebaseFirestore.instance);
});

/// `null` enquanto carrega/sem uid — tratado como "ainda não aceitou" pelo
/// ponto de chamada (`openPraiseMinistry`), que aí mostra o termo.
final praiseCommitmentAcceptedProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return false;
  return ref.watch(praiseCommitmentRepositoryProvider).hasAccepted(uid);
});
