import '../models/event.dart';

/// Espelha EventCategoryUtils.kt (categoryLabel/categoryLabels) — só a parte
/// de eventos pontuais; as categorias de evento recorrente têm seu próprio
/// rótulo em recurring_event_flyer.dart (recurringEventFlyerCategoryLabel).
String eventCategoryLabel(String category) => switch (category) {
  EventCategory.cultos => 'Cultos',
  EventCategory.acampamento => 'Acampamento',
  EventCategory.pgm => 'PGM',
  EventCategory.congresso => 'Congresso',
  EventCategory.cursoWorkshop => 'Curso/Workshop',
  _ => category,
};

const eventCategoryLabels = [
  (EventCategory.cultos, 'Cultos'),
  (EventCategory.acampamento, 'Acampamento'),
  (EventCategory.pgm, 'PGM'),
  (EventCategory.congresso, 'Congresso'),
  (EventCategory.cursoWorkshop, 'Curso/Workshop'),
];
