import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Versículos favoritados pelo usuário — guardado localmente, por aparelho.
/// Espelha util/BibleFavoritesPreference.kt (mesma chave "bookId:chapter:verse").
class BibleFavoritesRepository {
  static const _prefsKey = 'bible_favorite_verses';

  String _refKey(int bookId, int chapter, int verse) => '$bookId:$chapter:$verse';

  (int, int, int) parseKey(String key) {
    final parts = key.split(':');
    return (int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  Future<Set<String>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_prefsKey) ?? const []).toSet();
  }

  Future<bool> isFavorite(int bookId, int chapter, int verse) async {
    return (await getAll()).contains(_refKey(bookId, chapter, verse));
  }

  Future<void> toggle(int bookId, int chapter, int verse) async {
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(_prefsKey) ?? const []).toSet();
    final key = _refKey(bookId, chapter, verse);
    if (!current.remove(key)) current.add(key);
    await prefs.setStringList(_prefsKey, current.toList());
  }
}

final bibleFavoritesRepositoryProvider = Provider<BibleFavoritesRepository>((ref) => BibleFavoritesRepository());
