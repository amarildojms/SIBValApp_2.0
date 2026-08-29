import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../devotionals/devotional_detail_page.dart';
import '../events/event_detail_page.dart';
import '../events/event_started_tag.dart';
import '../theme/app_theme.dart';
import '../models/post.dart';

/// Espelha item_post.xml/PostAdapter.kt: cabeçalho (autor + hora de criação
/// do post, sem alteração), texto, imagem grande em 16:9 (mesma proporção
/// usada pelos eventos), e a barra de curtir/comentar.
///
/// Sem equivalente nativo: posts de evento deixam de ser tocáveis — com um
/// selo discreto "Finalizado" e leve sombreamento no card inteiro — 5 horas
/// depois do horário de início (`Post.isPastEvent`, 27/08/2026 — antes era
/// baseado no dia civil). A linha `🗓️ (Ter) dd/MM, HH:mm` dentro do texto do
/// post vem pronta da Cloud Function com a abreviação do dia da semana
/// (`formatEventFeedText` em functions/index.js) — `_textWithHojeAmanha`
/// troca esse trecho por `(Hoje)`/`(Amanhã)` **no cliente**, calculado a
/// cada rebuild (`Post.isEventToday`/`Post.isEventTomorrow`), sem precisar
/// repostar (27/08/2026, revisão do que era feito só no servidor via reposte
/// 24h/6h antes do evento — reposte removido no mesmo dia). Post de
/// devocional ganha o mesmo sombreamento leve assim que deixa de ser
/// `isFromToday` (devocional de um dia anterior).
///
/// Selo "Iniciado às HH:mm" (29/08/2026, pedido do usuário) — aparece em cima
/// da imagem assim que chega o horário de início do evento (`Post.hasStarted`,
/// `event_started_tag.dart`, compartilhado com `event_card.dart`/
/// `event_detail_page.dart`) e some quando o selo "Finalizado" assume (5h
/// depois, `isPastEvent`) — os dois nunca aparecem juntos.
///
/// Post manual (`PostType.manual`) publicado no próprio dia (`isFromToday`)
/// é tratado como urgente (27/08/2026, pedido do usuário) — ganha a faixa
/// "ATENÇÃO" no topo do card; a posição no feed (topo do dia, 5º lugar
/// depois) é decidida em `home_feed_page.dart`, não aqui.
///
/// [onEditTap]/[onDeleteTap] só vêm preenchidos pra post manual do próprio
/// autor (ou admin) — mostram um menu (⋮) no cabeçalho.
///
/// O flyer do post automático de devocional (`PostType.devotional`) também
/// é tocável (24/08/2026, a pedido do usuário) — leva pra
/// `DevotionalDetailPage` daquele dia via `Post.targetId` (gravado como o id
/// da devocional pela Cloud Function que cria o post, mesmo campo usado por
/// evento pro id do evento).
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.liked,
    required this.onLikeTap,
    required this.onCommentTap,
    this.onEditTap,
    this.onDeleteTap,
  });

  final Post post;
  final bool liked;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback? onEditTap;
  final VoidCallback? onDeleteTap;

  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
  static final _weekdayParenRegex = RegExp(r'🗓️ \([^)]+\)');

  /// Só troca o `(dia da semana)` da linha `🗓️ (...)` já gerada pela Cloud
  /// Function por `(Hoje)`/`(Amanhã)` quando aplicável — calculado no
  /// cliente a cada rebuild, sem depender de reposte no servidor.
  String get _textWithHojeAmanha {
    if (post.postType != PostType.event) return post.text;
    final replacement = post.isEventToday
        ? 'Hoje'
        : post.isEventTomorrow
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
    final isDevotional = post.postType == PostType.devotional;
    final isUrgent = post.postType == PostType.manual && post.isFromToday;
    final eventDate = post.eventDateSaoPaulo;
    // Sem data resolvida (evento apagado ou virou inacessível) conta como
    // finalizado também — o link levaria a "Evento não encontrado", então
    // não faz sentido deixar tocável nem omitir o selo só por falta de dado.
    final isPastEvent = isEvent && (eventDate == null || post.isPastEvent);
    final isTappable =
        (isEvent &&
            post.targetId.isNotEmpty &&
            eventDate != null &&
            !post.isPastEvent) ||
        (isDevotional && post.targetId.isNotEmpty);
    // Leve sombreamento (27/08/2026, pedido do usuário): evento finalizado
    // ou devocional que não é mais a de hoje.
    final dimmed = isPastEvent || (isDevotional && !post.isFromToday);

    final cardColor = Theme.of(context).cardColor;
    return Opacity(
      opacity: dimmed ? 0.6 : 1,
      child: Card(
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isUrgent) const _UrgentBanner(),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      post.authorName.isNotEmpty
                          ? post.authorName
                          : 'SIBVal Connect',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (post.createdAt != null)
                    Text(
                      _dateFormat.format(post.createdAt!),
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  if (onEditTap != null || onDeleteTap != null)
                    PopupMenuButton<VoidCallback>(
                      icon: Icon(Icons.more_vert, color: context.textSecondary),
                      onSelected: (action) => action(),
                      itemBuilder: (context) => [
                        if (onEditTap != null)
                          PopupMenuItem(
                            value: onEditTap!,
                            child: const Text('Editar'),
                          ),
                        if (onDeleteTap != null)
                          PopupMenuItem(
                            value: onDeleteTap!,
                            child: const Text('Excluir'),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            if (post.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
                child: Text(
                  _textWithHojeAmanha,
                  style: TextStyle(color: context.textPrimary),
                ),
              ),
            if (post.imageUrl.isNotEmpty)
              GestureDetector(
                onTap: isTappable
                    ? () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => isDevotional
                              ? DevotionalDetailPage(
                                  devotionalId: post.targetId,
                                )
                              : EventDetailPage(eventId: post.targetId),
                        ),
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
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                          errorBuilder: (context, error, stack) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    if (isPastEvent)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Finalizado',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      )
                    else if (isEvent && eventDate != null && post.hasStarted)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: EventStartedTag(time: eventDate),
                      ),
                  ],
                ),
              ),
            _buildLikeCommentBar(context),
          ],
        ),
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
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  backgroundImage: post.imageUrl.isNotEmpty
                      ? NetworkImage(post.imageUrl)
                      : null,
                  child: post.imageUrl.isEmpty
                      ? Icon(Icons.cake_outlined, color: context.textSecondary)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.text,
                        style: TextStyle(color: context.textPrimary),
                      ),
                      if (post.createdAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _dateFormat.format(post.createdAt!),
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 12,
                          ),
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
          Text(
            '${post.likedBy.length}',
            style: TextStyle(color: context.textPrimary),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: onCommentTap,
            icon: Icon(Icons.chat_bubble_outline, color: context.textSecondary),
          ),
          Text(
            '${post.commentCount}',
            style: TextStyle(color: context.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// "ATENÇÃO" no topo do card — post manual publicado no próprio dia
/// (27/08/2026, pedido do usuário: post inserido direto no Início é
/// considerado urgente/informação importante enquanto durar o dia da
/// postagem). Sem faixa colorida (removida 27/08/2026, a pedido do usuário)
/// — só o ícone e o texto em vermelho, na cor de fundo normal do card.
/// `Icons.warning_amber_rounded` — volta ao ícone original (era branco
/// sobre a faixa vermelha), agora só ele em vermelho.
class _UrgentBanner extends StatelessWidget {
  const _UrgentBanner();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
          SizedBox(width: 6),
          Text(
            'ATENÇÃO',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
