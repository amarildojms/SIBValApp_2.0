import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/message_repository.dart';
import '../models/app_message.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

/// Caixa de Saída (24/08/2026, sem equivalente no app nativo) — histórico das
/// mensagens que o próprio usuário logado enviou (não as de outros admins,
/// ver `sentMessagesProvider`). Acesso fica dentro de `MessagesPage` (ícone
/// na app bar, só pra quem pode enviar), não no menu Mais. Cada item se
/// expande pra mostrar o texto completo em vez de navegar pra
/// `MessageDetailPage` — essa reusa `messageByIdProvider`/`markAsRead` que
/// contaria o próprio remetente como leitor, distorcendo `readBy`.
class MessageOutboxPage extends ConsumerWidget {
  const MessageOutboxPage({super.key});

  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(sentMessagesProvider);

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Mensagens Enviadas'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(sentMessagesProvider);
                  await ref.read(sentMessagesProvider.future);
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
                              'Nenhuma mensagem enviada ainda.',
                              style: TextStyle(color: context.textSecondary),
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView.builder(
                      itemCount: messages.length,
                      itemBuilder: (context, index) => _SentMessageTile(message: messages[index]),
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

class _SentMessageTile extends StatelessWidget {
  const _SentMessageTile({required this.message});

  final AppMessage message;

  String get _destinationLabel {
    if (message.sendToAll) return 'Para todos';
    final parts = <String>[];
    if (message.targetUserUids.isNotEmpty) parts.add('${message.targetUserUids.length} usuário(s)');
    if (message.targetMinistryIds.isNotEmpty) parts.add('${message.targetMinistryIds.length} ministério(s)');
    return parts.isEmpty ? 'Sem destinatários' : parts.join(' + ');
  }

  @override
  Widget build(BuildContext context) {
    final timestamp = message.createdAt != null ? MessageOutboxPage._dateFormat.format(message.createdAt!) : '';
    return ExpansionTile(
      leading: Icon(
        message.isMeeting ? Icons.event_outlined : Icons.mail_outline,
        color: context.textSecondary,
      ),
      title: Text(message.title, style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
      subtitle: Text(
        '$_destinationLabel • $timestamp',
        style: TextStyle(color: context.textSecondary, fontSize: 12),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message.body, style: TextStyle(color: context.textPrimary)),
              const SizedBox(height: 8),
              Text(
                'Lida por ${message.readBy.length} pessoa(s)',
                style: TextStyle(color: context.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
