import 'package:cloud_firestore/cloud_firestore.dart';

/// Espelha app/src/main/java/com/sibval/app/data/model/PrayerRequest.kt.
class PrayerRequest {
  final String id;
  final String authorName;
  final String authorPhone;
  final String authorEmail;
  final bool isAnonymous;
  final String text;
  final DateTime? createdAt;

  const PrayerRequest({
    required this.id,
    required this.authorName,
    required this.authorPhone,
    required this.authorEmail,
    required this.isAnonymous,
    required this.text,
    required this.createdAt,
  });

  factory PrayerRequest.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return PrayerRequest(
      id: doc.id,
      authorName: data['authorName'] as String? ?? '',
      authorPhone: data['authorPhone'] as String? ?? '',
      authorEmail: data['authorEmail'] as String? ?? '',
      isAnonymous: data['isAnonymous'] as bool? ?? false,
      text: data['text'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
