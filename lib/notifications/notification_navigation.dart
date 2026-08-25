import 'package:flutter/material.dart';

import '../admin/manage_users_page.dart';
import '../birthdays/birthdays_page.dart';
import '../devotionals/devotional_detail_page.dart';
import '../events/event_detail_page.dart';
import '../events/event_pending_list_page.dart';
import '../home/post_comments_page.dart';
import '../introduction/introduction_page.dart';
import '../messages/message_detail_page.dart';
import '../models/notification.dart';
import '../prayer/prayer_page.dart';

/// Roteamento por `type`/`targetId` compartilhado entre o toque num item da
/// Central de notificações (`NotificationsPage._onTap`) e o toque numa
/// notificação push (`PushNotificationService`) — espelha
/// MainActivity.handleNotificationIntent (tipos) + NotificationsFragment.kt
/// (mesmo destino ao tocar na lista in-app).
void navigateForNotificationType(BuildContext context, {required String type, required String targetId}) {
  switch (type) {
    case NotificationType.devotional:
      if (targetId.isNotEmpty) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => DevotionalDetailPage(devotionalId: targetId)));
      }
    case NotificationType.birthday:
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BirthdaysPage()));
    case NotificationType.userApproval:
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ManageUsersPage()));
    case NotificationType.eventPending:
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EventPendingListPage()));
    case NotificationType.eventReminder:
      if (targetId.isNotEmpty) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventDetailPage(eventId: targetId)));
      }
    case NotificationType.postLike:
    case NotificationType.postComment:
    case NotificationType.membershipAnniversary:
      if (targetId.isNotEmpty) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => PostCommentsPage(postId: targetId)));
      }
    case NotificationType.prayerRequest:
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrayerPage()));
    case NotificationType.message:
      if (targetId.isNotEmpty) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => MessageDetailPage(messageId: targetId)));
      }
    case NotificationType.visitor:
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const IntroductionPage()));
  }
}
