import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/hymn_favorites_repository.dart';
import '../data/hymnal_repository.dart';
import '../models/hymn.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

const _fontSizeKey = 'hymn_font_size';
const _defaultFontSize = 16.0;
const _minFontSize = 12.0;
const _maxFontSize = 26.0;
const _fontSizeStep = 2.0;

/// Espelha HymnDetailFragment.kt: título (já sem prefixo/número), letra
/// (extraída do XML), fonte ajustável e persistida, e favoritar — tudo fixo
/// numa barra ao lado do título, igual ao app nativo.
class HymnDetailPage extends ConsumerStatefulWidget {
  const HymnDetailPage({super.key, required this.hymnal, required this.songId});

  final Hymnal hymnal;
  final int songId;

  @override
  ConsumerState<HymnDetailPage> createState() => _HymnDetailPageState();
}

class _HymnDetailPageState extends ConsumerState<HymnDetailPage> {
  double _fontSize = _defaultFontSize;
  bool _loadingFontSize = true;
  bool _favorite = false;

  @override
  void initState() {
    super.initState();
    _loadFontSize();
    _loadFavorite();
  }

  Future<void> _loadFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _fontSize = prefs.getDouble(_fontSizeKey) ?? _defaultFontSize;
        _loadingFontSize = false;
      });
    }
  }

  Future<void> _loadFavorite() async {
    final favorite = await ref.read(hymnFavoritesRepositoryProvider).isFavorite(widget.hymnal, widget.songId);
    if (mounted) setState(() => _favorite = favorite);
  }

  Future<void> _toggleFavorite() async {
    await ref.read(hymnFavoritesRepositoryProvider).toggle(widget.hymnal, widget.songId);
    setState(() => _favorite = !_favorite);
  }

  Future<void> _changeFontSize(double delta) async {
    final newSize = (_fontSize + delta).clamp(_minFontSize, _maxFontSize);
    setState(() => _fontSize = newSize);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, newSize);
  }

  @override
  Widget build(BuildContext context) {
    final hymnAsync = ref.watch(hymnDetailProvider((hymnal: widget.hymnal, songId: widget.songId)));

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: _loadingFontSize
          ? const Center(child: CircularProgressIndicator())
          : hymnAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary))),
              data: (hymn) {
                if (hymn == null) {
                  return Center(child: Text('Hino não encontrado.', style: TextStyle(color: context.textSecondary)));
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HymnHeader(
                      title: '${hymn.number} — ${hymn.title}',
                      favorite: _favorite,
                      onFavoriteTap: _toggleFavorite,
                      onDecreaseFont: () => _changeFontSize(-_fontSizeStep),
                      onIncreaseFont: () => _changeFontSize(_fontSizeStep),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Text(hymn.lyrics,
                            style: TextStyle(color: context.textPrimary, fontSize: _fontSize, height: 1.5)),
                      ),
                    ),
                  ],
                );
              },
            ),
        ),
    );
  }
}

class _HymnHeader extends StatelessWidget {
  const _HymnHeader({
    required this.title,
    required this.favorite,
    required this.onFavoriteTap,
    required this.onDecreaseFont,
    required this.onIncreaseFont,
  });

  final String title;
  final bool favorite;
  final VoidCallback onFavoriteTap;
  final VoidCallback onDecreaseFont;
  final VoidCallback onIncreaseFont;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: SibValColors.goldAccent, fontSize: 20, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Favoritar',
            onPressed: onFavoriteTap,
            icon: Icon(favorite ? Icons.star : Icons.star_outline,
                color: favorite ? SibValColors.goldAccent : context.textPrimary),
          ),
          IconButton(onPressed: onDecreaseFont, icon: const Icon(Icons.text_decrease)),
          IconButton(onPressed: onIncreaseFont, icon: const Icon(Icons.text_increase)),
        ],
      ),
    );
  }
}
