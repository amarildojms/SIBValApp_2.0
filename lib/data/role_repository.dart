import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_role.dart';

/// Espelha o papel/capacidade configurável (sibval_app_2.0, 03/09/2026) — ver
/// doc comment de `Capability`/`AppRole` (`lib/models/app_role.dart`). Sem
/// equivalente no nativo.
///
/// Mantém duas coleções em paralelo:
/// - `roles/{roleId}` — o que o app lê pra resolver as capacidades do
///   usuário logado (`resolveCapabilities`) e o que `ManageRolesPage` edita.
/// - `capabilityRoles/{capabilityId}.roleIds` — índice invertido, nunca lido
///   pelo cliente, só existe pra `hasCapability()` em `firestore.rules`
///   conseguir checar "algum dos meus papéis concede X" com um único
///   `get()`, já que regras do Firestore não iteram um array fazendo um
///   `get()` por item.
class RoleRepository {
  RoleRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _roles => _firestore.collection('roles');
  CollectionReference<Map<String, dynamic>> get _capabilityRoles => _firestore.collection('capabilityRoles');

  Stream<List<AppRole>> watchAll() {
    return _roles.orderBy('label').snapshots().map(
          (s) => s.docs.map(AppRole.fromFirestore).toList(),
        );
  }

  /// Chamado uma vez por visita a `ManageUsersPage`/`ManageRolesPage` (só
  /// admin chega lá, que já tem permissão de escrita em `roles`) — mesmo
  /// padrão de `ServiceOrderExtraMomentRepository`/momentos especiais.
  Future<void> seedDefaultsIfEmpty() async {
    final snapshot = await _roles.limit(1).get();
    if (snapshot.docs.isNotEmpty) return;
    for (final role in defaultAppRoles) {
      await saveRole(role);
    }
  }

  String newRoleId() => _roles.doc().id;

  /// Grava o papel e mantém `capabilityRoles` sincronizado num batch só —
  /// pra cada capacidade do catálogo, adiciona ou remove [role.id] da lista
  /// conforme ele concede aquela capacidade ou não.
  Future<void> saveRole(AppRole role) async {
    final batch = _firestore.batch();
    batch.set(_roles.doc(role.id), role.toMap());
    for (final cap in Capability.all) {
      final capId = cap.$1;
      final ref = _capabilityRoles.doc(capId);
      if (role.capabilities.contains(capId)) {
        batch.set(ref, {
          'roleIds': FieldValue.arrayUnion([role.id]),
        }, SetOptions(merge: true));
      } else {
        batch.set(ref, {
          'roleIds': FieldValue.arrayRemove([role.id]),
        }, SetOptions(merge: true));
      }
    }
    await batch.commit();
  }

  Future<void> deleteRole(String roleId) async {
    final batch = _firestore.batch();
    batch.delete(_roles.doc(roleId));
    for (final cap in Capability.all) {
      batch.set(_capabilityRoles.doc(cap.$1), {
        'roleIds': FieldValue.arrayRemove([roleId]),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }
}

final roleRepositoryProvider = Provider<RoleRepository>(
  (ref) => RoleRepository(FirebaseFirestore.instance),
);

final rolesProvider = StreamProvider.autoDispose<List<AppRole>>((ref) {
  return ref.watch(roleRepositoryProvider).watchAll();
});

/// Une as capacidades de todos os papéis em [userRoles] contra o catálogo
/// [roles]. Não faz o bypass de admin — quem chama decide se soma
/// `isAdmin ||` por fora (mesmo padrão dos getters de `CurrentUserProfile`).
Set<String> resolveCapabilities(List<String> userRoles, List<AppRole> roles) {
  final result = <String>{};
  for (final role in roles) {
    if (userRoles.contains(role.id)) result.addAll(role.capabilities);
  }
  return result;
}

/// Verifica se um usuário (via [isAdmin]/[userRoles]) tem [capabilityId],
/// combinando contra o catálogo [roles] — usado pra filtrar candidatos numa
/// lista de `AppUser` (ex.: "quem pode ser Dirigente" em
/// `LeaderScheduleFormPage`/`ServiceOrderListPage`), fora do contexto do
/// próprio usuário logado (que já tem isso pronto em
/// `CurrentUserProfile.capabilities`).
bool userHasCapability(bool isAdmin, List<String> userRoles, String capabilityId, List<AppRole> roles) {
  if (isAdmin) return true;
  return resolveCapabilities(userRoles, roles).contains(capabilityId);
}
