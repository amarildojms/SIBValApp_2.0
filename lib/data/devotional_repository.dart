import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/devotional.dart';

/// Espelha app/src/main/java/com/sibval/app/data/repository/DevotionalRepository.kt.
class DevotionalRepository {
  DevotionalRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _devotionals => _firestore.collection('devotionals');

  static String dateKeyOf(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  Future<List<Devotional>> getPublished({int limit = 60}) async {
    final todayKey = dateKeyOf(DateTime.now());
    final snapshot = await _devotionals
        .where('dateKey', isLessThanOrEqualTo: todayKey)
        .orderBy('dateKey', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map(Devotional.fromFirestore).toList();
  }

  Future<Devotional?> getById(String id) async {
    final doc = await _devotionals.doc(id).get();
    return doc.exists ? Devotional.fromFirestore(doc) : null;
  }

  Future<void> markRead(String id, String uid) {
    return _devotionals.doc(id).update({
      'readBy': FieldValue.arrayUnion([uid]),
    });
  }
}

final devotionalRepositoryProvider = Provider<DevotionalRepository>((ref) {
  return DevotionalRepository(FirebaseFirestore.instance);
});

final devotionalsProvider = FutureProvider.autoDispose<List<Devotional>>((ref) {
  return ref.watch(devotionalRepositoryProvider).getPublished();
});
