import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/role_repository.dart';
import '../models/app_role.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

/// Sem equivalente no app nativo — feature nova (03/09/2026, pedido do
/// usuário: papéis/permissões configuráveis). Antes cada papel (Secretaria,
/// Mídia, Dirigentes...) e o que ele concedia eram hardcoded em `UserRole` +
/// `CurrentUserProfile` (Flutter) e em uma função própria por papel em
/// `firestore.rules` — mudar isso exigia código novo e um deploy. Agora o
/// admin cria/renomeia/exclui papéis livremente aqui, escolhendo pra cada um
/// quais das capacidades abaixo ele concede.
///
/// A lista de capacidades possíveis continua fixa (`Capability.all`, ver
/// `lib/models/app_role.dart`) — cada uma corresponde a um ponto real de
/// checagem em alguma tela ou coleção do Firestore (`firestore.rules`,
/// `hasCapability`); só a associação papel→capacidades é dado.
///
/// Só admin chega aqui — gate no ponto de chamada (`SettingsManagementPage`),
/// mesmo padrão do resto do app.
class ManageRolesPage extends ConsumerStatefulWidget {
  const ManageRolesPage({super.key});

  @override
  ConsumerState<ManageRolesPage> createState() => _ManageRolesPageState();
}

class _ManageRolesPageState extends ConsumerState<ManageRolesPage> {
  @override
  void initState() {
    super.initState();
    ref.read(roleRepositoryProvider).seedDefaultsIfEmpty().catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(rolesProvider);

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Gerenciar Perfis de Acesso'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Crie perfis de acesso e escolha quais permissões cada um concede. '
                'Depois, atribua os perfis de acesso aos usuários em "Gerenciar Usuários".',
                style: TextStyle(color: context.textSecondary, fontSize: 13),
              ),
            ),
            Expanded(
              child: rolesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary)),
                ),
                data: (roles) {
                  if (roles.isEmpty) {
                    return Center(
                      child: Text(
                        'Nenhum perfil de acesso cadastrado ainda.',
                        style: TextStyle(color: context.textSecondary),
                      ),
                    );
                  }
                  return ListView.builder(
                    // `bottom: 80` (03/09/2026, bug relatado pelo usuário) —
                    // sem isso, o último card ficava escondido atrás do FAB
                    // "Novo perfil de acesso", sem como tocar no botão de
                    // excluir dele.
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: roles.length,
                    itemBuilder: (context, index) {
                      final role = roles[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text(role.label, style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            role.capabilities.isEmpty
                                ? 'Nenhuma permissão concedida ainda'
                                : role.capabilities.map(Capability.labelFor).join(', '),
                            style: TextStyle(color: context.textSecondary, fontSize: 12),
                          ),
                          onTap: () => _showEditDialog(context, ref, role: role),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _confirmDelete(context, ref, role),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Novo perfil de acesso'),
      ),
    );
  }

  /// Diálogo único de criar/editar — `role == null` cria um novo (id
  /// aleatório, ver `RoleRepository.newRoleId`), senão edita o passado.
  void _showEditDialog(BuildContext context, WidgetRef ref, {AppRole? role}) {
    final controller = TextEditingController(text: role?.label ?? '');
    final selected = {...?role?.capabilities};
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(role == null ? 'Novo perfil de acesso' : 'Editar perfil de acesso'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nome do perfil de acesso'),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final cap in Capability.all)
                        CheckboxListTile(
                          value: selected.contains(cap.$1),
                          title: Text(cap.$2),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (value) => setDialogState(() {
                            if (value ?? false) {
                              selected.add(cap.$1);
                            } else {
                              selected.remove(cap.$1);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                final label = controller.text.trim();
                if (label.isEmpty) return;
                Navigator.of(dialogContext).pop();
                final repo = ref.read(roleRepositoryProvider);
                try {
                  await repo.saveRole(
                    AppRole(
                      id: role?.id ?? repo.newRoleId(),
                      label: label,
                      capabilities: selected.toList(),
                    ),
                  );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha ao salvar: $e')));
                  }
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, AppRole role) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir perfil de acesso'),
        content: Text(
          'Tem certeza que deseja excluir "${role.label}"? Quem tinha esse perfil de acesso perde as permissões associadas.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(roleRepositoryProvider).deleteRole(role.id);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}
