import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/devotional_repository.dart';
import '../models/devotional.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'devotional_form_page.dart';

/// Espelha DevotionalRepositoryFragment.kt/...ViewModel.kt/...Adapter.kt:
/// todas as devocionais cadastradas (inclusive futuras), agrupadas por mês,
/// com toque para editar e toque longo para excluir. Só quem tem
/// `canManageDevotionals` chega aqui (o gate fica no FAB da lista pública).
class DevotionalRepositoryPage extends ConsumerWidget {
  const DevotionalRepositoryPage({super.key});

  static final _monthYearFormat = DateFormat('MMMM yyyy', 'pt_BR');
  static final _dateFormat = DateFormat("d 'de' MMMM 'de' yyyy", 'pt_BR');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devotionalsAsync = ref.watch(devotionalRepositoryListProvider);

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      floatingActionButton: FloatingActionButton(
        heroTag: 'devotional_repository_fab',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DevotionalFormPage()),
        ),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenTitle('Repositório de Devocionais'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(devotionalRepositoryListProvider.future),
              child: devotionalsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ListView(
                  children: [
                    const SizedBox(height: 80),
                    Center(child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary))),
                  ],
                ),
                data: (devotionals) {
                  if (devotionals.isEmpty) {
                    return ListView(
                      children: [
                        const SizedBox(height: 80),
                        Center(
                          child:
                              Text('Nenhuma devocional cadastrada ainda.', style: TextStyle(color: context.textSecondary)),
                        ),
                      ],
                    );
                  }
                  final rows = _groupByMonth(devotionals);
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      if (row is _MonthHeaderRow) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                          child: Text(
                            row.label,
                            style: TextStyle(
                              color: SibValColors.goldAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        );
                      }
                      final devotional = (row as _DevotionalItemRow).devotional;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            devotional.baseReference == null
                                ? devotional.title
                                : '${devotional.title} (${devotional.baseReference})',
                            style: TextStyle(color: context.textPrimary),
                          ),
                          subtitle: Text(
                            '${_dateFormat.format(DateTime.fromMillisecondsSinceEpoch(devotional.dateMillis))} — ${devotional.author}',
                            style: TextStyle(color: context.textSecondary),
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => DevotionalFormPage(devotionalId: devotional.id)),
                          ),
                          onLongPress: () => _confirmDelete(context, ref, devotional),
                          trailing: IconButton(
                            icon: const Icon(Icons.content_copy_outlined),
                            tooltip: 'Copiar para outra data',
                            onPressed: () => _copyToAnotherDate(context, ref, devotional),
                          ),
                        ),
                      );
                    },
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

  List<_DevotionalRepositoryRow> _groupByMonth(List<Devotional> devotionals) {
    final rows = <_DevotionalRepositoryRow>[];
    String? lastLabel;
    for (final devotional in devotionals) {
      final date = DateTime.fromMillisecondsSinceEpoch(devotional.dateMillis);
      final label = _capitalize(_monthYearFormat.format(date));
      if (label != lastLabel) {
        rows.add(_MonthHeaderRow(label));
        lastLabel = label;
      }
      rows.add(_DevotionalItemRow(devotional));
    }
    return rows;
  }

  String _capitalize(String text) => text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

  /// "Copiar para outra data" (04/09/2026, pedido do usuário) — pede a nova
  /// data num `showDatePicker`, cria a cópia (`DevotionalRepository.copyTo`)
  /// e abre `DevotionalFormPage` já nela, pra ajustes finos antes de
  /// considerar pronta. O original não é tocado.
  Future<void> _copyToAnotherDate(
    BuildContext context,
    WidgetRef ref,
    Devotional devotional,
  ) async {
    final now = DateTime.now();
    final newDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      helpText: 'Copiar "${devotional.title}" para qual data?',
    );
    if (newDate == null || !context.mounted) return;
    try {
      final newId = await ref
          .read(devotionalRepositoryProvider)
          .copyTo(sourceId: devotional.id, newDate: newDate);
      ref.invalidate(devotionalRepositoryListProvider);
      ref.invalidate(devotionalsProvider);
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DevotionalFormPage(devotionalId: newId)),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Falha ao copiar: $e')));
      }
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Devotional devotional) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir'),
        content: Text(devotional.title),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref.read(devotionalRepositoryProvider).delete(devotional.id);
              ref.invalidate(devotionalRepositoryListProvider);
              ref.invalidate(devotionalsProvider);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}

sealed class _DevotionalRepositoryRow {}

class _MonthHeaderRow extends _DevotionalRepositoryRow {
  _MonthHeaderRow(this.label);
  final String label;
}

class _DevotionalItemRow extends _DevotionalRepositoryRow {
  _DevotionalItemRow(this.devotional);
  final Devotional devotional;
}
