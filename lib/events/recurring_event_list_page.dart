import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../admin/recurring_event_flyer_repository_page.dart';
import '../data/recurring_event_repository.dart';
import '../data/user_repository.dart';
import '../models/recurring_event.dart';
import '../models/recurring_event_flyer.dart' show recurringEventFlyerCategoryLabel;
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'recurring_event_form_page.dart';
import 'recurring_event_utils.dart';

/// Espelha RecurringEventListFragment.kt/...ViewModel.kt: lista dos moldes de
/// série recorrente (não as instâncias já publicadas, que aparecem na aba
/// Programação Semanal). Só quem gerencia eventos chega aqui.
class RecurringEventListPage extends ConsumerWidget {
  const RecurringEventListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(recurringEventsProvider);
    final profileAsync = ref.watch(currentUserProfileProvider);
    final isAdmin = profileAsync.asData?.value?.isAdmin ?? false;

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      floatingActionButton: FloatingActionButton(
        heroTag: 'recurring_event_list_fab',
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RecurringEventFormPage()));
          ref.invalidate(recurringEventsProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenTitle('Eventos recorrentes'),
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.collections_outlined),
                  title: const Text('Repositório de Flyers'),
                  subtitle: const Text('Cadastre os flyers usados nas ocorrências semanais.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const RecurringEventFlyerRepositoryPage())),
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(recurringEventsProvider.future),
              child: eventsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ListView(
                  children: [
                    const SizedBox(height: 80),
                    Center(child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary))),
                  ],
                ),
                data: (events) {
                  if (events.isEmpty) {
                    return ListView(
                      children: [
                        const SizedBox(height: 80),
                        Center(
                          child: Text(
                            'Nenhum evento recorrente cadastrado.',
                            style: TextStyle(color: context.textSecondary),
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: events.length,
                    itemBuilder: (context, index) => _RecurringEventTile(event: events[index]),
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

class _RecurringEventTile extends ConsumerWidget {
  const _RecurringEventTile({required this.event});

  final RecurringEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hour = event.hour.toString().padLeft(2, '0');
    final minute = event.minute.toString().padLeft(2, '0');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => RecurringEventFormPage(recurringEventId: event.id)));
          ref.invalidate(recurringEventsProvider);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${weekdayLabel(event.weekday)}, $hour:$minute',
                      style: TextStyle(color: context.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      recurringEventFlyerCategoryLabel(event.category),
                      style: TextStyle(color: context.textTertiary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch(
                value: event.active,
                onChanged: (value) => _onActiveChanged(context, ref, value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onActiveChanged(BuildContext context, WidgetRef ref, bool active) async {
    final repo = ref.read(recurringEventRepositoryProvider);
    if (active) {
      await repo.setActive(event.id, true);
      ref.invalidate(recurringEventsProvider);
      return;
    }
    final choice = await showDialog<_DeactivateChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Desativar evento recorrente'),
        content: const Text(
          'Desativar toda a série (para de gerar novas ocorrências) ou só a próxima data '
          '(a série continua ativa nas semanas seguintes)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(_DeactivateChoice.nextOnly),
            child: const Text('Só a próxima data'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(_DeactivateChoice.fullSeries),
            child: const Text('Toda a série'),
          ),
        ],
      ),
    );
    switch (choice) {
      case _DeactivateChoice.fullSeries:
        await repo.deactivateSeries(event.id);
      case _DeactivateChoice.nextOnly:
        await repo.cancelNextOccurrenceOnly(event.id);
      case null:
        break;
    }
    ref.invalidate(recurringEventsProvider);
  }
}

enum _DeactivateChoice { fullSeries, nextOnly }
