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
