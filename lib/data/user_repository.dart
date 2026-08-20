import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import 'post_repository.dart' show currentUidProvider;

/// Espelha os checks de permissão de app/src/main/java/com/sibval/app/data/model/User.kt
/// (isAdmin || roles.contains(...)). Também carrega os dados eclesiásticos
/// opcionais (paridade com `AppUser`/`Member`, 19/08/2026) usados no % de
/// cadastro exibido na tela Mais e pré-preenchimento de Editar Perfil.
class CurrentUserProfile {
  const CurrentUserProfile({
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.isAdmin,
    required this.roles,
    required this.cpf,
    required this.hasBirthdate,
    this.phone = '',
    this.address = '',
    this.admissionForm = '',
    this.originChurch = '',
    this.baptismDate,
    this.maritalStatus = '',
    this.ministry = '',
    this.churchPosition = '',
    this.communicationsConsent = false,
    this.acceptedPrivacyPolicy = false,
    this.acceptedTermsOfUse = false,
  });

  final String name;
  final String email;
  final String photoUrl;
  final bool isAdmin;
  final List<String> roles;
  final String cpf;
  final bool hasBirthdate;
  final String phone;
  final String address;
  final String admissionForm;
  final String originChurch;
  final DateTime? baptismDate;
  final String maritalStatus;
  final String ministry;
  final String churchPosition;

  /// Checkbox opcional do cadastro (ver `registration_consent_section.dart`)
  /// — usado por `CommunicationsConsentBanner` pra decidir se sugere ativar.
  final bool communicationsConsent;

  /// Os dois checkboxes obrigatórios do cadastro. Contas criadas antes de
  /// 20/08/2026 (Termos de Uso) ou antes do checkbox de privacidade existir
  /// não têm esses timestamps gravados — usado por `RequiredConsentGatePage`
  /// pra bloquear o app até aceitarem.
  final bool acceptedPrivacyPolicy;
  final bool acceptedTermsOfUse;

  bool get canViewPrayerRequests => isAdmin || roles.contains('intercessao');
  bool get canManageBirthdays => isAdmin || roles.contains('secretaria');
  bool get canManageEventos => isAdmin || roles.contains('eventos');
  bool get canManageGallery => isAdmin || roles.contains('midia');
  bool get canManageDevotionals => isAdmin || roles.contains('secretaria');

  /// Espelha MoreViewModel.kt shortName(): primeiro + último nome, ou o
  /// e-mail se não houver nome cadastrado.
  String get shortName {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return email;
    if (parts.length == 1) return parts.first;
    return '${parts.first} ${parts.last}';
  }

  /// % de cadastro preenchido: 4 campos sempre obrigatórios no registro
  /// (nome, cpf, data de nascimento, e-mail) + 8 opcionais aqui + a data de
  /// membresia (vem do `Member` vinculado, ver `myMemberProvider` — passada
  /// à parte porque não existe mais em `users/{uid}`).
  int completionPercent({required bool hasMembershipDate}) {
    final requiredFilled = [name, cpf, email].where((v) => v.trim().isNotEmpty).length + (hasBirthdate ? 1 : 0);
    final optionalFilled = [phone, address, admissionForm, originChurch, maritalStatus, ministry, churchPosition]
            .where((v) => v.trim().isNotEmpty)
            .length +
        (baptismDate != null ? 1 : 0) +
        (hasMembershipDate ? 1 : 0);
    const totalFields = 13; // 4 obrigatórios + 8 opcionais + membershipDate
    return (((requiredFilled + optionalFilled) / totalFields) * 100).round();
  }
}

final currentUserProfileProvider = FutureProvider.autoDispose<CurrentUserProfile?>((ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
  final data = doc.data();
  if (data == null) return null;
  return CurrentUserProfile(
    name: data['name'] as String? ?? '',
    email: data['email'] as String? ?? '',
    photoUrl: data['photoUrl'] as String? ?? '',
    isAdmin: data['isAdmin'] as bool? ?? false,
    roles: List<String>.from(data['roles'] as List? ?? const []),
    cpf: data['cpf'] as String? ?? '',
    hasBirthdate: data['birthdate'] != null,
    phone: data['phone'] as String? ?? '',
    address: data['address'] as String? ?? '',
    admissionForm: data['admissionForm'] as String? ?? '',
    originChurch: data['originChurch'] as String? ?? '',
    baptismDate: (data['baptismDate'] as Timestamp?)?.toDate(),
    maritalStatus: data['maritalStatus'] as String? ?? '',
    ministry: data['ministry'] as String? ?? '',
    churchPosition: data['churchPosition'] as String? ?? '',
    communicationsConsent: data['communicationsConsent'] as bool? ?? false,
    acceptedPrivacyPolicy: data['privacyPolicyAcceptedAt'] != null,
    acceptedTermsOfUse: data['termsOfUseAcceptedAt'] != null,
  );
});

/// Espelha os métodos de admin de UserRepository.kt — aprovar/rejeitar
/// cadastro, bloquear, alterar cargos, excluir perfil. Só quem é isAdmin
/// pode chegar nessas ações (a tela que as usa só aparece pra admin no
/// menu Mais).
class UserRepository {
  UserRepository(this._firestore, this._storage);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _users => _firestore.collection('users');

