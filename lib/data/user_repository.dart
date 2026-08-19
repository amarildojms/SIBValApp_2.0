import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import 'post_repository.dart' show currentUidProvider;

/// Espelha os checks de permissão de app/src/main/java/com/sibval/app/data/model/User.kt
/// (isAdmin || roles.contains(...)). Só o necessário até agora: nome (pra
/// pré-preencher formulários) e a permissão de ver pedidos de oração.
class CurrentUserProfile {
  const CurrentUserProfile({
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.isAdmin,
    required this.roles,
  });

  final String name;
  final String email;
  final String photoUrl;
  final bool isAdmin;
  final List<String> roles;

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
  /// liberar o acesso.
  Future<void> createUserProfile({
    required String uid,
    required String name,
    required String email,
    required DateTime birthdate,
  }) {
    return _users.doc(uid).set({
      'name': name,
      'email': email,
      'birthdate': Timestamp.fromDate(birthdate),
      'birthMonth': birthdate.month,
      'birthDay': birthdate.day,
      'createdAt': FieldValue.serverTimestamp(),
      'status': UserStatus.pending,
      'isAdmin': false,
      'isBlocked': false,
      'roles': <String>[],
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
