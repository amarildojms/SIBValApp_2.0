import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../data/event_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../models/event.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'event_category_utils.dart';

/// Espelha EventFormFragment.kt/EventFormViewModel.kt: cria/edita um evento
/// pontual. Se [eventId] vier vazio, é criação (publica direto). Se vier
/// preenchido, é edição — e se [reviewMode] for true, é a revisão de um
/// evento pendente (mostra Aprovar além de Salvar/Rejeitar).
class EventFormPage extends ConsumerStatefulWidget {
  const EventFormPage({super.key, this.eventId = '', this.reviewMode = false});

  final String eventId;
  final bool reviewMode;

  @override
  ConsumerState<EventFormPage> createState() => _EventFormPageState();
}

class _EventFormPageState extends ConsumerState<EventFormPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _registrationLinkController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isMultiDay = false;
  DateTime? _selectedEndDate;
  TimeOfDay? _selectedEndTime;
  String? _category;
  bool _requiresRegistration = false;
  File? _pickedFlyer;
  String _existingFlyerUrl = '';

  Event? _editingEvent;
  bool _loadingEvent = false;
  bool _saving = false;

  static final _dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');
  static final _timeFormat = DateFormat('HH:mm', 'pt_BR');

  bool get _isEditing => widget.eventId.isNotEmpty;

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
    _registrationLinkController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadingEvent = true);
    final event = await ref.read(eventRepositoryProvider).getById(widget.eventId);
    if (!mounted) return;
    if (event != null) {
      final localDate = event.dateTimeUtc.toLocal();
      final localEndDate = event.endDateTimeUtc.toLocal();
      setState(() {
        _editingEvent = event;
        _titleController.text = event.title;
        _descriptionController.text = event.description;
        _locationController.text = event.location;
        _existingFlyerUrl = event.flyerUrl;
        _selectedDate = DateTime(localDate.year, localDate.month, localDate.day);
        _selectedTime = TimeOfDay(hour: localDate.hour, minute: localDate.minute);
        _isMultiDay = event.isMultiDay;
        if (_isMultiDay) {
          _selectedEndDate = DateTime(localEndDate.year, localEndDate.month, localEndDate.day);
          _selectedEndTime = TimeOfDay(hour: localEndDate.hour, minute: localEndDate.minute);
        }
        _category = event.category;
        _requiresRegistration = event.requiresRegistration;
        _registrationLinkController.text = event.registrationLink;
      });
    }
    setState(() => _loadingEvent = false);
  }

  Future<void> _pickFlyer() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 82,
    );
    if (picked != null) setState(() => _pickedFlyer = File(picked.path));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _selectedTime ?? TimeOfDay.now());
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _pickEndDate() async {
    final base = _selectedDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedEndDate ?? base,
      firstDate: base,
      lastDate: DateTime(base.year + 5),
    );
    if (picked != null) setState(() => _selectedEndDate = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(context: context, initialTime: _selectedEndTime ?? _selectedTime ?? TimeOfDay.now());
    if (picked != null) setState(() => _selectedEndTime = picked);
  }

  int? get _dateTimeMillis {
    final date = _selectedDate;
    final time = _selectedTime;
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute).millisecondsSinceEpoch;
  }

  /// Sem "vários dias" marcado, o fim é igual ao início (evento de 1 dia só).
  int? get _endDateTimeMillis {
    if (!_isMultiDay) return _dateTimeMillis;
    final date = _selectedEndDate;
    final time = _selectedEndTime;
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute).millisecondsSinceEpoch;
  }

  bool _validate() {
    final hasFlyer = _pickedFlyer != null || _existingFlyerUrl.isNotEmpty;
    final start = _dateTimeMillis;
    final end = _endDateTimeMillis;
    return _titleController.text.trim().isNotEmpty &&
        _descriptionController.text.trim().isNotEmpty &&
        _locationController.text.trim().isNotEmpty &&
        start != null &&
        end != null &&
        end >= start &&
        (_category?.isNotEmpty ?? false) &&
        hasFlyer &&
        !(_requiresRegistration && _registrationLinkController.text.trim().isEmpty);
  }

  Event _buildEvent() {
    final base =
        _editingEvent ??
        const Event(
          id: '',
          title: '',
          description: '',
          location: '',
          dateTimeMillis: 0,
          endDateTimeMillis: 0,
          flyerUrl: '',
          flyerStoragePath: '',
          category: '',
          requiresRegistration: false,
          registrationLink: '',
          likedBy: [],
          status: EventStatus.published,
          source: EventSource.manual,
          createdBy: '',
          createdAt: null,
        );
    return base.copyWith(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      location: _locationController.text.trim(),
      dateTimeMillis: _dateTimeMillis,
      endDateTimeMillis: _endDateTimeMillis,
      category: _category,
      requiresRegistration: _requiresRegistration,
      registrationLink: _registrationLinkController.text.trim(),
    );
  }

  Future<void> _save() async {
    if (!_validate()) {
      _showSnack('Preencha título, descrição, local, data, hora, categoria e flyer (e confira se o fim não é antes do início).');
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(eventRepositoryProvider);
      if (_isEditing) {
        await repo.update(_buildEvent(), _pickedFlyer);
      } else {
        final uid = ref.read(currentUidProvider) ?? '';
        await repo.create(_buildEvent(), _pickedFlyer, uid);
      }
      if (!mounted) return;
      await _showResultDialog(
        title: _isEditing ? 'Evento atualizado!' : 'Evento salvo!',
        message: _isEditing ? 'As alterações foram salvas com sucesso.' : 'O evento foi publicado com sucesso.',
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _showSnack('Falha ao salvar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _approve() async {
    if (!_validate()) {
      _showSnack('Preencha título, descrição, local, data, hora, categoria e flyer (e confira se o fim não é antes do início).');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(eventRepositoryProvider).updateAndApprove(_buildEvent(), _pickedFlyer);
      if (!mounted) return;
      await _showResultDialog(title: 'Evento atualizado!', message: 'As alterações foram salvas com sucesso.');
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _showSnack('Falha ao aprovar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmReject() async {
    final reject = widget.reviewMode;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(reject ? 'Rejeitar' : 'Excluir'),
        content: Text(
          reject
              ? 'Rejeitar e excluir este evento pendente?'
              : 'Excluir este evento? Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(reject ? 'Rejeitar' : 'Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await ref.read(eventRepositoryProvider).delete(_editingEvent!);
      if (!mounted) return;
      await _showResultDialog(
        title: reject ? 'Rejeitar' : 'Excluir',
        message: reject ? 'O evento pendente foi rejeitado e removido.' : 'O evento foi excluído.',
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _showSnack('Falha ao excluir: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showResultDialog({required String title, required String message}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('OK'))],
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.reviewMode
        ? 'Revisar Evento'
        : _isEditing
        ? 'Editar Evento'
        : 'Novo Evento';

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
                        _buildFlyerPicker(context),
                        const SizedBox(height: 16),
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
                            for (final entry in eventCategoryLabels)
                              DropdownMenuItem(value: entry.$1, child: Text(entry.$2)),
                          ],
                          onChanged: (value) => setState(() => _category = value),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: _pickDate,
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Data',
                                    suffixIcon: Icon(Icons.calendar_today_outlined),
                                  ),
                                  child: Text(
                                    _selectedDate != null ? _dateFormat.format(_selectedDate!) : '',
                                    style: TextStyle(color: context.textPrimary),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: _pickTime,
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Hora',
                                    suffixIcon: Icon(Icons.access_time_outlined),
                                  ),
                                  child: Text(
                                    _selectedTime != null
                                        ? _timeFormat.format(
                                            DateTime(2000, 1, 1, _selectedTime!.hour, _selectedTime!.minute),
                                          )
                                        : '',
                                    style: TextStyle(color: context.textPrimary),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text('Evento de vários dias', style: TextStyle(color: context.textPrimary)),
                            ),
                            Switch(
                              value: _isMultiDay,
                              onChanged: (value) => setState(() => _isMultiDay = value),
                            ),
                          ],
                        ),
                        if (_isMultiDay) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: _pickEndDate,
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Data final',
                                      suffixIcon: Icon(Icons.calendar_today_outlined),
                                    ),
                                    child: Text(
                                      _selectedEndDate != null ? _dateFormat.format(_selectedEndDate!) : '',
                                      style: TextStyle(color: context.textPrimary),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: _pickEndTime,
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Hora final',
                                      suffixIcon: Icon(Icons.access_time_outlined),
                                    ),
                                    child: Text(
                                      _selectedEndTime != null
                                          ? _timeFormat.format(
                                              DateTime(2000, 1, 1, _selectedEndTime!.hour, _selectedEndTime!.minute),
                                            )
                                          : '',
                                      style: TextStyle(color: context.textPrimary),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text('Requer inscrição', style: TextStyle(color: context.textPrimary)),
                            ),
                            Switch(
                              value: _requiresRegistration,
                              onChanged: (value) => setState(() => _requiresRegistration = value),
                            ),
                          ],
                        ),
                        if (_requiresRegistration) ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: _registrationLinkController,
                            decoration: const InputDecoration(labelText: 'Link de inscrição'),
                          ),
                        ],
                        const SizedBox(height: 24),
                        _buildActions(context),
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

  Widget _buildFlyerPicker(BuildContext context) {
    return GestureDetector(
      onTap: _pickFlyer,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: _pickedFlyer != null
              ? Image.file(_pickedFlyer!, fit: BoxFit.cover)
              : _existingFlyerUrl.isNotEmpty
              ? Image.network(_existingFlyerUrl, fit: BoxFit.cover)
              : Icon(Icons.add_photo_alternate_outlined, color: context.textSecondary, size: 40),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Salvar'),
          ),
        ),
        if (widget.reviewMode) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(onPressed: _saving ? null : _approve, child: const Text('Aprovar')),
          ),
        ],
        if (_isEditing) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _saving ? null : _confirmReject,
              child: Text(widget.reviewMode ? 'Rejeitar' : 'Excluir'),
            ),
          ),
        ],
      ],
    );
  }
}
