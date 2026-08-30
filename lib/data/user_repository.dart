import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/address.dart';
import '../models/app_user.dart';
import '../models/member.dart';
import 'post_repository.dart' show currentUidProvider;

/// Espelha os checks de permissão de app/src/main/java/com/sibval/app/data/model/User.kt
/// (isAdmin || roles.contains(...)). A seção "Dados eclesiásticos" (forma de
/// adesão em diante) não existe mais aqui (20/08/2026) — virou exclusividade
/// da Secretaria, editada direto no `Member` vinculado (ver
/// `completionPercent`, que agora recebe esse `Member?` pra calcular o % de
/// cadastro em vez de campos locais).
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
    this.addressDetails = Address.empty,
    this.maritalStatus = '',
    this.photoUpdatedAt,
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
  final Address addressDetails;

  /// Dado pessoal comum, não eclesiástico (29/08/2026, pedido do usuário) —
  /// editado pelo próprio usuário em `edit_profile_page.dart`, gravado em
  /// `users/{uid}` (`UserRepository.updateProfileDetails`). Antes de
  /// 29/08/2026 esse campo vivia só em `Member.maritalStatus`, exclusividade
  /// da Secretaria.
  final String maritalStatus;
  final DateTime? photoUpdatedAt;

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
  // ALTERADO (21/08/2026): publicar devocionais e posts manuais no feed
  // "Início" virou exclusividade do papel Publicações — a Secretaria não
  // gerencia mais esse conteúdo.
  bool get canManageDevotionals => isAdmin || roles.contains('publicacoes');
  bool get canManagePublications => isAdmin || roles.contains('publicacoes');

  // NOVO (24/08/2026): área Introdução — ver lib/models/visitor.dart.
  bool get canRegisterVisitors => isAdmin || roles.contains('introducao');
  bool get canViewVisitorSummaries => isAdmin || roles.contains('dirigentes');
  bool get canViewVisitorDetails => isAdmin || roles.contains('pastor');

  // NOVO (27/08/2026): Ordem de Culto — só dirigente ou admin cadastra (ver
  // lib/models/service_order.dart). Edição/exclusão são restritas ao dono da
  // ordem (`ServiceOrder.ownerUid`) ou admin — checado ponto a ponto na tela,
  // não aqui, porque depende do documento, não só do papel do usuário.
  bool get canManageServiceOrders => isAdmin || roles.contains('dirigentes');

  // NOVO (28/08/2026): Ministério de Louvor — papel próprio pra quem só
  // precisa ver a Ordem de Culto (com tom/cifra), não gerenciá-la. Quem
  // edita cifras NÃO é um papel — é uma seleção individual do admin
  // (`canEditCifrasProvider` em `lib/data/cifra_repository.dart`), por isso
  // não tem getter aqui.
  bool get canViewPraiseOrder => isAdmin || roles.contains('louvor');

  // NOVO (28/08/2026): Escala de Dirigentes — planejamento antecipado de
  // quem vai dirigir cada culto + tema (menu ☰ dentro de "Ordem de Culto",
  // ver lib/service_order/leader_schedule_*.dart), distinto da ServiceOrder
  // em si. Pastor cadastra/edita/exclui; Dirigentes só visualiza.
  bool get canManageLeaderSchedule => isAdmin || roles.contains('pastor');
  bool get canViewLeaderSchedule =>
      isAdmin || roles.contains('pastor') || roles.contains('dirigentes');

  /// Espelha MoreViewModel.kt shortName(): primeiro + último nome, ou o
  /// e-mail se não houver nome cadastrado.
  String get shortName {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return email;
    if (parts.length == 1) return parts.first;
    return '${parts.first} ${parts.last}';
  }

  /// % de cadastro preenchido — lista revisada em 29/08/2026 (pedido do
  /// usuário), 14 campos ao todo: nome, e-mail, telefone (`users/{uid}`);
  /// CEP/rua/número/bairro/cidade/UF do endereço estruturado (número conta
  /// como preenchido também quando "Sem número" está marcado); estado civil
  /// (`users/{uid}.maritalStatus`); e, do `Member` vinculado (ver
  /// `myMemberProvider`) — data de membresia (só a Secretaria preenche),
  /// forma de adesão, igreja de origem e data de batismo (esses três já
  /// podem vir do próprio usuário, `MemberRepository.updateSelfEditableDetails`/
  /// `updateBaptismDate`). CPF e data de nascimento saíram da conta (eram
  /// sempre obrigatórios no cadastro, então não agregavam informação sobre o
  /// quanto falta preencher); ministérios/cargos também saíram — não estão
  /// na lista pedida pelo usuário.
  int completionPercent({required Member? member}) {
    final a = addressDetails;
    final filled = <bool>[
      name.trim().isNotEmpty,
      email.trim().isNotEmpty,
      phone.trim().isNotEmpty,
      a.cep.trim().isNotEmpty,
      a.street.trim().isNotEmpty,
      a.noNumber || a.number.trim().isNotEmpty,
      a.neighborhood.trim().isNotEmpty,
      a.city.trim().isNotEmpty,
      a.state.trim().isNotEmpty,
      maritalStatus.trim().isNotEmpty,
      member?.membershipDate != null,
      (member?.admissionForm ?? '').trim().isNotEmpty,
      (member?.originChurch ?? '').trim().isNotEmpty,
      member?.baptismDate != null,
    ];
    final filledCount = filled.where((f) => f).length;
    return ((filledCount / filled.length) * 100).round();
  }
}

