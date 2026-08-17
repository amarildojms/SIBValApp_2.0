import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/post_repository.dart';
import '../theme/app_theme.dart';
import 'post_card.dart';
import 'post_comments_page.dart';

/// Espelha HomeFragment.kt/HomeViewModel.kt: lista de posts do feed, com
/// curtir e comentar. A criação de post manual (admin) fica para uma fase
/// seguinte — aqui é a experiência de leitura do feed.
class HomeFeedPage extends ConsumerWidget {
  const HomeFeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(postsProvider);
    final uid = ref.watch(currentUidProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Início')),
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
