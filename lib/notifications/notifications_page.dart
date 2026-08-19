import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../admin/manage_users_page.dart';
import '../birthdays/birthdays_page.dart';
import '../data/notification_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../devotionals/devotional_detail_page.dart';
import '../events/event_detail_page.dart';
import '../events/event_pending_list_page.dart';
import '../home/post_comments_page.dart';
import '../models/notification.dart';
import '../prayer/prayer_page.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

/// Espelha NotificationsFragment.kt/NotificationsViewModel.kt: lista de
/// notificações (lidas em cinza, não lidas em destaque), tocar marca como
/// lida e navega pro destino correspondente ao tipo.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final uid = ref.watch(currentUidProvider);

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenTitle('Notificações'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(notificationsProvider.future),
              child: notificationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 80),
              Center(child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary))),
            ],
          ),
          data: (notifications) {
            if (notifications.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Text('Nenhuma notificação por enquanto.', style: TextStyle(color: context.textSecondary)),
                  ),
                ],
              );
            }
            return ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                final isUnread = uid != null && !notification.readBy.contains(uid);
                final color = isUnread ? context.textPrimary : context.textTertiary;
                final timestamp =
                    notification.createdAt != null ? _dateFormat.format(notification.createdAt!.toDate()) : '';
                return ListTile(
                  title: Text(
                    notification.title,
                    style: TextStyle(color: color, fontWeight: isUnread ? FontWeight.bold : FontWeight.normal),
                  ),
                  subtitle: Text('${notification.body}\n$timestamp', style: TextStyle(color: color)),
                  isThreeLine: true,
                  onTap: () => _onTap(context, ref, notification, uid),
                );
              },
            );
              },
            ),
          ),
        ),
      ],
      ),
      ),
    );
  }

  Future<void> _onTap(BuildContext context, WidgetRef ref, AppNotification notification, String? uid) async {
    if (uid != null && !notification.readBy.contains(uid)) {
      await ref.read(notificationRepositoryProvider).markAsRead([notification.id], uid);
      ref.invalidate(notificationsProvider);
    }
    if (!context.mounted) return;
    switch (notification.type) {
      case NotificationType.devotional:
        if (notification.targetId.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => DevotionalDetailPage(devotionalId: notification.targetId)),
          );
        }
      case NotificationType.birthday:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BirthdaysPage()));
      case NotificationType.userApproval:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ManageUsersPage()));
      case NotificationType.eventPending:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EventPendingListPage()));
      case NotificationType.eventReminder:
        if (notification.targetId.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => EventDetailPage(eventId: notification.targetId)),
          );
        }
      case NotificationType.postLike:
      case NotificationType.postComment:
        if (notification.targetId.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PostCommentsPage(postId: notification.targetId)),
          );
        }
      case NotificationType.prayerRequest:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrayerPage()));
    }
  }
}
