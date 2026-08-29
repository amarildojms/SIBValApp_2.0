import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show getDatabasesPath;

import '../models/bible.dart';

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário). Fonte alternativa de texto bíblico — nasceu só pra Ordem de
/// Culto (`ServiceOrderBibleTextPage`), e ganhou depois (mesma sessão) a aba
/// "Bíblia" inteira (livro/capítulo, busca, favoritos) como **versão
/// padrão**, convivendo lado a lado com o Almeida 1911 local
/// (`bible_database.dart`/`bible_repository.dart`) — usuário escolhe qual
/// ler via `BibleVersion`/`bibleVersionProvider`
/// (`bible_source_repository.dart`), e todo lugar cai pro Almeida 1911 se a
/// BLIVRE falhar (sem internet e sem cache ainda).
///
/// O objetivo aqui é um texto mais legível (português mais atual que o
/// arcaico de 1911) sem depender de licença que a igreja não tem — decisão
/// tomada em conversa com o usuário: **Bíblia Livre (BLIVRE)**, edição
/// Textus Receptus (mesma linhagem textual do Almeida, atualização da
/// tradução de 1819), Bíblia completa (AT+NT), licença **Creative Commons
/// Atribuição 4.0** (permite uso comercial, exige só crédito — a sigla
/// "BLIVRE" já basta, conferido em https://ebible.org/details.php?id=porbr2018).
/// Não é a edição alternativa de texto crítico (Nestle) que também existe no
/// projeto BLIVRE.
///
/// Fonte dos dados: `damarals/biblias` (GitHub) — release **fixada em
/// `v1.0.0`**, não "latest" (evita quebrar em silêncio se o formato mudar
/// numa versão futura; revisar manualmente antes de trocar a tag). Schema
/// conferido baixando o arquivo de verdade antes de implementar: `[{"abbrev":
/// "Gn", "chapters": [["versículo 1", "versículo 2", ...], ...]}, ...]`, 66
/// livros na ordem canônica — mapeada aqui pro mesmo `bookId` 1..66 do
/// schema OpenLP local (`BibleBook.id`), sem precisar de tabela de conversão
/// no banco. `_abbrevs` foi comparado item a item com o `abbrev` real de
/// cada um dos 66 livros do arquivo baixado (não só assumido) — só
/// "Êxodo" difere do que se esperaria (`"Êx"`, com acento, não `"Ex"`);
/// nenhum livro/capítulo veio vazio.
///
/// Arquivo inteiro (~3,8 MB, os 66 livros) baixado **uma vez só** e cacheado
/// em disco (`getDatabasesPath()/blivre.json`, mesmo diretório do
/// `alm1911.sqlite` — reaproveita o diretório já gravável do `sqflite`, sem
/// precisar do pacote `path_provider`) — aberturas seguintes do app não
/// dependem mais de rede pra esse texto. Se a 1ª busca falhar (sem internet
/// e sem cache ainda), quem chama cai pro Almeida 1911 local
/// (`BibleRepository`) — ver `ServiceOrderBibleTextPage`.
class BlivreRepository {
  BlivreRepository();

  static const _sourceUrl =
      'https://github.com/damarals/biblias/releases/download/v1.0.0/BLIVRE.json';

  static const List<String> _abbrevs = [
    'Gn', 'Êx', 'Lv', 'Nm', 'Dt', 'Js', 'Jz', 'Rt', '1Sm', '2Sm',
    '1Rs', '2Rs', '1Cr', '2Cr', 'Ed', 'Ne', 'Et', 'Jó', 'Sl', 'Pv',
    'Ec', 'Ct', 'Is', 'Jr', 'Lm', 'Ez', 'Dn', 'Os', 'Jl', 'Am',
    'Ob', 'Jn', 'Mq', 'Na', 'Hc', 'Sf', 'Ag', 'Zc', 'Ml',
    'Mt', 'Mc', 'Lc', 'Jo', 'At', 'Rm', '1Co', '2Co', 'Gl', 'Ef',
    'Fp', 'Cl', '1Ts', '2Ts', '1Tm', '2Tm', 'Tt', 'Fm', 'Hb', 'Tg',
    '1Pe', '2Pe', '1Jo', '2Jo', '3Jo', 'Jd', 'Ap',
  ];

