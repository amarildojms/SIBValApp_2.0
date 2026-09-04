import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/agenda_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../data/user_repository.dart';
import '../models/agenda_entry.dart';
import '../theme/app_theme.dart';
import '../util/time_picker_24h.dart';
import '../widgets/date_field.dart';

/// Remanejar um compromisso aprovado — exclusivo do aprovador (03/09/2026, 2ª
/// rodada, pedido do usuário). Duas opções: o aprovador escolhe a nova
/// data/horário direto (`AgendaRepository.rescheduleDirect`), ou devolve pro
/// solicitante com uma mensagem pedindo pra escolher outra data
/// (`requestReschedule`, o solicitante edita e reenvia).
Future<void> showAgendaRescheduleSheet(
  BuildContext context,
  WidgetRef ref,
  AgendaEntry entry,
) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_calendar_outlined),
            title: const Text('Escolher nova data/horário'),
            onTap: () => Navigator.of(sheetContext).pop('direct'),
          ),
          ListTile(
            leading: const Icon(Icons.forward_to_inbox_outlined),
            title: const Text('Pedir para o solicitante remarcar'),
            onTap: () => Navigator.of(sheetContext).pop('message'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  if (choice == 'direct') {
    await _rescheduleDirect(context, ref, entry);
  } else if (choice == 'message') {
    await _requestReschedule(context, ref, entry);
  }
}

Future<void> _rescheduleDirect(BuildContext context, WidgetRef ref, AgendaEntry entry) async {
  final result = await showDialog<_DirectRescheduleResult>(
    context: context,
    builder: (_) => _DirectRescheduleDialog(entry: entry),
  );
  if (result == null) return;
  final profile = ref.read(currentUserProfileProvider).asData?.value;
  final uid = ref.read(currentUidProvider) ?? '';
  await ref.read(agendaRepositoryProvider).rescheduleDirect(
        entry.id,
        start: result.start,
        end: result.end,
        reason: result.reason,
        approverUid: uid,
        approverName: profile?.shortName ?? '',
      );
}

Future<void> _requestReschedule(BuildContext context, WidgetRef ref, AgendaEntry entry) async {
  final controller = TextEditingController();
  final message = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Pedir para remarcar'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 3,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Justificativa',
          hintText: 'Explique por que precisa remarcar e sugira um novo período.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () {
            final text = controller.text.trim();
            if (text.isEmpty) return;
            Navigator.of(dialogContext).pop(text);
          },
          child: const Text('Enviar'),
        ),
      ],
    ),
  );
  if (message == null || message.isEmpty) return;
  final profile = ref.read(currentUserProfileProvider).asData?.value;
  final uid = ref.read(currentUidProvider) ?? '';
  await ref.read(agendaRepositoryProvider).requestReschedule(
        entry.id,
        message: message,
        approverUid: uid,
        approverName: profile?.shortName ?? '',
      );
}

class _DirectRescheduleResult {
  const _DirectRescheduleResult(this.start, this.end, this.reason);
  final DateTime start;
  final DateTime end;
  final String reason;
}

class _DirectRescheduleDialog extends StatefulWidget {
  const _DirectRescheduleDialog({required this.entry});

  final AgendaEntry entry;

  @override
  State<_DirectRescheduleDialog> createState() => _DirectRescheduleDialogState();
}

class _DirectRescheduleDialogState extends State<_DirectRescheduleDialog> {
  late DateTime? _startDate = DateTime(
    widget.entry.startDateTime.year,
    widget.entry.startDateTime.month,
    widget.entry.startDateTime.day,
  );
  late DateTime? _endDate = DateTime(
    widget.entry.endDateTime.year,
    widget.entry.endDateTime.month,
    widget.entry.endDateTime.day,
  );
  late TimeOfDay? _startTime = TimeOfDay.fromDateTime(widget.entry.startDateTime);
  late TimeOfDay? _endTime = TimeOfDay.fromDateTime(widget.entry.endDateTime);
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker24h(
      context: context,
      initialTime: (isStart ? _startTime : _endTime) ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() => isStart ? _startTime = picked : _endTime = picked);
  }

  void _confirm() {
    final startDate = _startDate;
    final endDate = _endDate;
    final startTime = _startTime;
    final endTime = _endTime;
    if (startDate == null || endDate == null || startTime == null || endTime == null) return;
    final start = DateTime(startDate.year, startDate.month, startDate.day, startTime.hour, startTime.minute);
    final end = DateTime(endDate.year, endDate.month, endDate.day, endTime.hour, endTime.minute);
    if (!end.isAfter(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O término precisa ser depois do início.')),
      );
      return;
    }
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a justificativa do remanejamento.')),
      );
      return;
    }
    Navigator.of(context).pop(_DirectRescheduleResult(start, end, reason));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova data/horário'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DateField(
              label: 'De',
              value: _startDate,
              firstDate: DateTime.now().subtract(const Duration(days: 1)),
              lastDate: DateTime(DateTime.now().year + 2),
              onChanged: (date) => setState(() => _startDate = date),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _pickTime(isStart: true),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Início'),
                child: Text(
                  _startTime != null
                      ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
                      : '',
                  style: TextStyle(color: context.textPrimary),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DateField(
              label: 'Até',
              value: _endDate,
              firstDate: _startDate ?? DateTime.now(),
              lastDate: DateTime(DateTime.now().year + 2),
              onChanged: (date) => setState(() => _endDate = date),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _pickTime(isStart: false),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Término'),
                child: Text(
                  _endTime != null
                      ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
                      : '',
                  style: TextStyle(color: context.textPrimary),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Justificativa'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        TextButton(onPressed: _confirm, child: const Text('Remanejar')),
      ],
    );
  }
}
