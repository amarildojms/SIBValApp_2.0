import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import 'post_repository.dart' show currentUidProvider;

/// Espelha os checks de permissão de app/src/main/java/com/sibval/app/data/model/User.kt
/// (isAdmin || roles.contains(...)). Só o necessário até agora: nome (pra
/// pré-preencher formulários) e a permissão de ver pedidos de oração.
class CurrentUserProfile {
  const CurrentUserProfile({required this.name, required this.email, required this.isAdmin, required this.roles});

  final String name;
  final String email;
  final bool isAdmin;
  final List<String> roles;

  bool get canViewPrayerRequests => isAdmin || roles.contains('intercessao');
  bool get canManageBirthdays => isAdmin || roles.contains('secretaria');
  bool get canManageEventos => isAdmin || roles.contains('eventos');
  bool get canManageGallery => isAdmin || roles.contains('midia');
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
    isAdmin: data['isAdmin'] as bool? ?? false,
    roles: List<String>.from(data['roles'] as List? ?? const []),
  );
});

/// Espelha os métodos de admin de UserRepository.kt — aprovar/rejeitar
/// cadastro, bloquear, alterar cargos, excluir perfil. Só quem é isAdmin
/// pode chegar nessas ações (a tela que as usa só aparece pra admin no
/// menu Mais).
class UserRepository {
  UserRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users => _firestore.collection('users');

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
  return UserRepository(FirebaseFirestore.instance);
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
