import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/user_repository.dart';
import '../models/app_user.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);

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
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _UserCard(user: filtered[index]),
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

class _UserCard extends ConsumerWidget {
  const _UserCard({required this.user});

  final AppUser user;

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
            const SizedBox(height: 10),
            if (isPending)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => ref.read(userRepositoryProvider).setUserStatus(user.uid, UserStatus.rejected).then(
                          (_) => ref.invalidate(allUsersProvider),
                        ),
                    child: const Text('Rejeitar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => ref.read(userRepositoryProvider).setUserStatus(user.uid, UserStatus.approved).then(
                          (_) => ref.invalidate(allUsersProvider),
                        ),
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
              Wrap(
                spacing: 8,
                children: [
                  _RoleChip(label: 'Secretaria', role: UserRole.secretaria, user: user),
                  _RoleChip(label: 'Mídia', role: UserRole.midia, user: user),
                  _RoleChip(label: 'Intercessão', role: UserRole.intercessao, user: user),
                  _RoleChip(label: 'Eventos', role: UserRole.eventos, user: user),
                ],
              ),
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
              ref.read(userRepositoryProvider).deleteUserProfile(user.uid).then((_) => ref.invalidate(allUsersProvider));
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

class _RoleChip extends ConsumerWidget {
  const _RoleChip({required this.label, required this.role, required this.user});

  final String label;
  final String role;
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = user.roles.contains(role);
    return FilterChip(
      label: Text(label),
      selected: enabled,
      onSelected: (value) {
        final newRoles = value ? [...user.roles, role] : user.roles.where((r) => r != role).toList();
        ref.read(userRepositoryProvider).updateRoles(user.uid, newRoles).then((_) => ref.invalidate(allUsersProvider));
      },
    );
  }
}
