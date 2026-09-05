import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard;
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
/// aqui, no Repertório Mensal, não no Semanal) por classificação, solista,
/// período (mês/ano do "Mês referência") e um campo de texto que busca em
/// nome **e letra** (`PraiseSong.lyrics`) da música — reorganizado numa
/// rodada seguinte pra um botão "Filtro" que abre essas opções num bottom
/// sheet, em vez de ficar tudo sempre visível na tela.
class _MonthlyRepertoireTab extends ConsumerStatefulWidget {
  const _MonthlyRepertoireTab();

  @override
  ConsumerState<_MonthlyRepertoireTab> createState() => _MonthlyRepertoireTabState();
}

class _MonthlyRepertoireTabState extends ConsumerState<_MonthlyRepertoireTab> {
  PraiseSongClassification? _filterClassification;
  String? _filterSoloist;
  String _filterQuery = '';
  int? _filterMonth;
  int? _filterYear;

  bool get _hasFilter =>
      _filterClassification != null ||
      _filterSoloist != null ||
      _filterQuery.isNotEmpty ||
      (_filterMonth != null && _filterYear != null);

  String get _filterSummary {
    final parts = <String>[
      if (_filterQuery.isNotEmpty) '"$_filterQuery"',
      if (_filterClassification != null) _filterClassification!.label,
      if (_filterSoloist != null) _filterSoloist!,
      if (_filterMonth != null && _filterYear != null)
        '${praiseMonthNames[_filterMonth! - 1]} de $_filterYear',
    ];
    return parts.join(' · ');
  }

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
          final periodKey = (_filterMonth != null && _filterYear != null)
              ? '$_filterYear-${_filterMonth!.toString().padLeft(2, '0')}'
              : null;
          final songs = allSongs.where((song) {
            if (_filterClassification != null &&
                !song.classifications.contains(_filterClassification)) {
              return false;
            }
            if (_filterSoloist != null && !song.soloists.contains(_filterSoloist)) {
              return false;
            }
            if (periodKey != null && song.referenceMonthKey != periodKey) {
              return false;
            }
            if (query.isNotEmpty) {
              final haystack = _normalizePraiseText('${song.name} ${song.lyrics}');
              if (!_matchesAllWords(haystack, query)) return false;
            }
            return true;
          }).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _hasFilter ? _filterSummary : 'Nenhum filtro aplicado',
                        style: TextStyle(color: context.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showFilterSheet(context, soloistOptions),
                      icon: Icon(
                        Icons.filter_alt_outlined,
                        color: _hasFilter ? SibValColors.goldAccent : context.textPrimary,
                      ),
                      label: Text(
                        'Filtro',
                        style: TextStyle(
                          color: _hasFilter ? SibValColors.goldAccent : context.textPrimary,
                        ),
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
                          _filterMonth = null;
                          _filterYear = null;
                        }),
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
          // Abertas por padrão de novo (02/09/2026 sessão seguinte, pedido
          // do usuário — reverte o "fechadas por padrão" de 03/09/2026).
          initiallyExpanded: true,
          children: [for (final song in groupSongs) tileFor(song)],
        );
      },
    );
  }

  /// Bottom sheet com as opções de filtro (texto, classificação, solista,
  /// período mês/ano) — separado do botão "Filtro" pra não ocupar espaço
  /// permanente na tela. Estado só é aplicado ao próprio `_MonthlyRepertoireTab`
  /// ao tocar "Aplicar"; "Limpar filtro" zera tudo direto.
  void _showFilterSheet(BuildContext context, List<String> soloistOptions) {
    var tempQuery = _filterQuery;
    var tempClassification = _filterClassification;
    var tempSoloist = _filterSoloist;
    var tempMonth = _filterMonth;
    var tempYear = _filterYear;
    // Sem `.dispose()` deste controller de propósito — mesmo motivo já
    // documentado em `_showSongDialog` (bug real "'_dependents.isEmpty': is
    // not true", 03/09/2026): o `TextField` que usa este controller ainda
    // está montado durante a animação de fechamento do bottom sheet quando
    // `.whenComplete()`/o callback de Aplicar/Limpar rodaria o dispose,
    // derrubando o app. Deixa o GC coletar, mesmo padrão de
    // `nameController`/`artistController` nesta mesma tela.
    final queryController = TextEditingController(text: tempQuery);
    final now = DateTime.now();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          // Sem isso, "Aplicar"/"Limpar filtro" ficavam embaixo da barra de
          // navegação do sistema (3 botões) — invisíveis e, pior, o toque
          // caía na própria barra do Android em vez de chegar no app
          // (confirmado via `dumpsys window`: a barra ocupa uma faixa fixa
          // no fim da tela que intercepta o toque antes do Flutter,
          // independente de onde o widget "pensa" que está desenhado).
          bottom: true,
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filtrar músicas',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: queryController,
                  decoration: const InputDecoration(
                    labelText: 'Buscar por nome ou letra',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) => tempQuery = value,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PraiseSongClassification>(
                  initialValue: tempClassification,
                  isExpanded: true,
                  dropdownColor: Theme.of(sheetContext).colorScheme.surfaceContainerHighest,
                  decoration: const InputDecoration(labelText: 'Classificação', isDense: true),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todas')),
                    for (final c in PraiseSongClassification.values)
                      DropdownMenuItem(value: c, child: Text(c.label)),
                  ],
                  onChanged: (value) => setSheetState(() => tempClassification = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: tempSoloist,
                  isExpanded: true,
                  dropdownColor: Theme.of(sheetContext).colorScheme.surfaceContainerHighest,
                  decoration: const InputDecoration(labelText: 'Solista', isDense: true),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos')),
                    for (final s in soloistOptions) DropdownMenuItem(value: s, child: Text(s)),
                  ],
                  onChanged: (value) => setSheetState(() => tempSoloist = value),
                ),
                const SizedBox(height: 12),
                Text(
                  'Período (mês/ano)',
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
                        initialValue: tempMonth,
                        isExpanded: true,
                        dropdownColor: Theme.of(sheetContext).colorScheme.surfaceContainerHighest,
                        decoration: const InputDecoration(labelText: 'Mês', isDense: true),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Todos')),
                          for (var m = 1; m <= 12; m++)
                            DropdownMenuItem(value: m, child: Text(praiseMonthNames[m - 1])),
                        ],
                        onChanged: (value) => setSheetState(() {
                          tempMonth = value;
                          if (value != null) tempYear ??= now.year;
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<int>(
                        initialValue: tempYear,
                        isExpanded: true,
                        dropdownColor: Theme.of(sheetContext).colorScheme.surfaceContainerHighest,
                        decoration: const InputDecoration(labelText: 'Ano', isDense: true),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Todos')),
                          for (var y = now.year - 2; y <= now.year + 2; y++)
                            DropdownMenuItem(value: y, child: Text('$y')),
                        ],
                        onChanged: (value) => setSheetState(() => tempYear = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _filterQuery = '';
                            _filterClassification = null;
                            _filterSoloist = null;
                            _filterMonth = null;
                            _filterYear = null;
                          });
                          Navigator.of(sheetContext).pop();
                        },
                        child: const Text('Limpar filtro'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _filterQuery = tempQuery;
                            _filterClassification = tempClassification;
                            _filterSoloist = tempSoloist;
                            _filterMonth = tempMonth;
                            _filterYear = tempYear;
                          });
                          Navigator.of(sheetContext).pop();
                        },
                        child: const Text('Aplicar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  void _showSongDialog(BuildContext context, WidgetRef ref, {PraiseSong? song}) {
    final nameController = TextEditingController(text: song?.name ?? '');
    final artistController = TextEditingController(text: song?.artist ?? '');
    // Mais de uma classificação por música (05/09/2026, pedido do usuário) —
    // mesmo padrão de `Set` mutável já usado em outros multi-selects desta
    // base (ex. capacidades de um papel em `manage_roles_page.dart`).
    final classifications = song?.classifications.toSet() ??
        <PraiseSongClassification>{PraiseSongClassification.avulso};
    // Seleção (não mais texto livre) restrita a quem tem o papel Louvor —
    // ver `_SoloistDropdown` (03/09/2026, pedido do usuário).
    final soloistSelections = (song?.soloists.isEmpty ?? true)
        ? <String?>[null]
        : List<String?>.of(song!.soloists);
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

    // Aviso de "sair sem salvar?" ao voltar (03/09/2026, pedido do usuário)
    // — mesmo padrão de `PopScope`/`_dirty` já usado em telas de formulário
    // desta base (`introduction_page.dart`, `service_order_form_page.dart`),
    // adaptado pra um diálogo: compara o estado atual contra o snapshot de
    // quando o diálogo abriu, em vez de uma flag `_dirty` à parte — mais
    // simples aqui porque não há valor padrão "pré-preenchido" que já
    // contaria como alteração (diferente da Ordem de Culto).
    final initialName = nameController.text;
    final initialArtist = artistController.text;
    final initialClassifications = Set<PraiseSongClassification>.of(classifications);
    final initialSoloists = List<String?>.of(soloistSelections);
    final initialRefMonth = refMonth;
    final initialRefYear = refYear;
    final initialLyrics = lyricsController.text;

    bool soloistsChanged() {
      if (soloistSelections.length != initialSoloists.length) return true;
      for (var i = 0; i < soloistSelections.length; i++) {
        if (soloistSelections[i] != initialSoloists[i]) return true;
      }
      return false;
    }

    bool hasUnsavedChanges() =>
        nameController.text != initialName ||
        artistController.text != initialArtist ||
        !setEquals(classifications, initialClassifications) ||
        soloistsChanged() ||
        refMonth != initialRefMonth ||
        refYear != initialRefYear ||
        lyricsController.text != initialLyrics;

    Future<void> confirmDiscardAndPop(BuildContext dialogContext) async {
      final discard = await showDialog<bool>(
        context: dialogContext,
        builder: (confirmContext) => AlertDialog(
          title: const Text('Sair sem salvar?'),
          content: const Text('Os dados preenchidos ainda não foram salvos.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(confirmContext).pop(false),
              child: const Text('Continuar preenchendo'),
            ),
            TextButton(
              onPressed: () => Navigator.of(confirmContext).pop(true),
              child: const Text('Sair'),
            ),
          ],
        ),
      );
      if (discard == true && dialogContext.mounted) Navigator.of(dialogContext).pop();
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => PopScope(
          canPop: !hasUnsavedChanges(),
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            confirmDiscardAndPop(dialogContext);
          },
          child: AlertDialog(
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
                    // Sem isso, `canPop` do `PopScope` ficava preso no valor
                    // do primeiro build — mesmo bug já documentado em
                    // `introduction_page.dart` (03/09/2026).
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: artistController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Cantor/Banda'),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Classificação',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Uma música pode ter mais de uma classificação
                  // (05/09/2026, pedido do usuário) — virou seleção múltipla
                  // (`FilterChip`), não mais um dropdown de valor único.
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final c in PraiseSongClassification.values)
                        FilterChip(
                          label: Text(c.label),
                          selected: classifications.contains(c),
                          onSelected: (selected) => setDialogState(() {
                            if (selected) {
                              classifications.add(c);
                            } else {
                              classifications.remove(c);
                            }
                          }),
                        ),
                    ],
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
                  for (var i = 0; i < soloistSelections.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _SoloistDropdown(
                              value: soloistSelections[i],
                              onChanged: (value) =>
                                  setDialogState(() => soloistSelections[i] = value),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: soloistSelections.length > 1
                                ? () => setDialogState(() => soloistSelections.removeAt(i))
                                : null,
                          ),
                        ],
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setDialogState(() => soloistSelections.add(null)),
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
                  Wrap(
                    spacing: 4,
                    children: [
                      OutlinedButton.icon(
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
                      // Botão "Colar" (05/09/2026, pedido do usuário) — cola
                      // direto da área de transferência, sem passar pela
                      // busca no navegador.
                      OutlinedButton.icon(
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          final text = data?.text;
                          if (text == null || text.trim().isEmpty) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Área de transferência vazia.'),
                                ),
                              );
                            }
                            return;
                          }
                          setDialogState(() => lyricsController.text = text);
                        },
                        icon: const Icon(Icons.content_paste, size: 18),
                        label: const Text('Colar'),
                      ),
                    ],
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
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              // Sem `.dispose()` de `lyricsController` aqui — o diálogo ainda
              // está montado durante a animação de saída do
              // `Navigator.pop()`, então descartar o controller aqui
              // derrubava o app com "'_dependents.isEmpty': is not true"
              // (bug real relatado pelo usuário, 03/09/2026, na época com os
              // campos de solista — que eram texto livre com
              // `TextEditingController` próprio; viraram dropdown de
              // seleção depois e não têm mais esse risco). Mesmo padrão de
              // não descartar controller de diálogo ad-hoc já usado em
              // `nameController`/`artistController` neste mesmo diálogo.
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final artist = artistController.text.trim();
                final soloists = soloistSelections.whereType<String>().toSet().toList();
                final referenceMonthKey = (refMonth != null && refYear != null)
                    ? '$refYear-${refMonth!.toString().padLeft(2, '0')}'
                    : null;
                final lyrics = lyricsController.text.trim();
                Navigator.of(dialogContext).pop();
                final newSong = PraiseSong(
                  id: song?.id ?? '',
                  name: name,
                  artist: artist,
                  classifications: classifications.isEmpty
                      ? const [PraiseSongClassification.avulso]
                      : classifications.toList(),
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
      song.classificationsLabel,
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

/// Dropdown de solista restrito a quem tem o papel Louvor (03/09/2026,
/// pedido do usuário: "o solista deve ser selecionado entre os
/// usuários/membros do app que tenham papel de Louvor") — substitui o campo
/// de texto livre com sugestões que existia antes (`_SoloistField`, aceitava
/// qualquer nome digitado, a lista era só uma sugestão). Fonte:
/// `louvorMemberNamesProvider` (`settings/louvorMembers.names`, mantido por
/// `manage_users_page.dart` ao marcar/desmarcar o chip "Louvor" — ver doc
/// comment em `praise_repertoire_repository.dart`). `ConsumerWidget` simples
/// (sem estado próprio) — o valor selecionado vive no
/// `soloistSelections[i]` do diálogo chamador, igual aos demais dropdowns
/// controlados desta tela (Classificação, Mês, Ano).
class _SoloistDropdown extends ConsumerWidget {
  const _SoloistDropdown({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(louvorMemberNamesProvider).asData?.value ?? const <String>[];
    // Um solista já salvo que não está mais na lista (ex.: perdeu o papel
    // Louvor depois de escalado) continua aparecendo como opção, pra não
    // sumir um dado já gravado sozinho — só some da lista de escolha se o
    // dialogo for reaberto sem esse valor pré-selecionado.
    final options = value != null && !names.contains(value) ? [value!, ...names] : names;
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      decoration: const InputDecoration(
        hintText: 'Selecione um solista',
        isDense: true,
      ),
      items: [for (final name in options) DropdownMenuItem(value: name, child: Text(name))],
      onChanged: onChanged,
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

/// Uma busca de mais de uma palavra (ex.: "bondade deus") deve achar
/// "Bondade de Deus" mesmo sem bater a frase exata — [normalizedQuery] (já
/// passada por [_normalizePraiseText]) é dividida em palavras e cada uma
/// precisa aparecer em [normalizedHaystack], em qualquer ordem/posição, em
/// vez de exigir a frase inteira como substring única (03/09/2026, corrige
/// busca que não achava nada com mais de uma palavra).
bool _matchesAllWords(String normalizedHaystack, String normalizedQuery) {
  final words = normalizedQuery.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  return words.every(normalizedHaystack.contains);
}
