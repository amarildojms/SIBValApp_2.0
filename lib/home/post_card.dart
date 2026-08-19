import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../events/event_detail_page.dart';
import '../theme/app_theme.dart';
import '../models/event.dart' show toSaoPauloTimeNow;
import '../models/post.dart';

/// Espelha item_post.xml/PostAdapter.kt: cabeçalho (autor + hora de criação
/// do post, sem alteração), texto, imagem grande em 16:9 (mesma proporção
/// usada pelos eventos), e a barra de curtir/comentar.
///
/// Sem equivalente nativo: posts de evento deixam de ser tocáveis — com um
/// selo discreto "Finalizado" — assim que a data do evento passa
/// (`Post.isPastEvent`). Um evento cujo documento não foi encontrado (apagado
/// ou virou inacessível — ver `PostRepository._fetchEventDates`) entra na
/// mesma categoria: sem data pra mostrar, o link só levaria a uma tela de
/// "Evento não encontrado".
///
/// A linha `🗓️ (Ter) dd/MM, HH:mm` dentro do texto do post (gerada pela
/// Cloud Function `postEventToFeed` em functions/index.js) tem o dia da
/// semana entre parênteses trocado por `(Hoje)`/`(Amanhã)` quando aplicável —
/// só essa linha, não o cabeçalho.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.liked,
    required this.onLikeTap,
    required this.onCommentTap,
  });

  final Post post;
  final bool liked;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;

  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
  static final _weekdayParenRegex = RegExp(r'🗓️ \([^)]+\)');

  /// Só troca o `(dia da semana)` da linha `🗓️ (...)  já gerada pela Cloud
  /// Function — data e hora depois dele ficam como vieram, o resto do texto
  /// não é tocado.
  String _textWithHojeAmanha(DateTime? eventDate) {
    if (eventDate == null) return post.text;
    final today = toSaoPauloTimeNow();
    final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    final diff = eventDay.difference(todayDay).inDays;
    final replacement = diff == 0
        ? 'Hoje'
        : diff == 1
            ? 'Amanhã'
            : null;
    if (replacement == null) return post.text;
    return post.text.replaceFirst(_weekdayParenRegex, '🗓️ ($replacement)');
  }

  @override
  Widget build(BuildContext context) {
    if (post.postType == PostType.birthday) {
      return _buildBirthdayCard(context);
    }

    final isEvent = post.postType == PostType.event;
    final eventDate = post.eventDateSaoPaulo;
    // Sem data resolvida (evento apagado ou virou inacessível) conta como
    // finalizado também — o link levaria a "Evento não encontrado", então
    // não faz sentido deixar tocável nem omitir o selo só por falta de dado.
    final isPastEvent = isEvent && (eventDate == null || post.isPastEvent);
    final isTappable = isEvent && post.targetId.isNotEmpty && eventDate != null && !post.isPastEvent;

    final cardColor = Theme.of(context).cardColor;
    return Card(
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    post.authorName.isNotEmpty ? post.authorName : 'SIBVal Connect',
                    style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
                  ),
                ),
                if (post.createdAt != null)
                  Text(
                    _dateFormat.format(post.createdAt!),
                    style: TextStyle(color: context.textSecondary, fontSize: 12),
                  ),
              ],
            ),
          ),
          if (post.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
              child: Text(_textWithHojeAmanha(eventDate), style: TextStyle(color: context.textPrimary)),
            ),
          if (post.imageUrl.isNotEmpty)
            GestureDetector(
              onTap: isTappable
                  ? () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => EventDetailPage(eventId: post.targetId)),
                      )
                  : null,
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      color: cardColor,
                      child: Image.network(
                        post.imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(child: CircularProgressIndicator());
                        },
                        errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  if (isPastEvent)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Finalizado',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          _buildLikeCommentBar(context),
        ],
      ),
    );
  }

  /// Post automático de aniversário: card menor, com a miniatura da foto à
  /// esquerda e a mensagem de felicitações ao lado, em vez do layout grande
  /// de post comum (sem imagem 16:9).
  Widget _buildBirthdayCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  backgroundImage: post.imageUrl.isNotEmpty ? NetworkImage(post.imageUrl) : null,
                  child: post.imageUrl.isEmpty
                      ? Icon(Icons.cake_outlined, color: context.textSecondary)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.text, style: TextStyle(color: context.textPrimary)),
                      if (post.createdAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _dateFormat.format(post.createdAt!),
                          style: TextStyle(color: context.textSecondary, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildLikeCommentBar(context),
        ],
      ),
    );
  }

  Widget _buildLikeCommentBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          IconButton(
            onPressed: onLikeTap,
            icon: Icon(
              liked ? Icons.favorite : Icons.favorite_border,
              color: liked ? Colors.redAccent : context.textSecondary,
            ),
          ),
          Text('${post.likedBy.length}', style: TextStyle(color: context.textPrimary)),
          const SizedBox(width: 16),
          IconButton(
            onPressed: onCommentTap,
            icon: Icon(Icons.chat_bubble_outline, color: context.textSecondary),
          ),
          Text('${post.commentCount}', style: TextStyle(color: context.textPrimary)),
        ],
      ),
    );
  }
}
