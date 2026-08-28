import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/praise_repertoire_repository.dart';
import '../models/praise_repertoire.dart';
import '../theme/app_theme.dart';
import '../widgets/date_field.dart';
import '../widgets/sibval_app_bar.dart';

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

  void _addAssignment() => setState(() => _assignments.add(_AssignmentDraft()));

  void _removeAssignment(int index) {
    final draft = _assignments.removeAt(index);
    draft.dispose();
    setState(() {});
  }

  void _addLink() => setState(() => _linkControllers.add(TextEditingController()));

  void _removeLink(int index) {
    final controller = _linkControllers.removeAt(index);
    controller.dispose();
    setState(() {});
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

  Future<void> _delete() async {
    final editing = widget.editing;
    if (editing == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir repertório'),
        content: Text(
          'Tem certeza que deseja excluir o repertório de ${_dateFormat.format(editing.weekDate)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(praiseRepertoireRepositoryProvider).deleteWeeklyRepertoire(editing.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(praiseSongsProvider);
    final songs = songsAsync.asData?.value ?? const [];

    return Scaffold(
      appBar: SibValAppBar(
        isHome: false,
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
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
                      onChanged: (date) => setState(() => _weekDate = date),
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
                        onChanged: () => setState(() {}),
                        onRemove: _assignments.length > 1
                            ? () => _removeAssignment(i)
                            : null,
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _addAssignment,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Adicionar música'),
                    ),
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
                child: DropdownButtonFormField<String>(
                  initialValue: draft.songId,
                  isExpanded: true,
                  dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  decoration: const InputDecoration(
                    labelText: 'Música',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  items: [
                    for (final song in songs)
                      DropdownMenuItem(
                        value: song.id,
                        child: Text(
                          song.artist.isEmpty ? song.name : '${song.name} — ${song.artist}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (id) {
                    final matches = songs.where((s) => s.id == id);
                    final song = matches.isEmpty ? null : matches.first;
                    draft.songId = id;
                    draft.songName = song?.name ?? '';
                    draft.songArtist = song?.artist ?? '';
                    onChanged();
                  },
                ),
              ),
              if (onRemove != null)
                IconButton(icon: const Icon(Icons.close), onPressed: onRemove),
            ],
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
                        child: Text(draft.toneIsMinor ? '${note}m' : note),
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
            ),
          ],
        ],
      ),
    );
  }
}
