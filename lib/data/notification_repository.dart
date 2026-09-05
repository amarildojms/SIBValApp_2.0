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
    bool canViewVisitorSummaries = false,
    bool canViewVisitorDetails = false,
    bool canManageBasketDonations = false,
    bool canConfirmBasketPix = false,
    int limit = 50,
  }) async {
    final snapshot = await _notifications.orderBy('createdAt', descending: true).limit(limit).get();
    return snapshot.docs.map(AppNotification.fromFirestore).where((n) {
      if (n.dismissedBy.contains(uid)) return false;
      return n.audience == NotificationAudience.all ||
          (n.audience == NotificationAudience.admin && isAdmin) ||
          (n.audience == NotificationAudience.intercessao && canViewPrayerRequests) ||
          (n.audience == NotificationAudience.dirigentes && (canViewVisitorSummaries || canViewVisitorDetails)) ||
          // Alimento: só Diaconia. Pix: Diaconia OU Tesouraria (04/09/2026,
          // pedido explícito do usuário — antes as duas caíam na mesma
          // audiência e um Tesouraria-only via também a de alimento).
          (n.audience == NotificationAudience.basketReviewFood && canManageBasketDonations) ||
          (n.audience == NotificationAudience.basketReviewPix &&
              (canManageBasketDonations || canConfirmBasketPix)) ||
          (n.audience == NotificationAudience.user && n.targetUid == uid);
    }).toList();
  }

  /// Tempo real (21/08/2026) — ver `notificationsProvider`. O sino e o badge
  /// de não lidas devem atualizar assim que uma notificação nova chega, sem
  /// esperar a tela ser reaberta.
  Stream<List<AppNotification>> watchRecent({
    required bool isAdmin,
    required String uid,
    bool canViewPrayerRequests = false,
    bool canViewVisitorSummaries = false,
    bool canViewVisitorDetails = false,
    bool canManageBasketDonations = false,
    bool canConfirmBasketPix = false,
    int limit = 50,
  }) {
    return _notifications.orderBy('createdAt', descending: true).limit(limit).snapshots().map((snapshot) {
      return snapshot.docs.map(AppNotification.fromFirestore).where((n) {
        if (n.dismissedBy.contains(uid)) return false;
        return n.audience == NotificationAudience.all ||
            (n.audience == NotificationAudience.admin && isAdmin) ||
            (n.audience == NotificationAudience.intercessao && canViewPrayerRequests) ||
            (n.audience == NotificationAudience.dirigentes && (canViewVisitorSummaries || canViewVisitorDetails)) ||
            (n.audience == NotificationAudience.basketReviewFood && canManageBasketDonations) ||
            (n.audience == NotificationAudience.basketReviewPix &&
                (canManageBasketDonations || canConfirmBasketPix)) ||
            (n.audience == NotificationAudience.user && n.targetUid == uid);
      }).toList();
    });
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

  /// "Descartar" — a coleção `notifications` é compartilhada (uma mesma
  /// notificação de audiência `all`/`admin`/etc. aparece pra vários usuários),
  /// então excluir o documento apagaria a notificação pra todo mundo. Em vez
  /// disso, cada usuário guarda seu próprio dispensar em `dismissedBy`, igual
  /// ao padrão já usado em `readBy`, e a notificação some só da lista dele.
  Future<void> dismiss(String id, String uid) {
    return _notifications.doc(id).update({
      'dismissedBy': FieldValue.arrayUnion([uid]),
    });
  }

  /// "Limpar tudo" — dispensa de uma vez todas as notificações atualmente
  /// visíveis pro usuário (mesmo `dismissedBy`, um batch em vez de uma a uma).
  Future<void> dismissAll(List<String> ids, String uid) async {
    if (ids.isEmpty) return;
    final batch = _firestore.batch();
    for (final id in ids) {
      batch.update(_notifications.doc(id), {
        'dismissedBy': FieldValue.arrayUnion([uid]),
      });
    }
    await batch.commit();
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(FirebaseFirestore.instance);
});

final notificationsProvider = StreamProvider.autoDispose<List<AppNotification>>((ref) async* {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) {
    yield const [];
    return;
  }
  final profile = await ref.watch(currentUserProfileProvider.future);
  yield* ref
      .watch(notificationRepositoryProvider)
      .watchRecent(
        isAdmin: profile?.isAdmin ?? false,
        uid: uid,
        canViewPrayerRequests: profile?.canViewPrayerRequests ?? false,
        canViewVisitorSummaries: profile?.canViewVisitorSummaries ?? false,
        canViewVisitorDetails: profile?.canViewVisitorDetails ?? false,
        canManageBasketDonations: profile?.canManageBasketDonations ?? false,
        canConfirmBasketPix: profile?.canConfirmBasketPix ?? false,
      );
});
