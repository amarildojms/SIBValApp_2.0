import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notice.dart';

/// Espelha o padrão de upload de `PostRepository` — sem equivalente no
/// nativo (03/09/2026, Quadro de Avisos).
class NoticeRepository {
  NoticeRepository(this._firestore, this._storage);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _notices =>
      _firestore.collection('notices');

  /// Tempo real — o painel da Início (`_NoticesCard`) e a tela de
  /// gerenciamento (`NoticeManagementPage`) refletem uma inclusão/edição/
  /// exclusão na hora, sem pull-to-refresh.
  Stream<List<Notice>> watchAll() {
    return _notices
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Notice.fromFirestore).toList());
  }

  Future<void> create({
    required String title,
    required String message,
    File? imageFile,
    required bool needsOffering,
    String offerPixKey = '',
    String offerDescription = '',
    String offerChurchName = '',
    String offerCity = '',
    bool requiresRegistration = false,
    String registrationLink = '',
    int? eventDateMillis,
    String? eventTime,
    required String createdByUid,
    required String createdByName,
  }) async {
    final doc = _notices.doc();
    var imageUrl = '';
    var storagePath = '';
    if (imageFile != null) {
      storagePath = 'notices/${doc.id}.jpg';
      final ref = _storage.ref(storagePath);
      await ref.putFile(imageFile);
      imageUrl = await ref.getDownloadURL();
    }
    await doc.set({
      'title': title,
      'message': message,
      'imageUrl': imageUrl,
      'storagePath': storagePath,
      'needsOffering': needsOffering,
      'offerPixKey': needsOffering ? offerPixKey : '',
      'offerDescription': needsOffering ? offerDescription : '',
      'offerChurchName': needsOffering ? offerChurchName : '',
      'offerCity': needsOffering ? offerCity : '',
      'requiresRegistration': requiresRegistration,
      'registrationLink': requiresRegistration ? registrationLink : '',
      'eventDateMillis': eventDateMillis,
      'eventTime': eventTime,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> update({
    required Notice notice,
    required String title,
    required String message,
    File? imageFile,
    required bool needsOffering,
    String offerPixKey = '',
    String offerDescription = '',
    String offerChurchName = '',
    String offerCity = '',
    bool requiresRegistration = false,
    String registrationLink = '',
    int? eventDateMillis,
    String? eventTime,
  }) async {
    var imageUrl = notice.imageUrl;
    var storagePath = notice.storagePath;
    if (imageFile != null) {
      if (storagePath.isNotEmpty) {
        try {
          await _storage.ref(storagePath).delete();
        } catch (_) {}
      }
      storagePath = 'notices/${notice.id}.jpg';
      final ref = _storage.ref(storagePath);
      await ref.putFile(imageFile);
      imageUrl = await ref.getDownloadURL();
    }
    await _notices.doc(notice.id).update({
      'title': title,
      'message': message,
      'imageUrl': imageUrl,
      'storagePath': storagePath,
      'needsOffering': needsOffering,
      'offerPixKey': needsOffering ? offerPixKey : '',
      'offerDescription': needsOffering ? offerDescription : '',
      'offerChurchName': needsOffering ? offerChurchName : '',
      'offerCity': needsOffering ? offerCity : '',
      'requiresRegistration': requiresRegistration,
      'registrationLink': requiresRegistration ? registrationLink : '',
      'eventDateMillis': eventDateMillis,
      'eventTime': eventTime,
    });
  }

  Future<void> delete(Notice notice) async {
    if (notice.storagePath.isNotEmpty) {
      try {
        await _storage.ref(notice.storagePath).delete();
      } catch (_) {}
    }
    await _notices.doc(notice.id).delete();
  }
}

final noticeRepositoryProvider = Provider<NoticeRepository>((ref) {
  return NoticeRepository(FirebaseFirestore.instance, FirebaseStorage.instance);
});

final noticesProvider = StreamProvider.autoDispose<List<Notice>>((ref) {
  return ref.watch(noticeRepositoryProvider).watchAll();
});
