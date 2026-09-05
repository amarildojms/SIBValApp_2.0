import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cifra_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../data/user_repository.dart';
import '../models/cifra.dart';
import '../models/praise_repertoire.dart';
import '../theme/app_theme.dart';
import '../util/cifra_club_text.dart';
import '../widgets/sibval_app_bar.dart';

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário). Editor de cifra — só admin ou quem foi selecionado
/// individualmente como editor de cifra (`canEditCifrasProvider`, não é um
/// papel) chega aqui (`CifraListPage`). `content` é digitado/colado no
/// formato "Cifra Club" — linha de acordes solta em cima, linha de letra
/// embaixo (28/08/2026, rodada de import — antes era `[Acorde]palavra`
/// inline; cifras salvas nesse formato antigo continuam funcionando, ver
/// `CifraViewPage`) — ou importado de um arquivo .txt (botão "Importar
/// arquivo", `_importFile`, `cleanCifraClubText`). `chord_transpose.dart` é
/// quem sabe achar/transpor isso na hora de exibir (`CifraViewPage`, não
/// aqui: o texto salvo fica sempre no tom original).
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
      widget.song?.id ??
      widget.existing?.songId ??
      ref.read(cifraRepositoryProvider).newStandaloneId();

  String? _toneNote;
  bool _toneIsMinor = false;
  int _capo = 0;
  bool _saving = false;
  bool _dirty = false;

  bool get _isStandalone => widget.song == null;

  @override
  void initState() {
    super.initState();
    final baseTone = widget.existing?.baseTone ?? '';
    if (baseTone.isNotEmpty) {
      _toneIsMinor = baseTone.endsWith('m');
      _toneNote = _toneIsMinor
          ? baseTone.substring(0, baseTone.length - 1)
          : baseTone;
    }
    _capo = widget.existing?.capo ?? 0;
    // Listeners adicionados só depois de já preenchidos os valores iniciais
    // acima, senão disparariam `_markDirty` no próprio `initState` (mesmo
    // cuidado já documentado em `introduction_page.dart`/
    // `service_order_form_page.dart`).
    _nameController.addListener(_markDirty);
    _artistController.addListener(_markDirty);
    _contentController.addListener(_markDirty);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _artistController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  /// Aviso "voltar sem salvar?" (29/08/2026, pedido do usuário) — mesmo
  /// padrão de `service_order_form_page.dart`/`introduction_page.dart`, com
  /// um botão a mais ("Salvar") que chama `_save()` direto — ela já faz o
  /// `Navigator.pop()` sozinha quando o salvamento dá certo.
  Future<void> _confirmDiscardAndPop() async {
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair sem salvar?'),
        content: const Text(
          'As alterações feitas nesta cifra ainda não foram salvas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('continue'),
            child: const Text('Continuar editando'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('discard'),
            child: const Text('Sair sem salvar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('save'),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'discard') {
      Navigator.of(context).pop();
    } else if (action == 'save') {
      await _save();
    }
  }

  /// Importa um .txt (colado/exportado de um site de cifra) e joga no campo
  /// de conteúdo, já limpo (`cleanCifraClubText`) — pede confirmação antes
  /// de sobrescrever se já havia algo digitado. `FilePickerPlatform.instance`
  /// (não mais `FilePicker.platform`, removido a partir do file_picker 12.x)
  /// devolve a lista de `PlatformFile` diretamente, com `readAsBytes()` em
  /// vez de um campo `bytes` nullable — API nova, confirmada lendo o pacote
  /// instalado (`file_picker_platform_interface-3.2.0`).
  Future<void> _importFile() async {
    final files = await FilePickerPlatform.instance.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );
    if (files.isEmpty) return;
    final bytes = await files.first.readAsBytes();
    final cleaned = cleanCifraClubText(
      utf8.decode(bytes, allowMalformed: true),
    );
    await _applyImportedText(cleaned);
  }

  /// Botão "Colar" (05/09/2026, pedido do usuário) — cola direto da área de
  /// transferência, sem passar por arquivo. Mesma limpeza
  /// (`cleanCifraClubText`, corta cabeçalho de site de cifra/colapsa linhas
  /// em branco) e mesma confirmação de sobrescrita do "Importar .txt".
  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Área de transferência vazia.')),
        );
      }
      return;
    }
    await _applyImportedText(cleanCifraClubText(text));
  }

  /// Compartilhado por "Importar .txt" e "Colar" — pede confirmação antes de
  /// sobrescrever se já havia algo digitado.
  Future<void> _applyImportedText(String cleaned) async {
    if (!mounted) return;
    if (_contentController.text.trim().isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Substituir o conteúdo atual?'),
          content: const Text(
            'O texto importado vai substituir o que já está digitado nesta '
            'cifra.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Substituir'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _contentController.text = cleaned);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome da música.')),
      );
      return;
    }
    final uid = ref.read(currentUidProvider);
    final profile = ref.read(currentUserProfileProvider).asData?.value;
    if (uid == null || profile == null) return;
    setState(() => _saving = true);
    final tone = _toneNote == null
        ? ''
        : (_toneIsMinor ? '${_toneNote}m' : _toneNote!);
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
      // Timeout defensivo (29/08/2026, bug relatado pelo usuário — botão
      // ficava processando pra sempre, sem mensagem de sucesso nem de erro):
      // o `Future` de `.set()` do cloud_firestore só completa quando o
      // servidor confirma a escrita — sem internet (ou com a escrita presa
      // atrás de uma regra de segurança negada enquanto offline), ele nunca
      // resolve nem rejeita sozinho, deixando o spinner girando
      // indefinidamente. Com o timeout, o usuário ao menos recebe um erro
      // acionável em vez de um botão travado sem explicação.
      await ref
          .read(cifraRepositoryProvider)
          .save(cifra)
          .timeout(const Duration(seconds: 15));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cifra salva.')));
        Navigator.of(context).pop();
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível confirmar o salvamento — verifique sua '
              'conexão com a internet e tente novamente.',
            ),
          ),
        );
      }
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
    final title =
        widget.song?.name ??
        (widget.existing != null ? widget.existing!.songName : 'Nova cifra');
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmDiscardAndPop();
      },
      child: Scaffold(
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
                            dropdownColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            decoration: const InputDecoration(
                              labelText: 'Tom original',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            // Mesmo mecanismo de `weekly_repertoire_form_page.dart`
                            // (28/08/2026, pedido do usuário) — a lista aberta E
                            // o botão fechado ganham o "m" quando "Menor" está
                            // marcado (ex. "Em", "Dbm", "F#m"), não só o
                            // fechado.
                            items: [
                              for (final note in praiseToneNotes)
                                DropdownMenuItem(
                                  value: note,
                                  // Tom selecionado em destaque na lista
                                  // aberta (28/08/2026, pedido do usuário).
                                  child: Text(
                                    _toneIsMinor ? '${note}m' : note,
                                    style: note == _toneNote
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
                                Text(_toneIsMinor ? '${note}m' : note),
                            ],
                            onChanged: (value) => setState(() {
                              _toneNote = value;
                              _dirty = true;
                            }),
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
                                  : (value) => setState(() {
                                      _toneIsMinor = value ?? false;
                                      _dirty = true;
                                    }),
                            ),
                            const Text('Menor', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'Capotraste',
                          style: TextStyle(color: context.textPrimary),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: _capo > 0
                              ? () => setState(() {
                                  _capo--;
                                  _dirty = true;
                                })
                              : null,
                        ),
                        Text(
                          '$_capo',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: _capo < 11
                              ? () => setState(() {
                                  _capo++;
                                  _dirty = true;
                                })
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Letra e acordes — Formato: uma linha só com os '
                            'acordes, e a linha de baixo com a letra '
                            'correspondente. Para marcar trechos que não são '
                            'acorde (ex.: Introdução, Refrão), use chaves: '
                            '{Refrão}.',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 4,
                      children: [
                        TextButton.icon(
                          onPressed: _pasteFromClipboard,
                          icon: const Icon(Icons.content_paste, size: 18),
                          label: const Text('Colar'),
                        ),
                        TextButton.icon(
                          onPressed: _importFile,
                          icon: const Icon(Icons.upload_file, size: 18),
                          label: const Text('Importar .txt'),
                        ),
                      ],
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 18,
                          ),
                        ),
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
}
