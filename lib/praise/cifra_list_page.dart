import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cifra_repository.dart';
import '../data/praise_repertoire_repository.dart';
import '../data/user_repository.dart';
import '../models/cifra.dart';
import '../models/praise_repertoire.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'cifra_editor_page.dart';
import 'cifra_editors_management_page.dart';
import 'cifra_view_page.dart';

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário). Lista todas as cifras já cadastradas — tanto as linkadas a uma
/// música do repertório mestre (`praiseSongs`) quanto as avulsas (`deve ser
/// possível incluir cifras além do que está no repertório`) — mais os
/// músicas do repertório que ainda não têm cifra, pra dar pra criar uma.
/// Toque abre `CifraViewPage`; "+" (só quem `canEditCifrasProvider`) cria
/// uma cifra nova, avulsa; engrenagem (só admin) abre
/// `CifraEditorsManagementPage`, onde o admin seleciona individualmente quem
/// mais pode editar/incluir cifra (não é um papel).
class CifraListPage extends ConsumerStatefulWidget {
  const CifraListPage({super.key});

  @override
  ConsumerState<CifraListPage> createState() => _CifraListPageState();
}

class _CifraListPageState extends ConsumerState<CifraListPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(praiseSongsProvider);
    final cifrasAsync = ref.watch(cifrasProvider);
    final canEdit = ref.watch(canEditCifrasProvider);
    final isAdmin = ref.watch(currentUserProfileProvider).asData?.value?.isAdmin ?? false;

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              heroTag: 'cifra_new_fab',
              tooltip: 'Nova cifra avulsa',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CifraEditorPage()),
              ),
              child: const Icon(Icons.add),
            )
          : null,
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Cifras',
                      style: TextStyle(
                        color: SibValColors.goldAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                      ),
                    ),
                  ),
                  if (isAdmin)
                    IconButton(
                      tooltip: 'Configurar editores de cifra',
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CifraEditorsManagementPage(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Buscar por nome ou cantor/banda',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: songsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text(
                    'Falha ao carregar: $error',
                    style: TextStyle(color: context.textPrimary),
                  ),
                ),
                data: (songs) {
                  final cifras = cifrasAsync.asData?.value ?? const <Cifra>[];
                  final entries = _buildEntries(songs, cifras);
                  final query = _normalizeText(_query);
                  final filtered = query.isEmpty
                      ? entries
                      : entries
                          .where(
                            (e) =>
                                _normalizeText(e.name).contains(query) ||
                                _normalizeText(e.artist).contains(query),
                          )
                          .toList();
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        entries.isEmpty
                            ? 'Nenhuma cifra cadastrada ainda.'
                            : 'Nenhum resultado pra "$_query".',
                        style: TextStyle(color: context.textSecondary),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final entry = filtered[index];
                      return ListTile(
                        leading: Icon(
                          entry.hasCifra ? Icons.description : Icons.description_outlined,
                          color: entry.hasCifra ? SibValColors.goldAccent : null,
                        ),
                        title: Text(entry.name, style: TextStyle(color: context.textPrimary)),
                        subtitle: entry.artist.isEmpty
                            ? null
                            : Text(entry.artist, style: TextStyle(color: context.textSecondary)),
                        trailing: canEdit
                            ? IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Editar cifra',
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CifraEditorPage(
                                      song: entry.song,
                                      existing: entry.cifra,
                                    ),
                                  ),
                                ),
                              )
                            : null,
                        onTap: entry.hasCifra
                            ? () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CifraViewPage(songId: entry.songId, songName: entry.name),
                                  ),
                                )
                            : (canEdit
                                ? () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        // `existing` também aqui (não só no
                                        // botão de editar) — uma cifra avulsa
                                        // com conteúdo vazio ainda é um
                                        // documento existente (`cifra.id`);
                                        // sem repassar, `CifraEditorPage`
                                        // geraria um id novo e deixaria esse
                                        // documento vazio órfão.
                                        builder: (_) => CifraEditorPage(
                                          song: entry.song,
                                          existing: entry.cifra,
                                        ),
                                      ),
                                    )
                                : null),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Combina o repertório mestre (`praiseSongs`) com as cifras já salvas —
  /// cada música do repertório vira uma entrada (com ou sem cifra ainda);
  /// cifras avulsas (sem `songId` batendo com nenhuma música) viram entradas
  /// próprias.
  List<_CifraEntry> _buildEntries(List<PraiseSong> songs, List<Cifra> cifras) {
    final cifraBySongId = {for (final c in cifras) c.songId: c};
    final songIds = songs.map((s) => s.id).toSet();
    final entries = [
      for (final song in songs)
        _CifraEntry(
          songId: song.id,
          name: song.name,
          artist: song.artist,
          cifra: cifraBySongId[song.id],
          song: song,
        ),
      for (final cifra in cifras)
        if (!songIds.contains(cifra.songId))
          _CifraEntry(
            songId: cifra.songId,
            name: cifra.songName,
            artist: cifra.songArtist,
            cifra: cifra,
            song: null,
          ),
    ];
    entries.sort((a, b) => a.name.compareTo(b.name));
    return entries;
  }
}

class _CifraEntry {
  const _CifraEntry({
    required this.songId,
    required this.name,
    required this.artist,
    required this.cifra,
    required this.song,
  });

  final String songId;
  final String name;
  final String artist;
  final Cifra? cifra;

  /// `null` pra cifra avulsa, sem música correspondente no repertório mestre.
  final PraiseSong? song;

  bool get hasCifra => cifra != null && cifra!.content.trim().isNotEmpty;
}

const _diacritics = 'áàãâäéèêëíìîïóòõôöúùûüçñ';
const _plainLetters = 'aaaaaeeeeiiiiooooouuuucn';

/// Case/acento-insensível — mesmo helper duplicado em outras telas desta
/// base.
String _normalizeText(String value) {
  var result = value.toLowerCase().trim();
  for (var i = 0; i < _diacritics.length; i++) {
    result = result.replaceAll(_diacritics[i], _plainLetters[i]);
  }
  return result;
}
