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
