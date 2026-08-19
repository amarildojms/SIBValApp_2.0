import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bible_favorites_repository.dart';
import '../data/bible_repository.dart';
import '../models/bible.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'bible_reader_page.dart';

/// Espelha BibleFavoritesFragment.kt: lista dos versículos favoritados.
class BibleFavoritesPage extends ConsumerStatefulWidget {
  const BibleFavoritesPage({super.key});

  @override
  ConsumerState<BibleFavoritesPage> createState() => _BibleFavoritesPageState();
}

class _BibleFavoritesPageState extends ConsumerState<BibleFavoritesPage> {
  List<BibleVerseRef>? _favorites;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final favoritesRepo = ref.read(bibleFavoritesRepositoryProvider);
    final keys = await favoritesRepo.getAll();
    final refs = keys.map(favoritesRepo.parseKey).toList();
    final resolved = await ref.read(bibleRepositoryProvider).resolveRefs(refs);
    if (!mounted) return;
    setState(() => _favorites = resolved);
  }

  Future<void> _unfavorite(BibleVerseRef ref_) async {
    await ref.read(bibleFavoritesRepositoryProvider).toggle(ref_.bookId, ref_.chapter, ref_.verse);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Versículos favoritos'),
            Expanded(
              child: _favorites == null
                  ? const Center(child: CircularProgressIndicator())
                  : _favorites!.isEmpty
                      ? Center(
                          child: Text('Nenhum versículo favoritado ainda.',
                              style: TextStyle(color: context.textSecondary)),
                        )
                      : ListView.builder(
                          itemCount: _favorites!.length,
                          itemBuilder: (context, index) {
                            final favorite = _favorites![index];
                            return ListTile(
                              title: Text(favorite.reference,
                                  style:
                                      TextStyle(color: SibValColors.goldAccent, fontWeight: FontWeight.bold)),
                              subtitle: Text(favorite.text, style: TextStyle(color: context.textPrimary)),
                              trailing: IconButton(
                                icon: const Icon(Icons.star, color: SibValColors.goldAccent),
                                onPressed: () => _unfavorite(favorite),
                              ),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => BibleReaderPage(
                                    bookId: favorite.bookId,
                                    bookName: favorite.bookName,
                                    chapter: favorite.chapter,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
