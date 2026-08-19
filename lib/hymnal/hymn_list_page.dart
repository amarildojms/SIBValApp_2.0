import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/hymn_favorites_repository.dart';
import '../data/hymnal_repository.dart';
import '../models/hymn.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'hymn_detail_page.dart';

/// Espelha HymnListFragment.kt/HymnListViewModel.kt: lista de hinos com busca
/// por número/título, favoritos marcáveis inline e filtro "só favoritos".
class HymnListPage extends ConsumerStatefulWidget {
  const HymnListPage({super.key, required this.hymnal});

  final Hymnal hymnal;

  @override
  ConsumerState<HymnListPage> createState() => _HymnListPageState();
}

class _HymnListPageState extends ConsumerState<HymnListPage> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _favoritesOnly = false;
  Set<String> _favoriteKeys = {};
  List<Hymn>? _searchResults;
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final keys = await ref.read(hymnFavoritesRepositoryProvider).getAll();
    if (mounted) setState(() => _favoriteKeys = keys);
  }

  /// Busca por número, título ou trecho da letra direto no banco (a letra não
  /// vem na lista carregada de início, só no detalhe do hino).
  Future<void> _search(String query) async {
    final trimmed = query.trim();
    setState(() => _query = query);
    if (trimmed.isEmpty) {
      setState(() => _searchResults = null);
      return;
    }
    final token = ++_searchToken;
    final results = await ref.read(hymnalRepositoryProvider(widget.hymnal)).searchSongs(trimmed);
    if (!mounted || token != _searchToken) return;
    setState(() => _searchResults = results);
  }

  Future<void> _toggleFavorite(Hymn hymn) async {
    await ref.read(hymnFavoritesRepositoryProvider).toggle(widget.hymnal, hymn.id);
    _loadFavorites();
  }

  bool _isFavorite(Hymn hymn) => _favoriteKeys.contains('${widget.hymnal.name}:${hymn.id}');

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(hymnSongsProvider(widget.hymnal));

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenTitle(widget.hymnal.displayTitle),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Buscar por número, título ou letra...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _search('');
                        },
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FilterChip(
              label: const Text('Favoritos'),
              avatar: const Icon(Icons.star, size: 18),
              selected: _favoritesOnly,
              onSelected: (value) => setState(() => _favoritesOnly = value),
            ),
          ),
          Expanded(
            child: songsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary))),
              data: (songs) {
                final hasQuery = _query.trim().isNotEmpty;
                if (hasQuery && _searchResults == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                var filtered = hasQuery ? _searchResults! : songs;
                if (_favoritesOnly) {
                  filtered = filtered.where(_isFavorite).toList();
                }
                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      _favoritesOnly ? 'Nenhum hino favoritado ainda.' : 'Nenhum hino encontrado.',
                      style: TextStyle(color: context.textSecondary),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final hymn = filtered[index];
                    final favorite = _isFavorite(hymn);
                    return ListTile(
                      leading: SizedBox(
                        width: 40,
                        child: Text(hymn.number,
                            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(hymn.title, style: TextStyle(color: context.textPrimary)),
                      trailing: IconButton(
                        icon: Icon(favorite ? Icons.star : Icons.star_outline,
                            color: favorite ? SibValColors.goldAccent : context.textSecondary),
                        onPressed: () => _toggleFavorite(hymn),
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => HymnDetailPage(hymnal: widget.hymnal, songId: hymn.id)),
                      ),
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
}
