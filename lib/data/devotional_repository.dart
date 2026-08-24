import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/devotional.dart';
import 'post_repository.dart' show currentUidProvider;

/// Espelha app/src/main/java/com/sibval/app/data/repository/DevotionalRepository.kt.
class DevotionalRepository {
  DevotionalRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _devotionals => _firestore.collection('devotionals');

  static String dateKeyOf(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  /// Tempo real (24/08/2026) — a lista e o badge de não lidas (bottom nav
  /// "Devocionais") devem refletir uma devocional nova/editada assim que ela
  /// chega, sem esperar um refresh manual. Ver `devotionalsProvider`.
  Stream<List<Devotional>> watchPublished({int limit = 60}) {
    final todayKey = dateKeyOf(DateTime.now());
    return _devotionals
        .where('dateKey', isLessThanOrEqualTo: todayKey)
        .orderBy('dateKey', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(Devotional.fromFirestore).toList());
  }

  Future<Devotional?> getById(String id) async {
    final doc = await _devotionals.doc(id).get();
    return doc.exists ? Devotional.fromFirestore(doc) : null;
  }

  /// Todas as devocionais (inclusive futuras), mais recente primeiro — usado
  /// no repositório de gerenciamento (admin/Secretaria).
  Future<List<Devotional>> getAll({int limit = 200}) async {
    final snapshot = await _devotionals.orderBy('dateMillis', descending: true).limit(limit).get();
    return snapshot.docs.map(Devotional.fromFirestore).toList();
  }

  Future<void> markRead(String id, String uid) {
    return _devotionals.doc(id).update({
      'readBy': FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> create({
    required String title,
    required DateTime date,
    required String text,
    required String author,
  }) {
    final doc = _devotionals.doc();
    return doc.set({
      'title': title,
      'dateKey': dateKeyOf(date),
      'dateMillis': date.millisecondsSinceEpoch,
      'text': text,
      'author': author,
      'readBy': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> update({
    required String id,
    required String title,
    required DateTime date,
    required String text,
    required String author,
  }) {
    return _devotionals.doc(id).update({
      'title': title,
      'dateKey': dateKeyOf(date),
      'dateMillis': date.millisecondsSinceEpoch,
      'text': text,
      'author': author,
    });
  }

  Future<void> delete(String id) {
    return _devotionals.doc(id).delete();
  }
}

final devotionalRepositoryProvider = Provider<DevotionalRepository>((ref) {
  return DevotionalRepository(FirebaseFirestore.instance);
});

/// `StreamProvider` (24/08/2026, era `FutureProvider`) — ver
/// `DevotionalRepository.watchPublished`.
final devotionalsProvider = StreamProvider.autoDispose<List<Devotional>>((ref) {
  return ref.watch(devotionalRepositoryProvider).watchPublished();
});

/// Alimenta o badge do ícone "Devocionais" na barra inferior (24/08/2026,
/// pedido do usuário) — mesma contagem de não lidas usada em destaque na
/// lista (`DevotionalsListPage`), derivada de `devotionalsProvider` em vez de
/// uma query própria.
final unreadDevotionalsCountProvider = StreamProvider.autoDispose<int>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(0);
  final devotionals = ref.watch(devotionalsProvider).asData?.value ?? const <Devotional>[];
  return Stream.value(devotionals.where((d) => !d.readBy.contains(uid)).length);
});

final devotionalRepositoryListProvider = FutureProvider.autoDispose<List<Devotional>>((ref) {
  return ref.watch(devotionalRepositoryProvider).getAll();
});
