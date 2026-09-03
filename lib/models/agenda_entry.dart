import 'package:cloud_firestore/cloud_firestore.dart';

/// Um compromisso da Agenda de um ministério — ensaio, reunião etc. (03/09/2026,
/// pedido do usuário, sem equivalente no nativo). Cadastrado por quem tem o
/// cargo "Líder" naquele ministério (ver `MemberRepository.isLeaderCargo` /
/// `Ministry.leaderUids`); visível aos demais membros do mesmo ministério
/// (`liderados`) e a qualquer outro ministério pra checagem de conflito de
/// [location] (`findAgendaConflicts`, `agenda_repository.dart`).
class AgendaEntry {
  const AgendaEntry({
    required this.id,
    required this.ministryId,
    required this.ministryName,
    required this.title,
    this.description = '',
    required this.location,
    required this.startDateTime,
    required this.endDateTime,
    required this.createdByUid,
    required this.createdByName,
    this.createdAt,
  });

  final String id;
  final String ministryId;
  final String ministryName;
  final String title;
  final String description;

  /// Área/local da igreja (texto livre, com sugestão dos locais já usados —
  /// ver `_LocationField`, `agenda_entry_form_page.dart`) — é o que decide
  /// conflito entre ministérios diferentes: mesmo local + horário sobreposto
  /// vira aviso; locais diferentes podem coincidir livremente (pedido
  /// explícito do usuário: "podem ocorrer dois ou três no mesmo horário por
  /// utilizarem áreas diferentes da igreja").
  final String location;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String createdByUid;
  final String createdByName;
  final DateTime? createdAt;

  factory AgendaEntry.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return AgendaEntry(
      id: doc.id,
      ministryId: data['ministryId'] as String? ?? '',
      ministryName: data['ministryName'] as String? ?? '',
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
    );
  }

  Map<String, dynamic> toMap() => {
    'ministryId': ministryId,
    'ministryName': ministryName,
    'title': title,
    'description': description,
    'location': location,
    'startDateTime': Timestamp.fromDate(startDateTime),
    'endDateTime': Timestamp.fromDate(endDateTime),
    'createdByUid': createdByUid,
    'createdByName': createdByName,
  };
}
