import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/post_repository.dart';
import '../data/user_repository.dart';
import '../models/notification.dart';
import '../models/post.dart';
import '../notifications/notification_read_sync.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'post_card.dart';
import 'post_comments_page.dart';
import 'post_form_page.dart';

/// Espelha HomeFragment.kt/HomeViewModel.kt: lista de posts do feed, com
/// curtir e comentar. Criação de post manual (21/08/2026, sem equivalente no
/// nativo) fica atrás do FAB, restrita a quem tem `canManagePublications`
/// (papel Publicações ou admin).
///
/// **Extraído de `HomeFeedPage` em 02/09/2026** (pedido do usuário, inspirado
/// num modelo de referência trazido por ele: `NOVO_LAYOUT.jpeg`) — o Mural
/// virou uma aba própria da barra inferior (`muralTabIndex`), separada do
/// painel de Início (`HomePage`/`HomeHighlights`, que ficou só com a grade de
/// acesso rápido + os cards "Próximo na Igreja"/"Devocional de Hoje"). Toda a
/// lógica de ranking/banner abaixo é a mesma de antes, só mudou de arquivo.
///
/// `postsProvider` é um `StreamProvider` (`.snapshots()`) — o feed atualiza
/// sozinho quando qualquer post muda (novo evento vigente, devocional do
/// dia, aniversariante, reposte, curtida...), sem pull-to-refresh.
///
/// Aniversário de MEMBRESIA (25/08/2026, revisão do que existia desde
/// 24/08/2026): deixou de ser um post fixado no topo da lista — virou um
/// banner fixo acima da lista (`_MembershipAnniversaryBanner`), igual ao
/// `ownBirthdayBanner`/`checkOwnBirthday` do `HomeFragment.kt`/
/// `HomeViewModel.kt` nativo (TextView fora do RecyclerView, sem curtir nem
/// comentar). A Cloud Function continua criando o documento em `posts`
/// (`postType: membership_anniversary`, `targetId` = uid do aniversariante)
/// só como fonte de dado em tempo real pro banner — ele nunca chega a
/// aparecer na lista. Como o banner mora aqui agora (não mais em `HomePage`),
/// `notification_navigation.dart` leva pra `muralTabIndex`, não mais pro
/// `homeTabIndex`, quando o tipo é `membershipAnniversary`.
class MuralPage extends ConsumerStatefulWidget {
  const MuralPage({super.key});

  @override
  ConsumerState<MuralPage> createState() => _MuralPageState();
}

class _MuralPageState extends ConsumerState<MuralPage> {
  Timer? _reorderTicker;

