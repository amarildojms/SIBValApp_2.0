import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/praise_repertoire_repository.dart';
import '../models/praise_repertoire.dart';
import '../theme/app_theme.dart';
import '../widgets/date_field.dart';
import '../widgets/sibval_app_bar.dart';
import 'praise_suggestions_page.dart';

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário). Editor do repertório de uma semana — data (chave do documento,
/// `PraiseRepertoireRepository.weekKeyFor`, por isso fica travada ao editar
/// uma semana já existente), lista dinâmica de músicas escaladas (cada uma
/// com tom e "momento" — Louvor 1/2/3 ou texto livre pra "mais ou menos
/// casos", pedido do usuário) e uma lista dinâmica de links de playlist
/// (YouTube/Spotify/etc.).
class WeeklyRepertoireFormPage extends ConsumerStatefulWidget {
  const WeeklyRepertoireFormPage({super.key, this.editing});

  final WeeklyRepertoire? editing;

  @override
  ConsumerState<WeeklyRepertoireFormPage> createState() =>
      _WeeklyRepertoireFormPageState();
}

class _AssignmentDraft {
  String? songId;
  String songName;
  String songArtist;
  String? toneNote;
  bool toneIsMinor;
  String slotLabel;
  bool isCustomSlot;
  final TextEditingController customSlotController;

  _AssignmentDraft({
    this.songId,
    this.songName = '',
    this.songArtist = '',
    this.toneNote,
    this.toneIsMinor = false,
    this.slotLabel = 'Louvor 1',
    this.isCustomSlot = false,
    String customSlot = '',
  }) : customSlotController = TextEditingController(text: customSlot);

  factory _AssignmentDraft.from(PraiseAssignment a) {
    final isCustom = !praiseSlotLabels.contains(a.slotLabel);
    return _AssignmentDraft(
      songId: a.songId,
      songName: a.songName,
      songArtist: a.songArtist,
      toneNote: a.toneNote.isEmpty ? null : a.toneNote,
      toneIsMinor: a.toneIsMinor,
      slotLabel: isCustom ? praiseSlotLabels[0] : a.slotLabel,
      isCustomSlot: isCustom,
      customSlot: isCustom ? a.slotLabel : '',
    );
  }

  PraiseAssignment? toAssignment() {
    if (songId == null) return null;
    final label = isCustomSlot ? customSlotController.text.trim() : slotLabel;
    if (label.isEmpty) return null;
    return PraiseAssignment(
      songId: songId!,
      songName: songName,
      songArtist: songArtist,
      toneNote: toneNote ?? '',
      toneIsMinor: toneNote == null ? false : toneIsMinor,
      slotLabel: label,
    );
  }

  void dispose() {
    customSlotController.dispose();
  }
}

class _WeeklyRepertoireFormPageState
    extends ConsumerState<WeeklyRepertoireFormPage> {
  static final _dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');

  DateTime? _weekDate;
  final List<_AssignmentDraft> _assignments = [];
  final List<TextEditingController> _linkControllers = [];
  bool _saving = false;

  /// Aviso de "sair sem salvar?" ao voltar (03/09/2026, pedido do usuário)
  /// — mesmo padrão de `PopScope`/`_dirty` já usado em
  /// `service_order_form_page.dart`. Flag explícita (não um cálculo "algum
  /// campo preenchido"), porque o formulário já nasce com valores padrão
  /// (data = próximo domingo, "Louvor 1" no momento de cada música) que não
  /// devem contar como alteração — só vira `true` quando o usuário de fato
  /// interage com algum campo.
  bool _dirty = false;

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _weekDate = editing.weekDate;
      _assignments.addAll(editing.assignments.map(_AssignmentDraft.from));
      _linkControllers.addAll(
        editing.links.map((l) => TextEditingController(text: l)),
      );
    } else {
      _weekDate = _nextOrCurrentSunday(DateTime.now());
    }
    if (_assignments.isEmpty) _assignments.add(_AssignmentDraft());
    if (_linkControllers.isEmpty) _linkControllers.add(TextEditingController());
  }

  static DateTime _nextOrCurrentSunday(DateTime from) {
    final d = DateTime(from.year, from.month, from.day);
    return d.add(Duration(days: (7 - d.weekday) % 7));
  }

  @override
  void dispose() {
    for (final draft in _assignments) {
      draft.dispose();
    }
    for (final controller in _linkControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addAssignment() => setState(() {
    _dirty = true;
    _assignments.add(_AssignmentDraft());
  });

  /// Chamado pelo botão "+" de `PraiseSuggestionsPage` — sem fechar a tela
  /// de sugestões (02/09/2026, pedido do usuário: "uma opção de adicionar
  /// cada música ao repertório semanal"). Revisado (03/09/2026, pedido do
  /// usuário): se o **último** campo de música da lista ainda estiver vazio
  /// (nenhuma música selecionada), a primeira sugestão escolhida preenche
  /// esse campo em vez de abrir um novo; só a partir da segunda sugestão
  /// escolhida é que novos campos são acrescentados abaixo. Evita deixar um
  /// campo "Selecione" vazio esquecido no meio/fim da lista quando o
  /// dirigente monta o repertório inteiro via Sugestões.
  void _addAssignmentFromSong(PraiseSong song) {
    setState(() {
      _dirty = true;
      final last = _assignments.isEmpty ? null : _assignments.last;
      if (last != null && last.songId == null) {
        last.songId = song.id;
        last.songName = song.name;
        last.songArtist = song.artist;
      } else {
        _assignments.add(
          _AssignmentDraft(songId: song.id, songName: song.name, songArtist: song.artist),
        );
      }
    });
  }

  void _removeAssignment(int index) {
    final draft = _assignments.removeAt(index);
    draft.dispose();
    setState(() => _dirty = true);
  }

  void _addLink() => setState(() {
    _dirty = true;
    _linkControllers.add(TextEditingController());
  });

  void _removeLink(int index) {
    final controller = _linkControllers.removeAt(index);
    controller.dispose();
    setState(() => _dirty = true);
  }

  Future<void> _confirmDiscardAndPop() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair sem salvar?'),
        content: const Text(
          'Os dados preenchidos no repertório ainda não foram salvos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Continuar preenchendo'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _save() async {
    if (_weekDate == null) return;
    setState(() => _saving = true);
    final assignments = _assignments
        .map((d) => d.toAssignment())
        .whereType<PraiseAssignment>()
        .toList();
    final links = _linkControllers
        .map((c) => c.text.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final repertoire = WeeklyRepertoire(
      id: '',
      weekDate: _weekDate!,
      assignments: assignments,
      links: links,
    );
    try {
      await ref.read(praiseRepertoireRepositoryProvider).saveWeeklyRepertoire(repertoire);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Falha ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(praiseSongsProvider);
    final songs = songsAsync.asData?.value ?? const [];

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmDiscardAndPop();
      },
      child: Scaffold(
      // Excluir saiu daqui — agora é só via toque longo na lista
      // (`_WeeklyRepertoireTab`, 28/08/2026, pedido do usuário: "Tirar
      // lixeira do editar repertório", editar/excluir/copiar via toque
      // longo, mesmo padrão de `ServiceOrderListPage`).
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenTitle(_isEditing ? 'Editar Repertório' : 'Novo Repertório'),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                children: [
                  if (_isEditing)
                    _label(context, 'Semana de ${_dateFormat.format(_weekDate!)}')
                  else
                    DateField(
                      label: 'Domingo da semana',
                      value: _weekDate,
                      firstDate: DateTime(DateTime.now().year - 1),
                      lastDate: DateTime(DateTime.now().year + 3),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      onChanged: (date) => setState(() {
                        _dirty = true;
                        _weekDate = date;
                      }),
                    ),
                  const SizedBox(height: 16),
                  _label(context, 'Músicas escaladas'),
                  const SizedBox(height: 8),
                  for (var i = 0; i < _assignments.length; i++)
                    Padding(
                      key: ValueKey(_assignments[i]),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AssignmentRow(
                        draft: _assignments[i],
                        songs: songs,
                        onChanged: () => setState(() => _dirty = true),
                        onRemove: _assignments.length > 1
                            ? () => _removeAssignment(i)
                            : null,
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _addAssignment,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Adicionar música'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                PraiseSuggestionsPage(onAdd: _addAssignmentFromSong),
                          ),
                        ),
                        icon: const Icon(Icons.lightbulb_outline, size: 18),
                        label: const Text('Sugestões'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _label(context, 'Links de playlist'),
                  const SizedBox(height: 8),
                  for (var i = 0; i < _linkControllers.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _linkControllers[i],
                              decoration: const InputDecoration(
                                hintText: 'https://...',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                              onChanged: (_) => _markDirty(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => _removeLink(i),
                          ),
                        ],
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _addLink,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Adicionar link'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                      ),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Salvar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        color: context.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _AssignmentRow extends StatelessWidget {
  const _AssignmentRow({
    required this.draft,
    required this.songs,
    required this.onChanged,
    this.onRemove,
  });

  final _AssignmentDraft draft;
  final List<PraiseSong> songs;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                // Picker em pastas por mês referência (02/09/2026, pedido do
                // usuário: "o repertório semanal organize as músicas em
                // pastas relacionadas ao seu mês de referência") — no lugar
                // do dropdown plano de antes, ver `_pickSongFromFolders`.
                child: InkWell(
                  onTap: () async {
                    final picked = await _pickSongFromFolders(context, songs);
                    if (picked != null) {
                      draft.songId = picked.id;
                      draft.songName = picked.name;
                      draft.songArtist = picked.artist;
                      onChanged();
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Música',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    child: Text(
                      draft.songId == null
                          ? 'Selecione'
                          : (draft.songArtist.isEmpty
                                ? draft.songName
                                : '${draft.songName} — ${draft.songArtist}'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              if (onRemove != null)
                IconButton(icon: const Icon(Icons.close), onPressed: onRemove),
            ],
          ),
          Builder(
            builder: (context) {
              // Solista(s) da música escalada (05/09/2026, pedido do
              // usuário: "no repertório semanal aparecer os solistas de cada
              // música") — vem do catálogo mestre (`PraiseSong.soloists`),
              // casado por `draft.songId`; some quando a música não tem
              // solista cadastrado.
              final song = songs.where((s) => s.id == draft.songId).firstOrNull;
              final soloists = song?.soloists ?? const [];
              if (soloists.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Solista(s): ${soloists.join(', ')}',
                  style: TextStyle(color: context.textSecondary, fontSize: 12),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: draft.toneNote,
                  isExpanded: true,
                  dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  decoration: const InputDecoration(
                    labelText: 'Tom',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  // Lista aberta e botão fechado mostram o mesmo texto — se
                  // "Menor" estiver marcado, todo item ganha o "m" (ex.
                  // "Em", "Dbm", "F#m"), não só o valor selecionado
                  // (28/08/2026, pedido do usuário — antes só o botão
                  // fechado ganhava o "m" via `selectedItemBuilder`, a lista
                  // aberta continuava com as notas puras).
                  items: [
                    for (final note in praiseToneNotes)
                      DropdownMenuItem(
                        value: note,
                        // Tom selecionado em destaque na lista aberta, não só
                        // no botão fechado (28/08/2026, pedido do usuário).
                        child: Text(
                          draft.toneIsMinor ? '${note}m' : note,
                          style: note == draft.toneNote
                              ? const TextStyle(
                                  color: SibValColors.goldAccent,
                                  fontWeight: FontWeight.bold,
                                )
                              : null,
                        ),
                      ),
                  ],
                  selectedItemBuilder: (context) => [
                    for (final note in praiseToneNotes)
                      Text(draft.toneIsMinor ? '${note}m' : note),
                  ],
                  onChanged: (value) {
                    draft.toneNote = value;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 4),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: draft.toneIsMinor,
                    onChanged: draft.toneNote == null
                        ? null
                        : (value) {
                            draft.toneIsMinor = value ?? false;
                            onChanged();
                          },
                  ),
                  const Text('Menor', style: TextStyle(fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: draft.isCustomSlot ? 'Outro' : draft.slotLabel,
            isExpanded: true,
            dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            decoration: const InputDecoration(
              labelText: 'Momento',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
            items: [
              for (final label in praiseSlotLabels)
                DropdownMenuItem(value: label, child: Text(label)),
              const DropdownMenuItem(value: 'Outro', child: Text('Outro')),
            ],
            onChanged: (value) {
              if (value == 'Outro') {
                draft.isCustomSlot = true;
              } else {
                draft.isCustomSlot = false;
                draft.slotLabel = value ?? praiseSlotLabels[0];
              }
              onChanged();
            },
          ),
          if (draft.isCustomSlot) ...[
            const SizedBox(height: 8),
            TextField(
              controller: draft.customSlotController,
              decoration: const InputDecoration(
                labelText: 'Nome do momento',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              onChanged: (_) => onChanged(),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bottom sheet do picker de música em pastas por mês referência
/// (`_AssignmentRow`, ver comentário acima) — uma `ExpansionTile` por mês
/// (mais recente primeiro; "Sem mês definido" sempre por último), com busca
/// por nome/cantor no topo pra catálogos maiores.
Future<PraiseSong?> _pickSongFromFolders(
  BuildContext context,
  List<PraiseSong> songs,
) {
  return showModalBottomSheet<PraiseSong>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _SongFolderPickerSheet(songs: songs),
  );
}

class _SongFolderPickerSheet extends StatefulWidget {
  const _SongFolderPickerSheet({required this.songs});

  final List<PraiseSong> songs;

  @override
  State<_SongFolderPickerSheet> createState() => _SongFolderPickerSheetState();
}

class _SongFolderPickerSheetState extends State<_SongFolderPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _normalizeSongQuery(_query);
    final filtered = query.isEmpty
        ? widget.songs
        : widget.songs
              .where((s) => _normalizeSongQuery('${s.name} ${s.artist}').contains(query))
              .toList();

    final groups = <String?, List<PraiseSong>>{};
    for (final song in filtered) {
      groups.putIfAbsent(song.referenceMonthKey, () => []).add(song);
    }
    final keys = groups.keys.toList()
      ..sort((a, b) {
        if (a == null && b == null) return 0;
        if (a == null) return 1;
        if (b == null) return -1;
        return b.compareTo(a);
      });

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                autofocus: false,
                decoration: const InputDecoration(
                  labelText: 'Buscar música',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('Nenhuma música encontrada.'))
                  : ListView(
                      controller: scrollController,
                      children: [
                        for (final key in keys)
                          ExpansionTile(
                            leading: const Icon(Icons.folder_outlined),
                            title: Text(praiseReferenceMonthLabel(key)),
                            initiallyExpanded: keys.length == 1,
                            children: [
                              for (final song in groups[key]!)
                                ListTile(
                                  title: Text(song.name),
                                  subtitle: song.artist.isEmpty ? null : Text(song.artist),
                                  onTap: () => Navigator.of(context).pop(song),
                                ),
                            ],
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

const _songQueryDiacritics = 'áàãâäéèêëíìîïóòõôöúùûüçñ';
const _songQueryPlainLetters = 'aaaaaeeeeiiiiooooouuuucn';

String _normalizeSongQuery(String value) {
  var result = value.toLowerCase().trim();
  for (var i = 0; i < _songQueryDiacritics.length; i++) {
    result = result.replaceAll(_songQueryDiacritics[i], _songQueryPlainLetters[i]);
  }
  return result;
}
