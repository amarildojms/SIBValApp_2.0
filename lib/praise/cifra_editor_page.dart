import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cifra_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../data/user_repository.dart';
import '../models/cifra.dart';
import '../models/praise_repertoire.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário). Editor de cifra — só admin ou quem foi selecionado
/// individualmente como editor de cifra (`canEditCifrasProvider`, não é um
/// papel) chega aqui (`CifraListPage`). `content` usa colchetes pro acorde
/// entrar antes da sílaba/palavra (ex. `"[G]Digno é o [D]Senhor"`) —
/// `chord_transpose.dart` é quem sabe achar/transpor isso na hora de exibir
/// (`CifraViewPage`, não aqui: o texto salvo fica sempre no tom original).
///
/// Três modos (28/08/2026, revisão — "deve ser possível incluir cifras além
/// do que está no repertório"):
/// - [song] preenchido: cifra linkada a uma música do repertório mestre —
///   nome/cantor vêm de lá, só leitura aqui (editam em Ministério de Louvor).
/// - [song] nulo e [existing] preenchido: editando uma cifra avulsa já
///   salva — nome/cantor ficam editáveis.
/// - Os dois nulos: cifra avulsa nova — nome/cantor em branco, `songId`
///   gerado na hora (`CifraRepository.newStandaloneId`).
class CifraEditorPage extends ConsumerStatefulWidget {
  const CifraEditorPage({super.key, this.song, this.existing});

  final PraiseSong? song;
  final Cifra? existing;

  @override
  ConsumerState<CifraEditorPage> createState() => _CifraEditorPageState();
}

class _CifraEditorPageState extends ConsumerState<CifraEditorPage> {
  late final _nameController = TextEditingController(
    text: widget.song?.name ?? widget.existing?.songName ?? '',
  );
  late final _artistController = TextEditingController(
    text: widget.song?.artist ?? widget.existing?.songArtist ?? '',
  );
  late final _contentController = TextEditingController(
    text: widget.existing?.content ?? '',
  );
  late final String _songId =
      widget.song?.id ?? widget.existing?.songId ?? ref.read(cifraRepositoryProvider).newStandaloneId();

  String? _toneNote;
  bool _toneIsMinor = false;
  int _capo = 0;
  bool _saving = false;

  bool get _isStandalone => widget.song == null;

  @override
  void initState() {
    super.initState();
    final baseTone = widget.existing?.baseTone ?? '';
    if (baseTone.isNotEmpty) {
      _toneIsMinor = baseTone.endsWith('m');
      _toneNote = _toneIsMinor ? baseTone.substring(0, baseTone.length - 1) : baseTone;
    }
    _capo = widget.existing?.capo ?? 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _artistController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Informe o nome da música.')));
      return;
    }
    final uid = ref.read(currentUidProvider);
    final profile = ref.read(currentUserProfileProvider).asData?.value;
    if (uid == null || profile == null) return;
    setState(() => _saving = true);
    final tone = _toneNote == null ? '' : (_toneIsMinor ? '${_toneNote}m' : _toneNote!);
    final cifra = Cifra(
      id: _songId,
      songId: _songId,
      songName: widget.song?.name ?? name,
      songArtist: widget.song?.artist ?? _artistController.text.trim(),
      content: _contentController.text,
      baseTone: tone,
      capo: _capo,
      updatedByUid: uid,
      updatedByName: profile.shortName,
    );
    try {
      await ref.read(cifraRepositoryProvider).save(cifra);
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
    final title = widget.song?.name ?? (widget.existing != null ? widget.existing!.songName : 'Nova cifra');
    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenTitle('Cifra — $title'),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                children: [
                  if (_isStandalone) ...[
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Nome da música',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _artistController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Cantor/Banda',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _toneNote,
                          isExpanded: true,
                          dropdownColor:
                              Theme.of(context).colorScheme.surfaceContainerHighest,
                          decoration: const InputDecoration(
                            labelText: 'Tom original',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            for (final note in praiseToneNotes)
                              DropdownMenuItem(value: note, child: Text(note)),
                          ],
                          // Mesmo mecanismo de `weekly_repertoire_form_page.dart`
                          // (28/08/2026, pedido do usuário) — só o texto do
                          // botão fechado ganha o "m", a lista aberta continua
                          // com as notas puras.
                          selectedItemBuilder: (context) => [
                            for (final note in praiseToneNotes)
                              Text(_toneIsMinor ? '${note}m' : note),
                          ],
                          onChanged: (value) => setState(() => _toneNote = value),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: _toneIsMinor,
                            onChanged: _toneNote == null
                                ? null
                                : (value) => setState(() => _toneIsMinor = value ?? false),
                          ),
                          const Text('Menor', style: TextStyle(fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('Capotraste', style: TextStyle(color: context.textPrimary)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _capo > 0 ? () => setState(() => _capo--) : null,
                      ),
                      Text('$_capo', style: TextStyle(color: context.textPrimary, fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: _capo < 11 ? () => setState(() => _capo++) : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Letra e acordes — coloque o acorde entre colchetes antes da '
                    'sílaba/palavra, ex.: [G]Digno é o [D]Senhor',
                    style: TextStyle(color: context.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _contentController,
                    maxLines: 20,
                    minLines: 10,
                    style: const TextStyle(fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 20),
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
}
