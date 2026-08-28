import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cifra.dart';
import 'post_repository.dart' show currentUidProvider;
import 'user_repository.dart';

/// Sem equivalente no app nativo — feature nova (28/08/2026), ver doc
/// comment de `Cifra` (`lib/models/cifra.dart`). Doc id = songId (1 cifra
/// por música).
class CifraRepository {
  CifraRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('cifras');

  Stream<List<Cifra>> watchAll() {
    return _collection
        .orderBy('songName')
        .snapshots()
        .map((s) => s.docs.map(Cifra.fromFirestore).toList());
  }

  Stream<Cifra?> watchOne(String songId) {
    return _collection
        .doc(songId)
        .snapshots()
        .map((doc) => doc.exists ? Cifra.fromFirestore(doc) : null);
  }

  Future<Cifra?> getOne(String songId) async {
    final doc = await _collection.doc(songId).get();
    return doc.exists ? Cifra.fromFirestore(doc) : null;
  }

  /// Id novo pra uma cifra avulsa (28/08/2026, pedido do usuário — "deve ser
  /// possível incluir cifras além do que está no repertório"), sem precisar
  /// bater com nenhum `PraiseSong` existente.
  String newStandaloneId() => _collection.doc().id;

  Future<void> save(Cifra cifra) {
    return _collection.doc(cifra.songId).set(cifra.toMap());
  }

  Future<void> delete(String songId) => _collection.doc(songId).delete();
}

final cifraRepositoryProvider = Provider<CifraRepository>((ref) {
  return CifraRepository(FirebaseFirestore.instance);
});

final cifrasProvider = StreamProvider.autoDispose<List<Cifra>>((ref) {
  return ref.watch(cifraRepositoryProvider).watchAll();
});

final cifraForSongProvider = StreamProvider.autoDispose.family<Cifra?, String>((
  ref,
  songId,
) {
  return ref.watch(cifraRepositoryProvider).watchOne(songId);
});

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário: "não deve existir o papel cifrista, esta atribuição será dada
/// individualmente direto ao usuário que o admin selecionar"). Guarda a
/// lista de uids liberados a editar/incluir cifra num único documento
/// (`settings/cifraEditors`), em vez de um papel em `users/{uid}.roles` —
/// gerenciado pelo botão de configuração (admin-only) dentro de
/// `CifraListPage`. `SIBValApp2/firestore.rules` espelha essa mesma lista
/// via `isCifraEditor()` (`get()` no documento), tanto pra `read` quanto
/// `write` de `cifras`.
class CifraEditorsRepository {
  CifraEditorsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection('settings').doc('cifraEditors');

  Stream<List<String>> watchUids() {
    return _doc.snapshots().map(
      (doc) => List<String>.from(doc.data()?['uids'] as List? ?? const []),
    );
  }

  Future<void> setUids(List<String> uids) => _doc.set({'uids': uids});
}

final cifraEditorsRepositoryProvider = Provider<CifraEditorsRepository>((ref) {
  return CifraEditorsRepository(FirebaseFirestore.instance);
});

final cifraEditorUidsProvider = StreamProvider.autoDispose<List<String>>((ref) {
  return ref.watch(cifraEditorsRepositoryProvider).watchUids();
});

/// `true` se o usuário logado pode incluir/editar cifra — admin sempre, ou
/// quem o admin selecionou individualmente (`cifraEditorUidsProvider`).
final canEditCifrasProvider = Provider.autoDispose<bool>((ref) {
  final profile = ref.watch(currentUserProfileProvider).asData?.value;
  if (profile == null) return false;
  if (profile.isAdmin) return true;
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return false;
  final uids = ref.watch(cifraEditorUidsProvider).asData?.value ?? const [];
  return uids.contains(uid);
});
