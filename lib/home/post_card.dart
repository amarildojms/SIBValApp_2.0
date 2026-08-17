import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/post.dart';

/// Espelha item_post.xml/PostAdapter.kt: cabeçalho (autor + hora), texto,
/// imagem grande em 16:9 (mesma proporção usada pelos eventos), e a barra de
/// curtir/comentar.
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

  @override
  Widget build(BuildContext context) {
    return Card(
      color: SibValColors.navyBlueLight,
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
                    post.authorName.isNotEmpty ? post.authorName : 'SIB Val App',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                if (post.createdAt != null)
                  Text(
                    _dateFormat.format(post.createdAt!),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
          ),
          if (post.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
              child: Text(post.text, style: const TextStyle(color: Colors.white)),
            ),
          if (post.imageUrl.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: SibValColors.navyBlueLight,
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
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                IconButton(
                  onPressed: onLikeTap,
                  icon: Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    color: liked ? Colors.redAccent : Colors.white70,
                  ),
                ),
                Text('${post.likedBy.length}', style: const TextStyle(color: Colors.white)),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: onCommentTap,
                  icon: const Icon(Icons.chat_bubble_outline, color: Colors.white70),
                ),
                Text('${post.commentCount}', style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
