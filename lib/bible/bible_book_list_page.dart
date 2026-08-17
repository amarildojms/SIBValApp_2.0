import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bible_repository.dart';
import '../models/bible.dart';
import 'bible_chapter_picker_page.dart';

/// Espelha BibleBookListFragment.kt: lista de livros dividida em Antigo e
/// Novo Testamento (a divisão vem do `testament_reference_id` do Gênesis,
/// não existe uma tabela de testamentos separada no banco OpenLP).
class BibleBookListPage extends ConsumerWidget {
  const BibleBookListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(bibleBooksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bíblia')),
      body: booksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Falha ao carregar: $error', style: const TextStyle(color: Colors.white))),
        data: (books) {
          if (books.isEmpty) {
            return const Center(child: Text('Livros não encontrados.', style: TextStyle(color: Colors.white70)));
          }
          final oldTestamentId = books.firstWhere((b) => b.id == BibleRepository.firstBookId).testamentId;
          final oldTestament = books.where((b) => b.testamentId == oldTestamentId).toList();
          final newTestament = books.where((b) => b.testamentId != oldTestamentId).toList();

          return ListView(
            children: [
              const _SectionHeader('Antigo Testamento'),
              for (final book in oldTestament) _BookTile(book: book),
              const _SectionHeader('Novo Testamento'),
              for (final book in newTestament) _BookTile(book: book),
            ],
          );
        },
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
      title: Text(book.name, style: const TextStyle(color: Colors.white)),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BibleChapterPickerPage(bookId: book.id, bookName: book.name)),
      ),
    );
  }
}
