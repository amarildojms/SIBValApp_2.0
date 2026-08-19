import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Espelha EventEmailSendersFragment.kt/EventEmailSendersViewModel.kt: lista
/// de e-mails autorizados a criar eventos por e-mail, busca, adicionar
/// (validado) e remover (sem confirmação, igual ao original). Só chega aqui
/// quem tem canManageEventos (gate fica no tile do menu Mais).
class EventEmailSendersPage extends ConsumerStatefulWidget {
  const EventEmailSendersPage({super.key});

  @override
  ConsumerState<EventEmailSendersPage> createState() => _EventEmailSendersPageState();
}

class _EventEmailSendersPageState extends ConsumerState<EventEmailSendersPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emailsAsync = ref.watch(eventEmailSendersProvider);

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenTitle('Remetentes de E-mail de Eventos'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(labelText: 'Buscar e-mail', prefixIcon: Icon(Icons.search)),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: emailsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary))),
              data: (emails) {
                final filtered = _query.trim().isEmpty
                    ? emails
                    : emails.where((e) => e.toLowerCase().contains(_query.toLowerCase())).toList();
                if (filtered.isEmpty) {
                  return Center(child: Text('Nenhum e-mail cadastrado.', style: TextStyle(color: context.textSecondary)));
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final email = filtered[index];
                    return ListTile(
                      title: Text(email, style: TextStyle(color: context.textPrimary)),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => _removeEmail(emails, email),
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
    );
  }

  Future<void> _removeEmail(List<String> current, String email) async {
    final updated = current.where((e) => e != email).toList();
    await ref.read(settingsRepositoryProvider).setEventEmailSenders(updated);
    ref.invalidate(eventEmailSendersProvider);
  }

  void _showAddDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Adicionar e-mail'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'E-mail'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              final normalized = controller.text.trim().toLowerCase();
              if (!_emailRegex.hasMatch(normalized)) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Informe um e-mail válido.')));
                return;
              }
              Navigator.of(dialogContext).pop();
              final current = await ref.read(eventEmailSendersProvider.future);
              final updated = {...current, normalized}.toList();
              await ref.read(settingsRepositoryProvider).setEventEmailSenders(updated);
              ref.invalidate(eventEmailSendersProvider);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
