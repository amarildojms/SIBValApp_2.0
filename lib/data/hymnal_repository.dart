import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xml/xml.dart';

import '../models/hymn.dart';
import 'hymnal_database.dart';

/// Espelha app/src/main/java/com/sibval/app/data/repository/HymnalRepository.kt —
/// mesmas queries, mesmo schema OpenLP "songs" (compartilhado pelos dois
/// hinários, só muda o conteúdo do arquivo .sqlite).
class HymnalRepository {
  const HymnalRepository(this.hymnal);

  final Hymnal hymnal;

  Future<List<Hymn>> getSongs() async {
    final db = await HymnalDatabase.instance(hymnal);
    final rows = await db.rawQuery(
      'SELECT id, song_number, title FROM songs ORDER BY CAST(song_number AS INTEGER)',
    );
    return rows.map((row) => _toHymn(row)).toList();
  }

  /// Busca por número, título ou trecho da letra — mesma ideia de
  /// HymnalRepository.kt#searchSongs, mas direto nas colunas `song_number`/
  /// `title`/`lyrics` (sem depender de colunas de busca pré-computadas).
  Future<List<Hymn>> searchSongs(String query) async {
    final db = await HymnalDatabase.instance(hymnal);
    final like = '%$query%';
    final rows = await db.rawQuery(
      'SELECT id, song_number, title FROM songs '
      'WHERE song_number LIKE ? OR title LIKE ? OR lyrics LIKE ? '
      'ORDER BY CAST(song_number AS INTEGER)',
      [like, like, like],
    );
    return rows.map(_toHymn).toList();
  }

  Future<Hymn?> getSong(int id) async {
    final db = await HymnalDatabase.instance(hymnal);
    final rows = await db.rawQuery(
      'SELECT id, song_number, title, lyrics FROM songs WHERE id = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return Hymn(
      id: row['id'] as int,
      number: row['song_number'] as String? ?? '',
      title: _cleanTitle(row['song_number'] as String? ?? '', row['title'] as String? ?? ''),
      lyrics: _parseLyrics(row['lyrics'] as String? ?? ''),
    );
  }

  Hymn _toHymn(Map<String, Object?> row) {
    final number = row['song_number'] as String? ?? '';
    return Hymn(
      id: row['id'] as int,
      number: number,
      title: _cleanTitle(number, row['title'] as String? ?? ''),
    );
  }

  /// O título bruto no banco vem como "CC 554 Nome Do Hino" — tira o prefixo
  /// "$titlePrefix $number " pra exibir só "Nome Do Hino", igual ao app nativo.
  String _cleanTitle(String number, String rawTitle) {
    final prefix = '${hymnal.titlePrefix} $number ';
    return rawTitle.startsWith(prefix) ? rawTitle.substring(prefix.length) : rawTitle;
  }

  /// A letra vem em XML no formato OpenLP (`song > lyrics > verse`).
  /// Extrai o texto de cada verso e junta com linha em branco entre elas.
  String _parseLyrics(String rawLyrics) {
    if (rawLyrics.isEmpty) return '';
    try {
      final document = XmlDocument.parse(rawLyrics);
      final verses = document.findAllElements('verse');
      return verses.map((v) => v.innerText.trim()).where((t) => t.isNotEmpty).join('\n\n');
    } catch (_) {
      return rawLyrics;
    }
  }
}

final hymnalRepositoryProvider = Provider.family<HymnalRepository, Hymnal>((ref, hymnal) {
  return HymnalRepository(hymnal);
});

final hymnSongsProvider = FutureProvider.autoDispose.family<List<Hymn>, Hymnal>((ref, hymnal) {
  return ref.watch(hymnalRepositoryProvider(hymnal)).getSongs();
});

typedef HymnDetailKey = ({Hymnal hymnal, int songId});

final hymnDetailProvider = FutureProvider.autoDispose.family<Hymn?, HymnDetailKey>((ref, key) {
  return ref.watch(hymnalRepositoryProvider(key.hymnal)).getSong(key.songId);
});
