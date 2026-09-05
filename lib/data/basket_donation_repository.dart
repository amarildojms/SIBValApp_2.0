import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/basket_donation.dart';

/// Campanhas de doação de alimentos (`donationCampaigns`, 04/09/2026,
/// generalização de "Doe para Cestas Básicas" — antes um singleton
/// `settings/basketCampaign`). Ver doc comment de [DonationCampaign].
class DonationCampaignRepository {
  DonationCampaignRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('donationCampaigns');

  Stream<List<DonationCampaign>> watchAll() {
    return _collection.snapshots().map(
      (snap) => snap.docs.map(DonationCampaign.fromFirestore).toList(),
    );
  }

  Stream<DonationCampaign?> watchOne(String id) {
    return _collection.doc(id).snapshots().map(
      (doc) => doc.exists ? DonationCampaign.fromFirestore(doc) : null,
    );
  }

  /// Só quem tem `canCreateDonationCampaigns` (admin) chega aqui — criar uma
  /// campanha nova é uma decisão estrutural, distinta de configurar uma já
  /// existente (`update`, aberto pra Diaconia também).
  Future<String> create(DonationCampaign campaign) async {
    final ref = await _collection.add(campaign.toMap());
    return ref.id;
  }

  Future<void> update(DonationCampaign campaign) =>
      _collection.doc(campaign.id).update(campaign.toMap());

  Future<void> delete(String id) => _collection.doc(id).delete();
}

final donationCampaignRepositoryProvider = Provider<DonationCampaignRepository>((
  ref,
) {
  return DonationCampaignRepository(FirebaseFirestore.instance);
});

final donationCampaignsProvider =
    StreamProvider.autoDispose<List<DonationCampaign>>((ref) {
      return ref.watch(donationCampaignRepositoryProvider).watchAll();
    });

/// Só as campanhas ativas e não finalizadas — usada pela lista de cards
/// fixos na Contribua (`contribute_page.dart`). Uma campanha finalizada
/// nunca aparece aqui de novo, mesmo que `active` volte a `true`
/// (`DonationCampaign.finalized`, 04/09/2026, "Finalizar campanha" — estado
/// permanente, diferente do toggle Ativa/Inativa).
final activeDonationCampaignsProvider =
    Provider.autoDispose<List<DonationCampaign>>((ref) {
      final all = ref.watch(donationCampaignsProvider).asData?.value ?? const [];
      return all.where((c) => c.active && !c.finalized).toList();
    });

final donationCampaignProvider = StreamProvider.autoDispose
    .family<DonationCampaign?, String>((ref, campaignId) {
      return ref
          .read(donationCampaignRepositoryProvider)
          .watchOne(campaignId);
    });

/// Catálogo de itens necessários (`basketFoodItems`) — CRUD simples pela
/// Diaconia (ou admin), filtrado por `campaignId`.
class BasketFoodItemRepository {
  BasketFoodItemRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('basketFoodItems');

  Stream<List<BasketFoodItem>> watchForCampaign(String campaignId) {
    return _collection
        .where('campaignId', isEqualTo: campaignId)
        .snapshots()
        .map((snap) {
          final items = snap.docs.map(BasketFoodItem.fromFirestore).toList();
          items.sort((a, b) => a.order.compareTo(b.order));
          return items;
        });
  }

  Future<void> create({
    required String campaignId,
    required String name,
    required String unit,
    required BasketPriority priority,
    required int quantityPerBasket,
  }) async {
    // `where('campaignId', ...).orderBy('order', ...)` (04/09/2026, bug
    // relatado pelo usuário: "toco em adicionar... não adiciona") exigiria
    // um índice composto que não existe — a query falhava com
    // FAILED_PRECONDITION, sem nenhum catch em `_showItemDialog`
    // (`basket_campaign_settings_page.dart`), então o item nunca era
    // criado e nenhum erro aparecia (o diálogo já tinha fechado antes do
    // `await` estourar). Corrigido lendo só por igualdade (`campaignId`,
    // índice automático de campo único, sem precisar de deploy) e
    // calculando o maior `order` no cliente — cada campanha tem poucos
    // itens, não compensa criar um índice composto só pra isso.
    final existing = await _collection
        .where('campaignId', isEqualTo: campaignId)
        .get();
    final nextOrder = existing.docs.isEmpty
        ? 0
        : existing.docs
                .map((d) => (d.data()['order'] as num?)?.toInt() ?? 0)
                .reduce((a, b) => a > b ? a : b) +
            1;
    await _collection.add(
      BasketFoodItem(
        id: '',
        campaignId: campaignId,
        name: name,
        unit: unit,
        priority: priority,
        quantityPerBasket: quantityPerBasket,
        order: nextOrder,
      ).toMap(),
    );
  }

  Future<void> update(BasketFoodItem item) =>
      _collection.doc(item.id).update(item.toMap());

  Future<void> delete(String id) => _collection.doc(id).delete();
}

final basketFoodItemRepositoryProvider = Provider<BasketFoodItemRepository>((
  ref,
) {
  return BasketFoodItemRepository(FirebaseFirestore.instance);
});

