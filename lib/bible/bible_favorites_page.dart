import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bible_favorites_repository.dart';
import '../data/bible_source_repository.dart';
import '../models/bible.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'bible_reader_page.dart';

/// Espelha BibleFavoritesFragment.kt: lista dos versículos favoritados.
/// Texto exibido vem da versão escolhida em `BibleBookListPage`
/// (`bibleVersionProvider`) — favoritar um versículo guarda só a referência
/// (`bookId:chapter:verse`), então trocar de versão muda o texto mostrado
/// aqui automaticamente, sem precisar refavoritar nada.
class BibleFavoritesPage extends ConsumerStatefulWidget {
  const BibleFavoritesPage({super.key});

  @override
  ConsumerState<BibleFavoritesPage> createState() => _BibleFavoritesPageState();
}

class _BibleFavoritesPageState extends ConsumerState<BibleFavoritesPage> {
  List<BibleVerseRef>? _favorites;
  bool _favoritesFromBlivre = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final favoritesRepo = ref.read(bibleFavoritesRepositoryProvider);
    final keys = await favoritesRepo.getAll();
    final refs = keys.map(favoritesRepo.parseKey).toList();
    final version = ref.read(bibleVersionProvider);
    final resolved = await ref
        .read(bibleSourceRepositoryProvider)
        .resolveRefs(version, refs);
    if (!mounted) return;
    setState(() {
      _favorites = resolved.results;
      _favoritesFromBlivre = resolved.fromBlivre;
    });
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
            // Crédito da fonte (28/08/2026, pedido do usuário) — só aparece
            // quando o texto veio da BLIVRE.
            if (_favorites != null && _favorites!.isNotEmpty && _favoritesFromBlivre)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Fonte: Bíblia Livre (BLIVRE), licença CC BY 4.0',
                  style: TextStyle(color: context.textSecondary, fontSize: 12),
                ),
              ),
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
