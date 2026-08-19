import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/devotional_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

/// Espelha DevotionalFormFragment.kt/...ViewModel.kt: cadastro/edição de
/// devocional (título, data, texto, autor). Sem `devotionalId` é criação;
/// com `devotionalId` carrega os dados existentes e vira edição.
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
  DateTime? _selectedDate;
  bool _loading = false;
  bool _saving = false;

  static final _dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final devotional = await ref.read(devotionalRepositoryProvider).getById(widget.devotionalId!);
    if (!mounted) return;
    if (devotional != null) {
      _titleController.text = devotional.title;
      _textController.text = devotional.text;
      _authorController.text = devotional.author;
      _selectedDate = DateTime.fromMillisecondsSinceEpoch(devotional.dateMillis);
    }
    setState(() => _loading = false);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
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

    setState(() => _saving = true);
    try {
      final repository = ref.read(devotionalRepositoryProvider);
      if (widget.isEditing) {
        await repository.update(id: widget.devotionalId!, title: title, date: date, text: text, author: author);
      } else {
        await repository.create(title: title, date: date, text: text, author: author);
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
                        InkWell(
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Data de publicação',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today_outlined),
                            ),
                            child: Text(
                              _selectedDate != null ? _dateFormat.format(_selectedDate!) : '',
                              style: TextStyle(color: context.textPrimary),
                            ),
                          ),
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
