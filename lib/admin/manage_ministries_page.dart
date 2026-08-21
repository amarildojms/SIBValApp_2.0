import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ministry_repository.dart';
import '../data/user_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

/// Tela nova (20/08/2026, sem equivalente no app nativo) onde admin/
/// Secretaria cadastram os ministérios e, dentro de cada um, os cargos/
/// funções que alimentam o seletor de `members_page.dart` (`_MemberDialog`).
/// Só chega aqui quem tem `canManageBirthdays` (gate no tile do menu Mais,
/// mesmo grupo que já edita Rol de Membros).
class ManageMinistriesPage extends ConsumerWidget {
  const ManageMinistriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final canManage = profileAsync.asData?.value?.canManageBirthdays ?? false;
    final ministriesAsync = ref.watch(ministriesProvider);

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      floatingActionButton: canManage
          ? FloatingActionButton(
              heroTag: 'manage_ministries_fab',
              onPressed: () => _showAddMinistryDialog(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Ministérios e Cargos'),
            if (!canManage)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Acesso restrito à Secretaria.', style: TextStyle(color: context.textSecondary)),
              )
            else
              Expanded(
                child: ministriesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) =>
                      Center(child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary))),
                  data: (ministries) {
                    if (ministries.isEmpty) {
                      return Center(
                        child: Text('Nenhum ministério cadastrado.', style: TextStyle(color: context.textSecondary)),
                      );
                    }
                    return ListView.builder(
                      itemCount: ministries.length,
                      itemBuilder: (context, index) => _MinistryTile(ministry: ministries[index]),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddMinistryDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Adicionar ministério'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nome do ministério'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.of(dialogContext).pop();
              await ref.read(ministryRepositoryProvider).create(name);
              ref.invalidate(ministriesProvider);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}

class _MinistryTile extends ConsumerWidget {
  const _MinistryTile({required this.ministry});

  final Ministry ministry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ExpansionTile(
      title: Text(ministry.name, style: TextStyle(color: context.textPrimary)),
      subtitle: Text(
        ministry.cargos.isEmpty ? 'Nenhum cargo cadastrado' : '${ministry.cargos.length} cargo(s)',
        style: TextStyle(color: context.textSecondary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Renomear',
            onPressed: () => _showRenameDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Excluir',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (ministry.cargos.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final cargo in ministry.cargos)
                      Chip(
                        label: Text(cargo),
                        onDeleted: () async {
                          await ref.read(ministryRepositoryProvider).removeCargo(ministry.id, cargo);
                          ref.invalidate(ministriesProvider);
                        },
                      ),
                  ],
                ),
              const SizedBox(height: 8),
              _AddCargoField(ministryId: ministry.id),
            ],
          ),
        ),
      ],
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: ministry.name);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Renomear ministério'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nome do ministério'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.of(dialogContext).pop();
              await ref.read(ministryRepositoryProvider).renameMinistry(ministry.id, name);
              ref.invalidate(ministriesProvider);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir ministério'),
        content: Text(
          'Tem certeza que deseja excluir "${ministry.name}"? Membros já vinculados a ele mantêm o registro atual.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref.read(ministryRepositoryProvider).delete(ministry.id);
              ref.invalidate(ministriesProvider);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}

class _AddCargoField extends ConsumerStatefulWidget {
  const _AddCargoField({required this.ministryId});

  final String ministryId;

  @override
  ConsumerState<_AddCargoField> createState() => _AddCargoFieldState();
}

class _AddCargoFieldState extends ConsumerState<_AddCargoField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final cargo = _controller.text.trim();
    if (cargo.isEmpty) return;
    _controller.clear();
    await ref.read(ministryRepositoryProvider).addCargo(widget.ministryId, cargo);
    ref.invalidate(ministriesProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Novo cargo/função'),
            onSubmitted: (_) => _submit(),
          ),
        ),
        IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: _submit),
      ],
    );
  }
}
