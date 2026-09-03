import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/agenda_location_repository.dart';
import '../data/agenda_repository.dart';
import '../data/ministry_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../data/user_repository.dart';
import '../models/agenda_entry.dart';
import '../theme/app_theme.dart';
import '../widgets/date_field.dart';
import '../widgets/sibval_app_bar.dart';

/// Cadastro/edição de compromisso da Agenda (03/09/2026) — só chega aqui quem
/// tem pelo menos um ministério em [manageableMinistryIds] (líder do
/// ministério, ou admin — checado por `AgendaPage`). Se [editing] vier
/// preenchido, edita esse compromisso em vez de criar um novo.
///
/// [initialDate] pré-preenche Data (e Início/Término, quando o valor traz
/// hora de verdade) a partir do que já estava selecionado no calendário ao
/// tocar em "Novo Compromisso" (03/09/2026, pedido do usuário) — ignorado em
/// modo edição, onde a data/hora vem sempre do compromisso existente.
class AgendaEntryFormPage extends ConsumerStatefulWidget {
  const AgendaEntryFormPage({
    super.key,
    required this.manageableMinistryIds,
    this.editing,
    this.initialDate,
  });

  final Set<String> manageableMinistryIds;
  final AgendaEntry? editing;
  final DateTime? initialDate;

  @override
  ConsumerState<AgendaEntryFormPage> createState() =>
      _AgendaEntryFormPageState();
}

