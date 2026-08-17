import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bible_repository.dart';
import '../theme/app_theme.dart';
import 'bible_reader_page.dart';

/// Espelha BibleChapterPickerFragment.kt: grade de capítulos (5 por linha).
class BibleChapterPickerPage extends ConsumerWidget {
  const BibleChapterPickerPage({super.key, required this.bookId, required this.bookName});

  final int bookId;
  final String bookName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(bibleChapterCountProvider(bookId));

    return Scaffold(
      appBar: AppBar(title: Text(bookName)),
      body: countAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary))),
        data: (count) => GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: count,
          itemBuilder: (context, index) {
            final chapter = index + 1;
            return _ChapterButton(
              chapter: chapter,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BibleReaderPage(bookId: bookId, bookName: bookName, chapter: chapter),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChapterButton extends StatelessWidget {
  const _ChapterButton({required this.chapter, required this.onTap});

  final int chapter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Center(
          child: Text('$chapter', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
