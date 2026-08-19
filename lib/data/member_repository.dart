import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../models/member.dart';
import 'post_repository.dart' show currentUidProvider;
import 'user_repository.dart' show currentUserProfileProvider;

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
  MemberRepository(this._firestore, this._storage);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _members => _firestore.collection('members');

  Future<List<Member>> getAll() async {
    final snapshot = await _members.orderBy('name').get();
    return snapshot.docs.map(Member.fromFirestore).toList();
  }

  Future<Member?> getByLinkedUid(String uid) async {
    if (uid.isEmpty) return null;
    final snapshot = await _members.where('linkedUid', isEqualTo: uid).limit(1).get();
    if (snapshot.docs.isEmpty) return null;
    return Member.fromFirestore(snapshot.docs.first);
  }

  /// Acha o membro do usuário logado. Tenta primeiro por `linkedUid` (rápido,
  /// já indexado); membros aprovados antes desse campo existir (19/08/2026)
  /// ainda não o têm, então cai pro CPF/e-mail — mesma busca de
  /// `upsertFromUser` — e faz o backfill de `linkedUid` no documento achado,
  /// pra próxima consulta já vir direto por `linkedUid`.
  Future<Member?> getForCurrentUser({required String uid, required String cpf, required String email}) async {
    final byLinkedUid = await getByLinkedUid(uid);
    if (byLinkedUid != null) return byLinkedUid;

    final normalizedCpf = cpf.replaceAll(RegExp(r'\D'), '');
    final normalizedEmail = email.trim().toLowerCase();
    QueryDocumentSnapshot<Map<String, dynamic>>? doc;
    if (normalizedCpf.isNotEmpty) {
      final byCpf = await _members.where('cpf', isEqualTo: normalizedCpf).limit(1).get();
      if (byCpf.docs.isNotEmpty) doc = byCpf.docs.first;
    }
    if (doc == null && normalizedEmail.isNotEmpty) {
      final byEmail = await _members.where('email', isEqualTo: normalizedEmail).limit(1).get();
      if (byEmail.docs.isNotEmpty) doc = byEmail.docs.first;
    }
    if (doc == null) return null;

    // Backfill best-effort: só funciona se o usuário logado for Secretaria/
    // admin (regra de escrita de `members`); para os demais, o `catch` evita
    // que a leitura (permitida a todo autenticado) quebre por causa disso.
    doc.reference.set({'linkedUid': uid}, SetOptions(merge: true)).catchError((_) {});
    return Member.fromFirestore(doc);
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
    String address = '',
    DateTime? membershipDate,
    String admissionForm = '',
    String originChurch = '',
    DateTime? baptismDate,
    String maritalStatus = '',
    String ministry = '',
    String churchPosition = '',
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedCpf = cpf.replaceAll(RegExp(r'\D'), '');
    final doc = _docFor(cpf: normalizedCpf, email: normalizedEmail) ?? _members.doc();

    var photoUrl = '';
    var storagePath = '';
    if (photoFile != null) {
      storagePath = 'members/${doc.id}.jpg';
      final ref = _storage.ref(storagePath);
      await ref.putFile(photoFile);
      photoUrl = await ref.getDownloadURL();
    }

    await doc.set({
      'name': name,
      'email': normalizedEmail,
      'cpf': normalizedCpf,
      'birthDay': birthDay,
      'birthMonth': birthMonth,
      'photoUrl': photoUrl,
      'storagePath': storagePath,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'phone': phone,
      'address': address,
      'membershipDate': membershipDate != null ? Timestamp.fromDate(membershipDate) : null,
      'admissionForm': admissionForm,
      'originChurch': originChurch,
      'baptismDate': baptismDate != null ? Timestamp.fromDate(baptismDate) : null,
      'maritalStatus': maritalStatus,
      'ministry': ministry,
      'churchPosition': churchPosition,
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
      createdBy: uid,
      createdAt: DateTime.now(),
      phone: phone,
      address: address,
      membershipDate: membershipDate,
      admissionForm: admissionForm,
      originChurch: originChurch,
      baptismDate: baptismDate,
      maritalStatus: maritalStatus,
      ministry: ministry,
      churchPosition: churchPosition,
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
    String address = '',
    DateTime? membershipDate,
    String admissionForm = '',
    String originChurch = '',
    DateTime? baptismDate,
    String maritalStatus = '',
    String ministry = '',
    String churchPosition = '',
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
      'createdBy': member.createdBy,
      'createdAt': member.createdAt != null ? Timestamp.fromDate(member.createdAt!) : FieldValue.serverTimestamp(),
      'phone': phone,
      'address': address,
      'membershipDate': membershipDate != null ? Timestamp.fromDate(membershipDate) : null,
      'admissionForm': admissionForm,
      'originChurch': originChurch,
      'baptismDate': baptismDate != null ? Timestamp.fromDate(baptismDate) : null,
      'maritalStatus': maritalStatus,
      'ministry': ministry,
      'churchPosition': churchPosition,
      'linkedUid': member.linkedUid,
    };

    final canonicalId = _canonicalId(cpf: normalizedCpf, email: normalizedEmail) ?? member.id;
    if (canonicalId != member.id) {
      await _members.doc(canonicalId).set(data);
      await _members.doc(member.id).delete();
    } else {
      await _members.doc(member.id).set(data);
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
  /// aprovado, sem duplicar. `membershipDate` nunca é incluído aqui de
  /// propósito — é exclusividade do usuário autorizado (Secretaria) editando
  /// diretamente o registro em Rol de Membros, e o merge preserva o que já
  /// estiver lá.
  Future<void> upsertFromUser(AppUser user) async {
    if (user.birthMonth < 1 || user.birthMonth > 12 || user.birthDay < 1 || user.birthDay > 31) {
      return;
    }
    final normalizedEmail = user.email.trim().toLowerCase();
    final normalizedCpf = user.cpf.replaceAll(RegExp(r'\D'), '');
    if (normalizedCpf.isEmpty && normalizedEmail.isEmpty) return;

    final canonicalId = normalizedCpf.isNotEmpty ? normalizedCpf : normalizedEmail;
    final existingId = await _findExistingMemberId(cpf: normalizedCpf, email: normalizedEmail);

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
      'admissionForm': user.admissionForm,
      'originChurch': user.originChurch,
      'baptismDate': user.baptismDate != null ? Timestamp.fromDate(user.baptismDate!) : null,
      'maritalStatus': user.maritalStatus,
      'ministry': user.ministry,
      'churchPosition': user.churchPosition,
      if (user.photoUrl.isNotEmpty) 'photoUrl': user.photoUrl,
    };

    await _members.doc(canonicalId).set(data, SetOptions(merge: true));
    if (existingId != null && existingId != canonicalId) {
      await _members.doc(existingId).delete();
    }
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
  DocumentReference<Map<String, dynamic>>? _docFor({required String cpf, required String email}) {
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
  Future<String?> _findExistingMemberId({required String cpf, required String email}) async {
    if (cpf.isNotEmpty) {
      if ((await _members.doc(cpf).get()).exists) return cpf;
      final byCpf = await _members.where('cpf', isEqualTo: cpf).limit(1).get();
      if (byCpf.docs.isNotEmpty) return byCpf.docs.first.id;
    }
    if (email.isNotEmpty) {
      if ((await _members.doc(email).get()).exists) return email;
      final byEmail = await _members.where('email', isEqualTo: email).limit(1).get();
      if (byEmail.docs.isNotEmpty) return byEmail.docs.first.id;
    }
    return null;
  }
}

final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  return MemberRepository(FirebaseFirestore.instance, FirebaseStorage.instance);
});

final membersProvider = FutureProvider.autoDispose<List<Member>>((ref) {
  return ref.watch(memberRepositoryProvider).getAll();
});

/// Membro vinculado ao usuário logado — alimenta o % de cadastro e "Membro
/// SIB Val há..." na tela Mais. `null` quando o usuário ainda não tem
/// registro em `members` (ex.: cadastro pendente de aprovação).
final myMemberProvider = FutureProvider.autoDispose((ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  final profile = await ref.watch(currentUserProfileProvider.future);
  if (profile == null) return null;
  return ref.watch(memberRepositoryProvider).getForCurrentUser(uid: uid, cpf: profile.cpf, email: profile.email);
});
