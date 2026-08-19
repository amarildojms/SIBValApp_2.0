import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/bible_favorites_repository.dart';
import '../data/bible_repository.dart';
import '../models/bible.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

const _fontSizeKey = 'bible_font_size';
const _defaultFontSize = 16.0;
const _minFontSize = 12.0;
const _maxFontSize = 26.0;
const _fontSizeStep = 2.0;

/// Espelha BibleReaderFragment.kt/BibleReaderViewModel.kt: número do versículo
/// em sobrescrito/dourado, navegação Anterior/Próximo cruzando limites de
/// livro, fonte ajustável e persistida, e favoritar versículo (toque no texto
/// seleciona, toque na estrela do cabeçalho confirma o favorito).
class BibleReaderPage extends ConsumerStatefulWidget {
  const BibleReaderPage({super.key, required this.bookId, required this.bookName, required this.chapter});

  final int bookId;
  final String bookName;
  final int chapter;

  @override
  ConsumerState<BibleReaderPage> createState() => _BibleReaderPageState();
}

class _BibleReaderPageState extends ConsumerState<BibleReaderPage> {
  late int _bookId;
  late String _bookName;
  late int _chapter;
  double _fontSize = _defaultFontSize;
  bool _loadingFontSize = true;
  final _selectedVerses = <int>{};
  var _favoriteVerses = <int>{};

  @override
  void initState() {
    super.initState();
    _bookId = widget.bookId;
    _bookName = widget.bookName;
    _chapter = widget.chapter;
    _loadFontSize();
    _loadFavorites();
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

  Future<void> _loadFavorites() async {
    final all = await ref.read(bibleFavoritesRepositoryProvider).getAll();
    final prefix = '$_bookId:$_chapter:';
    final favorites = all.where((key) => key.startsWith(prefix)).map((key) => int.parse(key.split(':')[2])).toSet();
    if (mounted) {
      setState(() {
        _favoriteVerses = favorites;
        _selectedVerses.clear();
      });
    }
  }

  Future<void> _changeFontSize(double delta) async {
    final newSize = (_fontSize + delta).clamp(_minFontSize, _maxFontSize);
    setState(() => _fontSize = newSize);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, newSize);
  }

  Future<void> _toggleVerseTap(int verseNumber) async {
    if (_favoriteVerses.contains(verseNumber)) {
      await ref.read(bibleFavoritesRepositoryProvider).toggle(_bookId, _chapter, verseNumber);
      setState(() => _favoriteVerses.remove(verseNumber));
      return;
    }
    setState(() {
      if (!_selectedVerses.remove(verseNumber)) _selectedVerses.add(verseNumber);
    });
  }

  Future<void> _commitFavorites() async {
    if (_selectedVerses.isEmpty) return;
    final repository = ref.read(bibleFavoritesRepositoryProvider);
    for (final verseNumber in _selectedVerses) {
      await repository.toggle(_bookId, _chapter, verseNumber);
    }
    setState(() {
      _favoriteVerses.addAll(_selectedVerses);
      _selectedVerses.clear();
    });
  }

  Future<void> _goToPrevious() async {
    if (_chapter > 1) {
      setState(() => _chapter -= 1);
      _loadFavorites();
      return;
    }
    if (_bookId > BibleRepository.firstBookId) {
      final previousBookId = _bookId - 1;
      final count = await ref.read(bibleRepositoryProvider).getChapterCount(previousBookId);
      final books = await ref.read(bibleBooksProvider.future);
      final name = books.firstWhere((b) => b.id == previousBookId).name;
      setState(() {
        _bookId = previousBookId;
        _bookName = name;
        _chapter = count;
      });
      _loadFavorites();
    }
  }

  Future<void> _goToNext(int currentChapterCount) async {
    if (_chapter < currentChapterCount) {
      setState(() => _chapter += 1);
      _loadFavorites();
      return;
    }
    if (_bookId < BibleRepository.lastBookId) {
      final nextBookId = _bookId + 1;
      final books = await ref.read(bibleBooksProvider.future);
      final name = books.firstWhere((b) => b.id == nextBookId).name;
      setState(() {
        _bookId = nextBookId;
        _bookName = name;
        _chapter = 1;
      });
      _loadFavorites();
    }
  }

