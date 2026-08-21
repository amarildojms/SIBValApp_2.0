import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/event_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../data/user_repository.dart';
import '../models/event.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'event_card.dart';
import 'event_detail_page.dart';
import 'event_filter.dart';
import 'event_filter_sheet.dart';
import 'event_form_page.dart';
import 'event_pending_list_page.dart';
import 'recurring_event_list_page.dart';

/// Espelha EventsFragment.kt/EventsViewModel.kt: abas Eventos (pontuais) e
/// Programação Semanal (recorrentes), com destaque + lista.
class EventsPage extends ConsumerWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);
    final tab = ref.watch(eventsTabProvider);
    final filter = ref.watch(eventFilterProvider);
    final uid = ref.watch(currentUidProvider);
    final profileAsync = ref.watch(currentUserProfileProvider);
    final canManageEventos = profileAsync.asData?.value?.canManageEventos ?? false;
    final pendingCount = canManageEventos ? ref.watch(eventPendingProvider).asData?.value.length ?? 0 : 0;

    return DefaultTabController(
      length: 2,
      initialIndex: tab == EventsTab.pontual ? 0 : 1,
      child: Scaffold(
        appBar: const SibValAppBar(isHome: false),
        floatingActionButton: canManageEventos
            ? FloatingActionButton(
                heroTag: 'events_fab',
                onPressed: () => _onAddEvent(context, tab),
                child: const Icon(Icons.add),
              )
            : null,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Confira nossas programações'),
            TabBar(
              onTap: (index) => ref.read(eventsTabProvider.notifier).state =
                  index == 0 ? EventsTab.pontual : EventsTab.recorrente,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 12),
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              tabs: const [
                Tab(text: 'EVENTOS'),
                Tab(text: 'PROGRAMAÇÃO SEMANAL'),
              ],
            ),
            if (canManageEventos && pendingCount > 0)
              Material(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: InkWell(
                  onTap: () => _openPendingList(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.pending_actions_outlined, color: context.textPrimary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pendentes de aprovação ($pendingCount)',
                            style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: context.textPrimary),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(child: _buildEventsList(context, ref, eventsAsync, tab, filter, uid)),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsList(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Event>> eventsAsync,
    EventsTab tab,
    EventFilter filter,
    String? uid,
  ) {
    return RefreshIndicator(
      onRefresh: () => ref.refresh(eventsProvider.future),
      child: eventsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ListView(
              children: [
                const SizedBox(height: 80),
                Center(child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary))),
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
                        style: TextStyle(color: context.textSecondary),
                      ),
                    ),
                  ],
                );
              }

              final featured = filtered.first;
              final rest = tab == EventsTab.pontual
                  ? filtered.skip(1).where((event) => _matchesFilter(event, filter)).toList()
                  : filtered.skip(1).toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _FeaturedCard(
                    event: featured,
                    onTap: () => _openDetail(context, featured.id),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Próximos Eventos',
                          style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (tab == EventsTab.pontual)
                        TextButton.icon(
                          onPressed: () => _openFilter(context, ref, filter),
                          icon: Icon(Icons.sort, color: filter.isActive ? SibValColors.goldAccent : context.textPrimary),
                          label: Text(
                            'Filtrar',
                            style: TextStyle(color: filter.isActive ? SibValColors.goldAccent : context.textPrimary),
                          ),
                        ),
                    ],
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
        );
  }

  void _onAddEvent(BuildContext context, EventsTab tab) {
    if (tab == EventsTab.pontual) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EventFormPage()));
    } else {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RecurringEventListPage()));
    }
  }

  void _openPendingList(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EventPendingListPage()));
  }

  void _openDetail(BuildContext context, String eventId) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventDetailPage(eventId: eventId)));
  }

  Future<void> _openFilter(BuildContext context, WidgetRef ref, EventFilter current) async {
    final result = await showModalBottomSheet<EventFilter>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EventFilterSheet(initialFilter: current),
    );
    if (result != null) {
      ref.read(eventFilterProvider.notifier).state = result;
    }
  }

  bool _matchesFilter(Event event, EventFilter filter) {
    if (filter.categories.isNotEmpty && !filter.categories.contains(event.category)) return false;
    if (filter.registrationFilter == EventRegistrationFilter.requires && !event.requiresRegistration) return false;
    if (filter.registrationFilter == EventRegistrationFilter.free && event.requiresRegistration) return false;
    if (filter.dateFilter == EventDateFilter.none) return true;

    final eventStart = DateTime.fromMillisecondsSinceEpoch(event.dateTimeMillis);
    final eventEnd = DateTime.fromMillisecondsSinceEpoch(event.endDateTimeMillis);
    final reference = DateTime.now();

    switch (filter.dateFilter) {
      case EventDateFilter.today:
        return _rangeIncludesDay(eventStart, eventEnd, reference);
      case EventDateFilter.thisWeek:
        return _rangeOverlapsWeek(eventStart, eventEnd, reference);
      case EventDateFilter.thisMonth:
        return _rangeOverlapsMonth(eventStart, eventEnd, reference.year, reference.month);
      case EventDateFilter.nextMonth:
        final nextMonth = DateTime(reference.year, reference.month + 1);
        return _rangeOverlapsMonth(eventStart, eventEnd, nextMonth.year, nextMonth.month);
      case EventDateFilter.custom:
        final custom = filter.customDateMillis;
        if (custom == null) return true;
        return _rangeIncludesDay(eventStart, eventEnd, DateTime.fromMillisecondsSinceEpoch(custom));
      case EventDateFilter.none:
        return true;
    }
  }

  /// True quando o dia de [day] cai em algum ponto entre o dia de [start] e o dia de [end]
  /// (inclusive) — cobre eventos de vários dias em vez de só o dia de início.
  bool _rangeIncludesDay(DateTime start, DateTime end, DateTime day) {
    final dayOnly = DateTime(day.year, day.month, day.day);
    final startOnly = DateTime(start.year, start.month, start.day);
    final endOnly = DateTime(end.year, end.month, end.day);
    return !dayOnly.isBefore(startOnly) && !dayOnly.isAfter(endOnly);
  }

  bool _rangeOverlapsWeek(DateTime start, DateTime end, DateTime reference) {
    final weekStart = _startOfWeek(reference);
    final weekEnd = weekStart.add(const Duration(days: 6));
    final startOnly = DateTime(start.year, start.month, start.day);
    final endOnly = DateTime(end.year, end.month, end.day);
    return !endOnly.isBefore(weekStart) && !startOnly.isAfter(weekEnd);
  }

  bool _rangeOverlapsMonth(DateTime start, DateTime end, int year, int month) {
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 1).subtract(const Duration(days: 1));
    final startOnly = DateTime(start.year, start.month, start.day);
    final endOnly = DateTime(end.year, end.month, end.day);
    return !endOnly.isBefore(monthStart) && !startOnly.isAfter(monthEnd);
  }

  DateTime _startOfWeek(DateTime date) {
    final daysFromSunday = date.weekday % 7;
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: daysFromSunday));
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
