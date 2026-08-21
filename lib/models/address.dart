/// Endereço quebrado em campos estruturados (21/08/2026) — incremento sem
/// equivalente no nativo (que só tinha um campo de texto livre `address`).
/// Guardado em `users/{uid}.addressDetails` e `members/{id}.addressDetails`,
/// ao lado do antigo `address` (texto único), que continua sendo gravado —
/// composto a partir daqui via [formatted] — pra não quebrar nada que ainda
/// leia só o texto único (ex.: `MemberRepository.upsertFromUser`, que copia
/// `user.address` pro membro vinculado).
class Address {
  const Address({
    this.cep = '',
    this.street = '',
    this.number = '',
    this.noNumber = false,
    this.complement = '',
    this.neighborhood = '',
    this.city = '',
    this.state = '',
  });

  static const empty = Address();

  final String cep;
  final String street;
  final String number;
  final bool noNumber;
  final String complement;
  final String neighborhood;
  final String city;
  final String state;

  bool get isEmpty =>
      cep.isEmpty &&
      street.isEmpty &&
      number.isEmpty &&
      !noNumber &&
      complement.isEmpty &&
      neighborhood.isEmpty &&
      city.isEmpty &&
      state.isEmpty;

  Address copyWith({
    String? cep,
    String? street,
    String? number,
    bool? noNumber,
    String? complement,
    String? neighborhood,
    String? city,
    String? state,
  }) {
    return Address(
      cep: cep ?? this.cep,
      street: street ?? this.street,
      number: number ?? this.number,
      noNumber: noNumber ?? this.noNumber,
      complement: complement ?? this.complement,
      neighborhood: neighborhood ?? this.neighborhood,
      city: city ?? this.city,
      state: state ?? this.state,
    );
  }

  /// Linha única legível — mantém `address` (texto livre) populado pra quem
  /// ainda lê só esse campo.
  String get formatted {
    final numberLabel = noNumber ? 'S/N' : number;
    final streetLine = [street, numberLabel].where((s) => s.isNotEmpty).join(', ');
    final localityLine = [neighborhood, city.isNotEmpty && state.isNotEmpty ? '$city - $state' : city]
        .where((s) => s.isNotEmpty)
        .join(', ');
    final parts = [
      streetLine,
      if (complement.isNotEmpty) complement,
      localityLine,
      if (cep.isNotEmpty) 'CEP $cep',
    ].where((s) => s.isNotEmpty);
    return parts.join(' - ');
  }

  Map<String, dynamic> toMap() => {
        'cep': cep,
        'street': street,
        'number': number,
        'noNumber': noNumber,
        'complement': complement,
        'neighborhood': neighborhood,
        'city': city,
        'state': state,
      };

  factory Address.fromMap(Map<String, dynamic>? map) {
    if (map == null) return Address.empty;
    return Address(
      cep: map['cep'] as String? ?? '',
      street: map['street'] as String? ?? '',
      number: map['number'] as String? ?? '',
      noNumber: map['noNumber'] as bool? ?? false,
      complement: map['complement'] as String? ?? '',
      neighborhood: map['neighborhood'] as String? ?? '',
      city: map['city'] as String? ?? '',
      state: map['state'] as String? ?? '',
    );
  }
}
