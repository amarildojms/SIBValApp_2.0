import 'package:cloud_firestore/cloud_firestore.dart';

/// Espelha app/src/main/java/com/sibval/app/data/model/Post.kt — mesma coleção
/// `posts` no Firestore, criada tanto pelo app quanto pelas Cloud Functions
/// (posts automáticos de devocional, evento e aniversário).
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
}

abstract final class PostType {
  static const manual = 'manual';
  static const devotional = 'devotional';
  static const event = 'event';
  static const birthday = 'birthday';
}
