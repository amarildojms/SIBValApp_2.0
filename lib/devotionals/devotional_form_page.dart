import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bible_repository.dart';
import '../data/devotional_repository.dart';
import '../models/bible.dart';
import '../theme/app_theme.dart';
import '../util/scroll_to_save.dart';
import '../widgets/date_field.dart';
import '../widgets/sibval_app_bar.dart';

/// Espelha DevotionalFormFragment.kt/...ViewModel.kt: cadastro/edição de
/// devocional (título, data, texto, autor). Sem `devotionalId` é criação;
/// com `devotionalId` carrega os dados existentes e vira edição.
///
/// Texto base (26/08/2026, sem equivalente nativo, pedido do usuário): livro
/// + capítulo + versículo abaixo do título, opcional. Livro é digitável com
/// sugestões (mesmo padrão embutido-na-árvore de `_InvitedByField` em
/// `introduction_page.dart` — não `Autocomplete`, que já deu problema de
/// timing nesta base); capítulo/versículo são dropdowns alimentados pelo
/// banco da Bíblia (`bibleChapterCountProvider`/`bibleVersesProvider`), só
/// habilitados depois do livro/capítulo anterior estar resolvido. Versículo
/// virou uma faixa "de... até..." (27/08/2026, pedido do usuário) — "até" só
/// habilita depois de "de" escolhido, e só lista números maiores ou iguais.
class DevotionalFormPage extends ConsumerStatefulWidget {
  const DevotionalFormPage({super.key, this.devotionalId});

  final String? devotionalId;

  bool get isEditing => devotionalId != null;

  @override
  ConsumerState<DevotionalFormPage> createState() => _DevotionalFormPageState();
}

