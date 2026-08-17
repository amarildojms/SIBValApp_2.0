import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/event_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../models/event.dart';
import 'event_card.dart';
import 'event_detail_page.dart';

/// Espelha EventsFragment.kt/EventsViewModel.kt: abas Eventos (pontuais) e
/// Programação Semanal (recorrentes), com destaque + lista.
class EventsPage extends ConsumerWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);
    final tab = ref.watch(eventsTabProvider);
    final uid = ref.watch(currentUidProvider);

    return DefaultTabController(
      length: 2,
      initialIndex: tab == EventsTab.pontual ? 0 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Confira nossas programações'),
          bottom: TabBar(
            onTap: (index) => ref.read(eventsTabProvider.notifier).state =
                index == 0 ? EventsTab.pontual : EventsTab.recorrente,
            tabs: const [
              Tab(text: 'EVENTOS'),
              Tab(text: 'PROGRAMAÇÃO SEMANAL'),
            ],
          ),
        ),
        body: RefreshIndicator(
          onRefresh: () => ref.refresh(eventsProvider.future),
          child: eventsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ListView(
              children: [
                const SizedBox(height: 80),
                Center(child: Text('Falha ao carregar: $error', style: const TextStyle(color: Colors.white))),
              ],
            ),
            data: (events) {
              final filtered = events.where((event) {
                final isRecurring = event.source == EventSource.recurring;
                return tab == EventsTab.recorrente ? isRecurring : !isRecurring;
              }).toList();

              if (filtered.isEmpty) {
                return ListView(
                  children: [
                    const SizedBox(height: 80),
                    Center(
                      child: Text(
                        tab == EventsTab.recorrente
                            ? 'Nenhuma programação semanal no momento.'
                            : 'Nenhum evento programado no momento.',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                );
              }

              final featured = filtered.first;
              final rest = filtered.skip(1).toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _FeaturedCard(
                    event: featured,
                    onTap: () => _openDetail(context, featured.id),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Próximos Eventos',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  for (final event in rest)
                    EventCard(
                      event: event,
                      liked: uid != null && event.likedBy.contains(uid),
                      onTap: () => _openDetail(context, event.id),
                      onLikeTap: () async {
                        if (uid == null) return;
                        final liked = event.likedBy.contains(uid);
                        await ref.read(eventRepositoryProvider).toggleLike(event.id, uid, !liked);
                        ref.invalidate(eventsProvider);
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, String eventId) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventDetailPage(eventId: eventId)));
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.event, required this.onTap});

  final Event event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: event.flyerUrl.isNotEmpty
              ? Image.network(event.flyerUrl, fit: BoxFit.cover)
              : Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
        ),
      ),
    );
  }
}