final basketFoodItemsProvider = StreamProvider.autoDispose
    .family<List<BasketFoodItem>, String>((ref, campaignId) {
      return ref
          .watch(basketFoodItemRepositoryProvider)
          .watchForCampaign(campaignId);
    });

/// Intenções de doação (`basketDonations`) — cada usuário só cria/lê/edita as
/// próprias enquanto pendentes; marcar como entregue/confirmada é exclusivo
/// de Diaconia/Tesouraria (04/09/2026, ver doc comment de [BasketDonation]).
/// [watchMine]/[watchPendingAll] filtram sem `orderBy` combinado e ordenam em
/// memória — evita índice composto, mesmo padrão já usado em
/// `AppMessage.isRecipient`/`sentMessagesProvider`.
class BasketDonationRepository {
  BasketDonationRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('basketDonations');
  CollectionReference<Map<String, dynamic>> get _campaigns =>
      _firestore.collection('donationCampaigns');
  CollectionReference<Map<String, dynamic>> get _items =>
      _firestore.collection('basketFoodItems');

  Stream<List<BasketDonation>> watchMine(String uid) {
    return _collection.where('uid', isEqualTo: uid).snapshots().map((snap) {
      final donations = snap.docs.map(BasketDonation.fromFirestore).toList();
      donations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return donations;
    });
  }

  /// Todas as doações ainda não resolvidas, de qualquer doador/campanha —
  /// alimenta o painel da Diaconia/Tesouraria (`BasketDiaconiaDashboardPage`).
  Stream<List<BasketDonation>> watchPendingAll() {
    return _collection
        .where('delivered', isEqualTo: false)
        .where('cancelled', isEqualTo: false)
        .snapshots()
        .map((snap) {
          final donations = snap.docs
              .map(BasketDonation.fromFirestore)
              .toList();
          donations.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return donations;
        });
  }

  /// Histórico de doações já resolvidas (entregues/confirmadas) — visível a
  /// Diaconia/Tesouraria (04/09/2026, pedido do usuário: "cada card de
  /// doação... deve guardar dentro dele o histórico... visível ao diácono e
  /// tesoureiro"). Sem [campaignId], traz de todas as campanhas (usado pelo
  /// painel `BasketDiaconiaDashboardPage`); com ele, só daquela campanha
  /// (usado por `BasketCampaignSettingsPage`). Duas igualdades (`delivered`,
  /// opcionalmente `campaignId`), sem `orderBy` — cai no índice automático
  /// de campo único, sem precisar de índice composto (mesma cautela do bug
  /// de `BasketFoodItemRepository.create` corrigido nesta sessão); ordena
  /// por `deliveredAt` (mês/ano da resolução, não da criação) em memória.
  Stream<List<BasketDonation>> watchHistory({String? campaignId}) {
    Query<Map<String, dynamic>> query = _collection.where(
      'delivered',
      isEqualTo: true,
    );
    if (campaignId != null) {
      query = query.where('campaignId', isEqualTo: campaignId);
    }
    return query.snapshots().map((snap) {
      final donations = snap.docs.map(BasketDonation.fromFirestore).toList();
      donations.sort((a, b) {
        final da = a.deliveredAt ?? a.createdAt;
        final db = b.deliveredAt ?? b.createdAt;
        return db.compareTo(da);
      });
      return donations;
    });
  }

  Future<BasketDonation> createFood({
    required String campaignId,
    required String uid,
    required String userName,
    required List<BasketDonationItem> items,
  }) async {
    final now = DateTime.now();
    final donation = BasketDonation(
      id: '',
      campaignId: campaignId,
      uid: uid,
      userName: userName,
      type: BasketDonationType.food,
      items: items,
      createdAt: now,
      expiresAt: now.add(const Duration(days: 7)),
    );
    final ref = await _collection.add(donation.toMap());
    return BasketDonation(
      id: ref.id,
      campaignId: campaignId,
      uid: uid,
      userName: userName,
      type: BasketDonationType.food,
      items: items,
      createdAt: now,
      expiresAt: donation.expiresAt,
    );
  }

  /// Criada assim que o doador gera o código Pix em `PixOfferPage`
  /// (`onGenerated`) — não espera confirmação nenhuma, só registra a
  /// intenção com o valor informado, visível à Diaconia/Tesouraria.
  Future<void> createPix({
    required String campaignId,
    required String uid,
    required String userName,
    required double amount,
  }) async {
    final now = DateTime.now();
    await _collection.add(
      BasketDonation(
        id: '',
        campaignId: campaignId,
        uid: uid,
        userName: userName,
        type: BasketDonationType.pix,
        amount: amount,
        createdAt: now,
        expiresAt: now.add(const Duration(days: 7)),
      ).toMap(),
    );
  }

  /// Só o próprio doador, só enquanto pendente — não mexe em
  /// `createdAt`/`expiresAt` (04/09/2026, pedido do usuário: editar não deve
  /// zerar o prazo dos 7 dias).
  Future<void> updateItems(String id, List<BasketDonationItem> items) {
    return _collection.doc(id).update({
      'items': items.map((e) => e.toMap()).toList(),
    });
  }

