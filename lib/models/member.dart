import 'package:cloud_firestore/cloud_firestore.dart';

import 'address.dart';

/// Ministério(s) que o membro exerce, com os cargos/funções marcados dentro
/// de cada um (20/08/2026, substitui os antigos campos livres `ministry`/
/// `churchPosition`). `ministryName` é denormalizado do `Ministry`
/// correspondente (`ministry_repository.dart`) só pra exibição sem join;
/// `ministryId` é o que importa pra filtrar/consultar.
class MemberMinistry {
  const MemberMinistry({required this.ministryId, required this.ministryName, required this.cargos});

  final String ministryId;
  final String ministryName;
  final List<String> cargos;

  Map<String, dynamic> toMap() => {
        'ministryId': ministryId,
        'ministryName': ministryName,
        'cargos': cargos,
      };

  factory MemberMinistry.fromMap(Map<String, dynamic> map) {
    return MemberMinistry(
      ministryId: map['ministryId'] as String? ?? '',
      ministryName: map['ministryName'] as String? ?? '',
      cargos: List<String>.from(map['cargos'] as List? ?? const []),
    );
  }
}

/// Espelha app/src/main/java/com/sibval/app/data/model/Member.kt, ampliado
/// (19/08/2026) com paridade de campos ao cadastro de usuário — ver
/// UserRepository.createUserProfile. `membershipDate` só é gravado pelo
/// usuário autorizado (papel Secretaria) nesta tela, nunca pelo autocadastro.
/// `linkedUid` guarda o uid do usuário Auth dono deste registro, quando
/// existir (preenchido por `MemberRepository.upsertFromUser`), permitindo
/// achar "o membro do usuário logado" sem depender de CPF/e-mail.
///
/// Toda a seção "Dados eclesiásticos" (admissionForm em diante, incluindo
/// `ministries`) passou a ser exclusividade da Secretaria em Rol de Membros
/// (20/08/2026) — não existe mais em `users/{uid}`/`AppUser`.
class Member {
  final String id;
  final String name;
  final String email;
  final String cpf;
  final int birthDay;
  final int birthMonth;
  final String photoUrl;
  final String storagePath;
  final String createdBy;
  final DateTime? createdAt;
  final String phone;
  final String address;
  final Address addressDetails;
  final DateTime? membershipDate;
  final String admissionForm;
  final String originChurch;
  final DateTime? baptismDate;
  final String maritalStatus;
  final List<String> ministryIds;
  final List<MemberMinistry> ministries;
  final String linkedUid;
  final DateTime? photoUpdatedAt;

  const Member({
    required this.id,
    required this.name,
    required this.email,
    required this.cpf,
    required this.birthDay,
    required this.birthMonth,
    required this.photoUrl,
    required this.storagePath,
    required this.createdBy,
    required this.createdAt,
    this.phone = '',
    this.address = '',
    this.addressDetails = Address.empty,
    this.membershipDate,
    this.admissionForm = '',
    this.originChurch = '',
    this.baptismDate,
    this.maritalStatus = '',
    this.ministryIds = const [],
    this.ministries = const [],
    this.linkedUid = '',
    this.photoUpdatedAt,
  });

  factory Member.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Member(
      id: doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      cpf: data['cpf'] as String? ?? '',
      birthDay: (data['birthDay'] as num?)?.toInt() ?? 0,
      birthMonth: (data['birthMonth'] as num?)?.toInt() ?? 0,
      photoUrl: data['photoUrl'] as String? ?? '',
      storagePath: data['storagePath'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      phone: data['phone'] as String? ?? '',
      address: data['address'] as String? ?? '',
      addressDetails: Address.fromMap(data['addressDetails'] as Map<String, dynamic>?),
      membershipDate: (data['membershipDate'] as Timestamp?)?.toDate(),
      admissionForm: data['admissionForm'] as String? ?? '',
      originChurch: data['originChurch'] as String? ?? '',
      baptismDate: (data['baptismDate'] as Timestamp?)?.toDate(),
      maritalStatus: data['maritalStatus'] as String? ?? '',
      ministryIds: List<String>.from(data['ministryIds'] as List? ?? const []),
      ministries: (data['ministries'] as List? ?? const [])
          .map((m) => MemberMinistry.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList(),
      linkedUid: data['linkedUid'] as String? ?? '',
      photoUpdatedAt: (data['photoUpdatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
