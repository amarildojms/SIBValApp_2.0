import 'package:cloud_firestore/cloud_firestore.dart';

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário). "Escala de Dirigentes": planejamento antecipado de quem vai
/// dirigir cada culto, cadastrado pelo Pastor — distinto da `ServiceOrder`
/// em si, que só existe quando o dirigente de fato monta a liturgia daquele
/// culto. `theme` aqui é só uma prévia do tema pretendido — não sincroniza
/// automaticamente com `ServiceOrder.theme` quando a ordem é criada depois.
/// Horário fixo às 19h (mesmo padrão do culto de domingo à noite, ver
/// `_nextSunday` em `service_order_form_page.dart`) — o cadastro só pede a
/// data, sem seletor de horário próprio.
class LeaderScheduleEntry {
  final String id;
  final DateTime dateTime;
  final String leaderUid;
  final String leaderName;
  final String theme;
  final DateTime? createdAt;

  const LeaderScheduleEntry({
    required this.id,
    required this.dateTime,
    required this.leaderUid,
    required this.leaderName,
    this.theme = '',
    this.createdAt,
  });

  Map<String, dynamic> toFieldsMap() => {
    'dateTimeMillis': dateTime.millisecondsSinceEpoch,
    'leaderUid': leaderUid,
    'leaderName': leaderName,
    'theme': theme,
  };

  factory LeaderScheduleEntry.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return LeaderScheduleEntry(
      id: doc.id,
      dateTime: DateTime.fromMillisecondsSinceEpoch(
        (data['dateTimeMillis'] as num?)?.toInt() ?? 0,
      ),
      leaderUid: data['leaderUid'] as String? ?? '',
      leaderName: data['leaderName'] as String? ?? '',
      theme: data['theme'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
