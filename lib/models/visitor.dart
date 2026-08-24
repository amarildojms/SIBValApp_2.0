import 'package:cloud_firestore/cloud_firestore.dart';

import 'event.dart' show toSaoPauloTime, toSaoPauloTimeNow;

/// Sem equivalente no app nativo — feature nova (24/08/2026): a Recepção
/// cadastra o visitante com dados completos em `visitors/{id}`, restrito a
/// quem tem o papel Recepção (ou admin) e ao papel Pastor (dados completos,
/// telefone incluso). A Cloud Function `onVisitorCreated`
/// (`SIBValApp2/functions/index.js`) espelha um subconjunto sem telefone em
/// `visitorSummaries/{id}` (mesmo id) — é o que o papel Dirigentes lê, além
/// de notificar Dirigentes/admin imediatamente. Ver `VisitorSummary` abaixo.
class Visitor {
  final String id;
  final String name;
  final String phone;
  final String church;
  final bool firstVisit;
  final DateTime? createdAt;
  final String createdByUid;

  const Visitor({
    required this.id,
    required this.name,
    required this.phone,
    required this.church,
    required this.firstVisit,
    required this.createdAt,
    required this.createdByUid,
  });

  factory Visitor.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Visitor(
      id: doc.id,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      church: data['church'] as String? ?? '',
      firstVisit: data['firstVisit'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      createdByUid: data['createdByUid'] as String? ?? '',
    );
  }

  /// Verdadeiro só no dia em que o visitante foi cadastrado (fuso
  /// America/Sao_Paulo) — usado por `VisitorRepository` pra "arquivar"
  /// visitantes de dias anteriores (25/08/2026, pedido do usuário: a área de
  /// visitantes deve mostrar só os do dia). Mesmo padrão de `Post.isFromToday`.
  bool get isFromToday {
    if (createdAt == null) return false;
    final created = toSaoPauloTime(createdAt!.toUtc());
    final today = toSaoPauloTimeNow();
    return created.year == today.year && created.month == today.month && created.day == today.day;
  }
}

/// Recorte de [Visitor] sem telefone/`createdByUid` — o que o papel
/// Dirigentes enxerga (`visitorSummaries/{id}`), gerado pela Cloud Function
/// junto com a notificação de novo visitante.
class VisitorSummary {
  final String id;
  final String name;
  final String church;
  final bool firstVisit;
  final DateTime? createdAt;

  const VisitorSummary({
    required this.id,
    required this.name,
    required this.church,
    required this.firstVisit,
    required this.createdAt,
  });

  factory VisitorSummary.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return VisitorSummary(
      id: doc.id,
      name: data['name'] as String? ?? '',
      church: data['church'] as String? ?? '',
      firstVisit: data['firstVisit'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Ver `Visitor.isFromToday`.
  bool get isFromToday {
    if (createdAt == null) return false;
    final created = toSaoPauloTime(createdAt!.toUtc());
    final today = toSaoPauloTimeNow();
    return created.year == today.year && created.month == today.month && created.day == today.day;
  }
}
