import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ministério cadastrado pelo admin/Secretaria (`ManageMinistriesPage`), com a
/// lista de cargos/funções disponíveis dentro dele. Selecionado pelos membros
/// em `members_page.dart` (`_MemberDialog`) — sem equivalente no app nativo,
/// mesma categoria de incremento que `admissionFormOptions`
/// (`church_membership_options.dart`).
///
/// [leaderUids] (03/09/2026, Agenda) — uids dos usuários com o cargo "Líder"
/// dentro deste ministério (ver `MemberRepository.update`, que mantém esta
/// lista sincronizada sempre que a Secretaria edita `MemberMinistry.cargos`
/// em Rol de Membros). É a fonte de verdade de quem pode agendar
/// compromissos (`agendaEntries`) para este ministério — tanto no cliente
/// (`myLedMinistryIdsProvider`) quanto em `firestore.rules`
/// (`isMinistryLeader`), já que a permissão de escrita não pode depender de
/// uma consulta livre em `members` (`list` não é liberado a não-admin).
class Ministry {
  const Ministry({
    required this.id,
    required this.name,
    required this.cargos,
    this.leaderUids = const [],
  });

  final String id;
  final String name;
  final List<String> cargos;
  final List<String> leaderUids;

  factory Ministry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Ministry(
      id: doc.id,
      name: data['name'] as String? ?? '',
      cargos: List<String>.from(data['cargos'] as List? ?? const []),
      leaderUids: List<String>.from(data['leaderUids'] as List? ?? const []),
    );
  }
}

class MinistryRepository {
  MinistryRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _ministries => _firestore.collection('ministries');

  Future<List<Ministry>> getAll() async {
    final snapshot = await _ministries.orderBy('name').get();
    return snapshot.docs.map(Ministry.fromFirestore).toList();
  }

  Future<void> create(String name) {
    return _ministries.add({
      'name': name.trim(),
      'cargos': <String>[],
      'leaderUids': <String>[],
    });
  }

  Future<void> renameMinistry(String id, String name) {
    return _ministries.doc(id).update({'name': name.trim()});
  }

  Future<void> delete(String id) {
    return _ministries.doc(id).delete();
  }

  Future<void> addCargo(String id, String cargo) {
    return _ministries.doc(id).update({
      'cargos': FieldValue.arrayUnion([cargo.trim()]),
    });
  }

  Future<void> removeCargo(String id, String cargo) {
    return _ministries.doc(id).update({
      'cargos': FieldValue.arrayRemove([cargo]),
    });
  }

  /// Mantido por `MemberRepository.update` (03/09/2026, Agenda) — ver doc
  /// comment de `Ministry.leaderUids`.
  Future<void> addLeader(String id, String uid) {
    return _ministries.doc(id).update({
      'leaderUids': FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> removeLeader(String id, String uid) {
    return _ministries.doc(id).update({
      'leaderUids': FieldValue.arrayRemove([uid]),
    });
  }
}

final ministryRepositoryProvider = Provider<MinistryRepository>((ref) {
  return MinistryRepository(FirebaseFirestore.instance);
});

final ministriesProvider = FutureProvider.autoDispose<List<Ministry>>((ref) {
  return ref.watch(ministryRepositoryProvider).getAll();
});
