import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/hymnal_repository.dart';
import '../models/hymn.dart';
import 'hymn_detail_page.dart';

/// Espelha HymnListFragment.kt: lista de hinos ordenada por número. Busca e
/// favoritos ficam para depois.
class HymnListPage extends ConsumerWidget {
  const HymnListPage({super.key, required this.hymnal});

  final Hymnal hymnal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(hymnSongsProvider(hymnal));

    return Scaffold(
      appBar: AppBar(title: Text(hymnal.displayTitle)),
      body: songsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Falha ao carregar: $error', style: const TextStyle(color: Colors.white))),
        data: (songs) => ListView.builder(
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final hymn = songs[index];
            return ListTile(
              leading: SizedBox(
                width: 40,
                child: Text(hymn.number, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
              ),
              title: Text(hymn.title, style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => HymnDetailPage(hymnal: hymnal, songId: hymn.id)),
              ),
            );
          },
        ),
      ),
    );
  }
}
