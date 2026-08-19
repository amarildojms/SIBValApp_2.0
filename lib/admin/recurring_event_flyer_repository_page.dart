import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../data/recurring_event_flyer_repository.dart';
import '../models/recurring_event_flyer.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

/// Espelha RecurringEventFlyerRepositoryFragment.kt/...ViewModel.kt/...Adapter.kt:
/// grade de flyers cadastrados pra eventos recorrentes (CLA/EBD/CO/COO), mais a
/// categoria pseudo "Devocionais" (só usada pelo post automático de devocional).
/// Cada flyer é padrão da categoria (dateKey vazio) ou de uma data específica. Só
/// admin chega aqui (gate fica no tile do menu Mais).
class RecurringEventFlyerRepositoryPage extends ConsumerWidget {
  const RecurringEventFlyerRepositoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flyersAsync = ref.watch(recurringEventFlyersProvider);

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _FlyerFormSheet(),
        ),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenTitle('Repositório de Flyers'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(recurringEventFlyersProvider.future),
              child: flyersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ListView(
                  children: [
                    const SizedBox(height: 80),
                    Center(child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary))),
                  ],
                ),
                data: (flyers) {
                  if (flyers.isEmpty) {
                    return ListView(
                      children: [
                        const SizedBox(height: 80),
                        Center(
                          child:
                              Text('Nenhum flyer cadastrado ainda.', style: TextStyle(color: context.textSecondary)),
                        ),
                      ],
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.95,
                    ),
                    itemCount: flyers.length,
                    itemBuilder: (context, index) => _FlyerCard(flyer: flyers[index]),
                  );
                },
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _FlyerCard extends ConsumerWidget {
  const _FlyerCard({required this.flyer});

  final RecurringEventFlyer flyer;

  static final _dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeholderColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    final dateLabel = flyer.dateKey.isEmpty ? 'Padrão da categoria' : _formatDateKey(flyer.dateKey);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onLongPress: () => _confirmDelete(context, ref),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: flyer.flyerUrl.isNotEmpty
                  ? Image.network(
                      flyer.flyerUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Container(color: placeholderColor),
                    )
                  : Container(color: placeholderColor),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recurringEventFlyerCategoryLabel(flyer.category),
                    style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(dateLabel, style: TextStyle(color: context.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateKey(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length != 3) return dateKey;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return dateKey;
    return _dateFormat.format(DateTime(year, month, day));
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir'),
        content: const Text('Excluir este flyer do repositório?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref.read(recurringEventFlyerRepositoryProvider).delete(flyer);
              ref.invalidate(recurringEventFlyersProvider);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}

class _FlyerFormSheet extends ConsumerStatefulWidget {
  const _FlyerFormSheet();

  @override
  ConsumerState<_FlyerFormSheet> createState() => _FlyerFormSheetState();
}

class _FlyerFormSheetState extends ConsumerState<_FlyerFormSheet> {
  String? _category;
  bool _isDefault = false;
  DateTime? _selectedDate;
  File? _pickedFlyer;
  bool _saving = false;

  static final _dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');

  Future<void> _pickFlyer() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 82,
    );
    if (picked != null) {
      setState(() => _pickedFlyer = File(picked.path));
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    final category = _category;
    final file = _pickedFlyer;
    if (category == null || file == null || (!_isDefault && _selectedDate == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a categoria, a imagem e, se não for o padrão, a data.')),
      );
      return;
    }

    setState(() => _saving = true);
    final date = _selectedDate;
    final dateKey = _isDefault || date == null
        ? ''
        : '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    try {
      await ref.read(recurringEventFlyerRepositoryProvider).create(category: category, dateKey: dateKey, file: file);
      ref.invalidate(recurringEventFlyersProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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
            Text('Novo flyer', style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _pickFlyer,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: _pickedFlyer != null
                      ? Image.file(_pickedFlyer!, fit: BoxFit.cover)
                      : Icon(Icons.add_photo_alternate_outlined, color: context.textSecondary, size: 40),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _pickFlyer, child: const Text('Selecionar flyer')),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Categoria'),
              items: [
                for (final category in flyerRepositoryCategories)
                  DropdownMenuItem(value: category, child: Text(recurringEventFlyerCategoryLabel(category))),
              ],
              onChanged: (value) => setState(() => _category = value),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text('Usar como padrão da categoria', style: TextStyle(color: context.textPrimary))),
                Switch(value: _isDefault, onChanged: (value) => setState(() => _isDefault = value)),
              ],
            ),
            if (!_isDefault) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Data', suffixIcon: Icon(Icons.calendar_today_outlined)),
                  child: Text(
                    _selectedDate != null ? _dateFormat.format(_selectedDate!) : '',
                    style: TextStyle(color: context.textPrimary),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Salvar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
