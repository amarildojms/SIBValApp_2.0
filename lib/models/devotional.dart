import 'package:cloud_firestore/cloud_firestore.dart';

/// Espelha app/src/main/java/com/sibval/app/data/model/Devotional.kt.
class Devotional {
  final String id;
  final String title;
  final String dateKey;
  final int dateMillis;
  final String text;
  final String author;
  final List<String> readBy;

  const Devotional({
    required this.id,
    required this.title,
    required this.dateKey,
    required this.dateMillis,
    required this.text,
    required this.author,
    required this.readBy,
  });

  factory Devotional.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Devotional(
      id: doc.id,
      title: data['title'] as String? ?? '',
      dateKey: data['dateKey'] as String? ?? '',
      dateMillis: (data['dateMillis'] as num?)?.toInt() ?? 0,
      text: data['text'] as String? ?? '',
      author: data['author'] as String? ?? '',
      readBy: List<String>.from(data['readBy'] as List? ?? const []),
    );
  }
}
