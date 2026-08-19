import 'package:cloud_firestore/cloud_firestore.dart';

/// Espelha app/src/main/java/com/sibval/app/data/model/User.kt — mesma
/// coleção `users` no Firestore. Nomeado AppUser pra não colidir com a
/// classe User do firebase_auth, já usada em outros arquivos.
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
  final String admissionForm;
  final String originChurch;
  final DateTime? baptismDate;
  final String maritalStatus;
  final String ministry;
  final String churchPosition;

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
    this.admissionForm = '',
    this.originChurch = '',
    this.baptismDate,
    this.maritalStatus = '',
    this.ministry = '',
    this.churchPosition = '',
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
      admissionForm: data['admissionForm'] as String? ?? '',
      originChurch: data['originChurch'] as String? ?? '',
      baptismDate: (data['baptismDate'] as Timestamp?)?.toDate(),
      maritalStatus: data['maritalStatus'] as String? ?? '',
      ministry: data['ministry'] as String? ?? '',
      churchPosition: data['churchPosition'] as String? ?? '',
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
      admissionForm: admissionForm,
      originChurch: originChurch,
      baptismDate: baptismDate,
      maritalStatus: maritalStatus,
      ministry: ministry,
      churchPosition: churchPosition,
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
