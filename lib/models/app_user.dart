import 'package:cloud_firestore/cloud_firestore.dart';

import 'address.dart';

/// Espelha app/src/main/java/com/sibval/app/data/model/User.kt — mesma
/// coleção `users` no Firestore. Nomeado AppUser pra não colidir com a
/// classe User do firebase_auth, já usada em outros arquivos.
///
/// A seção "Dados eclesiásticos" (admissionForm, originChurch, baptismDate,
/// ministérios/cargos) não existe mais aqui (20/08/2026) — virou exclusividade
/// da Secretaria, editada direto em `Member` (`members_page.dart`),
/// desacoplada do fluxo de aprovação de cadastro.
///
/// `maritalStatus` (29/08/2026, pedido do usuário) é a exceção: voltou a
/// existir aqui como dado pessoal comum, preenchido/editado livremente pelo
/// próprio usuário em `edit_profile_page.dart` — nunca foi (e não é) parte
/// da seção eclesiástica gerida pela Secretaria.
class AppUser {
  final String uid;
  final String name;
  final String email;
  final String cpf;
  final int birthDay;
  final int birthMonth;
  final String photoUrl;
  final String status;
  final bool isAdmin;
  final bool isBlocked;
  final List<String> roles;
  final String phone;
  final String address;
  final Address addressDetails;
  final DateTime? baptismDate;
  final String maritalStatus;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.cpf,
    required this.birthDay,
    required this.birthMonth,
    required this.photoUrl,
    required this.status,
    required this.isAdmin,
    required this.isBlocked,
    required this.roles,
    this.phone = '',
    this.address = '',
    this.addressDetails = Address.empty,
    this.baptismDate,
    this.maritalStatus = '',
  });

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppUser(
      uid: doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      cpf: data['cpf'] as String? ?? '',
      birthDay: (data['birthDay'] as num?)?.toInt() ?? 0,
      birthMonth: (data['birthMonth'] as num?)?.toInt() ?? 0,
      photoUrl: data['photoUrl'] as String? ?? '',
      status: data['status'] as String? ?? UserStatus.approved,
      isAdmin: data['isAdmin'] as bool? ?? false,
      isBlocked: data['isBlocked'] as bool? ?? false,
      roles: List<String>.from(data['roles'] as List? ?? const []),
      phone: data['phone'] as String? ?? '',
      address: data['address'] as String? ?? '',
      addressDetails: Address.fromMap(data['addressDetails'] as Map<String, dynamic>?),
      baptismDate: (data['baptismDate'] as Timestamp?)?.toDate(),
      maritalStatus: data['maritalStatus'] as String? ?? '',
    );
  }

  AppUser copyWith({String? status, bool? isBlocked, List<String>? roles}) {
    return AppUser(
      uid: uid,
      name: name,
      email: email,
      cpf: cpf,
      birthDay: birthDay,
      birthMonth: birthMonth,
      photoUrl: photoUrl,
      status: status ?? this.status,
      isAdmin: isAdmin,
      isBlocked: isBlocked ?? this.isBlocked,
      roles: roles ?? this.roles,
      phone: phone,
      address: address,
      addressDetails: addressDetails,
      baptismDate: baptismDate,
      maritalStatus: maritalStatus,
    );
  }
}

abstract final class UserStatus {
  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';
}

abstract final class UserRole {
  static const secretaria = 'secretaria';
  static const midia = 'midia';
  static const intercessao = 'intercessao';
  static const eventos = 'eventos';
  static const publicacoes = 'publicacoes';

  // NOVO (24/08/2026): área Introdução — ver lib/models/visitor.dart.
  // Renomeado de "recepcao" pra "introducao" (pedido do usuário, mesma sessão
  // da sincronização automática de papéis por ministério, ver
  // functions/index.js: onMemberMinistryRoleSync).
  static const introducao = 'introducao';
  static const dirigentes = 'dirigentes';
  static const pastor = 'pastor';

  // NOVO (28/08/2026): Ministério de Louvor — quem tem esse papel vê a Ordem
  // de Culto numa visão própria (`ServiceOrderPraiseViewPage`), com tom das
  // músicas e link pra cifra, 1h antes do horário liberado pros Dirigentes.
  static const louvor = 'louvor';

  // NOTA (28/08/2026): quem edita cifras NÃO é um papel — o usuário pediu
  // explicitamente pra ser uma seleção individual do admin, não um chip
  // aqui (existiu como papel "cifrista" por uma rodada, revertido). Ver
  // `CifraEditorsRepository`/`settings/cifraEditors` em
  // `lib/data/cifra_repository.dart`.
}
