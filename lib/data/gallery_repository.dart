import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/album.dart';
import '../models/gallery_image.dart';

/// Espelha app/src/main/java/com/sibval/app/data/repository/GalleryRepository.kt.
/// Só leitura nesta fase — criar álbum, subir e apagar fotos são ações de
/// quem tem o cargo Mídia (ou admin), mesmo tratamento dado à criação manual
/// de post: fica para a fase do Painel Admin.
class GalleryRepository {
  GalleryRepository(this._firestore);

  final FirebaseFirestore _firestore;

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
}

final galleryRepositoryProvider = Provider<GalleryRepository>((ref) {
  return GalleryRepository(FirebaseFirestore.instance);
});

final albumsProvider = FutureProvider.autoDispose<List<Album>>((ref) {
  return ref.watch(galleryRepositoryProvider).getAlbums();
});

final albumImagesProvider = FutureProvider.autoDispose.family<List<GalleryImage>, String>((ref, albumId) {
  return ref.watch(galleryRepositoryProvider).getImages(albumId);
});
