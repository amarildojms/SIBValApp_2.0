import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/agenda_location_repository.dart';
import '../data/agenda_repository.dart' show myLedMinistryIdsProvider;
import '../data/ministry_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../data/recurring_agenda_entry_repository.dart';
import '../data/user_repository.dart';
import '../events/recurring_event_utils.dart' show weekdayLabels;
import '../models/agenda_entry.dart' show AgendaAudience;
import '../models/recurring_agenda_entry.dart';
import '../models/recurring_event.dart' show EventDuration, eventDurationLabel;
import '../theme/app_theme.dart';
import '../util/agenda_area.dart';
import '../util/time_picker_24h.dart';
import '../widgets/sibval_app_bar.dart';

/// Solicitação de compromisso recorrente (03/09/2026, 2ª rodada, pedido do
/// usuário: "Deve ser possível solicitar um agendamento recorrente (Ex.: um
/// ensaio todo sábado mesmo horário)") — a série inteira passa por
/// aprovação uma vez (`AgendaApprovalPage`, aba "Séries recorrentes"); a
/// partir daí uma Cloud Function gera as ocorrências semanais já aprovadas
/// (`RecurringAgendaEntryRepository`).
class RecurringAgendaEntryFormPage extends ConsumerStatefulWidget {
  const RecurringAgendaEntryFormPage({super.key});

  @override
  ConsumerState<RecurringAgendaEntryFormPage> createState() =>
      _RecurringAgendaEntryFormPageState();
}

