import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:diacritic/diacritic.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/address.dart';
import '../models/app_user.dart';
import '../models/member.dart';
import 'ministry_repository.dart';
import 'post_repository.dart' show currentUidProvider;
import 'user_repository.dart' show currentUserProfileProvider;

/// Cargo que marca o membro como líder daquele vínculo de ministério
/// (`MemberMinistry`) — comparação sem acento/maiúsculas, casamento exato
/// (não "contém") pra "Vice-líder"/"Auxiliar de líder" não contarem como
/// liderança de verdade (03/09/2026, Agenda: só quem tem esse cargo pode
/// agendar compromissos pro ministério — ver `Ministry.leaderUids`).
bool isLeaderCargo(String cargo) =>
    removeDiacritics(cargo).trim().toLowerCase() == 'lider';

Set<String> _leaderMinistryIds(List<MemberMinistry> ministries) {
  return {
    for (final m in ministries)
      if (m.cargos.any(isLeaderCargo)) m.ministryId,
  };
}

/// Espelha app/src/main/java/com/sibval/app/data/repository/MemberRepository.kt.
/// A foto já sai comprimida do image_picker (maxWidth/maxHeight/imageQuality),
/// equivalente ao ImageCompressor.kt nativo.
///
/// O documento é indexado preferencialmente pelo CPF (chave estável, imune a
/// troca de e-mail) — incremento sem equivalente no nativo, que só indexava
/// por e-mail. Membros sem CPF (cadastro manual rápido ou registros antigos)
/// caem pro e-mail como antes; sem nenhum dos dois, id autogerado. É assim
/// que `upsertFromUser` e a Cloud Function `onUserPhotoUpdated`
/// (SIBValApp2/functions/index.js) acham o membro certo pra mesclar/
/// sincronizar. Se o CPF ou e-mail mudar, o documento precisa migrar de id
/// (senão vira lixo órfão, ou pior, outro membro reusa o id antigo).
class MemberRepository {
  MemberRepository(this._firestore, this._storage, this._ministries);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final MinistryRepository _ministries;

  CollectionReference<Map<String, dynamic>> get _members =>
      _firestore.collection('members');

  DocumentReference<Map<String, dynamic>> get _agendaLeadersDoc =>
      _firestore.collection('settings').doc('agendaLeaders');

  Future<List<Member>> getAll() async {
    final snapshot = await _members.orderBy('name').get();
    return snapshot.docs.map(Member.fromFirestore).toList();
  }

