/// Uma chave PIX cadastrada na Contribua — [label] é livre (ex.: "Dízimos",
/// "Missões") pra o admin distinguir as chaves entre si na tela de
/// configuração; não aparece pro usuário final (ver [description]).
///
/// **Reforma de 01/09/2026** (pedido do usuário): a Contribua deixou de
/// mostrar a chave PIX crua — cada [PixEntry] agora vira um card de "gerar
/// oferta" (`_PixOfferCard`/`PixOfferPage` em `contribute_page.dart`/
/// `pix_offer_page.dart`), onde o usuário informa um valor e o app monta um
/// código Pix (BR Code) com esse valor e a mensagem de [description]. Card só
/// aparece se [key] e [description] (ou, na falta desta, [label]) não
/// estiverem vazios. O upload de QR Code estático (imagem) existiu entre
/// 22/08/2026 e esta reforma — removido junto porque a página deixou de
/// exibir qualquer QR fixo (o `qr_flutter` gera um na hora, com o valor já
/// embutido).
class PixEntry {
  const PixEntry({this.label = '', this.key = '', this.description = ''});

  final String label;
  final String key;

  /// Texto exibido no card gerado a partir desta chave (ex.: "Oferta para
  /// Missões", "Dízimo") — também vira a mensagem de referência gravada no
  /// código Pix gerado. Cai pra [label] se vazio (compatibilidade com chaves
  /// cadastradas antes desta reforma).
  final String description;

  /// Texto de fato mostrado no card — [description], com fallback pra
  /// [label] quando a descrição ainda não foi preenchida.
  String get displayTitle => description.isNotEmpty ? description : label;

  factory PixEntry.fromMap(Map<String, dynamic> map) {
    return PixEntry(
      label: map['label'] as String? ?? '',
      key: map['key'] as String? ?? '',
      description: map['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {'label': label, 'key': key, 'description': description};
}

/// Uma conta bancária cadastrada na Contribua — mesmo motivo do [label] em
/// [PixEntry] (ex.: "Conta principal", "Conta de missões").
class BankAccountEntry {
  const BankAccountEntry({
    this.label = '',
    this.bankName = '',
    this.agency = '',
    this.operation = '',
    this.account = '',
  });

  final String label;
  final String bankName;
  final String agency;

  /// Código de operação (ex.: 001, 013, 1288) — obrigatório por alguns bancos
  /// (Caixa Econômica Federal, principalmente) além de agência e conta pra
  /// TED/DOC. Adicionado 24/08/2026 (faltava no cadastro).
  final String operation;
  final String account;

  factory BankAccountEntry.fromMap(Map<String, dynamic> map) {
    return BankAccountEntry(
      label: map['label'] as String? ?? '',
      bankName: map['bankName'] as String? ?? '',
      agency: map['agency'] as String? ?? '',
      operation: map['operation'] as String? ?? '',
      account: map['account'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'label': label,
        'bankName': bankName,
        'agency': agency,
        'operation': operation,
        'account': account,
      };
}

/// Dados exibidos na aba "Contribua" (21/08/2026) — sem equivalente no
/// nativo. Guardado em `settings/contribution` (Firestore), documento único
/// editado pelo admin via `ContributeSettingsPage`. Suporta várias chaves PIX
/// e várias contas bancárias (22/08/2026, a pedido do usuário) — igrejas
/// costumam ter conta separada pra dízimo/missões/obras, por exemplo.
class ContributionInfo {
  const ContributionInfo({
    this.churchName = '',
    this.cnpj = '',
    this.city = '',
    this.pixEntries = const [],
    this.bankAccounts = const [],
  });

  static const empty = ContributionInfo();

  /// Nome da igreja — dobra de razão social: a busca automática por CNPJ
  /// (`lookupCnpj`) preenche este campo direto, sem um campo separado (22/08/2026,
  /// a pedido do usuário). Continua editável depois da busca.
  final String churchName;
  final String cnpj;

  /// Cidade do recebedor (01/09/2026) — exigida pelo padrão BR Code do Pix
  /// (campo "Merchant City") pra gerar os códigos com valor de qualquer
  /// [PixEntry] (`PixOfferPage`); não tem uso fora disso.
  final String city;
  final List<PixEntry> pixEntries;
  final List<BankAccountEntry> bankAccounts;

  bool get isEmpty => churchName.isEmpty && cnpj.isEmpty && pixEntries.isEmpty && bankAccounts.isEmpty;

  factory ContributionInfo.fromMap(Map<String, dynamic>? map) {
    if (map == null) return ContributionInfo.empty;
    return ContributionInfo(
      churchName: map['churchName'] as String? ?? '',
      cnpj: map['cnpj'] as String? ?? '',
      city: map['city'] as String? ?? '',
      pixEntries: (map['pixEntries'] as List? ?? const [])
          .map((e) => PixEntry.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      bankAccounts: (map['bankAccounts'] as List? ?? const [])
          .map((e) => BankAccountEntry.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'churchName': churchName,
        'cnpj': cnpj,
        'city': city,
        'pixEntries': pixEntries.map((e) => e.toMap()).toList(),
        'bankAccounts': bankAccounts.map((e) => e.toMap()).toList(),
      };
}
