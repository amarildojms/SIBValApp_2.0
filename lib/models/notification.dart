import 'package:cloud_firestore/cloud_firestore.dart';

/// Espelha app/src/main/java/com/sibval/app/data/model/Notification.kt — mesma
/// coleção `notifications` no Firestore. Nomeado AppNotification pra não
/// colidir com a classe Notification do próprio Flutter.
class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final String targetId;
  final String audience;
  final String targetUid;
  final List<String> readBy;
  final List<String> dismissedBy;
  final Timestamp? createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.targetId,
    required this.audience,
    required this.targetUid,
    required this.readBy,
    required this.dismissedBy,
    required this.createdAt,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppNotification(
      id: doc.id,
      type: data['type'] as String? ?? '',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      targetId: data['targetId'] as String? ?? '',
      audience: data['audience'] as String? ?? NotificationAudience.all,
      targetUid: data['targetUid'] as String? ?? '',
      readBy: List<String>.from(data['readBy'] as List? ?? const []),
      dismissedBy: List<String>.from(data['dismissedBy'] as List? ?? const []),
      createdAt: data['createdAt'] as Timestamp?,
    );
  }
}

abstract final class NotificationType {
  static const birthday = 'birthday';
  static const devotional = 'devotional';
  static const userApproval = 'user_approval';
  static const eventPending = 'event_pending';
  static const eventReminder = 'event_reminder';
  static const postLike = 'post_like';
  static const postComment = 'post_comment';
  static const prayerRequest = 'prayer_request';
  static const message = 'message';
  static const membershipAnniversary = 'membership_anniversary';
  static const visitor = 'visitor';
}

/// [NotificationAudience.user] é individual — só aparece pra quem tem
/// `targetUid` igual ao uid logado (ex.: curtida/comentário na homenagem de
/// aniversário de alguém). [NotificationAudience.intercessao] (19/08/2026) é
/// admin ou quem tem o papel Intercessão — novo pedido de oração recebido.
abstract final class NotificationAudience {
  static const all = 'all';
  static const admin = 'admin';
  static const user = 'user';
  static const intercessao = 'intercessao';

  /// Admin ou papel Dirigentes — novo visitante cadastrado pela Recepção
  /// (24/08/2026, ver lib/models/visitor.dart).
  static const dirigentes = 'dirigentes';
}
