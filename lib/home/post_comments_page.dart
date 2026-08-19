import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/post_repository.dart';
import '../models/comment.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

/// Espelha PostCommentsFragment.kt/PostCommentsViewModel.kt.
class PostCommentsPage extends ConsumerStatefulWidget {
  const PostCommentsPage({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<PostCommentsPage> createState() => _PostCommentsPageState();
}

class _PostCommentsPageState extends ConsumerState<PostCommentsPage> {
  final _commentController = TextEditingController();
  List<Comment> _comments = [];
  bool _loading = true;
  bool _sending = false;

  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final comments = await ref.read(postRepositoryProvider).getComments(widget.postId);
      if (mounted) setState(() => _comments = comments);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _sending = true);
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final name = userDoc.data()?['name'] as String? ?? '';
      await ref.read(postRepositoryProvider).addComment(widget.postId, uid, name, text);
      _commentController.clear();
      await _load();
      ref.invalidate(postsProvider);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenTitle('Comentários'),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? Center(
                        child: Text('Nenhum comentário ainda.', style: TextStyle(color: context.textSecondary)),
                      )
                    : ListView.builder(
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return ListTile(
                            title: Text(
                              comment.authorName.isNotEmpty ? comment.authorName : 'Alguém',
                              style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(comment.text, style: TextStyle(color: context.textSecondary)),
                            trailing: comment.createdAt != null
                                ? Text(
                                    _dateFormat.format(comment.createdAt!),
                                    style: TextStyle(color: context.textTertiary, fontSize: 11),
                                  )
                                : null,
                          );
                        },
                      ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(hintText: 'Escreva um comentário...'),
                    ),
                  ),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
