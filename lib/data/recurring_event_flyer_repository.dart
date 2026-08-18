import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recurring_event_flyer.dart';

/// Espelha app/src/main/java/com/sibval/app/data/repository/RecurringEventFlyerRepository.kt.
/// Acesso restrito ao admin — a foto já sai comprimida do image_picker
/// (maxWidth/maxHeight/imageQuality), equivalente ao ImageCompressor.kt nativo.
class RecurringEventFlyerRepository {
  RecurringEventFlyerRepository(this._firestore, this._storage);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _flyers => _firestore.collection('recurringEventFlyers');

  Future<List<RecurringEventFlyer>> getAll() async {
    final snapshot = await _flyers.orderBy('category').orderBy('dateKey').get();
    return snapshot.docs.map(RecurringEventFlyer.fromFirestore).toList();
  }

  Future<void> create({required String category, required String dateKey, required File file}) async {
    final doc = _flyers.doc();
    final storagePath = 'recurringEventFlyers/${doc.id}.jpg';
    final ref = _storage.ref(storagePath);
    await ref.putFile(file);
    final flyerUrl = await ref.getDownloadURL();

    await doc.set({
      'category': category,
      'dateKey': dateKey,
      'flyerUrl': flyerUrl,
      'flyerStoragePath': storagePath,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(RecurringEventFlyer flyer) async {
    if (flyer.flyerStoragePath.isNotEmpty) {
      try {
        await _storage.ref(flyer.flyerStoragePath).delete();
      } catch (_) {}
    }
    await _flyers.doc(flyer.id).delete();
  }
}

final recurringEventFlyerRepositoryProvider = Provider<RecurringEventFlyerRepository>((ref) {
  return RecurringEventFlyerRepository(FirebaseFirestore.instance, FirebaseStorage.instance);
});

final recurringEventFlyersProvider = FutureProvider.autoDispose<List<RecurringEventFlyer>>((ref) {
  return ref.watch(recurringEventFlyerRepositoryProvider).getAll();
});
