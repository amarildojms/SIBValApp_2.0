import 'package:diacritic/diacritic.dart';

import '../models/agenda_location.dart';

/// "Fora da Igreja" continua reservado/hardcoded — não é um lugar físico que
/// o admin cadastraria no catálogo (`agendaLocations`), é a ausência de uso
/// do espaço da igreja. "Todo o espaço" deixou de ser um valor fixo
/// (03/09/2026, 2ª rodada, pedido do usuário: "não precisa ter hardcode,
/// pois está duplicando") — agora é só um local do catálogo como outro
/// qualquer, marcado com `AgendaLocation.blocksEntireVenue`.
const String kOutsideChurchArea = 'Fora da Igreja';

String normalizeAgendaLocation(String location) =>
    removeDiacritics(location).trim().toLowerCase();

/// Nomes normalizados dos locais do catálogo marcados como "bloqueia todo o
/// espaço" — usado por [areasConflict] pra saber quando uma área conflita
/// com qualquer outra, sem depender de comparar contra um texto fixo.
Set<String> wholeVenueLocationNames(List<AgendaLocation> catalog) => {
  for (final l in catalog)
    if (l.blocksEntireVenue) normalizeAgendaLocation(l.name),
};

/// `true` se [a] e [b] ocupam a mesma área/horário para fins de bloqueio do
/// calendário. [kOutsideChurchArea] nunca conflita com nada (evento fora da
/// igreja não disputa espaço físico); qualquer local em [wholeVenue]
/// conflita com qualquer área não vazia (inclusive outro local "bloqueia
/// tudo"); fora isso, só conflita se for exatamente a mesma área
/// (comparação sem acento/maiúsculas).
bool areasConflict(String a, String b, Set<String> wholeVenue) {
  if (a.isEmpty || b.isEmpty) return false;
  if (a == kOutsideChurchArea || b == kOutsideChurchArea) return false;
  final normalizedA = normalizeAgendaLocation(a);
  final normalizedB = normalizeAgendaLocation(b);
  if (wholeVenue.contains(normalizedA) || wholeVenue.contains(normalizedB)) {
    return true;
  }
  return normalizedA == normalizedB;
}

/// Monta a lista de itens pro dropdown de local/área: "Fora da Igreja"
/// primeiro, depois o catálogo cadastrado pelo admin (ordenado, já inclui
/// "Todo o espaço" se o admin tiver cadastrado assim), garantindo que
/// [extra] (o valor já salvo, numa edição, mesmo se tiver sumido do
/// catálogo depois) sempre apareça.
List<String> locationItemsFor(List<AgendaLocation> catalog, {String? extra}) {
  final catalogNames = catalog.map((l) => l.name).toList()..sort();
  return [
    kOutsideChurchArea,
    ...catalogNames,
    if (extra != null &&
        extra.isNotEmpty &&
        extra != kOutsideChurchArea &&
        !catalogNames.contains(extra))
      extra,
  ];
}
