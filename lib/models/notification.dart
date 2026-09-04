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

  /// 5 minutos antes do início do culto (28/08/2026, pedido do usuário) —
  /// audiência `all`, texto usa `serviceOrderDisplayName` no lugar de
  /// "Culto" quando a ordem tem `theme` preenchido.
  static const serviceOrderReminder = 'service_order_reminder';

  /// Disparada quando o dirigente de fato toca em "Iniciar Culto"
  /// (`ServiceOrderRepository.markStarted`) — é o que libera
  /// `ServiceOrderMemberViewPage` de ficar travada no timer.
  static const serviceOrderStarted = 'service_order_started';

  /// Disparada quando o dirigente toca em "Finalizar Culto"
  /// (`ServiceOrderRepository.finalize`) — audiência `all`, com uma
  /// mensagem de bênção no corpo (28/08/2026, pedido do usuário: "exibir
  /// uma popup para todos os usuários"). Tratada de forma especial em
  /// `PushNotificationService._onForegroundMessage` — quem está com o app
  /// aberto vê um diálogo de verdade em vez do banner do sistema (ver
  /// `navigatorKey`).
  static const serviceOrderFinalized = 'service_order_finalized';

  /// Novo compromisso da Agenda aguardando decisão — audiência `user`, um por
  /// aprovador (03/09/2026, pedido do usuário: fila de aprovação antes de
  /// efetivar no calendário).
  static const agendaEntryPending = 'agenda_entry_pending';

  /// Compromisso aprovado — pro criador, `audience: user`.
  static const agendaEntryApproved = 'agenda_entry_approved';

  /// Compromisso rejeitado — pro criador, `audience: user`, corpo inclui a
  /// justificativa informada pelo aprovador.
  static const agendaEntryRejected = 'agenda_entry_rejected';

  /// Compromisso aprovado, depois cancelado pelo aprovador (03/09/2026, 2ª
  /// rodada, pedido do usuário: "Somente o aprovador pode cancelar/
  /// remanejar... Quem solicitou o agendamento deve ser notificado") — pro
  /// criador.
  static const agendaEntryCancelled = 'agenda_entry_cancelled';

  /// Aprovador remanejou direto (escolheu a nova data/horário) — pro
  /// criador.
  static const agendaEntryRescheduled = 'agenda_entry_rescheduled';

  /// Aprovador pediu pro criador escolher outra data (corpo inclui a
  /// mensagem) — pro criador.
  static const agendaEntryRescheduleRequested = 'agenda_entry_reschedule_requested';

  /// Nova série recorrente da Agenda aguardando aprovação — pro aprovador.
  static const recurringAgendaEntryPending = 'recurring_agenda_entry_pending';

  /// Série recorrente aprovada — pro criador.
  static const recurringAgendaEntryApproved = 'recurring_agenda_entry_approved';

  /// Série recorrente rejeitada (corpo inclui a justificativa) — pro
  /// criador.
  static const recurringAgendaEntryRejected = 'recurring_agenda_entry_rejected';
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

  /// Admin ou papel Dirigentes — novo visitante cadastrado pela Introdução
  /// (24/08/2026, ver lib/models/visitor.dart).
  static const dirigentes = 'dirigentes';
}