class _DevotionalFormPageState extends ConsumerState<DevotionalFormPage> {
  final _titleController = TextEditingController();
  final _textController = TextEditingController();
  final _authorController = TextEditingController();
  final _bookController = TextEditingController();
  final _bookFocusNode = FocusNode();
  final _scrollController = ScrollController();
  DateTime? _selectedDate;
  int? _baseBookId;
  int? _baseChapter;
  int? _baseVerseStart;
  int? _baseVerseEnd;
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _load();
    } else {
      _prefillDate();
    }
  }

  /// Pré-preenche a data de publicação com o dia seguinte à última devocional
  /// cadastrada (26/08/2026, pedido do usuário) — só faz sentido pra
  /// cadastro novo; edição carrega a data existente em `_load`.
  Future<void> _prefillDate() async {
    final latest = await ref.read(devotionalRepositoryProvider).getLatestDate();
    if (!mounted) return;
    setState(() {
      _selectedDate = latest != null ? latest.add(const Duration(days: 1)) : DateTime.now();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final devotional = await ref.read(devotionalRepositoryProvider).getById(widget.devotionalId!);
    if (!mounted) return;
    if (devotional != null) {
      _titleController.text = devotional.title;
      _textController.text = devotional.text;
      _authorController.text = devotional.author;
      _bookController.text = devotional.baseBookName;
      _selectedDate = DateTime.fromMillisecondsSinceEpoch(devotional.dateMillis);
      _baseBookId = devotional.baseBookId;
      _baseChapter = devotional.baseChapter;
      _baseVerseStart = devotional.baseVerseStart;
      _baseVerseEnd = devotional.baseVerseEnd ?? devotional.baseVerseStart;
    }
    setState(() => _loading = false);
  }

  void _onBookSelected(BibleBook book) {
    setState(() {
      _baseBookId = book.id;
      _baseChapter = null;
      _baseVerseStart = null;
      _baseVerseEnd = null;
    });
  }

  void _onBookTextEdited() {
    if (_baseBookId == null) return;
    setState(() {
      _baseBookId = null;
      _baseChapter = null;
      _baseVerseStart = null;
      _baseVerseEnd = null;
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final text = _textController.text.trim();
    final author = _authorController.text.trim();
    final date = _selectedDate;
    if (title.isEmpty || text.isEmpty || author.isEmpty || date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha o título, a data, o texto e o autor.')),
      );
      return;
    }

    final hasBaseText = _baseBookId != null && _baseChapter != null && _baseVerseStart != null;

    setState(() => _saving = true);
    _scrollController.scrollToSaveButton();
    try {
      final repository = ref.read(devotionalRepositoryProvider);
      if (widget.isEditing) {
        await repository.update(
          id: widget.devotionalId!,
          title: title,
          date: date,
          text: text,
          author: author,
          baseBookId: hasBaseText ? _baseBookId : null,
          baseBookName: hasBaseText ? _bookController.text.trim() : '',
          baseChapter: hasBaseText ? _baseChapter : null,
          baseVerseStart: hasBaseText ? _baseVerseStart : null,
          baseVerseEnd: hasBaseText ? (_baseVerseEnd ?? _baseVerseStart) : null,
        );
      } else {
        await repository.create(
          title: title,
          date: date,
          text: text,
          author: author,
          baseBookId: hasBaseText ? _baseBookId : null,
          baseBookName: hasBaseText ? _bookController.text.trim() : '',
          baseChapter: hasBaseText ? _baseChapter : null,
          baseVerseStart: hasBaseText ? _baseVerseStart : null,
          baseVerseEnd: hasBaseText ? (_baseVerseEnd ?? _baseVerseStart) : null,
        );
      }
      ref.invalidate(devotionalRepositoryListProvider);
      ref.invalidate(devotionalsProvider);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(widget.isEditing ? 'Devocional atualizada!' : 'Devocional salva!'),
          content: Text(
            widget.isEditing
                ? 'As alterações foram salvas com sucesso.'
                : 'A devocional foi publicada com sucesso.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    _authorController.dispose();
    _bookController.dispose();
    _bookFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScreenTitle(widget.isEditing ? 'Editar Devocional' : 'Cadastro de Devocionais'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(labelText: 'Título', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Texto base (opcional)',
                          style: TextStyle(color: context.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        _BaseBookField(
                          controller: _bookController,
                          focusNode: _bookFocusNode,
                          onSelected: _onBookSelected,
                          onEdited: _onBookTextEdited,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: _ChapterDropdown(
                                bookId: _baseBookId,
                                value: _baseChapter,
                                onChanged: (chapter) => setState(() {
                                  _baseChapter = chapter;
                                  _baseVerseStart = null;
                                  _baseVerseEnd = null;
                                }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _VerseDropdown(
                                label: 'De',
                                bookId: _baseBookId,
                                chapter: _baseChapter,
                                minValue: null,
                                value: _baseVerseStart,
                                onChanged: (verse) => setState(() {
                                  _baseVerseStart = verse;
                                  _baseVerseEnd = verse;
                                }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _VerseDropdown(
                                label: 'Até',
                                bookId: _baseVerseStart == null ? null : _baseBookId,
                                chapter: _baseVerseStart == null ? null : _baseChapter,
                                minValue: _baseVerseStart,
                                value: _baseVerseEnd,
                                onChanged: (verse) => setState(() => _baseVerseEnd = verse),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DateField(
                          label: 'Data de publicação',
                          value: _selectedDate,
                          firstDate: DateTime(DateTime.now().year - 5),
                          lastDate: DateTime(DateTime.now().year + 5),
                          decoration: const InputDecoration(border: OutlineInputBorder()),
                          onChanged: (date) => setState(() => _selectedDate = date),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _textController,
                          minLines: 6,
                          maxLines: 20,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                            labelText: 'Texto da devocional…',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _authorController,
                          decoration: const InputDecoration(labelText: 'Autor', border: OutlineInputBorder()),
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
                                : Text(widget.isEditing ? 'Salvar alterações' : 'Salvar'),
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

/// Campo de livro digitável com sugestões da Bíblia — toque no campo mostra
/// a lista inteira (66 livros, poucos o bastante pra não precisar filtrar
/// antes), digitar filtra por trecho do nome. Seleção só confirma o
/// `bookId` ao tocar numa sugestão ou ao perder o foco com um nome que bate
/// exatamente (case/acento-insensível) com um livro — texto parcial não
/// resolvido é tratado como "sem texto base" no `_save` do form.
class _BaseBookField extends ConsumerStatefulWidget {
  const _BaseBookField({
    required this.controller,
    required this.focusNode,
    required this.onSelected,
    required this.onEdited,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<BibleBook> onSelected;
  final VoidCallback onEdited;

  @override
  ConsumerState<_BaseBookField> createState() => _BaseBookFieldState();
}

class _BaseBookFieldState extends ConsumerState<_BaseBookField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    widget.focusNode.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    widget.focusNode.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!widget.focusNode.hasFocus) {
      final books = ref.read(bibleBooksProvider).asData?.value ?? const <BibleBook>[];
      final query = _normalizeBookName(widget.controller.text);
      if (query.isNotEmpty) {
        final exact = books.where((b) => _normalizeBookName(b.name) == query);
        if (exact.isNotEmpty) {
          widget.onSelected(exact.first);
          setState(() {});
          return;
        }
      }
    }
    setState(() {});
  }

  List<BibleBook> _matches(List<BibleBook> books) {
    final query = _normalizeBookName(widget.controller.text);
    if (query.isEmpty) return books;
    return books.where((b) => _normalizeBookName(b.name).contains(query)).toList();
  }

  void _select(BibleBook book) {
    widget.controller.text = book.name;
    widget.controller.selection = TextSelection.collapsed(offset: book.name.length);
    widget.onSelected(book);
    widget.focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(bibleBooksProvider).asData?.value ?? const <BibleBook>[];
    final matches = widget.focusNode.hasFocus ? _matches(books) : const <BibleBook>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (matches.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              // `canvasColor` é a mesma cor que o `DropdownButtonFormField` usa
              // pro fundo do popup de Capítulo/Versículo (sem override nosso) —
              // pedido do usuário pra lista de livros bater com essa cor em vez
              // de `cardColor` (mais claro no tema escuro).
              color: Theme.of(context).canvasColor,
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: matches.length,
              itemBuilder: (context, index) {
                final book = matches[index];
                return ListTile(
                  dense: true,
                  title: Text(book.name, style: TextStyle(color: context.textPrimary)),
                  onTap: () => _select(book),
                );
              },
            ),
          ),
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          decoration: const InputDecoration(
            labelText: 'Livro',
            hintText: 'Toque para escolher ou digite para buscar',
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.arrow_drop_down),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          onChanged: (_) => widget.onEdited(),
        ),
      ],
    );
  }
}

const _diacritics = 'áàãâäéèêëíìîïóòõôöúùûüçñ';
const _plainLetters = 'aaaaaeeeeiiiiooooouuuucn';

/// Case/acento-insensível — mesmo helper de `introduction_page.dart`
/// (`_normalizeName`), duplicado localmente por ser específico do arquivo.
String _normalizeBookName(String value) {
  var result = value.toLowerCase().trim();
  for (var i = 0; i < _diacritics.length; i++) {
    result = result.replaceAll(_diacritics[i], _plainLetters[i]);
  }
  return result;
}

class _ChapterDropdown extends ConsumerWidget {
  const _ChapterDropdown({required this.bookId, required this.value, required this.onChanged});

  final int? bookId;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = bookId == null ? 0 : (ref.watch(bibleChapterCountProvider(bookId!)).asData?.value ?? 0);
    return DropdownButtonFormField<int>(
      // Chave própria do estado carregado — sem ela, o valor pré-selecionado
      // (edição de devocional existente) não aparece: `initialValue` só é
      // lido no `initState` do `FormField` interno, e o primeiro build
      // acontece com `count == 0` (provider ainda carregando o banco da
      // Bíblia), antes do capítulo salvo poder ser validado contra o total.
      key: ValueKey('chapter-$bookId-$count'),
      initialValue: count > 0 && value != null && value! <= count ? value : null,
      decoration: const InputDecoration(
        labelText: 'Capítulo',
        border: OutlineInputBorder(),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
      items: [
        for (var chapter = 1; chapter <= count; chapter++)
          DropdownMenuItem(value: chapter, child: Text('$chapter')),
      ],
      onChanged: count == 0 ? null : onChanged,
    );
  }
}

/// Um lado da faixa "de... até..." — `minValue` (não nulo só no campo
/// "Até") restringe a lista aos versículos maiores ou iguais ao início da
/// faixa, pra não deixar montar um intervalo invertido.
class _VerseDropdown extends ConsumerWidget {
  const _VerseDropdown({
    required this.label,
    required this.bookId,
    required this.chapter,
    required this.minValue,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int? bookId;
  final int? chapter;
  final int? minValue;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verses = (bookId == null || chapter == null)
        ? const <BibleVerse>[]
        : ref.watch(bibleVersesProvider((bookId: bookId!, chapter: chapter!))).asData?.value ?? const <BibleVerse>[];
    final numbers = verses.map((v) => v.number).where((n) => minValue == null || n >= minValue!).toList();
    return DropdownButtonFormField<int>(
      // Mesmo motivo do `key` em `_ChapterDropdown` — força reconstruir o
      // `FormField` interno quando os versículos (ou o piso `minValue`)
      // mudam.
      key: ValueKey('verse-$label-$bookId-$chapter-$minValue-${numbers.length}'),
      initialValue: numbers.contains(value) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
      items: [
        for (final number in numbers) DropdownMenuItem(value: number, child: Text('$number')),
      ],
      onChanged: numbers.isEmpty ? null : onChanged,
    );
  }
}
