import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/bible_repository.dart';
import '../models/bible.dart';
import '../theme/app_theme.dart';

const _fontSizeKey = 'bible_font_size';
const _defaultFontSize = 16.0;
const _minFontSize = 12.0;
const _maxFontSize = 26.0;
const _fontSizeStep = 2.0;

/// Espelha BibleReaderFragment.kt/BibleReaderViewModel.kt: número do versículo
/// em sobrescrito/dourado, navegação Anterior/Próximo cruzando limites de
/// livro, fonte ajustável e persistida. Favoritos/busca ficam para depois.
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

  @override
  void initState() {
    super.initState();
    _bookId = widget.bookId;
    _bookName = widget.bookName;
    _chapter = widget.chapter;
    _loadFontSize();
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

  Future<void> _changeFontSize(double delta) async {
    final newSize = (_fontSize + delta).clamp(_minFontSize, _maxFontSize);
    setState(() => _fontSize = newSize);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, newSize);
  }

  Future<void> _goToPrevious() async {
    if (_chapter > 1) {
      setState(() => _chapter -= 1);
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
    }
  }

  Future<void> _goToNext(int currentChapterCount) async {
    if (_chapter < currentChapterCount) {
      setState(() => _chapter += 1);
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
      appBar: AppBar(
        title: Text('$_bookName $_chapter'),
        actions: [
          IconButton(onPressed: () => _changeFontSize(-_fontSizeStep), icon: const Icon(Icons.text_decrease)),
          IconButton(onPressed: () => _changeFontSize(_fontSizeStep), icon: const Icon(Icons.text_increase)),
        ],
      ),
      body: _loadingFontSize
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: versesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, _) =>
                        Center(child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary))),
                    data: (verses) => SingleChildScrollView(
                      key: ValueKey('$_bookId-$_chapter'),
                      padding: const EdgeInsets.all(20),
                      child: _VersesText(verses: verses, fontSize: _fontSize),
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
    );
  }
}

class _VersesText extends StatelessWidget {
  const _VersesText({required this.verses, required this.fontSize});

  final List<BibleVerse> verses;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          for (final verse in verses) ...[
            TextSpan(
              text: '${verse.number} ',
              style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: fontSize * 0.65),
            ),
            TextSpan(text: '${verse.text} ', style: TextStyle(color: context.textPrimary, fontSize: fontSize, height: 1.5)),
          ],
        ],
      ),
    );
  }
}
