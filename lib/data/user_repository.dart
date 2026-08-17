import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
