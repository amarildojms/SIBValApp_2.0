import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/basket_donation.dart';

/// Documento `settings/basketCampaign` — ver doc comment de
/// [BasketCampaignSettings]. Mesmo padrão de `ContributionRepository`.
class BasketCampaignRepository {
  BasketCampaignRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection('settings').doc('basketCampaign');

  Stream<BasketCampaignSettings> watch() {
    return _doc.snapshots().map(
      (doc) => BasketCampaignSettings.fromMap(doc.data()),
    );
  }

  Future<void> update(BasketCampaignSettings settings) =>
      _doc.set(settings.toMap());
}

final basketCampaignRepositoryProvider = Provider<BasketCampaignRepository>((
  ref,
) {
  return BasketCampaignRepository(FirebaseFirestore.instance);
});

final basketCampaignProvider =
    StreamProvider.autoDispose<BasketCampaignSettings>((ref) {
      return ref.watch(basketCampaignRepositoryProvider).watch();
    });

/// Catálogo de itens necessários (`basketFoodItems`) — CRUD simples pelo
/// admin, mesmo padrão de `MinistryRepository`.
class BasketFoodItemRepository {
  BasketFoodItemRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('basketFoodItems');

  Stream<List<BasketFoodItem>> watchAll() {
    return _collection.snapshots().map((snap) {
      final items = snap.docs.map(BasketFoodItem.fromFirestore).toList();
      items.sort((a, b) => a.order.compareTo(b.order));
      return items;
    });
  }

  Future<void> create({
    required String name,
    required String unit,
    required BasketPriority priority,
    required int neededQuantity,
  }) async {
    final existing = await _collection
        .orderBy('order', descending: true)
        .limit(1)
        .get();
    final nextOrder = existing.docs.isEmpty
        ? 0
        : ((existing.docs.first.data()['order'] as num?)?.toInt() ?? 0) + 1;
    await _collection.add(
      BasketFoodItem(
        id: '',
        name: name,
        unit: unit,
        priority: priority,
        neededQuantity: neededQuantity,
        order: nextOrder,
      ).toMap(),
    );
  }

  Future<void> update(BasketFoodItem item) =>
      _collection.doc(item.id).set(item.toMap());

  Future<void> delete(String id) => _collection.doc(id).delete();
}

final basketFoodItemRepositoryProvider = Provider<BasketFoodItemRepository>((
  ref,
) {
  return BasketFoodItemRepository(FirebaseFirestore.instance);
});

final basketFoodItemsProvider =
    StreamProvider.autoDispose<List<BasketFoodItem>>((ref) {
      return ref.watch(basketFoodItemRepositoryProvider).watchAll();
    });

/// Intenções de doação (`basketDonations`) — cada usuário só escreve as
/// próprias. [watchMine] filtra só por `uid` (sem `orderBy`) e ordena em
/// memória por `createdAt` decrescente — evita exigir um índice composto,
/// mesmo padrão já usado em `AppMessage.isRecipient`/`sentMessagesProvider`.
class BasketDonationRepository {
  BasketDonationRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('basketDonations');

  Stream<List<BasketDonation>> watchMine(String uid) {
    return _collection.where('uid', isEqualTo: uid).snapshots().map((snap) {
      final donations = snap.docs.map(BasketDonation.fromFirestore).toList();
      donations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return donations;
    });
  }

  Future<BasketDonation> create({
    required String uid,
    required String userName,
    required List<BasketDonationItem> items,
  }) async {
    final now = DateTime.now();
    final donation = BasketDonation(
      id: '',
      uid: uid,
      userName: userName,
      items: items,
      createdAt: now,
      expiresAt: now.add(const Duration(days: 7)),
    );
    final ref = await _collection.add(donation.toMap());
    return BasketDonation(
      id: ref.id,
      uid: uid,
      userName: userName,
      items: items,
      createdAt: now,
      expiresAt: donation.expiresAt,
    );
  }

  Future<void> markDelivered(String id) {
    return _collection.doc(id).update({
      'delivered': true,
      'deliveredAt': Timestamp.now(),
    });
  }
}

final basketDonationRepositoryProvider = Provider<BasketDonationRepository>((
  ref,
) {
  return BasketDonationRepository(FirebaseFirestore.instance);
});

final myBasketDonationsProvider = StreamProvider.autoDispose
    .family<List<BasketDonation>, String>((ref, uid) {
      return ref.watch(basketDonationRepositoryProvider).watchMine(uid);
    });
