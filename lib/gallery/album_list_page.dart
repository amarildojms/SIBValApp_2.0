import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/login_page.dart';
import '../data/gallery_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../data/user_repository.dart';
import '../models/album.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'album_photos_page.dart';

/// Espelha AlbumListFragment.kt: grade de álbuns (2 colunas). Criar/apagar
/// álbum é ação de quem tem o cargo Mídia (ou admin).
class AlbumListPage extends ConsumerWidget {
  const AlbumListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);

    if (uid == null) {
      return Scaffold(
        appBar: const SibValAppBar(isHome: false),
        body: SafeArea(
          bottom: true,
          top: false,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Galeria'),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Faça login para ver a galeria de fotos.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        ),
                        child: const Text('Entrar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          ),
        ),
      );
    }

    final albumsAsync = ref.watch(albumsProvider);
    final profileAsync = ref.watch(currentUserProfileProvider);
    final canManageGallery = profileAsync.asData?.value?.canManageGallery ?? false;

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      floatingActionButton: canManageGallery
          ? FloatingActionButton(
              heroTag: 'album_list_fab',
              onPressed: () => _showCreateAlbumDialog(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenTitle('Galeria'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(albumsProvider.future),
              child: albumsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ListView(
                  children: [
                    const SizedBox(height: 80),
                    Center(child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary))),
                  ],
                ),
                data: (albums) {
                  if (albums.isEmpty) {
                    return ListView(
                      children: [
                        const SizedBox(height: 80),
                        Center(
                          child: Text('Nenhum álbum publicado ainda.', style: TextStyle(color: context.textSecondary)),
                        ),
                      ],
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: albums.length,
                    itemBuilder: (context, index) =>
                        _AlbumTile(album: albums[index], canManageGallery: canManageGallery),
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

  void _showCreateAlbumDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Criar álbum'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Nome')),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.of(dialogContext).pop();
              final uid = ref.read(currentUidProvider) ?? '';
              await ref.read(galleryRepositoryProvider).createAlbum(name, uid);
              ref.invalidate(albumsProvider);
            },
            child: const Text('Criar'),
          ),
        ],
      ),
    );
  }
}

class _AlbumTile extends ConsumerWidget {
  const _AlbumTile({required this.album, required this.canManageGallery});

  final Album album;
  final bool canManageGallery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeholderColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AlbumPhotosPage(albumId: album.id, albumName: album.name)),
      ),
      onLongPress: canManageGallery ? () => _confirmDelete(context, ref) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: album.coverUrl.isNotEmpty
                  ? Image.network(
                      album.coverUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stack) => Container(
                        color: placeholderColor,
                        child: Icon(Icons.photo_library_outlined, color: context.textSecondary),
                      ),
                    )
                  : Container(
                      color: placeholderColor,
                      child: Icon(Icons.photo_library_outlined, color: context.textSecondary),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            album.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir álbum'),
        content: Text('Tem certeza que deseja excluir "${album.name}"? Todas as fotos dele também serão apagadas.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref.read(galleryRepositoryProvider).deleteAlbum(album.id);
              ref.invalidate(albumsProvider);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}
