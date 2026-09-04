import 'package:cloud_firestore/cloud_firestore.dart';

/// "Doe para Cestas Básicas" (04/09/2026, sem equivalente no nativo — pedido
/// do usuário com base em prints de referência). Vive dentro da aba
/// Contribua: o usuário escolhe entre doar via Pix (reaproveita
/// [PixOfferPage] com a chave de [BasketCampaignSettings.pixKey]) ou doar
/// alimentos, registrando uma "intenção de doação" ([BasketDonation]) contra
/// a lista de itens necessários ([BasketFoodItem]) que o admin mantém.
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

/// Um item do catálogo de "itens que mais precisamos" — cadastrado pelo
/// admin em `BasketCampaignSettingsPage` (`basketFoodItems/{id}`).
class BasketFoodItem {
  const BasketFoodItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.priority,
    required this.neededQuantity,
    this.order = 0,
  });

  final String id;
  final String name;

  /// Ex.: "pacotes", "unidades", "litros" — texto livre, mesmo padrão de
  /// `PraiseSong`/`ServiceOrder` pra campos de rótulo curto.
  final String unit;
  final BasketPriority priority;
  final int neededQuantity;

  /// Ordem de exibição — mantida pelo repositório (próximo inteiro livre a
  /// cada cadastro), sem reordenação manual nesta 1ª versão.
  final int order;

  factory BasketFoodItem.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return BasketFoodItem(
      id: doc.id,
      name: data['name'] as String? ?? '',
      unit: data['unit'] as String? ?? 'unidades',
      priority: BasketPriority.fromName(data['priority'] as String?),
      neededQuantity: (data['neededQuantity'] as num?)?.toInt() ?? 0,
      order: (data['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'unit': unit,
    'priority': priority.name,
    'neededQuantity': neededQuantity,
    'order': order,
  };
}

/// Documento único `settings/basketCampaign` — dados de configuração da
/// campanha (chave Pix, meta/arrecadação do mês, texto de entrega). Leitura
/// liberada a visitante sem login também, mesmo padrão de `settings/contribution`.
class BasketCampaignSettings {
  const BasketCampaignSettings({
    this.pixKey = '',
    this.goalCount = 0,
    this.collectedCount = 0,
    this.deliveryInfo = '',
  });

  static const empty = BasketCampaignSettings();

  final String pixKey;

  /// Meta do mês (ex.: "20 cestas básicas") e quantas já foram arrecadadas —
  /// ajustados manualmente pelo admin em `BasketCampaignSettingsPage`, sem
  /// tentativa de calcular "cestas" a partir dos itens doados (não há
  /// conversão de itens pra cestas definida).
  final int goalCount;
  final int collectedCount;

  /// Texto livre de "Onde e quando entregar?" (endereço/horário) — mostrado
  /// tanto na lista de itens quanto na confirmação/registro de uma doação.
  final String deliveryInfo;

  bool get hasProgress => goalCount > 0;

  factory BasketCampaignSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return BasketCampaignSettings.empty;
    return BasketCampaignSettings(
      pixKey: map['pixKey'] as String? ?? '',
      goalCount: (map['goalCount'] as num?)?.toInt() ?? 0,
      collectedCount: (map['collectedCount'] as num?)?.toInt() ?? 0,
      deliveryInfo: map['deliveryInfo'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'pixKey': pixKey,
    'goalCount': goalCount,
    'collectedCount': collectedCount,
    'deliveryInfo': deliveryInfo,
  };
}

/// Um item dentro de uma [BasketDonation] — retrato de um [BasketFoodItem]
/// no momento da doação (nome/unidade copiados, não uma referência viva:
/// se o admin renomear o item depois, a doação já registrada não muda).
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

/// Uma "intenção de doação" de alimentos (`basketDonations/{id}`) — criada
/// pelo próprio usuário ao confirmar `BasketDonationConfirmPage`. Válida por
/// 7 dias ([expiresAt] = [createdAt] + 7 dias, calculado no cliente ao criar,
/// não recalculado depois) — passado esse prazo sem `delivered`, vira
/// [isExpired] só pra exibição (nenhuma Cloud Function apaga/expira o
/// documento de verdade, mesmo padrão de `Visitor.isFromToday`/
/// `Post.isFromToday`: um getter derivado do relógio, não um job agendado).
class BasketDonation {
  const BasketDonation({
    required this.id,
    required this.uid,
    required this.userName,
    required this.items,
    required this.createdAt,
    required this.expiresAt,
    this.delivered = false,
    this.deliveredAt,
  });

  final String id;
  final String uid;
  final String userName;
  final List<BasketDonationItem> items;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool delivered;
  final DateTime? deliveredAt;

  bool get isExpired => !delivered && DateTime.now().isAfter(expiresAt);
  bool get isPending => !delivered && !isExpired;

  factory BasketDonation.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return BasketDonation(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      items: (data['items'] as List? ?? const [])
          .map(
            (e) =>
                BasketDonationItem.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      delivered: data['delivered'] as bool? ?? false,
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'userName': userName,
    'items': items.map((e) => e.toMap()).toList(),
    'createdAt': Timestamp.fromDate(createdAt),
    'expiresAt': Timestamp.fromDate(expiresAt),
    'delivered': delivered,
    'deliveredAt': deliveredAt == null
        ? null
        : Timestamp.fromDate(deliveredAt!),
  };
}
