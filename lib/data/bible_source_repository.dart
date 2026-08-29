import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bible.dart';
import 'bible_repository.dart';
import 'blivre_repository.dart';

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário: "é possível implementar esta mesma versão para a bíblia
/// completa, mantendo as duas versões, porém a livre como padrão?"). As duas
/// versões que a aba "Bíblia" (e a Ordem de Culto) podem exibir — `blivre`
/// (online, com crédito, ver `BlivreRepository`) é o padrão; `almeida1911`
/// é o banco local de sempre (`bible_database.dart`), sempre disponível
/// offline.
enum BibleVersion { blivre, almeida1911 }

const _versionPrefsKey = 'bible_version';

/// Escolha do usuário, persistida — mesmo padrão de `ThemeModeNotifier`
/// (`theme_preference.dart`): estado síncrono já nasce no valor padrão
/// (`BibleVersion.blivre`, pedido explícito do usuário), e `_load()`
/// sobrescreve de forma assíncrona se havia uma escolha salva.
class BibleVersionNotifier extends Notifier<BibleVersion> {
  @override
  BibleVersion build() {
    _load();
    return BibleVersion.blivre;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = _fromString(prefs.getString(_versionPrefsKey));
  }

  Future<void> set(BibleVersion version) async {
    state = version;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_versionPrefsKey, _toString(version));
  }

  BibleVersion _fromString(String? value) => switch (value) {
    'almeida1911' => BibleVersion.almeida1911,
    _ => BibleVersion.blivre,
  };

  String _toString(BibleVersion version) => switch (version) {
    BibleVersion.blivre => 'blivre',
    BibleVersion.almeida1911 => 'almeida1911',
  };
}

final bibleVersionProvider =
    NotifierProvider<BibleVersionNotifier, BibleVersion>(
      BibleVersionNotifier.new,
    );

/// Um capítulo resolvido — `fromBlivre` diz qual fonte respondeu de verdade
/// (pra exibir o crédito certo), que pode divergir de `BibleVersion`
/// escolhido pelo usuário quando a BLIVRE falha e cai pro Almeida 1911.
typedef ResolvedVerses = ({List<BibleVerse> verses, bool fromBlivre});
typedef ResolvedChapterCount = ({int count, bool fromBlivre});
typedef ResolvedSearch = ({List<BibleVerseRef> results, bool fromBlivre});

/// Combina `BibleRepository` (Almeida 1911, local) e `BlivreRepository`
/// (BLIVRE, online com cache) atrás de uma única API — todo método tenta a
/// BLIVRE primeiro quando `version == BibleVersion.blivre`, e cai pro
/// Almeida 1911 se falhar (sem internet e sem cache ainda) ou não achar o
/// dado. Livro/testamento (`BibleBook`) são sempre lidos do banco local —
/// estruturais, iguais nas duas versões, sem motivo pra depender de rede.
class BibleSourceRepository {
  BibleSourceRepository(this._local, this._blivre);

  final BibleRepository _local;
  final BlivreRepository _blivre;

  Future<ResolvedVerses> getVerses(
    BibleVersion version,
    int bookId,
    int chapter,
  ) async {
    if (version == BibleVersion.blivre) {
      try {
        final verses = await _blivre.getVerses(bookId, chapter);
        if (verses != null && verses.isNotEmpty) {
          return (verses: verses, fromBlivre: true);
        }
      } catch (_) {
        // Sem internet, sem cache ainda, ou falha de rede — cai pro Almeida
        // 1911 abaixo, sem quebrar a leitura.
      }
    }
    final local = await _local.getVerses(bookId, chapter);
    return (verses: local, fromBlivre: false);
  }

  Future<ResolvedChapterCount> getChapterCount(
    BibleVersion version,
    int bookId,
  ) async {
    if (version == BibleVersion.blivre) {
      try {
        final count = await _blivre.getChapterCount(bookId);
        if (count != null) return (count: count, fromBlivre: true);
      } catch (_) {
        // Idem — cai pro Almeida 1911.
      }
    }
    final count = await _local.getChapterCount(bookId);
    return (count: count, fromBlivre: false);
  }

  Future<ResolvedSearch> search(
    BibleVersion version,
    String query, {
    BibleSearchScope scope = const BibleSearchScope.allBible(),
  }) async {
    if (version == BibleVersion.blivre) {
      try {
        final books = await _local.getBooks();
        final results = await _blivre.search(query, scope: scope, books: books);
        return (results: results, fromBlivre: true);
      } catch (_) {
        // Idem — cai pro Almeida 1911.
      }
    }
    final results = await _local.search(query, scope: scope);
    return (results: results, fromBlivre: false);
  }

  Future<ResolvedSearch> resolveRefs(
    BibleVersion version,
    List<(int bookId, int chapter, int verse)> refs,
  ) async {
    if (version == BibleVersion.blivre) {
      try {
        final books = await _local.getBooks();
        final results = await _blivre.resolveRefs(refs, books);
        // Alguma referência não resolvida na BLIVRE (não deveria acontecer,
        // mas por segurança) — completa com o Almeida 1911 em vez de deixar
        // um favorito "sumir" da lista.
        if (results.length == refs.length) {
          return (results: results, fromBlivre: true);
        }
      } catch (_) {
        // Idem — cai pro Almeida 1911.
      }
    }
    final results = await _local.resolveRefs(refs);
    return (results: results, fromBlivre: false);
  }
}

final bibleSourceRepositoryProvider = Provider<BibleSourceRepository>((ref) {
  return BibleSourceRepository(
    ref.watch(bibleRepositoryProvider),
    ref.watch(blivreRepositoryProvider),
  );
});

typedef VersionedChapterKey = ({int bookId, int chapter});

/// Recalcula sozinho quando `bibleVersionProvider` muda — trocar a versão
/// na aba "Bíblia" atualiza a leitura/contagem de capítulos na hora.
final versionedChapterCountProvider =
    FutureProvider.autoDispose.family<ResolvedChapterCount, int>((
      ref,
      bookId,
    ) {
      final version = ref.watch(bibleVersionProvider);
      return ref.watch(bibleSourceRepositoryProvider).getChapterCount(version, bookId);
    });

final versionedVersesProvider =
    FutureProvider.autoDispose.family<ResolvedVerses, VersionedChapterKey>((
      ref,
      key,
    ) {
      final version = ref.watch(bibleVersionProvider);
      return ref
          .watch(bibleSourceRepositoryProvider)
          .getVerses(version, key.bookId, key.chapter);
    });
