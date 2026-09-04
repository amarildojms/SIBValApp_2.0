import 'package:cloud_firestore/cloud_firestore.dart';

import 'agenda_entry.dart' show AgendaAudience;

/// Molde de um compromisso recorrente da Agenda (03/09/2026, 2ª rodada,
/// pedido do usuário: "Deve ser possível solicitar um agendamento
/// recorrente (Ex.: um ensaio todo sábado mesmo horário)") — mesma
/// arquitetura de `RecurringEvent`/`Event` (molde + instância gerada), só
/// que a instância nasce em `agendaEntries` (mesma coleção dos compromissos
/// avulsos), marcada via `AgendaEntry.recurringAgendaEntryId`.
///
/// A série inteira passa por aprovação **uma vez** ([status]) — aprovada,
/// uma Cloud Function gera semanalmente a ocorrência já `approved` (ver
/// `SIBValApp2/functions/index.js`, mesmo mecanismo de
/// `generateInstanceForTemplate`/`occurrenceInCurrentWeekMillis`).
class RecurringAgendaEntry {
  const RecurringAgendaEntry({
    required this.id,
    required this.audienceType,
    this.ministryIds = const [],
    this.ministryNames = const [],
    required this.title,
    this.description = '',
    required this.location,
    required this.weekday,
    required this.hour,
    required this.minute,
    required this.durationMinutes,
    this.active = true,
    this.status = RecurringAgendaEntryStatus.pending,
    this.rejectionReason = '',
    this.approvedByUid = '',
    this.approvedByName = '',
    this.decidedAt,
    required this.createdByUid,
    required this.createdByName,
    this.createdAt,
  });

  final String id;
  final String audienceType;
  final List<String> ministryIds;
  final List<String> ministryNames;
  final String title;
  final String description;
  final String location;

  /// Calendar.SUNDAY(1)..SATURDAY(7) — mesma convenção de `RecurringEvent`.
  final int weekday;
  final int hour;
  final int minute;
  final int durationMinutes;

  /// Desativada pelo aprovador: para de gerar novas ocorrências (mesmo
  /// padrão de `RecurringEvent.active`).
  final bool active;

  final String status;
  final String rejectionReason;
  final String approvedByUid;
  final String approvedByName;
  final DateTime? decidedAt;
  final String createdByUid;
  final String createdByName;
  final DateTime? createdAt;

  String get displayAudience =>
      audienceType == AgendaAudience.wholeChurch ? 'Toda a igreja' : ministryNames.join(', ');

  Map<String, dynamic> toContentMap() => {
    'audienceType': audienceType,
    'ministryIds': ministryIds,
    'ministryNames': ministryNames,
    'title': title,
    'description': description,
    'location': location,
    'weekday': weekday,
    'hour': hour,
    'minute': minute,
    'durationMinutes': durationMinutes,
    'createdByUid': createdByUid,
    'createdByName': createdByName,
  };

  factory RecurringAgendaEntry.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return RecurringAgendaEntry(
      id: doc.id,
      audienceType: data['audienceType'] as String? ?? AgendaAudience.ministries,
      ministryIds: List<String>.from(data['ministryIds'] as List? ?? const []),
      ministryNames: List<String>.from(data['ministryNames'] as List? ?? const []),
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      location: data['location'] as String? ?? '',
      weekday: (data['weekday'] as num?)?.toInt() ?? 1,
      hour: (data['hour'] as num?)?.toInt() ?? 0,
      minute: (data['minute'] as num?)?.toInt() ?? 0,
      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 60,
      active: data['active'] as bool? ?? true,
      status: data['status'] as String? ?? RecurringAgendaEntryStatus.pending,
      rejectionReason: data['rejectionReason'] as String? ?? '',
      approvedByUid: data['approvedByUid'] as String? ?? '',
      approvedByName: data['approvedByName'] as String? ?? '',
      decidedAt: (data['decidedAt'] as Timestamp?)?.toDate(),
      createdByUid: data['createdByUid'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

abstract final class RecurringAgendaEntryStatus {
  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';
}
