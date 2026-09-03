import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/member_repository.dart';
import '../data/praise_repertoire_repository.dart';
import '../data/role_repository.dart';
import '../data/user_repository.dart';
import '../models/app_role.dart';
import '../models/app_user.dart';
import '../models/notification.dart';
import '../notifications/notification_read_sync.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

/// Espelha ManageUsersFragment.kt/ManageUsersViewModel.kt: lista de todos os
/// usuários (pendentes primeiro), busca por nome/e-mail, aprovar/rejeitar
/// cadastro pendente, bloquear, alternar cargos, excluir perfil. Só admin
/// chega aqui (gate fica no tile do menu Mais).
class ManageUsersPage extends ConsumerStatefulWidget {
  const ManageUsersPage({super.key});

  @override
  ConsumerState<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends ConsumerState<ManageUsersPage> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _louvorMirrorBackfilled = false;

  @override
  void initState() {
    super.initState();
    syncNotificationsForScreen(ref, type: NotificationType.userApproval);
    // Semeia o catálogo de papéis configuráveis (03/09/2026) na 1ª vez que
    // um admin abre esta tela, se ainda não existir — mesmo padrão de
    // `ServiceOrderExtraMomentRepository`/momentos especiais. Falha em
    // silêncio (ex.: `firestore.rules` de `roles`/`capabilityRoles` ainda
    // não deployada) — não bloqueia o resto da tela.
    ref.read(roleRepositoryProvider).seedDefaultsIfEmpty().catchError((_) {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);
    final roleCatalog = ref.watch(rolesProvider).asData?.value ?? const <AppRole>[];

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenTitle('Gerenciar Usuários'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(labelText: 'Buscar por nome ou e-mail', prefixIcon: Icon(Icons.search)),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: usersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary))),
              data: (users) {
                // Backfill do espelho `settings/louvorMembers` (03/09/2026,
                // pedido do usuário) — uma vez por visita a esta tela, não a
                // cada emissão do stream. Ver doc comment de
                // `PraiseLouvorMembersRepository.backfillFromUsers`. Espera o
                // catálogo de papéis carregar (senão nenhum usuário bateria
                // a capacidade e o backfill removeria todo mundo do espelho).
                if (!_louvorMirrorBackfilled && roleCatalog.isNotEmpty) {
                  _louvorMirrorBackfilled = true;
                  ref.read(praiseLouvorMembersRepositoryProvider).backfillFromUsers(users, roleCatalog);
                }
                final filtered = _query.trim().isEmpty
                    ? users
                    : users
                        .where((u) =>
                            u.name.toLowerCase().contains(_query.toLowerCase()) ||
                            u.email.toLowerCase().contains(_query.toLowerCase()))
                        .toList();
                if (filtered.isEmpty) {
                  return Center(child: Text('Nenhum usuário encontrado.', style: TextStyle(color: context.textSecondary)));
                }
                final duplicateCpfs = _findDuplicateCpfs(users);
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final user = filtered[index];
                    return _UserCard(
                      user: user,
                      hasDuplicateCpf: user.cpf.isNotEmpty && duplicateCpfs.contains(user.cpf),
                      roleCatalog: roleCatalog,
                    );
                  },
                );
              },
            ),
          ),
        ],
        ),
      ),
    );
  }
}

/// CPFs (não vazios) usados por mais de um perfil — não dá pra bloquear isso
/// no cadastro em si (regra `allow list: if isAdmin()` impede o
/// autocadastrante de consultar outros perfis), então o alerta aparece aqui,
/// onde o admin já tem a lista completa carregada, como checagem antes de
/// aprovar.
Set<String> _findDuplicateCpfs(List<AppUser> users) {
  final seen = <String>{};
  final duplicates = <String>{};
  for (final user in users) {
    if (user.cpf.isEmpty) continue;
    if (!seen.add(user.cpf)) duplicates.add(user.cpf);
  }
  return duplicates;
}

class _UserCard extends ConsumerWidget {
  const _UserCard({required this.user, required this.hasDuplicateCpf, required this.roleCatalog});

