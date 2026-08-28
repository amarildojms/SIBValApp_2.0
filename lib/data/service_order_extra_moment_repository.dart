import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/service_order_extra_moment.dart';

/// Sem equivalente no app nativo — feature nova (28/08/2026), ver doc
/// comment de `ServiceOrderExtraMomentOption`
/// (`lib/models/service_order_extra_moment.dart`).
class ServiceOrderExtraMomentRepository {
  ServiceOrderExtraMomentRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('serviceOrderExtraMoments');

  Stream<List<ServiceOrderExtraMomentOption>> watchAll() {
    return _collection
        .orderBy('name')
        .snapshots()
        .map(
          (s) => s.docs.map(ServiceOrderExtraMomentOption.fromFirestore).toList(),
        );
  }

  /// Leitura única, sem passar pelo provider (28/08/2026) — usada por
  /// `ServiceOrderFormPage._pickExtraMoments`. O bug relatado duas vezes
  /// (momentos especiais cadastrados não apareciam no picker) não sumiu só
  /// trocando `asData?.value` por `.future` do `StreamProvider` — pode ser
  /// algum comportamento de lifecycle do provider `autoDispose` sendo lido
  /// de fora de qualquer `watch`. Este método contorna isso de vez: um
  /// `.get()` direto no Firestore, sem Riverpod no meio.
  Future<List<ServiceOrderExtraMomentOption>> getAll() async {
    final snapshot = await _collection.orderBy('name').get();
    return snapshot.docs.map(ServiceOrderExtraMomentOption.fromFirestore).toList();
  }

  Future<void> create(String name, ExtraMomentFieldKind fieldKind) {
    return _collection.add({
      'name': name,
      'fieldKind': fieldKind.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> update(String id, String name, ExtraMomentFieldKind fieldKind) {
    return _collection.doc(id).update({'name': name, 'fieldKind': fieldKind.name});
  }

  Future<void> setDefault(String id, bool isDefault) {
    return _collection.doc(id).update({'isDefault': isDefault});
  }

  Future<void> delete(String id) => _collection.doc(id).delete();
}

final serviceOrderExtraMomentRepositoryProvider =
    Provider<ServiceOrderExtraMomentRepository>((ref) {
      return ServiceOrderExtraMomentRepository(FirebaseFirestore.instance);
    });

final serviceOrderExtraMomentsProvider =
    StreamProvider.autoDispose<List<ServiceOrderExtraMomentOption>>((ref) {
      return ref.watch(serviceOrderExtraMomentRepositoryProvider).watchAll();
    });
