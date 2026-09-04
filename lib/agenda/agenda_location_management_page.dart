import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/agenda_location_repository.dart';
import '../models/agenda_location.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

/// Catálogo de locais/áreas da igreja (03/09/2026, pedido do usuário:
/// "Local/área deve ser configurável por um admin") — mesmo padrão simples de
/// CRUD de `ManageMinistriesPage`, alcançado pelo ícone de local na app bar
/// de `AgendaPage`, só admin.
class AgendaLocationManagementPage extends ConsumerWidget {
  const AgendaLocationManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(agendaLocationsProvider);

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      floatingActionButton: FloatingActionButton(
        heroTag: 'agenda_location_fab',
        onPressed: () => _showEditDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      // `SafeArea` no rodapé (03/09/2026, corrige conteúdo escondido atrás
      // dos botões de navegação do sistema, relatado pelo usuário) — mesmo
      // padrão já usado no resto do app.
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Locais da Agenda'),
            Expanded(
              child: locationsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text(
                    'Falha ao carregar: $error',
                    style: TextStyle(color: context.textPrimary),
                  ),
                ),
                data: (locations) => locations.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhum local cadastrado ainda.',
                          style: TextStyle(color: context.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: locations.length,
                        itemBuilder: (context, index) {
                          final location = locations[index];
                          return ListTile(
                            leading: Icon(
                              location.blocksEntireVenue
                                  ? Icons.lock_outlined
                                  : Icons.place_outlined,
                            ),
                            title: Text(location.name),
                            subtitle: location.blocksEntireVenue
                                ? const Text('Bloqueia todo o espaço')
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _showEditDialog(
                                    context,
                                    ref,
                                    existing: location,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () =>
                                      _confirmDelete(context, ref, location),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref, {
    AgendaLocation? existing,
  }) {
    final controller = TextEditingController(text: existing?.name ?? '');
    var blocksEntireVenue = existing?.blocksEntireVenue ?? false;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Adicionar local' : 'Editar local'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nome do local'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Bloqueia todo o espaço'),
                subtitle: const Text(
                  'Qualquer compromisso/evento no mesmo horário entra em '
                  'conflito com este local, mesmo usando uma área diferente.',
                ),
                value: blocksEntireVenue,
                onChanged: (value) =>
                    setDialogState(() => blocksEntireVenue = value ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                Navigator.of(dialogContext).pop();
                final repo = ref.read(agendaLocationRepositoryProvider);
                if (existing == null) {
                  await repo.create(name, blocksEntireVenue: blocksEntireVenue);
                } else {
                  await repo.update(
                    existing.id,
                    name,
                    blocksEntireVenue: blocksEntireVenue,
                  );
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AgendaLocation location,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir local'),
        content: Text('Excluir "${location.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(agendaLocationRepositoryProvider).delete(location.id);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}