  final AppUser user;
  final bool hasDuplicateCpf;
  final List<AppRole> roleCatalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPending = user.status == UserStatus.pending;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name.isNotEmpty ? user.name : user.email,
                        style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (user.name.isNotEmpty)
                        Text(user.email, style: TextStyle(color: context.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                _StatusChip(status: user.status),
              ],
            ),
            if (hasDuplicateCpf) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.redAccent),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'CPF já cadastrado em outro perfil — confira antes de aprovar.',
                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            if (isPending)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => ref.read(userRepositoryProvider).setUserStatus(user.uid, UserStatus.rejected).then(
                          (_) {
                            ref.invalidate(allUsersProvider);
                            ref.invalidate(pendingUserCountProvider);
                          },
                        ),
                    child: const Text('Rejeitar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      ref.read(userRepositoryProvider).setUserStatus(user.uid, UserStatus.approved).then(
                            (_) {
                              ref.invalidate(allUsersProvider);
                              ref.invalidate(pendingUserCountProvider);
                            },
                          );
                      // Espelha ManageUsersViewModel.approve(): mescla com o
                      // aniversariante pré-cadastrado (por CPF, ver
                      // MemberRepository.upsertFromUser), sem bloquear a
                      // aprovação em si se isso falhar.
                      ref.read(memberRepositoryProvider).upsertFromUser(user).catchError((_) {});
                    },
                    child: const Text('Aprovar'),
                  ),
                ],
              )
            else ...[
              Row(
                children: [
                  Text('Bloqueado', style: TextStyle(color: context.textPrimary)),
                  const Spacer(),
                  Switch(
                    value: user.isBlocked,
                    onChanged: (value) => ref.read(userRepositoryProvider).setUserBlocked(user.uid, value).then(
                          (_) => ref.invalidate(allUsersProvider),
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _PermissionsSection(user: user, roleCatalog: roleCatalog),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _confirmDelete(context, ref, user),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Excluir'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, AppUser user) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir usuário'),
        content: Text('Tem certeza que deseja excluir "${user.name.isNotEmpty ? user.name : user.email}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(userRepositoryProvider).deleteUserProfile(user.uid).then((_) {
                ref.invalidate(allUsersProvider);
                ref.invalidate(pendingUserCountProvider);
              });
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      UserStatus.pending => ('Pendente', Colors.amber),
      UserStatus.rejected => ('Rejeitado', Colors.redAccent),
      _ => ('Aprovado', Colors.green),
    };
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white)),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}

/// Lista de papéis compactada atrás de um link "Permissões" (03/09/2026,
/// pedido do usuário: "estamos ficando com muitos papéis, e está ficando uma
/// lista extensa... vamos ajustar a tela para que fique algo mais compacto,
/// como um link de permissões, e dentro dele tenham os papéis para
/// selecionar") — um `ExpansionTile` fechado por padrão, com o subtítulo já
/// mostrando quantos papéis o usuário tem, pra dar uma ideia sem precisar
/// abrir.
///
/// A lista de chips deixou de ser hardcoded (mesma sessão, papéis
/// configuráveis) — vem de [roleCatalog] (`rolesProvider`), o mesmo catálogo
/// que o admin edita em `ManageRolesPage`. Papéis "Introdução"/"Dirigentes"
/// também podem ser obtidos automaticamente por quem entra no ministério
/// correspondente (ver `functions/index.js: onMemberMinistryRoleSync`,
/// hardcoded pros ids `introducao`/`dirigentes` — excluir esses papéis aqui
/// quebra esse sync).
class _PermissionsSection extends StatelessWidget {
  const _PermissionsSection({required this.user, required this.roleCatalog});

  final AppUser user;
  final List<AppRole> roleCatalog;

  @override
  Widget build(BuildContext context) {
    final activeCount = roleCatalog.where((r) => user.roles.contains(r.id)).length;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Text(
          activeCount == 0 ? 'Permissões' : 'Permissões ($activeCount)',
          style: TextStyle(color: context.textPrimary, fontSize: 14),
        ),
        children: [
          if (roleCatalog.isEmpty)
            Text(
              'Nenhum perfil de acesso cadastrado ainda — cadastre em "Gerenciar Perfis de Acesso".',
              style: TextStyle(color: context.textSecondary, fontSize: 12),
            )
          else
            Wrap(
              spacing: 8,
              children: [
                for (final role in roleCatalog)
                  _RoleChip(role: role, user: user, roleCatalog: roleCatalog),
              ],
            ),
        ],
      ),
    );
  }
}

class _RoleChip extends ConsumerWidget {
  const _RoleChip({required this.role, required this.user, required this.roleCatalog});

  final AppRole role;
  final AppUser user;
  final List<AppRole> roleCatalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = user.roles.contains(role.id);
    return FilterChip(
      label: Text(role.label),
      selected: enabled,
      onSelected: (value) {
        final newRoles = value ? [...user.roles, role.id] : user.roles.where((r) => r != role.id).toList();
        ref.read(userRepositoryProvider).updateRoles(user.uid, newRoles).then((_) => ref.invalidate(allUsersProvider));
        // Espelho pra sugestão de "Adicionar solista" no Ministério de
        // Louvor (02/09/2026, pedido do usuário) — só quem não é admin
        // consegue ler nomes de outros usuários por essa via, já que
        // `users.list` é admin-only (ver doc comment de
        // `PraiseLouvorMembersRepository`). Recalculado pela capacidade, não
        // pelo id do papel tocado — como papéis são configuráveis, qualquer
        // um deles pode conceder `viewPraiseOrder`, não só o antigo
        // "louvor".
        final grantsPraiseOrder = resolveCapabilities(newRoles, roleCatalog).contains(Capability.viewPraiseOrder);
        ref.read(praiseLouvorMembersRepositoryProvider).setMember(user.uid, user.name, grantsPraiseOrder);
      },
    );
  }
}
