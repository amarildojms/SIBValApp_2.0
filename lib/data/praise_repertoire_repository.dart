import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/praise_repertoire.dart';

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário). Ver doc comment de `PraiseSong`/`WeeklyRepertoire`
/// (`lib/models/praise_repertoire.dart`).
class PraiseRepertoireRepository {
  PraiseRepertoireRepository(this._firestore);

  final FirebaseFirestore _firestore;

  static final _weekKeyFormat = DateFormat('yyyy-MM-dd');

  CollectionReference<Map<String, dynamic>> get _songs =>
      _firestore.collection('praiseSongs');
  CollectionReference<Map<String, dynamic>> get _weeklyRepertoires =>
      _firestore.collection('weeklyRepertoires');

  /// Chave (`weeklyRepertoires/{id}`) do repertório de [date] — o dia
  /// exato, sem "arredondar" pro domingo da semana. Antes (`sundayOf`,
  /// removido em 03/09/2026) qualquer dia dentro da mesma semana caía no
  /// repertório do domingo anterior — bug relatado pelo usuário: uma Ordem
  /// de Culto cadastrada pra terça (01/09) buscava as músicas do repertório
  /// de domingo (30/08), só porque as duas datas caem na "mesma semana".
  /// Pedido explícito: música só é atribuída a um momento "Louvor" quando
  /// existe repertório semanal com a **mesma data exata** da Ordem de
  /// Culto — sem repertório pra aquele dia específico, os momentos "Louvor"
  /// simplesmente ficam sem música (`ServiceOrderLivePage`/
  /// `ServiceOrderPraiseViewPage` já tratam `WeeklyRepertoire? == null`).
  static String weekKeyFor(DateTime date) =>
      _weekKeyFormat.format(DateTime(date.year, date.month, date.day));

  // Repertório mensal (catálogo mestre de músicas).
  Stream<List<PraiseSong>> watchSongs() {
    return _songs
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map(PraiseSong.fromFirestore).toList());
  }

  Future<void> createSong(PraiseSong song) {
    return _songs.add(song.toMap());
  }

  Future<void> updateSong(String id, PraiseSong song) {
    return _songs.doc(id).update(song.toMap());
  }

  Future<void> deleteSong(String id) => _songs.doc(id).delete();

  // Repertório semanal.
  Stream<List<WeeklyRepertoire>> watchWeeklyRepertoires({int limit = 100}) {
    return _weeklyRepertoires
        .orderBy('weekDateMillis', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(WeeklyRepertoire.fromFirestore).toList());
  }

  Future<WeeklyRepertoire?> getWeeklyRepertoire(String weekKey) async {
    final doc = await _weeklyRepertoires.doc(weekKey).get();
    return doc.exists ? WeeklyRepertoire.fromFirestore(doc) : null;
  }

  /// Busca o repertório da semana de [date] — usado por `ServiceOrderLivePage`
  /// pra preencher os momentos "Louvor" automaticamente. `null` se a semana
  /// ainda não tem repertório cadastrado.
  Future<WeeklyRepertoire?> getForDate(DateTime date) =>
      getWeeklyRepertoire(weekKeyFor(date));

  Future<void> saveWeeklyRepertoire(WeeklyRepertoire repertoire) {
    final key = weekKeyFor(repertoire.weekDate);
    return _weeklyRepertoires.doc(key).set(repertoire.toMap());
  }

  Future<void> deleteWeeklyRepertoire(String id) =>
      _weeklyRepertoires.doc(id).delete();
}

final praiseRepertoireRepositoryProvider = Provider<PraiseRepertoireRepository>((
  ref,
) {
  return PraiseRepertoireRepository(FirebaseFirestore.instance);
});

final praiseSongsProvider = StreamProvider.autoDispose<List<PraiseSong>>((ref) {
  return ref.watch(praiseRepertoireRepositoryProvider).watchSongs();
});

final weeklyRepertoiresProvider =
    StreamProvider.autoDispose<List<WeeklyRepertoire>>((ref) {
      return ref.watch(praiseRepertoireRepositoryProvider).watchWeeklyRepertoires();
    });

/// Repertório da semana de uma data específica (28/08/2026) — usado tanto
/// por `ServiceOrderLivePage` (dirigente) quanto por
/// `ServiceOrderPraiseViewPage` (Louvor), pra não duplicar a busca manual
/// em cada tela.
final weeklyRepertoireForDateProvider =
    FutureProvider.autoDispose.family<WeeklyRepertoire?, DateTime>((ref, date) {
      return ref.watch(praiseRepertoireRepositoryProvider).getForDate(date);
    });

/// Espelho dos nomes de quem tem o papel Louvor (02/09/2026, pedido do
/// usuário: "em adicionar solista, deve buscar entre os membros que tem o
/// papel Louvor") — `settings/louvorMembers.names`, mapa uid→nome. Não dá
/// pra consultar `users` direto pra isso: `firestore.rules` só libera
/// `list` nessa coleção pra admin, e quem cadastra uma música pode ser só
/// Louvor (não-admin) — mesmo problema já documentado no CLAUDE.md pra
/// "Convidado por" da Introdução, resolvido lá com `members`; aqui não dá
/// pra usar `members` porque o papel Louvor não é um ministério
/// sincronizado, é atribuído direto ao usuário. Mantido pelo próprio
/// `manage_users_page.dart` (só admin, que já escreve em `settings/*`) toda
/// vez que o chip "Louvor" é marcado/desmarcado — sem precisar de regra nova
/// (`settings/{docId}` já libera leitura pra qualquer autenticado e escrita
/// pra admin).
class PraiseLouvorMembersRepository {
  PraiseLouvorMembersRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection('settings').doc('louvorMembers');

  Stream<List<String>> watchNames() {
    return _doc.snapshots().map((doc) {
      final names = doc.data()?['names'] as Map<String, dynamic>?;
      if (names == null || names.isEmpty) return const <String>[];
      return names.values.cast<String>().toList()..sort();
    });
  }

  Future<void> setMember(String uid, String name, bool isMember) {
    return _doc.set({
      'names': {uid: isMember ? name : FieldValue.delete()},
    }, SetOptions(merge: true));
  }
}

final praiseLouvorMembersRepositoryProvider = Provider<PraiseLouvorMembersRepository>((
  ref,
) {
  return PraiseLouvorMembersRepository(FirebaseFirestore.instance);
});

final louvorMemberNamesProvider = StreamProvider.autoDispose<List<String>>((ref) {
  return ref.watch(praiseLouvorMembersRepositoryProvider).watchNames();
});
