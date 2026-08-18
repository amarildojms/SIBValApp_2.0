import 'package:cloud_firestore/cloud_firestore.dart';

/// Espelha app/src/main/java/com/sibval/app/data/model/GalleryImage.kt —
/// mesma coleção `galleryImages` no Firestore.
class GalleryImage {
  final String id;
  final String albumId;
  final String uploaderUid;
  final String uploaderName;
  final String storagePath;
  final String downloadUrl;
  final DateTime? createdAt;

  const GalleryImage({
    required this.id,
    required this.albumId,
    required this.uploaderUid,
    required this.uploaderName,
    required this.storagePath,
    required this.downloadUrl,
    required this.createdAt,
  });

  factory GalleryImage.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return GalleryImage(
      id: doc.id,
      albumId: data['albumId'] as String? ?? '',
      uploaderUid: data['uploaderUid'] as String? ?? '',
      uploaderName: data['uploaderName'] as String? ?? '',
      storagePath: data['storagePath'] as String? ?? '',
      downloadUrl: data['downloadUrl'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
