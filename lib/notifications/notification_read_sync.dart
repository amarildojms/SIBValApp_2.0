import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notification_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../data/user_repository.dart';
import 'push_notification_service.dart';

/// Ao abrir uma tela ligada a um tipo de notificação (ver
/// `navigateForNotificationType` em `notification_navigation.dart` pro mesmo
/// mapeamento tipo -> tela), marca como lida — e cancela da barra do celular
/// — toda notificação desse tipo ainda não lida pelo usuário logado (e, se
/// [targetId] vier preenchido, só as que apontam pro mesmo alvo). Chamado
/// uma vez no `initState` de cada tela ligada a notificação, mesmo sem o
/// usuário ter tocado na notificação pra chegar lá — ex.: abrir
/// "Aniversariantes" direto pelo menu já marca como lida a notificação de
/// aniversário do dia, mesmo padrão do toque direto (24/08/2026).
Future<void> syncNotificationsForScreen(WidgetRef ref, {required String type, String targetId = ''}) async {
  final uid = ref.read(currentUidProvider);
  if (uid == null) return;

  final profile = ref.read(currentUserProfileProvider).asData?.value;
  final notifications = await ref.read(notificationRepositoryProvider).getRecent(
        isAdmin: profile?.isAdmin ?? false,
        uid: uid,
        canViewPrayerRequests: profile?.canViewPrayerRequests ?? false,
      );

  final unread = notifications.where(
    (n) => n.type == type && !n.readBy.contains(uid) && (targetId.isEmpty || n.targetId == targetId),
  );
  final ids = unread.map((n) => n.id).toList();
  if (ids.isEmpty) return;

  await ref.read(notificationRepositoryProvider).markAsRead(ids, uid);
  final pushService = ref.read(pushNotificationServiceProvider);
  for (final id in ids) {
    await pushService.cancelNotification(id);
  }
}
