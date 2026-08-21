import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/post_repository.dart';
import '../data/user_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'post_card.dart';
import 'post_comments_page.dart';
import 'post_form_page.dart';

/// Espelha HomeFragment.kt/HomeViewModel.kt: lista de posts do feed, com
/// curtir e comentar. Criação de post manual (21/08/2026, sem equivalente no
/// nativo) fica atrás do FAB, restrita a quem tem `canManagePublications`
/// (papel Publicações ou admin).
class HomeFeedPage extends ConsumerWidget {
  const HomeFeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(postsProvider);
    final uid = ref.watch(currentUidProvider);
    final canManagePublications = ref.watch(currentUserProfileProvider).asData?.value?.canManagePublications ?? false;

    return Scaffold(
      appBar: const SibValAppBar(isHome: true),
      floatingActionButton: canManagePublications
          ? FloatingActionButton(
              heroTag: 'home_feed_fab',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PostFormPage())),
              child: const Icon(Icons.add),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(postsProvider.future),
        child: postsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 80),
              Center(child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary))),
            ],
          ),
          data: (posts) {
            if (posts.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Text('Nenhuma notícia publicada ainda.', style: TextStyle(color: context.textSecondary)),
                  ),
                ],
              );
            }
            return ListView.builder(
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                final liked = uid != null && post.likedBy.contains(uid);
                return PostCard(
                  post: post,
                  liked: liked,
                  onLikeTap: () async {
                    if (uid == null) {
                      _showLoginRequired(context);
                      return;
                    }
                    await ref.read(postRepositoryProvider).toggleLike(post.id, uid, !liked);
                    ref.invalidate(postsProvider);
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
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showLoginRequired(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Faça login para curtir ou comentar.')),
    );
  }
}
