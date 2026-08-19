import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bible.dart';
import 'bible_database.dart';

/// Espelha app/src/main/java/com/sibval/app/data/repository/BibleRepository.kt —
/// mesmas queries, mesmo banco (schema OpenLP: tabelas `book`/`verse`).
class BibleRepository {
  const BibleRepository();

  Future<List<BibleBook>> getBooks() async {
    final db = await BibleDatabase.instance();
    final rows = await db.rawQuery('SELECT id, testament_reference_id, name FROM book ORDER BY id');
    return rows
        .map((row) => BibleBook(
              id: row['id'] as int,
              testamentId: row['testament_reference_id'] as int,
              name: row['name'] as String,
            ))
        .toList();
  }

  Future<int> getChapterCount(int bookId) async {
    final db = await BibleDatabase.instance();
    final rows = await db.rawQuery('SELECT MAX(chapter) as maxChapter FROM verse WHERE book_id = ?', [bookId]);
    return (rows.first['maxChapter'] as int?) ?? 1;
  }

  Future<List<BibleVerse>> getVerses(int bookId, int chapter) async {
    final db = await BibleDatabase.instance();
    final rows = await db.rawQuery(
      'SELECT verse, text FROM verse WHERE book_id = ? AND chapter = ? ORDER BY verse',
      [bookId, chapter],
    );
    return rows.map((row) => BibleVerse(number: row['verse'] as int, text: row['text'] as String)).toList();
  }

  /// Busca por trecho do texto em toda a bíblia — espelha
  /// BibleRepository.kt#search (sem escopo de livro atual por ora).
  Future<List<BibleVerseRef>> search(String query) async {
    final db = await BibleDatabase.instance();
    final rows = await db.rawQuery(
      'SELECT book.id as bookId, book.name as bookName, verse.chapter as chapter, verse.verse as verseNumber, '
      'verse.text as text FROM verse JOIN book ON book.id = verse.book_id '
      'WHERE verse.text LIKE ? ORDER BY book.id, verse.chapter, verse.verse LIMIT 200',
      ['%$query%'],
    );
    return rows
        .map((row) => BibleVerseRef(
              bookId: row['bookId'] as int,
              bookName: row['bookName'] as String,
              chapter: row['chapter'] as int,
              verse: row['verseNumber'] as int,
              text: row['text'] as String,
            ))
        .toList();
  }

  /// Resolve as referências favoritadas (guardadas como "bookId:chapter:verse")
  /// pro texto completo do versículo, pra exibir na tela de Favoritos.
  Future<List<BibleVerseRef>> resolveRefs(List<(int bookId, int chapter, int verse)> refs) async {
    if (refs.isEmpty) return [];
    final db = await BibleDatabase.instance();
    final books = {for (final b in await getBooks()) b.id: b.name};
    final result = <BibleVerseRef>[];
    for (final ref in refs) {
      final rows = await db.rawQuery(
        'SELECT text FROM verse WHERE book_id = ? AND chapter = ? AND verse = ?',
        [ref.$1, ref.$2, ref.$3],
      );
      if (rows.isEmpty) continue;
      result.add(BibleVerseRef(
        bookId: ref.$1,
        bookName: books[ref.$1] ?? '',
        chapter: ref.$2,
        verse: ref.$3,
        text: rows.first['text'] as String,
      ));
    }
    return result;
  }

  static const firstBookId = 1;
  static const lastBookId = 66;
}

final bibleRepositoryProvider = Provider<BibleRepository>((ref) => const BibleRepository());

final bibleBooksProvider = FutureProvider.autoDispose<List<BibleBook>>((ref) {
  return ref.watch(bibleRepositoryProvider).getBooks();
});

final bibleChapterCountProvider = FutureProvider.autoDispose.family<int, int>((ref, bookId) {
  return ref.watch(bibleRepositoryProvider).getChapterCount(bookId);
});

typedef BibleReaderKey = ({int bookId, int chapter});

final bibleVersesProvider = FutureProvider.autoDispose.family<List<BibleVerse>, BibleReaderKey>((ref, key) {
  return ref.watch(bibleRepositoryProvider).getVerses(key.bookId, key.chapter);
});
