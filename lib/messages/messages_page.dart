import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/message_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../models/app_message.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'message_detail_page.dart';
import 'message_form_page.dart';

/// Central de Mensagens (21/08/2026, sem equivalente no app nativo) — lista
/// de mensagens recebidas (diretas, por ministério ou para todos), com seção
/// de próximas reuniões agendadas no topo. Só admin vê o FAB de envio (gate
/// espelhando `firestore.rules` nativo `messages.create`).
class MessagesPage extends ConsumerWidget {
  const MessagesPage({super.key});

  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(inboxMessagesProvider);
    final meetingsAsync = ref.watch(upcomingMeetingsProvider);
    final uid = ref.watch(currentUidProvider);
    final canSend = ref.watch(canSendMessagesProvider);

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      floatingActionButton: canSend
          ? FloatingActionButton(
              heroTag: 'messages_fab',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MessageFormPage())),
              child: const Icon(Icons.add),
            )
          : null,
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Mensagens'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(inboxMessagesProvider);
                  await ref.read(inboxMessagesProvider.future);
                },
                child: messagesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => ListView(
                    children: [
                      const SizedBox(height: 80),
                      Center(
                        child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary)),
                      ),
                    ],
                  ),
                  data: (messages) {
                    if (messages.isEmpty) {
                      return ListView(
                        children: [
                          const SizedBox(height: 80),
                          Center(
                            child: Text(
                              'Nenhuma mensagem por enquanto.',
                              style: TextStyle(color: context.textSecondary),
                            ),
                          ),
                        ],
                      );
                    }
                    final meetings = meetingsAsync.asData?.value ?? const <AppMessage>[];
                    return ListView(
                      children: [
                        if (meetings.isNotEmpty) _UpcomingMeetingsSection(meetings: meetings),
                        for (final message in messages) _MessageTile(message: message, uid: uid),
                      ],
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
}

class _UpcomingMeetingsSection extends StatelessWidget {
  const _UpcomingMeetingsSection({required this.meetings});

  final List<AppMessage> meetings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Próximas reuniões',
            style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          for (final meeting in meetings)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.event_outlined, color: SibValColors.goldAccent),
                title: Text(meeting.title),
                subtitle: Text(MessagesPage._dateFormat.format(meeting.meetingAt!)),
                onTap: () =>
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => MessageDetailPage(messageId: meeting.id))),
              ),
            ),
          const Divider(),
        ],
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message, required this.uid});

  final AppMessage message;
  final String? uid;

  @override
  Widget build(BuildContext context) {
    final isUnread = uid != null && !message.readBy.contains(uid);
    final color = isUnread ? context.textPrimary : context.textTertiary;
    final timestamp = message.createdAt != null ? MessagesPage._dateFormat.format(message.createdAt!) : '';
    return ListTile(
      leading: Icon(message.isMeeting ? Icons.event_outlined : Icons.mail_outline, color: color),
      title: Text(
        message.title,
        style: TextStyle(color: color, fontWeight: isUnread ? FontWeight.bold : FontWeight.normal),
      ),
      subtitle: Text('De ${message.senderName} • $timestamp', style: TextStyle(color: color)),
      onTap: () =>
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => MessageDetailPage(messageId: message.id))),
    );
  }
}
