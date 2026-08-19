import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/gallery_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../data/user_repository.dart';
import '../models/gallery_image.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'image_viewer_page.dart';

/// Espelha GaleriaFragment.kt: grade de fotos do álbum (3 colunas). Subir e
/// apagar foto é ação de quem tem o cargo Mídia (ou admin).
class AlbumPhotosPage extends ConsumerWidget {
  const AlbumPhotosPage({super.key, required this.albumId, required this.albumName});

  final String albumId;
  final String albumName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imagesAsync = ref.watch(albumImagesProvider(albumId));
    final profileAsync = ref.watch(currentUserProfileProvider);
    final canManageGallery = profileAsync.asData?.value?.canManageGallery ?? false;

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      floatingActionButton: canManageGallery
          ? FloatingActionButton(
              heroTag: 'album_photos_fab',
              onPressed: () => _upload(context, ref),
              child: const Icon(Icons.add_a_photo_outlined),
            )
          : null,
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenTitle(albumName),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(albumImagesProvider(albumId).future),
              child: imagesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 80),
              Center(child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary))),
            ],
          ),
          data: (images) {
            if (images.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Text('Nenhuma foto neste álbum ainda.', style: TextStyle(color: context.textSecondary)),
                  ),
                ],
              );
            }
            final urls = images.map((i) => i.downloadUrl).toList();
            return GridView.builder(
              padding: const EdgeInsets.all(4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: images.length,
              itemBuilder: (context, index) {
                final placeholderColor = Theme.of(context).colorScheme.surfaceContainerHighest;
                final image = images[index];
                return InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ImageViewerPage(urls: urls, initialIndex: index)),
                  ),
                  onLongPress: canManageGallery ? () => _confirmDelete(context, ref, image) : null,
                  child: Image.network(
                    image.downloadUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      color: placeholderColor,
                      child: Icon(Icons.broken_image_outlined, color: context.textSecondary),
                    ),
                  ),
                );
              },
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

  Future<void> _upload(BuildContext context, WidgetRef ref) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 82,
    );
    if (picked == null) return;

    final uid = ref.read(currentUidProvider) ?? '';
    final profile = ref.read(currentUserProfileProvider).asData?.value;
    try {
      await ref.read(galleryRepositoryProvider).uploadImage(
            file: File(picked.path),
            albumId: albumId,
            uploaderUid: uid,
            uploaderName: profile?.name ?? '',
          );
      ref.invalidate(albumImagesProvider(albumId));
      ref.invalidate(albumsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha ao subir foto: $e')));
      }
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, GalleryImage image) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir foto'),
        content: const Text('Tem certeza que deseja excluir esta foto?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref.read(galleryRepositoryProvider).deleteImage(image);
              ref.invalidate(albumImagesProvider(albumId));
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}
