import 'package:cloud_firestore/cloud_firestore.dart';

/// "Doe para Cestas Básicas" (04/09/2026, sem equivalente no nativo — pedido
/// do usuário com base em prints de referência). Vive dentro da aba
/// Contribua: o usuário escolhe entre doar via Pix (reaproveita
/// [PixOfferPage] com a chave de [DonationCampaign.pixKey]) ou doar
/// alimentos, registrando uma "intenção de doação" ([BasketDonation]) contra
/// a lista de itens necessários ([BasketFoodItem]) que a Diaconia mantém.
///
/// **Generalizado pra múltiplas campanhas (04/09/2026, mesma sessão, pedido
/// do usuário)** — "Cestas Básicas" deixou de ser a única campanha possível
/// (`settings/basketCampaign`, singleton, removido) e virou a primeira de
/// uma coleção `donationCampaigns` que o admin pode expandir (ex.: doação de
/// alimentos pra Cristolândia). Todo item/doação carrega `campaignId`.
///
/// **Diaconia recebe e confirma, Tesouraria confirma o Pix bancário
/// (04/09/2026)** — antes o próprio doador marcava a própria doação como
/// entregue; agora só quem tem a capacidade `manage_basket_donations`
/// (Diaconia) marca uma doação de alimento como entregue, e só quem tem
/// `manage_basket_donations` OU `confirm_basket_pix` (Tesouraria) confirma
/// uma doação via Pix — ação única, qualquer um dos dois papéis resolve
/// (confirmado com o usuário: não é uma aprovação em duas etapas
/// obrigatórias). Ver `BasketDonationRepository.markFoodDelivered`/
/// `.confirmPix`, `CurrentUserProfile.canManageBasketDonations`/
/// `.canConfirmBasketPix`.
enum BasketPriority {
  alta,
  media,
  baixa;

  String get label => switch (this) {
    BasketPriority.alta => 'Prioridade alta',
    BasketPriority.media => 'Prioridade média',
    BasketPriority.baixa => 'Prioridade baixa',
  };

  static BasketPriority fromName(String? name) {
    return BasketPriority.values.firstWhere(
      (p) => p.name == name,
      orElse: () => BasketPriority.media,
    );
  }
}

/// Tipo de uma [BasketDonation] — alimento (com [BasketDonation.items]) ou
/// Pix (com [BasketDonation.amount]), 04/09/2026.
enum BasketDonationType {
  food,
  pix;

  static BasketDonationType fromName(String? name) {
    return BasketDonationType.values.firstWhere(
      (t) => t.name == name,
      orElse: () => BasketDonationType.food,
    );
  }
}

/// Uma campanha de doação de alimentos (`donationCampaigns/{id}`) — chave
/// Pix, meta/valor por cesta e texto de entrega, mais o catálogo de itens
/// necessários (`basketFoodItems`, filtrado por `campaignId`). Leitura
/// liberada a visitante sem login também, mesmo padrão de
/// `settings/contribution`.
class DonationCampaign {
  const DonationCampaign({
    required this.id,
    this.name = '',
    this.active = true,
    this.finalized = false,
    this.pixKey = '',
    this.goalCount = 0,
    this.valuePerBasket = 0,
    this.pixAmountConfirmedThisMonth = 0,
    this.foodBasketsCollected = 0,
    this.pixBasketsCollected = 0,
    this.deliveryInfo = '',
  });

  final String id;
  final String name;
  final bool active;

  /// "Finalizar campanha" (04/09/2026, pedido do usuário) — distinto de
  /// [active] (pausa temporária, reversível): uma campanha finalizada nunca
  /// mais aparece na Contribua nem aceita doação nova, mesmo que alguém
  /// marque [active] de volta — é um estado permanente de "encerrada",
  /// mantido só pra consulta do histórico. Só admin finaliza
  /// (`CurrentUserProfile.canCreateDonationCampaigns`), mesmo gate de criar
  /// uma campanha nova — é uma decisão estrutural sobre o ciclo de vida da
  /// campanha, não a configuração do dia a dia.
  final bool finalized;
  final String pixKey;

  /// Meta do mês (ex.: "20 cestas básicas") — a quantidade necessária de
  /// cada item (`BasketFoodItem.remainingNeeded`) é calculada a partir desta
  /// meta, não digitada separadamente (04/09/2026, pedido do usuário).
  final int goalCount;

  /// Valor em R$ de 1 cesta via Pix — a cada `valuePerBasket` confirmado em
  /// `pixAmountConfirmedThisMonth`, mais uma cesta conta pra
  /// [pixBasketsCollected] (ver `BasketDonationRepository.confirmPix`).
  final double valuePerBasket;

  /// Só as transações de `BasketDonationRepository` escrevem estes três —
  /// nunca editados à mão (04/09/2026, antes `collectedCount` era digitado
  /// pelo admin). Zerados todo mês por `resetMonthlyDonationCampaigns`
  /// (Cloud Function).
  final double pixAmountConfirmedThisMonth;
  final int foodBasketsCollected;
  final int pixBasketsCollected;

