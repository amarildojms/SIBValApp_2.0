import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/member.dart';

/// Espelha app/src/main/java/com/sibval/app/data/repository/MemberRepository.kt.
/// A foto já sai comprimida do image_picker (maxWidth/maxHeight/imageQuality),
/// equivalente ao ImageCompressor.kt nativo.
class MemberRepository {
  MemberRepository(this._firestore, this._storage);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _members => _firestore.collection('members');

  Future<List<Member>> getAll() async {
    final snapshot = await _members.orderBy('name').get();
    return snapshot.docs.map(Member.fromFirestore).toList();
  }

  Future<Member> create({
    required String name,
    required String email,
    required int birthDay,
    required int birthMonth,
    required File? photoFile,
    required String uid,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final doc = normalizedEmail.isNotEmpty ? _members.doc(normalizedEmail) : _members.doc();

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
      'birthDay': birthDay,
      'birthMonth': birthMonth,
      'photoUrl': photoUrl,
      'storagePath': storagePath,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return Member(
      id: doc.id,
      name: name,
      email: normalizedEmail,
      birthDay: birthDay,
      birthMonth: birthMonth,
      photoUrl: photoUrl,
      storagePath: storagePath,
      createdBy: uid,
      createdAt: DateTime.now(),
    );
  }

  /// O documento é indexado pelo e-mail — é assim que a Cloud Function que
  /// sincroniza a foto de perfil acha o membro certo. Se o e-mail mudar, o
  /// documento precisa migrar de id (senão vira lixo órfão, ou pior, outro
  /// membro reusa o id antigo).
  Future<void> update({
    required Member member,
    required String name,
    required String email,
    required int birthDay,
    required int birthMonth,
    required File? photoFile,
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
    final data = {
      'name': name,
      'email': normalizedEmail,
      'birthDay': birthDay,
      'birthMonth': birthMonth,
      'photoUrl': photoUrl,
      'storagePath': storagePath,
      'createdBy': member.createdBy,
      'createdAt': member.createdAt != null ? Timestamp.fromDate(member.createdAt!) : FieldValue.serverTimestamp(),
    };

    final emailChanged = normalizedEmail.isNotEmpty && normalizedEmail != member.id;
    if (emailChanged) {
      await _members.doc(normalizedEmail).set(data);
      await _members.doc(member.id).delete();
    } else {
      await _members.doc(member.id).set(data);
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
}

final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  return MemberRepository(FirebaseFirestore.instance, FirebaseStorage.instance);
});

final membersProvider = FutureProvider.autoDispose<List<Member>>((ref) {
  return ref.watch(memberRepositoryProvider).getAll();
});
