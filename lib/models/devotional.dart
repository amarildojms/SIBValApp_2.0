import 'package:cloud_firestore/cloud_firestore.dart';

/// Espelha app/src/main/java/com/sibval/app/data/model/Devotional.kt.
class Devotional {
  final String id;
  final String title;
  final String dateKey;
  final int dateMillis;
  final String text;
  final String author;
  final List<String> readBy;

  /// Texto base (livro/capítulo/versículo, com faixa opcional) — campo sem
  /// equivalente no `Devotional.kt` nativo (26/08/2026, pedido do usuário),
  /// opcional. `null` quando algum dos três não foi selecionado no cadastro.
  /// `baseVerseEnd` (27/08/2026, "de... até...") é o fim da faixa — igual a
  /// `baseVerseStart` pra um versículo só, maior pra uma faixa.
  final int? baseBookId;
  final String baseBookName;
  final int? baseChapter;
  final int? baseVerseStart;
  final int? baseVerseEnd;

  const Devotional({
    required this.id,
    required this.title,
    required this.dateKey,
    required this.dateMillis,
    required this.text,
    required this.author,
    required this.readBy,
    this.baseBookId,
    this.baseBookName = '',
    this.baseChapter,
    this.baseVerseStart,
    this.baseVerseEnd,
  });

  /// "Livro capítulo:versículo" ou "Livro capítulo:início-fim" pronto pra
  /// exibição — `null` se o texto base não foi preenchido.
  String? get baseReference {
    if (baseBookName.isEmpty || baseChapter == null || baseVerseStart == null) return null;
    final end = baseVerseEnd;
    final versePart = (end != null && end != baseVerseStart) ? '$baseVerseStart-$end' : '$baseVerseStart';
    return '$baseBookName $baseChapter:$versePart';
  }

  factory Devotional.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    // `baseVerse` (nome antigo, sem faixa) cai pra `baseVerseStart` — não
    // houve migração de dados, ver `[[feedback_firestore_set_merge_and_log_verification]]`.
    final verseStart = (data['baseVerseStart'] as num?)?.toInt() ?? (data['baseVerse'] as num?)?.toInt();
    return Devotional(
      id: doc.id,
      title: data['title'] as String? ?? '',
      dateKey: data['dateKey'] as String? ?? '',
      dateMillis: (data['dateMillis'] as num?)?.toInt() ?? 0,
      text: data['text'] as String? ?? '',
      author: data['author'] as String? ?? '',
      readBy: List<String>.from(data['readBy'] as List? ?? const []),
      baseBookId: (data['baseBookId'] as num?)?.toInt(),
      baseBookName: data['baseBookName'] as String? ?? '',
      baseChapter: (data['baseChapter'] as num?)?.toInt(),
      baseVerseStart: verseStart,
      baseVerseEnd: (data['baseVerseEnd'] as num?)?.toInt() ?? verseStart,
    );
  }
}
