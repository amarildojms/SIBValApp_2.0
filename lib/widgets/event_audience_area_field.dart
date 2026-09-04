import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/agenda_location_repository.dart';
import '../data/ministry_repository.dart';
import '../models/event.dart';
import '../theme/app_theme.dart';
import '../util/agenda_area.dart';

/// Par de campos "Destinado a" (`EventAudience`) + "Área da igreja" — mesma
/// lógica usada por `AgendaEntryFormPage`, compartilhada aqui entre
/// `EventFormPage` e `RecurringEventFormPage` (03/09/2026, pedido do
/// usuário: eventos pontuais/recorrentes ganham os dois campos pra poderem
/// ser enviados automaticamente pro calendário da Agenda). Diferente do
/// `_MinistryPickerDialog` duplicado por arquivo no resto desta base, este
/// widget é reaproveitado como um todo (audiência + área) porque as duas
/// telas de evento precisam do mesmíssimo comportamento — só o que
/// acontece com o valor final (`onChanged`) muda por chamador.
///
/// ALTERADO (03/09/2026, 4ª rodada, pedido do usuário): "Igreja e
/// comunidade" foi retirado — só restam "Toda a igreja" e "Ministério(s)
/// específico(s)" — e o par de botões Aberto/Restrito (`isOpen`) saiu daqui:
/// Aberto/Restrito deixou de ser uma escolha própria e passou a ser
/// derivado direto do "Destinado a" (Restrito = ministério(s) específico(s),
/// Aberto = toda a igreja), ver `AgendaCalendarItem.hasMinistryAudience`.
class EventAudienceAreaFields extends ConsumerStatefulWidget {
  const EventAudienceAreaFields({
    super.key,
    required this.audienceType,
    required this.ministryIds,
    required this.churchArea,
    required this.onChanged,
  });

  final String audienceType;
  final List<String> ministryIds;
  final String churchArea;

  /// Chamado a cada mudança com os 4 campos já resolvidos (nomes dos
  /// ministérios já denormalizados a partir de [ministryIds]).
  final void Function(
    String audienceType,
    List<String> ministryIds,
    List<String> ministryNames,
    String churchArea,
  )
  onChanged;

  @override
  ConsumerState<EventAudienceAreaFields> createState() => _EventAudienceAreaFieldsState();
}

class _EventAudienceAreaFieldsState extends ConsumerState<EventAudienceAreaFields> {
  late String _audienceType = widget.audienceType;
  late final Set<String> _ministryIds = {...widget.ministryIds};

  void _emit(List<Ministry> allMinistries) {
    final names = _audienceType == EventAudience.specificMinistries
        ? [
            for (final id in _ministryIds)
              allMinistries.firstWhere((m) => m.id == id, orElse: () => allMinistries.first).name,
          ]
        : const <String>[];
    widget.onChanged(
      _audienceType,
      _audienceType == EventAudience.specificMinistries ? _ministryIds.toList() : const [],
      names,
      widget.churchArea,
    );
  }

  Future<void> _pickMinistries(List<Ministry> allMinistries) async {
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _MinistryPickerDialog(ministries: allMinistries, initiallySelected: _ministryIds),
    );
    if (result != null) {
      setState(() {
        _ministryIds
          ..clear()
          ..addAll(result);
      });
      _emit(allMinistries);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allMinistries = ref.watch(ministriesProvider).asData?.value ?? const [];
    final catalogLocations = ref.watch(agendaLocationsProvider).asData?.value ?? const [];
    final locationItems = locationItemsFor(catalogLocations, extra: widget.churchArea);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Destinado a', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Toda a igreja'),
              selected: _audienceType == EventAudience.wholeChurch,
              onSelected: (_) {
                setState(() => _audienceType = EventAudience.wholeChurch);
                _emit(allMinistries);
              },
            ),
            ChoiceChip(
              label: const Text('Ministério(s) específico(s)'),
              selected: _audienceType == EventAudience.specificMinistries,
              onSelected: (_) {
                setState(() => _audienceType = EventAudience.specificMinistries);
                _emit(allMinistries);
              },
            ),
          ],
        ),
        if (_audienceType == EventAudience.specificMinistries) ...[
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
                allMinistries.where((m) => _ministryIds.contains(m.id)).map((m) => m.name).join(', '),
                style: TextStyle(color: context.textPrimary),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Aparece como "Restrito" pra quem não participa dos ministérios '
            'acima, e só notifica quem participa (03/09/2026, pedido do usuário).',
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: widget.churchArea.isEmpty ? null : widget.churchArea,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Área da igreja',
            hintText: 'Selecione "Fora da Igreja" se não for na igreja',
          ),
          items: [
            for (final name in locationItems) DropdownMenuItem(value: name, child: Text(name)),
          ],
          onChanged: (value) {
            widget.onChanged(
              _audienceType,
              _audienceType == EventAudience.specificMinistries ? _ministryIds.toList() : const [],
              _audienceType == EventAudience.specificMinistries
                  ? [
                      for (final id in _ministryIds)
                        allMinistries.firstWhere((m) => m.id == id, orElse: () => allMinistries.first).name,
                    ]
                  : const [],
              value ?? '',
            );
          },
        ),
      ],
    );
  }
}

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
