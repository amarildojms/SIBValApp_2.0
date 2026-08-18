import 'package:cloud_firestore/cloud_firestore.dart';

/// Espelha app/src/main/java/com/sibval/app/data/model/Member.kt.
class Member {
  final String id;
  final String name;
  final String email;
  final int birthDay;
  final int birthMonth;
  final String photoUrl;
  final String storagePath;
  final String createdBy;
  final DateTime? createdAt;

  const Member({
    required this.id,
    required this.name,
    required this.email,
    required this.birthDay,
    required this.birthMonth,
    required this.photoUrl,
    required this.storagePath,
    required this.createdBy,
    required this.createdAt,
  });

  factory Member.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Member(
      id: doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      birthDay: (data['birthDay'] as num?)?.toInt() ?? 0,
      birthMonth: (data['birthMonth'] as num?)?.toInt() ?? 0,
      photoUrl: data['photoUrl'] as String? ?? '',
      storagePath: data['storagePath'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