  /// Texto livre de "Onde e quando entregar?" (endereço/horário) — mostrado
  /// tanto na lista de itens quanto na confirmação/registro de uma doação.
  final String deliveryInfo;

  int get collectedCount => foodBasketsCollected + pixBasketsCollected;
  bool get hasProgress => goalCount > 0;

  factory DonationCampaign.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return DonationCampaign(
      id: doc.id,
      name: data['name'] as String? ?? '',
      active: data['active'] as bool? ?? true,
      finalized: data['finalized'] as bool? ?? false,
      pixKey: data['pixKey'] as String? ?? '',
      goalCount: (data['goalCount'] as num?)?.toInt() ?? 0,
      valuePerBasket: (data['valuePerBasket'] as num?)?.toDouble() ?? 0,
      pixAmountConfirmedThisMonth:
          (data['pixAmountConfirmedThisMonth'] as num?)?.toDouble() ?? 0,
      foodBasketsCollected: (data['foodBasketsCollected'] as num?)?.toInt() ?? 0,
      pixBasketsCollected: (data['pixBasketsCollected'] as num?)?.toInt() ?? 0,
      deliveryInfo: data['deliveryInfo'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'active': active,
    'finalized': finalized,
    'pixKey': pixKey,
    'goalCount': goalCount,
    'valuePerBasket': valuePerBasket,
    'pixAmountConfirmedThisMonth': pixAmountConfirmedThisMonth,
    'foodBasketsCollected': foodBasketsCollected,
    'pixBasketsCollected': pixBasketsCollected,
    'deliveryInfo': deliveryInfo,
  };

  DonationCampaign copyWith({
    String? name,
    bool? active,
    bool? finalized,
    String? pixKey,
    int? goalCount,
    double? valuePerBasket,
    String? deliveryInfo,
  }) => DonationCampaign(
    id: id,
    name: name ?? this.name,
    active: active ?? this.active,
    finalized: finalized ?? this.finalized,
    pixKey: pixKey ?? this.pixKey,
    goalCount: goalCount ?? this.goalCount,
    valuePerBasket: valuePerBasket ?? this.valuePerBasket,
    pixAmountConfirmedThisMonth: pixAmountConfirmedThisMonth,
    foodBasketsCollected: foodBasketsCollected,
    pixBasketsCollected: pixBasketsCollected,
    deliveryInfo: deliveryInfo ?? this.deliveryInfo,
  );
}

/// Um item do catálogo de "itens que mais precisamos" — cadastrado pela
/// Diaconia (ou admin) em `BasketCampaignSettingsPage`
/// (`basketFoodItems/{id}`), com `campaignId` apontando pra sua campanha.
class BasketFoodItem {
  const BasketFoodItem({
    required this.id,
    required this.campaignId,
    required this.name,
    required this.unit,
    required this.priority,
    this.quantityPerBasket = 0,
    this.stockReceived = 0,
    this.order = 0,
  });

  final String id;
  final String campaignId;
  final String name;

  /// Ex.: "pacotes", "unidades", "litros" — texto livre, mesmo padrão de
  /// `PraiseSong`/`ServiceOrder` pra campos de rótulo curto.
  final String unit;
  final BasketPriority priority;

  /// Quantidade deste item que entra em 1 cesta completa — 0 significa que o
  /// item não faz parte da "receita da cesta" (04/09/2026, substitui o
  /// campo `neededQuantity`, antes digitado à mão pelo admin).
  final int quantityPerBasket;

  /// Soma de tudo que já foi doado e marcado como entregue (`delivered`) —
  /// só `BasketDonationRepository.markFoodDelivered` escreve, nunca editado
  /// à mão. Zerado todo mês por `resetMonthlyDonationCampaigns`.
  final int stockReceived;

  /// Ordem de exibição — mantida pelo repositório (próximo inteiro livre a
  /// cada cadastro), sem reordenação manual nesta 1ª versão.
  final int order;

  /// Quanto ainda falta receber deste item pra completar a meta de cestas do
  /// mês (`goalCount` da campanha) — 0 se o item não entra na receita
  /// (`quantityPerBasket == 0`).
  int remainingNeeded(int goalCount) {
    if (quantityPerBasket <= 0) return 0;
    final total = quantityPerBasket * goalCount;
    final remaining = total - stockReceived;
    return remaining < 0 ? 0 : remaining;
  }

