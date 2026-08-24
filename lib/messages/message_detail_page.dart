import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/message_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../models/notification.dart';
import '../notifications/notification_read_sync.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

/// Aberta ao tocar numa mensagem na lista (`MessagesPage`) ou numa notificação
/// push do tipo `message` (`notification_navigation.dart`, que só tem o
/// `messageId`) — busca por id (`messageByIdProvider`) e marca como lida ao
/// abrir, mesmo padrão de `NotificationsPage._onTap`.
class MessageDetailPage extends ConsumerStatefulWidget {
  const MessageDetailPage({super.key, required this.messageId});

  final String messageId;

  @override
  ConsumerState<MessageDetailPage> createState() => _MessageDetailPageState();
}

class _MessageDetailPageState extends ConsumerState<MessageDetailPage> {
  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
  bool _markedRead = false;

  @override
  void initState() {
    super.initState();
    syncNotificationsForScreen(ref, type: NotificationType.message, targetId: widget.messageId);
  }

  Future<void> _markAsReadOnceLoaded() async {
    if (_markedRead) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final message = await ref.read(messageByIdProvider(widget.messageId).future);
    if (message == null || message.readBy.contains(uid)) return;
    _markedRead = true;
    await ref.read(messageRepositoryProvider).markAsRead(message.id, uid);
    ref.invalidate(inboxMessagesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final messageAsync = ref.watch(messageByIdProvider(widget.messageId));
    messageAsync.whenData((_) => _markAsReadOnceLoaded());

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: messageAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary)),
          ),
          data: (message) {
            if (message == null) {
              return Center(
                child: Text('Mensagem não encontrada.', style: TextStyle(color: context.textSecondary)),
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.isMeeting)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: SibValColors.goldAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_outlined, color: SibValColors.goldAccent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              message.meetingAt != null
                                  ? 'Reunião agendada para ${_dateFormat.format(message.meetingAt!)}'
                                  : 'Reunião',
                              style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    message.title,
                    style: TextStyle(color: context.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'De ${message.senderName}'
                    '${message.createdAt != null ? ' • ${_dateFormat.format(message.createdAt!)}' : ''}',
                    style: TextStyle(color: context.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Text(message.body, style: TextStyle(color: context.textPrimary, fontSize: 15)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
