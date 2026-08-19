import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/post_repository.dart' show currentUidProvider;
import '../data/recurring_event_repository.dart';
import '../models/recurring_event.dart';
import '../models/recurring_event_flyer.dart' show RecurringEventCategory, recurringEventFlyerCategoryLabel;
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'recurring_event_utils.dart';

enum _EditScope { series, nextOnly }

/// Espelha RecurringEventFormFragment.kt/...ViewModel.kt: cria/edita o molde
/// de uma série recorrente (dia da semana + horário fixos). Sem flyer aqui —
/// o flyer de cada ocorrência vem do Repositório de Flyers pela categoria/data.
class RecurringEventFormPage extends ConsumerStatefulWidget {
  const RecurringEventFormPage({super.key, this.recurringEventId = ''});

  final String recurringEventId;

  @override
  ConsumerState<RecurringEventFormPage> createState() => _RecurringEventFormPageState();
}

class _RecurringEventFormPageState extends ConsumerState<RecurringEventFormPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  String? _category;
  int? _weekday;
  TimeOfDay? _time;
  int _reminderLeadMinutes = 360;
  bool _active = true;

  RecurringEvent? _editingEvent;
  bool _loadingEvent = false;
  bool _saving = false;

  static final _timeFormat = DateFormat('HH:mm', 'pt_BR');

  bool get _isEditing => widget.recurringEventId.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadingEvent = true);
    final event = await ref.read(recurringEventRepositoryProvider).getById(widget.recurringEventId);
    if (!mounted) return;
    if (event != null) {
      setState(() {
        _editingEvent = event;
        _titleController.text = event.title;
        _descriptionController.text = event.description;
        _locationController.text = event.location;
        _category = event.category;
        _weekday = event.weekday;
        _time = TimeOfDay(hour: event.hour, minute: event.minute);
        _reminderLeadMinutes = event.reminderLeadMinutes;
        _active = event.active;
      });
    }
    setState(() => _loadingEvent = false);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time ?? TimeOfDay.now());
    if (picked != null) setState(() => _time = picked);
  }

  bool _validate() {
    return _titleController.text.trim().isNotEmpty &&
        _descriptionController.text.trim().isNotEmpty &&
        _locationController.text.trim().isNotEmpty &&
        (_category?.isNotEmpty ?? false) &&
        _weekday != null &&
        _time != null;
  }

  Future<void> _save() async {
    if (!_validate()) {
      _showSnack('Preencha título, descrição, local, categoria, dia da semana e horário.');
      return;
    }
    if (_isEditing) {
      final scope = await showDialog<_EditScope>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Aplicar alterações'),
          content: const Text(
            'As mudanças valem para toda a série (a partir da próxima geração semanal) '
            'ou só para a próxima data já publicada?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(_EditScope.nextOnly),
              child: const Text('Só a próxima data'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(_EditScope.series),
              child: const Text('Toda a série'),
            ),
          ],
        ),
      );
      if (scope == null) return;
      await _performSave(scope);
    } else {
      await _performSave(_EditScope.series);
    }
  }

  Future<void> _performSave(_EditScope scope) async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(recurringEventRepositoryProvider);
      final existing = _editingEvent;
      if (existing != null) {
        final updated = existing.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          location: _locationController.text.trim(),
          category: _category,
          weekday: _weekday,
          hour: _time!.hour,
          minute: _time!.minute,
          reminderLeadMinutes: _reminderLeadMinutes,
          active: _active,
        );
        final deactivating = existing.active && !updated.active;
        if (scope == _EditScope.series) {
          await repo.update(updated);
          if (deactivating) await repo.cancelNextOccurrenceOnly(existing.id);
        } else {
          final applied = await repo.applyEditToUpcomingInstance(updated);
          if (applied) {
            if (deactivating) await repo.cancelNextOccurrenceOnly(existing.id);
          } else {
            _showSnack(
              'Ainda não há uma instância publicada para esta série; as alterações foram aplicadas à série toda.',
            );
            await repo.update(updated);
          }
        }
      } else {
        final uid = ref.read(currentUidProvider) ?? '';
        final newEvent = RecurringEvent(
          id: '',
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          location: _locationController.text.trim(),
          category: _category!,
          weekday: _weekday!,
          hour: _time!.hour,
          minute: _time!.minute,
          flyerUrl: '',
          flyerStoragePath: '',
          reminderLeadMinutes: _reminderLeadMinutes,
          active: true,
          createdBy: '',
          createdAt: null,
        );
        await repo.create(newEvent, uid);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _showSnack('Falha ao salvar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir'),
        content: const Text(
          'Excluir este evento recorrente? As instâncias já publicadas na agenda não serão '
          'removidas, mas nenhuma nova será gerada.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await ref.read(recurringEventRepositoryProvider).delete(_editingEvent!);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _showSnack('Falha ao excluir: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? 'Editar evento recorrente' : 'Novo evento recorrente';

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: _loadingEvent
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScreenTitle(title),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(labelText: 'Título'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(labelText: 'Descrição'),
                          maxLines: 4,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _locationController,
                          decoration: const InputDecoration(labelText: 'Local'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _category,
                          decoration: const InputDecoration(labelText: 'Categoria'),
                          items: [
                            for (final category in RecurringEventCategory.all)
                              DropdownMenuItem(value: category, child: Text(recurringEventFlyerCategoryLabel(category))),
                          ],
                          onChanged: (value) => setState(() => _category = value),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: _weekday,
                          decoration: const InputDecoration(labelText: 'Dia da semana'),
                          items: [
                            for (final entry in weekdayLabels)
                              DropdownMenuItem(value: entry.$1, child: Text(entry.$2)),
                          ],
                          onChanged: (value) => setState(() => _weekday = value),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: _pickTime,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Horário',
                              suffixIcon: Icon(Icons.access_time_outlined),
                            ),
                            child: Text(
                              _time != null
                                  ? _timeFormat.format(DateTime(2000, 1, 1, _time!.hour, _time!.minute))
                                  : '',
                              style: TextStyle(color: context.textPrimary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: _reminderLeadMinutes,
                          decoration: const InputDecoration(labelText: 'Lembrar com antecedência'),
                          items: [
                            for (final entry in reminderLeadLabels)
                              DropdownMenuItem(value: entry.$1, child: Text(entry.$2)),
                          ],
                          onChanged: (value) => setState(() => _reminderLeadMinutes = value ?? _reminderLeadMinutes),
                        ),
                        if (_isEditing) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: Text('Ativo', style: TextStyle(color: context.textPrimary))),
                              Switch(value: _active, onChanged: (value) => setState(() => _active = value)),
                            ],
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Salvar'),
                          ),
                        ),
                        if (_isEditing) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: _saving ? null : _confirmDelete,
                              child: const Text('Excluir'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
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