/// `StreamProvider` (29/08/2026, era `FutureProvider` com `.get()`) — o
/// usuário relatou demora pra carregar o próprio perfil/ícones de admin no
/// menu Mais ao reabrir o app do zero. Causa: `.get()` prioriza o servidor
/// por padrão (só cai pro cache se estiver offline), então todo cold start
/// pagava o round-trip completo de rede (restaurar sessão do Firebase Auth +
/// buscar o documento) antes de mostrar qualquer coisa. `.snapshots()` emite
/// o valor em cache imediatamente (persistência do Firestore já guarda o
/// último snapshot da sessão anterior em disco) e atualiza de novo assim que
/// o servidor responde — mesmo padrão já usado por `allUsersProvider`/
/// `unreadDevotionalsCountProvider`/etc. `ref.invalidate` continua
/// funcionando igual (recria a stream, que já teria dado publish de novo com
/// o cache local mesmo sem isso).
final currentUserProfileProvider =
    StreamProvider.autoDispose<CurrentUserProfile?>((ref) {
      final uid = ref.watch(currentUidProvider);
      if (uid == null) return Stream.value(null);
      return FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots()
          .map((doc) {
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
              addressDetails: Address.fromMap(
                data['addressDetails'] as Map<String, dynamic>?,
              ),
              maritalStatus: data['maritalStatus'] as String? ?? '',
              photoUpdatedAt: (data['photoUpdatedAt'] as Timestamp?)
                  ?.toDate(),
              communicationsConsent:
                  data['communicationsConsent'] as bool? ?? false,
              acceptedPrivacyPolicy: data['privacyPolicyAcceptedAt'] != null,
              acceptedTermsOfUse: data['termsOfUseAcceptedAt'] != null,
            );
          });
    });

