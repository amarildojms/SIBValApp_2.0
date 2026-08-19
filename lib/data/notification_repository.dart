import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notification.dart';
import 'post_repository.dart' show currentUidProvider;
import 'user_repository.dart';

/// Espelha app/src/main/java/com/sibval/app/data/repository/NotificationRepository.kt.
class NotificationRepository {
  NotificationRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notifications => _firestore.collection('notifications');

  Future<List<AppNotification>> getRecent({
    required bool isAdmin,
    required String uid,
    bool canViewPrayerRequests = false,
    int limit = 50,
  }) async {
    final snapshot = await _notifications.orderBy('createdAt', descending: true).limit(limit).get();
    return snapshot.docs.map(AppNotification.fromFirestore).where((n) {
      return n.audience == NotificationAudience.all ||
          (n.audience == NotificationAudience.admin && isAdmin) ||
          (n.audience == NotificationAudience.intercessao && canViewPrayerRequests) ||
          (n.audience == NotificationAudience.user && n.targetUid == uid);
    }).toList();
  }

  Future<void> markAsRead(List<String> ids, String uid) async {
    if (ids.isEmpty) return;
    final batch = _firestore.batch();
    for (final id in ids) {
      batch.update(_notifications.doc(id), {
        'readBy': FieldValue.arrayUnion([uid]),
      });
    }
    await batch.commit();
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(FirebaseFirestore.instance);
});

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const [];
  final profile = await ref.watch(currentUserProfileProvider.future);
  return ref.watch(notificationRepositoryProvider).getRecent(
        isAdmin: profile?.isAdmin ?? false,
        uid: uid,
        canViewPrayerRequests: profile?.canViewPrayerRequests ?? false,
      );
});
