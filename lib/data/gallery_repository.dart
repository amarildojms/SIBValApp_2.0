import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/album.dart';
import '../models/gallery_image.dart';

/// Espelha app/src/main/java/com/sibval/app/data/repository/GalleryRepository.kt.
/// Criar/apagar álbum e subir/apagar foto são ações de quem tem o cargo
/// Mídia (ou admin) — a foto já sai comprimida do image_picker
/// (maxWidth/maxHeight/imageQuality), equivalente ao ImageCompressor.kt nativo.
class GalleryRepository {
  GalleryRepository(this._firestore, this._storage);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _albums => _firestore.collection('albums');
  CollectionReference<Map<String, dynamic>> get _images => _firestore.collection('galleryImages');

  Future<List<Album>> getAlbums() async {
    final snapshot = await _albums.orderBy('createdAt', descending: true).get();
    return snapshot.docs.map(Album.fromFirestore).toList();
  }

  Future<List<GalleryImage>> getImages(String albumId, {int limit = 120}) async {
    final snapshot = await _images
        .where('albumId', isEqualTo: albumId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map(GalleryImage.fromFirestore).toList();
  }

  Future<Album> createAlbum(String name, String uid) async {
    final doc = _albums.doc();
    await doc.set({
      'name': name,
      'coverUrl': '',
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return Album(id: doc.id, name: name, coverUrl: '', createdBy: uid, createdAt: DateTime.now());
  }

  Future<void> deleteAlbum(String albumId) async {
    final snapshot = await _images.where('albumId', isEqualTo: albumId).get();
    for (final doc in snapshot.docs) {
      final image = GalleryImage.fromFirestore(doc);
      if (image.storagePath.isNotEmpty) {
        try {
          await _storage.ref(image.storagePath).delete();
        } catch (_) {}
      }
      await doc.reference.delete();
    }
    await _albums.doc(albumId).delete();
  }

  Future<GalleryImage> uploadImage({
    required File file,
    required String albumId,
    required String uploaderUid,
    required String uploaderName,
  }) async {
    final doc = _images.doc();
    final storagePath = 'gallery/${doc.id}.jpg';
    final ref = _storage.ref(storagePath);
    await ref.putFile(file);
    final downloadUrl = await ref.getDownloadURL();

    await doc.set({
      'albumId': albumId,
      'uploaderUid': uploaderUid,
      'uploaderName': uploaderName,
      'storagePath': storagePath,
      'downloadUrl': downloadUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });

    try {
      await _albums.doc(albumId).update({'coverUrl': downloadUrl});
    } catch (_) {}

    return GalleryImage(
      id: doc.id,
      albumId: albumId,
      uploaderUid: uploaderUid,
      uploaderName: uploaderName,
      storagePath: storagePath,
      downloadUrl: downloadUrl,
      createdAt: DateTime.now(),
    );
  }

  Future<void> deleteImage(GalleryImage image) async {
    if (image.storagePath.isNotEmpty) {
      try {
        await _storage.ref(image.storagePath).delete();
      } catch (_) {}
    }
    await _images.doc(image.id).delete();
  }
}

final galleryRepositoryProvider = Provider<GalleryRepository>((ref) {
  return GalleryRepository(FirebaseFirestore.instance, FirebaseStorage.instance);
});

final albumsProvider = FutureProvider.autoDispose<List<Album>>((ref) {
  return ref.watch(galleryRepositoryProvider).getAlbums();
});

final albumImagesProvider = FutureProvider.autoDispose.family<List<GalleryImage>, String>((ref, albumId) {
  return ref.watch(galleryRepositoryProvider).getImages(albumId);
});
