import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/bible_repository.dart';
import '../data/blivre_repository.dart';
import '../models/bible.dart';
import '../models/service_order.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

const _fontSizeKey = 'bible_font_size';
const _defaultFontSize = 16.0;
const _minFontSize = 12.0;
const _maxFontSize = 26.0;
const _fontSizeStep = 2.0;

/// Texto bíblico resolvido pra um capítulo — de qual fonte veio, pra
/// `ServiceOrderBibleTextPage` decidir o que mostrar na linha de crédito
/// (28/08/2026, pedido do usuário: "buscando de um site específico, e
/// colocando os devidos créditos"). Tenta a BLIVRE primeiro
/// (`BlivreRepository`, online, cacheada em disco após a 1ª busca); se
/// falhar (sem internet e sem cache ainda) ou o capítulo não existir lá por
/// algum motivo, cai pro Almeida 1911 local (`BibleRepository`, sempre
/// disponível, offline).
typedef _ResolvedVerses = ({List<BibleVerse> verses, bool fromBlivre});

/// Público (29/08/2026) — reaproveitado por `ServiceOrderMissionMomentPage`
/// (Divisa do Momento Missionário), que precisa da mesma resolução
/// BLIVRE-com-fallback pra mais de uma referência de uma vez.
final resolvedBibleVersesProvider = FutureProvider.autoDispose
    .family<_ResolvedVerses, BibleReaderKey>((ref, key) async {
      try {
        final blivre = await ref
            .watch(blivreRepositoryProvider)
            .getVerses(key.bookId, key.chapter);
        if (blivre != null && blivre.isNotEmpty) {
          return (verses: blivre, fromBlivre: true);
        }
      } catch (_) {
        // Sem internet, sem cache ainda, ou falha de rede — cai pro Almeida
        // 1911 local abaixo, sem quebrar a leitura.
      }
      final local = await ref
          .watch(bibleRepositoryProvider)
          .getVerses(key.bookId, key.chapter);
      return (verses: local, fromBlivre: false);
    });

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
/// **Fonte do texto** (28/08/2026, pedido do usuário — ver doc comment de
/// `BlivreRepository`): busca primeiro na Bíblia Livre (BLIVRE, online, com
/// crédito exibido abaixo do título); só essa tela usa essa fonte — a aba
/// "Bíblia" principal e o restante da Ordem de Culto (seleção de livro/
/// capítulo/versículo) continuam no Almeida 1911 local, inclusive como
/// fallback aqui se a BLIVRE não responder.
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
      setState(
        () => _fontSize = prefs.getDouble(_fontSizeKey) ?? _defaultFontSize,
      );
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
    final resolvedAsync = ref.watch(
      resolvedBibleVersesProvider((
        bookId: reference.bookId!,
        chapter: reference.chapter!,
      )),
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
            // Crédito da fonte (28/08/2026, pedido do usuário) — só aparece
            // com a BLIVRE; o Almeida 1911 (fallback offline) é domínio
            // público, sem exigência de crédito, mas o rótulo "(offline)"
            // ajuda a entender por que o texto pode ler diferente do
            // normal quando a busca online falha.
            resolvedAsync.maybeWhen(
              data: (resolved) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  resolved.fromBlivre
                      ? 'Fonte: Bíblia Livre (BLIVRE), licença CC BY 4.0'
                      : 'Fonte: Almeida 1911 (offline)',
                  style: TextStyle(color: context.textSecondary, fontSize: 12),
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
            Expanded(
              child: resolvedAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text(
                    'Falha ao carregar: $error',
                    style: TextStyle(color: context.textPrimary),
                  ),
                ),
                data: (resolved) {
                  final verses = resolved.verses;
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
