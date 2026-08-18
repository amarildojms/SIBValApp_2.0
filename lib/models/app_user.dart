import 'package:cloud_firestore/cloud_firestore.dart';

/// Espelha app/src/main/java/com/sibval/app/data/model/User.kt — mesma
/// coleção `users` no Firestore. Nomeado AppUser pra não colidir com a
/// classe User do firebase_auth, já usada em outros arquivos.
class AppUser {
  final String uid;
  final String name;
  final String email;
  final String status;
  final bool isAdmin;
  final bool isBlocked;
  final List<String> roles;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.status,
    required this.isAdmin,
    required this.isBlocked,
    required this.roles,
  });

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppUser(
      uid: doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      status: data['status'] as String? ?? UserStatus.approved,
      isAdmin: data['isAdmin'] as bool? ?? false,
      isBlocked: data['isBlocked'] as bool? ?? false,
      roles: List<String>.from(data['roles'] as List? ?? const []),
    );
  }

  AppUser copyWith({String? status, bool? isBlocked, List<String>? roles}) {
    return AppUser(
      uid: uid,
      name: name,
      email: email,
      status: status ?? this.status,
      isAdmin: isAdmin,
      isBlocked: isBlocked ?? this.isBlocked,
      roles: roles ?? this.roles,
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
}
