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
/// **Como o "tema" casa com uma música**: não existe (nem foi pedido) um
/// campo de tags/tema livre por música — o casamento é uma busca de texto
/// (`_normalizeText`, case/acento-insensível, mesmo helper duplicado de
/// outras telas desta base) contra nome, cantor/banda e o rótulo da
/// classificação (`PraiseSongClassification.label` — "Chamada a adoração",
/// "Celebração", "Adoração", "Avulso"). Isso já cobre o caso mais comum na
/// prática (digitar "adoração" e achar as músicas classificadas como tal),
/// mas não é uma busca semântica de verdade.
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
    final query = _normalizeText(_query);
    final results = query.isEmpty
        ? const <PraiseSong>[]
        : songs.where((s) {
            final haystack = _normalizeText(
              '${s.name} ${s.artist} ${s.classification.label}',
            );
            return haystack.contains(query);
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
              child: Row(
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
            ),
            Expanded(
              child: query.isEmpty
                  ? Center(
                      child: Text(
                        'Digite um tema e toque em Buscar.',
                        style: TextStyle(color: context.textSecondary),
                      ),
                    )
                  : results.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhuma música encontrada para esse tema.',
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
                          song.classification.label,
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
