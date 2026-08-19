import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import 'event_category_utils.dart';
import 'event_filter.dart';

/// Espelha EventFilterBottomSheet.kt/dialog_event_filter.xml: filtro de data
/// (só um por vez), tipo de programação (inscrições abertas/gratuito, só um
/// por vez) e categorias (múltipla escolha). Retorna o [EventFilter]
/// escolhido ao chamar Navigator.pop, ou nada se o usuário só fechar o sheet.
class EventFilterSheet extends StatefulWidget {
  const EventFilterSheet({super.key, required this.initialFilter});

  final EventFilter initialFilter;

  @override
  State<EventFilterSheet> createState() => _EventFilterSheetState();
}

class _EventFilterSheetState extends State<EventFilterSheet> {
  late EventDateFilter _dateFilter = widget.initialFilter.dateFilter;
  late int? _customDateMillis = widget.initialFilter.customDateMillis;
  late EventRegistrationFilter _registrationFilter = widget.initialFilter.registrationFilter;
  late final Set<String> _categories = {...widget.initialFilter.categories};

  static final _dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final initial = _customDateMillis != null ? DateTime.fromMillisecondsSinceEpoch(_customDateMillis!) : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _dateFilter = EventDateFilter.custom;
        _customDateMillis = picked.millisecondsSinceEpoch;
      });
    }
  }

  void _toggleDateFilter(EventDateFilter filter) {
    if (filter == EventDateFilter.custom) {
      if (_dateFilter == EventDateFilter.custom) {
        setState(() => _dateFilter = EventDateFilter.none);
      } else {
        _pickCustomDate();
      }
      return;
    }
    setState(() => _dateFilter = _dateFilter == filter ? EventDateFilter.none : filter);
  }

  void _toggleRegistrationFilter(EventRegistrationFilter filter) {
    setState(() => _registrationFilter = _registrationFilter == filter ? EventRegistrationFilter.any : filter);
  }

  void _toggleCategory(String category, bool selected) {
    setState(() {
      if (selected) {
        _categories.add(category);
      } else {
        _categories.remove(category);
      }
    });
  }

  String get _customDateLabel =>
      _dateFilter == EventDateFilter.custom && _customDateMillis != null
          ? _dateFormat.format(DateTime.fromMillisecondsSinceEpoch(_customDateMillis!))
          : 'Selecionar data';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Data', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: const Text('Hoje'),
                  selected: _dateFilter == EventDateFilter.today,
                  onSelected: (_) => _toggleDateFilter(EventDateFilter.today),
                ),
                ChoiceChip(
                  label: const Text('Esta semana'),
                  selected: _dateFilter == EventDateFilter.thisWeek,
                  onSelected: (_) => _toggleDateFilter(EventDateFilter.thisWeek),
                ),
                ChoiceChip(
                  label: const Text('Este mês'),
                  selected: _dateFilter == EventDateFilter.thisMonth,
                  onSelected: (_) => _toggleDateFilter(EventDateFilter.thisMonth),
                ),
                ChoiceChip(
                  label: const Text('Próximo mês'),
                  selected: _dateFilter == EventDateFilter.nextMonth,
                  onSelected: (_) => _toggleDateFilter(EventDateFilter.nextMonth),
                ),
                ChoiceChip(
                  label: Text(_customDateLabel),
                  selected: _dateFilter == EventDateFilter.custom,
                  onSelected: (_) => _toggleDateFilter(EventDateFilter.custom),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Tipo de programação', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: const Text('Inscrições abertas'),
                  selected: _registrationFilter == EventRegistrationFilter.requires,
                  onSelected: (_) => _toggleRegistrationFilter(EventRegistrationFilter.requires),
                ),
                ChoiceChip(
                  label: const Text('Gratuito'),
                  selected: _registrationFilter == EventRegistrationFilter.free,
                  onSelected: (_) => _toggleRegistrationFilter(EventRegistrationFilter.free),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Categoria', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final entry in eventCategoryLabels)
                  FilterChip(
                    label: Text(entry.$2),
                    selected: _categories.contains(entry.$1),
                    onSelected: (selected) => _toggleCategory(entry.$1, selected),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(const EventFilter()),
                  child: const Text('Limpar filtros'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(
                    EventFilter(
                      dateFilter: _dateFilter,
                      customDateMillis: _dateFilter == EventDateFilter.custom ? _customDateMillis : null,
                      registrationFilter: _registrationFilter,
                      categories: _categories,
                    ),
                  ),
                  child: const Text('Aplicar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
