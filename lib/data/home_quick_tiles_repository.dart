import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ordem dos ícones de acesso rápido da tela Início (02/09/2026, pedido do
/// usuário: "os ícones da tela inicial, vamos ajustar para que eles sejam
/// configuráveis"). Guarda a ordem de TODOS os ícones elegíveis — os 7 que
/// hoje vivem na grade principal mais os que hoje só vivem dentro de "Mais"
/// — nessa mesma lista; `_QuickAccessGrid` (`home_highlights.dart`) mostra só
/// os 7 primeiros elegíveis pro usuário atual (permissão/login), o resto vira
/// o "pool" arrastável durante a edição (toque e segure num dos 7).
///
/// Persistido local (`shared_preferences`, por aparelho) — não é um dado do
/// usuário no Firestore, é só preferência de layout deste aparelho, sem
/// sincronizar entre dispositivos.
const List<String> defaultHomeQuickTileOrder = [
  'bible',
  'serviceOrder',
  'prayer',
  'ebd',
  'messages',
  'agenda',
  'pgms',
  'mural',
  'gallery',
  'hymnals',
  'partners',
  'settingsManagement',
  'birthdays',
  'introduction',
  'praiseMinistry',
];

const _prefsKey = 'home_quick_tiles_order';

/// Mesmo padrão de `BibleVersionNotifier` (`bible_source_repository.dart`):
/// estado síncrono já nasce no padrão, `_load()` sobrescreve de forma
/// assíncrona se havia uma ordem salva.
class HomeQuickTilesOrderNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    _load();
    return defaultHomeQuickTileOrder;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefsKey);
    if (saved != null && saved.isNotEmpty) state = saved;
  }

  Future<void> setOrder(List<String> ids) async {
    state = ids;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, ids);
  }
}

final homeQuickTilesOrderProvider =
    NotifierProvider<HomeQuickTilesOrderNotifier, List<String>>(
      HomeQuickTilesOrderNotifier.new,
    );
