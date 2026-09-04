import 'package:cloud_firestore/cloud_firestore.dart';

/// Um compromisso da Agenda de um ministério — ensaio, reunião etc. (03/09/2026,
/// pedido do usuário, sem equivalente no nativo). Cadastrado por quem tem o
/// cargo "Líder" em **algum** ministério (não precisa mais ser o ministério
/// alvo — ver `MemberRepository.isLeaderCargo` / `Ministry.leaderUids` /
/// `settings/agendaLeaders`); visível conforme [audienceType] e passa por
/// aprovação (`[status]`) antes de valer de verdade — só um compromisso
/// `approved` bloqueia o calendário (`findAgendaConflicts`,
/// `agenda_repository.dart`) e aparece na visualização normal.
class AgendaEntry {
  const AgendaEntry({
    required this.id,
    required this.audienceType,
    this.ministryIds = const [],
    this.ministryNames = const [],
    required this.title,
    this.description = '',
    required this.location,
    required this.startDateTime,
    required this.endDateTime,
    required this.createdByUid,
    required this.createdByName,
    this.createdAt,
    this.status = AgendaEntryStatus.pending,
    this.rejectionReason = '',
    this.approvedByUid = '',
    this.approvedByName = '',
    this.decidedAt,
    this.rescheduleMessage = '',
    this.recurringAgendaEntryId = '',
    this.cancelReason = '',
  });

  final String id;

  /// [AgendaAudience.ministries] (com [ministryIds] preenchido) ou
  /// [AgendaAudience.wholeChurch] (destinado a toda a igreja, sem ministério
  /// específico) — 03/09/2026, antes era um único `ministryId`. ALTERADO
  /// (mesma data, 4ª rodada): Aberto/Restrito deixou de ser um flag próprio
  /// (`isOpen`, removido) — [AgendaAudience.ministries] = Restrito (só quem
  /// participa vê os detalhes/é notificado), [AgendaAudience.wholeChurch] =
  /// Aberto (todo mundo), sempre — ver `AgendaCalendarItem.hasMinistryAudience`
  /// e `sendAgendaEntryMessage` em `SIBValApp2/functions/index.js`.
  final String audienceType;
  final List<String> ministryIds;

  /// Nomes denormalizados dos ministérios em [ministryIds] — só exibição,
  /// mesmo padrão do antigo `ministryName` único.
  final List<String> ministryNames;

  final String title;
  final String description;

  /// Área/local da igreja (catálogo `agendaLocations` + os dois valores
  /// reservados de `lib/util/agenda_area.dart`) — decide conflito entre
  /// compromissos/eventos diferentes (`areasConflict`).
  final String location;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String createdByUid;
  final String createdByName;
  final DateTime? createdAt;

  /// `pending` até um aprovador decidir; só `approved` bloqueia o calendário
  /// e aparece na visualização normal — ver `AgendaEntryStatus`.
  final String status;

  /// Motivo informado pelo aprovador ao rejeitar — vazio caso contrário.
  final String rejectionReason;
  final String approvedByUid;
  final String approvedByName;
  final DateTime? decidedAt;

  /// Texto do aprovador pedindo pro solicitante escolher outra data —
  /// preenchido só quando `status == needsReschedule` (03/09/2026, 2ª
  /// rodada: "enviar para o solicitante com um texto explicando que ele
  /// deve remarcar para outra data").
  final String rescheduleMessage;

  /// Preenchido quando esta ocorrência foi gerada automaticamente por uma
  /// série recorrente (`RecurringAgendaEntry`) — vazio pra um compromisso
  /// avulso comum. Usado pra colorir/identificar a categoria no calendário
  /// e pra `cancelNextOccurrenceOnly` achar a ocorrência certa.
  final String recurringAgendaEntryId;

  /// Motivo informado pelo aprovador ao cancelar um compromisso já
  /// aprovado — vazio caso contrário (03/09/2026, 3ª rodada, pedido do
  /// usuário: "Ao remanejar ou cancelar um agendamento, deve informar a
  /// justificativa").
  final String cancelReason;

  String get displayAudience => audienceType == AgendaAudience.wholeChurch
      ? 'Toda a igreja'
      : ministryNames.join(', ');

  factory AgendaEntry.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return AgendaEntry(
      id: doc.id,
      audienceType:
          data['audienceType'] as String? ?? AgendaAudience.ministries,
      ministryIds: List<String>.from(data['ministryIds'] as List? ?? const []),
      ministryNames: List<String>.from(
        data['ministryNames'] as List? ?? const [],
      ),
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      location: data['location'] as String? ?? '',
      startDateTime:
          (data['startDateTime'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      endDateTime:
          (data['endDateTime'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      createdByUid: data['createdByUid'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      status: data['status'] as String? ?? AgendaEntryStatus.pending,
      rejectionReason: data['rejectionReason'] as String? ?? '',
      approvedByUid: data['approvedByUid'] as String? ?? '',
      approvedByName: data['approvedByName'] as String? ?? '',
      decidedAt: (data['decidedAt'] as Timestamp?)?.toDate(),
      rescheduleMessage: data['rescheduleMessage'] as String? ?? '',
      recurringAgendaEntryId: data['recurringAgendaEntryId'] as String? ?? '',
      cancelReason: data['cancelReason'] as String? ?? '',
    );
  }

  /// Campos de conteúdo — usado tanto na criação quanto na edição, que força
  /// `status: pending` de novo (ver doc comment de `AgendaRepository.update`).
  Map<String, dynamic> toContentMap() => {
    'audienceType': audienceType,
    'ministryIds': ministryIds,
    'ministryNames': ministryNames,
    'title': title,
    'description': description,
    'location': location,
    'startDateTime': Timestamp.fromDate(startDateTime),
    'endDateTime': Timestamp.fromDate(endDateTime),
    'createdByUid': createdByUid,
    'createdByName': createdByName,
  };
}

abstract final class AgendaAudience {
  static const ministries = 'ministries';
  static const wholeChurch = 'wholeChurch';
}

abstract final class AgendaEntryStatus {
  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';

  /// Estava `approved`, aprovador cancelou (03/09/2026, 2ª rodada) — some do
  /// calendário e da checagem de conflito, mas fica registrado.
  static const cancelled = 'cancelled';

  /// Estava `approved`, aprovador pediu pro solicitante escolher outra data
  /// (`rescheduleMessage`) — o solicitante edita e reenvia (volta pra
  /// `pending`).
  static const needsReschedule = 'needsReschedule';
}
