import 'package:flutter/material.dart';

import '../models/basket_donation.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'basket_donation_confirm_page.dart';

class _DonationLine {
  _DonationLine({required this.item});

  final BasketFoodItem item;
  int quantity = 1;
}

/// "Informe o que você pretende doar" (04/09/2026) — segunda etapa do fluxo
/// de doação de alimentos: escolher itens do catálogo (ou um item avulso,
/// fora da lista pré-definida pelo admin) e a quantidade de cada um.
class BasketDonationFormPage extends StatefulWidget {
  const BasketDonationFormPage({super.key, required this.catalog});

  final List<BasketFoodItem> catalog;

  @override
  State<BasketDonationFormPage> createState() => _BasketDonationFormPageState();
}

class _BasketDonationFormPageState extends State<BasketDonationFormPage> {
  final List<_DonationLine> _lines = [];

  void _incrementQuantity(_DonationLine line, int delta) {
    setState(() {
      final next = line.quantity + delta;
      line.quantity = next < 1 ? 1 : next;
    });
  }

  void _removeLine(_DonationLine line) => setState(() => _lines.remove(line));

  Future<void> _addItem() async {
    final alreadyAdded = _lines.map((l) => l.item.id).toSet();
    final available = widget.catalog
        .where((item) => !alreadyAdded.contains(item.id))
        .toList();
    final chosen = await showModalBottomSheet<BasketFoodItem>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _AddItemSheet(available: available),
    );
    if (chosen == null) return;
    setState(() => _lines.add(_DonationLine(item: chosen)));
  }

  Future<void> _addCustomItem() async {
    final nameController = TextEditingController();
    final unitController = TextEditingController(text: 'unidades');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Outro item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nome do item'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: unitController,
              decoration: const InputDecoration(
                labelText: 'Unidade (ex.: pacotes, unidades)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final name = nameController.text.trim();
    if (name.isEmpty) return;
    final unit = unitController.text.trim().isEmpty
        ? 'unidades'
        : unitController.text.trim();
    setState(() {
      _lines.add(
        _DonationLine(
          item: BasketFoodItem(
            id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
            name: name,
            unit: unit,
            priority: BasketPriority.media,
            neededQuantity: 0,
          ),
        ),
      );
    });
  }

  void _continue() {
    final items = [
      for (final line in _lines)
        BasketDonationItem(
          itemId: line.item.id,
          itemName: line.item.name,
          unit: line.item.unit,
          quantity: line.quantity,
        ),
    ];
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BasketDonationConfirmPage(items: items),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Doar alimentos'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Text(
                    'Informe o que você pretende doar',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_lines.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Nenhum item adicionado ainda.',
                        style: TextStyle(color: context.textSecondary),
                      ),
                    )
                  else
                    Card(
                      child: Column(
                        children: [
                          for (var i = 0; i < _lines.length; i++) ...[
                            if (i > 0) const Divider(height: 1),
                            _LineTile(
                              line: _lines[i],
                              onIncrement: () =>
                                  _incrementQuantity(_lines[i], 1),
                              onDecrement: () =>
                                  _incrementQuantity(_lines[i], -1),
                              onRemove: () => _removeLine(_lines[i]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar outro item'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _addCustomItem,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Informar um item que não está na lista'),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _lines.isEmpty ? null : _continue,
                    child: const Text('Continuar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({
    required this.line,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  final _DonationLine line;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(line.item.name, style: TextStyle(color: context.textPrimary)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: onDecrement,
          ),
          Text(
            '${line.quantity}',
            style: TextStyle(
              color: context.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: onIncrement,
          ),
          const SizedBox(width: 4),
          Text(
            line.item.unit,
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onRemove,
            tooltip: 'Remover',
          ),
        ],
      ),
    );
  }
}

class _AddItemSheet extends StatelessWidget {
  const _AddItemSheet({required this.available});

  final List<BasketFoodItem> available;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Adicionar item',
              style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            if (available.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Todos os itens da lista já foram adicionados.',
                  style: TextStyle(color: context.textSecondary),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final item in available)
                      ListTile(
                        title: Text(item.name),
                        subtitle: Text(item.unit),
                        onTap: () => Navigator.of(context).pop(item),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
