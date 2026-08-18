import 'package:cloud_firestore/cloud_firestore.dart';

/// Espelha app/src/main/java/com/sibval/app/data/model/Album.kt — mesma
/// coleção `albums` no Firestore.
class Album {
  final String id;
  final String name;
  final String coverUrl;
  final String createdBy;
  final DateTime? createdAt;

  const Album({
    required this.id,
    required this.name,
    required this.coverUrl,
    required this.createdBy,
    required this.createdAt,
  });

  factory Album.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Album(
      id: doc.id,
      name: data['name'] as String? ?? '',
      coverUrl: data['coverUrl'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