  Map<String, List<List<String>>>? _cache;

  Future<Map<String, List<List<String>>>> _ensureLoaded() async {
    final cached = _cache;
    if (cached != null) return cached;

    final databasesPath = await getDatabasesPath();
    // Nome do arquivo com sufixo "_v2" (28/08/2026, correção de bug) —
    // versões instaladas antes desta correção já tinham um `blivre.json`
    // cacheado com acentos corrompidos (ver abaixo); trocar o nome garante
    // que ninguém continue lendo o cache antigo quebrado, força um novo
    // download decodificado corretamente.
    final file = File(p.join(databasesPath, 'blivre_v2.json'));

    String raw;
    if (await file.exists()) {
      raw = await file.readAsString(encoding: utf8);
    } else {
      final response = await http
          .get(Uri.parse(_sourceUrl))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw Exception('Falha ao baixar BLIVRE: HTTP ${response.statusCode}');
      }
      // BUG corrigido (28/08/2026, relatado pelo usuário — "vários
      // caracteres especiais nos textos"): `response.body` decodifica pelo
      // charset do cabeçalho `Content-Type`; o GitHub serve este arquivo
      // como `application/octet-stream`, sem charset declarado, então o
      // pacote `http` caía no padrão ISO-8859-1 (Latin-1) — corrompendo
      // todo acento de um arquivo que na verdade é UTF-8. `response.bodyBytes`
      // ignora esse cabeçalho e decodifica os bytes como UTF-8 de propósito.
      raw = utf8.decode(response.bodyBytes);
      await Directory(databasesPath).create(recursive: true);
      await file.writeAsString(raw, encoding: utf8, flush: true);
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    final byAbbrev = <String, List<List<String>>>{};
    for (final entry in decoded) {
      final map = entry as Map<String, dynamic>;
      final abbrev = map['abbrev'] as String;
      final chapters = (map['chapters'] as List<dynamic>)
          .map((c) => (c as List<dynamic>).cast<String>())
          .toList();
      byAbbrev[abbrev] = chapters;
    }
    _cache = byAbbrev;
    return byAbbrev;
  }

  /// Versículos de um capítulo, na BLIVRE — `null` se o `bookId` estiver
  /// fora de 1..66 ou o capítulo não existir nos dados (não deveria
  /// acontecer com um `bookId`/capítulo válidos vindos do banco local, mas
  /// protege contra um índice fora da faixa).
  Future<List<BibleVerse>?> getVerses(int bookId, int chapter) async {
    if (bookId < 1 || bookId > _abbrevs.length) return null;
    final data = await _ensureLoaded();
    final chapters = data[_abbrevs[bookId - 1]];
    if (chapters == null || chapter < 1 || chapter > chapters.length) {
      return null;
    }
    final verses = chapters[chapter - 1];
    return [
      for (var i = 0; i < verses.length; i++)
        BibleVerse(number: i + 1, text: verses[i].trim()),
    ];
  }

  /// Número de capítulos de um livro, na BLIVRE — `null` se o `bookId`
  /// estiver fora de 1..66.
  Future<int?> getChapterCount(int bookId) async {
    if (bookId < 1 || bookId > _abbrevs.length) return null;
    final data = await _ensureLoaded();
    return data[_abbrevs[bookId - 1]]?.length;
  }

