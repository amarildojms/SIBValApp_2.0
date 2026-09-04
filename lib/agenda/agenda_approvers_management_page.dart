import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/agenda_repository.dart';
import '../data/user_repository.dart';
import '../models/app_user.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

/// Sem equivalente no app nativo — feature nova (03/09/2026, pedido do
/// usuário: "o aprovador será previamente determinado pelo admin em uma
/// página de configurações dentro do calendário"). Mesmo padrão exato de
/// `CifraEditorsManagementPage` (`lib/praise/cifra_editors_management_page.dart`)
/// — marca/desmarca cada usuário aprovado como aprovador de compromissos da
/// Agenda, salvando na hora (`AgendaApproversRepository.setUids`), sem virar
/// um papel em `users/{uid}.roles`. Aberta por um ícone admin-only na app bar
/// de `AgendaPage`.
class AgendaApproversManagementPage extends ConsumerStatefulWidget {
  const AgendaApproversManagementPage({super.key});

  @override
  ConsumerState<AgendaApproversManagementPage> createState() =>
      _AgendaApproversManagementPageState();
}

class _AgendaApproversManagementPageState
    extends ConsumerState<AgendaApproversManagementPage> {
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
      await ref.read(agendaApproversRepositoryProvider).setUids(next);
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
    final uidsAsync = ref.watch(agendaApproverUidsProvider);

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Aprovadores da Agenda'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Selecione quem pode aprovar, rejeitar, cancelar e remanejar '
                'compromissos. O admin só ganha esse poder se também for '
                'marcado aqui.',
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
                      // 03/09/2026, 2ª rodada, pedido do usuário: "Admin não
                      // pode aprovar agendamento, somente quem o admin
                      // atribuir" — mesmo o admin precisa se auto-atribuir
                      // aqui, sem travamento automático (diferente de
                      // `CifraEditorsManagementPage`, onde admin é sempre
                      // habilitado).
                      final selected = uids.contains(user.uid);
                      return CheckboxListTile(
                        title: Text(user.name, style: TextStyle(color: context.textPrimary)),
                        subtitle: Text(
                          user.isAdmin ? '${user.email} — admin' : user.email,
                          style: TextStyle(color: context.textSecondary),
                        ),
                        value: selected,
                        onChanged: (value) => _toggle(uids, user.uid, value ?? false),
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
