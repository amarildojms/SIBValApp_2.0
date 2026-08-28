import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cifra_repository.dart';
import '../data/user_repository.dart';
import '../models/app_user.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário: "não deve existir o papel cifrista, esta atribuição será dada
/// individualmente direto ao usuário que o admin selecionar"). Botão de
/// configuração (admin-only) dentro de `CifraListPage` — marca/desmarca
/// cada usuário aprovado como editor de cifra, salvando na hora
/// (`CifraEditorsRepository.setUids`, mesmo padrão de toque-e-salva dos
/// `_RoleChip` de `manage_users_page.dart`), sem virar um papel em
/// `users/{uid}.roles`.
class CifraEditorsManagementPage extends ConsumerStatefulWidget {
  const CifraEditorsManagementPage({super.key});

  @override
  ConsumerState<CifraEditorsManagementPage> createState() =>
      _CifraEditorsManagementPageState();
}

class _CifraEditorsManagementPageState
    extends ConsumerState<CifraEditorsManagementPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggle(List<String> current, String uid, bool selected) async {
    final next = selected ? [...current, uid] : current.where((u) => u != uid).toList();
    try {
      await ref.read(cifraEditorsRepositoryProvider).setUids(next);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Falha ao salvar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);
    final uidsAsync = ref.watch(cifraEditorUidsProvider);

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Editores de Cifra'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Selecione quem pode incluir e editar cifras, além do admin.',
                style: TextStyle(color: context.textSecondary, fontSize: 13),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Buscar por nome ou e-mail',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: usersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary)),
                ),
                data: (users) {
                  final approved = users.where((u) => u.status == UserStatus.approved).toList()
                    ..sort((a, b) => a.name.compareTo(b.name));
                  final query = _query.trim().toLowerCase();
                  final filtered = query.isEmpty
                      ? approved
                      : approved
                          .where((u) =>
                              u.name.toLowerCase().contains(query) ||
                              u.email.toLowerCase().contains(query))
                          .toList();
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text('Nenhum usuário encontrado.', style: TextStyle(color: context.textSecondary)),
                    );
                  }
                  final uids = uidsAsync.asData?.value ?? const <String>[];
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final user = filtered[index];
                      final selected = uids.contains(user.uid) || user.isAdmin;
                      return CheckboxListTile(
                        title: Text(user.name, style: TextStyle(color: context.textPrimary)),
                        subtitle: Text(
                          user.isAdmin ? '${user.email} — admin (sempre habilitado)' : user.email,
                          style: TextStyle(color: context.textSecondary),
                        ),
                        value: selected,
                        onChanged: user.isAdmin
                            ? null
                            : (value) => _toggle(uids, user.uid, value ?? false),
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
