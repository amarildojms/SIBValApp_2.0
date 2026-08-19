import 'package:flutter_riverpod/legacy.dart';

/// Espelha EventFilter.kt: filtros da aba Eventos (só eventos pontuais).
enum EventDateFilter { none, today, thisWeek, thisMonth, nextMonth, custom }

enum EventRegistrationFilter { any, requires, free }

class EventFilter {
  const EventFilter({
    this.dateFilter = EventDateFilter.none,
    this.customDateMillis,
    this.registrationFilter = EventRegistrationFilter.any,
    this.categories = const {},
  });

  final EventDateFilter dateFilter;
  final int? customDateMillis;
  final EventRegistrationFilter registrationFilter;
  final Set<String> categories;

  bool get isActive =>
      dateFilter != EventDateFilter.none || registrationFilter != EventRegistrationFilter.any || categories.isNotEmpty;
}

final eventFilterProvider = StateProvider.autoDispose<EventFilter>((ref) => const EventFilter());