  /// Tempo real (21/08/2026) — ver `membersProvider`.
  Stream<List<Member>> watchAll() {
    return _members
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map(Member.fromFirestore).toList());
  }

  Future<Member?> getByLinkedUid(String uid) async {
    if (uid.isEmpty) return null;
    final snapshot = await _members
        .where('linkedUid', isEqualTo: uid)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return Member.fromFirestore(snapshot.docs.first);
  }

  /// Acha o id do documento do membro do usuário logado. Tenta primeiro por
  /// `linkedUid` (rápido, já indexado); membros aprovados antes desse campo
  /// existir (19/08/2026) ainda não o têm, então cai pro CPF/e-mail — mesma
  /// busca de `upsertFromUser` — e faz o backfill de `linkedUid` no
  /// documento achado, pra próxima consulta já vir direto por `linkedUid`.
  Future<String?> _findMemberDocId({
    required String uid,
    required String cpf,
    required String email,
  }) async {
    final byLinkedUid = await getByLinkedUid(uid);
    if (byLinkedUid != null) return byLinkedUid.id;

    final normalizedCpf = cpf.replaceAll(RegExp(r'\D'), '');
    final normalizedEmail = email.trim().toLowerCase();
    QueryDocumentSnapshot<Map<String, dynamic>>? doc;
    if (normalizedCpf.isNotEmpty) {
      final byCpf = await _members
          .where('cpf', isEqualTo: normalizedCpf)
          .limit(1)
          .get();
      if (byCpf.docs.isNotEmpty) doc = byCpf.docs.first;
    }
    if (doc == null && normalizedEmail.isNotEmpty) {
      final byEmail = await _members
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();
      if (byEmail.docs.isNotEmpty) doc = byEmail.docs.first;
    }
    if (doc == null) return null;

    // Backfill best-effort: só funciona se o usuário logado for Secretaria/
    // admin (regra de escrita de `members`); para os demais, o `catch` evita
    // que a leitura (permitida a todo autenticado) quebre por causa disso.
    doc.reference
        .set({'linkedUid': uid}, SetOptions(merge: true))
        .catchError((_) {});
    return doc.id;
  }

  /// Observa o membro do usuário logado em tempo real (20/08/2026) — qualquer
  /// edição feita pela Secretaria em Rol de Membros (inclusive
  /// ministérios/cargos) chega direto pra quem estiver com "Editar perfil"
  /// ou a tela Mais abertos, sem precisar reabrir a tela. Resolve o id do
  /// documento uma vez (`_findMemberDocId`) e depois segue por `snapshots()`.
  Stream<Member?> watchForCurrentUser({
    required String uid,
    required String cpf,
    required String email,
  }) async* {
    final docId = await _findMemberDocId(uid: uid, cpf: cpf, email: email);
    if (docId == null) {
      yield null;
      return;
    }
    yield* _members
        .doc(docId)
        .snapshots()
        .map((doc) => doc.exists ? Member.fromFirestore(doc) : null);
  }

  Future<Member> create({
    required String name,
    required String email,
    required String cpf,
    required int birthDay,
    required int birthMonth,
    required File? photoFile,
    required String uid,
    String phone = '',
    Address addressDetails = Address.empty,
    DateTime? membershipDate,
    String admissionForm = '',
    String originChurch = '',
    DateTime? baptismDate,
    List<MemberMinistry> ministries = const [],
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedCpf = cpf.replaceAll(RegExp(r'\D'), '');
    final doc =
        _docFor(cpf: normalizedCpf, email: normalizedEmail) ?? _members.doc();

    var photoUrl = '';
    var storagePath = '';
    if (photoFile != null) {
      storagePath = 'members/${doc.id}.jpg';
      final ref = _storage.ref(storagePath);
      await ref.putFile(photoFile);
      photoUrl = await ref.getDownloadURL();
    }

    final ministryIds = ministries.map((m) => m.ministryId).toList();
    await doc.set({
      'name': name,
      'email': normalizedEmail,
      'cpf': normalizedCpf,
      'birthDay': birthDay,
      'birthMonth': birthMonth,
      'photoUrl': photoUrl,
      'storagePath': storagePath,
      if (photoFile != null) 'photoUpdatedAt': FieldValue.serverTimestamp(),
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'phone': phone,
      'address': addressDetails.formatted,
      'addressDetails': addressDetails.toMap(),
      'membershipDate': membershipDate != null
          ? Timestamp.fromDate(membershipDate)
          : null,
      'admissionForm': admissionForm,
      'originChurch': originChurch,
      'baptismDate': baptismDate != null
          ? Timestamp.fromDate(baptismDate)
          : null,
      'ministryIds': ministryIds,
      'ministries': ministries.map((m) => m.toMap()).toList(),
    });

    return Member(
      id: doc.id,
      name: name,
      email: normalizedEmail,
      cpf: normalizedCpf,
      birthDay: birthDay,
      birthMonth: birthMonth,
      photoUrl: photoUrl,
      storagePath: storagePath,
      photoUpdatedAt: photoFile != null ? DateTime.now() : null,
      createdBy: uid,
      createdAt: DateTime.now(),
      phone: phone,
      address: addressDetails.formatted,
      addressDetails: addressDetails,
      membershipDate: membershipDate,
      admissionForm: admissionForm,
      originChurch: originChurch,
      baptismDate: baptismDate,
      ministryIds: ministryIds,
      ministries: ministries,
    );
  }

  Future<void> update({
    required Member member,
    required String name,
    required String email,
    required String cpf,
    required int birthDay,
    required int birthMonth,
    required File? photoFile,
    String phone = '',
    Address addressDetails = Address.empty,
    DateTime? membershipDate,
    String admissionForm = '',
    String originChurch = '',
    DateTime? baptismDate,
    List<MemberMinistry> ministries = const [],
  }) async {
    var photoUrl = member.photoUrl;
    var storagePath = member.storagePath;
    if (photoFile != null) {
      if (storagePath.isNotEmpty) {
        try {
          await _storage.ref(storagePath).delete();
        } catch (_) {}
      }
      storagePath = 'members/${member.id}.jpg';
      final ref = _storage.ref(storagePath);
      await ref.putFile(photoFile);
      photoUrl = await ref.getDownloadURL();
    }

    final normalizedEmail = email.trim().toLowerCase();
    final normalizedCpf = cpf.replaceAll(RegExp(r'\D'), '');
    final data = {
      'name': name,
      'email': normalizedEmail,
      'cpf': normalizedCpf,
      'birthDay': birthDay,
      'birthMonth': birthMonth,
      'photoUrl': photoUrl,
      'storagePath': storagePath,
      if (photoFile != null) 'photoUpdatedAt': FieldValue.serverTimestamp(),
      'createdBy': member.createdBy,
      'createdAt': member.createdAt != null
          ? Timestamp.fromDate(member.createdAt!)
          : FieldValue.serverTimestamp(),
      'phone': phone,
      'address': addressDetails.formatted,
      'addressDetails': addressDetails.toMap(),
      'membershipDate': membershipDate != null
          ? Timestamp.fromDate(membershipDate)
          : null,
      'admissionForm': admissionForm,
      'originChurch': originChurch,
      'baptismDate': baptismDate != null
          ? Timestamp.fromDate(baptismDate)
          : null,
      'ministryIds': ministries.map((m) => m.ministryId).toList(),
      'ministries': ministries.map((m) => m.toMap()).toList(),
      'linkedUid': member.linkedUid,
    };

    final canonicalId =
        _canonicalId(cpf: normalizedCpf, email: normalizedEmail) ?? member.id;
    if (canonicalId != member.id) {
      await _members.doc(canonicalId).set(data, SetOptions(merge: true));
      await _members.doc(member.id).delete();
    } else {
      // `merge: true` (25/08/2026, corrigindo bug pré-existente): sem isso,
      // esse `set` sobrescrevia o documento inteiro e apagava em silêncio os
      // campos que só a Cloud Function escreve
      // (`lastMembershipAnniversaryFeedPostDate`, `membershipAnniversaryFeedPostId`,
      // `lastBirthdayFeedPostDate`) a cada edição pela Secretaria — inclusive a
      // própria edição de `membershipDate` que devia disparar a retratação do
      // post fixado (`removeMembershipAnniversaryFromFeed`,
      // SIBValApp2/functions/index.js), que não achava mais o post pra
      // apagar porque o campo já tinha sumido antes da function rodar. Os
      // campos explícitos em `data` (inclusive os `null`) continuam
      // sobrescrevendo normalmente — merge só preserva o que não está listado
      // aqui.
      await _members.doc(member.id).set(data, SetOptions(merge: true));
    }

    // Sincroniza `ministries/{id}.leaderUids` (03/09/2026, Agenda) — só
    // funciona se o membro já tiver conta vinculada (`linkedUid`); sem
    // backfill pra quem virar líder antes de ter conta, mesmo padrão já
    // usado em todo o resto desta base (ver CLAUDE.md).
    if (member.linkedUid.isNotEmpty) {
      final oldLeaderIds = _leaderMinistryIds(member.ministries);
      final newLeaderIds = _leaderMinistryIds(ministries);
      for (final id in newLeaderIds.difference(oldLeaderIds)) {
        await _ministries.addLeader(id, member.linkedUid);
      }
      for (final id in oldLeaderIds.difference(newLeaderIds)) {
        await _ministries.removeLeader(id, member.linkedUid);
      }

      // Espelho global "é líder de algum ministério" (03/09/2026, Agenda) —
      // `settings/agendaLeaders.uids` alimenta `isAnyAgendaLeader()` em
      // `firestore.rules`, que não pode iterar `members` pra checar isso
      // (mesmo motivo de `Ministry.leaderUids` acima, só que sem amarrar a
      // um ministério específico: qualquer líder pode agendar compromisso
      // pra qualquer ministério/toda a igreja agora).
      final wasAnyLeader = oldLeaderIds.isNotEmpty;
      final isAnyLeaderNow = newLeaderIds.isNotEmpty;
      if (isAnyLeaderNow && !wasAnyLeader) {
        await _agendaLeadersDoc.set({
          'uids': FieldValue.arrayUnion([member.linkedUid]),
        }, SetOptions(merge: true));
      } else if (!isAnyLeaderNow && wasAnyLeader) {
        await _agendaLeadersDoc.set({
          'uids': FieldValue.arrayRemove([member.linkedUid]),
        }, SetOptions(merge: true));
      }
    }
  }

  /// Espelha MemberRepository.kt upsertFromUser(): chamado ao aprovar um
  /// cadastro (ver ManageUsersPage), cria ou atualiza a entrada de
  /// aniversariante correspondente com os dados do usuário aprovado. Casa
  /// primeiro por CPF; se não achar (membro pré-cadastrado sem CPF ainda),
  /// cai pro e-mail — e se achar por um id "antigo" (e-mail) enquanto o
  /// usuário já tem CPF, migra o documento pro id canônico (CPF), preservando
  /// o que já existia ali (SetOptions.merge) — é o "mesclar dados" pedido:
  /// o aniversariante cadastrado manualmente vira o mesmo registro do usuário
  /// aprovado, sem duplicar. Nem `membershipDate` nem os campos da seção
  /// "Dados eclesiásticos" (admissionForm em diante) entram aqui de
  /// propósito — são exclusividade do usuário autorizado (Secretaria)
  /// editando diretamente o registro em Rol de Membros (20/08/2026), e o
  /// merge preserva o que já estiver lá.
  Future<void> upsertFromUser(AppUser user) async {
    if (user.birthMonth < 1 ||
        user.birthMonth > 12 ||
        user.birthDay < 1 ||
        user.birthDay > 31) {
      return;
    }
    final normalizedEmail = user.email.trim().toLowerCase();
    final normalizedCpf = user.cpf.replaceAll(RegExp(r'\D'), '');
    if (normalizedCpf.isEmpty && normalizedEmail.isEmpty) return;

    final canonicalId = normalizedCpf.isNotEmpty
        ? normalizedCpf
        : normalizedEmail;
    final existingId = await _findExistingMemberId(
      cpf: normalizedCpf,
      email: normalizedEmail,
    );

    final data = <String, dynamic>{
      'name': user.name,
      'email': normalizedEmail,
      'cpf': normalizedCpf,
      'birthDay': user.birthDay,
      'birthMonth': user.birthMonth,
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'linkedUid': user.uid,
      'phone': user.phone,
      'address': user.address,
      'addressDetails': user.addressDetails.toMap(),
      if (user.photoUrl.isNotEmpty) 'photoUrl': user.photoUrl,
      if (user.photoUrl.isNotEmpty)
        'photoUpdatedAt': FieldValue.serverTimestamp(),
      if (user.baptismDate != null)
        'baptismDate': Timestamp.fromDate(user.baptismDate!),
    };

    await _members.doc(canonicalId).set(data, SetOptions(merge: true));
    if (existingId != null && existingId != canonicalId) {
      await _members.doc(existingId).delete();
    }
  }

  /// Campo de `members` que o próprio usuário (dono do registro via
  /// `linkedUid`) pode editar sem ser Secretaria — ver `firestore.rules`
  /// nativo, `EditProfilePage`. Os demais campos self-editable
  /// (`updateSelfEditableDetails`, abaixo) ganharam o mesmo privilégio em
  /// 29/08/2026. `membershipDate`/`ministries` continuam exclusividade da
  /// Secretaria em Rol de Membros.
  Future<void> updateBaptismDate(String memberId, DateTime? baptismDate) {
    return _members.doc(memberId).update({
      'baptismDate': baptismDate != null
          ? Timestamp.fromDate(baptismDate)
          : null,
    });
  }

  /// Mesmo privilégio de `updateBaptismDate` — o próprio dono do registro
  /// (`linkedUid`) pode editar telefone/endereço/forma de adesão/igreja de
  /// origem em `EditProfilePage`, sem depender da Secretaria. Ver
  /// `firestore.rules` (`members.update`, `affectedKeys().hasOnly([...])`).
  ///
  /// Renomeado de `updateEcclesiasticalDetails` (29/08/2026, pedido do
  /// usuário) — ganhou `phone`/`addressDetails`, que antes só chegavam ao
  /// `Member` na aprovação do cadastro (`upsertFromUser`) e nunca mais
  /// depois disso: editar o endereço em "Editar perfil" atualizava só
  /// `users/{uid}`, deixando o Rol de Membros desatualizado (reportado pelo
  /// usuário com o exemplo do endereço).
  Future<void> updateSelfEditableDetails(
    String memberId, {
    required String phone,
    required Address addressDetails,
    required String admissionForm,
    required String originChurch,
  }) {
    return _members.doc(memberId).update({
      'phone': phone,
      'address': addressDetails.formatted,
      'addressDetails': addressDetails.toMap(),
      'admissionForm': admissionForm,
      'originChurch': originChurch,
    });
  }

  Future<void> delete(Member member) async {
    if (member.storagePath.isNotEmpty) {
      try {
        await _storage.ref(member.storagePath).delete();
      } catch (_) {}
    }
    await _members.doc(member.id).delete();
  }

  /// Doc ref pronto pra criar em cima (só quando cpf/email não vazios —
  /// `create()` cai pro id autogerado quando os dois faltam).
  DocumentReference<Map<String, dynamic>>? _docFor({
    required String cpf,
    required String email,
  }) {
    final id = _canonicalId(cpf: cpf, email: email);
    return id == null ? null : _members.doc(id);
  }

  String? _canonicalId({required String cpf, required String email}) {
    if (cpf.isNotEmpty) return cpf;
    if (email.isNotEmpty) return email;
    return null;
  }

  /// Acha o id do documento existente pro CPF/e-mail informado, mesmo que o
  /// doc não esteja (ainda) na chave canônica — ex.: membro cadastrado antes
  /// do CPF existir, indexado por e-mail, ou um `cpf` gravado como campo sem
  /// o doc ter sido migrado pra esse id.
  Future<String?> _findExistingMemberId({
    required String cpf,
    required String email,
  }) async {
    if (cpf.isNotEmpty) {
      if ((await _members.doc(cpf).get()).exists) return cpf;
      final byCpf = await _members.where('cpf', isEqualTo: cpf).limit(1).get();
      if (byCpf.docs.isNotEmpty) return byCpf.docs.first.id;
    }
    if (email.isNotEmpty) {
      if ((await _members.doc(email).get()).exists) return email;
      final byEmail = await _members
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (byEmail.docs.isNotEmpty) return byEmail.docs.first.id;
    }
    return null;
  }
}