  /// Busca em texto livre sobre toda a BLIVRE já cacheada em memória —
  /// varredura simples (`contains`, minúsculas), sem SQL: o dado inteiro já
  /// está em memória depois da 1ª leitura (`_ensureLoaded`), então uma
  /// varredura dos ~31 mil versículos é rápida o bastante num celular. Corta
  /// em 200 resultados, mesmo limite de `BibleRepository.search` (SQL local),
  /// pra manter o mesmo comportamento entre as duas fontes. `books` vem de
  /// fora (`BibleRepository.getBooks()`, sempre local — nome/ordem/testamento
  /// dos livros são estruturais, iguais nas duas versões, não precisam de
  /// fonte online) — evita este repositório depender do outro.
  Future<List<BibleVerseRef>> search(
    String query, {
    BibleSearchScope scope = const BibleSearchScope.allBible(),
    required List<BibleBook> books,
  }) async {
    if (books.isEmpty) return const [];
    final data = await _ensureLoaded();
    final lower = query.toLowerCase();
    // `books` vem de `BibleRepository.getBooks()`, ordenado por id ASC — o
    // primeiro é sempre Gênesis (bookId 1), cujo testamento define "Antigo".
    // Evita importar `bible_repository.dart` só por causa dessa constante.
    final oldTestamentId = books.first.testamentId;
    bool matchesScope(BibleBook book) => switch (scope.kind) {
      BibleSearchScopeKind.allBible => true,
      BibleSearchScopeKind.oldTestament => book.testamentId == oldTestamentId,
      BibleSearchScopeKind.newTestament => book.testamentId != oldTestamentId,
      BibleSearchScopeKind.specificBook => book.id == scope.bookId,
    };

    final results = <BibleVerseRef>[];
    for (final book in books) {
      if (!matchesScope(book)) continue;
      if (book.id < 1 || book.id > _abbrevs.length) continue;
      final chapters = data[_abbrevs[book.id - 1]];
      if (chapters == null) continue;
      for (var c = 0; c < chapters.length; c++) {
        final verses = chapters[c];
        for (var v = 0; v < verses.length; v++) {
          if (verses[v].toLowerCase().contains(lower)) {
            results.add(
              BibleVerseRef(
                bookId: book.id,
                bookName: book.name,
                chapter: c + 1,
                verse: v + 1,
                text: verses[v].trim(),
              ),
            );
            if (results.length >= 200) return results;
          }
        }
      }
    }
    return results;
  }

  /// Resolve referências favoritadas (`bookId:chapter:verse`) pro texto na
  /// BLIVRE — mesmo propósito de `BibleRepository.resolveRefs`, pra
  /// `BibleFavoritesPage` mostrar o texto na versão escolhida pelo usuário.
  /// Uma referência que não existir nos dados (não deveria acontecer, já que
  /// os números de capítulo/versículo vêm da mesma numeração canônica) é
  /// simplesmente pulada, em vez de quebrar a lista inteira.
  Future<List<BibleVerseRef>> resolveRefs(
    List<(int bookId, int chapter, int verse)> refs,
    List<BibleBook> books,
  ) async {
    if (refs.isEmpty) return const [];
    final data = await _ensureLoaded();
    final namesById = {for (final b in books) b.id: b.name};
    final result = <BibleVerseRef>[];
    for (final ref in refs) {
      final (bookId, chapter, verse) = ref;
      if (bookId < 1 || bookId > _abbrevs.length) continue;
      final chapters = data[_abbrevs[bookId - 1]];
      if (chapters == null || chapter < 1 || chapter > chapters.length) {
        continue;
      }
      final verses = chapters[chapter - 1];
      if (verse < 1 || verse > verses.length) continue;
      result.add(
        BibleVerseRef(
          bookId: bookId,
          bookName: namesById[bookId] ?? '',
          chapter: chapter,
          verse: verse,
          text: verses[verse - 1].trim(),
        ),
      );
    }
    return result;
  }
}

final blivreRepositoryProvider = Provider<BlivreRepository>((ref) {
  return BlivreRepository();
});