  factory BasketFoodItem.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return BasketFoodItem(
      id: doc.id,
      campaignId: data['campaignId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      unit: data['unit'] as String? ?? 'unidades',
      priority: BasketPriority.fromName(data['priority'] as String?),
      quantityPerBasket: (data['quantityPerBasket'] as num?)?.toInt() ?? 0,
      stockReceived: (data['stockReceived'] as num?)?.toInt() ?? 0,
      order: (data['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'campaignId': campaignId,
    'name': name,
    'unit': unit,
    'priority': priority.name,
    'quantityPerBasket': quantityPerBasket,
    'stockReceived': stockReceived,
    'order': order,
  };

  BasketFoodItem copyWith({
    String? name,
    String? unit,
    BasketPriority? priority,
    int? quantityPerBasket,
  }) => BasketFoodItem(
    id: id,
    campaignId: campaignId,
    name: name ?? this.name,
    unit: unit ?? this.unit,
    priority: priority ?? this.priority,
    quantityPerBasket: quantityPerBasket ?? this.quantityPerBasket,
    stockReceived: stockReceived,
    order: order,
  );
}

/// Um item dentro de uma [BasketDonation] do tipo `food` — retrato de um
/// [BasketFoodItem] no momento da doação (nome/unidade copiados, não uma
/// referência viva: se a Diaconia renomear o item depois, a doação já
/// registrada não muda).
class BasketDonationItem {
  const BasketDonationItem({
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.quantity,
  });

  final String itemId;
  final String itemName;
  final String unit;
  final int quantity;

  factory BasketDonationItem.fromMap(Map<String, dynamic> map) {
    return BasketDonationItem(
      itemId: map['itemId'] as String? ?? '',
      itemName: map['itemName'] as String? ?? '',
      unit: map['unit'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'itemId': itemId,
    'itemName': itemName,
    'unit': unit,
    'quantity': quantity,
  };
}

/// Uma "intenção de doação" (`basketDonations/{id}`) — de alimento
/// ([BasketDonationType.food], com [items]) ou Pix ([BasketDonationType.pix],
/// com [amount], criada assim que o doador gera o código Pix em
/// `PixOfferPage`, 04/09/2026). Válida por 7 dias ([expiresAt] =
/// [createdAt] + 7 dias, calculado no cliente ao criar, não recalculado
/// depois nem ao editar — `BasketDonationRepository.updateItems` preserva
/// esse prazo) — passado esse prazo sem `delivered`, vira [isExpired] só pra
/// exibição (nenhuma Cloud Function apaga/expira o documento de verdade,
/// mesmo padrão de `Visitor.isFromToday`/`Post.isFromToday`).
///
/// `delivered`/`deliveredAt` é o campo genérico de "resolvido" pros dois
/// tipos — "entregue" pra alimento, "confirmado" pro Pix — evita duplicar um
/// par `confirmed`/`confirmedAt` em paralelo só pro Pix.
///
/// [cancelled] (04/09/2026, pedido do usuário: "cancelar/editar sua doação
/// antes da entrega") — só o próprio doador cancela, só enquanto pendente;
/// uma doação cancelada nunca conta pra contabilização (que só roda ao
/// marcar `delivered`).
class BasketDonation {
  const BasketDonation({
    required this.id,
    required this.campaignId,
    required this.uid,
    required this.userName,
    required this.type,
    this.items = const [],
    this.amount = 0,
    required this.createdAt,
    required this.expiresAt,
    this.delivered = false,
    this.deliveredAt,
    this.confirmedBy = '',
    this.cancelled = false,
  });

  final String id;
  final String campaignId;
  final String uid;
  final String userName;
  final BasketDonationType type;
  final List<BasketDonationItem> items;

  /// Só preenchido pra `type == pix`.
  final double amount;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool delivered;
  final DateTime? deliveredAt;

  /// uid de quem marcou `delivered` (Diaconia ou Tesouraria) — só
  /// informativo, não afeta permissão nenhuma depois de gravado.
  final String confirmedBy;
  final bool cancelled;

  bool get isExpired => !delivered && !cancelled && DateTime.now().isAfter(expiresAt);
  bool get isPending => !delivered && !cancelled && !isExpired;

  factory BasketDonation.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return BasketDonation(
      id: doc.id,
      campaignId: data['campaignId'] as String? ?? '',
      uid: data['uid'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      type: BasketDonationType.fromName(data['type'] as String?),
      items: (data['items'] as List? ?? const [])
          .map(
            (e) =>
                BasketDonationItem.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      delivered: data['delivered'] as bool? ?? false,
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
      confirmedBy: data['confirmedBy'] as String? ?? '',
      cancelled: data['cancelled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'campaignId': campaignId,
    'uid': uid,
    'userName': userName,
    'type': type.name,
    'items': items.map((e) => e.toMap()).toList(),
    'amount': amount,
    'createdAt': Timestamp.fromDate(createdAt),
    'expiresAt': Timestamp.fromDate(expiresAt),
    'delivered': delivered,
    'deliveredAt': deliveredAt == null
        ? null
        : Timestamp.fromDate(deliveredAt!),
    'confirmedBy': confirmedBy,
    'cancelled': cancelled,
  };
}
