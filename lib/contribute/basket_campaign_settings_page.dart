import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/basket_donation_repository.dart';
import '../models/basket_donation.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'basket_widgets.dart';

/// Opção escolhida no diálogo de "alterações não salvas" ao tentar voltar
/// (`_BasketCampaignSettingsPageState._confirmLeave`, 04/09/2026) — mesmo
/// padrão de `contribute_settings_page.dart`.
enum _LeaveAction { cancel, discard, save }

/// Configuração da campanha "Doe para Cestas Básicas" (04/09/2026) — chave
/// Pix, meta/arrecadação do mês, texto de "onde e quando entregar" e o
/// catálogo de itens necessários. Só chega aqui quem tem
/// `canManageBasketCampaign` (gate na engrenagem de `BasketCampaignPage`).
class BasketCampaignSettingsPage extends ConsumerStatefulWidget {
  const BasketCampaignSettingsPage({super.key, required this.initial});

  final BasketCampaignSettings initial;

  @override
  ConsumerState<BasketCampaignSettingsPage> createState() =>
      _BasketCampaignSettingsPageState();
}

class _BasketCampaignSettingsPageState
    extends ConsumerState<BasketCampaignSettingsPage> {
  late final _pixKeyController = TextEditingController(
    text: widget.initial.pixKey,
  );
  late final _goalController = TextEditingController(
    text: widget.initial.goalCount > 0 ? '${widget.initial.goalCount}' : '',
  );
  late final _collectedController = TextEditingController(
    text: widget.initial.collectedCount > 0
        ? '${widget.initial.collectedCount}'
        : '',
  );
  late final _deliveryController = TextEditingController(
    text: widget.initial.deliveryInfo,
  );

  bool _saving = false;

  /// `true` assim que qualquer dos 4 campos de texto muda — os itens do
  /// catálogo (`_showItemDialog`/`_confirmDeleteItem`) já gravam direto no
  /// Firestore ao confirmar, então não passam por este flag. Mesmo padrão de
  /// `contribute_settings_page.dart`.
  bool _dirty = false;

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _pixKeyController.dispose();
    _goalController.dispose();
    _collectedController.dispose();
    _deliveryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final settings = BasketCampaignSettings(
        pixKey: _pixKeyController.text.trim(),
        goalCount: int.tryParse(_goalController.text.trim()) ?? 0,
        collectedCount: int.tryParse(_collectedController.text.trim()) ?? 0,
        deliveryInfo: _deliveryController.text.trim(),
      );
      await ref.read(basketCampaignRepositoryProvider).update(settings);
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Configuração salva.')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Falha ao salvar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Diálogo mostrado ao tentar voltar com `_dirty` (04/09/2026, pedido do
  /// usuário) — mesmo padrão de `contribute_settings_page.dart`.
  Future<void> _confirmLeave() async {
    final action = await showDialog<_LeaveAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Alterações não salvas'),
        content: const Text(
          'Você tem alterações não salvas nesta tela. Deseja salvar antes de sair?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_LeaveAction.cancel),
            child: const Text('Continuar editando'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_LeaveAction.discard),
            child: const Text('Sair sem salvar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(_LeaveAction.save),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (action) {
      case _LeaveAction.discard:
        Navigator.of(context).pop();
      case _LeaveAction.save:
        await _save();
        if (mounted && !_dirty) Navigator.of(context).pop();
      case _LeaveAction.cancel:
      case null:
        break;
    }
  }

  Future<void> _showItemDialog({BasketFoodItem? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final unitController = TextEditingController(
      text: existing?.unit ?? 'pacotes',
    );
    final quantityController = TextEditingController(
      text: existing != null ? '${existing.neededQuantity}' : '',
    );
    var priority = existing?.priority ?? BasketPriority.media;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Novo item' : 'Editar item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nome (ex.: Arroz (5kg))',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: unitController,
                  decoration: const InputDecoration(
                    labelText: 'Unidade (ex.: pacotes, unidades)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Quantidade necessária',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<BasketPriority>(
                  initialValue: priority,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Prioridade'),
                  items: [
                    for (final p in BasketPriority.values)
                      DropdownMenuItem(value: p, child: Text(p.label)),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => priority = value ?? priority),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(existing == null ? 'Adicionar' : 'Salvar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    final name = nameController.text.trim();
    if (name.isEmpty) return;
    final unit = unitController.text.trim().isEmpty
        ? 'unidades'
        : unitController.text.trim();
    final quantity = int.tryParse(quantityController.text.trim()) ?? 0;
    final repo = ref.read(basketFoodItemRepositoryProvider);
    if (existing == null) {
      await repo.create(
        name: name,
        unit: unit,
        priority: priority,
        neededQuantity: quantity,
      );
    } else {
      await repo.update(
        BasketFoodItem(
          id: existing.id,
          name: name,
          unit: unit,
          priority: priority,
          neededQuantity: quantity,
          order: existing.order,
        ),
      );
    }
  }

  Future<void> _confirmDeleteItem(BasketFoodItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir item'),
        content: Text(
          'Tem certeza que deseja excluir "${item.name}" da lista?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(basketFoodItemRepositoryProvider).delete(item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(basketFoodItemsProvider);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmLeave();
      },
      child: Scaffold(
        appBar: const SibValAppBar(isHome: false),
        body: SafeArea(
          bottom: true,
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const ScreenTitle('Configurar Cestas Básicas'),
              TextField(
                controller: _pixKeyController,
                onChanged: (_) => _markDirty(),
                decoration: const InputDecoration(
                  labelText: 'Chave PIX para doações',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _goalController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => _markDirty(),
                      decoration: const InputDecoration(
                        labelText: 'Meta do mês (cestas)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _collectedController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => _markDirty(),
                      decoration: const InputDecoration(
                        labelText: 'Arrecadadas este mês',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _deliveryController,
                maxLines: 3,
                onChanged: (_) => _markDirty(),
                decoration: const InputDecoration(
                  labelText: 'Onde e quando entregar',
                  hintText: 'Ex.: Aos domingos, das 8h às 12h, ou durante o expediente da secretaria.',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Itens necessários',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showItemDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar item'),
                  ),
                ],
              ),
              itemsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Falha ao carregar: $error',
                    style: TextStyle(color: context.textPrimary),
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Nenhum item cadastrado ainda.',
                        style: TextStyle(color: context.textSecondary),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final item in items)
                        Card(
                          margin: const EdgeInsets.only(top: 8),
                          child: ListTile(
                            onTap: () => _showItemDialog(existing: item),
                            title: Text(
                              item.name,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                BasketPriorityBadge(priority: item.priority),
                                const SizedBox(width: 8),
                                Text(
                                  'Precisa de ${item.neededQuantity} ${item.unit}',
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Excluir',
                              onPressed: () => _confirmDeleteItem(item),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
