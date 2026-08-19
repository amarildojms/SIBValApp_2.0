import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/comment.dart';
import '../models/event.dart' show EventStatus;
import '../models/post.dart';

/// Espelha app/src/main/java/com/sibval/app/data/repository/PostRepository.kt —
/// mesma coleção `posts` e subcoleção `posts/{postId}/comments`, mesmas regras
/// (like via arrayUnion/arrayRemove, comentário incrementa commentCount).
///
/// `getPosts` tem uma ordenação client-side sem equivalente nativo: posts de
/// evento sobem no feed conforme a data se aproxima (ver `_compareFeedOrder`),
/// ficando abaixo só dos posts de aniversário do dia, e voltam ao fluxo
/// cronológico normal assim que o evento passa.
class PostRepository {
  PostRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _posts => _firestore.collection('posts');
  CollectionReference<Map<String, dynamic>> _comments(String postId) =>
      _posts.doc(postId).collection('comments');

  Future<List<Post>> getPosts({int limit = 50}) async {
    final snapshot = await _posts.orderBy('createdAt', descending: true).limit(limit).get();
    final posts = snapshot.docs.map(Post.fromFirestore).toList();

    final eventIds = posts
        .where((post) => post.postType == PostType.event && post.targetId.isNotEmpty)
        .map((post) => post.targetId)
        .toSet()
        .toList();
    final eventDates = await _fetchEventDates(eventIds);

    final enriched = posts
        .map((post) => eventDates.containsKey(post.targetId)
            ? post.withEventDateTimeMillis(eventDates[post.targetId])
            : post)
        .toList();
    enriched.sort(_compareFeedOrder);
    return enriched;
  }

  /// Datas dos eventos referenciados pelos posts. Busca doc a doc (`get()`
  /// por id, em paralelo) em vez de uma query `whereIn` na coleção: a regra
  /// do Firestore (`allow read: if resource.data.status == 'published' ||
  /// isEventos()`) depende do conteúdo de cada documento, e o Firestore não
  /// consegue provar essa condição pra uma query de lista sobre `__name__`
  /// — mesmo filtrando `status` na própria query, ela vem inteira como
  /// PERMISSION_DENIED pra quem não gerencia eventos. Um `get()` por
  /// documento não tem essa limitação (é como `EventRepository.getById`
  /// já busca eventos hoje).
  Future<Map<String, int>> _fetchEventDates(List<String> eventIds) async {
    if (eventIds.isEmpty) return const {};
    final result = <String, int>{};
    await Future.wait(eventIds.map((id) async {
      try {
        final doc = await _firestore.collection('events').doc(id).get();
        final data = doc.data();
        if (data == null || data['status'] != EventStatus.published) return;
        final millis = (data['dateTimeMillis'] as num?)?.toInt();
        if (millis != null) result[id] = millis;
      } catch (_) {
        // Evento não publicado (ex.: pendente/cancelado) e o usuário não
        // gerencia eventos — a regra nega esse doc; o post cai pro fluxo
        // normal (sem badge de data), o resto do feed não é afetado.
      }
    }));
    return result;
  }

  /// Aniversariantes do dia primeiro, depois eventos que ainda vão ocorrer
  /// (do mais próximo pro mais distante) e por último o restante do feed em
  /// ordem cronológica normal — inclui eventos já ocorridos, que voltam a se
  /// comportar como um post comum.
  int _compareFeedOrder(Post a, Post b) {
    final rankA = _feedRank(a);
    final rankB = _feedRank(b);
    if (rankA != rankB) return rankA.compareTo(rankB);
    if (rankA == 1) return a.eventDateTimeMillis!.compareTo(b.eventDateTimeMillis!);
    final createdAtA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final createdAtB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return createdAtB.compareTo(createdAtA);
  }

  int _feedRank(Post post) {
    if (post.postType == PostType.birthday) return 0;
    if (post.postType == PostType.event && post.eventDateTimeMillis != null && !post.isPastEvent) return 1;
    return 2;
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

/// Reativo — dispara sozinho quando o usuário loga/desloga (o app não recria
/// mais a árvore de widgets no login, ver AuthGate removido de main.dart).
final authStateChangesProvider = StreamProvider<User?>((ref) => FirebaseAuth.instance.authStateChanges());

final currentUidProvider = Provider<String?>((ref) => ref.watch(authStateChangesProvider).asData?.value?.uid);
