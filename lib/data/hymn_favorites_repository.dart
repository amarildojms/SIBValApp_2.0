import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/hymn.dart';

/// Hinos favoritados pelo usuário — guardado localmente, por aparelho.
/// Espelha util/HymnFavoritesPreference.kt (mesma chave "hymnalName:songId").
class HymnFavoritesRepository {
  static const _prefsKey = 'hymn_favorite_songs';

  String _refKey(Hymnal hymnal, int songId) => '${hymnal.name}:$songId';

  Future<Set<String>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_prefsKey) ?? const []).toSet();
  }

  Future<bool> isFavorite(Hymnal hymnal, int songId) async {
    return (await getAll()).contains(_refKey(hymnal, songId));
  }

  Future<void> toggle(Hymnal hymnal, int songId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(_prefsKey) ?? const []).toSet();
    final key = _refKey(hymnal, songId);
    if (!current.remove(key)) current.add(key);
    await prefs.setStringList(_prefsKey, current.toList());
  }
}

final hymnFavoritesRepositoryProvider = Provider<HymnFavoritesRepository>((ref) => HymnFavoritesRepository());