  /// Só o próprio doador, só enquanto pendente.
  Future<void> cancel(String id) {
    return _collection.doc(id).update({'cancelled': true});
  }

  /// Diaconia marca uma doação de **alimento** como entregue — soma cada
  /// item ao estoque (`BasketFoodItem.stockReceived`) e recalcula quantas
  /// cestas completas isso já forma (`min` do `floor(stock/quantityPerBasket)`
  /// sobre os itens da receita), gravando em `DonationCampaign.foodBasketsCollected`.
  /// Transação (não Cloud Function) — funciona sem depender de deploy.
  Future<void> markFoodDelivered(String donationId, String confirmedByUid) async {
    await _firestore.runTransaction((tx) async {
      final donationRef = _collection.doc(donationId);
      final donationSnap = await tx.get(donationRef);
      final donation = BasketDonation.fromFirestore(donationSnap);
      if (donation.delivered || donation.cancelled) return;

      final itemRefs = {
        for (final line in donation.items) line.itemId: _items.doc(line.itemId),
      };
      final itemSnaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final entry in itemRefs.entries) {
        itemSnaps[entry.key] = await tx.get(entry.value);
      }

      final campaignRef = _campaigns.doc(donation.campaignId);
      final campaignSnap = await tx.get(campaignRef);
      if (!campaignSnap.exists) return;
      final campaign = DonationCampaign.fromFirestore(campaignSnap);

      final updatedStock = <String, int>{};
      for (final line in donation.items) {
        final snap = itemSnaps[line.itemId];
        if (snap == null || !snap.exists) continue;
        final item = BasketFoodItem.fromFirestore(snap);
        final newStock = item.stockReceived + line.quantity;
        updatedStock[line.itemId] = newStock;
        tx.update(itemRefs[line.itemId]!, {'stockReceived': newStock});
      }

      // Recalcula quantas cestas completas o estoque atual forma —
      // considera TODOS os itens da receita da campanha, não só os desta
      // doação, então relê quem não mudou agora.
      final recipeSnap = await _items
          .where('campaignId', isEqualTo: donation.campaignId)
          .get();
      var completeBaskets = campaign.goalCount > 0
          ? 1 << 30
          : 0;
      var hasRecipe = false;
      for (final doc in recipeSnap.docs) {
        final item = BasketFoodItem.fromFirestore(doc);
        if (item.quantityPerBasket <= 0) continue;
        hasRecipe = true;
        final stock = updatedStock[item.id] ?? item.stockReceived;
        final baskets = stock ~/ item.quantityPerBasket;
        if (baskets < completeBaskets) completeBaskets = baskets;
      }
      if (!hasRecipe) completeBaskets = campaign.foodBasketsCollected;

      tx.update(donationRef, {
        'delivered': true,
        'deliveredAt': Timestamp.now(),
        'confirmedBy': confirmedByUid,
      });
      tx.update(campaignRef, {'foodBasketsCollected': completeBaskets});
    });
  }

  /// Diaconia OU Tesouraria confirma que uma doação **Pix** de fato caiu na
  /// conta — soma o valor a `pixAmountConfirmedThisMonth` e recalcula
  /// `pixBasketsCollected` (`floor(total / valuePerBasket)`).
  Future<void> confirmPix(String donationId, String confirmedByUid) async {
    await _firestore.runTransaction((tx) async {
      final donationRef = _collection.doc(donationId);
      final donationSnap = await tx.get(donationRef);
      final donation = BasketDonation.fromFirestore(donationSnap);
      if (donation.delivered || donation.cancelled) return;

      final campaignRef = _campaigns.doc(donation.campaignId);
      final campaignSnap = await tx.get(campaignRef);
      if (!campaignSnap.exists) return;
      final campaign = DonationCampaign.fromFirestore(campaignSnap);

      final newTotal = campaign.pixAmountConfirmedThisMonth + donation.amount;
      final pixBaskets = campaign.valuePerBasket > 0
          ? (newTotal / campaign.valuePerBasket).floor()
          : 0;

      tx.update(donationRef, {
        'delivered': true,
        'deliveredAt': Timestamp.now(),
        'confirmedBy': confirmedByUid,
      });
      tx.update(campaignRef, {
        'pixAmountConfirmedThisMonth': newTotal,
        'pixBasketsCollected': pixBaskets,
      });
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

final pendingBasketDonationsProvider =
    StreamProvider.autoDispose<List<BasketDonation>>((ref) {
      return ref.watch(basketDonationRepositoryProvider).watchPendingAll();
    });

/// `campaignId == null` traz o histórico de todas as campanhas (painel da
/// Diaconia/Tesouraria); com um id, só daquela campanha.
final basketDonationHistoryProvider = StreamProvider.autoDispose
    .family<List<BasketDonation>, String?>((ref, campaignId) {
      return ref
          .watch(basketDonationRepositoryProvider)
          .watchHistory(campaignId: campaignId);
    });
