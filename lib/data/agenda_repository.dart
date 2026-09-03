import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:diacritic/diacritic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/agenda_entry.dart';
import 'member_repository.dart' show isLeaderCargo, myMemberProvider;

class AgendaRepository {
  AgendaRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _entries =>
      _firestore.collection('agendaEntries');

  /// Tempo real — a agenda de um ministério é editada por mais de um líder em
  /// potencial e lida pelos liderados, mesmo padrão de `membersProvider`.
  Stream<List<AgendaEntry>> watchAll() {
    return _entries
        .orderBy('startDateTime')
        .snapshots()
        .map((s) => s.docs.map(AgendaEntry.fromFirestore).toList());
  }

  Future<void> create(AgendaEntry entry) => _entries.add(entry.toMap());

  Future<void> update(String id, AgendaEntry entry) =>
      _entries.doc(id).update(entry.toMap());

  Future<void> delete(String id) => _entries.doc(id).delete();
}

final agendaRepositoryProvider = Provider<AgendaRepository>((ref) {
  return AgendaRepository(FirebaseFirestore.instance);
});

final agendaEntriesProvider = StreamProvider.autoDispose<List<AgendaEntry>>((
  ref,
) {
  return ref.watch(agendaRepositoryProvider).watchAll();
});

/// Ministérios em que o usuário logado tem o cargo "Líder" — só esses entram
/// no seletor de ministério ao criar/editar um compromisso (ou todos, se
/// admin — checado à parte na UI, não aqui).
final myLedMinistryIdsProvider = Provider.autoDispose<Set<String>>((ref) {
  final member = ref.watch(myMemberProvider).asData?.value;
  if (member == null) return const {};
  return {
    for (final m in member.ministries)
      if (m.cargos.any(isLeaderCargo)) m.ministryId,
  };
});

/// Todo ministério de que o usuário logado participa (líder ou não) — define
/// o que os "liderados" enxergam na Agenda.
final myMemberMinistryIdsProvider = Provider.autoDispose<Set<String>>((ref) {
  final member = ref.watch(myMemberProvider).asData?.value;
  return member == null ? const {} : member.ministryIds.toSet();
});

String normalizeAgendaLocation(String location) =>
    removeDiacritics(location).trim().toLowerCase();

/// Compromissos que colidem com [location]/[start]/[end] — mesmo local
/// (comparação sem acento/maiúsculas) e intervalo de horário sobreposto,
/// vindo de qualquer ministério (03/09/2026, pedido do usuário: evitar dois
/// ministérios reservando a mesma área ao mesmo tempo, mas permitir áreas
/// diferentes simultâneas). [excludeId] ignora o próprio compromisso sendo
/// editado.
List<AgendaEntry> findAgendaConflicts(
  List<AgendaEntry> all, {
  required String location,
  required DateTime start,
  required DateTime end,
  String? excludeId,
}) {
  final normalizedLocation = normalizeAgendaLocation(location);
  if (normalizedLocation.isEmpty) return const [];
  return all.where((e) {
    if (e.id == excludeId) return false;
    if (normalizeAgendaLocation(e.location) != normalizedLocation) {
      return false;
    }
    return start.isBefore(e.endDateTime) && end.isAfter(e.startDateTime);
  }).toList();
}
