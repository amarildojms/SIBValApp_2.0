import 'package:cloud_firestore/cloud_firestore.dart';

/// Um local/área da igreja cadastrado pelo admin (03/09/2026, pedido do
/// usuário: "Local/área deve ser configurável por um admin") — catálogo que
/// alimenta o dropdown "Local/Área" da Agenda (`AgendaEntryFormPage`), no
/// lugar do campo livre com sugestão que existia antes.
///
/// [blocksEntireVenue] (03/09/2026, 2ª rodada — pedido do usuário: "O local
/// 'Todo o espaço' será cadastrado pelo admin também, então não precisa ter
/// hardcode") — marca o local que representa o espaço inteiro da igreja:
/// qualquer outro compromisso/evento no mesmo horário conflita com ele,
/// mesmo usando um nome de área diferente (ver `areasConflict`,
/// `lib/util/agenda_area.dart`). Substitui o antigo valor fixo
/// `kWholeVenueArea` — o texto "Todo o espaço" deixou de ser especial por
/// nome, e passou a ser especial por este campo.
class AgendaLocation {
  const AgendaLocation({
    required this.id,
    required this.name,
    this.blocksEntireVenue = false,
  });

  final String id;
  final String name;
  final bool blocksEntireVenue;

  factory AgendaLocation.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return AgendaLocation(
      id: doc.id,
      name: data['name'] as String? ?? '',
      blocksEntireVenue: data['blocksEntireVenue'] as bool? ?? false,
    );
  }
}