  /// Espelha RegisterViewModel.kt: cria o doc em `users/{uid}` com status
  /// pendente de aprovação — precisa de um admin em Gerenciar Usuários pra
  /// liberar o acesso. Os campos complementares (cpf em diante) foram
  /// incrementados além do que existe hoje no app nativo, a pedido do
  /// usuário, para suportar um cadastro de membresia mais completo. CPF é
  /// obrigatório nas duas telas que chamam este método (cadastro por e-mail
  /// e completar perfil via Google) — os demais ficam opcionais aqui, quem
  /// exige o que é cada tela. `membershipDate` não é mais coletado aqui
  /// (19/08/2026) — passa a ser exclusividade do usuário autorizado (papel
  /// Secretaria) via `MemberRepository`, ver `members_page.dart`.
  Future<void> createUserProfile({
    required String uid,
    required String name,
    required String email,
    required DateTime birthdate,
    required String cpf,
    String phone = '',
    String address = '',
    String admissionForm = '',
    String originChurch = '',
    DateTime? baptismDate,
    String maritalStatus = '',
    String ministry = '',
    String churchPosition = '',
    bool privacyPolicyAccepted = false,
    bool termsOfUseAccepted = false,
    bool communicationsConsent = false,
  }) {
    final normalizedCpf = cpf.replaceAll(RegExp(r'\D'), '');
    return _users.doc(uid).set({
      'name': name,
      'email': email,
      'birthdate': Timestamp.fromDate(birthdate),
      'birthMonth': birthdate.month,
      'birthDay': birthdate.day,
      'cpf': normalizedCpf,
      'phone': phone,
      'address': address,
      'admissionForm': admissionForm,
      'originChurch': originChurch,
      'baptismDate': baptismDate != null ? Timestamp.fromDate(baptismDate) : null,
      'maritalStatus': maritalStatus,
      'ministry': ministry,
      'churchPosition': churchPosition,
      if (privacyPolicyAccepted) 'privacyPolicyAcceptedAt': FieldValue.serverTimestamp(),
      if (termsOfUseAccepted) 'termsOfUseAcceptedAt': FieldValue.serverTimestamp(),
      'communicationsConsent': communicationsConsent,
      if (communicationsConsent) 'communicationsConsentAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'status': UserStatus.pending,
      'isAdmin': false,
      'isBlocked': false,
      'roles': <String>[],
    });
  }

  /// Usado em `edit_profile_page.dart` — permite ao próprio usuário completar
  /// os campos opcionais do cadastro (regra atual já permite:
  /// `auth.uid == userId`). `membershipDate` não entra aqui de propósito.
  Future<void> updateProfileDetails({
    required String uid,
    required String phone,
    required String address,
    required String admissionForm,
    required String originChurch,
    required DateTime? baptismDate,
    required String maritalStatus,
    required String ministry,
    required String churchPosition,
  }) {
    return _users.doc(uid).update({
      'phone': phone,
      'address': address,
      'admissionForm': admissionForm,
      'originChurch': originChurch,
      'baptismDate': baptismDate != null ? Timestamp.fromDate(baptismDate) : null,
      'maritalStatus': maritalStatus,
      'ministry': ministry,
      'churchPosition': churchPosition,
    });
  }

  /// Mesmo caminho de storage do app nativo (`users/{uid}.jpg`) — é o que a
  /// Cloud Function de sincronização de foto espera encontrar.
  Future<String> uploadProfilePhoto(String uid, File photoFile) async {
    final storagePath = 'users/$uid.jpg';
    final ref = _storage.ref(storagePath);
    await ref.putFile(photoFile);
    final photoUrl = await ref.getDownloadURL();
    await _users.doc(uid).update({'photoUrl': photoUrl, 'photoStoragePath': storagePath});
    return photoUrl;
  }

  Future<void> updateName(String uid, String name) {
    return _users.doc(uid).update({'name': name});
  }

  /// Usado por `CommunicationsConsentBanner` quando o usuário ativa o
  /// consentimento (opcional, checkbox 3 do cadastro) depois de já cadastrado.
  Future<void> setCommunicationsConsent(String uid, bool accepted) {
    return _users.doc(uid).update({
      'communicationsConsent': accepted,
      if (accepted) 'communicationsConsentAt': FieldValue.serverTimestamp(),
    });
  }

  /// Usado por `RequiredConsentGatePage` — aceite retroativo dos Termos de
  /// Uso e da Política de Privacidade para contas criadas antes desses
  /// checkboxes existirem no cadastro (20/08/2026).
  Future<void> acceptRequiredConsents(String uid) {
    return _users.doc(uid).update({
      'termsOfUseAcceptedAt': FieldValue.serverTimestamp(),
      'privacyPolicyAcceptedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<AppUser>> getAllUsers() async {
    final snapshot = await _users.orderBy('name').get();
    return snapshot.docs.map(AppUser.fromFirestore).toList();
  }

  Future<int> getPendingCount() async {
    final snapshot = await _users.where('status', isEqualTo: UserStatus.pending).get();
    return snapshot.docs.length;
  }

  Future<void> setUserStatus(String uid, String status) {
    return _users.doc(uid).update({'status': status});
  }

  Future<void> setUserBlocked(String uid, bool blocked) {
    return _users.doc(uid).update({'isBlocked': blocked});
  }

  Future<void> updateRoles(String uid, List<String> roles) {
    return _users.doc(uid).update({'roles': roles});
  }

  Future<void> deleteUserProfile(String uid) {
    return _users.doc(uid).delete();
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(FirebaseFirestore.instance, FirebaseStorage.instance);
});

/// Pendentes primeiro, depois por nome — mesma ordenação de ManageUsersViewModel.kt.
final allUsersProvider = FutureProvider.autoDispose<List<AppUser>>((ref) async {
  final users = await ref.watch(userRepositoryProvider).getAllUsers();
  final sorted = [...users]
    ..sort((a, b) {
      final pendingCompare = (a.status != UserStatus.pending ? 1 : 0).compareTo(b.status != UserStatus.pending ? 1 : 0);
      if (pendingCompare != 0) return pendingCompare;
      return a.name.compareTo(b.name);
    });
  return sorted;
});

final pendingUserCountProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(userRepositoryProvider).getPendingCount();
});
