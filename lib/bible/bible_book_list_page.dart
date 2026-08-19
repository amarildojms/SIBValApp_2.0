import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bible_repository.dart';
import '../models/bible.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'bible_chapter_picker_page.dart';
import 'bible_favorites_page.dart';
import 'bible_search_page.dart';

/// Espelha BibleBookListFragment.kt: lista de livros dividida em Antigo e
/// Novo Testamento (a divisão vem do `testament_reference_id` do Gênesis,
/// não existe uma tabela de testamentos separada no banco OpenLP).
class BibleBookListPage extends ConsumerWidget {
  const BibleBookListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(bibleBooksProvider);

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Bíblia'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () =>
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BibleSearchPage())),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, color: context.textSecondary),
                            const SizedBox(width: 8),
                            Text('Buscar na Bíblia', style: TextStyle(color: context.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.star_outline),
                    tooltip: 'Favoritos',
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BibleFavoritesPage())),
                  ),
                ],
              ),
            ),
            Expanded(
              child: booksAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    Center(child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary))),
                data: (books) {
                  if (books.isEmpty) {
                    return Center(
                        child: Text('Livros não encontrados.', style: TextStyle(color: context.textSecondary)));
                  }
                  final oldTestamentId = books.firstWhere((b) => b.id == BibleRepository.firstBookId).testamentId;
                  final oldTestament = books.where((b) => b.testamentId == oldTestamentId).toList();
                  final newTestament = books.where((b) => b.testamentId != oldTestamentId).toList();

                  return ListView(
                    children: [
                      const _SectionHeader('Antigo Testamento'),
                      for (final book in oldTestament) _BookTile(book: book),
                      Divider(color: Theme.of(context).colorScheme.outlineVariant, height: 24, thickness: 1),
                      const _SectionHeader('Novo Testamento'),
                      for (final book in newTestament) _BookTile(book: book),
                    ],
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        label,
        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({required this.book});

  final BibleBook book;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(book.name, style: TextStyle(color: context.textPrimary)),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BibleChapterPickerPage(bookId: book.id, bookName: book.name)),
      ),
    );
  }
}