  @override
  void initState() {
    super.initState();
    // Sem targetId (igual ao tipo `birthday`): a notificação de aniversário
    // de MEMBRESIA agora leva direto pro Mural (ver
    // `notification_navigation.dart`), então simplesmente chegar aqui já
    // marca como lida e cancela da barra do celular.
    syncNotificationsForScreen(
      ref,
      type: NotificationType.membershipAnniversary,
    );
    // Reordena o feed sozinho quando só o relógio muda o resultado de
    // `_feedRank`/`Post.isPastEvent`/`Post.isFromToday` — evento cruzando a
    // marca de 5h, devocional/aniversariante virando "não é mais de hoje" à
    // meia-noite (27/08/2026, pedido do usuário). Sem isso, essas faixas só
    // recalculavam quando uma escrita nova chegava pelo `postsProvider`
    // (`StreamProvider`). Um minuto é granularidade de sobra pra esses dois
    // critérios (nenhum precisa de precisão de segundo).
    _reorderTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _reorderTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(postsProvider);
    final uid = ref.watch(currentUidProvider);
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final canManagePublications = profile?.canManagePublications ?? false;
    final isAdmin = profile?.isAdmin ?? false;

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      floatingActionButton: canManagePublications
          ? FloatingActionButton(
              heroTag: 'mural_fab',
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const PostFormPage())),
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenTitle('Mural'),
          Expanded(
            child: postsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Text(
                      'Falha ao carregar: $error',
                      style: TextStyle(color: context.textPrimary),
                    ),
                  ),
                ],
              ),
              data: (posts) {
                // Post de aniversário de MEMBRESIA só vira o banner fixo pra
                // quem tem targetId == uid logado, e só no próprio dia do
                // aniversário (isFromToday) — todo mundo mais nem sabe que
                // ele existe, mesmo a coleção `posts` sendo de leitura
                // pública (o filtro é só aqui, no cliente; ver
                // PostType.membershipAnniversary). Nunca entra na lista
                // comum, curtível/comentável.
                Post? membershipAnniversaryPost;
                final feedPosts = <Post>[];
                for (final post in posts) {
                  if (post.postType == PostType.membershipAnniversary) {
                    if (uid != null &&
                        post.targetId == uid &&
                        post.isFromToday) {
                      membershipAnniversaryPost = post;
                    }
                    continue;
                  }
                  feedPosts.add(post);
                }
                feedPosts.sort(_compareFeedPosts);

                return Column(
                  children: [
                    if (membershipAnniversaryPost != null)
                      _MembershipAnniversaryBanner(
                        text: membershipAnniversaryPost.text,
                      ),
                    Expanded(
                      child: feedPosts.isEmpty
                          ? ListView(
                              children: [
                                const SizedBox(height: 80),
                                Center(
                                  child: Text(
                                    'Nenhuma notícia publicada ainda.',
                                    style: TextStyle(
                                      color: context.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              itemCount: feedPosts.length,
                              itemBuilder: (context, index) {
                                final post = feedPosts[index];
                                final liked =
                                    uid != null &&
                                    post.likedBy.contains(uid);
                                final canEdit =
                                    post.postType == PostType.manual &&
                                    (isAdmin ||
                                        (uid != null &&
                                            post.authorUid == uid));
                                return PostCard(
                                  post: post,
                                  liked: liked,
                                  onLikeTap: () async {
                                    if (uid == null) {
                                      _showLoginRequired(context);
                                      return;
                                    }
                                    await ref
                                        .read(postRepositoryProvider)
                                        .toggleLike(post.id, uid, !liked);
                                  },
                                  onCommentTap: () {
                                    if (uid == null) {
                                      _showLoginRequired(context);
                                      return;
                                    }
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            PostCommentsPage(postId: post.id),
                                      ),
                                    );
                                  },
                                  onEditTap: canEdit
                                      ? () => Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                PostFormPage(editing: post),
                                          ),
                                        )
                                      : null,
                                  onDeleteTap: canEdit
                                      ? () =>
                                            _confirmDelete(context, ref, post)
                                      : null,
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Post post,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir publicação'),
        content: const Text(
          'Excluir esta publicação? Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(postRepositoryProvider).deleteManualPost(post);
    }
  }

  void _showLoginRequired(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Faça login para curtir ou comentar.')),
    );
  }
}

/// Espelha `ownBirthdayBanner` (fragment_home.xml/HomeFragment.kt nativo):
/// faixa fixa acima da lista, fora do scroll — dourada, texto em negrito na
/// cor navy —, não um card dentro do feed. Sem curtir/comentar.
class _MembershipAnniversaryBanner extends StatelessWidget {
  const _MembershipAnniversaryBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: SibValColors.goldAccent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: SibValColors.navyBlue,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}

/// Ordenação do feed (27/08/2026, pedido do usuário — reintroduz uma
/// ordenação por regra, que tinha sido removida em 24/08/2026 em favor de
/// só `createdAt`; mesmo dia, revisão posterior adicionou a faixa 2 abaixo —
/// evento no próprio dia sobe pro topo, independente de ser pontual ou
/// recorrente). Faixas fixas, da mais alta pra mais baixa prioridade:
///
/// 0. Post manual urgente (`PostType.manual` publicado hoje) — "ATENÇÃO".
/// 1. Aniversariante(s) do dia.
/// 2. Evento (pontual ou recorrente) que acontece hoje (`Post.isEventToday`)
///    e ainda não finalizado — mais próximo primeiro. Pedido do usuário: no
///    dia do evento ele sobe pro topo, só abaixo de aniversariante/urgente.
/// 3. Evento pontual (não recorrente) que NÃO é hoje, ainda não finalizado,
///    mais próximo primeiro.
/// 4. Devocional de hoje (`isFromToday`).
/// 5. Evento recorrente que NÃO é hoje, ainda não finalizado, mais próximo
///    primeiro.
/// 6. Resto (post manual/aniversariante que não é mais de hoje etc.), mais
///    recente primeiro — mesmo critério do feed antigo (`createdAt`).
/// 7. "Fim da lista": eventos finalizados (pontuais e recorrentes juntos) e
///    devocional que não é mais a de hoje (27/08/2026, pedido do usuário —
///    antes ficava presa na faixa 3, só sombreada, sem cair de posição
///    "como os eventos finalizados") — mais recente primeiro (evento pelo
///    horário de início, devocional pelo `createdAt` do post).
///
/// "Finalizado" = 5h depois do início (`Post.isPastEvent`), não mais o dia
/// civil seguinte. Pontual vs. recorrente vem de `Post.isRecurringEvent`
/// (campo `isRecurring`, gravado pela Cloud Function ao criar o post —
/// `SIBValApp2/functions/index.js`, `createFeedPost`).
int _feedRank(Post post) {
  final isEvent = post.postType == PostType.event;
  final isDevotional = post.postType == PostType.devotional;
  if (post.postType == PostType.manual && post.isFromToday) return 0;
  if (post.postType == PostType.birthday && post.isFromToday) return 1;
  if (isEvent && post.isEventToday && !post.isPastEvent) return 2;
  if (isEvent && !post.isRecurringEvent && !post.isPastEvent) return 3;
  if (isDevotional && post.isFromToday) return 4;
  if (isEvent && post.isRecurringEvent && !post.isPastEvent) return 5;
  if ((isEvent && post.isPastEvent) || (isDevotional && !post.isFromToday)) return 7;
  return 6;
}

/// Data usada pra ordenar dentro da faixa 7 — horário de início pro evento,
/// `createdAt` do post pra devocional (que não tem `eventDateTimeMillis`).
DateTime _rankSevenSortDate(Post post) {
  if (post.eventDateTimeMillis != null) {
    return DateTime.fromMillisecondsSinceEpoch(post.eventDateTimeMillis!);
  }
  return post.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
}

int _compareFeedPosts(Post a, Post b) {
  final rankA = _feedRank(a);
  final rankB = _feedRank(b);
  if (rankA != rankB) return rankA.compareTo(rankB);
  switch (rankA) {
    case 2:
    case 3:
    case 5:
      // Eventos ativos: mais próximo de acontecer primeiro.
      return (a.eventDateTimeMillis ?? 0).compareTo(b.eventDateTimeMillis ?? 0);
    case 7:
      // Fim da lista: mais recente primeiro.
      return _rankSevenSortDate(b).compareTo(_rankSevenSortDate(a));
    default:
      final createdA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final createdB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return createdB.compareTo(createdA);
  }
}
