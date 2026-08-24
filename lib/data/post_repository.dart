import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/comment.dart';
import '../models/post.dart';

/// Espelha app/src/main/java/com/sibval/app/data/repository/PostRepository.kt —
/// mesma coleção `posts` e subcoleção `posts/{postId}/comments`, mesmas regras
/// (like via arrayUnion/arrayRemove, comentário incrementa commentCount).
///
/// Sem ordenação especial no cliente: o feed é sempre por `createdAt`
/// descendente, direto do Firestore — quem decide quando um post automático
/// sobe é a Cloud Function que o cria/reposta (evento repostado 24h/6h antes,
/// aniversariante às 01h, devocional no seu dia), não uma regra local aqui.
/// `postsProvider` usa `.snapshots()` (tempo real), não busca única.
class PostRepository {
  PostRepository(this._firestore, this._storage);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _posts => _firestore.collection('posts');
  CollectionReference<Map<String, dynamic>> _comments(String postId) =>
      _posts.doc(postId).collection('comments');

  Stream<List<Post>> watchPosts({int limit = 50}) {
    return _posts
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Post.fromFirestore).toList());
  }

  /// Publicação manual no feed "Início" — restrita a quem tem
  /// `canManagePublications` (papel Publicações ou admin, ver
  /// `firestore.rules` nativo `posts.create`). Espelha o resto do feed
  /// (curtida/comentário), sem equivalente direto no app nativo.
  Future<void> createManualPost({
    required String authorUid,
    required String authorName,
    required String text,
    File? imageFile,
  }) async {
    final doc = _posts.doc();
    var imageUrl = '';
    var storagePath = '';
    if (imageFile != null) {
      storagePath = 'posts/${doc.id}.jpg';
      final ref = _storage.ref(storagePath);
      await ref.putFile(imageFile);
      imageUrl = await ref.getDownloadURL();
    }
    await doc.set({
      'authorUid': authorUid,
      'authorName': authorName,
      'text': text,
      'imageUrl': imageUrl,
      'storagePath': storagePath,
      'createdAt': FieldValue.serverTimestamp(),
      'likedBy': <String>[],
      'commentCount': 0,
      'postType': PostType.manual,
      'targetId': '',
    });
  }

  /// Edição de post manual — só o autor ou admin chega aqui (gate na UI e no
  /// `firestore.rules`). Troca a imagem só se [imageFile] vier preenchido;
  /// senão mantém a existente (`existingStoragePath`).
  Future<void> updateManualPost({
    required String postId,
    required String text,
    File? imageFile,
    String existingStoragePath = '',
  }) async {
    final fields = <String, Object?>{'text': text};
    if (imageFile != null) {
      if (existingStoragePath.isNotEmpty) {
        try {
          await _storage.ref(existingStoragePath).delete();
        } catch (_) {}
      }
      final storagePath = 'posts/$postId.jpg';
      final ref = _storage.ref(storagePath);
      await ref.putFile(imageFile);
      fields['imageUrl'] = await ref.getDownloadURL();
      fields['storagePath'] = storagePath;
    }
    await _posts.doc(postId).update(fields);
  }

  Future<void> deleteManualPost(Post post) async {
    if (post.storagePath.isNotEmpty) {
      try {
        await _storage.ref(post.storagePath).delete();
      } catch (_) {}
    }
    await _posts.doc(post.id).delete();
  }

  Future<void> toggleLike(String postId, String uid, bool liked) {
    return _posts.doc(postId).update({
      'likedBy': liked ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
    });
  }

  Future<List<Comment>> getComments(String postId) async {
    final snapshot = await _comments(postId).orderBy('createdAt', descending: false).get();
    return snapshot.docs.map(Comment.fromFirestore).toList();
  }

  Future<void> addComment(String postId, String uid, String authorName, String text) async {
    final doc = _comments(postId).doc();
    await doc.set({
      'id': doc.id,
      'postId': postId,
      'authorUid': uid,
      'authorName': authorName,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _posts.doc(postId).update({'commentCount': FieldValue.increment(1)});
  }
}

final postRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepository(FirebaseFirestore.instance, FirebaseStorage.instance);
});

final postsProvider = StreamProvider.autoDispose<List<Post>>((ref) {
  return ref.watch(postRepositoryProvider).watchPosts();
});

/// Reativo — dispara sozinho quando o usuário loga/desloga (o app não recria
/// mais a árvore de widgets no login, ver AuthGate removido de main.dart).
final authStateChangesProvider = StreamProvider<User?>((ref) => FirebaseAuth.instance.authStateChanges());

final currentUidProvider = Provider<String?>((ref) => ref.watch(authStateChangesProvider).asData?.value?.uid);
