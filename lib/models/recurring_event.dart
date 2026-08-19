import 'package:cloud_firestore/cloud_firestore.dart';

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
    );
  }
}

abstract final class ReminderLeadTime {
  static const presetsMinutes = [30, 120, 240, 360, 480, 720, 1440, 4320, 10080];
}
