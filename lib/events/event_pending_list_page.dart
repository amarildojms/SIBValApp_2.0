import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/event_repository.dart';
import '../models/event.dart';
import '../models/notification.dart';
import '../notifications/notification_read_sync.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'event_form_page.dart';

/// Espelha EventPendingListFragment.kt: eventos com status pendente
/// (normalmente vindos de e-mail), aguardando revisão de quem gerencia
/// eventos. Tocar num item abre EventFormPage em modo revisão.
class EventPendingListPage extends ConsumerStatefulWidget {
  const EventPendingListPage({super.key});

  @override
  ConsumerState<EventPendingListPage> createState() => _EventPendingListPageState();
}

class _EventPendingListPageState extends ConsumerState<EventPendingListPage> {
  @override
  void initState() {
    super.initState();
    syncNotificationsForScreen(ref, type: NotificationType.eventPending);
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(eventPendingProvider);

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenTitle('Eventos pendentes de aprovação'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(eventPendingProvider.future),
              child: pendingAsync.when(
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
                            'Nenhum evento pendente de aprovação.',
                            style: TextStyle(color: context.textSecondary),
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: events.length,
                    itemBuilder: (context, index) => _PendingEventTile(
                      event: events[index],
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EventFormPage(eventId: events[index].id, reviewMode: true),
                          ),
                        );
                        ref.invalidate(eventPendingProvider);
                      },
                    ),
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

class _PendingEventTile extends StatelessWidget {
  const _PendingEventTile({required this.event, required this.onTap});

  final Event event;
  final VoidCallback onTap;

  static final _dateFormat = DateFormat("dd/MM/yyyy 'às' HH:mm", 'pt_BR');

  @override
  Widget build(BuildContext context) {
    final localDate = toSaoPauloTime(event.dateTimeUtc);
    final placeholderColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: event.flyerUrl.isNotEmpty
                      ? Image.network(
                          event.flyerUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => Container(color: placeholderColor),
                        )
                      : Container(color: placeholderColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _dateFormat.format(localDate),
                      style: TextStyle(color: context.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
