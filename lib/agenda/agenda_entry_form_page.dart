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
import '../util/agenda_area.dart';
import '../util/time_picker_24h.dart';
import '../widgets/date_field.dart';
import '../widgets/sibval_app_bar.dart';

/// Cadastro/edição de compromisso da Agenda (03/09/2026) — só chega aqui quem
/// lidera pelo menos um ministério (qualquer um, não precisa ser o
/// ministério-alvo, ver `AgendaPage`) ou é admin. Todo compromisso salvo aqui
/// (criação ou edição) entra/volta pra fila de aprovação
/// (`AgendaRepository.create`/`update` sempre gravam `status: pending`) —
/// só depois de aprovado é que ocupa o calendário de verdade.
///
/// [initialDate] pré-preenche Data (e Início/Término, quando o valor traz
/// hora de verdade) a partir do que já estava selecionado no calendário ao
/// tocar em "Novo Compromisso" — ignorado em modo edição, onde a data/hora
/// vem sempre do compromisso existente.
class AgendaEntryFormPage extends ConsumerStatefulWidget {
  const AgendaEntryFormPage({super.key, this.editing, this.initialDate});

  final AgendaEntry? editing;
  final DateTime? initialDate;

  @override
  ConsumerState<AgendaEntryFormPage> createState() =>
      _AgendaEntryFormPageState();
}