class _AgendaEntryFormPageState extends ConsumerState<AgendaEntryFormPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _ministryId;
  String? _location;
  DateTime? _date;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _dirty = false;
  bool _saving = false;

  bool get _isEditing => widget.editing != null;

  static final _timeFormat = DateFormat('HH:mm', 'pt_BR');

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _titleController.text = editing.title;
      _descriptionController.text = editing.description;
      _location = editing.location.isEmpty ? null : editing.location;
      _ministryId = editing.ministryId;
      _date = DateTime(
        editing.startDateTime.year,
        editing.startDateTime.month,
        editing.startDateTime.day,
      );
      _startTime = TimeOfDay.fromDateTime(editing.startDateTime);
      _endTime = TimeOfDay.fromDateTime(editing.endDateTime);
    } else {
      if (widget.manageableMinistryIds.length == 1) {
        _ministryId = widget.manageableMinistryIds.first;
      }
      final initial = widget.initialDate;
      if (initial != null) {
        _date = DateTime(initial.year, initial.month, initial.day);
        // Só puxa horário quando a seleção do calendário já trazia hora de
        // verdade (toque em Dia/Semana) — meia-noite exata é o que o
        // Syncfusion também usa pra "só a data" (toque em Mês, ou a faixa
        // de semana da Agenda), então não teria como distinguir das duas
        // situações; nesse caso o horário fica em branco pro usuário
        // escolher, como já era antes desta mudança.
        if (initial.hour != 0 || initial.minute != 0) {
          _startTime = TimeOfDay(hour: initial.hour, minute: initial.minute);
          _endTime = TimeOfDay(hour: (initial.hour + 1) % 24, minute: initial.minute);
        }
      }
    }
    _titleController.addListener(_markDirty);
    _descriptionController.addListener(_markDirty);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair sem salvar?'),
        content: const Text('As alterações feitas serão perdidas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Continuar editando'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sair sem salvar'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  DateTime? _combine(DateTime? date, TimeOfDay? time) {
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final location = _location ?? '';
    if (_ministryId == null) {
      _showError('Selecione o ministério.');
      return;
    }
    if (title.isEmpty) {
      _showError('Informe um título.');
      return;
    }
    if (location.isEmpty) {
      _showError('Selecione o local/área.');
      return;
    }
    final start = _combine(_date, _startTime);
    final end = _combine(_date, _endTime);
    if (start == null || end == null) {
      _showError('Informe data, horário de início e de término.');
      return;
    }
    if (!end.isAfter(start)) {
      _showError('O horário de término precisa ser depois do início.');
      return;
    }

    final allEntries = ref.read(agendaEntriesProvider).asData?.value ?? const [];
    final conflicts = findAgendaConflicts(
      allEntries,
      location: location,
      start: start,
      end: end,
      excludeId: widget.editing?.id,
    );
    if (conflicts.isNotEmpty) {
      final proceed = await _confirmConflict(conflicts.first);
      if (proceed != true) return;
    }

    final ministries = ref.read(ministriesProvider).asData?.value ?? const [];
    final ministryName = ministries
        .firstWhere(
          (m) => m.id == _ministryId,
          orElse: () => ministries.first,
        )
        .name;
    final uid = ref.read(currentUidProvider) ?? '';
    final profile = ref.read(currentUserProfileProvider).asData?.value;

    setState(() => _saving = true);
    try {
      final entry = AgendaEntry(
        id: widget.editing?.id ?? '',
        ministryId: _ministryId!,
        ministryName: ministryName,
        title: title,
        description: _descriptionController.text.trim(),
        location: location,
        startDateTime: start,
        endDateTime: end,
        createdByUid: widget.editing?.createdByUid ?? uid,
        createdByName: widget.editing?.createdByName ?? (profile?.shortName ?? ''),
      );
      final repo = ref.read(agendaRepositoryProvider);
      if (widget.editing != null) {
        await repo.update(widget.editing!.id, entry);
      } else {
        await repo.create(entry);
      }
      if (!mounted) return;
      _dirty = false;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool?> _confirmConflict(AgendaEntry conflict) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Conflito de horário'),
        content: Text(
          '${conflict.ministryName} já reservou "${conflict.location}" nesse '
          'horário (${_timeFormat.format(conflict.startDateTime)} às '
          '${_timeFormat.format(conflict.endDateTime)}). Deseja continuar mesmo assim?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final allMinistries = ref.watch(ministriesProvider).asData?.value ?? const [];
    final manageable = allMinistries
        .where((m) => widget.manageableMinistryIds.contains(m.id))
        .toList();
    final catalogLocations = (ref.watch(agendaLocationsProvider).asData?.value ?? const [])
        .map((l) => l.name)
        .toList();
    // Defensivo: se o local salvo neste compromisso (edição) foi renomeado ou
    // excluído do catálogo depois, mantém ele na lista mesmo assim — senão o
    // `DropdownButtonFormField` quebra com um valor fora dos `items`.
    final locationItems = {
      ...catalogLocations,
      if (_location != null) _location!,
    }.toList()
      ..sort();

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmDiscard() && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: const SibValAppBar(isHome: false),
        body: SafeArea(
          bottom: true,
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ScreenTitle(_isEditing ? 'Editar compromisso' : 'Novo compromisso'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _ministryId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Ministério'),
                  items: [
                    for (final m in manageable)
                      DropdownMenuItem(value: m.id, child: Text(m.name)),
                  ],
                  onChanged: (value) => setState(() {
                    _ministryId = value;
                    _dirty = true;
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    hintText: 'Ex.: Ensaio, Reunião de líderes',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _location,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Local/Área',
                    hintText: locationItems.isEmpty ? 'Nenhum local cadastrado' : null,
                  ),
                  items: [
                    for (final name in locationItems)
                      DropdownMenuItem(value: name, child: Text(name)),
                  ],
                  onChanged: locationItems.isEmpty
                      ? null
                      : (value) => setState(() {
                          _location = value;
                          _dirty = true;
                        }),
                ),
                const SizedBox(height: 16),
                DateField(
                  label: 'Data',
                  value: _date,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime(DateTime.now().year + 2),
                  onChanged: (date) => setState(() {
                    _date = date;
                    _dirty = true;
                  }),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _TimeField(
                        label: 'Início',
                        value: _startTime,
                        onChanged: (time) => setState(() {
                          _startTime = time;
                          // Preenche o término com +1h por padrão (03/09/2026,
                          // pedido do usuário) — o campo continua editável
                          // depois, esta escolha só serve de ponto de partida.
                          if (time != null) {
                            _endTime = TimeOfDay(
                              hour: (time.hour + 1) % 24,
                              minute: time.minute,
                            );
                          }
                          _dirty = true;
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TimeField(
                        label: 'Término',
                        value: _endTime,
                        onChanged: (time) => setState(() {
                          _endTime = time;
                          _dirty = true;
                        }),
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
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salvar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Campo de horário, mesmo estilo visual de `DateField` — toque abre
/// `showTimePicker` nativo (mesmo padrão de `_TimeField` em
/// `service_order_form_page.dart`, duplicado localmente).
class _TimeField extends StatelessWidget {
  const _TimeField({required this.label, required this.value, required this.onChanged});

  final String label;
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay?> onChanged;

  Future<void> _open(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: value ?? const TimeOfDay(hour: 19, minute: 0),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final text = value != null
        ? '${value!.hour.toString().padLeft(2, '0')}:${value!.minute.toString().padLeft(2, '0')}'
        : '';
    return InkWell(
      onTap: () => _open(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.access_time),
        ),
        child: Text(text, style: TextStyle(color: context.textPrimary)),
      ),
    );
  }
}

