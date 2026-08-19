import 'package:cloud_firestore/cloud_firestore.dart';

import 'event.dart' show toSaoPauloTime, toSaoPauloTimeNow;

/// Espelha app/src/main/java/com/sibval/app/data/model/Post.kt — mesma coleção
/// `posts` no Firestore, criada tanto pelo app quanto pelas Cloud Functions
/// (posts automáticos de devocional, evento e aniversário).
///
/// `eventDateTimeMillis` não existe no documento — é preenchido por
/// `PostRepository.getPosts` a partir do evento referenciado por `targetId`,
/// pra permitir ordenar o feed pela proximidade da data do evento e saber
/// quando ele já ocorreu (sem precisar duplicar a data no post no Firestore).
class Post {
  final String id;
  final String authorUid;
  final String authorName;
  final String text;
  final String imageUrl;
  final DateTime? createdAt;
  final List<String> likedBy;
  final int commentCount;
  final String postType;
  final String targetId;
  final int? eventDateTimeMillis;

  const Post({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.text,
    required this.imageUrl,
    required this.createdAt,
    required this.likedBy,
    required this.commentCount,
    required this.postType,
    required this.targetId,
    this.eventDateTimeMillis,
  });

  factory Post.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Post(
      id: doc.id,
      authorUid: data['authorUid'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      text: data['text'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      likedBy: List<String>.from(data['likedBy'] as List? ?? const []),
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      postType: data['postType'] as String? ?? PostType.manual,
      targetId: data['targetId'] as String? ?? '',
    );
  }

  Post withEventDateTimeMillis(int? millis) => Post(
        id: id,
        authorUid: authorUid,
        authorName: authorName,
        text: text,
        imageUrl: imageUrl,
        createdAt: createdAt,
        likedBy: likedBy,
        commentCount: commentCount,
        postType: postType,
        targetId: targetId,
        eventDateTimeMillis: millis,
      );

  DateTime? get eventDateSaoPaulo => eventDateTimeMillis != null
      ? toSaoPauloTime(DateTime.fromMillisecondsSinceEpoch(eventDateTimeMillis!, isUtc: true))
      : null;

  /// Verdadeiro a partir do dia seguinte ao do evento (o dia do evento em si
  /// ainda conta como "não ocorrido" pra manter o post fixado/tocável).
  bool get isPastEvent {
    final eventDate = eventDateSaoPaulo;
    if (eventDate == null) return false;
    final today = toSaoPauloTimeNow();
    final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    return eventDay.isBefore(todayDay);
  }
}

abstract final class PostType {
  static const manual = 'manual';
  static const devotional = 'devotional';
  static const event = 'event';
  static const birthday = 'birthday';
}