class _AgendaEntryFormPageState extends ConsumerState<AgendaEntryFormPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _audienceType = AgendaAudience.ministries;
  final Set<String> _selectedMinistryIds = {};
  String? _location;
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _multiDay = false;
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
      _audienceType = editing.audienceType;
      _selectedMinistryIds.addAll(editing.ministryIds);
      _startDate = DateTime(
        editing.startDateTime.year,
        editing.startDateTime.month,
        editing.startDateTime.day,
      );
      _endDate = DateTime(
        editing.endDateTime.year,
        editing.endDateTime.month,
        editing.endDateTime.day,
      );
      _multiDay = _endDate != _startDate;
      _startTime = TimeOfDay.fromDateTime(editing.startDateTime);
      _endTime = TimeOfDay.fromDateTime(editing.endDateTime);
    } else {
      // Pré-seleciona os ministérios que o criador lidera, só como
      // conveniência (03/09/2026: qualquer líder pode escolher qualquer
      // ministério/toda a igreja agora — isso não restringe nada, é só o
      // ponto de partida).
      _selectedMinistryIds.addAll(ref.read(myLedMinistryIdsProvider));
      final initial = widget.initialDate;
      if (initial != null) {
        _startDate = DateTime(initial.year, initial.month, initial.day);
        _endDate = _startDate;
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
        _dirty = true;
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
    final start = _combine(_startDate, _startTime);
    final end = _combine(_multiDay ? _endDate : _startDate, _endTime);
    if (start == null || end == null) {
      _showError('Informe data, horário de início e de término.');
      return;
    }
    if (!end.isAfter(start)) {
      _showError('O horário/data de término precisa ser depois do início.');
      return;
    }

    final catalogLocations = ref.read(agendaLocationsProvider).asData?.value ?? const [];
    final occupants = ref.read(agendaConflictItemsProvider);
    final conflicts = findAgendaConflicts(
      occupants,
      location: location,
      start: start,
      end: end,
      wholeVenue: wholeVenueLocationNames(catalogLocations),
      excludeId: widget.editing?.id,
    );
    if (conflicts.isNotEmpty) {
      final conflict = conflicts.first;
      final profileForMask = ref.read(currentUserProfileProvider).asData?.value;
      final visibleIds = {
        ...ref.read(myLedMinistryIdsProvider),
        ...ref.read(myMemberMinistryIdsProvider),
      };
      final masked = conflict.isMaskedFor(
        isAdmin: profileForMask?.isAdmin ?? false,
        isApprover: ref.read(isAgendaApproverProvider),
        visibleIds: visibleIds,
      );
      final proceed = await _confirmConflict(conflict, masked: masked);
      if (proceed != true) return;
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
      final entry = AgendaEntry(
        id: widget.editing?.id ?? '',
        audienceType: _audienceType,
        ministryIds: _audienceType == AgendaAudience.wholeChurch
            ? const []
            : _selectedMinistryIds.toList(),
        ministryNames: ministryNames,
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
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Enviado para aprovação'),
          content: const Text(
            'O compromisso foi enviado para aprovação. Assim que for aprovado ou '
            'rejeitado, você recebe uma notificação.',
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

  Future<bool?> _confirmConflict(AgendaCalendarItem conflict, {required bool masked}) {
    final label = masked ? 'Restrito' : conflict.title;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Conflito de horário'),
        content: Text(
          '${conflict.isEvent ? 'O evento' : 'Já existe um compromisso'} "$label" '
          'ocupa "${conflict.location}" nesse horário '
          '(${_timeFormat.format(conflict.start)} às ${_timeFormat.format(conflict.end)}). '
          'Deseja continuar mesmo assim?',
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
    final catalogLocations = ref.watch(agendaLocationsProvider).asData?.value ?? const [];
    final locationItems = locationItemsFor(catalogLocations, extra: _location);

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
                Text('Destinado a', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Ministério(s) específico(s)'),
                        selected: _audienceType == AgendaAudience.ministries,
                        onSelected: (_) => setState(() {
                          _audienceType = AgendaAudience.ministries;
                          _dirty = true;
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Toda a igreja'),
                        selected: _audienceType == AgendaAudience.wholeChurch,
                        onSelected: (_) => setState(() {
                          _audienceType = AgendaAudience.wholeChurch;
                          _dirty = true;
                        }),
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
                    hintText: 'Ex.: Ensaio, Reunião de líderes',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _location,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Local/Área'),
                  items: [
                    for (final name in locationItems)
                      DropdownMenuItem(value: name, child: Text(name)),
                  ],
                  onChanged: (value) => setState(() {
                    _location = value;
                    _dirty = true;
                  }),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Vários dias'),
                  value: _multiDay,
                  onChanged: (value) => setState(() {
                    _multiDay = value ?? false;
                    if (!_multiDay) _endDate = _startDate;
                    _dirty = true;
                  }),
                ),
                DateField(
                  label: _multiDay ? 'De' : 'Data',
                  value: _startDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime(DateTime.now().year + 2),
                  onChanged: (date) => setState(() {
                    _startDate = date;
                    if (!_multiDay ||
                        (_endDate != null && date != null && _endDate!.isBefore(date))) {
                      _endDate = date;
                    }
                    _dirty = true;
                  }),
                ),
                if (_multiDay) ...[
                  const SizedBox(height: 16),
                  DateField(
                    label: 'Até',
                    value: _endDate,
                    firstDate: _startDate ?? DateTime.now(),
                    lastDate: DateTime(DateTime.now().year + 2),
                    onChanged: (date) => setState(() {
                      _endDate = date;
                      _dirty = true;
                    }),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _TimeField(
                        label: 'Início',
                        value: _startTime,
                        onChanged: (time) => setState(() {
                          _startTime = time;
                          // Preenche o término com +1h por padrão — o campo
                          // continua editável depois, esta escolha só serve
                          // de ponto de partida.
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
                      : const Text('Enviar para aprovação'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mesmo padrão de `_MinistryPickerDialog` em `message_form_page.dart`/
/// `members_page.dart` — checklist em diálogo, sem restringir a lista aos
/// ministérios liderados (03/09/2026: qualquer líder pode escolher qualquer
/// ministério).
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

/// Campo de horário, mesmo estilo visual de `DateField` — toque abre
/// `showTimePicker` nativo (mesmo padrão de `_TimeField` em
/// `service_order_form_page.dart`, duplicado localmente).
class _TimeField extends StatelessWidget {
  const _TimeField({required this.label, required this.value, required this.onChanged});

  final String label;
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay?> onChanged;

  Future<void> _open(BuildContext context) async {
    final picked = await showTimePicker24h(
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
