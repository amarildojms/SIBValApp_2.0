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
/// aparecer na lista.
class HomeFeedPage extends ConsumerStatefulWidget {
  const HomeFeedPage({super.key});

  @override
  ConsumerState<HomeFeedPage> createState() => _HomeFeedPageState();
}

class _HomeFeedPageState extends ConsumerState<HomeFeedPage> {
  @override
  void initState() {
    super.initState();
    // Sem targetId (igual ao tipo `birthday`): a notificação de aniversário
    // de MEMBRESIA agora leva direto pro Início (ver
    // `notification_navigation.dart`), então simplesmente chegar aqui já
    // marca como lida e cancela da barra do celular.
    syncNotificationsForScreen(ref, type: NotificationType.membershipAnniversary);
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(postsProvider);
    final uid = ref.watch(currentUidProvider);
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final canManagePublications = profile?.canManagePublications ?? false;
    final isAdmin = profile?.isAdmin ?? false;

    return Scaffold(
      appBar: const SibValAppBar(isHome: true),
      floatingActionButton: canManagePublications
          ? FloatingActionButton(
              heroTag: 'home_feed_fab',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PostFormPage())),
              child: const Icon(Icons.add),
            )
          : null,
      body: postsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          children: [
            const SizedBox(height: 80),
            Center(child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary))),
          ],
        ),
        data: (posts) {
          // Post de aniversário de MEMBRESIA só vira o banner fixo pra quem
          // tem targetId == uid logado, e só no próprio dia do aniversário
          // (isFromToday) — todo mundo mais nem sabe que ele existe, mesmo a
          // coleção `posts` sendo de leitura pública (o filtro é só aqui, no
          // cliente; ver PostType.membershipAnniversary). Nunca entra na
          // lista comum, curtível/comentável.
          Post? membershipAnniversaryPost;
          final feedPosts = <Post>[];
          for (final post in posts) {
            if (post.postType == PostType.membershipAnniversary) {
              if (uid != null && post.targetId == uid && post.isFromToday) membershipAnniversaryPost = post;
              continue;
            }
            feedPosts.add(post);
          }

          return Column(
            children: [
              if (membershipAnniversaryPost != null)
                _MembershipAnniversaryBanner(text: membershipAnniversaryPost.text),
              Expanded(
                child: feedPosts.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 80),
                          Center(
                            child: Text(
                              'Nenhuma notícia publicada ainda.',
                              style: TextStyle(color: context.textSecondary),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        itemCount: feedPosts.length,
                        itemBuilder: (context, index) {
                          final post = feedPosts[index];
                          final liked = uid != null && post.likedBy.contains(uid);
                          final canEdit = post.postType == PostType.manual &&
                              (isAdmin || (uid != null && post.authorUid == uid));
                          return PostCard(
                            post: post,
                            liked: liked,
                            onLikeTap: () async {
                              if (uid == null) {
                                _showLoginRequired(context);
                                return;
                              }
                              await ref.read(postRepositoryProvider).toggleLike(post.id, uid, !liked);
                            },
                            onCommentTap: () {
                              if (uid == null) {
                                _showLoginRequired(context);
                                return;
                              }
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => PostCommentsPage(postId: post.id)),
                              );
                            },
                            onEditTap: canEdit
                                ? () => Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => PostFormPage(editing: post)),
                                    )
                                : null,
                            onDeleteTap: canEdit ? () => _confirmDelete(context, ref, post) : null,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Post post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir publicação'),
        content: const Text('Excluir esta publicação? Essa ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Excluir')),
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
        style: const TextStyle(color: SibValColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }
}
