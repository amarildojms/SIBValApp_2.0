/// Espelha os data classes de app/src/main/java/com/sibval/app/data/model/Bible*.kt.
class BibleBook {
  final int id;
  final int testamentId;
  final String name;

  const BibleBook({required this.id, required this.testamentId, required this.name});
}

class BibleVerse {
  final int number;
  final String text;

  const BibleVerse({required this.number, required this.text});
}

/// Uma referência de versículo (livro + capítulo + número) com o texto —
/// usada tanto na busca quanto na lista de favoritos.
class BibleVerseRef {
  final int bookId;
  final String bookName;
  final int chapter;
  final int verse;
  final String text;

  const BibleVerseRef({
    required this.bookId,
    required this.bookName,
    required this.chapter,
    required this.verse,
    required this.text,
  });

  String get reference => '$bookName $chapter:$verse';
}

/// Espelha BibleSearchScope.kt (sealed class) — aqui como enum + bookId
/// opcional pra evitar a cerimônia de sealed class no Dart.
enum BibleSearchScopeKind { allBible, oldTestament, newTestament, specificBook }

class BibleSearchScope {
  const BibleSearchScope._(this.kind, this.bookId);

  const BibleSearchScope.allBible() : this._(BibleSearchScopeKind.allBible, null);
  const BibleSearchScope.oldTestament() : this._(BibleSearchScopeKind.oldTestament, null);
  const BibleSearchScope.newTestament() : this._(BibleSearchScopeKind.newTestament, null);
  const BibleSearchScope.specificBook(int bookId) : this._(BibleSearchScopeKind.specificBook, bookId);

  final BibleSearchScopeKind kind;
  final int? bookId;
}
