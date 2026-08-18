import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/gallery_repository.dart';
import '../models/album.dart';
import '../theme/app_theme.dart';
import 'album_photos_page.dart';

/// Espelha AlbumListFragment.kt: grade de álbuns (2 colunas). Criar/apagar
/// álbum é ação de quem tem o cargo Mídia — fica para a fase do Painel Admin.
class AlbumListPage extends ConsumerWidget {
  const AlbumListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(albumsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Galeria')),
      body: RefreshIndicator(
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
              itemBuilder: (context, index) => _AlbumTile(album: albums[index]),
            );
          },
        ),
      ),
    );
  }
}

class _AlbumTile extends StatelessWidget {
  const _AlbumTile({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    final placeholderColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AlbumPhotosPage(albumId: album.id, albumName: album.name)),
      ),
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
}