  @override
  Widget build(BuildContext context) {
    final versesAsync = ref.watch(bibleVersesProvider((bookId: _bookId, chapter: _chapter)));
    final chapterCountAsync = ref.watch(bibleChapterCountProvider(_bookId));
    final chapterCount = chapterCountAsync.asData?.value;

    final hasPrevious = !(_bookId == BibleRepository.firstBookId && _chapter == 1);
    final hasNext = !(_bookId == BibleRepository.lastBookId && chapterCount != null && _chapter == chapterCount);

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: _loadingFontSize
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReaderHeader(
                  title: '$_bookName $_chapter',
                  onFavoriteTap: _commitFavorites,
                  onDecreaseFont: () => _changeFontSize(-_fontSizeStep),
                  onIncreaseFont: () => _changeFontSize(_fontSizeStep),
                ),
                Expanded(
                  child: versesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, _) =>
                        Center(child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary))),
                    data: (verses) => SingleChildScrollView(
                      key: ValueKey('$_bookId-$_chapter'),
                      padding: const EdgeInsets.all(20),
                      child: _VersesText(
                        verses: verses,
                        fontSize: _fontSize,
                        selectedVerses: _selectedVerses,
                        favoriteVerses: _favoriteVerses,
                        onVerseTap: _toggleVerseTap,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton.icon(
                        onPressed: hasPrevious ? _goToPrevious : null,
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('Anterior'),
                      ),
                      OutlinedButton.icon(
                        onPressed: hasNext && chapterCount != null ? () => _goToNext(chapterCount) : null,
                        icon: const Icon(Icons.chevron_right),
                        label: const Text('Próximo'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ),
    );
  }
}

/// Barra fixa com o título (livro/capítulo) e, ao lado, favoritar + zoom —
/// espelha o `readerHeader` do fragment_bible_reader.xml nativo.
class _ReaderHeader extends StatelessWidget {
  const _ReaderHeader({
    required this.title,
    required this.onFavoriteTap,
    required this.onDecreaseFont,
    required this.onIncreaseFont,
  });

  final String title;
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
              style: TextStyle(color: context.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Favoritar selecionados',
            onPressed: onFavoriteTap,
            icon: Icon(Icons.star_outline, color: context.textPrimary),
          ),
          IconButton(onPressed: onDecreaseFont, icon: const Icon(Icons.text_decrease)),
          IconButton(onPressed: onIncreaseFont, icon: const Icon(Icons.text_increase)),
        ],
      ),
    );
  }
}

class _VersesText extends StatefulWidget {
  const _VersesText({
    required this.verses,
    required this.fontSize,
    required this.selectedVerses,
    required this.favoriteVerses,
    required this.onVerseTap,
  });

  final List<BibleVerse> verses;
  final double fontSize;
  final Set<int> selectedVerses;
  final Set<int> favoriteVerses;
  final ValueChanged<int> onVerseTap;

  @override
  State<_VersesText> createState() => _VersesTextState();
}

class _VersesTextState extends State<_VersesText> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    return Text.rich(
      TextSpan(
        children: [
          for (final verse in widget.verses) ...[
            TextSpan(
              text: '${verse.number} ',
              style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: widget.fontSize * 0.65),
              recognizer: _recognizerFor(verse.number),
            ),
            TextSpan(
              text: '${verse.text} ',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: widget.fontSize,
                height: 1.5,
                backgroundColor: widget.favoriteVerses.contains(verse.number)
                    ? SibValColors.goldAccent.withValues(alpha: 0.25)
                    : widget.selectedVerses.contains(verse.number)
                        ? Colors.blue.withValues(alpha: 0.25)
                        : null,
              ),
              recognizer: _recognizerFor(verse.number),
            ),
          ],
        ],
      ),
    );
  }

  TapGestureRecognizer _recognizerFor(int verseNumber) {
    final recognizer = TapGestureRecognizer()..onTap = () => widget.onVerseTap(verseNumber);
    _recognizers.add(recognizer);
    return recognizer;
  }
}
