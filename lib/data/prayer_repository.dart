import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/prayer_request.dart';

/// Espelha app/src/main/java/com/sibval/app/data/repository/PrayerRepository.kt.
/// Telefone do responsável (envio via WhatsApp) fica para depois.
class PrayerRepository {
  PrayerRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _requests => _firestore.collection('prayerRequests');

  Future<void> submit(PrayerRequest request) async {
    final doc = _requests.doc();
    await doc.set({
      'id': doc.id,
      'uid': '',
      'authorName': request.authorName,
      'authorPhone': request.authorPhone,
      'authorEmail': request.authorEmail,
      'isAnonymous': request.isAnonymous,
      'text': request.text,
      'isArchived': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<PrayerRequest>> getAll({int limit = 200}) async {
    final snapshot = await _requests
        .where('isArchived', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map(PrayerRequest.fromFirestore).toList();
  }

  Future<List<PrayerRequest>> getArchived({int limit = 200}) async {
    final snapshot = await _requests
        .where('isArchived', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map(PrayerRequest.fromFirestore).toList();
  }

  Future<void> archive(String id) {
    return _requests.doc(id).update({
      'isArchived': true,
      'archivedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String id) {
    return _requests.doc(id).delete();
  }
}

final prayerRepositoryProvider = Provider<PrayerRepository>((ref) {
  return PrayerRepository(FirebaseFirestore.instance);
});

final prayerRequestsProvider = FutureProvider.autoDispose<List<PrayerRequest>>((ref) {
  return ref.watch(prayerRepositoryProvider).getAll();
});

final archivedPrayerRequestsProvider = FutureProvider.autoDispose<List<PrayerRequest>>((ref) {
  return ref.watch(prayerRepositoryProvider).getArchived();
});

/// Badge no ícone "Pedido de Oração" do menu Mais — pedidos ainda não
/// encaminhados ao responsável (arquivar é efeito colateral de
/// `PrayerPage._sendToResponsible`, então o badge cai sozinho depois disso).
final pendingPrayerCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final requests = await ref.watch(prayerRequestsProvider.future);
  return requests.length;
});
