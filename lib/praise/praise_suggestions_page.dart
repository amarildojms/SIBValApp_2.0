import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/praise_repertoire_repository.dart';
import '../models/praise_repertoire.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

/// Sem equivalente no app nativo — feature nova (02/09/2026, pedido do
/// usuário). Botão "Sugestões" dentro do cadastro de repertório semanal
/// (`WeeklyRepertoireFormPage`) abre esta tela: o dirigente/Louvor digita um
/// "tema" e o app busca em todo `praiseSongs` (`praiseSongsProvider`, já
/// carregado em tempo real) músicas que combinem com o tema.
///
/// **Como o "tema" casa com uma música** (revisado na sessão seguinte,
/// pedido do usuário): a busca de texto (`_normalizeText`, case/acento-
/// insensível, mesmo helper duplicado de outras telas desta base) agora vai
/// contra **nome e letra** (`PraiseSong.lyrics`), não mais cantor/banda ou o
/// rótulo da classificação — classificação e solista viraram filtros
/// próprios (dropdowns "Todas"/"Todos" por padrão) que, quando selecionados,
/// **restringem** o resultado da busca por tema (AND, não OR). Os filtros
/// também funcionam sozinhos, sem tema digitado, pra navegar o catálogo por
/// classificação/solista.
///
/// Cada resultado mostra nome, cantor/banda, classificação, solista(s) e mês
/// referência, com um botão "+" que adiciona a música ao repertório sendo
/// montado (via [onAdd], chamado pra cada música sem fechar a tela — o
/// pedido foi "uma opção de adicionar cada música", permitindo adicionar
/// várias antes de voltar).
class PraiseSuggestionsPage extends ConsumerStatefulWidget {
  const PraiseSuggestionsPage({super.key, required this.onAdd});

  final void Function(PraiseSong song) onAdd;

  @override
  ConsumerState<PraiseSuggestionsPage> createState() => _PraiseSuggestionsPageState();
}

class _PraiseSuggestionsPageState extends ConsumerState<PraiseSuggestionsPage> {
  final _themeController = TextEditingController();
  String _query = '';
  PraiseSongClassification? _filterClassification;
  String? _filterSoloist;
  final Set<String> _added = {};

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(praiseSongsProvider);
    final songs = songsAsync.asData?.value ?? const [];
    final soloistOptions = songs.expand((s) => s.soloists).toSet().toList()..sort();
    final query = _normalizeText(_query);
    final hasCriteria =
        query.isNotEmpty || _filterClassification != null || _filterSoloist != null;
    final results = !hasCriteria
        ? const <PraiseSong>[]
        : songs.where((s) {
            if (_filterClassification != null &&
                !s.classifications.contains(_filterClassification)) {
              return false;
            }
            if (_filterSoloist != null && !s.soloists.contains(_filterSoloist)) {
              return false;
            }
            if (query.isNotEmpty) {
              final haystack = _normalizeText('${s.name} ${s.lyrics}');
              if (!_matchesAllWords(haystack, query)) return false;
            }
            return true;
          }).toList();

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Sugestões por Tema'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _themeController,
                          autofocus: true,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Tema',
                            hintText: 'Ex.: adoração, natal, batismo...',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onSubmitted: (value) => setState(() => _query = value),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => setState(() => _query = _themeController.text),
                        child: const Text('Buscar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<PraiseSongClassification>(
                          initialValue: _filterClassification,
                          isExpanded: true,
                          dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          decoration: const InputDecoration(
                            labelText: 'Classificação',
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Todas')),
                            for (final c in PraiseSongClassification.values)
                              DropdownMenuItem(value: c, child: Text(c.label)),
                          ],
                          onChanged: (value) => setState(() => _filterClassification = value),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _filterSoloist,
                          isExpanded: true,
                          dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          decoration: const InputDecoration(labelText: 'Solista', isDense: true),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Todos')),
                            for (final s in soloistOptions)
                              DropdownMenuItem(value: s, child: Text(s)),
                          ],
                          onChanged: (value) => setState(() => _filterSoloist = value),
                        ),
                      ),
                      if (_filterClassification != null || _filterSoloist != null)
                        IconButton(
                          icon: const Icon(Icons.filter_alt_off_outlined),
                          tooltip: 'Limpar filtros',
                          onPressed: () => setState(() {
                            _filterClassification = null;
                            _filterSoloist = null;
                          }),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: !hasCriteria
                  ? Center(
                      child: Text(
                        'Digite um tema ou selecione um filtro e toque em Buscar.',
                        style: TextStyle(color: context.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : results.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhuma música encontrada para esse tema/filtro.',
                        style: TextStyle(color: context.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final song = results[index];
                        final added = _added.contains(song.id);
                        final subtitleParts = [
                          if (song.artist.isNotEmpty) song.artist,
                          song.classificationsLabel,
                          if (song.soloists.isNotEmpty)
                            'Solista(s): ${song.soloists.join(', ')}',
                          song.referenceMonthLabel,
                        ];
                        return ListTile(
                          title: Text(
                            song.name,
                            style: TextStyle(color: context.textPrimary),
                          ),
                          subtitle: Text(
                            subtitleParts.join(' · '),
                            style: TextStyle(color: context.textSecondary),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              added ? Icons.check_circle : Icons.add_circle_outline,
                              color: added ? Colors.green : SibValColors.goldAccent,
                            ),
                            tooltip: added ? 'Adicionada' : 'Adicionar ao repertório',
                            onPressed: () {
                              widget.onAdd(song);
                              setState(() => _added.add(song.id));
                            },
                          ),
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

/// Mesma lógica de `_matchesAllWords` em `praise_ministry_page.dart`: mais
/// de uma palavra no Tema (ex.: "bondade deus") precisa achar "Bondade de
/// Deus" mesmo sem bater a frase exata — cada palavra precisa aparecer em
/// [normalizedHaystack], em qualquer ordem/posição.
bool _matchesAllWords(String normalizedHaystack, String normalizedQuery) {
  final words = normalizedQuery.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  return words.every(normalizedHaystack.contains);
}
