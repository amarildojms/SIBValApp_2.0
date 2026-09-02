import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/praise_repertoire_repository.dart';
import '../data/user_repository.dart';
import '../models/praise_repertoire.dart';
import '../theme/app_theme.dart';
import '../widgets/date_field.dart';
import '../widgets/sibval_app_bar.dart';
import 'cifra_list_page.dart';
import 'ensaios_list_page.dart';
import 'praise_commitment_page.dart';
import 'praise_lyrics_page.dart';
import 'weekly_repertoire_form_page.dart';

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário). Ministério de Louvor: duas abas —
/// "Repertório Mensal" (catálogo mestre de músicas, `praiseSongs`) e
/// "Repertório Semanal" (escala de músicas por semana, com tom e momento —
/// `weeklyRepertoires`, `weekly_repertoire_form_page.dart`). O repertório
/// semanal alimenta automaticamente os momentos "Louvor" da Ordem de Culto
/// daquela semana (`ServiceOrderLivePage`, ver
/// `PraiseRepertoireRepository.getForDate`/`praiseSlotLabelFor`).
///
/// Menu (☰) ao lado do título (28/08/2026, pedido do usuário — "Cifras" saiu
/// de um tile próprio no menu Mais e entrou aqui, primeira opção de um menu
/// pensado pra crescer).
///
/// Acesso é só de quem tem o papel Louvor/admin (`canViewPraiseOrder`) —
/// **não** de Dirigentes (pedido explícito do usuário, revisão de
/// 28/08/2026: "Dirigente não deve ter acesso a nada em Ministério de
/// Louvor" / "Acesso a Ministério de Louvor deve ser a quem tem papel
/// Louvor" — antes `canManageServiceOrders`, o mesmo que gerencia Ordem de
/// Culto, também dava acesso aqui). Quem o admin selecionou individualmente
/// como editor de cifra (`canEditCifrasProvider` — não é um papel) também
/// entra, mas só pra ver o menu — as duas abas de gerenciar repertório
/// (`canManage`) continuam exclusivas de Louvor/admin.
class PraiseMinistryPage extends ConsumerWidget {
  const PraiseMinistryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final canManage = profile?.canViewPraiseOrder ?? false;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
                    const Expanded(
                      child: Text(
                        'Ministério de Louvor',
                        style: TextStyle(
                          color: SibValColors.goldAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 19,
                        ),
                      ),
                    ),
                    const _PraiseMenuButton(),
                  ],
                ),
              ),
              if (canManage) ...[
                const TabBar(
                  labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  tabs: [
                    Tab(text: 'Repertório Mensal'),
                    Tab(text: 'Repertório Semanal'),
                  ],
                ),
                const Expanded(
                  child: TabBarView(
                    children: [_MonthlyRepertoireTab(), _WeeklyRepertoireTab()],
                  ),
                ),
              ] else
                Expanded(
                  child: Center(
                    child: Text(
                      'Use o menu ☰ acima para acessar as opções disponíveis.',
                      style: TextStyle(color: context.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Menu (3 barras) com as opções do Ministério de Louvor — "Cifras"
/// (28/08/2026: "Ensaios" removido a pedido do usuário — o mesmo ensaio de
/// uma semana agora abre direto ao tocar nela em "Repertório Semanal", ver
/// `_WeeklyRepertoireTab`, sem precisar de uma entrada própria no menu) e
/// "Termo de Compromisso" (02/09/2026, pedido do usuário — quem já aceitou
/// precisa poder reler o termo depois; abre `PraiseCommitmentTermPage` em
/// `readOnly: true`, sem checkboxes/botão de aceite).
class _PraiseMenuButton extends StatelessWidget {
  const _PraiseMenuButton();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.menu, color: context.textPrimary),
      onSelected: (value) {
        if (value == 'cifras') {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CifraListPage()),
          );
        } else if (value == 'termo') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const PraiseCommitmentTermPage(readOnly: true),
            ),
          );
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'cifras',
          // Mesmo ícone do tile solto que existia antes (28/08/2026, pedido
          // do usuário: "mantenha com o ícone que tinha antes").
          child: Row(
            children: [
              Icon(Icons.lyrics_outlined, size: 20),
              SizedBox(width: 12),
              Text('Cifras'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'termo',
          child: Row(
            children: [
              Icon(Icons.fact_check_outlined, size: 20),
              SizedBox(width: 12),
              Text('Termo de Compromisso'),
            ],
          ),
        ),
      ],
    );
  }
}

