import 'package:cloud_firestore/cloud_firestore.dart';

/// Espelha app/src/main/java/com/sibval/app/data/model/Member.kt, ampliado
/// (19/08/2026) com paridade de campos ao cadastro de usuário — ver
/// UserRepository.createUserProfile. `membershipDate` só é gravado pelo
/// usuário autorizado (papel Secretaria) nesta tela, nunca pelo autocadastro.
/// `linkedUid` guarda o uid do usuário Auth dono deste registro, quando
/// existir (preenchido por `MemberRepository.upsertFromUser`), permitindo
/// achar "o membro do usuário logado" sem depender de CPF/e-mail.
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
  final DateTime? membershipDate;
  final String admissionForm;
  final String originChurch;
  final DateTime? baptismDate;
  final String maritalStatus;
  final String ministry;
  final String churchPosition;
  final String linkedUid;

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
    this.membershipDate,
    this.admissionForm = '',
    this.originChurch = '',
    this.baptismDate,
    this.maritalStatus = '',
    this.ministry = '',
    this.churchPosition = '',
    this.linkedUid = '',
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
      membershipDate: (data['membershipDate'] as Timestamp?)?.toDate(),
      admissionForm: data['admissionForm'] as String? ?? '',
      originChurch: data['originChurch'] as String? ?? '',
      baptismDate: (data['baptismDate'] as Timestamp?)?.toDate(),
      maritalStatus: data['maritalStatus'] as String? ?? '',
      ministry: data['ministry'] as String? ?? '',
      churchPosition: data['churchPosition'] as String? ?? '',
      linkedUid: data['linkedUid'] as String? ?? '',
    );
  }
}