class _RecurringAgendaEntryFormPageState
    extends ConsumerState<RecurringAgendaEntryFormPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _audienceType = AgendaAudience.ministries;
  final Set<String> _selectedMinistryIds = {};
  String? _location;
  int? _weekday;
  TimeOfDay? _time;
  int _durationMinutes = 60;
  bool _saving = false;

  static final _timeFormat = DateFormat('HH:mm', 'pt_BR');

  @override
  void initState() {
    super.initState();
    _selectedMinistryIds.addAll(ref.read(myLedMinistryIdsProvider));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker24h(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 19, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickMinistries(List<Ministry> allMinistries) async {
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _MinistryPickerDialog(
        ministries: allMinistries,
        initiallySelected: _selectedMinistryIds,
      ),
    );
    if (result != null) {
      setState(() {
        _selectedMinistryIds
          ..clear()
          ..addAll(result);
      });
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final location = _location ?? '';
    if (title.isEmpty) {
      _showError('Informe um título.');
      return;
    }
    if (_audienceType == AgendaAudience.ministries && _selectedMinistryIds.isEmpty) {
      _showError('Selecione pelo menos um ministério, ou marque "Toda a igreja".');
      return;
    }
    if (location.isEmpty) {
      _showError('Selecione o local/área.');
      return;
    }
    if (_weekday == null || _time == null) {
      _showError('Informe o dia da semana e o horário.');
      return;
    }

    final ministries = ref.read(ministriesProvider).asData?.value ?? const [];
    final ministryNames = _audienceType == AgendaAudience.wholeChurch
        ? const <String>[]
        : [
            for (final id in _selectedMinistryIds)
              ministries.firstWhere((m) => m.id == id, orElse: () => ministries.first).name,
          ];
    final uid = ref.read(currentUidProvider) ?? '';
    final profile = ref.read(currentUserProfileProvider).asData?.value;

    setState(() => _saving = true);
    try {
      final entry = RecurringAgendaEntry(
        id: '',
        audienceType: _audienceType,
        ministryIds:
            _audienceType == AgendaAudience.wholeChurch ? const [] : _selectedMinistryIds.toList(),
        ministryNames: ministryNames,
        title: title,
        description: _descriptionController.text.trim(),
        location: location,
        weekday: _weekday!,
        hour: _time!.hour,
        minute: _time!.minute,
        durationMinutes: _durationMinutes,
        createdByUid: uid,
        createdByName: profile?.shortName ?? '',
      );
      await ref.read(recurringAgendaEntryRepositoryProvider).create(entry);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Enviado para aprovação'),
          content: const Text(
            'A série recorrente foi enviada para aprovação. Assim que for '
            'aprovada ou rejeitada, você recebe uma notificação.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('OK')),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final allMinistries = ref.watch(ministriesProvider).asData?.value ?? const [];
    final catalogLocations = ref.watch(agendaLocationsProvider).asData?.value ?? const [];
    final locationItems = locationItemsFor(catalogLocations, extra: _location);

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenTitle('Compromisso recorrente'),
              const SizedBox(height: 4),
              Text(
                'Ex.: um ensaio toda semana, mesmo dia e horário.',
                style: TextStyle(color: context.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Text('Destinado a', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Ministério(s) específico(s)'),
                      selected: _audienceType == AgendaAudience.ministries,
                      onSelected: (_) => setState(() => _audienceType = AgendaAudience.ministries),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Toda a igreja'),
                      selected: _audienceType == AgendaAudience.wholeChurch,
                      onSelected: (_) => setState(() => _audienceType = AgendaAudience.wholeChurch),
                    ),
                  ),
                ],
              ),
              if (_audienceType == AgendaAudience.ministries) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: allMinistries.isEmpty ? null : () => _pickMinistries(allMinistries),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Selecionar ministérios',
                      suffixIcon: const Icon(Icons.arrow_drop_down),
                      hintText: allMinistries.isEmpty ? 'Nenhum ministério cadastrado' : null,
                    ),
                    child: Text(
                      allMinistries
                          .where((m) => _selectedMinistryIds.contains(m.id))
                          .map((m) => m.name)
                          .join(', '),
                      style: TextStyle(color: context.textPrimary),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aparece como "Restrito" pra quem não participa dos ministérios '
                  'acima, e só notifica quem participa (03/09/2026, pedido do usuário).',
                  style: TextStyle(color: context.textSecondary, fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  hintText: 'Ex.: Ensaio',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _location,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Local/Área'),
                items: [
                  for (final name in locationItems) DropdownMenuItem(value: name, child: Text(name)),
                ],
                onChanged: (value) => setState(() => _location = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _weekday,
                decoration: const InputDecoration(labelText: 'Dia da semana'),
                items: [
                  for (final entry in weekdayLabels)
                    DropdownMenuItem(value: entry.$1, child: Text(entry.$2)),
                ],
                onChanged: (value) => setState(() => _weekday = value),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
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
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _durationMinutes,
                      decoration: const InputDecoration(labelText: 'Duração'),
                      items: [
                        for (final minutes in EventDuration.presetsMinutes)
                          DropdownMenuItem(value: minutes, child: Text(eventDurationLabel(minutes))),
                      ],
                      onChanged: (value) =>
                          setState(() => _durationMinutes = value ?? _durationMinutes),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descrição (opcional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Enviar para aprovação'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mesmo padrão de `_MinistryPickerDialog` já duplicado por arquivo nesta
/// base (ver `agenda_entry_form_page.dart`/`message_form_page.dart`).
class _MinistryPickerDialog extends StatefulWidget {
  const _MinistryPickerDialog({required this.ministries, required this.initiallySelected});

  final List<Ministry> ministries;
  final Set<String> initiallySelected;

  @override
  State<_MinistryPickerDialog> createState() => _MinistryPickerDialogState();
}

class _MinistryPickerDialogState extends State<_MinistryPickerDialog> {
  late final _selected = {...widget.initiallySelected};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Selecionar ministérios'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final ministry in widget.ministries)
              CheckboxListTile(
                controlAffinity: ListTileControlAffinity.leading,
                value: _selected.contains(ministry.id),
                title: Text(ministry.name),
                onChanged: (checked) => setState(() {
                  if (checked ?? false) {
                    _selected.add(ministry.id);
                  } else {
                    _selected.remove(ministry.id);
                  }
                }),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.of(context).pop(_selected), child: const Text('Confirmar')),
      ],
    );
  }
}
