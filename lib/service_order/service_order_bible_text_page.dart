import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/bible_repository.dart';
import '../models/service_order.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

const _fontSizeKey = 'bible_font_size';
const _defaultFontSize = 16.0;
const _minFontSize = 12.0;
const _maxFontSize = 26.0;
const _fontSizeStep = 2.0;

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário). Ao tocar num texto bíblico dentro do modo apresentação
/// (`ServiceOrderLivePage`), antes abria `BibleReaderPage` (a mesma tela da
/// aba Bíblia — capítulo inteiro, navegação entre capítulos/livros).
/// Pedido do usuário: só o texto selecionado, sem a página inteira — esta
/// tela mostra unicamente os versículos entre `reference.verseStart` e
/// `.verseEnd` do capítulo carregado, sem navegação além de voltar, mas com
/// os mesmos botões de zoom da leitura normal (`_fontSizeKey` compartilha a
/// preferência salva com `BibleReaderPage`, mesmo texto/tamanho entre as
/// duas leituras).
///
/// Zoom dentro do corpo, não na `SibValAppBar` (28/08/2026, correção — a
/// barra superior é fixa/compartilhada em todo o app, só com o logo e
/// login; ali os botões ficavam espremidos ao lado do ícone de login). Igual
/// ao `_ReaderHeader` de `bible_reader_page.dart`: uma faixa fixa dentro do
/// corpo, abaixo da app bar, com o título e os botões +/- lado a lado.
class ServiceOrderBibleTextPage extends ConsumerStatefulWidget {
  const ServiceOrderBibleTextPage({super.key, required this.reference});

  final BibleReference reference;

  @override
  ConsumerState<ServiceOrderBibleTextPage> createState() =>
      _ServiceOrderBibleTextPageState();
}

class _ServiceOrderBibleTextPageState
    extends ConsumerState<ServiceOrderBibleTextPage> {
  double _fontSize = _defaultFontSize;

  @override
  void initState() {
    super.initState();
    _loadFontSize();
  }

  Future<void> _loadFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _fontSize = prefs.getDouble(_fontSizeKey) ?? _defaultFontSize);
    }
  }

  Future<void> _changeFontSize(double delta) async {
    final newSize = (_fontSize + delta).clamp(_minFontSize, _maxFontSize);
    setState(() => _fontSize = newSize);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, newSize);
  }

  @override
  Widget build(BuildContext context) {
    final reference = widget.reference;
    final versesAsync = ref.watch(
      bibleVersesProvider((bookId: reference.bookId!, chapter: reference.chapter!)),
    );
    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      reference.reference ?? '',
                      style: const TextStyle(
                        color: SibValColors.goldAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _changeFontSize(-_fontSizeStep),
                    icon: const Icon(Icons.text_decrease),
                  ),
                  IconButton(
                    onPressed: () => _changeFontSize(_fontSizeStep),
                    icon: const Icon(Icons.text_increase),
                  ),
                ],
              ),
            ),
            Expanded(
              child: versesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text(
                    'Falha ao carregar: $error',
                    style: TextStyle(color: context.textPrimary),
                  ),
                ),
                data: (verses) {
                  final start = reference.verseStart!;
                  final end = reference.verseEnd ?? start;
                  final filtered = verses
                      .where((v) => v.number >= start && v.number <= end)
                      .toList();
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'Versículo não encontrado.',
                        style: TextStyle(color: context.textSecondary),
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      for (final verse in filtered)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '${verse.number} ',
                                  style: TextStyle(
                                    color: SibValColors.goldAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: _fontSize * 0.75,
                                  ),
                                ),
                                TextSpan(
                                  text: verse.text,
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: _fontSize,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
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