final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  return MemberRepository(
    FirebaseFirestore.instance,
    FirebaseStorage.instance,
    ref.watch(ministryRepositoryProvider),
  );
});

/// `StreamProvider` (21/08/2026, era `FutureProvider`) — Rol de Membros e
/// Aniversariantes ficavam sem atualizar sozinhos quando a Cloud Function
/// `onUserPhotoUpdated` sincronizava a foto do perfil pro `Member` vinculado:
/// nada invalidava esse provider depois de uma escrita feita do lado do
/// servidor. Mesmo padrão já usado em `myMemberProvider`.
final membersProvider = StreamProvider.autoDispose<List<Member>>((ref) {
  return ref.watch(memberRepositoryProvider).watchAll();
});

/// Membro vinculado ao usuário logado — alimenta o % de cadastro, "Membro
/// SIB Val há..." e a seção "Dados eclesiásticos" (majoritariamente só
/// leitura — `admissionForm`/`originChurch`/`baptismDate` são exceção,
/// editáveis pelo próprio usuário desde 29/08/2026) da tela Mais/Editar
/// perfil. `null` quando o usuário ainda não tem registro em
/// `members` (ex.: cadastro pendente de aprovação). É um `StreamProvider`
/// (20/08/2026, era `FutureProvider`) pra refletir em tempo real qualquer
/// edição que a Secretaria fizer em Rol de Membros enquanto a tela estiver
/// aberta, sem precisar reabrir.
final myMemberProvider = StreamProvider.autoDispose<Member?>((ref) async* {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) {
    yield null;
    return;
  }
  final profile = await ref.watch(currentUserProfileProvider.future);
  if (profile == null) {
    yield null;
    return;
  }
  yield* ref
      .watch(memberRepositoryProvider)
      .watchForCurrentUser(uid: uid, cpf: profile.cpf, email: profile.email);
});