/// Aba "Repertório Mensal" — catálogo mestre de músicas (nome + cantor/banda),
/// de onde o repertório semanal escala. "Mensal" é só o nome da aba, não
/// particiona por mês — ver doc comment de `PraiseSong`.
///
/// Filtro (02/09/2026, pedido do usuário — corrigido nesta rodada: mora
/// aqui, no Repertório Mensal, não no Semanal) por classificação, solista e
/// um campo de texto que busca em nome **e letra** (`PraiseSong.lyrics`) da
/// música.
class _MonthlyRepertoireTab extends ConsumerStatefulWidget {
  const _MonthlyRepertoireTab();

  @override
  ConsumerState<_MonthlyRepertoireTab> createState() => _MonthlyRepertoireTabState();
}

class _MonthlyRepertoireTabState extends ConsumerState<_MonthlyRepertoireTab> {
  PraiseSongClassification? _filterClassification;
  String? _filterSoloist;
  String _filterQuery = '';

  bool get _hasFilter =>
      _filterClassification != null || _filterSoloist != null || _filterQuery.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(praiseSongsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'praise_song_fab',
        onPressed: () => _showSongDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: songsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary)),
        ),
        data: (allSongs) {
          if (allSongs.isEmpty) {
            return Center(
              child: Text(
                'Nenhuma música cadastrada ainda.',
                style: TextStyle(color: context.textSecondary),
              ),
            );
          }
          final soloistOptions = allSongs.expand((s) => s.soloists).toSet().toList()..sort();
          final query = _normalizePraiseText(_filterQuery);
          final songs = allSongs.where((song) {
            if (_filterClassification != null && song.classification != _filterClassification) {
              return false;
            }
            if (_filterSoloist != null && !song.soloists.contains(_filterSoloist)) {
              return false;
            }
            if (query.isNotEmpty) {
              final haystack = _normalizePraiseText('${song.name} ${song.lyrics}');
              if (!haystack.contains(query)) return false;
            }
            return true;
          }).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Column(
                  children: [
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
                            decoration: const InputDecoration(
                              labelText: 'Solista',
                              isDense: true,
                            ),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('Todos')),
                              for (final s in soloistOptions)
                                DropdownMenuItem(value: s, child: Text(s)),
                            ],
                            onChanged: (value) => setState(() => _filterSoloist = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Buscar por nome ou letra',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (value) => setState(() => _filterQuery = value),
                          ),
                        ),
                        if (_hasFilter)
                          IconButton(
                            icon: const Icon(Icons.filter_alt_off_outlined),
                            tooltip: 'Limpar filtro',
                            onPressed: () => setState(() {
                              _filterClassification = null;
                              _filterSoloist = null;
                              _filterQuery = '';
                            }),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildSongList(context, ref, songs)),
            ],
          );
        },
      ),
    );
  }

  /// Organiza [songs] (já filtradas) em pastas por mês referência
  /// (03/09/2026, pedido do usuário: "o repositório mensal continua sem
  /// organizar as músicas por mês") — mesmo critério/ordem já usado no
  /// picker de `WeeklyRepertoireFormPage` e em `EnsaioDetailPage` (mais
  /// recente primeiro, "Sem mês definido" sempre por último). Só uma pasta
  /// (ex.: filtro reduziu tudo a um mês só) cai de volta pra lista simples,
  /// sem `ExpansionTile` supérfluo.
  Widget _buildSongList(BuildContext context, WidgetRef ref, List<PraiseSong> songs) {
    if (songs.isEmpty) {
      return Center(
        child: Text(
          'Nenhuma música para o filtro selecionado.',
          style: TextStyle(color: context.textSecondary),
        ),
      );
    }
    final groups = <String?, List<PraiseSong>>{};
    for (final song in songs) {
      groups.putIfAbsent(song.referenceMonthKey, () => []).add(song);
    }
    final groupKeys = groups.keys.toList()
      ..sort((a, b) {
        if (a == null && b == null) return 0;
        if (a == null) return 1;
        if (b == null) return -1;
        return b.compareTo(a);
      });

    Widget tileFor(PraiseSong song) => _SongTile(
      song: song,
      onEdit: () => _showSongDialog(context, ref, song: song),
      onDelete: () => _confirmDelete(context, ref, song),
    );

    if (groupKeys.length <= 1) {
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: songs.length,
        itemBuilder: (context, index) => tileFor(songs[index]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: groupKeys.length,
      itemBuilder: (context, index) {
        final key = groupKeys[index];
        final groupSongs = groups[key]!;
        return ExpansionTile(
          leading: const Icon(Icons.folder_outlined),
          title: Text(praiseReferenceMonthLabel(key)),
          subtitle: Text('${groupSongs.length} música(s)'),
          // Fechadas por padrão (03/09/2026, pedido do usuário).
          initiallyExpanded: false,
          children: [for (final song in groupSongs) tileFor(song)],
        );
      },
    );
  }

  void _showSongDialog(BuildContext context, WidgetRef ref, {PraiseSong? song}) {
    final nameController = TextEditingController(text: song?.name ?? '');
    final artistController = TextEditingController(text: song?.artist ?? '');
    var classification = song?.classification ?? PraiseSongClassification.avulso;
    final soloistControllers = (song?.soloists.isEmpty ?? true)
        ? [TextEditingController()]
        : song!.soloists.map((s) => TextEditingController(text: s)).toList();
    final lyricsController = TextEditingController(text: song?.lyrics ?? '');
    // Mês referência — mês/ano (02/09/2026, pedido do usuário). Sem seletor
    // de dia: só interessa em que mês a música entrou/foi usada.
    final now = DateTime.now();
    int? refMonth;
    int? refYear;
    if (song?.referenceMonthKey != null) {
      final parts = song!.referenceMonthKey!.split('-');
      if (parts.length == 2) {
        refYear = int.tryParse(parts[0]);
        refMonth = int.tryParse(parts[1]);
      }
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(song == null ? 'Adicionar música' : 'Editar música'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Nome da música'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: artistController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Cantor/Banda'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<PraiseSongClassification>(
                    initialValue: classification,
                    isExpanded: true,
                    dropdownColor: Theme.of(dialogContext).colorScheme.surfaceContainerHighest,
                    decoration: const InputDecoration(labelText: 'Classificação'),
                    items: [
                      for (final c in PraiseSongClassification.values)
                        DropdownMenuItem(value: c, child: Text(c.label)),
                    ],
                    onChanged: (value) => setDialogState(
                      () => classification = value ?? PraiseSongClassification.avulso,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Solistas',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (var i = 0; i < soloistControllers.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _SoloistField(controller: soloistControllers[i])),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            // Sem `.dispose()` aqui de propósito — o campo
                            // (`_SoloistField`) ainda está montado no
                            // momento deste callback (a remoção da árvore só
                            // acontece depois, quando `setDialogState`
                            // reconstrói); descartar o controller antes
                            // disso causava
                            // "'_dependents.isEmpty': is not true" (bug real
                            // relatado pelo usuário, 03/09/2026) — mesmo
                            // motivo por trás da correção no Salvar/Cancelar
                            // abaixo. Mesmo padrão de não descartar
                            // controller de diálogo ad-hoc já usado em
                            // `nameController`/`artistController`.
                            onPressed: soloistControllers.length > 1
                                ? () =>
                                      setDialogState(() => soloistControllers.removeAt(i))
                                : null,
                          ),
                        ],
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () =>
                          setDialogState(() => soloistControllers.add(TextEditingController())),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Adicionar solista'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mês referência',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<int>(
                          initialValue: refMonth,
                          isExpanded: true,
                          dropdownColor: Theme.of(dialogContext).colorScheme.surfaceContainerHighest,
                          decoration: const InputDecoration(labelText: 'Mês', isDense: true),
                          items: [
                            for (var m = 1; m <= 12; m++)
                              DropdownMenuItem(value: m, child: Text(praiseMonthNames[m - 1])),
                          ],
                          onChanged: (value) => setDialogState(() {
                            refMonth = value;
                            refYear ??= now.year;
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<int>(
                          initialValue: refYear,
                          isExpanded: true,
                          dropdownColor: Theme.of(dialogContext).colorScheme.surfaceContainerHighest,
                          decoration: const InputDecoration(labelText: 'Ano', isDense: true),
                          items: [
                            for (var y = now.year - 2; y <= now.year + 2; y++)
                              DropdownMenuItem(value: y, child: Text('$y')),
                          ],
                          onChanged: (value) => setDialogState(() => refYear = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Letra',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Sem API gratuita de letra completa disponível hoje
                  // (Vagalume descontinuou; Genius/Musixmatch só liberam
                  // trecho/metadados no plano gratuito) — o botão abre uma
                  // busca no navegador pra facilitar achar e copiar a letra
                  // (02/09/2026, pedido do usuário).
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final query = Uri.encodeComponent(
                          'letra ${nameController.text.trim()} ${artistController.text.trim()}'
                              .trim(),
                        );
                        launchUrl(
                          Uri.parse('https://www.google.com/search?q=$query'),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      icon: const Icon(Icons.search, size: 18),
                      label: const Text('Buscar letra'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: lyricsController,
                    maxLines: 8,
                    minLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Cole aqui a letra encontrada na busca',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              // Sem `.dispose()` de `soloistControllers`/`lyricsController`
              // aqui — mesmo motivo do botão "X" acima: o diálogo (e os
              // `_SoloistField`s dentro dele) ainda está montado durante a
              // animação de saída do `Navigator.pop()`, então descartar os
              // controllers aqui derrubava o app com
              // "'_dependents.isEmpty': is not true" (bug real relatado pelo
              // usuário, 03/09/2026). Mesmo padrão de não descartar
              // controller de diálogo ad-hoc já usado em
              // `nameController`/`artistController` neste mesmo diálogo.
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final artist = artistController.text.trim();
                final soloists = soloistControllers
                    .map((c) => c.text.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
                final referenceMonthKey = (refMonth != null && refYear != null)
                    ? '$refYear-${refMonth!.toString().padLeft(2, '0')}'
                    : null;
                final lyrics = lyricsController.text.trim();
                Navigator.of(dialogContext).pop();
                final newSong = PraiseSong(
                  id: song?.id ?? '',
                  name: name,
                  artist: artist,
                  classification: classification,
                  soloists: soloists,
                  referenceMonthKey: referenceMonthKey,
                  lyrics: lyrics,
                );
                final repo = ref.read(praiseRepertoireRepositoryProvider);
                try {
                  if (song == null) {
                    await repo.createSong(newSong);
                  } else {
                    await repo.updateSong(song.id, newSong);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Falha ao salvar: $e')));
                  }
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, PraiseSong song) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir música'),
        content: Text('Tem certeza que deseja excluir "${song.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                await ref.read(praiseRepertoireRepositoryProvider).deleteSong(song.id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Falha ao excluir: $e')));
                }
              }
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}

/// Linha de uma música na aba "Repertório Mensal" (dentro ou fora de uma
/// pasta) — extraída pra ser reaproveitada tanto na lista simples quanto
/// dentro de cada `ExpansionTile` de mês em `_buildSongList`.
class _SongTile extends StatelessWidget {
  const _SongTile({required this.song, required this.onEdit, required this.onDelete});

  final PraiseSong song;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = [
      if (song.artist.isNotEmpty) song.artist,
      song.classification.label,
      if (song.soloists.isNotEmpty) 'Solista(s): ${song.soloists.join(', ')}',
    ];
    return ListTile(
      title: Text(
        song.name,
        style: TextStyle(
          // Dourado quando há letra salva pra tocar e abrir — mesmo padrão
          // de "item clicável em dourado" já usado em outras telas desta
          // base (02/09/2026, pedido do usuário: abrir a letra ao tocar na
          // música).
          color: song.hasLyrics ? SibValColors.goldAccent : context.textPrimary,
        ),
      ),
      subtitle: subtitleParts.isEmpty
          ? null
          : Text(subtitleParts.join(' · '), style: TextStyle(color: context.textSecondary)),
      onTap: song.hasLyrics
          ? () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PraiseLyricsPage(
                  songName: song.name,
                  songArtist: song.artist,
                  lyrics: song.lyrics,
                ),
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Editar', onPressed: onEdit),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Excluir',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// Aba "Repertório Semanal" — lista as semanas já escaladas
/// (`weeklyRepertoires`), mais recente primeiro; "+" cria uma nova (data
/// padrão: próximo domingo sem repertório ainda).
///
/// Toque simples abre direto o ensaio daquela semana (`EnsaioDetailPage`,
/// somente leitura) — antes ia pro formulário de edição. Editar/Excluir/
/// Copiar viraram um menu de toque longo (28/08/2026, pedido do usuário,
/// mesmo padrão de `ServiceOrderListPage._showActions`). "Copiar" duplica
/// tudo (músicas + links) pedindo só a nova data.
class _WeeklyRepertoireTab extends ConsumerWidget {
  const _WeeklyRepertoireTab();

  static final _dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repertoiresAsync = ref.watch(weeklyRepertoiresProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'weekly_repertoire_fab',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const WeeklyRepertoireFormPage()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nova Semana'),
      ),
      body: repertoiresAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary)),
        ),
        data: (repertoires) {
          if (repertoires.isEmpty) {
            return Center(
              child: Text(
                'Nenhum repertório semanal cadastrado ainda.',
                style: TextStyle(color: context.textSecondary),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: repertoires.length,
            itemBuilder: (context, index) {
              final repertoire = repertoires[index];
              return ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text(
                  _dateFormat.format(repertoire.weekDate),
                  style: TextStyle(color: context.textPrimary),
                ),
                subtitle: Text(
                  '${repertoire.assignments.length} música(s)',
                  style: TextStyle(color: context.textSecondary),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EnsaioDetailPage(repertoire: repertoire),
                  ),
                ),
                onLongPress: () => _showActions(context, ref, repertoire),
              );
            },
          );
        },
      ),
    );
  }

  void _showActions(BuildContext context, WidgetRef ref, WeeklyRepertoire repertoire) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => WeeklyRepertoireFormPage(editing: repertoire),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copiar'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showCopyDialog(context, ref, repertoire);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Excluir'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmDelete(context, ref, repertoire);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, WeeklyRepertoire repertoire) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir repertório'),
        content: Text(
          'Tem certeza que deseja excluir o repertório de ${_dateFormat.format(repertoire.weekDate)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref
                  .read(praiseRepertoireRepositoryProvider)
                  .deleteWeeklyRepertoire(repertoire.id);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  void _showCopyDialog(BuildContext context, WidgetRef ref, WeeklyRepertoire repertoire) {
    DateTime? newDate = repertoire.weekDate.add(const Duration(days: 7));
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Copiar repertório'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cria uma cópia com todas as músicas e links de '
                '${_dateFormat.format(repertoire.weekDate)} na nova data '
                'escolhida.',
              ),
              const SizedBox(height: 16),
              DateField(
                label: 'Nova data',
                value: newDate,
                firstDate: DateTime(DateTime.now().year - 1),
                lastDate: DateTime(DateTime.now().year + 3),
                decoration: const InputDecoration(border: OutlineInputBorder()),
                onChanged: (date) => setDialogState(() => newDate = date),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: newDate == null
                  ? null
                  : () async {
                      Navigator.of(dialogContext).pop();
                      final copy = WeeklyRepertoire(
                        id: '',
                        weekDate: newDate!,
                        assignments: repertoire.assignments,
                        links: repertoire.links,
                      );
                      await ref
                          .read(praiseRepertoireRepositoryProvider)
                          .saveWeeklyRepertoire(copy);
                    },
              child: const Text('Copiar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Campo "Nome do solista" com sugestão entre quem tem o papel Louvor
/// (02/09/2026, pedido do usuário) — mesmo padrão embutido-na-árvore de
/// `_ParticipationField`/`service_order_form_page.dart` (escolhido de
/// propósito no lugar de `Autocomplete`, que já causou um bug de assert
/// nesta base — ver `[[feedback_flutter_migration_style]]`). `FocusNode`
/// próprio (não recebido por fora) porque cada linha de solista é criada e
/// removida dinamicamente — mais simples que o chamador rastrear uma lista
/// paralela de `FocusNode`s.
class _SoloistField extends ConsumerStatefulWidget {
  const _SoloistField({required this.controller});

  final TextEditingController controller;

  @override
  ConsumerState<_SoloistField> createState() => _SoloistFieldState();
}

class _SoloistFieldState extends ConsumerState<_SoloistField> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _focusNode.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focusNode.removeListener(_onChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  List<String> _matches(List<String> names) {
    final query = _normalizePraiseText(widget.controller.text);
    if (query.isEmpty) return const [];
    return names.where((name) => _normalizePraiseText(name).contains(query)).take(8).toList();
  }

  void _select(String name) {
    widget.controller.text = name;
    widget.controller.selection = TextSelection.collapsed(offset: name.length);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final names = ref.watch(louvorMemberNamesProvider).asData?.value ?? const <String>[];
    final matches = _focusNode.hasFocus ? _matches(names) : const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (matches.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            constraints: const BoxConstraints(maxHeight: 160),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: matches.length,
              itemBuilder: (context, index) {
                final name = matches[index];
                return ListTile(
                  dense: true,
                  title: Text(name, style: TextStyle(color: context.textPrimary)),
                  onTap: () => _select(name),
                );
              },
            ),
          ),
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Nome do solista (busca entre quem tem o papel Louvor)',
            isDense: true,
          ),
        ),
      ],
    );
  }
}

const _praiseDiacritics = 'áàãâäéèêëíìîïóòõôöúùûüçñ';
const _praisePlainLetters = 'aaaaaeeeeiiiiooooouuuucn';

/// Case/acento-insensível — mesmo helper duplicado em outras telas desta
/// base (usado pelo filtro por nome/letra do Repertório Mensal).
String _normalizePraiseText(String value) {
  var result = value.toLowerCase().trim();
  for (var i = 0; i < _praiseDiacritics.length; i++) {
    result = result.replaceAll(_praiseDiacritics[i], _praisePlainLetters[i]);
  }
  return result;
}
