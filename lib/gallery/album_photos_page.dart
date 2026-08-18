import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/gallery_repository.dart';
import '../theme/app_theme.dart';
import 'image_viewer_page.dart';

/// Espelha GaleriaFragment.kt: grade de fotos do álbum (3 colunas). Subir e
/// apagar foto é ação de quem tem o cargo Mídia — fica para a fase do Painel
/// Admin.
class AlbumPhotosPage extends ConsumerWidget {
  const AlbumPhotosPage({super.key, required this.albumId, required this.albumName});

  final String albumId;
  final String albumName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imagesAsync = ref.watch(albumImagesProvider(albumId));

    return Scaffold(
      appBar: AppBar(title: Text(albumName)),
      body: RefreshIndicator(
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
                return InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ImageViewerPage(urls: urls, initialIndex: index)),
                  ),
                  child: Image.network(
                    images[index].downloadUrl,
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
    );
  }
}