/// Espelha os métodos de admin de UserRepository.kt — aprovar/rejeitar
/// cadastro, bloquear, alterar cargos, excluir perfil. Só quem é isAdmin
/// pode chegar nessas ações (a tela que as usa só aparece pra admin no
/// menu Mais).
class UserRepository {
  UserRepository(this._firestore, this._storage);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  /// Espelha RegisterViewModel.kt: cria o doc em `users/{uid}` com status
  /// pendente de aprovação — precisa de um admin em Gerenciar Usuários pra
  /// liberar o acesso. Os campos complementares (cpf em diante) foram
  /// incrementados além do que existe hoje no app nativo, a pedido do
  /// usuário, para suportar um cadastro de membresia mais completo. CPF é
  /// obrigatório nas duas telas que chamam este método (cadastro por e-mail
  /// e completar perfil via Google) — os demais ficam opcionais aqui, quem
  /// exige o que é cada tela. Nem `membershipDate` nem a seção "Dados
  /// eclesiásticos" são coletados aqui (19/08/2026 e 20/08/2026) — passam a
  /// ser exclusividade do usuário autorizado (papel Secretaria) via
  /// `MemberRepository`, ver `members_page.dart`.
  Future<void> createUserProfile({
    required String uid,
    required String name,
    required String email,
    required DateTime birthdate,
    required String cpf,
    String phone = '',
    Address addressDetails = Address.empty,
    DateTime? baptismDate,
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
      'address': addressDetails.formatted,
      'addressDetails': addressDetails.toMap(),
      if (baptismDate != null) 'baptismDate': Timestamp.fromDate(baptismDate),
      if (privacyPolicyAccepted)
        'privacyPolicyAcceptedAt': FieldValue.serverTimestamp(),
      if (termsOfUseAccepted)
        'termsOfUseAcceptedAt': FieldValue.serverTimestamp(),
      'communicationsConsent': communicationsConsent,
      if (communicationsConsent)
        'communicationsConsentAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'status': UserStatus.pending,
      'isAdmin': false,
      'isBlocked': false,
      'roles': <String>[],
    });
  }

  /// Usado em `edit_profile_page.dart` — permite ao próprio usuário editar
  /// telefone/endereço/estado civil (regra atual já permite: `auth.uid ==
  /// userId`). `maritalStatus` voltou pra cá em 29/08/2026 (pedido do
  /// usuário) como dado pessoal comum — o resto da seção "Dados
  /// eclesiásticos" continua fora daqui, em `Member`.
  Future<void> updateProfileDetails({
    required String uid,
    required String phone,
    required Address addressDetails,
    String maritalStatus = '',
  }) {
    return _users.doc(uid).update({
      'phone': phone,
      'address': addressDetails.formatted,
      'addressDetails': addressDetails.toMap(),
      'maritalStatus': maritalStatus,
    });
  }

  /// Mesmo caminho de storage do app nativo (`users/{uid}.jpg`) — é o que a
  /// Cloud Function de sincronização de foto espera encontrar.
  Future<String> uploadProfilePhoto(String uid, File photoFile) async {
    final storagePath = 'users/$uid.jpg';
    final ref = _storage.ref(storagePath);
    await ref.putFile(photoFile);
    final photoUrl = await ref.getDownloadURL();
    await _users.doc(uid).update({
      'photoUrl': photoUrl,
      'photoStoragePath': storagePath,
      'photoUpdatedAt': FieldValue.serverTimestamp(),
    });
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

  /// Tempo real (21/08/2026) — ver `allUsersProvider`.
  Stream<List<AppUser>> watchAllUsers() {
    return _users
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map(AppUser.fromFirestore).toList());
  }

  Future<int> getPendingCount() async {
    final snapshot = await _users
        .where('status', isEqualTo: UserStatus.pending)
        .get();
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

  /// Espelha UserRepository.kt `updateFcmToken` — token salvo em
  /// `users/{uid}.fcmToken`, consumido pelas Cloud Functions (`functions/index.js`
  /// no repo nativo) que disparam push via `fcmToken`. Ver `PushNotificationService`.
  Future<void> updateFcmToken(String uid, String token) {
    return _users.doc(uid).update({'fcmToken': token});
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(FirebaseFirestore.instance, FirebaseStorage.instance);
});

/// `StreamProvider` (21/08/2026, era `FutureProvider`) — o badge de "Gerenciar
/// Usuários" e a lista devem refletir um cadastro novo assim que ele chega.
/// Pendentes primeiro, depois por nome — mesma ordenação de ManageUsersViewModel.kt.
final allUsersProvider = StreamProvider.autoDispose<List<AppUser>>((ref) {
  return ref.watch(userRepositoryProvider).watchAllUsers().map((users) {
    final sorted = [...users]
      ..sort((a, b) {
        final pendingCompare = (a.status != UserStatus.pending ? 1 : 0)
            .compareTo(b.status != UserStatus.pending ? 1 : 0);
        if (pendingCompare != 0) return pendingCompare;
        return a.name.compareTo(b.name);
      });
    return sorted;
  });
});

final pendingUserCountProvider = StreamProvider.autoDispose<int>((ref) {
  final users = ref.watch(allUsersProvider).asData?.value ?? const <AppUser>[];
  return Stream.value(
    users.where((u) => u.status == UserStatus.pending).length,
  );
});
