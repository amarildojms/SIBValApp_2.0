/// Uma chave PIX cadastrada na Contribua — [label] é livre (ex.: "Dízimos",
/// "Missões") pra distinguir quando há mais de uma. QR Code fica em Storage
/// (`contribution/`), como as fotos/flyers do resto do app.
class PixEntry {
  const PixEntry({
    this.label = '',
    this.key = '',
    this.qrCodeUrl = '',
    this.qrCodeStoragePath = '',
  });

  final String label;
  final String key;
  final String qrCodeUrl;
  final String qrCodeStoragePath;

  factory PixEntry.fromMap(Map<String, dynamic> map) {
    return PixEntry(
      label: map['label'] as String? ?? '',
      key: map['key'] as String? ?? '',
      qrCodeUrl: map['qrCodeUrl'] as String? ?? '',
      qrCodeStoragePath: map['qrCodeStoragePath'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'label': label,
        'key': key,
        'qrCodeUrl': qrCodeUrl,
        'qrCodeStoragePath': qrCodeStoragePath,
      };
}

/// Uma conta bancária cadastrada na Contribua — mesmo motivo do [label] em
/// [PixEntry] (ex.: "Conta principal", "Conta de missões").
class BankAccountEntry {
  const BankAccountEntry({
    this.label = '',
    this.bankName = '',
    this.agency = '',
    this.account = '',
  });

  final String label;
  final String bankName;
  final String agency;
  final String account;

  factory BankAccountEntry.fromMap(Map<String, dynamic> map) {
    return BankAccountEntry(
      label: map['label'] as String? ?? '',
      bankName: map['bankName'] as String? ?? '',
      agency: map['agency'] as String? ?? '',
      account: map['account'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'label': label,
        'bankName': bankName,
        'agency': agency,
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
    this.pixEntries = const [],
    this.bankAccounts = const [],
  });

  static const empty = ContributionInfo();

  /// Nome da igreja — dobra de razão social: a busca automática por CNPJ
  /// (`lookupCnpj`) preenche este campo direto, sem um campo separado (22/08/2026,
  /// a pedido do usuário). Continua editável depois da busca.
  final String churchName;
  final String cnpj;
  final List<PixEntry> pixEntries;
  final List<BankAccountEntry> bankAccounts;

  bool get isEmpty => churchName.isEmpty && cnpj.isEmpty && pixEntries.isEmpty && bankAccounts.isEmpty;

  factory ContributionInfo.fromMap(Map<String, dynamic>? map) {
    if (map == null) return ContributionInfo.empty;
    return ContributionInfo(
      churchName: map['churchName'] as String? ?? '',
      cnpj: map['cnpj'] as String? ?? '',
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
        'pixEntries': pixEntries.map((e) => e.toMap()).toList(),
        'bankAccounts': bankAccounts.map((e) => e.toMap()).toList(),
      };
}
