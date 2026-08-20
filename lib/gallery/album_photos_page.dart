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
/// apagar foto é ação de quem tem o cargo Mídia (ou admin). Seleção múltipla
/// pra excluir várias fotos de uma vez (20/08/2026) segue o mesmo padrão de
/// `event_email_senders_page.dart`: toque longo entra em modo seleção, barra
/// acima da grade mostra a contagem e o botão de excluir.
class AlbumPhotosPage extends ConsumerStatefulWidget {
  const AlbumPhotosPage({super.key, required this.albumId, required this.albumName});

  final String albumId;
  final String albumName;

  @override
  ConsumerState<AlbumPhotosPage> createState() => _AlbumPhotosPageState();
}

class _AlbumPhotosPageState extends ConsumerState<AlbumPhotosPage> {
  final _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final imagesAsync = ref.watch(albumImagesProvider(widget.albumId));
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
            ScreenTitle(widget.albumName),
            if (_selected.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Cancelar seleção',
                      onPressed: () => setState(_selected.clear),
                    ),
                    Expanded(
                      child: Text(
                        '${_selected.length} selecionada(s)',
                        style: TextStyle(color: context.textSecondary, fontSize: 12),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Excluir selecionadas',
                      onPressed: () => _confirmAndDeleteSelected(context, ref),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(albumImagesProvider(widget.albumId).future),
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
                        final selected = _selected.contains(image.id);
                        return InkWell(
                          onTap: () {
                            if (_selected.isNotEmpty) {
                              setState(() => selected ? _selected.remove(image.id) : _selected.add(image.id));
                              return;
                            }
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => ImageViewerPage(urls: urls, initialIndex: index)),
                            );
                          },
                          onLongPress: canManageGallery ? () => setState(() => _selected.add(image.id)) : null,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                image.downloadUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) => Container(
                                  color: placeholderColor,
                                  child: Icon(Icons.broken_image_outlined, color: context.textSecondary),
                                ),
                              ),
                              if (selected)
                                Container(color: SibValColors.navyBlue.withValues(alpha: 0.45)),
                              if (canManageGallery && _selected.isNotEmpty)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Icon(
                                    selected ? Icons.check_circle : Icons.radio_button_unchecked,
                                    color: selected ? SibValColors.goldAccent : Colors.white,
                                    shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
                                  ),
                                ),
                            ],
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
    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 82,
    );
    if (picked.isEmpty) return;

    final uid = ref.read(currentUidProvider) ?? '';
    final profile = ref.read(currentUserProfileProvider).asData?.value;
    final repo = ref.read(galleryRepositoryProvider);
    final total = picked.length;
    var done = 0;
    var failures = 0;

    if (!context.mounted) return;
    late StateSetter dialogSetState;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          dialogSetState = setState;
          return AlertDialog(
            content: Row(
              children: [
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 16),
                Expanded(child: Text('Enviando foto $done de $total...')),
              ],
            ),
          );
        },
      ),
    );

    // Indexado (não uma lista que cada upload dá `.add`) pra preservar a
    // ordem de seleção do usuário mesmo rodando em paralelo — é dela que
    // tiramos a foto que vira capa (a última da seleção), não a que
    // terminar de subir por último.
    final uploaded = List<GalleryImage?>.filled(picked.length, null);
    await Future.wait(picked.indexed.map((entry) async {
      final (index, xfile) = entry;
      try {
        uploaded[index] = await repo.uploadImage(
          file: File(xfile.path),
          albumId: widget.albumId,
          uploaderUid: uid,
          uploaderName: profile?.name ?? '',
        );
      } catch (_) {
        failures++;
      } finally {
        done++;
        dialogSetState(() {});
      }
    }));

    final lastUploaded = uploaded.lastWhere((image) => image != null, orElse: () => null);
    if (lastUploaded != null) {
      await repo.setAlbumCover(widget.albumId, lastUploaded.downloadUrl);
    }

    ref.invalidate(albumImagesProvider(widget.albumId));
    ref.invalidate(albumsProvider);

    if (context.mounted) {
      Navigator.of(context).pop();
      if (failures > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$failures de $total fotos falharam ao subir.')),
        );
      }
    }
  }

  Future<void> _confirmAndDeleteSelected(BuildContext context, WidgetRef ref) async {
    final images = ref.read(albumImagesProvider(widget.albumId)).asData?.value ?? const <GalleryImage>[];
    final toDelete = images.where((image) => _selected.contains(image.id)).toList();
    final count = toDelete.length;
    if (count == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir fotos?'),
        content: Text(
          count == 1
              ? 'Tem certeza que deseja excluir a foto selecionada?'
              : 'Tem certeza que deseja excluir as $count fotos selecionadas?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmed != true) return;

    final repo = ref.read(galleryRepositoryProvider);
    // Sequencial (não Future.wait) de propósito: deleteImage recalcula a
    // capa do álbum a cada chamada — rodar em paralelo reintroduziria a
    // mesma corrida de capa que _upload evita ao subir várias fotos juntas.
    for (final image in toDelete) {
      await repo.deleteImage(image);
    }

    ref.invalidate(albumImagesProvider(widget.albumId));
    ref.invalidate(albumsProvider);
    if (mounted) setState(_selected.clear);
  }
}
