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
