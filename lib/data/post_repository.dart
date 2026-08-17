import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/comment.dart';
import '../models/post.dart';

/// Espelha app/src/main/java/com/sibval/app/data/repository/PostRepository.kt —
/// mesma coleção `posts` e subcoleção `posts/{postId}/comments`, mesmas regras
/// (like via arrayUnion/arrayRemove, comentário incrementa commentCount).
class PostRepository {
  PostRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _posts => _firestore.collection('posts');
  CollectionReference<Map<String, dynamic>> _comments(String postId) =>
      _posts.doc(postId).collection('comments');

  Future<List<Post>> getPosts({int limit = 50}) async {
    final snapshot = await _posts.orderBy('createdAt', descending: true).limit(limit).get();
    return snapshot.docs.map(Post.fromFirestore).toList();
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
  return PostRepository(FirebaseFirestore.instance);
});

final postsProvider = FutureProvider.autoDispose<List<Post>>((ref) {
  return ref.watch(postRepositoryProvider).getPosts();
});

final currentUidProvider = Provider<String?>((ref) => FirebaseAuth.instance.currentUser?.uid);
