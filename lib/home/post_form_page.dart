import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/post_repository.dart';
import '../data/user_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

/// Publicação manual no feed "Início" — tela nova (21/08/2026), sem
/// equivalente no app nativo. Só quem tem `canManagePublications` (papel
/// Publicações ou admin) chega aqui (gate no FAB de `HomeFeedPage`).
class PostFormPage extends ConsumerStatefulWidget {
  const PostFormPage({super.key});

  @override
  ConsumerState<PostFormPage> createState() => _PostFormPageState();
}

class _PostFormPageState extends ConsumerState<PostFormPage> {
  final _textController = TextEditingController();
  File? _pickedImage;
  bool _saving = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 82,
    );
    if (picked != null) setState(() => _pickedImage = File(picked.path));
  }

  Future<void> _publish() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escreva algo para publicar.')));
      return;
    }
    final uid = ref.read(currentUidProvider);
    final profile = ref.read(currentUserProfileProvider).asData?.value;
    if (uid == null || profile == null) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(postRepositoryProvider)
          .createManualPost(authorUid: uid, authorName: profile.shortName, text: text, imageFile: _pickedImage);
      ref.invalidate(postsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenTitle('Nova publicação'),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    image: _pickedImage != null
                        ? DecorationImage(image: FileImage(_pickedImage!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _pickedImage == null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, color: context.textSecondary, size: 32),
                              const SizedBox(height: 8),
                              Text('Adicionar imagem (opcional)', style: TextStyle(color: context.textSecondary)),
                            ],
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _textController,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Texto da publicação', alignLabelWithHint: true),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _publish,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Publicar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
