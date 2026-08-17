import 'package:cloud_firestore/cloud_firestore.dart';

/// Espelha app/src/main/java/com/sibval/app/data/model/Comment.kt —
/// subcoleção `posts/{postId}/comments`.
class Comment {
  final String id;
  final String postId;
  final String authorUid;
  final String authorName;
  final String text;
  final DateTime? createdAt;

  const Comment({
    required this.id,
    required this.postId,
    required this.authorUid,
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  factory Comment.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Comment(
      id: doc.id,
      postId: data['postId'] as String? ?? '',
      authorUid: data['authorUid'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
