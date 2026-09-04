import 'package:cloud_firestore/cloud_firestore.dart';

import 'event.dart' show EventAudience;

/// Espelha app/src/main/java/com/sibval/app/data/model/RecurringEvent.kt —
/// mesma coleção `recurringEvents` no Firestore. É o molde da série; as
/// instâncias geradas semanalmente ficam em `events` (Event.source == recurring).
class RecurringEvent {
  final String id;
  final String title;
  final String description;
  final String location;
  final String category;
  final int weekday; // Calendar.SUNDAY(1)..Calendar.SATURDAY(7)
  final int hour;
  final int minute;
  final String flyerUrl;
  final String flyerStoragePath;
  final int reminderLeadMinutes;
  final bool active;
  final String createdBy;
  final DateTime? createdAt;

  /// Mesmos 3 campos de `Event` (03/09/2026, pedido do usuário) — propagados
  /// pra cada instância gerada em `events` (ver
  /// `generateInstanceForTemplate`, `SIBValApp2/functions/index.js`).
  final String audienceType;
  final List<String> targetMinistryIds;
  final List<String> targetMinistryNames;
  final String churchArea;

  /// Duração em minutos, propagada pra cada instância gerada (ver
  /// `Event.durationMinutes`) — 03/09/2026, 2ª rodada.
  final int? durationMinutes;

  const RecurringEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.category,
    required this.weekday,
    required this.hour,
    required this.minute,
    required this.flyerUrl,
    required this.flyerStoragePath,
    required this.reminderLeadMinutes,
    required this.active,
    required this.createdBy,
    required this.createdAt,
    this.audienceType = EventAudience.wholeChurch,
    this.targetMinistryIds = const [],
    this.targetMinistryNames = const [],
    this.churchArea = '',
    this.durationMinutes,
  });

  RecurringEvent copyWith({
    String? title,
    String? description,
    String? location,
    String? category,
    int? weekday,
    int? hour,
    int? minute,
    int? reminderLeadMinutes,
    bool? active,
    String? audienceType,
    List<String>? targetMinistryIds,
    List<String>? targetMinistryNames,
    String? churchArea,
    int? durationMinutes,
  }) {
    return RecurringEvent(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      category: category ?? this.category,
      weekday: weekday ?? this.weekday,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      flyerUrl: flyerUrl,
      flyerStoragePath: flyerStoragePath,
      reminderLeadMinutes: reminderLeadMinutes ?? this.reminderLeadMinutes,
      active: active ?? this.active,
      createdBy: createdBy,
      createdAt: createdAt,
      audienceType: audienceType ?? this.audienceType,
      targetMinistryIds: targetMinistryIds ?? this.targetMinistryIds,
      targetMinistryNames: targetMinistryNames ?? this.targetMinistryNames,
      churchArea: churchArea ?? this.churchArea,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }

  factory RecurringEvent.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return RecurringEvent(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      location: data['location'] as String? ?? '',
      category: data['category'] as String? ?? '',
      weekday: (data['weekday'] as num?)?.toInt() ?? 1,
      hour: (data['hour'] as num?)?.toInt() ?? 0,
      minute: (data['minute'] as num?)?.toInt() ?? 0,
      flyerUrl: data['flyerUrl'] as String? ?? '',
      flyerStoragePath: data['flyerStoragePath'] as String? ?? '',
      reminderLeadMinutes: (data['reminderLeadMinutes'] as num?)?.toInt() ?? 180,
      active: data['active'] as bool? ?? true,
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      audienceType: data['audienceType'] as String? ?? EventAudience.wholeChurch,
      targetMinistryIds: List<String>.from(
        data['targetMinistryIds'] as List? ?? const [],
      ),
      targetMinistryNames: List<String>.from(
        data['targetMinistryNames'] as List? ?? const [],
      ),
      churchArea: data['churchArea'] as String? ?? '',
      durationMinutes: (data['durationMinutes'] as num?)?.toInt(),
    );
  }
}

abstract final class ReminderLeadTime {
  static const presetsMinutes = [30, 120, 240, 360, 480, 720, 1440, 4320, 10080];
}

/// Presets de duração pra Eventos/compromissos (03/09/2026, 2ª rodada,
/// pedido do usuário: "Eventos deve ganhar também o campo Duração") — mesmo
/// padrão de `ReminderLeadTime`.
abstract final class EventDuration {
  static const presetsMinutes = [30, 60, 90, 120, 180, 240, 300, 360, 480];
}

String eventDurationLabel(int minutes) {
  if (minutes < 60) return '$minutes minutos';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  final hoursLabel = hours == 1 ? '1 hora' : '$hours horas';
  return rest == 0 ? hoursLabel : '$hoursLabel e $rest minutos';
}
