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

  /// Domingo da semana que contém [date] — chave (`weeklyRepertoires/{id}`)
  /// e ponto de partida do repertório semanal.
  static DateTime sundayOf(DateTime date) {
    final sunday = date.subtract(Duration(days: date.weekday % 7));
    return DateTime(sunday.year, sunday.month, sunday.day);
  }

  static String weekKeyFor(DateTime date) => _weekKeyFormat.format(sundayOf(date));

  // Repertório mensal (catálogo mestre de músicas).
  Stream<List<PraiseSong>> watchSongs() {
    return _songs
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map(PraiseSong.fromFirestore).toList());
  }

  Future<void> createSong(String name, String artist) {
    return _songs.add({'name': name, 'artist': artist});
  }

  Future<void> updateSong(String id, String name, String artist) {
    return _songs.doc(id).update({'name': name, 'artist': artist});
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
