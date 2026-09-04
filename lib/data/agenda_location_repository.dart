import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/agenda_location.dart';

/// CRUD simples do catálogo de locais/áreas da Agenda — mesmo padrão de
/// `MinistryRepository`/`ManageMinistriesPage`, só admin escreve (ver
/// `firestore.rules`).
class AgendaLocationRepository {
  AgendaLocationRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _locations =>
      _firestore.collection('agendaLocations');

  Stream<List<AgendaLocation>> watchAll() {
    return _locations
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map(AgendaLocation.fromFirestore).toList());
  }

  Future<void> create(String name, {bool blocksEntireVenue = false}) {
    return _locations.add({
      'name': name.trim(),
      'blocksEntireVenue': blocksEntireVenue,
    });
  }

  Future<void> update(
    String id,
    String name, {
    required bool blocksEntireVenue,
  }) {
    return _locations.doc(id).update({
      'name': name.trim(),
      'blocksEntireVenue': blocksEntireVenue,
    });
  }

  Future<void> delete(String id) {
    return _locations.doc(id).delete();
  }
}

final agendaLocationRepositoryProvider = Provider<AgendaLocationRepository>((
  ref,
) {
  return AgendaLocationRepository(FirebaseFirestore.instance);
});

final agendaLocationsProvider = StreamProvider.autoDispose<List<AgendaLocation>>((
  ref,
) {
  return ref.watch(agendaLocationRepositoryProvider).watchAll();
});
